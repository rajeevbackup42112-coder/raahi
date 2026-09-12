-- Raahi Learning V1.2 — Tests / Attempts runtime smoke
-- Dev/disposable only; entire suite rolls back.

begin;

insert into auth.users(id,aud,role,email) values
('71111111-1111-1111-1111-111111111111','authenticated','authenticated','test-teacher@test.invalid'),
('72222222-2222-2222-2222-222222222222','authenticated','authenticated','test-self@test.invalid'),
('73333333-3333-3333-3333-333333333333','authenticated','authenticated','test-manager@test.invalid'),
('74444444-4444-4444-4444-444444444444','authenticated','authenticated','test-outsider@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','71111111-1111-1111-1111-111111111111',true);
select set_config('test.teacher',(public.bootstrap_account('Test Teacher')->>'account_id'),true);
select set_config('request.jwt.claim.sub','72222222-2222-2222-2222-222222222222',true);
select set_config('test.self',(public.bootstrap_account('Rahul Self')->>'account_id'),true);
select set_config('request.jwt.claim.sub','73333333-3333-3333-3333-333333333333',true);
select set_config('test.manager',(public.bootstrap_account('Rahul Parent')->>'account_id'),true);
select set_config('request.jwt.claim.sub','74444444-4444-4444-4444-444444444444',true);
select set_config('test.outsider',(public.bootstrap_account('Outsider')->>'account_id'),true);

reset role;
insert into public.account_capabilities(account_id,capability_code) values(current_setting('test.teacher')::uuid,'teach');
insert into public.locations(id,name,slug,state,country_code) values('70000000-0000-0000-0000-000000000001','Dhanbad','tests-dhanbad','live','IN');
insert into public.learners(id,display_name,avatar_type,created_by_account_id) values('70000000-0000-0000-0000-000000000010','Rahul','none',current_setting('test.manager')::uuid);
insert into public.account_learner_access(account_id,learner_id,access_type,status) values
(current_setting('test.manager')::uuid,'70000000-0000-0000-0000-000000000010','manage','active'),
(current_setting('test.self')::uuid,'70000000-0000-0000-0000-000000000010','self','active');

set local role authenticated;
select set_config('request.jwt.claim.sub','71111111-1111-1111-1111-111111111111',true);
select set_config('test.class',(public.create_class(null,current_setting('test.teacher')::uuid,'70000000-0000-0000-0000-000000000001','Maths Test Class','group',10,'test-class')->>'class_id'),true);
select public.activate_class(current_setting('test.class')::uuid,'activate-test-class');

reset role;
insert into public.class_memberships(class_id,learner_id,state) values(current_setting('test.class')::uuid,'70000000-0000-0000-0000-000000000010','active');

set local role authenticated;
select set_config('request.jwt.claim.sub','71111111-1111-1111-1111-111111111111',true);
select set_config('test.test',(public.create_test(current_setting('test.class')::uuid,'Fractions Quiz','Choose the best answer',now()-interval '1 minute',now()+interval '1 hour',600,'create-test')->>'test_id'),true);
select set_config('test.question',(public.add_test_question(current_setting('test.test')::uuid,1,'What is 1/2 + 1/2?',5,'q1')->>'question_id'),true);
select set_config('test.choice1',(public.add_test_choice(current_setting('test.question')::uuid,1,'1',true,'c1')->>'choice_id'),true);
select set_config('test.choice2',(public.add_test_choice(current_setting('test.question')::uuid,2,'2',false,'c2')->>'choice_id'),true);
select public.publish_test(current_setting('test.test')::uuid,'publish-test');
select set_config('test.future',(public.create_test(current_setting('test.class')::uuid,'Tomorrow Quiz',null,now()+interval '1 day',now()+interval '2 days',null,'future-test')->>'test_id'),true);
select set_config('test.futureq',(public.add_test_question(current_setting('test.future')::uuid,1,'2+2?',1,'future-q')->>'question_id'),true);
select public.add_test_choice(current_setting('test.futureq')::uuid,1,'4',true,'future-c1');
select public.add_test_choice(current_setting('test.futureq')::uuid,2,'5',false,'future-c2');
select public.publish_test(current_setting('test.future')::uuid,'future-publish');

-- Management access does not grant Test-taking impersonation.
select set_config('request.jwt.claim.sub','73333333-3333-3333-3333-333333333333',true);
do $$ begin
  perform public.start_test(current_setting('test.test')::uuid,'70000000-0000-0000-0000-000000000010','manager-start');
  raise exception 'MANAGER_START_ALLOWED';
exception when others then if position('LEARNER_SELF_ACCESS_REQUIRED' in sqlerrm)=0 then raise; end if; end $$;

-- Learner self starts once; a retry/new key resumes the same logical Attempt.
select set_config('request.jwt.claim.sub','72222222-2222-2222-2222-222222222222',true);
select set_config('test.attempt',(public.start_test(current_setting('test.test')::uuid,'70000000-0000-0000-0000-000000000010','start-1')->>'attempt_id'),true);
do $$ declare a uuid; b uuid; begin
  a:=current_setting('test.attempt')::uuid;
  b:=(public.start_test(current_setting('test.test')::uuid,'70000000-0000-0000-0000-000000000010','start-2')->>'attempt_id')::uuid;
  if a<>b then raise exception 'SECOND_ATTEMPT_CREATED'; end if;
end $$;

do $$ begin
  perform public.start_test(current_setting('test.future')::uuid,'70000000-0000-0000-0000-000000000010','future-start');
  raise exception 'UPCOMING_TEST_STARTED';
exception when others then if position('TEST_NOT_OPEN_YET' in sqlerrm)=0 then raise; end if; end $$;

-- Correctness is not exposed to learner before released result; raw key table is unreadable.
do $$ declare d jsonb; begin
  d:=public.get_test_definition(current_setting('test.test')::uuid,'70000000-0000-0000-0000-000000000010');
  if d #>> '{questions,0,choices,0,is_correct}' is not null then raise exception 'KEY_LEAKED'; end if;
end $$;
do $$ begin
  perform 1 from public.test_choices limit 1;
  raise exception 'RAW_KEY_READ_ALLOWED';
exception when insufficient_privilege then null; end $$;

select public.save_test_answer(current_setting('test.attempt')::uuid,current_setting('test.question')::uuid,current_setting('test.choice2')::uuid,null,'save-1');
select public.submit_test(current_setting('test.attempt')::uuid,'submit-1');
select public.submit_test(current_setting('test.attempt')::uuid,'submit-2');

reset role;
do $$ declare n int; s text; begin
  select count(*),max(state) into n,s from public.test_attempts where test_id=current_setting('test.test')::uuid and learner_id='70000000-0000-0000-0000-000000000010';
  if n<>1 or s<>'submitted' then raise exception 'SUBMIT_IDEMPOTENCY_BAD:%/%',n,s; end if;
  if (select definition_locked_at from public.tests where id=current_setting('test.test')::uuid) is null then raise exception 'TEST_NOT_LOCKED'; end if;
end $$;
do $$ begin
  update public.test_questions set prompt='tampered' where id=current_setting('test.question')::uuid;
  raise exception 'LOCKED_EDIT_ALLOWED';
exception when others then if position('TEST_DEFINITION_LOCKED' in sqlerrm)=0 then raise; end if; end $$;

-- Teacher evaluates hidden result.
set local role authenticated;
select set_config('request.jwt.claim.sub','71111111-1111-1111-1111-111111111111',true);
select public.evaluate_test_attempt(current_setting('test.attempt')::uuid,'Good effort; check the fraction rule.','evaluate-1');

-- Manager sees evaluated state but not score/feedback while results are hidden.
select set_config('request.jwt.claim.sub','73333333-3333-3333-3333-333333333333',true);
do $$ declare r jsonb; begin
  r:=public.get_test_attempt(current_setting('test.test')::uuid,'70000000-0000-0000-0000-000000000010');
  if r->>'state'<>'evaluated' then raise exception 'STATUS_NOT_VISIBLE:%',r; end if;
  if r->>'score' is not null or r->>'teacher_feedback' is not null then raise exception 'HIDDEN_RESULT_LEAK:%',r; end if;
end $$;

-- Explicit answer-key correction recalculates evaluated result and keeps feedback.
select set_config('request.jwt.claim.sub','71111111-1111-1111-1111-111111111111',true);
select public.correct_answer_key(current_setting('test.question')::uuid,current_setting('test.choice2')::uuid,'Original key was wrong','correct-key');
do $$ declare r jsonb; begin
  r:=public.get_test_attempt(current_setting('test.test')::uuid,'70000000-0000-0000-0000-000000000010');
  if (r->>'score')::numeric<>5 then raise exception 'RECALC_BAD:%',r; end if;
  if r->>'teacher_feedback' is distinct from 'Good effort; check the fraction rule.' then raise exception 'FEEDBACK_LOST'; end if;
end $$;
select public.set_test_results_visibility(current_setting('test.test')::uuid,true,'release-results');

-- After release, guardian may see the released result projection but still cannot read
-- the protected Test definition/questions/answer key. Learner self retains that access.
select set_config('request.jwt.claim.sub','73333333-3333-3333-3333-333333333333',true);
do $$ declare r jsonb; d jsonb; begin
  r:=public.get_test_attempt(current_setting('test.test')::uuid,'70000000-0000-0000-0000-000000000010');
  if (r->>'score')::numeric<>5 or r->>'teacher_feedback' is null then raise exception 'RELEASE_BAD:%',r; end if;
  d:=public.get_test_definition(current_setting('test.test')::uuid,'70000000-0000-0000-0000-000000000010');
  if d is not null then raise exception 'GUARDIAN_TEST_DEFINITION_LEAK:%',d; end if;
end $$;

select set_config('request.jwt.claim.sub','72222222-2222-2222-2222-222222222222',true);
do $$ declare d jsonb; begin
  d:=public.get_test_definition(current_setting('test.test')::uuid,'70000000-0000-0000-0000-000000000010');
  if d #>> '{questions,0,choices,1,is_correct}' <> 'true' then raise exception 'CORRECTED_KEY_NOT_RELEASED_TO_SELF:%',d; end if;
end $$;

select set_config('request.jwt.claim.sub','74444444-4444-4444-4444-444444444444',true);
do $$ declare d jsonb; begin
  d:=public.get_test_definition(current_setting('test.test')::uuid,'70000000-0000-0000-0000-000000000010');
  if d is not null then raise exception 'OUTSIDER_TEST_READ_ALLOWED'; end if;
end $$;
do $$ begin
  insert into public.test_attempts(test_id,learner_id) values(current_setting('test.test')::uuid,'70000000-0000-0000-0000-000000000010');
  raise exception 'DIRECT_ATTEMPT_WRITE_ALLOWED';
exception when insufficient_privilege then null; end $$;

rollback;
select 'TESTS_ATTEMPTS_RUNTIME_TESTS_PASS' as result;
