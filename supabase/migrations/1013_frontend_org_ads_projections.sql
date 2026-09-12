-- Raahi Learning V1.2 — secure Organization administration and Ads integration projections.
-- Read models only; state transitions continue to use canonical commands.

create or replace function app_private.read_organization_members(p_organization_id uuid)
returns setof jsonb
language plpgsql
stable security definer
set search_path=''
as $$
begin
  if not (app_private.has_organization_member_capability(p_organization_id,'manage_members') or app_private.has_account_capability('platform_admin')) then
    raise exception 'NOT_AUTHORIZED';
  end if;
  return query
  select jsonb_build_object(
    'organization_member_id',om.id,
    'organization_id',om.organization_id,
    'account_id',om.account_id,
    'display_name',a.display_name,
    'account_lifecycle_status',a.lifecycle_status,
    'status',om.status,
    'created_at',om.created_at,
    'ended_at',om.ended_at,
    'capabilities',coalesce((
      select jsonb_agg(c.capability_code order by c.capability_code)
      from public.organization_member_capabilities c
      where c.organization_member_id=om.id
    ),'[]'::jsonb)
  )
  from public.organization_members om
  join public.accounts a on a.id=om.account_id
  where om.organization_id=p_organization_id
  order by case om.status when 'active' then 0 else 1 end,a.display_name,om.id;
end;
$$;

create or replace function app_private.read_my_ad_campaigns()
returns setof jsonb
language sql
stable security definer
set search_path=''
as $$
  select jsonb_build_object(
    'campaign_id',c.id,
    'account_id',c.account_id,
    'organization_id',c.organization_id,
    'owner_name',coalesce(a.display_name,o.name),
    'objective',c.objective,
    'campaign_name',c.campaign_name,
    'audience_context',c.audience_context,
    'education_category',c.education_category,
    'starts_at',c.starts_at,
    'ends_at',c.ends_at,
    'state',c.state,
    'commercial_state',cc.state,
    'latest_revision_id',(select r.id from public.ad_campaign_revisions r where r.campaign_id=c.id order by r.revision_number desc limit 1),
    'latest_revision_number',(select r.revision_number from public.ad_campaign_revisions r where r.campaign_id=c.id order by r.revision_number desc limit 1),
    'latest_revision_submitted_at',(select r.submitted_at from public.ad_campaign_revisions r where r.campaign_id=c.id order by r.revision_number desc limit 1),
    'created_at',c.created_at,
    'updated_at',c.updated_at
  )
  from public.ad_campaigns c
  left join public.accounts a on a.id=c.account_id
  left join public.organizations o on o.id=c.organization_id
  left join public.ad_commercial_clearances cc on cc.campaign_id=c.id
  where app_private.has_advertiser_authority(c.account_id,c.organization_id)
  order by c.updated_at desc,c.id;
$$;

create or replace function app_private.read_ad_campaign_workspace(p_campaign_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path=''
as $$
declare v_account uuid; v_org uuid; v_result jsonb;
begin
  select account_id,organization_id into v_account,v_org from public.ad_campaigns where id=p_campaign_id;
  if not found then return null; end if;
  if not (app_private.has_advertiser_authority(v_account,v_org) or app_private.has_account_capability('platform_admin') or app_private.has_account_capability('ads_commercial')) then
    raise exception 'NOT_AUTHORIZED';
  end if;

  select jsonb_build_object(
    'campaign',jsonb_build_object(
      'campaign_id',c.id,'account_id',c.account_id,'organization_id',c.organization_id,
      'owner_name',coalesce(a.display_name,o.name),'objective',c.objective,'campaign_name',c.campaign_name,
      'audience_context',c.audience_context,'education_category',c.education_category,
      'starts_at',c.starts_at,'ends_at',c.ends_at,'state',c.state,'created_at',c.created_at,'updated_at',c.updated_at
    ),
    'targets',coalesce((select jsonb_agg(jsonb_build_object('location_id',t.location_id,'location_name',l.name,'placement_type',t.placement_type) order by l.name,t.placement_type) from public.ad_campaign_targets t join public.locations l on l.id=t.location_id where t.campaign_id=c.id),'[]'::jsonb),
    'revisions',coalesce((select jsonb_agg(jsonb_build_object(
      'revision_id',r.id,'revision_number',r.revision_number,'headline',r.headline,'body',r.body,'image_asset_id',r.image_asset_id,
      'destination_type',r.destination_type,'destination_id',r.destination_id,'external_url',r.external_url,'cta_type',r.cta_type,
      'submitted_at',r.submitted_at,'created_at',r.created_at,
      'reviews',coalesce((select jsonb_agg(jsonb_build_object('review_id',rv.id,'review_scope',rv.review_scope,'location_id',rv.location_id,'state',rv.state,'reason',rv.reason,'details',rv.details,'decided_at',rv.decided_at) order by rv.created_at,rv.id) from public.ad_reviews rv where rv.campaign_revision_id=r.id),'[]'::jsonb)
    ) order by r.revision_number desc) from public.ad_campaign_revisions r where r.campaign_id=c.id),'[]'::jsonb),
    'commercial',(select jsonb_build_object('clearance_id',cc.id,'state',cc.state,'clearance_type',cc.clearance_type,'package_code',cc.package_code,'agreed_amount',cc.agreed_amount,'currency_code',cc.currency_code,'reason',cc.reason,'updated_at',cc.updated_at) from public.ad_commercial_clearances cc where cc.campaign_id=c.id),
    'reservations',coalesce((select jsonb_agg(jsonb_build_object('reservation_id',ir.id,'state',ir.state,'hold_expires_at',ir.hold_expires_at,'resolved_at',ir.resolved_at,'created_at',ir.created_at) order by ir.created_at desc) from public.ad_inventory_reservations ir where ir.campaign_id=c.id),'[]'::jsonb),
    'placements',coalesce((select jsonb_agg(jsonb_build_object('placement_id',p.id,'location_id',p.location_id,'location_name',l2.name,'placement_type',p.placement_type,'serving_revision_id',p.serving_revision_id,'starts_on',p.starts_on,'ends_on',p.ends_on,'state',p.state,'pause_reason',p.pause_reason) order by p.starts_on,p.id) from public.ad_placements p join public.locations l2 on l2.id=p.location_id where p.campaign_id=c.id),'[]'::jsonb)
  ) into v_result
  from public.ad_campaigns c
  left join public.accounts a on a.id=c.account_id
  left join public.organizations o on o.id=c.organization_id
  where c.id=p_campaign_id;
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
  elsif not (app_private.has_location_staff_scope(p_location_id,'local_manager') or app_private.has_account_capability('platform_admin')) then
    raise exception 'NOT_AUTHORIZED';
  end if;

  return query
  select jsonb_build_object(
    'campaign_id',c.id,
    'campaign_name',c.campaign_name,
    'owner_name',coalesce(a.display_name,o.name),
    'organization_id',c.organization_id,
    'account_id',c.account_id,
    'revision_id',r.id,
    'revision_number',r.revision_number,
    'headline',r.headline,
    'body',r.body,
    'image_asset_id',r.image_asset_id,
    'destination_type',r.destination_type,
    'destination_id',r.destination_id,
    'external_url',r.external_url,
    'cta_type',r.cta_type,
    'submitted_at',r.submitted_at,
    'target_placements',coalesce((select jsonb_agg(jsonb_build_object('location_id',t.location_id,'location_name',l.name,'placement_type',t.placement_type) order by l.name,t.placement_type) from public.ad_campaign_targets t join public.locations l on l.id=t.location_id where t.campaign_id=c.id and (p_location_id is null or t.location_id=p_location_id)),'[]'::jsonb),
    'review_state',rv.state,
    'review_reason',rv.reason,
    'review_details',rv.details,
    'review_id',rv.id,
    'commercial_state',cc.state,
    'review_conflicted',app_private.ad_reviewer_conflicted(r.id)
  )
  from public.ad_campaign_revisions r
  join public.ad_campaigns c on c.id=r.campaign_id and c.state<>'closed'
  left join public.accounts a on a.id=c.account_id
  left join public.organizations o on o.id=c.organization_id
  left join public.ad_commercial_clearances cc on cc.campaign_id=c.id
  left join public.ad_reviews rv on rv.campaign_revision_id=r.id
    and rv.review_scope=case when p_location_id is null then 'platform' else 'local' end
    and rv.location_id is not distinct from p_location_id
  where r.submitted_at is not null
    and (p_location_id is null or exists(select 1 from public.ad_campaign_targets t where t.campaign_id=c.id and t.location_id=p_location_id))
  order by r.submitted_at,r.id;
end;
$$;

revoke all on function app_private.read_organization_members(uuid),app_private.read_my_ad_campaigns(),app_private.read_ad_campaign_workspace(uuid),app_private.read_ad_review_queue(uuid) from public,anon,authenticated,service_role;
grant execute on function app_private.read_organization_members(uuid),app_private.read_my_ad_campaigns(),app_private.read_ad_campaign_workspace(uuid),app_private.read_ad_review_queue(uuid) to authenticated;

create or replace function public.get_organization_members(p_organization_id uuid)
returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.read_organization_members(p_organization_id); $$;
create or replace function public.get_my_ad_campaigns()
returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.read_my_ad_campaigns(); $$;
create or replace function public.get_ad_campaign_workspace(p_campaign_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.read_ad_campaign_workspace(p_campaign_id); $$;
create or replace function public.get_ad_review_queue(p_location_id uuid default null)
returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.read_ad_review_queue(p_location_id); $$;

revoke all on function public.get_organization_members(uuid),public.get_my_ad_campaigns(),public.get_ad_campaign_workspace(uuid),public.get_ad_review_queue(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_organization_members(uuid),public.get_my_ad_campaigns(),public.get_ad_campaign_workspace(uuid),public.get_ad_review_queue(uuid) to authenticated;
