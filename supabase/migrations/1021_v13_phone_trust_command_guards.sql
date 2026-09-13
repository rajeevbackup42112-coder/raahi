-- Raahi Learning V1.3 — enforce frozen phone-trust action matrix.
-- Freshness is derived from auth.users.phone_confirmed_at (migration 1020).

create or replace function app_private.command_requires_fresh_phone_trust(p_command_name text)
returns boolean
language sql
immutable
strict
set search_path=''
as $$
  select p_command_name = any(array[
    'post_learning_request',
    'reopen_learning_request',
    'send_enquiry',
    'send_sponsored_enquiry',
    'express_interest_in_request',
    'accept_class_invitation',
    'publish_teaching_option',
    'create_organization',
    'add_organization_member',
    'issue_organization_member_invitation',
    'accept_organization_member_invitation',
    'set_organization_member_capability',
    'grant_learner_self_access',
    'issue_learner_self_access_invitation',
    'accept_learner_self_access_invitation',
    'request_account_closure',
    'publish_community_post',
    'submit_ad_campaign_revision',
    'confirm_ad_commercial_clearance',
    'confirm_ad_inventory',
    'apply_access_restriction',
    'lift_access_restriction',
    'moderate_community_content',
    'resolve_report'
  ]::text[]);
$$;

revoke all on function app_private.command_requires_fresh_phone_trust(text)
from public,anon,authenticated,service_role;
-- Internal-only helper; callers reach it through canonical SECURITY DEFINER commands.
revoke execute on function app_private.has_fresh_phone_trust(), app_private.require_fresh_phone_trust() from authenticated;

create or replace function app_private.begin_human_idempotent_command(
  p_actor_account_id uuid,
  p_command_name text,
  p_idempotency_key text,
  p_request_fingerprint text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_inserted integer := 0;
  v_fingerprint text;
  v_result jsonb;
begin
  if p_actor_account_id is null then
    raise exception 'IDEMPOTENCY_ACTOR_REQUIRED';
  end if;
  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED';
  end if;

  insert into public.idempotency_keys (
    actor_account_id, command_name, idempotency_key, request_fingerprint
  )
  values (
    p_actor_account_id, p_command_name, p_idempotency_key, p_request_fingerprint
  )
  on conflict (actor_account_id, command_name, idempotency_key) do nothing;

  get diagnostics v_inserted = row_count;

  select request_fingerprint, result_json
    into v_fingerprint, v_result
  from public.idempotency_keys
  where actor_account_id = p_actor_account_id
    and command_name = p_command_name
    and idempotency_key = p_idempotency_key
  for update;

  if v_fingerprint is distinct from p_request_fingerprint then
    raise exception 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST';
  end if;

  if v_inserted = 0 then
    if v_result is null then
      raise exception 'IDEMPOTENCY_REQUEST_INCOMPLETE';
    end if;
    return jsonb_build_object('cached', true, 'result', v_result);
  end if;

  -- Phone freshness is enforced only for a new execution. A completed retry
  -- with the same idempotency key returns its cached result above.
  if app_private.command_requires_fresh_phone_trust(p_command_name) then
    perform app_private.require_fresh_phone_trust();
  end if;

  return jsonb_build_object('cached', false);
end;
$$;

-- First-time teaching enablement is gated, but an already-active teacher may
-- revisit onboarding without an OTP solely because the phone later became stale.
create or replace function app_private.cmd_enable_teaching(p_idempotency_key text)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb;
  v_fp text:=app_private.request_fingerprint('{}'::jsonb); v_id uuid; v_result jsonb;
begin
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'enable_teaching',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select id into v_id from public.account_capabilities
  where account_id=v_actor and capability_code='teach' and status='active' limit 1;
  if v_id is not null then
    v_result:=jsonb_build_object('capability_id',v_id,'capability_code','teach','already_active',true);
    perform app_private.complete_human_idempotent_command(v_actor,'enable_teaching',p_idempotency_key,v_result);
    return v_result;
  end if;

  if exists(select 1 from public.account_capabilities where account_id=v_actor and capability_code='teach' and status='revoked') then
    raise exception 'TEACHING_REENABLE_REQUIRES_REVIEW';
  end if;

  perform app_private.require_fresh_phone_trust();

  insert into public.account_capabilities(account_id,capability_code,granted_by_account_id)
  values(v_actor,'teach',v_actor) returning id into v_id;
  perform app_private.write_audit(v_actor,'account.teaching_enable','account',v_actor,null,null,'{}'::jsonb);
  v_result:=jsonb_build_object('capability_id',v_id,'capability_code','teach','already_active',false);
  perform app_private.complete_human_idempotent_command(v_actor,'enable_teaching',p_idempotency_key,v_result);
  return v_result;
end;
$$;

-- Ordinary edits to an already-visible Teacher profile remain available while
-- stale. Only crossing from absent/hidden to visible requires fresh trust.
create or replace function app_private.cmd_upsert_teacher_profile(
  p_headline text,p_bio text,p_experience_summary text,p_visibility_status text,p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_old_visibility text; v_result jsonb;
begin
  if not app_private.has_account_capability('teach') then raise exception 'TEACH_CAPABILITY_REQUIRED'; end if;
  if p_visibility_status not in ('visible','hidden') then raise exception 'INVALID_VISIBILITY'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('headline',p_headline,'bio',p_bio,'experience_summary',p_experience_summary,'visibility_status',p_visibility_status));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'upsert_teacher_profile',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select visibility_status into v_old_visibility
  from public.teacher_profiles where account_id=v_actor for update;

  if p_visibility_status='visible' and coalesce(v_old_visibility,'hidden')<>'visible' then
    perform app_private.require_fresh_phone_trust();
  end if;

  insert into public.teacher_profiles(account_id,headline,bio,experience_summary,visibility_status)
  values(v_actor,nullif(btrim(p_headline),''),nullif(btrim(p_bio),''),nullif(btrim(p_experience_summary),''),p_visibility_status)
  on conflict(account_id) do update set headline=excluded.headline,bio=excluded.bio,experience_summary=excluded.experience_summary,visibility_status=excluded.visibility_status;
  v_result:=jsonb_build_object('teacher_account_id',v_actor,'visibility_status',p_visibility_status);
  perform app_private.complete_human_idempotent_command(v_actor,'upsert_teacher_profile',p_idempotency_key,v_result);
  return v_result;
end;
$$;

-- Stopping/deactivating learner acquisition is never gated. Re-opening an
-- unavailable option to taking_new_learners requires fresh phone trust.
create or replace function app_private.cmd_set_teaching_availability(
  p_teaching_option_id uuid,p_availability_status text,p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_old text; v_result jsonb;
begin
  if p_availability_status not in ('taking_new_learners','not_taking_new_learners','no_longer_offered') then raise exception 'INVALID_AVAILABILITY'; end if;
  if not app_private.can_manage_teaching_option(p_teaching_option_id) then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('teaching_option_id',p_teaching_option_id,'availability_status',p_availability_status));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'set_teaching_availability',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select availability_status into v_old from public.teaching_options where id=p_teaching_option_id for update;
  if not found then raise exception 'TEACHING_OPTION_NOT_FOUND'; end if;

  if p_availability_status='taking_new_learners' and v_old<>'taking_new_learners' then
    perform app_private.require_fresh_phone_trust();
  end if;

  update public.teaching_options set availability_status=p_availability_status where id=p_teaching_option_id;
  v_result:=jsonb_build_object('teaching_option_id',p_teaching_option_id,'old_status',v_old,'availability_status',p_availability_status,'changed',v_old<>p_availability_status);
  perform app_private.complete_human_idempotent_command(v_actor,'set_teaching_availability',p_idempotency_key,v_result);
  return v_result;
end;
$$;

-- Ad pause/end/cancel remains available while stale. Only activation/resume to
-- live is gated, after cached idempotent retries have been handled.
create or replace function app_private.cmd_set_ad_placement_state(
  p_placement_id uuid,p_new_state text,p_reason text,p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
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

  if p_new_state='live' and v_state<>'live' then
    perform app_private.require_fresh_phone_trust();
  end if;

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
end;
$$;
