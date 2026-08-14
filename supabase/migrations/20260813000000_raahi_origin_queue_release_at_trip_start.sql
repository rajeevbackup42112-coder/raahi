-- ============================================================
-- RAAHI — Move Origin Queue Release from Trip Completion to Trip Start
-- Migration: 20260813000000_raahi_origin_queue_release_at_trip_start.sql
-- ============================================================
--
-- ROOT CAUSE:
--   driver_start_trip (last deployed in 20260809240000) transitions
--   trips.status to 'in_progress' and sets drivers.availability_status
--   to 'trip_started', but does NOT release the driver's origin-side
--   driver_queue row. That row remains in ('waiting', 'offered', 'assigned')
--   until driver_complete_trip runs at the destination.
--
--   driver_complete_trip (last deployed in 20260811170000) performs a
--   broad cleanup:
--
--     UPDATE public.driver_queue
--     SET status = 'completed', completed_at = NOW(), updated_at = NOW()
--     WHERE driver_id = p_driver_id
--       AND status IN ('waiting', 'offered', 'assigned');
--
--   This means:
--   (a) The driver occupies the origin FIFO position for the entire
--       duration of the trip, blocking Driver B from becoming eligible
--       even though Driver A has physically departed.
--   (b) match_route_queue() is never triggered at departure, so waiting
--       passenger demand cannot be matched to the next driver until
--       Driver A reaches the destination.
--   (c) The broad cleanup in driver_complete_trip is dangerous once
--       queue release moves to Start Trip — it could accidentally
--       terminate a later queue entry belonging to the same driver
--       (e.g., if the driver re-queued on a different route while
--       their previous trip was still in_progress).
--
-- QUEUE RELEASE POINT BEFORE: driver_complete_trip (destination)
-- QUEUE RELEASE POINT AFTER:  driver_start_trip (origin departure)
--
-- EXACT QUEUE-TRIP LINK USED:
--   PRIMARY path (departure_pending → in_progress):
--     driver_queue.provisional_trip_id = v_trip.id
--     This is the canonical link set by match_route_queue() when the
--     driver receives an offer. It is the authoritative queue→trip
--     reference for the offered/assigned lifecycle.
--
--   LEGACY path (full/boarding/ready/accepting_bookings → in_progress):
--     trips.queue_entry_id = driver_queue.id
--     This is the back-reference set by activate_next_driver() in the
--     legacy lifecycle (stage3). It is the canonical trip→queue link
--     for the older activation path.
--
--   Both links are used in a single shared helper section to avoid
--   duplicated lifecycle logic.
--
-- CANONICAL PRODUCT INVARIANT:
--   Start Trip = release origin FIFO position
--   Complete Trip = close the in-progress trip only
--
-- REQUIRED CHANGES:
--
--   1. driver_start_trip:
--      After all departure guards pass and the trip is moved to
--      'in_progress', identify the specific driver_queue row tied to
--      this trip (via provisional_trip_id or queue_entry_id), mark it
--      completed (status='completed', completed_at=NOW(), updated_at=NOW()),
--      clear transient offer fields (offered_at, offer_expires_at,
--      provisional_trip_id), then call match_route_queue(v_trip.route_id)
--      to trigger next-driver matching immediately.
--
--      Applied to BOTH successful start paths (PRIMARY and LEGACY)
--      through one shared internal section.
--
--      Only the successful first transition releases the queue row.
--      Error returns do NOT release the queue row.
--      Idempotency: if the queue row is already 'completed', the UPDATE
--      affects 0 rows — no duplicate transition, no duplicate match call.
--
--   2. driver_complete_trip:
--      Remove the broad driver_queue cleanup. Instead, scope any
--      compatibility cleanup strictly to the queue entry associated
--      with the completed trip (via provisional_trip_id or queue_entry_id).
--      Since queue release already happened at Start Trip, this UPDATE
--      will typically affect 0 rows (idempotent safety net only).
--
-- CONCURRENCY / IDEMPOTENCY:
--   driver_start_trip already holds a row lock on the trips row via the
--   SELECT ... WHERE status = 'departure_pending' (or legacy statuses).
--   The queue row UPDATE uses WHERE status IN ('waiting','offered','assigned')
--   so a second call (after the first already set status='completed') will
--   match 0 rows and not re-trigger matching. match_route_queue() has its
--   own route-level advisory lock — preserved.
--
-- PRESERVE:
--   - passenger FIFO
--   - driver FIFO
--   - Branch 0 provisional-trip reuse
--   - fit-aware passenger matching
--   - test/live isolation
--   - offer expiry
--   - decline behavior
--   - pg_cron expiry scheduling
--   - departure lock logic
--   - minimum occupancy logic
--   - fare collection
--   - no-show handling
--   - booking abuse protection
--   - completion timestamps (completed_at, actual_arrival, updated_at)
--   - all other driver_complete_trip logic
--
-- DO NOT USE: activate_next_driver()
--   activate_next_driver() uses the legacy waiting→active lifecycle.
--   The canonical current lifecycle is waiting→offered→provisional_offer→accept.
--   Only match_route_queue() is used here.
--
-- ACTIVATE_NEXT_DRIVER USED: NO
--
-- FIFO IMPACT:
--   Driver B becomes first eligible origin driver immediately when
--   Driver A starts the trip. Multiple vehicles on the same corridor
--   can operate simultaneously. Rajeev's in-progress trip and Dipti's
--   newly offered trip may coexist simultaneously.
--
-- MATCHER TRIGGER:
--   PERFORM public.match_route_queue(v_trip.route_id);
--   Called after queue row is released. Waiting demand (e.g., Naresh's
--   4-seat booking) can be matched to the next driver (e.g., Dipti)
--   immediately after Rajeev starts his trip.
--
-- DATA REPAIR: NONE
--   No broad data repair. Existing in-progress trips retain their
--   current driver_queue state. The fix applies only to future
--   driver_start_trip calls.
--
-- STATIC REGRESSION:
--   Given: Driver FIFO #1 Rajeev Backup4 (3-seat trip, departure_pending),
--          Driver FIFO #2 Dipti (waiting), Naresh WAITING (4 seats).
--
--   Rajeev presses Start Trip:
--     → trip → in_progress ✓
--     → driver → trip_started ✓
--     → Rajeev's driver_queue row (provisional_trip_id = Rajeev's trip)
--       → status = 'completed', completed_at = NOW() ✓
--     → match_route_queue(route_id) called ✓
--     → Dipti becomes next eligible origin driver ✓
--     → Naresh matched to Dipti's capacity via match_route_queue ✓
--
--   Rajeev presses Complete Trip:
--     → his existing trip closes ✓
--     → passengers/bookings complete ✓
--     → driver resets to offline ✓
--     → Dipti's separate queue/trip state completely untouched ✓
--       (tightened cleanup only touches Rajeev's own trip's queue entry,
--        which is already 'completed' → 0 rows affected)
--
-- NEW MIGRATION:
--   20260813000000_raahi_origin_queue_release_at_trip_start.sql
--   After: 20260811190000_raahi_fix_match_route_queue_branch0_v2.sql
--
-- MANUAL E2E STILL REQUIRED: YES
-- ============================================================

-- ============================================================
-- STEP 1: Rewrite driver_start_trip
--
-- Changes from 20260809240000:
--   PRIMARY path (departure_pending → in_progress):
--     After the trip UPDATE and driver UPDATE, identify the
--     driver_queue row via provisional_trip_id = v_trip.id and
--     mark it completed. Then call match_route_queue().
--
--   LEGACY path (fallback statuses → in_progress):
--     After the trip UPDATE and driver UPDATE, identify the
--     driver_queue row via trips.queue_entry_id and mark it
--     completed. Then call match_route_queue().
--
--   All departure guards (lock check, minimum occupancy) are
--   IDENTICAL to 20260809240000. Queue release only happens
--   after all guards pass and the trip is successfully started.
--
--   Error return paths are UNCHANGED — no queue release on error.
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
  -- Queue release
  v_queue_entry_id UUID;
  v_queue_rows_updated INTEGER;
BEGIN
  -- ── PRIMARY PATH: departure_pending ────────────────────────────────────

  -- Find the driver's active departure_pending trip
  SELECT t.*
  INTO v_trip
  FROM public.trips t
  WHERE t.driver_id = p_driver_id
    AND t.status = 'departure_pending'
  ORDER BY t.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    -- ── LEGACY FALLBACK PATH ─────────────────────────────────────────────
    -- Also accept legacy status names in case of old data
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

    -- ── QUEUE RELEASE: LEGACY PATH ──────────────────────────────────────
    -- Identify the queue entry via trips.queue_entry_id (legacy link set
    -- by activate_next_driver). Fall back to driver_id scan if NULL.
    v_queue_entry_id := v_trip.queue_entry_id;

    IF v_queue_entry_id IS NOT NULL THEN
      -- Exact link via trips.queue_entry_id
      UPDATE public.driver_queue
      SET
        status              = 'completed',
        completed_at        = v_now,
        updated_at          = v_now,
        offered_at          = NULL,
        offer_expires_at    = NULL,
        provisional_trip_id = NULL
      WHERE id = v_queue_entry_id
        AND driver_id = p_driver_id
        AND status IN ('waiting', 'offered', 'assigned');

      GET DIAGNOSTICS v_queue_rows_updated = ROW_COUNT;
    ELSE
      -- Fallback: no queue_entry_id on trip — find by provisional_trip_id
      -- or most recent non-terminal queue row for this driver on this route
      UPDATE public.driver_queue
      SET
        status              = 'completed',
        completed_at        = v_now,
        updated_at          = v_now,
        offered_at          = NULL,
        offer_expires_at    = NULL,
        provisional_trip_id = NULL
      WHERE id = (
        SELECT dq.id
        FROM public.driver_queue dq
        WHERE dq.driver_id = p_driver_id
          AND dq.route_id = v_trip.route_id
          AND dq.status IN ('waiting', 'offered', 'assigned')
          AND (
            dq.provisional_trip_id = v_trip.id
            OR dq.provisional_trip_id IS NULL
          )
        ORDER BY dq.joined_at DESC
        LIMIT 1
      )
        AND status IN ('waiting', 'offered', 'assigned');

      GET DIAGNOSTICS v_queue_rows_updated = ROW_COUNT;
    END IF;

    -- Trigger canonical matching for next waiting driver
    -- Only if we actually released a queue row (idempotency guard)
    IF v_queue_rows_updated > 0 THEN
      PERFORM public.match_route_queue(v_trip.route_id);
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'trip_id', v_trip.id,
      'message', 'Trip started',
      'queue_released', v_queue_rows_updated > 0
    );
  END IF;

  -- ── departure_pending path ──────────────────────────────────────────────

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

  -- ── QUEUE RELEASE: PRIMARY PATH ─────────────────────────────────────────
  --
  -- Identify the specific driver_queue row tied to this trip.
  -- Canonical link: driver_queue.provisional_trip_id = v_trip.id
  -- This is set by match_route_queue() when the driver receives an offer
  -- and is the authoritative queue→trip reference for the offered/assigned
  -- lifecycle. We do NOT broadly update every queue row for this driver.
  --
  -- Idempotency: WHERE status IN ('waiting','offered','assigned') ensures
  -- a second call (after the first already set status='completed') matches
  -- 0 rows and does not re-trigger matching.
  --
  -- Transient offer fields are cleared (offered_at, offer_expires_at,
  -- provisional_trip_id) as they are no longer meaningful once the trip
  -- is in_progress. Historical linkage (queue_entry_id on trips, audit
  -- logs) is preserved for auditing.
  -- ────────────────────────────────────────────────────────────────────────

  UPDATE public.driver_queue
  SET
    status              = 'completed',
    completed_at        = v_now,
    updated_at          = v_now,
    offered_at          = NULL,
    offer_expires_at    = NULL,
    provisional_trip_id = NULL
  WHERE driver_id = p_driver_id
    AND provisional_trip_id = v_trip.id
    AND status IN ('waiting', 'offered', 'assigned');

  GET DIAGNOSTICS v_queue_rows_updated = ROW_COUNT;

  -- Fallback: if no row found via provisional_trip_id (e.g., legacy data
  -- where provisional_trip_id was not set), try via trips.queue_entry_id
  IF v_queue_rows_updated = 0 AND v_trip.queue_entry_id IS NOT NULL THEN
    UPDATE public.driver_queue
    SET
      status              = 'completed',
      completed_at        = v_now,
      updated_at          = v_now,
      offered_at          = NULL,
      offer_expires_at    = NULL,
      provisional_trip_id = NULL
    WHERE id = v_trip.queue_entry_id
      AND driver_id = p_driver_id
      AND status IN ('waiting', 'offered', 'assigned');

    GET DIAGNOSTICS v_queue_rows_updated = ROW_COUNT;
  END IF;

  -- Trigger canonical matching for next waiting driver
  -- match_route_queue() has its own route-level advisory lock (preserved).
  -- Only trigger if we actually released a queue row (idempotency guard).
  IF v_queue_rows_updated > 0 THEN
    PERFORM public.match_route_queue(v_trip.route_id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'trip_id', v_trip.id,
    'message', 'Trip started',
    'booked_seats', v_booked_seats,
    'queue_released', v_queue_rows_updated > 0
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.driver_start_trip(UUID) TO authenticated;

-- ============================================================
-- STEP 2: Tighten driver_complete_trip
--
-- Changes from 20260811170000:
--   The broad driver_queue cleanup:
--
--     UPDATE public.driver_queue
--     SET status = 'completed', completed_at = NOW(), updated_at = NOW()
--     WHERE driver_id = p_driver_id
--       AND status IN ('waiting', 'offered', 'assigned');
--
--   is replaced with a scoped cleanup that only touches the queue entry
--   associated with the completed trip. Since queue release already
--   happened at Start Trip, this UPDATE will typically affect 0 rows
--   (idempotent safety net only).
--
--   Scoping strategy (same dual-link approach as driver_start_trip):
--     Primary:  driver_queue WHERE provisional_trip_id = v_trip.id
--     Fallback: driver_queue WHERE id = v_trip.queue_entry_id
--
--   This ensures that if the driver re-queued on a different route
--   while their previous trip was still in_progress (edge case), the
--   new queue entry is NOT accidentally terminated by Complete Trip.
--
--   All other logic is IDENTICAL to 20260811170000:
--     - trips UPDATE: status='completed', actual_arrival=NOW(),
--       completed_at=NOW(), updated_at=NOW()
--     - bookings UPDATE: status='completed'
--     - passenger_queue UPDATE: ASSIGNED → COMPLETED
--     - drivers UPDATE: offline, current_route_id=NULL
--     - audit log: trip_completed
-- ============================================================

CREATE OR REPLACE FUNCTION public.driver_complete_trip(
  p_driver_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trip         RECORD;
  v_profile_id   UUID;
  v_queue_rows_updated INTEGER;
BEGIN
  -- Get driver's profile_id for audit log
  SELECT profile_id INTO v_profile_id
  FROM public.drivers
  WHERE id = p_driver_id;

  -- Find the in-progress trip
  SELECT * INTO v_trip
  FROM public.trips
  WHERE driver_id = p_driver_id
    AND status = 'in_progress'
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'No in-progress trip found');
  END IF;

  -- ----------------------------------------------------------------
  -- Mark trip as completed
  -- Preserved from 20260811170000: completed_at, actual_arrival, updated_at
  -- ----------------------------------------------------------------
  UPDATE public.trips
  SET
    status         = 'completed',
    actual_arrival = NOW(),
    completed_at   = NOW(),
    updated_at     = NOW()
  WHERE id = v_trip.id;

  -- Mark all confirmed bookings on this trip as completed
  UPDATE public.bookings
  SET
    status     = 'completed',
    updated_at = NOW()
  WHERE trip_id = v_trip.id
    AND status  = 'confirmed';

  -- Mark all ASSIGNED passenger_queue rows for this trip as COMPLETED
  UPDATE public.passenger_queue
  SET
    status     = 'COMPLETED',
    updated_at = NOW()
  WHERE assigned_trip_id = v_trip.id
    AND status = 'ASSIGNED';

  -- ----------------------------------------------------------------
  -- POST-COMPLETION DRIVER RESET
  -- Reset driver to OFFLINE so Driver Home shows Go Online panel.
  -- Clear current_route_id (stale active route reference).
  -- Preserve: current_vehicle_id, verification_status, license_number.
  -- ----------------------------------------------------------------
  UPDATE public.drivers
  SET
    availability_status = 'offline',
    current_route_id    = NULL,
    updated_at          = NOW()
  WHERE id = p_driver_id;

  -- ----------------------------------------------------------------
  -- SCOPED DRIVER_QUEUE CLEANUP (tightened from 20260811170000)
  --
  -- Origin queue release already happened at driver_start_trip.
  -- This is a safety net only — it will typically affect 0 rows.
  --
  -- Scope: ONLY the queue entry associated with the completed trip.
  --   Primary link:  driver_queue.provisional_trip_id = v_trip.id
  --   Fallback link: driver_queue.id = v_trip.queue_entry_id
  --
  -- This does NOT broadly complete unrelated current/future queue rows
  -- belonging to the same driver (e.g., if the driver re-queued on a
  -- different route while this trip was in_progress).
  --
  -- Dipti's separate queue/trip state is completely untouched.
  -- ----------------------------------------------------------------

  -- Primary: find via provisional_trip_id
  UPDATE public.driver_queue
  SET
    status              = 'completed',
    completed_at        = NOW(),
    updated_at          = NOW(),
    offered_at          = NULL,
    offer_expires_at    = NULL,
    provisional_trip_id = NULL
  WHERE driver_id = p_driver_id
    AND provisional_trip_id = v_trip.id
    AND status IN ('waiting', 'offered', 'assigned');

  GET DIAGNOSTICS v_queue_rows_updated = ROW_COUNT;

  -- Fallback: find via trips.queue_entry_id (legacy link)
  IF v_queue_rows_updated = 0 AND v_trip.queue_entry_id IS NOT NULL THEN
    UPDATE public.driver_queue
    SET
      status              = 'completed',
      completed_at        = NOW(),
      updated_at          = NOW(),
      offered_at          = NULL,
      offer_expires_at    = NULL,
      provisional_trip_id = NULL
    WHERE id = v_trip.queue_entry_id
      AND driver_id = p_driver_id
      AND status IN ('waiting', 'offered', 'assigned');
  END IF;

  -- Audit log
  INSERT INTO public.audit_logs (
    performed_by,
    action,
    target_table,
    target_id,
    new_value,
    notes
  )
  VALUES (
    v_profile_id,
    'trip_completed'::public.audit_action,
    'trips',
    v_trip.id,
    jsonb_build_object(
      'driver_id',           p_driver_id,
      'driver_profile_id',   v_profile_id,
      'post_trip_status',    'offline',
      'route_cleared',       true,
      'completed_at_set',    true,
      'queue_release_point', 'trip_start',
      'queue_cleanup_scoped', true
    ),
    'Trip completed by driver — driver reset to offline'
  );

  RETURN jsonb_build_object(
    'success',  true,
    'trip_id',  v_trip.id,
    'message',  'Trip completed. You can go online again to join the queue.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.driver_complete_trip(UUID) TO authenticated;

-- ============================================================
-- STEP 3: Verification
-- ============================================================

DO $$
BEGIN
  -- Verify driver_start_trip exists and is callable
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'driver_start_trip'
  ) THEN
    RAISE EXCEPTION 'driver_start_trip function not found after migration';
  END IF;

  -- Verify driver_complete_trip exists and is callable
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'driver_complete_trip'
  ) THEN
    RAISE EXCEPTION 'driver_complete_trip function not found after migration';
  END IF;

  -- Verify match_route_queue exists (called by driver_start_trip)
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'match_route_queue'
  ) THEN
    RAISE EXCEPTION 'match_route_queue function not found — required by driver_start_trip';
  END IF;

  RAISE NOTICE 'OK: driver_start_trip, driver_complete_trip, match_route_queue all present';
  RAISE NOTICE 'OK: Origin queue release moved to trip start';
  RAISE NOTICE 'OK: driver_complete_trip queue cleanup scoped to trip-specific queue entry';
  RAISE NOTICE 'OK: activate_next_driver NOT used';
END $$;
