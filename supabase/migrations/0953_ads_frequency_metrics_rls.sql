-- Raahi Learning V1.2 — Sponsored serving, frequency privacy, aggregate metrics and inventory RLS.

create or replace function app_private.ad_surface_placement_type(p_surface text)
returns text language sql immutable set search_path='' as $$
  select case p_surface
    when 'home' then 'home_sponsored'
    when 'explore' then 'explore_sponsored'
    when 'community' then 'community_event'
    else null
  end;
$$;

create or replace function app_private.can_read_ad_reservation(p_reservation_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.ad_inventory_reservations r
    where r.id=p_reservation_id and (
      app_private.can_read_ad_campaign(r.campaign_id)
      or exists(
        select 1 from public.ad_inventory_reservation_days rd join public.ad_inventory_days d on d.id=rd.inventory_day_id
        where rd.reservation_id=r.id and app_private.can_manage_ad_inventory(d.location_id)
      )
    )
  );
$$;

create or replace function app_private.can_read_ad_placement(p_placement_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.ad_placements p
    where p.id=p_placement_id and (
      app_private.can_read_ad_campaign(p.campaign_id)
      or app_private.can_manage_ad_inventory(p.location_id)
    )
  );
$$;

create or replace function app_private.get_ad_inventory_availability(
  p_location_id uuid,p_placement_type text,p_start_date date,p_end_date date
)
returns setof jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'inventory_date',d.inventory_date,
    'placement_type',d.placement_type,
    'capacity',d.capacity,
    'remaining_units',greatest(d.capacity-coalesce((
      select sum(rd.units)::int from public.ad_inventory_reservation_days rd
      join public.ad_inventory_reservations r on r.id=rd.reservation_id
      where rd.inventory_day_id=d.id and (r.state='confirmed' or (r.state='held' and r.hold_expires_at>now()))
    ),0),0),
    'max_units_per_campaign',d.max_units_per_campaign,
    'rate_card_code',d.rate_card_code
  )
  from public.ad_inventory_days d
  join public.locations l on l.id=d.location_id and l.state='live'
  where d.location_id=p_location_id and d.placement_type=p_placement_type
    and d.inventory_date between p_start_date and p_end_date
  order by d.inventory_date;
$$;

create or replace function app_private.serve_sponsored_candidate(p_location_id uuid,p_surface text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(false); v_type text; v_candidate record;
  v_window timestamptz; v_count int; v_result jsonb;
begin
  if v_actor is null then return null; end if;
  if not exists(select 1 from public.accounts where id=v_actor and lifecycle_status='active') then return null; end if;
  v_type:=app_private.ad_surface_placement_type(p_surface);
  -- Every unrecognized/private learning surface is deliberately ad-free.
  if v_type is null then return null; end if;
  if not exists(select 1 from public.locations where id=p_location_id and state='live') then return null; end if;

  for v_candidate in
    select p.id as placement_id,p.campaign_id,p.serving_revision_id,p.location_id,p.placement_type,p.inventory_reservation_id,p.starts_on,p.ends_on,
           r.headline,r.body,r.image_asset_id,r.destination_type,r.destination_id,r.external_url,r.cta_type,
           d.per_account_daily_cap
      from public.ad_placements p
      join public.ad_campaigns c on c.id=p.campaign_id
      join public.ad_campaign_revisions r on r.id=p.serving_revision_id
      join public.ad_inventory_reservation_days rd on rd.reservation_id=p.inventory_reservation_id
      join public.ad_inventory_days d on d.id=rd.inventory_day_id and d.inventory_date=current_date and d.location_id=p.location_id and d.placement_type=p.placement_type
     where p.location_id=p_location_id and p.placement_type=v_type and p.state='live'
       and current_date between p.starts_on and p.ends_on
       and now() between c.starts_at and c.ends_at
       and not exists(select 1 from public.hidden_campaigns h where h.account_id=v_actor and h.campaign_id=p.campaign_id)
       and app_private.ad_placement_prerequisites_ok(p.campaign_id,p.location_id,p.placement_type,p.inventory_reservation_id,p.serving_revision_id,p.starts_on,p.ends_on)
     order by md5(v_actor::text||current_date::text||p.id::text)
  loop
    insert into public.ad_frequency_state(account_id,campaign_id,window_started_at,served_count)
    values(v_actor,v_candidate.campaign_id,date_trunc('day',now()),0)
    on conflict (account_id,campaign_id) do nothing;

    select window_started_at,served_count into v_window,v_count
      from public.ad_frequency_state
     where account_id=v_actor and campaign_id=v_candidate.campaign_id
     for update;
    if v_window::date<>current_date then
      update public.ad_frequency_state
         set window_started_at=date_trunc('day',now()),served_count=0,last_served_at=null
       where account_id=v_actor and campaign_id=v_candidate.campaign_id;
      v_count:=0;
    end if;
    if v_count>=v_candidate.per_account_daily_cap then continue; end if;

    update public.ad_frequency_state set served_count=served_count+1,last_served_at=now()
     where account_id=v_actor and campaign_id=v_candidate.campaign_id;
    insert into public.ad_metrics_daily(ad_placement_id,metric_date,sponsored_views)
    values(v_candidate.placement_id,current_date,1)
    on conflict (ad_placement_id,metric_date) do update set sponsored_views=public.ad_metrics_daily.sponsored_views+1;

    v_result:=jsonb_build_object(
      'sponsored',true,'placement_id',v_candidate.placement_id,'campaign_id',v_candidate.campaign_id,
      'serving_revision_id',v_candidate.serving_revision_id,'headline',v_candidate.headline,'body',v_candidate.body,
      'image_asset_id',v_candidate.image_asset_id,'destination_type',v_candidate.destination_type,
      'destination_id',v_candidate.destination_id,'external_url',v_candidate.external_url,'cta_type',v_candidate.cta_type,
      'location_id',v_candidate.location_id,'placement_type',v_candidate.placement_type
    );
    return v_result;
  end loop;
  return null;
end; $$;

create or replace function app_private.cmd_hide_sponsored_campaign(p_campaign_id uuid,p_hidden boolean,p_reason text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(false); v_gate jsonb; v_fp text; v_changed boolean:=false; v_result jsonb;
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('campaign_id',p_campaign_id,'hidden',p_hidden,'reason',p_reason));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'hide_sponsored_campaign',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if not exists(select 1 from public.ad_campaigns where id=p_campaign_id) then raise exception 'CAMPAIGN_NOT_FOUND'; end if;
  if p_hidden then
    insert into public.hidden_campaigns(account_id,campaign_id,hide_reason) values(v_actor,p_campaign_id,nullif(btrim(p_reason),''))
    on conflict (account_id,campaign_id) do update set hide_reason=excluded.hide_reason;
    v_changed:=true;
  else
    delete from public.hidden_campaigns where account_id=v_actor and campaign_id=p_campaign_id;
    get diagnostics v_changed=row_count;
  end if;
  v_result:=jsonb_build_object('campaign_id',p_campaign_id,'hidden',p_hidden,'changed',v_changed);
  perform app_private.complete_human_idempotent_command(v_actor,'hide_sponsored_campaign',p_idempotency_key,v_result);
  return v_result;
end; $$;

create or replace function app_private.cmd_record_sponsored_interaction(p_placement_id uuid,p_interaction text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(false); v_gate jsonb; v_fp text; v_campaign uuid; v_result jsonb;
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_interaction not in ('open','external_visit') then raise exception 'INVALID_SPONSORED_INTERACTION'; end if;
  select campaign_id into v_campaign from public.ad_placements where id=p_placement_id;
  if not found then raise exception 'PLACEMENT_NOT_FOUND'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('placement_id',p_placement_id,'interaction',p_interaction));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'record_sponsored_interaction',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if p_interaction='open' then
    insert into public.ad_metrics_daily(ad_placement_id,metric_date,opens) values(p_placement_id,current_date,1)
    on conflict (ad_placement_id,metric_date) do update set opens=public.ad_metrics_daily.opens+1;
  else
    insert into public.ad_metrics_daily(ad_placement_id,metric_date,external_visits) values(p_placement_id,current_date,1)
    on conflict (ad_placement_id,metric_date) do update set external_visits=public.ad_metrics_daily.external_visits+1;
  end if;
  v_result:=jsonb_build_object('placement_id',p_placement_id,'interaction',p_interaction,'recorded',true);
  perform app_private.complete_human_idempotent_command(v_actor,'record_sponsored_interaction',p_idempotency_key,v_result);
  return v_result;
end; $$;

create or replace function app_private.cmd_send_sponsored_enquiry(
  p_placement_id uuid,p_learner_id uuid,p_opening_message text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_campaign uuid; v_location uuid; v_revision uuid; v_teaching_option uuid; v_cta text;
  v_provider_account uuid; v_provider_org uuid; v_availability text; v_enquiry uuid; v_result jsonb;
begin
  if not app_private.can_make_learning_decision(p_learner_id) then raise exception 'NOT_AUTHORIZED'; end if;
  select p.campaign_id,p.location_id,p.serving_revision_id,r.destination_id,r.cta_type
    into v_campaign,v_location,v_revision,v_teaching_option,v_cta
    from public.ad_placements p join public.ad_campaign_revisions r on r.id=p.serving_revision_id
   where p.id=p_placement_id and p.state='live' and current_date between p.starts_on and p.ends_on
     and app_private.ad_placement_prerequisites_ok(p.campaign_id,p.location_id,p.placement_type,p.inventory_reservation_id,p.serving_revision_id,p.starts_on,p.ends_on);
  if not found then raise exception 'SPONSORED_PLACEMENT_NOT_ELIGIBLE'; end if;
  if v_cta<>'enquire' or not exists(select 1 from public.ad_campaign_revisions where id=v_revision and destination_type='teaching_option') then raise exception 'SPONSORED_ENQUIRY_NOT_SUPPORTED'; end if;
  if not exists(select 1 from public.locations where id=v_location and state='live') then raise exception 'LOCATION_NOT_LIVE'; end if;
  select teacher_account_id,organization_id,availability_status into v_provider_account,v_provider_org,v_availability from public.teaching_options where id=v_teaching_option;
  if not found then raise exception 'TEACHING_OPTION_NOT_FOUND'; end if;
  if v_availability<>'taking_new_learners' then raise exception 'TEACHING_OPTION_NOT_TAKING_LEARNERS'; end if;
  if not exists(select 1 from public.teaching_option_locations where teaching_option_id=v_teaching_option and location_id=v_location) then raise exception 'TEACHING_OPTION_NOT_IN_LOCATION'; end if;
  if v_provider_account is not null then
    if not exists(select 1 from public.teacher_profiles tp join public.accounts a on a.id=tp.account_id where tp.account_id=v_provider_account and tp.visibility_status='visible' and a.lifecycle_status='active') then raise exception 'PROVIDER_NOT_PUBLIC'; end if;
    if app_private.has_active_account_restriction(v_provider_account,'public_discovery',v_location) or app_private.has_active_account_restriction(v_provider_account,'new_enquiries',v_location) then raise exception 'PROVIDER_RESTRICTED'; end if;
  else
    if not exists(select 1 from public.organizations where id=v_provider_org and status='active') then raise exception 'PROVIDER_NOT_PUBLIC'; end if;
    if app_private.has_active_organization_restriction(v_provider_org,'public_discovery',v_location) or app_private.has_active_organization_restriction(v_provider_org,'new_enquiries',v_location) then raise exception 'PROVIDER_RESTRICTED'; end if;
  end if;
  if app_private.has_active_account_restriction(v_actor,'new_enquiries',v_location) then raise exception 'ACCOUNT_RESTRICTED'; end if;
  if nullif(btrim(p_opening_message),'') is not null and (
       app_private.has_active_account_restriction(v_actor,'messaging',v_location)
       or (v_provider_account is not null and app_private.has_active_account_restriction(v_provider_account,'messaging',v_location))
       or (v_provider_org is not null and app_private.has_active_organization_restriction(v_provider_org,'messaging',v_location))
     ) then raise exception 'MESSAGING_RESTRICTED'; end if;
  if p_opening_message is not null and char_length(p_opening_message)>8000 then raise exception 'MESSAGE_TOO_LONG'; end if;

  v_fp:=app_private.request_fingerprint(jsonb_build_object('placement_id',p_placement_id,'learner_id',p_learner_id,'opening_message',p_opening_message));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'send_sponsored_enquiry',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if exists(select 1 from public.enquiries where learner_id=p_learner_id and teaching_option_id=v_teaching_option and source_type in ('direct','sponsored') and state in ('pending','active')) then raise exception 'DUPLICATE_ACTIVE_ENQUIRY'; end if;

  insert into public.enquiries(learner_id,created_by_account_id,location_id,provider_account_id,provider_organization_id,teaching_option_id,source_type,source_campaign_id,state)
  values(p_learner_id,v_actor,v_location,v_provider_account,v_provider_org,v_teaching_option,'sponsored',v_campaign,'pending') returning id into v_enquiry;
  if nullif(btrim(p_opening_message),'') is not null then insert into public.enquiry_messages(enquiry_id,sender_account_id,body,message_type) values(v_enquiry,v_actor,btrim(p_opening_message),'controlled_structured'); end if;
  insert into public.ad_metrics_daily(ad_placement_id,metric_date,enquiries) values(p_placement_id,current_date,1)
  on conflict (ad_placement_id,metric_date) do update set enquiries=public.ad_metrics_daily.enquiries+1;
  perform app_private.write_audit(v_actor,'enquiry.create','enquiry',v_enquiry,p_learner_id,null,jsonb_build_object('source_type','sponsored','source_campaign_id',v_campaign,'placement_id',p_placement_id,'location_id',v_location));
  v_result:=jsonb_build_object('enquiry_id',v_enquiry,'state','pending','source_type','sponsored','source_campaign_id',v_campaign);
  perform app_private.complete_human_idempotent_command(v_actor,'send_sponsored_enquiry',p_idempotency_key,v_result);
  return v_result;
end; $$;

create or replace function app_private.get_ad_campaign_metrics(p_campaign_id uuid)
returns setof jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('placement_id',p.id,'location_id',p.location_id,'placement_type',p.placement_type,'metric_date',m.metric_date,
    'sponsored_views',m.sponsored_views,'opens',m.opens,'enquiries',m.enquiries,'external_visits',m.external_visits)
  from public.ad_placements p join public.ad_metrics_daily m on m.ad_placement_id=p.id
  where p.campaign_id=p_campaign_id and app_private.can_read_ad_campaign(p_campaign_id)
  order by m.metric_date,p.id;
$$;

alter table public.ad_inventory_days enable row level security; alter table public.ad_inventory_days force row level security;
alter table public.ad_inventory_reservations enable row level security; alter table public.ad_inventory_reservations force row level security;
alter table public.ad_inventory_reservation_days enable row level security; alter table public.ad_inventory_reservation_days force row level security;
alter table public.ad_placements enable row level security; alter table public.ad_placements force row level security;
alter table public.hidden_campaigns enable row level security; alter table public.hidden_campaigns force row level security;
alter table public.ad_frequency_state enable row level security; alter table public.ad_frequency_state force row level security;
alter table public.ad_metrics_daily enable row level security; alter table public.ad_metrics_daily force row level security;

create policy ad_inventory_days_ops_select on public.ad_inventory_days for select to authenticated using(app_private.can_manage_ad_inventory(location_id));
create policy ad_inventory_reservations_authorized_select on public.ad_inventory_reservations for select to authenticated using(app_private.can_read_ad_reservation(id));
create policy ad_inventory_reservation_days_authorized_select on public.ad_inventory_reservation_days for select to authenticated using(app_private.can_read_ad_reservation(reservation_id));
create policy ad_placements_authorized_select on public.ad_placements for select to authenticated using(app_private.can_read_ad_placement(id));
create policy hidden_campaigns_self_select on public.hidden_campaigns for select to authenticated using(account_id=app_private.current_account_id() or app_private.has_account_capability('platform_admin'));
create policy ad_frequency_state_self_select on public.ad_frequency_state for select to authenticated using(account_id=app_private.current_account_id() or app_private.has_account_capability('platform_admin'));
create policy ad_metrics_daily_aggregate_select on public.ad_metrics_daily for select to authenticated using(app_private.can_read_ad_placement(ad_placement_id));

revoke all on table public.ad_inventory_days,public.ad_inventory_reservations,public.ad_inventory_reservation_days,public.ad_placements,public.hidden_campaigns,public.ad_frequency_state,public.ad_metrics_daily from public,anon,authenticated,service_role;
grant select on table public.ad_inventory_days,public.ad_inventory_reservations,public.ad_inventory_reservation_days,public.ad_placements,public.hidden_campaigns,public.ad_frequency_state,public.ad_metrics_daily to authenticated;
grant select,insert,update,delete on table public.ad_inventory_days,public.ad_inventory_reservations,public.ad_inventory_reservation_days,public.ad_placements,public.hidden_campaigns,public.ad_frequency_state,public.ad_metrics_daily to service_role;

revoke all on function app_private.ad_surface_placement_type(text),app_private.can_read_ad_reservation(uuid),app_private.can_read_ad_placement(uuid),app_private.get_ad_inventory_availability(uuid,text,date,date),app_private.serve_sponsored_candidate(uuid,text),app_private.cmd_hide_sponsored_campaign(uuid,boolean,text,text),app_private.cmd_record_sponsored_interaction(uuid,text,text),app_private.cmd_send_sponsored_enquiry(uuid,uuid,text,text),app_private.get_ad_campaign_metrics(uuid) from public,anon,authenticated,service_role;
grant execute on function app_private.can_read_ad_reservation(uuid),app_private.can_read_ad_placement(uuid),app_private.get_ad_inventory_availability(uuid,text,date,date),app_private.serve_sponsored_candidate(uuid,text),app_private.cmd_hide_sponsored_campaign(uuid,boolean,text,text),app_private.cmd_record_sponsored_interaction(uuid,text,text),app_private.cmd_send_sponsored_enquiry(uuid,uuid,text,text),app_private.get_ad_campaign_metrics(uuid) to authenticated;

create or replace function public.get_ad_inventory_availability(p_location_id uuid,p_placement_type text,p_start_date date,p_end_date date)
returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.get_ad_inventory_availability(p_location_id,p_placement_type,p_start_date,p_end_date); $$;
create or replace function public.get_sponsored_candidate(p_location_id uuid,p_surface text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.serve_sponsored_candidate(p_location_id,p_surface); $$;
create or replace function public.hide_sponsored_campaign(p_campaign_id uuid,p_hidden boolean,p_reason text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_hide_sponsored_campaign(p_campaign_id,p_hidden,p_reason,p_idempotency_key); $$;
create or replace function public.record_sponsored_interaction(p_placement_id uuid,p_interaction text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_record_sponsored_interaction(p_placement_id,p_interaction,p_idempotency_key); $$;
create or replace function public.send_sponsored_enquiry(p_placement_id uuid,p_learner_id uuid,p_opening_message text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_send_sponsored_enquiry(p_placement_id,p_learner_id,p_opening_message,p_idempotency_key); $$;
create or replace function public.get_ad_campaign_metrics(p_campaign_id uuid)
returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.get_ad_campaign_metrics(p_campaign_id); $$;
revoke all on function public.get_ad_inventory_availability(uuid,text,date,date),public.get_sponsored_candidate(uuid,text),public.hide_sponsored_campaign(uuid,boolean,text,text),public.record_sponsored_interaction(uuid,text,text),public.send_sponsored_enquiry(uuid,uuid,text,text),public.get_ad_campaign_metrics(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_ad_inventory_availability(uuid,text,date,date),public.get_sponsored_candidate(uuid,text),public.hide_sponsored_campaign(uuid,boolean,text,text),public.record_sponsored_interaction(uuid,text,text),public.send_sponsored_enquiry(uuid,uuid,text,text),public.get_ad_campaign_metrics(uuid) to authenticated;
