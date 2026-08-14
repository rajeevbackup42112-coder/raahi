-- ============================================================
-- RAAHI — match_route_queue ENUM CAST FIX
-- Migration: 20260811120000_raahi_match_route_queue_enum_cast_fix.sql
-- ============================================================
--
-- ROOT CAUSE (CONFIRMED):
--   ERROR 42804: column "status" is of type trip_status but
--   expression is of type text
--
--   Failing SQL in match_route_queue (migration 20260811070000):
--
--     UPDATE public.trips
--     SET status = CASE
--       WHEN booked_seats >= total_seats THEN 'full'
--       ELSE 'accepting_bookings'
--     END,
--     updated_at = NOW()
--     WHERE id = v_trip_id;
--
--   PostgreSQL infers the CASE result type as TEXT because both
--   branch literals are untyped string constants. The trips.status
--   column is public.trip_status (an ENUM). PostgreSQL cannot
--   implicitly cast TEXT → ENUM in an UPDATE SET expression,
--   so it raises ERROR 42804.
--
--   Note: direct string literal assignments such as
--     SET status = 'accepting_bookings'
--   work fine because PostgreSQL resolves the literal against the
--   target column type at parse time. Only CASE expressions (and
--   other expression contexts) require explicit casts.
--
-- ENUM CAST FIX:
--   Add ::public.trip_status to both CASE branches:
--
--     UPDATE public.trips
--     SET status = CASE
--       WHEN booked_seats >= total_seats
--         THEN 'full'::public.trip_status
--       ELSE 'accepting_bookings'::public.trip_status
--     END,
--     updated_at = NOW()
--     WHERE id = v_trip_id;
--
-- OTHER ENUM ISSUES FOUND IN CURRENT match_route_queue BODY:
--   Audited all assignments and comparisons in the function body
--   (migration 20260811070000 version):
--
--   1. INSERT trips ... VALUES (..., 'accepting_bookings', ...)
--      → Direct string literal in VALUES; PostgreSQL resolves
--        against column type at parse time. No cast needed.
--        Added explicit cast for clarity and safety.
--
--   2. UPDATE driver_queue SET status = 'offered'
--      → Direct string literal; PostgreSQL resolves against
--        queue_status enum. Works without cast.
--        Added explicit cast for clarity and safety.
--
--   3. UPDATE passenger_queue SET status = 'MATCHING'
--      → passenger_queue.status is TEXT (not an enum).
--        No cast needed or applicable.
--
--   4. UPDATE bookings SET status = 'confirmed'
--      → Direct string literal; PostgreSQL resolves against
--        booking_status enum. Works without cast.
--        Added explicit cast for clarity and safety.
--
-- FIFO SEMANTICS: UNCHANGED
-- BOOKING LOGIC: UNCHANGED
-- FARE LOGIC: UNCHANGED
-- NO-SHOW LOGIC: UNCHANGED
-- ABUSE CONTROLS: UNCHANGED
-- DRIVER QUEUE ORDERING: UNCHANGED
-- TEST/LIVE ISOLATION: UNCHANGED (is_test_data guard preserved)
-- ROUTE LOGIC: UNCHANGED
-- DEPARTURE LOGIC: UNCHANGED
-- ADMIN CONTROLS: UNCHANGED
--
-- STATIC MATCH VERIFICATION (scenario from user):
--   Rajeev Backup4: queue #1, 4-seat Maruti Dzire, waiting, online
--   Dipti: queue #2, waiting
--   Passengers: rajeev.backup1 (1 seat), Naresh (2 seats),
--               rajeev.backup3 (1 seat) — total 4 seats WAITING
--
--   Expected result from match_route_queue:
--   - matched = true
--   - Rajeev selected (FIFO #1, joined_at earliest)
--   - 3 passenger bookings assigned (1+2+1 = 4 seats = capacity)
--   - trip booked_seats = 4 = total_seats
--   - CASE: booked_seats(4) >= total_seats(4) → 'full'::public.trip_status ✓
--   - trip status = full ✓
--   - Dipti remains waiting #2 (driver_queue untouched) ✓
--
-- FILES CHANGED:
--   supabase/migrations/20260811120000_raahi_match_route_queue_enum_cast_fix.sql
-- ============================================================

-- ============================================================
-- REDEPLOY match_route_queue WITH EXPLICIT ENUM-SAFE CASTS
--
-- This is a complete CREATE OR REPLACE of the function as it
-- exists in migration 20260811070000, with the following changes:
--
--   CHANGE 1 (BUG FIX — required):
--     CASE expression in UPDATE trips SET status:
--     'full' → 'full'::public.trip_status
--     'accepting_bookings' → 'accepting_bookings'::public.trip_status
--
--   CHANGE 2 (defensive cast — belt-and-suspenders):
--     INSERT trips VALUES: 'accepting_bookings' →
--     'accepting_bookings'::public.trip_status
--
--   CHANGE 3 (defensive cast — belt-and-suspenders):
--     UPDATE driver_queue SET status = 'offered' →
--     'offered'::public.queue_status
--
--   CHANGE 4 (defensive cast — belt-and-suspenders):
--     UPDATE bookings SET status = 'confirmed' →
--     'confirmed'::public.booking_status
--
-- All other logic is IDENTICAL to migration 20260811070000.
-- FIFO, test/live isolation, passenger assignment, audit log
-- are all preserved exactly.
-- ============================================================

CREATE OR REPLACE FUNCTION public.match_route_queue(p_route_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver         RECORD;
  v_trip_id        UUID;
  v_assigned       INTEGER := 0;
  v_seats_left     INTEGER;
  v_pq             RECORD;
  v_booking_id     UUID;
  v_result         JSONB;
  v_is_test_driver BOOLEAN;
BEGIN
  -- Lock the first eligible driver in queue (FIFO)
  SELECT dq.*, d.profile_id AS driver_profile_id, d.is_test_data AS driver_is_test
  INTO v_driver
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  JOIN public.vehicles v ON v.id = dq.vehicle_id
  WHERE dq.route_id = p_route_id
    AND dq.status = 'waiting'
  ORDER BY dq.joined_at
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('matched', false, 'reason', 'no_driver_available');
  END IF;

  v_is_test_driver := COALESCE(v_driver.driver_is_test, false);

  -- Count waiting passengers (test isolation: test driver → test passengers only,
  -- real driver → real passengers only)
  SELECT COUNT(*) INTO v_assigned
  FROM public.passenger_queue
  WHERE route_id = p_route_id
    AND status = 'WAITING'
    AND is_test_data = v_is_test_driver;

  IF v_assigned = 0 THEN
    RETURN jsonb_build_object(
      'matched',         false,
      'reason',          'no_passengers_waiting',
      'test_isolation',  v_is_test_driver
    );
  END IF;

  -- Get vehicle capacity
  SELECT seating_capacity INTO v_seats_left
  FROM public.vehicles WHERE id = v_driver.vehicle_id;

  -- Create provisional trip
  -- CHANGE 2: explicit ::public.trip_status cast on 'accepting_bookings'
  INSERT INTO public.trips (
    driver_id, route_id, vehicle_id,
    status, total_seats, booked_seats,
    is_test_data, created_at, updated_at
  )
  VALUES (
    v_driver.driver_id,
    p_route_id,
    v_driver.vehicle_id,
    'accepting_bookings'::public.trip_status,
    v_seats_left,
    0,
    v_is_test_driver,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_trip_id;

  -- Link driver queue to trip
  -- CHANGE 3: explicit ::public.queue_status cast on 'offered'
  UPDATE public.driver_queue
  SET
    status              = 'offered'::public.queue_status,
    provisional_trip_id = v_trip_id,
    offer_expires_at    = NOW() + (
      SELECT COALESCE(value::INTEGER, 45) * INTERVAL '1 second'
      FROM public.business_settings WHERE key = 'driver_offer_timeout_seconds'
    )
  WHERE id = v_driver.id;

  -- Assign passengers (FIFO, fit-aware, test isolation enforced)
  v_assigned   := 0;
  v_seats_left := (SELECT seating_capacity FROM public.vehicles WHERE id = v_driver.vehicle_id);

  FOR v_pq IN
    SELECT pq.*, b.seats
    FROM public.passenger_queue pq
    JOIN public.bookings b ON b.id = pq.booking_id
    WHERE pq.route_id = p_route_id
      AND pq.status = 'WAITING'
      AND pq.is_test_data = v_is_test_driver  -- ISOLATION: match only same test/real category
    ORDER BY pq.queue_sequence
  LOOP
    EXIT WHEN v_seats_left <= 0;
    IF v_pq.seats <= v_seats_left THEN
      UPDATE public.passenger_queue
      SET
        status           = 'MATCHING',
        assigned_trip_id = v_trip_id,
        updated_at       = NOW()
      WHERE id = v_pq.id;

      -- CHANGE 4: explicit ::public.booking_status cast on 'confirmed'
      UPDATE public.bookings
      SET
        trip_id    = v_trip_id,
        status     = 'confirmed'::public.booking_status,
        updated_at = NOW()
      WHERE id = v_pq.booking_id;

      UPDATE public.trips
      SET
        booked_seats = booked_seats + v_pq.seats,
        updated_at   = NOW()
      WHERE id = v_trip_id;

      v_seats_left := v_seats_left - v_pq.seats;
      v_assigned   := v_assigned + 1;
    END IF;
  END LOOP;

  -- ── CHANGE 1 (BUG FIX): explicit ::public.trip_status casts ────────────
  --
  -- ERROR 42804 ROOT CAUSE:
  --   PostgreSQL infers the CASE result type as TEXT because both
  --   branch literals are untyped string constants. trips.status is
  --   public.trip_status (ENUM). PostgreSQL cannot implicitly cast
  --   TEXT → ENUM in an UPDATE SET expression → ERROR 42804.
  --
  -- FIX: cast both CASE branches to ::public.trip_status explicitly.
  -- ──────────────────────────────────────────────────────────────────────
  UPDATE public.trips
  SET
    status     = CASE
                   WHEN booked_seats >= total_seats
                     THEN 'full'::public.trip_status
                   ELSE 'accepting_bookings'::public.trip_status
                 END,
    updated_at = NOW()
  WHERE id = v_trip_id;

  INSERT INTO public.audit_logs (
    performed_by, action, target_table, target_id, new_value, notes
  )
  VALUES (
    COALESCE(auth.uid(), v_driver.driver_profile_id),
    'match_created'::public.audit_action,
    'trips',
    v_trip_id,
    jsonb_build_object(
      'passengers_assigned',    v_assigned,
      'route_id',               p_route_id,
      'is_test_data',           v_is_test_driver,
      'test_isolation_applied', true
    ),
    'match_route_queue: test isolation enforced'
  );

  RETURN jsonb_build_object(
    'matched',            true,
    'trip_id',            v_trip_id,
    'passengers_assigned', v_assigned,
    'test_isolation',     v_is_test_driver
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.match_route_queue(UUID) TO authenticated;
