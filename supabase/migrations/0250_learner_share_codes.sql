-- Raahi Learning V1.2 — Private Learner share codes
-- Bearer token is generated inside Postgres, returned once, and never persisted in plaintext.

create table public.learner_share_codes (
  id uuid primary key default gen_random_uuid(),
  learner_id uuid not null references public.learners(id),
  created_by_account_id uuid not null references public.accounts(id),
  code_hash text not null unique,
  state text not null default 'active',
  expires_at timestamptz not null,
  consumed_at timestamptz null,
  revoked_at timestamptz null,
  created_at timestamptz not null default now(),
  constraint learner_share_codes_hash_format check (code_hash ~ '^[0-9a-f]{64}$'),
  constraint learner_share_codes_state_check check (state in ('active','consumed','revoked','expired')),
  constraint learner_share_codes_expiry_after_creation check (expires_at > created_at),
  constraint learner_share_codes_terminal_timestamp_check check (
    (state = 'active' and consumed_at is null and revoked_at is null)
    or (state = 'consumed' and consumed_at is not null and revoked_at is null)
    or (state = 'revoked' and revoked_at is not null and consumed_at is null)
    or (state = 'expired' and consumed_at is null and revoked_at is null)
  )
);

comment on table public.learner_share_codes is
  'Private, one-time Learner bearer codes. Plaintext is never stored. No public Learner directory or browse path is created.';

-- V1 keeps at most one effective active share-code row per Learner. The create
-- command serializes on the Learner row, expires stale rows and revokes any
-- still-active predecessor before inserting a replacement.
create unique index learner_share_codes_one_active_per_learner_idx
  on public.learner_share_codes (learner_id)
  where state = 'active';

create index learner_share_codes_learner_history_idx
  on public.learner_share_codes (learner_id, created_at desc);

create index learner_share_codes_creator_history_idx
  on public.learner_share_codes (created_by_account_id, created_at desc);

create index learner_share_codes_expiry_idx
  on public.learner_share_codes (expires_at)
  where state = 'active';

alter table public.learner_share_codes enable row level security;
alter table public.learner_share_codes force row level security;

-- There is intentionally no client table read path. UI/API access is through
-- narrowly-scoped RPC results only; code_hash is never exposed to clients.
create policy learner_share_codes_deny_authenticated
on public.learner_share_codes
for all
to authenticated
using (false)
with check (false);

revoke all on table public.learner_share_codes from public, anon, authenticated, service_role;

-- 24 hours is a V1 policy seam, not a schema invariant. It can be changed by a
-- forward migration without altering the data model or command contract.
create or replace function app_private.learner_share_code_ttl()
returns interval
language sql
immutable
set search_path = ''
as $$
  select interval '24 hours';
$$;

create or replace function app_private.learner_share_code_hash(p_plaintext_token text)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select encode(
    extensions.digest(convert_to(p_plaintext_token, 'UTF8'), 'sha256'),
    'hex'
  );
$$;

create or replace function app_private.generate_learner_share_code_token()
returns text
language sql
volatile
set search_path = ''
as $$
  select 'rl_' || rtrim(
    translate(encode(extensions.gen_random_bytes(24), 'base64'), '+/', '-_'),
    '='
  );
$$;

-- Revocation is a protective action, so a paused current formal learner-side
-- authority may revoke an already-issued code. Creation still requires the
-- normal active-account can_make_learning_decision() rule.
create or replace function app_private.can_revoke_learner_share_code(p_learner_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.current_account_id();
  v_status text;
  v_manager uuid;
begin
  if v_actor is null then
    return false;
  end if;

  select lifecycle_status into v_status
  from public.accounts
  where id = v_actor;

  if v_status not in ('active','paused') then
    return false;
  end if;

  if v_status = 'active' and app_private.has_account_capability('platform_admin') then
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

-- Private primitive for the later Class invite-by-code command. It is NOT a
-- public resolve/search API. Possession of the exact high-entropy token is
-- required, and only an active + unexpired row resolves. FOR UPDATE prepares
-- the row for atomic consume inside the future Class transaction.
create or replace function app_private.resolve_active_learner_share_code(
  p_plaintext_token text
)
returns table(share_code_id uuid, learner_id uuid)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_hash text;
begin
  if p_plaintext_token is null
     or p_plaintext_token !~ '^rl_[A-Za-z0-9_-]{32}$' then
    return;
  end if;

  v_hash := app_private.learner_share_code_hash(p_plaintext_token);

  return query
  select lsc.id, lsc.learner_id
  from public.learner_share_codes lsc
  where lsc.code_hash = v_hash
    and lsc.state = 'active'
    and lsc.expires_at > now()
  for update;
end;
$$;

create or replace function app_private.cmd_create_learner_share_code(
  p_learner_id uuid,
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
  v_token text;
  v_hash text;
  v_share_code_id uuid;
  v_expires_at timestamptz;
  v_superseded integer := 0;
  v_safe_result jsonb;
begin
  v_fingerprint := app_private.request_fingerprint(
    jsonb_build_object('learner_id', p_learner_id)
  );

  v_gate := app_private.begin_human_idempotent_command(
    v_actor,
    'create_learner_share_code',
    p_idempotency_key,
    v_fingerprint
  );

  if (v_gate->>'cached')::boolean then
    -- Secret-bearing commands cannot replay a plaintext token without storing
    -- it. Return the same logical resource, but never the secret again.
    return (v_gate->'result') || jsonb_build_object(
      'share_code', null,
      'secret_available', false,
      'idempotent_replay', true
    );
  end if;

  perform 1
  from public.learners
  where id = p_learner_id
  for update;
  if not found then
    raise exception 'LEARNER_NOT_FOUND';
  end if;

  if not app_private.can_make_learning_decision(p_learner_id) then
    raise exception 'NOT_AUTHORIZED';
  end if;

  -- Preserve lifecycle truth for stale rows before replacing the current code.
  update public.learner_share_codes
  set state = 'expired'
  where learner_id = p_learner_id
    and state = 'active'
    and expires_at <= now();

  update public.learner_share_codes
  set state = 'revoked',
      revoked_at = now()
  where learner_id = p_learner_id
    and state = 'active';
  get diagnostics v_superseded = row_count;

  v_token := app_private.generate_learner_share_code_token();
  v_hash := app_private.learner_share_code_hash(v_token);
  v_expires_at := now() + app_private.learner_share_code_ttl();

  insert into public.learner_share_codes (
    learner_id,
    created_by_account_id,
    code_hash,
    state,
    expires_at
  )
  values (
    p_learner_id,
    v_actor,
    v_hash,
    'active',
    v_expires_at
  )
  returning id into v_share_code_id;

  perform app_private.write_audit(
    v_actor,
    'learner.share_code_create',
    'learner_share_code',
    v_share_code_id,
    p_learner_id,
    null,
    jsonb_build_object(
      'expires_at', v_expires_at,
      'superseded_active_count', v_superseded
    )
  );

  -- Store only non-secret idempotency result. This deliberately excludes the
  -- plaintext token and its hash.
  v_safe_result := jsonb_build_object(
    'share_code_id', v_share_code_id,
    'learner_id', p_learner_id,
    'state', 'active',
    'expires_at', v_expires_at
  );

  perform app_private.complete_human_idempotent_command(
    v_actor,
    'create_learner_share_code',
    p_idempotency_key,
    v_safe_result
  );

  return v_safe_result || jsonb_build_object(
    'share_code', v_token,
    'secret_available', true,
    'idempotent_replay', false
  );
end;
$$;

create or replace function app_private.cmd_revoke_learner_share_code(
  p_share_code_id uuid,
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
  v_state text;
  v_expires_at timestamptz;
  v_result jsonb;
begin
  v_fingerprint := app_private.request_fingerprint(
    jsonb_build_object('share_code_id', p_share_code_id)
  );

  v_gate := app_private.begin_human_idempotent_command(
    v_actor,
    'revoke_learner_share_code',
    p_idempotency_key,
    v_fingerprint
  );
  if (v_gate->>'cached')::boolean then
    return v_gate->'result';
  end if;

  select learner_id, state, expires_at
  into v_learner_id, v_state, v_expires_at
  from public.learner_share_codes
  where id = p_share_code_id
  for update;

  if not found then
    raise exception 'SHARE_CODE_NOT_FOUND_OR_NOT_AUTHORIZED';
  end if;

  if not app_private.can_revoke_learner_share_code(v_learner_id) then
    raise exception 'SHARE_CODE_NOT_FOUND_OR_NOT_AUTHORIZED';
  end if;

  if v_state = 'active' and v_expires_at <= now() then
    update public.learner_share_codes
    set state = 'expired'
    where id = p_share_code_id;

    v_result := jsonb_build_object(
      'share_code_id', p_share_code_id,
      'learner_id', v_learner_id,
      'state', 'expired',
      'revoked', false,
      'already_terminal', true
    );
  elsif v_state = 'active' then
    update public.learner_share_codes
    set state = 'revoked',
        revoked_at = now()
    where id = p_share_code_id;

    perform app_private.write_audit(
      v_actor,
      'learner.share_code_revoke',
      'learner_share_code',
      p_share_code_id,
      v_learner_id,
      null,
      '{}'::jsonb
    );

    v_result := jsonb_build_object(
      'share_code_id', p_share_code_id,
      'learner_id', v_learner_id,
      'state', 'revoked',
      'revoked', true,
      'already_revoked', false
    );
  elsif v_state = 'revoked' then
    v_result := jsonb_build_object(
      'share_code_id', p_share_code_id,
      'learner_id', v_learner_id,
      'state', 'revoked',
      'revoked', true,
      'already_revoked', true
    );
  else
    v_result := jsonb_build_object(
      'share_code_id', p_share_code_id,
      'learner_id', v_learner_id,
      'state', v_state,
      'revoked', false,
      'already_terminal', true
    );
  end if;

  perform app_private.complete_human_idempotent_command(
    v_actor,
    'revoke_learner_share_code',
    p_idempotency_key,
    v_result
  );

  return v_result;
end;
$$;

-- Private helpers are owner-only except the two command implementations called
-- by authenticated public wrappers.
revoke all on function app_private.learner_share_code_ttl() from public, anon, authenticated, service_role;
revoke all on function app_private.learner_share_code_hash(text) from public, anon, authenticated, service_role;
revoke all on function app_private.generate_learner_share_code_token() from public, anon, authenticated, service_role;
revoke all on function app_private.can_revoke_learner_share_code(uuid) from public, anon, authenticated, service_role;
revoke all on function app_private.resolve_active_learner_share_code(text) from public, anon, authenticated, service_role;
revoke all on function app_private.cmd_create_learner_share_code(uuid,text) from public, anon, authenticated, service_role;
revoke all on function app_private.cmd_revoke_learner_share_code(uuid,text) from public, anon, authenticated, service_role;

grant execute on function app_private.cmd_create_learner_share_code(uuid,text) to authenticated;
grant execute on function app_private.cmd_revoke_learner_share_code(uuid,text) to authenticated;

create or replace function public.create_learner_share_code(
  p_learner_id uuid,
  p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app_private.cmd_create_learner_share_code(p_learner_id,p_idempotency_key);
$$;

create or replace function public.revoke_learner_share_code(
  p_share_code_id uuid,
  p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app_private.cmd_revoke_learner_share_code(p_share_code_id,p_idempotency_key);
$$;

revoke all on function public.create_learner_share_code(uuid,text) from public, anon, authenticated, service_role;
revoke all on function public.revoke_learner_share_code(uuid,text) from public, anon, authenticated, service_role;

grant execute on function public.create_learner_share_code(uuid,text) to authenticated;
grant execute on function public.revoke_learner_share_code(uuid,text) to authenticated;
