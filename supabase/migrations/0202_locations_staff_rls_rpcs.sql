-- Raahi Learning V1.2 — Location scope, RLS and canonical commands

alter table public.audit_log
  add column location_id uuid null references public.locations(id);

create index audit_log_location_time_idx
  on public.audit_log (location_id, created_at desc)
  where location_id is not null;

create or replace function app_private.has_location_staff_scope(
  p_location_id uuid,
  p_staff_type text default 'local_manager'
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.location_staff_assignments lsa
    join public.accounts a on a.id = lsa.account_id
    where lsa.location_id = p_location_id
      and lsa.account_id = app_private.current_account_id()
      and lsa.staff_type = p_staff_type
      and lsa.status = 'active'
      and a.lifecycle_status = 'active'
  );
$$;

create or replace function app_private.write_location_audit(
  p_actor_account_id uuid,
  p_action_type text,
  p_location_id uuid,
  p_target_type text,
  p_target_id uuid default null,
  p_reason text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  insert into public.audit_log (
    actor_kind, actor_account_id, action_type, target_type, target_id,
    location_id, reason, metadata
  ) values (
    'account', p_actor_account_id, p_action_type, p_target_type, p_target_id,
    p_location_id, p_reason, coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function app_private.cmd_create_location(
  p_name text,
  p_slug text,
  p_region text,
  p_state_or_province text,
  p_country_code text,
  p_coverage_metadata jsonb,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.require_current_account(true);
  v_gate jsonb;
  v_fingerprint text;
  v_location_id uuid;
  v_result jsonb;
  v_slug text := lower(btrim(p_slug));
  v_country text := upper(coalesce(nullif(btrim(p_country_code), ''), 'IN'));
begin
  if not app_private.has_account_capability('platform_admin') then
    raise exception 'NOT_AUTHORIZED';
  end if;

  v_fingerprint := app_private.request_fingerprint(jsonb_build_object(
    'name', p_name, 'slug', v_slug, 'region', p_region,
    'state_or_province', p_state_or_province, 'country_code', v_country,
    'coverage_metadata', coalesce(p_coverage_metadata, '{}'::jsonb)
  ));
  v_gate := app_private.begin_human_idempotent_command(
    v_actor, 'create_location', p_idempotency_key, v_fingerprint
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  if p_name is null or char_length(btrim(p_name)) not between 1 and 120 then
    raise exception 'INVALID_LOCATION_NAME';
  end if;
  if v_slug is null or v_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' or char_length(v_slug) > 120 then
    raise exception 'INVALID_LOCATION_SLUG';
  end if;
  if v_country !~ '^[A-Z]{2}$' then
    raise exception 'INVALID_COUNTRY_CODE';
  end if;

  insert into public.locations (
    name, slug, region, state_or_province, country_code, coverage_metadata
  ) values (
    btrim(p_name), v_slug, nullif(btrim(p_region), ''),
    nullif(btrim(p_state_or_province), ''), v_country,
    coalesce(p_coverage_metadata, '{}'::jsonb)
  )
  returning id into v_location_id;

  perform app_private.write_location_audit(
    v_actor, 'location.create', v_location_id, 'location', v_location_id, null,
    jsonb_build_object('initial_state', 'interest_only')
  );

  v_result := jsonb_build_object(
    'location_id', v_location_id, 'state', 'interest_only', 'slug', v_slug
  );
  perform app_private.complete_human_idempotent_command(
    v_actor, 'create_location', p_idempotency_key, v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.cmd_set_location_state(
  p_location_id uuid,
  p_new_state text,
  p_reason text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.require_current_account(true);
  v_gate jsonb;
  v_fingerprint text;
  v_old_state text;
  v_result jsonb;
  v_allowed boolean := false;
begin
  if not app_private.has_account_capability('platform_admin') then
    raise exception 'NOT_AUTHORIZED';
  end if;
  if p_new_state not in ('interest_only','preparing','live','paused','retired') then
    raise exception 'INVALID_LOCATION_STATE';
  end if;

  v_fingerprint := app_private.request_fingerprint(jsonb_build_object(
    'location_id', p_location_id, 'new_state', p_new_state, 'reason', p_reason
  ));
  v_gate := app_private.begin_human_idempotent_command(
    v_actor, 'set_location_state', p_idempotency_key, v_fingerprint
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select state into v_old_state
  from public.locations
  where id = p_location_id
  for update;
  if not found then raise exception 'LOCATION_NOT_FOUND'; end if;

  if v_old_state = p_new_state then
    v_result := jsonb_build_object(
      'location_id', p_location_id, 'old_state', v_old_state,
      'new_state', p_new_state, 'already_state', true
    );
    perform app_private.complete_human_idempotent_command(
      v_actor, 'set_location_state', p_idempotency_key, v_result
    );
    return v_result;
  end if;

  v_allowed :=
    (v_old_state = 'interest_only' and p_new_state in ('preparing','retired'))
    or (v_old_state = 'preparing' and p_new_state in ('live','retired'))
    or (v_old_state = 'live' and p_new_state = 'paused')
    or (v_old_state = 'paused' and p_new_state in ('live','retired'));

  if not v_allowed then
    raise exception 'INVALID_LOCATION_TRANSITION:%->%', v_old_state, p_new_state;
  end if;

  update public.locations set state = p_new_state where id = p_location_id;

  perform app_private.write_location_audit(
    v_actor, 'location.state_change', p_location_id, 'location', p_location_id,
    nullif(btrim(p_reason), ''),
    jsonb_build_object('old_state', v_old_state, 'new_state', p_new_state)
  );

  v_result := jsonb_build_object(
    'location_id', p_location_id, 'old_state', v_old_state,
    'new_state', p_new_state, 'already_state', false
  );
  perform app_private.complete_human_idempotent_command(
    v_actor, 'set_location_state', p_idempotency_key, v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.cmd_assign_local_manager(
  p_location_id uuid,
  p_target_account_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.require_current_account(true);
  v_gate jsonb;
  v_fingerprint text;
  v_location_state text;
  v_target_status text;
  v_target_auth uuid;
  v_assignment_id uuid;
  v_result jsonb;
begin
  if not app_private.has_account_capability('platform_admin') then
    raise exception 'NOT_AUTHORIZED';
  end if;

  v_fingerprint := app_private.request_fingerprint(jsonb_build_object(
    'location_id', p_location_id, 'target_account_id', p_target_account_id,
    'staff_type', 'local_manager'
  ));
  v_gate := app_private.begin_human_idempotent_command(
    v_actor, 'assign_local_manager', p_idempotency_key, v_fingerprint
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select state into v_location_state
  from public.locations where id = p_location_id for update;
  if not found then raise exception 'LOCATION_NOT_FOUND'; end if;
  if v_location_state = 'retired' then raise exception 'LOCATION_RETIRED'; end if;

  select lifecycle_status, auth_user_id into v_target_status, v_target_auth
  from public.accounts where id = p_target_account_id for update;
  if not found or v_target_status <> 'active' or v_target_auth is null then
    raise exception 'TARGET_ACCOUNT_NOT_ELIGIBLE';
  end if;

  select id into v_assignment_id
  from public.location_staff_assignments
  where location_id = p_location_id
    and account_id = p_target_account_id
    and staff_type = 'local_manager'
    and status = 'active'
  limit 1;

  if v_assignment_id is not null then
    v_result := jsonb_build_object(
      'assignment_id', v_assignment_id, 'already_active', true
    );
    perform app_private.complete_human_idempotent_command(
      v_actor, 'assign_local_manager', p_idempotency_key, v_result
    );
    return v_result;
  end if;

  insert into public.location_staff_assignments (
    location_id, account_id, staff_type
  ) values (p_location_id, p_target_account_id, 'local_manager')
  returning id into v_assignment_id;

  perform app_private.write_location_audit(
    v_actor, 'location.local_manager_assign', p_location_id,
    'location_staff_assignment', v_assignment_id, null,
    jsonb_build_object('target_account_id', p_target_account_id)
  );

  v_result := jsonb_build_object(
    'assignment_id', v_assignment_id, 'already_active', false
  );
  perform app_private.complete_human_idempotent_command(
    v_actor, 'assign_local_manager', p_idempotency_key, v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.cmd_end_location_staff_assignment(
  p_assignment_id uuid,
  p_reason text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.require_current_account(true);
  v_gate jsonb;
  v_fingerprint text;
  v_location_id uuid;
  v_status text;
  v_result jsonb;
begin
  if not app_private.has_account_capability('platform_admin') then
    raise exception 'NOT_AUTHORIZED';
  end if;

  v_fingerprint := app_private.request_fingerprint(jsonb_build_object(
    'assignment_id', p_assignment_id, 'reason', p_reason
  ));
  v_gate := app_private.begin_human_idempotent_command(
    v_actor, 'end_location_staff_assignment', p_idempotency_key, v_fingerprint
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select location_id, status into v_location_id, v_status
  from public.location_staff_assignments
  where id = p_assignment_id
  for update;
  if not found then raise exception 'STAFF_ASSIGNMENT_NOT_FOUND'; end if;

  if v_status = 'ended' then
    v_result := jsonb_build_object('assignment_id', p_assignment_id, 'already_ended', true);
    perform app_private.complete_human_idempotent_command(
      v_actor, 'end_location_staff_assignment', p_idempotency_key, v_result
    );
    return v_result;
  end if;

  update public.location_staff_assignments
  set status = 'ended', ended_at = now()
  where id = p_assignment_id;

  perform app_private.write_location_audit(
    v_actor, 'location.staff_assignment_end', v_location_id,
    'location_staff_assignment', p_assignment_id, nullif(btrim(p_reason), ''), '{}'
  );

  v_result := jsonb_build_object('assignment_id', p_assignment_id, 'already_ended', false);
  perform app_private.complete_human_idempotent_command(
    v_actor, 'end_location_staff_assignment', p_idempotency_key, v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.cmd_set_selected_location(
  p_location_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.require_current_account(true);
  v_gate jsonb;
  v_fingerprint text;
  v_state text;
  v_name text;
  v_current uuid;
  v_result jsonb;
begin
  v_fingerprint := app_private.request_fingerprint(jsonb_build_object('location_id', p_location_id));
  v_gate := app_private.begin_human_idempotent_command(
    v_actor, 'set_selected_location', p_idempotency_key, v_fingerprint
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select state, name into v_state, v_name
  from public.locations where id = p_location_id;
  if not found then raise exception 'LOCATION_NOT_FOUND'; end if;
  if v_state = 'retired' then raise exception 'LOCATION_RETIRED'; end if;

  select selected_location_id into v_current
  from public.account_location_preferences
  where account_id = v_actor;

  if v_current is distinct from p_location_id then
    insert into public.account_location_preferences (account_id, selected_location_id)
    values (v_actor, p_location_id)
    on conflict (account_id) do update
      set selected_location_id = excluded.selected_location_id,
          updated_at = now();
  end if;

  v_result := jsonb_build_object(
    'location_id', p_location_id,
    'location_name', v_name,
    'location_state', v_state,
    'changed', v_current is distinct from p_location_id
  );
  perform app_private.complete_human_idempotent_command(
    v_actor, 'set_selected_location', p_idempotency_key, v_result
  );
  return v_result;
end;
$$;

-- Account closure blocker aggregation becomes extensible from this slice onward.
create or replace function app_private.account_closure_blockers(p_account_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with blockers as (
    select jsonb_build_object(
      'code', 'SOLE_MANAGER_RESPONSIBILITY',
      'learner_id', ala.learner_id
    ) as blocker
    from public.account_learner_access ala
    where ala.account_id = p_account_id
      and ala.access_type = 'manage'
      and ala.status = 'active'
      and not exists (
        select 1
        from public.account_learner_access self_access
        where self_access.learner_id = ala.learner_id
          and self_access.access_type = 'self'
          and self_access.status = 'active'
      )

    union all

    select jsonb_build_object(
      'code', 'ACTIVE_LOCAL_MANAGER_ASSIGNMENT',
      'location_id', lsa.location_id,
      'assignment_id', lsa.id
    )
    from public.location_staff_assignments lsa
    where lsa.account_id = p_account_id
      and lsa.status = 'active'
  )
  select coalesce(jsonb_agg(blocker), '[]'::jsonb) from blockers;
$$;

create or replace function app_private.cmd_request_account_closure(p_idempotency_key text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.require_current_account(false);
  v_gate jsonb;
  v_fingerprint text := app_private.request_fingerprint('{}'::jsonb);
  v_status text;
  v_blockers jsonb;
  v_result jsonb;
begin
  v_gate := app_private.begin_human_idempotent_command(
    v_actor, 'request_account_closure', p_idempotency_key, v_fingerprint
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select lifecycle_status into v_status
  from public.accounts where id = v_actor for update;

  if v_status = 'closed' then
    v_result := jsonb_build_object('closed', true, 'already_closed', true, 'blockers', '[]'::jsonb);
    perform app_private.complete_human_idempotent_command(
      v_actor, 'request_account_closure', p_idempotency_key, v_result
    );
    return v_result;
  end if;

  v_blockers := app_private.account_closure_blockers(v_actor);
  if jsonb_array_length(v_blockers) > 0 then
    v_result := jsonb_build_object('closed', false, 'already_closed', false, 'blockers', v_blockers);
    perform app_private.complete_human_idempotent_command(
      v_actor, 'request_account_closure', p_idempotency_key, v_result
    );
    return v_result;
  end if;

  update public.account_learner_access
  set status = 'ended', ended_at = now()
  where account_id = v_actor and status = 'active';

  update public.account_capabilities
  set status = 'revoked', revoked_at = now()
  where account_id = v_actor and status = 'active';

  update public.accounts set lifecycle_status = 'closed' where id = v_actor;

  perform app_private.write_audit(v_actor, 'account.close', 'account', v_actor);

  v_result := jsonb_build_object('closed', true, 'already_closed', false, 'blockers', '[]'::jsonb);
  perform app_private.complete_human_idempotent_command(
    v_actor, 'request_account_closure', p_idempotency_key, v_result
  );
  return v_result;
end;
$$;

-- RLS
alter table public.locations enable row level security;
alter table public.locations force row level security;
alter table public.location_staff_assignments enable row level security;
alter table public.location_staff_assignments force row level security;
alter table public.account_location_preferences enable row level security;
alter table public.account_location_preferences force row level security;

create policy locations_select_public
on public.locations for select
to anon, authenticated
using (state <> 'retired');

create policy locations_select_privileged
on public.locations for select
to authenticated
using (
  (select app_private.has_account_capability('platform_admin'))
  or (select app_private.has_location_staff_scope(id, 'local_manager'))
);

create policy location_staff_select_authorized
on public.location_staff_assignments for select
to authenticated
using (
  account_id = (select app_private.current_account_id())
  or (select app_private.has_account_capability('platform_admin'))
);

create policy account_location_preferences_select_own
on public.account_location_preferences for select
to authenticated
using (account_id = (select app_private.current_account_id()));

-- Start from zero table privileges, then expose the minimum safe reads.
revoke all on table public.locations from public, anon, authenticated, service_role;
revoke all on table public.location_staff_assignments from public, anon, authenticated, service_role;
revoke all on table public.account_location_preferences from public, anon, authenticated, service_role;

grant select on table public.locations to anon, authenticated;
grant select on table public.location_staff_assignments to authenticated;
grant select on table public.account_location_preferences to authenticated;

grant select, insert, update, delete on table public.locations to service_role;
grant select, insert, update, delete on table public.location_staff_assignments to service_role;
grant select, insert, update, delete on table public.account_location_preferences to service_role;

-- Lock down private functions before selectively granting policy/wrapper calls.
revoke all on function app_private.has_location_staff_scope(uuid,text) from public, anon, authenticated, service_role;
revoke all on function app_private.write_location_audit(uuid,text,uuid,text,uuid,text,jsonb) from public, anon, authenticated, service_role;
revoke all on function app_private.cmd_create_location(text,text,text,text,text,jsonb,text) from public, anon, authenticated, service_role;
revoke all on function app_private.cmd_set_location_state(uuid,text,text,text) from public, anon, authenticated, service_role;
revoke all on function app_private.cmd_assign_local_manager(uuid,uuid,text) from public, anon, authenticated, service_role;
revoke all on function app_private.cmd_end_location_staff_assignment(uuid,text,text) from public, anon, authenticated, service_role;
revoke all on function app_private.cmd_set_selected_location(uuid,text) from public, anon, authenticated, service_role;
revoke all on function app_private.account_closure_blockers(uuid) from public, anon, authenticated, service_role;

-- cmd_request_account_closure is replaced above; preserve authenticated wrapper access.
revoke all on function app_private.cmd_request_account_closure(text) from public, anon, authenticated, service_role;

grant execute on function app_private.has_location_staff_scope(uuid,text) to authenticated;
grant execute on function app_private.cmd_create_location(text,text,text,text,text,jsonb,text) to authenticated;
grant execute on function app_private.cmd_set_location_state(uuid,text,text,text) to authenticated;
grant execute on function app_private.cmd_assign_local_manager(uuid,uuid,text) to authenticated;
grant execute on function app_private.cmd_end_location_staff_assignment(uuid,text,text) to authenticated;
grant execute on function app_private.cmd_set_selected_location(uuid,text) to authenticated;
grant execute on function app_private.cmd_request_account_closure(text) to authenticated;

-- Public Data API RPC wrappers.
create or replace function public.create_location(
  p_name text,
  p_slug text,
  p_region text default null,
  p_state_or_province text default null,
  p_country_code text default 'IN',
  p_coverage_metadata jsonb default '{}'::jsonb,
  p_idempotency_key text default null
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app_private.cmd_create_location(
    p_name,p_slug,p_region,p_state_or_province,p_country_code,p_coverage_metadata,p_idempotency_key
  );
$$;

create or replace function public.set_location_state(
  p_location_id uuid,
  p_new_state text,
  p_reason text,
  p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app_private.cmd_set_location_state(p_location_id,p_new_state,p_reason,p_idempotency_key);
$$;

create or replace function public.assign_local_manager(
  p_location_id uuid,
  p_target_account_id uuid,
  p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app_private.cmd_assign_local_manager(p_location_id,p_target_account_id,p_idempotency_key);
$$;

create or replace function public.end_location_staff_assignment(
  p_assignment_id uuid,
  p_reason text,
  p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app_private.cmd_end_location_staff_assignment(p_assignment_id,p_reason,p_idempotency_key);
$$;

create or replace function public.set_selected_location(
  p_location_id uuid,
  p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app_private.cmd_set_selected_location(p_location_id,p_idempotency_key);
$$;

revoke all on function public.create_location(text,text,text,text,text,jsonb,text) from public, anon, authenticated, service_role;
revoke all on function public.set_location_state(uuid,text,text,text) from public, anon, authenticated, service_role;
revoke all on function public.assign_local_manager(uuid,uuid,text) from public, anon, authenticated, service_role;
revoke all on function public.end_location_staff_assignment(uuid,text,text) from public, anon, authenticated, service_role;
revoke all on function public.set_selected_location(uuid,text) from public, anon, authenticated, service_role;

grant execute on function public.create_location(text,text,text,text,text,jsonb,text) to authenticated;
grant execute on function public.set_location_state(uuid,text,text,text) to authenticated;
grant execute on function public.assign_local_manager(uuid,uuid,text) to authenticated;
grant execute on function public.end_location_staff_assignment(uuid,text,text) to authenticated;
grant execute on function public.set_selected_location(uuid,text) to authenticated;