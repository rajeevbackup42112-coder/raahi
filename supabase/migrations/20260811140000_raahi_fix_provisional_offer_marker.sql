-- ============================================================
-- RAAHI — Fix Provisional Offer Producer/Consumer Mismatch
-- Migration: 20260811140000_raahi_fix_provisional_offer_marker.sql
-- ============================================================
--
-- ROOT CAUSE:
--   Migration 20260811120000 (enum-cast fix) rewrote match_route_queue
--   as a complete CREATE OR REPLACE but omitted `notes = 'provisional_offer'`
--   from the provisional trip INSERT. All prior versions of match_route_queue
--   (stages 5, 5.1, 5.2b, 7, and fix migrations 260000/290000/340000/350000)
--   correctly set notes = 'provisional_offer'.
--
--   driver_accept_offer (both overloads) locks the provisional trip with:
--     WHERE id = v_queue_entry.provisional_trip_id
--       AND notes = 'provisional_offer'
--   When notes IS NULL, that WHERE clause finds no row → returns
--   "Offer no longer available — another process claimed it."
--
-- CURRENT PRODUCER CONTRACT (match_route_queue 20260811120000):
--   INSERT INTO public.trips (driver_id, route_id, vehicle_id, status,
--     total_seats, booked_seats, is_test_data, created_at, updated_at)
--   VALUES (..., 'accepting_bookings'::public.trip_status, ...)
--   -- notes column absent → NULL
--
-- CURRENT CONSUMER CONTRACT (driver_accept_offer, both overloads):
--   SELECT * FROM public.trips
--   WHERE id = v_queue_entry.provisional_trip_id
--     AND notes = 'provisional_offer'
--   FOR UPDATE;
--
-- CANONICAL PROVISIONAL OFFER CONTRACT:
--   notes = 'provisional_offer' is the canonical marker.
--   It is used consistently by:
--     - driver_accept_offer (UUID, UUID) — migration 20260810010000
--     - driver_accept_offer (UUID)       — migration 20260809120000
--     - release_provisional_trip         — migrations 20260809060000, 20260810010000
--     - driver_decline_offer             — via release_provisional_trip
--     - expire_driver_offer              — via release_provisional_trip
--     - get_passenger_booking            — notes != 'provisional_offer' guard
--     - run_expiry_tests                 — notes IS DISTINCT FROM 'provisional_offer' guard
--     - get_active_trip_for_route        — notes IS NULL OR notes != 'provisional_offer' guard
--
-- MATCH_ROUTE_QUEUE CHANGE:
--   Add `notes` column to the provisional trip INSERT with value
--   'provisional_offer'. No other logic changed.
--
-- DRIVER_ACCEPT_OFFER CHANGE:
--   None. The marker requirement is preserved on both overloads.
--   The contract is enforced on both sides.
--
-- ACCEPT OVERLOADS FOUND:
--   1. driver_accept_offer(p_driver_profile_id UUID, p_queue_entry_id UUID)
--      — migration 20260810010000 (current deployed version)
--   2. driver_accept_offer(p_queue_entry_id UUID)
--      — migration 20260809120000 (single-arg overload for test harness)
--
-- ACCEPT OVERLOADS CONSISTENT: YES
--   Both overloads use identical provisional-trip lock logic:
--     WHERE id = v_queue_entry.provisional_trip_id
--       AND notes = 'provisional_offer'
--   Both clear notes = NULL on accept.
--   Both transition passenger_queue MATCHING → ASSIGNED.
--   Both transition driver_queue offered → assigned.
--   Both set driver.availability_status = 'active'.
--   Both write audit log with 'driver_accepted_offer' action.
--   No divergent lifecycle logic found.
--
-- DECLINE CONSISTENCY:
--   driver_decline_offer (both overloads) calls release_provisional_trip
--   which cancels the trip WHERE notes = 'provisional_offer'. Consistent.
--
-- EXPIRY CONSISTENCY:
--   expire_driver_offer calls release_provisional_trip which cancels the
--   trip WHERE notes = 'provisional_offer'. Consistent.
--
-- HOW OFFER EXPIRY IS TRIGGERED:
--   Three independent mechanisms (all server-side):
--   1. pg_cron: expire_all_stale_offers() scheduled every 1 minute
--      (if pg_cron extension is available on the Supabase plan)
--   2. Edge Function: supabase/functions/expire-offers runs every 1 minute
--      via Supabase cron — operates independently of any browser session
--   3. Lazy check: driver_accept_offer checks offer_expires_at <= NOW()
--      at accept time and calls expire_driver_offer if expired
--   The expiry authority is the DB timestamp driver_queue.offer_expires_at.
--   Frontend countdown is display-only.
--
-- CAN EXPIRED OFFERS REMAIN STALE INDEFINITELY: YES (by design)
--   If neither pg_cron nor the Edge Function cron fires (e.g., pg_cron
--   unavailable and Edge Function is paused), and no driver attempts to
--   accept, an expired offer can remain in driver_queue.status = 'offered'
--   indefinitely. This is lazy/event-driven architecture, not a bug.
--   The offer is still rejected server-side on any accept attempt.
--   FIFO progression is blocked until expiry cleanup runs or a new
--   accept/decline/expiry event fires. This is a known architectural
--   characteristic, not introduced by this patch.
--
-- ENUM/AUDIT CHECK:
--   No new enum literals introduced. 'provisional_offer' is a TEXT value
--   stored in trips.notes (TEXT column), not an enum. No enum risk.
--   All existing enum casts from migration 20260811120000 are preserved.
--
-- FIFO IMPACT: NONE
--   FIFO ordering (driver_queue.joined_at ASC) is unchanged.
--   No queue positions modified.
--
-- TEST/LIVE ISOLATION IMPACT: NONE
--   is_test_data guard preserved exactly as in migration 20260811120000.
--
-- DATA SAFETY:
--   No existing records modified. No queue history deleted.
--   No bookings, trips, or driver records altered.
--   Fresh offer must be generated manually after deployment.
--
-- FILES CHANGED:
--   supabase/migrations/20260811140000_raahi_fix_provisional_offer_marker.sql
-- ============================================================

-- ============================================================
-- REDEPLOY match_route_queue WITH notes = 'provisional_offer'
--
-- This is a complete CREATE OR REPLACE of the function as it
-- exists in migration 20260811120000, with ONE change:
--
--   CHANGE (BUG FIX — required):
--     Add `notes` column to the provisional trip INSERT:
--       notes = 'provisional_offer'
--
--   This restores the canonical provisional-offer contract that
--   was present in all prior versions of match_route_queue and
--   is required by driver_accept_offer, driver_decline_offer,
--   expire_driver_offer, release_provisional_trip, and
--   get_active_trip_for_route.
--
-- All other logic is IDENTICAL to migration 20260811120000:
--   - FIFO driver selection (joined_at ASC)
--   - test/live isolation (is_test_data guard)
--   - fit-aware passenger assignment (queue_sequence ASC)
--   - enum-safe CASE casts (::public.trip_status)
--   - audit log (match_created)
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

  -- ── BUG FIX: Create provisional trip WITH notes = 'provisional_offer' ──
  --
  -- Migration 20260811120000 omitted the notes column, leaving notes = NULL.
  -- driver_accept_offer requires: WHERE id = ... AND notes = 'provisional_offer'
  -- Without this marker the trip lock fails and accept returns
  -- "Offer no longer available — another process claimed it."
  --
  -- This restores the canonical contract present in all prior versions:
  --   stage5 (20260809060000), stage51 (20260809080000),
  --   stage52b (20260809120000), stage7 (20260809200000),
  --   fix_online_driver_visibility (20260809260000),
  --   fix_audit_performed_by (20260809290000),
  --   fix_existing_trip_matching (20260809340000),
  --   fix_full_trip_departure_transition (20260809350000)
  -- ────────────────────────────────────────────────────────────────────────
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

  -- Enum-safe CASE cast (preserved from migration 20260811120000)
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
      'test_isolation_applied', true,
      'provisional_marker_set', true
    ),
    'match_route_queue: provisional_offer marker set, test isolation enforced'
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

-- ============================================================
-- STATIC REGRESSION VERIFICATION
--
-- Scenario (from user):
--   Rajeev Backup4: queue #1, 4-seat Maruti Dzire, waiting, online
--   Dipti: queue #2, waiting
--   Passengers: rajeev.backup1 (1 seat), Naresh (2 seats),
--               rajeev.backup3 (1 seat) — total 4 seats WAITING
--
-- Expected result from match_route_queue:
--   matched = true                                            ✓
--   Rajeev selected (FIFO #1, joined_at earliest)            ✓
--   3 passenger bookings assigned (1+2+1 = 4 seats)          ✓
--   trip.notes = 'provisional_offer'                         ✓ (BUG FIX)
--   trip.booked_seats = 4 = total_seats                      ✓
--   CASE: booked_seats(4) >= total_seats(4) → 'full'         ✓
--   trip.status = full                                        ✓
--   Dipti remains waiting #2                                  ✓
--
-- BEFORE ACCEPT (expected after deployment):
--   driver_queue.status = offered                            ✓
--   provisional_trip_id = new trip                           ✓
--   offer_expires_at > NOW()                                 ✓
--   trip.status = accepting_bookings (or full)               ✓
--   trip.notes = 'provisional_offer'                         ✓ (BUG FIX)
--   passengers = MATCHING                                    ✓
--   bookings = confirmed                                     ✓
--
-- AFTER ACCEPT (expected):
--   driver_accept_offer finds trip WHERE notes='provisional_offer' ✓
--   RPC success = true                                       ✓
--   trip.notes = NULL (cleared on accept)                    ✓
--   driver_queue.status = assigned                           ✓
--   driver.availability_status = active                      ✓
--   passenger_queue.status = ASSIGNED                        ✓
--   bookings remain confirmed                                ✓
--
-- DUPLICATE ACCEPT (idempotent rejection):
--   driver_queue.status already = assigned → FOR UPDATE finds
--   no row with status = 'offered' → returns offer_not_found ✓
--   No duplicate trip, no duplicate assignment               ✓
-- ============================================================
