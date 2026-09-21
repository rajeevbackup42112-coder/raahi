-- Raahi Learning V1.4C — explicit authenticated-browser deny for the private
-- Founding Supply assistance ledger. Canonical SECURITY DEFINER RPCs remain the
-- only browser path.

create policy assisted_teacher_onboarding_deny_authenticated
on public.assisted_teacher_onboarding_requests
for all
to authenticated
using (false)
with check (false);
