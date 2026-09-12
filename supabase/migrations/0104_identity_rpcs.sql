-- Raahi Learning V1.2 — Canonical Identity commands
-- Public RPCs are thin SECURITY INVOKER wrappers. Privileged command logic lives
-- in the non-exposed app_private schema and derives the actor from auth.uid().

create or replace function app_private.cmd_bootstrap_account(p_display_name text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_account_id uuid;
  v_status text;
  v_created boolean := false;
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if p_display_name is null or char_length(btrim(p_display_name)) not between 1 and 120 then
    raise exception 'INVALID_DISPLAY_NAME';
  end if;

  insert into public.accounts (auth_user_id, display_name)
  values (v_uid, btrim(p_display_name))
  on conflict (auth_user_id) do nothing
  returning id into v_account_id;

  if v_account_id is not null then
    v_created := true;
    perform app_private.write_audit(
      v_account_id, 'account.bootstrap', 'account', v_account_id, null, null,
      jsonb_build_object('created', true)
    );
  else
    select id, lifecycle_status into v_account_id, v_status
    from public.accounts
    where auth_user_id = v_uid;
  end if;

  if v_status is null then
    select lifecycle_status into v_status from public.accounts where id = v_account_id;
  end if;

  return jsonb_build_object(
    'account_id', v_account_id,
    'created', v_created,
    'lifecycle_status', v_status
  );
end;
$$;

create or replace function app_private.cmd_create_learner(
  p_display_name text,
  p_access_type text,
  p_avatar_type text,
  p_avatar_ref text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.require_current_account(false);
  v_gate jsonb;
  v_fingerprint text;
  v_learner_id uuid;
  v_access_id uuid;
  v_result jsonb;
  v_status text;
begin
  v_fingerprint := app_private.request_fingerprint(jsonb_build_object(
    'display_name', p_display_name,
    'access_type', p_access_type,
    'avatar_type', p_avatar_type,
    'avatar_ref', p_avatar_ref
  ));
  v_gate := app_private.begin_human_idempotent_command(v_actor, 'create_learner', p_idempotency_key, v_fingerprint);
  if (v_gate->>'cached')::boolean then
    return v_gate->'result';
  end if;

  select lifecycle_status into v_status from public.accounts where id = v_actor;
  if v_status <> 'active' then
    raise exception 'ACCOUNT_NOT_ACTIVE';
  end if;
  if p_access_type not in ('self','manage') then
    raise exception 'INVALID_ACCESS_TYPE';
  end if;
  if p_display_name is null or char_length(btrim(p_display_name)) not between 1 and 120 then
    raise exception 'INVALID_DISPLAY_NAME';
  end if;
  if p_avatar_type not in ('builtin','upload','none') then
    raise exception 'INVALID_AVATAR_TYPE';
  end if;
  if (p_avatar_type = 'none' and p_avatar_ref is not null)
     or (p_avatar_type in ('builtin','upload') and p_avatar_ref is null) then
    raise exception 'INVALID_AVATAR_REFERENCE';
  end if;

  insert into public.learners (display_name, avatar_type, avatar_ref, created_by_account_id)
  values (btrim(p_display_name), p_avatar_type, p_avatar_ref, v_actor)
  returning id into v_learner_id;

  insert into public.account_learner_access (account_id, learner_id, access_type)
  values (v_actor, v_learner_id, p_access_type)
  returning id into v_access_id;

  perform app_private.write_audit(
    v_actor, 'learner.create', 'learner', v_learner_id, v_learner_id, null,
    jsonb_build_object('initial_access_type', p_access_type)
  );

  v_result := jsonb_build_object(
    'learner_id', v_learner_id,
    'access_id', v_access_id,
    'access_type', p_access_type
  );
  perform app_private.complete_human_idempotent_command(v_actor, 'create_learner', p_idempotency_key, v_result);
  return v_result;
end;
$$;

create or replace function app_private.cmd_grant_learner_self_access(
  p_learner_id uuid,
  p_target_account_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.require_current_account(false);
  v_gate jsonb;
  v_fingerprint text;
  v_status text;
  v_target_status text;
  v_target_auth uuid;
  v_manager uuid;
  v_existing_id uuid;
  v_existing_account uuid;
  v_access_id uuid;
  v_result jsonb;
begin
  v_fingerprint := app_private.request_fingerprint(jsonb_build_object(
    'learner_id', p_learner_id,
    'target_account_id', p_target_account_id
  ));
  v_gate := app_private.begin_human_idempotent_command(v_actor, 'grant_learner_self_access', p_idempotency_key, v_fingerprint);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select lifecycle_status into v_status from public.accounts where id = v_actor;
  if v_status <> 'active' then raise exception 'ACCOUNT_NOT_ACTIVE'; end if;

  perform 1 from public.learners where id = p_learner_id for update;
  if not found then raise exception 'LEARNER_NOT_FOUND'; end if;

  if not app_private.can_manage_learner(p_learner_id)
     and not app_private.has_account_capability('platform_admin') then
    raise exception 'NOT_AUTHORIZED';
  end if;

  select lifecycle_status, auth_user_id into v_target_status, v_target_auth
  from public.accounts where id = p_target_account_id;
  if not found or v_target_status = 'closed' or v_target_auth is null then
    raise exception 'TARGET_ACCOUNT_NOT_ELIGIBLE';
  end if;

  select account_id into v_manager
  from public.account_learner_access
  where learner_id = p_learner_id and access_type = 'manage' and status = 'active'
  limit 1;
  if v_manager = p_target_account_id then
    raise exception 'TARGET_IS_ACTIVE_MANAGER';
  end if;

  select id, account_id into v_existing_id, v_existing_account
  from public.account_learner_access
  where learner_id = p_learner_id and access_type = 'self' and status = 'active'
  limit 1;

  if v_existing_id is not null then
    if v_existing_account <> p_target_account_id then
      raise exception 'ACTIVE_SELF_ACCESS_ALREADY_EXISTS';
    end if;
    v_result := jsonb_build_object('access_id', v_existing_id, 'already_active', true);
    perform app_private.complete_human_idempotent_command(v_actor, 'grant_learner_self_access', p_idempotency_key, v_result);
    return v_result;
  end if;

  insert into public.account_learner_access (account_id, learner_id, access_type)
  values (p_target_account_id, p_learner_id, 'self')
  returning id into v_access_id;

  perform app_private.write_audit(
    v_actor, 'learner.self_access_grant', 'learner', p_learner_id, p_learner_id, null,
    jsonb_build_object('target_account_id', p_target_account_id)
  );

  v_result := jsonb_build_object('access_id', v_access_id, 'already_active', false);
  perform app_private.complete_human_idempotent_command(v_actor, 'grant_learner_self_access', p_idempotency_key, v_result);
  return v_result;
end;
$$;

create or replace function app_private.cmd_transfer_learner_management(
  p_learner_id uuid,
  p_target_account_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.require_current_account(false);
  v_gate jsonb;
  v_fingerprint text;
  v_target_status text;
  v_target_auth uuid;
  v_existing_manage_id uuid;
  v_existing_manager uuid;
  v_new_access_id uuid;
  v_result jsonb;
begin
  v_fingerprint := app_private.request_fingerprint(jsonb_build_object(
    'learner_id', p_learner_id,
    'target_account_id', p_target_account_id
  ));
  v_gate := app_private.begin_human_idempotent_command(v_actor, 'transfer_learner_management', p_idempotency_key, v_fingerprint);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  if not app_private.has_account_capability('platform_admin') then
    raise exception 'PLATFORM_ADMIN_REQUIRED';
  end if;

  perform 1 from public.learners where id = p_learner_id for update;
  if not found then raise exception 'LEARNER_NOT_FOUND'; end if;

  select lifecycle_status, auth_user_id into v_target_status, v_target_auth
  from public.accounts where id = p_target_account_id;
  if not found or v_target_status = 'closed' or v_target_auth is null then
    raise exception 'TARGET_ACCOUNT_NOT_ELIGIBLE';
  end if;

  if exists (
    select 1 from public.account_learner_access
    where learner_id = p_learner_id and account_id = p_target_account_id
      and access_type = 'self' and status = 'active'
  ) then
    raise exception 'TARGET_ALREADY_HAS_SELF_ACCESS_USE_END_MANAGER';
  end if;

  select id, account_id into v_existing_manage_id, v_existing_manager
  from public.account_learner_access
  where learner_id = p_learner_id and access_type = 'manage' and status = 'active'
  for update;

  if v_existing_manager = p_target_account_id then
    v_result := jsonb_build_object('access_id', v_existing_manage_id, 'already_manager', true);
    perform app_private.complete_human_idempotent_command(v_actor, 'transfer_learner_management', p_idempotency_key, v_result);
    return v_result;
  end if;

  if v_existing_manage_id is not null then
    update public.account_learner_access
    set status = 'ended', ended_at = now()
    where id = v_existing_manage_id;
  end if;

  insert into public.account_learner_access (account_id, learner_id, access_type)
  values (p_target_account_id, p_learner_id, 'manage')
  returning id into v_new_access_id;

  perform app_private.write_audit(
    v_actor, 'learner.management_transfer', 'learner', p_learner_id, p_learner_id, null,
    jsonb_build_object('from_account_id', v_existing_manager, 'to_account_id', p_target_account_id)
  );

  v_result := jsonb_build_object(
    'access_id', v_new_access_id,
    'from_account_id', v_existing_manager,
    'to_account_id', p_target_account_id
  );
  perform app_private.complete_human_idempotent_command(v_actor, 'transfer_learner_management', p_idempotency_key, v_result);
  return v_result;
end;
$$;

create or replace function app_private.cmd_end_learner_access(
  p_access_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.require_current_account(false);
  v_gate jsonb;
  v_fingerprint text;
  v_owner uuid;
  v_learner uuid;
  v_type text;
  v_state text;
  v_actor_status text;
  v_result jsonb;
begin
  v_fingerprint := app_private.request_fingerprint(jsonb_build_object('access_id', p_access_id));
  v_gate := app_private.begin_human_idempotent_command(v_actor, 'end_learner_access', p_idempotency_key, v_fingerprint);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select lifecycle_status into v_actor_status from public.accounts where id = v_actor;
  if v_actor_status = 'closed' then raise exception 'ACCOUNT_CLOSED'; end if;

  select account_id, learner_id, access_type, status
    into v_owner, v_learner, v_type, v_state
  from public.account_learner_access
  where id = p_access_id
  for update;
  if not found then raise exception 'ACCESS_NOT_FOUND'; end if;

  if v_owner <> v_actor and not app_private.has_account_capability('platform_admin') then
    raise exception 'NOT_AUTHORIZED';
  end if;

  if v_state = 'ended' then
    v_result := jsonb_build_object('access_id', p_access_id, 'already_ended', true);
    perform app_private.complete_human_idempotent_command(v_actor, 'end_learner_access', p_idempotency_key, v_result);
    return v_result;
  end if;

  perform 1 from public.learners where id = v_learner for update;

  if v_type = 'manage' and not exists (
    select 1 from public.account_learner_access
    where learner_id = v_learner and access_type = 'self' and status = 'active'
  ) then
    raise exception 'MANAGER_TRANSFER_OR_SELF_ACCESS_REQUIRED';
  end if;

  if v_type = 'self' and not exists (
    select 1 from public.account_learner_access
    where learner_id = v_learner and access_type = 'manage' and status = 'active'
  ) then
    raise exception 'LEARNER_WOULD_HAVE_NO_ACTIVE_ACCESS';
  end if;

  update public.account_learner_access
  set status = 'ended', ended_at = now()
  where id = p_access_id;

  perform app_private.write_audit(
    v_actor, 'learner.access_end', 'learner', v_learner, v_learner, null,
    jsonb_build_object('access_id', p_access_id, 'access_type', v_type, 'account_id', v_owner)
  );

  v_result := jsonb_build_object('access_id', p_access_id, 'already_ended', false);
  perform app_private.complete_human_idempotent_command(v_actor, 'end_learner_access', p_idempotency_key, v_result);
  return v_result;
end;
$$;

create or replace function app_private.cmd_grant_account_capability(
  p_target_account_id uuid,
  p_capability_code text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.require_current_account(false);
  v_gate jsonb;
  v_fingerprint text;
  v_target_status text;
  v_existing uuid;
  v_new uuid;
  v_result jsonb;
begin
  v_fingerprint := app_private.request_fingerprint(jsonb_build_object(
    'target_account_id', p_target_account_id, 'capability_code', p_capability_code
  ));
  v_gate := app_private.begin_human_idempotent_command(v_actor, 'grant_account_capability', p_idempotency_key, v_fingerprint);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  if not app_private.has_account_capability('platform_admin') then
    raise exception 'PLATFORM_ADMIN_REQUIRED';
  end if;

  select lifecycle_status into v_target_status from public.accounts where id = p_target_account_id;
  if not found or v_target_status = 'closed' then raise exception 'TARGET_ACCOUNT_NOT_ELIGIBLE'; end if;

  select id into v_existing from public.account_capabilities
  where account_id = p_target_account_id and capability_code = p_capability_code and status = 'active'
  limit 1;

  if v_existing is not null then
    v_result := jsonb_build_object('capability_id', v_existing, 'already_active', true);
    perform app_private.complete_human_idempotent_command(v_actor, 'grant_account_capability', p_idempotency_key, v_result);
    return v_result;
  end if;

  insert into public.account_capabilities (account_id, capability_code, granted_by_account_id)
  values (p_target_account_id, p_capability_code, v_actor)
  returning id into v_new;

  perform app_private.write_audit(
    v_actor, 'account.capability_grant', 'account', p_target_account_id, null, null,
    jsonb_build_object('capability_code', p_capability_code)
  );

  v_result := jsonb_build_object('capability_id', v_new, 'already_active', false);
  perform app_private.complete_human_idempotent_command(v_actor, 'grant_account_capability', p_idempotency_key, v_result);
  return v_result;
end;
$$;

create or replace function app_private.cmd_revoke_account_capability(
  p_target_account_id uuid,
  p_capability_code text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.require_current_account(false);
  v_gate jsonb;
  v_fingerprint text;
  v_capability_id uuid;
  v_result jsonb;
begin
  v_fingerprint := app_private.request_fingerprint(jsonb_build_object(
    'target_account_id', p_target_account_id, 'capability_code', p_capability_code
  ));
  v_gate := app_private.begin_human_idempotent_command(v_actor, 'revoke_account_capability', p_idempotency_key, v_fingerprint);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  if not app_private.has_account_capability('platform_admin') then
    raise exception 'PLATFORM_ADMIN_REQUIRED';
  end if;

  select id into v_capability_id
  from public.account_capabilities
  where account_id = p_target_account_id and capability_code = p_capability_code and status = 'active'
  for update;

  if v_capability_id is null then
    v_result := jsonb_build_object('already_revoked', true);
    perform app_private.complete_human_idempotent_command(v_actor, 'revoke_account_capability', p_idempotency_key, v_result);
    return v_result;
  end if;

  update public.account_capabilities
  set status = 'revoked', revoked_at = now()
  where id = v_capability_id;

  perform app_private.write_audit(
    v_actor, 'account.capability_revoke', 'account', p_target_account_id, null, null,
    jsonb_build_object('capability_code', p_capability_code)
  );

  v_result := jsonb_build_object('capability_id', v_capability_id, 'already_revoked', false);
  perform app_private.complete_human_idempotent_command(v_actor, 'revoke_account_capability', p_idempotency_key, v_result);
  return v_result;
end;
$$;

create or replace function app_private.cmd_pause_account(p_idempotency_key text)
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
  v_result jsonb;
begin
  v_gate := app_private.begin_human_idempotent_command(v_actor, 'pause_account', p_idempotency_key, v_fingerprint);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select lifecycle_status into v_status from public.accounts where id = v_actor for update;
  if v_status = 'closed' then raise exception 'ACCOUNT_CLOSED'; end if;

  if v_status = 'paused' then
    v_result := jsonb_build_object('lifecycle_status', 'paused', 'already_paused', true);
  else
    update public.accounts set lifecycle_status = 'paused' where id = v_actor;
    perform app_private.write_audit(v_actor, 'account.pause', 'account', v_actor);
    v_result := jsonb_build_object('lifecycle_status', 'paused', 'already_paused', false);
  end if;

  perform app_private.complete_human_idempotent_command(v_actor, 'pause_account', p_idempotency_key, v_result);
  return v_result;
end;
$$;

create or replace function app_private.cmd_resume_account(p_idempotency_key text)
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
  v_result jsonb;
begin
  v_gate := app_private.begin_human_idempotent_command(v_actor, 'resume_account', p_idempotency_key, v_fingerprint);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select lifecycle_status into v_status from public.accounts where id = v_actor for update;
  if v_status = 'closed' then raise exception 'ACCOUNT_CLOSED'; end if;

  if v_status = 'active' then
    v_result := jsonb_build_object('lifecycle_status', 'active', 'already_active', true);
  else
    update public.accounts set lifecycle_status = 'active' where id = v_actor;
    perform app_private.write_audit(v_actor, 'account.resume', 'account', v_actor);
    v_result := jsonb_build_object('lifecycle_status', 'active', 'already_active', false);
  end if;

  perform app_private.complete_human_idempotent_command(v_actor, 'resume_account', p_idempotency_key, v_result);
  return v_result;
end;
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
  v_gate := app_private.begin_human_idempotent_command(v_actor, 'request_account_closure', p_idempotency_key, v_fingerprint);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select lifecycle_status into v_status from public.accounts where id = v_actor for update;
  if v_status = 'closed' then
    v_result := jsonb_build_object('closed', true, 'already_closed', true, 'blockers', '[]'::jsonb);
    perform app_private.complete_human_idempotent_command(v_actor, 'request_account_closure', p_idempotency_key, v_result);
    return v_result;
  end if;

  select coalesce(
    jsonb_agg(jsonb_build_object('code', 'SOLE_MANAGER_RESPONSIBILITY', 'learner_id', ala.learner_id)),
    '[]'::jsonb
  ) into v_blockers
  from public.account_learner_access ala
  where ala.account_id = v_actor
    and ala.access_type = 'manage'
    and ala.status = 'active'
    and not exists (
      select 1 from public.account_learner_access self_access
      where self_access.learner_id = ala.learner_id
        and self_access.access_type = 'self'
        and self_access.status = 'active'
    );

  if jsonb_array_length(v_blockers) > 0 then
    v_result := jsonb_build_object('closed', false, 'already_closed', false, 'blockers', v_blockers);
    perform app_private.complete_human_idempotent_command(v_actor, 'request_account_closure', p_idempotency_key, v_result);
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
  perform app_private.complete_human_idempotent_command(v_actor, 'request_account_closure', p_idempotency_key, v_result);
  return v_result;
end;
$$;

-- Private command implementations are not Data API objects, but authenticated
-- callers need EXECUTE so the SECURITY INVOKER public wrappers can call them.
grant execute on function app_private.cmd_bootstrap_account(text) to authenticated;
grant execute on function app_private.cmd_create_learner(text,text,text,text,text) to authenticated;
grant execute on function app_private.cmd_grant_learner_self_access(uuid,uuid,text) to authenticated;
grant execute on function app_private.cmd_transfer_learner_management(uuid,uuid,text) to authenticated;
grant execute on function app_private.cmd_end_learner_access(uuid,text) to authenticated;
grant execute on function app_private.cmd_grant_account_capability(uuid,text,text) to authenticated;
grant execute on function app_private.cmd_revoke_account_capability(uuid,text,text) to authenticated;
grant execute on function app_private.cmd_pause_account(text) to authenticated;
grant execute on function app_private.cmd_resume_account(text) to authenticated;
grant execute on function app_private.cmd_request_account_closure(text) to authenticated;

-- Public Data API RPC wrappers.
create or replace function public.bootstrap_account(p_display_name text)
returns jsonb
language sql
security invoker
set search_path = ''
as $$ select app_private.cmd_bootstrap_account(p_display_name); $$;

create or replace function public.create_learner(
  p_display_name text, p_access_type text, p_avatar_type text, p_avatar_ref text, p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$ select app_private.cmd_create_learner(p_display_name,p_access_type,p_avatar_type,p_avatar_ref,p_idempotency_key); $$;

create or replace function public.grant_learner_self_access(
  p_learner_id uuid, p_target_account_id uuid, p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$ select app_private.cmd_grant_learner_self_access(p_learner_id,p_target_account_id,p_idempotency_key); $$;

create or replace function public.transfer_learner_management(
  p_learner_id uuid, p_target_account_id uuid, p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$ select app_private.cmd_transfer_learner_management(p_learner_id,p_target_account_id,p_idempotency_key); $$;

create or replace function public.end_learner_access(p_access_id uuid, p_idempotency_key text)
returns jsonb
language sql
security invoker
set search_path = ''
as $$ select app_private.cmd_end_learner_access(p_access_id,p_idempotency_key); $$;

create or replace function public.grant_account_capability(
  p_target_account_id uuid, p_capability_code text, p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$ select app_private.cmd_grant_account_capability(p_target_account_id,p_capability_code,p_idempotency_key); $$;

create or replace function public.revoke_account_capability(
  p_target_account_id uuid, p_capability_code text, p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$ select app_private.cmd_revoke_account_capability(p_target_account_id,p_capability_code,p_idempotency_key); $$;

create or replace function public.pause_account(p_idempotency_key text)
returns jsonb
language sql
security invoker
set search_path = ''
as $$ select app_private.cmd_pause_account(p_idempotency_key); $$;

create or replace function public.resume_account(p_idempotency_key text)
returns jsonb
language sql
security invoker
set search_path = ''
as $$ select app_private.cmd_resume_account(p_idempotency_key); $$;

create or replace function public.request_account_closure(p_idempotency_key text)
returns jsonb
language sql
security invoker
set search_path = ''
as $$ select app_private.cmd_request_account_closure(p_idempotency_key); $$;

revoke all on function public.bootstrap_account(text) from public, anon, authenticated, service_role;
revoke all on function public.create_learner(text,text,text,text,text) from public, anon, authenticated, service_role;
revoke all on function public.grant_learner_self_access(uuid,uuid,text) from public, anon, authenticated, service_role;
revoke all on function public.transfer_learner_management(uuid,uuid,text) from public, anon, authenticated, service_role;
revoke all on function public.end_learner_access(uuid,text) from public, anon, authenticated, service_role;
revoke all on function public.grant_account_capability(uuid,text,text) from public, anon, authenticated, service_role;
revoke all on function public.revoke_account_capability(uuid,text,text) from public, anon, authenticated, service_role;
revoke all on function public.pause_account(text) from public, anon, authenticated, service_role;
revoke all on function public.resume_account(text) from public, anon, authenticated, service_role;
revoke all on function public.request_account_closure(text) from public, anon, authenticated, service_role;

grant execute on function public.bootstrap_account(text) to authenticated;
grant execute on function public.create_learner(text,text,text,text,text) to authenticated;
grant execute on function public.grant_learner_self_access(uuid,uuid,text) to authenticated;
grant execute on function public.transfer_learner_management(uuid,uuid,text) to authenticated;
grant execute on function public.end_learner_access(uuid,text) to authenticated;
grant execute on function public.grant_account_capability(uuid,text,text) to authenticated;
grant execute on function public.revoke_account_capability(uuid,text,text) to authenticated;
grant execute on function public.pause_account(text) to authenticated;
grant execute on function public.resume_account(text) to authenticated;
grant execute on function public.request_account_closure(text) to authenticated;
