-- Raahi Learning V1.3 — deferred anonymous location RPC ACL hardening.
--
-- Anonymous marketplace browsing is deferred in V1.3. The public wrapper
-- list_public_locations() and its private SECURITY DEFINER helper had anon
-- EXECUTE grants, but anon intentionally has no USAGE on app_private, so the
-- wrapper could not successfully execute anyway.
--
-- Remove the unusable anonymous RPC grants. Authenticated behavior is
-- unchanged. This does not change table RLS or the public locations reference
-- table policy.

revoke execute on function public.list_public_locations() from anon;
revoke execute on function app_private.read_public_locations() from anon;
