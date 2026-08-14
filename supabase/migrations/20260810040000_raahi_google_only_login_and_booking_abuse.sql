-- ============================================================
-- RAAHI — GOOGLE-ONLY LOGIN + LIGHTWEIGHT BOOKING ABUSE PROTECTION
-- Migration: 20260810040000_raahi_google_only_login_and_booking_abuse.sql
-- ============================================================
--
-- PART A: Google-only login
--   No DB changes required — OTP removal is purely frontend.
--
-- PART B: Booking abuse protection
--   1. Add booking_cooldown_until to profiles
--   2. Add cancelled_by_type to cancellations (passenger|admin|driver|system)
--   3. Add business_settings rows for abuse protection config
--   4. New audit_action values for abuse events
--   5. Replace book_or_queue with abuse-protected version
--   6. Replace cancel_booking to stamp cancelled_by_type
--   7. admin_clear_booking_cooldown RPC
-- ============================================================

-- ============================================================
-- STEP 1: EXTEND profiles — booking cooldown
-- ============================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS booking_cooldown_until TIMESTAMPTZ;

-- ============================================================
-- STEP 2: EXTEND cancellations — actor type
-- ============================================================

ALTER TABLE public.cancellations
  ADD COLUMN IF NOT EXISTS cancelled_by_type TEXT NOT NULL DEFAULT 'passenger'
  CHECK (cancelled_by_type IN ('passenger', 'admin', 'driver', 'system'));

-- Back-fill existing rows: if cancelled_by matches a profile with role=admin → admin
-- otherwise leave as passenger (safe default for historical data)
UPDATE public.cancellations c
SET cancelled_by_type = 'admin'
FROM public.profiles p
WHERE c.cancelled_by = p.id
  AND p.role = 'admin';

-- ============================================================
-- STEP 3: NEW AUDIT ACTIONS
-- ============================================================

ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'booking_cooldown_started';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'booking_cooldown_cleared_admin';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'booking_action_rate_limited';

COMMIT;

-- ============================================================
-- STEP 4: BUSINESS SETTINGS — abuse protection defaults
-- ============================================================

INSERT INTO public.business_settings (key, value, description)
VALUES
  ('booking_abuse_protection_enabled',  'true',  'Enable repeated-cancellation cooldown protection'),
  ('cancellation_window_minutes',        '60',    'Window (minutes) in which cancellations are counted toward abuse threshold'),
  ('cancellation_limit_in_window',       '3',     'Number of passenger-initiated cancellations within the window that triggers a cooldown'),
  ('booking_cooldown_minutes',           '30',    'Duration (minutes) of booking cooldown after threshold is reached'),
  ('booking_action_rate_limit_enabled',  'true',  'Enable rapid-action rate limiting for booking/cancellation calls'),
  ('booking_action_window_seconds',      '60',    'Window (seconds) for counting rapid booking/cancellation actions'),
  ('booking_action_limit',               '10',    'Maximum booking/cancellation actions allowed within the window before rate-limiting')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- STEP 5: HELPER — get_business_setting_int
-- Returns a business_settings value as INTEGER with a fallback.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_business_setting_int(
  p_key     TEXT,
  p_default INTEGER
)
RETURNS INTEGER
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT value::INTEGER FROM public.business_settings WHERE key = p_key LIMIT 1),
    p_default
  );
$$;

CREATE OR REPLACE FUNCTION public.get_business_setting_bool(
  p_key     TEXT,
  p_default BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT value::BOOLEAN FROM public.business_settings WHERE key = p_key LIMIT 1),
    p_default
  );
$$;

-- ============================================================
-- STEP 6: book_or_queue — abuse-protected version
--
-- Checks (in order):
--   1. Authenticated + profile exists
--   2. Profile active (not suspended)
--   3. Booking cooldown not active
--   4. Rapid action rate limit
--   5. Duplicate active booking guard
--   6. Route + pickup validation
--   7. Seat count validation
--   8. Create booking + queue entry
--   9. Audit
--  10. Trigger matching
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

  -- Cancellation count
  v_cancel_count       INTEGER;
  v_window_start_cancel TIMESTAMPTZ;
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

      -- Count booking + cancellation actions in the window from audit_logs
      SELECT COUNT(*) INTO v_action_count
      FROM public.audit_logs
      WHERE performed_by = v_passenger_id
        AND action IN ('booking_created', 'booking_cancelled', 'passenger_joined_queue')
        AND created_at >= v_window_start;

      IF v_action_count >= v_rate_limit THEN
        v_retry_after := v_rate_window_sec;

        -- Audit the rate-limit event
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
  -- Use advisory lock keyed on passenger_id to prevent race-condition duplicates
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
    'message', 'You have joined the queue. A driver will be matched automatically.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.book_or_queue(UUID, UUID, INTEGER) TO authenticated;

-- ============================================================
-- STEP 7: cancel_booking — stamp cancelled_by_type + cooldown logic
--
-- Passenger-initiated cancellation:
--   - stamps cancelled_by_type = 'passenger'
--   - counts qualifying cancellations in window
--   - if threshold reached → sets booking_cooldown_until + audits
--
-- Admin-initiated cancellation (existing admin_cancel_booking_safe RPC):
--   - stamps cancelled_by_type = 'admin' (handled separately below)
-- ============================================================

-- Read the latest cancel_booking signature from migration 280000
-- Signature: cancel_booking(p_booking_id UUID) — uses auth.uid()

DROP FUNCTION IF EXISTS public.cancel_booking(UUID);

CREATE OR REPLACE FUNCTION public.cancel_booking(
  p_booking_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_passenger_id       UUID;
  v_booking            RECORD;
  v_queue_entry        RECORD;
  v_cancellation_id    UUID;

  -- Abuse protection
  v_abuse_enabled      BOOLEAN;
  v_cancel_window_min  INTEGER;
  v_cancel_limit       INTEGER;
  v_cooldown_minutes   INTEGER;
  v_cancel_count       INTEGER;
  v_window_start       TIMESTAMPTZ;
  v_cooldown_until     TIMESTAMPTZ;

  -- Rate limit
  v_rate_limit_enabled BOOLEAN;
  v_rate_window_sec    INTEGER;
  v_rate_limit         INTEGER;
  v_action_count       INTEGER;
  v_retry_after        INTEGER;
BEGIN
  -- ── IDENTITY ──────────────────────────────────────────────────────────────
  v_passenger_id := auth.uid();
  IF v_passenger_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- ── LOAD ABUSE SETTINGS ───────────────────────────────────────────────────
  v_abuse_enabled      := public.get_business_setting_bool('booking_abuse_protection_enabled', true);
  v_cancel_window_min  := public.get_business_setting_int('cancellation_window_minutes', 60);
  v_cancel_limit       := public.get_business_setting_int('cancellation_limit_in_window', 3);
  v_cooldown_minutes   := public.get_business_setting_int('booking_cooldown_minutes', 30);
  v_rate_limit_enabled := public.get_business_setting_bool('booking_action_rate_limit_enabled', true);
  v_rate_window_sec    := public.get_business_setting_int('booking_action_window_seconds', 60);
  v_rate_limit         := public.get_business_setting_int('booking_action_limit', 10);

  -- ── RAPID ACTION RATE LIMIT ───────────────────────────────────────────────
  IF v_abuse_enabled AND v_rate_limit_enabled THEN
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
        'bookings',
        p_booking_id,
        jsonb_build_object('action_count', v_action_count, 'window_seconds', v_rate_window_sec),
        'Rapid action rate limit triggered during cancel_booking'
      );
      RETURN jsonb_build_object(
        'success', false,
        'reason', 'rate_limited',
        'retry_after_seconds', v_retry_after,
        'error', 'Too many booking actions. Please wait a moment before trying again.'
      );
    END IF;
  END IF;

  -- ── FETCH BOOKING ─────────────────────────────────────────────────────────
  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id AND passenger_id = v_passenger_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found or not yours');
  END IF;

  IF v_booking.status NOT IN ('queued', 'confirmed', 'matching') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Cannot cancel a booking with status: %s', v_booking.status)
    );
  END IF;

  -- ── FETCH QUEUE ENTRY ─────────────────────────────────────────────────────
  SELECT * INTO v_queue_entry
  FROM public.passenger_queue
  WHERE booking_id = p_booking_id
  FOR UPDATE;

  -- ── CANCEL BOOKING ────────────────────────────────────────────────────────
  UPDATE public.bookings
  SET status = 'cancelled', updated_at = NOW()
  WHERE id = p_booking_id;

  -- ── CANCEL QUEUE ENTRY ────────────────────────────────────────────────────
  IF v_queue_entry.id IS NOT NULL THEN
    UPDATE public.passenger_queue
    SET status = 'CANCELLED', updated_at = NOW()
    WHERE id = v_queue_entry.id;
  END IF;

  -- ── RECORD CANCELLATION (passenger-initiated) ─────────────────────────────
  INSERT INTO public.cancellations (
    booking_id,
    cancelled_by,
    reason,
    cancelled_by_type
  )
  VALUES (
    p_booking_id,
    v_passenger_id,
    'Passenger cancelled',
    'passenger'
  )
  RETURNING id INTO v_cancellation_id;

  -- ── AUDIT ─────────────────────────────────────────────────────────────────
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    v_passenger_id,
    'booking_cancelled'::public.audit_action,
    'bookings',
    p_booking_id,
    jsonb_build_object('cancelled_by_type', 'passenger', 'cancellation_id', v_cancellation_id),
    'Passenger cancelled booking'
  );

  -- ── ABUSE PROTECTION: CHECK CANCELLATION THRESHOLD ───────────────────────
  IF v_abuse_enabled THEN
    v_window_start := NOW() - (v_cancel_window_min || ' minutes')::INTERVAL;

    -- Count only passenger-initiated cancellations in the window
    SELECT COUNT(*) INTO v_cancel_count
    FROM public.cancellations c
    JOIN public.bookings b ON b.id = c.booking_id
    WHERE b.passenger_id = v_passenger_id
      AND c.cancelled_by_type = 'passenger'
      AND c.created_at >= v_window_start;

    IF v_cancel_count >= v_cancel_limit THEN
      -- Check if cooldown is already active (avoid re-extending)
      SELECT booking_cooldown_until INTO v_cooldown_until
      FROM public.profiles WHERE id = v_passenger_id;

      IF v_cooldown_until IS NULL OR v_cooldown_until <= NOW() THEN
        -- Start new cooldown
        v_cooldown_until := NOW() + (v_cooldown_minutes || ' minutes')::INTERVAL;

        UPDATE public.profiles
        SET booking_cooldown_until = v_cooldown_until
        WHERE id = v_passenger_id;

        -- Audit cooldown start
        -- performed_by = v_passenger_id (the action that triggered it was theirs)
        INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
        VALUES (
          v_passenger_id,
          'booking_cooldown_started'::public.audit_action,
          'profiles',
          v_passenger_id,
          jsonb_build_object(
            'cancel_count', v_cancel_count,
            'window_minutes', v_cancel_window_min,
            'cooldown_until', v_cooldown_until,
            'cooldown_minutes', v_cooldown_minutes
          ),
          format('Booking cooldown started after %s cancellations in %s minutes', v_cancel_count, v_cancel_window_min)
        );
      END IF;
    END IF;
  END IF;

  -- ── RECHECK DEPARTURE ELIGIBILITY ────────────────────────────────────────
  IF v_queue_entry.id IS NOT NULL THEN
    PERFORM public.check_departure_eligibility_on_cancel(v_queue_entry.id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'message', 'Booking cancelled successfully'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancel_booking(UUID) TO authenticated;

-- ============================================================
-- STEP 8: admin_cancel_booking_safe — ensure cancelled_by_type = 'admin'
-- Patch the existing function to stamp admin cancellations correctly.
-- ============================================================

-- Read the existing function signature from migration 20260809310000
-- admin_cancel_booking_safe(p_booking_id UUID, p_reason TEXT)
-- We patch it to also set cancelled_by_type = 'admin' in cancellations.

CREATE OR REPLACE FUNCTION public.admin_cancel_booking_safe(
  p_booking_id UUID,
  p_reason     TEXT DEFAULT 'Admin cancelled'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id       UUID;
  v_admin          RECORD;
  v_booking        RECORD;
  v_queue_entry    RECORD;
  v_cancellation_id UUID;
BEGIN
  -- Identify calling admin
  v_admin_id := auth.uid();
  SELECT * INTO v_admin FROM public.profiles WHERE id = v_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  -- Fetch booking
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
  END IF;

  IF v_booking.status NOT IN ('queued', 'confirmed', 'matching') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Cannot cancel booking with status: %s', v_booking.status)
    );
  END IF;

  -- Fetch queue entry
  SELECT * INTO v_queue_entry
  FROM public.passenger_queue
  WHERE booking_id = p_booking_id FOR UPDATE;

  -- Cancel booking
  UPDATE public.bookings SET status = 'cancelled', updated_at = NOW() WHERE id = p_booking_id;

  -- Cancel queue entry
  IF v_queue_entry.id IS NOT NULL THEN
    UPDATE public.passenger_queue SET status = 'CANCELLED', updated_at = NOW() WHERE id = v_queue_entry.id;
  END IF;

  -- Record cancellation — admin type (does NOT count toward passenger abuse)
  INSERT INTO public.cancellations (booking_id, cancelled_by, reason, cancelled_by_type)
  VALUES (p_booking_id, v_admin_id, COALESCE(p_reason, 'Admin cancelled'), 'admin')
  RETURNING id INTO v_cancellation_id;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    v_admin_id,
    'booking_cancelled'::public.audit_action,
    'bookings',
    p_booking_id,
    jsonb_build_object(
      'cancelled_by_type', 'admin',
      'reason', p_reason,
      'cancellation_id', v_cancellation_id
    ),
    'Admin cancelled booking'
  );

  -- Recheck departure eligibility
  IF v_queue_entry.id IS NOT NULL THEN
    PERFORM public.check_departure_eligibility_on_cancel(v_queue_entry.id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'message', 'Booking cancelled by admin'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_cancel_booking_safe(UUID, TEXT) TO authenticated;

-- ============================================================
-- STEP 9: admin_clear_booking_cooldown RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_clear_booking_cooldown(
  p_profile_id UUID,
  p_reason     TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id   UUID;
  v_admin      RECORD;
  v_passenger  RECORD;
BEGIN
  -- Identify calling admin
  v_admin_id := auth.uid();
  SELECT * INTO v_admin FROM public.profiles WHERE id = v_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  -- Reason required
  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'A reason is required to clear a booking cooldown');
  END IF;

  -- Fetch passenger profile
  SELECT * INTO v_passenger FROM public.profiles WHERE id = p_profile_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Passenger profile not found');
  END IF;

  -- Only clear cooldown — do NOT reactivate suspended accounts
  IF v_passenger.status = 'suspended' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Passenger is suspended. Use Reactivate to restore account access. Cooldown clear does not unsuspend.'
    );
  END IF;

  -- Check if cooldown is actually active
  IF v_passenger.booking_cooldown_until IS NULL OR v_passenger.booking_cooldown_until <= NOW() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No active cooldown to clear for this passenger'
    );
  END IF;

  -- Clear cooldown
  UPDATE public.profiles
  SET booking_cooldown_until = NULL
  WHERE id = p_profile_id;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
  VALUES (
    v_admin_id,
    'booking_cooldown_cleared_admin'::public.audit_action,
    'profiles',
    p_profile_id,
    jsonb_build_object(
      'cleared_by_admin', v_admin_id,
      'reason', p_reason,
      'passenger_id', p_profile_id
    ),
    format('Admin cleared booking cooldown: %s', p_reason)
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Booking cooldown cleared. Passenger may book immediately.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_clear_booking_cooldown(UUID, TEXT) TO authenticated;

-- ============================================================
-- STEP 10: GRANTS for helper functions
-- ============================================================

GRANT EXECUTE ON FUNCTION public.get_business_setting_int(TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_business_setting_bool(TEXT, BOOLEAN) TO authenticated;
