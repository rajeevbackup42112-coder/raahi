-- Raahi Learning V1.3 — private Learner self-access invitations
-- Enables an existing Learner to gain self access later without Account UUID entry.
-- Bearer secrets are one-time/expiring, hash-only at rest, and never create a new Learner.

create table public.learner_self_access_invitations (
  id uuid primary key default gen_random_uuid(),
  learner_id uuid not null references public.learners(id),
  issued_by_account_id uuid not null references public.accounts(id),
  token_hash text not null unique,
  state text not null default 'active',
  expires_at timestamptz not null,
  accepted_by_account_id uuid null references public.accounts(id),
  accepted_at timestamptz null,
  revoked_at timestamptz null,
  created_at timestamptz not null default now(),
  constraint learner_self_access_invite_hash_format check (token_hash ~ '^[0-9a-f]{64}$'),
  constraint learner_self_access_invite_state_check check (state in ('active','accepted','revoked','expired')),
  constraint learner_self_access_invite_expiry_after_creation check (expires_at > created_at),
  constraint learner_self_access_invite_terminal_consistency check (
    (state='active' and accepted_by_account_id is null and accepted_at is null and revoked_at is null)
    or (state='accepted' and accepted_by_account_id is not null and accepted_at is not null and revoked_at is null)
    or (state='revoked' and accepted_by_account_id is null and accepted_at is null and revoked_at is not null)
    or (state='expired' and accepted_by_account_id is null and accepted_at is null and revoked_at is null)
  )
);

create unique index learner_self_access_invite_one_active_per_learner_idx
  on public.learner_self_access_invitations(learner_id)
  where state='active';
create index learner_self_access_invite_expiry_idx
  on public.learner_self_access_invitations(expires_at)
  where state='active';
create index learner_self_access_invite_issuer_idx
  on public.learner_self_access_invitations(issued_by_account_id,created_at desc);

alter table public.learner_self_access_invitations enable row level security;
alter table public.learner_self_access_invitations force row level security;
create policy learner_self_access_invitations_deny_authenticated
  on public.learner_self_access_invitations for all to authenticated
  using(false) with check(false);
revoke all on table public.learner_self_access_invitations from public,anon,authenticated,service_role;

create or replace function app_private.private_invite_hash(p_token text)
returns text
language sql
immutable
strict
set search_path=''
as $$
  select encode(extensions.digest(convert_to(p_token,'UTF8'),'sha256'),'hex');
$$;

create or replace function app_private.generate_private_invite_token(p_prefix text)
returns text
language sql
volatile
set search_path=''
as $$
  select p_prefix || rtrim(translate(encode(extensions.gen_random_bytes(24),'base64'),'+/','-_'),'=');
$$;

create or replace function app_private.learner_self_access_invitation_ttl()
returns interval
language sql
immutable
set search_path=''
as $$ select interval '7 days'; $$;

create or replace function app_private.can_revoke_learner_self_access_invitation(p_learner_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.current_account_id();
  v_status text;
begin
  if v_actor is null then return false; end if;
  select lifecycle_status into v_status from public.accounts where id=v_actor;
  if v_status not in ('active','paused') then return false; end if;
  if v_status='active' and app_private.has_account_capability('platform_admin') then return true; end if;
  return exists(
    select 1 from public.account_learner_access ala
    where ala.learner_id=p_learner_id
      and ala.account_id=v_actor
      and ala.access_type='manage'
      and ala.status='active'
  );
end;
$$;

create or replace function app_private.resolve_active_learner_self_access_invitation(p_token text)
returns table(invitation_id uuid,learner_id uuid,issued_by_account_id uuid,expires_at timestamptz)
language plpgsql
volatile
security definer
set search_path=''
as $$
declare v_hash text;
begin
  if p_token is null or p_token !~ '^rlsa_[A-Za-z0-9_-]{32}$' then return; end if;
  v_hash:=app_private.private_invite_hash(p_token);
  return query
  select i.id,i.learner_id,i.issued_by_account_id,i.expires_at
  from public.learner_self_access_invitations i
  where i.token_hash=v_hash and i.state='active' and i.expires_at>now()
  for update;
end;
$$;

create or replace function app_private.read_learner_self_access_invitation_preview(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_result jsonb;
begin
  if app_private.current_account_id() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_token is null or p_token !~ '^rlsa_[A-Za-z0-9_-]{32}$' then raise exception 'INVALID_OR_EXPIRED_INVITATION'; end if;
  select jsonb_build_object(
    'invitation_id',i.id,
    'learner_id',i.learner_id,
    'learner_name',l.display_name,
    'expires_at',i.expires_at
  ) into v_result
  from public.learner_self_access_invitations i
  join public.learners l on l.id=i.learner_id
  where i.token_hash=app_private.private_invite_hash(p_token)
    and i.state='active' and i.expires_at>now();
  if v_result is null then raise exception 'INVALID_OR_EXPIRED_INVITATION'; end if;
  return v_result;
end;
$$;

create or replace function app_private.cmd_issue_learner_self_access_invitation(
  p_learner_id uuid,p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.require_current_account(true);
  v_gate jsonb; v_fp text; v_token text; v_hash text; v_inv uuid; v_exp timestamptz;
  v_result jsonb; v_superseded int:=0;
begin
  if not (app_private.can_manage_learner(p_learner_id) or app_private.has_account_capability('platform_admin')) then
    raise exception 'NOT_AUTHORIZED';
  end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('learner_id',p_learner_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'issue_learner_self_access_invitation',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then
    return (v_gate->'result') || jsonb_build_object('invite_token',null,'secret_available',false,'idempotent_replay',true);
  end if;

  perform 1 from public.learners where id=p_learner_id for update;
  if not found then raise exception 'LEARNER_NOT_FOUND'; end if;
  if exists(select 1 from public.account_learner_access where learner_id=p_learner_id and access_type='self' and status='active') then
    raise exception 'ACTIVE_SELF_ACCESS_ALREADY_EXISTS';
  end if;

  update public.learner_self_access_invitations
  set state='expired'
  where learner_id=p_learner_id and state='active' and expires_at<=now();
  update public.learner_self_access_invitations
  set state='revoked',revoked_at=now()
  where learner_id=p_learner_id and state='active';
  get diagnostics v_superseded=row_count;

  v_token:=app_private.generate_private_invite_token('rlsa_');
  v_hash:=app_private.private_invite_hash(v_token);
  v_exp:=now()+app_private.learner_self_access_invitation_ttl();
  insert into public.learner_self_access_invitations(learner_id,issued_by_account_id,token_hash,expires_at)
  values(p_learner_id,v_actor,v_hash,v_exp) returning id into v_inv;

  perform app_private.write_audit(v_actor,'learner.self_access_invitation_issue','learner_self_access_invitation',v_inv,p_learner_id,null,
    jsonb_build_object('expires_at',v_exp,'superseded_active_count',v_superseded));
  v_result:=jsonb_build_object('invitation_id',v_inv,'learner_id',p_learner_id,'state','active','expires_at',v_exp);
  perform app_private.complete_human_idempotent_command(v_actor,'issue_learner_self_access_invitation',p_idempotency_key,v_result);
  return v_result || jsonb_build_object('invite_token',v_token,'secret_available',true,'idempotent_replay',false);
end;
$$;

create or replace function app_private.cmd_revoke_learner_self_access_invitation(
  p_invitation_id uuid,p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.require_current_account(false);
  v_gate jsonb; v_fp text; v_learner uuid; v_state text; v_exp timestamptz; v_result jsonb;
begin
  v_fp:=app_private.request_fingerprint(jsonb_build_object('invitation_id',p_invitation_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'revoke_learner_self_access_invitation',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select learner_id,state,expires_at into v_learner,v_state,v_exp
  from public.learner_self_access_invitations where id=p_invitation_id for update;
  if not found then raise exception 'INVITATION_NOT_FOUND_OR_NOT_AUTHORIZED'; end if;
  if not app_private.can_revoke_learner_self_access_invitation(v_learner) then raise exception 'INVITATION_NOT_FOUND_OR_NOT_AUTHORIZED'; end if;

  if v_state='active' and v_exp<=now() then
    update public.learner_self_access_invitations set state='expired' where id=p_invitation_id;
    v_result:=jsonb_build_object('invitation_id',p_invitation_id,'state','expired','revoked',false,'already_terminal',true);
  elsif v_state='active' then
    update public.learner_self_access_invitations set state='revoked',revoked_at=now() where id=p_invitation_id;
    perform app_private.write_audit(v_actor,'learner.self_access_invitation_revoke','learner_self_access_invitation',p_invitation_id,v_learner,null,'{}'::jsonb);
    v_result:=jsonb_build_object('invitation_id',p_invitation_id,'state','revoked','revoked',true,'already_revoked',false);
  elsif v_state='revoked' then
    v_result:=jsonb_build_object('invitation_id',p_invitation_id,'state','revoked','revoked',true,'already_revoked',true);
  else
    v_result:=jsonb_build_object('invitation_id',p_invitation_id,'state',v_state,'revoked',false,'already_terminal',true);
  end if;
  perform app_private.complete_human_idempotent_command(v_actor,'revoke_learner_self_access_invitation',p_idempotency_key,v_result);
  return v_result;
end;
$$;

create or replace function app_private.cmd_accept_learner_self_access_invitation(
  p_token text,p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.require_current_account(true);
  v_gate jsonb; v_fp text; v_inv uuid; v_learner uuid; v_issuer uuid; v_exp timestamptz;
  v_manager uuid; v_existing_id uuid; v_existing_account uuid; v_access uuid; v_result jsonb;
begin
  if p_token is null or p_token !~ '^rlsa_[A-Za-z0-9_-]{32}$' then raise exception 'INVALID_OR_EXPIRED_INVITATION'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('token_hash',app_private.private_invite_hash(p_token)));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'accept_learner_self_access_invitation',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select invitation_id,learner_id,issued_by_account_id,expires_at into v_inv,v_learner,v_issuer,v_exp
  from app_private.resolve_active_learner_self_access_invitation(p_token);
  if v_inv is null then raise exception 'INVALID_OR_EXPIRED_INVITATION'; end if;

  perform 1 from public.learners where id=v_learner for update;
  select account_id into v_manager from public.account_learner_access
  where learner_id=v_learner and access_type='manage' and status='active' limit 1;
  if v_manager=v_actor then raise exception 'TARGET_IS_ACTIVE_MANAGER'; end if;

  if not (
    v_manager=v_issuer
    or exists(select 1 from public.account_capabilities ac join public.accounts a on a.id=ac.account_id
      where ac.account_id=v_issuer and ac.capability_code='platform_admin' and ac.status='active' and a.lifecycle_status='active')
  ) then raise exception 'INVITER_NO_LONGER_AUTHORIZED'; end if;

  select id,account_id into v_existing_id,v_existing_account
  from public.account_learner_access
  where learner_id=v_learner and access_type='self' and status='active'
  limit 1;
  if v_existing_id is not null and v_existing_account<>v_actor then raise exception 'ACTIVE_SELF_ACCESS_ALREADY_EXISTS'; end if;

  if v_existing_id is null then
    insert into public.account_learner_access(account_id,learner_id,access_type)
    values(v_actor,v_learner,'self') returning id into v_access;
  else
    v_access:=v_existing_id;
  end if;

  update public.learner_self_access_invitations
  set state='accepted',accepted_by_account_id=v_actor,accepted_at=now()
  where id=v_inv and state='active';
  if not found then raise exception 'INVITATION_ACCEPT_RACE_LOST'; end if;

  perform app_private.write_audit(v_actor,'learner.self_access_invitation_accept','learner_self_access_invitation',v_inv,v_learner,null,
    jsonb_build_object('issued_by_account_id',v_issuer,'access_id',v_access));
  v_result:=jsonb_build_object('invitation_id',v_inv,'learner_id',v_learner,'access_id',v_access,'state','accepted','already_active',v_existing_id is not null);
  perform app_private.complete_human_idempotent_command(v_actor,'accept_learner_self_access_invitation',p_idempotency_key,v_result);
  return v_result;
end;
$$;

revoke all on function app_private.private_invite_hash(text),app_private.generate_private_invite_token(text),
  app_private.learner_self_access_invitation_ttl(),app_private.can_revoke_learner_self_access_invitation(uuid),
  app_private.resolve_active_learner_self_access_invitation(text),app_private.read_learner_self_access_invitation_preview(text),
  app_private.cmd_issue_learner_self_access_invitation(uuid,text),app_private.cmd_revoke_learner_self_access_invitation(uuid,text),
  app_private.cmd_accept_learner_self_access_invitation(text,text)
from public,anon,authenticated,service_role;

grant execute on function app_private.read_learner_self_access_invitation_preview(text),
  app_private.cmd_issue_learner_self_access_invitation(uuid,text),app_private.cmd_revoke_learner_self_access_invitation(uuid,text),
  app_private.cmd_accept_learner_self_access_invitation(text,text) to authenticated;

create or replace function public.issue_learner_self_access_invitation(p_learner_id uuid,p_idempotency_key text)
returns jsonb language sql security invoker set search_path=''
as $$ select app_private.cmd_issue_learner_self_access_invitation(p_learner_id,p_idempotency_key); $$;
create or replace function public.revoke_learner_self_access_invitation(p_invitation_id uuid,p_idempotency_key text)
returns jsonb language sql security invoker set search_path=''
as $$ select app_private.cmd_revoke_learner_self_access_invitation(p_invitation_id,p_idempotency_key); $$;
create or replace function public.accept_learner_self_access_invitation(p_token text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path=''
as $$ select app_private.cmd_accept_learner_self_access_invitation(p_token,p_idempotency_key); $$;
create or replace function public.get_learner_self_access_invitation_preview(p_token text)
returns jsonb language sql stable security invoker set search_path=''
as $$ select app_private.read_learner_self_access_invitation_preview(p_token); $$;

revoke all on function public.issue_learner_self_access_invitation(uuid,text),public.revoke_learner_self_access_invitation(uuid,text),
  public.accept_learner_self_access_invitation(text,text),public.get_learner_self_access_invitation_preview(text)
from public,anon,authenticated,service_role;
grant execute on function public.issue_learner_self_access_invitation(uuid,text),public.revoke_learner_self_access_invitation(uuid,text),
  public.accept_learner_self_access_invitation(text,text),public.get_learner_self_access_invitation_preview(text) to authenticated;
