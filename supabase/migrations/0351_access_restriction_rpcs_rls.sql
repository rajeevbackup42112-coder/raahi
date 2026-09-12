-- Raahi Learning V1.2 — Scoped restriction helpers, commands, RLS and discovery integration

create or replace function app_private.has_active_account_restriction(p_account_id uuid,p_scope text,p_location_id uuid default null)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.access_restrictions r
    where r.account_id=p_account_id and r.restriction_scope=p_scope and r.state='active'
      and r.starts_at<=now() and (r.ends_at is null or r.ends_at>now())
      and (r.location_id is null or r.location_id=p_location_id)
  );
$$;

create or replace function app_private.has_active_organization_restriction(p_organization_id uuid,p_scope text,p_location_id uuid default null)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.access_restrictions r
    where r.organization_id=p_organization_id and r.restriction_scope=p_scope and r.state='active'
      and r.starts_at<=now() and (r.ends_at is null or r.ends_at>now())
      and (r.location_id is null or r.location_id=p_location_id)
  );
$$;

create or replace function app_private.can_review_restrictions()
returns boolean language sql stable security definer set search_path='' as $$
  select app_private.has_account_capability('platform_admin') or app_private.has_account_capability('safety_reviewer');
$$;

create or replace function app_private.write_restriction_audit(
  p_actor_account_id uuid,p_action_type text,p_restriction_id uuid,p_account_id uuid,p_organization_id uuid,p_location_id uuid,p_reason text,p_metadata jsonb default '{}'::jsonb
)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
  insert into public.audit_log(actor_kind,actor_account_id,action_type,target_type,target_id,organization_id,location_id,reason,metadata)
  values('account',p_actor_account_id,p_action_type,'access_restriction',p_restriction_id,p_organization_id,p_location_id,p_reason,
    coalesce(p_metadata,'{}'::jsonb)||case when p_account_id is null then '{}'::jsonb else jsonb_build_object('subject_account_id',p_account_id) end)
  returning id into v_id;
  return v_id;
end; $$;

create or replace function app_private.cmd_apply_access_restriction(
  p_account_id uuid,p_organization_id uuid,p_restriction_scope text,p_location_id uuid,p_reason_code text,p_details text,p_ends_at timestamptz,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_id uuid; v_result jsonb;
begin
  if not app_private.can_review_restrictions() then raise exception 'NOT_AUTHORIZED'; end if;
  if (p_account_id is not null)::int + (p_organization_id is not null)::int <> 1 then raise exception 'RESTRICTION_SUBJECT_REQUIRED'; end if;
  if p_restriction_scope not in ('public_discovery','new_enquiries','messaging','class_access','community','ads') then raise exception 'INVALID_RESTRICTION_SCOPE'; end if;
  if p_reason_code is null or char_length(btrim(p_reason_code)) not between 1 and 120 then raise exception 'INVALID_REASON_CODE'; end if;
  if p_ends_at is not null and p_ends_at<=now() then raise exception 'INVALID_RESTRICTION_END'; end if;
  if p_account_id is not null and not exists(select 1 from public.accounts where id=p_account_id) then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if p_organization_id is not null and not exists(select 1 from public.organizations where id=p_organization_id) then raise exception 'ORGANIZATION_NOT_FOUND'; end if;
  if p_location_id is not null and not exists(select 1 from public.locations where id=p_location_id) then raise exception 'LOCATION_NOT_FOUND'; end if;

  v_fp:=app_private.request_fingerprint(jsonb_build_object('account_id',p_account_id,'organization_id',p_organization_id,'restriction_scope',p_restriction_scope,
    'location_id',p_location_id,'reason_code',p_reason_code,'details',p_details,'ends_at',p_ends_at));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'apply_access_restriction',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  update public.access_restrictions set state='expired'
  where state='active' and ends_at is not null and ends_at<=now()
    and ((p_account_id is not null and account_id=p_account_id) or (p_organization_id is not null and organization_id=p_organization_id))
    and restriction_scope=p_restriction_scope and location_id is not distinct from p_location_id;

  select id into v_id from public.access_restrictions
  where state='active' and ((p_account_id is not null and account_id=p_account_id) or (p_organization_id is not null and organization_id=p_organization_id))
    and restriction_scope=p_restriction_scope and location_id is not distinct from p_location_id
  limit 1 for update;

  if v_id is null then
    insert into public.access_restrictions(account_id,organization_id,restriction_scope,location_id,reason_code,details,ends_at,applied_by_account_id)
    values(p_account_id,p_organization_id,p_restriction_scope,p_location_id,btrim(p_reason_code),nullif(btrim(p_details),''),p_ends_at,v_actor)
    returning id into v_id;
    perform app_private.write_restriction_audit(v_actor,'restriction.apply',v_id,p_account_id,p_organization_id,p_location_id,btrim(p_reason_code),
      jsonb_build_object('scope',p_restriction_scope,'ends_at',p_ends_at));
    v_result:=jsonb_build_object('restriction_id',v_id,'state','active','already_active',false);
  else
    v_result:=jsonb_build_object('restriction_id',v_id,'state','active','already_active',true);
  end if;
  perform app_private.complete_human_idempotent_command(v_actor,'apply_access_restriction',p_idempotency_key,v_result);
  return v_result;
end; $$;

create or replace function app_private.cmd_lift_access_restriction(p_restriction_id uuid,p_reason text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_account uuid; v_org uuid; v_location uuid; v_scope text; v_state text; v_ends timestamptz; v_result jsonb;
begin
  if not app_private.can_review_restrictions() then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('restriction_id',p_restriction_id,'reason',p_reason));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'lift_access_restriction',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select account_id,organization_id,location_id,restriction_scope,state,ends_at into v_account,v_org,v_location,v_scope,v_state,v_ends
  from public.access_restrictions where id=p_restriction_id for update;
  if not found then raise exception 'RESTRICTION_NOT_FOUND'; end if;
  if v_state='active' and v_ends is not null and v_ends<=now() then
    update public.access_restrictions set state='expired' where id=p_restriction_id;
    v_state:='expired';
  end if;
  if v_state='active' then
    update public.access_restrictions set state='lifted',lifted_by_account_id=v_actor,lifted_at=now() where id=p_restriction_id;
    perform app_private.write_restriction_audit(v_actor,'restriction.lift',p_restriction_id,v_account,v_org,v_location,nullif(btrim(p_reason),''),jsonb_build_object('scope',v_scope));
    v_result:=jsonb_build_object('restriction_id',p_restriction_id,'state','lifted','changed',true);
  else
    v_result:=jsonb_build_object('restriction_id',p_restriction_id,'state',v_state,'changed',false);
  end if;
  perform app_private.complete_human_idempotent_command(v_actor,'lift_access_restriction',p_idempotency_key,v_result);
  return v_result;
end; $$;

create or replace function app_private.expire_access_restrictions()
returns integer language plpgsql security definer set search_path='' as $$
declare v_count integer;
begin
  with expired as (
    update public.access_restrictions set state='expired'
    where state='active' and ends_at is not null and ends_at<=now()
    returning id,account_id,organization_id,location_id,restriction_scope
  ), aud as (
    insert into public.audit_log(actor_kind,actor_account_id,action_type,target_type,target_id,organization_id,location_id,metadata)
    select 'system',null,'restriction.expire','access_restriction',id,organization_id,location_id,
      jsonb_build_object('scope',restriction_scope)||case when account_id is null then '{}'::jsonb else jsonb_build_object('subject_account_id',account_id) end
    from expired returning 1
  ) select count(*) into v_count from aud;
  return v_count;
end; $$;

alter table public.access_restrictions enable row level security;
alter table public.access_restrictions force row level security;
create policy access_restrictions_select_reviewer on public.access_restrictions for select to authenticated
using(app_private.can_review_restrictions());
revoke all on table public.access_restrictions from public,anon,authenticated,service_role;
grant select on table public.access_restrictions to authenticated;
grant select,insert,update,delete on table public.access_restrictions to service_role;

-- Discovery now respects exact global/Location public-discovery restrictions.
create or replace function app_private.is_teaching_option_public(p_teaching_option_id uuid,p_require_taking boolean default false)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.teaching_options t
    join public.teaching_option_locations tol on tol.teaching_option_id=t.id
    join public.locations l on l.id=tol.location_id and l.state='live'
    left join public.teacher_profiles tp on tp.account_id=t.teacher_account_id
    left join public.accounts ta on ta.id=t.teacher_account_id
    left join public.organizations o on o.id=t.organization_id
    where t.id=p_teaching_option_id and t.availability_status<>'no_longer_offered'
      and (not p_require_taking or t.availability_status='taking_new_learners')
      and ((t.teacher_account_id is not null and tp.visibility_status='visible' and ta.lifecycle_status='active'
            and not app_private.has_active_account_restriction(t.teacher_account_id,'public_discovery',tol.location_id))
        or (t.organization_id is not null and o.status='active'
            and not app_private.has_active_organization_restriction(t.organization_id,'public_discovery',tol.location_id)))
  );
$$;

create or replace function app_private.discover_teaching_options(p_location_id uuid,p_query text default null)
returns setof jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'teaching_option_id',t.id,'title',t.title,'category',t.category,'description',t.description,'teaching_mode',t.teaching_mode,
    'area_or_venue_text',t.area_or_venue_text,'fee_display_text',t.fee_display_text,'availability_status',t.availability_status,
    'provider_type',case when t.teacher_account_id is not null then 'teacher' else 'organization' end,
    'provider_id',coalesce(t.teacher_account_id,t.organization_id),'provider_name',coalesce(ta.display_name,o.name),
    'headline',tp.headline,'organization_logo_type',o.logo_type,'organization_logo_ref',o.logo_ref)
  from public.teaching_options t
  join public.teaching_option_locations tol on tol.teaching_option_id=t.id and tol.location_id=p_location_id
  join public.locations l on l.id=tol.location_id and l.state='live'
  left join public.accounts ta on ta.id=t.teacher_account_id
  left join public.teacher_profiles tp on tp.account_id=t.teacher_account_id
  left join public.organizations o on o.id=t.organization_id
  where t.availability_status='taking_new_learners'
    and ((t.teacher_account_id is not null and ta.lifecycle_status='active' and tp.visibility_status='visible'
          and not app_private.has_active_account_restriction(t.teacher_account_id,'public_discovery',p_location_id))
      or (t.organization_id is not null and o.status='active'
          and not app_private.has_active_organization_restriction(t.organization_id,'public_discovery',p_location_id)))
    and (nullif(btrim(p_query),'') is null or t.title ilike '%'||btrim(p_query)||'%' or coalesce(t.category,'') ilike '%'||btrim(p_query)||'%' or coalesce(ta.display_name,o.name,'') ilike '%'||btrim(p_query)||'%')
  order by t.updated_at desc,t.id;
$$;

create or replace function app_private.get_teacher_profile_public(p_teacher_account_id uuid,p_location_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('teacher_account_id',a.id,'display_name',a.display_name,'avatar_type',a.avatar_type,'avatar_ref',a.avatar_ref,
    'headline',tp.headline,'bio',tp.bio,'experience_summary',tp.experience_summary)
  from public.accounts a join public.teacher_profiles tp on tp.account_id=a.id
  where a.id=p_teacher_account_id and a.lifecycle_status='active' and tp.visibility_status='visible'
    and not app_private.has_active_account_restriction(a.id,'public_discovery',p_location_id)
    and exists(select 1 from public.teaching_options t join public.teaching_option_locations x on x.teaching_option_id=t.id
      join public.locations l on l.id=x.location_id and l.state='live'
      where t.teacher_account_id=a.id and x.location_id=p_location_id and t.availability_status<>'no_longer_offered');
$$;

create or replace function app_private.get_organization_public(p_organization_id uuid,p_location_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('organization_id',o.id,'organization_type',o.organization_type,'name',o.name,'description',o.description,
    'public_contact_text',o.public_contact_text,'venue_text',o.venue_text,'website_url',o.website_url,'logo_type',o.logo_type,'logo_ref',o.logo_ref)
  from public.organizations o
  where o.id=p_organization_id and o.status='active'
    and not app_private.has_active_organization_restriction(o.id,'public_discovery',p_location_id)
    and exists(select 1 from public.teaching_options t join public.teaching_option_locations x on x.teaching_option_id=t.id
      join public.locations l on l.id=x.location_id and l.state='live'
      where t.organization_id=o.id and x.location_id=p_location_id and t.availability_status<>'no_longer_offered');
$$;

revoke all on function app_private.has_active_account_restriction(uuid,text,uuid),app_private.has_active_organization_restriction(uuid,text,uuid),
  app_private.can_review_restrictions(),app_private.write_restriction_audit(uuid,text,uuid,uuid,uuid,uuid,text,jsonb),
  app_private.cmd_apply_access_restriction(uuid,uuid,text,uuid,text,text,timestamptz,text),app_private.cmd_lift_access_restriction(uuid,text,text),
  app_private.expire_access_restrictions() from public,anon,authenticated,service_role;
grant execute on function app_private.has_active_account_restriction(uuid,text,uuid),app_private.has_active_organization_restriction(uuid,text,uuid),
  app_private.can_review_restrictions() to authenticated;
grant execute on function app_private.cmd_apply_access_restriction(uuid,uuid,text,uuid,text,text,timestamptz,text),
  app_private.cmd_lift_access_restriction(uuid,text,text) to authenticated;

create or replace function public.apply_access_restriction(p_account_id uuid,p_organization_id uuid,p_restriction_scope text,p_location_id uuid,p_reason_code text,p_details text,p_ends_at timestamptz,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_apply_access_restriction(p_account_id,p_organization_id,p_restriction_scope,p_location_id,p_reason_code,p_details,p_ends_at,p_idempotency_key); $$;
create or replace function public.lift_access_restriction(p_restriction_id uuid,p_reason text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_lift_access_restriction(p_restriction_id,p_reason,p_idempotency_key); $$;
revoke all on function public.apply_access_restriction(uuid,uuid,text,uuid,text,text,timestamptz,text),public.lift_access_restriction(uuid,text,text) from public,anon,authenticated,service_role;
grant execute on function public.apply_access_restriction(uuid,uuid,text,uuid,text,text,timestamptz,text),public.lift_access_restriction(uuid,text,text) to authenticated;
