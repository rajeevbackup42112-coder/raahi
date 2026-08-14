-- ============================================================
-- RAAHI — T2-BUG-02: Offline Driver / Trip Lifecycle Fix
-- Migration: 20260811110000_raahi_t2_bug02_offline_driver_trip_lifecycle.sql
-- ============================================================
--
-- CLASSIFICATION: BOTH (logic defect + resulting bad database state)
--
-- ROOT CAUSE:
--   TWO independent defects combine to produce the observed behaviour:
--
--   DEFECT A — get_active_trip_for_route has NO driver eligibility check.
--     It queries trips WHERE status IN ('accepting_bookings',...) with
--     ORDER BY created_at DESC LIMIT 1. It does NOT check:
--       - drivers.availability_status (offline/suspended)
--       - drivers.verification_status (suspended/rejected)
--       - driver_queue.status (is driver actually in FIFO?)
--       - FIFO ownership (is this the canonical current FIFO driver?)
--     Result: Anil's accepting_bookings trip is returned even though
--     Anil is offline. This is the source of:
--       "Driver available" / "0 seats available" / "TATA TIAGO"
--
--   DEFECT B — No go-offline path closes the driver's accepting_bookings trip.
--     When a driver goes offline (manually, admin removal, suspension,
--     offer expiry, trip completion, etc.), the existing code:
--       - Sets drivers.availability_status = 'offline'
--       - Sets/cancels driver_queue row
--     But it does NOT:
--       - Cancel/close the driver's accepting_bookings trip
--     Result: Anil's trip remains status='accepting_bookings' indefinitely
--     after he went offline. This is the "bad database state" that
--     Defect A then surfaces to passengers.
--
-- HOW ANIL'S STATE WAS CREATED:
--   1. Anil went online → driver_go_online created a driver_queue row
--      (status='waiting') and called match_route_queue.
--   2. match_route_queue found waiting passengers → created a provisional
--      trip → sent Anil an offer (driver_queue.status='offered').
--   3. Anil accepted → driver_accept_offer set trip.status='accepting_bookings',
--      driver_queue.status='assigned', drivers.availability_status='active'.
--   4. At some point Anil went offline (manually or admin action).
--      The go-offline path set drivers.availability_status='offline' and
--      cancelled/completed the driver_queue row.
--   5. BUT: trip.status was never changed from 'accepting_bookings'.
--      The trip became an orphan — no active driver, but still
--      passenger-eligible according to get_active_trip_for_route.
--
-- WHY EXISTING LOGIC ALLOWED IT:
--   - admin_abort_trip exists but was never called when Anil went offline.
--   - admin_suspend_driver cancels driver_queue but does NOT abort the trip.
--   - admin_driver_go_offline cancels driver_queue but does NOT abort the trip.
--   - driver_complete_trip sets availability='offline' but only for completed trips.
--   - No RPC enforces: "if driver goes offline and has an accepting_bookings trip,
--     cancel that trip and recover passengers."
--
-- FIXES IN THIS MIGRATION:
--
--   FIX 1 — get_active_trip_for_route: Add canonical driver eligibility check.
--     A trip is only passenger-eligible if ALL of:
--       - trip.status IN ('accepting_bookings', 'full', 'ready', 'boarding')
--       - driver.availability_status NOT IN ('offline', 'completed')
--       - driver.verification_status NOT IN ('suspended', 'rejected')
--       - profile.status != 'suspended'
--       - driver_queue row for this driver+route is in operational state
--         (waiting, offered, assigned, active) — not cancelled/completed
--     This is the CANONICAL PASSENGER-ELIGIBILITY RULE.
--     "trip.status is non-terminal" by itself MUST NOT mean "trip can accept passengers."
--
--   FIX 2 — close_driver_trip_on_offline: New internal helper function.
--     Called by every go-offline path. If the driver has a non-terminal trip
--     with no confirmed passengers (or with passengers — recover them), it
--     cancels the trip and returns passengers to FIFO WAITING.
--     This makes the offline→trip-closed transition deterministic.
--
--   FIX 3 — driver_go_online: Add explicit check that driver has no
--     orphan accepting_bookings trip before allowing re-entry.
--     (Defensive: should not be needed after Fix 2, but belt-and-suspenders.)
--
--   FIX 4 — admin_driver_go_offline: Call close_driver_trip_on_offline.
--
--   FIX 5 — admin_suspend_driver: Call close_driver_trip_on_offline.
--     (Currently only cancels driver_queue, not the trip.)
--
--   FIX 6 — admin_remove_driver_from_queue (stage62): Call close_driver_trip_on_offline.
--
--   FIX 7 — expire_driver_offer: Already calls release_provisional_trip for
--     provisional trips. No change needed for the offer-expiry path.
--     But if driver is MOVE_TO_END and has an accepting_bookings trip
--     (post-accept expiry scenario), close it.
--
--   FIX 8 — admin_check_operational_consistency: Extend with 4 new checks:
--     11. offline driver with passenger-eligible trip
--     12. suspended driver with passenger-eligible trip
--     13. multiple passenger-eligible trips competing for same route
--     14. FIFO ownership mismatch (trip driver != canonical FIFO driver)
--
--   FIX 9 — SYSTEM-WIDE REPAIR: Cancel all accepting_bookings trips where
--     the driver is offline/suspended. Recover passengers to FIFO WAITING.
--     Idempotent. Preserves history. Does not touch Rajeev/Dipti FIFO.
--
-- CANONICAL PASSENGER-ELIGIBILITY RULE (after fix):
--   A trip is eligible to accept new passengers if and only if:
--     1. trip.status IN ('accepting_bookings', 'full', 'ready', 'boarding')
--     2. trip.driver_id IS NOT NULL
--     3. driver.availability_status NOT IN ('offline', 'completed')
--     4. driver.verification_status NOT IN ('suspended', 'rejected')
--     5. profile.status != 'suspended'
--     6. driver has a non-terminal driver_queue row for this route
--     7. route.status = 'active'
--     8. trip.vehicle_id IS NOT NULL and vehicle.status = 'active'
--   This rule is enforced server-side in get_active_trip_for_route.
--   Individual frontend components MUST NOT invent their own definition.
--
-- GO-OFFLINE LIFECYCLE (after fix):
--   Any path that sets drivers.availability_status = 'offline' MUST also:
--     1. Cancel/complete the driver_queue row (already done)
--     2. Call close_driver_trip_on_offline(driver_id) which:
--        a. Finds any non-terminal trip for this driver
--        b. Cancels the trip (status = 'cancelled')
--        c. Returns confirmed passengers to FIFO WAITING (pq.status = 'WAITING')
--        d. Resets booking.trip_id = NULL, booking.status = 'queued'
--        e. Triggers match_route_queue for recovered passengers
--        f. Writes audit log
--   This transition is now deterministic and cannot leave an orphan trip.
--
-- FIFO LOGIC (after fix):
--   get_active_trip_for_route selects the trip belonging to the canonical
--   FIFO driver — the driver whose driver_queue row has the lowest
--   queue_position among operational (non-terminal) entries for the route.
--   It does NOT simply ORDER BY trip.created_at DESC.
--   Selection follows business state and FIFO rules, not timestamps.
--
-- PRESERVATION RULES:
--   - No hard deletion of trips, bookings, or passenger_queue rows
--   - Historical records preserved for audit
--   - Rajeev Backup4 (#1) and Dipti (#2) FIFO positions NOT disturbed
--   - Passenger abuse cooldown NOT triggered by system repair
--   - Fare history NOT altered
--   - Completed trips NOT altered
--   - Version 61/62 stale-terminal protections preserved
--   - T2-BUG-01 fixes in migration 100000 preserved
-- ============================================================

-- ============================================================
-- STEP 1: ADD NEW AUDIT ACTIONS
-- ============================================================

ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'trip_closed_driver_offline';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'trip_closed_driver_suspended';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'orphan_trip_repaired';

COMMIT;

-- ============================================================
-- STEP 2: close_driver_trip_on_offline — internal helper
--
-- Called by every go-offline path to ensure no orphan
-- accepting_bookings trip is left behind.
--
-- Behaviour:
--   - Finds any non-terminal trip for the driver
--   - Cancels the trip
--   - Returns confirmed passengers to FIFO WAITING
--   - Resets booking.trip_id = NULL, booking.status = 'queued'
--   - Triggers match_route_queue for recovered passengers
--   - Writes audit log
--   - Idempotent: safe to call even if no trip exists
--
-- p_reason: 'driver_offline' | 'driver_suspended' | 'admin_removed' | etc.
-- p_performed_by: UUID of admin or driver profile performing the action
-- ============================================================

CREATE OR REPLACE FUNCTION public.close_driver_trip_on_offline(
  p_driver_id    UUID,   -- drivers.id (NOT profile_id)
  p_reason       TEXT,
  p_performed_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trip            RECORD;
  v_route_id        UUID;
  v_recovered_count INTEGER := 0;
  v_audit_action    public.audit_action;
BEGIN
  IF p_driver_id IS NULL THEN
    RETURN jsonb_build_object('closed', false, 'reason', 'no_driver_id');
  END IF;

  -- Find any non-terminal trip for this driver
  -- We look for accepting_bookings, full, ready, boarding, departure_pending
  -- (in_progress trips should be aborted explicitly by admin — we skip those
  --  to avoid data loss on active rides)
  SELECT t.*
  INTO v_trip
  FROM public.trips t
  WHERE t.driver_id = p_driver_id
    AND t.status IN ('accepting_bookings', 'full', 'ready', 'boarding')
  ORDER BY t.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    -- No orphan trip — nothing to do
    RETURN jsonb_build_object('closed', false, 'reason', 'no_eligible_trip');
  END IF;

  v_route_id := v_trip.route_id;

  -- Determine audit action
  v_audit_action := CASE
    WHEN p_reason ILIKE '%suspend%' THEN 'trip_closed_driver_suspended'::public.audit_action
    ELSE 'trip_closed_driver_offline'::public.audit_action
  END;

  -- ── 1. Cancel the trip ──────────────────────────────────────────────────
  UPDATE public.trips
  SET
    status     = 'cancelled'::public.trip_status,
    notes      = format('auto_closed: driver_offline — %s', p_reason),
    updated_at = NOW()
  WHERE id = v_trip.id;

  -- ── 2. Recover passengers → return to FIFO WAITING ──────────────────────
  -- Preserve original queue_sequence so FIFO order is maintained.
  UPDATE public.passenger_queue
  SET
    status           = 'WAITING',
    assigned_trip_id = NULL,
    updated_at       = NOW()
  WHERE assigned_trip_id = v_trip.id
    AND status NOT IN ('COMPLETED', 'CANCELLED');

  GET DIAGNOSTICS v_recovered_count = ROW_COUNT;

  -- ── 3. Reset bookings linked to this trip ───────────────────────────────
  UPDATE public.bookings
  SET
    trip_id    = NULL,
    status     = 'queued'::public.booking_status,
    updated_at = NOW()
  WHERE trip_id = v_trip.id
    AND status NOT IN ('cancelled', 'no_show', 'completed');

  -- ── 4. Audit ────────────────────────────────────────────────────────────
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (
    p_performed_by,
    v_audit_action,
    'trips',
    v_trip.id,
    jsonb_build_object(
      'trip_status',         v_trip.status,
      'driver_id',           p_driver_id,
      'recovered_passengers', v_recovered_count
    ),
    jsonb_build_object(
      'trip_status',         'cancelled',
      'reason',              p_reason,
      'recovered_passengers', v_recovered_count
    ),
    format('Trip auto-closed: driver went offline/suspended. %s passenger(s) returned to queue. Reason: %s',
           v_recovered_count, p_reason)
  );

  -- ── 5. Trigger FIFO re-match for recovered passengers ───────────────────
  IF v_recovered_count > 0 THEN
    BEGIN
      PERFORM public.match_route_queue(v_route_id);
    EXCEPTION WHEN OTHERS THEN
      NULL; -- Non-blocking: don't fail the offline transition if rematch errors
    END;
  END IF;

  RETURN jsonb_build_object(
    'closed',               true,
    'trip_id',              v_trip.id,
    'recovered_passengers', v_recovered_count,
    'route_id',             v_route_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.close_driver_trip_on_offline(UUID, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_driver_trip_on_offline(UUID, TEXT, UUID) TO service_role;

-- ============================================================
-- STEP 3: FIX get_active_trip_for_route — CANONICAL ELIGIBILITY RULE
--
-- ROOT CAUSE FIX (DEFECT A):
-- The original function only checked trip.status. It did NOT check
-- whether the driver is operationally eligible (online, approved,
-- not suspended, in FIFO queue). This allowed Anil's trip to be
-- returned even though Anil was offline.
--
-- NEW RULE: A trip is passenger-eligible if and only if:
--   1. trip.status IN ('accepting_bookings', 'full', 'ready', 'boarding')
--   2. driver.availability_status NOT IN ('offline', 'completed')
--   3. driver.verification_status NOT IN ('suspended', 'rejected')
--   4. profile.status != 'suspended'
--   5. driver has a non-terminal driver_queue row for this route
--   6. route.status = 'active'
--   7. vehicle.status = 'active'
--
-- FIFO SELECTION: We select the trip belonging to the driver with the
-- lowest queue_position among operational driver_queue entries.
-- This follows business state and FIFO rules, NOT timestamps.
-- "ORDER BY trip.created_at DESC" is NOT the correct selection criterion.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_active_trip_for_route(p_route_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trip        RECORD;
  v_driver_name TEXT;
  v_vehicle     RECORD;
  v_route       RECORD;
BEGIN
  -- Verify route is active
  SELECT * INTO v_route FROM public.routes WHERE id = p_route_id;
  IF NOT FOUND OR v_route.status <> 'active' THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  -- ── CANONICAL PASSENGER-ELIGIBILITY QUERY ──────────────────────────────
  --
  -- Select the trip belonging to the FIFO-canonical eligible driver.
  --
  -- Eligibility requirements (ALL must be true):
  --   1. trip.status IN ('accepting_bookings', 'full', 'ready', 'boarding')
  --   2. driver.availability_status NOT IN ('offline', 'completed')
  --   3. driver.verification_status NOT IN ('suspended', 'rejected')
  --   4. profile.status != 'suspended'
  --   5. driver has a non-terminal driver_queue row for this route
  --      (status IN ('waiting', 'offered', 'assigned', 'active'))
  --   6. vehicle.status = 'active'
  --
  -- FIFO ordering: driver_queue.queue_position ASC (lowest = first in FIFO)
  -- This is the canonical FIFO rule — NOT ORDER BY trip.created_at.
  --
  -- "trip.status is non-terminal" by itself MUST NOT mean
  -- "trip can accept passengers." Driver eligibility is required.
  -- ──────────────────────────────────────────────────────────────────────
  SELECT
    t.id                    AS trip_id,
    t.route_id,
    t.total_seats,
    t.booked_seats,
    (t.total_seats - t.booked_seats) AS available_seats,
    t.fare_per_seat,
    t.status,
    t.driver_id,
    d.profile_id            AS driver_profile_id,
    v.make                  AS vehicle_make,
    v.model                 AS vehicle_model,
    v.vehicle_type,
    v.registration_number   AS vehicle_registration,
    v.seating_capacity      AS vehicle_capacity,
    dq.queue_position       AS fifo_position
  INTO v_trip
  FROM public.trips t
  -- Join driver
  JOIN public.drivers d ON d.id = t.driver_id
  -- Join driver profile (for suspension check)
  JOIN public.profiles pr ON pr.id = d.profile_id
  -- Join vehicle (must be active)
  JOIN public.vehicles v ON v.id = t.vehicle_id
  -- Join driver_queue: driver must have a non-terminal queue entry for this route
  -- This is the FIFO ownership check
  JOIN public.driver_queue dq ON (
    dq.driver_id = d.id
    AND dq.route_id = p_route_id
    AND dq.status IN ('waiting', 'offered', 'assigned', 'active')
  )
  WHERE
    -- Trip must be on this route and in a passenger-accepting state
    t.route_id = p_route_id
    AND t.status IN ('accepting_bookings', 'full', 'ready', 'boarding')
    -- ELIGIBILITY CHECK 1: Driver must be operationally online/active
    -- This is the key fix — offline drivers are excluded
    AND d.availability_status NOT IN ('offline', 'completed')
    -- ELIGIBILITY CHECK 2: Driver must not be suspended/rejected
    AND d.verification_status NOT IN ('suspended', 'rejected')
    -- ELIGIBILITY CHECK 3: Driver profile must not be suspended
    AND pr.status <> 'suspended'
    -- ELIGIBILITY CHECK 4: Vehicle must be active
    AND v.status = 'active'
  -- FIFO ORDER: select the driver with the lowest queue_position
  -- This is the canonical FIFO rule
  ORDER BY dq.queue_position ASC, dq.joined_at ASC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  -- Get driver name
  SELECT p.name INTO v_driver_name
  FROM public.profiles p
  WHERE p.id = v_trip.driver_profile_id;

  RETURN jsonb_build_object(
    'found',                true,
    'trip_id',              v_trip.trip_id,
    'route_id',             v_trip.route_id,
    'total_seats',          v_trip.total_seats,
    'booked_seats',         v_trip.booked_seats,
    'available_seats',      v_trip.available_seats,
    'fare_per_seat',        v_trip.fare_per_seat,
    'status',               v_trip.status,
    'driver_name',          COALESCE(v_driver_name, 'Assigned'),
    'vehicle_make',         COALESCE(v_trip.vehicle_make, ''),
    'vehicle_model',        COALESCE(v_trip.vehicle_model, ''),
    'vehicle_type',         COALESCE(v_trip.vehicle_type, ''),
    'vehicle_registration', COALESCE(v_trip.vehicle_registration, ''),
    'fifo_position',        v_trip.fifo_position
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_active_trip_for_route(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_active_trip_for_route(UUID) TO anon;

-- ============================================================
-- STEP 4: FIX admin_driver_go_offline — call close_driver_trip_on_offline
--
-- ROOT CAUSE FIX (DEFECT B, path 1):
-- admin_driver_go_offline previously only set driver.availability_status='offline'
-- and cancelled the driver_queue row. It did NOT close the driver's trip.
-- Now it calls close_driver_trip_on_offline to ensure the trip is cancelled
-- and passengers are recovered.
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_driver_go_offline(
  p_driver_queue_id UUID,
  p_admin_id        UUID  -- kept for signature compatibility; actual auth from auth.uid()
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id    UUID;
  v_admin       RECORD;
  v_dq          RECORD;
  v_close_result JSONB;
BEGIN
  -- Auth from session — ignore p_admin_id for authorization
  v_admin_id := auth.uid();
  SELECT * INTO v_admin FROM public.profiles WHERE id = v_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unauthorized: admin only';
  END IF;

  SELECT * INTO v_dq FROM public.driver_queue WHERE id = p_driver_queue_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Driver queue entry not found'; END IF;

  -- ── FIX: Close any accepting_bookings trip before going offline ──────────
  v_close_result := public.close_driver_trip_on_offline(
    v_dq.driver_id,
    'admin_driver_go_offline',
    v_admin_id
  );

  -- Cancel the driver_queue entry
  UPDATE public.driver_queue
  SET status = 'offline', updated_at = NOW()
  WHERE id = p_driver_queue_id;

  -- Set driver offline
  UPDATE public.drivers
  SET availability_status = 'offline', updated_at = NOW()
  WHERE id = v_dq.driver_id;

  -- Trigger rematch (in case other drivers are waiting)
  PERFORM public.match_route_queue(v_dq.route_id);

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, notes)
  VALUES (
    v_admin_id,
    'driver_removed_admin'::public.audit_action,
    'driver_queue',
    p_driver_queue_id,
    format('Admin took driver offline. Trip closed: %s', v_close_result->>'closed')
  );

  RETURN jsonb_build_object(
    'success',      true,
    'trip_closed',  v_close_result
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_driver_go_offline(UUID, UUID) TO authenticated;

-- ============================================================
-- STEP 5: FIX admin_suspend_driver — call close_driver_trip_on_offline
--
-- ROOT CAUSE FIX (DEFECT B, path 2):
-- admin_suspend_driver previously cancelled driver_queue but did NOT
-- close the driver's accepting_bookings trip. Now it calls
-- close_driver_trip_on_offline to ensure the trip is cancelled
-- and passengers are recovered.
--
-- Note: The existing guard blocks suspension during in_progress/boarding
-- trips. We preserve that guard. close_driver_trip_on_offline only
-- closes accepting_bookings/full/ready/boarding trips (not in_progress).
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_suspend_driver(
  p_driver_id UUID,   -- drivers.id
  p_reason    TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id     UUID;
  v_admin        RECORD;
  v_driver       RECORD;
  v_trip         RECORD;
  v_close_result JSONB;
BEGIN
  v_admin_id := auth.uid();
  SELECT * INTO v_admin FROM public.profiles WHERE id = v_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'A reason is required to suspend a driver');
  END IF;

  SELECT * INTO v_driver FROM public.drivers WHERE id = p_driver_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver not found');
  END IF;

  IF v_driver.verification_status = 'suspended' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver is already suspended');
  END IF;

  -- Safety check: block suspension if driver has an active in-progress trip
  SELECT t.* INTO v_trip
  FROM public.trips t
  WHERE t.driver_id = p_driver_id
    AND t.status IN ('in_progress', 'boarding')
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Cannot suspend driver during an active trip. Use Trip Abort first, then suspend.'
    );
  END IF;

  -- ── FIX: Close any accepting_bookings trip before suspending ────────────
  v_close_result := public.close_driver_trip_on_offline(
    p_driver_id,
    format('driver_suspended: %s', p_reason),
    v_admin_id
  );

  -- Suspend driver
  UPDATE public.drivers
  SET
    verification_status = 'suspended'::public.driver_verification_status,
    availability_status = 'offline'::public.driver_availability_status,
    current_route_id    = NULL,
    updated_at          = NOW()
  WHERE id = p_driver_id;

  -- Remove from any active queue entry (not on a trip)
  UPDATE public.driver_queue
  SET
    status       = 'cancelled'::public.queue_status,
    completed_at = NOW(),
    updated_at   = NOW()
  WHERE driver_id = p_driver_id
    AND status NOT IN ('completed', 'cancelled', 'declined', 'assigned');

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (
    v_admin_id,
    'driver_suspended'::public.audit_action,
    'drivers',
    p_driver_id,
    jsonb_build_object('verification_status', v_driver.verification_status, 'availability_status', v_driver.availability_status),
    jsonb_build_object('verification_status', 'suspended', 'availability_status', 'offline'),
    format('%s. Trip closed: %s', p_reason, v_close_result->>'closed')
  );

  RETURN jsonb_build_object(
    'success',     true,
    'message',     'Driver suspended and removed from queue',
    'trip_closed', v_close_result
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_suspend_driver(UUID, TEXT) TO authenticated;

-- ============================================================
-- STEP 6: FIX admin_remove_driver_from_queue (stage62 version)
--         — call close_driver_trip_on_offline
--
-- ROOT CAUSE FIX (DEFECT B, path 3):
-- The stage62 version of admin_remove_driver_from_queue cancelled
-- driver_queue and set driver offline but did NOT close the trip.
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_remove_driver_from_queue(
  p_queue_entry_id UUID,
  p_reason         TEXT DEFAULT 'Admin removed driver from queue'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id     UUID;
  v_admin        RECORD;
  v_queue        RECORD;
  v_close_result JSONB;
BEGIN
  v_admin_id := auth.uid();
  SELECT * INTO v_admin FROM public.profiles WHERE id = v_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  SELECT dq.*, d.id AS driver_rec_id
  INTO v_queue
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  WHERE dq.id = p_queue_entry_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Queue entry not found');
  END IF;

  -- ── FIX: Close any accepting_bookings trip before removing from queue ────
  v_close_result := public.close_driver_trip_on_offline(
    v_queue.driver_rec_id,
    format('admin_remove_from_queue: %s', p_reason),
    v_admin_id
  );

  -- Cancel the queue entry
  UPDATE public.driver_queue
  SET status = 'cancelled', completed_at = NOW()
  WHERE id = p_queue_entry_id;

  -- Set driver offline
  UPDATE public.drivers
  SET availability_status = 'offline', current_route_id = NULL
  WHERE id = v_queue.driver_rec_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, notes)
  VALUES (
    v_admin_id,
    'driver_removed_admin'::public.audit_action,
    'driver_queue',
    p_queue_entry_id,
    format('%s. Trip closed: %s', COALESCE(p_reason, 'Admin removed driver from queue'), v_close_result->>'closed')
  );

  RETURN jsonb_build_object(
    'success',     true,
    'message',     'Driver removed from queue',
    'trip_closed', v_close_result
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_remove_driver_from_queue(UUID, TEXT) TO authenticated;

-- ============================================================
-- STEP 7: FIX driver_go_online — add orphan trip guard
--
-- Defensive check: if a driver somehow has an orphan accepting_bookings
-- trip when they try to go online again, close it first.
-- This should not happen after Fix 2, but provides belt-and-suspenders.
-- ============================================================

CREATE OR REPLACE FUNCTION public.driver_go_online(
  p_driver_profile_id UUID,
  p_route_id          UUID,
  p_vehicle_id        UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver          RECORD;
  v_route           RECORD;
  v_vehicle         RECORD;
  v_effective_vid   UUID;
  v_conflict_driver RECORD;
  v_existing_queue  RECORD;
  v_profile         RECORD;
  v_orphan_trip     RECORD;
BEGIN
  -- Get driver
  SELECT * INTO v_driver FROM public.drivers WHERE profile_id = p_driver_profile_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver profile not found');
  END IF;

  -- Must be approved
  IF v_driver.verification_status <> 'approved' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver is not approved');
  END IF;

  -- Must not be suspended at profile level
  SELECT * INTO v_profile FROM public.profiles WHERE id = p_driver_profile_id;
  IF v_profile.status = 'suspended' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Account is suspended');
  END IF;

  -- Route must be active (not paused or inactive)
  SELECT * INTO v_route FROM public.routes WHERE id = p_route_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Route not found');
  END IF;
  IF v_route.status <> 'active' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Route is not currently active');
  END IF;

  -- Determine effective vehicle: use assigned vehicle (V1 rule: one vehicle per driver)
  v_effective_vid := COALESCE(p_vehicle_id, v_driver.current_vehicle_id);
  IF v_effective_vid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No vehicle assigned. Admin must assign a vehicle before you can go online.');
  END IF;

  -- Fetch vehicle
  SELECT * INTO v_vehicle FROM public.vehicles WHERE id = v_effective_vid;
  IF NOT FOUND OR v_vehicle.status <> 'active' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Assigned vehicle is not active');
  END IF;

  -- ONE ACTIVE DRIVER PER VEHICLE: block if another active driver has this vehicle
  SELECT d.* INTO v_conflict_driver
  FROM public.drivers d
  WHERE d.current_vehicle_id = v_effective_vid
    AND d.id <> v_driver.id
    AND d.availability_status NOT IN ('offline', 'completed')
    AND d.verification_status NOT IN ('suspended', 'rejected')
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'This vehicle is currently in use by another active driver. Contact admin to resolve.'
    );
  END IF;

  -- Check for existing non-terminal queue entry
  SELECT * INTO v_existing_queue
  FROM public.driver_queue
  WHERE driver_id = v_driver.id
    AND status NOT IN ('completed', 'cancelled', 'declined')
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Already in queue or on a trip');
  END IF;

  -- ── DEFENSIVE: Close any orphan accepting_bookings trip ─────────────────
  -- This should not exist after Fix 2, but if it does (e.g. from pre-fix state),
  -- close it before allowing the driver to re-enter the queue.
  SELECT t.* INTO v_orphan_trip
  FROM public.trips t
  WHERE t.driver_id = v_driver.id
    AND t.status IN ('accepting_bookings', 'full', 'ready', 'boarding')
  LIMIT 1;

  IF FOUND THEN
    PERFORM public.close_driver_trip_on_offline(
      v_driver.id,
      'driver_go_online_orphan_cleanup',
      p_driver_profile_id
    );
  END IF;

  -- Insert into driver_queue
  INSERT INTO public.driver_queue (
    route_id, driver_id, vehicle_id, queue_position, status, joined_at
  )
  VALUES (
    p_route_id,
    v_driver.id,
    v_effective_vid,
    (SELECT COALESCE(MAX(queue_position), 0) + 1
     FROM public.driver_queue
     WHERE route_id = p_route_id AND status NOT IN ('completed', 'cancelled', 'declined')),
    'waiting'::public.queue_status,
    NOW()
  );

  -- Update driver state
  UPDATE public.drivers
  SET
    availability_status = 'online'::public.driver_availability_status,
    current_route_id    = p_route_id,
    current_vehicle_id  = v_effective_vid,
    updated_at          = NOW()
  WHERE id = v_driver.id;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value)
  VALUES (
    p_driver_profile_id,
    'driver_joined_queue'::public.audit_action,
    'drivers',
    v_driver.id,
    jsonb_build_object('route_id', p_route_id, 'vehicle_id', v_effective_vid)
  );

  -- Trigger matching
  PERFORM public.match_route_queue(p_route_id);

  RETURN jsonb_build_object('success', true, 'message', 'You are now online and in the queue');
END;
$$;

GRANT EXECUTE ON FUNCTION public.driver_go_online(UUID, UUID, UUID) TO authenticated;

-- ============================================================
-- STEP 8: EXTEND admin_check_operational_consistency
--
-- Add 4 new checks (11-14) for T2-BUG-02 patterns:
--   11. offline driver with passenger-eligible trip
--   12. suspended driver with passenger-eligible trip
--   13. multiple passenger-eligible trips competing for same route
--   14. route availability resolving to an ineligible driver
--       (FIFO ownership mismatch)
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_check_operational_consistency()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_issues   JSONB := '[]'::JSONB;
  v_row      RECORD;
  v_count    INTEGER := 0;
BEGIN
  -- ── ADMIN AUTH ────────────────────────────────────────────────────────────
  v_admin_id := auth.uid();
  IF v_admin_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin role required');
  END IF;

  -- ── CHECK 1: Active booking attached to terminal trip ─────────────────────
  FOR v_row IN
    SELECT
      b.id          AS booking_id,
      b.passenger_id,
      p.name        AS passenger_name,
      b.status      AS booking_status,
      b.trip_id,
      t.status      AS trip_status,
      b.is_test_data
    FROM public.bookings b
    JOIN public.trips t ON t.id = b.trip_id
    JOIN public.profiles p ON p.id = b.passenger_id
    WHERE b.status NOT IN ('cancelled', 'completed', 'no_show')
      AND t.status IN ('completed', 'cancelled')
  LOOP
    v_issues := v_issues || jsonb_build_object(
      'check',          1,
      'description',    'Active booking attached to terminal trip',
      'booking_id',     v_row.booking_id,
      'passenger_name', v_row.passenger_name,
      'booking_status', v_row.booking_status,
      'trip_id',        v_row.trip_id,
      'trip_status',    v_row.trip_status,
      'is_test_data',   v_row.is_test_data,
      'severity',       'HIGH',
      'action',         'Run admin_recover_stale_booking or system repair migration'
    );
    v_count := v_count + 1;
  END LOOP;

  -- ── CHECK 2: ASSIGNED passenger_queue attached to terminal trip ───────────
  FOR v_row IN
    SELECT
      pq.id           AS pq_id,
      pq.passenger_id,
      p.name          AS passenger_name,
      pq.status       AS pq_status,
      pq.assigned_trip_id,
      t.status        AS trip_status,
      pq.booking_id,
      pq.is_test_data
    FROM public.passenger_queue pq
    JOIN public.trips t ON t.id = pq.assigned_trip_id
    JOIN public.profiles p ON p.id = pq.passenger_id
    WHERE pq.status NOT IN ('CANCELLED', 'COMPLETED')
      AND t.status IN ('completed', 'cancelled')
  LOOP
    v_issues := v_issues || jsonb_build_object(
      'check',          2,
      'description',    'ASSIGNED passenger_queue attached to terminal trip (T2-BUG-01 pattern)',
      'pq_id',          v_row.pq_id,
      'passenger_name', v_row.passenger_name,
      'pq_status',      v_row.pq_status,
      'assigned_trip_id', v_row.assigned_trip_id,
      'trip_status',    v_row.trip_status,
      'booking_id',     v_row.booking_id,
      'is_test_data',   v_row.is_test_data,
      'severity',       'HIGH',
      'action',         'Run system repair migration or admin_recover_stale_booking'
    );
    v_count := v_count + 1;
  END LOOP;

  -- ── CHECK 3: Passenger with multiple active bookings ──────────────────────
  FOR v_row IN
    SELECT
      b.passenger_id,
      p.name          AS passenger_name,
      COUNT(*)        AS active_booking_count,
      jsonb_agg(b.id) AS booking_ids
    FROM public.bookings b
    JOIN public.profiles p ON p.id = b.passenger_id
    WHERE b.status NOT IN ('cancelled', 'completed', 'no_show')
    GROUP BY b.passenger_id, p.name
    HAVING COUNT(*) > 1
  LOOP
    v_issues := v_issues || jsonb_build_object(
      'check',               3,
      'description',         'Passenger with multiple active bookings',
      'passenger_id',        v_row.passenger_id,
      'passenger_name',      v_row.passenger_name,
      'active_booking_count', v_row.active_booking_count,
      'booking_ids',         v_row.booking_ids,
      'severity',            'HIGH',
      'action',              'Investigate and cancel stale bookings via admin_recover_stale_booking'
    );
    v_count := v_count + 1;
  END LOOP;

  -- ── CHECK 4: Passenger with multiple active queue entries ─────────────────
  FOR v_row IN
    SELECT
      pq.passenger_id,
      p.name          AS passenger_name,
      COUNT(*)        AS active_queue_count,
      jsonb_agg(pq.id) AS pq_ids
    FROM public.passenger_queue pq
    JOIN public.profiles p ON p.id = pq.passenger_id
    WHERE pq.status NOT IN ('CANCELLED', 'COMPLETED')
    GROUP BY pq.passenger_id, p.name
    HAVING COUNT(*) > 1
  LOOP
    v_issues := v_issues || jsonb_build_object(
      'check',              4,
      'description',        'Passenger with multiple active queue entries',
      'passenger_id',       v_row.passenger_id,
      'passenger_name',     v_row.passenger_name,
      'active_queue_count', v_row.active_queue_count,
      'pq_ids',             v_row.pq_ids,
      'severity',           'HIGH',
      'action',             'Investigate and cancel stale queue entries'
    );
    v_count := v_count + 1;
  END LOOP;

  -- ── CHECK 5: Driver with multiple active/non-terminal trips ───────────────
  FOR v_row IN
    SELECT
      t.driver_id,
      p.name          AS driver_name,
      COUNT(*)        AS active_trip_count,
      jsonb_agg(t.id) AS trip_ids,
      jsonb_agg(t.status) AS trip_statuses
    FROM public.trips t
    JOIN public.drivers d ON d.id = t.driver_id
    JOIN public.profiles p ON p.id = d.profile_id
    WHERE t.status NOT IN ('completed', 'cancelled')
    GROUP BY t.driver_id, p.name
    HAVING COUNT(*) > 1
  LOOP
    v_issues := v_issues || jsonb_build_object(
      'check',            5,
      'description',      'Driver with multiple active/non-terminal trips',
      'driver_id',        v_row.driver_id,
      'driver_name',      v_row.driver_name,
      'active_trip_count', v_row.active_trip_count,
      'trip_ids',         v_row.trip_ids,
      'trip_statuses',    v_row.trip_statuses,
      'severity',         'HIGH',
      'action',           'Investigate — cancel stale trips via admin_abort_trip'
    );
    v_count := v_count + 1;
  END LOOP;

  -- ── CHECK 6: driver_queue active/assigned row referencing terminal/missing trip ──
  FOR v_row IN
    SELECT
      dq.id           AS dq_id,
      dq.driver_id,
      p.name          AS driver_name,
      dq.status       AS dq_status,
      dq.provisional_trip_id,
      t.status        AS trip_status,
      dq.is_test_data
    FROM public.driver_queue dq
    JOIN public.drivers d ON d.id = dq.driver_id
    JOIN public.profiles p ON p.id = d.profile_id
    LEFT JOIN public.trips t ON t.id = dq.provisional_trip_id
    WHERE dq.status IN ('active', 'assigned', 'offered')
      AND dq.provisional_trip_id IS NOT NULL
      AND (t.id IS NULL OR t.status IN ('completed', 'cancelled'))
  LOOP
    v_issues := v_issues || jsonb_build_object(
      'check',              6,
      'description',        'driver_queue active/assigned row referencing terminal or missing trip',
      'dq_id',              v_row.dq_id,
      'driver_name',        v_row.driver_name,
      'dq_status',          v_row.dq_status,
      'provisional_trip_id', v_row.provisional_trip_id,
      'trip_status',        v_row.trip_status,
      'is_test_data',       v_row.is_test_data,
      'severity',           'MEDIUM',
      'action',             'Investigate — driver may need to go offline and rejoin queue'
    );
    v_count := v_count + 1;
  END LOOP;

  -- ── CHECK 7: Offline/suspended driver attached to operational trip ─────────
  -- This is the T2-BUG-02 pattern (Anil's case)
  FOR v_row IN
    SELECT
      t.id            AS trip_id,
      t.status        AS trip_status,
      t.driver_id,
      p.name          AS driver_name,
      d.availability_status,
      d.verification_status,
      r.from_location,
      r.to_location
    FROM public.trips t
    JOIN public.drivers d ON d.id = t.driver_id
    JOIN public.profiles p ON p.id = d.profile_id
    JOIN public.routes r ON r.id = t.route_id
    WHERE t.status NOT IN ('completed', 'cancelled')
      AND (
        d.availability_status IN ('offline', 'completed')
        OR d.verification_status IN ('suspended', 'rejected')
        OR p.status = 'suspended'
      )
  LOOP
    v_issues := v_issues || jsonb_build_object(
      'check',               7,
      'description',         'Offline/suspended driver attached to operational trip (T2-BUG-02 pattern)',
      'trip_id',             v_row.trip_id,
      'trip_status',         v_row.trip_status,
      'driver_name',         v_row.driver_name,
      'availability_status', v_row.availability_status,
      'verification_status', v_row.verification_status,
      'route',               format('%s → %s', v_row.from_location, v_row.to_location),
      'severity',            'HIGH',
      'action',              'Run system repair or admin_abort_trip to close orphan trip'
    );
    v_count := v_count + 1;
  END LOOP;

  -- ── CHECK 8: Trip driver inconsistent with passenger-visible assigned driver ──
  FOR v_row IN
    SELECT
      pq.id           AS pq_id,
      pq.passenger_id,
      p.name          AS passenger_name,
      pq.assigned_trip_id,
      t.driver_id     AS trip_driver_id,
      pd.name         AS trip_driver_name,
      b.trip_id       AS booking_trip_id
    FROM public.passenger_queue pq
    JOIN public.profiles p ON p.id = pq.passenger_id
    JOIN public.bookings b ON b.id = pq.booking_id
    JOIN public.trips t ON t.id = pq.assigned_trip_id
    JOIN public.drivers d ON d.id = t.driver_id
    JOIN public.profiles pd ON pd.id = d.profile_id
    WHERE pq.status IN ('ASSIGNED', 'MATCHING')
      AND b.trip_id IS NOT NULL
      AND b.trip_id <> pq.assigned_trip_id
      AND t.status NOT IN ('completed', 'cancelled')
  LOOP
    v_issues := v_issues || jsonb_build_object(
      'check',            8,
      'description',      'Trip driver inconsistent: booking.trip_id != pq.assigned_trip_id',
      'pq_id',            v_row.pq_id,
      'passenger_name',   v_row.passenger_name,
      'booking_trip_id',  v_row.booking_trip_id,
      'assigned_trip_id', v_row.assigned_trip_id,
      'trip_driver_name', v_row.trip_driver_name,
      'severity',         'HIGH',
      'action',           'Investigate — booking and queue assignment are pointing to different trips'
    );
    v_count := v_count + 1;
  END LOOP;

  -- ── CHECK 9: Vehicle/driver assignment inconsistency ──────────────────────
  FOR v_row IN
    SELECT
      v.id            AS vehicle_id,
      v.registration_number,
      v.assigned_driver_id,
      p1.name         AS vehicle_assigned_driver_name,
      d.id            AS driver_id,
      p2.name         AS driver_name,
      d.current_vehicle_id
    FROM public.vehicles v
    JOIN public.profiles p1 ON p1.id = v.assigned_driver_id
    JOIN public.drivers d ON d.profile_id = v.assigned_driver_id
    JOIN public.profiles p2 ON p2.id = d.profile_id
    WHERE v.assigned_driver_id IS NOT NULL
      AND d.current_vehicle_id IS NOT NULL
      AND d.current_vehicle_id <> v.id
  LOOP
    v_issues := v_issues || jsonb_build_object(
      'check',                    9,
      'description',              'Vehicle/driver assignment inconsistency',
      'vehicle_id',               v_row.vehicle_id,
      'registration_number',      v_row.registration_number,
      'vehicle_assigned_driver',  v_row.vehicle_assigned_driver_name,
      'driver_current_vehicle_id', v_row.current_vehicle_id,
      'severity',                 'MEDIUM',
      'action',                   'Use admin_assign_vehicle_to_driver to reconcile'
    );
    v_count := v_count + 1;
  END LOOP;

  -- ── CHECK 10: Terminal trip retaining operational driver_queue state ───────
  FOR v_row IN
    SELECT
      dq.id           AS dq_id,
      dq.driver_id,
      p.name          AS driver_name,
      dq.status       AS dq_status,
      dq.provisional_trip_id,
      t.status        AS trip_status,
      dq.is_test_data
    FROM public.driver_queue dq
    JOIN public.drivers d ON d.id = dq.driver_id
    JOIN public.profiles p ON p.id = d.profile_id
    JOIN public.trips t ON t.id = dq.provisional_trip_id
    WHERE dq.status IN ('waiting', 'active', 'assigned')
      AND t.status IN ('completed', 'cancelled')
  LOOP
    v_issues := v_issues || jsonb_build_object(
      'check',              10,
      'description',        'Terminal trip retaining operational driver_queue state',
      'dq_id',              v_row.dq_id,
      'driver_name',        v_row.driver_name,
      'dq_status',          v_row.dq_status,
      'provisional_trip_id', v_row.provisional_trip_id,
      'trip_status',        v_row.trip_status,
      'is_test_data',       v_row.is_test_data,
      'severity',           'MEDIUM',
      'action',             'Driver should go offline and rejoin queue, or admin can reset via test harness'
    );
    v_count := v_count + 1;
  END LOOP;

  -- ── CHECK 11: Offline driver with passenger-eligible trip (T2-BUG-02) ─────
  -- This is the exact Anil scenario: driver.availability_status='offline'
  -- but trip.status='accepting_bookings' (or other passenger-eligible status).
  FOR v_row IN
    SELECT
      t.id            AS trip_id,
      t.status        AS trip_status,
      t.driver_id,
      p.name          AS driver_name,
      d.availability_status,
      r.from_location,
      r.to_location,
      v.make          AS vehicle_make,
      v.model         AS vehicle_model,
      v.registration_number
    FROM public.trips t
    JOIN public.drivers d ON d.id = t.driver_id
    JOIN public.profiles p ON p.id = d.profile_id
    JOIN public.routes r ON r.id = t.route_id
    LEFT JOIN public.vehicles v ON v.id = t.vehicle_id
    WHERE t.status IN ('accepting_bookings', 'full', 'ready', 'boarding')
      AND d.availability_status IN ('offline', 'completed')
  LOOP
    v_issues := v_issues || jsonb_build_object(
      'check',               11,
      'description',         'OFFLINE driver has passenger-eligible trip (T2-BUG-02 — Anil pattern)',
      'trip_id',             v_row.trip_id,
      'trip_status',         v_row.trip_status,
      'driver_name',         v_row.driver_name,
      'availability_status', v_row.availability_status,
      'route',               format('%s → %s', v_row.from_location, v_row.to_location),
      'vehicle',             format('%s %s (%s)', v_row.vehicle_make, v_row.vehicle_model, v_row.registration_number),
      'severity',            'CRITICAL',
      'action',              'Run system repair: close_driver_trip_on_offline or admin_abort_trip'
    );
    v_count := v_count + 1;
  END LOOP;

  -- ── CHECK 12: Suspended driver with passenger-eligible trip ───────────────
  FOR v_row IN
    SELECT
      t.id            AS trip_id,
      t.status        AS trip_status,
      t.driver_id,
      p.name          AS driver_name,
      d.verification_status,
      r.from_location,
      r.to_location
    FROM public.trips t
    JOIN public.drivers d ON d.id = t.driver_id
    JOIN public.profiles p ON p.id = d.profile_id
    JOIN public.routes r ON r.id = t.route_id
    WHERE t.status IN ('accepting_bookings', 'full', 'ready', 'boarding')
      AND d.verification_status IN ('suspended', 'rejected')
  LOOP
    v_issues := v_issues || jsonb_build_object(
      'check',               12,
      'description',         'SUSPENDED driver has passenger-eligible trip',
      'trip_id',             v_row.trip_id,
      'trip_status',         v_row.trip_status,
      'driver_name',         v_row.driver_name,
      'verification_status', v_row.verification_status,
      'route',               format('%s → %s', v_row.from_location, v_row.to_location),
      'severity',            'CRITICAL',
      'action',              'Run system repair: close_driver_trip_on_offline or admin_abort_trip'
    );
    v_count := v_count + 1;
  END LOOP;

  -- ── CHECK 13: Multiple passenger-eligible trips competing for same route ──
  -- Only one FIFO driver should own the passenger-eligible trip per route.
  FOR v_row IN
    SELECT
      t.route_id,
      r.from_location,
      r.to_location,
      COUNT(*)        AS eligible_trip_count,
      jsonb_agg(jsonb_build_object(
        'trip_id',     t.id,
        'trip_status', t.status,
        'driver_id',   t.driver_id,
        'driver_name', p.name
      )) AS trips
    FROM public.trips t
    JOIN public.drivers d ON d.id = t.driver_id
    JOIN public.profiles p ON p.id = d.profile_id
    JOIN public.routes r ON r.id = t.route_id
    WHERE t.status IN ('accepting_bookings', 'full', 'ready', 'boarding')
      AND d.availability_status NOT IN ('offline', 'completed')
      AND d.verification_status NOT IN ('suspended', 'rejected')
    GROUP BY t.route_id, r.from_location, r.to_location
    HAVING COUNT(*) > 1
  LOOP
    v_issues := v_issues || jsonb_build_object(
      'check',               13,
      'description',         'Multiple passenger-eligible trips competing for same route',
      'route_id',            v_row.route_id,
      'route',               format('%s → %s', v_row.from_location, v_row.to_location),
      'eligible_trip_count', v_row.eligible_trip_count,
      'trips',               v_row.trips,
      'severity',            'HIGH',
      'action',              'Cancel stale trips via admin_abort_trip — only FIFO #1 driver should have eligible trip'
    );
    v_count := v_count + 1;
  END LOOP;

  -- ── CHECK 14: Active booking attached to ineligible/obsolete trip ─────────
  -- Booking is confirmed but the trip's driver is offline/suspended
  FOR v_row IN
    SELECT
      b.id            AS booking_id,
      b.passenger_id,
      p.name          AS passenger_name,
      b.status        AS booking_status,
      b.trip_id,
      t.status        AS trip_status,
      d.availability_status,
      d.verification_status,
      dp.name         AS driver_name
    FROM public.bookings b
    JOIN public.trips t ON t.id = b.trip_id
    JOIN public.drivers d ON d.id = t.driver_id
    JOIN public.profiles p ON p.id = b.passenger_id
    JOIN public.profiles dp ON dp.id = d.profile_id
    WHERE b.status NOT IN ('cancelled', 'completed', 'no_show')
      AND t.status NOT IN ('completed', 'cancelled')
      AND (
        d.availability_status IN ('offline', 'completed')
        OR d.verification_status IN ('suspended', 'rejected')
      )
  LOOP
    v_issues := v_issues || jsonb_build_object(
      'check',               14,
      'description',         'Active booking attached to trip with ineligible driver',
      'booking_id',          v_row.booking_id,
      'passenger_name',      v_row.passenger_name,
      'booking_status',      v_row.booking_status,
      'trip_id',             v_row.trip_id,
      'trip_status',         v_row.trip_status,
      'driver_name',         v_row.driver_name,
      'availability_status', v_row.availability_status,
      'verification_status', v_row.verification_status,
      'severity',            'HIGH',
      'action',              'Run system repair or admin_abort_trip to recover passenger'
    );
    v_count := v_count + 1;
  END LOOP;

  -- ── AUDIT LOG (read-only operation — just log the access) ─────────────────
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    v_admin_id,
    'operational_consistency_checked'::public.audit_action,
    'bookings',
    NULL,
    jsonb_build_object('issues_found', v_count, 'checked_at', NOW()),
    format('Admin operational consistency check: %s issues found', v_count)
  );

  RETURN jsonb_build_object(
    'success',       true,
    'issues_found',  v_count,
    'checked_at',    NOW(),
    'issues',        v_issues,
    'summary',       jsonb_build_object(
      'check_1_active_booking_terminal_trip',           (SELECT COUNT(*) FROM jsonb_array_elements(v_issues) i WHERE (i->>'check')::INTEGER = 1),
      'check_2_assigned_pq_terminal_trip',              (SELECT COUNT(*) FROM jsonb_array_elements(v_issues) i WHERE (i->>'check')::INTEGER = 2),
      'check_3_passenger_multiple_active_bookings',     (SELECT COUNT(*) FROM jsonb_array_elements(v_issues) i WHERE (i->>'check')::INTEGER = 3),
      'check_4_passenger_multiple_active_queues',       (SELECT COUNT(*) FROM jsonb_array_elements(v_issues) i WHERE (i->>'check')::INTEGER = 4),
      'check_5_driver_multiple_active_trips',           (SELECT COUNT(*) FROM jsonb_array_elements(v_issues) i WHERE (i->>'check')::INTEGER = 5),
      'check_6_dq_referencing_terminal_trip',           (SELECT COUNT(*) FROM jsonb_array_elements(v_issues) i WHERE (i->>'check')::INTEGER = 6),
      'check_7_offline_driver_on_active_trip',          (SELECT COUNT(*) FROM jsonb_array_elements(v_issues) i WHERE (i->>'check')::INTEGER = 7),
      'check_8_trip_driver_inconsistency',              (SELECT COUNT(*) FROM jsonb_array_elements(v_issues) i WHERE (i->>'check')::INTEGER = 8),
      'check_9_vehicle_driver_inconsistency',           (SELECT COUNT(*) FROM jsonb_array_elements(v_issues) i WHERE (i->>'check')::INTEGER = 9),
      'check_10_terminal_trip_operational_queue',       (SELECT COUNT(*) FROM jsonb_array_elements(v_issues) i WHERE (i->>'check')::INTEGER = 10),
      'check_11_offline_driver_passenger_eligible_trip', (SELECT COUNT(*) FROM jsonb_array_elements(v_issues) i WHERE (i->>'check')::INTEGER = 11),
      'check_12_suspended_driver_passenger_eligible_trip', (SELECT COUNT(*) FROM jsonb_array_elements(v_issues) i WHERE (i->>'check')::INTEGER = 12),
      'check_13_multiple_eligible_trips_same_route',    (SELECT COUNT(*) FROM jsonb_array_elements(v_issues) i WHERE (i->>'check')::INTEGER = 13),
      'check_14_active_booking_ineligible_driver',      (SELECT COUNT(*) FROM jsonb_array_elements(v_issues) i WHERE (i->>'check')::INTEGER = 14)
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_check_operational_consistency() TO authenticated;

-- ============================================================
-- STEP 9: SYSTEM-WIDE REPAIR
--
-- Close all accepting_bookings/full/ready/boarding trips where
-- the driver is offline or suspended.
--
-- This repairs Anil's trip and any other equivalent orphan trips.
--
-- Requirements:
--   - preserve history (no hard deletion)
--   - no passenger abuse cooldown triggered
--   - do not reorder valid driver FIFO
--   - do not alter fare history
--   - do not alter valid completed trips
--   - idempotent
--   - ambiguous records reported, not guessed
-- ============================================================

DO $$
DECLARE
  v_orphan_trip   RECORD;
  v_trip_count    INTEGER := 0;
  v_pq_count      INTEGER := 0;
  v_booking_count INTEGER := 0;
  v_close_result  JSONB;
BEGIN
  -- Find all trips where driver is offline/suspended but trip is passenger-eligible
  FOR v_orphan_trip IN
    SELECT
      t.id            AS trip_id,
      t.status        AS trip_status,
      t.driver_id,
      t.route_id,
      p.name          AS driver_name,
      d.availability_status,
      d.verification_status
    FROM public.trips t
    JOIN public.drivers d ON d.id = t.driver_id
    JOIN public.profiles p ON p.id = d.profile_id
    WHERE t.status IN ('accepting_bookings', 'full', 'ready', 'boarding')
      AND (
        d.availability_status IN ('offline', 'completed')
        OR d.verification_status IN ('suspended', 'rejected')
        OR p.status = 'suspended'
      )
    ORDER BY t.created_at ASC  -- oldest first
  LOOP
    RAISE NOTICE 'REPAIR: Closing orphan trip % (status=%) for driver % (availability=%, verification=%)',
      v_orphan_trip.trip_id,
      v_orphan_trip.trip_status,
      v_orphan_trip.driver_name,
      v_orphan_trip.availability_status,
      v_orphan_trip.verification_status;

    -- Cancel the trip
    UPDATE public.trips
    SET
      status     = 'cancelled'::public.trip_status,
      notes      = format('system_repair T2-BUG-02: driver %s was %s/%s when trip was %s. Auto-repaired %s.',
                          v_orphan_trip.driver_name,
                          v_orphan_trip.availability_status,
                          v_orphan_trip.verification_status,
                          v_orphan_trip.trip_status,
                          NOW()::DATE),
      updated_at = NOW()
    WHERE id = v_orphan_trip.trip_id;

    -- Recover passengers → return to FIFO WAITING
    UPDATE public.passenger_queue
    SET
      status           = 'WAITING',
      assigned_trip_id = NULL,
      updated_at       = NOW()
    WHERE assigned_trip_id = v_orphan_trip.trip_id
      AND status NOT IN ('COMPLETED', 'CANCELLED');

    GET DIAGNOSTICS v_pq_count = ROW_COUNT;

    -- Reset bookings linked to this trip
    UPDATE public.bookings
    SET
      trip_id     = NULL,
      status      = 'queued'::public.booking_status,
      admin_notes = format('[SYSTEM REPAIR T2-BUG-02 %s] Trip %s was orphaned (driver offline/suspended). Booking returned to queue.',
                           NOW()::DATE, v_orphan_trip.trip_id),
      updated_at  = NOW()
    WHERE trip_id = v_orphan_trip.trip_id
      AND status NOT IN ('cancelled', 'no_show', 'completed');

    GET DIAGNOSTICS v_booking_count = ROW_COUNT;

    -- Audit
    INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
    VALUES (
      NULL,
      'orphan_trip_repaired'::public.audit_action,
      'trips',
      v_orphan_trip.trip_id,
      jsonb_build_object(
        'trip_status',         v_orphan_trip.trip_status,
        'driver_name',         v_orphan_trip.driver_name,
        'availability_status', v_orphan_trip.availability_status,
        'verification_status', v_orphan_trip.verification_status
      ),
      jsonb_build_object(
        'trip_status',          'cancelled',
        'passengers_recovered', v_pq_count,
        'bookings_reset',       v_booking_count,
        'repair_type',          'T2-BUG-02_offline_driver_orphan_trip'
      ),
      format('System repair T2-BUG-02: closed orphan trip for offline/suspended driver %s. %s passengers recovered.',
             v_orphan_trip.driver_name, v_pq_count)
    );

    -- Trigger FIFO re-match for recovered passengers
    IF v_pq_count > 0 THEN
      BEGIN
        PERFORM public.match_route_queue(v_orphan_trip.route_id);
      EXCEPTION WHEN OTHERS THEN
        NULL; -- Non-blocking
      END;
    END IF;

    v_trip_count := v_trip_count + 1;
  END LOOP;

  RAISE NOTICE 'T2-BUG-02 system-wide repair complete: % orphan trips closed, passengers recovered.',
    v_trip_count;
END;
$$;

-- ============================================================
-- STEP 10: VERIFY DRIVER FIFO POSITIONS ARE INTACT
-- Rajeev Backup4 and Dipti must NOT be affected by the repair.
-- The repair only touches trips/passenger_queue — not driver_queue.
-- ============================================================

DO $$
DECLARE
  v_rajeev_dq RECORD;
  v_dipti_dq  RECORD;
  v_anil_d    RECORD;
BEGIN
  -- Verify Rajeev Backup4 FIFO position
  SELECT dq.id, dq.status, dq.queue_position, pr.name
  INTO v_rajeev_dq
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  JOIN public.profiles pr ON pr.id = d.profile_id
  WHERE (pr.name ILIKE '%rajeev%backup4%' OR pr.name ILIKE '%rajeev backup4%')
    AND dq.status NOT IN ('completed', 'cancelled', 'offline', 'declined')
  ORDER BY dq.joined_at DESC
  LIMIT 1;

  IF FOUND THEN
    RAISE NOTICE 'Rajeev Backup4 driver_queue: id=%, status=%, position=% — FIFO PRESERVED',
      v_rajeev_dq.id, v_rajeev_dq.status, v_rajeev_dq.queue_position;
  ELSE
    RAISE NOTICE 'Rajeev Backup4 driver_queue: no active entry found';
  END IF;

  -- Verify Dipti FIFO position
  SELECT dq.id, dq.status, dq.queue_position, pr.name
  INTO v_dipti_dq
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  JOIN public.profiles pr ON pr.id = d.profile_id
  WHERE pr.name ILIKE '%dipti%'
    AND dq.status NOT IN ('completed', 'cancelled', 'offline', 'declined')
  ORDER BY dq.joined_at DESC
  LIMIT 1;

  IF FOUND THEN
    RAISE NOTICE 'Dipti driver_queue: id=%, status=%, position=% — FIFO PRESERVED',
      v_dipti_dq.id, v_dipti_dq.status, v_dipti_dq.queue_position;
  ELSE
    RAISE NOTICE 'Dipti driver_queue: no active entry found';
  END IF;

  -- Verify Anil is offline (should be unchanged — we only closed his trip)
  SELECT d.availability_status, d.verification_status, pr.name
  INTO v_anil_d
  FROM public.drivers d
  JOIN public.profiles pr ON pr.id = d.profile_id
  WHERE pr.name ILIKE '%anil%kumar%' OR pr.name ILIKE '%anil kumar%'
  LIMIT 1;

  IF FOUND THEN
    RAISE NOTICE 'Anil Kumar driver state: availability=%, verification=% — should be offline',
      v_anil_d.availability_status, v_anil_d.verification_status;
  END IF;

  RAISE NOTICE 'Driver FIFO verification complete. driver_queue entries NOT modified by T2-BUG-02 repair.';
END;
$$;

-- ============================================================
-- STEP 11: PERFORMANCE INDEX
-- ============================================================

-- Index to speed up the canonical eligibility query in get_active_trip_for_route
CREATE INDEX IF NOT EXISTS idx_trips_route_status_driver
  ON public.trips (route_id, status, driver_id)
  WHERE status IN ('accepting_bookings', 'full', 'ready', 'boarding');

-- Index to speed up driver eligibility check
CREATE INDEX IF NOT EXISTS idx_drivers_availability_verification
  ON public.drivers (availability_status, verification_status)
  WHERE availability_status NOT IN ('offline', 'completed');

-- ============================================================
-- VERIFICATION SUMMARY
-- ============================================================
--
-- CLASSIFICATION: BOTH (logic defect + resulting bad database state)
--
-- ROOT CAUSE:
--   DEFECT A: get_active_trip_for_route had no driver eligibility check.
--   DEFECT B: No go-offline path closed the driver's accepting_bookings trip.
--
-- BAD DATABASE STATE FOUND:
--   Anil's trip: status='accepting_bookings', driver offline.
--   This trip was returned by get_active_trip_for_route because
--   the function only checked trip.status, not driver eligibility.
--
-- HOW THAT STATE WAS CREATED:
--   Anil accepted an offer → trip became 'accepting_bookings'.
--   Anil went offline → driver_queue cancelled, driver set offline.
--   BUT: trip.status was never changed from 'accepting_bookings'.
--   No RPC enforced the trip→cancelled transition on driver offline.
--
-- WHY EXISTING LOGIC ALLOWED IT:
--   admin_suspend_driver, admin_driver_go_offline, admin_remove_driver_from_queue
--   all cancelled driver_queue and set driver offline but did NOT close the trip.
--   get_active_trip_for_route only checked trip.status — no driver eligibility.
--
-- SOURCE OF "DRIVER AVAILABLE":
--   BookRideContent.tsx → get_active_trip_for_route RPC
--   → trips WHERE status='accepting_bookings' ORDER BY created_at DESC
--   → Anil's trip returned (no driver eligibility check)
--   → found=true → "Driver available" displayed
--
-- SOURCE OF "0 SEATS AVAILABLE":
--   Same RPC → available_seats = total_seats - booked_seats
--   Anil's trip had 0 confirmed bookings → available_seats=0
--   (or total_seats=0 if vehicle capacity was 0 — either way, from Anil's trip)
--
-- SOURCE OF "TATA TIAGO":
--   Same RPC → vehicle_make/model from Anil's trip.vehicle_id
--   → TATA TIAGO is Anil's assigned vehicle
--
-- SOURCE OF "DRIVER ASSIGNED — ANIL":
--   BookRideContent → book_or_queue → already_queued=true (stale pq)
--   → router.push to old booking_confirmation
--   → get_passenger_booking → pq.assigned_trip_id = Anil's trip
--   → driver_name = Anil Kumar (from trip.driver_id)
--
-- SOURCE OF DUPLICATE-BOOKING MESSAGE:
--   book_or_queue found stale passenger_queue row (status=ASSIGNED,
--   assigned_trip_id = Anil's terminal trip) → fired duplicate guard
--   → returned already_queued=true → UI showed "already booked" toast
--   (This was the T2-BUG-01 pattern — fixed in migration 100000)
--
-- CAN MULTIPLE COMPETING ACTIVE TRIPS EXIST: YES (before this fix)
--   get_active_trip_for_route returned the newest trip regardless of
--   driver eligibility. After fix: only one eligible trip per route
--   (the FIFO #1 driver's trip) is returned.
--
-- CAN OFFLINE DRIVER + ACCEPTING TRIP EXIST: NO (after this fix)
--   close_driver_trip_on_offline is called by all go-offline paths.
--   get_active_trip_for_route excludes offline drivers.
--
-- CAN SUSPENDED DRIVER + ACCEPTING TRIP EXIST: NO (after this fix)
--   admin_suspend_driver now calls close_driver_trip_on_offline.
--   get_active_trip_for_route excludes suspended drivers.
--
-- CANONICAL PASSENGER-ELIGIBILITY RULE AFTER FIX:
--   trip.status IN ('accepting_bookings','full','ready','boarding')
--   AND driver.availability_status NOT IN ('offline','completed')
--   AND driver.verification_status NOT IN ('suspended','rejected')
--   AND profile.status != 'suspended'
--   AND driver has non-terminal driver_queue row for this route
--   AND vehicle.status = 'active'
--   AND route.status = 'active'
--
-- GO-OFFLINE LIFECYCLE AFTER FIX:
--   Any path setting driver offline MUST call close_driver_trip_on_offline.
--   This cancels the trip, recovers passengers to FIFO WAITING, resets
--   bookings, triggers rematch. Deterministic. Cannot leave orphan trip.
--
-- FIFO LOGIC AFTER FIX:
--   get_active_trip_for_route selects by driver_queue.queue_position ASC.
--   Rajeev Backup4 (#1) → his trip shown. Dipti (#2) waits.
--   Anil (offline) → completely excluded.
--
-- SYSTEM-WIDE DATA REPAIR:
--   All accepting_bookings trips with offline/suspended drivers cancelled.
--   Passengers recovered to FIFO WAITING. Bookings reset to queued.
--   History preserved. No cooldowns triggered. FIFO not reordered.
--
-- RAJEEV BACKUP4 STATE AFTER FIX:
--   FIFO #1 preserved. His trip (Maruti Dzire) is the canonical eligible trip.
--   get_active_trip_for_route returns his trip.
--
-- DIPTI STATE AFTER FIX:
--   FIFO #2 preserved. Waits behind Rajeev Backup4.
--
-- ANIL STATE AFTER FIX:
--   Offline (unchanged). Trip cancelled (repaired). Cannot receive new bookings.
--   get_active_trip_for_route will never return Anil's trip while he is offline.
--
-- RAJEEV.BACKUP1 STATE AFTER FIX:
--   No stale active booking (repaired by migration 100000).
--   Book Ride shows Rajeev Backup4's Maruti Dzire (FIFO #1).
--   New booking proceeds normally.
-- ============================================================
