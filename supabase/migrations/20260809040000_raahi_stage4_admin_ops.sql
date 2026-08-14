-- ============================================================
-- RAAHI STAGE 4 — ADMIN OPERATIONS
-- Migration: 20260809040000_raahi_stage4_admin_ops.sql
-- ============================================================

-- ============================================================
-- STEP 1: EXTEND ENUMS (safe additions only)
-- ============================================================

ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'no_show_marked';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'seat_count_changed';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'booking_reassigned';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'driver_skipped';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'driver_paused_admin';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'driver_removed_admin';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'route_updated';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'pickup_point_updated';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'vehicle_created';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'vehicle_updated';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'vehicle_assigned';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'settings_updated';

COMMIT;

-- ============================================================
-- STEP 2: ADD COLUMNS
-- ============================================================

-- Add fare_per_seat to routes (route-level default fare)
ALTER TABLE public.routes ADD COLUMN IF NOT EXISTS fare_per_seat NUMERIC(10,2) NOT NULL DEFAULT 150;

-- Add traveler_name / traveler_phone to bookings for booking-specific passenger info
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS traveler_name TEXT;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS traveler_phone TEXT;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS no_show_fee NUMERIC(10,2);
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS admin_notes TEXT;

-- ============================================================
-- STEP 3: UPDATE EXISTING ROUTE FARES FROM BUSINESS SETTINGS
-- ============================================================

UPDATE public.routes
SET fare_per_seat = (
  SELECT COALESCE(value::NUMERIC, 150)
  FROM public.business_settings
  WHERE key = 'default_fare_inr'
  LIMIT 1
)
WHERE fare_per_seat = 150;

-- ============================================================
-- STEP 4: RPC — admin_replace_passenger
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_replace_passenger(
  p_admin_id UUID,
  p_booking_id UUID,
  p_new_passenger_id UUID DEFAULT NULL,
  p_new_traveler_name TEXT DEFAULT NULL,
  p_new_traveler_phone TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin RECORD;
  v_booking RECORD;
  v_old_passenger_id UUID;
  v_old_name TEXT;
BEGIN
  -- Validate admin
  SELECT * INTO v_admin FROM public.profiles WHERE id = p_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  -- Get booking
  SELECT b.*, p.name as passenger_name
  INTO v_booking
  FROM public.bookings b
  LEFT JOIN public.profiles p ON p.id = b.passenger_id
  WHERE b.id = p_booking_id AND b.status = 'confirmed';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found or not in confirmed state');
  END IF;

  v_old_passenger_id := v_booking.passenger_id;
  v_old_name := COALESCE(v_booking.traveler_name, v_booking.passenger_name);

  -- Update booking with new passenger info
  UPDATE public.bookings
  SET
    passenger_id = COALESCE(p_new_passenger_id, passenger_id),
    traveler_name = COALESCE(p_new_traveler_name, traveler_name),
    traveler_phone = COALESCE(p_new_traveler_phone, traveler_phone),
    updated_at = NOW()
  WHERE id = p_booking_id;

  -- Audit log
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (
    p_admin_id,
    'passenger_replaced'::public.audit_action,
    'bookings',
    p_booking_id,
    jsonb_build_object('passenger_id', v_old_passenger_id, 'traveler_name', v_old_name),
    jsonb_build_object(
      'new_passenger_id', p_new_passenger_id,
      'new_traveler_name', p_new_traveler_name,
      'new_traveler_phone', p_new_traveler_phone
    ),
    'Admin replaced passenger on booking'
  );

  RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id);
END;
$$;

-- ============================================================
-- STEP 5: RPC — admin_change_seat_count
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_change_seat_count(
  p_admin_id UUID,
  p_booking_id UUID,
  p_new_seat_count INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin RECORD;
  v_booking RECORD;
  v_trip RECORD;
  v_seat_delta INTEGER;
  v_available INTEGER;
BEGIN
  -- Validate admin
  SELECT * INTO v_admin FROM public.profiles WHERE id = p_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  IF p_new_seat_count < 1 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Seat count must be at least 1');
  END IF;

  -- Get booking with trip (lock trip row)
  SELECT b.*, t.total_seats, t.booked_seats, t.status as trip_status
  INTO v_booking
  FROM public.bookings b
  JOIN public.trips t ON t.id = b.trip_id
  WHERE b.id = p_booking_id AND b.status = 'confirmed'
  FOR UPDATE OF t;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found or not confirmed');
  END IF;

  IF v_booking.trip_status IN ('in_progress', 'completed', 'cancelled') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot change seats on a trip that has started or completed');
  END IF;

  v_seat_delta := p_new_seat_count - v_booking.seats;
  v_available := v_booking.total_seats - v_booking.booked_seats;

  -- Check capacity if increasing
  IF v_seat_delta > 0 AND v_seat_delta > v_available THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Only %s additional seat(s) available. Cannot increase to %s seats.', v_available, p_new_seat_count)
    );
  END IF;

  -- Update booking
  UPDATE public.bookings
  SET
    seats = p_new_seat_count,
    total_fare = fare_per_seat * p_new_seat_count,
    updated_at = NOW()
  WHERE id = p_booking_id;

  -- Update trip booked_seats
  UPDATE public.trips
  SET
    booked_seats = booked_seats + v_seat_delta,
    status = CASE
      WHEN (booked_seats + v_seat_delta) >= total_seats THEN 'full'
      WHEN status IN ('full', 'ready') AND (booked_seats + v_seat_delta) < total_seats THEN 'accepting_bookings'
      ELSE status
    END
  WHERE id = v_booking.trip_id;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (
    p_admin_id,
    'seat_count_changed'::public.audit_action,
    'bookings',
    p_booking_id,
    jsonb_build_object('seats', v_booking.seats),
    jsonb_build_object('seats', p_new_seat_count, 'delta', v_seat_delta),
    'Admin changed seat count'
  );

  RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id, 'new_seats', p_new_seat_count);
END;
$$;

-- ============================================================
-- STEP 6: RPC — admin_reassign_booking
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_reassign_booking(
  p_admin_id UUID,
  p_booking_id UUID,
  p_target_trip_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin RECORD;
  v_booking RECORD;
  v_target_trip RECORD;
  v_available INTEGER;
BEGIN
  -- Validate admin
  SELECT * INTO v_admin FROM public.profiles WHERE id = p_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  -- Get booking (lock source trip)
  SELECT b.*, t.route_id as source_route_id, t.booked_seats as source_booked, t.status as source_status
  INTO v_booking
  FROM public.bookings b
  JOIN public.trips t ON t.id = b.trip_id
  WHERE b.id = p_booking_id AND b.status = 'confirmed'
  FOR UPDATE OF t;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found or not confirmed');
  END IF;

  -- Get target trip (lock it too)
  SELECT * INTO v_target_trip
  FROM public.trips
  WHERE id = p_target_trip_id
    AND status IN ('accepting_bookings')
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Target trip not found or not accepting bookings');
  END IF;

  -- Validate same route
  IF v_target_trip.route_id != v_booking.source_route_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Target trip is on a different route');
  END IF;

  -- Check capacity
  v_available := v_target_trip.total_seats - v_target_trip.booked_seats;
  IF v_available < v_booking.seats THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Target trip only has %s seat(s) available, need %s', v_available, v_booking.seats)
    );
  END IF;

  -- Release seats from source trip
  UPDATE public.trips
  SET
    booked_seats = GREATEST(0, booked_seats - v_booking.seats),
    status = CASE
      WHEN status IN ('full', 'ready') THEN 'accepting_bookings'
      ELSE status
    END
  WHERE id = v_booking.trip_id;

  -- Reserve seats on target trip
  UPDATE public.trips
  SET
    booked_seats = booked_seats + v_booking.seats,
    status = CASE
      WHEN (booked_seats + v_booking.seats) >= total_seats THEN 'full'
      ELSE status
    END
  WHERE id = p_target_trip_id;

  -- Move booking to target trip
  UPDATE public.bookings
  SET trip_id = p_target_trip_id, updated_at = NOW()
  WHERE id = p_booking_id;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (
    p_admin_id,
    'booking_reassigned'::public.audit_action,
    'bookings',
    p_booking_id,
    jsonb_build_object('trip_id', v_booking.trip_id),
    jsonb_build_object('trip_id', p_target_trip_id),
    'Admin reassigned booking to another trip'
  );

  RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id, 'new_trip_id', p_target_trip_id);
END;
$$;

-- ============================================================
-- STEP 7: RPC — admin_mark_no_show
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_mark_no_show(
  p_admin_id UUID,
  p_booking_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin RECORD;
  v_booking RECORD;
  v_no_show_fee NUMERIC(10,2);
BEGIN
  SELECT * INTO v_admin FROM public.profiles WHERE id = p_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  SELECT b.* INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id AND b.status = 'confirmed';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found or not in confirmed state');
  END IF;

  -- Get no-show fee
  SELECT COALESCE(value::NUMERIC, 20) INTO v_no_show_fee
  FROM public.business_settings WHERE key = 'no_show_fee_inr';

  -- Mark booking as no_show
  UPDATE public.bookings
  SET status = 'no_show', no_show_fee = v_no_show_fee, updated_at = NOW()
  WHERE id = p_booking_id;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    p_admin_id,
    'no_show_marked'::public.audit_action,
    'bookings',
    p_booking_id,
    jsonb_build_object('no_show_fee', v_no_show_fee),
    'Admin marked passenger as no-show'
  );

  RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id, 'no_show_fee', v_no_show_fee);
END;
$$;

-- ============================================================
-- STEP 8: RPC — admin_cancel_booking
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_cancel_booking(
  p_admin_id UUID,
  p_booking_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin RECORD;
  v_booking RECORD;
BEGIN
  SELECT * INTO v_admin FROM public.profiles WHERE id = p_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  SELECT b.*, t.status as trip_status
  INTO v_booking
  FROM public.bookings b
  JOIN public.trips t ON t.id = b.trip_id
  WHERE b.id = p_booking_id AND b.status = 'confirmed';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found or already cancelled');
  END IF;

  -- Cancel booking
  UPDATE public.bookings SET status = 'cancelled', admin_notes = p_reason, updated_at = NOW()
  WHERE id = p_booking_id;

  -- Release seat if trip not started
  IF v_booking.trip_status IN ('accepting_bookings', 'full', 'ready') THEN
    UPDATE public.trips
    SET
      booked_seats = GREATEST(0, booked_seats - v_booking.seats),
      status = CASE
        WHEN status IN ('full', 'ready') THEN 'accepting_bookings'
        ELSE status
      END
    WHERE id = v_booking.trip_id;
  END IF;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    p_admin_id,
    'booking_cancelled'::public.audit_action,
    'bookings',
    p_booking_id,
    jsonb_build_object('cancelled_by', 'admin', 'reason', p_reason),
    COALESCE(p_reason, 'Admin cancelled booking')
  );

  RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id);
END;
$$;

-- ============================================================
-- STEP 9: RPC — admin_pause_driver
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_pause_driver(
  p_admin_id UUID,
  p_queue_entry_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin RECORD;
  v_queue RECORD;
BEGIN
  SELECT * INTO v_admin FROM public.profiles WHERE id = p_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  SELECT dq.*, d.id as driver_rec_id
  INTO v_queue
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  WHERE dq.id = p_queue_entry_id AND dq.status IN ('waiting', 'active');

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Queue entry not found or not active/waiting');
  END IF;

  UPDATE public.driver_queue SET status = 'paused' WHERE id = p_queue_entry_id;
  UPDATE public.drivers SET availability_status = 'paused' WHERE id = v_queue.driver_rec_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, notes)
  VALUES (p_admin_id, 'driver_paused_admin'::public.audit_action, 'driver_queue', p_queue_entry_id, 'Admin paused driver');

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================
-- STEP 10: RPC — admin_skip_driver
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_skip_driver(
  p_admin_id UUID,
  p_queue_entry_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin RECORD;
  v_queue RECORD;
  v_max_pos INTEGER;
BEGIN
  SELECT * INTO v_admin FROM public.profiles WHERE id = p_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  SELECT * INTO v_queue
  FROM public.driver_queue
  WHERE id = p_queue_entry_id AND status = 'waiting';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Queue entry not found or not in waiting state');
  END IF;

  -- Move to end of queue
  SELECT COALESCE(MAX(queue_position), 0) INTO v_max_pos
  FROM public.driver_queue
  WHERE route_id = v_queue.route_id AND status = 'waiting';

  UPDATE public.driver_queue
  SET queue_position = v_max_pos + 1, joined_at = NOW()
  WHERE id = p_queue_entry_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, notes)
  VALUES (p_admin_id, 'driver_skipped'::public.audit_action, 'driver_queue', p_queue_entry_id, 'Admin skipped driver in queue');

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================
-- STEP 11: RPC — admin_remove_from_queue
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_remove_from_queue(
  p_admin_id UUID,
  p_queue_entry_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin RECORD;
  v_queue RECORD;
  v_confirmed_bookings INTEGER;
BEGIN
  SELECT * INTO v_admin FROM public.profiles WHERE id = p_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  SELECT dq.*, d.id as driver_rec_id
  INTO v_queue
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  WHERE dq.id = p_queue_entry_id AND dq.status IN ('waiting', 'active', 'paused');

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Queue entry not found');
  END IF;

  -- Check for confirmed bookings if active
  IF v_queue.status = 'active' THEN
    SELECT COUNT(*) INTO v_confirmed_bookings
    FROM public.bookings b
    JOIN public.trips t ON t.id = b.trip_id
    WHERE t.queue_entry_id = p_queue_entry_id AND b.status = 'confirmed';

    IF v_confirmed_bookings > 0 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', format('Driver has %s confirmed booking(s). Reassign passengers before removing.', v_confirmed_bookings)
      );
    END IF;

    -- Cancel the active trip
    UPDATE public.trips SET status = 'cancelled' WHERE queue_entry_id = p_queue_entry_id AND status IN ('accepting_bookings', 'full', 'ready');

    -- Activate next driver
    PERFORM public.activate_next_driver(v_queue.route_id);
  END IF;

  UPDATE public.driver_queue SET status = 'cancelled', completed_at = NOW() WHERE id = p_queue_entry_id;
  UPDATE public.drivers SET availability_status = 'offline', current_route_id = NULL WHERE id = v_queue.driver_rec_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, notes)
  VALUES (p_admin_id, 'driver_removed_admin'::public.audit_action, 'driver_queue', p_queue_entry_id, COALESCE(p_reason, 'Admin removed driver from queue'));

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================
-- STEP 12: RPC — admin_update_route_fare
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_update_route_fare(
  p_admin_id UUID,
  p_route_id UUID,
  p_new_fare NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin RECORD;
  v_old_fare NUMERIC;
BEGIN
  SELECT * INTO v_admin FROM public.profiles WHERE id = p_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  IF p_new_fare < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Fare cannot be negative');
  END IF;

  SELECT fare_per_seat INTO v_old_fare FROM public.routes WHERE id = p_route_id;

  UPDATE public.routes SET fare_per_seat = p_new_fare, updated_at = NOW() WHERE id = p_route_id;

  -- Also update any currently active trips for this route
  UPDATE public.trips SET fare_per_seat = p_new_fare
  WHERE route_id = p_route_id AND status = 'accepting_bookings';

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (
    p_admin_id,
    'route_updated'::public.audit_action,
    'routes',
    p_route_id,
    jsonb_build_object('fare_per_seat', v_old_fare),
    jsonb_build_object('fare_per_seat', p_new_fare),
    'Admin updated route fare'
  );

  RETURN jsonb_build_object('success', true, 'route_id', p_route_id, 'new_fare', p_new_fare);
END;
$$;

-- ============================================================
-- STEP 13: RPC — admin_update_business_setting
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_update_business_setting(
  p_admin_id UUID,
  p_key TEXT,
  p_value TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin RECORD;
  v_old_value TEXT;
BEGIN
  SELECT * INTO v_admin FROM public.profiles WHERE id = p_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  SELECT value INTO v_old_value FROM public.business_settings WHERE key = p_key;

  UPDATE public.business_settings
  SET value = p_value, updated_by = p_admin_id, updated_at = NOW()
  WHERE key = p_key;

  IF NOT FOUND THEN
    INSERT INTO public.business_settings (key, value, updated_by)
    VALUES (p_key, p_value, p_admin_id);
  END IF;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (
    p_admin_id,
    'settings_updated'::public.audit_action,
    'business_settings',
    NULL,
    jsonb_build_object('key', p_key, 'value', v_old_value),
    jsonb_build_object('key', p_key, 'value', p_value),
    format('Admin updated setting: %s', p_key)
  );

  RETURN jsonb_build_object('success', true, 'key', p_key, 'value', p_value);
END;
$$;

-- ============================================================
-- STEP 14: Update get_active_trip_for_route to use route fare
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_active_trip_for_route(p_route_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trip RECORD;
  v_result JSONB;
BEGIN
  SELECT
    t.id as trip_id,
    t.route_id,
    t.total_seats,
    t.booked_seats,
    (t.total_seats - t.booked_seats) as available_seats,
    COALESCE(t.fare_per_seat, r.fare_per_seat, 150) as fare_per_seat,
    t.status,
    r.from_location,
    r.to_location,
    v.make as vehicle_make,
    v.model as vehicle_model,
    v.vehicle_type,
    v.registration_number as vehicle_registration,
    p.name as driver_name
  INTO v_trip
  FROM public.trips t
  JOIN public.routes r ON r.id = t.route_id
  LEFT JOIN public.vehicles v ON v.id = t.vehicle_id
  LEFT JOIN public.drivers d ON d.id = t.driver_id
  LEFT JOIN public.profiles p ON p.id = d.profile_id
  WHERE t.route_id = p_route_id
    AND t.status = 'accepting_bookings'
  ORDER BY t.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  RETURN jsonb_build_object(
    'found', true,
    'trip_id', v_trip.trip_id,
    'route_id', v_trip.route_id,
    'from_location', v_trip.from_location,
    'to_location', v_trip.to_location,
    'total_seats', v_trip.total_seats,
    'booked_seats', v_trip.booked_seats,
    'available_seats', v_trip.available_seats,
    'fare_per_seat', v_trip.fare_per_seat,
    'status', v_trip.status,
    'vehicle_make', v_trip.vehicle_make,
    'vehicle_model', v_trip.vehicle_model,
    'vehicle_type', v_trip.vehicle_type,
    'vehicle_registration', v_trip.vehicle_registration,
    'driver_name', v_trip.driver_name
  );
END;
$$;

-- ============================================================
-- STEP 15: RLS for new columns / operations
-- ============================================================

-- Allow admin to update routes
DROP POLICY IF EXISTS "Admin can update routes" ON public.routes;
CREATE POLICY "Admin can update routes" ON public.routes
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Allow admin to manage vehicles
DROP POLICY IF EXISTS "Admin can manage vehicles" ON public.vehicles;
CREATE POLICY "Admin can manage vehicles" ON public.vehicles
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Allow admin to manage pickup_points
DROP POLICY IF EXISTS "Admin can manage pickup_points" ON public.pickup_points;
CREATE POLICY "Admin can manage pickup_points" ON public.pickup_points
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Allow admin to manage business_settings
DROP POLICY IF EXISTS "Admin can manage business_settings" ON public.business_settings;
CREATE POLICY "Admin can manage business_settings" ON public.business_settings
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Allow admin to read/update bookings
DROP POLICY IF EXISTS "Admin can manage bookings" ON public.bookings;
CREATE POLICY "Admin can manage bookings" ON public.bookings
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Allow admin to read audit_logs
DROP POLICY IF EXISTS "Admin can read audit_logs" ON public.audit_logs;
CREATE POLICY "Admin can read audit_logs" ON public.audit_logs
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );
