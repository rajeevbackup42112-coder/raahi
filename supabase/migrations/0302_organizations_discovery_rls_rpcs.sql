-- Raahi Learning V1.2 — Organization authority and canonical membership commands

create or replace function app_private.has_organization_member_capability(p_organization_id uuid,p_capability_code text)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.organization_members om
    join public.organization_member_capabilities c on c.organization_member_id=om.id
    join public.accounts a on a.id=om.account_id
    join public.organizations o on o.id=om.organization_id
    where om.organization_id=p_organization_id
      and om.account_id=app_private.current_account_id()
      and om.status='active' and c.capability_code=p_capability_code
      and a.lifecycle_status='active' and o.status<>'closed'
  );
$$;

create or replace function app_private.is_active_organization_member(p_organization_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.organization_members om
    join public.accounts a on a.id=om.account_id
    where om.organization_id=p_organization_id
      and om.account_id=app_private.current_account_id()
      and om.status='active' and a.lifecycle_status<>'closed'
  );
$$;

create or replace function app_private.can_read_organization_member(p_member_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.organization_members target
    where target.id=p_member_id
      and (app_private.is_active_organization_member(target.organization_id)
           or app_private.has_account_capability('platform_admin'))
  );
$$;

create or replace function app_private.write_organization_audit(
  p_actor_account_id uuid,p_action_type text,p_organization_id uuid,p_target_type text,
  p_target_id uuid default null,p_reason text default null,p_metadata jsonb default '{}'::jsonb
)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
  insert into public.audit_log(actor_kind,actor_account_id,action_type,target_type,target_id,organization_id,reason,metadata)
  values('account',p_actor_account_id,p_action_type,p_target_type,p_target_id,p_organization_id,p_reason,coalesce(p_metadata,'{}'::jsonb))
  returning id into v_id;
  return v_id;
end; $$;

create or replace function app_private.cmd_create_organization(
  p_organization_type text,p_name text,p_description text,p_public_contact_text text,p_venue_text text,
  p_website_url text,p_logo_type text,p_logo_ref text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_org uuid; v_member uuid; v_result jsonb;
begin
  if p_organization_type not in ('school','university','college','coaching','academy','other_education') then raise exception 'INVALID_ORGANIZATION_TYPE'; end if;
  if p_name is null or char_length(btrim(p_name)) not between 1 and 160 then raise exception 'INVALID_ORGANIZATION_NAME'; end if;
  if p_logo_type not in ('builtin','upload','none') then raise exception 'INVALID_LOGO_TYPE'; end if;
  if (p_logo_type='none' and p_logo_ref is not null) or (p_logo_type in ('builtin','upload') and p_logo_ref is null) then raise exception 'INVALID_LOGO_REFERENCE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('organization_type',p_organization_type,'name',p_name,'description',p_description,
    'public_contact_text',p_public_contact_text,'venue_text',p_venue_text,'website_url',p_website_url,'logo_type',p_logo_type,'logo_ref',p_logo_ref));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'create_organization',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.organizations(organization_type,name,description,public_contact_text,venue_text,website_url,logo_type,logo_ref,created_by_account_id)
  values(p_organization_type,btrim(p_name),nullif(btrim(p_description),''),nullif(btrim(p_public_contact_text),''),nullif(btrim(p_venue_text),''),
    nullif(btrim(p_website_url),''),p_logo_type,p_logo_ref,v_actor) returning id into v_org;
  insert into public.organization_members(organization_id,account_id) values(v_org,v_actor) returning id into v_member;
  insert into public.organization_member_capabilities(organization_member_id,capability_code)
  select v_member,x from unnest(array['manage_profile','manage_teaching_options','manage_classes','manage_ads','manage_members']::text[]) x;
  perform app_private.write_organization_audit(v_actor,'organization.create',v_org,'organization',v_org,null,
    jsonb_build_object('creator_member_id',v_member,'organization_type',p_organization_type));
  v_result:=jsonb_build_object('organization_id',v_org,'member_id',v_member,'status','active');
  perform app_private.complete_human_idempotent_command(v_actor,'create_organization',p_idempotency_key,v_result);
  return v_result;
end; $$;

create or replace function app_private.cmd_update_organization_profile(
  p_organization_id uuid,p_name text,p_description text,p_public_contact_text text,p_venue_text text,
  p_website_url text,p_logo_type text,p_logo_ref text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_result jsonb;
begin
  if not app_private.has_organization_member_capability(p_organization_id,'manage_profile')
     and not app_private.has_account_capability('platform_admin') then raise exception 'NOT_AUTHORIZED'; end if;
  if p_name is null or char_length(btrim(p_name)) not between 1 and 160 then raise exception 'INVALID_ORGANIZATION_NAME'; end if;
  if p_logo_type not in ('builtin','upload','none') then raise exception 'INVALID_LOGO_TYPE'; end if;
  if (p_logo_type='none' and p_logo_ref is not null) or (p_logo_type in ('builtin','upload') and p_logo_ref is null) then raise exception 'INVALID_LOGO_REFERENCE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('organization_id',p_organization_id,'name',p_name,'description',p_description,
    'public_contact_text',p_public_contact_text,'venue_text',p_venue_text,'website_url',p_website_url,'logo_type',p_logo_type,'logo_ref',p_logo_ref));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'update_organization_profile',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  update public.organizations set name=btrim(p_name),description=nullif(btrim(p_description),''),public_contact_text=nullif(btrim(p_public_contact_text),''),
    venue_text=nullif(btrim(p_venue_text),''),website_url=nullif(btrim(p_website_url),''),logo_type=p_logo_type,logo_ref=p_logo_ref
  where id=p_organization_id and status<>'closed';
  if not found then raise exception 'ORGANIZATION_NOT_FOUND_OR_CLOSED'; end if;
  v_result:=jsonb_build_object('organization_id',p_organization_id,'updated',true);
  perform app_private.complete_human_idempotent_command(v_actor,'update_organization_profile',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_add_organization_member(p_organization_id uuid,p_target_account_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_member uuid; v_target_status text; v_result jsonb;
begin
  if not app_private.has_organization_member_capability(p_organization_id,'manage_members')
     and not app_private.has_account_capability('platform_admin') then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('organization_id',p_organization_id,'target_account_id',p_target_account_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'add_organization_member',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  perform 1 from public.organizations where id=p_organization_id and status<>'closed' for update;
  if not found then raise exception 'ORGANIZATION_NOT_FOUND_OR_CLOSED'; end if;
  select lifecycle_status into v_target_status from public.accounts where id=p_target_account_id;
  if not found or v_target_status<>'active' then raise exception 'TARGET_ACCOUNT_NOT_ELIGIBLE'; end if;
  select id into v_member from public.organization_members where organization_id=p_organization_id and account_id=p_target_account_id and status='active' limit 1;
  if v_member is null then
    insert into public.organization_members(organization_id,account_id) values(p_organization_id,p_target_account_id) returning id into v_member;
    perform app_private.write_organization_audit(v_actor,'organization.member_add',p_organization_id,'organization_member',v_member,null,jsonb_build_object('target_account_id',p_target_account_id));
    v_result:=jsonb_build_object('member_id',v_member,'already_active',false);
  else v_result:=jsonb_build_object('member_id',v_member,'already_active',true); end if;
  perform app_private.complete_human_idempotent_command(v_actor,'add_organization_member',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_set_organization_member_capability(
  p_organization_member_id uuid,p_capability_code text,p_enabled boolean,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_org uuid; v_status text; v_rows integer:=0; v_result jsonb;
begin
  if p_capability_code not in ('manage_profile','manage_teaching_options','manage_classes','manage_ads','manage_members') then raise exception 'INVALID_ORGANIZATION_CAPABILITY'; end if;
  select organization_id,status into v_org,v_status from public.organization_members where id=p_organization_member_id for update;
  if not found then raise exception 'ORGANIZATION_MEMBER_NOT_FOUND'; end if;
  if not app_private.has_organization_member_capability(v_org,'manage_members')
     and not app_private.has_account_capability('platform_admin') then raise exception 'NOT_AUTHORIZED'; end if;
  if v_status<>'active' then raise exception 'ORGANIZATION_MEMBER_NOT_ACTIVE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('organization_member_id',p_organization_member_id,'capability_code',p_capability_code,'enabled',p_enabled));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'set_organization_member_capability',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if p_enabled then
    insert into public.organization_member_capabilities(organization_member_id,capability_code) values(p_organization_member_id,p_capability_code) on conflict do nothing;
    get diagnostics v_rows=row_count;
  else
    if p_capability_code='manage_members' and not app_private.has_account_capability('platform_admin') and not exists(
      select 1 from public.organization_members om join public.organization_member_capabilities c on c.organization_member_id=om.id
      where om.organization_id=v_org and om.status='active' and om.id<>p_organization_member_id and c.capability_code='manage_members')
    then raise exception 'ORGANIZATION_MUST_RETAIN_MANAGER'; end if;
    delete from public.organization_member_capabilities where organization_member_id=p_organization_member_id and capability_code=p_capability_code;
    get diagnostics v_rows=row_count;
  end if;
  if v_rows>0 then perform app_private.write_organization_audit(v_actor,'organization.member_capability_change',v_org,'organization_member',p_organization_member_id,null,
    jsonb_build_object('capability_code',p_capability_code,'enabled',p_enabled)); end if;
  v_result:=jsonb_build_object('member_id',p_organization_member_id,'capability_code',p_capability_code,'enabled',p_enabled,'changed',v_rows>0);
  perform app_private.complete_human_idempotent_command(v_actor,'set_organization_member_capability',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_remove_organization_member(p_organization_member_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_org uuid; v_status text; v_account uuid; v_result jsonb;
begin
  select organization_id,status,account_id into v_org,v_status,v_account from public.organization_members where id=p_organization_member_id for update;
  if not found then raise exception 'ORGANIZATION_MEMBER_NOT_FOUND'; end if;
  if not app_private.has_organization_member_capability(v_org,'manage_members')
     and not app_private.has_account_capability('platform_admin') then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('organization_member_id',p_organization_member_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'remove_organization_member',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if v_status='ended' then v_result:=jsonb_build_object('member_id',p_organization_member_id,'already_ended',true);
  else
    if not app_private.has_account_capability('platform_admin') and exists(select 1 from public.organization_member_capabilities where organization_member_id=p_organization_member_id and capability_code='manage_members')
       and not exists(select 1 from public.organization_members om join public.organization_member_capabilities c on c.organization_member_id=om.id
         where om.organization_id=v_org and om.status='active' and om.id<>p_organization_member_id and c.capability_code='manage_members')
    then raise exception 'ORGANIZATION_MUST_RETAIN_MANAGER'; end if;
    update public.organization_members set status='ended',ended_at=now() where id=p_organization_member_id;
    perform app_private.write_organization_audit(v_actor,'organization.member_remove',v_org,'organization_member',p_organization_member_id,null,jsonb_build_object('account_id',v_account));
    v_result:=jsonb_build_object('member_id',p_organization_member_id,'already_ended',false);
  end if;
  perform app_private.complete_human_idempotent_command(v_actor,'remove_organization_member',p_idempotency_key,v_result); return v_result;
end; $$;
