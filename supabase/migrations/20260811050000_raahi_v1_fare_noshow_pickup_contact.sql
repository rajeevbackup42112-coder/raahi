-- ============================================================
-- RAAHI V1 — FARE COLLECTION, NO-SHOW, PICKUP ADMIN, CONTACT PRIVACY
-- Migration: 20260811050000_raahi_v1_fare_noshow_pickup_contact.sql
-- ============================================================
--
-- PRE-IMPLEMENTATION AUDIT:
--
-- CURRENT PICKUP POINT ADMIN CAPABILITY:
--   EXISTS: add, edit name/landmark, sequence_order, is_active, direction
--   MISSING: server-side RPC for safe reorder; deactivation guard for historical refs
--   VERDICT: Direct table updates exist in AdminRoutesContent — upgrade to RPCs
--
-- CURRENT CONTACT NUMBER SOURCE:
--   profiles.phone column exists (nullable TEXT)
--   No enforcement before booking — MISSING
--
-- CURRENT DRIVER PASSENGER LIST SOURCE:
--   get_driver_queue_status RPC returns passenger_count only
--   No per-passenger detail with pickup/fare/contact — MISSING
--
-- CURRENT FARE COLLECTION SUPPORT:
--   bookings.total_fare stored at booking time
--   No fare_collections table, no driver mark-collected action — MISSING
--
-- CURRENT NO-SHOW SUPPORT:
--   booking_status enum has 'no_show' value
--   No driver RPC to mark no-show safely — MISSING
--
-- CURRENT DEPARTURE ELIGIBILITY LOGIC:
--   check_departure_eligibility_on_cancel exists
--   driver_leave_now / driver_wait_for_more exist
--   Multi-pickup: no distinction between origin vs later-pickup passengers — MISSING
--
-- CURRENT MULTI-PICKUP BEHAVIOR:
--   pickup_points.sequence_order exists
--   bookings.pickup_point_id exists
--   No departure eligibility filter by pickup sequence — MISSING
--
-- SCHEMA/RPC CHANGES REQUIRED:
--   1. fare_collections table (idempotent mark-collected)
--   2. bookings.fare_collected_at, fare_collected_by columns
--   3. driver_get_pickup_plan RPC (grouped by pickup sequence)
--   4. driver_mark_fare_collected RPC (server-derived amount, idempotent)
--   5. driver_mark_no_show RPC (distinct from cancel, releases seats)
--   6. get_passenger_trip_contact RPC (privacy-gated contact)
--   7. get_driver_contact_for_passenger RPC (privacy-gated)
--   8. admin_add_pickup_point / admin_edit_pickup_point / admin_reorder_pickup_points RPCs
--   9. Departure eligibility: filter by origin pickup sequence
--  10. New audit_action values
--  11. phone_required enforcement in book_or_queue
-- ============================================================

-- ============================================================
-- STEP 1: EXTEND bookings — fare collection tracking
-- ============================================================

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS fare_collected_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS fare_collected_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- ============================================================
-- STEP 2: fare_collections table
-- Canonical audit of each fare collection event.
-- Idempotent: unique constraint on booking_id prevents double-count.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.fare_collections (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id        UUID NOT NULL REFERENCES public.bookings(id) ON DELETE RESTRICT,
  trip_id           UUID NOT NULL REFERENCES public.trips(id) ON DELETE RESTRICT,
  driver_id         UUID NOT NULL REFERENCES public.drivers(id) ON DELETE RESTRICT,
  collected_by      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  amount_expected   NUMERIC(10,2) NOT NULL,
  amount_collected  NUMERIC(10,2) NOT NULL,
  collected_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  notes             TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- One fare collection record per booking (idempotency enforced at DB level)
CREATE UNIQUE INDEX IF NOT EXISTS idx_fare_collections_booking_id
  ON public.fare_collections(booking_id);

CREATE INDEX IF NOT EXISTS idx_fare_collections_trip_id
  ON public.fare_collections(trip_id);

CREATE INDEX IF NOT EXISTS idx_fare_collections_driver_id
  ON public.fare_collections(driver_id);

ALTER TABLE public.fare_collections ENABLE ROW LEVEL SECURITY;

-- Drivers can read fare collections for their own trips
DROP POLICY IF EXISTS "drivers_read_own_fare_collections" ON public.fare_collections;
CREATE POLICY "drivers_read_own_fare_collections"
  ON public.fare_collections FOR SELECT TO authenticated
  USING (
    collected_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.id = fare_collections.driver_id AND d.profile_id = auth.uid()
    )
  );

-- Admins can read all
DROP POLICY IF EXISTS "admins_read_all_fare_collections" ON public.fare_collections;
CREATE POLICY "admins_read_all_fare_collections"
  ON public.fare_collections FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Insert only via SECURITY DEFINER RPCs
DROP POLICY IF EXISTS "no_direct_insert_fare_collections" ON public.fare_collections;
CREATE POLICY "no_direct_insert_fare_collections"
  ON public.fare_collections FOR INSERT TO authenticated
  WITH CHECK (false);

-- ============================================================
-- STEP 3: NEW AUDIT ACTIONS
-- ============================================================

ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'fare_collected';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'no_show_marked';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'pickup_point_added';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'pickup_point_edited';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'pickup_points_reordered';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'pickup_point_deactivated';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'pickup_point_activated';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'passenger_phone_updated';

COMMIT;

-- ============================================================
-- STEP 4: BUSINESS SETTINGS — phone requirement
-- ============================================================

INSERT INTO public.business_settings (key, value, description)
VALUES
  ('require_phone_for_booking', 'true', 'Require passenger to have a phone number before completing a booking')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- STEP 5: book_or_queue — add phone requirement check
-- Extends the existing abuse-protected version from migration 040000.
-- Only adds the phone check; all other logic preserved.
-- ============================================================

DROP FUNCTION IF EXISTS public.book_or_queue(UUID, UUID, INTEGER);

CREATE OR REPLACE FUNCTION public.book_or_queue(
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
  v_passenger_id       UUID;
  v_profile            RECORD;
  v_route              RECORD;
  v_pickup             RECORD;
  v_booking_id         UUID;
  v_queue_id           UUID;
  v_fare               NUMERIC;
  v_max_seats          INTEGER;
  v_existing_bk_id     UUID;
  v_existing_pq_id     UUID;

  -- Abuse protection settings
  v_abuse_enabled      BOOLEAN;
  v_cooldown_minutes   INTEGER;
  v_cancel_window_min  INTEGER;
  v_cancel_limit       INTEGER;
  v_rate_limit_enabled BOOLEAN;
  v_rate_window_sec    INTEGER;
  v_rate_limit         INTEGER;

  -- Cooldown check
  v_cooldown_until     TIMESTAMPTZ;
  v_remaining_minutes  INTEGER;

  -- Rate limit check
  v_action_count       INTEGER;
  v_window_start       TIMESTAMPTZ;
  v_retry_after        INTEGER;

  -- Phone requirement
  v_require_phone      BOOLEAN;
BEGIN
  -- ── IDENTITY ────────────────────────────────────────────────────────────
  v_passenger_id := auth.uid();
  IF v_passenger_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- ── PROFILE CHECK ────────────────────────────────────────────────────────
  SELECT * INTO v_profile
  FROM public.profiles
  WHERE id = v_passenger_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Profile not found. Please complete your profile before booking.'
    );
  END IF;

  -- ── SUSPENSION CHECK ─────────────────────────────────────────────────────
  IF v_profile.status = 'suspended' THEN
    RETURN jsonb_build_object(
      'success', false,
      'reason', 'account_suspended',
      'error', 'Your account has been suspended. Please contact support.'
    );
  END IF;

  -- ── PHONE REQUIREMENT CHECK ───────────────────────────────────────────────
  v_require_phone := public.get_business_setting_bool('require_phone_for_booking', true);
  IF v_require_phone THEN
    IF v_profile.phone IS NULL OR trim(v_profile.phone) = '' THEN
      RETURN jsonb_build_object(
        'success', false,
        'reason', 'phone_required',
        'error', 'A contact number is required before booking. Please add your mobile number in your profile.'
      );
    END IF;
  END IF;

  -- ── LOAD ABUSE PROTECTION SETTINGS ──────────────────────────────────────
  v_abuse_enabled      := public.get_business_setting_bool('booking_abuse_protection_enabled', true);
  v_cooldown_minutes   := public.get_business_setting_int('booking_cooldown_minutes', 30);
  v_cancel_window_min  := public.get_business_setting_int('cancellation_window_minutes', 60);
  v_cancel_limit       := public.get_business_setting_int('cancellation_limit_in_window', 3);
  v_rate_limit_enabled := public.get_business_setting_bool('booking_action_rate_limit_enabled', true);
  v_rate_window_sec    := public.get_business_setting_int('booking_action_window_seconds', 60);
  v_rate_limit         := public.get_business_setting_int('booking_action_limit', 10);

  IF v_abuse_enabled THEN

    -- ── COOLDOWN CHECK ─────────────────────────────────────────────────────
    v_cooldown_until := v_profile.booking_cooldown_until;
    IF v_cooldown_until IS NOT NULL AND v_cooldown_until > NOW() THEN
      v_remaining_minutes := CEIL(EXTRACT(EPOCH FROM (v_cooldown_until - NOW())) / 60)::INTEGER;
      RETURN jsonb_build_object(
        'success', false,
        'reason', 'booking_cooldown',
        'cooldown_expires_at', v_cooldown_until,
        'remaining_minutes', v_remaining_minutes,
        'error', format(
          'You''ve cancelled several rides recently. New bookings are paused for %s minutes.',
          v_remaining_minutes
        )
      );
    END IF;

    -- ── RAPID ACTION RATE LIMIT ────────────────────────────────────────────
    IF v_rate_limit_enabled THEN
      v_window_start := NOW() - (v_rate_window_sec || ' seconds')::INTERVAL;

      SELECT COUNT(*) INTO v_action_count
      FROM public.audit_logs
      WHERE performed_by = v_passenger_id
        AND action IN ('booking_created', 'booking_cancelled', 'passenger_joined_queue')
        AND created_at >= v_window_start;

      IF v_action_count >= v_rate_limit THEN
        v_retry_after := v_rate_window_sec;

        INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
        VALUES (
          v_passenger_id,
          'booking_action_rate_limited'::public.audit_action,
          'profiles',
          v_passenger_id,
          jsonb_build_object('action_count', v_action_count, 'window_seconds', v_rate_window_sec),
          'Rapid action rate limit triggered during book_or_queue'
        );

        RETURN jsonb_build_object(
          'success', false,
          'reason', 'rate_limited',
          'retry_after_seconds', v_retry_after,
          'error', 'Too many booking actions. Please wait a moment before trying again.'
        );
      END IF;
    END IF;

  END IF; -- v_abuse_enabled

  -- ── VALIDATE ROUTE ────────────────────────────────────────────────────────
  SELECT * INTO v_route
  FROM public.routes
  WHERE id = p_route_id AND status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Route not found or inactive');
  END IF;

  -- ── VALIDATE PICKUP ───────────────────────────────────────────────────────
  SELECT * INTO v_pickup
  FROM public.pickup_points
  WHERE id = p_pickup_point_id AND route_id = p_route_id AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pickup point not valid for this route');
  END IF;

  -- ── VALIDATE SEAT COUNT ───────────────────────────────────────────────────
  v_max_seats := public.get_business_setting_int('max_seats_per_booking', 4);

  IF p_seats < 1 OR p_seats > v_max_seats THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Seat count must be between 1 and %s', v_max_seats)
    );
  END IF;

  -- ── PREVENT DUPLICATE (with advisory lock for concurrency safety) ─────────
  PERFORM pg_advisory_xact_lock(hashtext(v_passenger_id::TEXT || p_route_id::TEXT));

  SELECT b.id, pq.id
  INTO v_existing_bk_id, v_existing_pq_id
  FROM public.bookings b
  JOIN public.passenger_queue pq ON pq.booking_id = b.id
  WHERE b.passenger_id = v_passenger_id
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

  -- ── CREATE BOOKING ────────────────────────────────────────────────────────
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
    v_passenger_id,
    NULL,
    p_pickup_point_id,
    p_seats,
    v_fare,
    v_fare * p_seats,
    'queued',
    NOW()
  )
  RETURNING id INTO v_booking_id;

  -- ── JOIN PASSENGER QUEUE ──────────────────────────────────────────────────
  INSERT INTO public.passenger_queue (
    passenger_id,
    route_id,
    booking_id,
    seat_count,
    status,
    joined_at
  )
  VALUES (
    v_passenger_id,
    p_route_id,
    v_booking_id,
    p_seats,
    'WAITING',
    NOW()
  )
  RETURNING id INTO v_queue_id;

  -- ── AUDIT ─────────────────────────────────────────────────────────────────
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    v_passenger_id,
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

  -- ── TRIGGER MATCHING ──────────────────────────────────────────────────────
  PERFORM public.match_route_queue(p_route_id);

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', v_booking_id,
    'queue_id', v_queue_id,
    'fare_per_seat', v_fare,
    'fare', v_fare * p_seats,
    'seats', p_seats,
    'already_queued', false,
    'message', 'Seat Reserved. Pay ₹' || (v_fare * p_seats)::TEXT || ' directly to the driver at your pickup point.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.book_or_queue(UUID, UUID, INTEGER) TO authenticated;

-- ============================================================
-- STEP 6: update_passenger_phone RPC
-- Passenger updates their own phone number.
-- Validates basic Indian mobile format server-side.
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_passenger_phone(
  p_phone TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_passenger_id UUID;
  v_cleaned      TEXT;
BEGIN
  v_passenger_id := auth.uid();
  IF v_passenger_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Clean: strip spaces, dashes, +91 prefix
  v_cleaned := regexp_replace(trim(p_phone), '[^0-9]', '', 'g');
  -- Remove leading 91 if 12 digits
  IF length(v_cleaned) = 12 AND left(v_cleaned, 2) = '91' THEN
    v_cleaned := right(v_cleaned, 10);
  END IF;

  -- Validate: must be 10 digits starting with 6-9
  IF v_cleaned !~ '^[6-9][0-9]{9}$' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Please enter a valid 10-digit Indian mobile number (starting with 6, 7, 8, or 9).'
    );
  END IF;

  UPDATE public.profiles
  SET phone = v_cleaned, updated_at = NOW()
  WHERE id = v_passenger_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    v_passenger_id,
    'passenger_phone_updated'::public.audit_action,
    'profiles',
    v_passenger_id,
    jsonb_build_object('phone_set', true),
    'Passenger updated contact number'
  );

  RETURN jsonb_build_object('success', true, 'message', 'Contact number saved.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_passenger_phone(TEXT) TO authenticated;

-- ============================================================
-- STEP 7: driver_get_pickup_plan RPC
-- Returns assigned passengers grouped by pickup point in route sequence.
-- Includes fare state, contact (privacy-gated to assigned trip only).
-- ============================================================

CREATE OR REPLACE FUNCTION public.driver_get_pickup_plan(
  p_driver_profile_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver        RECORD;
  v_trip          RECORD;
  v_result        JSONB;
  v_pickup_groups JSONB;
  v_summary       JSONB;
BEGIN
  -- Verify caller is the driver
  IF auth.uid() <> p_driver_profile_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  -- Get driver record
  SELECT * INTO v_driver
  FROM public.drivers
  WHERE profile_id = p_driver_profile_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver not found');
  END IF;

  -- Get active trip for this driver
  SELECT t.* INTO v_trip
  FROM public.trips t
  WHERE t.driver_id = v_driver.id
    AND t.status NOT IN ('completed', 'cancelled')
  ORDER BY t.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'found', false, 'message', 'No active trip');
  END IF;

  -- Build pickup plan grouped by pickup point in sequence order
  SELECT jsonb_agg(
    jsonb_build_object(
      'pickup_point_id', pp.id,
      'pickup_name', pp.name,
      'sequence_order', pp.sequence_order,
      'passenger_count', grp.passenger_count,
      'seat_count', grp.seat_count,
      'passengers', grp.passengers
    )
    ORDER BY pp.sequence_order
  )
  INTO v_pickup_groups
  FROM (
    SELECT
      b.pickup_point_id,
      COUNT(DISTINCT b.passenger_id) AS passenger_count,
      SUM(b.seats) AS seat_count,
      jsonb_agg(
        jsonb_build_object(
          'booking_id', b.id,
          'passenger_name', pr.name,
          'passenger_phone', pr.phone,  -- exposed only because driver has active trip with this passenger
          'seats', b.seats,
          'fare_due', b.total_fare,
          'fare_collected', (b.fare_collected_at IS NOT NULL),
          'fare_collected_at', b.fare_collected_at,
          'booking_status', b.status,
          'queue_status', pq.status
        )
        ORDER BY b.booked_at
      ) AS passengers
    FROM public.bookings b
    JOIN public.profiles pr ON pr.id = b.passenger_id
    LEFT JOIN public.passenger_queue pq ON pq.booking_id = b.id
    WHERE b.trip_id = v_trip.id
      AND b.status IN ('confirmed', 'queued', 'matching')
      AND pq.status = 'ASSIGNED'
    GROUP BY b.pickup_point_id
  ) grp
  JOIN public.pickup_points pp ON pp.id = grp.pickup_point_id;

  -- Fare summary
  SELECT jsonb_build_object(
    'expected_fare', COALESCE(SUM(b.total_fare), 0),
    'fare_collected', COALESCE(SUM(CASE WHEN b.fare_collected_at IS NOT NULL THEN b.total_fare ELSE 0 END), 0),
    'fare_remaining', COALESCE(SUM(CASE WHEN b.fare_collected_at IS NULL THEN b.total_fare ELSE 0 END), 0),
    'total_passengers', COUNT(DISTINCT b.passenger_id),
    'total_seats', COALESCE(SUM(b.seats), 0)
  )
  INTO v_summary
  FROM public.bookings b
  JOIN public.passenger_queue pq ON pq.booking_id = b.id
  WHERE b.trip_id = v_trip.id
    AND b.status IN ('confirmed', 'queued', 'matching')
    AND pq.status = 'ASSIGNED';

  RETURN jsonb_build_object(
    'success', true,
    'found', true,
    'trip_id', v_trip.id,
    'trip_status', v_trip.status,
    'route_id', v_trip.route_id,
    'fare_per_seat', v_trip.fare_per_seat,
    'pickup_groups', COALESCE(v_pickup_groups, '[]'::jsonb),
    'summary', v_summary
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.driver_get_pickup_plan(UUID) TO authenticated;

-- ============================================================
-- STEP 8: driver_mark_fare_collected RPC
-- Idempotent: second call returns success without double-counting.
-- Amount is server-derived from booking — client amount ignored.
-- Driver can only mark fare for passengers on their own active trip.
-- ============================================================

CREATE OR REPLACE FUNCTION public.driver_mark_fare_collected(
  p_booking_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_profile_id UUID;
  v_driver            RECORD;
  v_trip              RECORD;
  v_booking           RECORD;
  v_pq                RECORD;
  v_amount            NUMERIC;
  v_fc_id             UUID;
BEGIN
  v_driver_profile_id := auth.uid();
  IF v_driver_profile_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Get driver record
  SELECT * INTO v_driver
  FROM public.drivers
  WHERE profile_id = v_driver_profile_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver profile not found');
  END IF;

  -- Get active trip for this driver
  SELECT * INTO v_trip
  FROM public.trips
  WHERE driver_id = v_driver.id
    AND status NOT IN ('completed', 'cancelled')
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active trip found');
  END IF;

  -- Get booking — must belong to this driver's trip
  SELECT b.* INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id
    AND b.trip_id = v_trip.id
    AND b.status IN ('confirmed', 'queued', 'matching')
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Booking not found on your active trip. You cannot mark fare for another driver''s passenger.'
    );
  END IF;

  -- Verify passenger is ASSIGNED to this trip
  SELECT * INTO v_pq
  FROM public.passenger_queue
  WHERE booking_id = p_booking_id AND status = 'ASSIGNED';

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Passenger is not currently assigned to your trip'
    );
  END IF;

  -- IDEMPOTENCY: if already collected, return success without re-inserting
  IF v_booking.fare_collected_at IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_collected', true,
      'amount', v_booking.total_fare,
      'collected_at', v_booking.fare_collected_at,
      'message', 'Fare already marked as collected'
    );
  END IF;

  -- Server-derived amount — do NOT trust client
  v_amount := v_booking.total_fare;

  -- Mark booking as fare collected
  UPDATE public.bookings
  SET
    fare_collected_at = NOW(),
    fare_collected_by = v_driver_profile_id,
    updated_at = NOW()
  WHERE id = p_booking_id;

  -- Insert fare_collections audit record
  INSERT INTO public.fare_collections (
    booking_id, trip_id, driver_id, collected_by,
    amount_expected, amount_collected, collected_at, notes
  )
  VALUES (
    p_booking_id, v_trip.id, v_driver.id, v_driver_profile_id,
    v_amount, v_amount, NOW(),
    'Fare collected by driver at pickup'
  )
  ON CONFLICT (booking_id) DO NOTHING
  RETURNING id INTO v_fc_id;

  -- Audit log
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    v_driver_profile_id,
    'fare_collected'::public.audit_action,
    'bookings',
    p_booking_id,
    jsonb_build_object(
      'trip_id', v_trip.id,
      'amount', v_amount,
      'driver_id', v_driver.id
    ),
    'Driver marked fare collected at pickup'
  );

  RETURN jsonb_build_object(
    'success', true,
    'already_collected', false,
    'amount', v_amount,
    'collected_at', NOW(),
    'message', 'Fare collected ✓'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.driver_mark_fare_collected(UUID) TO authenticated;

-- ============================================================
-- STEP 9: driver_mark_no_show RPC
-- Distinct from cancellation — does NOT trigger abuse cooldown.
-- Releases seats, updates queue, writes audit.
-- Idempotent: second call on already-no-show booking returns success.
-- Cannot mark no-show after fare already collected (safety guard).
-- ============================================================

CREATE OR REPLACE FUNCTION public.driver_mark_no_show(
  p_booking_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_profile_id UUID;
  v_driver            RECORD;
  v_trip              RECORD;
  v_booking           RECORD;
  v_pq                RECORD;
  v_route_id          UUID;
BEGIN
  v_driver_profile_id := auth.uid();
  IF v_driver_profile_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Get driver record
  SELECT * INTO v_driver
  FROM public.drivers
  WHERE profile_id = v_driver_profile_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver profile not found');
  END IF;

  -- Get active trip for this driver (not yet in_progress — no-show is pre-departure)
  SELECT * INTO v_trip
  FROM public.trips
  WHERE driver_id = v_driver.id
    AND status NOT IN ('completed', 'cancelled', 'in_progress')
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    -- Also allow no-show during in_progress for later-pickup passengers
    SELECT * INTO v_trip
    FROM public.trips
    WHERE driver_id = v_driver.id
      AND status NOT IN ('completed', 'cancelled')
    ORDER BY created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'No active trip found');
    END IF;
  END IF;

  v_route_id := v_trip.route_id;

  -- Get booking — must belong to this driver's trip
  SELECT b.* INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id
    AND b.trip_id = v_trip.id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Booking not found on your active trip. You cannot mark no-show for another driver''s passenger.'
    );
  END IF;

  -- IDEMPOTENCY: already no-show
  IF v_booking.status = 'no_show' THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_no_show', true,
      'message', 'Passenger was already marked as no-show'
    );
  END IF;

  -- SAFETY: cannot mark no-show after fare collected
  IF v_booking.fare_collected_at IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Cannot mark no-show: fare has already been collected for this passenger. Contact admin for exceptional recovery.'
    );
  END IF;

  -- Must be in a cancellable state
  IF v_booking.status NOT IN ('confirmed', 'queued', 'matching') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Cannot mark no-show for booking with status: %s', v_booking.status)
    );
  END IF;

  -- Get queue entry
  SELECT * INTO v_pq
  FROM public.passenger_queue
  WHERE booking_id = p_booking_id
  FOR UPDATE;

  -- Mark booking as no_show (NOT cancelled — distinct state)
  UPDATE public.bookings
  SET status = 'no_show', updated_at = NOW()
  WHERE id = p_booking_id;

  -- Update queue entry to CANCELLED (no-show means they did not board)
  IF v_pq.id IS NOT NULL THEN
    UPDATE public.passenger_queue
    SET status = 'CANCELLED', updated_at = NOW()
    WHERE id = v_pq.id;
  END IF;

  -- Release seats from trip
  UPDATE public.trips
  SET
    booked_seats = GREATEST(0, booked_seats - v_booking.seats),
    updated_at = NOW()
  WHERE id = v_trip.id;

  -- Audit log — performed_by is the driver (profiles.id)
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (
    v_driver_profile_id,
    'no_show_marked'::public.audit_action,
    'bookings',
    p_booking_id,
    jsonb_build_object('status', v_booking.status, 'seats', v_booking.seats),
    jsonb_build_object('status', 'no_show', 'seats_released', v_booking.seats),
    format('Driver marked passenger as no-show. %s seat(s) released.', v_booking.seats)
  );

  -- NOTE: Do NOT insert into cancellations table — no-show is NOT a cancellation.
  -- Do NOT trigger abuse cooldown — no-show is NOT passenger-initiated cancellation.

  -- Recalculate departure eligibility after seat release
  -- (reuses existing check_departure_eligibility_on_cancel if it exists)
  BEGIN
    IF v_pq.id IS NOT NULL THEN
      PERFORM public.check_departure_eligibility_on_cancel(v_pq.id);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    -- Non-fatal: departure eligibility check failure should not block no-show
    NULL;
  END;

  RETURN jsonb_build_object(
    'success', true,
    'already_no_show', false,
    'seats_released', v_booking.seats,
    'message', format('Passenger marked as no-show. %s seat(s) released.', v_booking.seats)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.driver_mark_no_show(UUID) TO authenticated;

-- ============================================================
-- STEP 10: get_passenger_trip_contact RPC
-- Passenger gets driver contact — only when assigned to that driver's active trip.
-- Returns nothing once trip is terminal.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_passenger_trip_contact()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_passenger_id UUID;
  v_result       RECORD;
BEGIN
  v_passenger_id := auth.uid();
  IF v_passenger_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Find the passenger's active assigned booking with a non-terminal trip
  SELECT
    pr.name AS driver_name,
    pr.phone AS driver_phone,
    t.id AS trip_id,
    t.status AS trip_status,
    v.registration_number,
    v.make AS vehicle_make,
    v.model AS vehicle_model,
    v.color AS vehicle_color
  INTO v_result
  FROM public.bookings b
  JOIN public.passenger_queue pq ON pq.booking_id = b.id
  JOIN public.trips t ON t.id = b.trip_id
  JOIN public.drivers d ON d.id = t.driver_id
  JOIN public.profiles pr ON pr.id = d.profile_id
  LEFT JOIN public.vehicles v ON v.id = t.vehicle_id
  WHERE b.passenger_id = v_passenger_id
    AND b.status IN ('confirmed', 'queued', 'matching')
    AND pq.status = 'ASSIGNED'
    AND t.status NOT IN ('completed', 'cancelled')
  ORDER BY b.booked_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', true,
      'found', false,
      'message', 'No active assigned trip — contact not available'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'found', true,
    'driver_name', v_result.driver_name,
    'driver_phone', v_result.driver_phone,
    'trip_id', v_result.trip_id,
    'trip_status', v_result.trip_status,
    'vehicle_registration', v_result.registration_number,
    'vehicle_make', v_result.vehicle_make,
    'vehicle_model', v_result.vehicle_model,
    'vehicle_color', v_result.vehicle_color
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_passenger_trip_contact() TO authenticated;

-- ============================================================
-- STEP 11: ADMIN PICKUP POINT RPCs
-- Safe server-side operations for pickup point management.
-- No hard-delete — deactivation only for points with historical refs.
-- ============================================================

-- admin_add_pickup_point
CREATE OR REPLACE FUNCTION public.admin_add_pickup_point(
  p_route_id       UUID,
  p_name           TEXT,
  p_landmark       TEXT DEFAULT NULL,
  p_sequence_order INTEGER DEFAULT NULL,
  p_direction      TEXT DEFAULT 'both',
  p_is_active      BOOLEAN DEFAULT true
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id    UUID;
  v_admin       RECORD;
  v_route       RECORD;
  v_seq         INTEGER;
  v_new_id      UUID;
BEGIN
  v_admin_id := auth.uid();
  SELECT * INTO v_admin FROM public.profiles WHERE id = v_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  IF p_name IS NULL OR trim(p_name) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pickup point name is required');
  END IF;

  SELECT * INTO v_route FROM public.routes WHERE id = p_route_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Route not found');
  END IF;

  IF p_direction NOT IN ('forward', 'return', 'both') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Direction must be forward, return, or both');
  END IF;

  -- Auto-assign sequence if not provided
  IF p_sequence_order IS NULL THEN
    SELECT COALESCE(MAX(sequence_order), 0) + 10 INTO v_seq
    FROM public.pickup_points
    WHERE route_id = p_route_id;
  ELSE
    v_seq := p_sequence_order;
  END IF;

  INSERT INTO public.pickup_points (route_id, name, landmark, sequence_order, direction, is_active)
  VALUES (p_route_id, trim(p_name), NULLIF(trim(COALESCE(p_landmark, '')), ''), v_seq, p_direction, p_is_active)
  RETURNING id INTO v_new_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    v_admin_id, 'pickup_point_added'::public.audit_action, 'pickup_points', v_new_id,
    jsonb_build_object('name', p_name, 'route_id', p_route_id, 'sequence_order', v_seq),
    'Admin added pickup point'
  );

  RETURN jsonb_build_object('success', true, 'pickup_point_id', v_new_id, 'message', 'Pickup point added');
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_add_pickup_point(UUID, TEXT, TEXT, INTEGER, TEXT, BOOLEAN) TO authenticated;

-- admin_edit_pickup_point
CREATE OR REPLACE FUNCTION public.admin_edit_pickup_point(
  p_pickup_point_id UUID,
  p_name            TEXT DEFAULT NULL,
  p_landmark        TEXT DEFAULT NULL,
  p_direction       TEXT DEFAULT NULL,
  p_is_active       BOOLEAN DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_admin    RECORD;
  v_pp       RECORD;
  v_has_refs BOOLEAN;
BEGIN
  v_admin_id := auth.uid();
  SELECT * INTO v_admin FROM public.profiles WHERE id = v_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  SELECT * INTO v_pp FROM public.pickup_points WHERE id = p_pickup_point_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pickup point not found');
  END IF;

  -- Safety: if deactivating, check for active bookings
  IF p_is_active = false AND v_pp.is_active = true THEN
    SELECT EXISTS(
      SELECT 1 FROM public.bookings b
      WHERE b.pickup_point_id = p_pickup_point_id
        AND b.status IN ('confirmed', 'queued', 'matching')
    ) INTO v_has_refs;

    IF v_has_refs THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Cannot deactivate: there are active bookings at this pickup point. Cancel those bookings first.'
      );
    END IF;
  END IF;

  IF p_direction IS NOT NULL AND p_direction NOT IN ('forward', 'return', 'both') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Direction must be forward, return, or both');
  END IF;

  UPDATE public.pickup_points
  SET
    name           = COALESCE(NULLIF(trim(p_name), ''), name),
    landmark       = CASE WHEN p_landmark IS NOT NULL THEN NULLIF(trim(p_landmark), '') ELSE landmark END,
    direction      = COALESCE(p_direction, direction),
    is_active      = COALESCE(p_is_active, is_active),
    updated_at     = NOW()
  WHERE id = p_pickup_point_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (
    v_admin_id,
    CASE WHEN p_is_active = false THEN 'pickup_point_deactivated'::public.audit_action
         WHEN p_is_active = true  THEN 'pickup_point_activated'::public.audit_action
         ELSE 'pickup_point_edited'::public.audit_action END,
    'pickup_points', p_pickup_point_id,
    jsonb_build_object('name', v_pp.name, 'is_active', v_pp.is_active),
    jsonb_build_object(
      'name', COALESCE(NULLIF(trim(p_name), ''), v_pp.name),
      'is_active', COALESCE(p_is_active, v_pp.is_active)
    ),
    'Admin edited pickup point'
  );

  RETURN jsonb_build_object('success', true, 'message', 'Pickup point updated');
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_edit_pickup_point(UUID, TEXT, TEXT, TEXT, BOOLEAN) TO authenticated;

-- admin_reorder_pickup_points
-- Accepts array of {id, sequence_order} objects and applies them atomically.
CREATE OR REPLACE FUNCTION public.admin_reorder_pickup_points(
  p_route_id UUID,
  p_order    JSONB   -- array of {id: uuid, sequence_order: int}
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_admin    RECORD;
  v_item     JSONB;
  v_pp_id    UUID;
  v_seq      INTEGER;
BEGIN
  v_admin_id := auth.uid();
  SELECT * INTO v_admin FROM public.profiles WHERE id = v_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  IF p_order IS NULL OR jsonb_array_length(p_order) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order array is required');
  END IF;

  -- Apply each sequence_order update
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_order)
  LOOP
    v_pp_id := (v_item->>'id')::UUID;
    v_seq   := (v_item->>'sequence_order')::INTEGER;

    UPDATE public.pickup_points
    SET sequence_order = v_seq, updated_at = NOW()
    WHERE id = v_pp_id AND route_id = p_route_id;
  END LOOP;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    v_admin_id, 'pickup_points_reordered'::public.audit_action, 'routes', p_route_id,
    p_order,
    'Admin reordered pickup points'
  );

  RETURN jsonb_build_object('success', true, 'message', 'Pickup points reordered');
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_reorder_pickup_points(UUID, JSONB) TO authenticated;

-- ============================================================
-- STEP 12: INDEXES for new columns
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_bookings_fare_collected_at
  ON public.bookings(fare_collected_at)
  WHERE fare_collected_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_bookings_trip_id_status
  ON public.bookings(trip_id, status);

-- ============================================================
-- STEP 13: RLS for new bookings columns
-- Existing RLS on bookings already covers these columns.
-- fare_collected_by references profiles — covered by existing FK.
-- No additional policies needed.
-- ============================================================

-- ============================================================
-- STEP 14: get_my_bookings — extend to include fare_collected status
-- Passengers need to see Fare Collected ✓ on their booking.
-- ============================================================

-- Drop existing function to replace with extended version
DROP FUNCTION IF EXISTS public.get_my_bookings();

CREATE OR REPLACE FUNCTION public.get_my_bookings()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_passenger_id UUID;
  v_bookings     JSONB;
BEGIN
  v_passenger_id := auth.uid();
  IF v_passenger_id IS NULL THEN
    RETURN jsonb_build_object('bookings', '[]'::jsonb);
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'id',              b.id,
      'seats',           b.seats,
      'fare_per_seat',   b.fare_per_seat,
      'total_fare',      b.total_fare,
      'status',          COALESCE(pq.status, b.status::TEXT),
      'booking_status',  b.status::TEXT,
      'queue_status',    COALESCE(pq.status, ''),
      'booked_at',       b.booked_at,
      'pickup_name',     COALESCE(pp.name, ''),
      'route_from',      COALESCE(r.from_location, ''),
      'route_to',        COALESCE(r.to_location, ''),
      'trip_id',         b.trip_id,
      'trip_status',     COALESCE(t.status::TEXT, ''),
      'vehicle_make',    COALESCE(v.make, ''),
      'vehicle_model',   COALESCE(v.model, ''),
      'fare_collected',  (b.fare_collected_at IS NOT NULL),
      'fare_collected_at', b.fare_collected_at
    )
    ORDER BY b.booked_at DESC
  )
  INTO v_bookings
  FROM public.bookings b
  LEFT JOIN public.passenger_queue pq ON pq.booking_id = b.id
  LEFT JOIN public.pickup_points pp ON pp.id = b.pickup_point_id
  LEFT JOIN public.trips t ON t.id = b.trip_id
  LEFT JOIN public.routes r ON r.id = COALESCE(t.route_id, (
    SELECT route_id FROM public.passenger_queue WHERE booking_id = b.id LIMIT 1
  ))
  LEFT JOIN public.vehicles v ON v.id = t.vehicle_id
  WHERE b.passenger_id = v_passenger_id;

  RETURN jsonb_build_object('bookings', COALESCE(v_bookings, '[]'::jsonb));
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_bookings() TO authenticated;
