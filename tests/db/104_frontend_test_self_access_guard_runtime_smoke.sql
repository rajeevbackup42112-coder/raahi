-- Raahi Learning V1.2 — frontend Test self-access guard runtime smoke.
-- Management authority may see Attempt status/results, but never protected Test-taking definition.
-- Disposable dev suite; all fixtures roll back.

begin;
insert into auth.users(id,aud,role,email) values
('a4111111-1111-1111-1111-111111111111','authenticated','authenticated','frontend104-teacher@test.invalid'),
('a4222222-2222-2222-2222-222222222222','authenticated','authenticated','frontend104-self@test.invalid'),
('a4333333-3333-3333-3333-333333333333','authenticated','authenticated','frontend104-parent@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','a4111111-1111-1111-1111-111111111111',true);
select set_config('test.teacher',(public.bootstrap_account('Frontend Teacher 104')->>'account_id'),true);
select public.enable_teaching('104-enable-teaching');
select set_config('request.jwt.claim.sub','a4222222-2222-2222-2222-222222222222',true);
select set_config('test.self',(public.bootstrap_account('Frontend Self 104')->>'account_id'),true);
select set_config('request.jwt.claim.sub','a4333333-3333-3333-3333-333333333333',true);
select set_config('test.parent',(public.bootstrap_account('Frontend Parent 104')->>'account_id'),true);
select set_config('test.learner',(public.create_learner('Frontend Learner 104','manage','none',null,'104-learner')->>'learner_id'),true);
select public.grant_learner_self_access(current_setting('test.learner')::uuid,current_setting('test.self')::uuid,'104-self-access');
reset role;
insert into public.locations(id,name,slug,state,country_code) values
('a4000000-0000-0000-0000-000000000001','Frontend Location 104','frontend-location-104','live','IN');

set local role authenticated;
select set_config('request.jwt.claim.sub','a4111111-1111-1111-1111-111111111111',true);
select set_config('test.class',(public.create_class(null,current_setting('test.teacher')::uuid,'a4000000-0000-0000-0000-000000000001','Frontend Test Class 104','group',5,'104-class')->>'class_id'),true);
select public.activate_class(current_setting('test.class')::uuid,'104-activate');
reset role;
insert into public.class_memberships(class_id,learner_id,state) values(current_setting('test.class')::uuid,current_setting('test.learner')::uuid,'active');

set local role authenticated;
select set_config('request.jwt.claim.sub','a4111111-1111-1111-1111-111111111111',true);
select set_config('test.test',(public.create_test(current_setting('test.class')::uuid,'Frontend Test 104',null,now()-interval '1 minute',now()+interval '1 hour',600,'104-test')->>'test_id'),true);
select set_config('test.question',(public.add_test_question(current_setting('test.test')::uuid,1,'2 + 2?',1,'104-q')->>'question_id'),true);
select public.add_test_choice(current_setting('test.question')::uuid,1,'4',true,'104-c1');
select public.add_test_choice(current_setting('test.question')::uuid,2,'5',false,'104-c2');
select public.publish_test(current_setting('test.test')::uuid,'104-publish');

do $$ declare d jsonb; begin
  d:=public.get_test_definition(current_setting('test.test')::uuid,current_setting('test.learner')::uuid);
  if d is null then raise exception 'PROVIDER_TEST_DEFINITION_DENIED'; end if;
end $$;

select set_config('request.jwt.claim.sub','a4222222-2222-2222-2222-222222222222',true);
do $$ declare d jsonb; begin
  d:=public.get_test_definition(current_setting('test.test')::uuid,current_setting('test.learner')::uuid);
  if d is null then raise exception 'SELF_TEST_DEFINITION_DENIED'; end if;
  if d #>> '{questions,0,choices,0,is_correct}' is not null then raise exception 'ANSWER_KEY_LEAKED_PRE_RESULT'; end if;
end $$;
select set_config('test.attempt',(public.start_test(current_setting('test.test')::uuid,current_setting('test.learner')::uuid,'104-start')->>'attempt_id'),true);

select set_config('request.jwt.claim.sub','a4333333-3333-3333-3333-333333333333',true);
do $$ declare d jsonb; r jsonb; begin
  d:=public.get_test_definition(current_setting('test.test')::uuid,current_setting('test.learner')::uuid);
  if d is not null then raise exception 'GUARDIAN_TEST_DEFINITION_LEAK:%',d; end if;
  r:=public.get_test_attempt(current_setting('test.test')::uuid,current_setting('test.learner')::uuid);
  if r->>'state'<>'in_progress' then raise exception 'GUARDIAN_ATTEMPT_STATUS_MISSING:%',r; end if;
end $$;
do $$ begin
  perform public.start_test(current_setting('test.test')::uuid,current_setting('test.learner')::uuid,'104-parent-start');
  raise exception 'GUARDIAN_TEST_START_ALLOWED';
exception when others then if position('LEARNER_SELF_ACCESS_REQUIRED' in sqlerrm)=0 then raise; end if; end $$;

rollback;
select 'FRONTEND_TEST_SELF_ACCESS_GUARD_PASS' as result;
