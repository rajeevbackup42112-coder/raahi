-- ============================================================
-- RAAHI — Fix Canonical Completion Timestamps
-- Migration: 20260811170000_raahi_fix_completed_at_timestamps.sql
-- ============================================================
--
-- ROOT CAUSE:
--   driver_complete_trip (last deployed in 20260810000000) does NOT set
--   completed_at = NOW() when it marks trips.status = 'completed'.
--   It also does NOT set completed_at = NOW() when it marks
--   driver_queue rows as status = 'completed'.
--
--   The trips.completed_at column was added in migration 20260811060000
--   (ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ).
--   That migration backfilled existing completed trips using updated_at.
--   But all trips completed AFTER that migration (including the confirmed
--   live trip) have completed_at = NULL because driver_complete_trip
--   never writes it.
--
--   The driver_queue.completed_at column was defined in the original
--   schema (20260809012749). Stage3 (20260809023814) correctly set
--   completed_at = NOW() on driver_queue cancellations and completions.
--   However, migration 20260810000000 rewrote driver_complete_trip and
--   omitted completed_at from the driver_queue UPDATE, breaking the
--   lifecycle timestamp contract.
--
-- CONFIRMED LIVE EVIDENCE:
--   After a successful trip completion:
--     trips.status = 'completed'          ✓
--     trips.actual_arrival = <timestamp>  ✓
--     trips.completed_at = NULL           ✗  ← BUG
--     driver_queue.status = 'completed'   ✓
--     driver_queue.completed_at = NULL    ✗  ← BUG
--
-- DRIVER_QUEUE.COMPLETED_AT SEMANTICS (verified from schema + stage3):
--   driver_queue.completed_at records the terminal lifecycle timestamp
--   for a queue row — the moment it transitioned to a terminal state
--   (either 'completed' or 'cancelled'). Stage3 set it on both.
--   Migration 20260810000000 preserved it for cancellations (via other
--   RPCs) but omitted it from the driver_complete_trip UPDATE.
--   Setting completed_at = NOW() when marking queue rows 'completed'
--   is correct and consistent with the established contract.
--
-- OTHER COMPLETION PATHS AUDITED:
--
--   Stage3 driver_complete_trip (20260809023814, line 582):
--     UPDATE public.trips SET status = 'completed', actual_arrival = NOW()
--     → Does NOT set completed_at. Superseded by 20260810000000.
--     No action needed (superseded).
--
--   admin_recover_stale_booking (20260811090000):
--     Only marks bookings as 'cancelled'. Never sets trips.status='completed'.
--     NOT affected.
--
--   System stale-state repair DO block (20260811090000):
--     Only marks bookings as 'cancelled'. Never sets trips.status='completed'.
--     NOT affected.
--
--   All other RPCs that set trips.status:
--     'cancelled' — cancel_booking, admin_cancel_booking, release_provisional_trip,
--                   driver_go_offline, admin_remove_driver_from_queue, etc.
--                   These are cancellation paths, not completion paths.
--                   completed_at is not semantically appropriate here.
--     'in_progress', 'boarding', 'full', 'accepting_bookings', 'departure_pending':
--                   Non-terminal transitions. completed_at not applicable.
--
--   CONCLUSION: driver_complete_trip is the ONLY canonical trip completion
--   path. No other RPC sets trips.status='completed'. The fix is isolated
--   to driver_complete_trip.
--
-- FIX:
--   1. driver_complete_trip: add completed_at = NOW() to the trips UPDATE.
--   2. driver_complete_trip: add completed_at = NOW() to the driver_queue UPDATE.
--   3. All other logic preserved exactly from 20260810000000:
--      - actual_arrival = NOW()
--      - updated_at = NOW()
--      - bookings completed
--      - passenger_queue ASSIGNED → COMPLETED
--      - driver reset to offline
--      - current_route_id cleared
--      - current_vehicle_id preserved
--      - audit log with 'trip_completed'
--
-- DATA REPAIR:
--   Repair non-historical recent rows where:
--     trips.status = 'completed' AND trips.completed_at IS NULL
--   Use COALESCE(actual_arrival, updated_at) as the best available
--   timestamp. This is safe because:
--     - actual_arrival is set by driver_complete_trip in the same UPDATE
--       that sets status='completed', so it is the canonical completion time
--     - updated_at is the next-best proxy (also set in the same UPDATE)
--     - We do NOT touch rows where completed_at IS NOT NULL (already repaired
--       by migration 20260811060000 or set correctly)
--   Historical completed trips were already backfilled by 20260811060000.
--   This repair targets only rows completed after that migration.
--
--   driver_queue repair: rows where status='completed' AND completed_at IS NULL
--   Use updated_at as proxy (no arrival timestamp on queue rows).
--
-- WHAT IS NOT CHANGED:
--   - fare collections
--   - booking history
--   - passenger queue history
--   - FIFO ordering
--   - matching logic
--   - offer lifecycle
--   - no-show logic
--   - cancellation abuse counters
--   - any currently non-NULL completed_at values
--   - any other RPC or function
--
-- MIGRATION ORDERING:
--   This migration follows:
--     20260811160000_raahi_fix_get_my_bookings_case_enum_cast.sql
--   It is a forward-only migration. No previously deployed migration
--   is modified.
--
-- FILES CHANGED:
--   supabase/migrations/20260811170000_raahi_fix_completed_at_timestamps.sql
-- ============================================================

-- ============================================================
-- STEP 1: Fix driver_complete_trip
--
-- Changes from 20260810000000 version:
--   - trips UPDATE: add completed_at = NOW()
--   - driver_queue UPDATE: add completed_at = NOW()
--   - All other logic is IDENTICAL to 20260810000000
-- ============================================================

CREATE OR REPLACE FUNCTION public.driver_complete_trip(
  p_driver_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trip         RECORD;
  v_profile_id   UUID;
BEGIN
  -- Get driver's profile_id for audit log
  SELECT profile_id INTO v_profile_id
  FROM public.drivers
  WHERE id = p_driver_id;

  -- Find the in-progress trip
  SELECT * INTO v_trip
  FROM public.trips
  WHERE driver_id = p_driver_id
    AND status = 'in_progress'
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'No in-progress trip found');
  END IF;

  -- ----------------------------------------------------------------
  -- Mark trip as completed
  --
  -- FIX (migration 20260811170000):
  --   Added: completed_at = NOW()
  --   Preserved: actual_arrival = NOW(), updated_at = NOW()
  -- ----------------------------------------------------------------
  UPDATE public.trips
  SET
    status         = 'completed',
    actual_arrival = NOW(),
    completed_at   = NOW(),
    updated_at     = NOW()
  WHERE id = v_trip.id;

  -- Mark all confirmed bookings on this trip as completed
  UPDATE public.bookings
  SET
    status     = 'completed',
    updated_at = NOW()
  WHERE trip_id = v_trip.id
    AND status  = 'confirmed';

  -- Mark all ASSIGNED passenger_queue rows for this trip as COMPLETED
  UPDATE public.passenger_queue
  SET
    status     = 'COMPLETED',
    updated_at = NOW()
  WHERE assigned_trip_id = v_trip.id
    AND status = 'ASSIGNED';

  -- ----------------------------------------------------------------
  -- POST-COMPLETION DRIVER RESET
  -- Reset driver to OFFLINE so Driver Home shows Go Online panel.
  -- Clear current_route_id (stale active route reference).
  -- Preserve: current_vehicle_id, verification_status, license_number.
  -- ----------------------------------------------------------------
  UPDATE public.drivers
  SET
    availability_status = 'offline',
    current_route_id    = NULL,
    updated_at          = NOW()
  WHERE id = p_driver_id;

  -- ----------------------------------------------------------------
  -- CLEAR STALE DRIVER_QUEUE ROWS
  -- Mark all non-terminal driver_queue rows for this driver as
  -- 'completed' so get_driver_queue_status returns found=false.
  -- This prevents the stale "Passengers Assigned" card from appearing.
  --
  -- FIX (migration 20260811170000):
  --   Added: completed_at = NOW()
  --   driver_queue.completed_at records the terminal lifecycle timestamp
  --   (the moment the row transitioned to a terminal state). Stage3
  --   set this correctly; 20260810000000 omitted it. Restored here.
  -- ----------------------------------------------------------------
  UPDATE public.driver_queue
  SET
    status       = 'completed',
    completed_at = NOW(),
    updated_at   = NOW()
  WHERE driver_id = p_driver_id
    AND status IN ('waiting', 'offered', 'assigned');

  -- Audit log
  INSERT INTO public.audit_logs (
    performed_by,
    action,
    target_table,
    target_id,
    new_value,
    notes
  )
  VALUES (
    v_profile_id,
    'trip_completed'::public.audit_action,
    'trips',
    v_trip.id,
    jsonb_build_object(
      'driver_id',           p_driver_id,
      'driver_profile_id',   v_profile_id,
      'post_trip_status',    'offline',
      'route_cleared',       true,
      'completed_at_set',    true
    ),
    'Trip completed by driver — driver reset to offline'
  );

  RETURN jsonb_build_object(
    'success',  true,
    'trip_id',  v_trip.id,
    'message',  'Trip completed. You can go online again to join the queue.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.driver_complete_trip(UUID) TO authenticated;

-- ============================================================
-- STEP 2: DATA REPAIR — trips.completed_at
--
-- Repair rows where:
--   status = 'completed' AND completed_at IS NULL
--
-- These are trips completed after migration 20260811060000 deployed
-- (which backfilled earlier rows) but before this fix.
--
-- Strategy: COALESCE(actual_arrival, updated_at)
--   actual_arrival is set by driver_complete_trip in the same UPDATE
--   that sets status='completed', making it the canonical completion time.
--   updated_at is the fallback if actual_arrival is somehow NULL.
--
-- Safety: Only touches rows where completed_at IS NULL.
--         Does NOT modify rows where completed_at IS NOT NULL.
--         Does NOT modify cancelled trips.
--         Does NOT modify non-terminal trips.
-- ============================================================

UPDATE public.trips
SET
  completed_at = COALESCE(actual_arrival, updated_at),
  updated_at   = updated_at  -- preserve existing updated_at (no-op assignment)
WHERE status = 'completed'
  AND completed_at IS NULL;

-- ============================================================
-- STEP 3: DATA REPAIR — driver_queue.completed_at
--
-- Repair rows where:
--   status = 'completed' AND completed_at IS NULL
--
-- These are queue rows completed by driver_complete_trip after
-- migration 20260810000000 (which omitted completed_at) and before
-- this fix.
--
-- Strategy: Use updated_at as proxy.
--   driver_queue rows have no arrival timestamp. updated_at is set
--   in the same UPDATE that sets status='completed', making it the
--   best available proxy for the terminal transition time.
--
-- Safety: Only touches rows where completed_at IS NULL.
--         Does NOT modify rows where completed_at IS NOT NULL.
--         Does NOT modify cancelled rows (those were set correctly
--         by other RPCs that already wrote completed_at = NOW()).
-- ============================================================

UPDATE public.driver_queue
SET
  completed_at = updated_at
WHERE status = 'completed'
  AND completed_at IS NULL;

-- ============================================================
-- STEP 4: Verification
-- ============================================================

DO $$
DECLARE
  v_trips_null_count    INTEGER;
  v_dq_null_count       INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_trips_null_count
  FROM public.trips
  WHERE status = 'completed'
    AND completed_at IS NULL;

  SELECT COUNT(*) INTO v_dq_null_count
  FROM public.driver_queue
  WHERE status = 'completed'
    AND completed_at IS NULL;

  IF v_trips_null_count > 0 THEN
    RAISE NOTICE 'WARNING: % completed trip(s) still have completed_at = NULL after repair', v_trips_null_count;
  ELSE
    RAISE NOTICE 'OK: All completed trips now have completed_at set';
  END IF;

  IF v_dq_null_count > 0 THEN
    RAISE NOTICE 'WARNING: % completed driver_queue row(s) still have completed_at = NULL after repair', v_dq_null_count;
  ELSE
    RAISE NOTICE 'OK: All completed driver_queue rows now have completed_at set';
  END IF;
END $$;
