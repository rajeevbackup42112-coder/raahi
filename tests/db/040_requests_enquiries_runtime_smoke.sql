-- Raahi Learning V1.2 — Learning Requests / Enquiries runtime smoke
-- Dev/disposable only. Entire suite rolls back.
-- Covers learner-side decision authority, public Request privacy, duplicate/material
-- edit rules, direct and Request-origin Enquiries, pending/active messaging,
-- Trial lifecycle, unrelated-account denial, Location persistence, pause-history
-- access and direct core-table write denial.

begin;

insert into auth.users(id,aud,role,email) values
('51111111-1111-1111-1111-111111111111','authenticated','authenticated','manager040@test.invalid'),
('52222222-2222-2222-2222-222222222222','authenticated','authenticated','learner040@test.invalid'),
('53333333-3333-3333-3333-333333333333','authenticated','authenticated','teacher040@test.invalid'),
('54444444-4444-4444-4444-444444444444','authenticated','authenticated','other040@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','51111111-1111-1111-1111-111111111111',true);
select set_config('test.manager',(public.bootstrap_account('Parent Manager')->>'account_id'),true);
select set_config('request.jwt.claim.sub','52222222-2222-2222-2222-222222222222',true);
select set_config('test.self',(public.bootstrap_account('Learner Self')->>'account_id'),true);
select set_config('request.jwt.claim.sub','53333333-3333-3333-3333-333333333333',true);
select set_config('test.teacher',(public.bootstrap_account('Teacher 040')->>'account_id'),true);
select set_config('request.jwt.claim.sub','54444444-4444-4444-4444-444444444444',true);
select set_config('test.other',(public.bootstrap_account('Unrelated 040')->>'account_id'),true);

reset role;
insert into public.account_capabilities(account_id,capability_code) values(current_setting('test.teacher')::uuid,'teach');
insert into public.locations(id,name,slug,state,country_code) values
('d1111111-1111-1111-1111-111111111111','Dhanbad 040','dhanbad-040','live','IN'),
('d2222222-2222-2222-2222-222222222222','Gomoh 040','gomoh-040','live','IN');

set local role authenticated;
select set_config('request.jwt.claim.sub','51111111-1111-1111-1111-111111111111',true);
select set_config('test.learner',(public.create_learner('Rahul 040','manage','none',null,'040-learner')->>'learner_id'),true);
select public.grant_learner_self_access(current_setting('test.learner')::uuid,current_setting('test.self')::uuid,'040-self-access');

select set_config('request.jwt.claim.sub','53333333-3333-3333-3333-333333333333',true);
select public.upsert_teacher_profile('Maths Teacher','Maths bio','10 years','visible','040-teacher-profile');
select set_config('test.option',(public.publish_teaching_option(null,'Class 8 Maths','Academics','Maths support','both','Dhanbad','₹1200/month',array['d1111111-1111-1111-1111-111111111111']::uuid[],'040-option')->>'teaching_option_id'),true);

select set_config('request.jwt.claim.sub','51111111-1111-1111-1111-111111111111',true);
select set_config('test.request',(public.post_learning_request(current_setting('test.learner')::uuid,'d1111111-1111-1111-1111-111111111111','Need Class 8 Maths','Academics','either','Private internal detail not for public','Weekday evenings','040-request')->>'learning_request_id'),true);

do $$ declare a uuid; begin
  a := (public.post_learning_request(current_setting('test.learner')::uuid,'d1111111-1111-1111-1111-111111111111','Need Class 8 Maths','Academics','either','Private internal detail not for public','Weekday evenings','040-request')->>'learning_request_id')::uuid;
  if a <> current_setting('test.request')::uuid then raise exception 'REQUEST_IDEMPOTENCY_FAILED'; end if;
end $$;

do $$ declare j jsonb; begin
  j:=public.get_learning_request_public(current_setting('test.request')::uuid);
  if j is null then raise exception 'REQUEST_NOT_PUBLIC'; end if;
  if j ? 'learner_id' or j ? 'learner_name' or j ? 'details' then raise exception 'REQUEST_PUBLIC_PRIVACY_LEAK:%',j; end if;
end $$;

do $$ begin
  perform public.post_learning_request(current_setting('test.learner')::uuid,'d1111111-1111-1111-1111-111111111111','Call 9876543210 for Maths','Academics','either',null,null,'040-bad-contact');
  raise exception 'PUBLIC_CONTACT_DATA_ALLOWED';
exception when others then if position('PUBLIC_REQUEST_CONTACT_DATA_NOT_ALLOWED' in sqlerrm)=0 then raise; end if; end $$;

do $$ begin
  perform public.update_learning_request(current_setting('test.request')::uuid,'Need Guitar','Music','either',null,'Weekday evenings','040-material-edit');
  raise exception 'MATERIAL_REQUEST_EDIT_ALLOWED';
exception when others then if position('MATERIAL_CHANGE_REQUIRES_NEW_REQUEST' in sqlerrm)=0 then raise; end if; end $$;

select set_config('request.jwt.claim.sub','52222222-2222-2222-2222-222222222222',true);
do $$ begin
  perform public.post_learning_request(current_setting('test.learner')::uuid,'d2222222-2222-2222-2222-222222222222','Need Science','Academics','either',null,null,'040-self-denied');
  raise exception 'SELF_FORMAL_DECISION_ALLOWED_WITH_MANAGER';
exception when others then if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if; end $$;

select set_config('request.jwt.claim.sub','51111111-1111-1111-1111-111111111111',true);
select set_config('test.enquiry',(public.send_enquiry(current_setting('test.learner')::uuid,current_setting('test.option')::uuid,'d1111111-1111-1111-1111-111111111111','Interested in this option','040-enquiry')->>'enquiry_id'),true);
do $$ begin
  perform public.send_enquiry_message(current_setting('test.enquiry')::uuid,'Free chat before engagement','040-pending-message');
  raise exception 'PENDING_FREE_MESSAGE_ALLOWED';
exception when others then if position('ENQUIRY_NOT_ACTIVE' in sqlerrm)=0 then raise; end if; end $$;

select set_config('request.jwt.claim.sub','54444444-4444-4444-4444-444444444444',true);
do $$ declare n int; begin select count(*) into n from public.enquiries where id=current_setting('test.enquiry')::uuid; if n<>0 then raise exception 'UNRELATED_ENQUIRY_READ_ALLOWED'; end if; end $$;
do $$ begin
  perform public.close_enquiry(current_setting('test.enquiry')::uuid,'other','040-other-close');
  raise exception 'UNRELATED_ENQUIRY_CLOSE_ALLOWED';
exception when others then if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if; end $$;

select set_config('request.jwt.claim.sub','53333333-3333-3333-3333-333333333333',true);
select public.engage_enquiry(current_setting('test.enquiry')::uuid,'040-engage');
select public.send_enquiry_message(current_setting('test.enquiry')::uuid,'Thanks, let us discuss','040-teacher-message');
select set_config('test.trial',(public.schedule_trial_event(current_setting('test.enquiry')::uuid,now()+interval '2 days','040-trial')->>'trial_event_id'),true);
select public.reschedule_trial_event(current_setting('test.trial')::uuid,now()+interval '3 days','040-trial-reschedule');

select set_config('request.jwt.claim.sub','51111111-1111-1111-1111-111111111111',true);
select public.send_enquiry_message(current_setting('test.enquiry')::uuid,'Confirmed','040-manager-message');
do $$ declare n int; begin select count(*) into n from public.enquiry_trial_events where id=current_setting('test.trial')::uuid; if n<>1 then raise exception 'TRIAL_NOT_VISIBLE_TO_LEARNER_SIDE'; end if; end $$;

select set_config('request.jwt.claim.sub','53333333-3333-3333-3333-333333333333',true);
select set_config('test.request_enquiry',(public.express_interest_in_request(current_setting('test.request')::uuid,null,'I can help with Maths','040-request-interest')->>'enquiry_id'),true);
select set_config('request.jwt.claim.sub','51111111-1111-1111-1111-111111111111',true);
select public.engage_enquiry(current_setting('test.request_enquiry')::uuid,'040-request-engage');

select public.close_learning_request(current_setting('test.request')::uuid,'found','040-request-close');
do $$ declare n int; begin
  select count(*) into n from public.enquiries where id in (current_setting('test.enquiry')::uuid,current_setting('test.request_enquiry')::uuid);
  if n<>2 then raise exception 'CLOSING_REQUEST_DESTROYED_ENQUIRY_HISTORY:%',n; end if;
  if public.get_learning_request_public(current_setting('test.request')::uuid) is not null then raise exception 'CLOSED_REQUEST_STILL_PUBLIC'; end if;
end $$;
select public.reopen_learning_request(current_setting('test.request')::uuid,'040-request-reopen');

select public.set_selected_location('d2222222-2222-2222-2222-222222222222','040-select-gomoh');
do $$ declare loc uuid; begin select location_id into loc from public.enquiries where id=current_setting('test.enquiry')::uuid; if loc<>'d1111111-1111-1111-1111-111111111111'::uuid then raise exception 'ENQUIRY_LOCATION_DRIFTED'; end if; end $$;

select public.pause_account('040-pause-manager');
do $$ declare n int; begin
  select count(*) into n from public.enquiries where id=current_setting('test.enquiry')::uuid;
  if n<>1 then raise exception 'PAUSED_MANAGER_LOST_ENQUIRY_HISTORY'; end if;
end $$;
do $$ begin
  perform public.send_enquiry_message(current_setting('test.enquiry')::uuid,'Should fail while paused','040-paused-message');
  raise exception 'PAUSED_MANAGER_MESSAGE_ALLOWED';
exception when others then if position('ACCOUNT_NOT_ACTIVE' in sqlerrm)=0 then raise; end if; end $$;

do $$ begin
  update public.enquiries set state='closed' where id=current_setting('test.enquiry')::uuid;
  raise exception 'DIRECT_ENQUIRY_WRITE_ALLOWED';
exception when insufficient_privilege then null; end $$;

rollback;
select 'REQUESTS_ENQUIRIES_RUNTIME_TESTS_PASS' as result;
