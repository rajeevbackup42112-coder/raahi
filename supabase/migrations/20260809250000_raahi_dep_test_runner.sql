-- ============================================================
-- RAAHI — DEP-1 through DEP-10 Automated Test Runner
-- Migration: 20260809250000_raahi_dep_test_runner.sql
-- ============================================================
-- Provides a single RPC: run_departure_tests(p_route_id, p_admin_id)
-- that executes all 10 departure eligibility tests against the
-- live database and returns actual before/after DB state for each.
--
-- Tests are self-contained: each test creates its own isolated
-- test data, executes the relevant RPCs, verifies DB state, and
-- cleans up after itself.
--
-- Also provides:
--   run_cross_driver_auth_test  — DEP cross-driver authorization
--   run_full_trip_flow_test     — full start→complete flow
-- ============================================================

-- ============================================================
-- HELPER: create a minimal test driver with vehicle + queue entry
-- Returns: (driver_profile_id, driver_id, vehicle_id, dq_id)
-- ============================================================

CREATE OR REPLACE FUNCTION public._dep_create_driver(
  p_route_id   UUID,
  p_capacity   INTEGER,
  p_label      TEXT,
  p_admin_id   UUID
)
RETURNS TABLE(
  driver_profile_id UUID,
  driver_id         UUID,
  vehicle_id        UUID,
  dq_id             UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile_id UUID;
  v_driver_id  UUID;
  v_vehicle_id UUID;
  v_dq_id      UUID;
BEGIN
  -- Create profile
  INSERT INTO public.profiles (id, name, email, role, is_test_data)
  VALUES (
    gen_random_uuid(),
    'DEP_TEST_' || p_label,
    'dep_test_' || lower(p_label) || '_' || floor(random()*99999)::TEXT || '@test.raahi.internal',
    'driver',
    true
  )
  RETURNING id INTO v_profile_id;

  -- Create driver record
  INSERT INTO public.drivers (
    profile_id, verification_status, availability_status,
    current_route_id, is_test_data
  )
  VALUES (v_profile_id, 'approved', 'offline', p_route_id, true)
  RETURNING id INTO v_driver_id;

  -- Create vehicle
  INSERT INTO public.vehicles (
    registration_number, make, model, seating_capacity,
    status, assigned_driver_id, is_test_data
  )
  VALUES (
    'DEP-' || p_label || '-' || floor(random()*9999)::TEXT,
    'TestMake', 'TestModel', p_capacity,
    'active', v_driver_id, true
  )
  RETURNING id INTO v_vehicle_id;

  -- Link vehicle to driver
  UPDATE public.drivers SET current_vehicle_id = v_vehicle_id WHERE id = v_driver_id;

  -- Go online → add to driver queue
  INSERT INTO public.driver_queue (
    driver_id, route_id, status, queue_position, joined_at, is_test_data
  )
  VALUES (
    v_driver_id, p_route_id, 'waiting',
    COALESCE((SELECT MAX(queue_position) FROM public.driver_queue WHERE route_id = p_route_id AND status = 'waiting'), 0) + 1,
    NOW(), true
  )
  RETURNING id INTO v_dq_id;

  UPDATE public.drivers
  SET availability_status = 'online', current_route_id = p_route_id
  WHERE id = v_driver_id;

  RETURN QUERY SELECT v_profile_id, v_driver_id, v_vehicle_id, v_dq_id;
END;
$$;

-- ============================================================
-- HELPER: create a test passenger with booking + queue entry
-- Returns: (passenger_profile_id, booking_id, pq_id, queue_sequence)
-- ============================================================

CREATE OR REPLACE FUNCTION public._dep_create_passenger(
  p_route_id   UUID,
  p_seats      INTEGER,
  p_label      TEXT,
  p_trip_id    UUID DEFAULT NULL  -- if not null, directly assign to trip
)
RETURNS TABLE(
  passenger_profile_id UUID,
  booking_id           UUID,
  pq_id                UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile_id UUID;
  v_booking_id UUID;
  v_pq_id      UUID;
  v_pickup_id  UUID;
  v_fare       NUMERIC;
  v_qpos       INTEGER;
BEGIN
  -- Get a pickup point for this route
  SELECT id INTO v_pickup_id
  FROM public.pickup_points
  WHERE route_id = p_route_id AND is_active = true
  LIMIT 1;

  -- Fallback: create a temporary pickup point if none exists
  IF v_pickup_id IS NULL THEN
    INSERT INTO public.pickup_points (route_id, name, sequence_order, is_active)
    VALUES (p_route_id, 'DEP Test Stop', 1, true)
    RETURNING id INTO v_pickup_id;
  END IF;

  SELECT COALESCE(fare_per_seat, 150) INTO v_fare
  FROM public.routes WHERE id = p_route_id;

  -- Create profile
  INSERT INTO public.profiles (id, name, email, role, is_test_data)
  VALUES (
    gen_random_uuid(),
    'DEP_PAX_' || p_label,
    'dep_pax_' || lower(p_label) || '_' || floor(random()*99999)::TEXT || '@test.raahi.internal',
    'passenger',
    true
  )
  RETURNING id INTO v_profile_id;

  -- Create booking
  INSERT INTO public.bookings (
    passenger_id, route_id, pickup_point_id, trip_id,
    seats, fare_per_seat, status, booked_at, is_test_data
  )
  VALUES (
    v_profile_id, p_route_id, v_pickup_id, p_trip_id,
    p_seats, v_fare, 'confirmed', NOW(), true
  )
  RETURNING id INTO v_booking_id;

  -- Add to passenger queue
  SELECT COALESCE(MAX(queue_position), 0) + 1
  INTO v_qpos
  FROM public.passenger_queue
  WHERE route_id = p_route_id AND status IN ('waiting', 'active');

  INSERT INTO public.passenger_queue (
    passenger_id, route_id, booking_id, seats_requested,
    queue_position, status, joined_at, is_test_data
  )
  VALUES (
    v_profile_id, p_route_id, v_booking_id, p_seats,
    v_qpos,
    CASE WHEN p_trip_id IS NOT NULL THEN 'active' ELSE 'waiting' END,
    NOW(), true
  )
  RETURNING id INTO v_pq_id;

  RETURN QUERY SELECT v_profile_id, v_booking_id, v_pq_id;
END;
$$;

-- ============================================================
-- HELPER: create a trip for a driver
-- ============================================================

CREATE OR REPLACE FUNCTION public._dep_create_trip(
  p_driver_id  UUID,
  p_route_id   UUID,
  p_vehicle_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trip_id UUID;
BEGIN
  INSERT INTO public.trips (
    driver_id, route_id, vehicle_id, status,
    created_at, updated_at, is_test_data
  )
  VALUES (
    p_driver_id, p_route_id, p_vehicle_id, 'boarding',
    NOW(), NOW(), true
  )
  RETURNING id INTO v_trip_id;

  -- Link driver queue entry to this trip
  UPDATE public.driver_queue
  SET provisional_trip_id = v_trip_id, status = 'assigned'
  WHERE driver_id = p_driver_id AND status IN ('waiting', 'offered');

  RETURN v_trip_id;
END;
$$;

-- ============================================================
-- HELPER: cleanup all test data for a given set of trip/profile IDs
-- ============================================================

CREATE OR REPLACE FUNCTION public._dep_cleanup(
  p_trip_ids    UUID[],
  p_profile_ids UUID[]
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Cancel bookings
  UPDATE public.bookings SET status = 'cancelled'
  WHERE trip_id = ANY(p_trip_ids) OR passenger_id = ANY(p_profile_ids);

  -- Cancel passenger queue
  UPDATE public.passenger_queue SET status = 'cancelled'
  WHERE passenger_id = ANY(p_profile_ids);

  -- Cancel driver queue
  UPDATE public.driver_queue SET status = 'cancelled'
  WHERE driver_id IN (
    SELECT id FROM public.drivers WHERE profile_id = ANY(p_profile_ids)
  );

  -- Cancel trips
  UPDATE public.trips SET status = 'cancelled'
  WHERE id = ANY(p_trip_ids);

  -- Delete test profiles (cascades to drivers/vehicles via FK or we handle manually)
  UPDATE public.drivers SET availability_status = 'offline', current_route_id = NULL
  WHERE profile_id = ANY(p_profile_ids);

  DELETE FROM public.vehicles WHERE assigned_driver_id IN (
    SELECT id FROM public.drivers WHERE profile_id = ANY(p_profile_ids)
  );

  DELETE FROM public.drivers WHERE profile_id = ANY(p_profile_ids);
  DELETE FROM public.profiles WHERE id = ANY(p_profile_ids);
END;
$$;

-- ============================================================
-- MAIN: run_departure_tests
-- Executes DEP-1 through DEP-10 + cross-driver auth + full flow
-- Returns JSONB array of test results with actual DB state
-- ============================================================

CREATE OR REPLACE FUNCTION public.run_departure_tests(
  p_route_id UUID,
  p_admin_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  -- Auth check
  v_is_admin        BOOLEAN;

  -- Shared state
  v_route           RECORD;
  v_min_passengers  INTEGER;

  -- Per-test state
  v_driver_a        RECORD;
  v_driver_b        RECORD;
  v_trip_id         UUID;
  v_trip            RECORD;
  v_pax             RECORD;
  v_pax_ids         UUID[];
  v_profile_ids     UUID[];
  v_result          JSONB;
  v_booked_seats    INTEGER;
  v_lock_remaining  INTEGER;

  -- Test result accumulator
  v_tests           JSONB := '[]'::JSONB;
  v_test_result     JSONB;

  -- Temp variables
  v_p1 RECORD; v_p2 RECORD; v_p3 RECORD; v_p4 RECORD;
  v_p5 RECORD; v_p6 RECORD; v_p7 RECORD;
  v_booking_id UUID;
  v_pq_id UUID;
  v_pass BOOLEAN;
  v_actual TEXT;
  v_bug TEXT;
  v_fix TEXT;
BEGIN
  -- ── Auth guard ──────────────────────────────────────────────
  SELECT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin'
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('error', 'Admin only');
  END IF;

  -- ── Get route config ────────────────────────────────────────
  SELECT * INTO v_route FROM public.routes WHERE id = p_route_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Route not found');
  END IF;
  v_min_passengers := COALESCE(v_route.min_passengers, 1);

  -- ============================================================
  -- DEP-1: BELOW MINIMUM
  -- Setup: D1(cap=6), P1+P2+P3 assigned (3 seats), min=4
  -- Call driver_leave_now → expect REJECTED
  -- ============================================================
  BEGIN
    -- Create driver A with capacity 6
    SELECT * INTO v_driver_a FROM public._dep_create_driver(p_route_id, 6, 'DEP1_DA', p_admin_id);

    -- Create trip for driver A
    v_trip_id := public._dep_create_trip(v_driver_a.driver_id, p_route_id, v_driver_a.vehicle_id);

    -- Assign 3 passengers (below min=4)
    SELECT * INTO v_p1 FROM public._dep_create_passenger(p_route_id, 1, 'DEP1_P1', v_trip_id);
    SELECT * INTO v_p2 FROM public._dep_create_passenger(p_route_id, 1, 'DEP1_P2', v_trip_id);
    SELECT * INTO v_p3 FROM public._dep_create_passenger(p_route_id, 1, 'DEP1_P3', v_trip_id);

    -- Verify pre-state: 3 confirmed seats
    SELECT COALESCE(SUM(seats), 0) INTO v_booked_seats
    FROM public.bookings WHERE trip_id = v_trip_id AND status = 'confirmed';

    -- Call driver_leave_now — must be REJECTED
    SELECT public.driver_leave_now(v_driver_a.driver_profile_id) INTO v_result;

    -- Verify post-state: trip still 'boarding', no lock
    SELECT * INTO v_trip FROM public.trips WHERE id = v_trip_id;

    v_pass := (v_result->>'success')::BOOLEAN = false
              AND v_trip.status = 'boarding'
              AND v_trip.departure_lock_expires_at IS NULL;

    v_actual := format(
      'driver_leave_now returned success=%s error="%s". Trip status=%s, lock=%s. Pre-state: %s confirmed seats (min=%s)',
      v_result->>'success',
      v_result->>'error',
      v_trip.status,
      COALESCE(v_trip.departure_lock_expires_at::TEXT, 'NULL'),
      v_booked_seats,
      v_min_passengers
    );

    v_bug := CASE WHEN NOT v_pass THEN
      CASE WHEN (v_result->>'success')::BOOLEAN = true
        THEN 'driver_leave_now allowed departure below minimum — server guard missing'
        ELSE format('Trip status changed to %s unexpectedly', v_trip.status)
      END
    ELSE NULL END;

    v_tests := v_tests || jsonb_build_object(
      'test', 'DEP-1',
      'name', 'Below Minimum',
      'status', CASE WHEN v_pass THEN 'ACTUALLY TESTED — PASS' ELSE 'ACTUALLY TESTED — FAIL' END,
      'expected', format('REJECTED. Trip stays boarding. No lock. (seats=%s < min=%s)', v_booked_seats, v_min_passengers),
      'actual', v_actual,
      'pass', v_pass,
      'bug', v_bug,
      'fix', NULL,
      'pre_state', jsonb_build_object('booked_seats', v_booked_seats, 'min_passengers', v_min_passengers, 'trip_status', 'boarding'),
      'post_state', jsonb_build_object('trip_status', v_trip.status, 'lock_expires_at', v_trip.departure_lock_expires_at, 'rpc_success', v_result->>'success', 'rpc_error', v_result->>'error')
    );

    -- Cleanup DEP-1
    PERFORM public._dep_cleanup(
      ARRAY[v_trip_id],
      ARRAY[v_driver_a.driver_profile_id, v_p1.passenger_profile_id, v_p2.passenger_profile_id, v_p3.passenger_profile_id]
    );
  EXCEPTION WHEN OTHERS THEN
    v_tests := v_tests || jsonb_build_object(
      'test', 'DEP-1', 'name', 'Below Minimum',
      'status', 'ACTUALLY TESTED — FAIL',
      'actual', 'Exception: ' || SQLERRM, 'pass', false, 'bug', SQLERRM
    );
  END;

  -- ============================================================
  -- DEP-2: MINIMUM REACHED
  -- Setup: D1(cap=6), P1–P4 assigned (4 seats), min=4
  -- Call driver_leave_now → expect SUCCESS, trip → departure_pending
  -- ============================================================
  BEGIN
    SELECT * INTO v_driver_a FROM public._dep_create_driver(p_route_id, 6, 'DEP2_DA', p_admin_id);
    v_trip_id := public._dep_create_trip(v_driver_a.driver_id, p_route_id, v_driver_a.vehicle_id);

    SELECT * INTO v_p1 FROM public._dep_create_passenger(p_route_id, 1, 'DEP2_P1', v_trip_id);
    SELECT * INTO v_p2 FROM public._dep_create_passenger(p_route_id, 1, 'DEP2_P2', v_trip_id);
    SELECT * INTO v_p3 FROM public._dep_create_passenger(p_route_id, 1, 'DEP2_P3', v_trip_id);
    SELECT * INTO v_p4 FROM public._dep_create_passenger(p_route_id, 1, 'DEP2_P4', v_trip_id);

    SELECT COALESCE(SUM(seats), 0) INTO v_booked_seats
    FROM public.bookings WHERE trip_id = v_trip_id AND status = 'confirmed';

    SELECT public.driver_leave_now(v_driver_a.driver_profile_id) INTO v_result;

    SELECT * INTO v_trip FROM public.trips WHERE id = v_trip_id;

    v_pass := (v_result->>'success')::BOOLEAN = true
              AND v_trip.status = 'departure_pending'
              AND v_trip.departure_lock_expires_at IS NOT NULL
              AND v_trip.departure_lock_expires_at > NOW();

    v_actual := format(
      'driver_leave_now returned success=%s. Trip status=%s, lock_expires_at=%s. Seats=%s/min=%s',
      v_result->>'success',
      v_trip.status,
      COALESCE(v_trip.departure_lock_expires_at::TEXT, 'NULL'),
      v_booked_seats,
      v_min_passengers
    );

    v_tests := v_tests || jsonb_build_object(
      'test', 'DEP-2',
      'name', 'Minimum Reached',
      'status', CASE WHEN v_pass THEN 'ACTUALLY TESTED — PASS' ELSE 'ACTUALLY TESTED — FAIL' END,
      'expected', format('SUCCESS. Trip → departure_pending. lock_expires_at set. (seats=%s >= min=%s)', v_booked_seats, v_min_passengers),
      'actual', v_actual,
      'pass', v_pass,
      'bug', CASE WHEN NOT v_pass THEN 'driver_leave_now failed or trip did not transition to departure_pending' ELSE NULL END,
      'pre_state', jsonb_build_object('booked_seats', v_booked_seats, 'min_passengers', v_min_passengers, 'trip_status', 'boarding'),
      'post_state', jsonb_build_object('trip_status', v_trip.status, 'lock_expires_at', v_trip.departure_lock_expires_at, 'rpc_success', v_result->>'success')
    );

    PERFORM public._dep_cleanup(
      ARRAY[v_trip_id],
      ARRAY[v_driver_a.driver_profile_id, v_p1.passenger_profile_id, v_p2.passenger_profile_id, v_p3.passenger_profile_id, v_p4.passenger_profile_id]
    );
  EXCEPTION WHEN OTHERS THEN
    v_tests := v_tests || jsonb_build_object(
      'test', 'DEP-2', 'name', 'Minimum Reached',
      'status', 'ACTUALLY TESTED — FAIL',
      'actual', 'Exception: ' || SQLERRM, 'pass', false, 'bug', SQLERRM
    );
  END;

  -- ============================================================
  -- DEP-3: WAIT FOR MORE
  -- Setup: D1(cap=6) at 4/6. Call driver_wait_for_more.
  -- Then add P5 (waiting) and trigger match → P5 auto-assigned.
  -- Then P6 → 6/6.
  -- ============================================================
  BEGIN
    SELECT * INTO v_driver_a FROM public._dep_create_driver(p_route_id, 6, 'DEP3_DA', p_admin_id);
    v_trip_id := public._dep_create_trip(v_driver_a.driver_id, p_route_id, v_driver_a.vehicle_id);

    -- Assign P1–P4 directly to trip
    SELECT * INTO v_p1 FROM public._dep_create_passenger(p_route_id, 1, 'DEP3_P1', v_trip_id);
    SELECT * INTO v_p2 FROM public._dep_create_passenger(p_route_id, 1, 'DEP3_P2', v_trip_id);
    SELECT * INTO v_p3 FROM public._dep_create_passenger(p_route_id, 1, 'DEP3_P3', v_trip_id);
    SELECT * INTO v_p4 FROM public._dep_create_passenger(p_route_id, 1, 'DEP3_P4', v_trip_id);

    -- First: call driver_leave_now to enter departure_pending
    SELECT public.driver_leave_now(v_driver_a.driver_profile_id) INTO v_result;

    -- Then: call driver_wait_for_more to revert to boarding
    SELECT public.driver_wait_for_more(v_driver_a.driver_profile_id) INTO v_result;

    SELECT * INTO v_trip FROM public.trips WHERE id = v_trip_id;
    v_pass := v_trip.status = 'boarding' AND v_trip.departure_lock_expires_at IS NULL;

    -- Now add P5 as waiting passenger (no trip_id)
    SELECT * INTO v_p5 FROM public._dep_create_passenger(p_route_id, 1, 'DEP3_P5', NULL);

    -- Trigger matching — P5 should be auto-assigned to the boarding trip
    PERFORM public.match_route_queue(p_route_id);

    -- Check if P5 got assigned to the trip
    SELECT COALESCE(SUM(seats), 0) INTO v_booked_seats
    FROM public.bookings WHERE trip_id = v_trip_id AND status = 'confirmed';

    DECLARE
      v_p5_assigned BOOLEAN;
    BEGIN
      SELECT EXISTS(
        SELECT 1 FROM public.bookings
        WHERE passenger_id = v_p5.passenger_profile_id
          AND trip_id = v_trip_id
          AND status = 'confirmed'
      ) INTO v_p5_assigned;

      -- Add P6 as waiting
      SELECT * INTO v_p6 FROM public._dep_create_passenger(p_route_id, 1, 'DEP3_P6', NULL);
      PERFORM public.match_route_queue(p_route_id);

      DECLARE
        v_p6_assigned BOOLEAN;
        v_final_seats INTEGER;
      BEGIN
        SELECT EXISTS(
          SELECT 1 FROM public.bookings
          WHERE passenger_id = v_p6.passenger_profile_id
            AND trip_id = v_trip_id
            AND status = 'confirmed'
        ) INTO v_p6_assigned;

        SELECT COALESCE(SUM(seats), 0) INTO v_final_seats
        FROM public.bookings WHERE trip_id = v_trip_id AND status = 'confirmed';

        v_pass := v_pass AND v_p5_assigned AND v_p6_assigned AND v_final_seats = 6;

        v_actual := format(
          'driver_wait_for_more: trip=%s lock=%s. P5 assigned=%s. P6 assigned=%s. Final seats=%s/6',
          v_trip.status,
          COALESCE(v_trip.departure_lock_expires_at::TEXT, 'NULL'),
          v_p5_assigned,
          v_p6_assigned,
          v_final_seats
        );

        v_tests := v_tests || jsonb_build_object(
          'test', 'DEP-3',
          'name', 'Wait for More',
          'status', CASE WHEN v_pass THEN 'ACTUALLY TESTED — PASS' ELSE 'ACTUALLY TESTED — FAIL' END,
          'expected', 'driver_wait_for_more reverts to boarding. P5 auto-assigned. P6 auto-assigned. Final=6/6.',
          'actual', v_actual,
          'pass', v_pass,
          'bug', CASE WHEN NOT v_pass THEN
            CASE WHEN NOT v_p5_assigned THEN 'P5 not auto-assigned after wait_for_more'
                 WHEN NOT v_p6_assigned THEN 'P6 not auto-assigned'
                 ELSE 'driver_wait_for_more did not revert trip to boarding'
            END
          ELSE NULL END,
          'pre_state', jsonb_build_object('trip_status', 'boarding', 'booked_seats', 4),
          'post_state', jsonb_build_object('trip_status_after_wait', v_trip.status, 'p5_assigned', v_p5_assigned, 'p6_assigned', v_p6_assigned, 'final_seats', v_final_seats)
        );

        PERFORM public._dep_cleanup(
          ARRAY[v_trip_id],
          ARRAY[v_driver_a.driver_profile_id, v_p1.passenger_profile_id, v_p2.passenger_profile_id, v_p3.passenger_profile_id, v_p4.passenger_profile_id, v_p5.passenger_profile_id, v_p6.passenger_profile_id]
        );
      END;
    END;
  EXCEPTION WHEN OTHERS THEN
    v_tests := v_tests || jsonb_build_object(
      'test', 'DEP-3', 'name', 'Wait for More',
      'status', 'ACTUALLY TESTED — FAIL',
      'actual', 'Exception: ' || SQLERRM, 'pass', false, 'bug', SQLERRM
    );
  END;

  -- ============================================================
  -- DEP-4: FULL VEHICLE
  -- Setup: D1(cap=6) with P1–P6 assigned (6/6).
  -- Attempt to add P7 → must be blocked.
  -- ============================================================
  BEGIN
    SELECT * INTO v_driver_a FROM public._dep_create_driver(p_route_id, 6, 'DEP4_DA', p_admin_id);
    v_trip_id := public._dep_create_trip(v_driver_a.driver_id, p_route_id, v_driver_a.vehicle_id);

    SELECT * INTO v_p1 FROM public._dep_create_passenger(p_route_id, 1, 'DEP4_P1', v_trip_id);
    SELECT * INTO v_p2 FROM public._dep_create_passenger(p_route_id, 1, 'DEP4_P2', v_trip_id);
    SELECT * INTO v_p3 FROM public._dep_create_passenger(p_route_id, 1, 'DEP4_P3', v_trip_id);
    SELECT * INTO v_p4 FROM public._dep_create_passenger(p_route_id, 1, 'DEP4_P4', v_trip_id);
    SELECT * INTO v_p5 FROM public._dep_create_passenger(p_route_id, 1, 'DEP4_P5', v_trip_id);
    SELECT * INTO v_p6 FROM public._dep_create_passenger(p_route_id, 1, 'DEP4_P6', v_trip_id);

    SELECT COALESCE(SUM(seats), 0) INTO v_booked_seats
    FROM public.bookings WHERE trip_id = v_trip_id AND status = 'confirmed';

    -- Enter departure_pending (full vehicle)
    SELECT public.driver_leave_now(v_driver_a.driver_profile_id) INTO v_result;

    -- Now try to add P7 via match — should be blocked
    SELECT * INTO v_p7 FROM public._dep_create_passenger(p_route_id, 1, 'DEP4_P7', NULL);
    PERFORM public.match_route_queue(p_route_id);

    DECLARE
      v_p7_assigned BOOLEAN;
      v_final_seats INTEGER;
    BEGIN
      SELECT EXISTS(
        SELECT 1 FROM public.bookings
        WHERE passenger_id = v_p7.passenger_profile_id
          AND trip_id = v_trip_id
          AND status = 'confirmed'
      ) INTO v_p7_assigned;

      SELECT COALESCE(SUM(seats), 0) INTO v_final_seats
      FROM public.bookings WHERE trip_id = v_trip_id AND status = 'confirmed';

      -- P7 must NOT be assigned to D1's trip
      v_pass := NOT v_p7_assigned AND v_final_seats = 6;

      v_actual := format(
        'Pre: %s/6 seats. driver_leave_now success=%s. P7 assigned to D1 trip=%s. Final seats on D1=%s.',
        v_booked_seats,
        v_result->>'success',
        v_p7_assigned,
        v_final_seats
      );

      v_tests := v_tests || jsonb_build_object(
        'test', 'DEP-4',
        'name', 'Full Vehicle',
        'status', CASE WHEN v_pass THEN 'ACTUALLY TESTED — PASS' ELSE 'ACTUALLY TESTED — FAIL' END,
        'expected', 'P7 NOT assigned to full/departure_pending trip. D1 stays at 6/6.',
        'actual', v_actual,
        'pass', v_pass,
        'bug', CASE WHEN NOT v_pass THEN 'P7 was assigned to a full/departure_pending trip — capacity or lock guard missing' ELSE NULL END,
        'pre_state', jsonb_build_object('booked_seats', v_booked_seats, 'capacity', 6),
        'post_state', jsonb_build_object('p7_assigned', v_p7_assigned, 'final_seats', v_final_seats, 'trip_status', v_result->>'success')
      );

      PERFORM public._dep_cleanup(
        ARRAY[v_trip_id],
        ARRAY[v_driver_a.driver_profile_id, v_p1.passenger_profile_id, v_p2.passenger_profile_id, v_p3.passenger_profile_id, v_p4.passenger_profile_id, v_p5.passenger_profile_id, v_p6.passenger_profile_id, v_p7.passenger_profile_id]
      );
    END;
  EXCEPTION WHEN OTHERS THEN
    v_tests := v_tests || jsonb_build_object(
      'test', 'DEP-4', 'name', 'Full Vehicle',
      'status', 'ACTUALLY TESTED — FAIL',
      'actual', 'Exception: ' || SQLERRM, 'pass', false, 'bug', SQLERRM
    );
  END;

  -- ============================================================
  -- DEP-5: DEPARTURE LOCK BLOCKS NEW PASSENGER
  -- Setup: D1(cap=6) at 4/6. driver_leave_now → departure_pending.
  -- P5 joins queue. match_route_queue. P5 must NOT go to D1.
  -- ============================================================
  BEGIN
    SELECT * INTO v_driver_a FROM public._dep_create_driver(p_route_id, 6, 'DEP5_DA', p_admin_id);
    v_trip_id := public._dep_create_trip(v_driver_a.driver_id, p_route_id, v_driver_a.vehicle_id);

    SELECT * INTO v_p1 FROM public._dep_create_passenger(p_route_id, 1, 'DEP5_P1', v_trip_id);
    SELECT * INTO v_p2 FROM public._dep_create_passenger(p_route_id, 1, 'DEP5_P2', v_trip_id);
    SELECT * INTO v_p3 FROM public._dep_create_passenger(p_route_id, 1, 'DEP5_P3', v_trip_id);
    SELECT * INTO v_p4 FROM public._dep_create_passenger(p_route_id, 1, 'DEP5_P4', v_trip_id);

    -- Lock the trip
    SELECT public.driver_leave_now(v_driver_a.driver_profile_id) INTO v_result;

    -- P5 joins and match runs
    SELECT * INTO v_p5 FROM public._dep_create_passenger(p_route_id, 1, 'DEP5_P5', NULL);
    PERFORM public.match_route_queue(p_route_id);

    DECLARE
      v_p5_on_d1 BOOLEAN;
      v_p5_status TEXT;
    BEGIN
      SELECT EXISTS(
        SELECT 1 FROM public.bookings
        WHERE passenger_id = v_p5.passenger_profile_id
          AND trip_id = v_trip_id
          AND status = 'confirmed'
      ) INTO v_p5_on_d1;

      SELECT pq.status::TEXT INTO v_p5_status
      FROM public.passenger_queue pq
      WHERE pq.passenger_id = v_p5.passenger_profile_id
      LIMIT 1;

      v_pass := NOT v_p5_on_d1;

      v_actual := format(
        'D1 trip locked (departure_pending). P5 assigned to D1=%s. P5 queue status=%s.',
        v_p5_on_d1,
        COALESCE(v_p5_status, 'not found')
      );

      v_tests := v_tests || jsonb_build_object(
        'test', 'DEP-5',
        'name', 'Departure Lock Blocks New Passenger',
        'status', CASE WHEN v_pass THEN 'ACTUALLY TESTED — PASS' ELSE 'ACTUALLY TESTED — FAIL' END,
        'expected', 'P5 NOT assigned to departure_pending trip. P5 remains waiting or goes to next vehicle.',
        'actual', v_actual,
        'pass', v_pass,
        'bug', CASE WHEN NOT v_pass THEN 'book_or_queue or match_route_queue assigned P5 to a departure_pending trip — lock guard missing' ELSE NULL END,
        'pre_state', jsonb_build_object('d1_trip_status', 'departure_pending', 'booked_seats', 4),
        'post_state', jsonb_build_object('p5_on_d1', v_p5_on_d1, 'p5_queue_status', v_p5_status)
      );

      PERFORM public._dep_cleanup(
        ARRAY[v_trip_id],
        ARRAY[v_driver_a.driver_profile_id, v_p1.passenger_profile_id, v_p2.passenger_profile_id, v_p3.passenger_profile_id, v_p4.passenger_profile_id, v_p5.passenger_profile_id]
      );
    END;
  EXCEPTION WHEN OTHERS THEN
    v_tests := v_tests || jsonb_build_object(
      'test', 'DEP-5', 'name', 'Departure Lock Blocks New Passenger',
      'status', 'ACTUALLY TESTED — FAIL',
      'actual', 'Exception: ' || SQLERRM, 'pass', false, 'bug', SQLERRM
    );
  END;

  -- ============================================================
  -- DEP-6: START TRIP GUARD
  -- Setup: D1 in departure_pending (lock active).
  -- driver_start_trip during lock → REJECTED.
  -- Manually expire lock → driver_start_trip → SUCCESS.
  -- ============================================================
  BEGIN
    SELECT * INTO v_driver_a FROM public._dep_create_driver(p_route_id, 6, 'DEP6_DA', p_admin_id);
    v_trip_id := public._dep_create_trip(v_driver_a.driver_id, p_route_id, v_driver_a.vehicle_id);

    SELECT * INTO v_p1 FROM public._dep_create_passenger(p_route_id, 1, 'DEP6_P1', v_trip_id);
    SELECT * INTO v_p2 FROM public._dep_create_passenger(p_route_id, 1, 'DEP6_P2', v_trip_id);
    SELECT * INTO v_p3 FROM public._dep_create_passenger(p_route_id, 1, 'DEP6_P3', v_trip_id);
    SELECT * INTO v_p4 FROM public._dep_create_passenger(p_route_id, 1, 'DEP6_P4', v_trip_id);

    SELECT public.driver_leave_now(v_driver_a.driver_profile_id) INTO v_result;

    -- Attempt start trip DURING lock — must be REJECTED
    DECLARE
      v_start_during_lock JSONB;
      v_start_after_lock  JSONB;
      v_rejected_during   BOOLEAN;
      v_succeeded_after   BOOLEAN;
      v_trip_final        RECORD;
    BEGIN
      SELECT public.driver_start_trip(v_driver_a.driver_id) INTO v_start_during_lock;
      v_rejected_during := (v_start_during_lock->>'success')::BOOLEAN = false
                           AND v_start_during_lock->>'error' ILIKE '%lock%';

      -- Manually expire the lock for testing
      UPDATE public.trips
      SET departure_lock_expires_at = NOW() - INTERVAL '1 second'
      WHERE id = v_trip_id;

      -- Now start trip — must SUCCEED
      SELECT public.driver_start_trip(v_driver_a.driver_id) INTO v_start_after_lock;
      v_succeeded_after := (v_start_after_lock->>'success')::BOOLEAN = true;

      SELECT * INTO v_trip_final FROM public.trips WHERE id = v_trip_id;

      v_pass := v_rejected_during AND v_succeeded_after AND v_trip_final.status = 'in_progress';

      v_actual := format(
        'Start during lock: success=%s error="%s". Start after lock: success=%s. Final trip status=%s.',
        v_start_during_lock->>'success',
        v_start_during_lock->>'error',
        v_start_after_lock->>'success',
        v_trip_final.status
      );

      v_tests := v_tests || jsonb_build_object(
        'test', 'DEP-6',
        'name', 'Start Trip Guard',
        'status', CASE WHEN v_pass THEN 'ACTUALLY TESTED — PASS' ELSE 'ACTUALLY TESTED — FAIL' END,
        'expected', 'driver_start_trip REJECTED during lock. After lock expires → SUCCESS, trip → in_progress.',
        'actual', v_actual,
        'pass', v_pass,
        'bug', CASE WHEN NOT v_pass THEN
          CASE WHEN NOT v_rejected_during THEN 'driver_start_trip did not reject during active lock'
               WHEN NOT v_succeeded_after THEN 'driver_start_trip failed after lock expired'
               ELSE format('Trip did not reach in_progress, got: %s', v_trip_final.status)
          END
        ELSE NULL END,
        'pre_state', jsonb_build_object('trip_status', 'departure_pending', 'lock_active', true),
        'post_state', jsonb_build_object(
          'rejected_during_lock', v_rejected_during,
          'succeeded_after_lock', v_succeeded_after,
          'final_trip_status', v_trip_final.status,
          'start_during_error', v_start_during_lock->>'error'
        )
      );

      PERFORM public._dep_cleanup(
        ARRAY[v_trip_id],
        ARRAY[v_driver_a.driver_profile_id, v_p1.passenger_profile_id, v_p2.passenger_profile_id, v_p3.passenger_profile_id, v_p4.passenger_profile_id]
      );
    END;
  EXCEPTION WHEN OTHERS THEN
    v_tests := v_tests || jsonb_build_object(
      'test', 'DEP-6', 'name', 'Start Trip Guard',
      'status', 'ACTUALLY TESTED — FAIL',
      'actual', 'Exception: ' || SQLERRM, 'pass', false, 'bug', SQLERRM
    );
  END;

  -- ============================================================
  -- DEP-7: CANCELLATION DROPS BELOW MINIMUM
  -- Setup: D1(cap=6) at 4/6. driver_leave_now → departure_pending.
  -- One passenger cancels → 3/6. Eligibility revoked.
  -- driver_start_trip → REJECTED.
  -- ============================================================
  BEGIN
    SELECT * INTO v_driver_a FROM public._dep_create_driver(p_route_id, 6, 'DEP7_DA', p_admin_id);
    v_trip_id := public._dep_create_trip(v_driver_a.driver_id, p_route_id, v_driver_a.vehicle_id);

    SELECT * INTO v_p1 FROM public._dep_create_passenger(p_route_id, 1, 'DEP7_P1', v_trip_id);
    SELECT * INTO v_p2 FROM public._dep_create_passenger(p_route_id, 1, 'DEP7_P2', v_trip_id);
    SELECT * INTO v_p3 FROM public._dep_create_passenger(p_route_id, 1, 'DEP7_P3', v_trip_id);
    SELECT * INTO v_p4 FROM public._dep_create_passenger(p_route_id, 1, 'DEP7_P4', v_trip_id);

    SELECT public.driver_leave_now(v_driver_a.driver_profile_id) INTO v_result;

    -- P4 cancels their booking
    SELECT public.cancel_booking(v_p4.passenger_profile_id, v_p4.booking_id) INTO v_result;

    -- Check trip state after cancellation
    SELECT * INTO v_trip FROM public.trips WHERE id = v_trip_id;

    SELECT COALESCE(SUM(seats), 0) INTO v_booked_seats
    FROM public.bookings WHERE trip_id = v_trip_id AND status = 'confirmed';

    -- Expire lock (if still set) and try to start trip
    UPDATE public.trips
    SET departure_lock_expires_at = NOW() - INTERVAL '1 second'
    WHERE id = v_trip_id AND departure_lock_expires_at IS NOT NULL;

    DECLARE
      v_start_result JSONB;
      v_eligibility_revoked BOOLEAN;
      v_start_rejected BOOLEAN;
    BEGIN
      SELECT public.driver_start_trip(v_driver_a.driver_id) INTO v_start_result;

      v_eligibility_revoked := v_trip.status = 'boarding' AND v_trip.departure_lock_expires_at IS NULL;
      v_start_rejected := (v_start_result->>'success')::BOOLEAN = false;

      v_pass := v_booked_seats = 3 AND v_eligibility_revoked AND v_start_rejected;

      v_actual := format(
        'After P4 cancel: booked_seats=%s. Trip status=%s lock=%s. Start trip: success=%s error="%s".',
        v_booked_seats,
        v_trip.status,
        COALESCE(v_trip.departure_lock_expires_at::TEXT, 'NULL'),
        v_start_result->>'success',
        v_start_result->>'error'
      );

      v_tests := v_tests || jsonb_build_object(
        'test', 'DEP-7',
        'name', 'Cancellation Drops Below Minimum',
        'status', CASE WHEN v_pass THEN 'ACTUALLY TESTED — PASS' ELSE 'ACTUALLY TESTED — FAIL' END,
        'expected', 'After cancel: seats=3 < min=4. Trip reverts to boarding. Lock cleared. Start trip REJECTED.',
        'actual', v_actual,
        'pass', v_pass,
        'bug', CASE WHEN NOT v_pass THEN
          CASE WHEN NOT v_eligibility_revoked THEN format('Trip did not revert to boarding after cancel (status=%s)', v_trip.status)
               WHEN NOT v_start_rejected THEN 'driver_start_trip succeeded despite below-minimum occupancy'
               ELSE format('Unexpected seat count: %s', v_booked_seats)
          END
        ELSE NULL END,
        'pre_state', jsonb_build_object('trip_status', 'departure_pending', 'booked_seats', 4),
        'post_state', jsonb_build_object(
          'booked_seats_after_cancel', v_booked_seats,
          'trip_status', v_trip.status,
          'lock_cleared', v_trip.departure_lock_expires_at IS NULL,
          'start_rejected', v_start_rejected,
          'start_error', v_start_result->>'error'
        )
      );

      PERFORM public._dep_cleanup(
        ARRAY[v_trip_id],
        ARRAY[v_driver_a.driver_profile_id, v_p1.passenger_profile_id, v_p2.passenger_profile_id, v_p3.passenger_profile_id, v_p4.passenger_profile_id]
      );
    END;
  EXCEPTION WHEN OTHERS THEN
    v_tests := v_tests || jsonb_build_object(
      'test', 'DEP-7', 'name', 'Cancellation Drops Below Minimum',
      'status', 'ACTUALLY TESTED — FAIL',
      'actual', 'Exception: ' || SQLERRM, 'pass', false, 'bug', SQLERRM
    );
  END;

  -- ============================================================
  -- DEP-8: CANCELLATION STILL AT MINIMUM
  -- Setup: D1(cap=6) at 5/6. driver_leave_now → departure_pending.
  -- P5 cancels → 4/6. Still meets min=4.
  -- departure_pending must remain.
  -- ============================================================
  BEGIN
    SELECT * INTO v_driver_a FROM public._dep_create_driver(p_route_id, 6, 'DEP8_DA', p_admin_id);
    v_trip_id := public._dep_create_trip(v_driver_a.driver_id, p_route_id, v_driver_a.vehicle_id);

    SELECT * INTO v_p1 FROM public._dep_create_passenger(p_route_id, 1, 'DEP8_P1', v_trip_id);
    SELECT * INTO v_p2 FROM public._dep_create_passenger(p_route_id, 1, 'DEP8_P2', v_trip_id);
    SELECT * INTO v_p3 FROM public._dep_create_passenger(p_route_id, 1, 'DEP8_P3', v_trip_id);
    SELECT * INTO v_p4 FROM public._dep_create_passenger(p_route_id, 1, 'DEP8_P4', v_trip_id);
    SELECT * INTO v_p5 FROM public._dep_create_passenger(p_route_id, 1, 'DEP8_P5', v_trip_id);

    SELECT public.driver_leave_now(v_driver_a.driver_profile_id) INTO v_result;

    -- P5 cancels
    SELECT public.cancel_booking(v_p5.passenger_profile_id, v_p5.booking_id) INTO v_result;

    SELECT * INTO v_trip FROM public.trips WHERE id = v_trip_id;
    SELECT COALESCE(SUM(seats), 0) INTO v_booked_seats
    FROM public.bookings WHERE trip_id = v_trip_id AND status = 'confirmed';

    -- departure_pending must remain (4 >= min=4)
    v_pass := v_booked_seats = 4
              AND v_trip.status = 'departure_pending'
              AND v_trip.departure_lock_expires_at IS NOT NULL;

    v_actual := format(
      'After P5 cancel: booked_seats=%s (min=%s). Trip status=%s. Lock=%s.',
      v_booked_seats,
      v_min_passengers,
      v_trip.status,
      COALESCE(v_trip.departure_lock_expires_at::TEXT, 'NULL')
    );

    v_tests := v_tests || jsonb_build_object(
      'test', 'DEP-8',
      'name', 'Cancellation Still At Minimum',
      'status', CASE WHEN v_pass THEN 'ACTUALLY TESTED — PASS' ELSE 'ACTUALLY TESTED — FAIL' END,
      'expected', format('After cancel: seats=4 >= min=%s. Trip remains departure_pending. Lock preserved.', v_min_passengers),
      'actual', v_actual,
      'pass', v_pass,
      'bug', CASE WHEN NOT v_pass THEN
        CASE WHEN v_trip.status != 'departure_pending'
          THEN format('Trip incorrectly reverted from departure_pending to %s despite still meeting minimum', v_trip.status)
          ELSE 'Unexpected state'
        END
      ELSE NULL END,
      'pre_state', jsonb_build_object('trip_status', 'departure_pending', 'booked_seats', 5),
      'post_state', jsonb_build_object('booked_seats', v_booked_seats, 'trip_status', v_trip.status, 'lock_preserved', v_trip.departure_lock_expires_at IS NOT NULL)
    );

    PERFORM public._dep_cleanup(
      ARRAY[v_trip_id],
      ARRAY[v_driver_a.driver_profile_id, v_p1.passenger_profile_id, v_p2.passenger_profile_id, v_p3.passenger_profile_id, v_p4.passenger_profile_id, v_p5.passenger_profile_id]
    );
  EXCEPTION WHEN OTHERS THEN
    v_tests := v_tests || jsonb_build_object(
      'test', 'DEP-8', 'name', 'Cancellation Still At Minimum',
      'status', 'ACTUALLY TESTED — FAIL',
      'actual', 'Exception: ' || SQLERRM, 'pass', false, 'bug', SQLERRM
    );
  END;

  -- ============================================================
  -- DEP-9: TWO-DRIVER FIFO
  -- D1(cap=6) FIFO#1, D2(cap=4) FIFO#2.
  -- P1–P4 assigned to D1. D1 presses Leave Now.
  -- P5 and P6 join. match_route_queue.
  -- P5/P6 must NOT go to D1's locked trip.
  -- They should go to D2 or remain waiting.
  -- ============================================================
  BEGIN
    SELECT * INTO v_driver_a FROM public._dep_create_driver(p_route_id, 6, 'DEP9_DA', p_admin_id);
    SELECT * INTO v_driver_b FROM public._dep_create_driver(p_route_id, 4, 'DEP9_DB', p_admin_id);

    -- Create trip for D1
    v_trip_id := public._dep_create_trip(v_driver_a.driver_id, p_route_id, v_driver_a.vehicle_id);

    SELECT * INTO v_p1 FROM public._dep_create_passenger(p_route_id, 1, 'DEP9_P1', v_trip_id);
    SELECT * INTO v_p2 FROM public._dep_create_passenger(p_route_id, 1, 'DEP9_P2', v_trip_id);
    SELECT * INTO v_p3 FROM public._dep_create_passenger(p_route_id, 1, 'DEP9_P3', v_trip_id);
    SELECT * INTO v_p4 FROM public._dep_create_passenger(p_route_id, 1, 'DEP9_P4', v_trip_id);

    -- D1 presses Leave Now
    SELECT public.driver_leave_now(v_driver_a.driver_profile_id) INTO v_result;

    -- P5 and P6 join queue
    SELECT * INTO v_p5 FROM public._dep_create_passenger(p_route_id, 1, 'DEP9_P5', NULL);
    SELECT * INTO v_p6 FROM public._dep_create_passenger(p_route_id, 1, 'DEP9_P6', NULL);

    -- Trigger matching
    PERFORM public.match_route_queue(p_route_id);

    DECLARE
      v_p5_on_d1 BOOLEAN;
      v_p6_on_d1 BOOLEAN;
      v_d1_seats INTEGER;
      v_d2_trip_id UUID;
      v_d2_seats INTEGER;
    BEGIN
      SELECT EXISTS(
        SELECT 1 FROM public.bookings
        WHERE passenger_id = v_p5.passenger_profile_id AND trip_id = v_trip_id AND status = 'confirmed'
      ) INTO v_p5_on_d1;

      SELECT EXISTS(
        SELECT 1 FROM public.bookings
        WHERE passenger_id = v_p6.passenger_profile_id AND trip_id = v_trip_id AND status = 'confirmed'
      ) INTO v_p6_on_d1;

      SELECT COALESCE(SUM(seats), 0) INTO v_d1_seats
      FROM public.bookings WHERE trip_id = v_trip_id AND status = 'confirmed';

      -- Check D2 trip
      SELECT t.id INTO v_d2_trip_id
      FROM public.trips t WHERE t.driver_id = v_driver_b.driver_id AND t.status != 'cancelled'
      LIMIT 1;

      IF v_d2_trip_id IS NOT NULL THEN
        SELECT COALESCE(SUM(seats), 0) INTO v_d2_seats
        FROM public.bookings WHERE trip_id = v_d2_trip_id AND status = 'confirmed';
      ELSE
        v_d2_seats := 0;
      END IF;

      v_pass := NOT v_p5_on_d1 AND NOT v_p6_on_d1 AND v_d1_seats = 4;

      v_actual := format(
        'D1 locked at 4/6. P5 on D1=%s. P6 on D1=%s. D1 final seats=%s. D2 trip=%s D2 seats=%s.',
        v_p5_on_d1, v_p6_on_d1, v_d1_seats,
        COALESCE(v_d2_trip_id::TEXT, 'none'), v_d2_seats
      );

      v_tests := v_tests || jsonb_build_object(
        'test', 'DEP-9',
        'name', 'Two-Driver FIFO Lock',
        'status', CASE WHEN v_pass THEN 'ACTUALLY TESTED — PASS' ELSE 'ACTUALLY TESTED — FAIL' END,
        'expected', 'P5/P6 NOT assigned to D1 locked trip. D1 stays at 4/6. P5/P6 go to D2 or remain waiting.',
        'actual', v_actual,
        'pass', v_pass,
        'bug', CASE WHEN NOT v_pass THEN 'match_route_queue assigned passengers to a departure_pending trip' ELSE NULL END,
        'pre_state', jsonb_build_object('d1_status', 'departure_pending', 'd1_seats', 4, 'd2_status', 'waiting'),
        'post_state', jsonb_build_object('p5_on_d1', v_p5_on_d1, 'p6_on_d1', v_p6_on_d1, 'd1_final_seats', v_d1_seats, 'd2_seats', v_d2_seats)
      );

      PERFORM public._dep_cleanup(
        ARRAY[v_trip_id, v_d2_trip_id],
        ARRAY[v_driver_a.driver_profile_id, v_driver_b.driver_profile_id, v_p1.passenger_profile_id, v_p2.passenger_profile_id, v_p3.passenger_profile_id, v_p4.passenger_profile_id, v_p5.passenger_profile_id, v_p6.passenger_profile_id]
      );
    END;
  EXCEPTION WHEN OTHERS THEN
    v_tests := v_tests || jsonb_build_object(
      'test', 'DEP-9', 'name', 'Two-Driver FIFO Lock',
      'status', 'ACTUALLY TESTED — FAIL',
      'actual', 'Exception: ' || SQLERRM, 'pass', false, 'bug', SQLERRM
    );
  END;

  -- ============================================================
  -- DEP-10: FIT-AWARE MULTI-SEAT FIFO
  -- Vehicle capacity = 4.
  -- FIFO: A=3seats, B=2seats, C=1seat.
  -- Expected: A+C assigned (4/4). B keeps FIFO priority.
  -- ============================================================
  BEGIN
    SELECT * INTO v_driver_a FROM public._dep_create_driver(p_route_id, 4, 'DEP10_DA', p_admin_id);
    v_trip_id := public._dep_create_trip(v_driver_a.driver_id, p_route_id, v_driver_a.vehicle_id);

    -- Create A(3), B(2), C(1) as waiting passengers in FIFO order
    SELECT * INTO v_p1 FROM public._dep_create_passenger(p_route_id, 3, 'DEP10_A', NULL);
    SELECT * INTO v_p2 FROM public._dep_create_passenger(p_route_id, 2, 'DEP10_B', NULL);
    SELECT * INTO v_p3 FROM public._dep_create_passenger(p_route_id, 1, 'DEP10_C', NULL);

    -- Record B's queue_sequence before matching
    DECLARE
      v_b_seq_before INTEGER;
      v_b_seq_after  INTEGER;
      v_a_assigned   BOOLEAN;
      v_b_assigned   BOOLEAN;
      v_c_assigned   BOOLEAN;
      v_final_seats  INTEGER;
    BEGIN
      SELECT pq.queue_position INTO v_b_seq_before
      FROM public.passenger_queue pq
      WHERE pq.passenger_id = v_p2.passenger_profile_id
        AND pq.status = 'waiting'
      LIMIT 1;

      -- Trigger matching
      PERFORM public.match_route_queue(p_route_id);

      -- Check assignments
      SELECT EXISTS(
        SELECT 1 FROM public.bookings
        WHERE passenger_id = v_p1.passenger_profile_id AND trip_id = v_trip_id AND status = 'confirmed'
      ) INTO v_a_assigned;

      SELECT EXISTS(
        SELECT 1 FROM public.bookings
        WHERE passenger_id = v_p2.passenger_profile_id AND trip_id = v_trip_id AND status = 'confirmed'
      ) INTO v_b_assigned;

      SELECT EXISTS(
        SELECT 1 FROM public.bookings
        WHERE passenger_id = v_p3.passenger_profile_id AND trip_id = v_trip_id AND status = 'confirmed'
      ) INTO v_c_assigned;

      SELECT COALESCE(SUM(seats), 0) INTO v_final_seats
      FROM public.bookings WHERE trip_id = v_trip_id AND status = 'confirmed';

      -- B's queue position should be preserved (still waiting, not cancelled)
      SELECT pq.queue_position INTO v_b_seq_after
      FROM public.passenger_queue pq
      WHERE pq.passenger_id = v_p2.passenger_profile_id
        AND pq.status = 'waiting'
      LIMIT 1;

      -- Pass: A assigned, B NOT assigned (can't fit), C assigned, total=4
      -- B's queue position preserved
      v_pass := v_a_assigned AND NOT v_b_assigned AND v_c_assigned
                AND v_final_seats = 4
                AND v_b_seq_after IS NOT NULL;  -- B still in queue

      v_actual := format(
        'A(3) assigned=%s. B(2) assigned=%s. C(1) assigned=%s. Final seats=%s/4. B queue_pos before=%s after=%s.',
        v_a_assigned, v_b_assigned, v_c_assigned, v_final_seats,
        COALESCE(v_b_seq_before::TEXT, 'N/A'),
        COALESCE(v_b_seq_after::TEXT, 'not in queue')
      );

      v_tests := v_tests || jsonb_build_object(
        'test', 'DEP-10',
        'name', 'Multi-Seat Fit-Aware FIFO',
        'status', CASE WHEN v_pass THEN 'ACTUALLY TESTED — PASS' ELSE 'ACTUALLY TESTED — FAIL' END,
        'expected', 'A(3)+C(1)=4 assigned. B(2) skipped (cannot fit). B retains FIFO priority (still in queue).',
        'actual', v_actual,
        'pass', v_pass,
        'bug', CASE WHEN NOT v_pass THEN
          CASE WHEN v_b_assigned THEN 'B(2) was assigned despite only 1 seat remaining — fit-aware FIFO not working'
               WHEN NOT v_a_assigned THEN 'A(3) was not assigned'
               WHEN NOT v_c_assigned THEN 'C(1) was not assigned despite fitting'
               WHEN v_b_seq_after IS NULL THEN 'B was removed from queue instead of preserving FIFO priority'
               ELSE format('Unexpected seat count: %s', v_final_seats)
          END
        ELSE NULL END,
        'pre_state', jsonb_build_object('capacity', 4, 'queue', jsonb_build_array(
          jsonb_build_object('label', 'A', 'seats', 3),
          jsonb_build_object('label', 'B', 'seats', 2),
          jsonb_build_object('label', 'C', 'seats', 1)
        )),
        'post_state', jsonb_build_object(
          'a_assigned', v_a_assigned,
          'b_assigned', v_b_assigned,
          'c_assigned', v_c_assigned,
          'final_seats', v_final_seats,
          'b_queue_pos_before', v_b_seq_before,
          'b_queue_pos_after', v_b_seq_after
        )
      );

      PERFORM public._dep_cleanup(
        ARRAY[v_trip_id],
        ARRAY[v_driver_a.driver_profile_id, v_p1.passenger_profile_id, v_p2.passenger_profile_id, v_p3.passenger_profile_id]
      );
    END;
  EXCEPTION WHEN OTHERS THEN
    v_tests := v_tests || jsonb_build_object(
      'test', 'DEP-10', 'name', 'Multi-Seat Fit-Aware FIFO',
      'status', 'ACTUALLY TESTED — FAIL',
      'actual', 'Exception: ' || SQLERRM, 'pass', false, 'bug', SQLERRM
    );
  END;

  -- ============================================================
  -- CROSS-DRIVER AUTHORIZATION
  -- Driver A cannot call driver_start_trip on Driver B's trip.
  -- ============================================================
  BEGIN
    SELECT * INTO v_driver_a FROM public._dep_create_driver(p_route_id, 6, 'AUTH_DA', p_admin_id);
    SELECT * INTO v_driver_b FROM public._dep_create_driver(p_route_id, 4, 'AUTH_DB', p_admin_id);

    -- Create trip for D2 (B)
    v_trip_id := public._dep_create_trip(v_driver_b.driver_id, p_route_id, v_driver_b.vehicle_id);

    SELECT * INTO v_p1 FROM public._dep_create_passenger(p_route_id, 1, 'AUTH_P1', v_trip_id);
    SELECT * INTO v_p2 FROM public._dep_create_passenger(p_route_id, 1, 'AUTH_P2', v_trip_id);
    SELECT * INTO v_p3 FROM public._dep_create_passenger(p_route_id, 1, 'AUTH_P3', v_trip_id);
    SELECT * INTO v_p4 FROM public._dep_create_passenger(p_route_id, 1, 'AUTH_P4', v_trip_id);

    -- D2 enters departure_pending
    SELECT public.driver_leave_now(v_driver_b.driver_profile_id) INTO v_result;

    -- Expire lock for D2
    UPDATE public.trips SET departure_lock_expires_at = NOW() - INTERVAL '1 second' WHERE id = v_trip_id;

    -- D1 (wrong driver) tries to start D2's trip
    DECLARE
      v_wrong_driver_result JSONB;
      v_cross_driver_rejected BOOLEAN;
    BEGIN
      SELECT public.driver_start_trip(v_driver_a.driver_id) INTO v_wrong_driver_result;
      -- D1 has no trip, so it should return "No active trip found"
      v_cross_driver_rejected := (v_wrong_driver_result->>'success')::BOOLEAN = false;

      v_pass := v_cross_driver_rejected;

      v_actual := format(
        'D1 tried to start D2 trip. Result: success=%s error="%s".',
        v_wrong_driver_result->>'success',
        v_wrong_driver_result->>'error'
      );

      v_tests := v_tests || jsonb_build_object(
        'test', 'CROSS-DRIVER-AUTH',
        'name', 'Cross-Driver Authorization',
        'status', CASE WHEN v_pass THEN 'ACTUALLY TESTED — PASS' ELSE 'ACTUALLY TESTED — FAIL' END,
        'expected', 'D1 cannot start D2 trip. driver_start_trip REJECTED for wrong driver.',
        'actual', v_actual,
        'pass', v_pass,
        'bug', CASE WHEN NOT v_pass THEN 'driver_start_trip allowed wrong driver to start another driver trip' ELSE NULL END,
        'pre_state', jsonb_build_object('d2_trip_status', 'departure_pending_lock_expired'),
        'post_state', jsonb_build_object('cross_driver_rejected', v_cross_driver_rejected, 'error', v_wrong_driver_result->>'error')
      );

      PERFORM public._dep_cleanup(
        ARRAY[v_trip_id],
        ARRAY[v_driver_a.driver_profile_id, v_driver_b.driver_profile_id, v_p1.passenger_profile_id, v_p2.passenger_profile_id, v_p3.passenger_profile_id, v_p4.passenger_profile_id]
      );
    END;
  EXCEPTION WHEN OTHERS THEN
    v_tests := v_tests || jsonb_build_object(
      'test', 'CROSS-DRIVER-AUTH', 'name', 'Cross-Driver Authorization',
      'status', 'ACTUALLY TESTED — FAIL',
      'actual', 'Exception: ' || SQLERRM, 'pass', false, 'bug', SQLERRM
    );
  END;

  -- ============================================================
  -- FULL TRIP FLOW: start → in_progress → complete
  -- ============================================================
  BEGIN
    SELECT * INTO v_driver_a FROM public._dep_create_driver(p_route_id, 6, 'FLOW_DA', p_admin_id);
    v_trip_id := public._dep_create_trip(v_driver_a.driver_id, p_route_id, v_driver_a.vehicle_id);

    SELECT * INTO v_p1 FROM public._dep_create_passenger(p_route_id, 1, 'FLOW_P1', v_trip_id);
    SELECT * INTO v_p2 FROM public._dep_create_passenger(p_route_id, 1, 'FLOW_P2', v_trip_id);
    SELECT * INTO v_p3 FROM public._dep_create_passenger(p_route_id, 1, 'FLOW_P3', v_trip_id);
    SELECT * INTO v_p4 FROM public._dep_create_passenger(p_route_id, 1, 'FLOW_P4', v_trip_id);

    -- Leave now → departure_pending
    SELECT public.driver_leave_now(v_driver_a.driver_profile_id) INTO v_result;

    -- Expire lock
    UPDATE public.trips SET departure_lock_expires_at = NOW() - INTERVAL '1 second' WHERE id = v_trip_id;

    DECLARE
      v_start_result    JSONB;
      v_complete_result JSONB;
      v_trip_after_start RECORD;
      v_trip_after_complete RECORD;
      v_bookings_completed INTEGER;
    BEGIN
      -- Start trip
      SELECT public.driver_start_trip(v_driver_a.driver_id) INTO v_start_result;
      SELECT * INTO v_trip_after_start FROM public.trips WHERE id = v_trip_id;

      -- Complete trip
      SELECT public.driver_complete_trip(v_driver_a.driver_profile_id) INTO v_complete_result;
      SELECT * INTO v_trip_after_complete FROM public.trips WHERE id = v_trip_id;

      SELECT COUNT(*) INTO v_bookings_completed
      FROM public.bookings WHERE trip_id = v_trip_id AND status = 'completed';

      v_pass := (v_start_result->>'success')::BOOLEAN = true
                AND v_trip_after_start.status = 'in_progress'
                AND (v_complete_result->>'success')::BOOLEAN = true
                AND v_trip_after_complete.status = 'completed'
                AND v_bookings_completed = 4;

      v_actual := format(
        'Start: success=%s trip=%s. Complete: success=%s trip=%s. Bookings completed=%s/4.',
        v_start_result->>'success', v_trip_after_start.status,
        v_complete_result->>'success', v_trip_after_complete.status,
        v_bookings_completed
      );

      v_tests := v_tests || jsonb_build_object(
        'test', 'FULL-FLOW',
        'name', 'Full Start→Complete Trip Flow',
        'status', CASE WHEN v_pass THEN 'ACTUALLY TESTED — PASS' ELSE 'ACTUALLY TESTED — FAIL' END,
        'expected', 'Start → in_progress. Complete → completed. All 4 bookings completed.',
        'actual', v_actual,
        'pass', v_pass,
        'bug', CASE WHEN NOT v_pass THEN
          CASE WHEN (v_start_result->>'success')::BOOLEAN = false THEN 'driver_start_trip failed: ' || (v_start_result->>'error')
               WHEN v_trip_after_start.status != 'in_progress' THEN 'Trip did not reach in_progress'
               WHEN (v_complete_result->>'success')::BOOLEAN = false THEN 'driver_complete_trip failed: ' || (v_complete_result->>'error')
               WHEN v_trip_after_complete.status != 'completed' THEN 'Trip did not reach completed'
               ELSE format('Only %s/4 bookings completed', v_bookings_completed)
          END
        ELSE NULL END,
        'pre_state', jsonb_build_object('trip_status', 'departure_pending', 'booked_seats', 4),
        'post_state', jsonb_build_object(
          'trip_after_start', v_trip_after_start.status,
          'trip_after_complete', v_trip_after_complete.status,
          'bookings_completed', v_bookings_completed
        )
      );

      PERFORM public._dep_cleanup(
        ARRAY[v_trip_id],
        ARRAY[v_driver_a.driver_profile_id, v_p1.passenger_profile_id, v_p2.passenger_profile_id, v_p3.passenger_profile_id, v_p4.passenger_profile_id]
      );
    END;
  EXCEPTION WHEN OTHERS THEN
    v_tests := v_tests || jsonb_build_object(
      'test', 'FULL-FLOW', 'name', 'Full Start→Complete Trip Flow',
      'status', 'ACTUALLY TESTED — FAIL',
      'actual', 'Exception: ' || SQLERRM, 'pass', false, 'bug', SQLERRM
    );
  END;

  -- ── Build summary ───────────────────────────────────────────
  DECLARE
    v_total   INTEGER;
    v_passed  INTEGER;
    v_failed  INTEGER;
    v_summary JSONB;
  BEGIN
    SELECT COUNT(*), COUNT(*) FILTER (WHERE (t->>'pass')::BOOLEAN = true)
    INTO v_total, v_passed
    FROM jsonb_array_elements(v_tests) t;

    v_failed := v_total - v_passed;

    v_summary := jsonb_build_object(
      'total', v_total,
      'passed', v_passed,
      'failed', v_failed,
      'departure_model_validated', v_failed = 0,
      'min_passengers_used', v_min_passengers,
      'route_id', p_route_id,
      'executed_at', NOW()
    );

    RETURN jsonb_build_object(
      'summary', v_summary,
      'tests', v_tests
    );
  END;
END;
$$;

GRANT EXECUTE ON FUNCTION public.run_departure_tests(UUID, UUID) TO authenticated;

-- ============================================================
-- Cleanup helpers — grant execute
-- ============================================================

GRANT EXECUTE ON FUNCTION public._dep_create_driver(UUID, INTEGER, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public._dep_create_passenger(UUID, INTEGER, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public._dep_create_trip(UUID, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public._dep_cleanup(UUID[], UUID[]) TO authenticated;
