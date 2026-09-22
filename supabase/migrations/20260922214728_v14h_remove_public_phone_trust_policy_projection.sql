-- Raahi Learning V1.4H security follow-up.
-- The browser does not need a public phone-trust policy RPC. The live security
-- advisor correctly flags that projection as an exposed SECURITY DEFINER function.
-- Keep the enforcement helpers private and remove the public convenience RPC.

drop function if exists public.get_phone_trust_policy();
