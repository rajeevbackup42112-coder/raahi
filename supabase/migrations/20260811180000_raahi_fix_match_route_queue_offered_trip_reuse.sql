-- ============================================================
-- RAAHI — Fix match_route_queue: Offered-Trip Reuse Branch
-- Migration: 20260811180000_raahi_fix_match_route_queue_offered_trip_reuse.sql
-- ============================================================
--
-- ROOT CAUSE (confirmed from production reproduction):
--
--   Scenario: Dhanbad → Gomoh route
--     Driver Dipti Kumari: queue position 1, 7-seat vehicle, status='waiting'
--     Passenger Rajeev.backup1 (1 seat) arrives →
--       match_route_queue runs → finds Dipti (waiting) →
--       creates provisional trip 2c242a27 with 1/7 seats →
--       sets Dipti driver_queue.status = 'offered'
--
--     Passenger Naresh Kumar (4 seats) arrives →
--       match_route_queue runs again →
--       current function: SELECT dq.* WHERE dq.status = 'waiting' →
--       Dipti is now 'offered' → SKIPPED →
--       finds Rajeev Backup4 (queue position 2, status='waiting') →
--       creates SECOND provisional trip 1f074ec2 with 4/4 seats
--
--   Result: two simultaneous provisional trips on the same route.
--   Trip 2c242a27: 1/7 seats occupied (6 wasted).
--   Trip 1f074ec2: 4/4 seats occupied.
--
-- EXACT MISSING LOGIC:
--   The current match_route_queue (20260811140000) has NO branch that
--   checks for an existing offered provisional trip with remaining
--   capacity before falling through to select a new waiting driver.
--
--   The idempotency guard present in migration 20260809080000
--   (IF EXISTS ... status = 'offered' THEN RETURN 'offer_already_pending')
--   was removed in migration 20260811120000 and not restored. That guard
--   prevented the second trip but also prevented filling the first trip.
--   The correct fix is not to restore the early-return guard but to add
--   a fill branch that adds new passengers to the existing offered trip.
--
-- PRIOR REUSE PATH:
--   Migration 20260809340000_raahi_fix_existing_trip_matching.sql
--   implemented Branch 1 for 'accepting_bookings' trips (driver assigned,
--   trip confirmed). That migration was superseded by 20260811120000 and
--   20260811140000 which rewrote match_route_queue completely, dropping
--   Branch 1. The offered-trip reuse path is a distinct case (driver still
--   in 'offered' state, trip still 'provisional_offer') and must be added
--   as a new preceding branch.
--
-- FIX — BRANCH 0: Offered-Provisional-Trip Reuse
--   Before selecting a new waiting driver, check whether there is an
--   existing provisional trip (notes = 'provisional_offer') on this route
--   whose driver_queue entry is still 'offered' and whose offer has not
--   yet expired, AND which has remaining capacity (booked_seats < total_seats).
--
--   If found:
--     - Lock the provisional trip row (FOR UPDATE).
--     - Recalculate remaining capacity = total_seats - booked_seats.
--     - Assign WAITING passengers (FIFO, fit-aware, is_test_data isolation)
--       into the existing provisional trip, up to remaining capacity.
--     - Update passenger_queue: status = 'MATCHING', assigned_trip_id = trip.id
--     - Update bookings: trip_id = trip.id, status = 'confirmed'
--     - Increment trips.booked_seats by the newly assigned seats.
--     - Update trips.status via CASE (full vs accepting_bookings).
--     - Audit each assignment.
--     - Return immediately — do NOT create a second provisional trip.
--
--   If NOT found (no offered trip with capacity, or offer expired):
--     Fall through to existing Branch 1 (new driver offer).
--
-- INVARIANTS PRESERVED:
--   - Passenger FIFO: ORDER BY pq.queue_sequence ASC (unchanged)
--   - Driver FIFO: Branch 1 still selects by dq.joined_at ASC (unchanged)
--   - is_test_data isolation: Branch 0 filters pq.is_test_data = v_is_test_driver
--     (same guard as Branch 1, derived from the offered driver's is_test_data)
--   - trips.total_seats never exceeded: fill limited to remaining_capacity
--   - Row locking: FOR UPDATE on trips row prevents concurrent overfill
--   - Advisory lock: pg_try_advisory_xact_lock on route_id prevents
--     concurrent match_route_queue calls from racing
--   - Decline/expiry semantics: release_provisional_trip returns all
--     MATCHING passengers (including those added by Branch 0) to WAITING.
--     No change to release_provisional_trip required.
--   - Acceptance semantics: driver_accept_offer transitions all MATCHING
--     passengers on the trip to ASSIGNED. Passengers added by Branch 0
--     are in MATCHING state on the same trip, so they are included.
--     No change to driver_accept_offer required.
--   - Provisional marker contract: Branch 0 only targets trips WHERE
--     notes = 'provisional_offer'. The marker is preserved until accept.
--   - Offer expiry guard: Branch 0 checks dq.offer_expires_at > NOW()
--     to avoid filling a trip whose offer has already expired server-side
--     (even if the cron cleanup has not yet run).
--
-- FUNCTIONS CHANGED:
--   match_route_queue(p_route_id UUID) — one new branch (Branch 0) added
--   before the existing driver-selection logic. All other logic is
--   IDENTICAL to migration 20260811140000.
--
-- FUNCTIONS NOT CHANGED:
--   driver_accept_offer (both overloads) — no change required
--   driver_decline_offer — no change required
--   expire_driver_offer — no change required
--   release_provisional_trip — no change required
--   book_or_queue (both overloads) — no change required
--   passenger_join_queue — no change required
--   Any booking, cancellation, admin, or UI logic — no change
--
-- SQL VERIFICATION SEQUENCE (expected result):
--   7-seat driver #1 (offered, provisional trip T1 with 0 seats initially)
--   → passenger 1 seat  → Branch 0 not yet applicable (T1 created by first call)
--                          Actually: first call creates T1 via Branch 1 with 1 seat
--   → passenger 4 seats → Branch 0: T1 has 6 remaining → add 4 seats → T1 = 5/7
--   → passenger 1 seat  → Branch 0: T1 has 2 remaining → add 1 seat  → T1 = 6/7
--   → passenger 1 seat  → Branch 0: T1 has 1 remaining → add 1 seat  → T1 = 7/7
--   Expected: all 7 seats on T1, no second provisional trip created.
--
-- MIGRATION ORDER:
--   After: 20260811170000_raahi_fix_completed_at_timestamps.sql
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
  v_offered_trip     RECORD;
  v_offered_dq       RECORD;
  v_remaining        INTEGER;
  v_fill_seats       INTEGER := 0;
  v_fill_pq_ids      UUID[]  := ARRAY[]::UUID[];
  v_fill_bk_ids      UUID[]  := ARRAY[]::UUID[];
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
  -- BRANCH 0: Reuse an existing offered provisional trip that still has
  -- remaining capacity.
  --
  -- Condition: there is a driver_queue row with status='offered' and
  -- offer_expires_at > NOW() (not yet expired server-side) whose
  -- provisional_trip_id points to a trip with notes='provisional_offer'
  -- and booked_seats < total_seats.
  --
  -- This branch fires when a new passenger arrives while the first
  -- driver's offer is still pending. Instead of selecting a new waiting
  -- driver and creating a second provisional trip, we fill the existing
  -- offered trip up to its remaining capacity.
  -- ──────────────────────────────────────────────────────────────────────

  -- Find the offered driver_queue entry for this route (if any, not expired)
  SELECT dq.*, d.is_test_data AS driver_is_test
  INTO v_offered_dq
  FROM public.driver_queue dq
  JOIN public.drivers d ON d.id = dq.driver_id
  WHERE dq.route_id = p_route_id
    AND dq.status = 'offered'
    AND dq.offer_expires_at > NOW()
  ORDER BY dq.joined_at ASC
  LIMIT 1
  FOR UPDATE OF dq SKIP LOCKED;

  IF FOUND THEN
    -- Lock the provisional trip row
    SELECT t.*
    INTO v_offered_trip
    FROM public.trips t
    WHERE t.id = v_offered_dq.provisional_trip_id
      AND t.notes = 'provisional_offer'
      AND t.booked_seats < t.total_seats
    FOR UPDATE;

    IF FOUND THEN
      v_is_test_driver := COALESCE(v_offered_dq.driver_is_test, false);
      v_remaining      := v_offered_trip.total_seats - v_offered_trip.booked_seats;

      -- Assign WAITING passengers FIFO into the existing provisional trip
      -- (fit-aware, is_test_data isolation, up to remaining capacity)
      v_fill_seats := 0;

      FOR v_pq IN
        SELECT pq.id, pq.booking_id, pq.seat_count, pq.queue_sequence
        FROM public.passenger_queue pq
        JOIN public.bookings b ON b.id = pq.booking_id
        WHERE pq.route_id = p_route_id
          AND pq.status = 'WAITING'
          AND pq.is_test_data = v_is_test_driver
        ORDER BY pq.queue_sequence ASC
        FOR UPDATE OF pq SKIP LOCKED
      LOOP
        EXIT WHEN v_fill_seats >= v_remaining;

        IF (v_fill_seats + v_pq.seat_count) <= v_remaining THEN
          -- Passenger fits — assign to existing provisional trip
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

          v_fill_seats  := v_fill_seats + v_pq.seat_count;
          v_fill_pq_ids := array_append(v_fill_pq_ids, v_pq.id);
          v_fill_bk_ids := array_append(v_fill_bk_ids, v_pq.booking_id);
        END IF;
        -- Fit-aware: if passenger doesn't fit, skip (continue looking for
        -- smaller bookings that fit remaining space). This mirrors the
        -- keep_multi_seat_booking_together=true behavior in Branch 1.
      END LOOP;

      IF array_length(v_fill_pq_ids, 1) IS NOT NULL
         AND array_length(v_fill_pq_ids, 1) > 0 THEN

        -- Increment booked_seats on the provisional trip
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
          COALESCE(auth.uid(), v_offered_dq.driver_profile_id),
          'passenger_assigned_to_trip'::public.audit_action,
          'trips',
          v_offered_trip.id,
          jsonb_build_object(
            'branch',              'offered_trip_reuse',
            'route_id',            p_route_id,
            'passengers_added',    array_length(v_fill_pq_ids, 1),
            'seats_added',         v_fill_seats,
            'booked_seats_before', v_offered_trip.booked_seats,
            'total_seats',         v_offered_trip.total_seats,
            'is_test_data',        v_is_test_driver
          ),
          'match_route_queue: filled existing offered provisional trip (Branch 0)'
        );

        RETURN jsonb_build_object(
          'matched',             true,
          'branch',              'offered_trip_reuse',
          'trip_id',             v_offered_trip.id,
          'passengers_assigned', array_length(v_fill_pq_ids, 1),
          'seats_added',         v_fill_seats,
          'is_test_data',        v_is_test_driver
        );
      END IF;
      -- If no WAITING passengers fit (e.g. all remaining WAITING passengers
      -- have more seats than remaining capacity), fall through to Branch 1.
      -- Branch 1 will find no waiting driver and return 'no_driver_available',
      -- which is the correct result — the offered driver's trip is nearly full
      -- and the remaining passengers must wait for the next driver.
    END IF;
    -- If the provisional trip was not found (already released/cancelled) or
    -- is already full, fall through to Branch 1.
  END IF;

  -- ──────────────────────────────────────────────────────────────────────
  -- BRANCH 1: New driver offer (unchanged from migration 20260811140000)
  --
  -- Only runs when:
  --   (a) No offered driver exists for this route, OR
  --   (b) The offered driver's offer has expired (server-side), OR
  --   (c) The offered driver's provisional trip is already full, OR
  --   (d) No WAITING passengers fit the remaining capacity of the offered trip.
  -- ──────────────────────────────────────────────────────────────────────

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

  -- Link driver queue to trip
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
-- SQL VERIFICATION SEQUENCE
--
-- Setup: 7-seat driver #1 (Dipti Kumari) is queue position 1,
-- status='waiting'. No other drivers. Route = Dhanbad → Gomoh.
-- All passengers are same is_test_data partition as driver.
--
-- Step 1: passenger 1 seat arrives → book_or_queue → match_route_queue
--   Branch 0: no offered driver yet → skip
--   Branch 1: Dipti selected (waiting) → provisional trip T1 created
--             T1.booked_seats = 1, T1.total_seats = 7
--             T1.notes = 'provisional_offer'
--             Dipti driver_queue.status = 'offered'
--   Result: T1 = 1/7, Dipti = offered ✓
--
-- Step 2: passenger 4 seats arrives → book_or_queue → match_route_queue
--   Branch 0: Dipti is 'offered', offer not expired, T1 has 6 remaining
--             4 seats fit → assign to T1 → T1.booked_seats = 5
--   Result: T1 = 5/7, no second trip ✓
--
-- Step 3: passenger 1 seat arrives → book_or_queue → match_route_queue
--   Branch 0: Dipti is 'offered', T1 has 2 remaining
--             1 seat fits → assign to T1 → T1.booked_seats = 6
--   Result: T1 = 6/7, no second trip ✓
--
-- Step 4: passenger 1 seat arrives → book_or_queue → match_route_queue
--   Branch 0: Dipti is 'offered', T1 has 1 remaining
--             1 seat fits → assign to T1 → T1.booked_seats = 7
--             CASE: 7 >= 7 → status = 'full'
--   Result: T1 = 7/7 (full), no second trip ✓
--
-- All 7 seats belong to Dipti's single provisional trip T1.
-- No second provisional trip was created.
--
-- Decline/expiry verification:
--   If Dipti declines or offer expires → release_provisional_trip(T1.id)
--   → T1 cancelled, all 7 MATCHING passengers returned to WAITING
--   → match_route_queue called again → Branch 0: no offered driver
--   → Branch 1: next waiting driver selected → new provisional trip T2
--   FIFO passenger order preserved (original queue_sequence unchanged) ✓
--
-- Acceptance verification:
--   If Dipti accepts → driver_accept_offer locks T1 WHERE notes='provisional_offer'
--   → all MATCHING passengers (1+4+1+1 = 7) transitioned to ASSIGNED
--   → bookings confirmed, trip_id set
--   → T1.notes = NULL, T1.status = 'full' (7 >= 7)
--   → Dipti driver_queue.status = 'assigned' ✓
-- ============================================================
