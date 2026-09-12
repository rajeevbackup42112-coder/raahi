-- Raahi Learning V1.2 — secure Organization workspace projection for frontend administration.
-- Read-only projection; all Organization state changes continue through canonical commands.

create or replace function app_private.read_organization_workspace(p_organization_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path=''
as $$
declare v_authorized boolean; v_result jsonb;
begin
  v_authorized:=app_private.has_account_capability('platform_admin')
    or app_private.has_organization_member_capability(p_organization_id,'manage_profile')
    or app_private.has_organization_member_capability(p_organization_id,'manage_teaching_options')
    or app_private.has_organization_member_capability(p_organization_id,'manage_classes')
    or app_private.has_organization_member_capability(p_organization_id,'manage_ads')
    or app_private.has_organization_member_capability(p_organization_id,'manage_members');
  if not v_authorized then raise exception 'NOT_AUTHORIZED'; end if;

  select jsonb_build_object(
    'organization',jsonb_build_object(
      'organization_id',o.id,'organization_type',o.organization_type,'name',o.name,'description',o.description,
      'public_contact_text',o.public_contact_text,'venue_text',o.venue_text,'website_url',o.website_url,
      'logo_type',o.logo_type,'logo_ref',o.logo_ref,'status',o.status,'created_at',o.created_at,'updated_at',o.updated_at
    ),
    'teaching_options',coalesce((
      select jsonb_agg(jsonb_build_object(
        'teaching_option_id',t.id,'title',t.title,'category',t.category,'description',t.description,
        'teaching_mode',t.teaching_mode,'area_or_venue_text',t.area_or_venue_text,'fee_display_text',t.fee_display_text,
        'availability_status',t.availability_status,'created_at',t.created_at,'updated_at',t.updated_at,
        'locations',coalesce((select jsonb_agg(jsonb_build_object('location_id',l.id,'name',l.name,'state',l.state) order by l.name,l.id)
          from public.teaching_option_locations x join public.locations l on l.id=x.location_id where x.teaching_option_id=t.id),'[]'::jsonb)
      ) order by t.updated_at desc,t.id)
      from public.teaching_options t where t.organization_id=o.id
    ),'[]'::jsonb)
  ) into v_result
  from public.organizations o where o.id=p_organization_id;

  if v_result is null then raise exception 'ORGANIZATION_NOT_FOUND'; end if;
  return v_result;
end;
$$;

revoke all on function app_private.read_organization_workspace(uuid) from public,anon,authenticated,service_role;
grant execute on function app_private.read_organization_workspace(uuid) to authenticated;

create or replace function public.get_organization_workspace(p_organization_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.read_organization_workspace(p_organization_id); $$;
revoke all on function public.get_organization_workspace(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_organization_workspace(uuid) to authenticated;
