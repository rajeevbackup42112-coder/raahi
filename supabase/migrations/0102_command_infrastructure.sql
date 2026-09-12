-- Raahi Learning V1.2 — Audit + idempotency infrastructure

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_kind text not null,
  actor_account_id uuid null references public.accounts(id),
  action_type text not null,
  target_type text not null,
  target_id uuid null,
  learner_id uuid null references public.learners(id),
  reason text null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint audit_log_actor_kind_check check (actor_kind in ('account','system')),
  constraint audit_log_actor_consistency check (
    (actor_kind = 'account' and actor_account_id is not null)
    or (actor_kind = 'system' and actor_account_id is null)
  ),
  constraint audit_log_action_nonblank check (char_length(btrim(action_type)) between 1 and 120),
  constraint audit_log_target_nonblank check (char_length(btrim(target_type)) between 1 and 120)
);

create table public.idempotency_keys (
  id uuid primary key default gen_random_uuid(),
  actor_account_id uuid null references public.accounts(id),
  command_name text not null,
  idempotency_key text not null,
  request_fingerprint text not null,
  result_json jsonb null,
  created_at timestamptz not null default now(),
  completed_at timestamptz null,
  expires_at timestamptz null,
  constraint idempotency_keys_command_nonblank check (char_length(btrim(command_name)) between 1 and 120),
  constraint idempotency_keys_key_nonblank check (char_length(btrim(idempotency_key)) between 1 and 200),
  constraint idempotency_keys_human_unique unique (actor_account_id, command_name, idempotency_key)
);

create unique index idempotency_keys_system_unique
  on public.idempotency_keys (command_name, idempotency_key)
  where actor_account_id is null;

create index idempotency_keys_expires_at_idx
  on public.idempotency_keys (expires_at)
  where expires_at is not null;

create index audit_log_actor_time_idx
  on public.audit_log (actor_account_id, created_at desc)
  where actor_account_id is not null;

create index audit_log_target_time_idx
  on public.audit_log (target_type, target_id, created_at desc);

create index audit_log_learner_time_idx
  on public.audit_log (learner_id, created_at desc)
  where learner_id is not null;

create or replace function app_private.request_fingerprint(p_payload jsonb)
returns text
language sql
immutable
set search_path = ''
as $$
  select encode(
    extensions.digest(convert_to(coalesce(p_payload, '{}'::jsonb)::text, 'UTF8'), 'sha256'),
    'hex'
  );
$$;

create or replace function app_private.begin_human_idempotent_command(
  p_actor_account_id uuid,
  p_command_name text,
  p_idempotency_key text,
  p_request_fingerprint text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inserted integer := 0;
  v_fingerprint text;
  v_result jsonb;
begin
  if p_actor_account_id is null then
    raise exception 'IDEMPOTENCY_ACTOR_REQUIRED';
  end if;
  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED';
  end if;

  insert into public.idempotency_keys (
    actor_account_id, command_name, idempotency_key, request_fingerprint
  )
  values (
    p_actor_account_id, p_command_name, p_idempotency_key, p_request_fingerprint
  )
  on conflict (actor_account_id, command_name, idempotency_key) do nothing;

  get diagnostics v_inserted = row_count;

  select request_fingerprint, result_json
    into v_fingerprint, v_result
  from public.idempotency_keys
  where actor_account_id = p_actor_account_id
    and command_name = p_command_name
    and idempotency_key = p_idempotency_key
  for update;

  if v_fingerprint is distinct from p_request_fingerprint then
    raise exception 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST';
  end if;

  if v_inserted = 0 then
    if v_result is null then
      raise exception 'IDEMPOTENCY_REQUEST_INCOMPLETE';
    end if;
    return jsonb_build_object('cached', true, 'result', v_result);
  end if;

  return jsonb_build_object('cached', false);
end;
$$;

create or replace function app_private.complete_human_idempotent_command(
  p_actor_account_id uuid,
  p_command_name text,
  p_idempotency_key text,
  p_result jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.idempotency_keys
  set result_json = p_result,
      completed_at = now()
  where actor_account_id = p_actor_account_id
    and command_name = p_command_name
    and idempotency_key = p_idempotency_key;

  if not found then
    raise exception 'IDEMPOTENCY_RECORD_NOT_FOUND';
  end if;
end;
$$;

create or replace function app_private.write_audit(
  p_actor_account_id uuid,
  p_action_type text,
  p_target_type text,
  p_target_id uuid default null,
  p_learner_id uuid default null,
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
    learner_id, reason, metadata
  )
  values (
    'account', p_actor_account_id, p_action_type, p_target_type, p_target_id,
    p_learner_id, p_reason, coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function app_private.request_fingerprint(jsonb) from public, anon, authenticated, service_role;
revoke all on function app_private.begin_human_idempotent_command(uuid,text,text,text) from public, anon, authenticated, service_role;
revoke all on function app_private.complete_human_idempotent_command(uuid,text,text,jsonb) from public, anon, authenticated, service_role;
revoke all on function app_private.write_audit(uuid,text,text,uuid,uuid,text,jsonb) from public, anon, authenticated, service_role;
