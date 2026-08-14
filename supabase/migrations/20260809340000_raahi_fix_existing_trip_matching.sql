-- ============================================================
-- RAAHI — Fix match_route_queue: existing-trip fill branch
-- Migration: 20260809340000_raahi_fix_existing_trip_matching.sql
-- ============================================================
--
-- ROOT CAUSE (confirmed from production DB snapshot):
--
--   Active trip:   d78924d7-fae0-42f3-a503-af26ecd34925
--   status:        accepting_bookings
--   booked_seats:  1 / total_seats: 4
--
--   Driver queue:  b474a0ef-c22f-4018-870c-d6e251cbcc87
--   status:        assigned          ← KEY ISSUE
--   provisional_trip_id: (above trip)
--
--   Passenger queue:
--     f46d84cc  status: WAITING  assigned_trip_id: NULL
--     8a9501d7  status: WAITING  assigned_trip_id: NULL
--
-- The deployed match_route_queue (migration 200000) searches for:
--
--   dq.status = 'waiting'
--
-- Once a driver accepts an offer, driver_queue.status becomes 'assigned'.
-- The matcher never finds this driver, returns 'no_driver_available',
-- and WAITING passengers are never filled into the existing trip.
--
-- The function also has no branch that looks for an already-active
-- accepting_bookings/boarding trip — it always tries to create a new
-- provisional offer.
--
-- FIX:
--   Add an EXISTING-TRIP FILL branch at the top of match_route_queue.
--
--   Branch 1 — Existing accepting trip:
--     Find trips WHERE status IN ('accepting_bookings', 'boarding')
--     AND booked_seats < total_seats
--     AND driver/vehicle are valid.
--     If found: assign WAITING passengers FIFO directly into that trip.
--     Update booking.trip_id, booking.status = confirmed,
--     passenger_queue.status = ASSIGNED, assigned_trip_id = trip.id.
--     Recalculate trip.booked_seats from confirmed bookings.
--     DO NOT create another trip or driver offer.
--
--   Branch 2 — New driver offer (unchanged):
--     Only runs when no eligible accepting trip exists.
--     Searches for dq.status = 'waiting' drivers as before.
--
-- TRIGGER VERIFICATION:
--   book_or_queue (migration 280000) already calls:
--     PERFORM public.match_route_queue(p_route_id);
--   after every passenger joins. Trigger is in place.
--
-- DEPARTURE PROTECTION:
--   Passengers are NOT assigned into trips with status:
--     departure_pending, in_progress, completed, cancelled, full
--
-- DRIVER UI:
--   get_driver_queue_status already reads trip.booked_seats live.
--   DriverHomeContent.tsx has a realtime subscription on trips +
--   passenger_queue tables that calls loadDriverState() on any change.
--   After this fix, when passengers are assigned the realtime event
--   fires and the driver UI updates to 3/4 without manual refresh.
--
-- ADMIN:
--   get_admin_bookings resolves route via passenger_queue.route_id
--   for queued bookings and trips.route_id for confirmed bookings.
--   After fix, bookings.status = 'confirmed' and bookings.trip_id is
--   populated, so Admin Bookings shows confirmed with driver/vehicle.
--
-- REGRESSION SAFETY:
--   A. existing accepting trip 1/4 + two 1-seat WAITING -> 3/4
--   B. existing accepting trip 3/4 + two 1-seat WAITING -> 4/4, second waits
--   C. fit-aware multi-seat preserved in existing-trip branch
--   D. departure_pending -> no new passengers assigned
--   E. driver chooses Wait for More -> trip re-enters accepting_bookings,
--      match_route_queue is called again
--   F. no existing active trip -> normal driver offer flow unchanged
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
  -- BRANCH 1: Fill existing accepting_bookings / boarding trip
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
        UPDATE public.trips
        SET
          booked_seats = (
            SELECT COALESCE(SUM(b.seats), 0)
            FROM public.bookings b
            WHERE b.trip_id = v_existing_trip_id
              AND b.status = 'confirmed'
          ),
          updated_at = NOW()
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
            'trip_id',   v_existing_trip_id,
            'route_id',  p_route_id,
            'booking_id', pq.booking_id,
            'branch',    'existing_trip_fill'
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
      'assigned_seats',      v_fill_seats
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
-- Update driver_wait_for_more (single-param, existing UI signature)
-- to also retrigger matching after re-entering accepting_bookings.
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

  -- Find the most recent departure_pending, boarding, or accepting_bookings trip
  SELECT id, route_id INTO v_trip_id, v_route_id
  FROM public.trips
  WHERE driver_id = v_driver_id
    AND status IN ('departure_pending', 'boarding', 'accepting_bookings')
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
-- Helper RPC: trigger_match_for_route
-- Allows admin to manually retrigger matching for a route.
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
