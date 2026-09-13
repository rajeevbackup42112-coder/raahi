-- Raahi Learning V1.3 — private Organization staff invitations
-- Replaces raw Account UUID entry with expiring bearer links while preserving the existing
-- Organization membership/capability model and manage_members authority boundary.

create table public.organization_member_invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  issued_by_account_id uuid not null references public.accounts(id),
  token_hash text not null unique,
  capability_codes text[] not null,
  state text not null default 'active',
  expires_at timestamptz not null,
  accepted_by_account_id uuid null references public.accounts(id),
  accepted_at timestamptz null,
  revoked_at timestamptz null,
  created_at timestamptz not null default now(),
  constraint organization_member_invite_hash_format check (token_hash ~ '^[0-9a-f]{64}$'),
  constraint organization_member_invite_capabilities_nonempty check (cardinality(capability_codes) between 1 and 5),
  constraint organization_member_invite_capabilities_allowed check (
    capability_codes <@ array['manage_profile','manage_teaching_options','manage_classes','manage_ads','manage_members']::text[]
  ),
  constraint organization_member_invite_state_check check (state in ('active','accepted','revoked','expired')),
  constraint organization_member_invite_expiry_after_creation check (expires_at > created_at),
  constraint organization_member_invite_terminal_consistency check (
    (state='active' and accepted_by_account_id is null and accepted_at is null and revoked_at is null)
    or (state='accepted' and accepted_by_account_id is not null and accepted_at is not null and revoked_at is null)
    or (state='revoked' and accepted_by_account_id is null and accepted_at is null and revoked_at is not null)
    or (state='expired' and accepted_by_account_id is null and accepted_at is null and revoked_at is null)
  )
);

create index organization_member_invite_org_state_idx
  on public.organization_member_invitations(organization_id,state,created_at desc);
create index organization_member_invite_expiry_idx
  on public.organization_member_invitations(expires_at)
  where state='active';
create index organization_member_invite_issuer_idx
  on public.organization_member_invitations(issued_by_account_id,created_at desc);

alter table public.organization_member_invitations enable row level security;
alter table public.organization_member_invitations force row level security;
create policy organization_member_invitations_deny_authenticated
  on public.organization_member_invitations for all to authenticated
  using(false) with check(false);
revoke all on table public.organization_member_invitations from public,anon,authenticated,service_role;

create or replace function app_private.organization_member_invitation_ttl()
returns interval language sql immutable set search_path=''
as $$ select interval '7 days'; $$;

create or replace function app_private.organization_account_has_capability(
  p_account_id uuid,p_organization_id uuid,p_capability_code text
)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select exists(
    select 1
    from public.organization_members om
    join public.organization_member_capabilities c on c.organization_member_id=om.id
    join public.accounts a on a.id=om.account_id
    where om.organization_id=p_organization_id
      and om.account_id=p_account_id
      and om.status='active'
      and a.lifecycle_status='active'
      and c.capability_code=p_capability_code
  );
$$;

create or replace function app_private.account_has_active_platform_admin(p_account_id uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select exists(
    select 1 from public.account_capabilities ac
    join public.accounts a on a.id=ac.account_id
    where ac.account_id=p_account_id
      and ac.capability_code='platform_admin'
      and ac.status='active'
      and a.lifecycle_status='active'
  );
$$;

create or replace function app_private.resolve_active_organization_member_invitation(p_token text)
returns table(invitation_id uuid,organization_id uuid,issued_by_account_id uuid,capability_codes text[],expires_at timestamptz)
language plpgsql
volatile
security definer
set search_path=''
as $$
declare v_hash text;
begin
  if p_token is null or p_token !~ '^rloi_[A-Za-z0-9_-]{32}$' then return; end if;
  v_hash:=app_private.private_invite_hash(p_token);
  return query
  select i.id,i.organization_id,i.issued_by_account_id,i.capability_codes,i.expires_at
  from public.organization_member_invitations i
  where i.token_hash=v_hash and i.state='active' and i.expires_at>now()
  for update;
end;
$$;

create or replace function app_private.read_organization_member_invitation_preview(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_result jsonb;
begin
  if app_private.current_account_id() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_token is null or p_token !~ '^rloi_[A-Za-z0-9_-]{32}$' then raise exception 'INVALID_OR_EXPIRED_INVITATION'; end if;
  select jsonb_build_object(
    'invitation_id',i.id,
    'organization_id',i.organization_id,
    'organization_name',o.name,
    'organization_type',o.organization_type,
    'capability_codes',i.capability_codes,
    'expires_at',i.expires_at
  ) into v_result
  from public.organization_member_invitations i
  join public.organizations o on o.id=i.organization_id
  where i.token_hash=app_private.private_invite_hash(p_token)
    and i.state='active' and i.expires_at>now() and o.status<>'closed';
  if v_result is null then raise exception 'INVALID_OR_EXPIRED_INVITATION'; end if;
  return v_result;
end;
$$;

create or replace function app_private.read_organization_member_invitations(p_organization_id uuid)
returns setof jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if not (app_private.has_organization_member_capability(p_organization_id,'manage_members') or app_private.has_account_capability('platform_admin')) then
    raise exception 'NOT_AUTHORIZED';
  end if;
  return query
  select jsonb_build_object(
    'invitation_id',i.id,
    'state',case when i.state='active' and i.expires_at<=now() then 'expired' else i.state end,
    'capability_codes',i.capability_codes,
    'expires_at',i.expires_at,
    'created_at',i.created_at,
    'accepted_at',i.accepted_at,
    'revoked_at',i.revoked_at
  )
  from public.organization_member_invitations i
  where i.organization_id=p_organization_id
  order by i.created_at desc,i.id;
end;
$$;

create or replace function app_private.cmd_issue_organization_member_invitation(
  p_organization_id uuid,p_capability_codes text[],p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.require_current_account(true);
  v_caps text[]; v_bad int; v_gate jsonb; v_fp text; v_token text; v_inv uuid; v_exp timestamptz; v_result jsonb;
begin
  if not (app_private.has_organization_member_capability(p_organization_id,'manage_members') or app_private.has_account_capability('platform_admin')) then
    raise exception 'NOT_AUTHORIZED';
  end if;
  select array_agg(distinct x order by x) into v_caps from unnest(coalesce(p_capability_codes,array[]::text[])) x;
  if coalesce(cardinality(v_caps),0)<1 then raise exception 'ORGANIZATION_INVITATION_CAPABILITY_REQUIRED'; end if;
  select count(*) into v_bad from unnest(v_caps) x where x not in ('manage_profile','manage_teaching_options','manage_classes','manage_ads','manage_members');
  if v_bad>0 then raise exception 'INVALID_ORGANIZATION_CAPABILITY'; end if;

  v_fp:=app_private.request_fingerprint(jsonb_build_object('organization_id',p_organization_id,'capability_codes',v_caps));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'issue_organization_member_invitation',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then
    return (v_gate->'result') || jsonb_build_object('invite_token',null,'secret_available',false,'idempotent_replay',true);
  end if;

  perform 1 from public.organizations where id=p_organization_id and status<>'closed' for update;
  if not found then raise exception 'ORGANIZATION_NOT_FOUND_OR_CLOSED'; end if;
  v_token:=app_private.generate_private_invite_token('rloi_');
  v_exp:=now()+app_private.organization_member_invitation_ttl();
  insert into public.organization_member_invitations(organization_id,issued_by_account_id,token_hash,capability_codes,expires_at)
  values(p_organization_id,v_actor,app_private.private_invite_hash(v_token),v_caps,v_exp) returning id into v_inv;

  perform app_private.write_organization_audit(v_actor,'organization.member_invitation_issue',p_organization_id,'organization_member_invitation',v_inv,null,
    jsonb_build_object('capability_codes',v_caps,'expires_at',v_exp));
  v_result:=jsonb_build_object('invitation_id',v_inv,'organization_id',p_organization_id,'state','active','capability_codes',v_caps,'expires_at',v_exp);
  perform app_private.complete_human_idempotent_command(v_actor,'issue_organization_member_invitation',p_idempotency_key,v_result);
  return v_result || jsonb_build_object('invite_token',v_token,'secret_available',true,'idempotent_replay',false);
end;
$$;

create or replace function app_private.cmd_revoke_organization_member_invitation(
  p_invitation_id uuid,p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.require_current_account(true);
  v_gate jsonb; v_fp text; v_org uuid; v_state text; v_exp timestamptz; v_result jsonb;
begin
  v_fp:=app_private.request_fingerprint(jsonb_build_object('invitation_id',p_invitation_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'revoke_organization_member_invitation',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select organization_id,state,expires_at into v_org,v_state,v_exp
  from public.organization_member_invitations where id=p_invitation_id for update;
  if not found then raise exception 'INVITATION_NOT_FOUND_OR_NOT_AUTHORIZED'; end if;
  if not (app_private.has_organization_member_capability(v_org,'manage_members') or app_private.has_account_capability('platform_admin')) then
    raise exception 'INVITATION_NOT_FOUND_OR_NOT_AUTHORIZED';
  end if;
  if v_state='active' and v_exp<=now() then
    update public.organization_member_invitations set state='expired' where id=p_invitation_id;
    v_result:=jsonb_build_object('invitation_id',p_invitation_id,'state','expired','revoked',false,'already_terminal',true);
  elsif v_state='active' then
    update public.organization_member_invitations set state='revoked',revoked_at=now() where id=p_invitation_id;
    perform app_private.write_organization_audit(v_actor,'organization.member_invitation_revoke',v_org,'organization_member_invitation',p_invitation_id,null,'{}'::jsonb);
    v_result:=jsonb_build_object('invitation_id',p_invitation_id,'state','revoked','revoked',true,'already_revoked',false);
  elsif v_state='revoked' then
    v_result:=jsonb_build_object('invitation_id',p_invitation_id,'state','revoked','revoked',true,'already_revoked',true);
  else
    v_result:=jsonb_build_object('invitation_id',p_invitation_id,'state',v_state,'revoked',false,'already_terminal',true);
  end if;
  perform app_private.complete_human_idempotent_command(v_actor,'revoke_organization_member_invitation',p_idempotency_key,v_result);
  return v_result;
end;
$$;

create or replace function app_private.cmd_accept_organization_member_invitation(
  p_token text,p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.require_current_account(true);
  v_gate jsonb; v_fp text; v_inv uuid; v_org uuid; v_issuer uuid; v_caps text[]; v_exp timestamptz;
  v_member uuid; v_existing boolean:=false; v_result jsonb;
begin
  if p_token is null or p_token !~ '^rloi_[A-Za-z0-9_-]{32}$' then raise exception 'INVALID_OR_EXPIRED_INVITATION'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('token_hash',app_private.private_invite_hash(p_token)));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'accept_organization_member_invitation',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select invitation_id,organization_id,issued_by_account_id,capability_codes,expires_at into v_inv,v_org,v_issuer,v_caps,v_exp
  from app_private.resolve_active_organization_member_invitation(p_token);
  if v_inv is null then raise exception 'INVALID_OR_EXPIRED_INVITATION'; end if;

  perform 1 from public.organizations where id=v_org and status<>'closed' for update;
  if not found then raise exception 'ORGANIZATION_NOT_FOUND_OR_CLOSED'; end if;
  if not (app_private.organization_account_has_capability(v_issuer,v_org,'manage_members') or app_private.account_has_active_platform_admin(v_issuer)) then
    raise exception 'INVITER_NO_LONGER_AUTHORIZED';
  end if;

  select id into v_member from public.organization_members
  where organization_id=v_org and account_id=v_actor and status='active' limit 1;
  if v_member is null then
    insert into public.organization_members(organization_id,account_id) values(v_org,v_actor) returning id into v_member;
  else
    v_existing:=true;
  end if;

  insert into public.organization_member_capabilities(organization_member_id,capability_code)
  select v_member,x from unnest(v_caps) x
  on conflict do nothing;

  update public.organization_member_invitations
  set state='accepted',accepted_by_account_id=v_actor,accepted_at=now()
  where id=v_inv and state='active';
  if not found then raise exception 'INVITATION_ACCEPT_RACE_LOST'; end if;

  perform app_private.write_organization_audit(v_actor,'organization.member_invitation_accept',v_org,'organization_member',v_member,null,
    jsonb_build_object('invitation_id',v_inv,'issued_by_account_id',v_issuer,'capability_codes',v_caps));
  v_result:=jsonb_build_object('invitation_id',v_inv,'organization_id',v_org,'member_id',v_member,'state','accepted','capability_codes',v_caps,'already_member',v_existing);
  perform app_private.complete_human_idempotent_command(v_actor,'accept_organization_member_invitation',p_idempotency_key,v_result);
  return v_result;
end;
$$;

revoke all on function app_private.organization_member_invitation_ttl(),app_private.organization_account_has_capability(uuid,uuid,text),
  app_private.account_has_active_platform_admin(uuid),app_private.resolve_active_organization_member_invitation(text),
  app_private.read_organization_member_invitation_preview(text),app_private.read_organization_member_invitations(uuid),
  app_private.cmd_issue_organization_member_invitation(uuid,text[],text),app_private.cmd_revoke_organization_member_invitation(uuid,text),
  app_private.cmd_accept_organization_member_invitation(text,text)
from public,anon,authenticated,service_role;

grant execute on function app_private.read_organization_member_invitation_preview(text),app_private.read_organization_member_invitations(uuid),
  app_private.cmd_issue_organization_member_invitation(uuid,text[],text),app_private.cmd_revoke_organization_member_invitation(uuid,text),
  app_private.cmd_accept_organization_member_invitation(text,text) to authenticated;

create or replace function public.issue_organization_member_invitation(p_organization_id uuid,p_capability_codes text[],p_idempotency_key text)
returns jsonb language sql security invoker set search_path=''
as $$ select app_private.cmd_issue_organization_member_invitation(p_organization_id,p_capability_codes,p_idempotency_key); $$;
create or replace function public.revoke_organization_member_invitation(p_invitation_id uuid,p_idempotency_key text)
returns jsonb language sql security invoker set search_path=''
as $$ select app_private.cmd_revoke_organization_member_invitation(p_invitation_id,p_idempotency_key); $$;
create or replace function public.accept_organization_member_invitation(p_token text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path=''
as $$ select app_private.cmd_accept_organization_member_invitation(p_token,p_idempotency_key); $$;
create or replace function public.get_organization_member_invitation_preview(p_token text)
returns jsonb language sql stable security invoker set search_path=''
as $$ select app_private.read_organization_member_invitation_preview(p_token); $$;
create or replace function public.get_organization_member_invitations(p_organization_id uuid)
returns setof jsonb language sql stable security invoker set search_path=''
as $$ select * from app_private.read_organization_member_invitations(p_organization_id); $$;

revoke all on function public.issue_organization_member_invitation(uuid,text[],text),public.revoke_organization_member_invitation(uuid,text),
  public.accept_organization_member_invitation(text,text),public.get_organization_member_invitation_preview(text),
  public.get_organization_member_invitations(uuid)
from public,anon,authenticated,service_role;
grant execute on function public.issue_organization_member_invitation(uuid,text[],text),public.revoke_organization_member_invitation(uuid,text),
  public.accept_organization_member_invitation(text,text),public.get_organization_member_invitation_preview(text),
  public.get_organization_member_invitations(uuid) to authenticated;
