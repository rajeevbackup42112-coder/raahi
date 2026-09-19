-- Explicit browser deny policy for the server-only MessageCentral challenge ledger.
-- Table grants are already revoked from anon/authenticated; this policy also
-- documents the intended RLS posture and keeps the security advisor unambiguous.

create policy phone_trust_challenges_deny_browser
on public.phone_trust_challenges
as restrictive
for all
to anon, authenticated
using (false)
with check (false);
