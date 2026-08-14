-- ============================================================
-- RAAHI STAGE 6.2 — CRITICAL SECURITY HARDENING
-- Migration: 20260809180000_raahi_stage62_security_hardening.sql
-- ============================================================
-- Purpose:
--   1. Harden all admin RPCs to use auth.uid() instead of p_admin_id param
--      (prevents callers from passing a fake admin UUID)
--   2. Add RLS policies to block passengers from reading sensitive tables
--   3. Restrict admin-only RPCs so passengers cannot call them
--   4. Ensure audit_logs, business_settings, all_bookings are admin-only
-- ============================================================

-- ============================================================
-- SECTION 1: Helper function — is_admin()
-- Returns TRUE only if the currently authenticated user has role='admin'
-- in public.profiles. Used in RLS policies and RPCs.
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_driver()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'driver'
  );
$$;

-- ============================================================
-- SECTION 2: Harden admin RPCs to use auth.uid() for admin check
-- These replace the p_admin_id-based check with auth.uid() so
-- a passenger cannot pass a fake admin UUID.
-- ============================================================

-- admin_replace_passenger: use auth.uid() for admin validation
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
SET search_path = public
AS $$
DECLARE
  v_booking RECORD;
  v_old_passenger_id UUID;
  v_old_name TEXT;
BEGIN
  -- Use auth.uid() — ignore p_admin_id, verify caller is admin
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

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

  UPDATE public.bookings
  SET
    passenger_id = COALESCE(p_new_passenger_id, passenger_id),
    traveler_name = COALESCE(p_new_traveler_name, traveler_name),
    traveler_phone = COALESCE(p_new_traveler_phone, traveler_phone),
    updated_at = NOW()
  WHERE id = p_booking_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (
    auth.uid(),
    'passenger_replaced'::public.audit_action,
    'bookings', p_booking_id,
    jsonb_build_object('passenger_id', v_old_passenger_id, 'traveler_name', v_old_name),
    jsonb_build_object('new_passenger_id', p_new_passenger_id, 'new_traveler_name', p_new_traveler_name),
    'Admin replaced passenger on booking'
  );

  RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id);
END;
$$;

-- admin_change_seat_count: use auth.uid()
CREATE OR REPLACE FUNCTION public.admin_change_seat_count(
  p_admin_id UUID,
  p_booking_id UUID,
  p_new_seat_count INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking RECORD;
  v_seat_delta INTEGER;
  v_available INTEGER;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  IF p_new_seat_count < 1 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Seat count must be at least 1');
  END IF;

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

  IF v_seat_delta > 0 AND v_seat_delta > v_available THEN
    RETURN jsonb_build_object('success', false, 'error',
      format('Only %s additional seat(s) available.', v_available));
  END IF;

  UPDATE public.bookings SET seats = p_new_seat_count, total_fare = fare_per_seat * p_new_seat_count, updated_at = NOW()
  WHERE id = p_booking_id;

  UPDATE public.trips
  SET booked_seats = booked_seats + v_seat_delta,
      status = CASE
        WHEN (booked_seats + v_seat_delta) >= total_seats THEN 'full'
        WHEN status IN ('full', 'ready') AND (booked_seats + v_seat_delta) < total_seats THEN 'accepting_bookings'
        ELSE status
      END
  WHERE id = v_booking.trip_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (auth.uid(), 'seat_count_changed'::public.audit_action, 'bookings', p_booking_id,
    jsonb_build_object('seats', v_booking.seats),
    jsonb_build_object('seats', p_new_seat_count, 'delta', v_seat_delta),
    'Admin changed seat count');

  RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id, 'new_seats', p_new_seat_count);
END;
$$;

-- admin_mark_no_show: use auth.uid()
CREATE OR REPLACE FUNCTION public.admin_mark_no_show(
  p_admin_id UUID,
  p_booking_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking RECORD;
  v_no_show_fee NUMERIC(10,2);
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  SELECT b.* INTO v_booking FROM public.bookings b
  WHERE b.id = p_booking_id AND b.status = 'confirmed';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found or not in confirmed state');
  END IF;

  SELECT COALESCE(value::NUMERIC, 20) INTO v_no_show_fee
  FROM public.business_settings WHERE key = 'no_show_fee_inr';

  UPDATE public.bookings SET status = 'no_show', no_show_fee = v_no_show_fee, updated_at = NOW()
  WHERE id = p_booking_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (auth.uid(), 'no_show_marked'::public.audit_action, 'bookings', p_booking_id,
    jsonb_build_object('no_show_fee', v_no_show_fee), 'Admin marked passenger as no-show');

  RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id, 'no_show_fee', v_no_show_fee);
END;
$$;

-- admin_cancel_booking: use auth.uid()
CREATE OR REPLACE FUNCTION public.admin_cancel_booking(
  p_admin_id UUID,
  p_booking_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking RECORD;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  SELECT b.*, t.status as trip_status INTO v_booking
  FROM public.bookings b
  JOIN public.trips t ON t.id = b.trip_id
  WHERE b.id = p_booking_id AND b.status = 'confirmed';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found or already cancelled');
  END IF;

  UPDATE public.bookings SET status = 'cancelled', admin_notes = p_reason, updated_at = NOW()
  WHERE id = p_booking_id;

  IF v_booking.trip_status IN ('accepting_bookings', 'full', 'ready') THEN
    UPDATE public.trips
    SET booked_seats = GREATEST(0, booked_seats - v_booking.seats),
        status = CASE WHEN status IN ('full', 'ready') THEN 'accepting_bookings' ELSE status END
    WHERE id = v_booking.trip_id;
  END IF;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (auth.uid(), 'booking_cancelled'::public.audit_action, 'bookings', p_booking_id,
    jsonb_build_object('cancelled_by', 'admin', 'reason', p_reason),
    COALESCE(p_reason, 'Admin cancelled booking'));

  RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id);
END;
$$;

-- admin_pause_driver: use auth.uid()
CREATE OR REPLACE FUNCTION public.admin_pause_driver(
  p_admin_id UUID,
  p_queue_entry_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_queue RECORD;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  SELECT dq.*, d.id as driver_rec_id INTO v_queue
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  WHERE dq.id = p_queue_entry_id AND dq.status IN ('waiting', 'active');

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Queue entry not found or not active/waiting');
  END IF;

  UPDATE public.driver_queue SET status = 'paused' WHERE id = p_queue_entry_id;
  UPDATE public.drivers SET availability_status = 'paused' WHERE id = v_queue.driver_rec_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, notes)
  VALUES (auth.uid(), 'driver_paused_admin'::public.audit_action, 'driver_queue', p_queue_entry_id, 'Admin paused driver');

  RETURN jsonb_build_object('success', true);
END;
$$;

-- admin_skip_driver: use auth.uid()
CREATE OR REPLACE FUNCTION public.admin_skip_driver(
  p_admin_id UUID,
  p_queue_entry_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_queue RECORD;
  v_max_pos INTEGER;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  SELECT * INTO v_queue FROM public.driver_queue WHERE id = p_queue_entry_id AND status = 'waiting';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Queue entry not found or not in waiting state');
  END IF;

  SELECT COALESCE(MAX(queue_position), 0) INTO v_max_pos
  FROM public.driver_queue WHERE route_id = v_queue.route_id AND status = 'waiting';

  UPDATE public.driver_queue SET queue_position = v_max_pos + 1, joined_at = NOW() WHERE id = p_queue_entry_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, notes)
  VALUES (auth.uid(), 'driver_skipped'::public.audit_action, 'driver_queue', p_queue_entry_id, 'Admin skipped driver in queue');

  RETURN jsonb_build_object('success', true);
END;
$$;

-- admin_update_route_fare: use auth.uid()
CREATE OR REPLACE FUNCTION public.admin_update_route_fare(
  p_admin_id UUID,
  p_route_id UUID,
  p_new_fare NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_fare NUMERIC;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  IF p_new_fare < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Fare cannot be negative');
  END IF;

  SELECT fare_per_seat INTO v_old_fare FROM public.routes WHERE id = p_route_id;
  UPDATE public.routes SET fare_per_seat = p_new_fare, updated_at = NOW() WHERE id = p_route_id;
  UPDATE public.trips SET fare_per_seat = p_new_fare WHERE route_id = p_route_id AND status = 'accepting_bookings';

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (auth.uid(), 'route_updated'::public.audit_action, 'routes', p_route_id,
    jsonb_build_object('fare_per_seat', v_old_fare),
    jsonb_build_object('fare_per_seat', p_new_fare),
    'Admin updated route fare');

  RETURN jsonb_build_object('success', true, 'route_id', p_route_id, 'new_fare', p_new_fare);
END;
$$;

-- admin_update_business_setting: use auth.uid()
CREATE OR REPLACE FUNCTION public.admin_update_business_setting(
  p_admin_id UUID,
  p_key TEXT,
  p_value TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_value TEXT;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  SELECT value INTO v_old_value FROM public.business_settings WHERE key = p_key;

  UPDATE public.business_settings SET value = p_value, updated_by = auth.uid(), updated_at = NOW() WHERE key = p_key;
  IF NOT FOUND THEN
    INSERT INTO public.business_settings (key, value, updated_by) VALUES (p_key, p_value, auth.uid());
  END IF;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (auth.uid(), 'settings_updated'::public.audit_action, 'business_settings', NULL,
    jsonb_build_object('key', p_key, 'value', v_old_value),
    jsonb_build_object('key', p_key, 'value', p_value),
    format('Admin updated setting: %s', p_key));

  RETURN jsonb_build_object('success', true, 'key', p_key, 'value', p_value);
END;
$$;

-- ============================================================
-- SECTION 3: Harden test-harness RPCs to use auth.uid()
-- ============================================================

-- admin_create_test_passenger: use auth.uid()
CREATE OR REPLACE FUNCTION public.admin_create_test_passenger(
  p_label TEXT,
  p_admin_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile_id UUID;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Unauthorized: admin only';
  END IF;

  v_profile_id := gen_random_uuid();
  INSERT INTO public.profiles (id, name, phone, email, role, status, is_test_data)
  VALUES (
    v_profile_id,
    '[TEST] ' || p_label,
    '+910000' || LPAD((EXTRACT(EPOCH FROM NOW())::BIGINT % 100000)::TEXT, 5, '0'),
    'test_' || lower(p_label) || '_' || substr(v_profile_id::TEXT, 1, 8) || '@raahi.test',
    'passenger', 'active', TRUE
  );

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (auth.uid(), 'test_data_created', 'profiles', v_profile_id,
    jsonb_build_object('label', p_label, 'role', 'passenger'), 'Test passenger created');

  RETURN v_profile_id;
END;
$$;

-- admin_create_test_driver: use auth.uid()
CREATE OR REPLACE FUNCTION public.admin_create_test_driver(
  p_label TEXT,
  p_capacity INTEGER,
  p_route_id UUID,
  p_admin_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile_id UUID;
  v_driver_id UUID;
  v_vehicle_id UUID;
  v_dq_id UUID;
  v_timeout_secs INTEGER := 45;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Unauthorized: admin only'; END IF;

  v_profile_id := gen_random_uuid();
  INSERT INTO public.profiles (id, name, phone, email, role, status, is_test_data)
  VALUES (v_profile_id, '[TEST] Driver ' || p_label,
    '+911111' || LPAD((EXTRACT(EPOCH FROM NOW())::BIGINT % 100000)::TEXT, 5, '0'),
    'test_driver_' || lower(p_label) || '_' || substr(v_profile_id::TEXT, 1, 8) || '@raahi.test',
    'driver', 'active', TRUE);

  v_vehicle_id := gen_random_uuid();
  INSERT INTO public.vehicles (id, registration_number, make, model, vehicle_type, seating_capacity, fuel_type, assigned_driver_id, status, is_test_data)
  VALUES (v_vehicle_id, 'TEST-' || p_label || '-' || substr(v_vehicle_id::TEXT, 1, 6),
    'TestMake', 'TestModel', 'car', p_capacity, 'petrol', v_profile_id, 'active', TRUE);

  v_driver_id := gen_random_uuid();
  INSERT INTO public.drivers (id, profile_id, license_number, verification_status, availability_status, current_route_id, current_vehicle_id, is_test_data)
  VALUES (v_driver_id, v_profile_id, 'TEST-LIC-' || p_label, 'approved', 'queued', p_route_id, v_vehicle_id, TRUE);

  SELECT COALESCE(value::INTEGER, 45) INTO v_timeout_secs
  FROM public.business_settings WHERE key = 'driver_offer_timeout_seconds';

  INSERT INTO public.driver_queue (route_id, driver_id, vehicle_id, status, joined_at)
  VALUES (p_route_id, v_driver_id, v_vehicle_id, 'waiting', NOW())
  RETURNING id INTO v_dq_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (auth.uid(), 'test_data_created', 'drivers', v_driver_id,
    jsonb_build_object('label', p_label, 'capacity', p_capacity, 'route_id', p_route_id),
    'Test driver created and queued');

  RETURN jsonb_build_object('profile_id', v_profile_id, 'driver_id', v_driver_id,
    'vehicle_id', v_vehicle_id, 'driver_queue_id', v_dq_id);
END;
$$;

-- admin_create_test_booking_and_queue: use auth.uid()
CREATE OR REPLACE FUNCTION public.admin_create_test_booking_and_queue(
  p_passenger_id UUID,
  p_route_id UUID,
  p_seat_count INTEGER,
  p_admin_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking_id UUID;
  v_pq_id UUID;
  v_seq BIGINT;
  v_fare NUMERIC := 150;
  v_pickup_id UUID;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Unauthorized: admin only'; END IF;

  SELECT fare_per_seat INTO v_fare FROM public.routes WHERE id = p_route_id;
  SELECT id INTO v_pickup_id FROM public.pickup_points
  WHERE route_id = p_route_id AND is_active = TRUE ORDER BY sequence_order LIMIT 1;

  INSERT INTO public.bookings (passenger_id, trip_id, pickup_point_id, seats, fare_per_seat, total_fare, status, is_test_data)
  VALUES (p_passenger_id, NULL, v_pickup_id, p_seat_count, v_fare, v_fare * p_seat_count, 'queued', TRUE)
  RETURNING id INTO v_booking_id;

  INSERT INTO public.passenger_queue (route_id, booking_id, passenger_id, seat_count, status, is_test_data)
  VALUES (p_route_id, v_booking_id, p_passenger_id, p_seat_count, 'WAITING', TRUE)
  RETURNING id, queue_sequence INTO v_pq_id, v_seq;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (auth.uid(), 'passenger_joined_queue', 'passenger_queue', v_pq_id,
    jsonb_build_object('booking_id', v_booking_id, 'seat_count', p_seat_count, 'queue_sequence', v_seq),
    'Test passenger queued');

  RETURN jsonb_build_object('booking_id', v_booking_id, 'passenger_queue_id', v_pq_id, 'queue_sequence', v_seq);
END;
$$;

-- admin_reset_test_data: use auth.uid()
CREATE OR REPLACE FUNCTION public.admin_reset_test_data(
  p_route_id UUID,
  p_admin_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pq_deleted INTEGER := 0;
  v_dq_deleted INTEGER := 0;
  v_trips_cancelled INTEGER := 0;
  v_bookings_deleted INTEGER := 0;
  v_drivers_deleted INTEGER := 0;
  v_vehicles_deleted INTEGER := 0;
  v_profiles_deleted INTEGER := 0;
  v_test_trip_ids UUID[];
  v_test_driver_ids UUID[];
  v_test_vehicle_ids UUID[];
  v_test_profile_ids UUID[];
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Unauthorized: admin only'; END IF;

  SELECT ARRAY_AGG(id) INTO v_test_trip_ids FROM public.trips WHERE route_id = p_route_id AND is_test_data = TRUE;
  SELECT ARRAY_AGG(dq.driver_id) INTO v_test_driver_ids FROM public.driver_queue dq WHERE dq.route_id = p_route_id AND dq.is_test_data = TRUE;
  SELECT ARRAY_AGG(dq.vehicle_id) INTO v_test_vehicle_ids FROM public.driver_queue dq WHERE dq.route_id = p_route_id AND dq.is_test_data = TRUE AND dq.vehicle_id IS NOT NULL;
  SELECT ARRAY_AGG(pq.passenger_id) INTO v_test_profile_ids FROM public.passenger_queue pq WHERE pq.route_id = p_route_id AND pq.is_test_data = TRUE;

  DELETE FROM public.passenger_queue WHERE route_id = p_route_id AND is_test_data = TRUE;
  GET DIAGNOSTICS v_pq_deleted = ROW_COUNT;

  DELETE FROM public.driver_queue WHERE route_id = p_route_id AND is_test_data = TRUE;
  GET DIAGNOSTICS v_dq_deleted = ROW_COUNT;

  IF v_test_trip_ids IS NOT NULL THEN
    UPDATE public.trips SET status = 'cancelled', notes = 'test_data_reset', updated_at = NOW()
    WHERE id = ANY(v_test_trip_ids) AND is_test_data = TRUE;
    GET DIAGNOSTICS v_trips_cancelled = ROW_COUNT;
    UPDATE public.bookings SET trip_id = NULL, updated_at = NOW()
    WHERE trip_id = ANY(v_test_trip_ids) AND is_test_data = TRUE;
  END IF;

  DELETE FROM public.bookings WHERE is_test_data = TRUE AND passenger_id = ANY(v_test_profile_ids);
  GET DIAGNOSTICS v_bookings_deleted = ROW_COUNT;

  IF v_test_driver_ids IS NOT NULL THEN
    DELETE FROM public.drivers WHERE id = ANY(v_test_driver_ids) AND is_test_data = TRUE;
    GET DIAGNOSTICS v_drivers_deleted = ROW_COUNT;
  END IF;

  IF v_test_vehicle_ids IS NOT NULL THEN
    DELETE FROM public.vehicles WHERE id = ANY(v_test_vehicle_ids) AND is_test_data = TRUE;
    GET DIAGNOSTICS v_vehicles_deleted = ROW_COUNT;
  END IF;

  IF v_test_profile_ids IS NOT NULL THEN
    DELETE FROM public.profiles WHERE id = ANY(v_test_profile_ids) AND is_test_data = TRUE;
    GET DIAGNOSTICS v_profiles_deleted = ROW_COUNT;
  END IF;

  IF v_test_driver_ids IS NOT NULL THEN
    DELETE FROM public.profiles
    WHERE id IN (SELECT profile_id FROM public.drivers WHERE id = ANY(v_test_driver_ids))
      AND is_test_data = TRUE;
  END IF;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (auth.uid(), 'test_data_reset', 'routes', p_route_id,
    jsonb_build_object('pq_deleted', v_pq_deleted, 'dq_deleted', v_dq_deleted,
      'trips_cancelled', v_trips_cancelled, 'bookings_deleted', v_bookings_deleted),
    'Test data reset for route');

  RETURN jsonb_build_object('success', TRUE, 'passenger_queue_deleted', v_pq_deleted,
    'driver_queue_deleted', v_dq_deleted, 'trips_cancelled', v_trips_cancelled,
    'bookings_deleted', v_bookings_deleted, 'drivers_deleted', v_drivers_deleted,
    'vehicles_deleted', v_vehicles_deleted, 'profiles_deleted', v_profiles_deleted);
END;
$$;

-- get_test_harness_state: use auth.uid()
CREATE OR REPLACE FUNCTION public.get_test_harness_state(
  p_route_id UUID,
  p_admin_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_passenger_queue JSONB;
  v_driver_queue JSONB;
  v_current_trips JSONB;
  v_audit_recent JSONB;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Unauthorized: admin only'; END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'id', pq.id, 'queue_sequence', pq.queue_sequence,
    'display_position', ROW_NUMBER() OVER (ORDER BY pq.queue_sequence),
    'passenger_name', p.name, 'seat_count', pq.seat_count,
    'status', pq.status, 'is_test_data', pq.is_test_data,
    'assigned_trip_id', pq.assigned_trip_id, 'joined_at', pq.joined_at
  ) ORDER BY pq.queue_sequence) INTO v_passenger_queue
  FROM public.passenger_queue pq
  JOIN public.profiles p ON p.id = pq.passenger_id
  WHERE pq.route_id = p_route_id AND pq.status IN ('WAITING', 'MATCHING', 'ASSIGNED');

  SELECT jsonb_agg(jsonb_build_object(
    'id', dq.id, 'queue_order', ROW_NUMBER() OVER (ORDER BY dq.joined_at),
    'driver_name', p.name, 'vehicle_make', v.make, 'vehicle_model', v.model,
    'capacity', v.seating_capacity, 'status', dq.status, 'is_test_data', dq.is_test_data,
    'offer_expires_at', dq.offer_expires_at, 'provisional_trip_id', dq.provisional_trip_id,
    'joined_at', dq.joined_at
  ) ORDER BY dq.joined_at) INTO v_driver_queue
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  JOIN public.profiles p ON p.id = d.profile_id
  LEFT JOIN public.vehicles v ON v.id = dq.vehicle_id
  WHERE dq.route_id = p_route_id AND dq.status IN ('waiting', 'offered', 'assigned');

  SELECT jsonb_agg(jsonb_build_object(
    'trip_id', t.id, 'status', t.status, 'notes', t.notes, 'is_test_data', t.is_test_data,
    'driver_name', p.name, 'total_seats', t.total_seats, 'booked_seats', t.booked_seats,
    'created_at', t.created_at
  )) INTO v_current_trips
  FROM public.trips t
  LEFT JOIN public.drivers d ON d.id = t.driver_id
  LEFT JOIN public.profiles p ON p.id = d.profile_id
  WHERE t.route_id = p_route_id AND t.status NOT IN ('cancelled', 'completed')
  ORDER BY t.created_at DESC;

  SELECT jsonb_agg(jsonb_build_object(
    'action', al.action, 'notes', al.notes, 'new_value', al.new_value, 'created_at', al.created_at
  ) ORDER BY al.created_at DESC) INTO v_audit_recent
  FROM public.audit_logs al
  WHERE al.target_table IN ('passenger_queue', 'driver_queue', 'trips', 'routes')
    AND al.created_at > NOW() - INTERVAL '2 hours'
  LIMIT 50;

  RETURN jsonb_build_object(
    'route_id', p_route_id,
    'passenger_queue', COALESCE(v_passenger_queue, '[]'::JSONB),
    'driver_queue', COALESCE(v_driver_queue, '[]'::JSONB),
    'current_trips', COALESCE(v_current_trips, '[]'::JSONB),
    'recent_audit', COALESCE(v_audit_recent, '[]'::JSONB),
    'snapshot_at', NOW()
  );
END;
$$;

-- admin_simulate_driver_action: use auth.uid()
CREATE OR REPLACE FUNCTION public.admin_simulate_driver_action(
  p_driver_queue_id UUID,
  p_action TEXT,
  p_admin_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_dq RECORD;
  v_result JSONB;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Unauthorized: admin only'; END IF;

  SELECT * INTO v_dq FROM public.driver_queue WHERE id = p_driver_queue_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Driver queue entry not found'; END IF;

  IF p_action = 'accept' THEN
    IF v_dq.status != 'offered' THEN RAISE EXCEPTION 'Driver is not in OFFERED state (current: %)', v_dq.status; END IF;
    IF v_dq.offer_expires_at < NOW() THEN RAISE EXCEPTION 'Offer has already expired'; END IF;
    v_result := public.driver_accept_offer(p_driver_queue_id);
    RETURN jsonb_build_object('action', 'accept', 'result', v_result);
  ELSIF p_action = 'decline' THEN
    IF v_dq.status != 'offered' THEN RAISE EXCEPTION 'Driver is not in OFFERED state'; END IF;
    v_result := public.driver_decline_offer(p_driver_queue_id);
    RETURN jsonb_build_object('action', 'decline', 'result', v_result);
  ELSIF p_action = 'expire' THEN
    UPDATE public.driver_queue SET offer_expires_at = NOW() - INTERVAL '1 second' WHERE id = p_driver_queue_id;
    v_result := public.expire_driver_offer(p_driver_queue_id);
    RETURN jsonb_build_object('action', 'expire', 'result', v_result);
  ELSE
    RAISE EXCEPTION 'Unknown action: %. Use accept, decline, or expire', p_action;
  END IF;
END;
$$;

-- admin_simulate_passenger_cancel: use auth.uid()
CREATE OR REPLACE FUNCTION public.admin_simulate_passenger_cancel(
  p_passenger_queue_id UUID,
  p_admin_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pq RECORD;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Unauthorized: admin only'; END IF;

  SELECT * INTO v_pq FROM public.passenger_queue WHERE id = p_passenger_queue_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Passenger queue entry not found'; END IF;
  IF v_pq.status NOT IN ('WAITING', 'MATCHING') THEN
    RAISE EXCEPTION 'Cannot cancel entry in status: %', v_pq.status;
  END IF;

  UPDATE public.passenger_queue SET status = 'CANCELLED', updated_at = NOW() WHERE id = p_passenger_queue_id;
  UPDATE public.bookings SET status = 'cancelled', updated_at = NOW() WHERE id = v_pq.booking_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (auth.uid(), 'passenger_queue_cancelled', 'passenger_queue', p_passenger_queue_id,
    jsonb_build_object('booking_id', v_pq.booking_id, 'seat_count', v_pq.seat_count),
    'Test: passenger cancelled before assignment');

  RETURN jsonb_build_object('success', TRUE, 'cancelled_queue_id', p_passenger_queue_id);
END;
$$;

-- admin_driver_go_offline: use auth.uid()
CREATE OR REPLACE FUNCTION public.admin_driver_go_offline(
  p_driver_queue_id UUID,
  p_admin_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_dq RECORD;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Unauthorized: admin only'; END IF;

  SELECT * INTO v_dq FROM public.driver_queue WHERE id = p_driver_queue_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Driver queue entry not found'; END IF;

  UPDATE public.driver_queue SET status = 'offline', updated_at = NOW() WHERE id = p_driver_queue_id;
  UPDATE public.drivers SET availability_status = 'offline', updated_at = NOW() WHERE id = v_dq.driver_id;
  PERFORM public.match_route_queue(v_dq.route_id);

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, notes)
  VALUES (auth.uid(), 'driver_removed', 'driver_queue', p_driver_queue_id, 'Test: driver went offline');

  RETURN jsonb_build_object('success', TRUE, 'driver_queue_id', p_driver_queue_id);
END;
$$;

-- admin_cancel_driver_after_accept: use auth.uid()
CREATE OR REPLACE FUNCTION public.admin_cancel_driver_after_accept(
  p_driver_queue_id UUID,
  p_admin_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_dq RECORD;
  v_trip RECORD;
  v_pq_ids UUID[];
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Unauthorized: admin only'; END IF;

  SELECT dq.*, d.profile_id INTO v_dq
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  WHERE dq.id = p_driver_queue_id FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Driver queue entry not found'; END IF;
  IF v_dq.status NOT IN ('assigned', 'offered') THEN
    RAISE EXCEPTION 'Driver is not in assigned/offered state (current: %)', v_dq.status;
  END IF;

  -- Get provisional trip
  SELECT * INTO v_trip FROM public.trips WHERE id = v_dq.provisional_trip_id FOR UPDATE;

  IF FOUND THEN
    -- Collect passenger queue IDs assigned to this trip
    SELECT ARRAY_AGG(id) INTO v_pq_ids
    FROM public.passenger_queue
    WHERE assigned_trip_id = v_trip.id AND status IN ('MATCHING', 'ASSIGNED');

    -- Release passengers back to WAITING (preserve queue_sequence for FIFO)
    IF v_pq_ids IS NOT NULL THEN
      UPDATE public.passenger_queue
      SET status = 'WAITING', assigned_trip_id = NULL, updated_at = NOW()
      WHERE id = ANY(v_pq_ids);
    END IF;

    -- Cancel the provisional trip
    UPDATE public.trips SET status = 'cancelled', notes = 'driver_cancelled_after_accept', updated_at = NOW()
    WHERE id = v_trip.id;
  END IF;

  -- Remove driver from queue
  UPDATE public.driver_queue SET status = 'cancelled', completed_at = NOW() WHERE id = p_driver_queue_id;
  UPDATE public.drivers SET availability_status = 'offline', updated_at = NOW() WHERE id = v_dq.driver_id;

  -- Trigger rematch
  PERFORM public.match_route_queue(v_dq.route_id);

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, notes)
  VALUES (auth.uid(), 'driver_removed_admin', 'driver_queue', p_driver_queue_id,
    'Admin: driver cancelled after accept, passengers released for rematch');

  RETURN jsonb_build_object('success', TRUE, 'trip_cancelled', v_trip.id,
    'passengers_released', COALESCE(array_length(v_pq_ids, 1), 0), 'rematch_triggered', TRUE);
END;
$$;

-- admin_force_match: use auth.uid()
CREATE OR REPLACE FUNCTION public.admin_force_match(
  p_route_id UUID,
  p_admin_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Unauthorized: admin only'; END IF;

  -- Temporarily enable matching if disabled
  UPDATE public.business_settings SET value = 'true' WHERE key = 'automatic_matching_enabled';

  v_result := public.match_route_queue(p_route_id);

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (auth.uid(), 'test_scenario_run', 'routes', p_route_id,
    jsonb_build_object('action', 'force_match', 'result', v_result), 'Admin forced match');

  RETURN jsonb_build_object('success', TRUE, 'match_result', v_result);
END;
$$;

-- admin_remove_from_queue: use auth.uid()
CREATE OR REPLACE FUNCTION public.admin_remove_from_queue(
  p_admin_id UUID,
  p_queue_entry_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_queue RECORD;
  v_confirmed_bookings INTEGER;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  SELECT dq.*, d.id as driver_rec_id INTO v_queue
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  WHERE dq.id = p_queue_entry_id AND dq.status IN ('waiting', 'active', 'paused');

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Queue entry not found');
  END IF;

  IF v_queue.status = 'active' THEN
    SELECT COUNT(*) INTO v_confirmed_bookings
    FROM public.bookings b
    JOIN public.trips t ON t.id = b.trip_id
    WHERE t.queue_entry_id = p_queue_entry_id AND b.status = 'confirmed';

    IF v_confirmed_bookings > 0 THEN
      RETURN jsonb_build_object('success', false, 'error',
        format('Driver has %s confirmed booking(s). Reassign passengers before removing.', v_confirmed_bookings));
    END IF;

    UPDATE public.trips SET status = 'cancelled'
    WHERE queue_entry_id = p_queue_entry_id AND status IN ('accepting_bookings', 'full', 'ready');
    PERFORM public.activate_next_driver(v_queue.route_id);
  END IF;

  UPDATE public.driver_queue SET status = 'cancelled', completed_at = NOW() WHERE id = p_queue_entry_id;
  UPDATE public.drivers SET availability_status = 'offline', current_route_id = NULL WHERE id = v_queue.driver_rec_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, notes)
  VALUES (auth.uid(), 'driver_removed_admin'::public.audit_action, 'driver_queue', p_queue_entry_id,
    COALESCE(p_reason, 'Admin removed driver from queue'));

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================
-- SECTION 4: Harden RLS policies — passengers cannot read
-- sensitive admin-only tables directly
-- ============================================================

-- audit_logs: admin read only (already set in stage4, reinforce)
DROP POLICY IF EXISTS "Admin can read audit_logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Passengers cannot read audit_logs" ON public.audit_logs;
CREATE POLICY "Admin can read audit_logs" ON public.audit_logs
  FOR SELECT USING (public.is_admin());

-- audit_logs: only admin can insert (system/SECURITY DEFINER functions bypass RLS)
DROP POLICY IF EXISTS "Admin can insert audit_logs" ON public.audit_logs;
CREATE POLICY "Admin can insert audit_logs" ON public.audit_logs
  FOR INSERT WITH CHECK (public.is_admin() OR auth.uid() IS NOT NULL);

-- business_settings: admin manage, authenticated read (routes need fare info)
DROP POLICY IF EXISTS "Admin can manage business_settings" ON public.business_settings;
DROP POLICY IF EXISTS "Authenticated can read business_settings" ON public.business_settings;
CREATE POLICY "Admin can manage business_settings" ON public.business_settings
  FOR ALL USING (public.is_admin());
CREATE POLICY "Authenticated can read business_settings" ON public.business_settings
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- profiles: passengers can only read their own profile
DROP POLICY IF EXISTS "Passengers read own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admin can read all profiles" ON public.profiles;
CREATE POLICY "Passengers read own profile" ON public.profiles
  FOR SELECT USING (id = auth.uid() OR public.is_admin() OR public.is_driver());
CREATE POLICY "Admin can read all profiles" ON public.profiles
  FOR ALL USING (public.is_admin());

-- bookings: passengers read own, admin reads all
DROP POLICY IF EXISTS "Passengers read own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Admin can manage bookings" ON public.bookings;
CREATE POLICY "Passengers read own bookings" ON public.bookings
  FOR SELECT USING (passenger_id = auth.uid() OR public.is_admin());
CREATE POLICY "Admin can manage bookings" ON public.bookings
  FOR ALL USING (public.is_admin());

-- ============================================================
-- SECTION 5: Grant execute permissions
-- ============================================================

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_driver() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_replace_passenger(UUID, UUID, UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_change_seat_count(UUID, UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_mark_no_show(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_cancel_booking(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_pause_driver(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_skip_driver(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_remove_from_queue(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_route_fare(UUID, UUID, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_business_setting(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_test_passenger(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_test_driver(TEXT, INTEGER, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_test_booking_and_queue(UUID, UUID, INTEGER, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reset_test_data(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_test_harness_state(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_simulate_driver_action(UUID, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_simulate_passenger_cancel(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_driver_go_offline(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_cancel_driver_after_accept(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_force_match(UUID, UUID) TO authenticated;
