-- ============================================================
-- RAAHI — Fix book_or_queue parameter name mismatch
-- Migration: 20260809270000_raahi_fix_book_or_queue_param_name.sql
-- ============================================================
--
-- ROOT CAUSE (confirmed by investigation):
--
-- The client (BookRideContent.tsx) calls:
--   supabase.rpc('book_or_queue', {
--     p_passenger_id: ...,
--     p_route_id: ...,
--     p_pickup_point_id: ...,   ← named parameter
--     p_seats: ...,
--   })
--
-- Migration 20260809260000 deployed book_or_queue with signature:
--   book_or_queue(p_passenger_id, p_route_id, p_pickup_id, p_seats)
--                                              ^^^^^^^^^^
--                                              WRONG — client sends p_pickup_point_id
--
-- PostgREST routes named-parameter RPC calls by matching parameter
-- names exactly. When the client sends p_pickup_point_id but the
-- function declares p_pickup_id, PostgREST either:
--   (a) returns PGRST202 "function not found in schema cache", OR
--   (b) falls back to the stale stage23 book_or_queue which has
--       INSERT INTO passenger_queue (..., seats_requested, ...)
--       → PostgreSQL error: 'column "seats_requested" of relation
--         "passenger_queue" does not exist'
--       → client getBookingErrorMessage sees 'seats' in error text
--       → maps to "Not enough seats available. Try booking fewer seats."
--
-- This is the exact error the user saw on route ee546d5d-22ea-4e13-9023-a556359812ee
-- despite the booking page correctly showing 4 available seats.
--
-- FIX: Drop the misnamed function and redeploy with p_pickup_point_id
-- to match the client's named parameter call.
-- ============================================================

-- Drop both possible variants to ensure clean slate
DROP FUNCTION IF EXISTS public.book_or_queue(UUID, UUID, UUID, INTEGER);

CREATE OR REPLACE FUNCTION public.book_or_queue(
  p_passenger_id    UUID,
  p_route_id        UUID,
  p_pickup_point_id UUID,
  p_seats           INTEGER DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_route            RECORD;
  v_pickup           RECORD;
  v_booking_id       UUID;
  v_queue_id         UUID;
  v_fare             NUMERIC;
  v_max_seats        INTEGER;
  v_existing_bk_id   UUID;
  v_existing_pq_id   UUID;
BEGIN
  -- Validate route is active
  SELECT * INTO v_route
  FROM public.routes
  WHERE id = p_route_id AND status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Route not found or inactive');
  END IF;

  -- Validate pickup belongs to route and is active
  SELECT * INTO v_pickup
  FROM public.pickup_points
  WHERE id = p_pickup_point_id AND route_id = p_route_id AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pickup point not valid for this route');
  END IF;

  -- Validate seat count
  SELECT COALESCE(value::INTEGER, 4) INTO v_max_seats
  FROM public.business_settings WHERE key = 'max_seats_per_booking';

  IF p_seats < 1 OR p_seats > COALESCE(v_max_seats, 4) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Seat count must be between 1 and %s', COALESCE(v_max_seats, 4))
    );
  END IF;

  -- PREVENT DUPLICATE: Check if passenger already has an active booking/queue entry
  -- for this route via passenger_queue (which has route_id).
  -- NOTE: bookings table has NO route_id column — use passenger_queue join.
  SELECT b.id, pq.id
  INTO v_existing_bk_id, v_existing_pq_id
  FROM public.bookings b
  JOIN public.passenger_queue pq ON pq.booking_id = b.id
  WHERE b.passenger_id = p_passenger_id
    AND pq.route_id = p_route_id
    AND b.status IN ('confirmed', 'queued', 'matching')
    AND pq.status IN ('WAITING', 'MATCHING', 'ASSIGNED')
  LIMIT 1;

  IF v_existing_bk_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'booking_id', v_existing_bk_id,
      'queue_id', v_existing_pq_id,
      'already_queued', true,
      'message', 'You already have an active booking on this route'
    );
  END IF;

  v_fare := COALESCE(v_route.fare_per_seat, 150);

  -- Create booking (status = queued, no trip_id yet)
  -- NOTE: bookings table has NO route_id column — route is tracked via passenger_queue
  INSERT INTO public.bookings (
    passenger_id,
    trip_id,
    pickup_point_id,
    seats,
    fare_per_seat,
    total_fare,
    status,
    booked_at
  )
  VALUES (
    p_passenger_id,
    NULL,
    p_pickup_point_id,
    p_seats,
    v_fare,
    v_fare * p_seats,
    'queued',
    NOW()
  )
  RETURNING id INTO v_booking_id;

  -- Join passenger queue
  -- NOTE: passenger_queue uses 'seat_count' (NOT 'seats_requested')
  -- and 'queue_sequence' BIGSERIAL (NOT 'queue_position')
  INSERT INTO public.passenger_queue (
    passenger_id,
    route_id,
    booking_id,
    seat_count,
    status,
    joined_at
  )
  VALUES (
    p_passenger_id,
    p_route_id,
    v_booking_id,
    p_seats,
    'WAITING',
    NOW()
  )
  RETURNING id INTO v_queue_id;

  -- Audit
  INSERT INTO public.audit_logs (
    performed_by, action, target_table, target_id, new_value, notes
  )
  VALUES (
    p_passenger_id,
    'passenger_joined_queue'::public.audit_action,
    'passenger_queue',
    v_queue_id,
    jsonb_build_object(
      'route_id', p_route_id,
      'booking_id', v_booking_id,
      'seat_count', p_seats
    ),
    'Passenger joined queue via book_or_queue'
  );

  -- Trigger automatic matching if a driver is available
  PERFORM public.match_route_queue(p_route_id);

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', v_booking_id,
    'queue_id', v_queue_id,
    'fare_per_seat', v_fare,
    'fare', v_fare * p_seats,
    'seats', p_seats,
    'already_queued', false,
    'message', 'You have joined the queue. A driver will be matched automatically.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.book_or_queue(UUID, UUID, UUID, INTEGER) TO authenticated;
