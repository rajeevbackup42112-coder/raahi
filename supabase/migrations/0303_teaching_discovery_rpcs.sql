-- Raahi Learning V1.2 — Teacher profile, Teaching Option and private Save commands

create or replace function app_private.can_manage_teaching_option(p_teaching_option_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_teacher uuid; v_org uuid; v_actor uuid:=app_private.current_account_id();
begin
  select teacher_account_id,organization_id into v_teacher,v_org from public.teaching_options where id=p_teaching_option_id;
  if not found or v_actor is null then return false; end if;
  if app_private.has_account_capability('platform_admin') then return true; end if;
  if v_teacher is not null then return v_teacher=v_actor and app_private.has_account_capability('teach'); end if;
  return app_private.has_organization_member_capability(v_org,'manage_teaching_options');
end; $$;

create or replace function app_private.is_teaching_option_public(p_teaching_option_id uuid,p_require_taking boolean default false)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.teaching_options t
    join public.teaching_option_locations tol on tol.teaching_option_id=t.id
    join public.locations l on l.id=tol.location_id and l.state='live'
    left join public.teacher_profiles tp on tp.account_id=t.teacher_account_id
    left join public.accounts ta on ta.id=t.teacher_account_id
    left join public.organizations o on o.id=t.organization_id
    where t.id=p_teaching_option_id
      and t.availability_status<>'no_longer_offered'
      and (not p_require_taking or t.availability_status='taking_new_learners')
      and ((t.teacher_account_id is not null and tp.visibility_status='visible' and ta.lifecycle_status='active')
        or (t.organization_id is not null and o.status='active'))
  );
$$;

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
  if p_saved and not exists(select 1 from public.teacher_profiles tp join public.accounts a on a.id=tp.account_id where tp.account_id=p_teacher_account_id and tp.visibility_status='visible' and a.lifecycle_status='active') then raise exception 'TEACHER_PROFILE_NOT_PUBLIC'; end if;
  if p_saved then insert into public.saved_teacher_profiles(account_id,teacher_account_id) values(v_actor,p_teacher_account_id) on conflict do nothing;
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
