-- ============================================================
-- RAAHI — Fix get_my_bookings CASE Enum Type-Resolution Bug
-- Migration: 20260811160000_raahi_fix_get_my_bookings_case_enum_cast.sql
-- ============================================================
--
-- ROOT CAUSE (confirmed independently):
--
--   Migration 20260811090000 regressed the ::TEXT casts that were
--   correctly present in migration 20260809320000.
--
--   In the current deployed get_my_bookings():
--
--     SELECT
--       b.status  AS booking_status,   -- type: public.booking_status (ENUM)
--       t.status  AS trip_status,      -- type: public.trip_status (ENUM)
--     ...
--
--   Then in the LOOP:
--
--     v_display_status := CASE v_row.queue_status
--       WHEN 'WAITING'   THEN 'queued'
--       WHEN 'MATCHING'  THEN 'matching'
--       WHEN 'ASSIGNED'  THEN 'assigned'
--       ELSE v_row.booking_status        -- ← ENUM-typed ELSE branch
--     END;
--
--   PostgreSQL's CASE type-resolution rule:
--     When branches have mixed types, PostgreSQL attempts to unify them.
--     The ELSE branch is public.booking_status (enum).
--     PostgreSQL resolves the entire CASE as public.booking_status.
--     It then attempts:
--       'assigned'::public.booking_status
--     which is INVALID because 'assigned' is not a member of booking_status.
--
--   This produces:
--     ERROR 22P02: invalid input value for enum booking_status: "assigned"
--
--   Independently reproduced with:
--     SELECT pg_typeof(
--       CASE WHEN true THEN 'assigned'
--            ELSE 'confirmed'::public.booking_status
--       END
--     );
--     → ERROR 22P02: invalid input value for enum booking_status: "assigned"
--
-- SCHEMA VERIFICATION:
--
--   public.booking_status enum values:
--     confirmed, cancelled, no_show, completed, queued, matching
--
--   'assigned' is intentionally NOT a member of booking_status.
--   'assigned' is a queue/display state only.
--
--   DO NOT add 'assigned' to booking_status. This fix resolves the
--   display-layer typing problem without broadening the enum.
--
-- FIX:
--
--   Add explicit ::TEXT casts to:
--     1. b.status::TEXT  AS booking_status  (in the FOR SELECT)
--     2. t.status::TEXT  AS trip_status     (in the FOR SELECT)
--     3. ELSE v_row.booking_status::TEXT    (in the CASE expression)
--
--   All CASE branches are now TEXT literals or explicit ::TEXT casts.
--   PostgreSQL resolves the CASE as TEXT. No enum inference occurs.
--
--   The v_display_status variable is already declared as TEXT, so
--   assignment is type-safe.
--
-- AUDIT OF OTHER PASSENGER BOOKING RPCs FOR THE SAME HAZARD:
--
--   get_passenger_booking (20260811090000):
--     Uses separate scalar variables:
--       v_trip_status TEXT  (declared TEXT, assigned from SELECT INTO)
--       v_booking.status    (accessed directly in jsonb_build_object,
--                            no CASE mixing with queue status)
--     No CASE expression mixes booking_status enum with TEXT display states.
--     NOT affected by this hazard.
--
--   get_admin_bookings (20260809320000):
--     Uses b.status::TEXT AS booking_status in SELECT (cast present).
--     No CASE expression mixes enum with TEXT display states.
--     NOT affected.
--
--   cancel_booking (20260811090000):
--     Loads booking into RECORD, checks v_booking.status directly.
--     No CASE expression mixes enum with TEXT display states.
--     NOT affected.
--
--   admin_cancel_booking:
--     No CASE expression mixes enum with TEXT display states.
--     NOT affected.
--
--   CONCLUSION: The enum/TEXT CASE hazard exists ONLY in get_my_bookings
--   as deployed by migration 20260811090000. No other RPC is affected.
--
-- DRIVER QUEUE STATUS:
--   driver_queue.status is a TEXT/VARCHAR column (not an enum).
--   No driver queue CASE expressions are affected.
--
-- WHAT IS NOT CHANGED:
--   - booking_status enum definition (no values added or removed)
--   - trip_status enum definition
--   - passenger_queue.status (TEXT column, unchanged)
--   - CASE semantics: WAITING→queued, MATCHING→matching, ASSIGNED→assigned
--   - trip terminal state guard (v_trip_terminal logic preserved exactly)
--   - fare_collected field in output (preserved)
--   - All other fields in the output JSONB (preserved)
--   - get_passenger_booking (not affected, not changed)
--   - matching, FIFO, driver queues, trip lifecycle, offer lifecycle,
--     fare collection, no-show behavior, booking lifecycle enum definitions,
--     frontend behavior
--
-- DATA REPAIR:
--   None required. The underlying booking data is correct.
--   Rajeev.backup1 has valid state:
--     bookings.status = confirmed
--     trips.status = in_progress
--     passenger_queue.status = ASSIGNED
--   The RPC was failing before returning any data. No data is corrupt.
--
-- MIGRATION ORDERING:
--   This migration follows:
--     20260811150000_raahi_fix_driver_accept_offer_capacity_status.sql
--   It is a forward-only migration. No previously deployed migration
--   is modified.
--
-- FILES CHANGED:
--   supabase/migrations/20260811160000_raahi_fix_get_my_bookings_case_enum_cast.sql
-- ============================================================

-- ============================================================
-- FIX: get_my_bookings — explicit ::TEXT casts prevent enum inference
--
-- CHANGES vs. 20260811090000 version:
--   Line A: b.status::TEXT  AS booking_status  (was: b.status AS booking_status)
--   Line B: t.status::TEXT  AS trip_status     (was: t.status AS trip_status)
--   Line C: ELSE v_row.booking_status::TEXT    (was: ELSE v_row.booking_status)
--
-- All other logic is IDENTICAL to migration 20260811090000:
--   - trip terminal state guard (v_trip_terminal)
--   - queue status conditions (NOT IN 'CANCELLED','COMPLETED')
--   - booking status conditions (NOT IN 'cancelled','completed','no_show')
--   - CASE branches: WAITING→queued, MATCHING→matching, ASSIGNED→assigned
--   - fare_collected field
--   - full output JSONB structure
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
  v_display_status TEXT;
  v_trip_terminal  BOOLEAN;
BEGIN
  v_passenger_id := auth.uid();
  IF v_passenger_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Not authenticated', 'bookings', '[]'::JSONB);
  END IF;

  FOR v_row IN
    SELECT
      b.id                          AS booking_id,
      b.trip_id,
      b.pickup_point_id,
      b.seats,
      b.fare_per_seat,
      b.total_fare,
      b.status::TEXT                AS booking_status,   -- LINE A: explicit ::TEXT cast
      b.booked_at,
      b.fare_collected_at,
      -- Pickup point
      pp.name                       AS pickup_name,
      -- Queue entry (may be null)
      pq.id                         AS queue_id,
      pq.route_id                   AS pq_route_id,
      pq.status                     AS queue_status,     -- TEXT column, no cast needed
      pq.seat_count,
      pq.assigned_trip_id,
      -- Trip (may be null)
      t.route_id                    AS trip_route_id,
      t.status::TEXT                AS trip_status,      -- LINE B: explicit ::TEXT cast
      t.vehicle_id,
      -- Route resolved: trip route preferred, else queue route
      COALESCE(rt.from_location, rq.from_location, '') AS route_from,
      COALESCE(rt.to_location,   rq.to_location,   '') AS route_to,
      -- Vehicle
      v.make                        AS vehicle_make,
      v.model                       AS vehicle_model
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
    -- ----------------------------------------------------------------
    -- TRIP TERMINAL STATE CHECK (preserved from 20260811090000)
    -- ----------------------------------------------------------------
    v_trip_terminal := (
      v_row.trip_status IS NOT NULL
      AND v_row.trip_status IN ('completed', 'cancelled')
    );

    -- Determine display status
    IF v_row.queue_status IS NOT NULL
       AND v_row.queue_status NOT IN ('CANCELLED', 'COMPLETED')
       AND v_row.booking_status NOT IN ('cancelled', 'completed', 'no_show')
       AND NOT v_trip_terminal
    THEN
      -- All branches are TEXT literals or explicit ::TEXT casts.
      -- PostgreSQL resolves this CASE as TEXT. No enum inference occurs.
      v_display_status := CASE v_row.queue_status
        WHEN 'WAITING'   THEN 'queued'::TEXT
        WHEN 'MATCHING'  THEN 'matching'::TEXT
        WHEN 'ASSIGNED'  THEN 'assigned'::TEXT
        ELSE v_row.booking_status::TEXT   -- LINE C: explicit ::TEXT cast
      END;
    ELSE
      -- Trip is terminal or booking is terminal — use booking_status directly.
      -- booking_status is already TEXT (cast in SELECT above).
      v_display_status := v_row.booking_status;
    END IF;

    v_item := jsonb_build_object(
      'id',              v_row.booking_id,
      'seats',           v_row.seats,
      'fare_per_seat',   v_row.fare_per_seat,
      'total_fare',      v_row.total_fare,
      'status',          v_display_status,
      'booking_status',  v_row.booking_status,
      'queue_status',    COALESCE(v_row.queue_status, ''),
      'booked_at',       v_row.booked_at,
      'pickup_name',     COALESCE(v_row.pickup_name, ''),
      'route_from',      v_row.route_from,
      'route_to',        v_row.route_to,
      'trip_id',         v_row.trip_id,
      'trip_status',     COALESCE(v_row.trip_status, ''),
      'vehicle_make',    COALESCE(v_row.vehicle_make, ''),
      'vehicle_model',   COALESCE(v_row.vehicle_model, ''),
      'fare_collected',  (v_row.fare_collected_at IS NOT NULL),
      'fare_collected_at', v_row.fare_collected_at
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

GRANT EXECUTE ON FUNCTION public.get_my_bookings() TO authenticated;
