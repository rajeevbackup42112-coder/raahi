-- ============================================================
-- RAAHI STAGE 3 — QUEUE ENGINE + ATOMIC BOOKING
-- Migration: 20260809023814_raahi_stage3_queue_booking.sql
-- ============================================================

-- ============================================================
-- STEP 1: EXTEND ENUMS (safe additions)
-- Each ALTER TYPE ADD VALUE must be committed before use
-- ============================================================

-- Extend driver_availability_status with new states
ALTER TYPE public.driver_availability_status ADD VALUE IF NOT EXISTS 'queued';
ALTER TYPE public.driver_availability_status ADD VALUE IF NOT EXISTS 'active';
ALTER TYPE public.driver_availability_status ADD VALUE IF NOT EXISTS 'full';
ALTER TYPE public.driver_availability_status ADD VALUE IF NOT EXISTS 'ready';
ALTER TYPE public.driver_availability_status ADD VALUE IF NOT EXISTS 'trip_started';
ALTER TYPE public.driver_availability_status ADD VALUE IF NOT EXISTS 'completed';
ALTER TYPE public.driver_availability_status ADD VALUE IF NOT EXISTS 'suspended';

-- Extend trip_status with new states
ALTER TYPE public.trip_status ADD VALUE IF NOT EXISTS 'accepting_bookings';
ALTER TYPE public.trip_status ADD VALUE IF NOT EXISTS 'full';
ALTER TYPE public.trip_status ADD VALUE IF NOT EXISTS 'ready';

-- Extend queue_status
ALTER TYPE public.queue_status ADD VALUE IF NOT EXISTS 'offline';

-- Extend audit_action with new actions
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'driver_went_online';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'driver_became_active';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'driver_paused';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'driver_removed';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'booking_created';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'booking_cancelled';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'passenger_replaced';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'passenger_reassigned';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'trip_became_full';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'next_driver_activated';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'admin_override_driver';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'trip_started';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'trip_completed';

-- COMMIT enum additions so new values are visible to subsequent statements
COMMIT;

-- ============================================================
-- STEP 2: ADD COLUMNS TO EXISTING TABLES
-- ============================================================

-- Add active_trip_id to trips for easy lookup
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS fare_per_seat NUMERIC(10,2) NOT NULL DEFAULT 150;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS notes TEXT;

-- Add cancellation status to cancellations
ALTER TABLE public.cancellations ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending';

-- Add queue_entry_id to trips for back-reference
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS queue_entry_id UUID REFERENCES public.driver_queue(id) ON DELETE SET NULL;

-- ============================================================
-- STEP 3: CORE QUEUE + BOOKING FUNCTIONS
-- ============================================================

-- ============================================================
-- FUNCTION: driver_go_online
-- Driver joins the queue for a route
-- ============================================================
CREATE OR REPLACE FUNCTION public.driver_go_online(
  p_driver_id UUID,
  p_route_id UUID,
  p_vehicle_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver RECORD;
  v_vehicle RECORD;
  v_route RECORD;
  v_existing_queue RECORD;
  v_active_queue RECORD;
  v_queue_entry_id UUID;
  v_queue_position INTEGER;
  v_new_trip_id UUID;
BEGIN
  -- Validate driver
  SELECT d.*, p.name, p.status as profile_status
  INTO v_driver
  FROM public.drivers d
  JOIN public.profiles p ON p.id = d.profile_id
  WHERE d.id = p_driver_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver not found');
  END IF;

  IF v_driver.verification_status != 'approved' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver not approved. Contact admin.');
  END IF;

  IF v_driver.profile_status = 'suspended' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver account is suspended.');
  END IF;

  -- Validate vehicle
  SELECT * INTO v_vehicle FROM public.vehicles WHERE id = p_vehicle_id AND status = 'active';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Vehicle not found or inactive');
  END IF;

  -- Validate route
  SELECT * INTO v_route FROM public.routes WHERE id = p_route_id AND status = 'active';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Route not found or inactive');
  END IF;

  -- Check if driver already in queue for this route
  SELECT * INTO v_existing_queue
  FROM public.driver_queue
  WHERE driver_id = p_driver_id
    AND route_id = p_route_id
    AND status IN ('waiting', 'active');

  IF FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver already in queue for this route');
  END IF;

  -- Calculate queue position
  SELECT COALESCE(MAX(queue_position), 0) + 1
  INTO v_queue_position
  FROM public.driver_queue
  WHERE route_id = p_route_id AND status IN ('waiting', 'active');

  -- Insert into queue
  INSERT INTO public.driver_queue (route_id, driver_id, vehicle_id, queue_position, status, joined_at)
  VALUES (p_route_id, p_driver_id, p_vehicle_id, v_queue_position, 'waiting', NOW())
  RETURNING id INTO v_queue_entry_id;

  -- Update driver status
  UPDATE public.drivers
  SET availability_status = 'queued', current_route_id = p_route_id, current_vehicle_id = p_vehicle_id
  WHERE id = p_driver_id;

  -- Log action
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  SELECT p.id, 'driver_went_online'::public.audit_action, 'driver_queue', v_queue_entry_id,
    jsonb_build_object('route_id', p_route_id, 'vehicle_id', p_vehicle_id, 'position', v_queue_position),
    'Driver joined queue'
  FROM public.drivers d JOIN public.profiles p ON p.id = d.profile_id WHERE d.id = p_driver_id;

  -- Check if there's no active vehicle for this route — if so, activate this driver
  SELECT dq.* INTO v_active_queue
  FROM public.driver_queue dq
  WHERE dq.route_id = p_route_id AND dq.status = 'active'
  LIMIT 1;

  IF NOT FOUND THEN
    -- No active driver — activate this one
    PERFORM public.activate_next_driver(p_route_id, v_queue_entry_id);
    RETURN jsonb_build_object('success', true, 'queue_entry_id', v_queue_entry_id, 'status', 'active', 'position', v_queue_position);
  END IF;

  RETURN jsonb_build_object('success', true, 'queue_entry_id', v_queue_entry_id, 'status', 'queued', 'position', v_queue_position);
END;
$$;

-- ============================================================
-- FUNCTION: activate_next_driver
-- Activates the next eligible queued driver for a route
-- ============================================================
CREATE OR REPLACE FUNCTION public.activate_next_driver(
  p_route_id UUID,
  p_specific_queue_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_next_queue RECORD;
  v_vehicle RECORD;
  v_new_trip_id UUID;
  v_fare NUMERIC(10,2);
BEGIN
  -- Get fare from business settings
  SELECT COALESCE(value::NUMERIC, 150) INTO v_fare
  FROM public.business_settings WHERE key = 'default_fare_inr';

  -- Find next eligible driver
  IF p_specific_queue_id IS NOT NULL THEN
    SELECT dq.*, d.id as driver_rec_id, v.seating_capacity
    INTO v_next_queue
    FROM public.driver_queue dq
    JOIN public.drivers d ON d.id = dq.driver_id
    JOIN public.vehicles v ON v.id = dq.vehicle_id
    WHERE dq.id = p_specific_queue_id
      AND dq.route_id = p_route_id
      AND dq.status = 'waiting'
      AND d.verification_status = 'approved'
      AND v.status = 'active';
  ELSE
    SELECT dq.*, d.id as driver_rec_id, v.seating_capacity
    INTO v_next_queue
    FROM public.driver_queue dq
    JOIN public.drivers d ON d.id = dq.driver_id
    JOIN public.vehicles v ON v.id = dq.vehicle_id
    WHERE dq.route_id = p_route_id
      AND dq.status = 'waiting'
      AND d.verification_status = 'approved'
      AND v.status = 'active'
    ORDER BY dq.joined_at ASC
    LIMIT 1;
  END IF;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'No eligible driver in queue');
  END IF;

  -- Mark queue entry as active
  UPDATE public.driver_queue
  SET status = 'active', activated_at = NOW()
  WHERE id = v_next_queue.id;

  -- Update driver status
  UPDATE public.drivers
  SET availability_status = 'active'
  WHERE id = v_next_queue.driver_id;

  -- Create a new trip
  INSERT INTO public.trips (route_id, driver_id, vehicle_id, total_seats, booked_seats, status, fare_per_seat, queue_entry_id)
  VALUES (p_route_id, v_next_queue.driver_id, v_next_queue.vehicle_id, v_next_queue.seating_capacity, 0, 'accepting_bookings', v_fare, v_next_queue.id)
  RETURNING id INTO v_new_trip_id;

  -- Log
  INSERT INTO public.audit_logs (action, target_table, target_id, new_value, notes)
  VALUES ('driver_became_active'::public.audit_action, 'driver_queue', v_next_queue.id,
    jsonb_build_object('trip_id', v_new_trip_id, 'route_id', p_route_id),
    'Driver activated from queue');

  RETURN jsonb_build_object('success', true, 'trip_id', v_new_trip_id, 'queue_entry_id', v_next_queue.id);
END;
$$;

-- ============================================================
-- FUNCTION: book_seat (ATOMIC — prevents overbooking)
-- ============================================================
CREATE OR REPLACE FUNCTION public.book_seat(
  p_passenger_id UUID,
  p_route_id UUID,
  p_pickup_point_id UUID,
  p_seats INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trip RECORD;
  v_max_seats INTEGER;
  v_available INTEGER;
  v_fare NUMERIC(10,2);
  v_total_fare NUMERIC(10,2);
  v_booking_id UUID;
  v_activate_result JSONB;
BEGIN
  -- Get max seats per booking from settings
  SELECT COALESCE(value::INTEGER, 4) INTO v_max_seats
  FROM public.business_settings WHERE key = 'max_seats_per_booking';

  IF p_seats < 1 OR p_seats > v_max_seats THEN
    RETURN jsonb_build_object('success', false, 'error', format('Seats must be between 1 and %s', v_max_seats));
  END IF;

  -- LOCK the active trip for this route (prevents concurrent overbooking)
  SELECT t.*
  INTO v_trip
  FROM public.trips t
  WHERE t.route_id = p_route_id
    AND t.status = 'accepting_bookings'
  ORDER BY t.created_at DESC
  LIMIT 1
  FOR UPDATE;  -- Row-level lock

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'No vehicle is currently accepting bookings for this route.');
  END IF;

  -- Calculate available seats
  v_available := v_trip.total_seats - v_trip.booked_seats;

  IF v_available < p_seats THEN
    IF v_available = 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Vehicle is full. Please try the next vehicle.');
    ELSE
      RETURN jsonb_build_object('success', false, 'error', format('Only %s seat(s) available. Please reduce your seat count.', v_available));
    END IF;
  END IF;

  -- Get fare
  v_fare := v_trip.fare_per_seat;
  v_total_fare := v_fare * p_seats;

  -- Create booking
  INSERT INTO public.bookings (passenger_id, trip_id, pickup_point_id, seats, fare_per_seat, total_fare, status)
  VALUES (p_passenger_id, v_trip.id, p_pickup_point_id, p_seats, v_fare, v_total_fare, 'confirmed')
  RETURNING id INTO v_booking_id;

  -- Update trip booked_seats
  UPDATE public.trips
  SET booked_seats = booked_seats + p_seats
  WHERE id = v_trip.id;

  -- Log booking
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (p_passenger_id, 'booking_created'::public.audit_action, 'bookings', v_booking_id,
    jsonb_build_object('trip_id', v_trip.id, 'seats', p_seats, 'fare', v_total_fare),
    'Seat booked by passenger');

  -- Check if trip is now full
  IF (v_trip.booked_seats + p_seats) >= v_trip.total_seats THEN
    -- Mark trip as full
    UPDATE public.trips SET status = 'full' WHERE id = v_trip.id;

    -- Mark driver as ready
    UPDATE public.drivers SET availability_status = 'ready'
    WHERE id = v_trip.driver_id;

    -- Mark queue entry as completed
    UPDATE public.driver_queue SET status = 'completed', completed_at = NOW()
    WHERE id = v_trip.queue_entry_id;

    -- Log
    INSERT INTO public.audit_logs (action, target_table, target_id, new_value, notes)
    VALUES ('trip_became_full'::public.audit_action, 'trips', v_trip.id,
      jsonb_build_object('route_id', p_route_id, 'total_seats', v_trip.total_seats),
      'Trip reached capacity');

    -- Activate next driver
    v_activate_result := public.activate_next_driver(p_route_id);

    IF (v_activate_result->>'success')::BOOLEAN THEN
      INSERT INTO public.audit_logs (action, target_table, target_id, new_value, notes)
      VALUES ('next_driver_activated'::public.audit_action, 'trips', (v_activate_result->>'trip_id')::UUID,
        v_activate_result, 'Auto-activated after previous trip filled');
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'booking_id', v_booking_id,
      'trip_id', v_trip.id,
      'seats', p_seats,
      'fare', v_total_fare,
      'trip_status', 'full',
      'message', 'Booking confirmed. Vehicle is now full and ready to depart.'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', v_booking_id,
    'trip_id', v_trip.id,
    'seats', p_seats,
    'fare', v_total_fare,
    'trip_status', 'accepting_bookings',
    'message', 'Booking confirmed.'
  );
END;
$$;

-- ============================================================
-- FUNCTION: cancel_booking
-- ============================================================
CREATE OR REPLACE FUNCTION public.cancel_booking(
  p_booking_id UUID,
  p_passenger_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking RECORD;
  v_trip RECORD;
  v_cancellation_fee NUMERIC(10,2);
  v_cancellation_id UUID;
BEGIN
  -- Get booking
  SELECT b.*, t.status as trip_status, t.route_id
  INTO v_booking
  FROM public.bookings b
  JOIN public.trips t ON t.id = b.trip_id
  WHERE b.id = p_booking_id AND b.passenger_id = p_passenger_id AND b.status = 'confirmed';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found or already cancelled');
  END IF;

  -- Cannot cancel if trip already started
  IF v_booking.trip_status IN ('in_progress', 'completed') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot cancel a trip that has already started or completed');
  END IF;

  -- Get cancellation fee
  SELECT COALESCE(value::NUMERIC, 20) INTO v_cancellation_fee
  FROM public.business_settings WHERE key = 'cancellation_fee_inr';

  -- Mark booking cancelled
  UPDATE public.bookings SET status = 'cancelled' WHERE id = p_booking_id;

  -- Create cancellation record
  INSERT INTO public.cancellations (booking_id, cancelled_by, reason, cancellation_fee, status)
  VALUES (p_booking_id, p_passenger_id, p_reason, v_cancellation_fee, 'pending')
  RETURNING id INTO v_cancellation_id;

  -- If trip hasn't started, release the seat
  IF v_booking.trip_status IN ('accepting_bookings', 'full', 'ready') THEN
    UPDATE public.trips
    SET booked_seats = GREATEST(0, booked_seats - v_booking.seats),
        status = CASE
          WHEN status IN ('full', 'ready') THEN 'accepting_bookings'
          ELSE status
        END
    WHERE id = v_booking.trip_id;

    -- If trip was full and now has space, reopen it
    -- (keep same driver active, don't re-dispatch)
  END IF;

  -- Log
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (p_passenger_id, 'booking_cancelled'::public.audit_action, 'bookings', p_booking_id,
    jsonb_build_object('cancellation_fee', v_cancellation_fee, 'trip_status', v_booking.trip_status),
    COALESCE(p_reason, 'Passenger cancelled booking'));

  RETURN jsonb_build_object(
    'success', true,
    'cancellation_id', v_cancellation_id,
    'cancellation_fee', v_cancellation_fee,
    'message', format('Booking cancelled. Cancellation fee of ₹%s will be collected.', v_cancellation_fee)
  );
END;
$$;

-- ============================================================
-- FUNCTION: driver_go_offline
-- Safe offline with state checks
-- ============================================================
CREATE OR REPLACE FUNCTION public.driver_go_offline(
  p_driver_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver RECORD;
  v_queue RECORD;
  v_trip RECORD;
  v_confirmed_bookings INTEGER;
BEGIN
  SELECT * INTO v_driver FROM public.drivers WHERE id = p_driver_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver not found');
  END IF;

  -- Get active queue entry
  SELECT * INTO v_queue
  FROM public.driver_queue
  WHERE driver_id = p_driver_id AND status IN ('waiting', 'active')
  ORDER BY joined_at DESC LIMIT 1;

  -- If driver is in TRIP_STARTED state, block
  IF v_driver.availability_status = 'trip_started' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot go offline during an active trip. Complete or contact admin.');
  END IF;

  -- If driver is ACTIVE, check for confirmed bookings
  IF v_driver.availability_status IN ('active', 'full', 'ready') THEN
    SELECT t.id INTO v_trip
    FROM public.trips t
    WHERE t.driver_id = p_driver_id AND t.status IN ('accepting_bookings', 'full', 'ready')
    ORDER BY t.created_at DESC LIMIT 1;

    IF FOUND THEN
      SELECT COUNT(*) INTO v_confirmed_bookings
      FROM public.bookings WHERE trip_id = v_trip.id AND status = 'confirmed';

      IF v_confirmed_bookings > 0 THEN
        RETURN jsonb_build_object(
          'success', false,
          'error', format('Cannot go offline — %s confirmed passenger(s) on this trip. Contact admin for reassignment.', v_confirmed_bookings),
          'requires_admin', true
        );
      END IF;

      -- No bookings — safe to withdraw, cancel the trip
      UPDATE public.trips SET status = 'cancelled' WHERE id = v_trip.id;

      -- Activate next driver
      PERFORM public.activate_next_driver(v_driver.current_route_id);
    END IF;
  END IF;

  -- Mark queue entry as cancelled
  IF FOUND THEN
    UPDATE public.driver_queue SET status = 'cancelled', completed_at = NOW() WHERE id = v_queue.id;
  END IF;

  -- Update driver status
  UPDATE public.drivers
  SET availability_status = 'offline', current_route_id = NULL, current_vehicle_id = NULL
  WHERE id = p_driver_id;

  -- Log
  INSERT INTO public.audit_logs (action, target_table, target_id, new_value, notes)
  VALUES ('driver_removed'::public.audit_action, 'drivers', p_driver_id,
    jsonb_build_object('previous_status', v_driver.availability_status),
    'Driver went offline');

  RETURN jsonb_build_object('success', true, 'message', 'You are now offline');
END;
$$;

-- ============================================================
-- FUNCTION: driver_start_trip
-- ============================================================
CREATE OR REPLACE FUNCTION public.driver_start_trip(
  p_driver_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trip RECORD;
BEGIN
  SELECT * INTO v_trip
  FROM public.trips
  WHERE driver_id = p_driver_id AND status IN ('full', 'ready', 'accepting_bookings')
  ORDER BY created_at DESC LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active trip found');
  END IF;

  UPDATE public.trips SET status = 'in_progress', actual_departure = NOW() WHERE id = v_trip.id;
  UPDATE public.drivers SET availability_status = 'trip_started' WHERE id = p_driver_id;

  INSERT INTO public.audit_logs (action, target_table, target_id, new_value, notes)
  VALUES ('trip_started'::public.audit_action, 'trips', v_trip.id,
    jsonb_build_object('driver_id', p_driver_id),
    'Trip started by driver');

  RETURN jsonb_build_object('success', true, 'trip_id', v_trip.id, 'message', 'Trip started');
END;
$$;

-- ============================================================
-- FUNCTION: driver_complete_trip
-- ============================================================
CREATE OR REPLACE FUNCTION public.driver_complete_trip(
  p_driver_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trip RECORD;
BEGIN
  SELECT * INTO v_trip
  FROM public.trips
  WHERE driver_id = p_driver_id AND status = 'in_progress'
  ORDER BY created_at DESC LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'No in-progress trip found');
  END IF;

  UPDATE public.trips SET status = 'completed', actual_arrival = NOW() WHERE id = v_trip.id;
  UPDATE public.drivers SET availability_status = 'completed' WHERE id = p_driver_id;
  UPDATE public.bookings SET status = 'completed' WHERE trip_id = v_trip.id AND status = 'confirmed';

  INSERT INTO public.audit_logs (action, target_table, target_id, new_value, notes)
  VALUES ('trip_completed'::public.audit_action, 'trips', v_trip.id,
    jsonb_build_object('driver_id', p_driver_id),
    'Trip completed by driver');

  RETURN jsonb_build_object('success', true, 'trip_id', v_trip.id, 'message', 'Trip completed');
END;
$$;

-- ============================================================
-- FUNCTION: admin_override_active_driver
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_override_active_driver(
  p_admin_id UUID,
  p_route_id UUID,
  p_new_queue_entry_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_current_trip RECORD;
  v_new_queue RECORD;
  v_confirmed_bookings INTEGER;
  v_new_trip_id UUID;
  v_fare NUMERIC(10,2);
BEGIN
  -- Verify admin
  SELECT public.is_admin() INTO v_is_admin;
  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  -- Get current active trip
  SELECT t.* INTO v_current_trip
  FROM public.trips t
  WHERE t.route_id = p_route_id AND t.status IN ('accepting_bookings', 'full', 'ready')
  ORDER BY t.created_at DESC LIMIT 1;

  -- Get new queue entry
  SELECT dq.*, v.seating_capacity INTO v_new_queue
  FROM public.driver_queue dq
  JOIN public.vehicles v ON v.id = dq.vehicle_id
  WHERE dq.id = p_new_queue_entry_id AND dq.status = 'waiting';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Target driver not found in waiting queue');
  END IF;

  -- Get fare
  SELECT COALESCE(value::NUMERIC, 150) INTO v_fare
  FROM public.business_settings WHERE key = 'default_fare_inr';

  -- If there's a current active trip with bookings, handle reassignment
  IF v_current_trip.id IS NOT NULL THEN
    SELECT COUNT(*) INTO v_confirmed_bookings
    FROM public.bookings WHERE trip_id = v_current_trip.id AND status = 'confirmed';

    -- Mark current trip as cancelled (bookings remain for admin to handle)
    UPDATE public.trips SET status = 'cancelled' WHERE id = v_current_trip.id;

    -- Mark current driver as offline
    UPDATE public.drivers SET availability_status = 'offline'
    WHERE id = v_current_trip.driver_id;

    -- Mark old queue entry as cancelled
    UPDATE public.driver_queue SET status = 'cancelled', completed_at = NOW()
    WHERE id = v_current_trip.queue_entry_id;
  END IF;

  -- Activate new driver
  UPDATE public.driver_queue SET status = 'active', activated_at = NOW() WHERE id = p_new_queue_entry_id;
  UPDATE public.drivers SET availability_status = 'active' WHERE id = v_new_queue.driver_id;

  -- Create new trip
  INSERT INTO public.trips (route_id, driver_id, vehicle_id, total_seats, booked_seats, status, fare_per_seat, queue_entry_id)
  VALUES (p_route_id, v_new_queue.driver_id, v_new_queue.vehicle_id, v_new_queue.seating_capacity, 0, 'accepting_bookings', v_fare, p_new_queue_entry_id)
  RETURNING id INTO v_new_trip_id;

  -- Log override
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (p_admin_id, 'admin_override_driver'::public.audit_action, 'driver_queue', p_new_queue_entry_id,
    jsonb_build_object('previous_trip_id', v_current_trip.id),
    jsonb_build_object('new_trip_id', v_new_trip_id, 'new_queue_entry_id', p_new_queue_entry_id),
    COALESCE(p_reason, 'Admin manual override'));

  RETURN jsonb_build_object(
    'success', true,
    'new_trip_id', v_new_trip_id,
    'previous_bookings_count', COALESCE(v_confirmed_bookings, 0),
    'message', 'Active driver changed successfully'
  );
END;
$$;

-- ============================================================
-- FUNCTION: get_active_trip_for_route
-- Used by passenger booking page
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_active_trip_for_route(
  p_route_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trip RECORD;
  v_result JSONB;
BEGIN
  SELECT
    t.id, t.route_id, t.driver_id, t.vehicle_id, t.total_seats, t.booked_seats,
    t.status, t.fare_per_seat,
    v.make, v.model, v.vehicle_type, v.seating_capacity, v.registration_number,
    p.name as driver_name,
    r.from_location, r.to_location
  INTO v_trip
  FROM public.trips t
  JOIN public.vehicles v ON v.id = t.vehicle_id
  JOIN public.drivers d ON d.id = t.driver_id
  JOIN public.profiles p ON p.id = d.profile_id
  JOIN public.routes r ON r.id = t.route_id
  WHERE t.route_id = p_route_id
    AND t.status = 'accepting_bookings'
  ORDER BY t.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  RETURN jsonb_build_object(
    'found', true,
    'trip_id', v_trip.id,
    'route_id', v_trip.route_id,
    'from_location', v_trip.from_location,
    'to_location', v_trip.to_location,
    'total_seats', v_trip.total_seats,
    'booked_seats', v_trip.booked_seats,
    'available_seats', v_trip.total_seats - v_trip.booked_seats,
    'fare_per_seat', v_trip.fare_per_seat,
    'status', v_trip.status,
    'vehicle_make', v_trip.make,
    'vehicle_model', v_trip.model,
    'vehicle_type', v_trip.vehicle_type,
    'vehicle_registration', v_trip.registration_number,
    'driver_name', v_trip.driver_name
  );
END;
$$;

-- ============================================================
-- STEP 4: RLS POLICIES FOR NEW OPERATIONS
-- ============================================================

-- Allow passengers to read trips (for booking page)
DROP POLICY IF EXISTS "trips_passenger_read" ON public.trips;
CREATE POLICY "trips_passenger_read"
ON public.trips FOR SELECT TO authenticated
USING (status IN ('accepting_bookings', 'full', 'ready', 'in_progress') OR public.is_admin());

-- Allow drivers to update their own trips
DROP POLICY IF EXISTS "trips_driver_update" ON public.trips;
CREATE POLICY "trips_driver_update"
ON public.trips FOR UPDATE TO authenticated
USING (driver_id IN (SELECT id FROM public.drivers WHERE profile_id = auth.uid()))
WITH CHECK (driver_id IN (SELECT id FROM public.drivers WHERE profile_id = auth.uid()));

-- Allow drivers to insert trips (via RPC only in practice)
DROP POLICY IF EXISTS "trips_driver_insert" ON public.trips;
CREATE POLICY "trips_driver_insert"
ON public.trips FOR INSERT TO authenticated
WITH CHECK (public.is_admin() OR driver_id IN (SELECT id FROM public.drivers WHERE profile_id = auth.uid()));

-- Cancellations — passenger can create
DROP POLICY IF EXISTS "cancellations_passenger_create" ON public.cancellations;
CREATE POLICY "cancellations_passenger_create"
ON public.cancellations FOR INSERT TO authenticated
WITH CHECK (cancelled_by = auth.uid());

-- Bookings — passenger can update own (for cancellation status)
DROP POLICY IF EXISTS "bookings_passenger_update" ON public.bookings;
CREATE POLICY "bookings_passenger_update"
ON public.bookings FOR UPDATE TO authenticated
USING (passenger_id = auth.uid())
WITH CHECK (passenger_id = auth.uid());

-- Audit logs — drivers can insert (for their own actions)
DROP POLICY IF EXISTS "audit_logs_driver_insert" ON public.audit_logs;
CREATE POLICY "audit_logs_driver_insert"
ON public.audit_logs FOR INSERT TO authenticated
WITH CHECK (true);

-- ============================================================
-- STEP 5: ADDITIONAL INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_trips_status_route ON public.trips(route_id, status);
CREATE INDEX IF NOT EXISTS idx_trips_driver_status ON public.trips(driver_id, status);
CREATE INDEX IF NOT EXISTS idx_driver_queue_route_status ON public.driver_queue(route_id, status);
CREATE INDEX IF NOT EXISTS idx_driver_queue_joined_at ON public.driver_queue(joined_at);
CREATE INDEX IF NOT EXISTS idx_bookings_trip_status ON public.bookings(trip_id, status);
CREATE INDEX IF NOT EXISTS idx_cancellations_booking ON public.cancellations(booking_id);

-- ============================================================
-- STEP 6: SECURITY CLEANUP — Remove hardcoded admin password note
-- ============================================================
-- The admin user was seeded in Stage 2 migration with a hardcoded password.
-- This migration does NOT re-seed or expose that password.
-- Admin should change their password via Supabase Auth dashboard after first login.
-- The seed in Stage 2 migration (20260809012749) contains the initial admin credentials.
-- For production: change admin password via Supabase Dashboard > Authentication > Users.
