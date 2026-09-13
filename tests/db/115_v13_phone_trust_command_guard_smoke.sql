-- Raahi Learning V1.3 — public/conditional phone-trust command guards
begin;

insert into auth.users(id,aud,role,email,phone,phone_confirmed_at) values
('b1150000-0000-0000-0000-000000000001','authenticated','authenticated','learner115@test.invalid','+919000001151',now()-interval '91 days'),
('b1150000-0000-0000-0000-000000000002','authenticated','authenticated','teacher115@test.invalid','+919000001152',now()-interval '91 days');
insert into public.locations(id,name,slug,region,state_or_province,country_code,state) values
('b1150000-0000-0000-0000-000000000100','Phone Guard 115','phone-guard-115','Dhanbad','Jharkhand','IN','live');

-- Learner-side public command: stale blocks new trust, fresh allows it.
set local role authenticated;
select set_config('request.jwt.claim.sub','b1150000-0000-0000-0000-000000000001',true);
select public.bootstrap_account('Phone Guard Learner 115');
do $$ declare j jsonb; begin
  j:=public.create_learner('Learner 115','self','none',null,'115-learner-create');
  perform set_config('app.test.learner115',j->>'learner_id',true);
end $$;
do $$ begin
  perform public.post_learning_request(current_setting('app.test.learner115')::uuid,'b1150000-0000-0000-0000-000000000100','Class 8 maths','Maths','either',null,'Evenings','115-request-stale');
  raise exception 'STALE_POST_LEARNING_REQUEST_ALLOWED';
exception when others then if position('PHONE_TRUST_REQUIRED' in sqlerrm)=0 then raise; end if; end $$;

reset role;
update auth.users set phone_confirmed_at=now() where id='b1150000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','b1150000-0000-0000-0000-000000000001',true);
do $$ declare j jsonb; begin
  j:=public.post_learning_request(current_setting('app.test.learner115')::uuid,'b1150000-0000-0000-0000-000000000100','Class 8 maths','Maths','either',null,'Evenings','115-request-fresh');
  perform set_config('app.test.request115',j->>'learning_request_id',true);
end $$;

-- A completed idempotent retry remains retrievable after trust later becomes stale.
reset role;
update auth.users set phone_confirmed_at=now()-interval '91 days' where id='b1150000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','b1150000-0000-0000-0000-000000000001',true);
do $$ declare j jsonb; begin
  j:=public.post_learning_request(current_setting('app.test.learner115')::uuid,'b1150000-0000-0000-0000-000000000100','Class 8 maths','Maths','either',null,'Evenings','115-request-fresh');
  if (j->>'learning_request_id')::uuid<>current_setting('app.test.request115')::uuid then raise exception 'STALE_CACHED_RETRY_BAD:%',j; end if;
end $$;

-- Closing is de-escalating and stays available; reopening creates new public trust.
do $$ declare j jsonb; begin
  j:=public.close_learning_request(current_setting('app.test.request115')::uuid,'plans_changed','115-close-stale');
  if j->>'state'<>'closed' then raise exception 'STALE_CLOSE_BAD:%',j; end if;
end $$;
do $$ begin
  perform public.reopen_learning_request(current_setting('app.test.request115')::uuid,'115-reopen-stale');
  raise exception 'STALE_REOPEN_ALLOWED';
exception when others then if position('PHONE_TRUST_REQUIRED' in sqlerrm)=0 then raise; end if; end $$;
reset role;
update auth.users set phone_confirmed_at=now() where id='b1150000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','b1150000-0000-0000-0000-000000000001',true);
select public.reopen_learning_request(current_setting('app.test.request115')::uuid,'115-reopen-fresh');

-- Teacher conditional paths: enable/public visibility require fresh trust.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','b1150000-0000-0000-0000-000000000002',true);
select public.bootstrap_account('Phone Guard Teacher 115');
do $$ begin
  perform public.enable_teaching('115-teach-stale');
  raise exception 'STALE_ENABLE_TEACHING_ALLOWED';
exception when others then if position('PHONE_TRUST_REQUIRED' in sqlerrm)=0 then raise; end if; end $$;
reset role;
update auth.users set phone_confirmed_at=now() where id='b1150000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','b1150000-0000-0000-0000-000000000002',true);
select public.enable_teaching('115-teach-fresh');

reset role;
update auth.users set phone_confirmed_at=now()-interval '91 days' where id='b1150000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','b1150000-0000-0000-0000-000000000002',true);
select public.upsert_teacher_profile('Maths teacher','Bio','Experience','hidden','115-profile-hidden-stale');
do $$ begin
  perform public.upsert_teacher_profile('Maths teacher','Bio','Experience','visible','115-profile-visible-stale');
  raise exception 'STALE_VISIBLE_PROFILE_ALLOWED';
exception when others then if position('PHONE_TRUST_REQUIRED' in sqlerrm)=0 then raise; end if; end $$;

reset role;
update auth.users set phone_confirmed_at=now() where id='b1150000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','b1150000-0000-0000-0000-000000000002',true);
select public.upsert_teacher_profile('Maths teacher','Bio','Experience','visible','115-profile-visible-fresh');
do $$ declare j jsonb; begin
  j:=public.publish_teaching_option(null,'Class 8 Maths','Maths','Strong foundations','both','Dhanbad','₹2000/month',array['b1150000-0000-0000-0000-000000000100'::uuid],'115-option-publish');
  perform set_config('app.test.option115',j->>'teaching_option_id',true);
end $$;

-- Stopping acquisition stays available while stale; restarting is gated.
reset role;
update auth.users set phone_confirmed_at=now()-interval '91 days' where id='b1150000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','b1150000-0000-0000-0000-000000000002',true);
select public.set_teaching_availability(current_setting('app.test.option115')::uuid,'not_taking_new_learners','115-option-stop-stale');
do $$ begin
  perform public.set_teaching_availability(current_setting('app.test.option115')::uuid,'taking_new_learners','115-option-start-stale');
  raise exception 'STALE_START_TAKING_ALLOWED';
exception when others then if position('PHONE_TRUST_REQUIRED' in sqlerrm)=0 then raise; end if; end $$;
reset role;
update auth.users set phone_confirmed_at=now() where id='b1150000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','b1150000-0000-0000-0000-000000000002',true);
select public.set_teaching_availability(current_setting('app.test.option115')::uuid,'taking_new_learners','115-option-start-fresh');

rollback;
select 'V13_PHONE_TRUST_COMMAND_GUARDS_PASS' as result;
