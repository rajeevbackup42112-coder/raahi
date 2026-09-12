-- Raahi Learning V1.2 — Identity integrity/indexes

create unique index account_learner_access_one_active_self_per_learner
  on public.account_learner_access (learner_id)
  where status = 'active' and access_type = 'self';

create unique index account_learner_access_one_active_manager_per_learner
  on public.account_learner_access (learner_id)
  where status = 'active' and access_type = 'manage';

create unique index account_learner_access_no_duplicate_active_tuple
  on public.account_learner_access (account_id, learner_id, access_type)
  where status = 'active';

create unique index account_capabilities_one_active_code_per_account
  on public.account_capabilities (account_id, capability_code)
  where status = 'active';

create index account_learner_access_account_status_idx
  on public.account_learner_access (account_id, status, learner_id);

create index account_learner_access_learner_status_idx
  on public.account_learner_access (learner_id, status, access_type, account_id);

create index account_capabilities_account_status_idx
  on public.account_capabilities (account_id, status, capability_code);

create index learners_created_by_account_idx
  on public.learners (created_by_account_id);

create trigger accounts_set_updated_at
before update on public.accounts
for each row execute function app_private.set_updated_at();

create trigger learners_set_updated_at
before update on public.learners
for each row execute function app_private.set_updated_at();
