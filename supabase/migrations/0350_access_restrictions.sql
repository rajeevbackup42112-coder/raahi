-- Raahi Learning V1.2 — Scoped access restrictions

create table public.access_restrictions (
  id uuid primary key default gen_random_uuid(),
  account_id uuid null references public.accounts(id),
  organization_id uuid null references public.organizations(id),
  restriction_scope text not null,
  location_id uuid null references public.locations(id),
  state text not null default 'active',
  reason_code text not null,
  details text null,
  starts_at timestamptz not null default now(),
  ends_at timestamptz null,
  applied_by_account_id uuid null references public.accounts(id),
  lifted_by_account_id uuid null references public.accounts(id),
  lifted_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint access_restrictions_subject_xor check ((account_id is not null)::int + (organization_id is not null)::int = 1),
  constraint access_restrictions_scope_check check (restriction_scope in ('public_discovery','new_enquiries','messaging','class_access','community','ads')),
  constraint access_restrictions_state_check check (state in ('active','lifted','expired')),
  constraint access_restrictions_reason_nonblank check (char_length(btrim(reason_code)) between 1 and 120),
  constraint access_restrictions_details_length check (details is null or char_length(details) <= 4000),
  constraint access_restrictions_end_after_start check (ends_at is null or ends_at > starts_at),
  constraint access_restrictions_lift_consistency check (
    (state='lifted' and lifted_at is not null and lifted_by_account_id is not null)
    or (state in ('active','expired') and lifted_at is null and lifted_by_account_id is null)
  )
);

create unique index access_restrictions_active_account_scope_idx
  on public.access_restrictions(account_id,restriction_scope,coalesce(location_id,'00000000-0000-0000-0000-000000000000'::uuid))
  where state='active' and account_id is not null;
create unique index access_restrictions_active_org_scope_idx
  on public.access_restrictions(organization_id,restriction_scope,coalesce(location_id,'00000000-0000-0000-0000-000000000000'::uuid))
  where state='active' and organization_id is not null;
create index access_restrictions_account_history_idx on public.access_restrictions(account_id,created_at desc) where account_id is not null;
create index access_restrictions_org_history_idx on public.access_restrictions(organization_id,created_at desc) where organization_id is not null;
create index access_restrictions_location_active_idx on public.access_restrictions(location_id,restriction_scope) where state='active' and location_id is not null;
create index access_restrictions_expiry_idx on public.access_restrictions(ends_at) where state='active' and ends_at is not null;
create index access_restrictions_applied_by_idx on public.access_restrictions(applied_by_account_id) where applied_by_account_id is not null;
create index access_restrictions_lifted_by_idx on public.access_restrictions(lifted_by_account_id) where lifted_by_account_id is not null;

create trigger access_restrictions_set_updated_at before update on public.access_restrictions
for each row execute function app_private.set_updated_at();
