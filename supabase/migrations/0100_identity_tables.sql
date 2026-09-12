-- Raahi Learning V1.2 — Foundation + Identity tables

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  display_name text not null,
  avatar_type text not null default 'none',
  avatar_ref text null,
  lifecycle_status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint accounts_display_name_nonblank check (char_length(btrim(display_name)) between 1 and 120),
  constraint accounts_avatar_type_check check (avatar_type in ('builtin','upload','none')),
  constraint accounts_avatar_ref_check check (
    (avatar_type = 'none' and avatar_ref is null)
    or (avatar_type in ('builtin','upload') and avatar_ref is not null)
  ),
  constraint accounts_lifecycle_status_check check (lifecycle_status in ('active','paused','closed'))
);

create table public.learners (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  avatar_type text not null default 'none',
  avatar_ref text null,
  created_by_account_id uuid not null references public.accounts(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint learners_display_name_nonblank check (char_length(btrim(display_name)) between 1 and 120),
  constraint learners_avatar_type_check check (avatar_type in ('builtin','upload','none')),
  constraint learners_avatar_ref_check check (
    (avatar_type = 'none' and avatar_ref is null)
    or (avatar_type in ('builtin','upload') and avatar_ref is not null)
  )
);

create table public.account_learner_access (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id),
  learner_id uuid not null references public.learners(id),
  access_type text not null,
  status text not null default 'active',
  granted_at timestamptz not null default now(),
  ended_at timestamptz null,
  created_at timestamptz not null default now(),
  constraint account_learner_access_type_check check (access_type in ('self','manage')),
  constraint account_learner_access_status_check check (status in ('active','ended')),
  constraint account_learner_access_end_consistency check (
    (status = 'active' and ended_at is null)
    or (status = 'ended' and ended_at is not null)
  )
);

create table public.account_capabilities (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id),
  capability_code text not null,
  status text not null default 'active',
  granted_by_account_id uuid null references public.accounts(id),
  granted_at timestamptz not null default now(),
  revoked_at timestamptz null,
  created_at timestamptz not null default now(),
  constraint account_capabilities_code_check check (
    capability_code in ('teach','community_post','platform_admin','safety_reviewer','verifier','ads_commercial')
  ),
  constraint account_capabilities_status_check check (status in ('active','revoked')),
  constraint account_capabilities_revoke_consistency check (
    (status = 'active' and revoked_at is null)
    or (status = 'revoked' and revoked_at is not null)
  )
);

comment on table public.accounts is 'Authenticated human/application account. Account is not the Learner.';
comment on table public.learners is 'Person whose learning history belongs to them, with or without their own login.';
comment on table public.account_learner_access is 'Explicit self/manage authority relationship between an Account and a Learner.';
comment on table public.account_capabilities is 'Small unscoped capability grants; Organization/Location scope lives in later relationship tables.';
