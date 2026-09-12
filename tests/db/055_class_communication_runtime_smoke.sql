-- Raahi Learning V1.2 — Class communication runtime smoke
-- Dev/disposable only. Entire suite rolls back.
-- Covers offline-origin Class thread without fake Enquiry, guardian/self visibility,
-- learner vs teacher posting authority, restrictions, previous-manager revocation,
-- paused teacher history, learner-side transfer authority, transferred source
-- read-only history, copied UUID denial and direct-write denial.

begin;

insert into auth.users(id,aud,role,email) values
('71111111-1111-1111-1111-111111111111','authenticated','authenticated','parent055@test.invalid'),
('72222222-2222-2222-2222-222222222222','authenticated','authenticated','self055@test.invalid'),
('73333333-3333-3333-3333-333333333333','authenticated','authenticated','teacher055@test.invalid'),
('74444444-4444-4444-4444-444444444444','authenticated','authenticated','other055@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','71111111-1111-1111-1111-111111111111',true);
select set_config('test.parent',(public.bootstrap_account('Parent 055')->>'account_id'),true);
select set_config('request.jwt.claim.sub','72222222-2222-2222-2222-222222222222',true);
select set_config('test.self',(public.bootstrap_account('Learner Self 055')->>'account_id'),true);
select set_config('request.jwt.claim.sub','73333333-3333-3333-3333-333333333333',true);
select set_config('test.teacher',(public.bootstrap_account('Teacher 055')->>'account_id'),true);
select set_config('request.jwt.claim.sub','74444444-4444-4444-4444-444444444444',true);
select set_config('test.other',(public.bootstrap_account('Other 055')->>'account_id'),true);
reset role;
insert into public.account_capabilities(account_id,capability_code) values(current_setting('test.teacher')::uuid,'teach');
insert into public.locations(id,name,slug,state,country_code) values('f1111111-1111-1111-1111-111111111111','Dhanbad 055','dhanbad-055','live','IN');

set local role authenticated;
select set_config('request.jwt.claim.sub','71111111-1111-1111-1111-111111111111',true);
select set_config('test.learner',(public.create_learner('Rahul 055','manage','none',null,'055-learner')->>'learner_id'),true);
select public.grant_learner_self_access(current_setting('test.learner')::uuid,current_setting('test.self')::uuid,'055-self-access');
select set_config('test.share',(public.create_learner_share_code(current_setting('test.learner')::uuid,'055-share')->>'share_code'),true);

select set_config('request.jwt.claim.sub','73333333-3333-3333-3333-333333333333',true);
select public.upsert_teacher_profile('Teacher','Bio','Experience','visible','055-profile');
select set_config('test.class',(public.create_class(null,current_setting('test.teacher')::uuid,'f1111111-1111-1111-1111-111111111111','Offline-origin Class','group',3,'055-class')->>'class_id'),true);
select public.activate_class(current_setting('test.class')::uuid,'055-activate');
select set_config('test.inv',(public.send_class_invitation_with_share_code(current_setting('test.class')::uuid,current_setting('test.share'),null,'055-invite')->>'invitation_id'),true);

select set_config('request.jwt.claim.sub','71111111-1111-1111-1111-111111111111',true);
select set_config('test.membership',(public.accept_class_invitation(current_setting('test.inv')::uuid,'055-accept')->>'membership_id'),true);

select set_config('request.jwt.claim.sub','73333333-3333-3333-3333-333333333333',true);
select set_config('test.announcement',(public.publish_class_post(current_setting('test.class')::uuid,null,'announcement','Saturday starts at 4:30 PM','important',false,'055-announcement')->>'class_post_id'),true);
select set_config('test.thread',(public.send_class_learner_message(current_setting('test.class')::uuid,current_setting('test.learner')::uuid,'Bring the worksheet on Saturday.','055-thread-teacher')->>'thread_id'),true);
do $$ declare n int; begin select count(*) into n from public.enquiries where learner_id=current_setting('test.learner')::uuid and provider_account_id=current_setting('test.teacher')::uuid; if n<>0 then raise exception 'FAKE_ENQUIRY_CREATED_FOR_CLASS_THREAD'; end if; end $$;

select set_config('request.jwt.claim.sub','71111111-1111-1111-1111-111111111111',true);
do $$ declare n int; begin
  select count(*) into n from public.class_learner_threads where id=current_setting('test.thread')::uuid; if n<>1 then raise exception 'GUARDIAN_THREAD_NOT_VISIBLE'; end if;
  select count(*) into n from public.class_posts where id=current_setting('test.announcement')::uuid; if n<>1 then raise exception 'CLASS_POST_NOT_VISIBLE'; end if;
end $$;
select public.send_class_learner_message(current_setting('test.class')::uuid,current_setting('test.learner')::uuid,'Thanks, we will bring it.','055-thread-parent');

select set_config('request.jwt.claim.sub','72222222-2222-2222-2222-222222222222',true);
select set_config('test.question',(public.publish_class_post(current_setting('test.class')::uuid,current_setting('test.learner')::uuid,'question','Can you explain question 7 again?','normal',true,'055-question')->>'class_post_id'),true);
select public.comment_on_class_post(current_setting('test.question')::uuid,current_setting('test.learner')::uuid,'I am stuck on the denominator.','055-comment-self');
do $$ begin perform public.publish_class_post(current_setting('test.class')::uuid,current_setting('test.learner')::uuid,'announcement','Forged announcement','important',true,'055-bad-announcement'); raise exception 'LEARNER_ANNOUNCEMENT_ALLOWED'; exception when others then if position('LEARNER_POST_TYPE_NOT_ALLOWED' in sqlerrm)=0 then raise; end if; end $$;
do $$ begin perform public.comment_on_class_post(current_setting('test.announcement')::uuid,current_setting('test.learner')::uuid,'Should not comment','055-disabled-comment'); raise exception 'COMMENT_ALLOWED_WHEN_DISABLED'; exception when others then if position('COMMENTS_DISABLED' in sqlerrm)=0 then raise; end if; end $$;

select set_config('request.jwt.claim.sub','74444444-4444-4444-4444-444444444444',true);
do $$ declare n int; begin
  select count(*) into n from public.class_learner_threads where id=current_setting('test.thread')::uuid; if n<>0 then raise exception 'COPIED_THREAD_ID_BYPASSED_RLS'; end if;
  select count(*) into n from public.class_posts where id=current_setting('test.question')::uuid; if n<>0 then raise exception 'COPIED_POST_ID_BYPASSED_RLS'; end if;
end $$;
do $$ begin perform public.send_class_learner_message(current_setting('test.class')::uuid,current_setting('test.learner')::uuid,'Intrusion','055-other-message'); raise exception 'UNRELATED_CLASS_MESSAGE_ALLOWED'; exception when others then if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if; end $$;

reset role;
insert into public.account_capabilities(account_id,capability_code) values(current_setting('test.other')::uuid,'safety_reviewer');
set local role authenticated;
select set_config('request.jwt.claim.sub','74444444-4444-4444-4444-444444444444',true);
select set_config('test.msg_restr',(public.apply_access_restriction(current_setting('test.parent')::uuid,null,'messaging','f1111111-1111-1111-1111-111111111111','TEST',null,null,'055-msg-restr')->>'restriction_id'),true);
select set_config('request.jwt.claim.sub','71111111-1111-1111-1111-111111111111',true);
do $$ begin perform public.send_class_learner_message(current_setting('test.class')::uuid,current_setting('test.learner')::uuid,'Blocked','055-blocked-message'); raise exception 'MESSAGING_RESTRICTION_IGNORED'; exception when others then if position('MESSAGING_RESTRICTED' in sqlerrm)=0 then raise; end if; end $$;
do $$ declare s text; begin select state into s from public.class_memberships where id=current_setting('test.membership')::uuid; if s<>'active' then raise exception 'MESSAGING_RESTRICTION_REWROTE_MEMBERSHIP'; end if; end $$;
select set_config('request.jwt.claim.sub','74444444-4444-4444-4444-444444444444',true);
select public.lift_access_restriction(current_setting('test.msg_restr')::uuid,'clear','055-msg-lift');

select set_config('request.jwt.claim.sub','71111111-1111-1111-1111-111111111111',true);
do $$ declare aid uuid; begin select id into aid from public.account_learner_access where account_id=current_setting('test.parent')::uuid and learner_id=current_setting('test.learner')::uuid and access_type='manage' and status='active'; perform public.end_learner_access(aid,'055-end-manager'); end $$;
do $$ declare n int; begin select count(*) into n from public.class_learner_threads where id=current_setting('test.thread')::uuid; if n<>0 then raise exception 'FORMER_MANAGER_STILL_READS_THREAD'; end if; end $$;
select set_config('request.jwt.claim.sub','72222222-2222-2222-2222-222222222222',true);
do $$ declare n int; begin select count(*) into n from public.class_learner_threads where id=current_setting('test.thread')::uuid; if n<>1 then raise exception 'SELF_LOST_THREAD_AFTER_MANAGER_END'; end if; end $$;

select set_config('request.jwt.claim.sub','73333333-3333-3333-3333-333333333333',true);
select public.pause_account('055-pause-teacher');
do $$ declare n int; begin
  select count(*) into n from public.classes where id=current_setting('test.class')::uuid; if n<>1 then raise exception 'PAUSED_TEACHER_LOST_CLASS_HISTORY'; end if;
  select count(*) into n from public.class_learner_threads where id=current_setting('test.thread')::uuid; if n<>1 then raise exception 'PAUSED_TEACHER_LOST_THREAD_HISTORY'; end if;
end $$;
do $$ begin perform public.send_class_learner_message(current_setting('test.class')::uuid,current_setting('test.learner')::uuid,'Should fail paused','055-paused-teacher-write'); raise exception 'PAUSED_TEACHER_WRITE_ALLOWED'; exception when others then if position('ACCOUNT_NOT_ACTIVE' in sqlerrm)=0 then raise; end if; end $$;
select public.resume_account('055-resume-teacher');

select set_config('test.dest',(public.create_class(null,current_setting('test.teacher')::uuid,'f1111111-1111-1111-1111-111111111111','Destination 055','group',2,'055-dest')->>'class_id'),true);
select public.activate_class(current_setting('test.dest')::uuid,'055-dest-active');
do $$ begin perform public.transfer_learner(current_setting('test.membership')::uuid,current_setting('test.dest')::uuid,'055-teacher-transfer'); raise exception 'TEACHER_UNILATERAL_TRANSFER_ALLOWED'; exception when others then if position('LEARNER_SIDE_TRANSFER_AUTHORITY_REQUIRED' in sqlerrm)=0 then raise; end if; end $$;

select set_config('request.jwt.claim.sub','72222222-2222-2222-2222-222222222222',true);
select set_config('test.dest_membership',(public.transfer_learner(current_setting('test.membership')::uuid,current_setting('test.dest')::uuid,'055-self-transfer')->>'destination_membership_id'),true);
do $$ declare n int; begin select count(*) into n from public.class_learner_threads where id=current_setting('test.thread')::uuid; if n<>1 then raise exception 'TRANSFERRED_THREAD_HISTORY_LOST'; end if; end $$;
do $$ begin perform public.send_class_learner_message(current_setting('test.class')::uuid,current_setting('test.learner')::uuid,'No longer active source','055-source-after-transfer'); raise exception 'TRANSFERRED_SOURCE_MESSAGE_ALLOWED'; exception when others then if position('ACTIVE_MEMBERSHIP_REQUIRED' in sqlerrm)=0 then raise; end if; end $$;

do $$ begin insert into public.class_learner_messages(thread_id,sender_account_id,body) values(current_setting('test.thread')::uuid,current_setting('test.self')::uuid,'direct'); raise exception 'DIRECT_CLASS_MESSAGE_WRITE_ALLOWED'; exception when insufficient_privilege then null; end $$;

rollback;
select 'CLASS_COMMUNICATION_RUNTIME_TESTS_PASS' as result;
