-- ============================================================
-- RAAHI — Fix match_route_queue: Post-Accept Active-Trip Fill
-- Migration: 20260814030000_raahi_fix_match_route_queue_accepted_trip_fill.sql
-- ============================================================
--
-- ROOT CAUSE (DB-proven, production state):
--
--   After driver_accept_offer runs:
--     driver_queue.status        = 'assigned'
--     driver_queue.provisional_trip_id = <trip_id>
--     trip.status                = 'accepting_bookings'
--     trip.notes                 = NULL   ← provisional_offer marker cleared
--     trip.booked_seats          = 1      (Rajeev.backup3.2112, 1 seat)
--     trip.total_seats           = 4
--
--   New passenger arrives: Rajeev backup2, 2 seats, WAITING.
--
--   Current match_route_queue (20260811190000) has:
--     Branch 0: fills an offered provisional trip WHERE notes='provisional_offer'
--               → trip.notes = NULL after accept → Branch 0 condition fails → skip
--     Branch 1: creates a new offer for a WAITING driver
--               → no waiting driver exists → returns 'no_driver_available'
--
--   Result: 2-seat passenger remains WAITING. Trip stays 1/4.
--   The accepted accepting_bookings trip with spare capacity is invisible
--   to both existing branches.
--
-- CANONICAL INVARIANT (new — Branch 1.5):
--
--   Before considering a new waiting driver (Branch 1), the matcher MUST
--   fill the current eligible accepted pre-departure trip on this route
--   when ALL of the following hold:
--
--     1. driver_queue.status = 'assigned'           (driver has accepted)
--     2. drivers.availability_status = 'active'     (driver is operationally active)
--     3. trip.status = 'accepting_bookings'          (passenger-eligible pre-departure)
--     4. trip.notes IS NULL OR trip.notes != 'provisional_offer'
--                                                    (offer marker cleared by accept)
--     5. trip.booked_seats < trip.total_seats        (spare capacity exists)
--     6. driver_queue.route_id = p_route_id          (same route)
--     7. driver_queue.is_test_data = passenger partition (test/live isolation)
--
-- REQUIRED ORDERING (preserved):
--
--   Branch 0   — Reuse existing offered provisional trip (notes='provisional_offer')
--                [UNCHANGED from 20260811190000]
--   Branch 1.5 — Fill already-accepted pre-departure trip with spare capacity
--                [NEW — this migration]
--   Branch 1   — Create a new offer for the next waiting driver
--                [UNCHANGED from 20260811190000]
--
-- PASSENGER STATUS TRANSITION (post-accept fill):
--
--   Because the driver has already accepted, passengers added to this
--   accepted trip become canonical assigned/confirmed state immediately:
--
--     passenger_queue.assigned_trip_id = trip.id
--     passenger_queue.status           = 'ASSIGNED'   (not MATCHING)
--     booking.trip_id                  = trip.id
--     booking.status                   = 'confirmed'
--     trip.booked_seats               += seats
--
--   This differs from Branch 0 (offered trip) where passengers become
--   MATCHING and are transitioned to ASSIGNED by driver_accept_offer.
--
-- CAPACITY STATUS TRANSITION:
--
--   After incrementing booked_seats:
--     IF booked_seats >= total_seats → trip.status = 'full'
--     ELSE                           → trip.status = 'accepting_bookings'
--
-- LOCKING STRATEGY:
--
--   1. Advisory lock on route_id (existing, unchanged).
--   2. FOR UPDATE SKIP LOCKED on driver_queue row alone (no JOIN) —
--      same two-step pattern as Branch 0 v2.
--   3. FOR UPDATE (blocking) on trips row — serializes booked_seats
--      increment; concurrent calls cannot overfill the trip.
--   4. FOR UPDATE SKIP LOCKED on passenger_queue rows.
--
-- CONTROL FLOW NOTE:
--   PL/pgSQL does not support GOTO. Fall-through from Branch 1.5 to
--   Branch 1 is implemented via a boolean flag v_skip_b15. When Branch
--   1.5 determines the driver is not operationally active, it sets
--   v_skip_b15 = true and the outer IF block is skipped, falling
--   naturally into Branch 1.
--
-- DO NOT CALL activate_next_driver.
--
-- PRESERVED INVARIANTS:
--   Route advisory lock, Branch 0 offered-provisional locking semantics,
--   FIFO passenger consideration, fit-aware skip policy, test/live
--   isolation, offer expiry/decline, driver FIFO, cancellation/no-show,
--   Start Trip origin queue release, frontend behavior.
--
-- FUNCTIONS CHANGED:
--   match_route_queue(p_route_id UUID) — Branch 1.5 inserted between
--   Branch 0 and Branch 1. Branch 0 and Branch 1 are IDENTICAL to
--   migration 20260811190000.
--
-- FUNCTIONS NOT CHANGED:
--   driver_accept_offer, driver_decline_offer, expire_driver_offer,
--   release_provisional_trip, book_or_queue, passenger_join_queue,
--   cancel_booking, activate_next_driver, any frontend file.
--
-- LIVE REMATCH ACTION:
--   After deploying, call match_route_queue(p_route_id) for the affected
--   route to rematch the existing WAITING 2-seat booking canonically.
--   Do NOT hard-edit passenger rows directly.
--
-- MIGRATION ORDER:
--   After: 20260814020000_raahi_fix_get_passenger_booking_record_hazard.sql
--
-- MANUAL E2E REQUIRED: YES
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

  -- Branch 1.5: accepted pre-departure trip fill
  v_accepted_dq      RECORD;
  v_accepted_trip    RECORD;
  v_acc_remaining    INTEGER;
  v_acc_fill_seats   INTEGER := 0;
  v_acc_fill_count   INTEGER := 0;
  v_skip_b15         BOOLEAN := false;
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
  -- TWO-STEP LOCKING (from 20260811190000 — UNCHANGED):
  --   Step 1: Lock the driver_queue row ALONE (no JOIN to drivers).
  --   Step 2: Lock the provisional trip row (FOR UPDATE, blocking).
  --   is_test_data derived from dq.is_test_data directly.
  -- ──────────────────────────────────────────────────────────────────────

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
    v_is_test_driver := COALESCE(v_offered_dq.is_test_data, false);

    SELECT t.*
    INTO v_offered_trip
    FROM public.trips t
    WHERE t.id = v_offered_dq.provisional_trip_id
      AND t.notes = 'provisional_offer'
      AND t.booked_seats < t.total_seats
    FOR UPDATE;

    IF FOUND THEN
      v_remaining  := v_offered_trip.total_seats - v_offered_trip.booked_seats;
      v_fill_seats := 0;
      v_fill_count := 0;

      FOR v_pq IN
        SELECT pq.id, pq.booking_id, pq.seat_count, pq.queue_sequence
        FROM public.passenger_queue pq
        WHERE pq.route_id = p_route_id
          AND pq.status = 'WAITING'
          AND pq.is_test_data = v_is_test_driver
        ORDER BY pq.queue_sequence ASC
        FOR UPDATE OF pq SKIP LOCKED
      LOOP
        EXIT WHEN v_fill_seats >= v_remaining;

        IF (v_fill_seats + v_pq.seat_count) <= v_remaining THEN
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
      END LOOP;

      IF v_fill_count > 0 THEN
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
      -- v_fill_count = 0: no WAITING passengers fit remaining capacity.
      -- Fall through to Branch 1.5.
    END IF;
    -- Provisional trip not found, already full, or released.
    -- Fall through to Branch 1.5.
  END IF;

  -- ──────────────────────────────────────────────────────────────────────
  -- BRANCH 1.5: Fill an already-accepted pre-departure trip with spare
  -- capacity.
  --
  -- Fires when Branch 0 did not return (no offered trip, offered trip
  -- full/released, or no WAITING passengers fit the offered trip).
  --
  -- Eligible accepted trip criteria:
  --   driver_queue.status = 'assigned'
  --   drivers.availability_status = 'active'
  --   trip.status = 'accepting_bookings'
  --   trip.notes IS NULL OR trip.notes != 'provisional_offer'
  --   trip.booked_seats < trip.total_seats
  --   same route_id and is_test_data partition
  --
  -- Locking: two-step (same as Branch 0 v2):
  --   Step 1: FOR UPDATE SKIP LOCKED on driver_queue alone (no JOIN)
  --   Step 2: FOR UPDATE (blocking) on trips row
  --
  -- Passenger transition: ASSIGNED/confirmed immediately (not MATCHING),
  -- because driver_accept_offer has already run for this trip.
  --
  -- Control flow: v_skip_b15 is set true when the driver is not
  -- operationally active, causing the fill block to be skipped and
  -- execution to fall through to Branch 1 naturally.
  -- ──────────────────────────────────────────────────────────────────────

  -- Step 1: Lock the assigned driver_queue row (no JOIN to drivers table)
  SELECT dq.*
  INTO v_accepted_dq
  FROM public.driver_queue dq
  WHERE dq.route_id = p_route_id
    AND dq.status = 'assigned'
    AND dq.provisional_trip_id IS NOT NULL
  ORDER BY dq.joined_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF FOUND THEN
    -- Verify driver is operationally active (separate query, no JOIN hazard)
    IF NOT EXISTS (
      SELECT 1
      FROM public.drivers d
      WHERE d.id = v_accepted_dq.driver_id
        AND d.availability_status = 'active'
    ) THEN
      v_skip_b15 := true;
    END IF;

    IF NOT v_skip_b15 THEN
      -- Derive test/live partition from driver_queue's own is_test_data flag
      v_is_test_driver := COALESCE(v_accepted_dq.is_test_data, false);

      -- Step 2: Lock the accepted trip row (blocking — not SKIP LOCKED).
      -- Eligible: accepting_bookings, notes cleared (not provisional_offer),
      -- spare capacity exists.
      SELECT t.*
      INTO v_accepted_trip
      FROM public.trips t
      WHERE t.id = v_accepted_dq.provisional_trip_id
        AND t.status = 'accepting_bookings'::public.trip_status
        AND (t.notes IS NULL OR t.notes != 'provisional_offer')
        AND t.booked_seats < t.total_seats
      FOR UPDATE;

      IF FOUND THEN
        v_acc_remaining  := v_accepted_trip.total_seats - v_accepted_trip.booked_seats;
        v_acc_fill_seats := 0;
        v_acc_fill_count := 0;

        -- Assign WAITING passengers FIFO into the accepted trip.
        -- Fit-aware: skip passengers whose seat_count exceeds remaining
        -- capacity; continue looking for smaller bookings that fit.
        -- Test/live isolation: pq.is_test_data = v_is_test_driver.
        -- Status: ASSIGNED (not MATCHING) — driver already accepted.
        FOR v_pq IN
          SELECT pq.id, pq.booking_id, pq.seat_count, pq.queue_sequence
          FROM public.passenger_queue pq
          WHERE pq.route_id = p_route_id
            AND pq.status = 'WAITING'
            AND pq.is_test_data = v_is_test_driver
          ORDER BY pq.queue_sequence ASC
          FOR UPDATE OF pq SKIP LOCKED
        LOOP
          EXIT WHEN v_acc_fill_seats >= v_acc_remaining;

          IF (v_acc_fill_seats + v_pq.seat_count) <= v_acc_remaining THEN
            -- Assign immediately as ASSIGNED/confirmed (driver already accepted)
            UPDATE public.passenger_queue
            SET
              status           = 'ASSIGNED',
              assigned_trip_id = v_accepted_trip.id,
              updated_at       = NOW()
            WHERE id = v_pq.id;

            UPDATE public.bookings
            SET
              trip_id    = v_accepted_trip.id,
              status     = 'confirmed'::public.booking_status,
              updated_at = NOW()
            WHERE id = v_pq.booking_id;

            v_acc_fill_seats := v_acc_fill_seats + v_pq.seat_count;
            v_acc_fill_count := v_acc_fill_count + 1;
          END IF;
          -- Fit-aware: if passenger does not fit, continue loop (not EXIT)
        END LOOP;

        IF v_acc_fill_count > 0 THEN
          -- Atomically increment booked_seats and recalculate trip status.
          -- Row is already locked FOR UPDATE above; concurrent calls cannot
          -- overfill the trip.
          UPDATE public.trips
          SET
            booked_seats = booked_seats + v_acc_fill_seats,
            status       = CASE
                             WHEN (booked_seats + v_acc_fill_seats) >= total_seats
                               THEN 'full'::public.trip_status
                             ELSE 'accepting_bookings'::public.trip_status
                           END,
            updated_at   = NOW()
          WHERE id = v_accepted_trip.id;

          INSERT INTO public.audit_logs (
            performed_by, action, target_table, target_id, new_value, notes
          )
          VALUES (
            auth.uid(),
            'passenger_assigned_to_trip'::public.audit_action,
            'trips',
            v_accepted_trip.id,
            jsonb_build_object(
              'branch',              'accepted_trip_fill',
              'route_id',            p_route_id,
              'passengers_added',    v_acc_fill_count,
              'seats_added',         v_acc_fill_seats,
              'booked_seats_before', v_accepted_trip.booked_seats,
              'total_seats',         v_accepted_trip.total_seats,
              'is_test_data',        v_is_test_driver,
              'driver_queue_id',     v_accepted_dq.id
            ),
            'match_route_queue: filled accepted pre-departure trip (Branch 1.5)'
          );

          RETURN jsonb_build_object(
            'matched',             true,
            'branch',              'accepted_trip_fill',
            'trip_id',             v_accepted_trip.id,
            'passengers_assigned', v_acc_fill_count,
            'seats_added',         v_acc_fill_seats,
            'is_test_data',        v_is_test_driver
          );
        END IF;
        -- v_acc_fill_count = 0: no WAITING passengers fit remaining capacity.
        -- Fall through to Branch 1.
      END IF;
      -- Accepted trip not found, already full, or not in eligible state.
      -- Fall through to Branch 1.
    END IF;
    -- v_skip_b15 = true: driver not operationally active.
    -- Fall through to Branch 1.
  END IF;

  -- ──────────────────────────────────────────────────────────────────────
  -- BRANCH 1: New driver offer.
  --
  -- Only runs when Branch 0 and Branch 1.5 both did not return.
  -- IDENTICAL to migration 20260811190000 Branch 1.
  -- ──────────────────────────────────────────────────────────────────────

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

  SELECT seating_capacity INTO v_seats_left
  FROM public.vehicles WHERE id = v_driver.vehicle_id;

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

  UPDATE public.driver_queue
  SET
    status              = 'offered'::public.queue_status,
    provisional_trip_id = v_trip_id,
    offer_expires_at    = NOW() + (
      SELECT COALESCE(value::INTEGER, 45) * INTERVAL '1 second'
      FROM public.business_settings WHERE key = 'driver_offer_timeout_seconds'
    )
  WHERE id = v_driver.id;

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
-- VERIFICATION QUERIES (run after applying this migration)
--
-- 1. Confirm exactly one match_route_queue signature exists:
--    SELECT proname, pg_get_function_identity_arguments(oid)
--    FROM pg_proc
--    WHERE proname = 'match_route_queue'
--      AND pronamespace = 'public'::regnamespace;
--    Expected: one row → match_route_queue(p_route_id uuid)
--
-- 2. Trigger live rematch for the affected route:
--    SELECT public.match_route_queue('<route_id_for_rajeev_backup4_trip>');
--    Expected: {"matched": true, "branch": "accepted_trip_fill", ...}
--
-- 3. Verify Rajeev backup2 (2-seat) is now ASSIGNED:
--    SELECT pq.status, pq.assigned_trip_id, pq.seat_count
--    FROM public.passenger_queue pq
--    JOIN public.bookings b ON b.id = pq.booking_id
--    JOIN public.profiles p ON p.id = b.passenger_id
--    WHERE p.name ILIKE '%rajeev%backup2%';
--    Expected: status='ASSIGNED', assigned_trip_id=<trip_id>
--
-- 4. Verify trip booked_seats = 3 (1 existing + 2 new):
--    SELECT id, booked_seats, total_seats, status
--    FROM public.trips
--    WHERE id = '104287af-f7fc-4bfa-a6d2-e0eee79556b9';
--    Expected: booked_seats=3, total_seats=4, status='accepting_bookings'
--
-- 5. Verify Rajeev backup2 booking is confirmed:
--    SELECT b.status, b.trip_id, b.seats
--    FROM public.bookings b
--    JOIN public.profiles p ON p.id = b.passenger_id
--    WHERE p.name ILIKE '%rajeev%backup2%';
--    Expected: status='confirmed', trip_id='104287af-f7fc-4bfa-a6d2-e0eee79556b9'
-- ============================================================
