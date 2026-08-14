-- ============================================================
-- RAAHI STAGE 7 — E2E OPERATIONAL FLOW
-- Migration: 20260809200000_raahi_stage7_e2e_operational.sql
-- ============================================================
-- Changes:
-- 1. Add direction column to pickup_points
-- 2. Add min_passengers column to routes
-- 3. Create unified book_or_queue RPC (prevents duplicate active bookings)
-- 4. Create convert_user_to_driver RPC (admin only)
-- 5. Ensure match_route_queue respects min_passengers
-- 6. Add admin write RLS policies for routes, vehicles, drivers, pickup_points
-- 7. Add get_active_trip_for_route RPC (used by BookRideContent)
-- 8. Add get_driver_queue_status RPC (used by DriverHomeContent)
-- 9. Upsert operational business settings
-- ============================================================

-- ============================================================
-- STEP 1: Add direction to pickup_points
-- ============================================================

ALTER TABLE public.pickup_points
  ADD COLUMN IF NOT EXISTS direction TEXT NOT NULL DEFAULT 'both'
  CHECK (direction IN ('forward', 'return', 'both'));

-- ============================================================
-- STEP 2: Add min_passengers to routes
-- ============================================================

ALTER TABLE public.routes
  ADD COLUMN IF NOT EXISTS min_passengers INTEGER NOT NULL DEFAULT 1;

-- ============================================================
-- STEP 3: Ensure admin write RLS on routes
-- ============================================================

DROP POLICY IF EXISTS "admin_write_routes" ON public.routes;
CREATE POLICY "admin_write_routes"
  ON public.routes FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "authenticated_read_routes" ON public.routes;
CREATE POLICY "authenticated_read_routes"
  ON public.routes FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "anon_read_active_routes" ON public.routes;
CREATE POLICY "anon_read_active_routes"
  ON public.routes FOR SELECT
  TO anon
  USING (status = 'active');

-- ============================================================
-- STEP 4: Ensure admin write RLS on pickup_points
-- ============================================================

DROP POLICY IF EXISTS "admin_write_pickup_points" ON public.pickup_points;
CREATE POLICY "admin_write_pickup_points"
  ON public.pickup_points FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "authenticated_read_pickup_points" ON public.pickup_points;
CREATE POLICY "authenticated_read_pickup_points"
  ON public.pickup_points FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================
-- STEP 5: Ensure admin write RLS on vehicles
-- ============================================================

DROP POLICY IF EXISTS "admin_write_vehicles" ON public.vehicles;
CREATE POLICY "admin_write_vehicles"
  ON public.vehicles FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "driver_read_own_vehicle" ON public.vehicles;
CREATE POLICY "driver_read_own_vehicle"
  ON public.vehicles FOR SELECT
  TO authenticated
  USING (
    assigned_driver_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ============================================================
-- STEP 6: Ensure admin write RLS on drivers
-- ============================================================

DROP POLICY IF EXISTS "admin_write_drivers" ON public.drivers;
CREATE POLICY "admin_write_drivers"
  ON public.drivers FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "driver_read_own_record" ON public.drivers;
CREATE POLICY "driver_read_own_record"
  ON public.drivers FOR SELECT
  TO authenticated
  USING (
    profile_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "driver_update_own_availability" ON public.drivers;
CREATE POLICY "driver_update_own_availability"
  ON public.drivers FOR UPDATE
  TO authenticated
  USING (profile_id = auth.uid())
  WITH CHECK (profile_id = auth.uid());

-- ============================================================
-- STEP 7: Ensure admin write RLS on profiles
-- ============================================================

DROP POLICY IF EXISTS "admin_write_profiles" ON public.profiles;
CREATE POLICY "admin_write_profiles"
  ON public.profiles FOR ALL
  TO authenticated
  USING (
    id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles p2 WHERE p2.id = auth.uid() AND p2.role = 'admin')
  )
  WITH CHECK (
    id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles p2 WHERE p2.id = auth.uid() AND p2.role = 'admin')
  );

-- ============================================================
-- STEP 8: RPC — get_active_trip_for_route
-- Returns the current accepting_bookings trip for a route
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_active_trip_for_route(p_route_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trip RECORD;
  v_driver_name TEXT;
  v_vehicle RECORD;
BEGIN
  SELECT t.*, d.profile_id as driver_profile_id
  INTO v_trip
  FROM public.trips t
  LEFT JOIN public.drivers d ON d.id = t.driver_id
  WHERE t.route_id = p_route_id
    AND t.status IN ('accepting_bookings', 'full', 'ready', 'boarding')
  ORDER BY t.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  -- Get driver name
  SELECT p.name INTO v_driver_name
  FROM public.profiles p
  WHERE p.id = v_trip.driver_profile_id;

  -- Get vehicle info
  SELECT make, model, vehicle_type, registration_number
  INTO v_vehicle
  FROM public.vehicles
  WHERE id = v_trip.vehicle_id;

  RETURN jsonb_build_object(
    'found', true,
    'trip_id', v_trip.id,
    'route_id', v_trip.route_id,
    'total_seats', v_trip.total_seats,
    'booked_seats', v_trip.booked_seats,
    'available_seats', v_trip.total_seats - v_trip.booked_seats,
    'fare_per_seat', v_trip.fare_per_seat,
    'status', v_trip.status,
    'driver_name', COALESCE(v_driver_name, 'Assigned'),
    'vehicle_make', COALESCE(v_vehicle.make, ''),
    'vehicle_model', COALESCE(v_vehicle.model, ''),
    'vehicle_type', COALESCE(v_vehicle.vehicle_type, ''),
    'vehicle_registration', COALESCE(v_vehicle.registration_number, '')
  );
END;
$$;

-- ============================================================
-- STEP 9: RPC — book_or_queue
-- Unified booking: joins queue (with or without active trip)
-- Prevents duplicate active bookings for same passenger+route
-- ============================================================

CREATE OR REPLACE FUNCTION public.book_or_queue(
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
  v_route RECORD;
  v_pickup RECORD;
  v_max_seats INTEGER;
  v_fare NUMERIC(10,2);
  v_total_fare NUMERIC(10,2);
  v_booking_id UUID;
  v_queue_result JSONB;
  v_existing_booking_id UUID;
  v_existing_pq_id UUID;
BEGIN
  -- Validate route is active
  SELECT * INTO v_route FROM public.routes WHERE id = p_route_id AND status = 'active';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Route is not available');
  END IF;

  -- Validate pickup point belongs to route and is active
  SELECT * INTO v_pickup FROM public.pickup_points
  WHERE id = p_pickup_point_id AND route_id = p_route_id AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid pickup point for this route');
  END IF;

  -- Validate seat count
  SELECT COALESCE(value::INTEGER, 4) INTO v_max_seats
  FROM public.business_settings WHERE key = 'max_seats_per_booking';
  IF p_seats < 1 OR p_seats > v_max_seats THEN
    RETURN jsonb_build_object('success', false, 'error', format('Seats must be between 1 and %s', v_max_seats));
  END IF;

  -- PREVENT DUPLICATE: Check if passenger already has an active booking/queue entry for this route
  SELECT b.id INTO v_existing_booking_id
  FROM public.bookings b
  WHERE b.passenger_id = p_passenger_id
    AND b.status IN ('confirmed', 'queued', 'matching')
    AND EXISTS (
      SELECT 1 FROM public.passenger_queue pq
      WHERE pq.booking_id = b.id
        AND pq.route_id = p_route_id
        AND pq.status IN ('WAITING', 'MATCHING', 'ASSIGNED')
    )
  LIMIT 1;

  IF v_existing_booking_id IS NOT NULL THEN
    -- Return existing booking info instead of error
    SELECT pq.id INTO v_existing_pq_id
    FROM public.passenger_queue pq
    WHERE pq.booking_id = v_existing_booking_id
      AND pq.status IN ('WAITING', 'MATCHING', 'ASSIGNED')
    LIMIT 1;

    RETURN jsonb_build_object(
      'success', true,
      'booking_id', v_existing_booking_id,
      'queue_id', v_existing_pq_id,
      'already_queued', true,
      'message', 'You already have an active booking on this route'
    );
  END IF;

  -- Get fare from route
  v_fare := v_route.fare_per_seat;
  v_total_fare := v_fare * p_seats;

  -- Create booking (status = queued, no trip_id yet)
  INSERT INTO public.bookings (
    passenger_id, trip_id, pickup_point_id, seats,
    fare_per_seat, total_fare, status
  )
  VALUES (
    p_passenger_id, NULL, p_pickup_point_id, p_seats,
    v_fare, v_total_fare, 'queued'
  )
  RETURNING id INTO v_booking_id;

  -- Join passenger queue (this also triggers auto-matching)
  SELECT public.passenger_join_queue(
    p_passenger_id,
    p_route_id,
    v_booking_id,
    p_seats
  ) INTO v_queue_result;

  IF NOT (v_queue_result->>'success')::BOOLEAN THEN
    -- Rollback booking
    DELETE FROM public.bookings WHERE id = v_booking_id;
    RETURN jsonb_build_object('success', false, 'error', COALESCE(v_queue_result->>'error', 'Failed to join queue'));
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', v_booking_id,
    'queue_id', v_queue_result->>'queue_id',
    'queue_position', v_queue_result->'queue_position',
    'fare', v_total_fare,
    'fare_per_seat', v_fare,
    'already_queued', false,
    'message', 'You have joined the queue. A driver will be matched automatically.'
  );
END;
$$;

-- ============================================================
-- STEP 10: RPC — convert_user_to_driver (admin only)
-- Converts a passenger profile to driver role and creates driver record
-- ============================================================

CREATE OR REPLACE FUNCTION public.convert_user_to_driver(
  p_admin_id UUID,
  p_user_id UUID,
  p_license_number TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_profile RECORD;
  v_driver_id UUID;
  v_existing_driver_id UUID;
BEGIN
  -- Validate admin
  SELECT (role = 'admin') INTO v_is_admin FROM public.profiles WHERE id = p_admin_id;
  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  -- Get user profile
  SELECT * INTO v_profile FROM public.profiles WHERE id = p_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  -- Check if already a driver
  SELECT id INTO v_existing_driver_id FROM public.drivers WHERE profile_id = p_user_id;
  IF v_existing_driver_id IS NOT NULL THEN
    -- Already has driver record — just update role if needed
    UPDATE public.profiles SET role = 'driver', updated_at = NOW() WHERE id = p_user_id;
    RETURN jsonb_build_object(
      'success', true,
      'driver_id', v_existing_driver_id,
      'message', 'User already has a driver record. Role updated to driver.'
    );
  END IF;

  -- Update profile role to driver
  UPDATE public.profiles
  SET role = 'driver', updated_at = NOW()
  WHERE id = p_user_id;

  -- Create driver record (pending verification by default)
  INSERT INTO public.drivers (
    profile_id, license_number, verification_status, availability_status
  )
  VALUES (
    p_user_id,
    p_license_number,
    'pending',
    'offline'
  )
  RETURNING id INTO v_driver_id;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    p_admin_id,
    'driver_approved'::public.audit_action,
    'drivers',
    v_driver_id,
    jsonb_build_object('user_id', p_user_id, 'license_number', p_license_number),
    'User converted to driver by admin'
  );

  RETURN jsonb_build_object(
    'success', true,
    'driver_id', v_driver_id,
    'message', 'User converted to driver. Status is pending — approve to allow them to go online.'
  );
END;
$$;

-- ============================================================
-- STEP 11: RPC — get_driver_queue_status
-- Returns current queue/trip state for a driver
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_driver_queue_status(p_driver_profile_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver RECORD;
  v_queue RECORD;
  v_trip RECORD;
  v_passenger_count INTEGER;
  v_waiting_seats INTEGER;
  v_route RECORD;
  v_timeout_secs INTEGER;
  v_seats_needed INTEGER;
BEGIN
  -- Get driver
  SELECT d.*, p.name as driver_name
  INTO v_driver
  FROM public.drivers d
  JOIN public.profiles p ON p.id = d.profile_id
  WHERE d.profile_id = p_driver_profile_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  -- Get active queue entry
  SELECT * INTO v_queue
  FROM public.driver_queue
  WHERE driver_id = v_driver.id
    AND status IN ('waiting', 'offered', 'assigned', 'active')
  ORDER BY joined_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  -- Get route info
  SELECT from_location, to_location, fare_per_seat, min_passengers
  INTO v_route
  FROM public.routes
  WHERE id = v_queue.route_id;

  -- Get offer timeout setting
  SELECT COALESCE(value::INTEGER, 45) INTO v_timeout_secs
  FROM public.business_settings WHERE key = 'driver_offer_timeout_seconds';

  -- Get queue position
  SELECT COUNT(*) INTO v_passenger_count
  FROM public.driver_queue
  WHERE route_id = v_queue.route_id
    AND status IN ('waiting', 'offered', 'assigned')
    AND joined_at < v_queue.joined_at;

  -- Get waiting passenger seats for this route
  SELECT COALESCE(SUM(seat_count), 0) INTO v_waiting_seats
  FROM public.passenger_queue
  WHERE route_id = v_queue.route_id AND status = 'WAITING';

  -- Get trip info if offered/assigned
  IF v_queue.provisional_trip_id IS NOT NULL THEN
    SELECT * INTO v_trip FROM public.trips WHERE id = v_queue.provisional_trip_id;
  END IF;

  -- Calculate seats needed for dispatch
  v_seats_needed := GREATEST(0, COALESCE(v_route.min_passengers, 1) - v_waiting_seats);

  RETURN jsonb_build_object(
    'found', true,
    'queue_entry_id', v_queue.id,
    'status', v_queue.status,
    'queue_position', v_passenger_count + 1,
    'drivers_ahead', v_passenger_count,
    'route_from', COALESCE(v_route.from_location, ''),
    'route_to', COALESCE(v_route.to_location, ''),
    'fare_per_seat', COALESCE(v_route.fare_per_seat, 0),
    'offered_at', v_queue.offered_at,
    'offer_expires_at', v_queue.offer_expires_at,
    'provisional_trip_id', v_queue.provisional_trip_id,
    'offer_timeout_seconds', v_timeout_secs,
    'waiting_passenger_seats', v_waiting_seats,
    'seats_needed_to_dispatch', v_seats_needed,
    'ready_to_dispatch', (v_waiting_seats >= COALESCE(v_route.min_passengers, 1)),
    'passenger_count', CASE WHEN v_trip.id IS NOT NULL THEN v_trip.booked_seats ELSE 0 END,
    'trip_id', v_trip.id,
    'trip_status', v_trip.status,
    'booked_seats', CASE WHEN v_trip.id IS NOT NULL THEN v_trip.booked_seats ELSE 0 END,
    'total_seats', CASE WHEN v_trip.id IS NOT NULL THEN v_trip.total_seats ELSE 0 END
  );
END;
$$;

-- ============================================================
-- STEP 12: Update match_route_queue to respect min_passengers
-- ============================================================

CREATE OR REPLACE FUNCTION public.match_route_queue(p_route_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_lock_key BIGINT;
  v_driver_entry RECORD;
  v_vehicle RECORD;
  v_capacity INTEGER;
  v_entry RECORD;
  v_assigned_seats INTEGER := 0;
  v_trip_id UUID;
  v_keep_together TEXT;
  v_timeout_seconds INTEGER;
  v_offer_expires TIMESTAMPTZ;
  v_passenger_ids UUID[] := ARRAY[]::UUID[];
  v_booking_ids UUID[] := ARRAY[]::UUID[];
  v_auto_match TEXT;
  v_min_passengers INTEGER;
  v_total_waiting_seats INTEGER;
  v_route RECORD;
BEGIN
  -- Check if automatic matching is enabled
  v_auto_match := public.get_business_setting('automatic_matching_enabled');
  IF v_auto_match != 'true' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'automatic_matching_disabled');
  END IF;

  -- Advisory lock keyed on route_id to prevent concurrent matching
  v_lock_key := ('x' || substr(p_route_id::TEXT, 1, 8))::BIT(32)::BIGINT;
  IF NOT pg_try_advisory_xact_lock(v_lock_key) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'lock_contention');
  END IF;

  -- Get route info including min_passengers
  SELECT * INTO v_route FROM public.routes WHERE id = p_route_id AND status = 'active';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'route_inactive_or_not_found');
  END IF;

  v_min_passengers := COALESCE(v_route.min_passengers, 1);

  -- Count total waiting seats
  SELECT COALESCE(SUM(seat_count), 0) INTO v_total_waiting_seats
  FROM public.passenger_queue
  WHERE route_id = p_route_id AND status = 'WAITING';

  -- Check minimum passengers threshold
  IF v_total_waiting_seats < v_min_passengers THEN
    RETURN jsonb_build_object(
      'success', false,
      'reason', 'insufficient_passengers',
      'waiting_seats', v_total_waiting_seats,
      'min_required', v_min_passengers
    );
  END IF;

  -- Find first eligible driver in FIFO order (status = waiting, not offered)
  SELECT dq.*, d.id as driver_rec_id, d.current_vehicle_id
  INTO v_driver_entry
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  WHERE dq.route_id = p_route_id
    AND dq.status = 'waiting'
  ORDER BY dq.joined_at ASC
  LIMIT 1
  FOR UPDATE OF dq SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_driver_available');
  END IF;

  -- Get vehicle capacity
  SELECT v.seating_capacity, v.make, v.model, v.registration_number
  INTO v_vehicle
  FROM public.vehicles v
  WHERE v.id = v_driver_entry.vehicle_id
    AND v.status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_valid_vehicle');
  END IF;

  v_capacity := v_vehicle.seating_capacity;
  v_keep_together := public.get_business_setting('keep_multi_seat_booking_together');

  -- Collect earliest waiting passenger bookings up to capacity (FIFO)
  v_assigned_seats := 0;

  FOR v_entry IN
    SELECT pq.id, pq.booking_id, pq.passenger_id, pq.seat_count, pq.queue_sequence
    FROM public.passenger_queue pq
    WHERE pq.route_id = p_route_id
      AND pq.status = 'WAITING'
    ORDER BY pq.queue_sequence ASC
    FOR UPDATE SKIP LOCKED
  LOOP
    IF (v_assigned_seats + v_entry.seat_count) <= v_capacity THEN
      v_assigned_seats := v_assigned_seats + v_entry.seat_count;
      v_passenger_ids := array_append(v_passenger_ids, v_entry.id);
      v_booking_ids := array_append(v_booking_ids, v_entry.booking_id);
    ELSIF v_keep_together = 'true' THEN
      IF v_assigned_seats < v_capacity THEN
        CONTINUE;
      ELSE
        EXIT;
      END IF;
    ELSE
      EXIT;
    END IF;

    IF v_assigned_seats >= v_capacity THEN
      EXIT;
    END IF;
  END LOOP;

  IF array_length(v_passenger_ids, 1) IS NULL OR array_length(v_passenger_ids, 1) = 0 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_passengers_waiting');
  END IF;

  -- Get offer timeout
  v_timeout_seconds := COALESCE(
    public.get_business_setting('driver_offer_timeout_seconds')::INTEGER,
    45
  );
  v_offer_expires := NOW() + (v_timeout_seconds || ' seconds')::INTERVAL;

  -- Create provisional trip
  INSERT INTO public.trips (
    route_id, driver_id, vehicle_id, total_seats, booked_seats,
    status, fare_per_seat, queue_entry_id, notes
  )
  SELECT
    p_route_id,
    v_driver_entry.driver_id,
    v_driver_entry.vehicle_id,
    v_capacity,
    v_assigned_seats,
    'scheduled'::public.trip_status,
    r.fare_per_seat,
    v_driver_entry.id,
    'provisional_offer'
  FROM public.routes r
  WHERE r.id = p_route_id
  RETURNING id INTO v_trip_id;

  -- Mark driver queue entry as OFFERED
  UPDATE public.driver_queue
  SET
    status = 'offered',
    offered_at = NOW(),
    offer_expires_at = v_offer_expires,
    provisional_trip_id = v_trip_id,
    updated_at = NOW()
  WHERE id = v_driver_entry.id;

  -- Mark passenger queue entries as MATCHING and link to provisional trip
  UPDATE public.passenger_queue
  SET
    status = 'MATCHING',
    assigned_trip_id = v_trip_id,
    updated_at = NOW()
  WHERE id = ANY(v_passenger_ids);

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    v_driver_entry.driver_id,
    'driver_offered_ride'::public.audit_action,
    'driver_queue',
    v_driver_entry.id,
    jsonb_build_object(
      'trip_id', v_trip_id,
      'route_id', p_route_id,
      'passenger_count', array_length(v_passenger_ids, 1),
      'seat_count', v_assigned_seats,
      'offer_expires_at', v_offer_expires
    ),
    'Driver offered ride via FIFO matching'
  );

  RETURN jsonb_build_object(
    'success', true,
    'trip_id', v_trip_id,
    'driver_queue_id', v_driver_entry.id,
    'passenger_queue_ids', v_passenger_ids,
    'assigned_seats', v_assigned_seats,
    'offer_expires_at', v_offer_expires
  );
END;
$$;

-- ============================================================
-- STEP 13: Update driver_go_online to trigger auto-matching
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
  v_queue_entry_id UUID;
  v_queue_position INTEGER;
  v_match_result JSONB;
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
    AND status IN ('waiting', 'active', 'offered', 'assigned');

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', true,
      'queue_entry_id', v_existing_queue.id,
      'queue_position', public.get_driver_queue_position(v_existing_queue.id),
      'already_online', true
    );
  END IF;

  -- Calculate queue position
  SELECT COALESCE(MAX(queue_position), 0) + 1
  INTO v_queue_position
  FROM public.driver_queue
  WHERE route_id = p_route_id AND status IN ('waiting', 'active', 'offered', 'assigned');

  -- Insert into queue
  INSERT INTO public.driver_queue (route_id, driver_id, vehicle_id, queue_position, status, joined_at)
  VALUES (p_route_id, p_driver_id, p_vehicle_id, v_queue_position, 'waiting', NOW())
  RETURNING id INTO v_queue_entry_id;

  -- Update driver status
  UPDATE public.drivers
  SET availability_status = 'queued',
      current_route_id = p_route_id,
      current_vehicle_id = p_vehicle_id,
      updated_at = NOW()
  WHERE id = p_driver_id;

  -- Log action
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  SELECT p.id, 'driver_went_online'::public.audit_action, 'driver_queue', v_queue_entry_id,
    jsonb_build_object('route_id', p_route_id, 'vehicle_id', p_vehicle_id, 'position', v_queue_position),
    'Driver joined queue'
  FROM public.drivers d JOIN public.profiles p ON p.id = d.profile_id WHERE d.id = p_driver_id;

  -- Trigger automatic matching (driver going online may satisfy conditions)
  SELECT public.match_route_queue(p_route_id) INTO v_match_result;

  RETURN jsonb_build_object(
    'success', true,
    'queue_entry_id', v_queue_entry_id,
    'queue_position', v_queue_position,
    'match_attempted', true,
    'match_result', v_match_result
  );
END;
$$;

-- ============================================================
-- STEP 14: Upsert operational business settings
-- Remove test-only settings from display by marking them
-- ============================================================

INSERT INTO public.business_settings (key, value, description)
VALUES
  ('cancellation_fee_inr', '20', 'Fee charged when a passenger cancels a confirmed booking (INR)'),
  ('no_show_fee_inr', '50', 'Fee charged when a passenger does not show up (INR)'),
  ('grace_period_minutes', '5', 'Time allowed after booking before no-show is recorded'),
  ('max_seats_per_booking', '4', 'Maximum number of seats a single passenger can book'),
  ('default_fare_inr', '150', 'Default fare per seat used when no route-specific fare is set'),
  ('luggage_policy', 'One small bag per passenger. No oversized luggage.', 'Displayed to passengers on the booking page'),
  ('driver_offer_timeout_seconds', '45', 'Seconds before a driver offer expires'),
  ('automatic_matching_enabled', 'true', 'Whether automatic FIFO matching is enabled'),
  ('driver_decline_queue_behavior', 'MOVE_TO_END', 'What happens when driver declines: MOVE_TO_END or REMOVE'),
  ('driver_timeout_queue_behavior', 'MOVE_TO_END', 'What happens when driver offer times out: MOVE_TO_END or REMOVE'),
  ('keep_multi_seat_booking_together', 'true', 'Whether to keep multi-seat bookings together when matching'),
  ('fit_aware_fifo_enabled', 'true', 'When true, the matching engine uses fit-aware FIFO')
ON CONFLICT (key) DO UPDATE
  SET description = EXCLUDED.description,
      updated_at = NOW();

-- ============================================================
-- STEP 15: Indexes for performance
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_pickup_points_route_direction
  ON public.pickup_points(route_id, direction, is_active, sequence_order);

CREATE INDEX IF NOT EXISTS idx_routes_status
  ON public.routes(status);

CREATE INDEX IF NOT EXISTS idx_drivers_profile_id
  ON public.drivers(profile_id);

CREATE INDEX IF NOT EXISTS idx_drivers_verification
  ON public.drivers(verification_status);

CREATE INDEX IF NOT EXISTS idx_vehicles_assigned_driver
  ON public.vehicles(assigned_driver_id);

CREATE INDEX IF NOT EXISTS idx_bookings_passenger_status
  ON public.bookings(passenger_id, status);
