-- ============================================================
-- RAAHI — Safe Admin Booking Cancellation + Passenger Read Fix
-- Migration: 20260809310000_raahi_admin_cancel_booking_safe.sql
-- ============================================================
--
-- PART A: Re-deploy get_passenger_booking and get_my_bookings
--   (already in 300000 but re-applied here to ensure latest version
--    is active after any re-apply scenarios)
--
-- PART B: New admin_cancel_booking RPC
--   - Derives admin identity from auth.uid() — no caller-supplied admin ID
--   - Handles: queued, matching, confirmed booking statuses
--   - Cancels booking + passenger_queue entry
--   - Recalculates trip.booked_seats for assigned bookings
--   - Calls check_departure_eligibility_on_cancel if trip was departure_pending
--   - Writes full audit log with performed_by = admin profile id
--   - Writes cancellations record (no fee during testing phase)
--   - Idempotent: safe to call twice on same booking
--   - Rejects: completed, already-cancelled, in_progress trips
--   - Rejects: non-admin callers server-side
-- ============================================================

-- ============================================================
-- PART A: Re-deploy passenger read RPCs (idempotent)
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
  v_passenger_id UUID;
  v_booking      RECORD;
  v_pq           RECORD;
  v_route        RECORD;
  v_trip         RECORD;
  v_pickup       RECORD;
  v_vehicle      RECORD;
  v_driver       RECORD;
  v_queue_pos    BIGINT;
  v_passengers_ahead BIGINT;
  v_resolved_route_id UUID;
BEGIN
  -- Identity: always from session
  v_passenger_id := auth.uid();
  IF v_passenger_id IS NULL THEN
    RETURN jsonb_build_object('found', false, 'error', 'Not authenticated');
  END IF;

  -- Load booking — must belong to this passenger
  SELECT b.id,
         b.passenger_id,
         b.trip_id,
         b.pickup_point_id,
         b.seats,
         b.fare_per_seat,
         b.total_fare,
         b.status,
         b.booked_at
  INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id
    AND b.passenger_id = v_passenger_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false, 'error', 'Booking not found');
  END IF;

  -- Load passenger_queue entry for this booking
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

  -- Resolve route_id: prefer trip route, fall back to queue route
  IF v_booking.trip_id IS NOT NULL THEN
    SELECT t.route_id, t.status AS trip_status,
           t.total_seats, t.booked_seats,
           t.vehicle_id, t.driver_id
    INTO v_trip
    FROM public.trips t
    WHERE t.id = v_booking.trip_id;
    v_resolved_route_id := v_trip.route_id;
  ELSIF v_pq.route_id IS NOT NULL THEN
    v_resolved_route_id := v_pq.route_id;
  ELSE
    v_resolved_route_id := NULL;
  END IF;

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

  -- Load vehicle (from trip if assigned)
  IF v_trip.vehicle_id IS NOT NULL THEN
    SELECT v.make, v.model, v.registration_number
    INTO v_vehicle
    FROM public.vehicles v
    WHERE v.id = v_trip.vehicle_id;
  END IF;

  -- Load driver name (from trip if assigned)
  IF v_trip.driver_id IS NOT NULL THEN
    SELECT p.name AS driver_name, p.phone AS driver_phone
    INTO v_driver
    FROM public.drivers d
    JOIN public.profiles p ON p.id = d.profile_id
    WHERE d.id = v_trip.driver_id;
  END IF;

  -- Queue position (only meaningful when WAITING/MATCHING)
  IF v_pq.id IS NOT NULL AND v_pq.status IN ('WAITING', 'MATCHING') THEN
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
    'queue_status',     v_pq.status,
    'queue_position',   v_queue_pos,
    'passengers_ahead', v_passengers_ahead,
    'seat_count',       COALESCE(v_pq.seat_count, v_booking.seats),
    'trip_id',          v_booking.trip_id,
    'trip_status',      v_trip.trip_status,
    'assigned_trip_id', v_pq.assigned_trip_id,
    'vehicle_make',     COALESCE(v_vehicle.make, ''),
    'vehicle_model',    COALESCE(v_vehicle.model, ''),
    'vehicle_registration', COALESCE(v_vehicle.registration_number, ''),
    'driver_name',      COALESCE(v_driver.driver_name, ''),
    'driver_phone',     COALESCE(v_driver.driver_phone, '')
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_bookings()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_passenger_id UUID;
  v_result       JSONB := '[]'::JSONB;
  v_row          RECORD;
  v_item         JSONB;
  v_items        JSONB[] := ARRAY[]::JSONB[];
  v_display_status TEXT;
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
      pp.name                       AS pickup_name,
      pq.id                         AS queue_id,
      pq.route_id                   AS pq_route_id,
      pq.status                     AS queue_status,
      pq.seat_count,
      pq.assigned_trip_id,
      t.route_id                    AS trip_route_id,
      t.status                      AS trip_status,
      t.vehicle_id,
      COALESCE(rt.from_location, rq.from_location, '') AS route_from,
      COALESCE(rt.to_location,   rq.to_location,   '') AS route_to,
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
    -- Determine display status
    IF v_row.queue_status IS NOT NULL
       AND v_row.queue_status NOT IN ('CANCELLED', 'COMPLETED')
       AND v_row.booking_status NOT IN ('cancelled', 'completed', 'no_show')
    THEN
      v_display_status := CASE v_row.queue_status
        WHEN 'WAITING'   THEN 'queued'
        WHEN 'MATCHING'  THEN 'matching'
        WHEN 'ASSIGNED'  THEN 'assigned'
        ELSE v_row.booking_status
      END;
    ELSE
      v_display_status := v_row.booking_status;
    END IF;

    v_item := jsonb_build_object(
      'id',             v_row.booking_id,
      'seats',          v_row.seats,
      'fare_per_seat',  v_row.fare_per_seat,
      'total_fare',     v_row.total_fare,
      'status',         v_display_status,
      'booking_status', v_row.booking_status,
      'queue_status',   COALESCE(v_row.queue_status, ''),
      'booked_at',      v_row.booked_at,
      'pickup_name',    COALESCE(v_row.pickup_name, ''),
      'route_from',     v_row.route_from,
      'route_to',       v_row.route_to,
      'trip_id',        v_row.trip_id,
      'trip_status',    COALESCE(v_row.trip_status, ''),
      'vehicle_make',   COALESCE(v_row.vehicle_make, ''),
      'vehicle_model',  COALESCE(v_row.vehicle_model, '')
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

-- ============================================================
-- PART B: admin_cancel_booking — safe, auth.uid()-based
-- ============================================================
-- Drops the old signature (p_admin_id, p_booking_id, p_reason)
-- and replaces with (p_booking_id, p_reason) — admin identity
-- derived server-side from auth.uid().
-- ============================================================

-- Drop old signature that accepted caller-supplied p_admin_id
DROP FUNCTION IF EXISTS public.admin_cancel_booking(UUID, UUID, TEXT);

CREATE OR REPLACE FUNCTION public.admin_cancel_booking(
  p_booking_id UUID,
  p_reason     TEXT DEFAULT 'Admin cancelled'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id       UUID;
  v_admin_profile  RECORD;
  v_booking        RECORD;
  v_pq             RECORD;
  v_trip           RECORD;
  v_route_id       UUID;
  v_route_from     TEXT;
  v_route_to       TEXT;
  v_prev_status    TEXT;
BEGIN
  -- ── 1. Derive admin identity from session ──────────────────
  v_admin_id := auth.uid();
  IF v_admin_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT id, role, name
  INTO v_admin_profile
  FROM public.profiles
  WHERE id = v_admin_id AND role = 'admin';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin role required');
  END IF;

  -- ── 2. Load booking with FOR UPDATE lock ──────────────────
  SELECT b.id,
         b.passenger_id,
         b.trip_id,
         b.pickup_point_id,
         b.seats,
         b.fare_per_seat,
         b.total_fare,
         b.status
  INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
  END IF;

  v_prev_status := v_booking.status;

  -- ── 3. Idempotency: already cancelled ─────────────────────
  IF v_booking.status = 'cancelled' THEN
    RETURN jsonb_build_object(
      'success', true,
      'booking_id', p_booking_id,
      'message', 'Booking was already cancelled (idempotent)'
    );
  END IF;

  -- ── 4. Reject terminal states ─────────────────────────────
  IF v_booking.status IN ('completed', 'no_show') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Cannot cancel a ' || v_booking.status || ' booking'
    );
  END IF;

  -- ── 5. Load passenger_queue entry (may be null) ───────────
  SELECT pq.id,
         pq.route_id,
         pq.status AS pq_status,
         pq.assigned_trip_id,
         pq.seat_count
  INTO v_pq
  FROM public.passenger_queue pq
  WHERE pq.booking_id = p_booking_id
  FOR UPDATE;

  -- ── 6. Resolve route for audit log ────────────────────────
  IF v_booking.trip_id IS NOT NULL THEN
    SELECT t.route_id, t.status, t.booked_seats, t.total_seats
    INTO v_trip
    FROM public.trips t
    WHERE t.id = v_booking.trip_id
    FOR UPDATE;
    v_route_id := v_trip.route_id;
  ELSIF v_pq.route_id IS NOT NULL THEN
    v_route_id := v_pq.route_id;
  END IF;

  IF v_route_id IS NOT NULL THEN
    SELECT from_location, to_location
    INTO v_route_from, v_route_to
    FROM public.routes
    WHERE id = v_route_id;
  END IF;

  -- ── 7. Reject in_progress trip cancellation ───────────────
  IF v_trip.status = 'in_progress' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Cannot cancel booking while trip is in progress'
    );
  END IF;

  -- ── 8. Cancel the booking ─────────────────────────────────
  UPDATE public.bookings
  SET status     = 'cancelled',
      admin_notes = COALESCE(p_reason, 'Admin cancelled'),
      updated_at  = NOW()
  WHERE id = p_booking_id;

  -- ── 9. Cancel passenger_queue entry ───────────────────────
  IF v_pq.id IS NOT NULL AND v_pq.pq_status NOT IN ('CANCELLED', 'COMPLETED') THEN
    UPDATE public.passenger_queue
    SET status     = 'CANCELLED',
        updated_at = NOW()
    WHERE id = v_pq.id;
  END IF;

  -- ── 10. Recalculate trip.booked_seats ─────────────────────
  --   Only if booking was linked to a trip and trip is not terminal
  IF v_booking.trip_id IS NOT NULL
     AND v_trip.status NOT IN ('completed', 'cancelled', 'in_progress')
  THEN
    UPDATE public.trips
    SET booked_seats = GREATEST(0, booked_seats - v_booking.seats),
        -- If trip was full/ready, revert to boarding so new passengers can join
        status = CASE
          WHEN status IN ('full', 'ready', 'departure_pending') THEN 'boarding'
          ELSE status
        END,
        updated_at = NOW()
    WHERE id = v_booking.trip_id;

    -- ── 11. Recheck departure eligibility ─────────────────
    PERFORM public.check_departure_eligibility_on_cancel(v_booking.trip_id);
  END IF;

  -- ── 12. Write cancellations record (no fee during testing) ─
  INSERT INTO public.cancellations (
    booking_id,
    cancelled_by,
    reason,
    cancellation_fee,
    fee_waived,
    waived_by,
    status
  ) VALUES (
    p_booking_id,
    v_admin_id,
    COALESCE(p_reason, 'Admin cancelled'),
    0,
    true,
    v_admin_id,
    'waived'
  )
  ON CONFLICT DO NOTHING;

  -- ── 13. Audit log ─────────────────────────────────────────
  INSERT INTO public.audit_logs (
    performed_by,
    action,
    target_table,
    target_id,
    old_value,
    new_value,
    notes
  ) VALUES (
    v_admin_id,
    'booking_cancelled'::public.audit_action,
    'bookings',
    p_booking_id,
    jsonb_build_object(
      'booking_status',   v_prev_status,
      'passenger_id',     v_booking.passenger_id,
      'trip_id',          v_booking.trip_id,
      'route',            COALESCE(v_route_from || ' → ' || v_route_to, ''),
      'seats',            v_booking.seats,
      'fare',             v_booking.total_fare
    ),
    jsonb_build_object(
      'booking_status',   'cancelled',
      'cancelled_by',     'admin',
      'admin_id',         v_admin_id,
      'admin_name',       v_admin_profile.name,
      'reason',           COALESCE(p_reason, 'Admin cancelled'),
      'trip_id',          v_booking.trip_id,
      'route',            COALESCE(v_route_from || ' → ' || v_route_to, '')
    ),
    COALESCE(p_reason, 'Admin cancelled booking')
  );

  RETURN jsonb_build_object(
    'success',          true,
    'booking_id',       p_booking_id,
    'previous_status',  v_prev_status,
    'passenger_id',     v_booking.passenger_id,
    'route',            COALESCE(v_route_from || ' → ' || v_route_to, ''),
    'message',          'Booking cancelled successfully'
  );
END;
$$;

-- ============================================================
-- PART C: get_admin_bookings — admin read with queued route resolution
-- ============================================================
-- Returns all bookings with route resolved via:
--   - trip.route_id for assigned bookings
--   - passenger_queue.route_id for queued bookings
-- Used by AdminBookingsContent to avoid the PGRST200 error
-- and to show route for queued bookings.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_admin_bookings(
  p_limit  INTEGER DEFAULT 200,
  p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_items    JSONB[] := ARRAY[]::JSONB[];
  v_result   JSONB;
  v_row      RECORD;
BEGIN
  -- Verify admin
  v_admin_id := auth.uid();
  IF v_admin_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Not authenticated', 'bookings', '[]'::JSONB);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = v_admin_id AND role = 'admin'
  ) THEN
    RETURN jsonb_build_object('error', 'Unauthorized', 'bookings', '[]'::JSONB);
  END IF;

  FOR v_row IN
    SELECT
      b.id                                              AS booking_id,
      b.passenger_id,
      b.trip_id,
      b.pickup_point_id,
      b.seats,
      b.fare_per_seat,
      b.total_fare,
      b.status                                          AS booking_status,
      b.traveler_name,
      b.traveler_phone,
      b.admin_notes,
      b.no_show_fee,
      b.created_at,
      -- Passenger
      pass.name                                         AS passenger_name,
      pass.phone                                        AS passenger_phone,
      pass.email                                        AS passenger_email,
      -- Pickup
      pp.name                                           AS pickup_name,
      -- Queue entry
      pq.id                                             AS queue_id,
      pq.route_id                                       AS pq_route_id,
      pq.status                                         AS queue_status,
      pq.seat_count,
      -- Trip
      t.id                                              AS trip_id_val,
      t.status                                          AS trip_status,
      t.route_id                                        AS trip_route_id,
      t.vehicle_id,
      t.driver_id,
      -- Route: prefer trip route, fall back to queue route
      COALESCE(rt.from_location, rq.from_location, '') AS route_from,
      COALESCE(rt.to_location,   rq.to_location,   '') AS route_to,
      -- Vehicle
      v.make                                            AS vehicle_make,
      v.model                                           AS vehicle_model,
      v.registration_number                             AS vehicle_reg,
      -- Driver
      dp.name                                           AS driver_name
    FROM public.bookings b
    LEFT JOIN public.profiles pass ON pass.id = b.passenger_id
    LEFT JOIN public.pickup_points pp ON pp.id = b.pickup_point_id
    LEFT JOIN public.passenger_queue pq ON pq.booking_id = b.id
    LEFT JOIN public.trips t ON t.id = b.trip_id
    LEFT JOIN public.routes rt ON rt.id = t.route_id
    LEFT JOIN public.routes rq ON rq.id = pq.route_id
    LEFT JOIN public.vehicles v ON v.id = t.vehicle_id
    LEFT JOIN public.drivers d ON d.id = t.driver_id
    LEFT JOIN public.profiles dp ON dp.id = d.profile_id
    ORDER BY b.created_at DESC
    LIMIT p_limit OFFSET p_offset
  LOOP
    v_items := array_append(v_items, jsonb_build_object(
      'id',              v_row.booking_id,
      'passenger_id',    v_row.passenger_id,
      'trip_id',         v_row.trip_id,
      'pickup_point_id', v_row.pickup_point_id,
      'seats',           v_row.seats,
      'fare_per_seat',   v_row.fare_per_seat,
      'total_fare',      v_row.total_fare,
      'status',          v_row.booking_status,
      'traveler_name',   v_row.traveler_name,
      'traveler_phone',  v_row.traveler_phone,
      'admin_notes',     v_row.admin_notes,
      'no_show_fee',     v_row.no_show_fee,
      'created_at',      v_row.created_at,
      'passenger_name',  COALESCE(v_row.traveler_name, v_row.passenger_name, '—'),
      'passenger_phone', COALESCE(v_row.traveler_phone, v_row.passenger_phone, '—'),
      'passenger_email', COALESCE(v_row.passenger_email, ''),
      'pickup_name',     COALESCE(v_row.pickup_name, ''),
      'queue_id',        v_row.queue_id,
      'queue_status',    v_row.queue_status,
      'route_from',      v_row.route_from,
      'route_to',        v_row.route_to,
      'trip_status',     COALESCE(v_row.trip_status, ''),
      'vehicle_make',    COALESCE(v_row.vehicle_make, ''),
      'vehicle_model',   COALESCE(v_row.vehicle_model, ''),
      'vehicle_reg',     COALESCE(v_row.vehicle_reg, ''),
      'driver_name',     COALESCE(v_row.driver_name, '')
    ));
  END LOOP;

  SELECT jsonb_agg(elem) INTO v_result
  FROM unnest(v_items) AS elem;

  RETURN jsonb_build_object(
    'bookings', COALESCE(v_result, '[]'::JSONB)
  );
END;
$$;

-- ============================================================
-- Grants
-- ============================================================
GRANT EXECUTE ON FUNCTION public.get_passenger_booking(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_bookings() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_cancel_booking(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_bookings(INTEGER, INTEGER) TO authenticated;
