-- Raahi Learning V1.2 — exact approved serving revision and Placement lifecycle guards.

create or replace function app_private.ad_placement_prerequisites_ok(
  p_campaign_id uuid,p_location_id uuid,p_placement_type text,p_reservation_id uuid,p_revision_id uuid,p_start_on date,p_end_on date
)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare
  v_account uuid; v_org uuid; v_campaign_state text; v_rev_campaign uuid; v_submitted timestamptz;
  v_res_campaign uuid; v_res_state text; v_min date; v_max date; v_days int; v_expected int; v_clear text;
begin
  select account_id,organization_id,state into v_account,v_org,v_campaign_state from public.ad_campaigns where id=p_campaign_id;
  if not found or v_campaign_state<>'submitted' then return false; end if;
  if not app_private.advertising_enabled(v_account,v_org) or app_private.advertiser_ads_restricted(v_account,v_org,p_location_id) then return false; end if;
  if not exists(select 1 from public.locations where id=p_location_id and state='live') then return false; end if;
  if not exists(select 1 from public.ad_campaign_targets where campaign_id=p_campaign_id and location_id=p_location_id and placement_type=p_placement_type) then return false; end if;

  select campaign_id,submitted_at into v_rev_campaign,v_submitted from public.ad_campaign_revisions where id=p_revision_id;
  if not found or v_rev_campaign<>p_campaign_id or v_submitted is null then return false; end if;
  if not app_private.revision_approved_for_location(p_revision_id,p_location_id) then return false; end if;

  select campaign_id,state into v_res_campaign,v_res_state from public.ad_inventory_reservations where id=p_reservation_id;
  if not found or v_res_campaign<>p_campaign_id or v_res_state<>'confirmed' then return false; end if;

  select min(d.inventory_date),max(d.inventory_date),count(*)::int
    into v_min,v_max,v_days
    from public.ad_inventory_reservation_days rd
    join public.ad_inventory_days d on d.id=rd.inventory_day_id
   where rd.reservation_id=p_reservation_id
     and d.location_id=p_location_id and d.placement_type=p_placement_type;
  if v_min is null or v_min<>p_start_on or v_max<>p_end_on then return false; end if;
  v_expected:=(p_end_on-p_start_on)+1;
  if v_days<>v_expected then return false; end if;
  if exists(
    select 1 from public.ad_inventory_reservation_days rd join public.ad_inventory_days d on d.id=rd.inventory_day_id
    where rd.reservation_id=p_reservation_id and (d.location_id<>p_location_id or d.placement_type<>p_placement_type)
  ) then return false; end if;

  select state into v_clear from public.ad_commercial_clearances where campaign_id=p_campaign_id;
  if v_clear is distinct from 'cleared' then return false; end if;
  return true;
end; $$;

create or replace function app_private.guard_ad_placement_exact_revision()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='INSERT' then
    if not app_private.ad_placement_prerequisites_ok(new.campaign_id,new.location_id,new.placement_type,new.inventory_reservation_id,new.serving_revision_id,new.starts_on,new.ends_on) then
      raise exception 'AD_PLACEMENT_PREREQUISITES_NOT_MET';
    end if;
    return new;
  end if;

  if new.campaign_id is distinct from old.campaign_id
     or new.location_id is distinct from old.location_id
     or new.placement_type is distinct from old.placement_type
     or new.inventory_reservation_id is distinct from old.inventory_reservation_id
     or new.serving_revision_id is distinct from old.serving_revision_id
     or new.starts_on is distinct from old.starts_on
     or new.ends_on is distinct from old.ends_on
     or new.state='live' and old.state is distinct from 'live' then
    if not app_private.ad_placement_prerequisites_ok(new.campaign_id,new.location_id,new.placement_type,new.inventory_reservation_id,new.serving_revision_id,new.starts_on,new.ends_on) then
      raise exception 'AD_PLACEMENT_PREREQUISITES_NOT_MET';
    end if;
  end if;
  return new;
end; $$;

create trigger ad_placements_exact_revision_guard
before insert or update on public.ad_placements
for each row execute function app_private.guard_ad_placement_exact_revision();

create or replace function app_private.cmd_create_ad_placement(
  p_reservation_id uuid,p_location_id uuid,p_placement_type text,p_serving_revision_id uuid,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_campaign uuid; v_start date; v_end date; v_placement uuid; v_result jsonb;
begin
  select campaign_id into v_campaign from public.ad_inventory_reservations where id=p_reservation_id and state='confirmed';
  if not found then raise exception 'CONFIRMED_RESERVATION_REQUIRED'; end if;
  if not (app_private.campaign_advertiser_authority(v_campaign) or app_private.has_account_capability('ads_commercial')) then raise exception 'NOT_AUTHORIZED'; end if;
  if p_placement_type not in ('home_sponsored','explore_sponsored','community_event') then raise exception 'INVALID_PLACEMENT_TYPE'; end if;

  select min(d.inventory_date),max(d.inventory_date) into v_start,v_end
    from public.ad_inventory_reservation_days rd join public.ad_inventory_days d on d.id=rd.inventory_day_id
   where rd.reservation_id=p_reservation_id and d.location_id=p_location_id and d.placement_type=p_placement_type;
  if v_start is null then raise exception 'RESERVATION_TARGET_NOT_FOUND'; end if;
  if not app_private.ad_placement_prerequisites_ok(v_campaign,p_location_id,p_placement_type,p_reservation_id,p_serving_revision_id,v_start,v_end) then raise exception 'AD_PLACEMENT_PREREQUISITES_NOT_MET'; end if;

  v_fp:=app_private.request_fingerprint(jsonb_build_object('reservation_id',p_reservation_id,'location_id',p_location_id,'placement_type',p_placement_type,'serving_revision_id',p_serving_revision_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'create_ad_placement',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  insert into public.ad_placements(campaign_id,location_id,placement_type,inventory_reservation_id,serving_revision_id,starts_on,ends_on,state)
  values(v_campaign,p_location_id,p_placement_type,p_reservation_id,p_serving_revision_id,v_start,v_end,'waiting')
  returning id into v_placement;
  perform app_private.write_audit(v_actor,'ads.placement_create','ad_placement',v_placement,null,null,jsonb_build_object('campaign_id',v_campaign,'revision_id',p_serving_revision_id,'location_id',p_location_id,'placement_type',p_placement_type));
  v_result:=jsonb_build_object('placement_id',v_placement,'campaign_id',v_campaign,'state','waiting','starts_on',v_start,'ends_on',v_end,'serving_revision_id',p_serving_revision_id);
  perform app_private.complete_human_idempotent_command(v_actor,'create_ad_placement',p_idempotency_key,v_result);
  return v_result;
end; $$;

create or replace function app_private.cmd_set_ad_placement_state(
  p_placement_id uuid,p_new_state text,p_reason text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_campaign uuid; v_location uuid; v_type text; v_res uuid; v_rev uuid; v_start date; v_end date; v_state text; v_result jsonb;
begin
  if p_new_state not in ('live','paused','ended','cancelled') then raise exception 'INVALID_PLACEMENT_STATE'; end if;
  select campaign_id,location_id,placement_type,inventory_reservation_id,serving_revision_id,starts_on,ends_on,state
    into v_campaign,v_location,v_type,v_res,v_rev,v_start,v_end,v_state
    from public.ad_placements where id=p_placement_id for update;
  if not found then raise exception 'PLACEMENT_NOT_FOUND'; end if;
  if not (app_private.campaign_advertiser_authority(v_campaign) or app_private.has_account_capability('ads_commercial') or app_private.can_manage_ad_inventory(v_location)) then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('placement_id',p_placement_id,'new_state',p_new_state,'reason',p_reason));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'set_ad_placement_state',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  if v_state=p_new_state then
    v_result:=jsonb_build_object('placement_id',p_placement_id,'state',v_state,'changed',false);
  elsif v_state in ('ended','cancelled') then raise exception 'PLACEMENT_TERMINAL';
  elsif p_new_state='live' then
    if current_date<v_start or current_date>v_end then raise exception 'PLACEMENT_OUTSIDE_SCHEDULE'; end if;
    if not app_private.ad_placement_prerequisites_ok(v_campaign,v_location,v_type,v_res,v_rev,v_start,v_end) then raise exception 'AD_PLACEMENT_PREREQUISITES_NOT_MET'; end if;
    update public.ad_placements set state='live',pause_reason=null where id=p_placement_id;
    v_result:=jsonb_build_object('placement_id',p_placement_id,'state','live','changed',true);
  elsif p_new_state='paused' then
    if nullif(btrim(p_reason),'') is null then raise exception 'PAUSE_REASON_REQUIRED'; end if;
    update public.ad_placements set state='paused',pause_reason=btrim(p_reason) where id=p_placement_id;
    v_result:=jsonb_build_object('placement_id',p_placement_id,'state','paused','changed',true);
  elsif p_new_state='ended' then
    update public.ad_placements set state='ended',pause_reason=null where id=p_placement_id;
    v_result:=jsonb_build_object('placement_id',p_placement_id,'state','ended','changed',true);
  else
    update public.ad_placements set state='cancelled',pause_reason=null where id=p_placement_id;
    v_result:=jsonb_build_object('placement_id',p_placement_id,'state','cancelled','changed',true);
  end if;
  perform app_private.write_audit(v_actor,'ads.placement_state','ad_placement',p_placement_id,null,p_reason,jsonb_build_object('from_state',v_state,'to_state',p_new_state));
  perform app_private.complete_human_idempotent_command(v_actor,'set_ad_placement_state',p_idempotency_key,v_result);
  return v_result;
end; $$;

create or replace function app_private.cmd_switch_ad_placement_revision(
  p_placement_id uuid,p_revision_id uuid,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_campaign uuid; v_location uuid; v_type text; v_res uuid; v_old uuid; v_start date; v_end date; v_state text; v_result jsonb;
begin
  select campaign_id,location_id,placement_type,inventory_reservation_id,serving_revision_id,starts_on,ends_on,state
    into v_campaign,v_location,v_type,v_res,v_old,v_start,v_end,v_state
    from public.ad_placements where id=p_placement_id for update;
  if not found then raise exception 'PLACEMENT_NOT_FOUND'; end if;
  if not (app_private.campaign_advertiser_authority(v_campaign) or app_private.has_account_capability('ads_commercial')) then raise exception 'NOT_AUTHORIZED'; end if;
  if v_state in ('ended','cancelled') then raise exception 'PLACEMENT_TERMINAL'; end if;
  if not app_private.ad_placement_prerequisites_ok(v_campaign,v_location,v_type,v_res,p_revision_id,v_start,v_end) then raise exception 'SERVING_REVISION_NOT_ELIGIBLE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('placement_id',p_placement_id,'revision_id',p_revision_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'switch_ad_placement_revision',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if v_old=p_revision_id then v_result:=jsonb_build_object('placement_id',p_placement_id,'serving_revision_id',p_revision_id,'changed',false);
  else
    update public.ad_placements set serving_revision_id=p_revision_id where id=p_placement_id;
    perform app_private.write_audit(v_actor,'ads.placement_revision_switch','ad_placement',p_placement_id,null,null,jsonb_build_object('from_revision_id',v_old,'to_revision_id',p_revision_id));
    v_result:=jsonb_build_object('placement_id',p_placement_id,'serving_revision_id',p_revision_id,'changed',true);
  end if;
  perform app_private.complete_human_idempotent_command(v_actor,'switch_ad_placement_revision',p_idempotency_key,v_result);
  return v_result;
end; $$;

revoke all on function app_private.ad_placement_prerequisites_ok(uuid,uuid,text,uuid,uuid,date,date),app_private.guard_ad_placement_exact_revision() from public,anon,authenticated,service_role;
revoke all on function app_private.cmd_create_ad_placement(uuid,uuid,text,uuid,text),app_private.cmd_set_ad_placement_state(uuid,text,text,text),app_private.cmd_switch_ad_placement_revision(uuid,uuid,text) from public,anon,authenticated,service_role;
grant execute on function app_private.cmd_create_ad_placement(uuid,uuid,text,uuid,text),app_private.cmd_set_ad_placement_state(uuid,text,text,text),app_private.cmd_switch_ad_placement_revision(uuid,uuid,text) to authenticated;

create or replace function public.create_ad_placement(p_reservation_id uuid,p_location_id uuid,p_placement_type text,p_serving_revision_id uuid,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_create_ad_placement(p_reservation_id,p_location_id,p_placement_type,p_serving_revision_id,p_idempotency_key); $$;
create or replace function public.set_ad_placement_state(p_placement_id uuid,p_new_state text,p_reason text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_set_ad_placement_state(p_placement_id,p_new_state,p_reason,p_idempotency_key); $$;
create or replace function public.switch_ad_placement_revision(p_placement_id uuid,p_revision_id uuid,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_switch_ad_placement_revision(p_placement_id,p_revision_id,p_idempotency_key); $$;
revoke all on function public.create_ad_placement(uuid,uuid,text,uuid,text),public.set_ad_placement_state(uuid,text,text,text),public.switch_ad_placement_revision(uuid,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.create_ad_placement(uuid,uuid,text,uuid,text),public.set_ad_placement_state(uuid,text,text,text),public.switch_ad_placement_revision(uuid,uuid,text) to authenticated;
