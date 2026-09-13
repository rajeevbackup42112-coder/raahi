-- Raahi Learning V1.2 — operational read projections proven necessary by frozen-UI integration.
-- Read models only. Existing commands remain the sole owners of consequential state changes.

create or replace function app_private.read_learner_transfer_options(p_source_membership_id uuid)
returns setof jsonb
language plpgsql
stable security definer
set search_path=''
as $$
declare
  v_source_class uuid;
  v_learner uuid;
  v_source_state text;
  v_teacher uuid;
  v_org uuid;
begin
  select m.class_id,m.learner_id,m.state,c.responsible_teacher_account_id,c.organization_id
    into v_source_class,v_learner,v_source_state,v_teacher,v_org
  from public.class_memberships m
  join public.classes c on c.id=m.class_id
  where m.id=p_source_membership_id;

  if v_source_class is null then raise exception 'MEMBERSHIP_NOT_FOUND'; end if;
  if v_source_state<>'active' then raise exception 'SOURCE_MEMBERSHIP_NOT_ACTIVE'; end if;
  if not app_private.can_make_learning_decision(v_learner) then raise exception 'LEARNER_SIDE_TRANSFER_AUTHORITY_REQUIRED'; end if;
  if app_private.current_actor_class_access_blocked(v_source_class) or app_private.class_provider_access_blocked(v_source_class) then
    raise exception 'CLASS_ACCESS_RESTRICTED';
  end if;

  return query
  select jsonb_build_object(
    'class_id',c.id,
    'title',c.title,
    'class_type',c.class_type,
    'location_id',c.location_id,
    'capacity',c.capacity,
    'reserved_occupancy',app_private.class_reserved_occupancy(c.id),
    'available_seats',greatest(c.capacity-app_private.class_reserved_occupancy(c.id),0),
    'responsible_teacher_account_id',c.responsible_teacher_account_id,
    'organization_id',c.organization_id
  )
  from public.classes c
  where c.id<>v_source_class
    and c.state='active'
    and c.responsible_teacher_account_id is not distinct from v_teacher
    and c.organization_id is not distinct from v_org
    and not app_private.current_actor_class_access_blocked(c.id)
    and not app_private.class_provider_access_blocked(c.id)
    and not exists(select 1 from public.class_memberships m where m.class_id=c.id and m.learner_id=v_learner and m.state='active')
    and not exists(select 1 from public.class_invitations i where i.class_id=c.id and i.learner_id=v_learner and i.state='pending' and i.expires_at>now())
    and app_private.class_reserved_occupancy(c.id)<c.capacity
  order by c.title,c.id;
end;
$$;

create or replace function app_private.read_organization_admin_workspace(p_organization_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path=''
as $$
declare
  v_platform boolean:=app_private.has_account_capability('platform_admin');
  v_profile boolean:=false;
  v_options boolean:=false;
  v_classes boolean:=false;
  v_ads boolean:=false;
  v_members boolean:=false;
  v_result jsonb;
begin
  v_profile:=v_platform or app_private.has_organization_member_capability(p_organization_id,'manage_profile');
  v_options:=v_platform or app_private.has_organization_member_capability(p_organization_id,'manage_teaching_options');
  v_classes:=v_platform or app_private.has_organization_member_capability(p_organization_id,'manage_classes');
  v_ads:=v_platform or app_private.has_organization_member_capability(p_organization_id,'manage_ads');
  v_members:=v_platform or app_private.has_organization_member_capability(p_organization_id,'manage_members');
  if not (v_profile or v_options or v_classes or v_ads or v_members) then raise exception 'NOT_AUTHORIZED'; end if;

  select jsonb_build_object(
    'organization',jsonb_build_object(
      'organization_id',o.id,'name',o.name,'organization_type',o.organization_type,'description',o.description,
      'public_contact_text',o.public_contact_text,'venue_text',o.venue_text,'website_url',o.website_url,
      'logo_type',o.logo_type,'logo_ref',o.logo_ref,'status',o.status
    ),
    'actor_capabilities',coalesce((
      select jsonb_agg(x order by x) from (
        select c.capability_code x
        from public.organization_members om
        join public.organization_member_capabilities c on c.organization_member_id=om.id
        where om.organization_id=o.id and om.account_id=app_private.current_account_id() and om.status='active'
      ) q
    ),case when v_platform then '["platform_admin"]'::jsonb else '[]'::jsonb end),
    'members',case when v_members then coalesce((
      select jsonb_agg(jsonb_build_object(
        'organization_member_id',om.id,'account_id',a.id,'display_name',a.display_name,
        'account_lifecycle_status',a.lifecycle_status,'member_status',om.status,'ended_at',om.ended_at,
        'capabilities',coalesce((select jsonb_agg(c.capability_code order by c.capability_code) from public.organization_member_capabilities c where c.organization_member_id=om.id),'[]'::jsonb)
      ) order by case om.status when 'active' then 0 else 1 end,a.display_name,om.id)
      from public.organization_members om join public.accounts a on a.id=om.account_id
      where om.organization_id=o.id
    ),'[]'::jsonb) else null end,
    'teaching_options',case when (v_options or v_classes) then coalesce((
      select jsonb_agg(jsonb_build_object(
        'teaching_option_id',t.id,'title',t.title,'category',t.category,'description',t.description,
        'teaching_mode',t.teaching_mode,'area_or_venue_text',t.area_or_venue_text,'fee_display_text',t.fee_display_text,
        'availability_status',t.availability_status,'updated_at',t.updated_at
      ) order by t.updated_at desc,t.id)
      from public.teaching_options t where t.organization_id=o.id
    ),'[]'::jsonb) else null end,
    'classes',case when v_classes then coalesce((
      select jsonb_agg(jsonb_build_object(
        'class_id',c.id,'title',c.title,'class_type',c.class_type,'state',c.state,'location_id',c.location_id,
        'capacity',c.capacity,'responsible_teacher_account_id',c.responsible_teacher_account_id,
        'responsible_teacher_name',a.display_name,'updated_at',c.updated_at
      ) order by c.updated_at desc,c.id)
      from public.classes c join public.accounts a on a.id=c.responsible_teacher_account_id
      where c.organization_id=o.id
    ),'[]'::jsonb) else null end,
    'can_manage_profile',v_profile,'can_manage_teaching_options',v_options,'can_manage_classes',v_classes,
    'can_manage_ads',v_ads,'can_manage_members',v_members
  ) into v_result
  from public.organizations o where o.id=p_organization_id;

  if v_result is null then raise exception 'ORGANIZATION_NOT_FOUND'; end if;
  return v_result;
end;
$$;

create or replace function app_private.read_my_saved_items()
returns jsonb
language plpgsql
stable security definer
set search_path=''
as $$
declare v_actor uuid:=app_private.current_account_id();
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
  return jsonb_build_object(
    'teachers',coalesce((
      select jsonb_agg(jsonb_build_object(
        'teacher_account_id',a.id,'display_name',a.display_name,'headline',p.headline,
        'visibility_status',p.visibility_status,'account_lifecycle_status',a.lifecycle_status,'saved_at',s.created_at
      ) order by s.created_at desc,a.id)
      from public.saved_teacher_profiles s
      join public.accounts a on a.id=s.teacher_account_id
      left join public.teacher_profiles p on p.account_id=a.id
      where s.account_id=v_actor
    ),'[]'::jsonb),
    'teaching_options',coalesce((
      select jsonb_agg(jsonb_build_object(
        'teaching_option_id',t.id,'title',t.title,'category',t.category,'teaching_mode',t.teaching_mode,
        'availability_status',t.availability_status,'provider_type',case when t.teacher_account_id is not null then 'teacher' else 'organization' end,
        'provider_id',coalesce(t.teacher_account_id,t.organization_id),'provider_name',coalesce(a.display_name,o.name),'saved_at',s.created_at
      ) order by s.created_at desc,t.id)
      from public.saved_teaching_options s
      join public.teaching_options t on t.id=s.teaching_option_id
      left join public.accounts a on a.id=t.teacher_account_id
      left join public.organizations o on o.id=t.organization_id
      where s.account_id=v_actor
    ),'[]'::jsonb),
    'organizations',coalesce((
      select jsonb_agg(jsonb_build_object(
        'organization_id',o.id,'name',o.name,'organization_type',o.organization_type,'status',o.status,
        'logo_type',o.logo_type,'logo_ref',o.logo_ref,'saved_at',s.created_at
      ) order by s.created_at desc,o.id)
      from public.saved_organizations s join public.organizations o on o.id=s.organization_id
      where s.account_id=v_actor
    ),'[]'::jsonb)
  );
end;
$$;

create or replace function app_private.read_my_ad_campaigns()
returns setof jsonb
language sql
stable security definer
set search_path=''
as $$
  select jsonb_build_object(
    'campaign_id',c.id,'account_id',c.account_id,'organization_id',c.organization_id,'objective',c.objective,
    'campaign_name',c.campaign_name,'audience_context',c.audience_context,'education_category',c.education_category,
    'starts_at',c.starts_at,'ends_at',c.ends_at,'state',c.state,'updated_at',c.updated_at,
    'latest_revision_id',(select r.id from public.ad_campaign_revisions r where r.campaign_id=c.id order by r.revision_number desc limit 1),
    'latest_revision_number',(select r.revision_number from public.ad_campaign_revisions r where r.campaign_id=c.id order by r.revision_number desc limit 1),
    'latest_revision_submitted_at',(select r.submitted_at from public.ad_campaign_revisions r where r.campaign_id=c.id order by r.revision_number desc limit 1),
    'target_count',(select count(*) from public.ad_campaign_targets t where t.campaign_id=c.id),
    'live_placement_count',(select count(*) from public.ad_placements p where p.campaign_id=c.id and p.state='live')
  )
  from public.ad_campaigns c
  where app_private.campaign_advertiser_authority(c.id)
  order by c.updated_at desc,c.id;
$$;

create or replace function app_private.read_ad_campaign_workspace(p_campaign_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path=''
as $$
declare
  v_global boolean:=false;
  v_result jsonb;
begin
  if not app_private.can_read_ad_campaign(p_campaign_id) then raise exception 'NOT_AUTHORIZED'; end if;
  v_global:=app_private.campaign_advertiser_authority(p_campaign_id)
    or app_private.has_account_capability('platform_admin')
    or app_private.has_account_capability('ads_commercial');

  select jsonb_build_object(
    'campaign',jsonb_build_object(
      'campaign_id',c.id,'account_id',c.account_id,'organization_id',c.organization_id,'objective',c.objective,
      'campaign_name',c.campaign_name,'audience_context',c.audience_context,'education_category',c.education_category,
      'starts_at',c.starts_at,'ends_at',c.ends_at,'state',c.state,'created_at',c.created_at,'updated_at',c.updated_at
    ),
    'targets',coalesce((
      select jsonb_agg(jsonb_build_object('location_id',t.location_id,'location_name',l.name,'placement_type',t.placement_type) order by l.name,t.placement_type)
      from public.ad_campaign_targets t join public.locations l on l.id=t.location_id
      where t.campaign_id=c.id and (v_global or app_private.has_location_staff_scope(t.location_id,'local_manager'))
    ),'[]'::jsonb),
    'revisions',coalesce((
      select jsonb_agg(jsonb_build_object(
        'revision_id',r.id,'revision_number',r.revision_number,'headline',r.headline,'body',r.body,'image_asset_id',r.image_asset_id,
        'destination_type',r.destination_type,'destination_id',r.destination_id,'external_url',r.external_url,'cta_type',r.cta_type,
        'submitted_at',r.submitted_at,'created_at',r.created_at,
        'reviews',coalesce((select jsonb_agg(jsonb_build_object(
          'review_id',rv.id,'review_scope',rv.review_scope,'location_id',rv.location_id,'state',rv.state,
          'reason',rv.reason,'details',rv.details,'decided_at',rv.decided_at,'updated_at',rv.updated_at
        ) order by rv.updated_at desc,rv.id)
        from public.ad_reviews rv
        where rv.campaign_revision_id=r.id and (v_global or (rv.location_id is not null and app_private.has_location_staff_scope(rv.location_id,'local_manager')))),'[]'::jsonb)
      ) order by r.revision_number desc)
      from public.ad_campaign_revisions r where r.campaign_id=c.id
    ),'[]'::jsonb),
    'commercial_clearance',case when v_global then (
      select jsonb_build_object('clearance_id',cc.id,'state',cc.state,'clearance_type',cc.clearance_type,'package_code',cc.package_code,
        'agreed_amount',cc.agreed_amount,'currency_code',cc.currency_code,'reason',cc.reason,'updated_at',cc.updated_at)
      from public.ad_commercial_clearances cc where cc.campaign_id=c.id
    ) else null end,
    'reservations',coalesce((
      select jsonb_agg(jsonb_build_object(
        'reservation_id',ar.id,'state',ar.state,'hold_expires_at',ar.hold_expires_at,'resolved_at',ar.resolved_at,'created_at',ar.created_at,
        'days',coalesce((select jsonb_agg(jsonb_build_object(
          'location_id',d.location_id,'placement_type',d.placement_type,'inventory_date',d.inventory_date,'units',rd.units
        ) order by d.inventory_date,d.location_id,d.placement_type)
        from public.ad_inventory_reservation_days rd join public.ad_inventory_days d on d.id=rd.inventory_day_id
        where rd.reservation_id=ar.id and (v_global or app_private.has_location_staff_scope(d.location_id,'local_manager'))),'[]'::jsonb)
      ) order by ar.created_at desc,ar.id)
      from public.ad_inventory_reservations ar
      where ar.campaign_id=c.id and (v_global or exists(
        select 1 from public.ad_inventory_reservation_days rd join public.ad_inventory_days d on d.id=rd.inventory_day_id
        where rd.reservation_id=ar.id and app_private.has_location_staff_scope(d.location_id,'local_manager')
      ))
    ),'[]'::jsonb),
    'placements',coalesce((
      select jsonb_agg(jsonb_build_object(
        'placement_id',p.id,'location_id',p.location_id,'placement_type',p.placement_type,'serving_revision_id',p.serving_revision_id,
        'starts_on',p.starts_on,'ends_on',p.ends_on,'state',p.state,'pause_reason',p.pause_reason
      ) order by p.starts_on,p.id)
      from public.ad_placements p
      where p.campaign_id=c.id and (v_global or app_private.has_location_staff_scope(p.location_id,'local_manager'))
    ),'[]'::jsonb),
    'global_authority',v_global
  ) into v_result
  from public.ad_campaigns c where c.id=p_campaign_id;

  if v_result is null then raise exception 'CAMPAIGN_NOT_FOUND'; end if;
  return v_result;
end;
$$;

create or replace function app_private.read_ad_review_queue(p_location_id uuid default null)
returns setof jsonb
language plpgsql
stable security definer
set search_path=''
as $$
begin
  if p_location_id is null then
    if not app_private.has_account_capability('platform_admin') then raise exception 'NOT_AUTHORIZED'; end if;
    return query
    select jsonb_build_object(
      'revision_id',r.id,'revision_number',r.revision_number,'campaign_id',c.id,'campaign_name',c.campaign_name,
      'headline',r.headline,'body',r.body,'submitted_at',r.submitted_at,'review_scope','platform',
      'current_review_state',(select rv.state from public.ad_reviews rv where rv.campaign_revision_id=r.id and rv.review_scope='platform' and rv.location_id is null order by rv.updated_at desc limit 1),
      'target_locations',coalesce((select jsonb_agg(jsonb_build_object('location_id',t.location_id,'location_name',l.name,'placement_type',t.placement_type) order by l.name,t.placement_type) from public.ad_campaign_targets t join public.locations l on l.id=t.location_id where t.campaign_id=c.id),'[]'::jsonb)
    )
    from public.ad_campaign_revisions r join public.ad_campaigns c on c.id=r.campaign_id
    where r.submitted_at is not null and c.state<>'closed'
      and not app_private.ad_reviewer_conflicted(r.id)
      and not exists(select 1 from public.ad_reviews rv where rv.campaign_revision_id=r.id and rv.review_scope='platform' and rv.location_id is null and rv.state in ('approved','rejected'))
    order by r.submitted_at,r.id;
  else
    if not (app_private.has_account_capability('platform_admin') or app_private.has_location_staff_scope(p_location_id,'local_manager')) then raise exception 'NOT_AUTHORIZED'; end if;
    return query
    select jsonb_build_object(
      'revision_id',r.id,'revision_number',r.revision_number,'campaign_id',c.id,'campaign_name',c.campaign_name,
      'headline',r.headline,'body',r.body,'submitted_at',r.submitted_at,'review_scope','local','location_id',p_location_id,
      'current_review_state',(select rv.state from public.ad_reviews rv where rv.campaign_revision_id=r.id and rv.review_scope='local' and rv.location_id=p_location_id order by rv.updated_at desc limit 1)
    )
    from public.ad_campaign_revisions r join public.ad_campaigns c on c.id=r.campaign_id
    where r.submitted_at is not null and c.state<>'closed'
      and exists(select 1 from public.ad_campaign_targets t where t.campaign_id=c.id and t.location_id=p_location_id)
      and not app_private.ad_reviewer_conflicted(r.id)
      and not exists(select 1 from public.ad_reviews rv where rv.campaign_revision_id=r.id and rv.review_scope='local' and rv.location_id=p_location_id and rv.state in ('approved','rejected'))
    order by r.submitted_at,r.id;
  end if;
end;
$$;

revoke all on function app_private.read_learner_transfer_options(uuid),app_private.read_organization_admin_workspace(uuid),app_private.read_my_saved_items(),app_private.read_my_ad_campaigns(),app_private.read_ad_campaign_workspace(uuid),app_private.read_ad_review_queue(uuid) from public,anon,authenticated,service_role;
grant execute on function app_private.read_learner_transfer_options(uuid),app_private.read_organization_admin_workspace(uuid),app_private.read_my_saved_items(),app_private.read_my_ad_campaigns(),app_private.read_ad_campaign_workspace(uuid),app_private.read_ad_review_queue(uuid) to authenticated;

create or replace function public.get_learner_transfer_options(p_source_membership_id uuid)
returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.read_learner_transfer_options(p_source_membership_id); $$;
create or replace function public.get_organization_admin_workspace(p_organization_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.read_organization_admin_workspace(p_organization_id); $$;
create or replace function public.get_my_saved_items()
returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.read_my_saved_items(); $$;
create or replace function public.get_my_ad_campaigns()
returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.read_my_ad_campaigns(); $$;
create or replace function public.get_ad_campaign_workspace(p_campaign_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.read_ad_campaign_workspace(p_campaign_id); $$;
create or replace function public.get_ad_review_queue(p_location_id uuid default null)
returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.read_ad_review_queue(p_location_id); $$;

revoke all on function public.get_learner_transfer_options(uuid),public.get_organization_admin_workspace(uuid),public.get_my_saved_items(),public.get_my_ad_campaigns(),public.get_ad_campaign_workspace(uuid),public.get_ad_review_queue(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_learner_transfer_options(uuid),public.get_organization_admin_workspace(uuid),public.get_my_saved_items(),public.get_my_ad_campaigns(),public.get_ad_campaign_workspace(uuid),public.get_ad_review_queue(uuid) to authenticated;
