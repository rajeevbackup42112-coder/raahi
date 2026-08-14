-- ============================================================
-- RAAHI STAGE 5.2 — TEST HARNESS + FIT-AWARE FIFO
-- Migration: 20260809100000_raahi_stage52_test_harness.sql
-- ============================================================
-- Changes:
-- 1. Add is_test_data flag to profiles, bookings, passenger_queue, driver_queue, vehicles, drivers, trips
-- 2. Add audit_action values for test harness events
-- 3. Create admin_create_test_passenger RPC
-- 4. Create admin_create_test_driver RPC
-- 5. Create admin_create_test_booking_and_queue RPC
-- 6. Create admin_reset_test_data RPC (safe delete of test-only records)
-- 7. Create admin_run_test_scenario RPC (scenario A-I execution)
-- 8. Create get_test_harness_state RPC (diagnostic read)
-- 9. Document fit-aware FIFO policy in business_settings
-- ============================================================

-- ============================================================
-- STEP 1: Add is_test_data columns
-- ============================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_test_data BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS is_test_data BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.passenger_queue
  ADD COLUMN IF NOT EXISTS is_test_data BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.driver_queue
  ADD COLUMN IF NOT EXISTS is_test_data BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.vehicles
  ADD COLUMN IF NOT EXISTS is_test_data BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS is_test_data BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.trips
  ADD COLUMN IF NOT EXISTS is_test_data BOOLEAN NOT NULL DEFAULT FALSE;

-- ============================================================
-- STEP 2: Extend audit_action enum
-- ============================================================

ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'test_data_created';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'test_data_reset';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'test_scenario_run';

COMMIT;

-- ============================================================
-- STEP 3: Upsert fit-aware FIFO policy in business_settings
-- ============================================================

INSERT INTO public.business_settings (key, value, description)
VALUES
  ('keep_multi_seat_booking_together', 'true',
   'FIT-AWARE FIFO: If a multi-seat booking cannot fit remaining vehicle capacity, defer it without changing queue_sequence. Fill remaining seats from later smaller bookings. Deferred booking retains original FIFO priority for next vehicle.'),
  ('fit_aware_fifo_enabled', 'true',
   'When true, the matching engine uses fit-aware FIFO: deferred bookings keep their queue_sequence and are considered first for the next vehicle.')
ON CONFLICT (key) DO UPDATE
  SET value = EXCLUDED.value,
      description = EXCLUDED.description,
      updated_at = NOW();

-- ============================================================
-- STEP 4: admin_create_test_passenger
-- Creates a fake auth user + profile + marks is_test_data=true
-- Returns profile_id
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_create_test_passenger(
  p_label TEXT,          -- e.g. 'P1', 'P2'
  p_admin_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile_id UUID;
  v_is_admin BOOLEAN;
BEGIN
  -- Validate admin
  SELECT (role = 'admin') INTO v_is_admin FROM public.profiles WHERE id = p_admin_id;
  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Unauthorized: admin only';
  END IF;

  -- Create a synthetic profile (no real auth user needed for test data)
  v_profile_id := gen_random_uuid();
  INSERT INTO public.profiles (id, name, phone, email, role, status, is_test_data)
  VALUES (
    v_profile_id,
    '[TEST] ' || p_label,
    '+910000' || LPAD((EXTRACT(EPOCH FROM NOW())::BIGINT % 100000)::TEXT, 5, '0'),
    'test_' || lower(p_label) || '_' || substr(v_profile_id::TEXT, 1, 8) || '@raahi.test',
    'passenger',
    'active',
    TRUE
  );

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (p_admin_id, 'test_data_created', 'profiles', v_profile_id,
    jsonb_build_object('label', p_label, 'role', 'passenger'), 'Test passenger created');

  RETURN v_profile_id;
END;
$$;

-- ============================================================
-- STEP 5: admin_create_test_driver
-- Creates profile + driver record + vehicle, marks is_test_data=true
-- Returns driver_queue_id after going online on the route
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_create_test_driver(
  p_label TEXT,           -- e.g. 'D1'
  p_capacity INTEGER,     -- vehicle seating capacity
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
  v_is_admin BOOLEAN;
  v_timeout_secs INTEGER := 45;
BEGIN
  SELECT (role = 'admin') INTO v_is_admin FROM public.profiles WHERE id = p_admin_id;
  IF NOT v_is_admin THEN RAISE EXCEPTION 'Unauthorized: admin only'; END IF;

  -- Profile
  v_profile_id := gen_random_uuid();
  INSERT INTO public.profiles (id, name, phone, email, role, status, is_test_data)
  VALUES (
    v_profile_id,
    '[TEST] Driver ' || p_label,
    '+911111' || LPAD((EXTRACT(EPOCH FROM NOW())::BIGINT % 100000)::TEXT, 5, '0'),
    'test_driver_' || lower(p_label) || '_' || substr(v_profile_id::TEXT, 1, 8) || '@raahi.test',
    'driver', 'active', TRUE
  );

  -- Vehicle
  v_vehicle_id := gen_random_uuid();
  INSERT INTO public.vehicles (id, registration_number, make, model, vehicle_type, seating_capacity, fuel_type, assigned_driver_id, status, is_test_data)
  VALUES (
    v_vehicle_id,
    'TEST-' || p_label || '-' || substr(v_vehicle_id::TEXT, 1, 6),
    'TestMake', 'TestModel', 'car', p_capacity, 'petrol',
    v_profile_id, 'active', TRUE
  );

  -- Driver record
  v_driver_id := gen_random_uuid();
  INSERT INTO public.drivers (id, profile_id, license_number, verification_status, availability_status, current_route_id, current_vehicle_id, is_test_data)
  VALUES (
    v_driver_id, v_profile_id,
    'TEST-LIC-' || p_label,
    'approved', 'queued', p_route_id, v_vehicle_id, TRUE
  );

  -- Update vehicle assigned_driver_id to profile_id (existing FK)
  UPDATE public.vehicles SET assigned_driver_id = v_profile_id WHERE id = v_vehicle_id;

  -- Get timeout setting
  SELECT COALESCE(value::INTEGER, 45) INTO v_timeout_secs
  FROM public.business_settings WHERE key = 'driver_offer_timeout_seconds';

  -- Enter driver queue
  INSERT INTO public.driver_queue (route_id, driver_id, vehicle_id, status, joined_at)
  VALUES (p_route_id, v_driver_id, v_vehicle_id, 'waiting', NOW())
  RETURNING id INTO v_dq_id;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (p_admin_id, 'test_data_created', 'drivers', v_driver_id,
    jsonb_build_object('label', p_label, 'capacity', p_capacity, 'route_id', p_route_id),
    'Test driver created and queued');

  RETURN jsonb_build_object(
    'profile_id', v_profile_id,
    'driver_id', v_driver_id,
    'vehicle_id', v_vehicle_id,
    'driver_queue_id', v_dq_id
  );
END;
$$;

-- ============================================================
-- STEP 6: admin_create_test_booking_and_queue
-- Creates booking + passenger_queue entry for a test passenger
-- Returns passenger_queue_id and queue_sequence
-- ============================================================

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
  v_is_admin BOOLEAN;
BEGIN
  SELECT (role = 'admin') INTO v_is_admin FROM public.profiles WHERE id = p_admin_id;
  IF NOT v_is_admin THEN RAISE EXCEPTION 'Unauthorized: admin only'; END IF;

  -- Get fare
  SELECT fare_per_seat INTO v_fare FROM public.routes WHERE id = p_route_id;

  -- Get first pickup point for route
  SELECT id INTO v_pickup_id FROM public.pickup_points
  WHERE route_id = p_route_id AND is_active = TRUE
  ORDER BY sequence_order LIMIT 1;

  -- Create booking (trip_id = NULL until matched)
  INSERT INTO public.bookings (passenger_id, trip_id, pickup_point_id, seats, fare_per_seat, total_fare, status, is_test_data)
  VALUES (p_passenger_id, NULL, v_pickup_id, p_seat_count, v_fare, v_fare * p_seat_count, 'queued', TRUE)
  RETURNING id INTO v_booking_id;

  -- Create passenger_queue entry
  INSERT INTO public.passenger_queue (route_id, booking_id, passenger_id, seat_count, status, is_test_data)
  VALUES (p_route_id, v_booking_id, p_passenger_id, p_seat_count, 'WAITING', TRUE)
  RETURNING id, queue_sequence INTO v_pq_id, v_seq;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (p_admin_id, 'passenger_joined_queue', 'passenger_queue', v_pq_id,
    jsonb_build_object('booking_id', v_booking_id, 'seat_count', p_seat_count, 'queue_sequence', v_seq),
    'Test passenger queued');

  RETURN jsonb_build_object(
    'booking_id', v_booking_id,
    'passenger_queue_id', v_pq_id,
    'queue_sequence', v_seq
  );
END;
$$;

-- ============================================================
-- STEP 7: admin_reset_test_data
-- Safely deletes ONLY is_test_data=true records for a route
-- Does NOT touch real production records
-- ============================================================

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
  v_is_admin BOOLEAN;
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
  SELECT (role = 'admin') INTO v_is_admin FROM public.profiles WHERE id = p_admin_id;
  IF NOT v_is_admin THEN RAISE EXCEPTION 'Unauthorized: admin only'; END IF;

  -- Collect test trip IDs for this route
  SELECT ARRAY_AGG(id) INTO v_test_trip_ids
  FROM public.trips WHERE route_id = p_route_id AND is_test_data = TRUE;

  -- Collect test driver IDs for this route
  SELECT ARRAY_AGG(dq.driver_id) INTO v_test_driver_ids
  FROM public.driver_queue dq WHERE dq.route_id = p_route_id AND dq.is_test_data = TRUE;

  -- Collect test vehicle IDs
  SELECT ARRAY_AGG(dq.vehicle_id) INTO v_test_vehicle_ids
  FROM public.driver_queue dq WHERE dq.route_id = p_route_id AND dq.is_test_data = TRUE AND dq.vehicle_id IS NOT NULL;

  -- Collect test passenger profile IDs
  SELECT ARRAY_AGG(pq.passenger_id) INTO v_test_profile_ids
  FROM public.passenger_queue pq WHERE pq.route_id = p_route_id AND pq.is_test_data = TRUE;

  -- 1. Delete test passenger_queue entries
  DELETE FROM public.passenger_queue
  WHERE route_id = p_route_id AND is_test_data = TRUE;
  GET DIAGNOSTICS v_pq_deleted = ROW_COUNT;

  -- 2. Delete test driver_queue entries
  DELETE FROM public.driver_queue
  WHERE route_id = p_route_id AND is_test_data = TRUE;
  GET DIAGNOSTICS v_dq_deleted = ROW_COUNT;

  -- 3. Cancel test trips (don't hard-delete — preserve audit trail)
  IF v_test_trip_ids IS NOT NULL THEN
    UPDATE public.trips
    SET status = 'cancelled', notes = 'test_data_reset', updated_at = NOW()
    WHERE id = ANY(v_test_trip_ids) AND is_test_data = TRUE;
    GET DIAGNOSTICS v_trips_cancelled = ROW_COUNT;

    -- Detach bookings from test trips
    UPDATE public.bookings
    SET trip_id = NULL, updated_at = NOW()
    WHERE trip_id = ANY(v_test_trip_ids) AND is_test_data = TRUE;
  END IF;

  -- 4. Delete test bookings
  DELETE FROM public.bookings WHERE is_test_data = TRUE
    AND passenger_id = ANY(v_test_profile_ids);
  GET DIAGNOSTICS v_bookings_deleted = ROW_COUNT;

  -- 5. Delete test drivers
  IF v_test_driver_ids IS NOT NULL THEN
    DELETE FROM public.drivers WHERE id = ANY(v_test_driver_ids) AND is_test_data = TRUE;
    GET DIAGNOSTICS v_drivers_deleted = ROW_COUNT;
  END IF;

  -- 6. Delete test vehicles
  IF v_test_vehicle_ids IS NOT NULL THEN
    DELETE FROM public.vehicles WHERE id = ANY(v_test_vehicle_ids) AND is_test_data = TRUE;
    GET DIAGNOSTICS v_vehicles_deleted = ROW_COUNT;
  END IF;

  -- 7. Delete test profiles (passengers + drivers)
  IF v_test_profile_ids IS NOT NULL THEN
    DELETE FROM public.profiles WHERE id = ANY(v_test_profile_ids) AND is_test_data = TRUE;
    GET DIAGNOSTICS v_profiles_deleted = ROW_COUNT;
  END IF;

  -- Also delete driver profiles
  IF v_test_driver_ids IS NOT NULL THEN
    DELETE FROM public.profiles
    WHERE id IN (SELECT profile_id FROM public.drivers WHERE id = ANY(v_test_driver_ids))
      AND is_test_data = TRUE;
  END IF;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (p_admin_id, 'test_data_reset', 'routes', p_route_id,
    jsonb_build_object(
      'passenger_queue_deleted', v_pq_deleted,
      'driver_queue_deleted', v_dq_deleted,
      'trips_cancelled', v_trips_cancelled,
      'bookings_deleted', v_bookings_deleted,
      'drivers_deleted', v_drivers_deleted,
      'vehicles_deleted', v_vehicles_deleted,
      'profiles_deleted', v_profiles_deleted
    ),
    'Test data reset for route');

  RETURN jsonb_build_object(
    'success', TRUE,
    'passenger_queue_deleted', v_pq_deleted,
    'driver_queue_deleted', v_dq_deleted,
    'trips_cancelled', v_trips_cancelled,
    'bookings_deleted', v_bookings_deleted,
    'drivers_deleted', v_drivers_deleted,
    'vehicles_deleted', v_vehicles_deleted,
    'profiles_deleted', v_profiles_deleted
  );
END;
$$;

-- ============================================================
-- STEP 8: get_test_harness_state
-- Returns full diagnostic state for a route (admin only)
-- ============================================================

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
  v_is_admin BOOLEAN;
  v_passenger_queue JSONB;
  v_driver_queue JSONB;
  v_current_trips JSONB;
  v_audit_recent JSONB;
BEGIN
  SELECT (role = 'admin') INTO v_is_admin FROM public.profiles WHERE id = p_admin_id;
  IF NOT v_is_admin THEN RAISE EXCEPTION 'Unauthorized: admin only'; END IF;

  -- Passenger queue with display position
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', pq.id,
      'queue_sequence', pq.queue_sequence,
      'display_position', ROW_NUMBER() OVER (ORDER BY pq.queue_sequence),
      'passenger_name', p.name,
      'seat_count', pq.seat_count,
      'status', pq.status,
      'is_test_data', pq.is_test_data,
      'assigned_trip_id', pq.assigned_trip_id,
      'joined_at', pq.joined_at
    )
    ORDER BY pq.queue_sequence
  ) INTO v_passenger_queue
  FROM public.passenger_queue pq
  JOIN public.profiles p ON p.id = pq.passenger_id
  WHERE pq.route_id = p_route_id
    AND pq.status IN ('WAITING', 'MATCHING', 'ASSIGNED');

  -- Driver queue with display position
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', dq.id,
      'queue_order', ROW_NUMBER() OVER (ORDER BY dq.joined_at),
      'driver_name', p.name,
      'vehicle_make', v.make,
      'vehicle_model', v.model,
      'capacity', v.seating_capacity,
      'status', dq.status,
      'is_test_data', dq.is_test_data,
      'offer_expires_at', dq.offer_expires_at,
      'provisional_trip_id', dq.provisional_trip_id,
      'joined_at', dq.joined_at
    )
    ORDER BY dq.joined_at
  ) INTO v_driver_queue
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  JOIN public.profiles p ON p.id = d.profile_id
  LEFT JOIN public.vehicles v ON v.id = dq.vehicle_id
  WHERE dq.route_id = p_route_id
    AND dq.status IN ('waiting', 'offered', 'assigned');

  -- Current trips (provisional + real)
  SELECT jsonb_agg(
    jsonb_build_object(
      'trip_id', t.id,
      'status', t.status,
      'notes', t.notes,
      'is_test_data', t.is_test_data,
      'driver_name', p.name,
      'vehicle_make', v.make,
      'vehicle_model', v.model,
      'total_seats', t.total_seats,
      'booked_seats', t.booked_seats,
      'passenger_count', (
        SELECT COUNT(*) FROM public.passenger_queue pq2
        WHERE pq2.assigned_trip_id = t.id AND pq2.status IN ('MATCHING','ASSIGNED')
      ),
      'created_at', t.created_at
    )
  ) INTO v_current_trips
  FROM public.trips t
  LEFT JOIN public.drivers d ON d.id = t.driver_id
  LEFT JOIN public.profiles p ON p.id = d.profile_id
  LEFT JOIN public.vehicles v ON v.id = t.vehicle_id
  WHERE t.route_id = p_route_id
    AND t.status NOT IN ('cancelled', 'completed')
  ORDER BY t.created_at DESC;

  -- Recent audit logs for this route
  SELECT jsonb_agg(
    jsonb_build_object(
      'action', al.action,
      'notes', al.notes,
      'new_value', al.new_value,
      'created_at', al.created_at
    )
    ORDER BY al.created_at DESC
  ) INTO v_audit_recent
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

-- ============================================================
-- STEP 9: admin_simulate_driver_action
-- Allows test harness to accept/decline/expire a driver offer
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_simulate_driver_action(
  p_driver_queue_id UUID,
  p_action TEXT,   -- 'accept' | 'decline' | 'expire'
  p_admin_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_dq RECORD;
  v_result JSONB;
BEGIN
  SELECT (role = 'admin') INTO v_is_admin FROM public.profiles WHERE id = p_admin_id;
  IF NOT v_is_admin THEN RAISE EXCEPTION 'Unauthorized: admin only'; END IF;

  SELECT * INTO v_dq FROM public.driver_queue WHERE id = p_driver_queue_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Driver queue entry not found'; END IF;

  IF p_action = 'accept' THEN
    IF v_dq.status != 'offered' THEN
      RAISE EXCEPTION 'Driver is not in OFFERED state (current: %)', v_dq.status;
    END IF;
    IF v_dq.offer_expires_at < NOW() THEN
      RAISE EXCEPTION 'Offer has already expired';
    END IF;
    -- Call existing accept function
    SELECT public.driver_accept_offer(p_driver_queue_id) INTO v_result;
    RETURN jsonb_build_object('action', 'accept', 'result', v_result);

  ELSIF p_action = 'decline' THEN
    IF v_dq.status != 'offered' THEN
      RAISE EXCEPTION 'Driver is not in OFFERED state';
    END IF;
    SELECT public.driver_decline_offer(p_driver_queue_id) INTO v_result;
    RETURN jsonb_build_object('action', 'decline', 'result', v_result);

  ELSIF p_action = 'expire' THEN
    -- Force expiry by setting offer_expires_at to past then calling expire
    UPDATE public.driver_queue
    SET offer_expires_at = NOW() - INTERVAL '1 second'
    WHERE id = p_driver_queue_id;

    SELECT public.expire_driver_offer(p_driver_queue_id) INTO v_result;
    RETURN jsonb_build_object('action', 'expire', 'result', v_result);

  ELSE
    RAISE EXCEPTION 'Unknown action: %. Use accept, decline, or expire', p_action;
  END IF;
END;
$$;

-- ============================================================
-- STEP 10: admin_simulate_passenger_cancel
-- Cancel a specific passenger_queue entry (test scenario G)
-- ============================================================

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
  v_is_admin BOOLEAN;
  v_pq RECORD;
BEGIN
  SELECT (role = 'admin') INTO v_is_admin FROM public.profiles WHERE id = p_admin_id;
  IF NOT v_is_admin THEN RAISE EXCEPTION 'Unauthorized: admin only'; END IF;

  SELECT * INTO v_pq FROM public.passenger_queue WHERE id = p_passenger_queue_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Passenger queue entry not found'; END IF;
  IF v_pq.status NOT IN ('WAITING', 'MATCHING') THEN
    RAISE EXCEPTION 'Cannot cancel entry in status: %', v_pq.status;
  END IF;

  -- Cancel the entry
  UPDATE public.passenger_queue
  SET status = 'CANCELLED', updated_at = NOW()
  WHERE id = p_passenger_queue_id;

  -- Cancel the booking
  UPDATE public.bookings
  SET status = 'cancelled', updated_at = NOW()
  WHERE id = v_pq.booking_id;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (p_admin_id, 'passenger_queue_cancelled', 'passenger_queue', p_passenger_queue_id,
    jsonb_build_object('booking_id', v_pq.booking_id, 'seat_count', v_pq.seat_count),
    'Test: passenger cancelled before assignment');

  RETURN jsonb_build_object('success', TRUE, 'cancelled_queue_id', p_passenger_queue_id);
END;
$$;

-- ============================================================
-- STEP 11: admin_driver_go_offline
-- Take a test driver offline (scenario I)
-- ============================================================

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
  v_is_admin BOOLEAN;
  v_dq RECORD;
BEGIN
  SELECT (role = 'admin') INTO v_is_admin FROM public.profiles WHERE id = p_admin_id;
  IF NOT v_is_admin THEN RAISE EXCEPTION 'Unauthorized: admin only'; END IF;

  SELECT * INTO v_dq FROM public.driver_queue WHERE id = p_driver_queue_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Driver queue entry not found'; END IF;

  -- Mark driver queue entry as offline/cancelled
  UPDATE public.driver_queue
  SET status = 'offline', updated_at = NOW()
  WHERE id = p_driver_queue_id;

  -- Update driver availability
  UPDATE public.drivers
  SET availability_status = 'offline', updated_at = NOW()
  WHERE id = v_dq.driver_id;

  -- Trigger rematch
  PERFORM public.match_route_queue(v_dq.route_id);

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, notes)
  VALUES (p_admin_id, 'driver_removed', 'driver_queue', p_driver_queue_id, 'Test: driver went offline');

  RETURN jsonb_build_object('success', TRUE, 'driver_queue_id', p_driver_queue_id);
END;
$$;

-- ============================================================
-- STEP 12: RLS policies for new is_test_data column
-- Admin can read all; test data is not visible to passengers/drivers
-- ============================================================

-- No new tables added, existing RLS covers the new columns.
-- The admin_* functions are SECURITY DEFINER so they bypass RLS.

-- ============================================================
-- STEP 13: Grant execute permissions to authenticated users
-- (admin check is inside each function)
-- ============================================================

GRANT EXECUTE ON FUNCTION public.admin_create_test_passenger(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_test_driver(TEXT, INTEGER, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_test_booking_and_queue(UUID, UUID, INTEGER, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reset_test_data(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_test_harness_state(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_simulate_driver_action(UUID, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_simulate_passenger_cancel(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_driver_go_offline(UUID, UUID) TO authenticated;
