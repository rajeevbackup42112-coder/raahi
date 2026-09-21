-- Raahi Learning V1.4C — Founding Supply assisted Teacher onboarding runtime smoke.
-- Disposable only. All synthetic Auth/application rows and public supply roll back.

begin;

insert into auth.users(id,aud,role,email) values
('88111111-1111-1111-1111-111111111111','authenticated','authenticated','founding-teacher@test.invalid'),
('88222222-2222-2222-2222-222222222222','authenticated','authenticated','founding-platform@test.invalid'),
('88333333-3333-3333-3333-333333333333','authenticated','authenticated','founding-other@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','88111111-1111-1111-1111-111111111111',true);
select set_config('t.teacher',(public.bootstrap_account('Founding Teacher')->>'account_id'),true);

select set_config('request.jwt.claim.sub','88222222-2222-2222-2222-222222222222',true);
select set_config('t.platform',(public.bootstrap_account('Founding Platform')->>'account_id'),true);

select set_config('request.jwt.claim.sub','88333333-3333-3333-3333-333333333333',true);
select set_config('t.other',(public.bootstrap_account('Organic Teacher')->>'account_id'),true);
reset role;

insert into public.locations(id,name,slug,state,country_code)
values('88999999-9999-9999-9999-999999999999','Founding Test Location','founding-test-location-v14c','live','IN');

insert into public.account_capabilities(account_id,capability_code,granted_by_account_id)
values(current_setting('t.platform')::uuid,'platform_admin',current_setting('t.platform')::uuid);

-- The genuine Teacher initiates assistance.
set local role authenticated;
select set_config('request.jwt.claim.sub','88111111-1111-1111-1111-111111111111',true);

select set_config(
  't.request',
  (
    public.request_assisted_teacher_onboarding(
      '88999999-9999-9999-9999-999999999999',
      'v14c-request-1'
    )->>'request_id'
  ),
  true
);

do $$
begin
  if exists(select 1 from public.teacher_profiles where account_id=current_setting('t.teacher')::uuid) then
    raise exception 'REQUEST_CREATED_PUBLIC_PROFILE';
  end if;
  if exists(select 1 from public.teaching_options where teacher_account_id=current_setting('t.teacher')::uuid) then
    raise exception 'REQUEST_CREATED_PUBLIC_OPTION';
  end if;
end $$;

-- Another ordinary Account cannot prepare the draft.
select set_config('request.jwt.claim.sub','88333333-3333-3333-3333-333333333333',true);
do $$
begin
  perform public.prepare_assisted_teacher_onboarding(
    current_setting('t.request')::uuid,
    'Class 10 Maths teacher in Founding Test Location',
    'I help students build strong concepts and exam confidence.',
    '10 years of teaching experience.',
    'Class 10 Mathematics',
    'Mathematics',
    'Concept building, revision and exam preparation.',
    'both',
    'Founding Test Location',
    'Contact for fee details',
    'v14c-forged-prepare'
  );
  raise exception 'NON_PLATFORM_PREPARE_ALLOWED';
exception
  when others then
    if position('PLATFORM_ADMIN_REQUIRED' in sqlerrm)=0 then raise; end if;
end $$;

-- Platform Admin prepares private proposed facts.
select set_config('request.jwt.claim.sub','88222222-2222-2222-2222-222222222222',true);

select public.prepare_assisted_teacher_onboarding(
  current_setting('t.request')::uuid,
  'Class 10 Maths teacher in Founding Test Location',
  'I help students build strong concepts and exam confidence.',
  '10 years of teaching experience.',
  'Class 10 Mathematics',
  'Mathematics',
  'Concept building, revision and exam preparation.',
  'both',
  'Founding Test Location',
  'Contact for fee details',
  'v14c-prepare-1'
);

-- Draft still has zero public supply.
reset role;
do $$
begin
  if exists(select 1 from public.teacher_profiles where account_id=current_setting('t.teacher')::uuid) then
    raise exception 'DRAFT_CREATED_PUBLIC_PROFILE';
  end if;
  if exists(select 1 from public.teaching_options where teacher_account_id=current_setting('t.teacher')::uuid) then
    raise exception 'DRAFT_CREATED_PUBLIC_OPTION';
  end if;
end $$;

-- Platform Admin cannot accept for the Teacher.
set local role authenticated;
select set_config('request.jwt.claim.sub','88222222-2222-2222-2222-222222222222',true);
do $$
begin
  perform public.accept_assisted_teacher_onboarding(
    current_setting('t.request')::uuid,
    'v14c-platform-accept-forbidden'
  );
  raise exception 'PLATFORM_ACCEPTED_FOR_TEACHER';
exception
  when others then
    if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if;
end $$;

-- Teacher sees the exact private proposal and accepts.
select set_config('request.jwt.claim.sub','88111111-1111-1111-1111-111111111111',true);

do $$
declare j jsonb;
begin
  select x into j
  from public.get_my_assisted_teacher_onboarding() x
  where x->>'request_id'=current_setting('t.request');

  if j is null then raise exception 'TEACHER_PROPOSAL_NOT_READABLE'; end if;
  if j->>'state'<>'draft_ready' then raise exception 'TEACHER_PROPOSAL_STATE_WRONG:%',j; end if;
  if j->>'proposed_headline'<>'Class 10 Maths teacher in Founding Test Location' then
    raise exception 'TEACHER_PROPOSAL_HEADLINE_WRONG:%',j;
  end if;
  if j->>'proposed_option_title'<>'Class 10 Mathematics' then
    raise exception 'TEACHER_PROPOSAL_OPTION_WRONG:%',j;
  end if;
  if j->>'consent_text_version'<>'founding-supply-v1' then
    raise exception 'CONSENT_VERSION_WRONG:%',j;
  end if;
end $$;

select set_config(
  't.option',
  (
    public.accept_assisted_teacher_onboarding(
      current_setting('t.request')::uuid,
      'v14c-accept-1'
    )->>'teaching_option_id'
  ),
  true
);

-- Same key/same request returns the same materialised option.
do $$
declare j jsonb;
begin
  j:=public.accept_assisted_teacher_onboarding(
    current_setting('t.request')::uuid,
    'v14c-accept-1'
  );
  if j->>'teaching_option_id'<>current_setting('t.option') then
    raise exception 'ASSISTED_ACCEPT_RETRY_DUPLICATED';
  end if;
end $$;

reset role;

do $$
declare v_profile_provenance text; v_option_provenance text; v_state text;
begin
  select creation_provenance into v_profile_provenance
  from public.teacher_profiles
  where account_id=current_setting('t.teacher')::uuid;

  select creation_provenance into v_option_provenance
  from public.teaching_options
  where id=current_setting('t.option')::uuid;

  select state into v_state
  from public.assisted_teacher_onboarding_requests
  where id=current_setting('t.request')::uuid;

  if v_profile_provenance<>'assisted' then raise exception 'PROFILE_NOT_ASSISTED'; end if;
  if v_option_provenance<>'assisted' then raise exception 'OPTION_NOT_ASSISTED'; end if;
  if v_state<>'accepted' then raise exception 'REQUEST_NOT_ACCEPTED'; end if;

  if not exists(
    select 1 from public.account_capabilities
    where account_id=current_setting('t.teacher')::uuid
      and capability_code='teach'
      and status='active'
  ) then raise exception 'TEACH_CAPABILITY_NOT_ENABLED'; end if;

  if not exists(
    select 1 from public.teacher_profiles
    where account_id=current_setting('t.teacher')::uuid
      and visibility_status='visible'
      and assisted_onboarding_request_id=current_setting('t.request')::uuid
  ) then raise exception 'ASSISTED_PROFILE_MATERIALISATION_BAD'; end if;

  if not exists(
    select 1 from public.teaching_options
    where id=current_setting('t.option')::uuid
      and teacher_account_id=current_setting('t.teacher')::uuid
      and availability_status='taking_new_learners'
      and assisted_onboarding_request_id=current_setting('t.request')::uuid
  ) then raise exception 'ASSISTED_OPTION_MATERIALISATION_BAD'; end if;

  if not exists(
    select 1 from public.teaching_option_locations
    where teaching_option_id=current_setting('t.option')::uuid
      and location_id='88999999-9999-9999-9999-999999999999'
  ) then raise exception 'ASSISTED_LOCATION_MISSING'; end if;

  if not exists(
    select 1 from public.audit_log
    where action_type='founding_supply.teacher_accepted'
      and actor_account_id=current_setting('t.teacher')::uuid
      and target_id=current_setting('t.request')::uuid
  ) then raise exception 'ASSISTED_ACCEPT_AUDIT_MISSING'; end if;
end $$;

-- Accepted supply is discoverable as the genuine Teacher.
set local role authenticated;
select set_config('request.jwt.claim.sub','88333333-3333-3333-3333-333333333333',true);

do $$
declare n integer;
begin
  select count(*) into n
  from public.discover_teaching_options(
    '88999999-9999-9999-9999-999999999999',
    'Class 10 Mathematics'
  ) x
  where x->>'teaching_option_id'=current_setting('t.option');
  if n<>1 then raise exception 'ASSISTED_SUPPLY_NOT_DISCOVERABLE'; end if;
end $$;

-- Ordinary self-service remains organic.
select public.enable_teaching('v14c-organic-enable');
select public.upsert_teacher_profile(
  'Organic Science teacher',
  'Organic self-service profile',
  'Self-entered experience',
  'visible',
  'v14c-organic-profile'
);
select set_config(
  't.organic_option',
  (
    public.publish_teaching_option(
      null,
      'Organic Science',
      'Science',
      'Self-service option',
      'in_person',
      'Founding Test Location',
      'Contact for fee details',
      array['88999999-9999-9999-9999-999999999999']::uuid[],
      'v14c-organic-option'
    )->>'teaching_option_id'
  ),
  true
);

reset role;

do $$
begin
  if (
    select creation_provenance from public.teacher_profiles
    where account_id=current_setting('t.other')::uuid
  )<>'organic' then raise exception 'ORGANIC_PROFILE_PROVENANCE_REGRESSED'; end if;

  if (
    select creation_provenance from public.teaching_options
    where id=current_setting('t.organic_option')::uuid
  )<>'organic' then raise exception 'ORGANIC_OPTION_PROVENANCE_REGRESSED'; end if;
end $$;

-- Direct browser writes remain denied.
set local role authenticated;
select set_config('request.jwt.claim.sub','88333333-3333-3333-3333-333333333333',true);
do $$
begin
  insert into public.assisted_teacher_onboarding_requests(
    teacher_account_id,requested_by_account_id,founding_location_id
  ) values (
    current_setting('t.other')::uuid,
    current_setting('t.other')::uuid,
    '88999999-9999-9999-9999-999999999999'
  );
  raise exception 'DIRECT_ASSISTANCE_WRITE_ALLOWED';
exception
  when insufficient_privilege then null;
end $$;

rollback;

select 'FOUNDING_SUPPLY_ASSISTED_TEACHER_RUNTIME_TESTS_PASS' as result;
