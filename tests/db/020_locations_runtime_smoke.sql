-- Raahi Learning V1.2 — Locations runtime smoke
-- Run only in disposable/dev environment. Entire suite rolls back.

begin;

insert into auth.users(id,aud,role,email) values
('11111111-1111-1111-1111-111111111111','authenticated','authenticated','admin@test.invalid'),
('22222222-2222-2222-2222-222222222222','authenticated','authenticated','manager@test.invalid'),
('33333333-3333-3333-3333-333333333333','authenticated','authenticated','member@test.invalid'),
('44444444-4444-4444-4444-444444444444','authenticated','authenticated','other@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
select set_config('test.admin_account',(public.bootstrap_account('Platform Admin')->>'account_id'),true);
select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',true);
select set_config('test.manager_account',(public.bootstrap_account('Local Manager')->>'account_id'),true);
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',true);
select set_config('test.member_account',(public.bootstrap_account('Community Member')->>'account_id'),true);
select set_config('request.jwt.claim.sub','44444444-4444-4444-4444-444444444444',true);
select set_config('test.other_account',(public.bootstrap_account('Other Account')->>'account_id'),true);

reset role;
insert into public.account_capabilities(account_id,capability_code,status)
values (current_setting('test.admin_account',true)::uuid,'platform_admin','active');

set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
select set_config('test.loc_interest',(public.create_location('Gomoh Test','gomoh-test','Dhanbad region','Jharkhand','IN','{}'::jsonb,'loc-create-interest')->>'location_id'),true);
select set_config('test.loc_prepare',(public.create_location('Dhanbad Test','dhanbad-test','Dhanbad region','Jharkhand','IN','{}'::jsonb,'loc-create-prepare')->>'location_id'),true);
select set_config('test.loc_live',(public.create_location('Live Test','live-test','Dhanbad region','Jharkhand','IN','{}'::jsonb,'loc-create-live')->>'location_id'),true);
select set_config('test.loc_retired',(public.create_location('Retired Test','retired-test','Dhanbad region','Jharkhand','IN','{}'::jsonb,'loc-create-retired')->>'location_id'),true);
select set_config('test.loc_invalid',(public.create_location('Invalid Transition','invalid-transition','Dhanbad region','Jharkhand','IN','{}'::jsonb,'loc-create-invalid')->>'location_id'),true);

-- Creation is retry-safe and fingerprint reuse is rejected.
do $$
declare v_count integer; v_result jsonb;
begin
  select count(*) into v_count from public.locations where slug='gomoh-test';
  v_result := public.create_location('Gomoh Test','gomoh-test','Dhanbad region','Jharkhand','IN','{}'::jsonb,'loc-create-interest');
  if (select count(*) from public.locations where slug='gomoh-test') <> v_count then
    raise exception 'LOCATION_CREATE_RETRY_DUPLICATED';
  end if;
  if v_result->>'location_id' <> current_setting('test.loc_interest',true) then
    raise exception 'LOCATION_CREATE_RETRY_RESULT_MISMATCH';
  end if;
  begin
    perform public.create_location('Different Name','gomoh-test-2','Dhanbad region','Jharkhand','IN','{}'::jsonb,'loc-create-interest');
    raise exception 'LOCATION_CREATE_FINGERPRINT_REUSE_NOT_REJECTED';
  exception when others then
    if position('IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST' in sqlerrm)=0 then raise; end if;
  end;
end $$;

-- Non-admin cannot create Location.
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',true);
do $$
begin
  perform public.create_location('Forbidden','forbidden',null,null,'IN','{}'::jsonb,'no-admin-create');
  raise exception 'NON_ADMIN_CREATED_LOCATION';
exception when others then
  if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if;
end $$;

-- Lifecycle: valid and invalid transitions.
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
select public.set_location_state(current_setting('test.loc_prepare',true)::uuid,'preparing','prepare test','state-prepare');
select public.set_location_state(current_setting('test.loc_live',true)::uuid,'preparing','prepare live','state-live-1');
select public.set_location_state(current_setting('test.loc_live',true)::uuid,'live','launch','state-live-2');
select public.set_location_state(current_setting('test.loc_retired',true)::uuid,'retired','not launching','state-retire');
do $$
begin
  perform public.set_location_state(current_setting('test.loc_invalid',true)::uuid,'live','skip preparing','bad-transition');
  raise exception 'INVALID_LOCATION_TRANSITION_ALLOWED';
exception when others then
  if position('INVALID_LOCATION_TRANSITION' in sqlerrm)=0 then raise; end if;
end $$;

-- Selected Location is a preference, not relationship ownership.
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',true);
select set_config('test.learner',(public.create_learner('Location Independent Learner','manage','none',null,'loc-learner')->>'learner_id'),true);
select set_config('test.access_before',(select count(*)::text from public.account_learner_access where learner_id=current_setting('test.learner',true)::uuid),true);
select public.set_selected_location(current_setting('test.loc_interest',true)::uuid,'select-loc-1');
select public.set_selected_location(current_setting('test.loc_prepare',true)::uuid,'select-loc-2');
do $$
declare v_selected uuid; v_after integer;
begin
  select selected_location_id into v_selected from public.account_location_preferences
  where account_id=current_setting('test.member_account',true)::uuid;
  if v_selected <> current_setting('test.loc_prepare',true)::uuid then raise exception 'SELECTED_LOCATION_NOT_UPDATED'; end if;
  select count(*) into v_after from public.account_learner_access where learner_id=current_setting('test.learner',true)::uuid;
  if v_after <> current_setting('test.access_before',true)::integer then raise exception 'LOCATION_SWITCH_MUTATED_LEARNER_RELATIONSHIP'; end if;
end $$;

do $$
begin
  perform public.set_selected_location(current_setting('test.loc_interest',true)::uuid,'select-loc-2');
  raise exception 'SELECTED_LOCATION_FINGERPRINT_REUSE_NOT_REJECTED';
exception when others then
  if position('IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST' in sqlerrm)=0 then raise; end if;
end $$;

do $$
begin
  perform public.set_selected_location(current_setting('test.loc_retired',true)::uuid,'select-retired');
  raise exception 'RETIRED_LOCATION_SELECTED';
exception when others then
  if position('LOCATION_RETIRED' in sqlerrm)=0 then raise; end if;
end $$;

-- Interest-only/preparing interest, duplicate safety, learn+teach coexistence, history.
select set_config('test.interest_learn',(public.register_location_interest(current_setting('test.loc_interest',true)::uuid,'learn','interest-learn-1')->>'interest_id'),true);
select public.register_location_interest(current_setting('test.loc_interest',true)::uuid,'learn','interest-learn-1');
select public.register_location_interest(current_setting('test.loc_interest',true)::uuid,'learn','interest-learn-2');
select set_config('test.interest_teach',(public.register_location_interest(current_setting('test.loc_interest',true)::uuid,'teach','interest-teach-1')->>'interest_id'),true);
do $$
declare v_active integer;
begin
  select count(*) into v_active from public.location_interests
  where location_id=current_setting('test.loc_interest',true)::uuid
    and account_id=current_setting('test.member_account',true)::uuid and state='active';
  if v_active <> 2 then raise exception 'LOCATION_INTEREST_ACTIVE_TUPLE_COUNT:%', v_active; end if;
end $$;

select public.withdraw_location_interest(current_setting('test.loc_interest',true)::uuid,'learn','withdraw-learn-1');
select public.register_location_interest(current_setting('test.loc_interest',true)::uuid,'learn','interest-learn-3');
do $$
declare v_active integer; v_withdrawn integer;
begin
  select count(*) filter (where state='active'), count(*) filter (where state='withdrawn')
    into v_active, v_withdrawn from public.location_interests
  where location_id=current_setting('test.loc_interest',true)::uuid
    and account_id=current_setting('test.member_account',true)::uuid and intent_type='learn';
  if v_active <> 1 or v_withdrawn <> 1 then raise exception 'LOCATION_INTEREST_HISTORY_BAD'; end if;
end $$;

select public.register_location_interest(current_setting('test.loc_prepare',true)::uuid,'learn','prepare-interest');
do $$
begin
  perform public.register_location_interest(current_setting('test.loc_live',true)::uuid,'learn','live-interest');
  raise exception 'LIVE_LOCATION_ACCEPTED_LAUNCH_INTEREST';
exception when others then
  if position('LOCATION_NOT_ACCEPTING_INTEREST' in sqlerrm)=0 then raise; end if;
end $$;

-- Direct client writes are denied.
do $$
begin
  insert into public.location_interests(location_id,account_id,intent_type)
  values (current_setting('test.loc_interest',true)::uuid,current_setting('test.member_account',true)::uuid,'learn');
  raise exception 'DIRECT_INTEREST_WRITE_ALLOWED';
exception when insufficient_privilege then null;
end $$;

do $$
begin
  update public.account_location_preferences set selected_location_id=current_setting('test.loc_interest',true)::uuid
  where account_id=current_setting('test.member_account',true)::uuid;
  raise exception 'DIRECT_PREFERENCE_WRITE_ALLOWED';
exception when insufficient_privilege then null;
end $$;

-- Local Manager exact Location scope + aggregate-only readiness.
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
select set_config('test.assignment',(public.assign_local_manager(current_setting('test.loc_interest',true)::uuid,current_setting('test.manager_account',true)::uuid,'assign-manager-1')->>'assignment_id'),true);
select public.assign_local_manager(current_setting('test.loc_interest',true)::uuid,current_setting('test.manager_account',true)::uuid,'assign-manager-2');

do $$
declare v_count integer;
begin
  select count(*) into v_count from public.location_staff_assignments
  where location_id=current_setting('test.loc_interest',true)::uuid
    and account_id=current_setting('test.manager_account',true)::uuid and status='active';
  if v_count <> 1 then raise exception 'DUPLICATE_ACTIVE_LOCAL_MANAGER:%', v_count; end if;
end $$;

select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',true);
do $$
declare v_counts jsonb; v_named integer;
begin
  v_counts := public.get_location_interest_counts(current_setting('test.loc_interest',true)::uuid);
  if (v_counts->>'learn')::int <> 1 or (v_counts->>'teach')::int <> 1 or (v_counts->>'total')::int <> 2 then
    raise exception 'MANAGER_AGGREGATE_COUNTS_BAD:%', v_counts;
  end if;
  begin
    perform public.get_location_interest_counts(current_setting('test.loc_prepare',true)::uuid);
    raise exception 'WRONG_LOCATION_MANAGER_AGGREGATE_ALLOWED';
  exception when others then
    if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if;
  end;
  select count(*) into v_named from public.location_interests
  where location_id=current_setting('test.loc_interest',true)::uuid;
  if v_named <> 0 then raise exception 'LOCAL_MANAGER_CAN_READ_NAMED_INTEREST_ROWS'; end if;
end $$;

do $$
begin
  perform public.set_location_state(current_setting('test.loc_interest',true)::uuid,'preparing','manager attempt','manager-state-attempt');
  raise exception 'LOCAL_MANAGER_GOVERNED_LOCATION_STATE';
exception when others then
  if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if;
end $$;

-- Active Local Manager assignment blocks Account closure.
do $$
declare v_result jsonb;
begin
  v_result := public.request_account_closure('manager-close-blocked');
  if (v_result->>'closed')::boolean then raise exception 'ACTIVE_MANAGER_ACCOUNT_CLOSED'; end if;
  if position('ACTIVE_LOCAL_MANAGER_ASSIGNMENT' in v_result::text)=0 then raise exception 'LOCAL_MANAGER_CLOSURE_BLOCKER_MISSING'; end if;
end $$;

-- Retired Location visibility is protected.
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',true);
do $$
declare v_count integer;
begin
  select count(*) into v_count from public.locations where id=current_setting('test.loc_retired',true)::uuid;
  if v_count <> 0 then raise exception 'ORDINARY_USER_SAW_RETIRED_LOCATION'; end if;
end $$;

reset role;
set local role anon;
do $$
declare v_retired integer; v_nonretired integer;
begin
  select count(*) into v_retired from public.locations where id=current_setting('test.loc_retired',true)::uuid;
  if v_retired <> 0 then raise exception 'ANON_SAW_RETIRED_LOCATION'; end if;
  select count(*) into v_nonretired from public.locations where id=current_setting('test.loc_interest',true)::uuid;
  if v_nonretired <> 1 then raise exception 'ANON_CANNOT_SEE_AVAILABLE_LOCATION'; end if;
  begin
    perform public.register_location_interest(current_setting('test.loc_interest',true)::uuid,'learn','anon-interest');
    raise exception 'ANON_PROTECTED_RPC_ALLOWED';
  exception when insufficient_privilege then null;
  end;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
do $$
declare v_count integer;
begin
  select count(*) into v_count from public.locations where id=current_setting('test.loc_retired',true)::uuid;
  if v_count <> 1 then raise exception 'PLATFORM_ADMIN_CANNOT_SEE_RETIRED_LOCATION'; end if;
end $$;

-- Ending staff assignment removes scope and closure blocker.
select public.end_location_staff_assignment(current_setting('test.assignment',true)::uuid,'rotation complete','end-manager-1');
select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',true);
do $$
begin
  if app_private.has_location_staff_scope(current_setting('test.loc_interest',true)::uuid,'local_manager') then
    raise exception 'ENDED_MANAGER_SCOPE_STILL_ACTIVE';
  end if;
end $$;

do $$
declare v_result jsonb;
begin
  v_result := public.request_account_closure('manager-close-after-end');
  if not (v_result->>'closed')::boolean then raise exception 'MANAGER_CLOSURE_STILL_BLOCKED:%', v_result; end if;
end $$;

reset role;
do $$
declare v_audit integer; v_idem integer;
begin
  select count(*) into v_audit from public.audit_log where location_id is not null;
  select count(*) into v_idem from public.idempotency_keys where command_name in (
    'create_location','set_location_state','set_selected_location','register_location_interest',
    'withdraw_location_interest','assign_local_manager','end_location_staff_assignment'
  );
  if v_audit < 1 then raise exception 'LOCATION_AUDIT_NOT_WRITTEN'; end if;
  if v_idem < 1 then raise exception 'LOCATION_IDEMPOTENCY_NOT_WRITTEN'; end if;
end $$;

rollback;
select 'LOCATIONS_RUNTIME_TESTS_PASS' as result;