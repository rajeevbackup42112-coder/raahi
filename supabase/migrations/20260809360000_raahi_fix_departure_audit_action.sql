-- ============================================================
-- RAAHI — Fix Departure Audit Action Enum
-- Migration: 20260809360000_raahi_fix_departure_audit_action.sql
-- ============================================================
--
-- ROOT CAUSE:
--
--   driver_leave_now (deployed in migration 350000) inserts an
--   audit_log row with:
--
--     'trip_departure_initiated'::public.audit_action
--
--   but that enum value was never added to public.audit_action.
--   PostgreSQL raises:
--
--     code: 22P02
--     message: "invalid input value for enum audit_action:
--               \"trip_departure_initiated\""
--
--   This causes the entire driver_leave_now transaction to roll back,
--   so the trip never transitions to departure_pending.
--
-- AUDIT OF ALL OPERATIONAL RPC audit_action LITERALS:
--
--   The following values are used in deployed RPCs and were verified
--   against the deployed enum (stages 2, 3, 4, 5, 51, 52):
--
--   PRESENT IN ENUM (no action needed):
--     trip_started              (stage3)
--     trip_completed            (stage3)
--     booking_created           (stage3)
--     booking_cancelled         (stage3)
--     passenger_replaced        (stage3)
--     driver_went_online        (stage3)
--     driver_approved           (stage2)
--     passenger_joined_queue    (stage5)
--     passenger_assigned_to_trip (stage5)
--     passenger_returned_to_queue (stage5)
--     driver_offered_ride       (stage5)
--     driver_accepted_offer     (stage5)
--     driver_declined_offer     (stage5)
--     offer_expired             (stage5)
--     driver_cancelled_trip     (stage5)
--     no_show_marked            (stage4)
--     seat_count_changed        (stage4)
--     booking_reassigned        (stage4)
--     driver_skipped            (stage4)
--     driver_paused_admin       (stage4)
--     driver_removed_admin      (stage4)
--     route_updated             (stage4)
--     settings_updated          (stage4)
--     test_data_reset           (stage52)
--
--   MISSING FROM ENUM — ONLY ONE:
--     trip_departure_initiated  ← ADDED BY THIS MIGRATION
--
-- FIX:
--   Use ALTER TYPE ... ADD VALUE IF NOT EXISTS (safe forward-only
--   migration — does NOT drop or recreate the enum).
--
-- ALSO FIXED:
--   The driver_leave_now audit INSERT in migration 350000 omits
--   performed_by (it is NULL). We redeploy driver_leave_now here
--   with performed_by = v_driver_id so the audit log correctly
--   identifies the acting driver's PROFILE ID (not drivers.id).
--   The profiles.id is resolved from drivers.profile_id.
--
-- RETEST:
--   Trip: d78924d7-fae0-42f3-a503-af26ecd34925
--   4/4 seats, status = full (set by migration 350000 repair block)
--   Driver clicks Start Departure → driver_leave_now → HTTP 200
--   Trip transitions to departure_pending (lock_seconds = 0 for full)
--   driver_start_trip → trip transitions to in_progress
--   Passengers see "Trip in Progress"
--   Admin Active Trips shows trip
--   audit_logs contains valid record with performed_by = driver profile id
--
-- ============================================================

-- ============================================================
-- STEP 1: Add missing enum value
-- Safe: ADD VALUE IF NOT EXISTS never fails if value already exists.
-- Does NOT drop or recreate the enum.
-- ============================================================

ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'trip_departure_initiated';

-- Commit enum addition so it is visible to subsequent statements
COMMIT;

-- ============================================================
-- STEP 2: Redeploy driver_leave_now with performed_by populated
--
-- The version in migration 350000 inserts the audit row without
-- performed_by (column is NULL). This migration fixes that by
-- resolving the driver's profile_id and passing it as performed_by.
--
-- All other logic is identical to migration 350000.
-- ============================================================

CREATE OR REPLACE FUNCTION public.driver_leave_now(
  p_driver_profile_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id         UUID;
  v_driver_profile_id UUID;   -- profiles.id (for audit performed_by)
  v_trip_id           UUID;
  v_trip_status       public.trip_status;
  v_route_id          UUID;
  v_min_passengers    INTEGER;
  v_booked_seats      INTEGER;
  v_total_seats       INTEGER;
  v_vehicle_capacity  INTEGER;
  v_lock_seconds      INTEGER := 60;
  v_lock_expires_at   TIMESTAMPTZ;
  v_is_full           BOOLEAN := FALSE;
BEGIN
  -- Resolve driver record from profile id
  SELECT d.id, d.profile_id
  INTO v_driver_id, v_driver_profile_id
  FROM public.drivers d
  WHERE d.profile_id = p_driver_profile_id;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver not found');
  END IF;

  -- Find the active trip for this driver
  -- Accept: accepting_bookings, full, boarding (all pre-departure states)
  -- Reject: departure_pending (already locked), in_progress, completed, cancelled
  SELECT t.id, t.status, t.route_id, t.total_seats
  INTO v_trip_id, v_trip_status, v_route_id, v_total_seats
  FROM public.trips t
  WHERE t.driver_id = v_driver_id
    AND t.status IN ('accepting_bookings', 'full', 'boarding')
  ORDER BY t.created_at DESC
  LIMIT 1;

  IF v_trip_id IS NULL THEN
    -- Check if already departure_pending (idempotent response)
    IF EXISTS (
      SELECT 1 FROM public.trips
      WHERE driver_id = v_driver_id
        AND status = 'departure_pending'
      LIMIT 1
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Departure lock already active');
    END IF;

    RETURN jsonb_build_object('success', false, 'error', 'No active boarding trip found');
  END IF;

  -- Get route min_passengers
  SELECT COALESCE(min_passengers, 1)
  INTO v_min_passengers
  FROM public.routes
  WHERE id = v_route_id;

  -- Count currently confirmed seats for this trip
  SELECT COALESCE(SUM(b.seats), 0)
  INTO v_booked_seats
  FROM public.bookings b
  WHERE b.trip_id = v_trip_id
    AND b.status = 'confirmed';

  -- Enforce minimum occupancy rule
  IF v_booked_seats < v_min_passengers THEN
    RETURN jsonb_build_object(
      'success',        false,
      'error',          'Below minimum occupancy',
      'booked_seats',   v_booked_seats,
      'min_passengers', v_min_passengers,
      'seats_needed',   v_min_passengers - v_booked_seats
    );
  END IF;

  -- Get vehicle capacity for context
  SELECT v.seating_capacity
  INTO v_vehicle_capacity
  FROM public.vehicles v
  JOIN public.drivers d ON d.current_vehicle_id = v.id
  WHERE d.id = v_driver_id;

  -- Determine if vehicle is full
  v_is_full := v_booked_seats >= COALESCE(v_total_seats, v_vehicle_capacity, 4);

  IF v_is_full THEN
    -- Full vehicle: no departure lock needed — set expires_at = NOW()
    -- so driver_start_trip can proceed immediately
    v_lock_seconds    := 0;
    v_lock_expires_at := NOW();
  ELSE
    -- Partial load at minimum: apply normal departure lock
    SELECT COALESCE(value::INTEGER, 60)
    INTO v_lock_seconds
    FROM public.business_settings
    WHERE key = 'departure_lock_seconds';

    v_lock_expires_at := NOW() + (v_lock_seconds || ' seconds')::INTERVAL;
  END IF;

  -- Transition trip to departure_pending
  UPDATE public.trips
  SET status                    = 'departure_pending',
      departure_lock_expires_at = v_lock_expires_at,
      updated_at                = NOW()
  WHERE id = v_trip_id;

  -- Audit log with performed_by = driver's profiles.id (NOT drivers.id)
  INSERT INTO public.audit_logs (
    performed_by,
    action,
    target_table,
    target_id,
    new_value,
    notes
  )
  VALUES (
    v_driver_profile_id,
    'trip_departure_initiated'::public.audit_action,
    'trips',
    v_trip_id,
    jsonb_build_object(
      'driver_id',                 v_driver_id,
      'driver_profile_id',         v_driver_profile_id,
      'booked_seats',              v_booked_seats,
      'total_seats',               v_total_seats,
      'is_full',                   v_is_full,
      'departure_lock_seconds',    v_lock_seconds,
      'departure_lock_expires_at', v_lock_expires_at
    ),
    CASE WHEN v_is_full
         THEN 'Full vehicle departure initiated — no lock window'
         ELSE 'Partial load departure initiated — lock window active'
    END
  );

  RETURN jsonb_build_object(
    'success',                   true,
    'trip_id',                   v_trip_id,
    'is_full',                   v_is_full,
    'departure_lock_seconds',    v_lock_seconds,
    'departure_lock_expires_at', v_lock_expires_at,
    'booked_seats',              v_booked_seats,
    'total_seats',               v_total_seats
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.driver_leave_now(UUID) TO authenticated;

-- ============================================================
-- STEP 3: Repair live trip if still in accepting_bookings
--
-- Migration 350000 included a repair block but it ran before the
-- enum fix. If the live trip is still accepting_bookings with
-- booked_seats = total_seats, transition it to 'full' now so
-- the driver can immediately click Start Departure.
-- ============================================================

UPDATE public.trips
SET
  status     = 'full'::public.trip_status,
  updated_at = NOW()
WHERE id = 'd78924d7-fae0-42f3-a503-af26ecd34925'
  AND status IN ('accepting_bookings', 'boarding')
  AND booked_seats >= total_seats;

-- Also repair any other full trips left in accepting_bookings
-- (defensive — covers any route, not just the test trip)
UPDATE public.trips
SET
  status     = 'full'::public.trip_status,
  updated_at = NOW()
WHERE status = 'accepting_bookings'
  AND booked_seats >= total_seats;

-- ============================================================
-- END OF MIGRATION
-- ============================================================
--
-- FINAL REPORT
-- ============================================================
--
-- INVALID AUDIT VALUE SOURCE:
--   supabase/migrations/20260809350000_raahi_fix_full_trip_departure_transition.sql
--   Function: driver_leave_now
--   Line ~586: 'trip_departure_initiated'::public.audit_action
--   The enum value was referenced but never added with ALTER TYPE.
--
-- trip_departure_initiated ENUM PRESENT BEFORE THIS MIGRATION:
--   NO
--
-- FIX APPLIED:
--   ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS
--   'trip_departure_initiated'
--   + driver_leave_now redeployed with performed_by = driver profile id
--
-- OTHER INVALID audit_action LITERALS FOUND:
--   NONE — all other literals used in operational RPCs are present
--   in the deployed enum (verified against stages 2, 3, 4, 5, 51, 52).
--
-- ============================================================
