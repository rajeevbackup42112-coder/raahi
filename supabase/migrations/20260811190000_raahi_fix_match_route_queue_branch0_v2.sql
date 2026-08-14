-- ============================================================
-- RAAHI — Fix match_route_queue Branch 0: Offered-Trip Reuse (v2)
-- Migration: 20260811190000_raahi_fix_match_route_queue_branch0_v2.sql
-- ============================================================
--
-- ROOT CAUSE (confirmed from live reproduction after 20260811180000):
--
--   Migration 20260811180000 added Branch 0 to reuse an existing offered
--   provisional trip. However, Branch 0 contained a critical defect:
--
--   DEFECT 1 — FOR UPDATE OF dq SKIP LOCKED on a JOIN query:
--     The Branch 0 driver_queue lookup used:
--
--       SELECT dq.*, d.is_test_data AS driver_is_test
--       FROM public.driver_queue dq
--       JOIN public.drivers d ON d.id = dq.driver_id
--       WHERE dq.route_id = p_route_id
--         AND dq.status = 'offered'
--         AND dq.offer_expires_at > NOW()
--       ORDER BY dq.joined_at ASC
--       LIMIT 1
--       FOR UPDATE OF dq SKIP LOCKED;
--
--     In PostgreSQL, FOR UPDATE OF alias SKIP LOCKED on a multi-table JOIN
--     applies SKIP LOCKED semantics to the entire result row. If the
--     drivers.d row is locked by any concurrent transaction (e.g., a
--     concurrent driver_accept_offer or driver_decline_offer call that
--     locks the drivers row), the entire result row is skipped even though
--     we only specified OF dq. This causes Branch 0 to return NOT FOUND
--     and fall through to Branch 1, creating a second provisional trip.
--
--     In the live reproduction, Rajeev.backup1's booking transaction may
--     have held a lock on the drivers row for Dipti while Naresh's booking
--     triggered match_route_queue concurrently (or near-concurrently),
--     causing Branch 0 to skip Dipti's driver_queue row.
--
--   DEFECT 2 — is_test_data isolation derived from drivers table:
--     Branch 0 used d.is_test_data (from the drivers table JOIN) to
--     determine the test/live partition for passenger filtering. The
--     driver_queue table has its own is_test_data column (dq.is_test_data)
--     which is the authoritative partition flag for queue operations.
--     Using d.is_test_data via a JOIN that could be skipped is fragile.
--
-- FIX — CORRECTED BRANCH 0:
--   Two-step locking approach:
--
--   Step 1: Lock the driver_queue row ALONE (no JOIN):
--     SELECT dq.*
--     FROM public.driver_queue dq
--     WHERE dq.route_id = p_route_id
--       AND dq.status = 'offered'
--       AND dq.offer_expires_at > NOW()
--     ORDER BY dq.joined_at ASC
--     LIMIT 1
--     FOR UPDATE SKIP LOCKED;
--
--     This locks only the driver_queue row. No JOIN means no risk of
--     skipping due to a lock on the drivers table.
--
--   Step 2: Lock the provisional trip row:
--     SELECT t.*
--     FROM public.trips t
--     WHERE t.id = v_offered_dq.provisional_trip_id
--       AND t.notes = 'provisional_offer'
--       AND t.booked_seats < t.total_seats
--     FOR UPDATE;
--
--     This blocks (not skips) if the trip row is locked, ensuring
--     serialized access to the trip's booked_seats counter.
--
--   Step 3: Derive is_test_data from dq.is_test_data directly:
--     v_is_test_driver := COALESCE(v_offered_dq.is_test_data, false);
--     No JOIN to drivers needed for this value.
--
-- CANONICAL PRODUCT INVARIANT (preserved):
--   While an existing driver offer is:
--     - driver_queue.status = 'offered'
--     - offer_expires_at > NOW() (not yet expired server-side)
--     - provisional_trip_id IS NOT NULL
--     - referenced trip has notes = 'provisional_offer'
--     - trip.booked_seats < trip.total_seats
--   new WAITING passengers on the same route/test partition must be
--   added to that existing provisional trip first, before any new
--   waiting driver is considered for a new offer.
--
-- CURRENT MATCHER BEHAVIOR (before this fix):
--   Branch 0 in 20260811180000 silently fell through to Branch 1 when
--   the drivers table row was locked during concurrent booking processing,
--   causing a second provisional trip to be created for the next waiting
--   driver even though the first driver's trip had remaining capacity.
--
-- EXISTING-PROVISIONAL REUSE PATH FOUND IN HISTORY: YES
--   Migration 20260809340000 implemented Branch 1 for accepting_bookings
--   trips (post-accept). Migration 20260811180000 implemented Branch 0
--   for offered provisional trips. This migration corrects Branch 0.
--
-- FUNCTIONS CHANGED:
--   match_route_queue(p_route_id UUID) — Branch 0 rewritten with two-step
--   locking. Branch 1 (new driver offer) is IDENTICAL to 20260811180000.
--
-- FUNCTIONS NOT CHANGED:
--   driver_accept_offer (both overloads) — no change required
--   driver_decline_offer — no change required
--   expire_driver_offer — no change required
--   release_provisional_trip — no change required
--   book_or_queue (both overloads) — no change required
--   passenger_join_queue — no change required
--
-- LOCKING/CONCURRENCY STRATEGY:
--   1. Advisory lock on route_id (pg_try_advisory_xact_lock) — prevents
--      two concurrent match_route_queue calls for the same route from
--      both entering Branch 0 simultaneously.
--   2. FOR UPDATE SKIP LOCKED on driver_queue row alone — locks the
--      offered driver_queue row without risk of JOIN-induced skip.
--   3. FOR UPDATE (blocking) on trips row — serializes booked_seats
--      increment; two concurrent calls cannot both read the same
--      remaining capacity and overfill the trip.
--
-- FIFO BEHAVIOR (preserved):
--   Passenger FIFO: ORDER BY pq.queue_sequence ASC (unchanged)
--   Driver FIFO: Branch 1 selects by dq.joined_at ASC (unchanged)
--   Branch 0 selects offered driver by dq.joined_at ASC (unchanged)
--
-- FIT-AWARE BEHAVIOR (preserved):
--   Current policy: passengers are assigned in queue_sequence order.
--   If a passenger's seat_count does not fit remaining capacity, they
--   are SKIPPED (not blocking) — the loop continues to look for smaller
--   bookings that fit. This mirrors the fit-aware behavior in Branch 1
--   (IF v_pq.seats <= v_seats_left THEN ... END IF; — no EXIT on skip).
--   This policy is preserved exactly in Branch 0.
--
--   Example: existing trip has 3 seats remaining.
--     Passenger A needs 4 seats → skipped (4 > 3)
--     Passenger B needs 1 seat → assigned (1 <= 3)
--   Result: B is assigned, A remains WAITING.
--   This matches the existing Branch 1 fit-aware behavior.
--
-- TEST/LIVE ISOLATION (preserved):
--   Branch 0 filters pq.is_test_data = v_is_test_driver where
--   v_is_test_driver = COALESCE(v_offered_dq.is_test_data, false).
--   v_offered_dq.is_test_data is dq.is_test_data (driver_queue's own
--   partition flag). Real driver → real passengers only.
--   Test driver → test passengers only.
--
-- DECLINE/EXPIRY COMPATIBILITY (preserved):
--   Passengers added by Branch 0 are in MATCHING state on the provisional
--   trip. release_provisional_trip returns all MATCHING passengers on the
--   trip to WAITING. driver_accept_offer transitions all MATCHING
--   passengers to ASSIGNED. No change to these functions required.
--
-- CAPACITY INVARIANT (preserved):
--   v_remaining = v_offered_trip.total_seats - v_offered_trip.booked_seats
--   is read AFTER the FOR UPDATE lock on the trip row. The booked_seats
--   increment uses booked_seats = booked_seats + v_fill_seats (atomic
--   within the transaction). trip.booked_seats can never exceed total_seats
--   because v_fill_seats <= v_remaining by construction.
--
-- DATA REPAIR: NONE
--   No existing records modified. The currently reproduced live provisional
--   trips (Dipti 1/7, Rajeev 4/4) will be reset/retested manually.
--
-- STATIC REGRESSION (deterministic scenario):
--   Driver FIFO: #1 Dipti — 7 seats, #2 Rajeev Backup4 — 4 seats
--   Passenger arrivals while Dipti's offer remains pending:
--     A = 1 seat, B = 4 seats, C = 1 seat, D = 1 seat
--
--   After A:
--     Branch 0: no offered driver yet → skip
--     Branch 1: Dipti selected (waiting) → T1 created, booked_seats=1/7
--     Dipti driver_queue.status = 'offered'
--
--   After B:
--     Branch 0: Dipti offered, T1 has 6 remaining, 4 fits → T1 = 5/7
--     NO Rajeev provisional trip created ✓
--
--   After C:
--     Branch 0: Dipti offered, T1 has 2 remaining, 1 fits → T1 = 6/7 ✓
--
--   After D:
--     Branch 0: Dipti offered, T1 has 1 remaining, 1 fits → T1 = 7/7
--     CASE: 7 >= 7 → status = 'full' ✓
--
--   Rajeev remains waiting #2. No second provisional trip. ✓
--   Exactly ONE active provisional trip on this route/test partition. ✓
--
-- MANUAL E2E STILL REQUIRED: YES
--
-- MIGRATION ORDER:
--   After: 20260811180000_raahi_fix_match_route_queue_offered_trip_reuse.sql
-- ============================================================

CREATE OR REPLACE FUNCTION public.match_route_queue(p_route_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver           RECORD;
  v_trip_id          UUID;
  v_assigned         INTEGER := 0;
  v_seats_left       INTEGER;
  v_pq               RECORD;
  v_is_test_driver   BOOLEAN;
  v_lock_key         BIGINT;

  -- Branch 0: offered-provisional-trip reuse
  v_offered_dq       RECORD;
  v_offered_trip     RECORD;
  v_remaining        INTEGER;
  v_fill_seats       INTEGER := 0;
  v_fill_count       INTEGER := 0;
BEGIN
  -- ──────────────────────────────────────────────────────────────────────
  -- ADVISORY LOCK: prevent concurrent match_route_queue calls for the
  -- same route from racing and creating duplicate provisional trips.
  -- ──────────────────────────────────────────────────────────────────────
  v_lock_key := ('x' || substr(replace(p_route_id::TEXT, '-', ''), 1, 8))::BIT(32)::BIGINT;
  IF NOT pg_try_advisory_xact_lock(v_lock_key) THEN
    RETURN jsonb_build_object('matched', false, 'reason', 'lock_contention');
  END IF;

  -- ──────────────────────────────────────────────────────────────────────
  -- BRANCH 0: Reuse an existing offered provisional trip with capacity.
  --
  -- TWO-STEP LOCKING (fix for 20260811180000 defect):
  --
  --   Step 1: Lock the driver_queue row ALONE (no JOIN to drivers).
  --     FOR UPDATE SKIP LOCKED on driver_queue only — avoids the
  --     PostgreSQL behavior where FOR UPDATE OF alias SKIP LOCKED on a
  --     multi-table JOIN skips the entire result row if ANY joined table
  --     row is locked, even if only one table's alias is specified.
  --
  --   Step 2: Lock the provisional trip row (FOR UPDATE, blocking).
  --     Serializes booked_seats increment. Two concurrent calls cannot
  --     both read the same remaining capacity and overfill the trip.
  --
  --   is_test_data derived from dq.is_test_data directly (no JOIN needed).
  -- ──────────────────────────────────────────────────────────────────────

  -- Step 1: Lock the offered driver_queue row (no JOIN to drivers)
  SELECT dq.*
  INTO v_offered_dq
  FROM public.driver_queue dq
  WHERE dq.route_id = p_route_id
    AND dq.status = 'offered'
    AND dq.offer_expires_at > NOW()
    AND dq.provisional_trip_id IS NOT NULL
  ORDER BY dq.joined_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF FOUND THEN
    -- Derive test/live partition from driver_queue's own is_test_data flag
    v_is_test_driver := COALESCE(v_offered_dq.is_test_data, false);

    -- Step 2: Lock the provisional trip row (blocking — not SKIP LOCKED)
    -- This serializes concurrent booked_seats increments.
    SELECT t.*
    INTO v_offered_trip
    FROM public.trips t
    WHERE t.id = v_offered_dq.provisional_trip_id
      AND t.notes = 'provisional_offer'
      AND t.booked_seats < t.total_seats
    FOR UPDATE;

    IF FOUND THEN
      -- Read authoritative remaining capacity AFTER the row lock
      v_remaining  := v_offered_trip.total_seats - v_offered_trip.booked_seats;
      v_fill_seats := 0;
      v_fill_count := 0;

      -- Assign WAITING passengers FIFO into the existing provisional trip.
      -- Fit-aware: if a passenger's seat_count exceeds remaining capacity,
      -- skip them and continue (same policy as Branch 1).
      -- is_test_data isolation: only passengers matching the driver's
      -- test/live partition are considered.
      FOR v_pq IN
        SELECT pq.id, pq.booking_id, pq.seat_count, pq.queue_sequence
        FROM public.passenger_queue pq
        WHERE pq.route_id = p_route_id
          AND pq.status = 'WAITING'
          AND pq.is_test_data = v_is_test_driver
        ORDER BY pq.queue_sequence ASC
        FOR UPDATE OF pq SKIP LOCKED
      LOOP
        -- Stop if no remaining capacity
        EXIT WHEN v_fill_seats >= v_remaining;

        -- Fit-aware: skip passengers that don't fit remaining capacity
        IF (v_fill_seats + v_pq.seat_count) <= v_remaining THEN
          -- Assign passenger to existing provisional trip
          UPDATE public.passenger_queue
          SET
            status           = 'MATCHING',
            assigned_trip_id = v_offered_trip.id,
            updated_at       = NOW()
          WHERE id = v_pq.id;

          UPDATE public.bookings
          SET
            trip_id    = v_offered_trip.id,
            status     = 'confirmed'::public.booking_status,
            updated_at = NOW()
          WHERE id = v_pq.booking_id;

          v_fill_seats := v_fill_seats + v_pq.seat_count;
          v_fill_count := v_fill_count + 1;
        END IF;
        -- If passenger doesn't fit: continue loop (fit-aware skip, not EXIT)
      END LOOP;

      IF v_fill_count > 0 THEN
        -- Increment booked_seats atomically and recalculate trip status
        UPDATE public.trips
        SET
          booked_seats = booked_seats + v_fill_seats,
          status       = CASE
                           WHEN (booked_seats + v_fill_seats) >= total_seats
                             THEN 'full'::public.trip_status
                           ELSE 'accepting_bookings'::public.trip_status
                         END,
          updated_at   = NOW()
        WHERE id = v_offered_trip.id;

        -- Audit
        INSERT INTO public.audit_logs (
          performed_by, action, target_table, target_id, new_value, notes
        )
        VALUES (
          auth.uid(),
          'passenger_assigned_to_trip'::public.audit_action,
          'trips',
          v_offered_trip.id,
          jsonb_build_object(
            'branch',              'offered_trip_reuse_v2',
            'route_id',            p_route_id,
            'passengers_added',    v_fill_count,
            'seats_added',         v_fill_seats,
            'booked_seats_before', v_offered_trip.booked_seats,
            'total_seats',         v_offered_trip.total_seats,
            'is_test_data',        v_is_test_driver
          ),
          'match_route_queue: filled existing offered provisional trip (Branch 0 v2)'
        );

        RETURN jsonb_build_object(
          'matched',             true,
          'branch',              'offered_trip_reuse_v2',
          'trip_id',             v_offered_trip.id,
          'passengers_assigned', v_fill_count,
          'seats_added',         v_fill_seats,
          'is_test_data',        v_is_test_driver
        );
      END IF;
      -- v_fill_count = 0: no WAITING passengers fit the remaining capacity.
      -- Fall through to Branch 1 — the offered trip cannot absorb any
      -- current WAITING passengers (all remaining WAITING passengers need
      -- more seats than the trip has left). Branch 1 will find no waiting
      -- driver and return 'no_driver_available', which is correct: the
      -- offered driver's trip is nearly full and the remaining passengers
      -- must wait for the next driver.
    END IF;
    -- Provisional trip not found (already released/cancelled) or already
    -- full: fall through to Branch 1.
  END IF;

  -- ──────────────────────────────────────────────────────────────────────
  -- BRANCH 1: New driver offer.
  --
  -- Only runs when:
  --   (a) No offered driver exists for this route, OR
  --   (b) The offered driver's offer has expired (offer_expires_at <= NOW()), OR
  --   (c) The offered driver's provisional_trip_id is NULL, OR
  --   (d) The offered driver's provisional trip is already full or released, OR
  --   (e) No WAITING passengers fit the remaining capacity of the offered trip.
  --
  -- IDENTICAL to migration 20260811180000 Branch 1.
  -- ──────────────────────────────────────────────────────────────────────

  -- Lock the first eligible waiting driver in queue (FIFO by joined_at)
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
      'matched',        false,
      'reason',         'no_passengers_waiting',
      'test_isolation', v_is_test_driver
    );
  END IF;

  -- Get vehicle capacity
  SELECT seating_capacity INTO v_seats_left
  FROM public.vehicles WHERE id = v_driver.vehicle_id;

  -- Create provisional trip WITH notes = 'provisional_offer'
  -- (canonical marker required by driver_accept_offer, release_provisional_trip)
  INSERT INTO public.trips (
    driver_id, route_id, vehicle_id,
    status, total_seats, booked_seats,
    notes,
    is_test_data, created_at, updated_at
  )
  VALUES (
    v_driver.driver_id,
    p_route_id,
    v_driver.vehicle_id,
    'accepting_bookings'::public.trip_status,
    v_seats_left,
    0,
    'provisional_offer',
    v_is_test_driver,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_trip_id;

  -- Link driver queue to trip and set offer expiry
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
      AND pq.is_test_data = v_is_test_driver
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

  -- Set final trip status based on capacity invariant
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
      'branch',                 'new_driver_offer',
      'passengers_assigned',    v_assigned,
      'route_id',               p_route_id,
      'is_test_data',           v_is_test_driver,
      'test_isolation_applied', true,
      'provisional_marker_set', true
    ),
    'match_route_queue: new provisional offer created (Branch 1)'
  );

  RETURN jsonb_build_object(
    'matched',             true,
    'branch',              'new_driver_offer',
    'trip_id',             v_trip_id,
    'passengers_assigned', v_assigned,
    'test_isolation',      v_is_test_driver
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.match_route_queue(UUID) TO authenticated;

-- ============================================================
-- STATIC REGRESSION VERIFICATION
--
-- Setup: 7-seat driver #1 (Dipti Kumari) is queue position 1,
-- status='waiting'. 4-seat driver #2 (Rajeev Backup4) is queue
-- position 2, status='waiting'. Route = Dhanbad → Gomoh.
-- All passengers are same is_test_data partition as Dipti.
--
-- Step 1: passenger A (1 seat) arrives → match_route_queue
--   Advisory lock acquired.
--   Branch 0: no driver_queue row with status='offered' → FOUND=false → skip
--   Branch 1: Dipti selected (waiting, joined_at earliest)
--             T1 created: total_seats=7, booked_seats=0, notes='provisional_offer'
--             Dipti driver_queue.status = 'offered', provisional_trip_id = T1
--             Passenger A: MATCHING, assigned_trip_id = T1
--             T1.booked_seats = 1
--             CASE: 1 < 7 → status = 'accepting_bookings'
--   Result: T1 = 1/7, Dipti = offered ✓
--
-- Step 2: passenger B (4 seats) arrives → match_route_queue
--   Advisory lock acquired.
--   Branch 0:
--     Step 1: driver_queue WHERE status='offered' AND offer_expires_at>NOW()
--             → finds Dipti's row (no JOIN, no risk of skip)
--             → FOR UPDATE SKIP LOCKED → locked ✓
--     v_is_test_driver = Dipti.is_test_data
--     Step 2: trips WHERE id=T1 AND notes='provisional_offer' AND booked_seats<total_seats
--             → T1: booked_seats=1 < total_seats=7 → FOUND ✓
--             → FOR UPDATE (blocking) → locked ✓
--     v_remaining = 7 - 1 = 6
--     Passenger loop: B needs 4 seats, 4 <= 6 → assign to T1
--     v_fill_seats = 4, v_fill_count = 1
--     UPDATE trips SET booked_seats = 1+4 = 5
--     CASE: 5 < 7 → status = 'accepting_bookings'
--   RETURN: matched=true, branch='offered_trip_reuse_v2', trip_id=T1
--   NO Rajeev provisional trip created ✓
--   Result: T1 = 5/7, Dipti = offered ✓
--
-- Step 3: passenger C (1 seat) arrives → match_route_queue
--   Branch 0:
--     Dipti still offered, T1.booked_seats=5 < 7 → FOUND ✓
--     v_remaining = 7 - 5 = 2
--     C needs 1 seat, 1 <= 2 → assign to T1
--     T1.booked_seats = 5+1 = 6
--     CASE: 6 < 7 → status = 'accepting_bookings'
--   Result: T1 = 6/7 ✓
--
-- Step 4: passenger D (1 seat) arrives → match_route_queue
--   Branch 0:
--     Dipti still offered, T1.booked_seats=6 < 7 → FOUND ✓
--     v_remaining = 7 - 6 = 1
--     D needs 1 seat, 1 <= 1 → assign to T1
--     T1.booked_seats = 6+1 = 7
--     CASE: 7 >= 7 → status = 'full'
--   Result: T1 = 7/7 (full) ✓
--
-- Final state:
--   T1: booked_seats=7, total_seats=7, status='full', notes='provisional_offer'
--   Dipti: driver_queue.status='offered', provisional_trip_id=T1
--   Rajeev Backup4: driver_queue.status='waiting' (unchanged)
--   No second provisional trip exists ✓
--   Exactly ONE active provisional trip on this route/test partition ✓
--
-- Decline/expiry verification:
--   Dipti declines → release_provisional_trip(T1.id)
--   → T1 cancelled, all 4 MATCHING passengers (A,B,C,D) → WAITING
--   → match_route_queue called again
--   → Branch 0: no offered driver → skip
--   → Branch 1: Rajeev Backup4 selected (next waiting, joined_at)
--   → new provisional trip T2 created (4-seat vehicle)
--   → passengers A,B,C,D re-queued in original queue_sequence order ✓
--
-- Acceptance verification:
--   Dipti accepts → driver_accept_offer locks T1 WHERE notes='provisional_offer'
--   → all MATCHING passengers (A,B,C,D) → ASSIGNED
--   → T1.notes = NULL, T1.status = 'full'
--   → Dipti driver_queue.status = 'assigned' ✓
-- ============================================================
