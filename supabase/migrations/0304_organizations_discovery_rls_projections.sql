-- Raahi Learning V1.2 — Organizations/discovery RLS, public projections, wrappers and closure blocker extension

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

create or replace function public.discover_teaching_options(p_location_id uuid,p_query text default null)
returns setof jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'teaching_option_id',t.id,'title',t.title,'category',t.category,'description',t.description,'teaching_mode',t.teaching_mode,
    'area_or_venue_text',t.area_or_venue_text,'fee_display_text',t.fee_display_text,'availability_status',t.availability_status,
    'provider_type',case when t.teacher_account_id is not null then 'teacher' else 'organization' end,
    'provider_id',coalesce(t.teacher_account_id,t.organization_id),'provider_name',coalesce(ta.display_name,o.name),
    'headline',tp.headline,'organization_logo_type',o.logo_type,'organization_logo_ref',o.logo_ref
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
    'provider_type',case when t.teacher_account_id is not null then 'teacher' else 'organization' end,
    'provider_id',coalesce(t.teacher_account_id,t.organization_id),'provider_name',coalesce(ta.display_name,o.name),'headline',tp.headline,
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

revoke all on function app_private.has_organization_member_capability(uuid,text),app_private.is_active_organization_member(uuid),
  app_private.can_read_organization_member(uuid),app_private.write_organization_audit(uuid,text,uuid,text,uuid,text,jsonb),
  app_private.can_manage_teaching_option(uuid),app_private.is_teaching_option_public(uuid,boolean),
  app_private.cmd_create_organization(text,text,text,text,text,text,text,text,text),app_private.cmd_update_organization_profile(uuid,text,text,text,text,text,text,text,text),
  app_private.cmd_add_organization_member(uuid,uuid,text),app_private.cmd_set_organization_member_capability(uuid,text,boolean,text),
  app_private.cmd_remove_organization_member(uuid,text),app_private.cmd_upsert_teacher_profile(text,text,text,text,text),
  app_private.cmd_publish_teaching_option(uuid,text,text,text,text,text,text,uuid[],text),app_private.cmd_update_teaching_option(uuid,text,text,text,text,text,text,text),
  app_private.cmd_set_teaching_availability(uuid,text,text),app_private.cmd_set_teaching_option_locations(uuid,uuid[],text),
  app_private.set_saved_teacher_profile(uuid,boolean),app_private.set_saved_teaching_option(uuid,boolean),app_private.set_saved_organization(uuid,boolean)
from public,anon,authenticated,service_role;

grant execute on function app_private.has_organization_member_capability(uuid,text),app_private.is_active_organization_member(uuid),
  app_private.can_read_organization_member(uuid),app_private.can_manage_teaching_option(uuid) to authenticated;
grant execute on function app_private.cmd_create_organization(text,text,text,text,text,text,text,text,text),
  app_private.cmd_update_organization_profile(uuid,text,text,text,text,text,text,text,text),app_private.cmd_add_organization_member(uuid,uuid,text),
  app_private.cmd_set_organization_member_capability(uuid,text,boolean,text),app_private.cmd_remove_organization_member(uuid,text),
  app_private.cmd_upsert_teacher_profile(text,text,text,text,text),app_private.cmd_publish_teaching_option(uuid,text,text,text,text,text,text,uuid[],text),
  app_private.cmd_update_teaching_option(uuid,text,text,text,text,text,text,text),app_private.cmd_set_teaching_availability(uuid,text,text),
  app_private.cmd_set_teaching_option_locations(uuid,uuid[],text),app_private.set_saved_teacher_profile(uuid,boolean),
  app_private.set_saved_teaching_option(uuid,boolean),app_private.set_saved_organization(uuid,boolean) to authenticated;

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
