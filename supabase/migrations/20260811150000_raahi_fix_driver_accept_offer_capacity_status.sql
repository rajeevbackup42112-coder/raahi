-- ============================================================
-- RAAHI — Fix driver_accept_offer Capacity Status Bug
-- Migration: 20260811150000_raahi_fix_driver_accept_offer_capacity_status.sql
-- ============================================================
--
-- ROOT CAUSE:
--   Both driver_accept_offer overloads unconditionally set:
--     trip.status = 'accepting_bookings'::public.trip_status
--   on acceptance, regardless of whether booked_seats >= total_seats.
--
--   This means a provisional trip that was already FULL (booked_seats = 4,
--   total_seats = 4) gets reset to 'accepting_bookings' after the driver
--   accepts, creating a capacity/status mismatch.
--
--   CONFIRMED E2E EVIDENCE:
--     Trip d105a70e-8948-4192-b436-564e377ee8c0
--     BEFORE accept: status=full, booked_seats=4, total_seats=4,
--                    notes='provisional_offer'
--     AFTER accept:  status=accepting_bookings, booked_seats=4, total_seats=4
--                    notes=NULL
--     Expected:      status=full (because 4 >= 4)
--
-- OVERLOADS FOUND:
--   1. driver_accept_offer(p_driver_profile_id UUID, p_queue_entry_id UUID)
--      — last deployed in migration 20260810010000_raahi_fix_offer_expiry_flow.sql
--      — line: SET status = 'accepting_bookings'::public.trip_status
--
--   2. driver_accept_offer(p_queue_entry_id UUID)
--      — last deployed in migration 20260809120000_raahi_stage52b_validation.sql
--      — line: SET status = 'accepting_bookings'::public.trip_status, notes = NULL
--
-- FIX:
--   Replace the unconditional status assignment in BOTH overloads with:
--
--     status = CASE
--       WHEN booked_seats >= total_seats
--         THEN 'full'::public.trip_status
--       ELSE 'accepting_bookings'::public.trip_status
--     END
--
--   This derives the correct status from the canonical capacity invariant
--   rather than preserving v_trip.status (which was 'full' on the provisional
--   trip but could be stale in other scenarios).
--
--   notes = NULL is preserved — clearing 'provisional_offer' after successful
--   acceptance is correct and must continue.
--
-- AUDIT OF OTHER FUNCTIONS FOR THE SAME UNCONDITIONAL RESET:
--
--   match_route_queue (20260811140000):
--     Already uses the CASE expression correctly:
--       CASE WHEN booked_seats >= total_seats
--         THEN 'full'::public.trip_status
--         ELSE 'accepting_bookings'::public.trip_status END
--     NOT affected.
--
--   driver_decline_offer:
--     Calls release_provisional_trip → cancels trip. Does NOT set
--     'accepting_bookings'. NOT affected.
--
--   expire_driver_offer:
--     Calls release_provisional_trip → cancels trip. Does NOT set
--     'accepting_bookings'. NOT affected.
--
--   release_provisional_trip:
--     Sets status = 'cancelled'. Does NOT set 'accepting_bookings'. NOT affected.
--
--   start/departure RPCs (driver_start_trip, driver_leave_now, etc.):
--     Transition to 'boarding', 'departure_pending', 'in_progress'.
--     Do NOT set 'accepting_bookings'. NOT affected.
--
--   get_active_trip_for_route:
--     Read-only SELECT. NOT affected.
--
--   fix_existing_trip_matching (20260809340000) / fix_full_trip_departure_transition (20260809350000):
--     These set 'accepting_bookings' only when releasing a departure lock
--     (returning a trip from 'departure_pending' back to open). That is a
--     different lifecycle transition and is correct — the trip is being
--     re-opened for boarding, not being accepted from provisional state.
--     NOT affected by this fix.
--
--   cancel_booking / admin_cancel_booking:
--     Set 'accepting_bookings' only when downgrading from 'full' after a
--     cancellation (seat freed). That is correct capacity-driven logic.
--     NOT affected.
--
--   CONCLUSION: The unconditional capacity-state reset exists ONLY in the
--   two driver_accept_offer overloads. No other function has this bug.
--
-- ENUM CAST SAFETY:
--   Both CASE branches use explicit ::public.trip_status casts:
--     'full'::public.trip_status
--     'accepting_bookings'::public.trip_status
--   This prevents ERROR 42804 (CASE result inferred as TEXT vs ENUM column).
--   Consistent with the fix applied in migration 20260811120000.
--
-- DATA REPAIR:
--   Non-terminal trips where booked_seats >= total_seats AND
--   status = 'accepting_bookings' are objectively inconsistent under the
--   canonical capacity invariant. A narrow repair is applied to
--   NON-TERMINAL trips only (status NOT IN terminal states).
--   Historical completed/cancelled trips are NOT modified.
--
-- FIFO IMPACT: NONE
--   No driver_queue ordering changed. No joined_at modified.
--
-- OFFER EXPIRY IMPACT: NONE
--   expire_driver_offer / release_provisional_trip logic unchanged.
--   Server-side expiry check in both overloads preserved exactly.
--
-- TEST/LIVE ISOLATION IMPACT: NONE
--   is_test_data guards in match_route_queue unchanged.
--   Both overloads do not filter by is_test_data (they operate on a
--   specific queue entry already scoped to a driver). No change.
--
-- PROVISIONAL OFFER MARKER CONTRACT: PRESERVED
--   Both overloads still require AND notes = 'provisional_offer' in the
--   trip lock SELECT. notes = NULL is still set on successful acceptance.
--   The marker contract established in migration 20260811140000 is intact.
--
-- BOOKING ASSIGNMENT: UNCHANGED
--   Passenger queue MATCHING → ASSIGNED transition unchanged.
--   Booking status confirmed, trip_id assignment unchanged.
--
-- FILES CHANGED:
--   supabase/migrations/20260811150000_raahi_fix_driver_accept_offer_capacity_status.sql
-- ============================================================

-- ============================================================
-- STEP 1: Fix driver_accept_offer(p_driver_profile_id UUID, p_queue_entry_id UUID)
--
-- This is the primary overload used by the frontend driver UI.
-- Last deployed in: 20260810010000_raahi_fix_offer_expiry_flow.sql
--
-- CHANGE (one line):
--   BEFORE:
--     status     = 'accepting_bookings'::public.trip_status,
--   AFTER:
--     status     = CASE
--                    WHEN booked_seats >= total_seats
--                      THEN 'full'::public.trip_status
--                    ELSE 'accepting_bookings'::public.trip_status
--                  END,
--
-- All other logic is IDENTICAL to migration 20260810010000:
--   - Row lock on driver_queue (FOR UPDATE)
--   - Server-side expiry check (offer_expires_at <= NOW())
--   - Provisional trip lock (AND notes = 'provisional_offer', FOR UPDATE)
--   - driver_queue offered → assigned
--   - driver.availability_status → active
--   - passenger_queue MATCHING → ASSIGNED
--   - bookings confirmed, trip_id set
--   - audit log with 'driver_accepted_offer'
-- ============================================================

CREATE OR REPLACE FUNCTION public.driver_accept_offer(
  p_driver_profile_id UUID,
  p_queue_entry_id    UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver      RECORD;
  v_queue_entry RECORD;
  v_trip        RECORD;
BEGIN
  -- Get driver record
  SELECT * INTO v_driver FROM public.drivers WHERE profile_id = p_driver_profile_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver not found', 'reason', 'driver_not_found');
  END IF;

  -- ----------------------------------------------------------------
  -- ATOMIC ROW LOCK: lock the driver_queue row before any evaluation.
  -- This prevents two concurrent accept calls from both succeeding.
  -- ----------------------------------------------------------------
  SELECT * INTO v_queue_entry
  FROM public.driver_queue
  WHERE id = p_queue_entry_id
    AND driver_id = v_driver.id
    AND status = 'offered'
  FOR UPDATE;

  IF NOT FOUND THEN
    -- Either already accepted, declined, or expired
    RETURN jsonb_build_object(
      'success', false,
      'error',  'Offer not found or already processed',
      'reason', 'offer_not_found'
    );
  END IF;

  -- ----------------------------------------------------------------
  -- SERVER-SIDE EXPIRY CHECK — authoritative.
  -- Database timestamp is the single source of truth.
  -- Frontend countdown is display-only.
  -- ----------------------------------------------------------------
  IF v_queue_entry.offer_expires_at <= NOW() THEN
    -- Perform canonical expiry cleanup (releases passengers, triggers rematch)
    PERFORM public.expire_driver_offer(p_queue_entry_id);
    RETURN jsonb_build_object(
      'success', false,
      'error',  'Offer has expired. Finding the next available ride.',
      'reason', 'offer_expired'
    );
  END IF;

  -- ----------------------------------------------------------------
  -- GET PROVISIONAL TRIP with lock
  -- ----------------------------------------------------------------
  SELECT * INTO v_trip
  FROM public.trips
  WHERE id = v_queue_entry.provisional_trip_id
    AND notes = 'provisional_offer'
  FOR UPDATE;

  IF NOT FOUND THEN
    -- Provisional trip was already released (concurrent expiry won)
    RETURN jsonb_build_object(
      'success', false,
      'error',  'Offer no longer available — another process claimed it.',
      'reason', 'offer_expired'
    );
  END IF;

  -- ----------------------------------------------------------------
  -- ACCEPT: Confirm trip, assign passengers, update driver state
  --
  -- BUG FIX (migration 20260811150000):
  --   Previously: status = 'accepting_bookings'::public.trip_status
  --   This unconditionally reset a FULL provisional trip to
  --   'accepting_bookings' even when booked_seats >= total_seats.
  --
  --   Fixed: derive status from canonical capacity invariant.
  --   IF booked_seats >= total_seats THEN 'full' ELSE 'accepting_bookings'
  --   Explicit ::public.trip_status casts prevent ERROR 42804.
  -- ----------------------------------------------------------------

  -- Confirm trip — clear provisional flag, set correct capacity status
  UPDATE public.trips
  SET
    status     = CASE
                   WHEN booked_seats >= total_seats
                     THEN 'full'::public.trip_status
                   ELSE 'accepting_bookings'::public.trip_status
                 END,
    notes      = NULL,
    updated_at = NOW()
  WHERE id = v_trip.id;

  -- Confirm driver queue entry as assigned
  UPDATE public.driver_queue
  SET
    status       = 'assigned',
    activated_at = NOW(),
    updated_at   = NOW()
  WHERE id = p_queue_entry_id;

  -- Update driver availability
  UPDATE public.drivers
  SET
    availability_status = 'active'::public.driver_availability_status,
    current_route_id    = v_queue_entry.route_id,
    current_vehicle_id  = v_queue_entry.vehicle_id,
    updated_at          = NOW()
  WHERE id = v_driver.id;

  -- Confirm passenger queue entries as ASSIGNED (driver has accepted)
  UPDATE public.passenger_queue
  SET
    status     = 'ASSIGNED',
    updated_at = NOW()
  WHERE assigned_trip_id = v_trip.id
    AND status = 'MATCHING';

  -- Link bookings to the real trip and update status to confirmed
  UPDATE public.bookings
  SET
    trip_id    = v_trip.id,
    status     = 'confirmed'::public.booking_status,
    updated_at = NOW()
  WHERE id IN (
    SELECT booking_id FROM public.passenger_queue
    WHERE assigned_trip_id = v_trip.id
      AND status = 'ASSIGNED'
  );

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    p_driver_profile_id,
    'driver_accepted_offer'::public.audit_action,
    'driver_queue',
    p_queue_entry_id,
    jsonb_build_object(
      'trip_id',      v_trip.id,
      'route_id',     v_queue_entry.route_id,
      'booked_seats', v_trip.booked_seats,
      'total_seats',  v_trip.total_seats
    ),
    'Driver accepted ride offer — trip confirmed'
  );

  RETURN jsonb_build_object(
    'success',      true,
    'trip_id',      v_trip.id,
    'status',       'driver_assigned',
    'booked_seats', v_trip.booked_seats,
    'total_seats',  v_trip.total_seats
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.driver_accept_offer(UUID, UUID) TO authenticated;

-- ============================================================
-- STEP 2: Fix driver_accept_offer(p_queue_entry_id UUID)
--
-- This is the single-arg overload used by the test harness
-- (admin_simulate_driver_action).
-- Last deployed in: 20260809120000_raahi_stage52b_validation.sql
--
-- CHANGE (one line):
--   BEFORE:
--     SET status = 'accepting_bookings'::public.trip_status, notes = NULL, updated_at = NOW()
--   AFTER:
--     SET status = CASE
--                    WHEN booked_seats >= total_seats
--                      THEN 'full'::public.trip_status
--                    ELSE 'accepting_bookings'::public.trip_status
--                  END,
--         notes = NULL, updated_at = NOW()
--
-- All other logic is IDENTICAL to migration 20260809120000:
--   - Row lock on driver_queue (FOR UPDATE)
--   - Server-side expiry check (offer_expires_at < NOW())
--   - Provisional trip lock (AND notes = 'provisional_offer', FOR UPDATE)
--   - driver_queue offered → assigned
--   - driver.availability_status → active
--   - passenger_queue MATCHING → ASSIGNED
--   - bookings confirmed, trip_id set
--   - audit log with 'driver_accepted_offer'
-- ============================================================

CREATE OR REPLACE FUNCTION public.driver_accept_offer(
  p_queue_entry_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_queue_entry       RECORD;
  v_trip              RECORD;
  v_driver_profile_id UUID;
BEGIN
  -- Get queue entry with lock
  SELECT dq.*, d.profile_id AS driver_profile_id
  INTO v_queue_entry
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  WHERE dq.id = p_queue_entry_id
    AND dq.status = 'offered'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Offer not found or already expired/accepted');
  END IF;

  v_driver_profile_id := v_queue_entry.driver_profile_id;

  -- Server-side expiry check — authoritative
  IF v_queue_entry.offer_expires_at < NOW() THEN
    PERFORM public.expire_driver_offer(p_queue_entry_id);
    RETURN jsonb_build_object('success', false, 'error', 'Offer has expired. Driver returned to queue.');
  END IF;

  -- Get provisional trip with lock
  SELECT * INTO v_trip
  FROM public.trips
  WHERE id = v_queue_entry.provisional_trip_id
    AND notes = 'provisional_offer'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Provisional trip not found — offer may have been cancelled');
  END IF;

  -- ----------------------------------------------------------------
  -- BUG FIX (migration 20260811150000):
  --   Previously: SET status = 'accepting_bookings'::public.trip_status
  --   Fixed: derive status from canonical capacity invariant.
  --   Explicit ::public.trip_status casts prevent ERROR 42804.
  -- ----------------------------------------------------------------

  -- Confirm trip — clear provisional flag, set correct capacity status
  UPDATE public.trips
  SET
    status     = CASE
                   WHEN booked_seats >= total_seats
                     THEN 'full'::public.trip_status
                   ELSE 'accepting_bookings'::public.trip_status
                 END,
    notes      = NULL,
    updated_at = NOW()
  WHERE id = v_trip.id;

  -- Confirm driver queue entry
  UPDATE public.driver_queue
  SET
    status       = 'assigned',
    activated_at = NOW(),
    updated_at   = NOW()
  WHERE id = p_queue_entry_id;

  -- Update driver availability
  UPDATE public.drivers
  SET
    availability_status = 'active'::public.driver_availability_status,
    current_route_id    = v_queue_entry.route_id,
    current_vehicle_id  = v_queue_entry.vehicle_id,
    updated_at          = NOW()
  WHERE id = v_queue_entry.driver_id;

  -- Confirm passenger queue entries
  UPDATE public.passenger_queue
  SET
    status     = 'ASSIGNED',
    updated_at = NOW()
  WHERE assigned_trip_id = v_trip.id
    AND status = 'MATCHING';

  -- Link bookings to real trip
  UPDATE public.bookings
  SET
    trip_id    = v_trip.id,
    status     = 'confirmed'::public.booking_status,
    updated_at = NOW()
  WHERE id IN (
    SELECT booking_id FROM public.passenger_queue
    WHERE assigned_trip_id = v_trip.id
      AND status = 'ASSIGNED'
  );

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    v_driver_profile_id,
    'driver_accepted_offer'::public.audit_action,
    'driver_queue',
    p_queue_entry_id,
    jsonb_build_object(
      'trip_id',  v_trip.id,
      'route_id', v_queue_entry.route_id
    ),
    'Driver accepted ride offer — trip confirmed'
  );

  RETURN jsonb_build_object(
    'success',      true,
    'trip_id',      v_trip.id,
    'status',       'driver_assigned',
    'booked_seats', v_trip.booked_seats,
    'total_seats',  v_trip.total_seats
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.driver_accept_offer(UUID) TO authenticated;

-- ============================================================
-- STEP 3: Narrow data repair for active non-terminal trips
--
-- Scope: trips where booked_seats >= total_seats AND
--        status = 'accepting_bookings' AND
--        status NOT IN terminal states (completed, cancelled)
--
-- These trips are objectively inconsistent under the canonical
-- capacity invariant. The confirmed example is:
--   d105a70e-8948-4192-b436-564e377ee8c0
--   booked_seats=4, total_seats=4, status=accepting_bookings
--
-- SAFETY CONSTRAINTS:
--   - Only repairs trips in non-terminal states
--   - Does NOT touch completed or cancelled trips
--   - Does NOT modify any booking, passenger_queue, or driver records
--   - Does NOT alter FIFO ordering
--   - notes column is NOT touched (only status is corrected)
-- ============================================================

UPDATE public.trips
SET
  status     = 'full'::public.trip_status,
  updated_at = NOW()
WHERE status = 'accepting_bookings'::public.trip_status
  AND booked_seats >= total_seats
  AND booked_seats > 0
  AND status NOT IN (
    'completed'::public.trip_status,
    'cancelled'::public.trip_status
  );

-- ============================================================
-- STATIC REGRESSION VERIFICATION
--
-- Scenario (E2E confirmed):
--   Route: Gomoh → Dhanbad
--   Driver: Rajeev Backup4 (FIFO #1, 4-seat vehicle)
--   Passengers: 4 seats total (3 bookings)
--   Provisional trip: booked_seats=4, total_seats=4,
--                     notes='provisional_offer', status=full
--
-- BEFORE ACCEPT (after match_route_queue):
--   driver_queue.status = offered                            ✓
--   provisional_trip_id = trip id                           ✓
--   offer_expires_at > NOW()                                ✓
--   trip.status = full (4 >= 4)                             ✓
--   trip.notes = 'provisional_offer'                        ✓
--   passengers = MATCHING                                   ✓
--   bookings = confirmed                                    ✓
--
-- AFTER ACCEPT (with this fix):
--   driver_accept_offer locks trip WHERE notes='provisional_offer' ✓
--   CASE: booked_seats(4) >= total_seats(4) → 'full'        ✓ (BUG FIX)
--   trip.status = full                                      ✓
--   trip.notes = NULL (cleared)                             ✓
--   driver_queue.status = assigned                          ✓
--   driver.availability_status = active                     ✓
--   passenger_queue.status = ASSIGNED                       ✓
--   bookings remain confirmed                               ✓
--   RPC returns success=true                                ✓
--
-- PARTIAL TRIP (booked_seats < total_seats):
--   CASE: booked_seats(2) >= total_seats(4) → false
--   → 'accepting_bookings'::public.trip_status              ✓
--   Correct — trip remains open for more passengers         ✓
--
-- DUPLICATE ACCEPT:
--   driver_queue.status already = assigned
--   → FOR UPDATE finds no row with status='offered'
--   → returns offer_not_found                               ✓
--   No duplicate trip, no duplicate assignment              ✓
--
-- FIFO: Unchanged — no driver_queue ordering modified       ✓
-- EXPIRY: Unchanged — offer_expires_at check preserved      ✓
-- TEST/LIVE ISOLATION: Unchanged                            ✓
-- PROVISIONAL MARKER CONTRACT: Preserved                    ✓
-- ============================================================
