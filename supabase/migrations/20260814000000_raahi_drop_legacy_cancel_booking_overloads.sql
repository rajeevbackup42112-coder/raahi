-- Migration: Drop legacy cancel_booking overloads
-- Removes the two legacy overloads that cause PGRST203 ambiguity.
-- Preserves the canonical: public.cancel_booking(p_booking_id uuid)
--
-- PGRST203 root cause: PostgREST cannot choose between three overloads when
-- the frontend sends { "p_booking_id": "<uuid>" } (no p_reason, no p_passenger_id).
--
-- Overloads being dropped:
--   1. public.cancel_booking(uuid, text)          -- legacy with p_reason
--   2. public.cancel_booking(uuid, uuid, text)    -- older legacy with p_passenger_id
--
-- Overload being preserved:
--   public.cancel_booking(uuid)                   -- canonical, derives identity from auth.uid()

DROP FUNCTION IF EXISTS public.cancel_booking(uuid, text);
DROP FUNCTION IF EXISTS public.cancel_booking(uuid, uuid, text);

-- Verification: after this migration exactly ONE public.cancel_booking must remain.
-- Run manually to confirm:
--   SELECT proname, pg_get_function_identity_arguments(oid)
--   FROM pg_proc
--   WHERE proname = 'cancel_booking'
--     AND pronamespace = 'public'::regnamespace;
-- Expected: one row → cancel_booking(p_booking_id uuid)
