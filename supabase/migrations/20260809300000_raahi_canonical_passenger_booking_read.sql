-- ============================================================
-- RAAHI — Canonical Passenger Booking Read Model
-- Migration: 20260809300000_raahi_canonical_passenger_booking_read.sql
-- ============================================================
--
-- ROOT CAUSE (PGRST200):
--   bookings has NO route_id column.
--   Client code was doing .from('bookings').select('route:routes(...)')
--   which PostgREST tried to resolve as a direct bookings→routes FK — none exists.
--
-- CORRECT ROUTE RESOLUTION:
--   QUEUED booking  (trip_id IS NULL):
--     bookings → passenger_queue (via passenger_queue.booking_id)
--              → passenger_queue.route_id → routes
--   ASSIGNED booking (trip_id IS NOT NULL):
--     bookings.trip_id → trips.route_id → routes
--
-- SOLUTION:
--   Two SECURITY DEFINER RPCs that use auth.uid() and perform the
--   correct multi-step joins in SQL — no invalid PostgREST relationships.
--
--   1. get_passenger_booking(p_booking_id UUID)
--      Returns full details for ONE booking (for BookingConfirmationContent).
--
--   2. get_my_bookings()
--      Returns all bookings for the authenticated passenger (for MyBookingsContent).
-- ============================================================

-- ============================================================
-- 1. get_passenger_booking — single booking detail
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

  -- Load passenger_queue entry for this booking (may not exist for direct-trip bookings)
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
    -- Route (resolved correctly)
    'route_from',       COALESCE(v_route.from_location, ''),
    'route_to',         COALESCE(v_route.to_location, ''),
    -- Pickup
    'pickup_name',      COALESCE(v_pickup.name, ''),
    'pickup_landmark',  COALESCE(v_pickup.landmark, ''),
    -- Queue state
    'queue_id',         v_pq.id,
    'queue_status',     v_pq.status,
    'queue_position',   v_queue_pos,
    'passengers_ahead', v_passengers_ahead,
    'seat_count',       COALESCE(v_pq.seat_count, v_booking.seats),
    -- Trip / assignment state
    'trip_id',          v_booking.trip_id,
    'trip_status',      v_trip.trip_status,
    'assigned_trip_id', v_pq.assigned_trip_id,
    -- Vehicle
    'vehicle_make',     COALESCE(v_vehicle.make, ''),
    'vehicle_model',    COALESCE(v_vehicle.model, ''),
    'vehicle_registration', COALESCE(v_vehicle.registration_number, ''),
    -- Driver
    'driver_name',      COALESCE(v_driver.driver_name, ''),
    'driver_phone',     COALESCE(v_driver.driver_phone, '')
  );
END;
$$;

-- ============================================================
-- 2. get_my_bookings — list of all bookings for the passenger
-- ============================================================
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
    -- Determine display status: prefer queue status for active queue entries
    DECLARE
      v_display_status TEXT;
    BEGIN
      IF v_row.queue_status IS NOT NULL
         AND v_row.queue_status NOT IN ('CANCELLED', 'COMPLETED')
         AND v_row.booking_status NOT IN ('cancelled', 'completed', 'no_show')
      THEN
        -- Map queue status to user-friendly booking status
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
    END;
  END LOOP;

  -- Convert array to JSON array
  SELECT jsonb_agg(elem) INTO v_result
  FROM unnest(v_items) AS elem;

  RETURN jsonb_build_object(
    'bookings', COALESCE(v_result, '[]'::JSONB)
  );
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.get_passenger_booking(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_bookings() TO authenticated;
