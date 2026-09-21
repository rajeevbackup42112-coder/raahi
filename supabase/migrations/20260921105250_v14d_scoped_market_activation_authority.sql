-- Raahi Learning V1.4D — scoped market-activation authority.
-- Global Platform Admin can operate across live Locations.
-- A Location local_manager can operate Raahi Desk and Founding Supply only inside
-- that manager's active Location scope.

create or replace function app_private.cmd_publish_raahi_desk_post(
  p_location_id uuid,
  p_post_type text,
  p_body text,
  p_external_url text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.require_current_account(true);
  v_gate jsonb;
  v_fp text;
  v_post uuid;
  v_result jsonb;
begin
  if not (
    app_private.has_account_capability('platform_admin')
    or app_private.has_location_staff_scope(p_location_id,'local_manager')
  ) then
    raise exception 'MARKET_ACTIVATION_SCOPE_REQUIRED';
  end if;

  if not exists(select 1 from public.locations where id=p_location_id and state='live') then
    raise exception 'LOCATION_NOT_LIVE';
  end if;
  if p_post_type not in ('discussion','question','resource','event','update') then
    raise exception 'INVALID_POST_TYPE';
  end if;
  if p_body is null or char_length(btrim(p_body)) not between 1 and 12000 then
    raise exception 'INVALID_POST_BODY';
  end if;

  v_fp:=app_private.request_fingerprint(jsonb_build_object(
    'location_id',p_location_id,
    'post_type',p_post_type,
    'body',p_body,
    'external_url',p_external_url,
    'provenance_kind','platform_editorial'
  ));
  v_gate:=app_private.begin_human_idempotent_command(
    v_actor,'publish_raahi_desk_post',p_idempotency_key,v_fp
  );
  if (v_gate->>'cached')::boolean then
    return v_gate->'result';
  end if;

  insert into public.community_posts(
    location_id,author_account_id,post_type,body,attachment_asset_id,external_url,provenance_kind
  )
  values(
    p_location_id,v_actor,p_post_type,btrim(p_body),null,
    nullif(btrim(p_external_url),''),'platform_editorial'
  )
  returning id into v_post;

  perform app_private.write_location_audit(
    v_actor,
    'community.raahi_desk_publish',
    p_location_id,
    'community_post',
    v_post,
    null,
    jsonb_build_object(
      'provenance_kind','platform_editorial',
      'post_type',p_post_type,
      'public_attribution','Raahi Desk',
      'authority_scope',
        case
          when app_private.has_account_capability('platform_admin') then 'global_platform'
          else 'location_local_manager'
        end
    )
  );

  v_result:=jsonb_build_object(
    'post_id',v_post,
    'visibility_status','published',
    'provenance_kind','platform_editorial',
    'attribution_label','Raahi Desk',
    'location_id',p_location_id
  );
  perform app_private.complete_human_idempotent_command(
    v_actor,'publish_raahi_desk_post',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.cmd_prepare_assisted_teacher_onboarding(
  p_request_id uuid,
  p_headline text,
  p_bio text,
  p_experience_summary text,
  p_option_title text,
  p_option_category text,
  p_option_description text,
  p_teaching_mode text,
  p_area_or_venue_text text,
  p_fee_display_text text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.require_current_account(true);
  v_gate jsonb;
  v_fp text;
  v_teacher uuid;
  v_location uuid;
  v_state text;
  v_result jsonb;
begin
  v_fp:=app_private.request_fingerprint(jsonb_build_object(
    'request_id',p_request_id,
    'headline',p_headline,
    'bio',p_bio,
    'experience_summary',p_experience_summary,
    'option_title',p_option_title,
    'option_category',p_option_category,
    'option_description',p_option_description,
    'teaching_mode',p_teaching_mode,
    'area_or_venue_text',p_area_or_venue_text,
    'fee_display_text',p_fee_display_text
  ));
  v_gate:=app_private.begin_human_idempotent_command(
    v_actor,'prepare_assisted_teacher_onboarding',p_idempotency_key,v_fp
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select teacher_account_id,founding_location_id,state
    into v_teacher,v_location,v_state
  from public.assisted_teacher_onboarding_requests
  where id=p_request_id
  for update;

  if not found then raise exception 'ASSISTED_ONBOARDING_NOT_FOUND'; end if;

  if not (
    app_private.has_account_capability('platform_admin')
    or app_private.has_location_staff_scope(v_location,'local_manager')
  ) then
    raise exception 'MARKET_ACTIVATION_SCOPE_REQUIRED';
  end if;

  if v_state<>'requested' then raise exception 'ASSISTED_ONBOARDING_NOT_PREPARABLE'; end if;
  if not exists(select 1 from public.locations where id=v_location and state='live') then
    raise exception 'LOCATION_NOT_LIVE';
  end if;
  if p_headline is null or char_length(btrim(p_headline)) not between 1 and 240 then
    raise exception 'INVALID_TEACHER_HEADLINE';
  end if;
  if p_bio is not null and char_length(p_bio)>5000 then raise exception 'INVALID_TEACHER_BIO'; end if;
  if p_experience_summary is not null and char_length(p_experience_summary)>2000 then
    raise exception 'INVALID_TEACHER_EXPERIENCE';
  end if;
  if p_option_title is null or char_length(btrim(p_option_title)) not between 1 and 200 then
    raise exception 'INVALID_TEACHING_OPTION_TITLE';
  end if;
  if p_option_category is not null and char_length(p_option_category)>120 then
    raise exception 'INVALID_TEACHING_OPTION_CATEGORY';
  end if;
  if p_option_description is not null and char_length(p_option_description)>5000 then
    raise exception 'INVALID_TEACHING_OPTION_DESCRIPTION';
  end if;
  if p_teaching_mode not in ('online','in_person','both') then
    raise exception 'INVALID_TEACHING_MODE';
  end if;
  if p_area_or_venue_text is not null and char_length(p_area_or_venue_text)>500 then
    raise exception 'INVALID_TEACHING_AREA';
  end if;
  if p_fee_display_text is not null and char_length(p_fee_display_text)>500 then
    raise exception 'INVALID_FEE_DISPLAY';
  end if;

  if exists(select 1 from public.teacher_profiles where account_id=v_teacher)
     or exists(select 1 from public.teaching_options where teacher_account_id=v_teacher) then
    raise exception 'FOUNDING_SUPPLY_EXISTING_TEACHER_DATA';
  end if;

  update public.assisted_teacher_onboarding_requests
  set
    state='draft_ready',
    proposed_headline=btrim(p_headline),
    proposed_bio=nullif(btrim(p_bio),''),
    proposed_experience_summary=nullif(btrim(p_experience_summary),''),
    proposed_option_title=btrim(p_option_title),
    proposed_option_category=nullif(btrim(p_option_category),''),
    proposed_option_description=nullif(btrim(p_option_description),''),
    proposed_teaching_mode=p_teaching_mode,
    proposed_area_or_venue_text=nullif(btrim(p_area_or_venue_text),''),
    proposed_fee_display_text=nullif(btrim(p_fee_display_text),''),
    proposal_prepared_by_account_id=v_actor,
    proposal_prepared_at=now()
  where id=p_request_id;

  perform app_private.write_location_audit(
    v_actor,
    'founding_supply.draft_prepared',
    v_location,
    'assisted_teacher_onboarding',
    p_request_id,
    null,
    jsonb_build_object(
      'teacher_account_id',v_teacher,
      'consent_text_version','founding-supply-v1',
      'authority_scope',
        case
          when app_private.has_account_capability('platform_admin') then 'global_platform'
          else 'location_local_manager'
        end
    )
  );

  v_result:=jsonb_build_object(
    'request_id',p_request_id,
    'teacher_account_id',v_teacher,
    'state','draft_ready',
    'founding_location_id',v_location
  );
  perform app_private.complete_human_idempotent_command(
    v_actor,'prepare_assisted_teacher_onboarding',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.cmd_withdraw_assisted_teacher_onboarding(
  p_request_id uuid,
  p_reason text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.require_current_account(true);
  v_gate jsonb;
  v_fp text;
  v_location uuid;
  v_teacher uuid;
  v_state text;
  v_result jsonb;
begin
  if p_reason is null or char_length(btrim(p_reason)) not between 1 and 500 then
    raise exception 'WITHDRAW_REASON_REQUIRED';
  end if;

  v_fp:=app_private.request_fingerprint(
    jsonb_build_object('request_id',p_request_id,'reason',p_reason)
  );
  v_gate:=app_private.begin_human_idempotent_command(
    v_actor,'withdraw_assisted_teacher_onboarding',p_idempotency_key,v_fp
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select teacher_account_id,founding_location_id,state
    into v_teacher,v_location,v_state
  from public.assisted_teacher_onboarding_requests
  where id=p_request_id
  for update;

  if not found then raise exception 'ASSISTED_ONBOARDING_NOT_FOUND'; end if;

  if not (
    app_private.has_account_capability('platform_admin')
    or app_private.has_location_staff_scope(v_location,'local_manager')
  ) then
    raise exception 'MARKET_ACTIVATION_SCOPE_REQUIRED';
  end if;

  if v_state not in ('requested','draft_ready') then
    raise exception 'ASSISTED_ONBOARDING_NOT_WITHDRAWABLE';
  end if;

  update public.assisted_teacher_onboarding_requests
  set state='withdrawn',resolved_by_account_id=v_actor,resolved_at=now(),
      resolution_reason=btrim(p_reason)
  where id=p_request_id;

  perform app_private.write_location_audit(
    v_actor,'founding_supply.platform_withdrawn',v_location,
    'assisted_teacher_onboarding',p_request_id,null,
    jsonb_build_object(
      'teacher_account_id',v_teacher,
      'reason',btrim(p_reason),
      'authority_scope',
        case
          when app_private.has_account_capability('platform_admin') then 'global_platform'
          else 'location_local_manager'
        end
    )
  );

  v_result:=jsonb_build_object(
    'request_id',p_request_id,
    'state','withdrawn',
    'founding_location_id',v_location
  );
  perform app_private.complete_human_idempotent_command(
    v_actor,'withdraw_assisted_teacher_onboarding',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.read_platform_assisted_teacher_onboarding(
  p_state text default null
)
returns setof jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_global boolean;
begin
  if app_private.current_account_id() is null then raise exception 'AUTH_REQUIRED'; end if;

  v_global:=app_private.has_account_capability('platform_admin');

  if not v_global
     and not exists(
       select 1
       from public.location_staff_assignments lsa
       join public.accounts a on a.id=lsa.account_id
       where lsa.account_id=app_private.current_account_id()
         and lsa.staff_type='local_manager'
         and lsa.status='active'
         and a.lifecycle_status='active'
     ) then
    raise exception 'MARKET_ACTIVATION_SCOPE_REQUIRED';
  end if;

  if p_state is not null
     and p_state not in ('requested','draft_ready','accepted','declined','cancelled','withdrawn') then
    raise exception 'INVALID_ASSISTED_ONBOARDING_STATE';
  end if;

  return query
  select jsonb_build_object(
    'request_id',r.id,
    'teacher_account_id',r.teacher_account_id,
    'teacher_display_name',a.display_name,
    'founding_location_id',r.founding_location_id,
    'founding_location_name',l.name,
    'state',r.state,
    'consent_text_version',r.consent_text_version,
    'proposed_headline',r.proposed_headline,
    'proposed_bio',r.proposed_bio,
    'proposed_experience_summary',r.proposed_experience_summary,
    'proposed_option_title',r.proposed_option_title,
    'proposed_option_category',r.proposed_option_category,
    'proposed_option_description',r.proposed_option_description,
    'proposed_teaching_mode',r.proposed_teaching_mode,
    'proposed_area_or_venue_text',r.proposed_area_or_venue_text,
    'proposed_fee_display_text',r.proposed_fee_display_text,
    'proposal_prepared_at',r.proposal_prepared_at,
    'requested_at',r.requested_at,
    'resolved_at',r.resolved_at,
    'operator_scope',
      case when v_global then 'global_platform' else 'location_local_manager' end
  )
  from public.assisted_teacher_onboarding_requests r
  join public.accounts a on a.id=r.teacher_account_id
  join public.locations l on l.id=r.founding_location_id
  where (p_state is null or r.state=p_state)
    and (
      v_global
      or app_private.has_location_staff_scope(r.founding_location_id,'local_manager')
    )
  order by
    case r.state when 'requested' then 0 when 'draft_ready' then 1 else 2 end,
    r.requested_at,
    r.id;
end;
$$;

revoke all on function
  app_private.cmd_publish_raahi_desk_post(uuid,text,text,text,text),
  app_private.cmd_prepare_assisted_teacher_onboarding(uuid,text,text,text,text,text,text,text,text,text,text),
  app_private.cmd_withdraw_assisted_teacher_onboarding(uuid,text,text),
  app_private.read_platform_assisted_teacher_onboarding(text)
from public,anon,authenticated,service_role;

grant execute on function
  app_private.cmd_publish_raahi_desk_post(uuid,text,text,text,text),
  app_private.cmd_prepare_assisted_teacher_onboarding(uuid,text,text,text,text,text,text,text,text,text,text),
  app_private.cmd_withdraw_assisted_teacher_onboarding(uuid,text,text),
  app_private.read_platform_assisted_teacher_onboarding(text)
to authenticated;
