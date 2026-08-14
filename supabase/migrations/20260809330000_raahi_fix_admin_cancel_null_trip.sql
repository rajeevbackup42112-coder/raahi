-- ============================================================
-- RAAHI — Fix admin_cancel_booking for queued bookings (trip_id = NULL)
-- Migration: 20260809330000_raahi_fix_admin_cancel_null_trip.sql
-- ============================================================
--
-- BUG SOURCE (migration 310000):
--   admin_cancel_booking declares:
--     v_trip RECORD;
--   Then conditionally loads it:
--     IF v_booking.trip_id IS NOT NULL THEN
--       SELECT ... INTO v_trip FROM public.trips ...
--     ELSIF v_pq.route_id IS NOT NULL THEN
--       v_route_id := v_pq.route_id;
--     END IF;
--   Then UNCONDITIONALLY dereferences it:
--     IF v_trip.status = 'in_progress' THEN   ← ERROR 55000 here
--   When trip_id IS NULL, v_trip is never assigned.
--   PostgreSQL raises: "record v_trip is not assigned yet" (55000).
--
-- FIX:
--   Replace v_trip RECORD with scalar variables (v_trip_status TEXT, etc.)
--   All trip field access is gated behind:
--     IF v_booking_trip_id IS NOT NULL THEN ... END IF;
--   Queued bookings (trip_id IS NULL) cancel booking + queue only.
--   No trip logic executes when no trip exists.
--
-- STATE MACHINE:
--   QUEUED  + NULL trip  → cancel booking + queue only
--   MATCHING + provisional trip → cancel + remove from provisional + recalc seats
--   CONFIRMED + assigned trip → cancel + recalc seats + departure recheck
--   COMPLETED / NO_SHOW → reject
--   ALREADY CANCELLED → idempotent success
--   IN_PROGRESS trip → reject
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_cancel_booking(
  p_booking_id UUID,
  p_reason     TEXT DEFAULT 'Admin cancelled'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  -- Admin identity
  v_admin_id           UUID;
  v_admin_name         TEXT;
  v_admin_role         TEXT;

  -- Booking fields (scalar — avoids uninitialized RECORD)
  v_booking_id         UUID;
  v_booking_passenger  UUID;
  v_booking_trip_id    UUID;
  v_booking_pickup_id  UUID;
  v_booking_seats      INTEGER;
  v_booking_fare       NUMERIC;
  v_booking_total      NUMERIC;
  v_booking_status     TEXT;
  v_booking_at         TIMESTAMPTZ;

  -- Passenger queue fields (scalar)
  v_pq_id              UUID;
  v_pq_route_id        UUID;
  v_pq_status          TEXT;
  v_pq_seat_count      INTEGER;
  v_pq_assigned_trip   UUID;

  -- Trip fields (scalar — all NULL when trip_id IS NULL)
  v_trip_status        TEXT;
  v_trip_booked_seats  INTEGER;
  v_trip_total_seats   INTEGER;
  v_trip_route_id      UUID;

  -- Route for audit log
  v_route_id           UUID;
  v_route_from         TEXT := '';
  v_route_to           TEXT := '';

  -- Previous status for audit
  v_prev_status        TEXT;
BEGIN
  -- ── 1. Derive admin identity from session ──────────────────────────────
  v_admin_id := auth.uid();
  IF v_admin_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT p.name, p.role
  INTO v_admin_name, v_admin_role
  FROM public.profiles p
  WHERE p.id = v_admin_id;

  IF v_admin_role IS DISTINCT FROM 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin role required');
  END IF;

  -- ── 2. Lock and load booking (scalar fields) ───────────────────────────
  SELECT b.id,
         b.passenger_id,
         b.trip_id,
         b.pickup_point_id,
         b.seats,
         b.fare_per_seat,
         b.total_fare,
         b.status::TEXT,
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
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
  END IF;

  v_prev_status := v_booking_status;

  -- ── 3. Idempotency: already cancelled ─────────────────────────────────
  IF v_booking_status = 'cancelled' THEN
    RETURN jsonb_build_object(
      'success',    true,
      'booking_id', p_booking_id,
      'message',    'Booking was already cancelled (idempotent)'
    );
  END IF;

  -- ── 4. Reject terminal states ──────────────────────────────────────────
  IF v_booking_status IN ('completed', 'no_show') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error',   'Cannot cancel a ' || v_booking_status || ' booking'
    );
  END IF;

  -- ── 5. Lock and load passenger_queue entry (may not exist) ────────────
  SELECT pq.id,
         pq.route_id,
         pq.status,
         pq.seat_count,
         pq.assigned_trip_id
  INTO v_pq_id,
       v_pq_route_id,
       v_pq_status,
       v_pq_seat_count,
       v_pq_assigned_trip
  FROM public.passenger_queue pq
  WHERE pq.booking_id = p_booking_id
  FOR UPDATE;
  -- If no queue row, all v_pq_* remain NULL — that is safe

  -- ── 6. Load trip fields ONLY when trip_id is not null ─────────────────
  --   This is the critical fix: v_trip_* scalars stay NULL for queued
  --   bookings. No RECORD is ever left uninitialized.
  IF v_booking_trip_id IS NOT NULL THEN
    SELECT t.status::TEXT,
           t.booked_seats,
           t.total_seats,
           t.route_id
    INTO v_trip_status,
         v_trip_booked_seats,
         v_trip_total_seats,
         v_trip_route_id
    FROM public.trips t
    WHERE t.id = v_booking_trip_id
    FOR UPDATE;
    -- If trip row not found, scalars remain NULL — safe
  END IF;
  -- v_trip_* are NULL when trip_id IS NULL — never dereferenced unsafely

  -- ── 7. Resolve route_id for audit log ─────────────────────────────────
  --   Use trip route when available, else queue route
  v_route_id := COALESCE(v_trip_route_id, v_pq_route_id);

  IF v_route_id IS NOT NULL THEN
    SELECT r.from_location, r.to_location
    INTO v_route_from, v_route_to
    FROM public.routes r
    WHERE r.id = v_route_id;
    v_route_from := COALESCE(v_route_from, '');
    v_route_to   := COALESCE(v_route_to, '');
  END IF;

  -- ── 8. Reject in_progress trip — ONLY checked when trip exists ────────
  --   Previously this was checked unconditionally, causing 55000 when
  --   v_trip was uninitialized. Now safely gated.
  IF v_booking_trip_id IS NOT NULL AND v_trip_status = 'in_progress' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error',   'Cannot cancel booking while trip is in progress'
    );
  END IF;

  -- ── 9. Cancel the booking ─────────────────────────────────────────────
  UPDATE public.bookings
  SET status      = 'cancelled',
      admin_notes = COALESCE(p_reason, 'Admin cancelled'),
      updated_at  = NOW()
  WHERE id = p_booking_id;

  -- ── 10. Cancel passenger_queue entry ──────────────────────────────────
  IF v_pq_id IS NOT NULL AND v_pq_status NOT IN ('CANCELLED', 'COMPLETED') THEN
    UPDATE public.passenger_queue
    SET status     = 'CANCELLED',
        updated_at = NOW()
    WHERE id = v_pq_id;
  END IF;

  -- ── 11. Trip recalculation — ONLY when a trip exists ──────────────────
  --   For QUEUED bookings (trip_id IS NULL) this entire block is skipped.
  IF v_booking_trip_id IS NOT NULL
     AND v_trip_status IS NOT NULL
     AND v_trip_status NOT IN ('completed', 'cancelled', 'in_progress')
  THEN
    -- Recalculate booked_seats
    UPDATE public.trips
    SET booked_seats = GREATEST(0, booked_seats - v_booking_seats),
        -- If trip was full/ready/departure_pending, revert to boarding
        status = CASE
          WHEN status IN ('full', 'ready', 'departure_pending') THEN 'boarding'
          ELSE status
        END,
        updated_at = NOW()
    WHERE id = v_booking_trip_id;

    -- Recheck departure eligibility after seat recalculation
    PERFORM public.check_departure_eligibility_on_cancel(v_booking_trip_id);
  END IF;

  -- ── 12. Write cancellations record (fee = 0 during testing) ───────────
  INSERT INTO public.cancellations (
    booking_id,
    cancelled_by,
    reason,
    cancellation_fee,
    fee_waived,
    waived_by,
    status
  ) VALUES (
    p_booking_id,
    v_admin_id,
    COALESCE(p_reason, 'Admin cancelled'),
    0,
    true,
    v_admin_id,
    'waived'
  )
  ON CONFLICT DO NOTHING;

  -- ── 13. Audit log ─────────────────────────────────────────────────────
  INSERT INTO public.audit_logs (
    performed_by,
    action,
    target_table,
    target_id,
    old_value,
    new_value,
    notes
  ) VALUES (
    v_admin_id,
    'booking_cancelled'::public.audit_action,
    'bookings',
    p_booking_id,
    jsonb_build_object(
      'booking_status', v_prev_status,
      'passenger_id',   v_booking_passenger,
      'trip_id',        v_booking_trip_id,
      'route',          CASE
                          WHEN v_route_from <> '' AND v_route_to <> ''
                          THEN v_route_from || ' → ' || v_route_to
                          ELSE ''
                        END,
      'seats',          v_booking_seats,
      'fare',           v_booking_total
    ),
    jsonb_build_object(
      'booking_status', 'cancelled',
      'cancelled_by',   'admin',
      'admin_id',       v_admin_id,
      'admin_name',     COALESCE(v_admin_name, ''),
      'reason',         COALESCE(p_reason, 'Admin cancelled'),
      'trip_id',        v_booking_trip_id,
      'route',          CASE
                          WHEN v_route_from <> '' AND v_route_to <> ''
                          THEN v_route_from || ' → ' || v_route_to
                          ELSE ''
                        END
    ),
    COALESCE(p_reason, 'Admin cancelled booking')
  );

  -- ── 14. Return success ────────────────────────────────────────────────
  RETURN jsonb_build_object(
    'success',         true,
    'booking_id',      p_booking_id,
    'previous_status', v_prev_status,
    'passenger_id',    v_booking_passenger,
    'route',           CASE
                         WHEN v_route_from <> '' AND v_route_to <> ''
                         THEN v_route_from || ' → ' || v_route_to
                         ELSE ''
                       END,
    'message',         'Booking cancelled successfully'
  );
END;
$$;

-- Grant execute to authenticated users (admin check is inside the function)
GRANT EXECUTE ON FUNCTION public.admin_cancel_booking(UUID, TEXT) TO authenticated;

-- ============================================================
-- Verification comment
-- ============================================================
-- After this migration:
--   admin_cancel_booking(booking_id, reason) where booking has
--   trip_id = NULL will:
--     1. Authenticate admin via auth.uid()
--     2. Lock booking row
--     3. Lock passenger_queue row
--     4. Set booking.status = 'cancelled'
--     5. Set passenger_queue.status = 'CANCELLED'
--     6. Skip ALL trip logic (v_booking_trip_id IS NULL)
--     7. Write cancellations record (fee = 0)
--     8. Write audit log with performed_by = admin profile id
--     9. Return success JSON
--   No 55000 error because v_trip RECORD is gone — replaced by
--   scalar variables that are only populated when trip_id IS NOT NULL.
-- ============================================================
