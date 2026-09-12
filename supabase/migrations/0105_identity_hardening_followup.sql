-- Raahi Learning V1.2 — Foundation + Identity hardening follow-up
-- Forward-fix migration after first shared/dev application.

create index account_capabilities_granted_by_account_idx
  on public.account_capabilities (granted_by_account_id)
  where granted_by_account_id is not null;

-- These tables are intentionally not client-readable. Explicit deny policies
-- document that intent and keep security advisors quiet while RLS remains
-- enabled/forced and table grants remain absent for anon/authenticated.
create policy audit_log_deny_client
on public.audit_log
for all
to authenticated
using (false)
with check (false);

create policy idempotency_keys_deny_client
on public.idempotency_keys
for all
to authenticated
using (false)
with check (false);
