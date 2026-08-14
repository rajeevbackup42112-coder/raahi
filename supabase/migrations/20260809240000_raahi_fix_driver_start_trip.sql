-- ============================================================
-- RAAHI — Fix driver_start_trip for departure_pending
-- Migration: 20260809240000_raahi_fix_driver_start_trip.sql
-- ============================================================
-- Root cause:
--   driver_start_trip (stage3) only looked for trips with status
--   IN ('full', 'ready', 'accepting_bookings').
--   After departure_eligibility migration, the trip is in
--   'departure_pending' state — so driver_start_trip always
--   returned "No active trip found", making it impossible to
--   ever start a trip.
--
-- Also missing: departure_lock_expires_at enforcement.
--   The RPC must REJECT if the lock window has not yet expired.
--
-- Also fixed:
--   get_test_harness_state — include departure_pending trips
--   admin_reset_test_data  — cancel departure_pending trips too
-- ============================================================

-- ============================================================
-- FIX 1: driver_start_trip
-- Now accepts departure_pending trips.
-- Rejects if departure_lock_expires_at has not yet passed.
-- Also validates minimum occupancy is still met (cancellation
-- recheck may have revoked eligibility).
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
  v_route          RECORD;
  v_booked_seats   INTEGER;
  v_min_passengers INTEGER;
  v_now            TIMESTAMPTZ := NOW();
BEGIN
  -- Find the driver's active departure_pending trip
  SELECT t.*
  INTO v_trip
  FROM public.trips t
  WHERE t.driver_id = p_driver_id
    AND t.status = 'departure_pending'
  ORDER BY t.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    -- Fallback: also accept legacy status names in case of old data
    SELECT t.*
    INTO v_trip
    FROM public.trips t
    WHERE t.driver_id = p_driver_id
      AND t.status IN ('boarding', 'full', 'ready', 'accepting_bookings')
    ORDER BY t.created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'No active trip found. Press Leave Now first to initiate departure.'
      );
    END IF;

    -- Legacy path: no lock check needed, start immediately
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
      jsonb_build_object('driver_id', p_driver_id),
      'Trip started by driver (legacy path)');

    RETURN jsonb_build_object('success', true, 'trip_id', v_trip.id, 'message', 'Trip started');
  END IF;

  -- ── departure_pending path ──────────────────────────────────

  -- GUARD 1: Departure lock must have expired
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
  -- (a passenger may have cancelled during the lock window)
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

  INSERT INTO public.audit_logs (action, target_table, target_id, new_value, notes)
  VALUES ('trip_started'::public.audit_action, 'trips', v_trip.id,
    jsonb_build_object('driver_id', p_driver_id, 'booked_seats', v_booked_seats),
    'Trip started by driver after departure lock');

  RETURN jsonb_build_object(
    'success', true,
    'trip_id', v_trip.id,
    'message', 'Trip started',
    'booked_seats', v_booked_seats
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.driver_start_trip(UUID) TO authenticated;

-- ============================================================
-- FIX 2: get_test_harness_state — include departure_pending
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
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin'
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('error', 'Admin only');
  END IF;

  RETURN jsonb_build_object(
    'passenger_queue', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', pq.id,
          'passenger_name', COALESCE(pr.name, 'Unknown'),
          'seat_count', pq.seats_requested,
          'status', UPPER(pq.status::TEXT),
          'queue_position', pq.queue_position,
          'joined_at', pq.joined_at,
          'is_test_data', COALESCE(pq.is_test_data, false)
        )
        ORDER BY pq.queue_position ASC NULLS LAST, pq.joined_at ASC
      )
      FROM public.passenger_queue pq
      JOIN public.profiles pr ON pr.id = pq.passenger_id
      WHERE pq.route_id = p_route_id
        AND pq.status NOT IN ('cancelled', 'completed')
    ),
    'driver_queue', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', dq.id,
          'driver_name', COALESCE(pr.name, 'Unknown'),
          'capacity', COALESCE(v.seating_capacity, 0),
          'status', dq.status,
          'queue_position', dq.queue_position,
          'offered_at', dq.offered_at,
          'offer_expires_at', dq.offer_expires_at,
          'provisional_trip_id', dq.provisional_trip_id,
          'is_test_data', COALESCE(dq.is_test_data, false)
        )
        ORDER BY dq.queue_position ASC NULLS LAST, dq.joined_at ASC
      )
      FROM public.driver_queue dq
      JOIN public.drivers d ON d.id = dq.driver_id
      JOIN public.profiles pr ON pr.id = d.profile_id
      LEFT JOIN public.vehicles v ON v.id = d.current_vehicle_id
      WHERE dq.route_id = p_route_id
        AND dq.status NOT IN ('cancelled', 'completed')
    ),
    'current_trips', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'trip_id', t.id,
          'driver_name', COALESCE(pr.name, 'No driver'),
          'status', t.status,
          'passenger_count', (
            SELECT COALESCE(SUM(b.seats), 0)
            FROM public.bookings b
            WHERE b.trip_id = t.id AND b.status = 'confirmed'
          ),
          'vehicle_capacity', COALESCE(v.seating_capacity, 0),
          'departure_lock_expires_at', t.departure_lock_expires_at,
          'departure_lock_remaining_seconds', CASE
            WHEN t.departure_lock_expires_at IS NOT NULL AND t.departure_lock_expires_at > NOW()
            THEN EXTRACT(EPOCH FROM (t.departure_lock_expires_at - NOW()))::INTEGER
            ELSE 0
          END,
          'notes', CASE
            WHEN t.status = 'departure_pending' THEN 'DEPARTURE LOCK ACTIVE'
            WHEN t.status = 'boarding' THEN 'Boarding'
            WHEN t.status = 'in_progress' THEN 'In Progress'
            ELSE t.status::TEXT
          END,
          'is_test_data', COALESCE(t.is_test_data, false)
        )
        ORDER BY t.created_at DESC
      )
      FROM public.trips t
      LEFT JOIN public.drivers d ON d.id = t.driver_id
      LEFT JOIN public.profiles pr ON pr.id = d.profile_id
      LEFT JOIN public.vehicles v ON v.id = t.vehicle_id
      WHERE t.route_id = p_route_id
        -- Include departure_pending in active trip states
        AND t.status IN ('accepting_bookings', 'full', 'ready', 'boarding', 'departure_pending', 'in_progress')
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_test_harness_state(UUID, UUID) TO authenticated;

-- ============================================================
-- FIX 3: admin_reset_test_data — cancel departure_pending trips
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
  v_is_admin          BOOLEAN;
  v_pq_deleted        INTEGER := 0;
  v_dq_deleted        INTEGER := 0;
  v_trips_cancelled   INTEGER := 0;
  v_bookings_deleted  INTEGER := 0;
  v_profiles_deleted  INTEGER := 0;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin'
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('error', 'Admin only');
  END IF;

  -- Cancel test trips (including departure_pending)
  UPDATE public.trips
  SET status = 'cancelled', updated_at = NOW()
  WHERE route_id = p_route_id
    AND is_test_data = true
    AND status NOT IN ('cancelled', 'completed');
  GET DIAGNOSTICS v_trips_cancelled = ROW_COUNT;

  -- Cancel test passenger queue entries
  UPDATE public.passenger_queue
  SET status = 'cancelled', updated_at = NOW()
  WHERE route_id = p_route_id
    AND is_test_data = true
    AND status NOT IN ('cancelled', 'completed');
  GET DIAGNOSTICS v_pq_deleted = ROW_COUNT;

  -- Cancel test driver queue entries
  UPDATE public.driver_queue
  SET status = 'cancelled', completed_at = NOW()
  WHERE route_id = p_route_id
    AND is_test_data = true
    AND status NOT IN ('cancelled', 'completed');
  GET DIAGNOSTICS v_dq_deleted = ROW_COUNT;

  -- Cancel test bookings
  UPDATE public.bookings
  SET status = 'cancelled', updated_at = NOW()
  WHERE route_id = p_route_id
    AND is_test_data = true
    AND status != 'cancelled';
  GET DIAGNOSTICS v_bookings_deleted = ROW_COUNT;

  -- Reset test driver availability
  UPDATE public.drivers
  SET availability_status = 'offline',
      current_route_id = NULL
  WHERE is_test_data = true;

  -- Log
  INSERT INTO public.audit_logs (action, target_table, target_id, new_value, notes)
  VALUES (
    'test_data_reset'::public.audit_action,
    'routes',
    p_route_id,
    jsonb_build_object(
      'pq_cancelled', v_pq_deleted,
      'dq_cancelled', v_dq_deleted,
      'trips_cancelled', v_trips_cancelled,
      'bookings_cancelled', v_bookings_deleted
    ),
    'Test data reset by admin'
  );

  RETURN jsonb_build_object(
    'success', true,
    'passenger_queue_deleted', v_pq_deleted,
    'driver_queue_deleted', v_dq_deleted,
    'trips_cancelled', v_trips_cancelled,
    'bookings_deleted', v_bookings_deleted
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_reset_test_data(UUID, UUID) TO authenticated;

-- ============================================================
-- FIX 4: admin_simulate_driver_action — add 'leave_now' action
-- Allows test harness to call driver_leave_now on behalf of a
-- test driver (for departure eligibility tests).
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_simulate_driver_action(
  p_driver_queue_id UUID,
  p_action TEXT,   -- 'accept' | 'decline' | 'expire' | 'leave_now' | 'start_trip'
  p_admin_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin      BOOLEAN;
  v_dq            RECORD;
  v_driver        RECORD;
  v_result        JSONB;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin'
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('error', 'Admin only');
  END IF;

  SELECT dq.*, d.profile_id AS driver_profile_id, d.id AS driver_id_val
  INTO v_dq
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  WHERE dq.id = p_driver_queue_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Driver queue entry not found');
  END IF;

  IF p_action = 'accept' THEN
    SELECT public.driver_accept_offer(v_dq.driver_profile_id, p_driver_queue_id) INTO v_result;
    RETURN v_result;

  ELSIF p_action = 'decline' THEN
    SELECT public.driver_decline_offer(v_dq.driver_profile_id, p_driver_queue_id) INTO v_result;
    RETURN v_result;

  ELSIF p_action = 'expire' THEN
    -- Force-expire the offer
    UPDATE public.driver_queue
    SET offer_expires_at = NOW() - INTERVAL '1 second'
    WHERE id = p_driver_queue_id;

    SELECT public.driver_decline_offer(v_dq.driver_profile_id, p_driver_queue_id) INTO v_result;
    RETURN jsonb_build_object('success', true, 'action', 'expired', 'decline_result', v_result);

  ELSIF p_action = 'leave_now' THEN
    -- Simulate driver pressing Leave Now
    SELECT public.driver_leave_now(v_dq.driver_profile_id) INTO v_result;
    RETURN v_result;

  ELSIF p_action = 'start_trip' THEN
    -- Simulate driver pressing Start Trip (after lock expires)
    SELECT public.driver_start_trip(v_dq.driver_id_val) INTO v_result;
    RETURN v_result;

  ELSE
    RETURN jsonb_build_object('error', format('Unknown action: %s', p_action));
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_simulate_driver_action(UUID, TEXT, UUID) TO authenticated;
