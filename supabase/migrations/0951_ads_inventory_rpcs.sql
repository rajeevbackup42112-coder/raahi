-- Raahi Learning V1.2 — finite Ads inventory reservation and commercial booking commands.

create or replace function app_private.ad_inventory_hold_ttl()
returns interval language sql immutable set search_path='' as $$ select interval '30 minutes'; $$;

create or replace function app_private.can_manage_ad_inventory(p_location_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select app_private.has_account_capability('platform_admin')
      or app_private.has_account_capability('ads_commercial')
      or app_private.has_location_staff_scope(p_location_id,'local_manager');
$$;

create or replace function app_private.expire_ad_inventory_holds_for_days(p_day_ids uuid[])
returns integer language plpgsql security definer set search_path='' as $$
declare v_count integer;
begin
  update public.ad_inventory_reservations r
     set state='expired',resolved_at=now()
   where r.state='held'
     and r.hold_expires_at<=now()
     and exists(
       select 1 from public.ad_inventory_reservation_days rd
       where rd.reservation_id=r.id and rd.inventory_day_id=any(p_day_ids)
     );
  get diagnostics v_count=row_count;
  return v_count;
end; $$;

create or replace function app_private.cmd_configure_ad_inventory_day(
  p_location_id uuid,p_placement_type text,p_inventory_date date,p_capacity integer,
  p_max_units_per_campaign integer,p_per_account_daily_cap integer,p_rate_card_code text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_day uuid; v_obligated integer:=0; v_result jsonb;
begin
  if not app_private.can_manage_ad_inventory(p_location_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if not exists(select 1 from public.locations where id=p_location_id and state<>'retired') then raise exception 'LOCATION_NOT_AVAILABLE'; end if;
  if p_placement_type not in ('home_sponsored','explore_sponsored','community_event') then raise exception 'INVALID_PLACEMENT_TYPE'; end if;
  if p_inventory_date is null or p_inventory_date<current_date then raise exception 'INVALID_INVENTORY_DATE'; end if;
  if p_capacity is null or p_capacity<0 then raise exception 'INVALID_INVENTORY_CAPACITY'; end if;
  if p_max_units_per_campaign is null or p_max_units_per_campaign<0 or p_max_units_per_campaign>p_capacity then raise exception 'INVALID_CAMPAIGN_CONCENTRATION_CAP'; end if;
  if p_per_account_daily_cap is null or p_per_account_daily_cap<1 then raise exception 'INVALID_FREQUENCY_CAP'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('location_id',p_location_id,'placement_type',p_placement_type,'inventory_date',p_inventory_date,'capacity',p_capacity,'max_units_per_campaign',p_max_units_per_campaign,'per_account_daily_cap',p_per_account_daily_cap,'rate_card_code',p_rate_card_code));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'configure_ad_inventory_day',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select id into v_day from public.ad_inventory_days
   where location_id=p_location_id and placement_type=p_placement_type and inventory_date=p_inventory_date
   for update;

  if v_day is not null then
    perform app_private.expire_ad_inventory_holds_for_days(array[v_day]);
    select coalesce(sum(rd.units),0)::int into v_obligated
      from public.ad_inventory_reservation_days rd
      join public.ad_inventory_reservations r on r.id=rd.reservation_id
     where rd.inventory_day_id=v_day
       and (r.state='confirmed' or (r.state='held' and r.hold_expires_at>now()));
    if p_capacity<v_obligated then raise exception 'CAPACITY_BELOW_EXISTING_OBLIGATIONS:%',v_obligated; end if;
    update public.ad_inventory_days
       set capacity=p_capacity,max_units_per_campaign=p_max_units_per_campaign,
           per_account_daily_cap=p_per_account_daily_cap,rate_card_code=nullif(btrim(p_rate_card_code),'')
     where id=v_day;
  else
    insert into public.ad_inventory_days(location_id,placement_type,inventory_date,capacity,max_units_per_campaign,per_account_daily_cap,rate_card_code)
    values(p_location_id,p_placement_type,p_inventory_date,p_capacity,p_max_units_per_campaign,p_per_account_daily_cap,nullif(btrim(p_rate_card_code),''))
    returning id into v_day;
  end if;

  perform app_private.write_audit(v_actor,'ads.inventory_configure','ad_inventory_day',v_day,null,null,jsonb_build_object('location_id',p_location_id,'placement_type',p_placement_type,'inventory_date',p_inventory_date,'capacity',p_capacity));
  v_result:=jsonb_build_object('inventory_day_id',v_day,'capacity',p_capacity,'obligated',v_obligated);
  perform app_private.complete_human_idempotent_command(v_actor,'configure_ad_inventory_day',p_idempotency_key,v_result);
  return v_result;
end; $$;

create or replace function app_private.cmd_reserve_ad_inventory(
  p_campaign_id uuid,p_location_id uuid,p_placement_type text,p_start_date date,p_end_date date,p_units integer,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_account uuid; v_org uuid; v_campaign_state text; v_campaign_start date; v_campaign_end date;
  v_expected int; v_actual int; v_day_ids uuid[]; v_day record; v_total int; v_campaign_total int;
  v_reservation uuid; v_hold_expires timestamptz; v_result jsonb;
begin
  if not (app_private.campaign_advertiser_authority(p_campaign_id) or app_private.has_account_capability('ads_commercial')) then raise exception 'NOT_AUTHORIZED'; end if;
  if p_placement_type not in ('home_sponsored','explore_sponsored','community_event') then raise exception 'INVALID_PLACEMENT_TYPE'; end if;
  if p_start_date is null or p_end_date is null or p_end_date<p_start_date or p_start_date<current_date then raise exception 'INVALID_RESERVATION_DATES'; end if;
  if p_units is null or p_units<1 then raise exception 'INVALID_RESERVATION_UNITS'; end if;

  select account_id,organization_id,state,starts_at::date,ends_at::date
    into v_account,v_org,v_campaign_state,v_campaign_start,v_campaign_end
    from public.ad_campaigns where id=p_campaign_id for update;
  if not found then raise exception 'CAMPAIGN_NOT_FOUND'; end if;
  if v_campaign_state<>'submitted' then raise exception 'CAMPAIGN_NOT_SUBMITTED'; end if;
  if p_start_date<v_campaign_start or p_end_date>v_campaign_end then raise exception 'RESERVATION_OUTSIDE_CAMPAIGN_DATES'; end if;
  if not app_private.advertising_enabled(v_account,v_org) then raise exception 'ADVERTISING_NOT_ENABLED'; end if;
  if app_private.advertiser_ads_restricted(v_account,v_org,p_location_id) then raise exception 'ADS_RESTRICTED'; end if;
  if not exists(select 1 from public.locations where id=p_location_id and state='live') then raise exception 'LOCATION_NOT_LIVE'; end if;
  if not exists(select 1 from public.ad_campaign_targets where campaign_id=p_campaign_id and location_id=p_location_id and placement_type=p_placement_type) then raise exception 'CAMPAIGN_TARGET_NOT_CONFIGURED'; end if;

  v_fp:=app_private.request_fingerprint(jsonb_build_object('campaign_id',p_campaign_id,'location_id',p_location_id,'placement_type',p_placement_type,'start_date',p_start_date,'end_date',p_end_date,'units',p_units));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'reserve_ad_inventory',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  v_expected:=(p_end_date-p_start_date)+1;
  select array_agg(id order by inventory_date,id),count(*)::int
    into v_day_ids,v_actual
    from public.ad_inventory_days
   where location_id=p_location_id and placement_type=p_placement_type and inventory_date between p_start_date and p_end_date;
  if coalesce(v_actual,0)<>v_expected then raise exception 'INVENTORY_NOT_CONFIGURED_FOR_ALL_DAYS'; end if;

  -- Serialize all requested physical inventory rows in deterministic date/id order.
  perform 1 from public.ad_inventory_days d
   where d.id=any(v_day_ids)
   order by d.inventory_date,d.id
   for update;

  perform app_private.expire_ad_inventory_holds_for_days(v_day_ids);

  for v_day in
    select d.* from public.ad_inventory_days d where d.id=any(v_day_ids) order by d.inventory_date,d.id
  loop
    select coalesce(sum(rd.units),0)::int into v_total
      from public.ad_inventory_reservation_days rd
      join public.ad_inventory_reservations r on r.id=rd.reservation_id
     where rd.inventory_day_id=v_day.id
       and (r.state='confirmed' or (r.state='held' and r.hold_expires_at>now()));
    select coalesce(sum(rd.units),0)::int into v_campaign_total
      from public.ad_inventory_reservation_days rd
      join public.ad_inventory_reservations r on r.id=rd.reservation_id
     where rd.inventory_day_id=v_day.id and r.campaign_id=p_campaign_id
       and (r.state='confirmed' or (r.state='held' and r.hold_expires_at>now()));
    if v_total+p_units>v_day.capacity then raise exception 'AD_INVENTORY_CAPACITY_UNAVAILABLE:%',v_day.inventory_date; end if;
    if v_campaign_total+p_units>v_day.max_units_per_campaign then raise exception 'AD_CAMPAIGN_CONCENTRATION_LIMIT:%',v_day.inventory_date; end if;
  end loop;

  v_hold_expires:=now()+app_private.ad_inventory_hold_ttl();
  insert into public.ad_inventory_reservations(campaign_id,requested_by_account_id,state,hold_expires_at)
  values(p_campaign_id,v_actor,'held',v_hold_expires) returning id into v_reservation;
  insert into public.ad_inventory_reservation_days(reservation_id,inventory_day_id,units)
  select v_reservation,id,p_units from public.ad_inventory_days where id=any(v_day_ids) order by inventory_date,id;

  perform app_private.write_audit(v_actor,'ads.inventory_reserve','ad_inventory_reservation',v_reservation,null,null,jsonb_build_object('campaign_id',p_campaign_id,'location_id',p_location_id,'placement_type',p_placement_type,'start_date',p_start_date,'end_date',p_end_date,'units',p_units));
  v_result:=jsonb_build_object('reservation_id',v_reservation,'state','held','hold_expires_at',v_hold_expires,'days',v_expected,'units_per_day',p_units);
  perform app_private.complete_human_idempotent_command(v_actor,'reserve_ad_inventory',p_idempotency_key,v_result);
  return v_result;
end; $$;

create or replace function app_private.cmd_confirm_ad_inventory(p_reservation_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_campaign uuid; v_state text; v_exp timestamptz; v_account uuid; v_org uuid; v_result jsonb;
begin
  select r.campaign_id,r.state,r.hold_expires_at,c.account_id,c.organization_id
    into v_campaign,v_state,v_exp,v_account,v_org
    from public.ad_inventory_reservations r join public.ad_campaigns c on c.id=r.campaign_id
   where r.id=p_reservation_id for update of r;
  if not found then raise exception 'RESERVATION_NOT_FOUND'; end if;
  if not (app_private.campaign_advertiser_authority(v_campaign) or app_private.has_account_capability('ads_commercial')) then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('reservation_id',p_reservation_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'confirm_ad_inventory',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  perform 1 from public.ad_inventory_days d join public.ad_inventory_reservation_days rd on rd.inventory_day_id=d.id
    where rd.reservation_id=p_reservation_id order by d.inventory_date,d.id for update of d;
  if v_state='confirmed' then
    v_result:=jsonb_build_object('reservation_id',p_reservation_id,'state','confirmed','already_confirmed',true);
  elsif v_state='held' and v_exp<=now() then
    update public.ad_inventory_reservations set state='expired',resolved_at=now() where id=p_reservation_id;
    raise exception 'RESERVATION_HOLD_EXPIRED';
  elsif v_state<>'held' then raise exception 'RESERVATION_NOT_CONFIRMABLE';
  else
    if not app_private.advertising_enabled(v_account,v_org) then raise exception 'ADVERTISING_NOT_ENABLED'; end if;
    update public.ad_inventory_reservations set state='confirmed',resolved_at=now() where id=p_reservation_id;
    v_result:=jsonb_build_object('reservation_id',p_reservation_id,'state','confirmed','already_confirmed',false);
  end if;
  perform app_private.complete_human_idempotent_command(v_actor,'confirm_ad_inventory',p_idempotency_key,v_result);
  return v_result;
end; $$;

create or replace function app_private.cmd_release_ad_inventory(p_reservation_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_campaign uuid; v_state text; v_result jsonb;
begin
  select campaign_id,state into v_campaign,v_state from public.ad_inventory_reservations where id=p_reservation_id for update;
  if not found then raise exception 'RESERVATION_NOT_FOUND'; end if;
  if not (app_private.campaign_advertiser_authority(v_campaign) or app_private.has_account_capability('ads_commercial')) then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('reservation_id',p_reservation_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'release_ad_inventory',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  perform 1 from public.ad_inventory_days d join public.ad_inventory_reservation_days rd on rd.inventory_day_id=d.id
    where rd.reservation_id=p_reservation_id order by d.inventory_date,d.id for update of d;
  if exists(select 1 from public.ad_placements where inventory_reservation_id=p_reservation_id and state in ('waiting','live','paused')) then raise exception 'ACTIVE_PLACEMENT_USES_RESERVATION'; end if;
  if v_state='released' then v_result:=jsonb_build_object('reservation_id',p_reservation_id,'state','released','already_released',true);
  elsif v_state in ('held','confirmed') then
    update public.ad_inventory_reservations set state='released',resolved_at=now() where id=p_reservation_id;
    v_result:=jsonb_build_object('reservation_id',p_reservation_id,'state','released','already_released',false);
  elsif v_state='expired' then v_result:=jsonb_build_object('reservation_id',p_reservation_id,'state','expired','already_released',false);
  else raise exception 'RESERVATION_NOT_RELEASABLE'; end if;
  perform app_private.complete_human_idempotent_command(v_actor,'release_ad_inventory',p_idempotency_key,v_result);
  return v_result;
end; $$;

revoke all on function app_private.ad_inventory_hold_ttl(),app_private.can_manage_ad_inventory(uuid),app_private.expire_ad_inventory_holds_for_days(uuid[]) from public,anon,authenticated,service_role;
revoke all on function app_private.cmd_configure_ad_inventory_day(uuid,text,date,integer,integer,integer,text,text),app_private.cmd_reserve_ad_inventory(uuid,uuid,text,date,date,integer,text),app_private.cmd_confirm_ad_inventory(uuid,text),app_private.cmd_release_ad_inventory(uuid,text) from public,anon,authenticated,service_role;
grant execute on function app_private.can_manage_ad_inventory(uuid),app_private.cmd_configure_ad_inventory_day(uuid,text,date,integer,integer,integer,text,text),app_private.cmd_reserve_ad_inventory(uuid,uuid,text,date,date,integer,text),app_private.cmd_confirm_ad_inventory(uuid,text),app_private.cmd_release_ad_inventory(uuid,text) to authenticated;

create or replace function public.configure_ad_inventory_day(p_location_id uuid,p_placement_type text,p_inventory_date date,p_capacity integer,p_max_units_per_campaign integer,p_per_account_daily_cap integer,p_rate_card_code text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_configure_ad_inventory_day(p_location_id,p_placement_type,p_inventory_date,p_capacity,p_max_units_per_campaign,p_per_account_daily_cap,p_rate_card_code,p_idempotency_key); $$;
create or replace function public.reserve_ad_inventory(p_campaign_id uuid,p_location_id uuid,p_placement_type text,p_start_date date,p_end_date date,p_units integer,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_reserve_ad_inventory(p_campaign_id,p_location_id,p_placement_type,p_start_date,p_end_date,p_units,p_idempotency_key); $$;
create or replace function public.confirm_ad_inventory(p_reservation_id uuid,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_confirm_ad_inventory(p_reservation_id,p_idempotency_key); $$;
create or replace function public.release_ad_inventory(p_reservation_id uuid,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_release_ad_inventory(p_reservation_id,p_idempotency_key); $$;
revoke all on function public.configure_ad_inventory_day(uuid,text,date,integer,integer,integer,text,text),public.reserve_ad_inventory(uuid,uuid,text,date,date,integer,text),public.confirm_ad_inventory(uuid,text),public.release_ad_inventory(uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.configure_ad_inventory_day(uuid,text,date,integer,integer,integer,text,text),public.reserve_ad_inventory(uuid,uuid,text,date,date,integer,text),public.confirm_ad_inventory(uuid,text),public.release_ad_inventory(uuid,text) to authenticated;
