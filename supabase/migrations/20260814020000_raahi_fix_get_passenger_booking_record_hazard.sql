-- ============================================================
-- RAAHI — Fix get_passenger_booking RECORD initialization hazard
-- Migration: 20260814020000_raahi_fix_get_passenger_booking_record_hazard.sql
-- ============================================================
--
-- ROOT CAUSE (PostgreSQL 55000):
--   v_vehicle RECORD and v_driver RECORD are declared but only populated
--   conditionally (when trip_vehicle_id IS NOT NULL AND NOT v_trip_terminal,
--   and trip_driver_id IS NOT NULL AND NOT v_trip_terminal respectively).
--   For a newly created booking where no vehicle/driver has been assigned yet,
--   these RECORD variables are never given tuple structure.
--   Any field access (v_vehicle.make, v_driver.driver_name, etc.) on an
--   indeterminate RECORD raises PostgreSQL error 55000 — even inside COALESCE().
--
-- FIX:
--   Replace v_vehicle RECORD and v_driver RECORD with typed scalar variables
--   initialized to NULL:
--     v_vehicle_make          TEXT := NULL;
--     v_vehicle_model         TEXT := NULL;
--     v_vehicle_registration  TEXT := NULL;
--     v_driver_name           TEXT := NULL;
--     v_driver_phone          TEXT := NULL;
--   Populate them conditionally (same guard conditions as before).
--   Build JSON from the scalars — COALESCE(scalar, '') is always safe.
--
-- SCOPE:
--   Only get_passenger_booking(uuid) is changed.
--   No other function, table, trigger, queue logic, matching, booking
--   creation, driver assignment, trip lifecycle, or frontend file is touched.
--
-- PRESERVED BEHAVIOR:
--   - Authentication / ownership check (auth.uid())
--   - Effective trip resolution (booking.trip_id COALESCE pq.assigned_trip_id)
--   - Terminal-trip suppression (v_trip_terminal guard)
--   - Route and pickup data
--   - Queue status / position
--   - Fare information (fare_collected, fare_collected_at)
--   - Assigned driver/vehicle display when available
--   - All existing JSON field names and types
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
  v_passenger_id          UUID;
  v_booking               RECORD;
  v_pq                    RECORD;
  v_route                 RECORD;
  v_trip_id               UUID;
  v_trip_status           TEXT;
  v_trip_vehicle_id       UUID;
  v_trip_driver_id        UUID;
  v_trip_route_id         UUID;
  v_pickup                RECORD;
  -- Typed scalars replacing v_vehicle RECORD and v_driver RECORD
  -- Initialized NULL so field access is always safe regardless of assignment path
  v_vehicle_make          TEXT := NULL;
  v_vehicle_model         TEXT := NULL;
  v_vehicle_registration  TEXT := NULL;
  v_driver_name           TEXT := NULL;
  v_driver_phone          TEXT := NULL;
  v_queue_pos             BIGINT;
  v_passengers_ahead      BIGINT;
  v_resolved_route_id     UUID;
  v_trip_terminal         BOOLEAN;
  v_effective_trip_id     UUID;  -- either booking.trip_id or pq.assigned_trip_id
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

  -- ── RESOLVE EFFECTIVE TRIP ID ─────────────────────────────────────────────
  -- Use booking.trip_id first; fall back to pq.assigned_trip_id.
  -- Covers the case where booking.trip_id IS NULL but
  -- pq.assigned_trip_id points to a terminal trip.
  v_effective_trip_id := COALESCE(v_booking.trip_id, v_pq.assigned_trip_id);

  -- Resolve trip scalars
  IF v_effective_trip_id IS NOT NULL THEN
    SELECT t.id, t.route_id, t.status, t.vehicle_id, t.driver_id
    INTO v_trip_id, v_trip_route_id, v_trip_status, v_trip_vehicle_id, v_trip_driver_id
    FROM public.trips t
    WHERE t.id = v_effective_trip_id;
    v_resolved_route_id := v_trip_route_id;
  ELSIF v_pq.route_id IS NOT NULL THEN
    v_resolved_route_id := v_pq.route_id;
  END IF;

  -- ── TRIP TERMINAL CHECK ───────────────────────────────────────────────────
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

  -- Load vehicle scalars — only if trip is NOT terminal
  -- Safe: scalars are already NULL-initialized; no 55000 hazard
  IF v_trip_vehicle_id IS NOT NULL AND NOT v_trip_terminal THEN
    SELECT v.make, v.model, v.registration_number
    INTO v_vehicle_make, v_vehicle_model, v_vehicle_registration
    FROM public.vehicles v
    WHERE v.id = v_trip_vehicle_id;
  END IF;

  -- Load driver scalars — only if trip is NOT terminal
  -- Safe: scalars are already NULL-initialized; no 55000 hazard
  IF v_trip_driver_id IS NOT NULL AND NOT v_trip_terminal THEN
    SELECT p.name, p.phone
    INTO v_driver_name, v_driver_phone
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
    -- Suppress queue_status when trip is terminal
    'queue_status',     CASE WHEN v_trip_terminal THEN NULL ELSE v_pq.status END,
    'queue_position',   v_queue_pos,
    'passengers_ahead', v_passengers_ahead,
    'seat_count',       COALESCE(v_pq.seat_count, v_booking.seats),
    'trip_id',          v_booking.trip_id,
    'trip_status',      v_trip_status,
    'assigned_trip_id', v_pq.assigned_trip_id,
    -- Vehicle scalars: NULL-safe, terminal-suppressed
    'vehicle_make',     CASE WHEN v_trip_terminal THEN '' ELSE COALESCE(v_vehicle_make, '') END,
    'vehicle_model',    CASE WHEN v_trip_terminal THEN '' ELSE COALESCE(v_vehicle_model, '') END,
    'vehicle_registration', CASE WHEN v_trip_terminal THEN '' ELSE COALESCE(v_vehicle_registration, '') END,
    -- Driver scalars: NULL-safe, terminal-suppressed
    'driver_name',      CASE WHEN v_trip_terminal THEN '' ELSE COALESCE(v_driver_name, '') END,
    'driver_phone',     CASE WHEN v_trip_terminal THEN '' ELSE COALESCE(v_driver_phone, '') END,
    'fare_collected',   (v_booking.fare_collected_at IS NOT NULL),
    'fare_collected_at', v_booking.fare_collected_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_passenger_booking(UUID) TO authenticated;
