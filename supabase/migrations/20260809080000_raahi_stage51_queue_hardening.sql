-- ============================================================
-- RAAHI STAGE 5.1 — QUEUE ENGINE HARDENING
-- Migration: 20260809080000_raahi_stage51_queue_hardening.sql
-- ============================================================
-- Changes:
-- 1. Make bookings.trip_id nullable (remove FK NOT NULL constraint)
-- 2. Clean up queue_placeholder trips safely
-- 3. Replace match_route_queue with full-capacity-only dispatch
-- 4. Replace book_seat to never create placeholder trips
-- 5. Add expire_all_stale_offers batch function for cron
-- 6. Add get_route_queues_for_admin matching_status field
-- 7. Extend booking_status enum with QUEUED/MATCHING lifecycle
-- 8. Add pg_cron job for server-side offer expiry
-- ============================================================

-- ============================================================
-- STEP 1: EXTEND booking_status enum safely
-- ============================================================

ALTER TYPE public.booking_status ADD VALUE IF NOT EXISTS 'queued';
ALTER TYPE public.booking_status ADD VALUE IF NOT EXISTS 'matching';

COMMIT;

-- ============================================================
-- STEP 2: EXTEND audit_action enum safely
-- ============================================================

ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'offer_batch_expired';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'placeholder_trip_cleaned';

COMMIT;

-- ============================================================
-- STEP 3: Make bookings.trip_id nullable
-- The FK constraint must be dropped and re-added as nullable
-- ============================================================

-- Drop the existing NOT NULL constraint if present
-- (trip_id may already be nullable depending on Stage 3 migration)
ALTER TABLE public.bookings
  ALTER COLUMN trip_id DROP NOT NULL;

-- ============================================================
-- STEP 4: SAFE CLEANUP of queue_placeholder trips
-- Strategy:
--   a) For passenger_queue entries pointing to a placeholder trip,
--      set assigned_trip_id = NULL and status = WAITING
--   b) For bookings pointing to a placeholder trip, set trip_id = NULL
--   c) Cancel the placeholder trips
-- This is safe because placeholder trips have notes = 'queue_placeholder'
-- and are in 'scheduled' status with no real passengers assigned.
-- ============================================================

DO $$
DECLARE
  v_placeholder_ids UUID[];
BEGIN
  -- Collect all placeholder trip IDs
  SELECT ARRAY_AGG(id) INTO v_placeholder_ids
  FROM public.trips
  WHERE notes = 'queue_placeholder';

  IF v_placeholder_ids IS NULL OR array_length(v_placeholder_ids, 1) = 0 THEN
    RAISE NOTICE 'No queue_placeholder trips found — nothing to clean up.';
    RETURN;
  END IF;

  RAISE NOTICE 'Found % queue_placeholder trips to clean up.', array_length(v_placeholder_ids, 1);

  -- Return any passenger_queue entries in MATCHING state back to WAITING
  UPDATE public.passenger_queue
  SET
    status = 'WAITING',
    assigned_trip_id = NULL,
    updated_at = NOW()
  WHERE assigned_trip_id = ANY(v_placeholder_ids)
    AND status IN ('MATCHING', 'ASSIGNED');

  -- Detach bookings from placeholder trips
  UPDATE public.bookings
  SET
    trip_id = NULL,
    updated_at = NOW()
  WHERE trip_id = ANY(v_placeholder_ids);

  -- Cancel placeholder trips (do NOT delete — preserve audit trail)
  UPDATE public.trips
  SET
    status = 'cancelled',
    notes = 'queue_placeholder_cleaned_stage51',
    updated_at = NOW()
  WHERE id = ANY(v_placeholder_ids)
    AND notes = 'queue_placeholder';

  -- Write audit log for cleanup
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  SELECT
    NULL,
    'placeholder_trip_cleaned'::public.audit_action,
    'trips',
    id,
    jsonb_build_object('cleaned_at', NOW(), 'stage', '5.1'),
    'Stage 5.1 migration: queue_placeholder trip cleaned up'
  FROM public.trips
  WHERE notes = 'queue_placeholder_cleaned_stage51';

  RAISE NOTICE 'Cleanup complete.';
END;
$$;

-- ============================================================
-- STEP 5: REPLACE match_route_queue
-- KEY CHANGE: Only create offer when waiting passenger seats
-- exactly fill the first eligible driver's vehicle capacity.
-- Strict FIFO: do NOT skip D1 because D2 has smaller capacity.
-- Idempotent: if D1 already has an active OFFERED entry, skip.
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
  v_auto_match := public.get_business_setting('automatic_matching_enabled');
  IF v_auto_match != 'true' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'automatic_matching_disabled');
  END IF;

  -- Advisory lock keyed on route_id to prevent concurrent matching
  v_lock_key := ('x' || substr(replace(p_route_id::TEXT, '-', ''), 1, 8))::BIT(32)::BIGINT;
  IF NOT pg_try_advisory_xact_lock(v_lock_key) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'lock_contention');
  END IF;

  -- --------------------------------------------------------
  -- IDEMPOTENCY CHECK:
  -- If the first eligible driver already has an OFFERED entry
  -- for this route, do not create a duplicate offer.
  -- --------------------------------------------------------
  IF EXISTS (
    SELECT 1 FROM public.driver_queue
    WHERE route_id = p_route_id
      AND status = 'offered'
    LIMIT 1
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'offer_already_pending');
  END IF;

  -- --------------------------------------------------------
  -- FIND FIRST ELIGIBLE DRIVER (strict FIFO)
  -- Only status = 'waiting' — do NOT skip to a smaller vehicle
  -- --------------------------------------------------------
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

  -- --------------------------------------------------------
  -- GET VEHICLE CAPACITY
  -- --------------------------------------------------------
  SELECT v.seating_capacity, v.make, v.model, v.registration_number
  INTO v_vehicle
  FROM public.vehicles v
  WHERE v.id = v_driver_entry.vehicle_id
    AND v.status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_valid_vehicle');
  END IF;

  v_capacity := v_vehicle.seating_capacity;

  -- --------------------------------------------------------
  -- COUNT TOTAL WAITING SEATS FOR THIS ROUTE
  -- FULL-CAPACITY RULE: Only proceed if waiting seats >= capacity
  -- --------------------------------------------------------
  SELECT COALESCE(SUM(pq.seat_count), 0)::INTEGER
  INTO v_total_waiting_seats
  FROM public.passenger_queue pq
  WHERE pq.route_id = p_route_id
    AND pq.status = 'WAITING';

  IF v_total_waiting_seats < v_capacity THEN
    -- Not enough passengers yet — do NOT create offer
    -- Driver #1 keeps their position; passengers keep waiting
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

  -- --------------------------------------------------------
  -- COLLECT PASSENGERS (FIFO, respect keep_multi_seat_together)
  -- Fill exactly up to v_capacity seats
  -- --------------------------------------------------------
  v_keep_together := COALESCE(
    public.get_business_setting('keep_multi_seat_booking_together'),
    'true'
  );
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
      -- Continue looking for smaller bookings that fit remaining space
      IF v_assigned_seats < v_capacity THEN
        CONTINUE;
      ELSE
        EXIT;
      END IF;
    ELSE
      -- Split not allowed in V1 — stop here
      EXIT;
    END IF;

    IF v_assigned_seats >= v_capacity THEN
      EXIT;
    END IF;
  END LOOP;

  -- Safety check: should not happen given the seat count check above
  IF array_length(v_passenger_queue_ids, 1) IS NULL OR v_assigned_seats = 0 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'passenger_collection_failed');
  END IF;

  -- --------------------------------------------------------
  -- GET OFFER TIMEOUT
  -- --------------------------------------------------------
  v_timeout_seconds := COALESCE(
    public.get_business_setting('driver_offer_timeout_seconds')::INTEGER,
    45
  );
  v_offer_expires := NOW() + (v_timeout_seconds || ' seconds')::INTERVAL;

  -- --------------------------------------------------------
  -- GET ROUTE FARE
  -- --------------------------------------------------------
  SELECT fare_per_seat INTO v_fare FROM public.routes WHERE id = p_route_id;

  -- --------------------------------------------------------
  -- CREATE PROVISIONAL TRIP (real trip, not placeholder)
  -- notes = 'provisional_offer' — will be cleared on accept
  -- --------------------------------------------------------
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

  -- --------------------------------------------------------
  -- MARK DRIVER AS OFFERED
  -- --------------------------------------------------------
  UPDATE public.driver_queue
  SET
    status = 'offered',
    offered_at = NOW(),
    offer_expires_at = v_offer_expires,
    provisional_trip_id = v_trip_id,
    updated_at = NOW()
  WHERE id = v_driver_entry.id;

  -- --------------------------------------------------------
  -- MARK PASSENGER QUEUE ENTRIES AS MATCHING
  -- --------------------------------------------------------
  UPDATE public.passenger_queue
  SET
    status = 'MATCHING',
    assigned_trip_id = v_trip_id,
    updated_at = NOW()
  WHERE id = ANY(v_passenger_queue_ids);

  -- --------------------------------------------------------
  -- UPDATE BOOKING STATUS TO 'matching'
  -- --------------------------------------------------------
  UPDATE public.bookings
  SET
    status = 'matching'::public.booking_status,
    updated_at = NOW()
  WHERE id = ANY(v_booking_ids)
    AND status IN ('confirmed', 'queued');

  -- --------------------------------------------------------
  -- AUDIT
  -- --------------------------------------------------------
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
-- STEP 6: REPLACE book_seat — NO placeholder trips
-- Booking and passenger_queue can exist with trip_id = NULL
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
    public.get_business_setting('max_seats_per_booking')::INTEGER,
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

  -- Validate pickup point belongs to route
  IF p_pickup_point_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.pickup_points
    WHERE id = p_pickup_point_id AND route_id = p_route_id AND status = 'active'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid pickup point for this route');
  END IF;

  -- Create booking with trip_id = NULL (queue-based model)
  -- trip_id will be assigned when matched to a driver
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
    NULL,                              -- No trip yet — assigned at matching
    p_pickup_point_id,
    p_seats,
    v_fare,
    v_fare * p_seats,
    'queued'::public.booking_status    -- New lifecycle status
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
    jsonb_build_object(
      'route_id', p_route_id,
      'seats', p_seats,
      'fare', v_fare * p_seats,
      'trip_id', NULL
    ),
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

  v_queue_position := public.get_passenger_queue_position(v_queue_id);

  -- Trigger matching if enabled
  v_auto_match := public.get_business_setting('automatic_matching_enabled');
  IF v_auto_match = 'true' THEN
    PERFORM public.match_route_queue(p_route_id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', v_booking_id,
    'queue_id', v_queue_id,
    'queue_position', v_queue_position,
    'fare_per_seat', v_fare,
    'total_fare', v_fare * p_seats,
    'trip_id', NULL,
    'message', 'Booking confirmed. You are in the queue. A vehicle will be assigned when capacity is reached.'
  );
END;
$$;

-- ============================================================
-- STEP 7: UPDATE driver_accept_offer
-- When driver accepts, link bookings to the real trip
-- ============================================================

CREATE OR REPLACE FUNCTION public.driver_accept_offer(
  p_driver_profile_id UUID,
  p_queue_entry_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver RECORD;
  v_queue_entry RECORD;
  v_trip RECORD;
BEGIN
  -- Get driver record
  SELECT * INTO v_driver FROM public.drivers WHERE profile_id = p_driver_profile_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver not found');
  END IF;

  -- Get queue entry with lock
  SELECT * INTO v_queue_entry
  FROM public.driver_queue
  WHERE id = p_queue_entry_id
    AND driver_id = v_driver.id
    AND status = 'offered'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Offer not found or already expired/accepted');
  END IF;

  -- Server-side expiry check — authoritative
  IF v_queue_entry.offer_expires_at < NOW() THEN
    PERFORM public.expire_driver_offer(p_queue_entry_id);
    RETURN jsonb_build_object('success', false, 'error', 'Offer has expired. You have been returned to the queue.');
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

  -- Confirm trip — clear provisional flag
  UPDATE public.trips
  SET
    status = 'accepting_bookings'::public.trip_status,
    notes = NULL,
    updated_at = NOW()
  WHERE id = v_trip.id;

  -- Confirm driver queue entry as assigned
  UPDATE public.driver_queue
  SET
    status = 'assigned',
    activated_at = NOW(),
    updated_at = NOW()
  WHERE id = p_queue_entry_id;

  -- Update driver availability
  UPDATE public.drivers
  SET
    availability_status = 'active'::public.driver_availability_status,
    current_route_id = v_queue_entry.route_id,
    current_vehicle_id = v_queue_entry.vehicle_id,
    updated_at = NOW()
  WHERE id = v_driver.id;

  -- Confirm passenger queue entries as ASSIGNED
  UPDATE public.passenger_queue
  SET
    status = 'ASSIGNED',
    updated_at = NOW()
  WHERE assigned_trip_id = v_trip.id
    AND status = 'MATCHING';

  -- Link bookings to the real trip and update status
  UPDATE public.bookings
  SET
    trip_id = v_trip.id,
    status = 'confirmed'::public.booking_status,
    updated_at = NOW()
  WHERE id IN (
    SELECT booking_id FROM public.passenger_queue
    WHERE assigned_trip_id = v_trip.id
      AND status = 'ASSIGNED'
  );

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    p_driver_profile_id,
    'driver_accepted_offer'::public.audit_action,
    'driver_queue',
    p_queue_entry_id,
    jsonb_build_object(
      'trip_id', v_trip.id,
      'route_id', v_queue_entry.route_id,
      'booked_seats', v_trip.booked_seats,
      'total_seats', v_trip.total_seats
    ),
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
-- STEP 8: UPDATE release_provisional_trip
-- Also reset booking status back to 'queued'
-- ============================================================

CREATE OR REPLACE FUNCTION public.release_provisional_trip(
  p_trip_id UUID,
  p_reason TEXT DEFAULT 'released'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking_ids UUID[];
BEGIN
  IF p_trip_id IS NULL THEN RETURN; END IF;

  -- Collect affected booking IDs before clearing
  SELECT ARRAY_AGG(booking_id) INTO v_booking_ids
  FROM public.passenger_queue
  WHERE assigned_trip_id = p_trip_id
    AND status = 'MATCHING';

  -- Cancel the provisional trip
  UPDATE public.trips
  SET
    status = 'cancelled'::public.trip_status,
    notes = p_reason,
    updated_at = NOW()
  WHERE id = p_trip_id
    AND notes = 'provisional_offer';

  -- Return passengers to WAITING, preserving original queue_sequence (FIFO priority)
  UPDATE public.passenger_queue
  SET
    status = 'WAITING',
    assigned_trip_id = NULL,
    updated_at = NOW()
  WHERE assigned_trip_id = p_trip_id
    AND status = 'MATCHING';

  -- Reset booking status back to 'queued' (not 'matching')
  IF v_booking_ids IS NOT NULL AND array_length(v_booking_ids, 1) > 0 THEN
    UPDATE public.bookings
    SET
      status = 'queued'::public.booking_status,
      trip_id = NULL,
      updated_at = NOW()
    WHERE id = ANY(v_booking_ids)
      AND status = 'matching';
  END IF;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    NULL,
    'passenger_returned_to_queue'::public.audit_action,
    'trips',
    p_trip_id,
    jsonb_build_object('reason', p_reason, 'booking_count', COALESCE(array_length(v_booking_ids, 1), 0)),
    'Passengers returned to FIFO queue — provisional trip released, FIFO priority preserved'
  );
END;
$$;

-- ============================================================
-- STEP 9: expire_all_stale_offers
-- Batch function called by pg_cron or Edge Function cron
-- Finds all OFFERED driver_queue entries past offer_expires_at
-- and expires them one by one (each triggers rematch)
-- ============================================================

CREATE OR REPLACE FUNCTION public.expire_all_stale_offers()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_entry RECORD;
  v_expired_count INTEGER := 0;
  v_result JSONB;
BEGIN
  FOR v_entry IN
    SELECT id, route_id, driver_id, offer_expires_at
    FROM public.driver_queue
    WHERE status = 'offered'
      AND offer_expires_at < NOW()
    ORDER BY offer_expires_at ASC
    FOR UPDATE SKIP LOCKED
  LOOP
    -- Expire this offer (releases passengers, triggers rematch)
    v_result := public.expire_driver_offer(v_entry.id);
    v_expired_count := v_expired_count + 1;
  END LOOP;

  IF v_expired_count > 0 THEN
    INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
    VALUES (
      NULL,
      'offer_batch_expired'::public.audit_action,
      'driver_queue',
      NULL,
      jsonb_build_object('expired_count', v_expired_count, 'ran_at', NOW()),
      format('Batch expiry: %s stale offer(s) expired by cron', v_expired_count)
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'expired_count', v_expired_count,
    'ran_at', NOW()
  );
END;
$$;

-- ============================================================
-- STEP 10: UPDATE get_route_queues_for_admin
-- Add matching_status field explaining why route is waiting
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_route_queues_for_admin(p_route_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_passenger_queue JSONB;
  v_driver_queue JSONB;
  v_current_match JSONB;
  v_matching_status JSONB;
  v_first_driver RECORD;
  v_first_vehicle RECORD;
  v_waiting_seats INTEGER;
  v_offered_entry RECORD;
  v_offer_seconds_remaining INTEGER;
BEGIN
  -- Passenger queue
  SELECT jsonb_agg(
    jsonb_build_object(
      'queue_id', pq.id,
      'queue_position', RANK() OVER (ORDER BY pq.queue_sequence ASC),
      'passenger_name', p.name,
      'seat_count', pq.seat_count,
      'status', pq.status,
      'joined_at', pq.joined_at,
      'assigned_trip_id', pq.assigned_trip_id
    ) ORDER BY pq.queue_sequence ASC
  )
  INTO v_passenger_queue
  FROM public.passenger_queue pq
  JOIN public.profiles p ON p.id = pq.passenger_id
  WHERE pq.route_id = p_route_id
    AND pq.status IN ('WAITING', 'MATCHING', 'ASSIGNED');

  -- Driver queue
  SELECT jsonb_agg(
    jsonb_build_object(
      'queue_id', dq.id,
      'queue_position', RANK() OVER (ORDER BY dq.joined_at ASC),
      'driver_name', pr.name,
      'vehicle_make', v.make,
      'vehicle_model', v.model,
      'vehicle_registration', v.registration_number,
      'vehicle_capacity', v.seating_capacity,
      'status', dq.status,
      'joined_at', dq.joined_at,
      'offered_at', dq.offered_at,
      'offer_expires_at', dq.offer_expires_at,
      'provisional_trip_id', dq.provisional_trip_id
    ) ORDER BY dq.joined_at ASC
  )
  INTO v_driver_queue
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  JOIN public.profiles pr ON pr.id = d.profile_id
  LEFT JOIN public.vehicles v ON v.id = dq.vehicle_id
  WHERE dq.route_id = p_route_id
    AND dq.status IN ('waiting', 'offered', 'assigned', 'active', 'paused');

  -- Current match/trip
  SELECT jsonb_build_object(
    'trip_id', t.id,
    'status', t.status,
    'booked_seats', t.booked_seats,
    'total_seats', t.total_seats,
    'driver_name', pr.name,
    'fare_per_seat', t.fare_per_seat
  )
  INTO v_current_match
  FROM public.trips t
  JOIN public.drivers d ON d.id = t.driver_id
  JOIN public.profiles pr ON pr.id = d.profile_id
  WHERE t.route_id = p_route_id
    AND t.status IN ('accepting_bookings', 'full', 'ready', 'in_progress', 'scheduled')
    AND (t.notes IS NULL OR t.notes != 'provisional_offer')
  ORDER BY t.created_at DESC
  LIMIT 1;

  -- --------------------------------------------------------
  -- MATCHING STATUS — explains current queue state to admin
  -- --------------------------------------------------------
  SELECT dq.*, pr.name as driver_name, v.seating_capacity, v.make, v.model
  INTO v_first_driver
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  JOIN public.profiles pr ON pr.id = d.profile_id
  LEFT JOIN public.vehicles v ON v.id = dq.vehicle_id
  WHERE dq.route_id = p_route_id
    AND dq.status IN ('waiting', 'offered')
  ORDER BY dq.joined_at ASC
  LIMIT 1;

  SELECT COALESCE(SUM(seat_count), 0)::INTEGER INTO v_waiting_seats
  FROM public.passenger_queue
  WHERE route_id = p_route_id AND status = 'WAITING';

  IF v_first_driver IS NULL THEN
    v_matching_status := jsonb_build_object(
      'state', 'no_driver',
      'message', 'No drivers online for this route'
    );
  ELSIF v_first_driver.status = 'offered' THEN
    -- Calculate seconds remaining
    v_offer_seconds_remaining := GREATEST(0,
      EXTRACT(EPOCH FROM (v_first_driver.offer_expires_at - NOW()))::INTEGER
    );
    v_matching_status := jsonb_build_object(
      'state', 'offer_sent',
      'message', format('Offer sent to %s — expires in %ss', v_first_driver.driver_name, v_offer_seconds_remaining),
      'driver_name', v_first_driver.driver_name,
      'vehicle_capacity', v_first_driver.seating_capacity,
      'offer_expires_at', v_first_driver.offer_expires_at,
      'seconds_remaining', v_offer_seconds_remaining
    );
  ELSIF v_waiting_seats < v_first_driver.seating_capacity THEN
    v_matching_status := jsonb_build_object(
      'state', 'waiting_for_passengers',
      'message', format(
        'Waiting for %s more seat(s) to fill %s''s %s %s (%s-seat vehicle)',
        v_first_driver.seating_capacity - v_waiting_seats,
        v_first_driver.driver_name,
        v_first_driver.make,
        v_first_driver.model,
        v_first_driver.seating_capacity
      ),
      'driver_name', v_first_driver.driver_name,
      'vehicle_capacity', v_first_driver.seating_capacity,
      'waiting_seats', v_waiting_seats,
      'seats_needed', v_first_driver.seating_capacity - v_waiting_seats
    );
  ELSE
    v_matching_status := jsonb_build_object(
      'state', 'ready_to_match',
      'message', format(
        'Ready to match — %s waiting seats for %s-seat vehicle',
        v_waiting_seats,
        v_first_driver.seating_capacity
      ),
      'driver_name', v_first_driver.driver_name,
      'vehicle_capacity', v_first_driver.seating_capacity,
      'waiting_seats', v_waiting_seats
    );
  END IF;

  RETURN jsonb_build_object(
    'passenger_queue', COALESCE(v_passenger_queue, '[]'::JSONB),
    'driver_queue', COALESCE(v_driver_queue, '[]'::JSONB),
    'current_match', v_current_match,
    'matching_status', v_matching_status
  );
END;
$$;

-- ============================================================
-- STEP 11: UPDATE get_driver_queue_status
-- Add 'waiting_for_passengers' state when not enough seats
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_driver_queue_status(
  p_driver_profile_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_driver RECORD;
  v_queue_entry RECORD;
  v_position INTEGER;
  v_trip RECORD;
  v_vehicle RECORD;
  v_route RECORD;
  v_timeout_seconds INTEGER;
  v_waiting_seats INTEGER;
  v_seats_needed INTEGER;
BEGIN
  SELECT * INTO v_driver FROM public.drivers WHERE profile_id = p_driver_profile_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  SELECT * INTO v_queue_entry
  FROM public.driver_queue
  WHERE driver_id = v_driver.id
    AND status IN ('waiting', 'offered', 'assigned', 'active')
  ORDER BY joined_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false, 'status', 'offline');
  END IF;

  v_position := public.get_driver_queue_position(v_queue_entry.id);

  SELECT * INTO v_route FROM public.routes WHERE id = v_queue_entry.route_id;
  SELECT make, model, registration_number, seating_capacity INTO v_vehicle
  FROM public.vehicles WHERE id = v_queue_entry.vehicle_id;

  v_timeout_seconds := COALESCE(
    public.get_business_setting('driver_offer_timeout_seconds')::INTEGER,
    45
  );

  -- OFFERED state
  IF v_queue_entry.status = 'offered' AND v_queue_entry.provisional_trip_id IS NOT NULL THEN
    SELECT * INTO v_trip FROM public.trips WHERE id = v_queue_entry.provisional_trip_id;
    RETURN jsonb_build_object(
      'found', true,
      'queue_entry_id', v_queue_entry.id,
      'status', v_queue_entry.status,
      'queue_position', v_position,
      'drivers_ahead', GREATEST(0, v_position - 1),
      'route_from', v_route.from_location,
      'route_to', v_route.to_location,
      'vehicle_make', v_vehicle.make,
      'vehicle_model', v_vehicle.model,
      'vehicle_registration', v_vehicle.registration_number,
      'vehicle_capacity', v_vehicle.seating_capacity,
      'offered_at', v_queue_entry.offered_at,
      'offer_expires_at', v_queue_entry.offer_expires_at,
      'provisional_trip_id', v_queue_entry.provisional_trip_id,
      'passenger_count', v_trip.booked_seats,
      'fare_per_seat', v_trip.fare_per_seat,
      'offer_timeout_seconds', v_timeout_seconds
    );
  END IF;

  -- ASSIGNED/ACTIVE state
  IF v_queue_entry.status IN ('assigned', 'active') THEN
    SELECT * INTO v_trip
    FROM public.trips
    WHERE (id = v_queue_entry.provisional_trip_id OR queue_entry_id = v_queue_entry.id)
      AND status NOT IN ('cancelled')
    ORDER BY created_at DESC
    LIMIT 1;

    RETURN jsonb_build_object(
      'found', true,
      'queue_entry_id', v_queue_entry.id,
      'status', v_queue_entry.status,
      'queue_position', v_position,
      'drivers_ahead', GREATEST(0, v_position - 1),
      'route_from', v_route.from_location,
      'route_to', v_route.to_location,
      'vehicle_make', v_vehicle.make,
      'vehicle_model', v_vehicle.model,
      'vehicle_registration', v_vehicle.registration_number,
      'vehicle_capacity', v_vehicle.seating_capacity,
      'trip_id', v_trip.id,
      'trip_status', v_trip.status,
      'booked_seats', v_trip.booked_seats,
      'total_seats', v_trip.total_seats
    );
  END IF;

  -- WAITING state — check if enough passengers exist
  SELECT COALESCE(SUM(seat_count), 0)::INTEGER INTO v_waiting_seats
  FROM public.passenger_queue
  WHERE route_id = v_queue_entry.route_id
    AND status = 'WAITING';

  v_seats_needed := GREATEST(0, v_vehicle.seating_capacity - v_waiting_seats);

  RETURN jsonb_build_object(
    'found', true,
    'queue_entry_id', v_queue_entry.id,
    'status', v_queue_entry.status,
    'queue_position', v_position,
    'drivers_ahead', GREATEST(0, v_position - 1),
    'route_from', v_route.from_location,
    'route_to', v_route.to_location,
    'vehicle_make', v_vehicle.make,
    'vehicle_model', v_vehicle.model,
    'vehicle_registration', v_vehicle.registration_number,
    'vehicle_capacity', v_vehicle.seating_capacity,
    'waiting_passenger_seats', v_waiting_seats,
    'seats_needed_to_dispatch', v_seats_needed,
    'ready_to_dispatch', (v_waiting_seats >= v_vehicle.seating_capacity)
  );
END;
$$;

-- ============================================================
-- STEP 12: GRANT EXECUTE on new/updated functions
-- ============================================================

GRANT EXECUTE ON FUNCTION public.match_route_queue(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.book_seat(UUID, UUID, UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.driver_accept_offer(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.release_provisional_trip(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expire_all_stale_offers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_route_queues_for_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_driver_queue_status(UUID) TO authenticated;

-- Also grant to service_role for cron execution
GRANT EXECUTE ON FUNCTION public.expire_all_stale_offers() TO service_role;
GRANT EXECUTE ON FUNCTION public.expire_driver_offer(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.match_route_queue(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.release_provisional_trip(UUID, TEXT) TO service_role;

-- ============================================================
-- STEP 13: pg_cron — Schedule expire_all_stale_offers
-- Runs every 30 seconds (pg_cron minimum is 1 minute on most
-- Supabase plans; if so, it will run every minute instead).
-- ============================================================

DO $$
BEGIN
  -- Only attempt if pg_cron extension is available
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    -- Remove existing job if present
    PERFORM cron.unschedule('raahi_expire_stale_offers')
    WHERE EXISTS (
      SELECT 1 FROM cron.job WHERE jobname = 'raahi_expire_stale_offers'
    );

    -- Schedule: every minute (pg_cron minimum)
    -- For sub-minute expiry, use Supabase Edge Function cron (see README)
    PERFORM cron.schedule(
      'raahi_expire_stale_offers',
      '* * * * *',   -- every minute
      'SELECT public.expire_all_stale_offers();'
    );

    RAISE NOTICE 'pg_cron job raahi_expire_stale_offers scheduled (every 1 minute).';
  ELSE
    RAISE NOTICE 'pg_cron not available. Use Supabase Edge Function cron for server-side expiry. See supabase/functions/expire-offers/index.ts';
  END IF;
END;
$$;
