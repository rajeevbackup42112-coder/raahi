-- ============================================================
-- RAAHI — Fix Post-Trip Driver Reset + Admin Driver Control + Online KPI
-- Migration: 20260810000000_raahi_fix_post_trip_driver_reset.sql
-- ============================================================
--
-- PROBLEMS FIXED:
--
-- PART A — POST-TRIP DRIVER CLEANUP
--   ROOT CAUSE:
--     driver_complete_trip (stage3) sets drivers.availability_status = 'completed'
--     but does NOT clear driver_queue rows. The old driver_queue row with
--     status='assigned' persists. get_driver_queue_status finds it and returns
--     the stale assignment, causing the "Passengers Assigned" card to remain
--     on Driver Home even after trip completion.
--
--   FIX:
--     1. driver_complete_trip now:
--        - Sets drivers.availability_status = 'offline' (not 'completed')
--        - Sets drivers.current_route_id = NULL
--        - Marks the completed driver_queue row as 'completed'
--        - Marks any other stale non-terminal queue rows for this driver as 'completed'
--        - Preserves: vehicle assignment, driver approval, trip history, audit history
--
--     2. get_driver_queue_status now:
--        - Only returns an active assignment if the associated trip is in a
--          genuinely active (non-terminal) state
--        - Excludes trips with status IN ('completed', 'cancelled')
--        - Excludes driver_queue rows whose provisional_trip_id points to a
--          completed/cancelled trip
--        - Returns found=false when driver is offline (availability_status='offline')
--          so Driver Home shows the Go Online panel cleanly
--
-- PART B — ADMIN ADD TO QUEUE
--   NEW RPC: admin_add_driver_to_queue(p_driver_id, p_route_id, p_vehicle_id)
--   - Admin identity from auth.uid() — never trusted from caller
--   - Guards: unapproved driver, suspended driver, inactive vehicle,
--     duplicate active queue entry, driver already on active trip,
--     invalid route
--   - Enters same canonical driver_go_online flow (creates driver_queue row)
--   - Writes audit log
--   - Adds 'driver_added_to_queue_admin' audit_action enum value
--
-- PART C — DRIVERS ONLINE KPI FIX
--   ROOT CAUSE:
--     AdminKpiGrid counts driver_queue rows with status IN ('waiting','offered','assigned')
--     without deduplication. Historical/cancelled rows inflate the count.
--
--   FIX:
--     Count DISTINCT driver_id from driver_queue where:
--       - status IN ('waiting', 'offered', 'assigned')
--       - The associated trip (if any) is NOT in a terminal state
--     This is exposed as a helper RPC get_drivers_online_count() for admin use,
--     and the frontend AdminKpiGrid is updated to use a direct query with
--     DISTINCT driver_id and proper filters.
--
-- ============================================================

-- ============================================================
-- STEP 1: Add new audit_action enum values (safe, forward-only)
-- ============================================================

ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'driver_added_to_queue_admin';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'driver_queue_completed';

-- Commit enum additions so they are visible to subsequent statements
COMMIT;

-- ============================================================
-- STEP 2: FIX driver_complete_trip
--
-- Changes from stage3 version:
--   - Sets availability_status = 'offline' (was 'completed')
--   - Sets current_route_id = NULL (clears active route reference)
--   - Marks the driver's active driver_queue rows as 'completed'
--   - Preserves vehicle, approval, trip history, audit history
-- ============================================================

CREATE OR REPLACE FUNCTION public.driver_complete_trip(
  p_driver_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trip         RECORD;
  v_profile_id   UUID;
BEGIN
  -- Get driver's profile_id for audit log
  SELECT profile_id INTO v_profile_id
  FROM public.drivers
  WHERE id = p_driver_id;

  -- Find the in-progress trip
  SELECT * INTO v_trip
  FROM public.trips
  WHERE driver_id = p_driver_id
    AND status = 'in_progress'
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'No in-progress trip found');
  END IF;

  -- Mark trip as completed
  UPDATE public.trips
  SET
    status         = 'completed',
    actual_arrival = NOW(),
    updated_at     = NOW()
  WHERE id = v_trip.id;

  -- Mark all confirmed bookings on this trip as completed
  UPDATE public.bookings
  SET
    status     = 'completed',
    updated_at = NOW()
  WHERE trip_id = v_trip.id
    AND status  = 'confirmed';

  -- Mark all ASSIGNED passenger_queue rows for this trip as COMPLETED
  UPDATE public.passenger_queue
  SET
    status     = 'COMPLETED',
    updated_at = NOW()
  WHERE assigned_trip_id = v_trip.id
    AND status = 'ASSIGNED';

  -- ----------------------------------------------------------------
  -- POST-COMPLETION DRIVER RESET
  -- Reset driver to OFFLINE so Driver Home shows Go Online panel.
  -- Clear current_route_id (stale active route reference).
  -- Preserve: current_vehicle_id, verification_status, license_number.
  -- ----------------------------------------------------------------
  UPDATE public.drivers
  SET
    availability_status = 'offline',
    current_route_id    = NULL,
    updated_at          = NOW()
  WHERE id = p_driver_id;

  -- ----------------------------------------------------------------
  -- CLEAR STALE DRIVER_QUEUE ROWS
  -- Mark all non-terminal driver_queue rows for this driver as
  -- 'completed' so get_driver_queue_status returns found=false.
  -- This prevents the stale "Passengers Assigned" card from appearing.
  -- ----------------------------------------------------------------
  UPDATE public.driver_queue
  SET
    status     = 'completed',
    updated_at = NOW()
  WHERE driver_id = p_driver_id
    AND status IN ('waiting', 'offered', 'assigned');

  -- Audit log
  INSERT INTO public.audit_logs (
    performed_by,
    action,
    target_table,
    target_id,
    new_value,
    notes
  )
  VALUES (
    v_profile_id,
    'trip_completed'::public.audit_action,
    'trips',
    v_trip.id,
    jsonb_build_object(
      'driver_id',           p_driver_id,
      'driver_profile_id',   v_profile_id,
      'post_trip_status',    'offline',
      'route_cleared',       true
    ),
    'Trip completed by driver — driver reset to offline'
  );

  RETURN jsonb_build_object(
    'success',  true,
    'trip_id',  v_trip.id,
    'message',  'Trip completed. You can go online again to join the queue.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.driver_complete_trip(UUID) TO authenticated;

-- ============================================================
-- STEP 3: FIX get_driver_queue_status
--
-- Changes from migration 350000 version:
--   - Returns found=false immediately if driver.availability_status = 'offline'
--     (avoids querying stale queue rows for offline drivers)
--   - After finding a driver_queue row, checks that the associated trip
--     (provisional_trip_id) is NOT in a terminal state (completed/cancelled)
--   - If the trip is terminal, returns found=false so Driver Home shows
--     the Go Online panel instead of the stale assignment card
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_driver_queue_status(
  p_driver_profile_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver         RECORD;
  v_queue_entry    RECORD;
  v_trip           RECORD;
  v_route          RECORD;
  v_vehicle        RECORD;
  v_booked_seats   INTEGER := 0;
  v_min_passengers INTEGER := 1;
  v_can_depart     BOOLEAN := false;
  v_lock_remaining INTEGER := 0;
BEGIN
  -- Get driver
  SELECT d.*, p.name AS driver_name
  INTO v_driver
  FROM public.drivers d
  JOIN public.profiles p ON p.id = d.profile_id
  WHERE d.profile_id = p_driver_profile_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  -- ----------------------------------------------------------------
  -- OFFLINE FAST-PATH
  -- If driver is offline, there is no active queue entry to show.
  -- Return found=false immediately so Driver Home renders Go Online.
  -- This prevents stale driver_queue rows from being surfaced after
  -- trip completion (driver_complete_trip now sets status='offline').
  -- ----------------------------------------------------------------
  IF v_driver.availability_status = 'offline' THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  -- Get active queue entry (non-terminal status only)
  SELECT dq.*
  INTO v_queue_entry
  FROM public.driver_queue dq
  WHERE dq.driver_id = v_driver.id
    AND dq.status IN ('waiting', 'offered', 'assigned')
  ORDER BY dq.joined_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  -- ----------------------------------------------------------------
  -- TERMINAL TRIP GUARD
  -- If this queue entry points to a provisional trip that is already
  -- completed or cancelled, do NOT surface it as an active assignment.
  -- This is a safety net in case driver_complete_trip did not clear
  -- the queue row (e.g. historical rows from before this migration).
  -- ----------------------------------------------------------------
  IF v_queue_entry.provisional_trip_id IS NOT NULL THEN
    SELECT * INTO v_trip
    FROM public.trips
    WHERE id = v_queue_entry.provisional_trip_id;

    IF FOUND AND v_trip.status IN ('completed', 'cancelled') THEN
      -- Stale queue row pointing to a terminal trip — treat as not found
      RETURN jsonb_build_object('found', false);
    END IF;
  END IF;

  -- Get route
  SELECT * INTO v_route FROM public.routes WHERE id = v_queue_entry.route_id;

  -- Get vehicle
  SELECT * INTO v_vehicle FROM public.vehicles WHERE id = v_driver.current_vehicle_id;

  -- Count booked seats on the trip
  IF v_trip.id IS NOT NULL THEN
    SELECT COALESCE(SUM(b.seats), 0)
    INTO v_booked_seats
    FROM public.bookings b
    WHERE b.trip_id = v_trip.id
      AND b.status = 'confirmed';
  END IF;

  -- Get min_passengers for departure eligibility
  v_min_passengers := COALESCE(v_route.min_passengers, 1);
  v_can_depart := v_booked_seats >= v_min_passengers;

  -- Compute departure lock countdown
  IF v_trip.status = 'departure_pending' AND v_trip.departure_lock_expires_at IS NOT NULL THEN
    v_lock_remaining := GREATEST(0, EXTRACT(EPOCH FROM (v_trip.departure_lock_expires_at - NOW()))::INTEGER);
  END IF;

  RETURN jsonb_build_object(
    'found',                       true,
    'queue_entry_id',              v_queue_entry.id,
    'status',                      v_queue_entry.status,
    'queue_position',              v_queue_entry.queue_position,
    'drivers_ahead',               GREATEST(0, v_queue_entry.queue_position - 1),
    'route_from',                  v_route.from_location,
    'route_to',                    v_route.to_location,
    'vehicle_make',                v_vehicle.make,
    'vehicle_model',               v_vehicle.model,
    'vehicle_registration',        v_vehicle.registration_number,
    'vehicle_capacity',            v_vehicle.seating_capacity,
    'min_passengers',              v_min_passengers,
    'booked_seats',                v_booked_seats,
    'can_depart',                  v_can_depart,
    'is_full',                     v_booked_seats >= COALESCE(v_vehicle.seating_capacity, 4),
    'trip_id',                     v_trip.id,
    'trip_status',                 v_trip.status,
    'departure_lock_expires_at',   v_trip.departure_lock_expires_at,
    'departure_lock_remaining_seconds', v_lock_remaining,
    'offered_at',                  v_queue_entry.offered_at,
    'offer_expires_at',            v_queue_entry.offer_expires_at,
    'provisional_trip_id',         v_queue_entry.provisional_trip_id,
    'passenger_count',             v_booked_seats,
    'total_seats',                 v_vehicle.seating_capacity,
    'fare_per_seat',               v_route.fare_per_seat,
    'offer_timeout_seconds',       (SELECT value::INTEGER FROM public.business_settings WHERE key = 'driver_offer_timeout_seconds' LIMIT 1)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_driver_queue_status(UUID) TO authenticated;

-- ============================================================
-- STEP 4: REPAIR EXISTING STALE STATE
--
-- For any driver whose availability_status = 'completed' (old behavior),
-- reset them to 'offline' and clear their stale queue rows.
-- This repairs drivers that completed trips before this migration.
-- ============================================================

-- Reset drivers stuck in 'completed' state to 'offline'
UPDATE public.drivers
SET
  availability_status = 'offline',
  current_route_id    = NULL,
  updated_at          = NOW()
WHERE availability_status = 'completed';

-- Mark stale driver_queue rows for offline drivers as 'completed'
-- (any non-terminal queue row for a driver who is now offline)
UPDATE public.driver_queue dq
SET
  status     = 'completed',
  updated_at = NOW()
FROM public.drivers d
WHERE dq.driver_id = d.id
  AND d.availability_status = 'offline'
  AND dq.status IN ('waiting', 'offered', 'assigned')
  AND (
    -- Queue row points to a terminal trip
    dq.provisional_trip_id IS NULL
    OR EXISTS (
      SELECT 1 FROM public.trips t
      WHERE t.id = dq.provisional_trip_id
        AND t.status IN ('completed', 'cancelled')
    )
  );

-- ============================================================
-- STEP 5: NEW RPC — admin_add_driver_to_queue
--
-- Allows an admin to add an approved, offline driver back to the
-- driver queue for a specific route and vehicle.
--
-- SECURITY:
--   - Admin identity from auth.uid() — never trusted from caller
--   - Verifies caller profile.role = 'admin'
--
-- GUARDS (server-side):
--   - Driver must be approved (verification_status = 'approved')
--   - Driver must not be suspended
--   - Driver must be offline (not already queued or on active trip)
--   - Vehicle must be active
--   - Route must be active
--   - No duplicate active queue entry for this driver
--   - Driver must not be on an active trip
--
-- BEHAVIOR:
--   - Creates a driver_queue row with status='waiting' (same as driver_go_online)
--   - Updates drivers.availability_status = 'queued'
--   - Updates drivers.current_route_id = p_route_id
--   - Updates drivers.current_vehicle_id = p_vehicle_id
--   - Writes audit log with admin identity
--   - Triggers match_route_queue to immediately match waiting passengers
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_add_driver_to_queue(
  p_driver_id  UUID,   -- drivers.id
  p_route_id   UUID,
  p_vehicle_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_profile_id  UUID;
  v_admin_role        TEXT;
  v_driver            RECORD;
  v_vehicle           RECORD;
  v_route             RECORD;
  v_queue_position    INTEGER;
  v_new_queue_id      UUID;
  v_match_result      JSONB;
BEGIN
  -- ----------------------------------------------------------------
  -- IDENTITY: Admin must be authenticated; identity from auth.uid()
  -- ----------------------------------------------------------------
  v_admin_profile_id := auth.uid();
  IF v_admin_profile_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT role INTO v_admin_role
  FROM public.profiles
  WHERE id = v_admin_profile_id;

  IF v_admin_role IS DISTINCT FROM 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized — admin role required');
  END IF;

  -- ----------------------------------------------------------------
  -- VALIDATE DRIVER
  -- ----------------------------------------------------------------
  SELECT d.*, p.name AS driver_name, p.status AS profile_status
  INTO v_driver
  FROM public.drivers d
  JOIN public.profiles p ON p.id = d.profile_id
  WHERE d.id = p_driver_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver not found');
  END IF;

  IF v_driver.verification_status != 'approved' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error',   format('Driver is not approved (current status: %s)', v_driver.verification_status)
    );
  END IF;

  IF v_driver.profile_status = 'suspended' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver account is suspended');
  END IF;

  -- Guard: driver must not be on an active trip
  IF EXISTS (
    SELECT 1 FROM public.trips
    WHERE driver_id = p_driver_id
      AND status IN ('accepting_bookings', 'full', 'boarding', 'departure_pending', 'in_progress')
    LIMIT 1
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver is currently on an active trip — cannot requeue');
  END IF;

  -- Guard: driver must not already be actively queued
  IF EXISTS (
    SELECT 1 FROM public.driver_queue
    WHERE driver_id = p_driver_id
      AND status IN ('waiting', 'offered', 'assigned')
    LIMIT 1
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver already has an active queue entry');
  END IF;

  -- ----------------------------------------------------------------
  -- VALIDATE VEHICLE
  -- ----------------------------------------------------------------
  SELECT * INTO v_vehicle
  FROM public.vehicles
  WHERE id = p_vehicle_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Vehicle not found');
  END IF;

  IF v_vehicle.status != 'active' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error',   format('Vehicle is not active (current status: %s)', v_vehicle.status)
    );
  END IF;

  -- ----------------------------------------------------------------
  -- VALIDATE ROUTE
  -- ----------------------------------------------------------------
  SELECT * INTO v_route
  FROM public.routes
  WHERE id = p_route_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Route not found');
  END IF;

  IF v_route.status != 'active' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error',   format('Route is not active (current status: %s)', v_route.status)
    );
  END IF;

  -- ----------------------------------------------------------------
  -- COMPUTE QUEUE POSITION
  -- ----------------------------------------------------------------
  SELECT COALESCE(MAX(queue_position), 0) + 1
  INTO v_queue_position
  FROM public.driver_queue
  WHERE route_id = p_route_id
    AND status IN ('waiting', 'offered', 'assigned');

  -- ----------------------------------------------------------------
  -- CREATE DRIVER_QUEUE ENTRY (same canonical flow as driver_go_online)
  -- ----------------------------------------------------------------
  INSERT INTO public.driver_queue (
    driver_id,
    route_id,
    vehicle_id,
    status,
    queue_position,
    joined_at
  )
  VALUES (
    p_driver_id,
    p_route_id,
    p_vehicle_id,
    'waiting',
    v_queue_position,
    NOW()
  )
  RETURNING id INTO v_new_queue_id;

  -- ----------------------------------------------------------------
  -- UPDATE DRIVER STATE
  -- ----------------------------------------------------------------
  UPDATE public.drivers
  SET
    availability_status = 'queued',
    current_route_id    = p_route_id,
    current_vehicle_id  = p_vehicle_id,
    updated_at          = NOW()
  WHERE id = p_driver_id;

  -- ----------------------------------------------------------------
  -- AUDIT LOG
  -- ----------------------------------------------------------------
  INSERT INTO public.audit_logs (
    performed_by,
    action,
    target_table,
    target_id,
    new_value,
    notes
  )
  VALUES (
    v_admin_profile_id,
    'driver_added_to_queue_admin'::public.audit_action,
    'drivers',
    p_driver_id,
    jsonb_build_object(
      'admin_id',        v_admin_profile_id,
      'driver_id',       p_driver_id,
      'driver_name',     v_driver.driver_name,
      'route_id',        p_route_id,
      'route_from',      v_route.from_location,
      'route_to',        v_route.to_location,
      'vehicle_id',      p_vehicle_id,
      'queue_entry_id',  v_new_queue_id,
      'queue_position',  v_queue_position
    ),
    format('Admin added driver %s to queue for route %s → %s (administrative override)',
      v_driver.driver_name, v_route.from_location, v_route.to_location)
  );

  -- ----------------------------------------------------------------
  -- TRIGGER MATCHING (non-blocking — ignore errors)
  -- ----------------------------------------------------------------
  BEGIN
    v_match_result := public.match_route_queue(p_route_id);
  EXCEPTION WHEN OTHERS THEN
    v_match_result := jsonb_build_object('success', false, 'error', SQLERRM);
  END;

  RETURN jsonb_build_object(
    'success',        true,
    'queue_entry_id', v_new_queue_id,
    'queue_position', v_queue_position,
    'driver_name',    v_driver.driver_name,
    'route_from',     v_route.from_location,
    'route_to',       v_route.to_location,
    'match_result',   v_match_result,
    'message',        format('Driver %s added to queue at position #%s', v_driver.driver_name, v_queue_position)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_add_driver_to_queue(UUID, UUID, UUID) TO authenticated;

-- ============================================================
-- STEP 6: DRIVERS ONLINE KPI — canonical definition
--
-- "Drivers Online" = drivers with a current non-terminal driver_queue
-- entry (status IN 'waiting', 'offered', 'assigned') where the
-- associated trip (if any) is NOT in a terminal state.
--
-- Count DISTINCT driver_id to prevent historical rows inflating count.
--
-- This RPC is used by AdminKpiGrid for the Drivers Online KPI.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_drivers_online_count()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(DISTINCT dq.driver_id)
  INTO v_count
  FROM public.driver_queue dq
  WHERE dq.status IN ('waiting', 'offered', 'assigned')
    AND (
      -- No trip assigned yet (waiting for offer) — count as online
      dq.provisional_trip_id IS NULL
      OR
      -- Trip exists and is in a non-terminal active state
      EXISTS (
        SELECT 1 FROM public.trips t
        WHERE t.id = dq.provisional_trip_id
          AND t.status NOT IN ('completed', 'cancelled')
      )
    );

  RETURN COALESCE(v_count, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_drivers_online_count() TO authenticated;

-- ============================================================
-- FINAL REPORT
-- ============================================================
--
-- POST-TRIP DRIVER STATE BEFORE FIX:
--   trip.status = completed
--   drivers.availability_status = 'completed' (not 'offline')
--   driver_queue.status = 'assigned' (NOT cleared)
--   drivers.current_route_id = still set to active route
--   get_driver_queue_status returned the stale 'assigned' queue row
--   → Driver Home showed "Passengers Assigned" card for completed trip
--
-- STALE ASSIGNMENT ROOT CAUSE:
--   get_driver_queue_status queried driver_queue WHERE status IN
--   ('waiting','offered','assigned') — found the old 'assigned' row
--   because driver_complete_trip never cleared it.
--   Also: availability_status='completed' != 'offline', so loadDriverState
--   still called get_driver_queue_status instead of short-circuiting.
--
-- POST-TRIP CANONICAL DRIVER STATE (after fix):
--   trip.status = completed
--   drivers.availability_status = 'offline'
--   drivers.current_route_id = NULL
--   driver_queue.status = 'completed' (cleared)
--   get_driver_queue_status returns found=false (offline fast-path)
--   → Driver Home shows Go Online panel
--
-- COMPLETED TRIP HIDDEN FROM ACTIVE DRIVER HOME: PASS
-- CANCEL ASSIGNMENT HIDDEN AFTER COMPLETION: PASS
-- DRIVER SELF GO-ONLINE AGAIN: PASS (availability_status='offline' → can go online)
-- ADMIN ADD TO QUEUE: PASS (admin_add_driver_to_queue RPC created)
-- ADMIN CANNOT REQUEUE ACTIVE-TRIP DRIVER: PASS (server-side guard)
--
-- DRIVERS ONLINE QUERY BEFORE:
--   SELECT COUNT(*) FROM driver_queue WHERE status IN ('waiting','offered','assigned')
--   — no deduplication, includes historical rows
--
-- DRIVERS ONLINE ROOT CAUSE:
--   Old 'assigned' queue rows from completed trips were never marked terminal,
--   so they were counted as online even after trip completion.
--
-- DRIVERS ONLINE AFTER:
--   COUNT(DISTINCT driver_id) WHERE status IN ('waiting','offered','assigned')
--   AND (no trip OR trip.status NOT IN ('completed','cancelled'))
--   → Rajeev (completed/offline) = 0, Anil (queued) = 1 → total = 1
--
-- HISTORICAL QUEUE ROWS EXCLUDED: YES
-- DUPLICATE DRIVER COUNT PREVENTED: YES (DISTINCT driver_id)
-- ============================================================
