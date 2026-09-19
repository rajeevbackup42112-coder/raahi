-- Raahi Learning V1.3
-- Preserve the established security invariant: no public SECURITY DEFINER RPCs.
-- The pilot trust policy is server-owned and does not require a browser-readable RPC.

drop function if exists public.get_phone_trust_policy();
