-- ============================================================
-- RAAHI STAGE 2 — COMPLETE DATABASE SCHEMA
-- Migration: 20260809012749_raahi_stage2_schema.sql
-- ============================================================

-- ============================================================
-- STEP 1: ENUM TYPES
-- ============================================================

DROP TYPE IF EXISTS public.user_role CASCADE;
CREATE TYPE public.user_role AS ENUM ('passenger', 'driver', 'admin');

DROP TYPE IF EXISTS public.user_status CASCADE;
CREATE TYPE public.user_status AS ENUM ('active', 'suspended', 'pending');

DROP TYPE IF EXISTS public.driver_verification_status CASCADE;
CREATE TYPE public.driver_verification_status AS ENUM ('pending', 'approved', 'rejected', 'suspended');

DROP TYPE IF EXISTS public.driver_availability_status CASCADE;
CREATE TYPE public.driver_availability_status AS ENUM ('offline', 'online', 'on_trip', 'paused');

DROP TYPE IF EXISTS public.vehicle_status CASCADE;
CREATE TYPE public.vehicle_status AS ENUM ('active', 'inactive', 'maintenance');

DROP TYPE IF EXISTS public.route_status CASCADE;
CREATE TYPE public.route_status AS ENUM ('active', 'inactive');

DROP TYPE IF EXISTS public.queue_status CASCADE;
CREATE TYPE public.queue_status AS ENUM ('waiting', 'active', 'paused', 'completed', 'cancelled');

DROP TYPE IF EXISTS public.trip_status CASCADE;
CREATE TYPE public.trip_status AS ENUM ('scheduled', 'boarding', 'in_progress', 'completed', 'cancelled');

DROP TYPE IF EXISTS public.booking_status CASCADE;
CREATE TYPE public.booking_status AS ENUM ('confirmed', 'cancelled', 'no_show', 'completed');

DROP TYPE IF EXISTS public.notification_type CASCADE;
CREATE TYPE public.notification_type AS ENUM ('booking', 'trip', 'system', 'payment', 'admin');

DROP TYPE IF EXISTS public.audit_action CASCADE;
CREATE TYPE public.audit_action AS ENUM (
  'fare_changed', 'cancellation_fee_changed', 'driver_assigned', 'driver_approved',
  'driver_suspended', 'driver_activated', 'booking_cancelled', 'booking_moved',
  'passenger_replaced', 'queue_override', 'settings_changed', 'user_suspended'
);

-- ============================================================
-- STEP 2: CORE TABLES (no foreign keys)
-- ============================================================

-- profiles (intermediary between auth.users and app data)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT '',
  phone TEXT,
  email TEXT,
  role public.user_role NOT NULL DEFAULT 'passenger'::public.user_role,
  avatar_url TEXT,
  status public.user_status NOT NULL DEFAULT 'active'::public.user_status,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- business_settings
CREATE TABLE IF NOT EXISTS public.business_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  value TEXT NOT NULL,
  description TEXT,
  updated_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- routes
CREATE TABLE IF NOT EXISTS public.routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_location TEXT NOT NULL,
  to_location TEXT NOT NULL,
  distance_km NUMERIC(6,2),
  estimated_duration_min INTEGER,
  status public.route_status NOT NULL DEFAULT 'active'::public.route_status,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- STEP 3: DEPENDENT TABLES
-- ============================================================

-- pickup_points
CREATE TABLE IF NOT EXISTS public.pickup_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id UUID NOT NULL REFERENCES public.routes(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  landmark TEXT,
  sequence_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- vehicles
CREATE TABLE IF NOT EXISTS public.vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_number TEXT NOT NULL UNIQUE,
  make TEXT NOT NULL,
  model TEXT NOT NULL,
  vehicle_type TEXT NOT NULL DEFAULT 'car',
  seating_capacity INTEGER NOT NULL DEFAULT 4,
  fuel_type TEXT NOT NULL DEFAULT 'petrol',
  color TEXT,
  assigned_driver_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  status public.vehicle_status NOT NULL DEFAULT 'active'::public.vehicle_status,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- drivers
CREATE TABLE IF NOT EXISTS public.drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  license_number TEXT,
  verification_status public.driver_verification_status NOT NULL DEFAULT 'pending'::public.driver_verification_status,
  availability_status public.driver_availability_status NOT NULL DEFAULT 'offline'::public.driver_availability_status,
  current_route_id UUID REFERENCES public.routes(id) ON DELETE SET NULL,
  current_vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
  verified_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- trips
CREATE TABLE IF NOT EXISTS public.trips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id UUID NOT NULL REFERENCES public.routes(id) ON DELETE RESTRICT,
  driver_id UUID REFERENCES public.drivers(id) ON DELETE SET NULL,
  vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
  total_seats INTEGER NOT NULL DEFAULT 4,
  booked_seats INTEGER NOT NULL DEFAULT 0,
  status public.trip_status NOT NULL DEFAULT 'scheduled'::public.trip_status,
  scheduled_departure TIMESTAMPTZ,
  actual_departure TIMESTAMPTZ,
  actual_arrival TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT booked_seats_valid CHECK (booked_seats >= 0 AND booked_seats <= total_seats)
);

-- driver_queue
CREATE TABLE IF NOT EXISTS public.driver_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id UUID NOT NULL REFERENCES public.routes(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
  queue_position INTEGER NOT NULL DEFAULT 0,
  status public.queue_status NOT NULL DEFAULT 'waiting'::public.queue_status,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  activated_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- bookings
CREATE TABLE IF NOT EXISTS public.bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE RESTRICT,
  pickup_point_id UUID REFERENCES public.pickup_points(id) ON DELETE SET NULL,
  seats INTEGER NOT NULL DEFAULT 1,
  fare_per_seat NUMERIC(10,2) NOT NULL DEFAULT 0,
  total_fare NUMERIC(10,2) NOT NULL DEFAULT 0,
  status public.booking_status NOT NULL DEFAULT 'confirmed'::public.booking_status,
  booked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT seats_positive CHECK (seats > 0 AND seats <= 4)
);

-- waiting_list
CREATE TABLE IF NOT EXISTS public.waiting_list (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  route_id UUID NOT NULL REFERENCES public.routes(id) ON DELETE CASCADE,
  pickup_point_id UUID REFERENCES public.pickup_points(id) ON DELETE SET NULL,
  seats INTEGER NOT NULL DEFAULT 1,
  position INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- cancellations
CREATE TABLE IF NOT EXISTS public.cancellations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE RESTRICT,
  cancelled_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  reason TEXT,
  cancellation_fee NUMERIC(10,2) NOT NULL DEFAULT 0,
  fee_waived BOOLEAN NOT NULL DEFAULT FALSE,
  waived_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- notifications
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type public.notification_type NOT NULL DEFAULT 'system'::public.notification_type,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- audit_logs
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  performed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  action public.audit_action NOT NULL,
  target_table TEXT,
  target_id UUID,
  old_value JSONB,
  new_value JSONB,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- STEP 4: INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON public.profiles(phone);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_status ON public.profiles(status);

CREATE INDEX IF NOT EXISTS idx_drivers_profile_id ON public.drivers(profile_id);
CREATE INDEX IF NOT EXISTS idx_drivers_verification_status ON public.drivers(verification_status);
CREATE INDEX IF NOT EXISTS idx_drivers_availability_status ON public.drivers(availability_status);
CREATE INDEX IF NOT EXISTS idx_drivers_current_route_id ON public.drivers(current_route_id);

CREATE INDEX IF NOT EXISTS idx_vehicles_assigned_driver ON public.vehicles(assigned_driver_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_status ON public.vehicles(status);

CREATE INDEX IF NOT EXISTS idx_routes_status ON public.routes(status);

CREATE INDEX IF NOT EXISTS idx_pickup_points_route_id ON public.pickup_points(route_id);

CREATE INDEX IF NOT EXISTS idx_trips_route_id ON public.trips(route_id);
CREATE INDEX IF NOT EXISTS idx_trips_driver_id ON public.trips(driver_id);
CREATE INDEX IF NOT EXISTS idx_trips_status ON public.trips(status);

CREATE INDEX IF NOT EXISTS idx_driver_queue_route_id ON public.driver_queue(route_id);
CREATE INDEX IF NOT EXISTS idx_driver_queue_driver_id ON public.driver_queue(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_queue_status ON public.driver_queue(status);

CREATE INDEX IF NOT EXISTS idx_bookings_passenger_id ON public.bookings(passenger_id);
CREATE INDEX IF NOT EXISTS idx_bookings_trip_id ON public.bookings(trip_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON public.bookings(status);

CREATE INDEX IF NOT EXISTS idx_waiting_list_passenger_id ON public.waiting_list(passenger_id);
CREATE INDEX IF NOT EXISTS idx_waiting_list_route_id ON public.waiting_list(route_id);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);

CREATE INDEX IF NOT EXISTS idx_audit_logs_performed_by ON public.audit_logs(performed_by);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON public.audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at);

CREATE INDEX IF NOT EXISTS idx_business_settings_key ON public.business_settings(key);

-- ============================================================
-- STEP 5: FUNCTIONS (must be before RLS policies)
-- ============================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Auto-create profile when auth user is created
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.profiles (id, name, email, role, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(COALESCE(NEW.email, ''), '@', 1)),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'passenger')::public.user_role,
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', NULL)
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Role check helper (reads from auth metadata — safe for any table)
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(
    (SELECT role::TEXT FROM public.profiles WHERE id = auth.uid() LIMIT 1),
    'passenger'
  );
$$;

-- Admin check (safe for all tables including profiles)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'::public.user_role
  );
$$;

-- Driver check (safe for non-profiles tables)
CREATE OR REPLACE FUNCTION public.is_driver()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'driver'::public.user_role
  );
$$;

-- ============================================================
-- STEP 6: ENABLE ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pickup_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.waiting_list ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cancellations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- STEP 7: RLS POLICIES
-- ============================================================

-- PROFILES
DROP POLICY IF EXISTS "profiles_own_access" ON public.profiles;
CREATE POLICY "profiles_own_access"
ON public.profiles FOR ALL TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "profiles_admin_full_access" ON public.profiles;
CREATE POLICY "profiles_admin_full_access"
ON public.profiles FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- DRIVERS
DROP POLICY IF EXISTS "drivers_own_access" ON public.drivers;
CREATE POLICY "drivers_own_access"
ON public.drivers FOR ALL TO authenticated
USING (profile_id = auth.uid())
WITH CHECK (profile_id = auth.uid());

DROP POLICY IF EXISTS "drivers_admin_full_access" ON public.drivers;
CREATE POLICY "drivers_admin_full_access"
ON public.drivers FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "drivers_passenger_read" ON public.drivers;
CREATE POLICY "drivers_passenger_read"
ON public.drivers FOR SELECT TO authenticated
USING (true);

-- VEHICLES
DROP POLICY IF EXISTS "vehicles_driver_own_read" ON public.vehicles;
CREATE POLICY "vehicles_driver_own_read"
ON public.vehicles FOR SELECT TO authenticated
USING (assigned_driver_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "vehicles_admin_full_access" ON public.vehicles;
CREATE POLICY "vehicles_admin_full_access"
ON public.vehicles FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ROUTES (public read for authenticated users)
DROP POLICY IF EXISTS "routes_authenticated_read" ON public.routes;
CREATE POLICY "routes_authenticated_read"
ON public.routes FOR SELECT TO authenticated
USING (status = 'active'::public.route_status OR public.is_admin());

DROP POLICY IF EXISTS "routes_admin_write" ON public.routes;
CREATE POLICY "routes_admin_write"
ON public.routes FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- PICKUP POINTS (public read for authenticated users)
DROP POLICY IF EXISTS "pickup_points_authenticated_read" ON public.pickup_points;
CREATE POLICY "pickup_points_authenticated_read"
ON public.pickup_points FOR SELECT TO authenticated
USING (is_active = true OR public.is_admin());

DROP POLICY IF EXISTS "pickup_points_admin_write" ON public.pickup_points;
CREATE POLICY "pickup_points_admin_write"
ON public.pickup_points FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- DRIVER QUEUE
DROP POLICY IF EXISTS "driver_queue_driver_own" ON public.driver_queue;
CREATE POLICY "driver_queue_driver_own"
ON public.driver_queue FOR ALL TO authenticated
USING (driver_id IN (SELECT id FROM public.drivers WHERE profile_id = auth.uid()))
WITH CHECK (driver_id IN (SELECT id FROM public.drivers WHERE profile_id = auth.uid()));

DROP POLICY IF EXISTS "driver_queue_admin_full" ON public.driver_queue;
CREATE POLICY "driver_queue_admin_full"
ON public.driver_queue FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "driver_queue_authenticated_read" ON public.driver_queue;
CREATE POLICY "driver_queue_authenticated_read"
ON public.driver_queue FOR SELECT TO authenticated
USING (true);

-- TRIPS
DROP POLICY IF EXISTS "trips_authenticated_read" ON public.trips;
CREATE POLICY "trips_authenticated_read"
ON public.trips FOR SELECT TO authenticated
USING (true);

DROP POLICY IF EXISTS "trips_admin_write" ON public.trips;
CREATE POLICY "trips_admin_write"
ON public.trips FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "trips_driver_own" ON public.trips;
CREATE POLICY "trips_driver_own"
ON public.trips FOR SELECT TO authenticated
USING (driver_id IN (SELECT id FROM public.drivers WHERE profile_id = auth.uid()));

-- BOOKINGS
DROP POLICY IF EXISTS "bookings_passenger_own" ON public.bookings;
CREATE POLICY "bookings_passenger_own"
ON public.bookings FOR SELECT TO authenticated
USING (passenger_id = auth.uid());

DROP POLICY IF EXISTS "bookings_passenger_create" ON public.bookings;
CREATE POLICY "bookings_passenger_create"
ON public.bookings FOR INSERT TO authenticated
WITH CHECK (passenger_id = auth.uid());

DROP POLICY IF EXISTS "bookings_admin_full" ON public.bookings;
CREATE POLICY "bookings_admin_full"
ON public.bookings FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "bookings_driver_trip_read" ON public.bookings;
CREATE POLICY "bookings_driver_trip_read"
ON public.bookings FOR SELECT TO authenticated
USING (
  trip_id IN (
    SELECT t.id FROM public.trips t
    JOIN public.drivers d ON t.driver_id = d.id
    WHERE d.profile_id = auth.uid()
  )
);

-- WAITING LIST
DROP POLICY IF EXISTS "waiting_list_passenger_own" ON public.waiting_list;
CREATE POLICY "waiting_list_passenger_own"
ON public.waiting_list FOR ALL TO authenticated
USING (passenger_id = auth.uid())
WITH CHECK (passenger_id = auth.uid());

DROP POLICY IF EXISTS "waiting_list_admin_full" ON public.waiting_list;
CREATE POLICY "waiting_list_admin_full"
ON public.waiting_list FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- CANCELLATIONS
DROP POLICY IF EXISTS "cancellations_passenger_own" ON public.cancellations;
CREATE POLICY "cancellations_passenger_own"
ON public.cancellations FOR SELECT TO authenticated
USING (cancelled_by = auth.uid());

DROP POLICY IF EXISTS "cancellations_admin_full" ON public.cancellations;
CREATE POLICY "cancellations_admin_full"
ON public.cancellations FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- NOTIFICATIONS
DROP POLICY IF EXISTS "notifications_own_access" ON public.notifications;
CREATE POLICY "notifications_own_access"
ON public.notifications FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "notifications_admin_full" ON public.notifications;
CREATE POLICY "notifications_admin_full"
ON public.notifications FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- BUSINESS SETTINGS (read for all authenticated, write for admin only)
DROP POLICY IF EXISTS "business_settings_authenticated_read" ON public.business_settings;
CREATE POLICY "business_settings_authenticated_read"
ON public.business_settings FOR SELECT TO authenticated
USING (true);

DROP POLICY IF EXISTS "business_settings_admin_write" ON public.business_settings;
CREATE POLICY "business_settings_admin_write"
ON public.business_settings FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- AUDIT LOGS (admin only)
DROP POLICY IF EXISTS "audit_logs_admin_full" ON public.audit_logs;
CREATE POLICY "audit_logs_admin_full"
ON public.audit_logs FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ============================================================
-- STEP 8: TRIGGERS
-- ============================================================

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS profiles_updated_at ON public.profiles;
CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS drivers_updated_at ON public.drivers;
CREATE TRIGGER drivers_updated_at
  BEFORE UPDATE ON public.drivers
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS vehicles_updated_at ON public.vehicles;
CREATE TRIGGER vehicles_updated_at
  BEFORE UPDATE ON public.vehicles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS routes_updated_at ON public.routes;
CREATE TRIGGER routes_updated_at
  BEFORE UPDATE ON public.routes
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trips_updated_at ON public.trips;
CREATE TRIGGER trips_updated_at
  BEFORE UPDATE ON public.trips
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS bookings_updated_at ON public.bookings;
CREATE TRIGGER bookings_updated_at
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS driver_queue_updated_at ON public.driver_queue;
CREATE TRIGGER driver_queue_updated_at
  BEFORE UPDATE ON public.driver_queue
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS notifications_updated_at ON public.notifications;
CREATE TRIGGER notifications_updated_at
  BEFORE UPDATE ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS business_settings_updated_at ON public.business_settings;
CREATE TRIGGER business_settings_updated_at
  BEFORE UPDATE ON public.business_settings
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- STEP 9: SEED DATA
-- ============================================================

DO $$
DECLARE
  admin_uuid UUID := gen_random_uuid();
  route_gomoh_dhanbad UUID := gen_random_uuid();
  route_dhanbad_gomoh UUID := gen_random_uuid();
BEGIN

  -- ---- ADMIN USER ----
  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
    is_sso_user, is_anonymous, confirmation_token, confirmation_sent_at,
    recovery_token, recovery_sent_at, email_change_token_new, email_change,
    email_change_sent_at, email_change_token_current, email_change_confirm_status,
    reauthentication_token, reauthentication_sent_at, phone, phone_change,
    phone_change_token, phone_change_sent_at
  ) VALUES (
    admin_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    'admin@raahi.in', crypt('raahi@admin2026', gen_salt('bf', 10)), now(), now(), now(),
    jsonb_build_object('full_name', 'Raahi Admin', 'role', 'admin'),
    jsonb_build_object('provider', 'email', 'providers', ARRAY['email']::TEXT[]),
    false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null
  ) ON CONFLICT (id) DO NOTHING;

  -- Update admin profile role (trigger creates it as passenger by default if metadata not read)
  UPDATE public.profiles SET role = 'admin'::public.user_role, name = 'Raahi Admin'
  WHERE id = admin_uuid;

  -- ---- ROUTES ----
  INSERT INTO public.routes (id, from_location, to_location, distance_km, estimated_duration_min, status)
  VALUES
    (route_gomoh_dhanbad, 'Gomoh', 'Dhanbad', 28.5, 45, 'active'::public.route_status),
    (route_dhanbad_gomoh, 'Dhanbad', 'Gomoh', 28.5, 45, 'active'::public.route_status)
  ON CONFLICT (id) DO NOTHING;

  -- ---- PICKUP POINTS — Gomoh → Dhanbad ----
  INSERT INTO public.pickup_points (id, route_id, name, landmark, sequence_order, is_active)
  VALUES
    (gen_random_uuid(), route_gomoh_dhanbad, 'Gomoh Railway Station', 'Near platform 1 gate', 1, true),
    (gen_random_uuid(), route_gomoh_dhanbad, 'Sindri Road Crossing', 'Opposite petrol pump', 2, true),
    (gen_random_uuid(), route_gomoh_dhanbad, 'Katras Chowk', 'Near State Bank ATM', 3, true),
    (gen_random_uuid(), route_gomoh_dhanbad, 'Dhanbad Bus Stand', 'Main gate, platform 3', 4, true)
  ON CONFLICT (id) DO NOTHING;

  -- ---- PICKUP POINTS — Dhanbad → Gomoh ----
  INSERT INTO public.pickup_points (id, route_id, name, landmark, sequence_order, is_active)
  VALUES
    (gen_random_uuid(), route_dhanbad_gomoh, 'Dhanbad Bus Stand', 'Main gate, platform 3', 1, true),
    (gen_random_uuid(), route_dhanbad_gomoh, 'Hirapur Crossing', 'Near Hirapur market', 2, true),
    (gen_random_uuid(), route_dhanbad_gomoh, 'Katras Chowk', 'Near State Bank ATM', 3, true),
    (gen_random_uuid(), route_dhanbad_gomoh, 'Gomoh Railway Station', 'Near platform 1 gate', 4, true)
  ON CONFLICT (id) DO NOTHING;

  -- ---- BUSINESS SETTINGS ----
  INSERT INTO public.business_settings (key, value, description)
  VALUES
    ('default_fare_inr', '150', 'Default fare per seat in INR — editable by Admin'),
    ('cancellation_fee_inr', '20', 'Cancellation fee in INR'),
    ('no_show_fee_inr', '20', 'No-show fee in INR'),
    ('grace_period_minutes', '5', 'Grace period in minutes before no-show fee applies'),
    ('max_seats_per_booking', '4', 'Maximum seats a passenger can book in one booking'),
    ('luggage_policy', 'One small personal bag/backpack per passenger', 'Luggage policy displayed to passengers'),
    ('queue_auto_advance', 'true', 'Automatically advance queue when vehicle is full')
  ON CONFLICT (key) DO UPDATE SET
    value = EXCLUDED.value,
    description = EXCLUDED.description;

EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Seed data error: %', SQLERRM;
END $$;
