-- Raahi Learning V1.2 — Organization FK performance follow-up
create index organizations_created_by_account_idx
  on public.organizations (created_by_account_id);
