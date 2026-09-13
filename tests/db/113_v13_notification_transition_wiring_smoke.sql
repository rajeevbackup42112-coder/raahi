-- Raahi Learning V1.3 — derived notification transition wiring smoke
-- Dev/disposable only. Entire suite rolls back.

begin;

insert into auth.users(id,aud,role,email) values
('d1311111-1111-1111-1111-111111111111','authenticated','authenticated','teacher-113@test.invalid'),
('d1322222-2222-2222-2222-222222222222','authenticated','authenticated','parent-113@test.invalid'),
('d1333333-3333-3333-3333-333333333333','authenticated','authenticated','self-113@test.invalid'),
('d1344444-4444-4444-4444-444444444444','authenticated','authenticated','outsider-113@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','d1311111-1111-1111-1111-111111111111',true);
select set_config('t.teacher',(public.bootstrap_account('Teacher 113')->>'account_id'),true);
select set_config('request.jwt.claim.sub','d1322222-2222-2222-2222-222222222222',true);
select set_config('t.parent',(public.bootstrap_account('Parent 113')->>'account_id'),true);
select set_config('request.jwt.claim.sub','d1333333-3333-3333-3333-333333333333',true);
select set_config('t.self',(public.bootstrap_account('Self 113')->>'account_id'),true);
select set_config('request.jwt.claim.sub','d1344444-4444-4444-4444-444444444444',true);
select set_config('t.outsider',(public.bootstrap_account('Outsider 113')->>'account_id'),true);

reset role;
insert into public.locations(id,name,slug,state,country_code)
values('d1300000-0000-0000-0000-000000000001','Dhanbad 113','dhanbad-113','live','IN');

-- Learner identity: parent is the formal decision account; self account has learning access.
set local role authenticated;
select set_config('request.jwt.claim.sub','d1322222-2222-2222-2222-222222222222',true);
select set_config('t.learner',(public.create_learner('Learner 113','manage','none',null,'113-learner')->>'learner_id'),true);
select public.grant_learner_self_access(current_setting('t.learner')::uuid,current_setting('t.self')::uuid,'113-self-access');

-- Independent teacher discovery setup.
select set_config('request.jwt.claim.sub','d1311111-1111-1111-1111-111111111111',true);
select public.enable_teaching('113-enable-teach');
select public.upsert_teacher_profile('Maths Teacher','Maths support','10 years','visible','113-profile');
select set_config('t.option',(public.publish_teaching_option(
  null,'Class 8 Maths','Academics','Maths support','both','Dhanbad','₹1200/month',
  array['d1300000-0000-0000-0000-000000000001']::uuid[],'113-option'
)->>'teaching_option_id'),true);

-- Direct Enquiry: provider gets a derived alert.
select set_config('request.jwt.claim.sub','d1322222-2222-2222-2222-222222222222',true);
select set_config('t.enquiry',(public.send_enquiry(
  current_setting('t.learner')::uuid,current_setting('t.option')::uuid,
  'd1300000-0000-0000-0000-000000000001','Interested in Maths','113-enquiry'
)->>'enquiry_id'),true);
select set_config('request.jwt.claim.sub','d1311111-1111-1111-1111-111111111111',true);
do $$ declare n int; begin
  select count(*) into n from public.get_my_notifications(100) x
  where x->>'notification_type'='enquiry_received' and (x->>'source_id')::uuid=current_setting('t.enquiry')::uuid;
  if n<>1 then raise exception 'ENQUIRY_RECEIVED_NOTIFICATION_WRONG:%',n; end if;
end $$;

-- Engage: formal learner decision account is notified, but self account is not used for the decision alert.
select public.engage_enquiry(current_setting('t.enquiry')::uuid,'113-engage');
select set_config('request.jwt.claim.sub','d1322222-2222-2222-2222-222222222222',true);
do $$ declare n int; begin
  select count(*) into n from public.get_my_notifications(100) x
  where x->>'notification_type'='enquiry_engaged' and (x->>'source_id')::uuid=current_setting('t.enquiry')::uuid;
  if n<>1 then raise exception 'PARENT_ENQUIRY_ENGAGED_NOTIFICATION_WRONG:%',n; end if;
end $$;
select set_config('request.jwt.claim.sub','d1333333-3333-3333-3333-333333333333',true);
do $$ declare n int; begin
  select count(*) into n from public.get_my_notifications(100) x
  where x->>'notification_type'='enquiry_engaged' and (x->>'source_id')::uuid=current_setting('t.enquiry')::uuid;
  if n<>0 then raise exception 'SELF_RECEIVED_FORMAL_DECISION_ALERT:%',n; end if;
end $$;

-- Provider message: both active learner-side accounts receive a generic message alert; body is not copied.
select set_config('request.jwt.claim.sub','d1311111-1111-1111-1111-111111111111',true);
select public.send_enquiry_message(current_setting('t.enquiry')::uuid,'Private Enquiry content 113','113-provider-msg');
select set_config('request.jwt.claim.sub','d1322222-2222-2222-2222-222222222222',true);
do $$ declare n int; leaked int; begin
  select count(*) into n from public.get_my_notifications(100) x
  where x->>'notification_type'='enquiry_message' and (x->>'source_id')::uuid=current_setting('t.enquiry')::uuid;
  select count(*) into leaked from public.get_my_notifications(100) x
  where coalesce(x->>'body','') like '%Private Enquiry content 113%';
  if n<>1 or leaked<>0 then raise exception 'PARENT_ENQUIRY_MESSAGE_NOTIFICATION_BAD:n=% leaked=%',n,leaked; end if;
end $$;
select set_config('request.jwt.claim.sub','d1333333-3333-3333-3333-333333333333',true);
do $$ declare n int; begin
  select count(*) into n from public.get_my_notifications(100) x
  where x->>'notification_type'='enquiry_message' and (x->>'source_id')::uuid=current_setting('t.enquiry')::uuid;
  if n<>1 then raise exception 'SELF_ENQUIRY_MESSAGE_NOTIFICATION_WRONG:%',n; end if;
end $$;

-- Learner-side message: provider gets the alert; sibling learner-side account is not notified about its own side's send.
select set_config('request.jwt.claim.sub','d1322222-2222-2222-2222-222222222222',true);
select public.send_enquiry_message(current_setting('t.enquiry')::uuid,'Parent reply 113','113-parent-msg');
select set_config('request.jwt.claim.sub','d1311111-1111-1111-1111-111111111111',true);
do $$ declare n int; begin
  select count(*) into n from public.get_my_notifications(100) x
  where x->>'notification_type'='enquiry_message' and (x->>'source_id')::uuid=current_setting('t.enquiry')::uuid;
  if n<>1 then raise exception 'TEACHER_ENQUIRY_MESSAGE_NOTIFICATION_WRONG:%',n; end if;
end $$;

-- Class invitation path.
select set_config('t.class',(public.create_class(
  null,current_setting('t.teacher')::uuid,'d1300000-0000-0000-0000-000000000001',
  'Maths 113','one_to_one',1,'113-class'
)->>'class_id'),true);
select public.activate_class(current_setting('t.class')::uuid,'113-activate-class');
select set_config('t.inv',(public.send_class_invitation(
  current_setting('t.class')::uuid,current_setting('t.enquiry')::uuid,'₹1200/month','113-invite'
)->>'invitation_id'),true);
select set_config('request.jwt.claim.sub','d1322222-2222-2222-2222-222222222222',true);
do $$ declare n int; begin
  select count(*) into n from public.get_my_notifications(100) x
  where x->>'notification_type'='class_invitation' and (x->>'source_id')::uuid=current_setting('t.inv')::uuid;
  if n<>1 then raise exception 'PARENT_CLASS_INVITE_NOTIFICATION_WRONG:%',n; end if;
end $$;
select set_config('request.jwt.claim.sub','d1333333-3333-3333-3333-333333333333',true);
do $$ declare n int; begin
  select count(*) into n from public.get_my_notifications(100) x
  where x->>'notification_type'='class_invitation' and (x->>'source_id')::uuid=current_setting('t.inv')::uuid;
  if n<>0 then raise exception 'SELF_RECEIVED_CLASS_DECISION_ALERT:%',n; end if;
end $$;

select set_config('request.jwt.claim.sub','d1322222-2222-2222-2222-222222222222',true);
select public.accept_class_invitation(current_setting('t.inv')::uuid,'113-accept-invite');
select set_config('request.jwt.claim.sub','d1311111-1111-1111-1111-111111111111',true);
do $$ declare n int; begin
  select count(*) into n from public.get_my_notifications(100) x
  where x->>'notification_type'='class_invitation_accepted' and (x->>'source_id')::uuid=current_setting('t.inv')::uuid;
  if n<>1 then raise exception 'TEACHER_ACCEPTED_INVITE_NOTIFICATION_WRONG:%',n; end if;
end $$;

-- Class messages: provider -> both learner-side accounts; learner-side -> provider.
select public.send_class_learner_message(current_setting('t.class')::uuid,current_setting('t.learner')::uuid,'Private Class content 113','113-class-provider-msg');
select set_config('request.jwt.claim.sub','d1322222-2222-2222-2222-222222222222',true);
do $$ declare n int; leaked int; begin
  select count(*) into n from public.get_my_notifications(100) x where x->>'notification_type'='class_message' and (x->>'source_id')::uuid=current_setting('t.class')::uuid;
  select count(*) into leaked from public.get_my_notifications(100) x where coalesce(x->>'body','') like '%Private Class content 113%';
  if n<>1 or leaked<>0 then raise exception 'PARENT_CLASS_MESSAGE_NOTIFICATION_BAD:n=% leaked=%',n,leaked; end if;
end $$;
select set_config('request.jwt.claim.sub','d1333333-3333-3333-3333-333333333333',true);
do $$ declare n int; begin
  select count(*) into n from public.get_my_notifications(100) x where x->>'notification_type'='class_message' and (x->>'source_id')::uuid=current_setting('t.class')::uuid;
  if n<>1 then raise exception 'SELF_CLASS_MESSAGE_NOTIFICATION_WRONG:%',n; end if;
end $$;
select public.send_class_learner_message(current_setting('t.class')::uuid,current_setting('t.learner')::uuid,'Self reply 113','113-class-self-msg');
select set_config('request.jwt.claim.sub','d1311111-1111-1111-1111-111111111111',true);
do $$ declare n int; begin
  select count(*) into n from public.get_my_notifications(100) x where x->>'notification_type'='class_message' and (x->>'source_id')::uuid=current_setting('t.class')::uuid;
  if n<>1 then raise exception 'TEACHER_CLASS_MESSAGE_NOTIFICATION_WRONG:%',n; end if;
end $$;

-- Activity publication notifies both learner-side accounts.
select set_config('t.activity',(public.create_activity(
  current_setting('t.class')::uuid,'assignment','Homework 113','Solve the worksheet',now()+interval '2 days',false,'113-activity'
)->>'activity_id'),true);
select public.publish_activity(current_setting('t.activity')::uuid,'113-publish-activity');
select set_config('request.jwt.claim.sub','d1322222-2222-2222-2222-222222222222',true);
do $$ declare n int; begin select count(*) into n from public.get_my_notifications(100) x where x->>'notification_type'='activity_published' and (x->>'source_id')::uuid=current_setting('t.activity')::uuid; if n<>1 then raise exception 'PARENT_ACTIVITY_NOTIFICATION_WRONG:%',n; end if; end $$;
select set_config('request.jwt.claim.sub','d1333333-3333-3333-3333-333333333333',true);
do $$ declare n int; begin select count(*) into n from public.get_my_notifications(100) x where x->>'notification_type'='activity_published' and (x->>'source_id')::uuid=current_setting('t.activity')::uuid; if n<>1 then raise exception 'SELF_ACTIVITY_NOTIFICATION_WRONG:%',n; end if; end $$;

-- Test publication + hidden evaluation + release results.
select set_config('request.jwt.claim.sub','d1311111-1111-1111-1111-111111111111',true);
select set_config('t.test',(public.create_test(current_setting('t.class')::uuid,'Quiz 113','Choose one',now()-interval '1 minute',now()+interval '1 hour',600,'113-test')->>'test_id'),true);
select set_config('t.question',(public.add_test_question(current_setting('t.test')::uuid,1,'2 + 2 = ?',5,'113-q')->>'question_id'),true);
select set_config('t.correct',(public.add_test_choice(current_setting('t.question')::uuid,1,'4',true,'113-c1')->>'choice_id'),true);
select public.add_test_choice(current_setting('t.question')::uuid,2,'5',false,'113-c2');
select public.publish_test(current_setting('t.test')::uuid,'113-publish-test');
select set_config('request.jwt.claim.sub','d1322222-2222-2222-2222-222222222222',true);
do $$ declare n int; begin select count(*) into n from public.get_my_notifications(100) x where x->>'notification_type'='test_published' and (x->>'source_id')::uuid=current_setting('t.test')::uuid; if n<>1 then raise exception 'PARENT_TEST_NOTIFICATION_WRONG:%',n; end if; end $$;
select set_config('request.jwt.claim.sub','d1333333-3333-3333-3333-333333333333',true);
do $$ declare n int; begin select count(*) into n from public.get_my_notifications(100) x where x->>'notification_type'='test_published' and (x->>'source_id')::uuid=current_setting('t.test')::uuid; if n<>1 then raise exception 'SELF_TEST_NOTIFICATION_WRONG:%',n; end if; end $$;
select set_config('t.attempt',(public.start_test(current_setting('t.test')::uuid,current_setting('t.learner')::uuid,'113-start')->>'attempt_id'),true);
select public.save_test_answer(current_setting('t.attempt')::uuid,current_setting('t.question')::uuid,current_setting('t.correct')::uuid,null,'113-save');
select public.submit_test(current_setting('t.attempt')::uuid,'113-submit');
select set_config('request.jwt.claim.sub','d1311111-1111-1111-1111-111111111111',true);
select public.evaluate_test_attempt(current_setting('t.attempt')::uuid,'Well done','113-evaluate');

-- Results hidden: no result alert yet.
select set_config('request.jwt.claim.sub','d1322222-2222-2222-2222-222222222222',true);
do $$ declare n int; begin select count(*) into n from public.get_my_notifications(100) x where x->>'notification_type'='test_results_available' and (x->>'source_id')::uuid=current_setting('t.test')::uuid; if n<>0 then raise exception 'HIDDEN_RESULT_NOTIFICATION_SENT:%',n; end if; end $$;

select set_config('request.jwt.claim.sub','d1311111-1111-1111-1111-111111111111',true);
select public.set_test_results_visibility(current_setting('t.test')::uuid,true,'113-release-results');
select set_config('request.jwt.claim.sub','d1322222-2222-2222-2222-222222222222',true);
do $$ declare n int; begin select count(*) into n from public.get_my_notifications(100) x where x->>'notification_type'='test_results_available' and (x->>'source_id')::uuid=current_setting('t.test')::uuid; if n<>1 then raise exception 'PARENT_RESULT_NOTIFICATION_WRONG:%',n; end if; end $$;
select set_config('request.jwt.claim.sub','d1333333-3333-3333-3333-333333333333',true);
do $$ declare n int; begin select count(*) into n from public.get_my_notifications(100) x where x->>'notification_type'='test_results_available' and (x->>'source_id')::uuid=current_setting('t.test')::uuid; if n<>1 then raise exception 'SELF_RESULT_NOTIFICATION_WRONG:%',n; end if; end $$;

-- Unrelated account receives nothing, and client roles cannot manufacture notifications.
select set_config('request.jwt.claim.sub','d1344444-4444-4444-4444-444444444444',true);
do $$ declare n int; begin select count(*) into n from public.get_my_notifications(100); if n<>0 then raise exception 'OUTSIDER_NOTIFICATION_LEAK:%',n; end if; end $$;
do $$ begin
  insert into public.notifications(recipient_account_id,notification_type,title) values(current_setting('t.outsider')::uuid,'fake','Fake');
  raise exception 'CLIENT_DIRECT_NOTIFICATION_INSERT_ALLOWED';
exception when insufficient_privilege then null; end $$;

rollback;
select 'V13_NOTIFICATION_TRANSITION_WIRING_PASS' as result;
