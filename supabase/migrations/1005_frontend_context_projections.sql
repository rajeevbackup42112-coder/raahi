-- Raahi Learning V1.2 — frontend integration projections discovered during frozen-UI wiring.

create or replace function app_private.read_public_locations()
returns setof jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'location_id',l.id,'name',l.name,'slug',l.slug,'region',l.region,
    'state_or_province',l.state_or_province,'country_code',l.country_code,'state',l.state
  )
  from public.locations l
  where l.state <> 'retired'
  order by case l.state when 'live' then 1 when 'preparing' then 2 when 'interest_only' then 3 when 'paused' then 4 else 5 end,
           l.name,l.id;
$$;

create or replace function app_private.read_my_account_context()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_actor uuid:=app_private.current_account_id(); v_result jsonb;
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
  select jsonb_build_object(
    'account',jsonb_build_object(
      'account_id',a.id,'display_name',a.display_name,'avatar_type',a.avatar_type,
      'avatar_ref',a.avatar_ref,'lifecycle_status',a.lifecycle_status
    ),
    'selected_location',(
      select jsonb_build_object('location_id',l.id,'name',l.name,'slug',l.slug,'state',l.state)
      from public.account_location_preferences p join public.locations l on l.id=p.selected_location_id
      where p.account_id=a.id
    ),
    'learners',coalesce((
      select jsonb_agg(jsonb_build_object(
        'access_id',ala.id,'access_type',ala.access_type,'learner_id',lr.id,
        'display_name',lr.display_name,'avatar_type',lr.avatar_type,'avatar_ref',lr.avatar_ref
      ) order by case ala.access_type when 'self' then 1 else 2 end,lr.display_name,lr.id)
      from public.account_learner_access ala join public.learners lr on lr.id=ala.learner_id
      where ala.account_id=a.id and ala.status='active'
    ),'[]'::jsonb),
    'capabilities',coalesce((
      select jsonb_agg(ac.capability_code order by ac.capability_code)
      from public.account_capabilities ac where ac.account_id=a.id and ac.status='active'
    ),'[]'::jsonb),
    'organizations',coalesce((
      select jsonb_agg(jsonb_build_object(
        'organization_member_id',om.id,'organization_id',o.id,'name',o.name,
        'organization_type',o.organization_type,'status',o.status,'logo_type',o.logo_type,'logo_ref',o.logo_ref,
        'capabilities',coalesce((select jsonb_agg(c.capability_code order by c.capability_code)
          from public.organization_member_capabilities c where c.organization_member_id=om.id),'[]'::jsonb)
      ) order by o.name,o.id)
      from public.organization_members om join public.organizations o on o.id=om.organization_id
      where om.account_id=a.id and om.status='active'
    ),'[]'::jsonb),
    'manager_scopes',coalesce((
      select jsonb_agg(jsonb_build_object(
        'assignment_id',s.id,'staff_type',s.staff_type,'location_id',l.id,'location_name',l.name,'location_state',l.state
      ) order by l.name,l.id)
      from public.location_staff_assignments s join public.locations l on l.id=s.location_id
      where s.account_id=a.id and s.status='active'
    ),'[]'::jsonb)
  ) into v_result
  from public.accounts a where a.id=v_actor;
  if v_result is null then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  return v_result;
end; $$;

revoke all on function app_private.read_public_locations(),app_private.read_my_account_context() from public,anon,authenticated,service_role;
grant execute on function app_private.read_public_locations() to anon,authenticated;
grant execute on function app_private.read_my_account_context() to authenticated;

create or replace function public.list_public_locations()
returns setof jsonb language sql stable security invoker set search_path='' as $$
  select * from app_private.read_public_locations();
$$;
create or replace function public.get_my_account_context()
returns jsonb language sql stable security invoker set search_path='' as $$
  select app_private.read_my_account_context();
$$;

revoke all on function public.list_public_locations(),public.get_my_account_context() from public,anon,authenticated,service_role;
grant execute on function public.list_public_locations() to anon,authenticated;
grant execute on function public.get_my_account_context() to authenticated;
