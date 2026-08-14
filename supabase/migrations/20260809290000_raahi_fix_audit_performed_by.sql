-- ============================================================
-- RAAHI — Fix audit_logs.performed_by: use driver profile_id
-- Migration: 20260809290000_raahi_fix_audit_performed_by.sql
-- ============================================================
--
-- ROOT CAUSE (confirmed from production error):
--
--   {
--     "code": "23503",
--     "details": "Key (performed_by)=(7b962aa7-80c2-465d-a87e-a216c7d5af22) is not present in table \"profiles\".",
--     "hint": null,
--     "message": "insert or update on table \"audit_logs\" violates foreign key constraint \"audit_logs_performed_by_fkey\""
--   }
--
-- DRIVER ID:          7b962aa7-80c2-465d-a87e-a216c7d5af22  (drivers.id)
-- DRIVER PROFILE ID:  2decf279-1928-49c8-81cb-1347291f78ed  (drivers.profile_id)
--
-- INVALID AUDIT ACTOR SITES FOUND:
--
--   1. match_route_queue (stage5  20260809060000) — performed_by = v_driver_entry.driver_id   ❌
--   2. match_route_queue (stage7  20260809200000) — performed_by = v_driver_entry.driver_id   ❌
--   3. match_route_queue (stage26 20260809260000) — performed_by = v_driver_entry.driver_id   ❌
--   4. expire_driver_offer (stage5 20260809060000) — performed_by = v_queue_entry.driver_id   ❌
--
-- ALREADY CORRECT (no changes needed):
--   - stage51 match_route_queue  — uses v_driver_entry.driver_profile_id  ✅
--   - driver_cancel_before_trip_start — uses p_driver_profile_id           ✅
--   - driver_accept_offer / driver_decline_offer — use p_driver_profile_id ✅
--   - book_or_queue / cancel_booking (migration 280000) — use auth.uid()   ✅
--   - all admin RPCs — use p_admin_id (profiles.id)                        ✅
--
-- FIX STRATEGY:
--   In match_route_queue, the SELECT already JOINs public.drivers d.
--   Add d.profile_id AS driver_profile_id to the SELECT so it is
--   available on v_driver_entry, then use v_driver_entry.driver_profile_id
--   for all audit_logs.performed_by writes.
--
--   In expire_driver_offer, resolve the driver's profile_id from
--   public.drivers WHERE id = v_queue_entry.driver_id before the audit.
--
-- ============================================================

-- ============================================================
-- 1. match_route_queue — definitive version
--    Supersedes all previous versions (stage5, stage7, stage26, stage51).
--    Key fix: SELECT includes d.profile_id AS driver_profile_id.
--             All audit_logs.performed_by use v_driver_entry.driver_profile_id.
-- ============================================================

CREATE OR REPLACE FUNCTION public.match_route_queue(p_route_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
  v_fare              NUMERIC;
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

  -- ── FIND FIRST ELIGIBLE DRIVER ──────────────────────────────────────────
  -- Accept 'waiting' (just joined, no trip yet) and 'active'
  -- (activated by driver_go_online when no passengers were waiting).
  -- CRITICAL: select d.profile_id AS driver_profile_id so audit entries
  -- use the correct profiles.id reference, never drivers.id.
  SELECT
    dq.*,
    d.id            AS driver_rec_id,
    d.profile_id    AS driver_profile_id,
    d.current_vehicle_id
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
    -- Check if there is an 'active' driver with an existing
    -- 'accepting_bookings' or 'boarding' trip that still has capacity.
    SELECT
      dq.*,
      d.id            AS driver_rec_id,
      d.profile_id    AS driver_profile_id,
      d.current_vehicle_id
    INTO v_driver_entry
    FROM public.driver_queue dq
    JOIN public.drivers d ON d.id = dq.driver_id
    JOIN public.trips t
      ON t.driver_id = dq.driver_id
     AND t.route_id  = p_route_id
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
      AND t.route_id  = p_route_id
      AND t.status IN ('accepting_bookings', 'boarding')
    ORDER BY t.created_at DESC
    LIMIT 1;
  END IF;

  -- ── GET VEHICLE CAPACITY ────────────────────────────────────────────────
  SELECT v.seating_capacity, v.make, v.model, v.registration_number
  INTO v_vehicle
  FROM public.vehicles v
  WHERE v.id = v_driver_entry.vehicle_id
    AND v.status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_valid_vehicle');
  END IF;

  v_capacity      := v_vehicle.seating_capacity;
  v_keep_together := public.get_business_setting('keep_multi_seat_booking_together');

  -- If using existing trip, account for already-booked seats
  IF v_existing_trip_id IS NOT NULL THEN
    SELECT COALESCE(SUM(b.seats), 0)
    INTO v_assigned_seats
    FROM public.bookings b
    WHERE b.trip_id = v_existing_trip_id AND b.status = 'confirmed';
  END IF;

  -- ── COLLECT WAITING PASSENGERS (FIFO) ───────────────────────────────────
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
      v_passenger_ids  := array_append(v_passenger_ids, v_entry.id);
      v_booking_ids    := array_append(v_booking_ids,   v_entry.booking_id);
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

  -- ── DIRECT ASSIGNMENT PATH (driver already has a live trip) ─────────────
  IF v_existing_trip_id IS NOT NULL THEN
    UPDATE public.bookings
    SET trip_id    = v_existing_trip_id,
        status     = 'confirmed',
        updated_at = NOW()
    WHERE id = ANY(v_booking_ids);

    UPDATE public.passenger_queue
    SET status          = 'ASSIGNED',
        assigned_trip_id = v_existing_trip_id,
        updated_at      = NOW()
    WHERE id = ANY(v_passenger_ids);

    UPDATE public.trips
    SET booked_seats = (
          SELECT COALESCE(SUM(b.seats), 0)
          FROM public.bookings b
          WHERE b.trip_id = v_existing_trip_id AND b.status = 'confirmed'
        ),
        updated_at = NOW()
    WHERE id = v_existing_trip_id;

    -- AUDIT: performed_by = driver_profile_id (profiles.id), NOT drivers.id
    INSERT INTO public.audit_logs (
      performed_by, action, target_table, target_id, new_value, notes
    )
    VALUES (
      v_driver_entry.driver_profile_id,
      'passenger_assigned_to_trip'::public.audit_action,
      'trips',
      v_existing_trip_id,
      jsonb_build_object(
        'route_id',        p_route_id,
        'passenger_count', array_length(v_passenger_ids, 1),
        'seat_count',      v_assigned_seats
      ),
      'Passengers directly assigned to existing driver trip'
    );

    RETURN jsonb_build_object(
      'success',            true,
      'trip_id',            v_existing_trip_id,
      'driver_queue_id',    v_driver_entry.id,
      'passenger_queue_ids', v_passenger_ids,
      'assigned_seats',     v_assigned_seats,
      'direct_assignment',  true
    );
  END IF;

  -- ── OFFER FLOW (no existing trip — create provisional trip) ─────────────
  v_timeout_seconds := COALESCE(
    public.get_business_setting('driver_offer_timeout_seconds')::INTEGER,
    45
  );
  v_offer_expires := NOW() + (v_timeout_seconds || ' seconds')::INTERVAL;

  SELECT fare_per_seat INTO v_fare FROM public.routes WHERE id = p_route_id;

  INSERT INTO public.trips (
    route_id, driver_id, vehicle_id, total_seats, booked_seats,
    status, fare_per_seat, queue_entry_id, notes
  )
  VALUES (
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

  UPDATE public.driver_queue
  SET status             = 'offered',
      offered_at         = NOW(),
      offer_expires_at   = v_offer_expires,
      provisional_trip_id = v_trip_id,
      updated_at         = NOW()
  WHERE id = v_driver_entry.id;

  UPDATE public.passenger_queue
  SET status           = 'MATCHING',
      assigned_trip_id = v_trip_id,
      updated_at       = NOW()
  WHERE id = ANY(v_passenger_ids);

  -- AUDIT: performed_by = driver_profile_id (profiles.id), NOT drivers.id
  INSERT INTO public.audit_logs (
    performed_by, action, target_table, target_id, new_value, notes
  )
  VALUES (
    v_driver_entry.driver_profile_id,
    'driver_offered_ride'::public.audit_action,
    'driver_queue',
    v_driver_entry.id,
    jsonb_build_object(
      'trip_id',         v_trip_id,
      'route_id',        p_route_id,
      'passenger_count', array_length(v_passenger_ids, 1),
      'seat_count',      v_assigned_seats,
      'offer_expires_at', v_offer_expires
    ),
    'Driver offered ride via FIFO matching'
  );

  RETURN jsonb_build_object(
    'success',             true,
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
-- 2. expire_driver_offer — fix performed_by
--    Resolves driver's profile_id before the audit INSERT.
--    Supersedes stage5 version (20260809060000).
-- ============================================================

CREATE OR REPLACE FUNCTION public.expire_driver_offer(
  p_queue_entry_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_queue_entry       RECORD;
  v_timeout_behavior  TEXT;
  v_driver_profile_id UUID;
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

  -- Resolve driver's profile_id (profiles.id) — never use drivers.id for audit
  SELECT profile_id INTO v_driver_profile_id
  FROM public.drivers
  WHERE id = v_queue_entry.driver_id;

  -- Release provisional trip
  PERFORM public.release_provisional_trip(v_queue_entry.provisional_trip_id, 'offer_expired');

  -- Apply timeout behavior
  v_timeout_behavior := COALESCE(
    public.get_business_setting('driver_timeout_queue_behavior'),
    'MOVE_TO_END'
  );

  IF v_timeout_behavior = 'MOVE_TO_END' THEN
    UPDATE public.driver_queue
    SET status              = 'waiting',
        joined_at           = NOW(),
        offered_at          = NULL,
        offer_expires_at    = NULL,
        provisional_trip_id = NULL,
        updated_at          = NOW()
    WHERE id = p_queue_entry_id;
  ELSE
    UPDATE public.driver_queue
    SET status     = 'cancelled',
        updated_at = NOW()
    WHERE id = p_queue_entry_id;

    UPDATE public.drivers
    SET availability_status = 'offline'::public.driver_availability_status,
        updated_at          = NOW()
    WHERE id = v_queue_entry.driver_id;
  END IF;

  -- AUDIT: performed_by = driver_profile_id (profiles.id), NOT drivers.id
  INSERT INTO public.audit_logs (
    performed_by, action, target_table, target_id, new_value, notes
  )
  VALUES (
    v_driver_profile_id,
    'offer_expired'::public.audit_action,
    'driver_queue',
    p_queue_entry_id,
    jsonb_build_object(
      'behavior', v_timeout_behavior,
      'route_id', v_queue_entry.route_id
    ),
    'Driver offer expired — timeout reached'
  );

  -- Trigger next match
  PERFORM public.match_route_queue(v_queue_entry.route_id);

  RETURN jsonb_build_object('success', true, 'behavior', v_timeout_behavior);
END;
$$;

GRANT EXECUTE ON FUNCTION public.expire_driver_offer(UUID) TO authenticated;

-- ============================================================
-- VERIFICATION REPORT
-- ============================================================
-- DRIVER ID:                          7b962aa7-80c2-465d-a87e-a216c7d5af22
-- DRIVER PROFILE ID:                  2decf279-1928-49c8-81cb-1347291f78ed
-- MATCH_ROUTE_QUEUE AUDIT ACTOR FIXED: YES
-- OTHER INVALID AUDIT ACTOR SITES FOUND:
--   expire_driver_offer (stage5) — v_queue_entry.driver_id → FIXED
--   match_route_queue (stage5, stage7, stage26) — v_driver_entry.driver_id → FIXED
-- SITES CONFIRMED CORRECT (no change):
--   stage51 match_route_queue — already used driver_profile_id ✅
--   driver_cancel_before_trip_start — uses p_driver_profile_id ✅
--   driver_accept_offer / driver_decline_offer — use p_driver_profile_id ✅
--   book_or_queue / cancel_booking (280000) — use auth.uid() ✅
--   all admin RPCs — use p_admin_id (profiles.id) ✅
-- ============================================================
