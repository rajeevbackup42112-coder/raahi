-- Raahi Learning V1.4C — Founding Supply assisted Teacher onboarding.
-- Genuine Teacher asks for help; Raahi prepares a private draft; only the same
-- authenticated Teacher can accept and atomically publish canonical supply.

create table public.assisted_teacher_onboarding_requests (
  id uuid primary key default gen_random_uuid(),
  teacher_account_id uuid not null references public.accounts(id),
  requested_by_account_id uuid not null references public.accounts(id),
  founding_location_id uuid not null references public.locations(id),
  state text not null default 'requested',
  consent_text_version text not null default 'founding-supply-v1',

  proposed_headline text null,
  proposed_bio text null,
  proposed_experience_summary text null,
  proposed_option_title text null,
  proposed_option_category text null,
  proposed_option_description text null,
  proposed_teaching_mode text null,
  proposed_area_or_venue_text text null,
  proposed_fee_display_text text null,

  proposal_prepared_by_account_id uuid null references public.accounts(id),
  proposal_prepared_at timestamptz null,
  resolved_by_account_id uuid null references public.accounts(id),
  resolved_at timestamptz null,
  resolution_reason text null,

  requested_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint assisted_teacher_request_self_check
    check (teacher_account_id=requested_by_account_id),
  constraint assisted_teacher_state_check
    check (state in ('requested','draft_ready','accepted','declined','cancelled','withdrawn')),
  constraint assisted_teacher_consent_version_check
    check (char_length(btrim(consent_text_version)) between 1 and 80),
  constraint assisted_teacher_headline_length
    check (proposed_headline is null or char_length(proposed_headline)<=240),
  constraint assisted_teacher_bio_length
    check (proposed_bio is null or char_length(proposed_bio)<=5000),
  constraint assisted_teacher_experience_length
    check (proposed_experience_summary is null or char_length(proposed_experience_summary)<=2000),
  constraint assisted_teacher_option_title_length
    check (proposed_option_title is null or char_length(proposed_option_title)<=200),
  constraint assisted_teacher_option_category_length
    check (proposed_option_category is null or char_length(proposed_option_category)<=120),
  constraint assisted_teacher_option_description_length
    check (proposed_option_description is null or char_length(proposed_option_description)<=5000),
  constraint assisted_teacher_mode_check
    check (proposed_teaching_mode is null or proposed_teaching_mode in ('online','in_person','both')),
  constraint assisted_teacher_area_length
    check (proposed_area_or_venue_text is null or char_length(proposed_area_or_venue_text)<=500),
  constraint assisted_teacher_fee_length
    check (proposed_fee_display_text is null or char_length(proposed_fee_display_text)<=500),
  constraint assisted_teacher_draft_completeness_check
    check (
      state not in ('draft_ready','accepted','declined')
      or (
        proposal_prepared_by_account_id is not null
        and proposal_prepared_at is not null
        and proposed_headline is not null
        and char_length(btrim(proposed_headline)) between 1 and 240
        and proposed_option_title is not null
        and char_length(btrim(proposed_option_title)) between 1 and 200
        and proposed_teaching_mode is not null
      )
    ),
  constraint assisted_teacher_resolution_consistency_check
    check (
      (state in ('requested','draft_ready') and resolved_by_account_id is null and resolved_at is null)
      or
      (state in ('accepted','declined','cancelled','withdrawn') and resolved_by_account_id is not null and resolved_at is not null)
    )
);

create unique index assisted_teacher_one_active_request_idx
  on public.assisted_teacher_onboarding_requests(teacher_account_id)
  where state in ('requested','draft_ready');

create index assisted_teacher_platform_queue_idx
  on public.assisted_teacher_onboarding_requests(state,founding_location_id,requested_at,id);

create trigger assisted_teacher_onboarding_set_updated_at
before update on public.assisted_teacher_onboarding_requests
for each row execute function app_private.set_updated_at();

alter table public.assisted_teacher_onboarding_requests enable row level security;
alter table public.assisted_teacher_onboarding_requests force row level security;

revoke all on table public.assisted_teacher_onboarding_requests
from public,anon,authenticated,service_role;
grant select,insert,update,delete on table public.assisted_teacher_onboarding_requests
to service_role;

alter table public.teacher_profiles
  add column creation_provenance text not null default 'organic',
  add column assisted_onboarding_request_id uuid null references public.assisted_teacher_onboarding_requests(id),
  add constraint teacher_profiles_creation_provenance_check
    check (creation_provenance in ('organic','assisted')),
  add constraint teacher_profiles_assisted_origin_consistency
    check (
      (creation_provenance='organic' and assisted_onboarding_request_id is null)
      or
      (creation_provenance='assisted' and assisted_onboarding_request_id is not null)
    );

alter table public.teaching_options
  add column creation_provenance text not null default 'organic',
  add column assisted_onboarding_request_id uuid null references public.assisted_teacher_onboarding_requests(id),
  add constraint teaching_options_creation_provenance_check
    check (creation_provenance in ('organic','assisted')),
  add constraint teaching_options_assisted_origin_consistency
    check (
      (creation_provenance='organic' and assisted_onboarding_request_id is null)
      or
      (creation_provenance='assisted' and assisted_onboarding_request_id is not null)
    );

create unique index teaching_options_one_assisted_option_per_request_idx
  on public.teaching_options(assisted_onboarding_request_id)
  where assisted_onboarding_request_id is not null;

comment on column public.teacher_profiles.creation_provenance is
  'Immutable creation origin: organic self-service or assisted Teacher-approved Founding Supply onboarding.';
comment on column public.teaching_options.creation_provenance is
  'Immutable creation origin: organic self-service or assisted Teacher-approved Founding Supply onboarding.';

-- Acceptance is equivalent to first-time teaching enablement + public profile +
-- first public Teaching Option, so preserve future phone-trust compatibility.
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
    'publish_raahi_desk_post',
    'accept_assisted_teacher_onboarding',
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
create or replace function app_private.cmd_request_assisted_teacher_onboarding(
  p_location_id uuid,
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
  v_request uuid;
  v_result jsonb;
begin
  v_fp:=app_private.request_fingerprint(jsonb_build_object('location_id',p_location_id));
  v_gate:=app_private.begin_human_idempotent_command(
    v_actor,'request_assisted_teacher_onboarding',p_idempotency_key,v_fp
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  if not exists(select 1 from public.locations where id=p_location_id and state='live') then
    raise exception 'LOCATION_NOT_LIVE';
  end if;

  if exists(select 1 from public.teacher_profiles where account_id=v_actor)
     or exists(select 1 from public.teaching_options where teacher_account_id=v_actor) then
    raise exception 'FOUNDING_SUPPLY_EXISTING_TEACHER_DATA';
  end if;

  if exists(
    select 1 from public.account_capabilities
    where account_id=v_actor and capability_code='teach' and status='revoked'
  ) then
    raise exception 'TEACHING_REENABLE_REQUIRES_REVIEW';
  end if;

  if exists(
    select 1 from public.assisted_teacher_onboarding_requests
    where teacher_account_id=v_actor and state in ('requested','draft_ready')
  ) then
    raise exception 'ASSISTED_ONBOARDING_ALREADY_ACTIVE';
  end if;

  insert into public.assisted_teacher_onboarding_requests(
    teacher_account_id,requested_by_account_id,founding_location_id
  )
  values(v_actor,v_actor,p_location_id)
  returning id into v_request;

  perform app_private.write_location_audit(
    v_actor,
    'founding_supply.assistance_requested',
    p_location_id,
    'assisted_teacher_onboarding',
    v_request,
    null,
    jsonb_build_object('consent_text_version','founding-supply-v1')
  );

  v_result:=jsonb_build_object(
    'request_id',v_request,
    'state','requested',
    'founding_location_id',p_location_id
  );
  perform app_private.complete_human_idempotent_command(
    v_actor,'request_assisted_teacher_onboarding',p_idempotency_key,v_result
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
  if not app_private.has_account_capability('platform_admin') then
    raise exception 'PLATFORM_ADMIN_REQUIRED';
  end if;

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
      'consent_text_version','founding-supply-v1'
    )
  );

  v_result:=jsonb_build_object(
    'request_id',p_request_id,
    'teacher_account_id',v_teacher,
    'state','draft_ready'
  );
  perform app_private.complete_human_idempotent_command(
    v_actor,'prepare_assisted_teacher_onboarding',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;
create or replace function app_private.cmd_accept_assisted_teacher_onboarding(
  p_request_id uuid,
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
  v_request public.assisted_teacher_onboarding_requests%rowtype;
  v_capability uuid;
  v_option uuid;
  v_result jsonb;
begin
  v_fp:=app_private.request_fingerprint(jsonb_build_object('request_id',p_request_id));
  v_gate:=app_private.begin_human_idempotent_command(
    v_actor,'accept_assisted_teacher_onboarding',p_idempotency_key,v_fp
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select * into v_request
  from public.assisted_teacher_onboarding_requests
  where id=p_request_id
  for update;

  if not found then raise exception 'ASSISTED_ONBOARDING_NOT_FOUND'; end if;
  if v_request.teacher_account_id<>v_actor then raise exception 'NOT_AUTHORIZED'; end if;
  if v_request.state<>'draft_ready' then raise exception 'ASSISTED_ONBOARDING_NOT_ACCEPTABLE'; end if;

  if not exists(
    select 1 from public.locations
    where id=v_request.founding_location_id and state='live'
  ) then
    raise exception 'LOCATION_NOT_LIVE';
  end if;

  if exists(select 1 from public.teacher_profiles where account_id=v_actor)
     or exists(select 1 from public.teaching_options where teacher_account_id=v_actor) then
    raise exception 'FOUNDING_SUPPLY_CHANGED_SINCE_REQUEST';
  end if;

  if exists(
    select 1 from public.account_capabilities
    where account_id=v_actor and capability_code='teach' and status='revoked'
  ) then
    raise exception 'TEACHING_REENABLE_REQUIRES_REVIEW';
  end if;

  select id into v_capability
  from public.account_capabilities
  where account_id=v_actor and capability_code='teach' and status='active'
  limit 1;

  if v_capability is null then
    insert into public.account_capabilities(
      account_id,capability_code,granted_by_account_id
    )
    values(v_actor,'teach',v_actor)
    returning id into v_capability;

    perform app_private.write_audit(
      v_actor,
      'account.teaching_enable',
      'account',
      v_actor,
      null,
      null,
      jsonb_build_object(
        'source','assisted_teacher_onboarding',
        'request_id',p_request_id
      )
    );
  end if;

  insert into public.teacher_profiles(
    account_id,
    headline,
    bio,
    experience_summary,
    visibility_status,
    creation_provenance,
    assisted_onboarding_request_id
  )
  values(
    v_actor,
    v_request.proposed_headline,
    v_request.proposed_bio,
    v_request.proposed_experience_summary,
    'visible',
    'assisted',
    p_request_id
  );

  insert into public.teaching_options(
    teacher_account_id,
    organization_id,
    title,
    category,
    description,
    teaching_mode,
    area_or_venue_text,
    fee_display_text,
    availability_status,
    creation_provenance,
    assisted_onboarding_request_id
  )
  values(
    v_actor,
    null,
    v_request.proposed_option_title,
    v_request.proposed_option_category,
    v_request.proposed_option_description,
    v_request.proposed_teaching_mode,
    v_request.proposed_area_or_venue_text,
    v_request.proposed_fee_display_text,
    'taking_new_learners',
    'assisted',
    p_request_id
  )
  returning id into v_option;

  insert into public.teaching_option_locations(teaching_option_id,location_id)
  values(v_option,v_request.founding_location_id);

  update public.assisted_teacher_onboarding_requests
  set
    state='accepted',
    resolved_by_account_id=v_actor,
    resolved_at=now(),
    resolution_reason='teacher_accepted_exact_draft'
  where id=p_request_id;

  perform app_private.write_location_audit(
    v_actor,
    'founding_supply.teacher_accepted',
    v_request.founding_location_id,
    'assisted_teacher_onboarding',
    p_request_id,
    null,
    jsonb_build_object(
      'teacher_account_id',v_actor,
      'teaching_option_id',v_option,
      'consent_text_version',v_request.consent_text_version,
      'creation_provenance','assisted'
    )
  );

  v_result:=jsonb_build_object(
    'request_id',p_request_id,
    'state','accepted',
    'teacher_account_id',v_actor,
    'teaching_option_id',v_option,
    'creation_provenance','assisted'
  );
  perform app_private.complete_human_idempotent_command(
    v_actor,'accept_assisted_teacher_onboarding',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.cmd_decline_assisted_teacher_onboarding(
  p_request_id uuid,
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
  v_fp:=app_private.request_fingerprint(jsonb_build_object('request_id',p_request_id));
  v_gate:=app_private.begin_human_idempotent_command(
    v_actor,'decline_assisted_teacher_onboarding',p_idempotency_key,v_fp
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select teacher_account_id,founding_location_id,state
    into v_teacher,v_location,v_state
  from public.assisted_teacher_onboarding_requests
  where id=p_request_id
  for update;

  if not found then raise exception 'ASSISTED_ONBOARDING_NOT_FOUND'; end if;
  if v_teacher<>v_actor then raise exception 'NOT_AUTHORIZED'; end if;
  if v_state<>'draft_ready' then raise exception 'ASSISTED_ONBOARDING_NOT_DECLINABLE'; end if;

  update public.assisted_teacher_onboarding_requests
  set state='declined',resolved_by_account_id=v_actor,resolved_at=now(),
      resolution_reason='teacher_declined_draft'
  where id=p_request_id;

  perform app_private.write_location_audit(
    v_actor,'founding_supply.teacher_declined',v_location,
    'assisted_teacher_onboarding',p_request_id,null,'{}'::jsonb
  );

  v_result:=jsonb_build_object('request_id',p_request_id,'state','declined');
  perform app_private.complete_human_idempotent_command(
    v_actor,'decline_assisted_teacher_onboarding',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.cmd_cancel_assisted_teacher_onboarding(
  p_request_id uuid,
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
  v_fp:=app_private.request_fingerprint(jsonb_build_object('request_id',p_request_id));
  v_gate:=app_private.begin_human_idempotent_command(
    v_actor,'cancel_assisted_teacher_onboarding',p_idempotency_key,v_fp
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select teacher_account_id,founding_location_id,state
    into v_teacher,v_location,v_state
  from public.assisted_teacher_onboarding_requests
  where id=p_request_id
  for update;

  if not found then raise exception 'ASSISTED_ONBOARDING_NOT_FOUND'; end if;
  if v_teacher<>v_actor then raise exception 'NOT_AUTHORIZED'; end if;
  if v_state not in ('requested','draft_ready') then
    raise exception 'ASSISTED_ONBOARDING_NOT_CANCELLABLE';
  end if;

  update public.assisted_teacher_onboarding_requests
  set state='cancelled',resolved_by_account_id=v_actor,resolved_at=now(),
      resolution_reason='teacher_cancelled'
  where id=p_request_id;

  perform app_private.write_location_audit(
    v_actor,'founding_supply.teacher_cancelled',v_location,
    'assisted_teacher_onboarding',p_request_id,null,'{}'::jsonb
  );

  v_result:=jsonb_build_object('request_id',p_request_id,'state','cancelled');
  perform app_private.complete_human_idempotent_command(
    v_actor,'cancel_assisted_teacher_onboarding',p_idempotency_key,v_result
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
  if not app_private.has_account_capability('platform_admin') then
    raise exception 'PLATFORM_ADMIN_REQUIRED';
  end if;
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
    jsonb_build_object('teacher_account_id',v_teacher,'reason',btrim(p_reason))
  );

  v_result:=jsonb_build_object('request_id',p_request_id,'state','withdrawn');
  perform app_private.complete_human_idempotent_command(
    v_actor,'withdraw_assisted_teacher_onboarding',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;
create or replace function app_private.read_my_assisted_teacher_onboarding()
returns setof jsonb
language sql
stable
security definer
set search_path=''
as $$
  select jsonb_build_object(
    'request_id',r.id,
    'teacher_account_id',r.teacher_account_id,
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
    'resolved_at',r.resolved_at
  )
  from public.assisted_teacher_onboarding_requests r
  join public.locations l on l.id=r.founding_location_id
  where r.teacher_account_id=app_private.current_account_id()
  order by r.created_at desc,r.id;
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
begin
  if app_private.current_account_id() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not app_private.has_account_capability('platform_admin') then
    raise exception 'PLATFORM_ADMIN_REQUIRED';
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
    'resolved_at',r.resolved_at
  )
  from public.assisted_teacher_onboarding_requests r
  join public.accounts a on a.id=r.teacher_account_id
  join public.locations l on l.id=r.founding_location_id
  where p_state is null or r.state=p_state
  order by
    case r.state when 'requested' then 0 when 'draft_ready' then 1 else 2 end,
    r.requested_at,
    r.id;
end;
$$;

revoke all on function
  app_private.cmd_request_assisted_teacher_onboarding(uuid,text),
  app_private.cmd_prepare_assisted_teacher_onboarding(uuid,text,text,text,text,text,text,text,text,text,text),
  app_private.cmd_accept_assisted_teacher_onboarding(uuid,text),
  app_private.cmd_decline_assisted_teacher_onboarding(uuid,text),
  app_private.cmd_cancel_assisted_teacher_onboarding(uuid,text),
  app_private.cmd_withdraw_assisted_teacher_onboarding(uuid,text,text),
  app_private.read_my_assisted_teacher_onboarding(),
  app_private.read_platform_assisted_teacher_onboarding(text)
from public,anon,authenticated,service_role;

grant execute on function
  app_private.cmd_request_assisted_teacher_onboarding(uuid,text),
  app_private.cmd_prepare_assisted_teacher_onboarding(uuid,text,text,text,text,text,text,text,text,text,text),
  app_private.cmd_accept_assisted_teacher_onboarding(uuid,text),
  app_private.cmd_decline_assisted_teacher_onboarding(uuid,text),
  app_private.cmd_cancel_assisted_teacher_onboarding(uuid,text),
  app_private.cmd_withdraw_assisted_teacher_onboarding(uuid,text,text),
  app_private.read_my_assisted_teacher_onboarding(),
  app_private.read_platform_assisted_teacher_onboarding(text)
to authenticated;

create or replace function public.request_assisted_teacher_onboarding(
  p_location_id uuid,
  p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path=''
as $$
  select app_private.cmd_request_assisted_teacher_onboarding(
    p_location_id,p_idempotency_key
  );
$$;

create or replace function public.prepare_assisted_teacher_onboarding(
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
language sql
security invoker
set search_path=''
as $$
  select app_private.cmd_prepare_assisted_teacher_onboarding(
    p_request_id,p_headline,p_bio,p_experience_summary,
    p_option_title,p_option_category,p_option_description,p_teaching_mode,
    p_area_or_venue_text,p_fee_display_text,p_idempotency_key
  );
$$;

create or replace function public.accept_assisted_teacher_onboarding(
  p_request_id uuid,
  p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path=''
as $$
  select app_private.cmd_accept_assisted_teacher_onboarding(
    p_request_id,p_idempotency_key
  );
$$;

create or replace function public.decline_assisted_teacher_onboarding(
  p_request_id uuid,
  p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path=''
as $$
  select app_private.cmd_decline_assisted_teacher_onboarding(
    p_request_id,p_idempotency_key
  );
$$;

create or replace function public.cancel_assisted_teacher_onboarding(
  p_request_id uuid,
  p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path=''
as $$
  select app_private.cmd_cancel_assisted_teacher_onboarding(
    p_request_id,p_idempotency_key
  );
$$;

create or replace function public.withdraw_assisted_teacher_onboarding(
  p_request_id uuid,
  p_reason text,
  p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path=''
as $$
  select app_private.cmd_withdraw_assisted_teacher_onboarding(
    p_request_id,p_reason,p_idempotency_key
  );
$$;

create or replace function public.get_my_assisted_teacher_onboarding()
returns setof jsonb
language sql
stable
security invoker
set search_path=''
as $$
  select * from app_private.read_my_assisted_teacher_onboarding();
$$;

create or replace function public.get_platform_assisted_teacher_onboarding(
  p_state text default null
)
returns setof jsonb
language sql
stable
security invoker
set search_path=''
as $$
  select * from app_private.read_platform_assisted_teacher_onboarding(p_state);
$$;

revoke all on function
  public.request_assisted_teacher_onboarding(uuid,text),
  public.prepare_assisted_teacher_onboarding(uuid,text,text,text,text,text,text,text,text,text,text),
  public.accept_assisted_teacher_onboarding(uuid,text),
  public.decline_assisted_teacher_onboarding(uuid,text),
  public.cancel_assisted_teacher_onboarding(uuid,text),
  public.withdraw_assisted_teacher_onboarding(uuid,text,text),
  public.get_my_assisted_teacher_onboarding(),
  public.get_platform_assisted_teacher_onboarding(text)
from public,anon,authenticated,service_role;

grant execute on function
  public.request_assisted_teacher_onboarding(uuid,text),
  public.prepare_assisted_teacher_onboarding(uuid,text,text,text,text,text,text,text,text,text,text),
  public.accept_assisted_teacher_onboarding(uuid,text),
  public.decline_assisted_teacher_onboarding(uuid,text),
  public.cancel_assisted_teacher_onboarding(uuid,text),
  public.withdraw_assisted_teacher_onboarding(uuid,text,text),
  public.get_my_assisted_teacher_onboarding(),
  public.get_platform_assisted_teacher_onboarding(text)
to authenticated;
