-- Raahi Learning V1.2 — Organizations + teacher discovery tables

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  organization_type text not null,
  name text not null,
  description text null,
  public_contact_text text null,
  venue_text text null,
  website_url text null,
  logo_type text not null default 'none',
  logo_ref text null,
  status text not null default 'active',
  created_by_account_id uuid not null references public.accounts(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  account_id uuid not null references public.accounts(id),
  status text not null default 'active',
  created_at timestamptz not null default now(),
  ended_at timestamptz null
);

create table public.organization_member_capabilities (
  organization_member_id uuid not null references public.organization_members(id),
  capability_code text not null,
  created_at timestamptz not null default now(),
  primary key (organization_member_id, capability_code)
);

create table public.teacher_profiles (
  account_id uuid primary key references public.accounts(id),
  headline text null,
  bio text null,
  experience_summary text null,
  visibility_status text not null default 'hidden',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.teaching_options (
  id uuid primary key default gen_random_uuid(),
  teacher_account_id uuid null references public.accounts(id),
  organization_id uuid null references public.organizations(id),
  title text not null,
  category text null,
  description text null,
  teaching_mode text not null,
  area_or_venue_text text null,
  fee_display_text text null,
  availability_status text not null default 'taking_new_learners',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.teaching_option_locations (
  teaching_option_id uuid not null references public.teaching_options(id),
  location_id uuid not null references public.locations(id),
  created_at timestamptz not null default now(),
  primary key (teaching_option_id, location_id)
);

create table public.saved_teacher_profiles (
  account_id uuid not null references public.accounts(id),
  teacher_account_id uuid not null references public.accounts(id),
  created_at timestamptz not null default now(),
  primary key (account_id, teacher_account_id)
);

create table public.saved_teaching_options (
  account_id uuid not null references public.accounts(id),
  teaching_option_id uuid not null references public.teaching_options(id),
  created_at timestamptz not null default now(),
  primary key (account_id, teaching_option_id)
);

create table public.saved_organizations (
  account_id uuid not null references public.accounts(id),
  organization_id uuid not null references public.organizations(id),
  created_at timestamptz not null default now(),
  primary key (account_id, organization_id)
);

alter table public.audit_log
  add column organization_id uuid null references public.organizations(id);

create index audit_log_organization_time_idx
  on public.audit_log (organization_id, created_at desc)
  where organization_id is not null;

create trigger organizations_set_updated_at
before update on public.organizations
for each row execute function app_private.set_updated_at();

create trigger teacher_profiles_set_updated_at
before update on public.teacher_profiles
for each row execute function app_private.set_updated_at();

create trigger teaching_options_set_updated_at
before update on public.teaching_options
for each row execute function app_private.set_updated_at();
