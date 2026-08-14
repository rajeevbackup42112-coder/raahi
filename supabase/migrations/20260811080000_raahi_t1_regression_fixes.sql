-- ============================================================
-- RAAHI — Test 1 Regression Fixes
-- Migration: 20260811080000_raahi_t1_regression_fixes.sql
-- Version: 59
-- ============================================================
-- Fixes:
--
-- T1-BUG-01 (Frontend only — no DB change needed):
--   AdminUsersClient.tsx was calling convert_user_to_driver with
--   p_admin_id which the deployed RPC (migration 280000) does not
--   accept. Fixed in AdminUsersClient.tsx — no migration required.
--
-- T1-BUG-02: get_driver_queue_status 55000 error
--   ROOT CAUSE: v_trip RECORD is only populated inside the
--   "IF v_queue_entry.provisional_trip_id IS NOT NULL" block.
--   When a driver is in 'waiting' state (no provisional trip yet),
--   provisional_trip_id IS NULL, so the SELECT INTO v_trip is skipped.
--   Later code unconditionally accesses v_trip.id, v_trip.status,
--   v_trip.departure_lock_expires_at — accessing fields of an
--   uninitialized RECORD raises PostgreSQL error 55000:
--   "record v_trip is not assigned yet".
--   FIX: Replace v_trip RECORD with scalar variables. Guard all
--   trip-field access with explicit NULL checks.
--
-- T1-BUG-03: Live Queue shows "No drivers online" / 0 drivers
--   ROOT CAUSE: get_route_queues_for_admin matching_status section
--   only queries driver_queue WHERE status IN ('waiting','offered').
--   When a driver is in 'active' state (activate_next_driver set
--   status='active' when driver went online with no passengers, or
--   driver has an assigned trip), v_first_driver IS NULL, so
--   matching_status returns "No drivers online" even though the
--   driver IS in the driver_queue list.
--   Additionally, the matching_status message "No drivers online"
--   is semantically wrong — it should only mean no drivers are in
--   the FIFO queue waiting for passengers. A driver with an active
--   trip is operational but not available for new matching.
--   FIX: Extend v_first_driver query to include 'active','assigned'
--   states. Add correct matching_status messages for each state.
--   Rename "No drivers online" to "No drivers in queue" when the
--   driver_queue list is empty (accurate: drivers may be online but
--   not in the FIFO waiting pool).
-- ============================================================

-- ============================================================
-- FIX T1-BUG-02: get_driver_queue_status
-- Replace uninitialized RECORD access with scalar variables
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
  v_driver              RECORD;
  v_queue_entry         RECORD;
  -- Scalar trip fields (replaces uninitialized RECORD v_trip)
  v_trip_id             UUID;
  v_trip_status         TEXT;
  v_trip_departure_lock TIMESTAMPTZ;
  v_trip_fare_per_seat  NUMERIC;
  v_trip_total_seats    INTEGER;
  v_route               RECORD;
  v_vehicle             RECORD;
  v_booked_seats        INTEGER := 0;
  v_min_passengers      INTEGER := 1;
  v_can_depart          BOOLEAN := false;
  v_lock_remaining      INTEGER := 0;
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

  -- ----------------------------------------------------------------
  -- OFFLINE FAST-PATH
  -- If driver is offline, there is no active queue entry to show.
  -- Return found=false immediately so Driver Home renders Go Online.
  -- ----------------------------------------------------------------
  IF v_driver.availability_status = 'offline' THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  -- Get active queue entry (non-terminal status only)
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

  -- ----------------------------------------------------------------
  -- LOAD TRIP SCALARS (safe — only when provisional_trip_id is set)
  -- Using scalar variables avoids the 55000 "record not assigned" error
  -- that occurred when v_trip RECORD fields were accessed after the
  -- SELECT INTO was skipped (provisional_trip_id IS NULL path).
  -- ----------------------------------------------------------------
  IF v_queue_entry.provisional_trip_id IS NOT NULL THEN
    SELECT
      t.id,
      t.status,
      t.departure_lock_expires_at,
      t.fare_per_seat,
      t.total_seats
    INTO
      v_trip_id,
      v_trip_status,
      v_trip_departure_lock,
      v_trip_fare_per_seat,
      v_trip_total_seats
    FROM public.trips t
    WHERE t.id = v_queue_entry.provisional_trip_id;

    -- ----------------------------------------------------------------
    -- TERMINAL TRIP GUARD (Version 48+ post-trip stale-state guard)
    -- If the provisional trip is already completed/cancelled, treat
    -- this queue entry as stale and return found=false.
    -- ----------------------------------------------------------------
    IF FOUND AND v_trip_status IN ('completed', 'cancelled') THEN
      RETURN jsonb_build_object('found', false);
    END IF;
  END IF;

  -- Get route
  SELECT * INTO v_route FROM public.routes WHERE id = v_queue_entry.route_id;

  -- Get vehicle
  SELECT * INTO v_vehicle FROM public.vehicles WHERE id = v_driver.current_vehicle_id;

  -- Count booked seats on the trip (only if trip exists)
  IF v_trip_id IS NOT NULL THEN
    SELECT COALESCE(SUM(b.seats), 0)
    INTO v_booked_seats
    FROM public.bookings b
    WHERE b.trip_id = v_trip_id
      AND b.status = 'confirmed';
  END IF;

  -- Get min_passengers for departure eligibility
  v_min_passengers := COALESCE(v_route.min_passengers, 1);
  v_can_depart := v_booked_seats >= v_min_passengers;

  -- Compute departure lock countdown (only if trip is departure_pending)
  IF v_trip_status = 'departure_pending' AND v_trip_departure_lock IS NOT NULL THEN
    v_lock_remaining := GREATEST(0, EXTRACT(EPOCH FROM (v_trip_departure_lock - NOW()))::INTEGER);
  END IF;

  RETURN jsonb_build_object(
    'found',                            true,
    'queue_entry_id',                   v_queue_entry.id,
    'status',                           v_queue_entry.status,
    'queue_position',                   v_queue_entry.queue_position,
    'drivers_ahead',                    GREATEST(0, COALESCE(v_queue_entry.queue_position, 1) - 1),
    'route_from',                       v_route.from_location,
    'route_to',                         v_route.to_location,
    'vehicle_make',                     v_vehicle.make,
    'vehicle_model',                    v_vehicle.model,
    'vehicle_registration',             v_vehicle.registration_number,
    'vehicle_capacity',                 v_vehicle.seating_capacity,
    'min_passengers',                   v_min_passengers,
    'booked_seats',                     v_booked_seats,
    'can_depart',                       v_can_depart,
    'is_full',                          v_booked_seats >= COALESCE(v_vehicle.seating_capacity, 4),
    'trip_id',                          v_trip_id,
    'trip_status',                      v_trip_status,
    'departure_lock_expires_at',        v_trip_departure_lock,
    'departure_lock_remaining_seconds', v_lock_remaining,
    'offered_at',                       v_queue_entry.offered_at,
    'offer_expires_at',                 v_queue_entry.offer_expires_at,
    'provisional_trip_id',              v_queue_entry.provisional_trip_id,
    'passenger_count',                  v_booked_seats,
    'total_seats',                      v_vehicle.seating_capacity,
    'fare_per_seat',                    v_route.fare_per_seat,
    'offer_timeout_seconds',            (
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
-- FIX T1-BUG-03: get_route_queues_for_admin matching_status
-- Extend v_first_driver to include 'active'/'assigned' states.
-- Replace misleading "No drivers online" with accurate labels.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_route_queues_for_admin(p_route_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_passenger_queue       JSONB;
  v_driver_queue          JSONB;
  v_current_match         JSONB;
  v_matching_status       JSONB;
  v_first_driver          RECORD;
  v_first_vehicle         RECORD;
  v_waiting_seats         INTEGER;
  v_offered_entry         RECORD;
  v_offer_seconds_remaining INTEGER;
BEGIN
  -- Passenger queue (WAITING / MATCHING / ASSIGNED)
  SELECT jsonb_agg(
    jsonb_build_object(
      'queue_id',        pq.id,
      'queue_position',  RANK() OVER (ORDER BY pq.queue_sequence ASC),
      'passenger_name',  p.name,
      'seat_count',      pq.seat_count,
      'status',          pq.status,
      'joined_at',       pq.joined_at,
      'assigned_trip_id', pq.assigned_trip_id
    ) ORDER BY pq.queue_sequence ASC
  )
  INTO v_passenger_queue
  FROM public.passenger_queue pq
  JOIN public.profiles p ON p.id = pq.passenger_id
  WHERE pq.route_id = p_route_id
    AND pq.status IN ('WAITING', 'MATCHING', 'ASSIGNED');

  -- Driver queue — all operational states
  SELECT jsonb_agg(
    jsonb_build_object(
      'queue_id',             dq.id,
      'queue_position',       RANK() OVER (ORDER BY dq.joined_at ASC),
      'driver_name',          pr.name,
      'vehicle_make',         v.make,
      'vehicle_model',        v.model,
      'vehicle_registration', v.registration_number,
      'vehicle_capacity',     v.seating_capacity,
      'status',               dq.status,
      'joined_at',            dq.joined_at,
      'offered_at',           dq.offered_at,
      'offer_expires_at',     dq.offer_expires_at,
      'provisional_trip_id',  dq.provisional_trip_id
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
    'trip_id',      t.id,
    'status',       t.status,
    'booked_seats', t.booked_seats,
    'total_seats',  t.total_seats,
    'driver_name',  pr.name,
    'fare_per_seat', t.fare_per_seat
  )
  INTO v_current_match
  FROM public.trips t
  JOIN public.drivers d ON d.id = t.driver_id
  JOIN public.profiles pr ON pr.id = d.profile_id
  WHERE t.route_id = p_route_id
    AND t.status IN ('accepting_bookings', 'full', 'ready', 'in_progress', 'scheduled', 'boarding', 'departure_pending')
    AND (t.notes IS NULL OR t.notes != 'provisional_offer')
  ORDER BY t.created_at DESC
  LIMIT 1;

  -- --------------------------------------------------------
  -- MATCHING STATUS — explains current queue state to admin
  --
  -- Priority order:
  --   1. offer_sent — a driver has been offered a trip
  --   2. active_trip — driver has an assigned/active trip
  --   3. waiting_for_passengers — driver waiting, not enough seats
  --   4. ready_to_match — enough seats to fill vehicle
  --   5. no_drivers_in_queue — no driver_queue entries at all
  --
  -- NOTE: "No drivers online" was misleading when a driver IS
  -- online but in 'active'/'assigned' state (has a trip).
  -- The correct label is "No drivers in queue" — meaning no
  -- driver is in the FIFO waiting pool for new matching.
  -- --------------------------------------------------------

  -- First check for offered driver
  SELECT dq.*, pr.name AS driver_name, v.seating_capacity, v.make, v.model
  INTO v_first_driver
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  JOIN public.profiles pr ON pr.id = d.profile_id
  LEFT JOIN public.vehicles v ON v.id = dq.vehicle_id
  WHERE dq.route_id = p_route_id
    AND dq.status = 'offered'
  ORDER BY dq.joined_at ASC
  LIMIT 1;

  IF FOUND THEN
    -- Offer is pending
    v_offer_seconds_remaining := GREATEST(0,
      EXTRACT(EPOCH FROM (v_first_driver.offer_expires_at - NOW()))::INTEGER
    );
    v_matching_status := jsonb_build_object(
      'state',            'offer_sent',
      'message',          format('Offer sent to %s — expires in %ss', v_first_driver.driver_name, v_offer_seconds_remaining),
      'driver_name',      v_first_driver.driver_name,
      'vehicle_capacity', v_first_driver.seating_capacity,
      'offer_expires_at', v_first_driver.offer_expires_at,
      'seconds_remaining', v_offer_seconds_remaining
    );
  ELSE
    -- No offered driver — check for active/assigned driver
    SELECT dq.*, pr.name AS driver_name, v.seating_capacity, v.make, v.model
    INTO v_first_driver
    FROM public.driver_queue dq
    JOIN public.drivers d ON d.id = dq.driver_id
    JOIN public.profiles pr ON pr.id = d.profile_id
    LEFT JOIN public.vehicles v ON v.id = dq.vehicle_id
    WHERE dq.route_id = p_route_id
      AND dq.status IN ('assigned', 'active')
    ORDER BY dq.joined_at ASC
    LIMIT 1;

    IF FOUND THEN
      -- Driver has an active trip — not available for new matching
      v_matching_status := jsonb_build_object(
        'state',            'active_trip',
        'message',          format('%s is on an active trip — not available for new matching', v_first_driver.driver_name),
        'driver_name',      v_first_driver.driver_name,
        'vehicle_capacity', v_first_driver.seating_capacity
      );
    ELSE
      -- Check for waiting driver
      SELECT dq.*, pr.name AS driver_name, v.seating_capacity, v.make, v.model
      INTO v_first_driver
      FROM public.driver_queue dq
      JOIN public.drivers d ON d.id = dq.driver_id
      JOIN public.profiles pr ON pr.id = d.profile_id
      LEFT JOIN public.vehicles v ON v.id = dq.vehicle_id
      WHERE dq.route_id = p_route_id
        AND dq.status = 'waiting'
      ORDER BY dq.joined_at ASC
      LIMIT 1;

      SELECT COALESCE(SUM(seat_count), 0)::INTEGER INTO v_waiting_seats
      FROM public.passenger_queue
      WHERE route_id = p_route_id AND status = 'WAITING';

      IF v_first_driver IS NULL THEN
        -- No driver in queue at all
        -- (Driver may be online/available_status=online but not in driver_queue)
        v_matching_status := jsonb_build_object(
          'state',   'no_drivers_in_queue',
          'message', 'No drivers in queue for this route'
        );
      ELSIF v_waiting_seats < v_first_driver.seating_capacity THEN
        v_matching_status := jsonb_build_object(
          'state',            'waiting_for_passengers',
          'message',          format(
            'Waiting for %s more seat(s) to fill %s''s %s %s (%s-seat vehicle)',
            v_first_driver.seating_capacity - v_waiting_seats,
            v_first_driver.driver_name,
            v_first_driver.make,
            v_first_driver.model,
            v_first_driver.seating_capacity
          ),
          'driver_name',      v_first_driver.driver_name,
          'vehicle_capacity', v_first_driver.seating_capacity,
          'waiting_seats',    v_waiting_seats,
          'seats_needed',     v_first_driver.seating_capacity - v_waiting_seats
        );
      ELSE
        v_matching_status := jsonb_build_object(
          'state',            'ready_to_match',
          'message',          format(
            'Ready to match — %s waiting seats for %s-seat vehicle',
            v_waiting_seats,
            v_first_driver.seating_capacity
          ),
          'driver_name',      v_first_driver.driver_name,
          'vehicle_capacity', v_first_driver.seating_capacity,
          'waiting_seats',    v_waiting_seats
        );
      END IF;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'passenger_queue', COALESCE(v_passenger_queue, '[]'::JSONB),
    'driver_queue',    COALESCE(v_driver_queue, '[]'::JSONB),
    'current_match',   v_current_match,
    'matching_status', v_matching_status
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_route_queues_for_admin(UUID) TO authenticated;

-- ============================================================
-- VERIFICATION NOTES
-- ============================================================
-- T1-BUG-01: Fixed in AdminUsersClient.tsx (frontend only).
--   convert_user_to_driver(p_user_id, p_license_number) — no p_admin_id.
--   Admin identity derived from auth.uid() server-side.
--   No DB change required.
--
-- T1-BUG-02: get_driver_queue_status now uses scalar variables
--   (v_trip_id, v_trip_status, v_trip_departure_lock, etc.)
--   instead of RECORD v_trip. All trip-field access is guarded
--   by "IF v_trip_id IS NOT NULL". The 55000 error cannot recur.
--   All Version 48+ post-trip stale-state guards preserved.
--
-- T1-BUG-03: get_route_queues_for_admin matching_status now
--   correctly handles all driver_queue states:
--   - offered → offer_sent (unchanged)
--   - assigned/active → active_trip (NEW — was incorrectly "No drivers online")
--   - waiting + not enough seats → waiting_for_passengers (unchanged)
--   - waiting + enough seats → ready_to_match (unchanged)
--   - no entries → no_drivers_in_queue (renamed from "No drivers online")
--   Driver queue list filter unchanged: ('waiting','offered','assigned','active','paused')
-- ============================================================
