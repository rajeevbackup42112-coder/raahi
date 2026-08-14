-- ============================================================
-- RAAHI — DEPARTURE ELIGIBILITY RULE
-- Migration: 20260809230000_raahi_departure_eligibility.sql
-- ============================================================
-- Changes:
-- 1. Add DEPARTURE_PENDING to trip_status enum
-- 2. Add departure_lock_seconds to business_settings
-- 3. Add departure_lock_expires_at column to trips
-- 4. Add driver_leave_now RPC — starts departure lock window
-- 5. Add driver_wait_for_more RPC — keeps vehicle open for FIFO
-- 6. check_departure_eligibility_on_cancel — revokes lock if pax cancels
-- 7. Update cancel_booking to call eligibility recheck
-- 8. Update book_or_queue to block assignment into departure_pending trips
-- 9. Update get_driver_queue_status to return departure eligibility fields
-- ============================================================

-- ============================================================
-- STEP 1: Add DEPARTURE_PENDING to trip_status enum
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumlabel = 'departure_pending'
      AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'trip_status')
  ) THEN
    ALTER TYPE public.trip_status ADD VALUE 'departure_pending';
  END IF;
END $$;

-- ============================================================
-- STEP 2: Add departure_lock_expires_at to trips
-- ============================================================

ALTER TABLE public.trips
  ADD COLUMN IF NOT EXISTS departure_lock_expires_at TIMESTAMPTZ;

-- ============================================================
-- STEP 3: Upsert departure_lock_seconds into business_settings
-- ============================================================

INSERT INTO public.business_settings (key, value, description)
VALUES (
  'departure_lock_seconds',
  '60',
  'Seconds the system waits after driver presses Leave Now before the trip can start. No new passengers are assigned during this window.'
)
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- STEP 4: driver_leave_now RPC
-- Transitions trip from boarding -> departure_pending.
-- Validates: assigned seats >= route.min_passengers.
-- Blocks new passenger assignment during lock window.
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
  v_trip_id           UUID;
  v_trip_status       public.trip_status;
  v_route_id          UUID;
  v_min_passengers    INTEGER;
  v_booked_seats      INTEGER;
  v_vehicle_capacity  INTEGER;
  v_lock_seconds      INTEGER := 60;
  v_lock_expires_at   TIMESTAMPTZ;
BEGIN
  -- Resolve driver record
  SELECT id INTO v_driver_id
  FROM public.drivers
  WHERE profile_id = p_driver_profile_id;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver not found');
  END IF;

  -- Find the active trip for this driver (boarding or departure_pending)
  SELECT t.id, t.status, t.route_id
  INTO v_trip_id, v_trip_status, v_route_id
  FROM public.trips t
  WHERE t.driver_id = v_driver_id
    AND t.status IN ('boarding', 'departure_pending')
  ORDER BY t.created_at DESC
  LIMIT 1;

  IF v_trip_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active boarding trip found');
  END IF;

  IF v_trip_status = 'departure_pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Departure lock already active');
  END IF;

  -- Get route min_passengers
  SELECT COALESCE(min_passengers, 1)
  INTO v_min_passengers
  FROM public.routes
  WHERE id = v_route_id;

  -- Count currently assigned/confirmed seats for this trip
  SELECT COALESCE(SUM(b.seats), 0)
  INTO v_booked_seats
  FROM public.bookings b
  WHERE b.trip_id = v_trip_id
    AND b.status = 'confirmed';

  -- Enforce minimum occupancy rule
  IF v_booked_seats < v_min_passengers THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Below minimum occupancy',
      'booked_seats', v_booked_seats,
      'min_passengers', v_min_passengers,
      'seats_needed', v_min_passengers - v_booked_seats
    );
  END IF;

  -- Get vehicle capacity for context
  SELECT v.seating_capacity
  INTO v_vehicle_capacity
  FROM public.vehicles v
  JOIN public.drivers d ON d.current_vehicle_id = v.id
  WHERE d.id = v_driver_id;

  -- Read departure_lock_seconds from business_settings
  SELECT COALESCE(value::INTEGER, 60)
  INTO v_lock_seconds
  FROM public.business_settings
  WHERE key = 'departure_lock_seconds';

  v_lock_expires_at := NOW() + (v_lock_seconds || ' seconds')::INTERVAL;

  -- Transition trip to departure_pending
  UPDATE public.trips
  SET status = 'departure_pending',
      departure_lock_expires_at = v_lock_expires_at,
      updated_at = NOW()
  WHERE id = v_trip_id;

  RETURN jsonb_build_object(
    'success', true,
    'trip_id', v_trip_id,
    'departure_lock_seconds', v_lock_seconds,
    'departure_lock_expires_at', v_lock_expires_at,
    'booked_seats', v_booked_seats,
    'vehicle_capacity', v_vehicle_capacity,
    'min_passengers', v_min_passengers
  );
END;
$$;

-- ============================================================
-- STEP 5: driver_wait_for_more RPC
-- Reverts departure_pending -> boarding so FIFO matching continues.
-- ============================================================

CREATE OR REPLACE FUNCTION public.driver_wait_for_more(
  p_driver_profile_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id UUID;
  v_trip_id   UUID;
BEGIN
  SELECT id INTO v_driver_id
  FROM public.drivers
  WHERE profile_id = p_driver_profile_id;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver not found');
  END IF;

  SELECT id INTO v_trip_id
  FROM public.trips
  WHERE driver_id = v_driver_id
    AND status = 'departure_pending'
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_trip_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No departure-pending trip found');
  END IF;

  UPDATE public.trips
  SET status = 'boarding',
      departure_lock_expires_at = NULL,
      updated_at = NOW()
  WHERE id = v_trip_id;

  RETURN jsonb_build_object('success', true, 'trip_id', v_trip_id);
END;
$$;

-- ============================================================
-- STEP 6: check_departure_eligibility_on_cancel
-- Called when a passenger cancels a booking.
-- If the trip is departure_pending and assigned seats drop below
-- min_passengers, revoke departure eligibility -> back to boarding.
-- ============================================================

CREATE OR REPLACE FUNCTION public.check_departure_eligibility_on_cancel(
  p_trip_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trip_status    public.trip_status;
  v_route_id       UUID;
  v_min_passengers INTEGER;
  v_booked_seats   INTEGER;
BEGIN
  SELECT status, route_id
  INTO v_trip_status, v_route_id
  FROM public.trips
  WHERE id = p_trip_id;

  IF v_trip_status IS NULL OR v_trip_status != 'departure_pending' THEN
    RETURN; -- Nothing to do
  END IF;

  SELECT COALESCE(min_passengers, 1)
  INTO v_min_passengers
  FROM public.routes
  WHERE id = v_route_id;

  SELECT COALESCE(SUM(b.seats), 0)
  INTO v_booked_seats
  FROM public.bookings b
  WHERE b.trip_id = p_trip_id
    AND b.status = 'confirmed';

  -- If below minimum, revoke departure eligibility
  IF v_booked_seats < v_min_passengers THEN
    UPDATE public.trips
    SET status = 'boarding',
        departure_lock_expires_at = NULL,
        updated_at = NOW()
    WHERE id = p_trip_id;
  END IF;
END;
$$;

-- ============================================================
-- STEP 7: Update cancel_booking to call eligibility recheck
-- ============================================================

CREATE OR REPLACE FUNCTION public.cancel_booking(
  p_passenger_id UUID,
  p_booking_id   UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking          RECORD;
  v_cancellation_fee NUMERIC := 0;
  v_fee_setting      TEXT;
BEGIN
  -- Fetch booking
  SELECT b.*, t.status AS trip_status
  INTO v_booking
  FROM public.bookings b
  LEFT JOIN public.trips t ON t.id = b.trip_id
  WHERE b.id = p_booking_id
    AND b.passenger_id = p_passenger_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found or not yours');
  END IF;

  IF v_booking.status = 'cancelled' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking already cancelled');
  END IF;

  IF v_booking.trip_status = 'in_progress' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot cancel a trip already in progress');
  END IF;

  -- Read cancellation fee
  SELECT value INTO v_fee_setting
  FROM public.business_settings
  WHERE key = 'cancellation_fee_inr';

  IF v_fee_setting IS NOT NULL THEN
    v_cancellation_fee := v_fee_setting::NUMERIC;
  END IF;

  -- Cancel the booking
  UPDATE public.bookings
  SET status = 'cancelled',
      updated_at = NOW()
  WHERE id = p_booking_id;

  -- Remove from passenger queue if still waiting
  UPDATE public.passenger_queue
  SET status = 'cancelled',
      updated_at = NOW()
  WHERE booking_id = p_booking_id
    AND status IN ('waiting', 'active');

  -- If booking was linked to a trip, recheck departure eligibility
  IF v_booking.trip_id IS NOT NULL THEN
    PERFORM public.check_departure_eligibility_on_cancel(v_booking.trip_id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'cancellation_fee', v_cancellation_fee
  );
END;
$$;

-- ============================================================
-- STEP 8: Update book_or_queue to block assignment into
-- departure_pending trips (only assign to 'boarding' trips)
-- ============================================================

-- Drop existing function first to allow parameter rename
DROP FUNCTION IF EXISTS public.book_or_queue(UUID, UUID, UUID, INTEGER);

CREATE OR REPLACE FUNCTION public.book_or_queue(
  p_passenger_id UUID,
  p_route_id     UUID,
  p_pickup_id    UUID,
  p_seats        INTEGER DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_route          RECORD;
  v_pickup         RECORD;
  v_existing       RECORD;
  v_trip           RECORD;
  v_booking_id     UUID;
  v_queue_id       UUID;
  v_fare           NUMERIC;
  v_queue_position INTEGER;
BEGIN
  -- Validate route
  SELECT * INTO v_route FROM public.routes WHERE id = p_route_id AND status = 'active';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Route not found or inactive');
  END IF;

  -- Validate pickup belongs to route
  SELECT * INTO v_pickup FROM public.pickup_points
  WHERE id = p_pickup_id AND route_id = p_route_id AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pickup point not valid for this route');
  END IF;

  -- Check for existing active booking on this route
  SELECT b.id INTO v_existing
  FROM public.bookings b
  WHERE b.passenger_id = p_passenger_id
    AND b.route_id = p_route_id
    AND b.status = 'confirmed'
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Already have an active booking on this route', 'already_queued', true);
  END IF;

  v_fare := COALESCE(v_route.fare_per_seat, 150);

  -- Look for an available boarding trip (NOT departure_pending or in_progress)
  -- Only assign to trips in 'boarding' status
  SELECT t.* INTO v_trip
  FROM public.trips t
  WHERE t.route_id = p_route_id
    AND t.status = 'boarding'
    AND (
      SELECT COALESCE(SUM(b2.seats), 0)
      FROM public.bookings b2
      WHERE b2.trip_id = t.id AND b2.status = 'confirmed'
    ) + p_seats <= (
      SELECT v.seating_capacity
      FROM public.vehicles v
      WHERE v.id = t.vehicle_id
    )
  ORDER BY t.created_at ASC
  LIMIT 1;

  -- Create booking
  INSERT INTO public.bookings (
    passenger_id, route_id, pickup_point_id, trip_id,
    seats, fare_per_seat, status, booked_at
  )
  VALUES (
    p_passenger_id, p_route_id, p_pickup_id,
    CASE WHEN v_trip.id IS NOT NULL THEN v_trip.id ELSE NULL END,
    p_seats, v_fare, 'confirmed', NOW()
  )
  RETURNING id INTO v_booking_id;

  -- Add to passenger queue
  SELECT COALESCE(MAX(queue_position), 0) + 1
  INTO v_queue_position
  FROM public.passenger_queue
  WHERE route_id = p_route_id
    AND status = 'waiting';

  INSERT INTO public.passenger_queue (
    passenger_id, route_id, booking_id, seats_requested,
    queue_position, status, joined_at
  )
  VALUES (
    p_passenger_id, p_route_id, v_booking_id, p_seats,
    v_queue_position, 'waiting', NOW()
  )
  RETURNING id INTO v_queue_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', v_booking_id,
    'queue_id', v_queue_id,
    'queue_position', v_queue_position,
    'trip_id', v_trip.id,
    'fare_per_seat', v_fare,
    'seats', p_seats
  );
END;
$$;

-- ============================================================
-- STEP 9: Update get_driver_queue_status to return departure
-- eligibility fields (min_passengers, can_depart, is_full,
-- departure_lock_remaining_seconds)
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

  -- Get active queue entry
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

  -- Get route
  SELECT * INTO v_route FROM public.routes WHERE id = v_queue_entry.route_id;

  -- Get vehicle
  SELECT * INTO v_vehicle FROM public.vehicles WHERE id = v_driver.current_vehicle_id;

  -- Get active trip if assigned
  IF v_queue_entry.provisional_trip_id IS NOT NULL THEN
    SELECT * INTO v_trip FROM public.trips WHERE id = v_queue_entry.provisional_trip_id;
  END IF;

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
    'found', true,
    'queue_entry_id', v_queue_entry.id,
    'status', v_queue_entry.status,
    'queue_position', v_queue_entry.queue_position,
    'drivers_ahead', GREATEST(0, v_queue_entry.queue_position - 1),
    'route_from', v_route.from_location,
    'route_to', v_route.to_location,
    'vehicle_make', v_vehicle.make,
    'vehicle_model', v_vehicle.model,
    'vehicle_registration', v_vehicle.registration_number,
    'vehicle_capacity', v_vehicle.seating_capacity,
    'min_passengers', v_min_passengers,
    'booked_seats', v_booked_seats,
    'can_depart', v_can_depart,
    'is_full', v_booked_seats >= COALESCE(v_vehicle.seating_capacity, 4),
    'trip_id', v_trip.id,
    'trip_status', v_trip.status,
    'departure_lock_expires_at', v_trip.departure_lock_expires_at,
    'departure_lock_remaining_seconds', v_lock_remaining,
    'offered_at', v_queue_entry.offered_at,
    'offer_expires_at', v_queue_entry.offer_expires_at,
    'provisional_trip_id', v_queue_entry.provisional_trip_id,
    'passenger_count', v_booked_seats,
    'total_seats', v_vehicle.seating_capacity,
    'fare_per_seat', v_route.fare_per_seat,
    'offer_timeout_seconds', (SELECT value::INTEGER FROM public.business_settings WHERE key = 'driver_offer_timeout_seconds' LIMIT 1)
  );
END;
$$;

-- ============================================================
-- STEP 10: Grant execute permissions
-- ============================================================

GRANT EXECUTE ON FUNCTION public.driver_leave_now(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.driver_wait_for_more(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_departure_eligibility_on_cancel(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_booking(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.book_or_queue(UUID, UUID, UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_driver_queue_status(UUID) TO authenticated;
