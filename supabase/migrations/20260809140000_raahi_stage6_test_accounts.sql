-- ============================================================
-- RAAHI STAGE 6 — TEST ACCOUNT SEED DATA
-- ============================================================
-- 
-- ⚠️  IMPORTANT: Supabase Auth users CANNOT be created via SQL migration.
-- You MUST manually create the following Auth users in Supabase Dashboard:
--
--   Dashboard → Authentication → Users → "Add user" (or "Invite user")
--
--   1. passenger@test.raahi.in   | Password: RaahiTest@2026
--   2. driver1@test.raahi.in     | Password: RaahiTest@2026
--   3. driver2@test.raahi.in     | Password: RaahiTest@2026
--   4. driver3@test.raahi.in     | Password: RaahiTest@2026
--   5. admin@test.raahi.in       | Password: RaahiTest@2026
--
--   For each user: set "Auto Confirm User" = true so no email verification needed.
--
-- After creating Auth users, run this migration to seed their profiles,
-- driver records, and vehicles.
--
-- All records are marked is_test_data = TRUE for safe cleanup.
--
-- NOTE: If Auth users have NOT been created yet, this migration will
-- skip the profile/driver/vehicle inserts gracefully (no FK errors).
-- Re-run after creating Auth users to seed the data.
-- ============================================================

-- ============================================================
-- STEP 1: Add is_test_data column if not already present
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'is_test_data'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN is_test_data BOOLEAN NOT NULL DEFAULT FALSE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'drivers' AND column_name = 'is_test_data'
  ) THEN
    ALTER TABLE public.drivers ADD COLUMN is_test_data BOOLEAN NOT NULL DEFAULT FALSE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'vehicles' AND column_name = 'is_test_data'
  ) THEN
    ALTER TABLE public.vehicles ADD COLUMN is_test_data BOOLEAN NOT NULL DEFAULT FALSE;
  END IF;
END $$;

-- ============================================================
-- STEP 2: Seed profiles — only if Auth user exists in auth.users
-- ============================================================
-- These UUIDs are placeholders. Replace with real Auth user IDs from:
--   Dashboard → Authentication → Users → copy UUID
--
-- PLACEHOLDER UUIDs — REPLACE WITH REAL AUTH USER IDs:
--   passenger_test_id  = '00000000-0000-0000-0000-000000000001'
--   driver1_test_id    = '00000000-0000-0000-0000-000000000002'
--   driver2_test_id    = '00000000-0000-0000-0000-000000000003'
--   driver3_test_id    = '00000000-0000-0000-0000-000000000004'
--   admin_test_id      = '00000000-0000-0000-0000-000000000005'
-- ============================================================

DO $$
BEGIN
  -- Passenger test profile (only if auth user exists)
  IF EXISTS (SELECT 1 FROM auth.users WHERE id = '00000000-0000-0000-0000-000000000001') THEN
    INSERT INTO public.profiles (id, name, email, phone, role, status, is_test_data)
    VALUES (
      '00000000-0000-0000-0000-000000000001',
      'Test Passenger',
      'passenger@test.raahi.in',
      NULL,
      'passenger',
      'active',
      TRUE
    )
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      email = EXCLUDED.email,
      role = EXCLUDED.role,
      status = EXCLUDED.status,
      is_test_data = TRUE;
  ELSE
    RAISE NOTICE 'Skipping passenger profile: Auth user 00000000-0000-0000-0000-000000000001 not found. Create the Auth user first, then re-run.';
  END IF;
END $$;

DO $$
BEGIN
  -- Driver 1 test profile (only if auth user exists)
  IF EXISTS (SELECT 1 FROM auth.users WHERE id = '00000000-0000-0000-0000-000000000002') THEN
    INSERT INTO public.profiles (id, name, email, phone, role, status, is_test_data)
    VALUES (
      '00000000-0000-0000-0000-000000000002',
      'Test Driver One',
      'driver1@test.raahi.in',
      NULL,
      'driver',
      'active',
      TRUE
    )
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      email = EXCLUDED.email,
      role = EXCLUDED.role,
      status = EXCLUDED.status,
      is_test_data = TRUE;
  ELSE
    RAISE NOTICE 'Skipping driver1 profile: Auth user 00000000-0000-0000-0000-000000000002 not found. Create the Auth user first, then re-run.';
  END IF;
END $$;

DO $$
BEGIN
  -- Driver 2 test profile (only if auth user exists)
  IF EXISTS (SELECT 1 FROM auth.users WHERE id = '00000000-0000-0000-0000-000000000003') THEN
    INSERT INTO public.profiles (id, name, email, phone, role, status, is_test_data)
    VALUES (
      '00000000-0000-0000-0000-000000000003',
      'Test Driver Two',
      'driver2@test.raahi.in',
      NULL,
      'driver',
      'active',
      TRUE
    )
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      email = EXCLUDED.email,
      role = EXCLUDED.role,
      status = EXCLUDED.status,
      is_test_data = TRUE;
  ELSE
    RAISE NOTICE 'Skipping driver2 profile: Auth user 00000000-0000-0000-0000-000000000003 not found. Create the Auth user first, then re-run.';
  END IF;
END $$;

DO $$
BEGIN
  -- Driver 3 test profile (only if auth user exists)
  IF EXISTS (SELECT 1 FROM auth.users WHERE id = '00000000-0000-0000-0000-000000000004') THEN
    INSERT INTO public.profiles (id, name, email, phone, role, status, is_test_data)
    VALUES (
      '00000000-0000-0000-0000-000000000004',
      'Test Driver Three',
      'driver3@test.raahi.in',
      NULL,
      'driver',
      'active',
      TRUE
    )
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      email = EXCLUDED.email,
      role = EXCLUDED.role,
      status = EXCLUDED.status,
      is_test_data = TRUE;
  ELSE
    RAISE NOTICE 'Skipping driver3 profile: Auth user 00000000-0000-0000-0000-000000000004 not found. Create the Auth user first, then re-run.';
  END IF;
END $$;

DO $$
BEGIN
  -- Admin test profile (only if auth user exists)
  IF EXISTS (SELECT 1 FROM auth.users WHERE id = '00000000-0000-0000-0000-000000000005') THEN
    INSERT INTO public.profiles (id, name, email, phone, role, status, is_test_data)
    VALUES (
      '00000000-0000-0000-0000-000000000005',
      'Test Admin',
      'admin@test.raahi.in',
      NULL,
      'admin',
      'active',
      TRUE
    )
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      email = EXCLUDED.email,
      role = EXCLUDED.role,
      status = EXCLUDED.status,
      is_test_data = TRUE;
  ELSE
    RAISE NOTICE 'Skipping admin profile: Auth user 00000000-0000-0000-0000-000000000005 not found. Create the Auth user first, then re-run.';
  END IF;
END $$;

-- ============================================================
-- STEP 3: Seed driver records (only if profile was inserted)
-- ============================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000000002') THEN
    INSERT INTO public.drivers (profile_id, license_number, verification_status, availability_status, is_test_data)
    VALUES (
      '00000000-0000-0000-0000-000000000002',
      'TEST-DL-D1-2026',
      'approved',
      'offline',
      TRUE
    )
    ON CONFLICT (profile_id) DO UPDATE SET
      license_number = EXCLUDED.license_number,
      verification_status = EXCLUDED.verification_status,
      is_test_data = TRUE;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000000003') THEN
    INSERT INTO public.drivers (profile_id, license_number, verification_status, availability_status, is_test_data)
    VALUES (
      '00000000-0000-0000-0000-000000000003',
      'TEST-DL-D2-2026',
      'approved',
      'offline',
      TRUE
    )
    ON CONFLICT (profile_id) DO UPDATE SET
      license_number = EXCLUDED.license_number,
      verification_status = EXCLUDED.verification_status,
      is_test_data = TRUE;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000000004') THEN
    INSERT INTO public.drivers (profile_id, license_number, verification_status, availability_status, is_test_data)
    VALUES (
      '00000000-0000-0000-0000-000000000004',
      'TEST-DL-D3-2026',
      'approved',
      'offline',
      TRUE
    )
    ON CONFLICT (profile_id) DO UPDATE SET
      license_number = EXCLUDED.license_number,
      verification_status = EXCLUDED.verification_status,
      is_test_data = TRUE;
  END IF;
END $$;

-- ============================================================
-- STEP 4: Seed vehicles (only if driver profile exists)
-- ============================================================

DO $$
BEGIN
  -- Vehicle for Driver 1 — 6-seat capacity
  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000000002') THEN
    INSERT INTO public.vehicles (
      id, make, model, registration_number, seating_capacity,
      assigned_driver_id, status, is_test_data
    )
    VALUES (
      '10000000-0000-0000-0000-000000000001',
      'Maruti Suzuki', 'Ertiga',
      'TEST-JH10-D1-6S',
      6,
      '00000000-0000-0000-0000-000000000002',
      'active',
      TRUE
    )
    ON CONFLICT (id) DO UPDATE SET
      seating_capacity = EXCLUDED.seating_capacity,
      assigned_driver_id = EXCLUDED.assigned_driver_id,
      status = EXCLUDED.status,
      is_test_data = TRUE;
  END IF;
END $$;

DO $$
BEGIN
  -- Vehicle for Driver 2 — 4-seat capacity
  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000000003') THEN
    INSERT INTO public.vehicles (
      id, make, model, registration_number, seating_capacity,
      assigned_driver_id, status, is_test_data
    )
    VALUES (
      '10000000-0000-0000-0000-000000000002',
      'Maruti Suzuki', 'Dzire',
      'TEST-JH10-D2-4S',
      4,
      '00000000-0000-0000-0000-000000000003',
      'active',
      TRUE
    )
    ON CONFLICT (id) DO UPDATE SET
      seating_capacity = EXCLUDED.seating_capacity,
      assigned_driver_id = EXCLUDED.assigned_driver_id,
      status = EXCLUDED.status,
      is_test_data = TRUE;
  END IF;
END $$;

DO $$
BEGIN
  -- Vehicle for Driver 3 — 4-seat capacity
  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000000004') THEN
    INSERT INTO public.vehicles (
      id, make, model, registration_number, seating_capacity,
      assigned_driver_id, status, is_test_data
    )
    VALUES (
      '10000000-0000-0000-0000-000000000003',
      'Tata', 'Nexon',
      'TEST-JH10-D3-4S',
      4,
      '00000000-0000-0000-0000-000000000004',
      'active',
      TRUE
    )
    ON CONFLICT (id) DO UPDATE SET
      seating_capacity = EXCLUDED.seating_capacity,
      assigned_driver_id = EXCLUDED.assigned_driver_id,
      status = EXCLUDED.status,
      is_test_data = TRUE;
  END IF;
END $$;

-- ============================================================
-- STEP 5: Safe cleanup function for test data
-- ============================================================

CREATE OR REPLACE FUNCTION public.cleanup_stage6_test_accounts()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_vehicles_deleted INT;
  v_drivers_deleted INT;
  v_profiles_deleted INT;
BEGIN
  -- Delete test vehicles
  DELETE FROM public.vehicles WHERE is_test_data = TRUE;
  GET DIAGNOSTICS v_vehicles_deleted = ROW_COUNT;

  -- Delete test driver records
  DELETE FROM public.drivers WHERE is_test_data = TRUE;
  GET DIAGNOSTICS v_drivers_deleted = ROW_COUNT;

  -- Delete test profiles (Auth users must be deleted manually in Dashboard)
  DELETE FROM public.profiles WHERE is_test_data = TRUE;
  GET DIAGNOSTICS v_profiles_deleted = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', TRUE,
    'vehicles_deleted', v_vehicles_deleted,
    'drivers_deleted', v_drivers_deleted,
    'profiles_deleted', v_profiles_deleted,
    'note', 'Auth users must be deleted manually in Supabase Dashboard → Authentication → Users'
  );
END;
$$;

-- ============================================================
-- AUDIT LOG
-- ============================================================

INSERT INTO public.audit_logs (action, target_table, notes)
VALUES (
  'settings_changed',
  'profiles',
  'Stage 6 test account profiles, drivers, and vehicles seeded (skipped if Auth users not yet created). Accounts: passenger@test.raahi.in, driver1@test.raahi.in, driver2@test.raahi.in, driver3@test.raahi.in, admin@test.raahi.in. Auth users must be created manually in Supabase Dashboard.'
);
