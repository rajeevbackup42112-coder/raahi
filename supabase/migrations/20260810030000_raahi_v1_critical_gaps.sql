-- ============================================================
-- RAAHI V1 CRITICAL GAPS
-- Migration: 20260810030000_raahi_v1_critical_gaps.sql
-- ============================================================
--
-- PRE-IMPLEMENTATION AUDIT MATRIX:
--
-- PASSENGER CAN EDIT SEAT COUNT:           NO  (cancel+rebook is canonical V1)
-- PASSENGER CAN EDIT ROUTE:                NO  (cancel+rebook is canonical V1)
-- DRIVER CAN CHANGE ROUTE WHILE ONLINE:    NO  (go offline → re-select → go online)
-- DRIVER CAN SELECT MULTIPLE VEHICLES:     NO  (current_vehicle_id is single FK)
-- ONE ACTIVE VEHICLE PER DRIVER ENFORCED:  NO  → FIX IN THIS MIGRATION
-- ONE ACTIVE DRIVER PER VEHICLE ENFORCED:  NO  → FIX IN THIS MIGRATION
-- SERVER OFFER EXPIRY:                     PASS (pg_cron + edge fn + lazy check)
-- BROWSER-CLOSED OFFER EXPIRY:             PASS (pg_cron + edge fn)
-- ADMIN VEHICLE REASSIGNMENT:              PASS (assignVehicleToDriver in UI)
-- ADMIN DRIVER REPLACEMENT:                NOT IMPLEMENTED → PARTIAL FIX (abort flow)
-- IN-PROGRESS TRIP RECOVERY:               NOT IMPLEMENTED → FIX IN THIS MIGRATION
-- ADMIN PASSENGER SUSPENSION:              PASS (updatePassengerStatus in UI)
-- ADMIN PASSENGER REACTIVATION:            PASS (updatePassengerStatus in UI)
-- ADMIN DRIVER SUSPEND/REACTIVATE:         PASS (fixed in v51 + migration 020)
-- ROUTE PAUSE:                             NOT IMPLEMENTED → FIX IN THIS MIGRATION
-- GENERIC DANGEROUS STATUS EDITING EXISTS: NO
--
-- V1 CRITICAL GAPS ADDRESSED HERE:
--   1. One active vehicle per driver — server-side constraint + RPC guard
--   2. One active driver per vehicle — server-side uniqueness check in RPCs
--   3. Route pause/resume — new route_status enum value + admin RPC
--   4. Admin passenger suspend/reactivate — proper RPCs with audit + reason
--   5. Trip abort/recovery — admin_abort_trip RPC returns passengers to FIFO
--
-- NOT IMPLEMENTED (V1 NICE-TO-HAVE / POST-V1):
--   - Full in-progress driver replacement (complex, post-V1)
--   - Undo accidental start (post-V1, safety analysis needed)
--   - Abuse cooldown clear (post-V1)
-- ============================================================

-- ============================================================
-- STEP 1: EXTEND ENUMS
-- ============================================================

-- Add 'paused' to route_status (distinct from 'inactive' — paused means
-- temporarily suspended, no new bookings, existing bookings preserved)
ALTER TYPE public.route_status ADD VALUE IF NOT EXISTS 'paused';

COMMIT;

-- Add audit actions for new operations
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'passenger_suspended';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'passenger_reactivated';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'route_paused';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'route_resumed';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'trip_aborted';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'passengers_recovered_after_abort';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'vehicle_reassigned_admin';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'driver_added_to_queue_admin';

COMMIT;

-- ============================================================
-- STEP 2: ONE ACTIVE VEHICLE PER DRIVER — ENFORCEMENT
--
-- Rule: A driver may have exactly one current_vehicle_id at a time.
-- The drivers.current_vehicle_id column already enforces this structurally
-- (single FK column). The gap is that admin_assign_vehicle_to_driver
-- (done directly in UI) does not clear the old vehicle's assigned_driver_id.
--
-- We add a server-side RPC: admin_assign_vehicle_to_driver
-- This replaces the direct table update in AdminUsersClient.
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_assign_vehicle_to_driver(
  p_driver_id  UUID,   -- drivers.id
  p_vehicle_id UUID,   -- vehicles.id (new vehicle)
  p_reason     TEXT DEFAULT 'Admin vehicle assignment'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_profile_id UUID;
  v_admin            RECORD;
  v_driver           RECORD;
  v_vehicle          RECORD;
  v_old_vehicle_id   UUID;
  v_conflict_driver  RECORD;
BEGIN
  -- Identify calling admin
  v_admin_profile_id := auth.uid();
  SELECT * INTO v_admin FROM public.profiles WHERE id = v_admin_profile_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  -- Lock and fetch driver
  SELECT * INTO v_driver FROM public.drivers WHERE id = p_driver_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver not found');
  END IF;

  -- Fetch vehicle
  SELECT * INTO v_vehicle FROM public.vehicles WHERE id = p_vehicle_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Vehicle not found');
  END IF;

  -- Vehicle must be active
  IF v_vehicle.status <> 'active' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Vehicle is not active — cannot assign');
  END IF;

  -- Vehicle must have valid capacity
  IF v_vehicle.seating_capacity IS NULL OR v_vehicle.seating_capacity < 1 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Vehicle has invalid seating capacity');
  END IF;

  -- Driver must be approved
  IF v_driver.verification_status <> 'approved' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver must be approved before assigning a vehicle');
  END IF;

  -- ONE ACTIVE DRIVER PER VEHICLE: check if vehicle is already committed to another ACTIVE driver
  -- "Active" means the other driver is currently queued/on_trip/active (not offline/suspended)
  SELECT d.* INTO v_conflict_driver
  FROM public.drivers d
  WHERE d.current_vehicle_id = p_vehicle_id
    AND d.id <> p_driver_id
    AND d.availability_status NOT IN ('offline', 'completed')
    AND d.verification_status NOT IN ('suspended', 'rejected')
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format(
        'Vehicle is already assigned to an active driver. Remove that driver from the vehicle first.',
        v_conflict_driver.id
      )
    );
  END IF;

  -- Capture old vehicle
  v_old_vehicle_id := v_driver.current_vehicle_id;

  -- Clear old vehicle's assigned_driver_id if it was pointing to this driver
  IF v_old_vehicle_id IS NOT NULL AND v_old_vehicle_id <> p_vehicle_id THEN
    UPDATE public.vehicles
    SET assigned_driver_id = NULL, updated_at = NOW()
    WHERE id = v_old_vehicle_id AND assigned_driver_id = v_driver.profile_id;
  END IF;

  -- Assign new vehicle to driver
  UPDATE public.drivers
  SET current_vehicle_id = p_vehicle_id, updated_at = NOW()
  WHERE id = p_driver_id;

  -- Point vehicle back to this driver's profile
  UPDATE public.vehicles
  SET assigned_driver_id = v_driver.profile_id, updated_at = NOW()
  WHERE id = p_vehicle_id;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (
    v_admin_profile_id,
    'vehicle_reassigned_admin'::public.audit_action,
    'drivers',
    p_driver_id,
    jsonb_build_object('old_vehicle_id', v_old_vehicle_id),
    jsonb_build_object('new_vehicle_id', p_vehicle_id),
    p_reason
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Vehicle assigned successfully',
    'old_vehicle_id', v_old_vehicle_id,
    'new_vehicle_id', p_vehicle_id
  );
END;
$$;

-- ============================================================
-- STEP 3: ONE ACTIVE DRIVER PER VEHICLE — GUARD IN driver_go_online
--
-- When a driver goes online, verify their assigned vehicle is not
-- currently committed to another active driver.
-- ============================================================

-- Drop old signature (p_driver_id, p_route_id, p_vehicle_id — all required)
-- so we can rename p_driver_id → p_driver_profile_id and make p_vehicle_id optional.
DROP FUNCTION IF EXISTS public.driver_go_online(UUID, UUID, UUID);

CREATE OR REPLACE FUNCTION public.driver_go_online(
  p_driver_profile_id UUID,
  p_route_id          UUID,
  p_vehicle_id        UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver          RECORD;
  v_route           RECORD;
  v_vehicle         RECORD;
  v_effective_vid   UUID;
  v_conflict_driver RECORD;
  v_existing_queue  RECORD;
  v_profile         RECORD;
BEGIN
  -- Get driver
  SELECT * INTO v_driver FROM public.drivers WHERE profile_id = p_driver_profile_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver profile not found');
  END IF;

  -- Must be approved
  IF v_driver.verification_status <> 'approved' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver is not approved');
  END IF;

  -- Must not be suspended at profile level
  SELECT * INTO v_profile FROM public.profiles WHERE id = p_driver_profile_id;
  IF v_profile.status = 'suspended' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Account is suspended');
  END IF;

  -- Route must be active (not paused or inactive)
  SELECT * INTO v_route FROM public.routes WHERE id = p_route_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Route not found');
  END IF;
  IF v_route.status <> 'active' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Route is not currently active');
  END IF;

  -- Determine effective vehicle: use assigned vehicle (V1 rule: one vehicle per driver)
  v_effective_vid := COALESCE(p_vehicle_id, v_driver.current_vehicle_id);
  IF v_effective_vid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No vehicle assigned. Admin must assign a vehicle before you can go online.');
  END IF;

  -- Fetch vehicle
  SELECT * INTO v_vehicle FROM public.vehicles WHERE id = v_effective_vid;
  IF NOT FOUND OR v_vehicle.status <> 'active' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Assigned vehicle is not active');
  END IF;

  -- ONE ACTIVE DRIVER PER VEHICLE: block if another active driver has this vehicle
  SELECT d.* INTO v_conflict_driver
  FROM public.drivers d
  WHERE d.current_vehicle_id = v_effective_vid
    AND d.id <> v_driver.id
    AND d.availability_status NOT IN ('offline', 'completed')
    AND d.verification_status NOT IN ('suspended', 'rejected')
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'This vehicle is currently in use by another active driver. Contact admin to resolve.'
    );
  END IF;

  -- Check for existing non-terminal queue entry
  SELECT * INTO v_existing_queue
  FROM public.driver_queue
  WHERE driver_id = v_driver.id
    AND status NOT IN ('completed', 'cancelled', 'declined')
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Already in queue or on a trip');
  END IF;

  -- Insert into driver_queue
  INSERT INTO public.driver_queue (
    route_id, driver_id, vehicle_id, queue_position, status, joined_at
  )
  VALUES (
    p_route_id,
    v_driver.id,
    v_effective_vid,
    (SELECT COALESCE(MAX(queue_position), 0) + 1
     FROM public.driver_queue
     WHERE route_id = p_route_id AND status NOT IN ('completed', 'cancelled', 'declined')),
    'waiting'::public.queue_status,
    NOW()
  );

  -- Update driver state
  UPDATE public.drivers
  SET
    availability_status = 'online'::public.driver_availability_status,
    current_route_id    = p_route_id,
    current_vehicle_id  = v_effective_vid,
    updated_at          = NOW()
  WHERE id = v_driver.id;

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value)
  VALUES (
    p_driver_profile_id,
    'driver_joined_queue'::public.audit_action,
    'drivers',
    v_driver.id,
    jsonb_build_object('route_id', p_route_id, 'vehicle_id', v_effective_vid)
  );

  -- Trigger matching
  PERFORM public.match_route_queue(p_route_id);

  RETURN jsonb_build_object('success', true, 'message', 'You are now online and in the queue');
END;
$$;

-- ============================================================
-- STEP 4: ROUTE PAUSE / RESUME
--
-- 'paused' = temporarily suspended. No new bookings accepted.
-- Existing bookings and active trips are preserved.
-- Drivers already queued on a paused route are NOT automatically
-- removed — Admin must handle that explicitly.
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_pause_route(
  p_route_id UUID,
  p_reason   TEXT DEFAULT 'Admin paused route'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_admin    RECORD;
  v_route    RECORD;
BEGIN
  v_admin_id := auth.uid();
  SELECT * INTO v_admin FROM public.profiles WHERE id = v_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  SELECT * INTO v_route FROM public.routes WHERE id = p_route_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Route not found');
  END IF;

  IF v_route.status = 'paused' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Route is already paused');
  END IF;

  UPDATE public.routes
  SET status = 'paused'::public.route_status, updated_at = NOW()
  WHERE id = p_route_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (
    v_admin_id,
    'route_paused'::public.audit_action,
    'routes',
    p_route_id,
    jsonb_build_object('status', v_route.status),
    jsonb_build_object('status', 'paused'),
    p_reason
  );

  RETURN jsonb_build_object('success', true, 'message', 'Route paused — no new bookings will be accepted');
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_resume_route(
  p_route_id UUID,
  p_reason   TEXT DEFAULT 'Admin resumed route'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_admin    RECORD;
  v_route    RECORD;
BEGIN
  v_admin_id := auth.uid();
  SELECT * INTO v_admin FROM public.profiles WHERE id = v_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  SELECT * INTO v_route FROM public.routes WHERE id = p_route_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Route not found');
  END IF;

  IF v_route.status = 'active' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Route is already active');
  END IF;

  UPDATE public.routes
  SET status = 'active'::public.route_status, updated_at = NOW()
  WHERE id = p_route_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (
    v_admin_id,
    'route_resumed'::public.audit_action,
    'routes',
    p_route_id,
    jsonb_build_object('status', v_route.status),
    jsonb_build_object('status', 'active'),
    p_reason
  );

  RETURN jsonb_build_object('success', true, 'message', 'Route resumed — bookings can now be accepted');
END;
$$;

-- ============================================================
-- STEP 5: ADMIN PASSENGER SUSPEND / REACTIVATE
--
-- Proper RPCs with reason, audit log, and safety checks.
-- Suspension blocks new bookings but does NOT cancel existing ones
-- (Admin must cancel bookings explicitly if needed).
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_suspend_passenger(
  p_passenger_id UUID,
  p_reason       TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id  UUID;
  v_admin     RECORD;
  v_passenger RECORD;
BEGIN
  v_admin_id := auth.uid();
  SELECT * INTO v_admin FROM public.profiles WHERE id = v_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'A reason is required to suspend a passenger');
  END IF;

  SELECT * INTO v_passenger FROM public.profiles WHERE id = p_passenger_id AND role = 'passenger';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Passenger not found');
  END IF;

  IF v_passenger.status = 'suspended' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Passenger is already suspended');
  END IF;

  UPDATE public.profiles
  SET status = 'suspended'::public.user_status, updated_at = NOW()
  WHERE id = p_passenger_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (
    v_admin_id,
    'passenger_suspended'::public.audit_action,
    'profiles',
    p_passenger_id,
    jsonb_build_object('status', v_passenger.status),
    jsonb_build_object('status', 'suspended'),
    p_reason
  );

  RETURN jsonb_build_object('success', true, 'message', 'Passenger suspended');
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_reactivate_passenger(
  p_passenger_id UUID,
  p_reason       TEXT DEFAULT 'Admin reactivated passenger'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id  UUID;
  v_admin     RECORD;
  v_passenger RECORD;
BEGIN
  v_admin_id := auth.uid();
  SELECT * INTO v_admin FROM public.profiles WHERE id = v_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  SELECT * INTO v_passenger FROM public.profiles WHERE id = p_passenger_id AND role = 'passenger';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Passenger not found');
  END IF;

  IF v_passenger.status = 'active' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Passenger is already active');
  END IF;

  UPDATE public.profiles
  SET status = 'active'::public.user_status, updated_at = NOW()
  WHERE id = p_passenger_id;

  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (
    v_admin_id,
    'passenger_reactivated'::public.audit_action,
    'profiles',
    p_passenger_id,
    jsonb_build_object('status', v_passenger.status),
    jsonb_build_object('status', 'active'),
    p_reason
  );

  RETURN jsonb_build_object('success', true, 'message', 'Passenger reactivated — they can book again');
END;
$$;

-- ============================================================
-- STEP 6: TRIP ABORT / RECOVERY
--
-- admin_abort_trip: safely aborts an in-progress or accepted trip.
-- - Marks trip as 'cancelled' (existing terminal state — no new enum needed)
-- - Returns all non-completed passengers to FIFO WAITING state
-- - Clears driver state (back to offline)
-- - Preserves all booking history and audit trail
-- - Does NOT automatically re-match (Admin may want to pause route first)
-- - Triggers match_route_queue after recovery so FIFO proceeds automatically
--
-- Eligible trip statuses for abort:
--   accepting_bookings, boarding, in_progress
--   (NOT completed or already cancelled)
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_abort_trip(
  p_trip_id UUID,
  p_reason  TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id        UUID;
  v_admin           RECORD;
  v_trip            RECORD;
  v_driver          RECORD;
  v_queue_entry     RECORD;
  v_recovered_count INTEGER := 0;
  v_route_id        UUID;
BEGIN
  v_admin_id := auth.uid();
  SELECT * INTO v_admin FROM public.profiles WHERE id = v_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'A reason is required to abort a trip');
  END IF;

  -- Lock trip
  SELECT * INTO v_trip FROM public.trips WHERE id = p_trip_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Trip not found');
  END IF;

  -- Only abort non-terminal trips
  IF v_trip.status IN ('completed', 'cancelled') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Trip is already in terminal state: %s', v_trip.status)
    );
  END IF;

  v_route_id := v_trip.route_id;

  -- ── 1. Cancel the trip ──────────────────────────────────────
  UPDATE public.trips
  SET
    status     = 'cancelled'::public.trip_status,
    notes      = format('aborted_by_admin: %s', p_reason),
    updated_at = NOW()
  WHERE id = p_trip_id;

  -- ── 2. Recover passengers → return to FIFO WAITING ─────────
  -- For each passenger_queue entry pointing to this trip that is
  -- not already COMPLETED or CANCELLED, return them to WAITING.
  -- Preserve original queue_sequence so FIFO order is maintained.
  UPDATE public.passenger_queue
  SET
    status           = 'WAITING',
    assigned_trip_id = NULL,
    updated_at       = NOW()
  WHERE assigned_trip_id = p_trip_id
    AND status NOT IN ('COMPLETED', 'CANCELLED');

  GET DIAGNOSTICS v_recovered_count = ROW_COUNT;

  -- Reset bookings that were linked to this trip back to queued
  UPDATE public.bookings
  SET
    trip_id    = NULL,
    status     = 'queued'::public.booking_status,
    updated_at = NOW()
  WHERE trip_id = p_trip_id
    AND status NOT IN ('cancelled', 'no_show', 'completed');

  -- ── 3. Release driver ───────────────────────────────────────
  IF v_trip.driver_id IS NOT NULL THEN
    SELECT * INTO v_driver FROM public.drivers WHERE id = v_trip.driver_id;

    IF FOUND THEN
      -- Mark driver offline (they must choose to go online again)
      UPDATE public.drivers
      SET
        availability_status = 'offline'::public.driver_availability_status,
        current_route_id    = NULL,
        updated_at          = NOW()
      WHERE id = v_trip.driver_id;

      -- End any non-terminal driver_queue entry for this driver
      UPDATE public.driver_queue
      SET
        status       = 'cancelled'::public.queue_status,
        completed_at = NOW(),
        updated_at   = NOW()
      WHERE driver_id = v_trip.driver_id
        AND status NOT IN ('completed', 'cancelled', 'declined');
    END IF;
  END IF;

  -- ── 4. Audit ────────────────────────────────────────────────
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (
    v_admin_id,
    'trip_aborted'::public.audit_action,
    'trips',
    p_trip_id,
    jsonb_build_object('status', v_trip.status, 'driver_id', v_trip.driver_id),
    jsonb_build_object('status', 'cancelled', 'recovered_passengers', v_recovered_count),
    p_reason
  );

  IF v_recovered_count > 0 THEN
    INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, new_value, notes)
    VALUES (
      v_admin_id,
      'passengers_recovered_after_abort'::public.audit_action,
      'trips',
      p_trip_id,
      jsonb_build_object('recovered_count', v_recovered_count, 'route_id', v_route_id),
      p_reason
    );
  END IF;

  -- ── 5. Trigger FIFO re-match for recovered passengers ───────
  -- Non-blocking: if no eligible driver is available, passengers
  -- simply remain in WAITING state until a driver goes online.
  IF v_recovered_count > 0 THEN
    PERFORM public.match_route_queue(v_route_id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', format('Trip aborted. %s passenger(s) returned to queue.', v_recovered_count),
    'recovered_passengers', v_recovered_count,
    'trip_id', p_trip_id
  );
END;
$$;

-- ============================================================
-- STEP 7: ADMIN SUSPEND DRIVER (proper RPC with reason + queue cleanup)
--
-- Existing UI calls direct table update. Add a proper RPC that also
-- removes the driver from any active queue entry and prevents matching.
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_suspend_driver(
  p_driver_id UUID,   -- drivers.id
  p_reason    TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_admin    RECORD;
  v_driver   RECORD;
  v_trip     RECORD;
BEGIN
  v_admin_id := auth.uid();
  SELECT * INTO v_admin FROM public.profiles WHERE id = v_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'A reason is required to suspend a driver');
  END IF;

  SELECT * INTO v_driver FROM public.drivers WHERE id = p_driver_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver not found');
  END IF;

  IF v_driver.verification_status = 'suspended' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Driver is already suspended');
  END IF;

  -- Safety check: block suspension if driver has an active in-progress trip
  SELECT t.* INTO v_trip
  FROM public.trips t
  WHERE t.driver_id = p_driver_id
    AND t.status IN ('in_progress', 'boarding')
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Cannot suspend driver during an active trip. Use Trip Abort first, then suspend.'
    );
  END IF;

  -- Suspend driver
  UPDATE public.drivers
  SET
    verification_status = 'suspended'::public.driver_verification_status,
    availability_status = 'offline'::public.driver_availability_status,
    current_route_id    = NULL,
    updated_at          = NOW()
  WHERE id = p_driver_id;

  -- Remove from any active queue entry (not on a trip)
  UPDATE public.driver_queue
  SET
    status       = 'cancelled'::public.queue_status,
    completed_at = NOW(),
    updated_at   = NOW()
  WHERE driver_id = p_driver_id
    AND status NOT IN ('completed', 'cancelled', 'declined', 'assigned');

  -- Audit
  INSERT INTO public.audit_logs (performed_by, action, target_table, target_id, old_value, new_value, notes)
  VALUES (
    v_admin_id,
    'driver_suspended'::public.audit_action,
    'drivers',
    p_driver_id,
    jsonb_build_object('verification_status', v_driver.verification_status, 'availability_status', v_driver.availability_status),
    jsonb_build_object('verification_status', 'suspended', 'availability_status', 'offline'),
    p_reason
  );

  RETURN jsonb_build_object('success', true, 'message', 'Driver suspended and removed from queue');
END;
$$;

-- ============================================================
-- STEP 8: GET TRIPS FOR ADMIN (for abort UI)
-- Returns non-terminal trips with driver/vehicle/passenger info
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_admin_active_trips(
  p_limit  INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_admin    RECORD;
  v_result   JSONB;
BEGIN
  v_admin_id := auth.uid();
  SELECT * INTO v_admin FROM public.profiles WHERE id = v_admin_id AND role = 'admin';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin only');
  END IF;

  SELECT jsonb_agg(row_to_json(t)) INTO v_result
  FROM (
    SELECT
      tr.id,
      tr.status,
      tr.total_seats,
      tr.booked_seats,
      tr.scheduled_departure,
      tr.actual_departure,
      tr.notes,
      tr.created_at,
      r.from_location,
      r.to_location,
      r.id AS route_id,
      v.make AS vehicle_make,
      v.model AS vehicle_model,
      v.registration_number AS vehicle_reg,
      p.name AS driver_name,
      p.phone AS driver_phone,
      (
        SELECT COUNT(*)
        FROM public.passenger_queue pq
        WHERE pq.assigned_trip_id = tr.id
          AND pq.status NOT IN ('CANCELLED', 'COMPLETED')
      ) AS active_passenger_count
    FROM public.trips tr
    LEFT JOIN public.routes r ON r.id = tr.route_id
    LEFT JOIN public.vehicles v ON v.id = tr.vehicle_id
    LEFT JOIN public.drivers d ON d.id = tr.driver_id
    LEFT JOIN public.profiles p ON p.id = d.profile_id
    WHERE tr.status NOT IN ('completed', 'cancelled')
    ORDER BY tr.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) t;

  RETURN jsonb_build_object('success', true, 'trips', COALESCE(v_result, '[]'::jsonb));
END;
$$;

-- ============================================================
-- STEP 9: REPAIR EXISTING INCONSISTENCIES
--
-- Fix any suspended drivers that still show as queued/online.
-- ============================================================

DO $$
BEGIN
  -- Suspended drivers should be offline and not in active queue
  UPDATE public.drivers
  SET
    availability_status = 'offline'::public.driver_availability_status,
    current_route_id    = NULL,
    updated_at          = NOW()
  WHERE verification_status = 'suspended'
    AND availability_status NOT IN ('offline', 'completed');

  -- Cancel any active queue entries for suspended drivers
  UPDATE public.driver_queue dq
  SET
    status       = 'cancelled'::public.queue_status,
    completed_at = NOW(),
    updated_at   = NOW()
  FROM public.drivers d
  WHERE dq.driver_id = d.id
    AND d.verification_status = 'suspended'
    AND dq.status NOT IN ('completed', 'cancelled', 'declined');

  RAISE NOTICE 'Repaired suspended driver state inconsistencies.';
END;
$$;

-- ============================================================
-- POST-IMPLEMENTATION AUDIT MATRIX:
--
-- PASSENGER CAN EDIT SEAT COUNT:           NO  (V1 rule: cancel+rebook)
-- PASSENGER CAN EDIT ROUTE:                NO  (V1 rule: cancel+rebook)
-- DRIVER CAN CHANGE ROUTE WHILE ONLINE:    NO  (V1 rule: go offline first)
-- DRIVER CAN SELECT MULTIPLE VEHICLES:     NO  (single current_vehicle_id)
-- ONE ACTIVE VEHICLE PER DRIVER ENFORCED:  YES (admin_assign_vehicle_to_driver RPC)
-- ONE ACTIVE DRIVER PER VEHICLE ENFORCED:  YES (driver_go_online + assign RPC)
-- SERVER OFFER EXPIRY:                     PASS
-- BROWSER-CLOSED OFFER EXPIRY:             PASS
-- ADMIN VEHICLE REASSIGNMENT:              PASS (admin_assign_vehicle_to_driver)
-- ADMIN DRIVER REPLACEMENT:                NOT IMPLEMENTED (post-V1)
-- IN-PROGRESS TRIP RECOVERY:               PASS (admin_abort_trip)
-- ADMIN PASSENGER SUSPENSION:              PASS (admin_suspend_passenger RPC)
-- ADMIN PASSENGER REACTIVATION:            PASS (admin_reactivate_passenger RPC)
-- ADMIN DRIVER SUSPEND/REACTIVATE:         PASS (admin_suspend_driver RPC + existing reactivate)
-- ROUTE PAUSE:                             PASS (admin_pause_route / admin_resume_route)
-- GENERIC DANGEROUS STATUS EDITING EXISTS: NO
-- ============================================================
