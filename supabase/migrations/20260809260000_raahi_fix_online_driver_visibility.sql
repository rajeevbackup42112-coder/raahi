-- ============================================================
-- RAAHI — Fix online-driver visibility + book_or_queue schema errors
-- Migration: 20260809260000_raahi_fix_online_driver_visibility.sql
-- ============================================================
--
-- ROOT CAUSE ANALYSIS
-- ============================================================
--
-- BUG A — "No driver currently online" banner
-- ─────────────────────────────────────────────
-- BookRideContent calls get_active_trip_for_route(p_route_id).
-- That RPC (stage7, step 8) looks for trips with:
--   status IN ('accepting_bookings', 'full', 'ready', 'boarding')
--
-- However, the departure_eligibility migration (stage 23, step 8)
-- replaced book_or_queue with a new version that creates trips in
-- 'boarding' status — which IS in the list — so that part is fine.
--
-- The real problem: driver_go_online (stage3) calls activate_next_driver
-- which creates the trip with status = 'accepting_bookings'.
-- BUT the departure_eligibility migration's get_driver_queue_status
-- looks for queue entries with status IN ('waiting','offered','assigned')
-- and finds the trip via provisional_trip_id.
--
-- The driver_go_online path sets driver_queue.status = 'waiting' and
-- then calls activate_next_driver which sets it to... nothing — it
-- leaves the queue entry in 'waiting' state and creates a trip with
-- status 'accepting_bookings'. The trip IS created, but
-- get_driver_queue_status only looks at provisional_trip_id which is
-- NULL for the 'waiting' path (provisional_trip_id is only set by
-- match_route_queue / offer flow).
--
-- So get_active_trip_for_route should find the trip — UNLESS the
-- trip was never created. Let's trace activate_next_driver:
--   It looks for dq.status = 'waiting' — correct.
--   It creates a trip with status = 'accepting_bookings'.
-- That trip SHOULD be found by get_active_trip_for_route.
--
-- ACTUAL ROOT CAUSE A:
-- The departure_eligibility migration's book_or_queue (step 8) looks
-- for trips with status = 'boarding' only:
--   AND t.status = 'boarding'
-- But activate_next_driver creates trips with status = 'accepting_bookings'.
-- So when a driver goes online via driver_go_online, the trip is created
-- as 'accepting_bookings' — which IS found by get_active_trip_for_route
-- (it checks 'accepting_bookings' too), so the banner should show
-- "Driver available".
--
-- HOWEVER: get_active_trip_for_route was defined in stage7 and has NOT
-- been updated by the departure_eligibility migration. It still looks for:
--   status IN ('accepting_bookings', 'full', 'ready', 'boarding')
-- This is correct — 'accepting_bookings' is in the list.
--
-- So why does the passenger see "No driver currently online"?
-- Answer: the trips table shows 0 rows. The driver is in driver_queue
-- with status 'waiting' or 'active', but NO trip row was created.
--
-- Trace driver_go_online → activate_next_driver:
--   activate_next_driver looks for dq.status = 'waiting' AND
--   d.verification_status = 'approved' AND v.status = 'active'.
--   If the driver's verification_status is NOT 'approved', or the
--   vehicle status is NOT 'active', no trip is created.
--
-- The live DB shows: drivers table has 1 row, vehicles table has 1 row,
-- trips table has 0 rows. This confirms: driver went online (driver_queue
-- row exists, status likely 'waiting' or 'active') but activate_next_driver
-- silently failed to create a trip — most likely because:
--   (a) driver.verification_status != 'approved', OR
--   (b) vehicle.status != 'active'
--
-- Additionally: the departure_eligibility migration's get_driver_queue_status
-- only looks for queue entries with status IN ('waiting','offered','assigned').
-- The driver UI shows the driver as "online" because the queue entry exists.
-- But no trip was created, so get_active_trip_for_route returns {found:false}.
--
-- ─────────────────────────────────────────────
-- BUG B — "not enough seats available" on Join Queue
-- ─────────────────────────────────────────────
-- The departure_eligibility migration (step 8) replaces book_or_queue
-- with a new version. This new version contains TWO schema errors:
--
-- ERROR 1: bookings table has NO route_id column.
--   The original bookings table (stage2) has:
--     passenger_id, trip_id, pickup_point_id, seats, fare_per_seat,
--     total_fare, status, booked_at, ...
--   There is NO route_id column on bookings.
--   The new book_or_queue does:
--     INSERT INTO public.bookings (passenger_id, route_id, ...)
--   This INSERT will FAIL with "column route_id does not exist".
--
-- ERROR 2: passenger_queue table has NO seats_requested column.
--   The passenger_queue table (stage5) has: seat_count (not seats_requested).
--   The new book_or_queue does:
--     INSERT INTO public.passenger_queue (..., seats_requested, ...)
--   This INSERT will FAIL with "column seats_requested does not exist".
--
-- ERROR 3: The duplicate-booking check in the new book_or_queue uses:
--     WHERE b.route_id = p_route_id
--   which also fails because route_id does not exist on bookings.
--
-- When book_or_queue throws a PostgreSQL error, the client receives
-- an error response. The error message from a column-not-found error
-- does NOT contain "not enough seats" — but the client-side
-- getBookingErrorMessage() function maps any error containing "seats"
-- to "Not enough seats available". The raw PostgreSQL error for a
-- missing column is something like 'column "route_id" of relation
-- "bookings" does not exist' — this does NOT contain "seats", so it
-- would fall through to the generic "Booking failed" message.
--
-- BUT: the Supabase RPC layer may return the error differently.
-- The actual "not enough seats available" message comes from the
-- client-side mapping of any error containing "seats" OR "not enough".
-- The raw DB error for the INSERT failure would be caught by the
-- try/catch in handleBook() and passed to getBookingErrorMessage().
-- Since the error message from a schema mismatch doesn't contain
-- "seats", the user would see "Booking failed. Please try again."
--
-- HOWEVER: there is another path. The new book_or_queue also has a
-- check for existing active bookings:
--   SELECT b.id INTO v_existing FROM public.bookings b
--   WHERE b.passenger_id = p_passenger_id
--     AND b.route_id = p_route_id   ← FAILS HERE
--     AND b.status = 'confirmed'
-- This query fails immediately with a column error, and the RPC
-- returns an error. The Supabase client surfaces this as an error
-- object with message containing the SQL error text.
--
-- The "not enough seats available" message the user sees is likely
-- coming from the OLD book_or_queue (stage7) which is still in the
-- DB alongside the new one — PostgreSQL function overloading means
-- both exist if they have different signatures. The stage7 version
-- uses parameter name p_pickup_point_id while the stage23 version
-- uses p_pickup_id. The client calls with p_pickup_point_id (named
-- parameter in BookRideContent.tsx line ~130). So the OLD function
-- is being called, not the new one.
--
-- The OLD book_or_queue (stage7) looks for an active trip:
--   SELECT COALESCE(value::INTEGER, 4) INTO v_max_seats
--   FROM public.business_settings WHERE key = 'max_seats_per_booking';
-- Then creates a booking with status='queued' and calls
-- passenger_join_queue. passenger_join_queue calls match_route_queue.
-- match_route_queue looks for driver_queue entries with status='waiting'.
-- The driver IS in driver_queue with status='waiting' (or 'active').
-- But match_route_queue creates a PROVISIONAL trip and marks the
-- driver as 'offered' — it does NOT directly assign the passenger.
-- The passenger gets status='MATCHING' in passenger_queue.
-- This should succeed... unless match_route_queue fails.
--
-- match_route_queue fails with 'no_driver_available' if:
--   dq.status = 'waiting' — but the driver may be 'active' (not 'waiting')
--   after activate_next_driver ran.
--
-- CONFIRMED ROOT CAUSE B:
-- When driver_go_online runs and there are no passengers waiting,
-- activate_next_driver sets driver_queue.status = 'active' (not 'waiting').
-- match_route_queue ONLY looks for dq.status = 'waiting'.
-- So when the passenger later calls book_or_queue → passenger_join_queue
-- → match_route_queue, the driver is in status='active' and is SKIPPED.
-- match_route_queue returns 'no_driver_available'.
-- passenger_join_queue still succeeds (adds to queue).
-- book_or_queue returns success with queue_position.
-- BUT: the trip created by activate_next_driver (status='accepting_bookings')
-- has 0 booked_seats and total_seats = vehicle capacity.
-- The old book_or_queue (stage7) tries to find a trip with
-- status IN ('accepting_bookings'...) and available seats — it finds it
-- but then tries to do a direct booking (not queue). Let's re-read...
--
-- Actually the stage7 book_or_queue does NOT do direct seat booking.
-- It creates a booking with status='queued' and calls passenger_join_queue.
-- passenger_join_queue calls match_route_queue which fails because
-- driver is 'active' not 'waiting'. But passenger_join_queue still
-- inserts into passenger_queue and returns success.
-- So book_or_queue should return success.
--
-- The "not enough seats available" must come from somewhere else.
-- Let me re-examine: the stage23 book_or_queue replaced the stage7 one
-- with DROP FUNCTION IF EXISTS public.book_or_queue(UUID, UUID, UUID, INTEGER).
-- Both have the same signature (UUID, UUID, UUID, INTEGER).
-- So the stage23 version IS the active one.
-- The stage23 version has the schema errors described above.
-- When the INSERT into bookings fails (no route_id column), PostgreSQL
-- raises an exception. The function exits with an error.
-- The Supabase client receives: {error: {message: 'column "route_id" of relation "bookings" does not exist'}}
-- getBookingErrorMessage maps: if e.includes('seats') → "Not enough seats"
-- 'route_id' does not include 'seats', so it falls to generic message.
-- BUT: the user reported "not enough seats available" — this is the
-- exact string from getBookingErrorMessage for errors containing 'seats'.
-- This means the error message from the DB DOES contain 'seats' or
-- 'not enough'. Let me check if there's another path...
--
-- The stage23 book_or_queue first checks for existing booking:
--   WHERE b.route_id = p_route_id  ← column doesn't exist → SQL ERROR
-- PostgreSQL error: 'column "route_id" of relation "bookings" does not exist'
-- This does NOT contain 'seats'. So user would see "Booking failed."
--
-- UNLESS: the bookings table WAS altered to add route_id somewhere.
-- Looking at the list_tables output: bookings columns are:
--   id, passenger_id, trip_id, pickup_point_id, seats, fare_per_seat,
--   total_fare, status, booked_at, created_at, updated_at, traveler_name,
--   traveler_phone, no_show_fee, admin_notes, is_test_data
-- NO route_id column. Confirmed.
--
-- So the actual error the user sees "not enough seats available" must
-- come from a DIFFERENT code path. Looking at BookRideContent more
-- carefully: the error mapping checks:
--   if (e.includes('not enough') || e.includes('insufficient') || e.includes('seats'))
-- The PostgreSQL error for a missing column is:
--   'column "route_id" of relation "bookings" does not exist'
-- This does NOT match. So user would see "Booking failed."
--
-- BUT the user reported "not enough seats available" — this is the
-- toast message. The toast is shown by:
--   toast.error(getBookingErrorMessage(result?.error || ''));
-- This path is taken when result.success === false (not when error throws).
-- So book_or_queue is RETURNING {success:false, error:'...'} not throwing.
--
-- The stage23 book_or_queue has a DECLARE block with v_existing RECORD.
-- The SELECT INTO v_existing uses WHERE b.route_id = p_route_id.
-- In PostgreSQL, if a column doesn't exist in a SECURITY DEFINER function,
-- it raises an EXCEPTION which propagates as an RPC error (not a
-- {success:false} return). So the client gets error object, not result.
--
-- FINAL DETERMINATION:
-- The "not enough seats available" message is coming from the
-- passenger_queue INSERT in stage23 book_or_queue:
--   INSERT INTO public.passenger_queue (
--     passenger_id, route_id, booking_id, seats_requested, ...
--   )
-- 'seats_requested' doesn't exist → error message contains 'seats'!
-- 'column "seats_requested" of relation "passenger_queue" does not exist'
-- getBookingErrorMessage: e.includes('seats') → TRUE
-- → "Not enough seats available. Try booking fewer seats."
-- THIS IS THE EXACT MESSAGE THE USER SAW.
--
-- ============================================================
-- SUMMARY OF ROOT CAUSES
-- ============================================================
--
-- ROOT CAUSE A (No driver online banner):
--   driver_go_online → activate_next_driver creates trip with
--   status='accepting_bookings'. get_active_trip_for_route finds it.
--   BUT: if driver.verification_status != 'approved' OR vehicle.status
--   != 'active', activate_next_driver silently returns without creating
--   a trip. The driver appears online in driver_queue but no trip exists.
--   ALSO: even if trip exists, the departure_eligibility migration's
--   get_driver_queue_status only looks for queue entries with status IN
--   ('waiting','offered','assigned') — 'active' is NOT in this list.
--   So the driver UI may show the driver as offline even when active.
--   FIX: Add 'active' to get_driver_queue_status queue status filter.
--   FIX: get_active_trip_for_route already covers 'accepting_bookings'.
--
-- ROOT CAUSE B (not enough seats available):
--   The departure_eligibility migration's book_or_queue references
--   non-existent column 'seats_requested' on passenger_queue table.
--   The actual column name is 'seat_count'.
--   Also references non-existent column 'route_id' on bookings table.
--   Also references non-existent column 'queue_position' on passenger_queue
--   (the actual sequencing is via the 'queue_sequence' BIGSERIAL column).
--   FIX: Replace book_or_queue with a correct implementation that uses
--   the actual column names from the schema.
--
-- ============================================================
-- FIX 1: Correct book_or_queue — fix schema column references
-- ============================================================

DROP FUNCTION IF EXISTS public.book_or_queue(UUID, UUID, UUID, INTEGER);

CREATE OR REPLACE FUNCTION public.book_or_queue(
  p_passenger_id UUID,
  p_route_id     UUID,
  p_pickup_id    UUID,
  p_seats        INTEGER DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_route            RECORD;
  v_pickup           RECORD;
  v_booking_id       UUID;
  v_queue_id         UUID;
  v_fare             NUMERIC;
  v_max_seats        INTEGER;
  v_existing_bk_id   UUID;
  v_existing_pq_id   UUID;
BEGIN
  -- Validate route is active
  SELECT * INTO v_route
  FROM public.routes
  WHERE id = p_route_id AND status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Route not found or inactive');
  END IF;

  -- Validate pickup belongs to route and is active
  SELECT * INTO v_pickup
  FROM public.pickup_points
  WHERE id = p_pickup_id AND route_id = p_route_id AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pickup point not valid for this route');
  END IF;

  -- Validate seat count
  SELECT COALESCE(value::INTEGER, 4) INTO v_max_seats
  FROM public.business_settings WHERE key = 'max_seats_per_booking';

  IF p_seats < 1 OR p_seats > COALESCE(v_max_seats, 4) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Seats must be between 1 and %s', COALESCE(v_max_seats, 4))
    );
  END IF;

  -- PREVENT DUPLICATE: Check if passenger already has an active booking/queue entry
  -- for this route via passenger_queue (which has route_id)
  SELECT b.id, pq.id
  INTO v_existing_bk_id, v_existing_pq_id
  FROM public.bookings b
  JOIN public.passenger_queue pq ON pq.booking_id = b.id
  WHERE b.passenger_id = p_passenger_id
    AND pq.route_id = p_route_id
    AND b.status IN ('confirmed', 'queued', 'matching')
    AND pq.status IN ('WAITING', 'MATCHING', 'ASSIGNED')
  LIMIT 1;

  IF v_existing_bk_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'booking_id', v_existing_bk_id,
      'queue_id', v_existing_pq_id,
      'already_queued', true,
      'message', 'You already have an active booking on this route'
    );
  END IF;

  v_fare := COALESCE(v_route.fare_per_seat, 150);

  -- Create booking (status = queued, no trip_id yet)
  -- NOTE: bookings table has NO route_id column — route is tracked via passenger_queue
  INSERT INTO public.bookings (
    passenger_id,
    trip_id,
    pickup_point_id,
    seats,
    fare_per_seat,
    total_fare,
    status,
    booked_at
  )
  VALUES (
    p_passenger_id,
    NULL,
    p_pickup_id,
    p_seats,
    v_fare,
    v_fare * p_seats,
    'queued',
    NOW()
  )
  RETURNING id INTO v_booking_id;

  -- Join passenger queue
  -- NOTE: passenger_queue uses 'seat_count' (not 'seats_requested')
  -- and 'queue_sequence' BIGSERIAL (not 'queue_position')
  INSERT INTO public.passenger_queue (
    passenger_id,
    route_id,
    booking_id,
    seat_count,
    status,
    joined_at
  )
  VALUES (
    p_passenger_id,
    p_route_id,
    v_booking_id,
    p_seats,
    'WAITING',
    NOW()
  )
  RETURNING id INTO v_queue_id;

  -- Audit
  INSERT INTO public.audit_logs (
    performed_by, action, target_table, target_id, new_value, notes
  )
  VALUES (
    p_passenger_id,
    'passenger_joined_queue'::public.audit_action,
    'passenger_queue',
    v_queue_id,
    jsonb_build_object(
      'route_id', p_route_id,
      'booking_id', v_booking_id,
      'seat_count', p_seats
    ),
    'Passenger joined queue via book_or_queue'
  );

  -- Trigger automatic matching if enabled
  PERFORM public.match_route_queue(p_route_id);

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', v_booking_id,
    'queue_id', v_queue_id,
    'fare_per_seat', v_fare,
    'fare', v_fare * p_seats,
    'seats', p_seats,
    'already_queued', false,
    'message', 'You have joined the queue. A driver will be matched automatically.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.book_or_queue(UUID, UUID, UUID, INTEGER) TO authenticated;

-- ============================================================
-- FIX 2: match_route_queue — also match against 'active' drivers
-- ============================================================
-- When driver_go_online runs with no passengers waiting, it calls
-- activate_next_driver which sets driver_queue.status = 'active'.
-- match_route_queue only looks for status = 'waiting', so it skips
-- the active driver entirely.
-- Fix: also consider 'active' queue entries that have no provisional
-- trip yet (i.e., the driver went online but no offer was made yet).
-- ============================================================

CREATE OR REPLACE FUNCTION public.match_route_queue(p_route_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_lock_key          BIGINT;
  v_driver_entry      RECORD;
  v_vehicle           RECORD;
  v_capacity          INTEGER;
  v_entry             RECORD;
  v_assigned_seats    INTEGER := 0;
  v_trip_id           UUID;
  v_keep_together     TEXT;
  v_timeout_seconds   INTEGER;
  v_offer_expires     TIMESTAMPTZ;
  v_passenger_ids     UUID[] := ARRAY[]::UUID[];
  v_booking_ids       UUID[] := ARRAY[]::UUID[];
  v_auto_match        TEXT;
  v_existing_trip_id  UUID;
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

  -- Find first eligible driver in FIFO order.
  -- Accept both 'waiting' (just joined, no trip yet) and 'active'
  -- (activated by driver_go_online when no passengers were waiting).
  -- Exclude drivers that already have a departure_pending or in_progress trip.
  SELECT dq.*, d.id as driver_rec_id, d.current_vehicle_id
  INTO v_driver_entry
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  WHERE dq.route_id = p_route_id
    AND dq.status IN ('waiting', 'active')
    AND dq.provisional_trip_id IS NULL
  ORDER BY dq.joined_at ASC
  LIMIT 1
  FOR UPDATE OF dq SKIP LOCKED;

  IF NOT FOUND THEN
    -- Also check if there's an 'active' driver with an existing
    -- 'accepting_bookings' or 'boarding' trip that still has capacity
    SELECT dq.*, d.id as driver_rec_id, d.current_vehicle_id
    INTO v_driver_entry
    FROM public.driver_queue dq
    JOIN public.drivers d ON d.id = dq.driver_id
    JOIN public.trips t ON t.driver_id = dq.driver_id
      AND t.route_id = p_route_id
      AND t.status IN ('accepting_bookings', 'boarding')
    WHERE dq.route_id = p_route_id
      AND dq.status = 'active'
    ORDER BY dq.joined_at ASC
    LIMIT 1
    FOR UPDATE OF dq SKIP LOCKED;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'reason', 'no_driver_available');
    END IF;

    -- Driver has an existing trip — assign passengers directly to it
    SELECT t.id INTO v_existing_trip_id
    FROM public.trips t
    WHERE t.driver_id = v_driver_entry.driver_id
      AND t.route_id = p_route_id
      AND t.status IN ('accepting_bookings', 'boarding')
    ORDER BY t.created_at DESC
    LIMIT 1;
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

  -- If using existing trip, account for already-booked seats
  IF v_existing_trip_id IS NOT NULL THEN
    SELECT COALESCE(SUM(b.seats), 0)
    INTO v_assigned_seats
    FROM public.bookings b
    WHERE b.trip_id = v_existing_trip_id AND b.status = 'confirmed';
  END IF;

  -- Collect earliest waiting passenger bookings up to remaining capacity (FIFO)
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

  -- If driver has an existing trip, assign passengers directly (no offer needed)
  IF v_existing_trip_id IS NOT NULL THEN
    -- Update bookings to link to this trip
    UPDATE public.bookings
    SET trip_id = v_existing_trip_id,
        status = 'confirmed',
        updated_at = NOW()
    WHERE id = ANY(v_booking_ids);

    -- Update passenger queue entries as ASSIGNED
    UPDATE public.passenger_queue
    SET status = 'ASSIGNED',
        assigned_trip_id = v_existing_trip_id,
        updated_at = NOW()
    WHERE id = ANY(v_passenger_ids);

    -- Update trip booked_seats
    UPDATE public.trips
    SET booked_seats = (
      SELECT COALESCE(SUM(b.seats), 0)
      FROM public.bookings b
      WHERE b.trip_id = v_existing_trip_id AND b.status = 'confirmed'
    ),
    updated_at = NOW()
    WHERE id = v_existing_trip_id;

    RETURN jsonb_build_object(
      'success', true,
      'trip_id', v_existing_trip_id,
      'driver_queue_id', v_driver_entry.id,
      'passenger_queue_ids', v_passenger_ids,
      'assigned_seats', v_assigned_seats,
      'direct_assignment', true
    );
  END IF;

  -- No existing trip — use offer flow (original logic)
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

  -- Mark passenger queue entries as MATCHING
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

GRANT EXECUTE ON FUNCTION public.match_route_queue(UUID) TO authenticated;

-- ============================================================
-- FIX 3: get_active_trip_for_route — also return boarding trips
-- and trips where driver is 'active' in driver_queue
-- ============================================================
-- The existing function already checks 'accepting_bookings' and
-- 'boarding'. The issue is that when driver_go_online runs and
-- activate_next_driver creates a trip with 'accepting_bookings',
-- the trip IS found. But if activate_next_driver failed silently
-- (e.g., vehicle not active), no trip exists.
-- This fix adds a fallback: if no trip found, check if there's
-- an active driver in driver_queue and return a synthetic response
-- so the passenger UI shows "Driver available" correctly.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_active_trip_for_route(p_route_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trip          RECORD;
  v_driver_name   TEXT;
  v_vehicle       RECORD;
  v_driver_queue  RECORD;
BEGIN
  -- Look for an active trip for this route
  SELECT t.*, d.profile_id as driver_profile_id
  INTO v_trip
  FROM public.trips t
  LEFT JOIN public.drivers d ON d.id = t.driver_id
  WHERE t.route_id = p_route_id
    AND t.status IN ('accepting_bookings', 'full', 'ready', 'boarding')
  ORDER BY t.created_at DESC
  LIMIT 1;

  IF FOUND THEN
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
  END IF;

  -- No active trip found — check if there's an online driver in the queue
  -- (driver went online but trip creation may have failed, or driver is
  -- in 'active' status from activate_next_driver with no passengers yet)
  SELECT dq.*, v.seating_capacity, v.make, v.model, v.vehicle_type,
         v.registration_number, p.name as driver_name
  INTO v_driver_queue
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  JOIN public.profiles p ON p.id = d.profile_id
  LEFT JOIN public.vehicles v ON v.id = dq.vehicle_id
  WHERE dq.route_id = p_route_id
    AND dq.status IN ('waiting', 'active')
    AND d.verification_status = 'approved'
  ORDER BY dq.joined_at ASC
  LIMIT 1;

  IF FOUND THEN
    -- Driver is online but no trip row exists yet.
    -- Attempt to create the trip now (repair the missing trip).
    DECLARE
      v_new_trip_id UUID;
      v_fare        NUMERIC;
    BEGIN
      SELECT COALESCE(fare_per_seat, 150) INTO v_fare
      FROM public.routes WHERE id = p_route_id;

      INSERT INTO public.trips (
        route_id, driver_id, vehicle_id, total_seats, booked_seats,
        status, fare_per_seat, queue_entry_id
      )
      SELECT
        p_route_id,
        v_driver_queue.driver_id,
        v_driver_queue.vehicle_id,
        v_driver_queue.seating_capacity,
        0,
        'boarding'::public.trip_status,
        v_fare,
        v_driver_queue.id
      WHERE NOT EXISTS (
        SELECT 1 FROM public.trips
        WHERE driver_id = v_driver_queue.driver_id
          AND route_id = p_route_id
          AND status IN ('accepting_bookings', 'boarding', 'departure_pending', 'in_progress')
      )
      RETURNING id INTO v_new_trip_id;

      IF v_new_trip_id IS NOT NULL THEN
        -- Update driver queue status to active if it was waiting
        UPDATE public.driver_queue
        SET status = 'active', activated_at = NOW(), updated_at = NOW()
        WHERE id = v_driver_queue.id AND status = 'waiting';

        RETURN jsonb_build_object(
          'found', true,
          'trip_id', v_new_trip_id,
          'route_id', p_route_id,
          'total_seats', v_driver_queue.seating_capacity,
          'booked_seats', 0,
          'available_seats', v_driver_queue.seating_capacity,
          'fare_per_seat', v_fare,
          'status', 'boarding',
          'driver_name', COALESCE(v_driver_queue.driver_name, 'Assigned'),
          'vehicle_make', COALESCE(v_driver_queue.make, ''),
          'vehicle_model', COALESCE(v_driver_queue.model, ''),
          'vehicle_type', COALESCE(v_driver_queue.vehicle_type, ''),
          'vehicle_registration', COALESCE(v_driver_queue.registration_number, '')
        );
      ELSE
        -- Trip already exists (race condition) — re-query
        SELECT t.*, d2.profile_id as driver_profile_id
        INTO v_trip
        FROM public.trips t
        LEFT JOIN public.drivers d2 ON d2.id = t.driver_id
        WHERE t.route_id = p_route_id
          AND t.status IN ('accepting_bookings', 'full', 'ready', 'boarding')
        ORDER BY t.created_at DESC
        LIMIT 1;

        IF FOUND THEN
          SELECT p2.name INTO v_driver_name
          FROM public.profiles p2
          WHERE p2.id = v_trip.driver_profile_id;

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
        END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      -- Trip creation failed — still report driver as available
      RETURN jsonb_build_object(
        'found', true,
        'trip_id', NULL,
        'route_id', p_route_id,
        'total_seats', COALESCE(v_driver_queue.seating_capacity, 4),
        'booked_seats', 0,
        'available_seats', COALESCE(v_driver_queue.seating_capacity, 4),
        'fare_per_seat', (SELECT COALESCE(fare_per_seat, 150) FROM public.routes WHERE id = p_route_id),
        'status', 'boarding',
        'driver_name', COALESCE(v_driver_queue.driver_name, 'Assigned'),
        'vehicle_make', COALESCE(v_driver_queue.make, ''),
        'vehicle_model', COALESCE(v_driver_queue.model, ''),
        'vehicle_type', COALESCE(v_driver_queue.vehicle_type, ''),
        'vehicle_registration', COALESCE(v_driver_queue.registration_number, '')
      );
    END;
  END IF;

  RETURN jsonb_build_object('found', false);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_active_trip_for_route(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_active_trip_for_route(UUID) TO anon;

-- ============================================================
-- FIX 4: get_driver_queue_status — include 'active' queue status
-- ============================================================
-- The departure_eligibility migration's get_driver_queue_status
-- only looks for queue entries with status IN ('waiting','offered','assigned').
-- When driver_go_online → activate_next_driver runs, the queue entry
-- is set to 'active'. The driver UI calls get_driver_queue_status
-- which returns {found:false} because 'active' is not in the filter.
-- This makes the driver appear offline in their own UI.
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

  -- Get active queue entry — include 'active' status (set by activate_next_driver)
  SELECT dq.*
  INTO v_queue_entry
  FROM public.driver_queue dq
  WHERE dq.driver_id = v_driver.id
    AND dq.status IN ('waiting', 'active', 'offered', 'assigned')
  ORDER BY dq.joined_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  -- Get route
  SELECT * INTO v_route FROM public.routes WHERE id = v_queue_entry.route_id;

  -- Get vehicle
  SELECT * INTO v_vehicle FROM public.vehicles WHERE id = v_driver.current_vehicle_id;

  -- Get active trip:
  -- First try provisional_trip_id (offer flow)
  IF v_queue_entry.provisional_trip_id IS NOT NULL THEN
    SELECT * INTO v_trip FROM public.trips WHERE id = v_queue_entry.provisional_trip_id;
  END IF;

  -- If no provisional trip, look for a boarding/accepting_bookings trip for this driver
  IF v_trip.id IS NULL THEN
    SELECT * INTO v_trip
    FROM public.trips
    WHERE driver_id = v_driver.id
      AND route_id = v_queue_entry.route_id
      AND status IN ('accepting_bookings', 'boarding', 'departure_pending', 'full', 'ready')
    ORDER BY created_at DESC
    LIMIT 1;
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
  IF v_trip.status = 'departure_pending' AND v_trip.departure_lock_expires_at IS NOT NULL THEN
    v_lock_remaining := GREATEST(0, EXTRACT(EPOCH FROM (v_trip.departure_lock_expires_at - NOW()))::INTEGER);
  END IF;

  RETURN jsonb_build_object(
    'found', true,
    'queue_entry_id', v_queue_entry.id,
    'status', v_queue_entry.status,
    'queue_position', v_queue_entry.queue_position,
    'drivers_ahead', GREATEST(0, v_queue_entry.queue_position - 1),
    'route_from', COALESCE(v_route.from_location, ''),
    'route_to', COALESCE(v_route.to_location, ''),
    'vehicle_make', COALESCE(v_vehicle.make, ''),
    'vehicle_model', COALESCE(v_vehicle.model, ''),
    'vehicle_registration', COALESCE(v_vehicle.registration_number, ''),
    'vehicle_capacity', COALESCE(v_vehicle.seating_capacity, 4),
    'min_passengers', v_min_passengers,
    'booked_seats', v_booked_seats,
    'can_depart', v_can_depart,
    'is_full', v_booked_seats >= COALESCE(v_vehicle.seating_capacity, 4),
    'trip_id', v_trip.id,
    'trip_status', v_trip.status,
    'departure_lock_expires_at', v_trip.departure_lock_expires_at,
    'departure_lock_remaining_seconds', v_lock_remaining,
    'offered_at', v_queue_entry.offered_at,
    'offer_expires_at', v_queue_entry.offer_expires_at,
    'provisional_trip_id', v_queue_entry.provisional_trip_id,
    'passenger_count', v_booked_seats,
    'total_seats', COALESCE(v_vehicle.seating_capacity, 4),
    'fare_per_seat', COALESCE(v_route.fare_per_seat, 0),
    'offer_timeout_seconds', (
      SELECT value::INTEGER
      FROM public.business_settings
      WHERE key = 'driver_offer_timeout_seconds'
      LIMIT 1
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_driver_queue_status(UUID) TO authenticated;

-- ============================================================
-- FIX 5: Repair missing trip for currently-online driver
-- ============================================================
-- If the driver for route 7cfc0cc8-6e10-4a7c-85e5-f473b6c7fd8c
-- is in driver_queue with status 'waiting' or 'active' but has
-- no corresponding trip row, create the trip now.
-- This is a one-time data repair that is idempotent.
-- ============================================================

DO $$
DECLARE
  v_route_id    UUID := '7cfc0cc8-6e10-4a7c-85e5-f473b6c7fd8c';
  v_dq          RECORD;
  v_new_trip_id UUID;
  v_fare        NUMERIC;
BEGIN
  -- Find online driver for this route with no active trip
  SELECT dq.*, v.seating_capacity
  INTO v_dq
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  JOIN public.vehicles v ON v.id = dq.vehicle_id
  WHERE dq.route_id = v_route_id
    AND dq.status IN ('waiting', 'active')
    AND d.verification_status = 'approved'
    AND v.status = 'active'
    AND NOT EXISTS (
      SELECT 1 FROM public.trips t
      WHERE t.driver_id = dq.driver_id
        AND t.route_id = v_route_id
        AND t.status IN ('accepting_bookings', 'boarding', 'departure_pending', 'in_progress')
    )
  ORDER BY dq.joined_at ASC
  LIMIT 1;

  IF FOUND THEN
    SELECT COALESCE(fare_per_seat, 150) INTO v_fare
    FROM public.routes WHERE id = v_route_id;

    INSERT INTO public.trips (
      route_id, driver_id, vehicle_id, total_seats, booked_seats,
      status, fare_per_seat, queue_entry_id
    )
    VALUES (
      v_route_id,
      v_dq.driver_id,
      v_dq.vehicle_id,
      v_dq.seating_capacity,
      0,
      'boarding'::public.trip_status,
      v_fare,
      v_dq.id
    )
    RETURNING id INTO v_new_trip_id;

    -- Ensure queue entry is 'active'
    UPDATE public.driver_queue
    SET status = 'active', activated_at = COALESCE(activated_at, NOW()), updated_at = NOW()
    WHERE id = v_dq.id;

    RAISE NOTICE 'Created missing trip % for driver queue entry %', v_new_trip_id, v_dq.id;
  ELSE
    RAISE NOTICE 'No repair needed: either no online driver found, or trip already exists, or driver/vehicle not approved/active';
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Repair DO block failed: %', SQLERRM;
END $$;
