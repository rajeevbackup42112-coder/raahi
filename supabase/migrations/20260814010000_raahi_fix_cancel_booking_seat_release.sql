-- ============================================================
-- Migration: 20260814010000_raahi_fix_cancel_booking_seat_release.sql
-- Title: Fix canonical cancel_booking seat release on passenger cancellation
--
-- Root cause:
--   public.cancel_booking(p_booking_id uuid) correctly cancelled bookings and
--   passenger_queue rows but did NOT subtract booking.seats from trip.booked_seats
--   nor transition the trip status back from 'full' to 'accepting_bookings' when
--   capacity became available.
--
-- Production evidence:
--   Rajeev5 cancelled a 3-seat booking on trip b46aa46b-15d3-4388-8843-82cade7ed2a1
--   After cancellation: trip remained status='full', booked_seats=7 (should be 4)
--
-- Fix:
--   After the booking is transitioned to 'cancelled' (inside the existing FOR UPDATE
--   lock on the booking row), if the booking referenced a non-terminal pre-departure
--   trip, atomically:
--     1. Lock the trip row FOR UPDATE
--     2. Subtract booking.seats from trip.booked_seats, guarded with GREATEST(0, ...)
--     3. Recalculate trip status:
--        - If new booked_seats >= total_seats → 'full'
--        - Else if trip was 'full' → 'accepting_bookings'
--        - Else → leave status unchanged (already accepting_bookings/ready/etc.)
--
-- Idempotency/concurrency:
--   Seat release occurs only when booking transitions from an active cancellable
--   status to 'cancelled'. The booking row is locked FOR UPDATE before the status
--   check, so repeated/retried calls will find status='cancelled' and return early
--   before reaching the seat-release block.
--
-- Preserved:
--   - Cancellation fee, abuse/cooldown, audit, rate limiting, departure eligibility
--   - Driver/provisional trip and other passengers untouched
--   - No legacy overloads restored
--   - No frontend changes
--
-- Data repair:
--   Repairs trip b46aa46b-15d3-4388-8843-82cade7ed2a1 from authoritative active
--   booking state (SUM of seats from non-cancelled/non-no_show bookings).
-- ============================================================

-- ── STEP 1: Replace canonical cancel_booking(uuid) with seat-release fix ──────

DROP FUNCTION IF EXISTS public.cancel_booking(UUID);

CREATE OR REPLACE FUNCTION public.cancel_booking(
  p_booking_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_passenger_id       UUID;
  v_booking            RECORD;
  v_queue_entry        RECORD;
  v_trip               RECORD;
  v_trip_status        TEXT;
  v_cancellation_id    UUID;
  v_new_booked_seats   INTEGER;
  v_new_trip_status    public.trip_status;

  -- Abuse protection
  v_abuse_enabled      BOOLEAN;
  v_cancel_window_min  INTEGER;
  v_cancel_limit       INTEGER;
  v_cooldown_minutes   INTEGER;
  v_cancel_count       INTEGER;
  v_window_start       TIMESTAMPTZ;
  v_cooldown_until     TIMESTAMPTZ;

  -- Rate limit
  v_rate_limit_enabled BOOLEAN;
  v_rate_window_sec    INTEGER;
  v_rate_limit         INTEGER;
  v_action_count       INTEGER;
  v_retry_after        INTEGER;
BEGIN
  -- ── IDENTITY ──────────────────────────────────────────────────────────────
  v_passenger_id := auth.uid();
  IF v_passenger_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- ── LOAD ABUSE SETTINGS ───────────────────────────────────────────────────
  v_abuse_enabled      := public.get_business_setting_bool('booking_abuse_protection_enabled', true);
  v_cancel_window_min  := public.get_business_setting_int('cancellation_window_minutes', 60);
  v_cancel_limit       := public.get_business_setting_int('cancellation_limit_in_window', 3);
  v_cooldown_minutes   := public.get_business_setting_int('booking_cooldown_minutes', 30);
  v_rate_limit_enabled := public.get_business_setting_bool('booking_action_rate_limit_enabled', true);
  v_rate_window_sec    := public.get_business_setting_int('booking_action_window_seconds', 60);
  v_rate_limit         := public.get_business_setting_int('booking_action_limit', 10);

  -- ── RAPID ACTION RATE LIMIT ───────────────────────────────────────────────
  IF v_abuse_enabled AND v_rate_limit_enabled THEN
    v_window_start := NOW() - (v_rate_window_sec || ' seconds')::INTERVAL;
    SELECT COUNT(*) INTO v_action_count
    FROM public.audit_logs
    WHERE performed_by = v_passenger_id
      AND action IN ('booking_created', 'booking_cancelled', 'passenger_joined_queue')
      AND created_at >= v_window_start;

    IF v_action_count >= v_rate_limit THEN
      v_retry_after := v_rate_window_sec;
      INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
      VALUES (
        v_passenger_id,
        'booking_action_rate_limited'::public.audit_action,
        'bookings',
        p_booking_id,
        jsonb_build_object('action_count', v_action_count, 'window_seconds', v_rate_window_sec),
        'Rapid action rate limit triggered during cancel_booking'
      );
      RETURN jsonb_build_object(
        'success', false,
        'reason', 'rate_limited',
        'retry_after_seconds', v_retry_after,
        'error', 'Too many booking actions. Please wait a moment before trying again.'
      );
    END IF;
  END IF;

  -- ── FETCH BOOKING (lock for update — idempotency guard) ───────────────────
  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id AND passenger_id = v_passenger_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found or not yours');
  END IF;

  -- ── BOOKING STATUS CHECK ──────────────────────────────────────────────────
  -- If already cancelled (retry/idempotent call), return early without
  -- decrementing seats a second time.
  IF v_booking.status NOT IN ('queued', 'confirmed', 'matching') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Cannot cancel a booking with status: %s', v_booking.status)
    );
  END IF;

  -- ── KEY FIX: TRIP TERMINAL STATE CHECK ───────────────────────────────────
  -- If the booking references a trip that is already completed or cancelled,
  -- this is a historical booking. Cancellation is not legal and must not
  -- trigger the passenger abuse cooldown counter.
  IF v_booking.trip_id IS NOT NULL THEN
    SELECT t.status INTO v_trip_status
    FROM public.trips t
    WHERE t.id = v_booking.trip_id;

    IF v_trip_status IN ('completed', 'cancelled') THEN
      RETURN jsonb_build_object(
        'success', false,
        'reason', 'trip_already_terminal',
        'error', 'This booking is from a trip that has already ended and cannot be cancelled.'
      );
    END IF;
  END IF;

  -- ── FETCH QUEUE ENTRY ─────────────────────────────────────────────────────
  SELECT * INTO v_queue_entry
  FROM public.passenger_queue
  WHERE booking_id = p_booking_id
  FOR UPDATE;

  -- ── CANCEL BOOKING ────────────────────────────────────────────────────────
  UPDATE public.bookings
  SET status = 'cancelled', updated_at = NOW()
  WHERE id = p_booking_id;

  -- ── CANCEL QUEUE ENTRY ────────────────────────────────────────────────────
  IF v_queue_entry.id IS NOT NULL THEN
    UPDATE public.passenger_queue
    SET status = 'CANCELLED', updated_at = NOW()
    WHERE id = v_queue_entry.id;
  END IF;

  -- ── SEAT RELEASE: subtract booking.seats from trip.booked_seats ──────────
  -- Only for pre-departure trips (non-terminal, non-in_progress).
  -- The trip row is locked FOR UPDATE to prevent concurrent over-decrement.
  -- Idempotency: we only reach here when booking was in an active cancellable
  -- state (checked above), so this block executes exactly once per cancellation.
  IF v_booking.trip_id IS NOT NULL THEN
    SELECT * INTO v_trip
    FROM public.trips
    WHERE id = v_booking.trip_id
    FOR UPDATE;

    IF FOUND AND v_trip.status NOT IN ('completed', 'cancelled', 'in_progress') THEN
      -- Atomically subtract seats, floor at 0
      v_new_booked_seats := GREATEST(0, v_trip.booked_seats - v_booking.seats);

      -- Recalculate trip status:
      --   If still at capacity → keep 'full'
      --   If was 'full' and now has room → 'accepting_bookings'
      --   Otherwise → leave status unchanged
      IF v_new_booked_seats >= v_trip.total_seats THEN
        v_new_trip_status := 'full'::public.trip_status;
      ELSIF v_trip.status = 'full'::public.trip_status THEN
        v_new_trip_status := 'accepting_bookings'::public.trip_status;
      ELSE
        v_new_trip_status := v_trip.status;
      END IF;

      UPDATE public.trips
      SET
        booked_seats = v_new_booked_seats,
        status       = v_new_trip_status,
        updated_at   = NOW()
      WHERE id = v_booking.trip_id;
    END IF;
  END IF;

  -- ── RECORD CANCELLATION (passenger-initiated) ─────────────────────────────
  INSERT INTO public.cancellations (
    booking_id,
    cancelled_by,
    reason,
    cancelled_by_type
  )
  VALUES (
    p_booking_id,
    v_passenger_id,
    'Passenger cancelled',
    'passenger'
  )
  RETURNING id INTO v_cancellation_id;

  -- ── AUDIT ─────────────────────────────────────────────────────────────────
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    v_passenger_id,
    'booking_cancelled'::public.audit_action,
    'bookings',
    p_booking_id,
    jsonb_build_object('cancelled_by_type', 'passenger', 'cancellation_id', v_cancellation_id),
    'Passenger cancelled booking'
  );

  -- ── ABUSE PROTECTION: CHECK CANCELLATION THRESHOLD ───────────────────────
  IF v_abuse_enabled THEN
    v_window_start := NOW() - (v_cancel_window_min || ' minutes')::INTERVAL;

    SELECT COUNT(*) INTO v_cancel_count
    FROM public.cancellations c
    JOIN public.bookings b ON b.id = c.booking_id
    WHERE b.passenger_id = v_passenger_id
      AND c.cancelled_by_type = 'passenger'
      AND c.created_at >= v_window_start;

    IF v_cancel_count >= v_cancel_limit THEN
      SELECT booking_cooldown_until INTO v_cooldown_until
      FROM public.profiles WHERE id = v_passenger_id;

      IF v_cooldown_until IS NULL OR v_cooldown_until <= NOW() THEN
        v_cooldown_until := NOW() + (v_cooldown_minutes || ' minutes')::INTERVAL;

        UPDATE public.profiles
        SET booking_cooldown_until = v_cooldown_until
        WHERE id = v_passenger_id;

        INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
        VALUES (
          v_passenger_id,
          'booking_cooldown_started'::public.audit_action,
          'profiles',
          v_passenger_id,
          jsonb_build_object(
            'cancel_count', v_cancel_count,
            'window_minutes', v_cancel_window_min,
            'cooldown_until', v_cooldown_until,
            'cooldown_minutes', v_cooldown_minutes
          ),
          format('Booking cooldown started after %s cancellations in %s minutes', v_cancel_count, v_cancel_window_min)
        );
      END IF;
    END IF;
  END IF;

  -- ── RECHECK DEPARTURE ELIGIBILITY ────────────────────────────────────────
  IF v_queue_entry.id IS NOT NULL THEN
    PERFORM public.check_departure_eligibility_on_cancel(v_queue_entry.id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'message', 'Booking cancelled successfully'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancel_booking(UUID) TO authenticated;

-- ── STEP 2: Data repair for affected trip b46aa46b-15d3-4388-8843-82cade7ed2a1 ──
--
-- Repair strategy: compute authoritative booked_seats from the SUM of seats
-- of all non-terminal bookings (confirmed, matching, queued) attached to this
-- trip. Only repair if the trip is in a pre-departure state (not completed/
-- cancelled/in_progress) to avoid touching terminal trips.
--
-- Production evidence: active booking seats = 4, active queue seats = 4.
-- Expected result: booked_seats = 4, status = 'accepting_bookings' (4 < 7 total).

DO $$
DECLARE
  v_trip_id      UUID := 'b46aa46b-15d3-4388-8843-82cade7ed2a1';
  v_trip         RECORD;
  v_active_seats INTEGER;
  v_new_status   public.trip_status;
BEGIN
  -- Load trip with lock
  SELECT * INTO v_trip
  FROM public.trips
  WHERE id = v_trip_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE NOTICE 'Data repair: trip % not found, skipping.', v_trip_id;
    RETURN;
  END IF;

  -- Only repair pre-departure trips
  IF v_trip.status IN ('completed', 'cancelled', 'in_progress') THEN
    RAISE NOTICE 'Data repair: trip % is in terminal/in-progress state (%), skipping.', v_trip_id, v_trip.status;
    RETURN;
  END IF;

  -- Compute authoritative booked_seats from active bookings
  SELECT COALESCE(SUM(b.seats), 0) INTO v_active_seats
  FROM public.bookings b
  WHERE b.trip_id = v_trip_id
    AND b.status IN ('confirmed', 'matching', 'queued');

  -- Determine correct status
  IF v_active_seats >= v_trip.total_seats THEN
    v_new_status := 'full'::public.trip_status;
  ELSE
    -- Trip had capacity available — restore to accepting_bookings
    v_new_status := 'accepting_bookings'::public.trip_status;
  END IF;

  RAISE NOTICE 'Data repair: trip % — old booked_seats=%, new booked_seats=%, old status=%, new status=%',
    v_trip_id, v_trip.booked_seats, v_active_seats, v_trip.status, v_new_status;

  UPDATE public.trips
  SET
    booked_seats = v_active_seats,
    status       = v_new_status,
    updated_at   = NOW()
  WHERE id = v_trip_id;

  RAISE NOTICE 'Data repair: trip % repaired successfully.', v_trip_id;
END $$;

-- ── STEP 3: Verification queries (run manually after applying) ────────────────
--
-- 1. Confirm exactly ONE cancel_booking signature exists:
--    SELECT proname, pg_get_function_identity_arguments(oid)
--    FROM pg_proc
--    WHERE proname = 'cancel_booking'
--      AND pronamespace = 'public'::regnamespace;
--    Expected: one row → cancel_booking(p_booking_id uuid)
--
-- 2. Confirm affected trip is repaired:
--    SELECT id, booked_seats, total_seats, status
--    FROM public.trips
--    WHERE id = 'b46aa46b-15d3-4388-8843-82cade7ed2a1';
--    Expected: booked_seats=4, total_seats=7, status='accepting_bookings'
--
-- 3. Confirm 4 active bookings remain:
--    SELECT COUNT(*), SUM(seats)
--    FROM public.bookings
--    WHERE trip_id = 'b46aa46b-15d3-4388-8843-82cade7ed2a1'
--      AND status IN ('confirmed','matching','queued');
--    Expected: count=?, sum=4
--
-- 4. Confirm Rajeev5 booking remains cancelled:
--    SELECT b.id, b.status, b.seats, p.name
--    FROM public.bookings b
--    JOIN public.profiles p ON p.id = b.passenger_id
--    WHERE b.trip_id = 'b46aa46b-15d3-4388-8843-82cade7ed2a1'
--      AND b.status = 'cancelled';
--    Expected: Rajeev5 row with seats=3, status=cancelled
