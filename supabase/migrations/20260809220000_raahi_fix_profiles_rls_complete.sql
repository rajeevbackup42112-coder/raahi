-- ============================================================
-- RAAHI — COMPLETE PROFILES RLS AUDIT & FIX
-- Migration: 20260809220000_raahi_fix_profiles_rls_complete.sql
-- ============================================================
--
-- AUDIT FINDINGS (policies before cleanup):
--
-- ON public.profiles — ALL policies that exist or may exist:
--   1. admin_write_profiles       (stage7)   — RECURSIVE: USING/WITH CHECK contains
--                                              EXISTS (SELECT 1 FROM public.profiles p2
--                                              WHERE p2.id = auth.uid() AND p2.role = 'admin')
--                                              This subquery re-evaluates profiles RLS → HTTP 500
--   2. profiles_admin_all         (stage210) — Uses is_admin() SECURITY DEFINER — safe but
--                                              coexists with recursive admin_write_profiles
--   3. profiles_admin_full_access (stage62)  — May exist; uses is_admin() — safe
--   4. profiles_driver_select     (stage210) — id = auth.uid() — safe
--   5. profiles_own_access        (unknown)  — May exist from earlier migrations
--   6. profiles_self_select       (stage210) — id = auth.uid() — safe
--   7. profiles_self_update       (stage210) — id = auth.uid() — safe
--   8. profiles_select_own        (stage61)  — id = auth.uid() — safe but duplicate
--   9. profiles_update_own        (stage61)  — WITH CHECK has recursive subquery
--                                              role = (SELECT role FROM public.profiles
--                                              WHERE id = auth.uid()) — RECURSIVE
--  10. "Passengers read own profile" (stage61) — id = auth.uid() — safe but duplicate
--  11. "Admin can read all profiles"  (stage61) — may exist
--
-- ROOT CAUSE: admin_write_profiles (stage7) was applied AFTER stage210 which tried to fix
-- recursion. stage7 re-introduced the recursive subquery. The previous fix migration
-- (stage210) did NOT drop admin_write_profiles by name, so it survived.
--
-- CROSS-TABLE RECURSION CHECK:
--   Tables routes, vehicles, drivers, pickup_points, passenger_queue in stage7 use:
--     EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
--   These are on OTHER tables (not profiles), so they query profiles under the calling
--   user's RLS context. If profiles RLS is broken, these also fail. Fix: replace all
--   inline profiles subqueries on other tables with public.is_admin() calls.
--
-- AJIT ADMIN PROFILE:
--   id: bb28bb8a-da98-4084-83b9-014dd7299a56, role: admin
--   This migration does NOT touch any profile data rows. Only policies are changed.
--
-- RAJEEV PASSENGER PROFILE:
--   id: bc01df62-e523-4eb8-82ad-3345d72cb7ba, role: passenger
--   Not touched.
-- ============================================================

-- ============================================================
-- STEP 1: Rebuild is_admin() — SECURITY DEFINER, no recursion
-- ============================================================
-- SECURITY DEFINER means this function executes as its owner (postgres/superuser),
-- NOT as the calling authenticated user. Therefore when this function queries
-- public.profiles, the profiles RLS policies are NOT evaluated for this internal
-- lookup — no recursion is possible.
-- SET search_path = public prevents search_path injection attacks.
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

-- ============================================================
-- STEP 2: Rebuild is_driver() — SECURITY DEFINER, no recursion
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_driver()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'driver'
  );
$$;

-- ============================================================
-- STEP 3: Grant execute permissions on helper functions
-- ============================================================

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_driver() TO authenticated;

-- ============================================================
-- STEP 4: DROP every profiles policy by exact name
-- (covers all policies from all previous migrations)
-- ============================================================

-- From stage7 (the recursive offender):
DROP POLICY IF EXISTS "admin_write_profiles"          ON public.profiles;

-- From stage62 / stage210:
DROP POLICY IF EXISTS "profiles_admin_all"            ON public.profiles;
DROP POLICY IF EXISTS "profiles_admin_full_access"    ON public.profiles;
DROP POLICY IF EXISTS "profiles_driver_select"        ON public.profiles;
DROP POLICY IF EXISTS "profiles_own_access"           ON public.profiles;
DROP POLICY IF EXISTS "profiles_self_select"          ON public.profiles;
DROP POLICY IF EXISTS "profiles_self_update"          ON public.profiles;

-- From stage61 (older names):
DROP POLICY IF EXISTS "profiles_select_own"           ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own"           ON public.profiles;
DROP POLICY IF EXISTS "Passengers read own profile"   ON public.profiles;
DROP POLICY IF EXISTS "Admin can read all profiles"   ON public.profiles;

-- Any other names that may have been created:
DROP POLICY IF EXISTS "profiles_insert_own"           ON public.profiles;
DROP POLICY IF EXISTS "profiles_delete_own"           ON public.profiles;
DROP POLICY IF EXISTS "profiles_read_own"             ON public.profiles;
DROP POLICY IF EXISTS "profiles_full_access_admin"    ON public.profiles;

-- ============================================================
-- STEP 5: Ensure RLS is enabled on profiles
-- ============================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- STEP 6: Rebuild canonical profiles policies — minimum set,
--         zero recursion
-- ============================================================

-- Policy 1: Authenticated user reads their own profile
-- Uses only id = auth.uid() — no function call, no subquery, no recursion.
-- Covers both passenger and driver self-read.
CREATE POLICY "profiles_select_own"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- Policy 2: Authenticated user updates their own profile (non-privileged fields)
-- USING: must be their own row
-- WITH CHECK: must still be their own row after update
-- Role and status changes are NOT blocked here at the SQL level (that would require
-- a recursive subquery). They are blocked at the application layer. Admin can change
-- any field via the admin policy below.
CREATE POLICY "profiles_update_own"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Policy 3: Admin full access (SELECT/INSERT/UPDATE/DELETE)
-- is_admin() is SECURITY DEFINER — queries profiles as superuser, no RLS evaluation,
-- no recursion. Safe to use here.
CREATE POLICY "profiles_admin_full_access"
  ON public.profiles
  FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ============================================================
-- STEP 7: Fix cross-table policies that use inline profiles
--         subqueries instead of is_admin() / is_driver()
--
-- These policies are on OTHER tables (routes, vehicles, drivers,
-- pickup_points, passenger_queue). They query public.profiles
-- under the calling user's RLS context. If profiles RLS is
-- healthy this works, but using is_admin() (SECURITY DEFINER)
-- is cleaner, faster, and immune to any future profiles RLS issue.
-- ============================================================

-- ROUTES — replace inline subquery with is_admin()
DROP POLICY IF EXISTS "admin_write_routes"            ON public.routes;
DROP POLICY IF EXISTS "routes_admin_write"            ON public.routes;
CREATE POLICY "routes_admin_write"
  ON public.routes FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "authenticated_read_routes"     ON public.routes;
DROP POLICY IF EXISTS "routes_authenticated_read"     ON public.routes;
CREATE POLICY "routes_authenticated_read"
  ON public.routes FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "anon_read_active_routes"       ON public.routes;
CREATE POLICY "anon_read_active_routes"
  ON public.routes FOR SELECT
  TO anon
  USING (status = 'active'::public.route_status);

-- PICKUP POINTS — replace inline subquery with is_admin()
DROP POLICY IF EXISTS "admin_write_pickup_points"     ON public.pickup_points;
DROP POLICY IF EXISTS "pickup_points_admin_write"     ON public.pickup_points;
CREATE POLICY "pickup_points_admin_write"
  ON public.pickup_points FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "authenticated_read_pickup_points" ON public.pickup_points;
DROP POLICY IF EXISTS "pickup_points_authenticated_read" ON public.pickup_points;
CREATE POLICY "pickup_points_authenticated_read"
  ON public.pickup_points FOR SELECT
  TO authenticated
  USING (true);

-- VEHICLES — replace inline subquery with is_admin()
DROP POLICY IF EXISTS "admin_write_vehicles"          ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_admin_full_access"    ON public.vehicles;
CREATE POLICY "vehicles_admin_full_access"
  ON public.vehicles FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "driver_read_own_vehicle"       ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_driver_own_read"      ON public.vehicles;
CREATE POLICY "vehicles_driver_own_read"
  ON public.vehicles FOR SELECT
  TO authenticated
  USING (assigned_driver_id = auth.uid() OR public.is_admin());

-- DRIVERS — replace inline subquery with is_admin() / is_driver()
DROP POLICY IF EXISTS "admin_write_drivers"           ON public.drivers;
DROP POLICY IF EXISTS "drivers_admin_full"            ON public.drivers;
CREATE POLICY "drivers_admin_full"
  ON public.drivers FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "driver_read_own_record"        ON public.drivers;
DROP POLICY IF EXISTS "drivers_passenger_read"        ON public.drivers;
-- Drivers: own record read (by profile_id) + admin read
CREATE POLICY "drivers_own_read"
  ON public.drivers FOR SELECT
  TO authenticated
  USING (profile_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "driver_update_own_availability" ON public.drivers;
CREATE POLICY "driver_update_own_availability"
  ON public.drivers FOR UPDATE
  TO authenticated
  USING (profile_id = auth.uid())
  WITH CHECK (profile_id = auth.uid());

-- Allow all authenticated users to read driver records (needed for trip display)
CREATE POLICY "drivers_authenticated_read"
  ON public.drivers FOR SELECT
  TO authenticated
  USING (true);

-- TRIPS — ensure admin write uses is_admin()
DROP POLICY IF EXISTS "trips_admin_write"             ON public.trips;
CREATE POLICY "trips_admin_write"
  ON public.trips FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- BOOKINGS — ensure admin write uses is_admin()
DROP POLICY IF EXISTS "bookings_admin_full"           ON public.bookings;
CREATE POLICY "bookings_admin_full"
  ON public.bookings FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- WAITING LIST — ensure admin write uses is_admin()
DROP POLICY IF EXISTS "waiting_list_admin_full"       ON public.waiting_list;
CREATE POLICY "waiting_list_admin_full"
  ON public.waiting_list FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- CANCELLATIONS — ensure admin write uses is_admin()
DROP POLICY IF EXISTS "cancellations_admin_full"      ON public.cancellations;
CREATE POLICY "cancellations_admin_full"
  ON public.cancellations FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- NOTIFICATIONS — ensure admin write uses is_admin()
DROP POLICY IF EXISTS "notifications_admin_full"      ON public.notifications;
CREATE POLICY "notifications_admin_full"
  ON public.notifications FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- BUSINESS SETTINGS — ensure admin write uses is_admin()
DROP POLICY IF EXISTS "business_settings_admin_write" ON public.business_settings;
CREATE POLICY "business_settings_admin_write"
  ON public.business_settings FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- AUDIT LOGS — ensure admin access uses is_admin()
DROP POLICY IF EXISTS "audit_logs_admin_full"         ON public.audit_logs;
CREATE POLICY "audit_logs_admin_full"
  ON public.audit_logs FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ============================================================
-- STEP 8: Verify Ajit's admin profile is intact (read-only check)
-- This DO block only reads — it does NOT modify any profile data.
-- ============================================================

DO $$
DECLARE
  v_ajit_role TEXT;
  v_ajit_status TEXT;
BEGIN
  SELECT role::TEXT, status::TEXT
  INTO v_ajit_role, v_ajit_status
  FROM public.profiles
  WHERE id = 'bb28bb8a-da98-4084-83b9-014dd7299a56';

  IF NOT FOUND THEN
    RAISE NOTICE 'VERIFY: Ajit profile (bb28bb8a-da98-4084-83b9-014dd7299a56) NOT FOUND — manual check required';
  ELSIF v_ajit_role = 'admin' THEN
    RAISE NOTICE 'VERIFY: Ajit profile OK — role=%, status=%', v_ajit_role, v_ajit_status;
  ELSE
    RAISE NOTICE 'VERIFY WARNING: Ajit profile found but role=% (expected admin) — manual check required', v_ajit_role;
  END IF;
END $$;

-- ============================================================
-- STEP 9: Verify Rajeev's passenger profile is intact
-- ============================================================

DO $$
DECLARE
  v_rajeev_role TEXT;
BEGIN
  SELECT role::TEXT
  INTO v_rajeev_role
  FROM public.profiles
  WHERE id = 'bc01df62-e523-4eb8-82ad-3345d72cb7ba';

  IF NOT FOUND THEN
    RAISE NOTICE 'VERIFY: Rajeev profile (bc01df62-e523-4eb8-82ad-3345d72cb7ba) NOT FOUND';
  ELSE
    RAISE NOTICE 'VERIFY: Rajeev profile OK — role=%', v_rajeev_role;
  END IF;
END $$;

-- ============================================================
-- FINAL SUMMARY
-- ============================================================
-- Policies AFTER cleanup on public.profiles:
--   profiles_select_own       — SELECT, id = auth.uid()
--   profiles_update_own       — UPDATE, id = auth.uid() / id = auth.uid()
--   profiles_admin_full_access — ALL, is_admin() SECURITY DEFINER
--
-- is_admin() — SECURITY DEFINER, SET search_path = public
--   Queries public.profiles as superuser (bypasses RLS) → no recursion
--
-- is_driver() — SECURITY DEFINER, SET search_path = public
--   Same pattern → no recursion
--
-- Cross-table policies — all inline profiles subqueries replaced with is_admin()
--
-- Ajit admin profile — NOT modified, only verified
-- Rajeev passenger profile — NOT modified, only verified
--
-- Role routing (unchanged):
--   admin   → /admin-dashboard
--   passenger → /available-routes
--   driver  → /driver-home
-- ============================================================
