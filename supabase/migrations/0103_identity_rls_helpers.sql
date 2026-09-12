-- Raahi Learning V1.2 — Identity authorization helpers + RLS

create or replace function app_private.current_account_id()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_auth_uid uuid := auth.uid();
  v_account_id uuid;
begin
  if v_auth_uid is null then
    return null;
  end if;

  select a.id into v_account_id
  from public.accounts a
  where a.auth_user_id = v_auth_uid;

  return v_account_id;
end;
$$;

create or replace function app_private.current_account_status()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select a.lifecycle_status
  from public.accounts a
  where a.id = app_private.current_account_id();
$$;

create or replace function app_private.require_current_account(p_require_active boolean default false)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_account_id uuid;
  v_status text;
begin
  v_account_id := app_private.current_account_id();
  if v_account_id is null then
    raise exception 'ACCOUNT_REQUIRED';
  end if;

  select lifecycle_status into v_status
  from public.accounts
  where id = v_account_id;

  if p_require_active and v_status <> 'active' then
    raise exception 'ACCOUNT_NOT_ACTIVE';
  end if;

  return v_account_id;
end;
$$;

create or replace function app_private.has_account_capability(p_capability_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.account_capabilities c
    join public.accounts a on a.id = c.account_id
    where c.account_id = app_private.current_account_id()
      and c.capability_code = p_capability_code
      and c.status = 'active'
      and a.lifecycle_status = 'active'
  );
$$;

create or replace function app_private.has_learner_self_access(p_learner_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.account_learner_access ala
    join public.accounts a on a.id = ala.account_id
    where ala.learner_id = p_learner_id
      and ala.account_id = app_private.current_account_id()
      and ala.access_type = 'self'
      and ala.status = 'active'
      and a.lifecycle_status <> 'closed'
  );
$$;

create or replace function app_private.can_manage_learner(p_learner_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.account_learner_access ala
    join public.accounts a on a.id = ala.account_id
    where ala.learner_id = p_learner_id
      and ala.account_id = app_private.current_account_id()
      and ala.access_type = 'manage'
      and ala.status = 'active'
      and a.lifecycle_status <> 'closed'
  );
$$;

create or replace function app_private.can_access_learner(p_learner_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.account_learner_access ala
    join public.accounts a on a.id = ala.account_id
    where ala.learner_id = p_learner_id
      and ala.account_id = app_private.current_account_id()
      and ala.status = 'active'
      and a.lifecycle_status <> 'closed'
  );
$$;

create or replace function app_private.can_make_learning_decision(p_learner_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.current_account_id();
  v_manager uuid;
  v_actor_status text;
begin
  if v_actor is null then
    return false;
  end if;

  select lifecycle_status into v_actor_status
  from public.accounts
  where id = v_actor;

  if v_actor_status <> 'active' then
    return false;
  end if;

  if app_private.has_account_capability('platform_admin') then
    return true;
  end if;

  select ala.account_id into v_manager
  from public.account_learner_access ala
  where ala.learner_id = p_learner_id
    and ala.access_type = 'manage'
    and ala.status = 'active'
  limit 1;

  if v_manager is not null then
    return v_manager = v_actor;
  end if;

  return exists (
    select 1
    from public.account_learner_access ala
    where ala.learner_id = p_learner_id
      and ala.account_id = v_actor
      and ala.access_type = 'self'
      and ala.status = 'active'
  );
end;
$$;

-- Every application table in the exposed public schema is protected by RLS.
alter table public.accounts enable row level security;
alter table public.accounts force row level security;
alter table public.learners enable row level security;
alter table public.learners force row level security;
alter table public.account_learner_access enable row level security;
alter table public.account_learner_access force row level security;
alter table public.account_capabilities enable row level security;
alter table public.account_capabilities force row level security;
alter table public.audit_log enable row level security;
alter table public.audit_log force row level security;
alter table public.idempotency_keys enable row level security;
alter table public.idempotency_keys force row level security;

create policy accounts_select_own
on public.accounts for select
to authenticated
using (auth_user_id = (select auth.uid()));

create policy learners_select_authorized
on public.learners for select
to authenticated
using (
  (select app_private.can_access_learner(id))
  or (select app_private.has_account_capability('platform_admin'))
);

create policy account_learner_access_select_authorized
on public.account_learner_access for select
to authenticated
using (
  (select app_private.can_access_learner(learner_id))
  or (select app_private.has_account_capability('platform_admin'))
);

create policy account_capabilities_select_authorized
on public.account_capabilities for select
to authenticated
using (
  account_id = (select app_private.current_account_id())
  or (select app_private.has_account_capability('platform_admin'))
);

-- Start from zero table privileges, then expose only safe reads.
revoke all on table public.accounts from public, anon, authenticated, service_role;
revoke all on table public.learners from public, anon, authenticated, service_role;
revoke all on table public.account_learner_access from public, anon, authenticated, service_role;
revoke all on table public.account_capabilities from public, anon, authenticated, service_role;
revoke all on table public.audit_log from public, anon, authenticated, service_role;
revoke all on table public.idempotency_keys from public, anon, authenticated, service_role;

grant select on table public.accounts to authenticated;
grant select on table public.learners to authenticated;
grant select on table public.account_learner_access to authenticated;
grant select on table public.account_capabilities to authenticated;

grant select, insert, update, delete on table public.accounts to service_role;
grant select, insert, update, delete on table public.learners to service_role;
grant select, insert, update, delete on table public.account_learner_access to service_role;
grant select, insert, update, delete on table public.account_capabilities to service_role;
grant select, insert, update, delete on table public.audit_log to service_role;
grant select, insert, update, delete on table public.idempotency_keys to service_role;

-- RLS helpers are callable by authenticated policies/queries, but the schema is
-- intentionally not an exposed Data API schema.
grant usage on schema app_private to authenticated;
grant execute on function app_private.current_account_id() to authenticated;
grant execute on function app_private.current_account_status() to authenticated;
grant execute on function app_private.has_account_capability(text) to authenticated;
grant execute on function app_private.has_learner_self_access(uuid) to authenticated;
grant execute on function app_private.can_manage_learner(uuid) to authenticated;
grant execute on function app_private.can_access_learner(uuid) to authenticated;
grant execute on function app_private.can_make_learning_decision(uuid) to authenticated;

revoke all on function app_private.require_current_account(boolean) from public, anon, authenticated, service_role;
