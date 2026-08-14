-- ============================================================
-- RAAHI — Fix Booking RPC Enum Cast + Uninitialized Record
-- Migration: 20260809320000_raahi_fix_booking_rpc_enum_and_record.sql
-- ============================================================
--
-- DEFECT 1 — get_my_bookings: 22P02 invalid booking_status enum cast
--   ROOT CAUSE: In migration 300000, the CASE expression had:
--     ELSE v_row.booking_status   (type: booking_status enum)
--   with TEXT branches like 'assigned', 'queued', 'matching'.
--   PostgreSQL unifies CASE branch types and tries to cast TEXT
--   branches to booking_status enum → 22P02 on 'assigned'.
--   Also migration 300000 had an illegal DECLARE block inside a
--   FOR loop body (invalid PL/pgSQL syntax).
--   FIX: Cast v_row.booking_status::TEXT in all CASE/ELSE branches.
--   Declare v_display_status at function level (not inside loop).
--
-- DEFECT 2 — get_passenger_booking: "record v_trip is not assigned yet"
--   ROOT CAUSE: v_trip declared as RECORD. When trip_id IS NULL the
--   SELECT INTO v_trip is never executed. Any subsequent field access
--   (v_trip.vehicle_id, v_trip.driver_id, v_trip.trip_status) raises
--   "record v_trip is not assigned yet" (PostgreSQL error 55000).
--   FIX: Replace v_trip RECORD with scalar variables. Guard all trip
--   field access with explicit NULL checks. Queued bookings with
--   trip_id IS NULL are fully supported.
--
-- DEFECT 3 — get_admin_bookings: potential enum cast in JSON output
--   ROOT CAUSE: v_row.booking_status is booking_status enum type.
--   Passing it directly to jsonb_build_object may cause type issues.
--   FIX: Cast to TEXT explicitly in jsonb_build_object call.
--
-- IDENTITY: All RPCs derive identity from auth.uid() — no caller UUIDs.
-- ROUTE RESOLUTION: COALESCE(pq.route_id, t.route_id) — no bookings→routes FK.
-- ============================================================

-- ============================================================
-- 1. get_passenger_booking — fixed: no uninitialized RECORD
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_passenger_booking(
  p_booking_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_passenger_id       UUID;
  -- Booking fields (scalar)
  v_booking_id         UUID;
  v_booking_passenger  UUID;
  v_booking_trip_id    UUID;
  v_booking_pickup_id  UUID;
  v_booking_seats      INTEGER;
  v_booking_fare       NUMERIC;
  v_booking_total      NUMERIC;
  v_booking_status     TEXT;   -- cast to TEXT immediately
  v_booking_at         TIMESTAMPTZ;
  -- Queue fields (scalar)
  v_pq_id              UUID;
  v_pq_route_id        UUID;
  v_pq_status          TEXT;
  v_pq_sequence        BIGINT;
  v_pq_seat_count      INTEGER;
  v_pq_assigned_trip   UUID;
  -- Trip fields (scalar) — all NULL-safe
  v_trip_route_id      UUID;
  v_trip_status        TEXT;
  v_trip_vehicle_id    UUID;
  v_trip_driver_id     UUID;
  -- Route fields
  v_route_from         TEXT := '';
  v_route_to           TEXT := '';
  v_resolved_route_id  UUID;
  -- Pickup fields
  v_pickup_name        TEXT := '';
  v_pickup_landmark    TEXT := '';
  -- Vehicle fields
  v_vehicle_make       TEXT := '';
  v_vehicle_model      TEXT := '';
  v_vehicle_reg        TEXT := '';
  -- Driver fields
  v_driver_name        TEXT := '';
  v_driver_phone       TEXT := '';
  -- Queue position
  v_queue_pos          BIGINT;
  v_passengers_ahead   BIGINT;
BEGIN
  -- Identity: always from session
  v_passenger_id := auth.uid();
  IF v_passenger_id IS NULL THEN
    RETURN jsonb_build_object('found', false, 'error', 'Not authenticated');
  END IF;

  -- Load booking — must belong to this passenger
  SELECT b.id,
         b.passenger_id,
         b.trip_id,
         b.pickup_point_id,
         b.seats,
         b.fare_per_seat,
         b.total_fare,
         b.status::TEXT,   -- cast enum to TEXT immediately
         b.booked_at
  INTO v_booking_id,
       v_booking_passenger,
       v_booking_trip_id,
       v_booking_pickup_id,
       v_booking_seats,
       v_booking_fare,
       v_booking_total,
       v_booking_status,
       v_booking_at
  FROM public.bookings b
  WHERE b.id = p_booking_id
    AND b.passenger_id = v_passenger_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false, 'error', 'Booking not found');
  END IF;

  -- Load passenger_queue entry (may not exist)
  SELECT pq.id,
         pq.route_id,
         pq.status,
         pq.queue_sequence,
         pq.seat_count,
         pq.assigned_trip_id
  INTO v_pq_id,
       v_pq_route_id,
       v_pq_status,
       v_pq_sequence,
       v_pq_seat_count,
       v_pq_assigned_trip
  FROM public.passenger_queue pq
  WHERE pq.booking_id = p_booking_id
  LIMIT 1;
  -- If no queue entry, all v_pq_* remain NULL — that is fine

  -- Load trip fields (scalar) — only if trip_id is not null
  IF v_booking_trip_id IS NOT NULL THEN
    SELECT t.route_id,
           t.status::TEXT,
           t.vehicle_id,
           t.driver_id
    INTO v_trip_route_id,
         v_trip_status,
         v_trip_vehicle_id,
         v_trip_driver_id
    FROM public.trips t
    WHERE t.id = v_booking_trip_id;
    -- If trip row not found, scalars remain NULL — safe
  END IF;
  -- v_trip_* are NULL when trip_id IS NULL — never dereferenced unsafely

  -- Resolve route_id: trip route preferred, else queue route
  v_resolved_route_id := COALESCE(v_trip_route_id, v_pq_route_id);

  -- Load route
  IF v_resolved_route_id IS NOT NULL THEN
    SELECT r.from_location, r.to_location
    INTO v_route_from, v_route_to
    FROM public.routes r
    WHERE r.id = v_resolved_route_id;
    v_route_from := COALESCE(v_route_from, '');
    v_route_to   := COALESCE(v_route_to, '');
  END IF;

  -- Load pickup point
  IF v_booking_pickup_id IS NOT NULL THEN
    SELECT pp.name, pp.landmark
    INTO v_pickup_name, v_pickup_landmark
    FROM public.pickup_points pp
    WHERE pp.id = v_booking_pickup_id;
    v_pickup_name     := COALESCE(v_pickup_name, '');
    v_pickup_landmark := COALESCE(v_pickup_landmark, '');
  END IF;

  -- Load vehicle (only if trip has a vehicle)
  IF v_trip_vehicle_id IS NOT NULL THEN
    SELECT v.make, v.model, v.registration_number
    INTO v_vehicle_make, v_vehicle_model, v_vehicle_reg
    FROM public.vehicles v
    WHERE v.id = v_trip_vehicle_id;
    v_vehicle_make  := COALESCE(v_vehicle_make, '');
    v_vehicle_model := COALESCE(v_vehicle_model, '');
    v_vehicle_reg   := COALESCE(v_vehicle_reg, '');
  END IF;

  -- Load driver (only if trip has a driver)
  IF v_trip_driver_id IS NOT NULL THEN
    SELECT p.name, p.phone
    INTO v_driver_name, v_driver_phone
    FROM public.drivers d
    JOIN public.profiles p ON p.id = d.profile_id
    WHERE d.id = v_trip_driver_id;
    v_driver_name  := COALESCE(v_driver_name, '');
    v_driver_phone := COALESCE(v_driver_phone, '');
  END IF;

  -- Queue position (only meaningful when WAITING/MATCHING)
  IF v_pq_id IS NOT NULL AND v_pq_status IN ('WAITING', 'MATCHING') THEN
    SELECT COUNT(*)
    INTO v_passengers_ahead
    FROM public.passenger_queue pq2
    WHERE pq2.route_id = v_pq_route_id
      AND pq2.status IN ('WAITING', 'MATCHING')
      AND pq2.queue_sequence < v_pq_sequence;

    v_queue_pos := v_passengers_ahead + 1;
  END IF;

  RETURN jsonb_build_object(
    'found',                true,
    'booking_id',           v_booking_id,
    'seats',                v_booking_seats,
    'fare_per_seat',        v_booking_fare,
    'total_fare',           v_booking_total,
    'booking_status',       v_booking_status,   -- TEXT, not enum
    'booked_at',            v_booking_at,
    -- Route (resolved correctly — no bookings→routes FK)
    'route_from',           v_route_from,
    'route_to',             v_route_to,
    -- Pickup
    'pickup_name',          v_pickup_name,
    'pickup_landmark',      v_pickup_landmark,
    -- Queue state
    'queue_id',             v_pq_id,
    'queue_status',         v_pq_status,
    'queue_position',       v_queue_pos,
    'passengers_ahead',     v_passengers_ahead,
    'seat_count',           COALESCE(v_pq_seat_count, v_booking_seats),
    -- Trip / assignment state (all NULL-safe)
    'trip_id',              v_booking_trip_id,
    'trip_status',          v_trip_status,      -- NULL when no trip
    'assigned_trip_id',     v_pq_assigned_trip,
    -- Vehicle (empty string when no trip)
    'vehicle_make',         v_vehicle_make,
    'vehicle_model',        v_vehicle_model,
    'vehicle_registration', v_vehicle_reg,
    -- Driver (empty string when no trip)
    'driver_name',          v_driver_name,
    'driver_phone',         v_driver_phone
  );
END;
$$;

-- ============================================================
-- 2. get_my_bookings — fixed: TEXT cast prevents enum inference
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
  v_display_status TEXT;   -- declared at function level (not inside loop)
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
      b.status::TEXT                                    AS booking_status,  -- TEXT cast
      b.booked_at,
      pp.name                                           AS pickup_name,
      pq.id                                             AS queue_id,
      pq.route_id                                       AS pq_route_id,
      pq.status                                         AS queue_status,
      pq.seat_count,
      pq.assigned_trip_id,
      t.route_id                                        AS trip_route_id,
      t.status::TEXT                                    AS trip_status,     -- TEXT cast
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
    -- Determine display status as TEXT — no enum inference possible
    -- booking_status is already TEXT (cast above)
    -- queue_status is TEXT (passenger_queue.status is text/varchar)
    IF v_row.queue_status IS NOT NULL
       AND v_row.queue_status NOT IN ('CANCELLED', 'COMPLETED')
       AND v_row.booking_status NOT IN ('cancelled', 'completed', 'no_show')
    THEN
      -- Map queue status to display text — all branches are TEXT literals
      v_display_status := CASE v_row.queue_status
        WHEN 'WAITING'   THEN 'queued'::TEXT
        WHEN 'MATCHING'  THEN 'matching'::TEXT
        WHEN 'ASSIGNED'  THEN 'assigned'::TEXT   -- TEXT only, never cast to booking_status
        ELSE v_row.booking_status::TEXT           -- already TEXT, explicit cast for safety
      END;
    ELSE
      v_display_status := v_row.booking_status::TEXT;
    END IF;

    v_item := jsonb_build_object(
      'id',             v_row.booking_id,
      'seats',          v_row.seats,
      'fare_per_seat',  v_row.fare_per_seat,
      'total_fare',     v_row.total_fare,
      'status',         v_display_status,          -- TEXT display status
      'booking_status', v_row.booking_status,       -- TEXT (cast in SELECT)
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

-- ============================================================
-- 3. get_admin_bookings — fixed: TEXT cast on booking_status
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_admin_bookings(
  p_limit  INTEGER DEFAULT 200,
  p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_items    JSONB[] := ARRAY[]::JSONB[];
  v_result   JSONB;
  v_row      RECORD;
BEGIN
  -- Verify admin identity from session
  v_admin_id := auth.uid();
  IF v_admin_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Not authenticated', 'bookings', '[]'::JSONB);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = v_admin_id AND role = 'admin'
  ) THEN
    RETURN jsonb_build_object('error', 'Unauthorized', 'bookings', '[]'::JSONB);
  END IF;

  FOR v_row IN
    SELECT
      b.id                                              AS booking_id,
      b.passenger_id,
      b.trip_id,
      b.pickup_point_id,
      b.seats,
      b.fare_per_seat,
      b.total_fare,
      b.status::TEXT                                    AS booking_status,  -- TEXT cast prevents enum issues
      b.traveler_name,
      b.traveler_phone,
      b.admin_notes,
      b.no_show_fee,
      b.created_at,
      -- Passenger
      pass.name                                         AS passenger_name,
      pass.phone                                        AS passenger_phone,
      pass.email                                        AS passenger_email,
      -- Pickup
      pp.name                                           AS pickup_name,
      -- Queue entry (NULL for non-queued bookings)
      pq.id                                             AS queue_id,
      pq.route_id                                       AS pq_route_id,
      pq.status                                         AS queue_status,
      pq.seat_count,
      -- Trip (NULL for queued bookings)
      t.id                                              AS trip_id_val,
      t.status::TEXT                                    AS trip_status,     -- TEXT cast
      t.route_id                                        AS trip_route_id,
      t.vehicle_id,
      t.driver_id,
      -- Route: COALESCE(trip route, queue route) — no bookings→routes FK
      COALESCE(rt.from_location, rq.from_location, '') AS route_from,
      COALESCE(rt.to_location,   rq.to_location,   '') AS route_to,
      -- Vehicle
      v.make                                            AS vehicle_make,
      v.model                                           AS vehicle_model,
      v.registration_number                             AS vehicle_reg,
      -- Driver
      dp.name                                           AS driver_name
    FROM public.bookings b
    LEFT JOIN public.profiles pass ON pass.id = b.passenger_id
    LEFT JOIN public.pickup_points pp ON pp.id = b.pickup_point_id
    LEFT JOIN public.passenger_queue pq ON pq.booking_id = b.id
    LEFT JOIN public.trips t ON t.id = b.trip_id
    LEFT JOIN public.routes rt ON rt.id = t.route_id
    LEFT JOIN public.routes rq ON rq.id = pq.route_id
    LEFT JOIN public.vehicles v ON v.id = t.vehicle_id
    LEFT JOIN public.drivers d ON d.id = t.driver_id
    LEFT JOIN public.profiles dp ON dp.id = d.profile_id
    ORDER BY b.created_at DESC
    LIMIT p_limit OFFSET p_offset
  LOOP
    v_items := array_append(v_items, jsonb_build_object(
      'id',              v_row.booking_id,
      'passenger_id',    v_row.passenger_id,
      'trip_id',         v_row.trip_id,
      'pickup_point_id', v_row.pickup_point_id,
      'seats',           v_row.seats,
      'fare_per_seat',   v_row.fare_per_seat,
      'total_fare',      v_row.total_fare,
      'status',          v_row.booking_status,      -- TEXT (cast in SELECT)
      'traveler_name',   v_row.traveler_name,
      'traveler_phone',  v_row.traveler_phone,
      'admin_notes',     v_row.admin_notes,
      'no_show_fee',     v_row.no_show_fee,
      'created_at',      v_row.created_at,
      'passenger_name',  COALESCE(v_row.traveler_name, v_row.passenger_name, '—'),
      'passenger_phone', COALESCE(v_row.traveler_phone, v_row.passenger_phone, '—'),
      'passenger_email', COALESCE(v_row.passenger_email, ''),
      'pickup_name',     COALESCE(v_row.pickup_name, ''),
      'queue_id',        v_row.queue_id,
      'queue_status',    v_row.queue_status,
      'route_from',      v_row.route_from,
      'route_to',        v_row.route_to,
      'trip_status',     COALESCE(v_row.trip_status, ''),
      'vehicle_make',    COALESCE(v_row.vehicle_make, ''),
      'vehicle_model',   COALESCE(v_row.vehicle_model, ''),
      'vehicle_reg',     COALESCE(v_row.vehicle_reg, ''),
      'driver_name',     COALESCE(v_row.driver_name, '')
    ));
  END LOOP;

  SELECT jsonb_agg(elem) INTO v_result
  FROM unnest(v_items) AS elem;

  RETURN jsonb_build_object(
    'bookings', COALESCE(v_result, '[]'::JSONB)
  );
END;
$$;

-- ============================================================
-- Grants (idempotent)
-- ============================================================
GRANT EXECUTE ON FUNCTION public.get_passenger_booking(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_bookings() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_bookings(INTEGER, INTEGER) TO authenticated;
-- admin_cancel_booking remains unchanged — compatible with fixed state model
GRANT EXECUTE ON FUNCTION public.admin_cancel_booking(UUID, TEXT) TO authenticated;
