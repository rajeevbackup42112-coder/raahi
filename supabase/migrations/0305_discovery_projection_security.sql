-- Raahi Learning V1.2 — Discovery projection SECURITY DEFINER isolation
-- Keep definer reads in non-exposed app_private; public RPCs are invoker wrappers.

create or replace function app_private.discover_teaching_options(p_location_id uuid,p_query text default null)
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

create or replace function app_private.get_teaching_option_public(p_teaching_option_id uuid)
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

create or replace function app_private.get_teacher_profile_public(p_teacher_account_id uuid,p_location_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('teacher_account_id',a.id,'display_name',a.display_name,'avatar_type',a.avatar_type,'avatar_ref',a.avatar_ref,
    'headline',tp.headline,'bio',tp.bio,'experience_summary',tp.experience_summary)
  from public.accounts a join public.teacher_profiles tp on tp.account_id=a.id
  where a.id=p_teacher_account_id and a.lifecycle_status='active' and tp.visibility_status='visible'
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
    and exists(select 1 from public.teaching_options t join public.teaching_option_locations x on x.teaching_option_id=t.id
      join public.locations l on l.id=x.location_id and l.state='live'
      where t.organization_id=o.id and x.location_id=p_location_id and t.availability_status<>'no_longer_offered');
$$;

revoke all on function app_private.discover_teaching_options(uuid,text),app_private.get_teaching_option_public(uuid),
  app_private.get_teacher_profile_public(uuid,uuid),app_private.get_organization_public(uuid,uuid)
from public,anon,authenticated,service_role;
grant execute on function app_private.discover_teaching_options(uuid,text),app_private.get_teaching_option_public(uuid),
  app_private.get_teacher_profile_public(uuid,uuid),app_private.get_organization_public(uuid,uuid) to authenticated;

create or replace function public.discover_teaching_options(p_location_id uuid,p_query text default null)
returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.discover_teaching_options(p_location_id,p_query); $$;
create or replace function public.get_teaching_option_public(p_teaching_option_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.get_teaching_option_public(p_teaching_option_id); $$;
create or replace function public.get_teacher_profile_public(p_teacher_account_id uuid,p_location_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.get_teacher_profile_public(p_teacher_account_id,p_location_id); $$;
create or replace function public.get_organization_public(p_organization_id uuid,p_location_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.get_organization_public(p_organization_id,p_location_id); $$;

revoke all on function public.discover_teaching_options(uuid,text),public.get_teaching_option_public(uuid),public.get_teacher_profile_public(uuid,uuid),public.get_organization_public(uuid,uuid)
from public,anon,authenticated,service_role;
grant execute on function public.discover_teaching_options(uuid,text),public.get_teaching_option_public(uuid),public.get_teacher_profile_public(uuid,uuid),public.get_organization_public(uuid,uuid)
to authenticated;
