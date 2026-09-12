-- Raahi Learning V1.2 — Locations core tables

create table public.locations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  region text null,
  state_or_province text null,
  country_code text not null default 'IN',
  coverage_metadata jsonb not null default '{}'::jsonb,
  state text not null default 'interest_only',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint locations_name_nonblank check (char_length(btrim(name)) between 1 and 120),
  constraint locations_slug_format check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' and char_length(slug) between 1 and 120),
  constraint locations_country_code_format check (country_code ~ '^[A-Z]{2}$'),
  constraint locations_state_check check (state in ('interest_only','preparing','live','paused','retired'))
);

comment on table public.locations is 'Raahi Learning launch/service Location. Only live Locations support normal public discovery/community/Ads serving.';

create table public.location_staff_assignments (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id),
  account_id uuid not null references public.accounts(id),
  staff_type text not null,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  ended_at timestamptz null,
  constraint location_staff_type_check check (staff_type in ('local_manager')),
  constraint location_staff_status_check check (status in ('active','ended')),
  constraint location_staff_end_consistency check (
    (status = 'active' and ended_at is null)
    or (status = 'ended' and ended_at is not null)
  )
);

comment on table public.location_staff_assignments is 'Scoped staff authority. Local Manager authority is always tied to active Location assignments.';

create unique index location_staff_one_active_role_idx
  on public.location_staff_assignments (location_id, account_id, staff_type)
  where status = 'active';

create index location_staff_account_scope_idx
  on public.location_staff_assignments (account_id, location_id)
  where status = 'active';

create index location_staff_location_scope_idx
  on public.location_staff_assignments (location_id, staff_type)
  where status = 'active';

create trigger locations_set_updated_at
before update on public.locations
for each row execute function app_private.set_updated_at();