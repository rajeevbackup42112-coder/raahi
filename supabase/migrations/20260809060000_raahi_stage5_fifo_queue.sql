-- ============================================================
-- RAAHI STAGE 5 — FIFO PASSENGER QUEUE + AUTOMATIC MATCHING
-- Migration: 20260809060000_raahi_stage5_fifo_queue.sql
-- ============================================================

-- ============================================================
-- STEP 1: EXTEND ENUMS (safe additions only)
-- ============================================================

ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'passenger_joined_queue';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'passenger_assigned_to_trip';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'passenger_returned_to_queue';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'driver_joined_queue';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'driver_offered_ride';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'driver_accepted_offer';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'driver_declined_offer';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'offer_expired';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'driver_cancelled_trip';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'passengers_rematched';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'admin_changed_queue_order';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'passenger_queue_cancelled';

COMMIT;

-- ============================================================
-- STEP 2: EXTEND driver_queue status enum
-- ============================================================

ALTER TYPE public.queue_status ADD VALUE IF NOT EXISTS 'offered';
ALTER TYPE public.queue_status ADD VALUE IF NOT EXISTS 'declined';
ALTER TYPE public.queue_status ADD VALUE IF NOT EXISTS 'assigned';

COMMIT;

-- ============================================================
-- STEP 3: ADD COLUMNS TO driver_queue
-- ============================================================

ALTER TABLE public.driver_queue
  ADD COLUMN IF NOT EXISTS offered_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS offer_expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS provisional_trip_id UUID;

-- ============================================================
-- STEP 4: CREATE passenger_queue TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.passenger_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id UUID NOT NULL REFERENCES public.routes(id) ON DELETE CASCADE,
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  passenger_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  seat_count INTEGER NOT NULL DEFAULT 1 CHECK (seat_count > 0),
  queue_sequence BIGSERIAL,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status TEXT NOT NULL DEFAULT 'WAITING'
    CHECK (status IN ('WAITING','MATCHING','ASSIGNED','CANCELLED','COMPLETED')),
  assigned_trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,
  original_queue_sequence BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_passenger_queue_route_status
  ON public.passenger_queue(route_id, status, queue_sequence);

CREATE INDEX IF NOT EXISTS idx_passenger_queue_booking
  ON public.passenger_queue(booking_id);

CREATE INDEX IF NOT EXISTS idx_passenger_queue_passenger
  ON public.passenger_queue(passenger_id);

-- ============================================================
-- STEP 5: RLS for passenger_queue
-- ============================================================

ALTER TABLE public.passenger_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "passengers_view_own_queue" ON public.passenger_queue;
CREATE POLICY "passengers_view_own_queue"
  ON public.passenger_queue FOR SELECT
  TO authenticated
  USING (passenger_id = auth.uid());

DROP POLICY IF EXISTS "passengers_insert_own_queue" ON public.passenger_queue;
CREATE POLICY "passengers_insert_own_queue"
  ON public.passenger_queue FOR INSERT
  TO authenticated
  WITH CHECK (passenger_id = auth.uid());

DROP POLICY IF EXISTS "passengers_update_own_queue" ON public.passenger_queue;
CREATE POLICY "passengers_update_own_queue"
  ON public.passenger_queue FOR UPDATE
  TO authenticated
  USING (passenger_id = auth.uid());

DROP POLICY IF EXISTS "admin_all_passenger_queue" ON public.passenger_queue;
CREATE POLICY "admin_all_passenger_queue"
  ON public.passenger_queue FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================
-- STEP 6: ADD NEW BUSINESS SETTINGS
-- ============================================================

INSERT INTO public.business_settings (key, value, description)
VALUES
  ('driver_offer_timeout_seconds', '45', 'Seconds before a driver offer expires'),
  ('driver_decline_queue_behavior', 'MOVE_TO_END', 'What happens when driver declines: MOVE_TO_END or REMOVE'),
  ('driver_timeout_queue_behavior', 'MOVE_TO_END', 'What happens when driver offer times out: MOVE_TO_END or REMOVE'),
  ('keep_multi_seat_booking_together', 'true', 'Whether to keep multi-seat bookings together when matching'),
  ('automatic_matching_enabled', 'true', 'Whether automatic FIFO matching is enabled')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- STEP 7: HELPER — get_business_setting
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_business_setting(p_key TEXT)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT value FROM public.business_settings WHERE key = p_key LIMIT 1;
$$;

-- ============================================================
-- STEP 8: HELPER — get_passenger_queue_position
-- Returns the 1-based rank of a passenger_queue entry among WAITING entries for a route
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_passenger_queue_position(p_queue_id UUID)
RETURNS INTEGER
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(
    (
      SELECT rank::INTEGER
      FROM (
        SELECT id, RANK() OVER (ORDER BY queue_sequence ASC) AS rank
        FROM public.passenger_queue
        WHERE route_id = (SELECT route_id FROM public.passenger_queue WHERE id = p_queue_id)
          AND status IN ('WAITING', 'MATCHING')
      ) ranked
      WHERE id = p_queue_id
    ),
    0
  );
$$;

-- ============================================================
-- STEP 9: HELPER — get_driver_queue_position
-- Returns the 1-based rank of a driver_queue entry among QUEUED entries for a route
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_driver_queue_position(p_queue_id UUID)
RETURNS INTEGER
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(
    (
      SELECT rank::INTEGER
      FROM (
        SELECT id, RANK() OVER (ORDER BY joined_at ASC) AS rank
        FROM public.driver_queue
        WHERE route_id = (SELECT route_id FROM public.driver_queue WHERE id = p_queue_id)
          AND status IN ('waiting', 'offered')
      ) ranked
      WHERE id = p_queue_id
    ),
    0
  );
$$;

-- ============================================================
-- STEP 10: RPC — passenger_join_queue
-- Called after booking is created; adds entry to passenger_queue
-- ============================================================

CREATE OR REPLACE FUNCTION public.passenger_join_queue(
  p_passenger_id UUID,
  p_route_id UUID,
  p_booking_id UUID,
  p_seat_count INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_queue_id UUID;
  v_position INTEGER;
  v_auto_match TEXT;
BEGIN
  -- Validate passenger owns booking
  IF NOT EXISTS (
    SELECT 1 FROM public.bookings
    WHERE id = p_booking_id AND passenger_id = p_passenger_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found or unauthorized');
  END IF;

  -- Prevent duplicate queue entries for same booking
  IF EXISTS (
    SELECT 1 FROM public.passenger_queue
    WHERE booking_id = p_booking_id AND status IN ('WAITING', 'MATCHING', 'ASSIGNED')
  ) THEN
    SELECT id INTO v_queue_id FROM public.passenger_queue
    WHERE booking_id = p_booking_id AND status IN ('WAITING', 'MATCHING', 'ASSIGNED')
    LIMIT 1;
    v_position := public.get_passenger_queue_position(v_queue_id);
    RETURN jsonb_build_object('success', true, 'queue_id', v_queue_id, 'queue_position', v_position, 'already_queued', true);
  END IF;

  -- Insert into passenger_queue
  INSERT INTO public.passenger_queue (
    route_id, booking_id, passenger_id, seat_count, joined_at, status
  ) VALUES (
    p_route_id, p_booking_id, p_passenger_id, p_seat_count, NOW(), 'WAITING'
  )
  RETURNING id INTO v_queue_id;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    p_passenger_id,
    'passenger_joined_queue'::public.audit_action,
    'passenger_queue',
    v_queue_id,
    jsonb_build_object('route_id', p_route_id, 'booking_id', p_booking_id, 'seat_count', p_seat_count),
    'Passenger joined FIFO queue'
  );

  v_position := public.get_passenger_queue_position(v_queue_id);

  -- Trigger matching if enabled
  v_auto_match := public.get_business_setting('automatic_matching_enabled');
  IF v_auto_match = 'true' THEN
    PERFORM public.match_route_queue(p_route_id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'queue_id', v_queue_id,
    'queue_position', v_position
  );
END;
$$;

-- ============================================================
-- STEP 11: RPC — match_route_queue
-- Core FIFO matching: first driver + first passengers by capacity
-- Uses advisory lock to prevent concurrent matching
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
  v_total_assigned INTEGER := 0;
  v_auto_match TEXT;
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
  -- Keep multi-seat bookings together by default
  v_assigned_seats := 0;

  FOR v_entry IN
    SELECT pq.id, pq.booking_id, pq.passenger_id, pq.seat_count, pq.queue_sequence
    FROM public.passenger_queue pq
    WHERE pq.route_id = p_route_id
      AND pq.status = 'WAITING'
    ORDER BY pq.queue_sequence ASC
    FOR UPDATE SKIP LOCKED
  LOOP
    -- Check if this booking fits
    IF (v_assigned_seats + v_entry.seat_count) <= v_capacity THEN
      v_assigned_seats := v_assigned_seats + v_entry.seat_count;
      v_passenger_ids := array_append(v_passenger_ids, v_entry.id);
      v_booking_ids := array_append(v_booking_ids, v_entry.booking_id);
    ELSIF v_keep_together = 'true' THEN
      -- Skip this booking (doesn't fit), continue looking for smaller ones
      -- But only if we haven't filled up yet
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
-- STEP 12: RPC — driver_accept_offer
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

  -- Check offer not expired
  IF v_queue_entry.offer_expires_at < NOW() THEN
    -- Expire it
    PERFORM public.expire_driver_offer(p_queue_entry_id);
    RETURN jsonb_build_object('success', false, 'error', 'Offer has expired');
  END IF;

  -- Get provisional trip with lock
  SELECT * INTO v_trip
  FROM public.trips
  WHERE id = v_queue_entry.provisional_trip_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Trip not found');
  END IF;

  -- Confirm trip
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

  -- Update bookings to link to this trip
  UPDATE public.bookings
  SET
    trip_id = v_trip.id,
    updated_at = NOW()
  WHERE id IN (
    SELECT booking_id FROM public.passenger_queue
    WHERE assigned_trip_id = v_trip.id AND status = 'ASSIGNED'
  );

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    p_driver_profile_id,
    'driver_accepted_offer'::public.audit_action,
    'driver_queue',
    p_queue_entry_id,
    jsonb_build_object('trip_id', v_trip.id, 'route_id', v_queue_entry.route_id),
    'Driver accepted ride offer'
  );

  RETURN jsonb_build_object(
    'success', true,
    'trip_id', v_trip.id,
    'status', 'driver_assigned'
  );
END;
$$;

-- ============================================================
-- STEP 13: RPC — driver_decline_offer
-- ============================================================

CREATE OR REPLACE FUNCTION public.driver_decline_offer(
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
  v_decline_behavior TEXT;
  v_new_joined_at TIMESTAMPTZ;
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
    RETURN jsonb_build_object('success', false, 'error', 'Offer not found or already processed');
  END IF;

  -- Release provisional trip and return passengers to queue
  PERFORM public.release_provisional_trip(v_queue_entry.provisional_trip_id, 'driver_declined');

  -- Apply decline behavior
  v_decline_behavior := COALESCE(
    public.get_business_setting('driver_decline_queue_behavior'),
    'MOVE_TO_END'
  );

  IF v_decline_behavior = 'MOVE_TO_END' THEN
    -- Move to end by updating joined_at to now
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
    -- REMOVE from queue
    UPDATE public.driver_queue
    SET
      status = 'cancelled',
      updated_at = NOW()
    WHERE id = p_queue_entry_id;

    UPDATE public.drivers
    SET availability_status = 'offline'::public.driver_availability_status, updated_at = NOW()
    WHERE id = v_driver.id;
  END IF;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    p_driver_profile_id,
    'driver_declined_offer'::public.audit_action,
    'driver_queue',
    p_queue_entry_id,
    jsonb_build_object('behavior', v_decline_behavior, 'route_id', v_queue_entry.route_id),
    'Driver declined ride offer'
  );

  -- Trigger next match
  PERFORM public.match_route_queue(v_queue_entry.route_id);

  RETURN jsonb_build_object('success', true, 'behavior', v_decline_behavior);
END;
$$;

-- ============================================================
-- STEP 14: RPC — expire_driver_offer
-- Called when offer timeout is reached
-- ============================================================

CREATE OR REPLACE FUNCTION public.expire_driver_offer(
  p_queue_entry_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_queue_entry RECORD;
  v_timeout_behavior TEXT;
BEGIN
  -- Get queue entry with lock
  SELECT * INTO v_queue_entry
  FROM public.driver_queue
  WHERE id = p_queue_entry_id
    AND status = 'offered'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_found_or_already_processed');
  END IF;

  -- Release provisional trip
  PERFORM public.release_provisional_trip(v_queue_entry.provisional_trip_id, 'offer_expired');

  -- Apply timeout behavior
  v_timeout_behavior := COALESCE(
    public.get_business_setting('driver_timeout_queue_behavior'),
    'MOVE_TO_END'
  );

  IF v_timeout_behavior = 'MOVE_TO_END' THEN
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
    SET status = 'cancelled', updated_at = NOW()
    WHERE id = p_queue_entry_id;

    UPDATE public.drivers
    SET availability_status = 'offline'::public.driver_availability_status, updated_at = NOW()
    WHERE id = v_queue_entry.driver_id;
  END IF;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    v_queue_entry.driver_id,
    'offer_expired'::public.audit_action,
    'driver_queue',
    p_queue_entry_id,
    jsonb_build_object('behavior', v_timeout_behavior, 'route_id', v_queue_entry.route_id),
    'Driver offer expired — timeout reached'
  );

  -- Trigger next match
  PERFORM public.match_route_queue(v_queue_entry.route_id);

  RETURN jsonb_build_object('success', true, 'behavior', v_timeout_behavior);
END;
$$;

-- ============================================================
-- STEP 15: HELPER — release_provisional_trip
-- Releases a provisional trip and returns passengers to WAITING
-- ============================================================

CREATE OR REPLACE FUNCTION public.release_provisional_trip(
  p_trip_id UUID,
  p_reason TEXT DEFAULT 'released'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_trip_id IS NULL THEN RETURN; END IF;

  -- Cancel the provisional trip
  UPDATE public.trips
  SET status = 'cancelled'::public.trip_status, notes = p_reason, updated_at = NOW()
  WHERE id = p_trip_id AND notes = 'provisional_offer';

  -- Return passengers to WAITING, preserving original queue_sequence
  UPDATE public.passenger_queue
  SET
    status = 'WAITING',
    assigned_trip_id = NULL,
    updated_at = NOW()
  WHERE assigned_trip_id = p_trip_id
    AND status = 'MATCHING';

  -- Audit rematching
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    NULL,
    'passenger_returned_to_queue'::public.audit_action,
    'trips',
    p_trip_id,
    jsonb_build_object('reason', p_reason),
    'Passengers returned to FIFO queue — provisional trip released'
  );
END;
$$;

-- ============================================================
-- STEP 16: RPC — driver_cancel_before_trip_start
-- Driver cancels after being assigned but before trip starts
-- ============================================================

CREATE OR REPLACE FUNCTION public.driver_cancel_before_trip_start(
  p_driver_profile_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver RECORD;
  v_queue_entry RECORD;
  v_trip RECORD;
  v_route_id UUID;
BEGIN
  SELECT * INTO v_driver FROM public.drivers WHERE profile_id = p_driver_profile_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver not found');
  END IF;

  -- Find active queue entry
  SELECT * INTO v_queue_entry
  FROM public.driver_queue
  WHERE driver_id = v_driver.id
    AND status IN ('assigned', 'offered', 'waiting', 'active')
  ORDER BY joined_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active queue entry found');
  END IF;

  v_route_id := v_queue_entry.route_id;

  -- Find associated trip
  SELECT * INTO v_trip
  FROM public.trips
  WHERE (id = v_queue_entry.provisional_trip_id OR queue_entry_id = v_queue_entry.id)
    AND status NOT IN ('in_progress', 'completed', 'cancelled')
  FOR UPDATE;

  IF FOUND THEN
    -- Release assigned passengers back to queue preserving FIFO priority
    -- Preserve original queue_sequence so they stay at front
    UPDATE public.passenger_queue
    SET
      status = 'WAITING',
      assigned_trip_id = NULL,
      updated_at = NOW()
    WHERE assigned_trip_id = v_trip.id
      AND status IN ('MATCHING', 'ASSIGNED');

    -- Cancel the trip
    UPDATE public.trips
    SET status = 'cancelled'::public.trip_status, notes = 'driver_cancelled', updated_at = NOW()
    WHERE id = v_trip.id;
  END IF;

  -- Remove driver from queue
  UPDATE public.driver_queue
  SET status = 'cancelled', updated_at = NOW()
  WHERE id = v_queue_entry.id;

  -- Set driver offline
  UPDATE public.drivers
  SET
    availability_status = 'offline'::public.driver_availability_status,
    current_route_id = NULL,
    current_vehicle_id = NULL,
    updated_at = NOW()
  WHERE id = v_driver.id;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    p_driver_profile_id,
    'driver_cancelled_trip'::public.audit_action,
    'driver_queue',
    v_queue_entry.id,
    jsonb_build_object('route_id', v_route_id, 'trip_id', v_trip.id),
    'Driver cancelled before trip start — passengers returned to queue'
  );

  -- Audit rematch
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    p_driver_profile_id,
    'passengers_rematched'::public.audit_action,
    'trips',
    v_trip.id,
    jsonb_build_object('route_id', v_route_id),
    'Passengers rematched after driver cancellation'
  );

  -- Trigger next match
  PERFORM public.match_route_queue(v_route_id);

  RETURN jsonb_build_object('success', true, 'route_id', v_route_id);
END;
$$;

-- ============================================================
-- STEP 17: RPC — cancel_passenger_queue_entry
-- Passenger cancels their queue entry before assignment
-- ============================================================

CREATE OR REPLACE FUNCTION public.cancel_passenger_queue_entry(
  p_passenger_id UUID,
  p_queue_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_entry RECORD;
BEGIN
  SELECT * INTO v_entry
  FROM public.passenger_queue
  WHERE id = p_queue_id
    AND passenger_id = p_passenger_id
    AND status IN ('WAITING', 'MATCHING')
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Queue entry not found or already assigned');
  END IF;

  -- If MATCHING, release the provisional trip slot
  IF v_entry.status = 'MATCHING' AND v_entry.assigned_trip_id IS NOT NULL THEN
    -- Reduce booked_seats on provisional trip
    UPDATE public.trips
    SET booked_seats = GREATEST(0, booked_seats - v_entry.seat_count), updated_at = NOW()
    WHERE id = v_entry.assigned_trip_id AND notes = 'provisional_offer';
  END IF;

  UPDATE public.passenger_queue
  SET status = 'CANCELLED', updated_at = NOW()
  WHERE id = p_queue_id;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    p_passenger_id,
    'passenger_queue_cancelled'::public.audit_action,
    'passenger_queue',
    p_queue_id,
    jsonb_build_object('route_id', v_entry.route_id, 'booking_id', v_entry.booking_id),
    'Passenger cancelled queue entry'
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================
-- STEP 18: RPC — get_passenger_queue_status
-- Returns full queue status for a passenger booking
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_passenger_queue_status(
  p_booking_id UUID,
  p_passenger_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_entry RECORD;
  v_position INTEGER;
  v_total_waiting INTEGER;
  v_trip RECORD;
  v_driver_profile RECORD;
  v_vehicle RECORD;
BEGIN
  SELECT * INTO v_entry
  FROM public.passenger_queue
  WHERE booking_id = p_booking_id
    AND passenger_id = p_passenger_id
    AND status NOT IN ('CANCELLED', 'COMPLETED')
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  v_position := public.get_passenger_queue_position(v_entry.id);

  SELECT COUNT(*)::INTEGER INTO v_total_waiting
  FROM public.passenger_queue
  WHERE route_id = v_entry.route_id
    AND status IN ('WAITING', 'MATCHING')
    AND queue_sequence < v_entry.queue_sequence;

  IF v_entry.assigned_trip_id IS NOT NULL AND v_entry.status = 'ASSIGNED' THEN
    SELECT t.*, d.id as driver_rec_id
    INTO v_trip
    FROM public.trips t
    LEFT JOIN public.drivers d ON d.id = t.driver_id
    WHERE t.id = v_entry.assigned_trip_id;

    IF FOUND AND v_trip.driver_id IS NOT NULL THEN
      SELECT p.name, p.phone INTO v_driver_profile
      FROM public.profiles p
      JOIN public.drivers d ON d.profile_id = p.id
      WHERE d.id = v_trip.driver_id;

      SELECT make, model, registration_number INTO v_vehicle
      FROM public.vehicles WHERE id = v_trip.vehicle_id;
    END IF;

    RETURN jsonb_build_object(
      'found', true,
      'queue_id', v_entry.id,
      'status', v_entry.status,
      'queue_position', v_position,
      'passengers_ahead', v_total_waiting,
      'seat_count', v_entry.seat_count,
      'assigned_trip_id', v_entry.assigned_trip_id,
      'driver_name', v_driver_profile.name,
      'driver_phone', v_driver_profile.phone,
      'vehicle_make', v_vehicle.make,
      'vehicle_model', v_vehicle.model,
      'vehicle_registration', v_vehicle.registration_number,
      'trip_status', v_trip.status
    );
  END IF;

  RETURN jsonb_build_object(
    'found', true,
    'queue_id', v_entry.id,
    'status', v_entry.status,
    'queue_position', v_position,
    'passengers_ahead', v_total_waiting,
    'seat_count', v_entry.seat_count,
    'assigned_trip_id', v_entry.assigned_trip_id
  );
END;
$$;

-- ============================================================
-- STEP 19: RPC — get_driver_queue_status
-- Returns full queue status for a driver
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

  IF v_queue_entry.status = 'offered' AND v_queue_entry.provisional_trip_id IS NOT NULL THEN
    SELECT * INTO v_trip FROM public.trips WHERE id = v_queue_entry.provisional_trip_id;
    RETURN jsonb_build_object(
      'found', true,
      'queue_entry_id', v_queue_entry.id,
      'status', v_queue_entry.status,
      'queue_position', v_position,
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
    'vehicle_capacity', v_vehicle.seating_capacity
  );
END;
$$;

-- ============================================================
-- STEP 20: RPC — get_route_queues_for_admin
-- Returns both passenger and driver queues for a route (admin)
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
  ORDER BY t.created_at DESC
  LIMIT 1;

  RETURN jsonb_build_object(
    'passenger_queue', COALESCE(v_passenger_queue, '[]'::JSONB),
    'driver_queue', COALESCE(v_driver_queue, '[]'::JSONB),
    'current_match', v_current_match
  );
END;
$$;

-- ============================================================
-- STEP 21: MODIFY book_seat to also add to passenger_queue
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
  v_trip RECORD;
  v_booking_id UUID;
  v_queue_id UUID;
  v_queue_position INTEGER;
  v_fare NUMERIC;
  v_auto_match TEXT;
BEGIN
  -- Validate seats
  IF p_seats < 1 OR p_seats > 4 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid seat count');
  END IF;

  -- Get route fare
  SELECT fare_per_seat INTO v_fare FROM public.routes WHERE id = p_route_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Route not found');
  END IF;

  -- Create booking (no trip assigned yet — queue-based model)
  INSERT INTO public.bookings (
    passenger_id, trip_id, pickup_point_id, seats, fare_per_seat, total_fare, status
  )
  SELECT
    p_passenger_id,
    -- Use a placeholder trip or NULL — will be assigned when matched
    -- For backward compat, try to find an active trip first
    COALESCE(
      (SELECT id FROM public.trips
       WHERE route_id = p_route_id
         AND status = 'accepting_bookings'
       ORDER BY created_at DESC LIMIT 1),
      -- Create a placeholder trip if none exists
      NULL
    ),
    p_pickup_point_id,
    p_seats,
    v_fare,
    v_fare * p_seats,
    'confirmed'::public.booking_status
  RETURNING id INTO v_booking_id;

  -- If no trip exists yet, we need a valid trip_id (FK constraint)
  -- Check if booking was created with NULL trip_id (not allowed by FK)
  -- So we create a placeholder trip if needed
  IF NOT EXISTS (SELECT 1 FROM public.bookings WHERE id = v_booking_id AND trip_id IS NOT NULL) THEN
    -- Create a placeholder trip for this route
    DECLARE
      v_placeholder_trip_id UUID;
      v_vehicle_id UUID;
      v_driver_id UUID;
    BEGIN
      -- Find first queued driver for this route
      SELECT dq.vehicle_id, dq.driver_id INTO v_vehicle_id, v_driver_id
      FROM public.driver_queue dq
      WHERE dq.route_id = p_route_id AND dq.status IN ('waiting', 'offered', 'assigned', 'active')
      ORDER BY dq.joined_at ASC LIMIT 1;

      INSERT INTO public.trips (route_id, driver_id, vehicle_id, total_seats, booked_seats, status, fare_per_seat, notes)
      VALUES (
        p_route_id,
        v_driver_id,
        v_vehicle_id,
        COALESCE((SELECT seating_capacity FROM public.vehicles WHERE id = v_vehicle_id), 4),
        0,
        'scheduled'::public.trip_status,
        v_fare,
        'queue_placeholder'
      )
      RETURNING id INTO v_placeholder_trip_id;

      UPDATE public.bookings SET trip_id = v_placeholder_trip_id WHERE id = v_booking_id;
    END;
  END IF;

  -- Add to passenger queue
  INSERT INTO public.passenger_queue (
    route_id, booking_id, passenger_id, seat_count, joined_at, status
  ) VALUES (
    p_route_id, v_booking_id, p_passenger_id, p_seats, NOW(), 'WAITING'
  )
  RETURNING id INTO v_queue_id;

  -- Audit booking created
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    p_passenger_id,
    'booking_created'::public.audit_action,
    'bookings',
    v_booking_id,
    jsonb_build_object('route_id', p_route_id, 'seats', p_seats, 'fare', v_fare * p_seats),
    'Passenger booked seat — entered FIFO queue'
  );

  -- Audit queue join
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
    'total_fare', v_fare * p_seats
  );
END;
$$;

-- ============================================================
-- STEP 22: MODIFY driver_go_online to use new FIFO model
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
  v_queue_id UUID;
  v_queue_position INTEGER;
  v_auto_match TEXT;
BEGIN
  -- Validate driver
  SELECT d.*, p.role INTO v_driver
  FROM public.drivers d
  JOIN public.profiles p ON p.id = d.profile_id
  WHERE d.id = p_driver_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver not found');
  END IF;

  IF v_driver.verification_status != 'approved' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver account not approved');
  END IF;

  -- Validate vehicle
  SELECT * INTO v_vehicle
  FROM public.vehicles
  WHERE id = p_vehicle_id AND status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Vehicle not found or inactive');
  END IF;

  -- Check not already in queue
  IF EXISTS (
    SELECT 1 FROM public.driver_queue
    WHERE driver_id = p_driver_id
      AND route_id = p_route_id
      AND status IN ('waiting', 'offered', 'assigned', 'active')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Already in queue for this route');
  END IF;

  -- Insert into driver_queue
  INSERT INTO public.driver_queue (
    route_id, driver_id, vehicle_id, status, joined_at
  ) VALUES (
    p_route_id, p_driver_id, p_vehicle_id, 'waiting', NOW()
  )
  RETURNING id INTO v_queue_id;

  -- Update driver status
  UPDATE public.drivers
  SET
    availability_status = 'queued'::public.driver_availability_status,
    current_route_id = p_route_id,
    current_vehicle_id = p_vehicle_id,
    updated_at = NOW()
  WHERE id = p_driver_id;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    v_driver.profile_id,
    'driver_joined_queue'::public.audit_action,
    'driver_queue',
    v_queue_id,
    jsonb_build_object('route_id', p_route_id, 'vehicle_id', p_vehicle_id),
    'Driver joined FIFO driver queue'
  );

  v_queue_position := public.get_driver_queue_position(v_queue_id);

  -- Trigger matching
  v_auto_match := public.get_business_setting('automatic_matching_enabled');
  IF v_auto_match = 'true' THEN
    PERFORM public.match_route_queue(p_route_id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'queue_id', v_queue_id,
    'queue_position', v_queue_position,
    'status', 'queued'
  );
END;
$$;

-- ============================================================
-- STEP 23: GRANT EXECUTE on new functions
-- ============================================================

GRANT EXECUTE ON FUNCTION public.get_business_setting(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_passenger_queue_position(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_driver_queue_position(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.passenger_join_queue(UUID, UUID, UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.match_route_queue(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.driver_accept_offer(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.driver_decline_offer(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expire_driver_offer(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.release_provisional_trip(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.driver_cancel_before_trip_start(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_passenger_queue_entry(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_passenger_queue_status(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_driver_queue_status(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_route_queues_for_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.book_seat(UUID, UUID, UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.driver_go_online(UUID, UUID, UUID) TO authenticated;
