-- Raahi Learning V1.4D — scoped market-activation authority runtime smoke.
-- Disposable only. Every synthetic row rolls back.

begin;

insert into auth.users(id,aud,role,email) values
('89111111-1111-1111-1111-111111111111','authenticated','authenticated','v14d-global@test.invalid'),
('89222222-2222-2222-2222-222222222222','authenticated','authenticated','v14d-gomoh-manager@test.invalid'),
('89333333-3333-3333-3333-333333333333','authenticated','authenticated','v14d-dhanbad-manager@test.invalid'),
('89444444-4444-4444-4444-444444444444','authenticated','authenticated','v14d-gomoh-teacher@test.invalid'),
('89555555-5555-5555-5555-555555555555','authenticated','authenticated','v14d-dhanbad-teacher@test.invalid'),
('89666666-6666-6666-6666-666666666666','authenticated','authenticated','v14d-outsider@test.invalid');

set local role authenticated;

select set_config('request.jwt.claim.sub','89111111-1111-1111-1111-111111111111',true);
select set_config('v14d.global',(public.bootstrap_account('V14D Global')->>'account_id'),true);

select set_config('request.jwt.claim.sub','89222222-2222-2222-2222-222222222222',true);
select set_config('v14d.gomoh_manager',(public.bootstrap_account('V14D Gomoh Manager')->>'account_id'),true);

select set_config('request.jwt.claim.sub','89333333-3333-3333-3333-333333333333',true);
select set_config('v14d.dhanbad_manager',(public.bootstrap_account('V14D Dhanbad Manager')->>'account_id'),true);

select set_config('request.jwt.claim.sub','89444444-4444-4444-4444-444444444444',true);
select set_config('v14d.gomoh_teacher',(public.bootstrap_account('V14D Gomoh Teacher')->>'account_id'),true);

select set_config('request.jwt.claim.sub','89555555-5555-5555-5555-555555555555',true);
select set_config('v14d.dhanbad_teacher',(public.bootstrap_account('V14D Dhanbad Teacher')->>'account_id'),true);

select set_config('request.jwt.claim.sub','89666666-6666-6666-6666-666666666666',true);
select set_config('v14d.outsider',(public.bootstrap_account('V14D Outsider')->>'account_id'),true);

reset role;

insert into public.locations(id,name,slug,state,country_code) values
('89911111-1111-1111-1111-111111111111','V14D Gomoh','v14d-gomoh','live','IN'),
('89922222-2222-2222-2222-222222222222','V14D Dhanbad','v14d-dhanbad','live','IN');

insert into public.account_capabilities(account_id,capability_code,status,granted_by_account_id)
values(current_setting('v14d.global')::uuid,'platform_admin','active',current_setting('v14d.global')::uuid);

insert into public.location_staff_assignments(location_id,account_id,staff_type,status) values
('89911111-1111-1111-1111-111111111111',current_setting('v14d.gomoh_manager')::uuid,'local_manager','active'),
('89922222-2222-2222-2222-222222222222',current_setting('v14d.dhanbad_manager')::uuid,'local_manager','active');

-- Genuine Teachers create one private assistance request in each Location.
set local role authenticated;

select set_config('request.jwt.claim.sub','89444444-4444-4444-4444-444444444444',true);
select set_config(
  'v14d.gomoh_request',
  (
    public.request_assisted_teacher_onboarding(
      '89911111-1111-1111-1111-111111111111',
      'v14d-gomoh-request'
    )->>'request_id'
  ),
  true
);

select set_config('request.jwt.claim.sub','89555555-5555-5555-5555-555555555555',true);
select set_config(
  'v14d.dhanbad_request',
  (
    public.request_assisted_teacher_onboarding(
      '89922222-2222-2222-2222-222222222222',
      'v14d-dhanbad-request'
    )->>'request_id'
  ),
  true
);

-- Gomoh manager sees only Gomoh.
select set_config('request.jwt.claim.sub','89222222-2222-2222-2222-222222222222',true);
do $$
declare n integer; wrong integer;
begin
  select count(*) into n
  from public.get_platform_assisted_teacher_onboarding(null) x;
  select count(*) into wrong
  from public.get_platform_assisted_teacher_onboarding(null) x
  where x->>'founding_location_id'='89922222-2222-2222-2222-222222222222';

  if n<>1 then raise exception 'GOMOH_MANAGER_QUEUE_NOT_SCOPED:%',n; end if;
  if wrong<>0 then raise exception 'GOMOH_MANAGER_SAW_DHANBAD'; end if;
end $$;

-- Gomoh manager can publish Raahi Desk only inside Gomoh.
select set_config(
  'v14d.gomoh_post',
  (
    public.publish_raahi_desk_post(
      '89911111-1111-1111-1111-111111111111',
      'resource',
      'Genuine scoped Gomoh platform editorial smoke.',
      null,
      'v14d-gomoh-desk'
    )->>'post_id'
  ),
  true
);

do $$
begin
  perform public.publish_raahi_desk_post(
    '89922222-2222-2222-2222-222222222222',
    'resource',
    'Cross-location publish must fail.',
    null,
    'v14d-cross-desk'
  );
  raise exception 'GOMOH_MANAGER_PUBLISHED_DHANBAD';
exception
  when others then
    if position('MARKET_ACTIVATION_SCOPE_REQUIRED' in sqlerrm)=0 then raise; end if;
end $$;

-- Gomoh manager can prepare only the Gomoh Teacher request.
select public.prepare_assisted_teacher_onboarding(
  current_setting('v14d.gomoh_request')::uuid,
  'Gomoh Maths Teacher',
  'Private draft bio.',
  'Private draft experience.',
  'Gomoh Maths',
  'Mathematics',
  'Private draft description.',
  'in_person',
  'V14D Gomoh',
  'Contact for fees',
  'v14d-gomoh-prepare'
);

do $$
begin
  perform public.prepare_assisted_teacher_onboarding(
    current_setting('v14d.dhanbad_request')::uuid,
    'Wrong-city draft',
    null,
    null,
    'Wrong-city option',
    null,
    null,
    'in_person',
    null,
    null,
    'v14d-cross-prepare'
  );
  raise exception 'GOMOH_MANAGER_PREPARED_DHANBAD';
exception
  when others then
    if position('MARKET_ACTIVATION_SCOPE_REQUIRED' in sqlerrm)=0 then raise; end if;
end $$;

-- Dhanbad manager sees only Dhanbad and can prepare Dhanbad.
select set_config('request.jwt.claim.sub','89333333-3333-3333-3333-333333333333',true);
do $$
declare n integer; wrong integer;
begin
  select count(*) into n
  from public.get_platform_assisted_teacher_onboarding(null) x;
  select count(*) into wrong
  from public.get_platform_assisted_teacher_onboarding(null) x
  where x->>'founding_location_id'='89911111-1111-1111-1111-111111111111';

  if n<>1 then raise exception 'DHANBAD_MANAGER_QUEUE_NOT_SCOPED:%',n; end if;
  if wrong<>0 then raise exception 'DHANBAD_MANAGER_SAW_GOMOH'; end if;
end $$;

select public.prepare_assisted_teacher_onboarding(
  current_setting('v14d.dhanbad_request')::uuid,
  'Dhanbad Science Teacher',
  'Private draft bio.',
  'Private draft experience.',
  'Dhanbad Science',
  'Science',
  'Private draft description.',
  'both',
  'V14D Dhanbad',
  'Contact for fees',
  'v14d-dhanbad-prepare'
);

-- Dhanbad manager cannot withdraw Gomoh request.
do $$
begin
  perform public.withdraw_assisted_teacher_onboarding(
    current_setting('v14d.gomoh_request')::uuid,
    'Cross-location withdrawal must fail.',
    'v14d-cross-withdraw'
  );
  raise exception 'DHANBAD_MANAGER_WITHDREW_GOMOH';
exception
  when others then
    if position('MARKET_ACTIVATION_SCOPE_REQUIRED' in sqlerrm)=0 then raise; end if;
end $$;

-- Unscoped Account cannot read the operational queue.
select set_config('request.jwt.claim.sub','89666666-6666-6666-6666-666666666666',true);
do $$
begin
  perform public.get_platform_assisted_teacher_onboarding(null);
  raise exception 'UNSCOPED_ACCOUNT_READ_MARKET_QUEUE';
exception
  when others then
    if position('MARKET_ACTIVATION_SCOPE_REQUIRED' in sqlerrm)=0 then raise; end if;
end $$;

-- Global Platform Admin sees both Locations and can operate cross-city.
select set_config('request.jwt.claim.sub','89111111-1111-1111-1111-111111111111',true);
do $$
declare n integer;
begin
  select count(*) into n
  from public.get_platform_assisted_teacher_onboarding(null) x
  where x->>'founding_location_id' in (
    '89911111-1111-1111-1111-111111111111',
    '89922222-2222-2222-2222-222222222222'
  );
  if n<>2 then raise exception 'GLOBAL_ADMIN_QUEUE_NOT_GLOBAL:%',n; end if;
end $$;

select public.withdraw_assisted_teacher_onboarding(
  current_setting('v14d.gomoh_request')::uuid,
  'Global cross-location operational proof.',
  'v14d-global-withdraw'
);

reset role;

-- Verify audit distinguishes Location-scoped authority.
do $$
begin
  if not exists(
    select 1
    from public.audit_log
    where action_type='community.raahi_desk_publish'
      and target_id=current_setting('v14d.gomoh_post')::uuid
      and metadata->>'authority_scope'='location_local_manager'
  ) then
    raise exception 'LOCAL_MANAGER_AUDIT_SCOPE_MISSING';
  end if;

  if exists(
    select 1
    from public.teacher_profiles
    where account_id in (
      current_setting('v14d.gomoh_teacher')::uuid,
      current_setting('v14d.dhanbad_teacher')::uuid
    )
  ) then
    raise exception 'SCOPED_OPERATOR_DRAFT_PUBLISHED_PROFILE';
  end if;

  if exists(
    select 1
    from public.teaching_options
    where teacher_account_id in (
      current_setting('v14d.gomoh_teacher')::uuid,
      current_setting('v14d.dhanbad_teacher')::uuid
    )
  ) then
    raise exception 'SCOPED_OPERATOR_DRAFT_PUBLISHED_OPTION';
  end if;
end $$;

rollback;

select 'V14D_SCOPED_MARKET_ACTIVATION_RUNTIME_TESTS_PASS' as result;
