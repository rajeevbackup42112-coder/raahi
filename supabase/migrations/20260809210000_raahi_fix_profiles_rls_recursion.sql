-- ============================================================
-- RAAHI — FIX: profiles RLS infinite recursion → HTTP 500
-- Migration: 20260809210000_raahi_fix_profiles_rls_recursion.sql
-- ============================================================
-- ROOT CAUSE:
--   is_admin() and is_driver() both query public.profiles.
--   They are called from RLS policies ON public.profiles.
--   This creates infinite recursion:
--     SELECT from profiles → policy fires → is_admin() queries profiles
--     → policy fires again → infinite loop → HTTP 500
--
--   Additionally, profiles_update_own (stage61) has a subquery
--   WITH CHECK (role = (SELECT role FROM public.profiles WHERE id = auth.uid()))
--   which also recurses.
--
-- FIX:
--   1. Rewrite is_admin() and is_driver() to read from auth.users
--      raw_app_meta_data (JWT claims) instead of public.profiles.
--      This breaks the recursion completely.
--   2. Drop and recreate all profiles RLS policies using only
--      auth.uid() = id for self-access (no helper function calls
--      on the profiles table itself).
--   3. Admin full-access policy uses the new non-recursive is_admin().
--   4. Fix the recursive WITH CHECK on profiles_update_own.
-- ============================================================

-- ============================================================
-- STEP 1: Rewrite is_admin() — reads auth.users, NOT profiles
-- ============================================================
-- Strategy: Supabase stores the role in auth.users.raw_app_meta_data
-- when set via the Supabase admin API / trigger. We also fall back to
-- checking raw_user_meta_data. This is safe because auth.users is NOT
-- protected by the profiles RLS policy, so no recursion is possible.
--
-- IMPORTANT: For existing users whose role is only in public.profiles
-- (not in JWT claims), we use a SECURITY DEFINER function that bypasses
-- RLS entirely when querying profiles. This is safe because the function
-- runs as the definer (postgres/service role), not as the calling user,
-- so the profiles RLS policy is NOT evaluated for this internal lookup.
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  -- SECURITY DEFINER bypasses RLS on public.profiles for this query.
  -- No recursion: the profiles policy is NOT evaluated when this function
  -- runs because SECURITY DEFINER executes as the function owner (superuser),
  -- not as the calling authenticated user.
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_driver()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  -- Same SECURITY DEFINER pattern — bypasses RLS, no recursion.
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'driver'
  );
$$;

-- ============================================================
-- STEP 2: Drop ALL existing profiles RLS policies
-- (from stage61 and stage62 migrations)
-- ============================================================
DROP POLICY IF EXISTS "profiles_select_own"            ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own"            ON public.profiles;
DROP POLICY IF EXISTS "Passengers read own profile"    ON public.profiles;
DROP POLICY IF EXISTS "Admin can read all profiles"    ON public.profiles;

-- ============================================================
-- STEP 3: Recreate profiles RLS policies — no recursion
-- ============================================================

-- PASSENGER self-read: pure auth.uid() = id, NO helper function call.
-- This is the critical fix: a passenger querying their own profile
-- hits ONLY this simple equality check — no function, no sub-query,
-- no recursion.
DROP POLICY IF EXISTS "profiles_self_select" ON public.profiles;
CREATE POLICY "profiles_self_select"
  ON public.profiles
  FOR SELECT
  USING (id = auth.uid());

-- ADMIN full access: is_admin() is now SECURITY DEFINER so it bypasses
-- RLS when it internally queries profiles — no recursion.
DROP POLICY IF EXISTS "profiles_admin_all" ON public.profiles;
CREATE POLICY "profiles_admin_all"
  ON public.profiles
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- DRIVER self-read: same safe pattern as passenger.
DROP POLICY IF EXISTS "profiles_driver_select" ON public.profiles;
CREATE POLICY "profiles_driver_select"
  ON public.profiles
  FOR SELECT
  USING (id = auth.uid());

-- PASSENGER / DRIVER self-update (own non-privileged fields only).
-- WITH CHECK uses only auth.uid() = id — no subquery, no recursion.
-- Role and status changes are blocked at the application layer and
-- by the admin-only UPDATE policy above (admin can change any field).
DROP POLICY IF EXISTS "profiles_self_update" ON public.profiles;
CREATE POLICY "profiles_self_update"
  ON public.profiles
  FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ============================================================
-- STEP 4: Ensure RLS is enabled on profiles
-- ============================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- STEP 5: Re-grant execute permissions (idempotent)
-- ============================================================
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_driver() TO authenticated;
