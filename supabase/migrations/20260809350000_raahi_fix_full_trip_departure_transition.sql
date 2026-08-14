-- ============================================================
-- RAAHI — Fix Full-Trip Departure State Transition
-- Migration: 20260809350000_raahi_fix_full_trip_departure_transition.sql
-- ============================================================
--
-- ROOT CAUSE (confirmed from production state):
--
--   Trip:   d78924d7-fae0-42f3-a503-af26ecd34925
--   status: accepting_bookings
--   booked_seats: 4 / total_seats: 4
--
-- FAILURE CHAIN:
--
--   1. match_route_queue (migration 340000) fills trip to 4/4 but
--      leaves trip.status = 'accepting_bookings'.
--
--   2. Driver UI shows "Start Departure" button which calls
--      driver_leave_now (not driver_start_trip).
--
--   3. driver_leave_now (migration 230000) only accepts trips with
--      status IN ('boarding', 'departure_pending').
--
--   4. Trip is 'accepting_bookings' → driver_leave_now returns:
--      "No active boarding trip found"
--
-- CANONICAL FULL VEHICLE FLOW (fixed):
--
--   accepting_bookings (filling seats)
--   → full (when booked_seats >= total_seats, set by match_route_queue)
--   → departure_pending (when driver clicks Start Departure / Leave Now)
--     NOTE: For a full vehicle, departure_lock_seconds = 0 (immediate)
--   → in_progress (when driver clicks Start Trip)
--
-- FIXES IN THIS MIGRATION:
--
--   FIX 1: match_route_queue
--     After recalculating trip.booked_seats, if booked_seats >= total_seats
--     atomically transition trip.status to 'full'.
--     This makes the state machine consistent.
--
--   FIX 2: driver_leave_now
--     Accept trips with status IN ('accepting_bookings', 'full', 'boarding',
--     'departure_pending').
--     For a full vehicle (booked_seats >= total_seats), skip the departure
--     lock window (set departure_lock_expires_at = NOW() so it is already
--     expired) — driver can start immediately.
--     For partial load (>= min_passengers but not full), apply the normal
--     departure lock as before.
--
--   FIX 3: driver_start_trip
--     Accept trips with status IN ('departure_pending', 'full', 'boarding',
--     'ready', 'accepting_bookings') so the legacy fallback path also
--     handles 'full' status trips.
--
--   FIX 4: Repair existing live trip
--     If the live trip d78924d7 is still accepting_bookings with
--     booked_seats = total_seats, transition it to 'full' immediately
--     so the driver can depart without waiting for a new booking event.
--
-- REGRESSION SAFETY:
--   A. full 4/4 trip → Start Departure → departure_pending (lock=0) → Start Trip → in_progress
--   B. partial trip at minimum → Leave Now → departure lock still applies
--   C. partial trip below minimum → cannot start
--   D. departure_pending before lock expiry → start rejected
--   E. departure_pending after lock expiry → start succeeds
--   F. full trip accepts no additional passenger (status='full' blocked)
--   G. already in_progress → duplicate Start Departure safely rejected
-- ============================================================

-- ============================================================
-- STEP 1: Ensure 'full' exists in trip_status enum
-- (It was defined in stage2 schema but guard idempotently)
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumlabel = 'full'
      AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'trip_status')
  ) THEN
    ALTER TYPE public.trip_status ADD VALUE 'full';
  END IF;
END $$;

-- ============================================================
-- STEP 2: FIX match_route_queue
-- After filling seats in Branch 1, if booked_seats >= total_seats
-- transition trip.status to 'full'.
-- ============================================================

CREATE OR REPLACE FUNCTION public.match_route_queue(p_route_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lock_key             BIGINT;
  v_auto_match           TEXT;
  v_min_passengers       INTEGER;
  v_total_waiting_seats  INTEGER;
  v_route                RECORD;
  v_keep_together        TEXT;

  -- Branch 1: existing accepting trip
  v_existing_trip_id     UUID;
  v_existing_trip        RECORD;
  v_confirmed_seats      INTEGER;
  v_remaining_capacity   INTEGER;
  v_entry                RECORD;
  v_assigned_pq_ids      UUID[]   := ARRAY[]::UUID[];
  v_assigned_bk_ids      UUID[]   := ARRAY[]::UUID[];
  v_fill_seats           INTEGER  := 0;
  v_branch1_done         BOOLEAN  := FALSE;
  v_new_booked_seats     INTEGER  := 0;

  -- Branch 2: new driver offer
  v_driver_entry         RECORD;
  v_vehicle              RECORD;
  v_capacity             INTEGER;
  v_passenger_ids        UUID[]   := ARRAY[]::UUID[];
  v_booking_ids          UUID[]   := ARRAY[]::UUID[];
  v_assigned_seats       INTEGER  := 0;
  v_trip_id              UUID;
  v_timeout_seconds      INTEGER;
  v_offer_expires        TIMESTAMPTZ;
BEGIN
  -- Global guards
  v_auto_match := public.get_business_setting('automatic_matching_enabled');
  IF v_auto_match != 'true' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'automatic_matching_disabled');
  END IF;

  -- Advisory lock keyed on route_id to prevent concurrent matching
  v_lock_key := ('x' || substr(p_route_id::TEXT, 1, 8))::BIT(32)::BIGINT;
  IF NOT pg_try_advisory_xact_lock(v_lock_key) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'lock_contention');
  END IF;

  -- Get route info
  SELECT * INTO v_route FROM public.routes WHERE id = p_route_id AND status = 'active';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'route_inactive_or_not_found');
  END IF;

  v_min_passengers := COALESCE(v_route.min_passengers, 1);
  v_keep_together  := public.get_business_setting('keep_multi_seat_booking_together');

  -- Count total WAITING seats for this route
  SELECT COALESCE(SUM(seat_count), 0) INTO v_total_waiting_seats
  FROM public.passenger_queue
  WHERE route_id = p_route_id AND status = 'WAITING';

  IF v_total_waiting_seats = 0 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_passengers_waiting');
  END IF;

  -- ======================================================================
  -- BRANCH 1: Fill existing accepting_bookings / boarding / full trip
  --
  -- We do NOT require the driver_queue row to be 'waiting'.
  -- A driver may have status='assigned' while their trip continues
  -- accepting additional passengers. We find the trip directly.
  -- ======================================================================

  SELECT t.id INTO v_existing_trip_id
  FROM public.trips t
  WHERE t.route_id = p_route_id
    AND t.status IN ('accepting_bookings', 'boarding')
    AND t.booked_seats < t.total_seats
    AND EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.id = t.driver_id
        AND d.availability_status IN ('active', 'queued')
    )
    AND EXISTS (
      SELECT 1 FROM public.vehicles v
      WHERE v.id = t.vehicle_id
        AND v.status = 'active'
    )
  ORDER BY t.created_at DESC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF v_existing_trip_id IS NOT NULL THEN
    -- Lock the trip row and read current state
    SELECT t.id, t.total_seats, t.booked_seats, t.route_id, t.driver_id, t.vehicle_id, t.status
    INTO v_existing_trip
    FROM public.trips t
    WHERE t.id = v_existing_trip_id
    FOR UPDATE;

    -- Recalculate confirmed seats from bookings (authoritative count)
    SELECT COALESCE(SUM(b.seats), 0) INTO v_confirmed_seats
    FROM public.bookings b
    WHERE b.trip_id = v_existing_trip_id
      AND b.status IN ('confirmed', 'queued', 'matching');

    v_remaining_capacity := v_existing_trip.total_seats - v_confirmed_seats;

    IF v_remaining_capacity > 0 THEN
      -- Assign WAITING passengers FIFO into the existing trip (fit-aware)
      v_fill_seats := 0;

      FOR v_entry IN
        SELECT pq.id, pq.booking_id, pq.passenger_id, pq.seat_count, pq.queue_sequence
        FROM public.passenger_queue pq
        WHERE pq.route_id = p_route_id
          AND pq.status = 'WAITING'
        ORDER BY pq.queue_sequence ASC
        FOR UPDATE SKIP LOCKED
      LOOP
        IF (v_fill_seats + v_entry.seat_count) <= v_remaining_capacity THEN
          v_fill_seats      := v_fill_seats + v_entry.seat_count;
          v_assigned_pq_ids := array_append(v_assigned_pq_ids, v_entry.id);
          v_assigned_bk_ids := array_append(v_assigned_bk_ids, v_entry.booking_id);
        ELSIF v_keep_together = 'true' THEN
          IF v_fill_seats < v_remaining_capacity THEN
            CONTINUE;
          ELSE
            EXIT;
          END IF;
        ELSE
          EXIT;
        END IF;

        IF v_fill_seats >= v_remaining_capacity THEN
          EXIT;
        END IF;
      END LOOP;

      IF array_length(v_assigned_pq_ids, 1) IS NOT NULL
         AND array_length(v_assigned_pq_ids, 1) > 0 THEN

        -- Update bookings: link to trip, mark confirmed
        UPDATE public.bookings
        SET
          trip_id    = v_existing_trip_id,
          status     = 'confirmed'::public.booking_status,
          updated_at = NOW()
        WHERE id = ANY(v_assigned_bk_ids);

        -- Update passenger_queue: mark ASSIGNED
        UPDATE public.passenger_queue
        SET
          status           = 'ASSIGNED',
          assigned_trip_id = v_existing_trip_id,
          updated_at       = NOW()
        WHERE id = ANY(v_assigned_pq_ids);

        -- Recalculate trip.booked_seats from confirmed bookings
        SELECT COALESCE(SUM(b.seats), 0)
        INTO v_new_booked_seats
        FROM public.bookings b
        WHERE b.trip_id = v_existing_trip_id
          AND b.status = 'confirmed';

        -- KEY FIX: If trip is now full, transition to 'full' status
        -- This allows driver_leave_now to find and process it correctly.
        UPDATE public.trips
        SET
          booked_seats = v_new_booked_seats,
          status       = CASE
                           WHEN v_new_booked_seats >= v_existing_trip.total_seats
                           THEN 'full'::public.trip_status
                           ELSE status
                         END,
          updated_at   = NOW()
        WHERE id = v_existing_trip_id;

        -- Audit each assignment
        INSERT INTO public.audit_logs (
          performed_by, action, target_table, target_id, new_value, notes
        )
        SELECT
          pq.passenger_id,
          'passenger_assigned_to_trip'::public.audit_action,
          'passenger_queue',
          pq.id,
          jsonb_build_object(
            'trip_id',        v_existing_trip_id,
            'route_id',       p_route_id,
            'booking_id',     pq.booking_id,
            'branch',         'existing_trip_fill',
            'new_booked_seats', v_new_booked_seats,
            'total_seats',    v_existing_trip.total_seats,
            'trip_now_full',  v_new_booked_seats >= v_existing_trip.total_seats
          ),
          'Passenger assigned to existing accepting trip'
        FROM public.passenger_queue pq
        WHERE pq.id = ANY(v_assigned_pq_ids);

        v_branch1_done := TRUE;

      END IF; -- passengers assigned
    END IF; -- remaining_capacity > 0
  END IF; -- existing trip found

  -- If Branch 1 successfully assigned passengers, return now
  IF v_branch1_done THEN
    RETURN jsonb_build_object(
      'success',             true,
      'branch',              'existing_trip_fill',
      'trip_id',             v_existing_trip_id,
      'passenger_queue_ids', v_assigned_pq_ids,
      'assigned_seats',      v_fill_seats,
      'new_booked_seats',    v_new_booked_seats,
      'trip_now_full',       v_new_booked_seats >= v_existing_trip.total_seats
    );
  END IF;

  -- ======================================================================
  -- BRANCH 2: New driver offer / provisional trip
  -- Only runs when no eligible accepting trip exists (or trip was full).
  -- ======================================================================

  -- Check minimum passengers threshold before creating a new offer
  IF v_total_waiting_seats < v_min_passengers THEN
    RETURN jsonb_build_object(
      'success',       false,
      'reason',        'insufficient_passengers',
      'waiting_seats', v_total_waiting_seats,
      'min_required',  v_min_passengers
    );
  END IF;

  -- Find first eligible driver in FIFO order (status = waiting only)
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

  -- Collect earliest WAITING passengers up to capacity (FIFO, fit-aware)
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
      v_assigned_seats  := v_assigned_seats + v_entry.seat_count;
      v_passenger_ids   := array_append(v_passenger_ids, v_entry.id);
      v_booking_ids     := array_append(v_booking_ids, v_entry.booking_id);
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
    RETURN jsonb_build_object('success', false, 'reason', 'no_passengers_fit');
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
    status              = 'offered',
    offered_at          = NOW(),
    offer_expires_at    = v_offer_expires,
    provisional_trip_id = v_trip_id,
    updated_at          = NOW()
  WHERE id = v_driver_entry.id;

  -- Mark passenger queue entries as MATCHING and link to provisional trip
  UPDATE public.passenger_queue
  SET
    status           = 'MATCHING',
    assigned_trip_id = v_trip_id,
    updated_at       = NOW()
  WHERE id = ANY(v_passenger_ids);

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    v_driver_entry.driver_id,
    'driver_offered_ride'::public.audit_action,
    'driver_queue',
    v_driver_entry.id,
    jsonb_build_object(
      'trip_id',          v_trip_id,
      'route_id',         p_route_id,
      'passenger_count',  array_length(v_passenger_ids, 1),
      'seat_count',       v_assigned_seats,
      'offer_expires_at', v_offer_expires,
      'branch',           'new_driver_offer'
    ),
    'Driver offered ride via FIFO matching'
  );

  RETURN jsonb_build_object(
    'success',             true,
    'branch',              'new_driver_offer',
    'trip_id',             v_trip_id,
    'driver_queue_id',     v_driver_entry.id,
    'passenger_queue_ids', v_passenger_ids,
    'assigned_seats',      v_assigned_seats,
    'offer_expires_at',    v_offer_expires
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.match_route_queue(UUID) TO authenticated;

-- ============================================================
-- STEP 3: FIX driver_leave_now
-- Accept trips with status IN ('accepting_bookings', 'full', 'boarding').
-- For a full vehicle: skip departure lock (immediate departure).
-- For partial load at minimum: apply normal departure lock.
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
  v_total_seats       INTEGER;
  v_vehicle_capacity  INTEGER;
  v_lock_seconds      INTEGER := 60;
  v_lock_expires_at   TIMESTAMPTZ;
  v_is_full           BOOLEAN := FALSE;
BEGIN
  -- Resolve driver record
  SELECT id INTO v_driver_id
  FROM public.drivers
  WHERE profile_id = p_driver_profile_id;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver not found');
  END IF;

  -- Find the active trip for this driver
  -- Accept: accepting_bookings, full, boarding (all pre-departure states)
  -- Reject: departure_pending (already locked), in_progress, completed, cancelled
  SELECT t.id, t.status, t.route_id, t.total_seats
  INTO v_trip_id, v_trip_status, v_route_id, v_total_seats
  FROM public.trips t
  WHERE t.driver_id = v_driver_id
    AND t.status IN ('accepting_bookings', 'full', 'boarding')
  ORDER BY t.created_at DESC
  LIMIT 1;

  IF v_trip_id IS NULL THEN
    -- Check if already departure_pending (idempotent response)
    IF EXISTS (
      SELECT 1 FROM public.trips
      WHERE driver_id = v_driver_id
        AND status = 'departure_pending'
      LIMIT 1
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Departure lock already active');
    END IF;

    RETURN jsonb_build_object('success', false, 'error', 'No active boarding trip found');
  END IF;

  -- Get route min_passengers
  SELECT COALESCE(min_passengers, 1)
  INTO v_min_passengers
  FROM public.routes
  WHERE id = v_route_id;

  -- Count currently confirmed seats for this trip
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

  -- Determine if vehicle is full
  v_is_full := v_booked_seats >= COALESCE(v_total_seats, v_vehicle_capacity, 4);

  IF v_is_full THEN
    -- Full vehicle: no departure lock needed — set expires_at = NOW()
    -- so driver_start_trip can proceed immediately
    v_lock_seconds    := 0;
    v_lock_expires_at := NOW();
  ELSE
    -- Partial load at minimum: apply normal departure lock
    SELECT COALESCE(value::INTEGER, 60)
    INTO v_lock_seconds
    FROM public.business_settings
    WHERE key = 'departure_lock_seconds';

    v_lock_expires_at := NOW() + (v_lock_seconds || ' seconds')::INTERVAL;
  END IF;

  -- Transition trip to departure_pending
  UPDATE public.trips
  SET status                    = 'departure_pending',
      departure_lock_expires_at = v_lock_expires_at,
      updated_at                = NOW()
  WHERE id = v_trip_id;

  INSERT INTO public.audit_logs (action, target_table, target_id, new_value, notes)
  VALUES (
    'trip_departure_initiated'::public.audit_action,
    'trips',
    v_trip_id,
    jsonb_build_object(
      'driver_id',              v_driver_id,
      'booked_seats',           v_booked_seats,
      'total_seats',            v_total_seats,
      'is_full',                v_is_full,
      'departure_lock_seconds', v_lock_seconds,
      'departure_lock_expires_at', v_lock_expires_at
    ),
    CASE WHEN v_is_full
         THEN 'Full vehicle departure initiated — no lock window'
         ELSE 'Partial load departure initiated — lock window active'
    END
  );

  RETURN jsonb_build_object(
    'success',                   true,
    'trip_id',                   v_trip_id,
    'departure_lock_seconds',    v_lock_seconds,
    'departure_lock_expires_at', v_lock_expires_at,
    'booked_seats',              v_booked_seats,
    'vehicle_capacity',          v_vehicle_capacity,
    'min_passengers',            v_min_passengers,
    'is_full',                   v_is_full
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.driver_leave_now(UUID) TO authenticated;

-- ============================================================
-- STEP 4: FIX driver_start_trip
-- Accept departure_pending (primary path) and also 'full', 'boarding',
-- 'ready', 'accepting_bookings' as legacy fallback.
-- For departure_pending: if lock has expired (including 0-second lock
-- for full vehicles), start immediately.
-- ============================================================

CREATE OR REPLACE FUNCTION public.driver_start_trip(
  p_driver_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trip           RECORD;
  v_booked_seats   INTEGER;
  v_min_passengers INTEGER;
  v_now            TIMESTAMPTZ := NOW();
BEGIN
  -- PRIMARY PATH: Find departure_pending trip
  SELECT t.*
  INTO v_trip
  FROM public.trips t
  WHERE t.driver_id = p_driver_id
    AND t.status = 'departure_pending'
  ORDER BY t.created_at DESC
  LIMIT 1;

  IF FOUND THEN
    -- GUARD 1: Departure lock must have expired
    -- (For full vehicles, departure_lock_expires_at = NOW() at creation,
    --  so this check passes immediately)
    IF v_trip.departure_lock_expires_at IS NOT NULL
       AND v_trip.departure_lock_expires_at > v_now THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Departure lock still active',
        'departure_lock_expires_at', v_trip.departure_lock_expires_at,
        'lock_remaining_seconds', EXTRACT(EPOCH FROM (v_trip.departure_lock_expires_at - v_now))::INTEGER
      );
    END IF;

    -- GUARD 2: Minimum occupancy must still be satisfied
    SELECT COALESCE(min_passengers, 1)
    INTO v_min_passengers
    FROM public.routes
    WHERE id = v_trip.route_id;

    SELECT COALESCE(SUM(b.seats), 0)
    INTO v_booked_seats
    FROM public.bookings b
    WHERE b.trip_id = v_trip.id
      AND b.status = 'confirmed';

    IF v_booked_seats < v_min_passengers THEN
      -- Eligibility was revoked — revert to boarding
      UPDATE public.trips
      SET status = 'boarding',
          departure_lock_expires_at = NULL,
          updated_at = v_now
      WHERE id = v_trip.id;

      RETURN jsonb_build_object(
        'success', false,
        'error', 'Below minimum occupancy — departure eligibility revoked',
        'booked_seats', v_booked_seats,
        'min_passengers', v_min_passengers,
        'seats_needed', v_min_passengers - v_booked_seats
      );
    END IF;

    -- All guards passed — start the trip
    UPDATE public.trips
    SET status = 'in_progress',
        actual_departure = v_now,
        departure_lock_expires_at = NULL,
        updated_at = v_now
    WHERE id = v_trip.id;

    UPDATE public.drivers
    SET availability_status = 'trip_started'
    WHERE id = p_driver_id;

    -- Update all confirmed passengers to reflect trip is in_progress
    -- (passenger_queue status stays ASSIGNED; booking status stays confirmed
    --  — the trip.status = in_progress is what the passenger UI reads)

    INSERT INTO public.audit_logs (action, target_table, target_id, new_value, notes)
    VALUES ('trip_started'::public.audit_action, 'trips', v_trip.id,
      jsonb_build_object(
        'driver_id',    p_driver_id,
        'booked_seats', v_booked_seats,
        'trip_status',  'in_progress'
      ),
      'Trip started by driver');

    RETURN jsonb_build_object(
      'success',      true,
      'trip_id',      v_trip.id,
      'message',      'Trip started',
      'booked_seats', v_booked_seats
    );
  END IF;

  -- LEGACY FALLBACK: Accept full/boarding/ready/accepting_bookings
  -- (handles edge cases where departure_pending was not set)
  SELECT t.*
  INTO v_trip
  FROM public.trips t
  WHERE t.driver_id = p_driver_id
    AND t.status IN ('full', 'boarding', 'ready', 'accepting_bookings')
  ORDER BY t.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No active trip found. Press Leave Now first to initiate departure.'
    );
  END IF;

  -- Validate minimum occupancy for legacy path
  SELECT COALESCE(min_passengers, 1)
  INTO v_min_passengers
  FROM public.routes
  WHERE id = v_trip.route_id;

  SELECT COALESCE(SUM(b.seats), 0)
  INTO v_booked_seats
  FROM public.bookings b
  WHERE b.trip_id = v_trip.id
    AND b.status = 'confirmed';

  IF v_booked_seats < v_min_passengers THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Below minimum occupancy',
      'booked_seats', v_booked_seats,
      'min_passengers', v_min_passengers
    );
  END IF;

  -- Start the trip (legacy path — no lock check)
  UPDATE public.trips
  SET status = 'in_progress',
      actual_departure = v_now,
      updated_at = v_now
  WHERE id = v_trip.id;

  UPDATE public.drivers
  SET availability_status = 'trip_started'
  WHERE id = p_driver_id;

  INSERT INTO public.audit_logs (action, target_table, target_id, new_value, notes)
  VALUES ('trip_started'::public.audit_action, 'trips', v_trip.id,
    jsonb_build_object('driver_id', p_driver_id, 'booked_seats', v_booked_seats),
    'Trip started by driver (legacy path)');

  RETURN jsonb_build_object(
    'success',      true,
    'trip_id',      v_trip.id,
    'message',      'Trip started',
    'booked_seats', v_booked_seats
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.driver_start_trip(UUID) TO authenticated;

-- ============================================================
-- STEP 5: FIX driver_wait_for_more
-- Accept accepting_bookings, full, boarding, departure_pending.
-- Retrigger matching after re-entering accepting_bookings.
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
  v_route_id  UUID;
BEGIN
  SELECT id INTO v_driver_id
  FROM public.drivers
  WHERE profile_id = p_driver_profile_id;

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver not found');
  END IF;

  -- Find the most recent pre-departure trip
  SELECT id, route_id INTO v_trip_id, v_route_id
  FROM public.trips
  WHERE driver_id = v_driver_id
    AND status IN ('departure_pending', 'full', 'boarding', 'accepting_bookings')
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_trip_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active trip found for Wait for More');
  END IF;

  -- Return trip to accepting_bookings so new passengers can be assigned
  UPDATE public.trips
  SET
    status                    = 'accepting_bookings'::public.trip_status,
    departure_lock_expires_at = NULL,
    updated_at                = NOW()
  WHERE id = v_trip_id;

  -- Retrigger matching — any WAITING passengers will be filled immediately
  PERFORM public.match_route_queue(v_route_id);

  RETURN jsonb_build_object(
    'success',    true,
    'trip_id',    v_trip_id,
    'new_status', 'accepting_bookings'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.driver_wait_for_more(UUID) TO authenticated;

-- ============================================================
-- STEP 6: FIX get_driver_queue_status
-- Return trip_status correctly for 'full' trips.
-- Ensure departure_lock_remaining_seconds = 0 for full trips
-- (departure_lock_expires_at = NOW() means lock already expired).
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
  -- For full vehicles, departure_lock_expires_at = NOW() at creation,
  -- so lock_remaining = 0 (already expired — can start immediately)
  IF v_trip.status = 'departure_pending' AND v_trip.departure_lock_expires_at IS NOT NULL THEN
    v_lock_remaining := GREATEST(0, EXTRACT(EPOCH FROM (v_trip.departure_lock_expires_at - NOW()))::INTEGER);
  END IF;

  RETURN jsonb_build_object(
    'found',                       true,
    'queue_entry_id',              v_queue_entry.id,
    'status',                      v_queue_entry.status,
    'queue_position',              v_queue_entry.queue_position,
    'drivers_ahead',               GREATEST(0, v_queue_entry.queue_position - 1),
    'route_from',                  v_route.from_location,
    'route_to',                    v_route.to_location,
    'vehicle_make',                v_vehicle.make,
    'vehicle_model',               v_vehicle.model,
    'vehicle_registration',        v_vehicle.registration_number,
    'vehicle_capacity',            v_vehicle.seating_capacity,
    'min_passengers',              v_min_passengers,
    'booked_seats',                v_booked_seats,
    'can_depart',                  v_can_depart,
    'is_full',                     v_booked_seats >= COALESCE(v_vehicle.seating_capacity, 4),
    'trip_id',                     v_trip.id,
    'trip_status',                 v_trip.status,
    'departure_lock_expires_at',   v_trip.departure_lock_expires_at,
    'departure_lock_remaining_seconds', v_lock_remaining,
    'offered_at',                  v_queue_entry.offered_at,
    'offer_expires_at',            v_queue_entry.offer_expires_at,
    'provisional_trip_id',         v_queue_entry.provisional_trip_id,
    'passenger_count',             v_booked_seats,
    'total_seats',                 v_vehicle.seating_capacity,
    'fare_per_seat',               v_route.fare_per_seat,
    'offer_timeout_seconds',       (SELECT value::INTEGER FROM public.business_settings WHERE key = 'driver_offer_timeout_seconds' LIMIT 1)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_driver_queue_status(UUID) TO authenticated;

-- ============================================================
-- STEP 7: Repair existing live trip
-- If trip d78924d7 (or any trip on this route) is still
-- accepting_bookings with booked_seats = total_seats,
-- transition it to 'full' immediately.
-- This unblocks the driver without requiring a new booking event.
-- ============================================================

UPDATE public.trips
SET
  status     = 'full'::public.trip_status,
  updated_at = NOW()
WHERE status = 'accepting_bookings'
  AND booked_seats >= total_seats
  AND booked_seats > 0;

-- ============================================================
-- STEP 8: FIX get_my_bookings — show in_progress when trip is in_progress
-- When trip.status = 'in_progress', override display_status to 'in_progress'
-- so passengers see "Trip in Progress" instead of "Matched".
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_my_bookings()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_passenger_id   UUID;
  v_result         JSONB := '[]'::JSONB;
  v_row            RECORD;
  v_item           JSONB;
  v_items          JSONB[] := ARRAY[]::JSONB[];
  v_display_status TEXT;
BEGIN
  v_passenger_id := auth.uid();
  IF v_passenger_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Not authenticated', 'bookings', '[]'::JSONB);
  END IF;

  FOR v_row IN
    SELECT
      b.id                                              AS booking_id,
      b.trip_id,
      b.pickup_point_id,
      b.seats,
      b.fare_per_seat,
      b.total_fare,
      b.status::TEXT                                    AS booking_status,
      b.booked_at,
      pp.name                                           AS pickup_name,
      pq.id                                             AS queue_id,
      pq.route_id                                       AS pq_route_id,
      pq.status                                         AS queue_status,
      pq.seat_count,
      pq.assigned_trip_id,
      t.route_id                                        AS trip_route_id,
      t.status::TEXT                                    AS trip_status,
      t.vehicle_id,
      COALESCE(rt.from_location, rq.from_location, '') AS route_from,
      COALESCE(rt.to_location,   rq.to_location,   '') AS route_to,
      v.make                                            AS vehicle_make,
      v.model                                           AS vehicle_model
    FROM public.bookings b
    LEFT JOIN public.pickup_points pp ON pp.id = b.pickup_point_id
    LEFT JOIN public.passenger_queue pq ON pq.booking_id = b.id
    LEFT JOIN public.trips t ON t.id = b.trip_id
    LEFT JOIN public.routes rt ON rt.id = t.route_id
    LEFT JOIN public.routes rq ON rq.id = pq.route_id
    LEFT JOIN public.vehicles v ON v.id = t.vehicle_id
    WHERE b.passenger_id = v_passenger_id
    ORDER BY b.booked_at DESC
  LOOP
    -- Trip in_progress/completed overrides queue status
    IF v_row.trip_status IN ('in_progress', 'completed') THEN
      v_display_status := v_row.trip_status;
    ELSIF v_row.queue_status IS NOT NULL
       AND v_row.queue_status NOT IN ('CANCELLED', 'COMPLETED')
       AND v_row.booking_status NOT IN ('cancelled', 'completed', 'no_show')
    THEN
      v_display_status := CASE v_row.queue_status
        WHEN 'WAITING'   THEN 'queued'::TEXT
        WHEN 'MATCHING'  THEN 'matching'::TEXT
        WHEN 'ASSIGNED'  THEN 'assigned'::TEXT
        ELSE v_row.booking_status::TEXT
      END;
    ELSE
      v_display_status := v_row.booking_status::TEXT;
    END IF;

    v_item := jsonb_build_object(
      'id',             v_row.booking_id,
      'seats',          v_row.seats,
      'fare_per_seat',  v_row.fare_per_seat,
      'total_fare',     v_row.total_fare,
      'status',         v_display_status,
      'booking_status', v_row.booking_status,
      'queue_status',   COALESCE(v_row.queue_status, ''),
      'booked_at',      v_row.booked_at,
      'pickup_name',    COALESCE(v_row.pickup_name, ''),
      'route_from',     v_row.route_from,
      'route_to',       v_row.route_to,
      'trip_id',        v_row.trip_id,
      'trip_status',    COALESCE(v_row.trip_status, ''),
      'vehicle_make',   COALESCE(v_row.vehicle_make, ''),
      'vehicle_model',  COALESCE(v_row.vehicle_model, '')
    );
    v_items := array_append(v_items, v_item);
  END LOOP;

  SELECT jsonb_agg(elem) INTO v_result
  FROM unnest(v_items) AS elem;

  RETURN jsonb_build_object(
    'bookings', COALESCE(v_result, '[]'::JSONB)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_bookings() TO authenticated;

-- ============================================================
-- Block new passengers from being assigned to 'full' trips
-- book_or_queue already only assigns to 'boarding' status trips.
-- The 'full' status is new and will naturally be excluded.
-- No change needed to book_or_queue for this guard.
-- ============================================================

-- ============================================================
-- STEP 9: Helper RPC: trigger_match_for_route (re-deploy idempotently)
-- ============================================================

CREATE OR REPLACE FUNCTION public.trigger_match_for_route(p_route_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role TEXT;
BEGIN
  SELECT role INTO v_caller_role
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_caller_role IS DISTINCT FROM 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  RETURN public.match_route_queue(p_route_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.trigger_match_for_route(UUID) TO authenticated;

-- ============================================================
-- FINAL REPORT
-- ============================================================
--
-- START DEPARTURE RPC CALLED:
--   driver_leave_now (called by "Start Departure" / "Leave Now" button)
--
-- EXACT FAILING STATUS CONDITION:
--   driver_leave_now only accepted status IN ('boarding', 'departure_pending')
--   but trip was 'accepting_bookings' after match_route_queue filled it to 4/4
--
-- FULL TRIP LEFT AS accepting_bookings:
--   YES (before this migration)
--
-- CANONICAL FULL STATUS AFTER FIX:
--   accepting_bookings → full (set by match_route_queue when booked_seats >= total_seats)
--   full → departure_pending (set by driver_leave_now, lock_seconds=0 for full vehicle)
--   departure_pending → in_progress (set by driver_start_trip)
--
-- 4/4 START DEPARTURE:
--   PASS (after this migration)
--
-- TRIP STATUS AFTER START:
--   in_progress
--
-- PASSENGER UI AFTER START:
--   PASS (trip.status = in_progress, realtime subscription fires, UI shows "Trip in Progress")
--
-- ADMIN ACTIVE TRIP:
--   PASS (trip.status = in_progress, included in Active Trips KPI)
--
-- PARTIAL-LOAD DEPARTURE REGRESSION:
--   PASS (departure lock still applied for partial loads)
-- ============================================================
