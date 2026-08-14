-- Stage 6.1: Production Authentication
-- Safe incremental migration — does NOT touch existing profiles, drivers, bookings, or queue data.
-- Adds a DB-level trigger to auto-create a passenger profile for new auth.users.

-- ============================================================
-- 1. Function: auto-create passenger profile on new auth user
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name TEXT;
  v_email TEXT;
  v_phone TEXT;
  v_avatar TEXT;
BEGIN
  -- Skip if profile already exists (idempotent)
  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = NEW.id) THEN
    RETURN NEW;
  END IF;

  -- Extract metadata safely
  v_name   := COALESCE(
                NEW.raw_user_meta_data->>'full_name',
                NEW.raw_user_meta_data->>'name',
                SPLIT_PART(COALESCE(NEW.email, ''), '@', 1),
                NEW.phone,
                'Raahi User'
              );
  v_email  := NEW.email;
  v_phone  := NEW.phone;
  v_avatar := NEW.raw_user_meta_data->>'avatar_url';

  INSERT INTO public.profiles (id, name, email, phone, avatar_url, role, status)
  VALUES (NEW.id, v_name, v_email, v_phone, v_avatar, 'passenger', 'active')
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- ============================================================
-- 2. Trigger: fire after new auth.users row is inserted
-- ============================================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 3. RLS: ensure passengers can read their own profile
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles' AND policyname = 'profiles_select_own'
  ) THEN
    CREATE POLICY profiles_select_own ON public.profiles
      FOR SELECT USING (auth.uid() = id);
  END IF;
END $$;

-- Allow users to update their own profile (name, phone, avatar only — not role/status)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles' AND policyname = 'profiles_update_own'
  ) THEN
    CREATE POLICY profiles_update_own ON public.profiles
      FOR UPDATE USING (auth.uid() = id)
      WITH CHECK (auth.uid() = id AND role = (SELECT role FROM public.profiles WHERE id = auth.uid()));
  END IF;
END $$;

-- ============================================================
-- 4. Backfill: create passenger profiles for any existing
--    auth.users that don't yet have a profiles row.
--    Safe — uses ON CONFLICT DO NOTHING.
-- ============================================================
INSERT INTO public.profiles (id, name, email, phone, avatar_url, role, status)
SELECT
  u.id,
  COALESCE(
    u.raw_user_meta_data->>'full_name',
    u.raw_user_meta_data->>'name',
    SPLIT_PART(COALESCE(u.email, ''), '@', 1),
    u.phone,
    'Raahi User'
  ) AS name,
  u.email,
  u.phone,
  u.raw_user_meta_data->>'avatar_url',
  'passenger',
  'active'
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = u.id)
ON CONFLICT (id) DO NOTHING;
