-- ============================================================
-- RAAHI STAGE 5.2B — FIFO VALIDATION + BUG FIX PASS
-- Migration: 20260809120000_raahi_stage52b_validation.sql
-- ============================================================
-- Purpose:
--   1. Fix book_seat: pickup_points uses is_active not status
--   2. Fix driver_accept_offer: accepts queue_entry_id directly
--      (test harness calls it with driver_queue_id, not profile_id)
--   3. Add admin_cancel_driver_after_accept RPC (Test F)
--   4. Add admin_force_match RPC (bypasses automatic_matching_enabled gate)
--   5. Add get_route_queue_counts RPC (public, for hero cards)
--   6. Fix match_route_queue: check automatic_matching_enabled setting exists
--   7. Ensure business_settings has required keys
-- ============================================================

-- ============================================================
-- STEP 1: Ensure required business_settings keys exist
-- ============================================================

INSERT INTO public.business_settings (key, value, description)
VALUES
  ('automatic_matching_enabled', 'true',
   'When true, match_route_queue is called automatically on queue changes'),
  ('driver_offer_timeout_seconds', '45',
   'Seconds before an unaccepted driver offer expires'),
  ('driver_decline_queue_behavior', 'end_of_queue',
   'Where to place a driver who declines: end_of_queue or removed'),
  ('driver_timeout_queue_behavior', 'end_of_queue',
   'Where to place a driver whose offer times out: end_of_queue or removed'),
  ('max_seats_per_booking', '4',
   'Maximum seats a single booking can reserve')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- STEP 2: Fix book_seat — pickup_points.is_active not .status
-- ============================================================

CREATE OR REPLACE FUNCTION public.book_seat(
  p_passenger_id UUID,
  p_route_id UUID,
  p_pickup_point_id UUID,
  p_seats INTEGER DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking_id UUID;
  v_queue_id UUID;
  v_queue_position INTEGER;
  v_fare NUMERIC;
  v_auto_match TEXT;
  v_max_seats INTEGER;
BEGIN
  -- Validate seats
  v_max_seats := COALESCE(
    (SELECT value::INTEGER FROM public.business_settings WHERE key = 'max_seats_per_booking'),
    4
  );
  IF p_seats < 1 OR p_seats > v_max_seats THEN
    RETURN jsonb_build_object('success', false, 'error', format('Seat count must be between 1 and %s', v_max_seats));
  END IF;

  -- Get route fare
  SELECT fare_per_seat INTO v_fare FROM public.routes WHERE id = p_route_id AND status = 'active';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Route not found or inactive');
  END IF;

  -- Validate pickup point belongs to route (use is_active, not status)
  IF p_pickup_point_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.pickup_points
    WHERE id = p_pickup_point_id AND route_id = p_route_id AND is_active = TRUE
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid pickup point for this route');
  END IF;

  -- Create booking with trip_id = NULL (queue-based model)
  INSERT INTO public.bookings (
    passenger_id,
    trip_id,
    pickup_point_id,
    seats,
    fare_per_seat,
    total_fare,
    status
  ) VALUES (
    p_passenger_id,
    NULL,
    p_pickup_point_id,
    p_seats,
    v_fare,
    v_fare * p_seats,
    'queued'::public.booking_status
  )
  RETURNING id INTO v_booking_id;

  -- Add to passenger queue
  INSERT INTO public.passenger_queue (
    route_id,
    booking_id,
    passenger_id,
    seat_count,
    joined_at,
    status
  ) VALUES (
    p_route_id,
    v_booking_id,
    p_passenger_id,
    p_seats,
    NOW(),
    'WAITING'
  )
  RETURNING id INTO v_queue_id;

  -- Audit: booking created
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    p_passenger_id,
    'booking_created'::public.audit_action,
    'bookings',
    v_booking_id,
    jsonb_build_object('route_id', p_route_id, 'seats', p_seats, 'fare', v_fare * p_seats, 'trip_id', NULL),
    'Passenger booked seat — entered FIFO queue (no trip assigned yet)'
  );

  -- Audit: queue join
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    p_passenger_id,
    'passenger_joined_queue'::public.audit_action,
    'passenger_queue',
    v_queue_id,
    jsonb_build_object('route_id', p_route_id, 'seat_count', p_seats),
    'Passenger joined FIFO passenger queue'
  );

  -- Trigger matching if enabled
  SELECT COALESCE(value, 'true') INTO v_auto_match
  FROM public.business_settings WHERE key = 'automatic_matching_enabled';
  IF COALESCE(v_auto_match, 'true') = 'true' THEN
    PERFORM public.match_route_queue(p_route_id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', v_booking_id,
    'queue_id', v_queue_id,
    'fare_per_seat', v_fare,
    'total_fare', v_fare * p_seats,
    'trip_id', NULL,
    'message', 'Booking confirmed. You are in the queue. A vehicle will be assigned when capacity is reached.'
  );
END;
$$;

-- ============================================================
-- STEP 3: Fix match_route_queue — use direct settings lookup
-- (avoids dependency on get_business_setting helper existence)
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
  v_passenger_queue_ids UUID[] := ARRAY[]::UUID[];
  v_booking_ids UUID[] := ARRAY[]::UUID[];
  v_total_waiting_seats INTEGER := 0;
  v_auto_match TEXT;
  v_fare NUMERIC;
BEGIN
  -- Check if automatic matching is enabled
  SELECT COALESCE(value, 'true') INTO v_auto_match
  FROM public.business_settings WHERE key = 'automatic_matching_enabled';
  IF COALESCE(v_auto_match, 'true') != 'true' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'automatic_matching_disabled');
  END IF;

  -- Advisory lock keyed on route_id to prevent concurrent matching
  v_lock_key := ('x' || substr(replace(p_route_id::TEXT, '-', ''), 1, 8))::BIT(32)::BIGINT;
  IF NOT pg_try_advisory_xact_lock(v_lock_key) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'lock_contention');
  END IF;

  -- IDEMPOTENCY CHECK
  IF EXISTS (
    SELECT 1 FROM public.driver_queue
    WHERE route_id = p_route_id AND status = 'offered'
    LIMIT 1
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'offer_already_pending');
  END IF;

  -- FIND FIRST ELIGIBLE DRIVER (strict FIFO)
  SELECT dq.*, d.id as driver_rec_id, d.profile_id as driver_profile_id
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

  -- GET VEHICLE CAPACITY
  SELECT v.seating_capacity, v.make, v.model, v.registration_number
  INTO v_vehicle
  FROM public.vehicles v
  WHERE v.id = v_driver_entry.vehicle_id
    AND v.status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_valid_vehicle');
  END IF;

  v_capacity := v_vehicle.seating_capacity;

  -- FULL-CAPACITY GATE
  SELECT COALESCE(SUM(pq.seat_count), 0)::INTEGER
  INTO v_total_waiting_seats
  FROM public.passenger_queue pq
  WHERE pq.route_id = p_route_id
    AND pq.status = 'WAITING';

  IF v_total_waiting_seats < v_capacity THEN
    RETURN jsonb_build_object(
      'success', false,
      'reason', 'insufficient_passengers',
      'waiting_seats', v_total_waiting_seats,
      'required_seats', v_capacity,
      'driver_queue_id', v_driver_entry.id,
      'message', format(
        'Waiting for %s more seat(s) to fill %s %s (%s-seat vehicle)',
        v_capacity - v_total_waiting_seats,
        v_vehicle.make,
        v_vehicle.model,
        v_capacity
      )
    );
  END IF;

  -- COLLECT PASSENGERS (FIT-AWARE FIFO)
  SELECT COALESCE(value, 'true') INTO v_keep_together
  FROM public.business_settings WHERE key = 'keep_multi_seat_booking_together';
  v_keep_together := COALESCE(v_keep_together, 'true');
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
      v_passenger_queue_ids := array_append(v_passenger_queue_ids, v_entry.id);
      v_booking_ids := array_append(v_booking_ids, v_entry.booking_id);
    ELSIF v_keep_together = 'true' THEN
      -- Booking doesn't fit whole — skip it (preserve FIFO priority)
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

  IF array_length(v_passenger_queue_ids, 1) IS NULL OR v_assigned_seats = 0 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'passenger_collection_failed');
  END IF;

  -- GET OFFER TIMEOUT
  SELECT COALESCE(value::INTEGER, 45) INTO v_timeout_seconds
  FROM public.business_settings WHERE key = 'driver_offer_timeout_seconds';
  v_timeout_seconds := COALESCE(v_timeout_seconds, 45);
  v_offer_expires := NOW() + (v_timeout_seconds || ' seconds')::INTERVAL;

  -- GET ROUTE FARE
  SELECT fare_per_seat INTO v_fare FROM public.routes WHERE id = p_route_id;

  -- CREATE PROVISIONAL TRIP
  INSERT INTO public.trips (
    route_id, driver_id, vehicle_id, total_seats, booked_seats,
    status, fare_per_seat, queue_entry_id, notes
  ) VALUES (
    p_route_id,
    v_driver_entry.driver_id,
    v_driver_entry.vehicle_id,
    v_capacity,
    v_assigned_seats,
    'scheduled'::public.trip_status,
    v_fare,
    v_driver_entry.id,
    'provisional_offer'
  )
  RETURNING id INTO v_trip_id;

  -- MARK DRIVER AS OFFERED
  UPDATE public.driver_queue
  SET
    status = 'offered',
    offered_at = NOW(),
    offer_expires_at = v_offer_expires,
    provisional_trip_id = v_trip_id,
    updated_at = NOW()
  WHERE id = v_driver_entry.id;

  -- MARK PASSENGER QUEUE ENTRIES AS MATCHING
  UPDATE public.passenger_queue
  SET
    status = 'MATCHING',
    assigned_trip_id = v_trip_id,
    updated_at = NOW()
  WHERE id = ANY(v_passenger_queue_ids);

  -- UPDATE BOOKING STATUS
  UPDATE public.bookings
  SET
    status = 'matching'::public.booking_status,
    updated_at = NOW()
  WHERE id = ANY(v_booking_ids)
    AND status IN ('confirmed', 'queued');

  -- AUDIT
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    v_driver_entry.driver_profile_id,
    'driver_offered_ride'::public.audit_action,
    'driver_queue',
    v_driver_entry.id,
    jsonb_build_object(
      'trip_id', v_trip_id,
      'route_id', p_route_id,
      'passenger_count', array_length(v_passenger_queue_ids, 1),
      'seat_count', v_assigned_seats,
      'vehicle_capacity', v_capacity,
      'offer_expires_at', v_offer_expires
    ),
    format('Driver offered ride — %s/%s seats filled (full capacity)', v_assigned_seats, v_capacity)
  );

  RETURN jsonb_build_object(
    'success', true,
    'trip_id', v_trip_id,
    'driver_queue_id', v_driver_entry.id,
    'passenger_queue_ids', v_passenger_queue_ids,
    'assigned_seats', v_assigned_seats,
    'vehicle_capacity', v_capacity,
    'offer_expires_at', v_offer_expires
  );
END;
$$;

-- ============================================================
-- STEP 4: Fix driver_accept_offer — accept by queue_entry_id
-- The test harness calls admin_simulate_driver_action which
-- calls driver_accept_offer(p_driver_queue_id). The Stage 5.1
-- signature is driver_accept_offer(profile_id, queue_entry_id).
-- Add an overload that accepts just the queue_entry_id.
-- ============================================================

CREATE OR REPLACE FUNCTION public.driver_accept_offer(
  p_queue_entry_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_queue_entry RECORD;
  v_trip RECORD;
  v_driver_profile_id UUID;
BEGIN
  -- Get queue entry with lock
  SELECT dq.*, d.profile_id as driver_profile_id
  INTO v_queue_entry
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  WHERE dq.id = p_queue_entry_id
    AND dq.status = 'offered'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Offer not found or already expired/accepted');
  END IF;

  v_driver_profile_id := v_queue_entry.driver_profile_id;

  -- Server-side expiry check — authoritative
  IF v_queue_entry.offer_expires_at < NOW() THEN
    PERFORM public.expire_driver_offer(p_queue_entry_id);
    RETURN jsonb_build_object('success', false, 'error', 'Offer has expired. Driver returned to queue.');
  END IF;

  -- Get provisional trip with lock
  SELECT * INTO v_trip
  FROM public.trips
  WHERE id = v_queue_entry.provisional_trip_id
    AND notes = 'provisional_offer'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Provisional trip not found — offer may have been cancelled');
  END IF;

  -- Confirm trip
  UPDATE public.trips
  SET status = 'accepting_bookings'::public.trip_status, notes = NULL, updated_at = NOW()
  WHERE id = v_trip.id;

  -- Confirm driver queue entry
  UPDATE public.driver_queue
  SET status = 'assigned', activated_at = NOW(), updated_at = NOW()
  WHERE id = p_queue_entry_id;

  -- Update driver availability
  UPDATE public.drivers
  SET
    availability_status = 'active'::public.driver_availability_status,
    current_route_id = v_queue_entry.route_id,
    current_vehicle_id = v_queue_entry.vehicle_id,
    updated_at = NOW()
  WHERE id = v_queue_entry.driver_id;

  -- Confirm passenger queue entries
  UPDATE public.passenger_queue
  SET status = 'ASSIGNED', updated_at = NOW()
  WHERE assigned_trip_id = v_trip.id AND status = 'MATCHING';

  -- Link bookings to real trip
  UPDATE public.bookings
  SET
    trip_id = v_trip.id,
    status = 'confirmed'::public.booking_status,
    updated_at = NOW()
  WHERE id IN (
    SELECT booking_id FROM public.passenger_queue
    WHERE assigned_trip_id = v_trip.id AND status = 'ASSIGNED'
  );

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    v_driver_profile_id,
    'driver_accepted_offer'::public.audit_action,
    'driver_queue',
    p_queue_entry_id,
    jsonb_build_object('trip_id', v_trip.id, 'route_id', v_queue_entry.route_id),
    'Driver accepted ride offer — trip confirmed'
  );

  RETURN jsonb_build_object(
    'success', true,
    'trip_id', v_trip.id,
    'status', 'driver_assigned',
    'booked_seats', v_trip.booked_seats,
    'total_seats', v_trip.total_seats
  );
END;
$$;

-- ============================================================
-- STEP 5: Fix expire_driver_offer — ensure it exists and works
-- ============================================================

CREATE OR REPLACE FUNCTION public.expire_driver_offer(
  p_queue_entry_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_dq RECORD;
  v_timeout_behavior TEXT;
BEGIN
  SELECT * INTO v_dq FROM public.driver_queue WHERE id = p_queue_entry_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Queue entry not found');
  END IF;

  IF v_dq.status != 'offered' THEN
    RETURN jsonb_build_object('success', false, 'error', format('Entry is not in offered state: %s', v_dq.status));
  END IF;

  -- Release provisional trip and return passengers to WAITING
  IF v_dq.provisional_trip_id IS NOT NULL THEN
    PERFORM public.release_provisional_trip(v_dq.provisional_trip_id, 'offer_expired');
  END IF;

  -- Apply timeout behavior
  SELECT COALESCE(value, 'end_of_queue') INTO v_timeout_behavior
  FROM public.business_settings WHERE key = 'driver_timeout_queue_behavior';

  IF COALESCE(v_timeout_behavior, 'end_of_queue') = 'end_of_queue' THEN
    -- Move to end of queue by updating joined_at
    UPDATE public.driver_queue
    SET
      status = 'waiting',
      joined_at = NOW(),
      offered_at = NULL,
      offer_expires_at = NULL,
      provisional_trip_id = NULL,
      updated_at = NOW()
    WHERE id = p_queue_entry_id;
  ELSE
    -- Remove from queue
    UPDATE public.driver_queue
    SET status = 'offline', updated_at = NOW()
    WHERE id = p_queue_entry_id;

    UPDATE public.drivers
    SET availability_status = 'offline', updated_at = NOW()
    WHERE id = v_dq.driver_id;
  END IF;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    NULL,
    'offer_expired'::public.audit_action,
    'driver_queue',
    p_queue_entry_id,
    jsonb_build_object('route_id', v_dq.route_id, 'provisional_trip_id', v_dq.provisional_trip_id),
    'Driver offer expired — passengers returned to WAITING, FIFO priority preserved'
  );

  -- Trigger rematch
  PERFORM public.match_route_queue(v_dq.route_id);

  RETURN jsonb_build_object('success', true, 'expired_queue_id', p_queue_entry_id);
END;
$$;

-- ============================================================
-- STEP 6: Fix driver_decline_offer — ensure it exists
-- ============================================================

CREATE OR REPLACE FUNCTION public.driver_decline_offer(
  p_queue_entry_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_dq RECORD;
  v_decline_behavior TEXT;
BEGIN
  SELECT * INTO v_dq FROM public.driver_queue WHERE id = p_queue_entry_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Queue entry not found');
  END IF;

  IF v_dq.status != 'offered' THEN
    RETURN jsonb_build_object('success', false, 'error', format('Entry is not in offered state: %s', v_dq.status));
  END IF;

  -- Release provisional trip
  IF v_dq.provisional_trip_id IS NOT NULL THEN
    PERFORM public.release_provisional_trip(v_dq.provisional_trip_id, 'driver_declined');
  END IF;

  -- Apply decline behavior
  SELECT COALESCE(value, 'end_of_queue') INTO v_decline_behavior
  FROM public.business_settings WHERE key = 'driver_decline_queue_behavior';

  IF COALESCE(v_decline_behavior, 'end_of_queue') = 'end_of_queue' THEN
    UPDATE public.driver_queue
    SET
      status = 'waiting',
      joined_at = NOW(),
      offered_at = NULL,
      offer_expires_at = NULL,
      provisional_trip_id = NULL,
      updated_at = NOW()
    WHERE id = p_queue_entry_id;
  ELSE
    UPDATE public.driver_queue
    SET status = 'declined', updated_at = NOW()
    WHERE id = p_queue_entry_id;

    UPDATE public.drivers
    SET availability_status = 'offline', updated_at = NOW()
    WHERE id = v_dq.driver_id;
  END IF;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    NULL,
    'driver_declined_offer'::public.audit_action,
    'driver_queue',
    p_queue_entry_id,
    jsonb_build_object('route_id', v_dq.route_id),
    'Driver declined offer — passengers returned to WAITING, FIFO priority preserved'
  );

  -- Trigger rematch
  PERFORM public.match_route_queue(v_dq.route_id);

  RETURN jsonb_build_object('success', true, 'declined_queue_id', p_queue_entry_id);
END;
$$;

-- ============================================================
-- STEP 7: admin_cancel_driver_after_accept (Test F)
-- Driver cancels AFTER accepting but BEFORE trip starts
-- Releases passengers for rematching, preserving FIFO
-- ============================================================

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
  v_is_admin BOOLEAN;
  v_dq RECORD;
  v_trip RECORD;
  v_pq_ids UUID[];
  v_booking_ids UUID[];
BEGIN
  SELECT (role = 'admin') INTO v_is_admin FROM public.profiles WHERE id = p_admin_id;
  IF NOT v_is_admin THEN RAISE EXCEPTION 'Unauthorized: admin only'; END IF;

  SELECT * INTO v_dq FROM public.driver_queue WHERE id = p_driver_queue_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Driver queue entry not found'; END IF;

  IF v_dq.status NOT IN ('assigned', 'active') THEN
    RAISE EXCEPTION 'Driver is not in assigned/active state (current: %)', v_dq.status;
  END IF;

  -- Find the confirmed trip for this driver queue entry
  SELECT * INTO v_trip
  FROM public.trips
  WHERE (queue_entry_id = p_driver_queue_id OR id = v_dq.provisional_trip_id)
    AND status NOT IN ('cancelled', 'completed', 'in_progress')
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No active trip found for this driver queue entry';
  END IF;

  -- Collect affected passenger queue IDs and booking IDs
  SELECT
    ARRAY_AGG(pq.id),
    ARRAY_AGG(pq.booking_id)
  INTO v_pq_ids, v_booking_ids
  FROM public.passenger_queue pq
  WHERE pq.assigned_trip_id = v_trip.id
    AND pq.status IN ('MATCHING', 'ASSIGNED');

  -- Cancel the trip
  UPDATE public.trips
  SET status = 'cancelled', notes = 'driver_cancelled_after_accept', updated_at = NOW()
  WHERE id = v_trip.id;

  -- Return passengers to WAITING (preserve original queue_sequence — FIFO intact)
  UPDATE public.passenger_queue
  SET
    status = 'WAITING',
    assigned_trip_id = NULL,
    updated_at = NOW()
  WHERE assigned_trip_id = v_trip.id
    AND status IN ('MATCHING', 'ASSIGNED');

  -- Reset bookings
  IF v_booking_ids IS NOT NULL THEN
    UPDATE public.bookings
    SET
      trip_id = NULL,
      status = 'queued'::public.booking_status,
      updated_at = NOW()
    WHERE id = ANY(v_booking_ids);
  END IF;

  -- Remove driver from queue (cancelled after accept = offline)
  UPDATE public.driver_queue
  SET
    status = 'offline',
    updated_at = NOW()
  WHERE id = p_driver_queue_id;

  UPDATE public.drivers
  SET availability_status = 'offline', updated_at = NOW()
  WHERE id = v_dq.driver_id;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    p_admin_id,
    'driver_cancelled_trip'::public.audit_action,
    'driver_queue',
    p_driver_queue_id,
    jsonb_build_object(
      'trip_id', v_trip.id,
      'route_id', v_dq.route_id,
      'passengers_released', COALESCE(array_length(v_pq_ids, 1), 0)
    ),
    'Driver cancelled after accept — passengers returned to WAITING with original FIFO priority'
  );

  -- Trigger rematch
  PERFORM public.match_route_queue(v_dq.route_id);

  RETURN jsonb_build_object(
    'success', TRUE,
    'trip_cancelled', v_trip.id,
    'passengers_released', COALESCE(array_length(v_pq_ids, 1), 0),
    'rematch_triggered', TRUE
  );
END;
$$;

-- ============================================================
-- STEP 8: admin_force_match
-- Force match_route_queue regardless of automatic_matching_enabled
-- Used by test harness to trigger matching on demand
-- ============================================================

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
  v_is_admin BOOLEAN;
  v_prev_setting TEXT;
  v_result JSONB;
BEGIN
  SELECT (role = 'admin') INTO v_is_admin FROM public.profiles WHERE id = p_admin_id;
  IF NOT v_is_admin THEN RAISE EXCEPTION 'Unauthorized: admin only'; END IF;

  -- Temporarily enable matching if disabled
  SELECT value INTO v_prev_setting FROM public.business_settings WHERE key = 'automatic_matching_enabled';
  UPDATE public.business_settings SET value = 'true' WHERE key = 'automatic_matching_enabled';

  -- Run matching
  v_result := public.match_route_queue(p_route_id);

  -- Restore previous setting
  UPDATE public.business_settings SET value = COALESCE(v_prev_setting, 'true') WHERE key = 'automatic_matching_enabled';

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (p_admin_id, 'test_scenario_run', 'routes', p_route_id,
    jsonb_build_object('match_result', v_result), 'Admin forced match_route_queue');

  RETURN v_result;
END;
$$;

-- ============================================================
-- STEP 9: get_route_queue_counts (public read — for hero cards)
-- Returns waiting seat counts per route without auth requirement
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_route_queue_counts()
RETURNS TABLE(route_id UUID, from_location TEXT, to_location TEXT, waiting_seats BIGINT)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    r.id AS route_id,
    r.from_location,
    r.to_location,
    COALESCE(SUM(pq.seat_count), 0) AS waiting_seats
  FROM public.routes r
  LEFT JOIN public.passenger_queue pq
    ON pq.route_id = r.id AND pq.status = 'WAITING'
  WHERE r.status = 'active'
  GROUP BY r.id, r.from_location, r.to_location
  ORDER BY r.from_location;
$$;

-- ============================================================
-- STEP 10: Grant execute permissions
-- ============================================================

GRANT EXECUTE ON FUNCTION public.book_seat(UUID, UUID, UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.match_route_queue(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.driver_accept_offer(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expire_driver_offer(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.driver_decline_offer(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_cancel_driver_after_accept(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_force_match(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_route_queue_counts() TO authenticated, anon;

GRANT EXECUTE ON FUNCTION public.expire_all_stale_offers() TO service_role;
GRANT EXECUTE ON FUNCTION public.expire_driver_offer(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.match_route_queue(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.release_provisional_trip(UUID, TEXT) TO service_role;

-- ============================================================
-- STEP 11: Update admin_simulate_driver_action to use new
-- single-arg driver_accept_offer overload
-- ============================================================

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
    -- Use single-arg overload
    v_result := public.driver_accept_offer(p_driver_queue_id);
    RETURN jsonb_build_object('action', 'accept', 'result', v_result);

  ELSIF p_action = 'decline' THEN
    IF v_dq.status != 'offered' THEN
      RAISE EXCEPTION 'Driver is not in OFFERED state';
    END IF;
    v_result := public.driver_decline_offer(p_driver_queue_id);
    RETURN jsonb_build_object('action', 'decline', 'result', v_result);

  ELSIF p_action = 'expire' THEN
    UPDATE public.driver_queue
    SET offer_expires_at = NOW() - INTERVAL '1 second'
    WHERE id = p_driver_queue_id;

    v_result := public.expire_driver_offer(p_driver_queue_id);
    RETURN jsonb_build_object('action', 'expire', 'result', v_result);

  ELSE
    RAISE EXCEPTION 'Unknown action: %. Use accept, decline, or expire', p_action;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_simulate_driver_action(UUID, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_cancel_driver_after_accept(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_force_match(UUID, UUID) TO authenticated;
