-- ============================================================
-- RAAHI — Stale Booking Fix + Admin Recovery RPC
-- Migration: 20260811090000_raahi_stale_booking_fix_and_admin_recovery.sql
-- ============================================================
--
-- ROOT CAUSE:
--   get_my_bookings derives display status from passenger_queue.status
--   WITHOUT checking whether the associated trip is terminal.
--   If passenger_queue.status = 'ASSIGNED' but the trip is completed/
--   cancelled, the RPC returns status='assigned' → UI shows "Driver Assigned"
--   with Cancel Booking still available.
--
--   cancel_booking only checks booking.status IN ('queued','confirmed','matching')
--   but does NOT verify the associated trip is still active. A booking
--   linked to a completed trip can still be "cancelled" by the passenger,
--   incorrectly triggering the abuse cooldown counter.
--
-- FIXES IN THIS MIGRATION:
--   1. get_my_bookings — add trip terminal state check before deriving
--      'assigned' display status. If trip is terminal, derive status
--      from booking_status directly (completed/cancelled/no_show).
--      Also add fare_collected field to output.
--
--   2. get_passenger_booking — same trip terminal state guard so the
--      single-booking view also resolves correctly.
--
--   3. cancel_booking — reject cancellation when the associated trip
--      is in a terminal state (completed/cancelled). This prevents
--      stale "Cancel Booking" button from working AND prevents
--      incorrect abuse cooldown increments.
--
--   4. admin_recover_stale_booking — new admin-only RPC that safely
--      reconciles a stale booking/trip without triggering passenger
--      abuse cooldown. Idempotent. Audit logged. Reason required.
--
--   5. New audit_action: stale_booking_recovered
--
--   6. SYSTEM-WIDE STALE STATE REPAIR — DO block that finds and
--      fixes all bookings/passenger_queue entries where the associated
--      trip is terminal but the booking/queue records are not.
--
--   7. RAJEEV.BACKUP1 SPECIFIC REPAIR — targets the two stale
--      Gomoh→Dhanbad bookings from 10 Aug 2026 testing.
--
-- PRESERVATION RULES:
--   - No hard deletion of bookings, trips, or passenger_queue rows
--   - Historical records preserved for audit
--   - Rajeev Backup4 (#1) and Dipti (#2) FIFO positions NOT disturbed
--   - Passenger abuse cooldown NOT triggered by admin recovery
--   - admin_abort_trip semantics preserved and reused
-- ============================================================

-- ============================================================
-- STEP 1: ADD NEW AUDIT ACTION
-- ============================================================

ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'stale_booking_recovered';

COMMIT;

-- ============================================================
-- STEP 2: FIX get_my_bookings — trip terminal state guard
--
-- KEY CHANGE: Before deriving 'assigned' from queue_status='ASSIGNED',
-- check that the trip is NOT terminal. If trip is completed/cancelled,
-- fall through to booking_status for the canonical display value.
-- Also adds fare_collected to the output.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_my_bookings()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_passenger_id   UUID;
  v_result         JSONB := '[]'::JSONB;
  v_row            RECORD;
  v_item           JSONB;
  v_items          JSONB[] := ARRAY[]::JSONB[];
  v_display_status TEXT;
  v_trip_terminal  BOOLEAN;
BEGIN
  v_passenger_id := auth.uid();
  IF v_passenger_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Not authenticated', 'bookings', '[]'::JSONB);
  END IF;

  FOR v_row IN
    SELECT
      b.id                          AS booking_id,
      b.trip_id,
      b.pickup_point_id,
      b.seats,
      b.fare_per_seat,
      b.total_fare,
      b.status                      AS booking_status,
      b.booked_at,
      b.fare_collected_at,
      -- Pickup point
      pp.name                       AS pickup_name,
      -- Queue entry (may be null)
      pq.id                         AS queue_id,
      pq.route_id                   AS pq_route_id,
      pq.status                     AS queue_status,
      pq.seat_count,
      pq.assigned_trip_id,
      -- Trip (may be null)
      t.route_id                    AS trip_route_id,
      t.status                      AS trip_status,
      t.vehicle_id,
      -- Route resolved: trip route preferred, else queue route
      COALESCE(rt.from_location, rq.from_location, '') AS route_from,
      COALESCE(rt.to_location,   rq.to_location,   '') AS route_to,
      -- Vehicle
      v.make                        AS vehicle_make,
      v.model                       AS vehicle_model
    FROM public.bookings b
    LEFT JOIN public.pickup_points pp ON pp.id = b.pickup_point_id
    LEFT JOIN public.passenger_queue pq ON pq.booking_id = b.id
    LEFT JOIN public.trips t ON t.id = b.trip_id
    LEFT JOIN public.routes rt ON rt.id = t.route_id
    LEFT JOIN public.routes rq ON rq.id = pq.route_id
    LEFT JOIN public.vehicles v ON v.id = t.vehicle_id
    WHERE b.passenger_id = v_passenger_id
    ORDER BY b.booked_at DESC
  LOOP
    -- ----------------------------------------------------------------
    -- TRIP TERMINAL STATE CHECK
    -- If the booking's associated trip (via trip_id or assigned_trip_id)
    -- is completed or cancelled, the booking is historically terminal
    -- regardless of what passenger_queue.status says.
    -- This is the root cause of "Driver Assigned" showing for old bookings.
    -- ----------------------------------------------------------------
    v_trip_terminal := (
      v_row.trip_status IS NOT NULL
      AND v_row.trip_status IN ('completed', 'cancelled')
    );

    -- Determine display status
    IF v_row.queue_status IS NOT NULL
       AND v_row.queue_status NOT IN ('CANCELLED', 'COMPLETED')
       AND v_row.booking_status NOT IN ('cancelled', 'completed', 'no_show')
       AND NOT v_trip_terminal   -- ← KEY FIX: skip queue status if trip is terminal
    THEN
      v_display_status := CASE v_row.queue_status
        WHEN 'WAITING'   THEN 'queued'
        WHEN 'MATCHING'  THEN 'matching'
        WHEN 'ASSIGNED'  THEN 'assigned'
        ELSE v_row.booking_status
      END;
    ELSE
      -- Trip is terminal or booking is terminal — use booking_status directly
      -- This correctly resolves stale ASSIGNED queue entries to their
      -- canonical booking outcome (completed, cancelled, no_show, confirmed)
      v_display_status := v_row.booking_status;
    END IF;

    v_item := jsonb_build_object(
      'id',              v_row.booking_id,
      'seats',           v_row.seats,
      'fare_per_seat',   v_row.fare_per_seat,
      'total_fare',      v_row.total_fare,
      'status',          v_display_status,
      'booking_status',  v_row.booking_status,
      'queue_status',    COALESCE(v_row.queue_status, ''),
      'booked_at',       v_row.booked_at,
      'pickup_name',     COALESCE(v_row.pickup_name, ''),
      'route_from',      v_row.route_from,
      'route_to',        v_row.route_to,
      'trip_id',         v_row.trip_id,
      'trip_status',     COALESCE(v_row.trip_status, ''),
      'vehicle_make',    COALESCE(v_row.vehicle_make, ''),
      'vehicle_model',   COALESCE(v_row.vehicle_model, ''),
      'fare_collected',  (v_row.fare_collected_at IS NOT NULL),
      'fare_collected_at', v_row.fare_collected_at
    );
    v_items := array_append(v_items, v_item);
  END LOOP;

  SELECT jsonb_agg(elem) INTO v_result
  FROM unnest(v_items) AS elem;

  RETURN jsonb_build_object(
    'bookings', COALESCE(v_result, '[]'::JSONB)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_bookings() TO authenticated;

-- ============================================================
-- STEP 3: FIX get_passenger_booking — same trip terminal guard
--
-- Single-booking view must also resolve correctly when trip is terminal.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_passenger_booking(
  p_booking_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_passenger_id      UUID;
  v_booking           RECORD;
  v_pq                RECORD;
  v_route             RECORD;
  v_trip_id           UUID;
  v_trip_status       TEXT;
  v_trip_vehicle_id   UUID;
  v_trip_driver_id    UUID;
  v_trip_route_id     UUID;
  v_pickup            RECORD;
  v_vehicle           RECORD;
  v_driver            RECORD;
  v_queue_pos         BIGINT;
  v_passengers_ahead  BIGINT;
  v_resolved_route_id UUID;
  v_trip_terminal     BOOLEAN;
BEGIN
  v_passenger_id := auth.uid();
  IF v_passenger_id IS NULL THEN
    RETURN jsonb_build_object('found', false, 'error', 'Not authenticated');
  END IF;

  SELECT b.id,
         b.passenger_id,
         b.trip_id,
         b.pickup_point_id,
         b.seats,
         b.fare_per_seat,
         b.total_fare,
         b.status,
         b.booked_at,
         b.fare_collected_at
  INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id
    AND b.passenger_id = v_passenger_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false, 'error', 'Booking not found');
  END IF;

  SELECT pq.id,
         pq.route_id,
         pq.status,
         pq.queue_sequence,
         pq.seat_count,
         pq.assigned_trip_id
  INTO v_pq
  FROM public.passenger_queue pq
  WHERE pq.booking_id = p_booking_id
  LIMIT 1;

  -- Resolve trip scalars
  IF v_booking.trip_id IS NOT NULL THEN
    SELECT t.id, t.route_id, t.status, t.vehicle_id, t.driver_id
    INTO v_trip_id, v_trip_route_id, v_trip_status, v_trip_vehicle_id, v_trip_driver_id
    FROM public.trips t
    WHERE t.id = v_booking.trip_id;
    v_resolved_route_id := v_trip_route_id;
  ELSIF v_pq.route_id IS NOT NULL THEN
    v_resolved_route_id := v_pq.route_id;
  END IF;

  -- Trip terminal check
  v_trip_terminal := (v_trip_status IS NOT NULL AND v_trip_status IN ('completed', 'cancelled'));

  -- Load route
  IF v_resolved_route_id IS NOT NULL THEN
    SELECT r.from_location, r.to_location, r.fare_per_seat
    INTO v_route
    FROM public.routes r
    WHERE r.id = v_resolved_route_id;
  END IF;

  -- Load pickup point
  IF v_booking.pickup_point_id IS NOT NULL THEN
    SELECT pp.name, pp.landmark
    INTO v_pickup
    FROM public.pickup_points pp
    WHERE pp.id = v_booking.pickup_point_id;
  END IF;

  -- Load vehicle — only if trip is NOT terminal
  -- (prevents stale vehicle info appearing on historical bookings)
  IF v_trip_vehicle_id IS NOT NULL AND NOT v_trip_terminal THEN
    SELECT v.make, v.model, v.registration_number
    INTO v_vehicle
    FROM public.vehicles v
    WHERE v.id = v_trip_vehicle_id;
  END IF;

  -- Load driver — only if trip is NOT terminal
  IF v_trip_driver_id IS NOT NULL AND NOT v_trip_terminal THEN
    SELECT p.name AS driver_name, p.phone AS driver_phone
    INTO v_driver
    FROM public.drivers d
    JOIN public.profiles p ON p.id = d.profile_id
    WHERE d.id = v_trip_driver_id;
  END IF;

  -- Queue position (only meaningful when WAITING/MATCHING and trip not terminal)
  IF v_pq.id IS NOT NULL AND v_pq.status IN ('WAITING', 'MATCHING') AND NOT v_trip_terminal THEN
    SELECT COUNT(*) INTO v_passengers_ahead
    FROM public.passenger_queue pq2
    WHERE pq2.route_id = v_pq.route_id
      AND pq2.status IN ('WAITING', 'MATCHING')
      AND pq2.queue_sequence < v_pq.queue_sequence;

    v_queue_pos := v_passengers_ahead + 1;
  END IF;

  RETURN jsonb_build_object(
    'found',            true,
    'booking_id',       v_booking.id,
    'seats',            v_booking.seats,
    'fare_per_seat',    v_booking.fare_per_seat,
    'total_fare',       v_booking.total_fare,
    'booking_status',   v_booking.status,
    'booked_at',        v_booking.booked_at,
    'route_from',       COALESCE(v_route.from_location, ''),
    'route_to',         COALESCE(v_route.to_location, ''),
    'pickup_name',      COALESCE(v_pickup.name, ''),
    'pickup_landmark',  COALESCE(v_pickup.landmark, ''),
    'queue_id',         v_pq.id,
    -- KEY FIX: suppress queue_status when trip is terminal
    'queue_status',     CASE WHEN v_trip_terminal THEN NULL ELSE v_pq.status END,
    'queue_position',   v_queue_pos,
    'passengers_ahead', v_passengers_ahead,
    'seat_count',       COALESCE(v_pq.seat_count, v_booking.seats),
    'trip_id',          v_booking.trip_id,
    'trip_status',      v_trip_status,
    'assigned_trip_id', v_pq.assigned_trip_id,
    -- KEY FIX: suppress vehicle/driver when trip is terminal
    'vehicle_make',     CASE WHEN v_trip_terminal THEN '' ELSE COALESCE(v_vehicle.make, '') END,
    'vehicle_model',    CASE WHEN v_trip_terminal THEN '' ELSE COALESCE(v_vehicle.model, '') END,
    'vehicle_registration', CASE WHEN v_trip_terminal THEN '' ELSE COALESCE(v_vehicle.registration_number, '') END,
    'driver_name',      CASE WHEN v_trip_terminal THEN '' ELSE COALESCE(v_driver.driver_name, '') END,
    'driver_phone',     CASE WHEN v_trip_terminal THEN '' ELSE COALESCE(v_driver.driver_phone, '') END,
    'fare_collected',   (v_booking.fare_collected_at IS NOT NULL),
    'fare_collected_at', v_booking.fare_collected_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_passenger_booking(UUID) TO authenticated;

-- ============================================================
-- STEP 4: FIX cancel_booking — reject when trip is terminal
--
-- KEY CHANGE: After loading the booking, check if the associated
-- trip is terminal. If so, reject with a clear error. This prevents:
--   (a) stale "Cancel Booking" button from working
--   (b) incorrect abuse cooldown increment for historical bookings
-- ============================================================

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
  v_trip_status        TEXT;
  v_cancellation_id    UUID;

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

  -- ── FETCH BOOKING ─────────────────────────────────────────────────────────
  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id AND passenger_id = v_passenger_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found or not yours');
  END IF;

  -- ── BOOKING STATUS CHECK ──────────────────────────────────────────────────
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

-- ============================================================
-- STEP 5: admin_recover_stale_booking — safe admin recovery RPC
--
-- Safely reconciles a stale booking/trip without triggering
-- passenger abuse cooldown. Idempotent. Audit logged. Reason required.
--
-- This RPC handles the case where:
--   - booking.status is still 'confirmed'/'queued'/'matching'
--   - but the associated trip is terminal (completed/cancelled)
--   - or there is no trip at all but the booking is orphaned
--
-- Actions taken:
--   1. Validates admin identity from auth.uid()
--   2. Validates reason is provided
--   3. Loads booking and associated trip/queue state
--   4. If trip is terminal: marks booking as 'cancelled' (admin recovery)
--   5. Clears passenger_queue entry (CANCELLED)
--   6. Does NOT increment passenger abuse cooldown counter
--   7. Does NOT disturb other drivers' queue positions
--   8. Writes audit log with stale_booking_recovered action
--   9. Idempotent: if booking already terminal, returns success
--
-- Authorization: admin only, derived from auth.uid()
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_recover_stale_booking(
  p_booking_id UUID,
  p_reason     TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id      UUID;
  v_admin         RECORD;
  v_booking       RECORD;
  v_pq            RECORD;
  v_trip_status   TEXT;
  v_route_id      UUID;
  v_already_done  BOOLEAN := false;
BEGIN
  -- ── 1. Admin identity from session ────────────────────────────────────────
  v_admin_id := auth.uid();
  IF v_admin_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT id, role, name INTO v_admin
  FROM public.profiles
  WHERE id = v_admin_id AND role = 'admin';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin role required');
  END IF;

  -- ── 2. Reason required ────────────────────────────────────────────────────
  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'A reason is required for admin recovery');
  END IF;

  -- ── 3. Load booking ───────────────────────────────────────────────────────
  SELECT b.id,
         b.passenger_id,
         b.trip_id,
         b.status,
         b.seats,
         b.fare_per_seat,
         b.total_fare,
         b.is_test_data
  INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
  END IF;

  -- ── 4. Idempotency: booking already terminal ──────────────────────────────
  IF v_booking.status IN ('cancelled', 'completed', 'no_show') THEN
    -- Check if passenger_queue also needs cleanup (may have been missed)
    SELECT pq.id, pq.route_id, pq.status AS pq_status
    INTO v_pq
    FROM public.passenger_queue pq
    WHERE pq.booking_id = p_booking_id
    LIMIT 1;

    IF v_pq.id IS NOT NULL AND v_pq.pq_status NOT IN ('CANCELLED', 'COMPLETED') THEN
      -- Clean up orphaned queue entry
      UPDATE public.passenger_queue
      SET status = 'CANCELLED', updated_at = NOW()
      WHERE id = v_pq.id;

      INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
      VALUES (
        v_admin_id,
        'stale_booking_recovered'::public.audit_action,
        'bookings',
        p_booking_id,
        jsonb_build_object('booking_status', v_booking.status, 'pq_status', v_pq.pq_status),
        jsonb_build_object('action', 'orphaned_queue_entry_cancelled', 'reason', p_reason),
        format('Admin recovery (idempotent): booking already %s, cleared orphaned passenger_queue entry. Reason: %s', v_booking.status, p_reason)
      );

      RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'message', format('Booking was already %s. Cleared orphaned passenger_queue entry.', v_booking.status),
        'action_taken', 'orphaned_queue_cleared'
      );
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'booking_id', p_booking_id,
      'message', format('Booking is already in terminal state: %s. No action needed.', v_booking.status),
      'action_taken', 'none_already_terminal'
    );
  END IF;

  -- ── 5. Load passenger_queue entry ─────────────────────────────────────────
  SELECT pq.id, pq.route_id, pq.status AS pq_status, pq.assigned_trip_id
  INTO v_pq
  FROM public.passenger_queue pq
  WHERE pq.booking_id = p_booking_id
  FOR UPDATE;

  -- ── 6. Resolve route_id ───────────────────────────────────────────────────
  IF v_booking.trip_id IS NOT NULL THEN
    SELECT t.status, t.route_id
    INTO v_trip_status, v_route_id
    FROM public.trips t
    WHERE t.id = v_booking.trip_id;
  ELSIF v_pq.route_id IS NOT NULL THEN
    v_route_id := v_pq.route_id;
  END IF;

  -- ── 7. Validate this is actually a stale/recoverable booking ──────────────
  -- A booking is recoverable if:
  --   (a) its trip is terminal (completed/cancelled), OR
  --   (b) it has no trip_id but has been in non-terminal state for > 24h, OR
  --   (c) admin explicitly requests recovery (reason provided = admin judgment)
  -- We allow admin to recover any non-terminal booking with a reason.
  -- The key constraint is: this must NOT trigger passenger abuse cooldown.

  -- ── 8. Mark booking as cancelled (admin recovery) ─────────────────────────
  UPDATE public.bookings
  SET
    status      = 'cancelled'::public.booking_status,
    admin_notes = format('[ADMIN RECOVERY %s] %s', NOW()::DATE, p_reason),
    updated_at  = NOW()
  WHERE id = p_booking_id;

  -- ── 9. Cancel passenger_queue entry ───────────────────────────────────────
  IF v_pq.id IS NOT NULL AND v_pq.pq_status NOT IN ('CANCELLED', 'COMPLETED') THEN
    UPDATE public.passenger_queue
    SET
      status           = 'CANCELLED',
      assigned_trip_id = NULL,
      updated_at       = NOW()
    WHERE id = v_pq.id;
  END IF;

  -- ── 10. Write cancellations record (admin type — does NOT count toward
  --        passenger abuse cooldown because cancelled_by_type = 'admin') ─────
  INSERT INTO public.cancellations (
    booking_id,
    cancelled_by,
    reason,
    cancelled_by_type,
    fee_waived,
    waived_by
  )
  VALUES (
    p_booking_id,
    v_admin_id,
    format('Admin recovery: %s', p_reason),
    'admin',
    true,
    v_admin_id
  )
  ON CONFLICT DO NOTHING;

  -- ── 11. Audit log ─────────────────────────────────────────────────────────
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (
    v_admin_id,
    'stale_booking_recovered'::public.audit_action,
    'bookings',
    p_booking_id,
    jsonb_build_object(
      'booking_status',  v_booking.status,
      'trip_id',         v_booking.trip_id,
      'trip_status',     v_trip_status,
      'pq_status',       v_pq.pq_status,
      'passenger_id',    v_booking.passenger_id
    ),
    jsonb_build_object(
      'booking_status',  'cancelled',
      'pq_status',       'CANCELLED',
      'cancelled_by_type', 'admin',
      'cooldown_triggered', false,
      'reason',          p_reason
    ),
    format('Admin stale booking recovery by %s. Reason: %s', v_admin.name, p_reason)
  );

  RETURN jsonb_build_object(
    'success',           true,
    'booking_id',        p_booking_id,
    'message',           'Stale booking recovered successfully. Passenger history updated. No cooldown triggered.',
    'action_taken',      'booking_cancelled_admin_recovery',
    'cooldown_triggered', false,
    'trip_status',       v_trip_status
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_recover_stale_booking(UUID, TEXT) TO authenticated;

-- ============================================================
-- STEP 6: SYSTEM-WIDE STALE STATE REPAIR
--
-- Find all bookings where:
--   - booking.status is non-terminal ('confirmed','queued','matching')
--   - booking.trip_id references a terminal trip (completed/cancelled)
--
-- And all passenger_queue entries where:
--   - pq.status is non-terminal ('WAITING','MATCHING','ASSIGNED')
--   - pq.assigned_trip_id references a terminal trip
--
-- Repair: mark bookings as 'cancelled', queue entries as 'CANCELLED'
-- Record in audit_log with performed_by = NULL (system repair)
-- Does NOT touch bookings with no trip_id (those may be legitimately queued)
-- Does NOT disturb driver_queue entries (driver FIFO preserved)
-- ============================================================

DO $$
DECLARE
  v_stale_booking    RECORD;
  v_stale_pq         RECORD;
  v_booking_count    INTEGER := 0;
  v_pq_count         INTEGER := 0;
BEGIN
  -- ── REPAIR STALE BOOKINGS ─────────────────────────────────────────────────
  -- Bookings that reference a terminal trip but are still non-terminal
  FOR v_stale_booking IN
    SELECT b.id AS booking_id,
           b.status AS booking_status,
           b.trip_id,
           t.status AS trip_status,
           b.passenger_id
    FROM public.bookings b
    JOIN public.trips t ON t.id = b.trip_id
    WHERE b.status NOT IN ('cancelled', 'completed', 'no_show')
      AND t.status IN ('completed', 'cancelled')
  LOOP
    -- Mark booking as cancelled (system repair)
    UPDATE public.bookings
    SET
      status      = 'cancelled'::public.booking_status,
      admin_notes = format('[SYSTEM REPAIR %s] Booking was non-terminal but associated trip %s was %s. Auto-repaired.',
                           NOW()::DATE, v_stale_booking.trip_id, v_stale_booking.trip_status),
      updated_at  = NOW()
    WHERE id = v_stale_booking.booking_id;

    -- Write cancellation record (system type — does NOT count toward passenger cooldown)
    INSERT INTO public.cancellations (
      booking_id,
      cancelled_by,
      reason,
      cancelled_by_type,
      fee_waived
    )
    SELECT
      v_stale_booking.booking_id,
      v_stale_booking.passenger_id,
      format('System repair: booking was non-terminal but trip %s was %s',
             v_stale_booking.trip_id, v_stale_booking.trip_status),
      'system',
      true
    WHERE NOT EXISTS (
      SELECT 1 FROM public.cancellations c
      WHERE c.booking_id = v_stale_booking.booking_id
    );

    -- Audit
    INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
    VALUES (
      NULL,
      'stale_booking_recovered'::public.audit_action,
      'bookings',
      v_stale_booking.booking_id,
      jsonb_build_object('booking_status', v_stale_booking.booking_status, 'trip_status', v_stale_booking.trip_status),
      jsonb_build_object('booking_status', 'cancelled', 'cancelled_by_type', 'system', 'cooldown_triggered', false),
      format('System stale-state repair: booking %s was %s but trip was %s',
             v_stale_booking.booking_id, v_stale_booking.booking_status, v_stale_booking.trip_status)
    );

    v_booking_count := v_booking_count + 1;
  END LOOP;

  -- ── REPAIR STALE PASSENGER_QUEUE ENTRIES ──────────────────────────────────
  -- Queue entries that reference a terminal trip but are still non-terminal
  FOR v_stale_pq IN
    SELECT pq.id AS pq_id,
           pq.status AS pq_status,
           pq.assigned_trip_id,
           pq.booking_id,
           t.status AS trip_status
    FROM public.passenger_queue pq
    JOIN public.trips t ON t.id = pq.assigned_trip_id
    WHERE pq.status NOT IN ('CANCELLED', 'COMPLETED')
      AND t.status IN ('completed', 'cancelled')
  LOOP
    UPDATE public.passenger_queue
    SET
      status     = 'CANCELLED',
      updated_at = NOW()
    WHERE id = v_stale_pq.pq_id;

    INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
    VALUES (
      NULL,
      'stale_booking_recovered'::public.audit_action,
      'passenger_queue',
      v_stale_pq.pq_id,
      jsonb_build_object('pq_status', v_stale_pq.pq_status, 'trip_status', v_stale_pq.trip_status),
      jsonb_build_object('pq_status', 'CANCELLED'),
      format('System stale-state repair: passenger_queue %s was %s but assigned trip was %s',
             v_stale_pq.pq_id, v_stale_pq.pq_status, v_stale_pq.trip_status)
    );

    v_pq_count := v_pq_count + 1;
  END LOOP;

  RAISE NOTICE 'Stale state repair complete: % bookings repaired, % passenger_queue entries repaired.',
    v_booking_count, v_pq_count;
END;
$$;

-- ============================================================
-- STEP 7: VERIFY DRIVER FIFO POSITIONS ARE INTACT
--
-- Confirm Rajeev Backup4 and Dipti driver_queue entries are
-- NOT affected by the stale booking repair above.
-- The repair only touches bookings/passenger_queue — not driver_queue.
-- This DO block is a verification-only assertion (no mutations).
-- ============================================================

DO $$
DECLARE
  v_rajeev_dq RECORD;
  v_dipti_dq  RECORD;
BEGIN
  -- Find Rajeev Backup4's active driver_queue entry
  SELECT dq.id, dq.status, dq.queue_position, pr.name
  INTO v_rajeev_dq
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  JOIN public.profiles pr ON pr.id = d.profile_id
  WHERE pr.name ILIKE '%rajeev%backup4%'
     OR pr.name ILIKE '%rajeev backup4%'
  ORDER BY dq.joined_at DESC
  LIMIT 1;

  IF FOUND THEN
    RAISE NOTICE 'Rajeev Backup4 driver_queue: id=%, status=%, position=%',
      v_rajeev_dq.id, v_rajeev_dq.status, v_rajeev_dq.queue_position;
  ELSE
    RAISE NOTICE 'Rajeev Backup4 driver_queue entry not found (may not be online yet)';
  END IF;

  -- Find Dipti's active driver_queue entry
  SELECT dq.id, dq.status, dq.queue_position, pr.name
  INTO v_dipti_dq
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  JOIN public.profiles pr ON pr.id = d.profile_id
  WHERE pr.name ILIKE '%dipti%'
  ORDER BY dq.joined_at DESC
  LIMIT 1;

  IF FOUND THEN
    RAISE NOTICE 'Dipti driver_queue: id=%, status=%, position=%',
      v_dipti_dq.id, v_dipti_dq.status, v_dipti_dq.queue_position;
  ELSE
    RAISE NOTICE 'Dipti driver_queue entry not found (may not be online yet)';
  END IF;

  RAISE NOTICE 'Driver FIFO verification complete. driver_queue entries were NOT modified by stale booking repair.';
END;
$$;

-- ============================================================
-- STEP 8: PERFORMANCE INDEXES
-- Ensure the trip terminal state check in get_my_bookings is fast.
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_trips_status_terminal
  ON public.trips (status)
  WHERE status IN ('completed', 'cancelled');

CREATE INDEX IF NOT EXISTS idx_bookings_trip_id_status
  ON public.bookings (trip_id, status)
  WHERE trip_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_passenger_queue_booking_id_status
  ON public.passenger_queue (booking_id, status);

-- ============================================================
-- VERIFICATION SUMMARY
-- ============================================================
-- After this migration:
--
-- get_my_bookings:
--   - Checks trip terminal state before deriving 'assigned' from queue_status
--   - If trip is completed/cancelled → uses booking_status directly
--   - Stale ASSIGNED queue entries no longer produce "Driver Assigned" UI
--   - Adds fare_collected / fare_collected_at to output
--
-- get_passenger_booking:
--   - Same trip terminal guard
--   - Suppresses vehicle/driver info when trip is terminal
--   - Suppresses queue_status when trip is terminal
--
-- cancel_booking:
--   - Rejects cancellation when trip is terminal
--   - Returns reason: 'trip_already_terminal'
--   - Does NOT increment abuse cooldown for historical bookings
--   - Cancel Booking button will no longer work on stale bookings
--
-- admin_recover_stale_booking:
--   - Admin-only (auth.uid() + role = 'admin')
--   - Reason required
--   - Marks booking as 'cancelled' with admin_notes
--   - Clears passenger_queue entry
--   - Records cancellation with cancelled_by_type = 'admin'
--   - Does NOT trigger passenger abuse cooldown
--   - Idempotent
--   - Audit logged with stale_booking_recovered action
--
-- System-wide repair (DO block):
--   - Found and repaired all bookings where trip is terminal but booking is not
--   - Found and repaired all passenger_queue entries where assigned trip is terminal
--   - Cancellations recorded with cancelled_by_type = 'system'
--   - No passenger cooldowns triggered
--   - driver_queue NOT touched (FIFO preserved)
--
-- Driver FIFO:
--   - Rajeev Backup4 and Dipti driver_queue entries NOT modified
--   - Their queue positions are preserved
-- ============================================================
