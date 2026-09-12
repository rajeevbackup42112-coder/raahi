-- Raahi Learning V1.2 — Organization/teacher authority, discovery projections and canonical commands

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

create or replace function app_private.can_manage_teaching_option(p_teaching_option_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_teacher uuid; v_org uuid; v_actor uuid:=app_private.current_account_id();
begin
  select teacher_account_id,organization_id into v_teacher,v_org
  from public.teaching_options where id=p_teaching_option_id;
  if not found or v_actor is null then return false; end if;
  if app_private.has_account_capability('platform_admin') then return true; end if;
  if v_teacher is not null then
    return v_teacher=v_actor and app_private.has_account_capability('teach');
  end if;
  return app_private.has_organization_member_capability(v_org,'manage_teaching_options');
end; $$;

create or replace function app_private.is_teaching_option_public(p_teaching_option_id uuid,p_require_taking boolean default false)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1
    from public.teaching_options t
    join public.teaching_option_locations tol on tol.teaching_option_id=t.id
    join public.locations l on l.id=tol.location_id and l.state='live'
    left join public.teacher_profiles tp on tp.account_id=t.teacher_account_id
    left join public.accounts ta on ta.id=t.teacher_account_id
    left join public.organizations o on o.id=t.organization_id
    where t.id=p_teaching_option_id
      and t.availability_status<>'no_longer_offered'
      and (not p_require_taking or t.availability_status='taking_new_learners')
      and (
        (t.teacher_account_id is not null and tp.visibility_status='visible' and ta.lifecycle_status='active')
        or (t.organization_id is not null and o.status='active')
      )
  );
$$;

create or replace function app_private.cmd_create_organization(
  p_organization_type text,p_name text,p_description text,p_public_contact_text text,p_venue_text text,
  p_website_url text,p_logo_type text,p_logo_ref text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_org uuid; v_member uuid; v_result jsonb;
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
  values(p_organization_type,btrim(p_name),nullif(btrim(p_description),''),nullif(btrim(p_public_contact_text),''),
    nullif(btrim(p_venue_text),''),nullif(btrim(p_website_url),''),p_logo_type,p_logo_ref,v_actor) returning id into v_org;
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
  update public.organizations set name=btrim(p_name),description=nullif(btrim(p_description),''),
    public_contact_text=nullif(btrim(p_public_contact_text),''),venue_text=nullif(btrim(p_venue_text),''),
    website_url=nullif(btrim(p_website_url),''),logo_type=p_logo_type,logo_ref=p_logo_ref
  where id=p_organization_id and status<>'closed';
  if not found then raise exception 'ORGANIZATION_NOT_FOUND_OR_CLOSED'; end if;
  v_result:=jsonb_build_object('organization_id',p_organization_id,'updated',true);
  perform app_private.complete_human_idempotent_command(v_actor,'update_organization_profile',p_idempotency_key,v_result);
  return v_result;
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
      where om.organization_id=v_org and om.status='active' and om.id<>p_organization_member_id and c.capability_code='manage_members'
    ) then raise exception 'ORGANIZATION_MUST_RETAIN_MANAGER'; end if;
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

create or replace function app_private.cmd_upsert_teacher_profile(p_headline text,p_bio text,p_experience_summary text,p_visibility_status text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_result jsonb;
begin
  if not app_private.has_account_capability('teach') then raise exception 'TEACH_CAPABILITY_REQUIRED'; end if;
  if p_visibility_status not in ('visible','hidden') then raise exception 'INVALID_VISIBILITY'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('headline',p_headline,'bio',p_bio,'experience_summary',p_experience_summary,'visibility_status',p_visibility_status));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'upsert_teacher_profile',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.teacher_profiles(account_id,headline,bio,experience_summary,visibility_status)
  values(v_actor,nullif(btrim(p_headline),''),nullif(btrim(p_bio),''),nullif(btrim(p_experience_summary),''),p_visibility_status)
  on conflict(account_id) do update set headline=excluded.headline,bio=excluded.bio,experience_summary=excluded.experience_summary,visibility_status=excluded.visibility_status;
  v_result:=jsonb_build_object('teacher_account_id',v_actor,'visibility_status',p_visibility_status);
  perform app_private.complete_human_idempotent_command(v_actor,'upsert_teacher_profile',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_publish_teaching_option(
  p_organization_id uuid,p_title text,p_category text,p_description text,p_teaching_mode text,
  p_area_or_venue_text text,p_fee_display_text text,p_location_ids uuid[],p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_option uuid; v_result jsonb; v_bad uuid;
begin
  if p_title is null or char_length(btrim(p_title)) not between 1 and 200 then raise exception 'INVALID_TEACHING_OPTION_TITLE'; end if;
  if p_teaching_mode not in ('online','in_person','both') then raise exception 'INVALID_TEACHING_MODE'; end if;
  if p_location_ids is null or cardinality(p_location_ids)=0 then raise exception 'AT_LEAST_ONE_LOCATION_REQUIRED'; end if;
  if p_organization_id is null then
    if not app_private.has_account_capability('teach') then raise exception 'TEACH_CAPABILITY_REQUIRED'; end if;
    if not exists(select 1 from public.teacher_profiles where account_id=v_actor) then raise exception 'TEACHER_PROFILE_REQUIRED'; end if;
  else
    if not app_private.has_organization_member_capability(p_organization_id,'manage_teaching_options') then raise exception 'NOT_AUTHORIZED'; end if;
    if not exists(select 1 from public.organizations where id=p_organization_id and status='active') then raise exception 'ORGANIZATION_NOT_ACTIVE'; end if;
  end if;
  select x into v_bad from unnest(p_location_ids) x left join public.locations l on l.id=x where l.id is null or l.state<>'live' limit 1;
  if v_bad is not null then raise exception 'TEACHING_LOCATION_NOT_LIVE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('organization_id',p_organization_id,'title',p_title,'category',p_category,'description',p_description,
    'teaching_mode',p_teaching_mode,'area_or_venue_text',p_area_or_venue_text,'fee_display_text',p_fee_display_text,'location_ids',to_jsonb(p_location_ids)));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'publish_teaching_option',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.teaching_options(teacher_account_id,organization_id,title,category,description,teaching_mode,area_or_venue_text,fee_display_text)
  values(case when p_organization_id is null then v_actor else null end,p_organization_id,btrim(p_title),nullif(btrim(p_category),''),nullif(btrim(p_description),''),
    p_teaching_mode,nullif(btrim(p_area_or_venue_text),''),nullif(btrim(p_fee_display_text),'')) returning id into v_option;
  insert into public.teaching_option_locations(teaching_option_id,location_id) select v_option,x from (select distinct unnest(p_location_ids) x) s;
  if p_organization_id is null then perform app_private.write_audit(v_actor,'teaching_option.publish','teaching_option',v_option,null,null,jsonb_build_object('owner_type','teacher'));
  else perform app_private.write_organization_audit(v_actor,'teaching_option.publish',p_organization_id,'teaching_option',v_option,null,jsonb_build_object('owner_type','organization')); end if;
  v_result:=jsonb_build_object('teaching_option_id',v_option,'availability_status','taking_new_learners');
  perform app_private.complete_human_idempotent_command(v_actor,'publish_teaching_option',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_update_teaching_option(
  p_teaching_option_id uuid,p_title text,p_category text,p_description text,p_teaching_mode text,p_area_or_venue_text text,p_fee_display_text text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_result jsonb;
begin
  if not app_private.can_manage_teaching_option(p_teaching_option_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if p_title is null or char_length(btrim(p_title)) not between 1 and 200 then raise exception 'INVALID_TEACHING_OPTION_TITLE'; end if;
  if p_teaching_mode not in ('online','in_person','both') then raise exception 'INVALID_TEACHING_MODE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('teaching_option_id',p_teaching_option_id,'title',p_title,'category',p_category,'description',p_description,
    'teaching_mode',p_teaching_mode,'area_or_venue_text',p_area_or_venue_text,'fee_display_text',p_fee_display_text));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'update_teaching_option',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  update public.teaching_options set title=btrim(p_title),category=nullif(btrim(p_category),''),description=nullif(btrim(p_description),''),teaching_mode=p_teaching_mode,
    area_or_venue_text=nullif(btrim(p_area_or_venue_text),''),fee_display_text=nullif(btrim(p_fee_display_text),'') where id=p_teaching_option_id;
  if not found then raise exception 'TEACHING_OPTION_NOT_FOUND'; end if;
  v_result:=jsonb_build_object('teaching_option_id',p_teaching_option_id,'updated',true);
  perform app_private.complete_human_idempotent_command(v_actor,'update_teaching_option',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_set_teaching_availability(p_teaching_option_id uuid,p_availability_status text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_old text; v_result jsonb;
begin
  if p_availability_status not in ('taking_new_learners','not_taking_new_learners','no_longer_offered') then raise exception 'INVALID_AVAILABILITY'; end if;
  if not app_private.can_manage_teaching_option(p_teaching_option_id) then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('teaching_option_id',p_teaching_option_id,'availability_status',p_availability_status));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'set_teaching_availability',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select availability_status into v_old from public.teaching_options where id=p_teaching_option_id for update;
  if not found then raise exception 'TEACHING_OPTION_NOT_FOUND'; end if;
  update public.teaching_options set availability_status=p_availability_status where id=p_teaching_option_id;
  v_result:=jsonb_build_object('teaching_option_id',p_teaching_option_id,'old_status',v_old,'availability_status',p_availability_status,'changed',v_old<>p_availability_status);
  perform app_private.complete_human_idempotent_command(v_actor,'set_teaching_availability',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_set_teaching_option_locations(p_teaching_option_id uuid,p_location_ids uuid[],p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_bad uuid; v_result jsonb;
begin
  if not app_private.can_manage_teaching_option(p_teaching_option_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if p_location_ids is null or cardinality(p_location_ids)=0 then raise exception 'AT_LEAST_ONE_LOCATION_REQUIRED'; end if;
  select x into v_bad from unnest(p_location_ids) x left join public.locations l on l.id=x where l.id is null or l.state<>'live' limit 1;
  if v_bad is not null then raise exception 'TEACHING_LOCATION_NOT_LIVE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('teaching_option_id',p_teaching_option_id,'location_ids',to_jsonb(p_location_ids)));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'set_teaching_option_locations',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  perform 1 from public.teaching_options where id=p_teaching_option_id for update;
  if not found then raise exception 'TEACHING_OPTION_NOT_FOUND'; end if;
  delete from public.teaching_option_locations where teaching_option_id=p_teaching_option_id;
  insert into public.teaching_option_locations(teaching_option_id,location_id) select p_teaching_option_id,x from (select distinct unnest(p_location_ids) x) s;
  v_result:=jsonb_build_object('teaching_option_id',p_teaching_option_id,'location_count',(select count(*) from public.teaching_option_locations where teaching_option_id=p_teaching_option_id));
  perform app_private.complete_human_idempotent_command(v_actor,'set_teaching_option_locations',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.set_saved_teacher_profile(p_teacher_account_id uuid,p_saved boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true);
begin
  if p_saved then
    if not exists(select 1 from public.teacher_profiles tp join public.accounts a on a.id=tp.account_id where tp.account_id=p_teacher_account_id and tp.visibility_status='visible' and a.lifecycle_status='active') then raise exception 'TEACHER_PROFILE_NOT_PUBLIC'; end if;
    insert into public.saved_teacher_profiles(account_id,teacher_account_id) values(v_actor,p_teacher_account_id) on conflict do nothing;
  else delete from public.saved_teacher_profiles where account_id=v_actor and teacher_account_id=p_teacher_account_id; end if;
  return jsonb_build_object('teacher_account_id',p_teacher_account_id,'saved',p_saved);
end; $$;

create or replace function app_private.set_saved_teaching_option(p_teaching_option_id uuid,p_saved boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true);
begin
  if p_saved and not app_private.is_teaching_option_public(p_teaching_option_id,false) then raise exception 'TEACHING_OPTION_NOT_PUBLIC'; end if;
  if p_saved then insert into public.saved_teaching_options(account_id,teaching_option_id) values(v_actor,p_teaching_option_id) on conflict do nothing;
  else delete from public.saved_teaching_options where account_id=v_actor and teaching_option_id=p_teaching_option_id; end if;
  return jsonb_build_object('teaching_option_id',p_teaching_option_id,'saved',p_saved);
end; $$;

create or replace function app_private.set_saved_organization(p_organization_id uuid,p_saved boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true);
begin
  if p_saved and not exists(select 1 from public.organizations where id=p_organization_id and status='active') then raise exception 'ORGANIZATION_NOT_PUBLIC'; end if;
  if p_saved then insert into public.saved_organizations(account_id,organization_id) values(v_actor,p_organization_id) on conflict do nothing;
  else delete from public.saved_organizations where account_id=v_actor and organization_id=p_organization_id; end if;
  return jsonb_build_object('organization_id',p_organization_id,'saved',p_saved);
end; $$;

-- RLS and least privilege.
alter table public.organizations enable row level security; alter table public.organizations force row level security;
alter table public.organization_members enable row level security; alter table public.organization_members force row level security;
alter table public.organization_member_capabilities enable row level security; alter table public.organization_member_capabilities force row level security;
alter table public.teacher_profiles enable row level security; alter table public.teacher_profiles force row level security;
alter table public.teaching_options enable row level security; alter table public.teaching_options force row level security;
alter table public.teaching_option_locations enable row level security; alter table public.teaching_option_locations force row level security;
alter table public.saved_teacher_profiles enable row level security; alter table public.saved_teacher_profiles force row level security;
alter table public.saved_teaching_options enable row level security; alter table public.saved_teaching_options force row level security;
alter table public.saved_organizations enable row level security; alter table public.saved_organizations force row level security;

create policy organizations_select_scope on public.organizations for select to authenticated
using(app_private.is_active_organization_member(id) or app_private.has_account_capability('platform_admin'));
create policy organization_members_select_scope on public.organization_members for select to authenticated
using(app_private.is_active_organization_member(organization_id) or app_private.has_account_capability('platform_admin'));
create policy organization_member_capabilities_select_scope on public.organization_member_capabilities for select to authenticated
using(app_private.can_read_organization_member(organization_member_id));
create policy teacher_profiles_select_own on public.teacher_profiles for select to authenticated
using(account_id=app_private.current_account_id() or app_private.has_account_capability('platform_admin'));
create policy teaching_options_select_owner on public.teaching_options for select to authenticated
using(app_private.can_manage_teaching_option(id));
create policy teaching_option_locations_select_owner on public.teaching_option_locations for select to authenticated
using(app_private.can_manage_teaching_option(teaching_option_id));
create policy saved_teacher_profiles_select_own on public.saved_teacher_profiles for select to authenticated using(account_id=app_private.current_account_id());
create policy saved_teaching_options_select_own on public.saved_teaching_options for select to authenticated using(account_id=app_private.current_account_id());
create policy saved_organizations_select_own on public.saved_organizations for select to authenticated using(account_id=app_private.current_account_id());

revoke all on table public.organizations,public.organization_members,public.organization_member_capabilities,public.teacher_profiles,public.teaching_options,
  public.teaching_option_locations,public.saved_teacher_profiles,public.saved_teaching_options,public.saved_organizations from public,anon,authenticated,service_role;
grant select on table public.organizations,public.organization_members,public.organization_member_capabilities,public.teacher_profiles,public.teaching_options,
  public.teaching_option_locations,public.saved_teacher_profiles,public.saved_teaching_options,public.saved_organizations to authenticated;
grant select,insert,update,delete on table public.organizations,public.organization_members,public.organization_member_capabilities,public.teacher_profiles,public.teaching_options,
  public.teaching_option_locations,public.saved_teacher_profiles,public.saved_teaching_options,public.saved_organizations to service_role;

-- Safe public projections. They deliberately do not expose auth ids, private membership data, or hidden provider records.
create or replace function public.discover_teaching_options(p_location_id uuid,p_query text default null)
returns setof jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'teaching_option_id',t.id,'title',t.title,'category',t.category,'description',t.description,
    'teaching_mode',t.teaching_mode,'area_or_venue_text',t.area_or_venue_text,'fee_display_text',t.fee_display_text,
    'availability_status',t.availability_status,'provider_type',case when t.teacher_account_id is not null then 'teacher' else 'organization' end,
    'provider_id',coalesce(t.teacher_account_id,t.organization_id),
    'provider_name',coalesce(ta.display_name,o.name),'headline',tp.headline,'organization_logo_type',o.logo_type,'organization_logo_ref',o.logo_ref
  )
  from public.teaching_options t
  join public.teaching_option_locations tol on tol.teaching_option_id=t.id and tol.location_id=p_location_id
  join public.locations l on l.id=tol.location_id and l.state='live'
  left join public.accounts ta on ta.id=t.teacher_account_id
  left join public.teacher_profiles tp on tp.account_id=t.teacher_account_id
  left join public.organizations o on o.id=t.organization_id
  where t.availability_status='taking_new_learners'
    and ((t.teacher_account_id is not null and ta.lifecycle_status='active' and tp.visibility_status='visible') or (t.organization_id is not null and o.status='active'))
    and (nullif(btrim(p_query),'') is null or t.title ilike '%'||btrim(p_query)||'%' or coalesce(t.category,'') ilike '%'||btrim(p_query)||'%' or coalesce(ta.display_name,o.name,'') ilike '%'||btrim(p_query)||'%')
  order by t.updated_at desc,t.id;
$$;

create or replace function public.get_teaching_option_public(p_teaching_option_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'teaching_option_id',t.id,'title',t.title,'category',t.category,'description',t.description,'teaching_mode',t.teaching_mode,
    'area_or_venue_text',t.area_or_venue_text,'fee_display_text',t.fee_display_text,'availability_status',t.availability_status,
    'provider_type',case when t.teacher_account_id is not null then 'teacher' else 'organization' end,'provider_id',coalesce(t.teacher_account_id,t.organization_id),
    'provider_name',coalesce(ta.display_name,o.name),'headline',tp.headline,
    'locations',(select coalesce(jsonb_agg(jsonb_build_object('location_id',l2.id,'name',l2.name) order by l2.name),'[]'::jsonb)
      from public.teaching_option_locations x join public.locations l2 on l2.id=x.location_id where x.teaching_option_id=t.id and l2.state='live')
  )
  from public.teaching_options t
  left join public.accounts ta on ta.id=t.teacher_account_id left join public.teacher_profiles tp on tp.account_id=t.teacher_account_id
  left join public.organizations o on o.id=t.organization_id
  where t.id=p_teaching_option_id and app_private.is_teaching_option_public(t.id,false);
$$;

create or replace function public.get_teacher_profile_public(p_teacher_account_id uuid,p_location_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('teacher_account_id',a.id,'display_name',a.display_name,'avatar_type',a.avatar_type,'avatar_ref',a.avatar_ref,
    'headline',tp.headline,'bio',tp.bio,'experience_summary',tp.experience_summary)
  from public.accounts a join public.teacher_profiles tp on tp.account_id=a.id
  where a.id=p_teacher_account_id and a.lifecycle_status='active' and tp.visibility_status='visible'
    and exists(select 1 from public.teaching_options t join public.teaching_option_locations x on x.teaching_option_id=t.id
      join public.locations l on l.id=x.location_id and l.state='live'
      where t.teacher_account_id=a.id and x.location_id=p_location_id and t.availability_status<>'no_longer_offered');
$$;

create or replace function public.get_organization_public(p_organization_id uuid,p_location_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('organization_id',o.id,'organization_type',o.organization_type,'name',o.name,'description',o.description,
    'public_contact_text',o.public_contact_text,'venue_text',o.venue_text,'website_url',o.website_url,'logo_type',o.logo_type,'logo_ref',o.logo_ref)
  from public.organizations o
  where o.id=p_organization_id and o.status='active'
    and exists(select 1 from public.teaching_options t join public.teaching_option_locations x on x.teaching_option_id=t.id
      join public.locations l on l.id=x.location_id and l.state='live'
      where t.organization_id=o.id and x.location_id=p_location_id and t.availability_status<>'no_longer_offered');
$$;

-- Extend closure blockers with sole active Organization management responsibility.
create or replace function app_private.account_closure_blockers(p_account_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  with blockers as (
    select jsonb_build_object('code','SOLE_MANAGER_RESPONSIBILITY','learner_id',ala.learner_id) blocker
    from public.account_learner_access ala
    where ala.account_id=p_account_id and ala.access_type='manage' and ala.status='active'
      and not exists(select 1 from public.account_learner_access s where s.learner_id=ala.learner_id and s.access_type='self' and s.status='active')
    union all
    select jsonb_build_object('code','ACTIVE_LOCAL_MANAGER_ASSIGNMENT','location_id',lsa.location_id,'assignment_id',lsa.id)
    from public.location_staff_assignments lsa where lsa.account_id=p_account_id and lsa.status='active'
    union all
    select jsonb_build_object('code','SOLE_ORGANIZATION_MANAGER','organization_id',om.organization_id,'member_id',om.id)
    from public.organization_members om
    join public.organization_member_capabilities c on c.organization_member_id=om.id and c.capability_code='manage_members'
    where om.account_id=p_account_id and om.status='active'
      and not exists(select 1 from public.organization_members other
        join public.organization_member_capabilities oc on oc.organization_member_id=other.id and oc.capability_code='manage_members'
        where other.organization_id=om.organization_id and other.status='active' and other.id<>om.id)
  ) select coalesce(jsonb_agg(blocker),'[]'::jsonb) from blockers;
$$;

-- Private ACLs. RLS helpers are executable for policies; command implementations for wrappers; everything else owner-only.
revoke all on function app_private.has_organization_member_capability(uuid,text) from public,anon,authenticated,service_role;
revoke all on function app_private.is_active_organization_member(uuid) from public,anon,authenticated,service_role;
revoke all on function app_private.can_read_organization_member(uuid) from public,anon,authenticated,service_role;
revoke all on function app_private.write_organization_audit(uuid,text,uuid,text,uuid,text,jsonb) from public,anon,authenticated,service_role;
revoke all on function app_private.can_manage_teaching_option(uuid) from public,anon,authenticated,service_role;
revoke all on function app_private.is_teaching_option_public(uuid,boolean) from public,anon,authenticated,service_role;
revoke all on function app_private.cmd_create_organization(text,text,text,text,text,text,text,text,text) from public,anon,authenticated,service_role;
revoke all on function app_private.cmd_update_organization_profile(uuid,text,text,text,text,text,text,text,text) from public,anon,authenticated,service_role;
revoke all on function app_private.cmd_add_organization_member(uuid,uuid,text) from public,anon,authenticated,service_role;
revoke all on function app_private.cmd_set_organization_member_capability(uuid,text,boolean,text) from public,anon,authenticated,service_role;
revoke all on function app_private.cmd_remove_organization_member(uuid,text) from public,anon,authenticated,service_role;
revoke all on function app_private.cmd_upsert_teacher_profile(text,text,text,text,text) from public,anon,authenticated,service_role;
revoke all on function app_private.cmd_publish_teaching_option(uuid,text,text,text,text,text,text,uuid[],text) from public,anon,authenticated,service_role;
revoke all on function app_private.cmd_update_teaching_option(uuid,text,text,text,text,text,text,text) from public,anon,authenticated,service_role;
revoke all on function app_private.cmd_set_teaching_availability(uuid,text,text) from public,anon,authenticated,service_role;
revoke all on function app_private.cmd_set_teaching_option_locations(uuid,uuid[],text) from public,anon,authenticated,service_role;
revoke all on function app_private.set_saved_teacher_profile(uuid,boolean) from public,anon,authenticated,service_role;
revoke all on function app_private.set_saved_teaching_option(uuid,boolean) from public,anon,authenticated,service_role;
revoke all on function app_private.set_saved_organization(uuid,boolean) from public,anon,authenticated,service_role;

grant execute on function app_private.has_organization_member_capability(uuid,text),app_private.is_active_organization_member(uuid),
  app_private.can_read_organization_member(uuid),app_private.can_manage_teaching_option(uuid) to authenticated;
grant execute on function app_private.cmd_create_organization(text,text,text,text,text,text,text,text,text),
  app_private.cmd_update_organization_profile(uuid,text,text,text,text,text,text,text,text),app_private.cmd_add_organization_member(uuid,uuid,text),
  app_private.cmd_set_organization_member_capability(uuid,text,boolean,text),app_private.cmd_remove_organization_member(uuid,text),
  app_private.cmd_upsert_teacher_profile(text,text,text,text,text),app_private.cmd_publish_teaching_option(uuid,text,text,text,text,text,text,uuid[],text),
  app_private.cmd_update_teaching_option(uuid,text,text,text,text,text,text,text),app_private.cmd_set_teaching_availability(uuid,text,text),
  app_private.cmd_set_teaching_option_locations(uuid,uuid[],text),app_private.set_saved_teacher_profile(uuid,boolean),
  app_private.set_saved_teaching_option(uuid,boolean),app_private.set_saved_organization(uuid,boolean) to authenticated;

-- Thin public command wrappers.
create or replace function public.create_organization(p_organization_type text,p_name text,p_description text,p_public_contact_text text,p_venue_text text,p_website_url text,p_logo_type text,p_logo_ref text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_create_organization(p_organization_type,p_name,p_description,p_public_contact_text,p_venue_text,p_website_url,p_logo_type,p_logo_ref,p_idempotency_key); $$;
create or replace function public.update_organization_profile(p_organization_id uuid,p_name text,p_description text,p_public_contact_text text,p_venue_text text,p_website_url text,p_logo_type text,p_logo_ref text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_update_organization_profile(p_organization_id,p_name,p_description,p_public_contact_text,p_venue_text,p_website_url,p_logo_type,p_logo_ref,p_idempotency_key); $$;
create or replace function public.add_organization_member(p_organization_id uuid,p_target_account_id uuid,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_add_organization_member(p_organization_id,p_target_account_id,p_idempotency_key); $$;
create or replace function public.set_organization_member_capability(p_organization_member_id uuid,p_capability_code text,p_enabled boolean,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_set_organization_member_capability(p_organization_member_id,p_capability_code,p_enabled,p_idempotency_key); $$;
create or replace function public.remove_organization_member(p_organization_member_id uuid,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_remove_organization_member(p_organization_member_id,p_idempotency_key); $$;
create or replace function public.upsert_teacher_profile(p_headline text,p_bio text,p_experience_summary text,p_visibility_status text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_upsert_teacher_profile(p_headline,p_bio,p_experience_summary,p_visibility_status,p_idempotency_key); $$;
create or replace function public.publish_teaching_option(p_organization_id uuid,p_title text,p_category text,p_description text,p_teaching_mode text,p_area_or_venue_text text,p_fee_display_text text,p_location_ids uuid[],p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_publish_teaching_option(p_organization_id,p_title,p_category,p_description,p_teaching_mode,p_area_or_venue_text,p_fee_display_text,p_location_ids,p_idempotency_key); $$;
create or replace function public.update_teaching_option(p_teaching_option_id uuid,p_title text,p_category text,p_description text,p_teaching_mode text,p_area_or_venue_text text,p_fee_display_text text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_update_teaching_option(p_teaching_option_id,p_title,p_category,p_description,p_teaching_mode,p_area_or_venue_text,p_fee_display_text,p_idempotency_key); $$;
create or replace function public.set_teaching_availability(p_teaching_option_id uuid,p_availability_status text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_set_teaching_availability(p_teaching_option_id,p_availability_status,p_idempotency_key); $$;
create or replace function public.set_teaching_option_locations(p_teaching_option_id uuid,p_location_ids uuid[],p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_set_teaching_option_locations(p_teaching_option_id,p_location_ids,p_idempotency_key); $$;
create or replace function public.save_teacher_profile(p_teacher_account_id uuid,p_saved boolean)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.set_saved_teacher_profile(p_teacher_account_id,p_saved); $$;
create or replace function public.save_teaching_option(p_teaching_option_id uuid,p_saved boolean)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.set_saved_teaching_option(p_teaching_option_id,p_saved); $$;
create or replace function public.save_organization(p_organization_id uuid,p_saved boolean)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.set_saved_organization(p_organization_id,p_saved); $$;

revoke all on function public.create_organization(text,text,text,text,text,text,text,text,text),public.update_organization_profile(uuid,text,text,text,text,text,text,text,text),
  public.add_organization_member(uuid,uuid,text),public.set_organization_member_capability(uuid,text,boolean,text),public.remove_organization_member(uuid,text),
  public.upsert_teacher_profile(text,text,text,text,text),public.publish_teaching_option(uuid,text,text,text,text,text,text,uuid[],text),
  public.update_teaching_option(uuid,text,text,text,text,text,text,text),public.set_teaching_availability(uuid,text,text),public.set_teaching_option_locations(uuid,uuid[],text),
  public.save_teacher_profile(uuid,boolean),public.save_teaching_option(uuid,boolean),public.save_organization(uuid,boolean),
  public.discover_teaching_options(uuid,text),public.get_teaching_option_public(uuid),public.get_teacher_profile_public(uuid,uuid),public.get_organization_public(uuid,uuid)
from public,anon,authenticated,service_role;

grant execute on function public.create_organization(text,text,text,text,text,text,text,text,text),public.update_organization_profile(uuid,text,text,text,text,text,text,text,text),
  public.add_organization_member(uuid,uuid,text),public.set_organization_member_capability(uuid,text,boolean,text),public.remove_organization_member(uuid,text),
  public.upsert_teacher_profile(text,text,text,text,text),public.publish_teaching_option(uuid,text,text,text,text,text,text,uuid[],text),
  public.update_teaching_option(uuid,text,text,text,text,text,text,text),public.set_teaching_availability(uuid,text,text),public.set_teaching_option_locations(uuid,uuid[],text),
  public.save_teacher_profile(uuid,boolean),public.save_teaching_option(uuid,boolean),public.save_organization(uuid,boolean),
  public.discover_teaching_options(uuid,text),public.get_teaching_option_public(uuid),public.get_teacher_profile_public(uuid,uuid),public.get_organization_public(uuid,uuid)
to authenticated;
