-- Raahi Learning V1.2 — limited guardian Test oversight runtime smoke.
-- Guardian/manager can see safe Test/Attempt status and released result only.
-- Protected Test definition and Attempt detail remain learner-self/provider only.
-- Disposable dev suite; all fixtures roll back.

begin;
insert into auth.users(id,aud,role,email) values
('a7111111-1111-1111-1111-111111111111','authenticated','authenticated','frontend107-teacher@test.invalid'),
('a7222222-2222-2222-2222-222222222222','authenticated','authenticated','frontend107-self@test.invalid'),
('a7333333-3333-3333-3333-333333333333','authenticated','authenticated','frontend107-parent@test.invalid'),
('a7444444-4444-4444-4444-444444444444','authenticated','authenticated','frontend107-outsider@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','a7111111-1111-1111-1111-111111111111',true);
select set_config('test.teacher',(public.bootstrap_account('Frontend Teacher 107')->>'account_id'),true);
select public.enable_teaching('107-enable');
select set_config('request.jwt.claim.sub','a7222222-2222-2222-2222-222222222222',true);
select set_config('test.self',(public.bootstrap_account('Frontend Self 107')->>'account_id'),true);
select set_config('request.jwt.claim.sub','a7333333-3333-3333-3333-333333333333',true);
select set_config('test.parent',(public.bootstrap_account('Frontend Parent 107')->>'account_id'),true);
select set_config('test.learner',(public.create_learner('Frontend Learner 107','manage','none',null,'107-learner')->>'learner_id'),true);
select public.grant_learner_self_access(current_setting('test.learner')::uuid,current_setting('test.self')::uuid,'107-self-access');
select set_config('request.jwt.claim.sub','a7444444-4444-4444-4444-444444444444',true);
select public.bootstrap_account('Frontend Outsider 107');
reset role;
insert into public.locations(id,name,slug,state,country_code) values('a7000000-0000-0000-0000-000000000001','Frontend Location 107','frontend-location-107','live','IN');

set local role authenticated;
select set_config('request.jwt.claim.sub','a7111111-1111-1111-1111-111111111111',true);
select set_config('test.class',(public.create_class(null,current_setting('test.teacher')::uuid,'a7000000-0000-0000-0000-000000000001','Frontend Class 107','group',5,'107-class')->>'class_id'),true);
select public.activate_class(current_setting('test.class')::uuid,'107-activate');
reset role;
insert into public.class_memberships(class_id,learner_id,state) values(current_setting('test.class')::uuid,current_setting('test.learner')::uuid,'active');

set local role authenticated;
select set_config('request.jwt.claim.sub','a7111111-1111-1111-1111-111111111111',true);
select set_config('test.test',(public.create_test(current_setting('test.class')::uuid,'Guardian Oversight 107',null,now()-interval '1 minute',now()+interval '1 hour',1800,'107-test')->>'test_id'),true);
select set_config('test.question',(public.add_test_question(current_setting('test.test')::uuid,1,'Secret question?',2,'107-q')->>'question_id'),true);
select set_config('test.correct',(public.add_test_choice(current_setting('test.question')::uuid,1,'Correct',true,'107-c1')->>'choice_id'),true);
select public.add_test_choice(current_setting('test.question')::uuid,2,'Wrong',false,'107-c2');
select public.publish_test(current_setting('test.test')::uuid,'107-publish');

select set_config('request.jwt.claim.sub','a7333333-3333-3333-3333-333333333333',true);
do $$ declare o jsonb; d jsonb; begin
  o:=public.get_test_oversight(current_setting('test.test')::uuid,current_setting('test.learner')::uuid);
  if o->>'display_state'<>'available' or o->>'attempt_state' is not null then raise exception 'GUARDIAN_PRESTART_OVERSIGHT_BAD:%',o; end if;
  d:=public.get_test_definition(current_setting('test.test')::uuid,current_setting('test.learner')::uuid);
  if d is not null then raise exception 'GUARDIAN_DEFINITION_LEAK_PRESTART:%',d; end if;
end $$;

select set_config('request.jwt.claim.sub','a7222222-2222-2222-2222-222222222222',true);
select set_config('test.attempt',(public.start_test(current_setting('test.test')::uuid,current_setting('test.learner')::uuid,'107-start')->>'attempt_id'),true);
select public.save_test_answer(current_setting('test.attempt')::uuid,current_setting('test.question')::uuid,current_setting('test.correct')::uuid,null,'107-save');
select public.submit_test(current_setting('test.attempt')::uuid,'107-submit');

select set_config('request.jwt.claim.sub','a7333333-3333-3333-3333-333333333333',true);
do $$ declare o jsonb; a jsonb; begin
  o:=public.get_test_oversight(current_setting('test.test')::uuid,current_setting('test.learner')::uuid);
  if o->>'attempt_state'<>'submitted' or o->>'score' is not null or o->>'teacher_feedback' is not null then raise exception 'GUARDIAN_SUBMITTED_OVERSIGHT_BAD:%',o; end if;
  a:=public.get_test_attempt(current_setting('test.test')::uuid,current_setting('test.learner')::uuid);
  if a is not null then raise exception 'GUARDIAN_ATTEMPT_DETAIL_LEAK:%',a; end if;
end $$;

select set_config('request.jwt.claim.sub','a7111111-1111-1111-1111-111111111111',true);
select public.evaluate_test_attempt(current_setting('test.attempt')::uuid,'Guardian-visible after release','107-evaluate');
select public.set_test_results_visibility(current_setting('test.test')::uuid,true,'107-release');

select set_config('request.jwt.claim.sub','a7333333-3333-3333-3333-333333333333',true);
do $$ declare o jsonb; d jsonb; begin
  o:=public.get_test_oversight(current_setting('test.test')::uuid,current_setting('test.learner')::uuid);
  if o->>'attempt_state'<>'evaluated' or (o->>'score')::numeric<>2 or o->>'teacher_feedback'<>'Guardian-visible after release' then raise exception 'GUARDIAN_RELEASED_OVERSIGHT_BAD:%',o; end if;
  d:=public.get_test_definition(current_setting('test.test')::uuid,current_setting('test.learner')::uuid);
  if d is not null then raise exception 'GUARDIAN_DEFINITION_LEAK_AFTER_RELEASE:%',d; end if;
end $$;

select set_config('request.jwt.claim.sub','a7444444-4444-4444-4444-444444444444',true);
do $$ declare o jsonb; begin
  o:=public.get_test_oversight(current_setting('test.test')::uuid,current_setting('test.learner')::uuid);
  if o is not null then raise exception 'OUTSIDER_OVERSIGHT_ALLOWED:%',o; end if;
end $$;

rollback;
select 'FRONTEND_TEST_OVERSIGHT_PROJECTION_PASS' as result;
