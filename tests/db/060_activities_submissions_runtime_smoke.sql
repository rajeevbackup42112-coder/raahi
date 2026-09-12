-- Raahi Learning V1.2 — Activities / Submissions runtime smoke
-- Dev/disposable only. Entire suite rolls back.
-- Covers Activity lifecycle, due date semantics, reusable Material authorization,
-- learner-owned/parent-performed submission, idempotent revision creation,
-- revision-specific teacher feedback, learner self resubmission, cross-learner
-- privacy, submission file authorization, post-leave own-history retention and
-- direct-write denial.

-- Canonical executable body is the transaction run used for the runtime marker
-- ACTIVITIES_SUBMISSIONS_RUNTIME_TESTS_PASS in the dev Supabase project.
-- The assertions are intentionally maintained as SQL rather than application mocks.

begin;

insert into auth.users(id,aud,role,email) values
('81111111-1111-1111-1111-111111111111','authenticated','authenticated','parent060@test.invalid'),
('82222222-2222-2222-2222-222222222222','authenticated','authenticated','self060@test.invalid'),
('83333333-3333-3333-3333-333333333333','authenticated','authenticated','teacher060@test.invalid'),
('84444444-4444-4444-4444-444444444444','authenticated','authenticated','otherparent060@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','81111111-1111-1111-1111-111111111111',true);
select set_config('test.parent',(public.bootstrap_account('Parent 060')->>'account_id'),true);
select set_config('request.jwt.claim.sub','82222222-2222-2222-2222-222222222222',true);
select set_config('test.self',(public.bootstrap_account('Self 060')->>'account_id'),true);
select set_config('request.jwt.claim.sub','83333333-3333-3333-3333-333333333333',true);
select set_config('test.teacher',(public.bootstrap_account('Teacher 060')->>'account_id'),true);
select set_config('request.jwt.claim.sub','84444444-4444-4444-4444-444444444444',true);
select set_config('test.other',(public.bootstrap_account('Other Parent 060')->>'account_id'),true);
reset role;
insert into public.account_capabilities(account_id,capability_code) values(current_setting('test.teacher')::uuid,'teach');
insert into public.locations(id,name,slug,state,country_code) values('a6111111-1111-1111-1111-111111111111','Dhanbad 060','dhanbad-060','live','IN');

set local role authenticated;
select set_config('request.jwt.claim.sub','81111111-1111-1111-1111-111111111111',true);
select set_config('test.l1',(public.create_learner('Rahul 060','manage','none',null,'060-l1')->>'learner_id'),true);
select public.grant_learner_self_access(current_setting('test.l1')::uuid,current_setting('test.self')::uuid,'060-self');
select set_config('test.share1',(public.create_learner_share_code(current_setting('test.l1')::uuid,'060-share1')->>'share_code'),true);
select set_config('request.jwt.claim.sub','84444444-4444-4444-4444-444444444444',true);
select set_config('test.l2',(public.create_learner('Other Learner 060','manage','none',null,'060-l2')->>'learner_id'),true);
select set_config('test.share2',(public.create_learner_share_code(current_setting('test.l2')::uuid,'060-share2')->>'share_code'),true);

select set_config('request.jwt.claim.sub','83333333-3333-3333-3333-333333333333',true);
select public.upsert_teacher_profile('Teacher 060','Bio','Experience','visible','060-profile');
select set_config('test.class',(public.create_class(null,current_setting('test.teacher')::uuid,'a6111111-1111-1111-1111-111111111111','Maths 060','group',4,'060-class')->>'class_id'),true);
select public.activate_class(current_setting('test.class')::uuid,'060-active');
select set_config('test.i1',(public.send_class_invitation_with_share_code(current_setting('test.class')::uuid,current_setting('test.share1'),null,'060-i1')->>'invitation_id'),true);
select set_config('test.i2',(public.send_class_invitation_with_share_code(current_setting('test.class')::uuid,current_setting('test.share2'),null,'060-i2')->>'invitation_id'),true);
select set_config('request.jwt.claim.sub','81111111-1111-1111-1111-111111111111',true);
select set_config('test.m1',(public.accept_class_invitation(current_setting('test.i1')::uuid,'060-a1')->>'membership_id'),true);
select set_config('request.jwt.claim.sub','84444444-4444-4444-4444-444444444444',true);
select set_config('test.m2',(public.accept_class_invitation(current_setting('test.i2')::uuid,'060-a2')->>'membership_id'),true);

select set_config('request.jwt.claim.sub','83333333-3333-3333-3333-333333333333',true);
select set_config('test.material',(public.create_material('Fractions Set 2',null,'text',null,null,'Worksheet content','060-mat')->>'material_id'),true);
select set_config('test.activity',(public.create_activity(current_setting('test.class')::uuid,'practice','Fractions Practice','Complete questions 1-12',now()-interval '1 day',true,'060-act')->>'activity_id'),true);
do $$ begin perform public.set_activity_material_link(current_setting('test.activity')::uuid,current_setting('test.material')::uuid,true,'060-link-too-early'); raise exception 'ACTIVITY_LINKED_UNSHARED_MATERIAL'; exception when others then if position('MATERIAL_NOT_SHARED_TO_ACTIVITY_CLASS' in sqlerrm)=0 then raise; end if; end $$;
select public.set_material_class_link(current_setting('test.material')::uuid,current_setting('test.class')::uuid,true,'060-mat-class');
select public.set_activity_material_link(current_setting('test.activity')::uuid,current_setting('test.material')::uuid,true,'060-act-mat');
select public.publish_activity(current_setting('test.activity')::uuid,'060-publish');

select set_config('request.jwt.claim.sub','81111111-1111-1111-1111-111111111111',true);
select set_config('test.file1',(public.register_file_asset('submissions/060/rahul-r1.jpg','activity_submission','image/jpeg',5000,'060-file1')->>'file_asset_id'),true);
select set_config('test.sub',(public.submit_activity(current_setting('test.activity')::uuid,current_setting('test.l1')::uuid,null,current_setting('test.file1')::uuid,'060-submit1')->>'submission_id'),true);
do $$ declare owner uuid; performer uuid; rn int; begin
  select learner_id into owner from public.submissions where id=current_setting('test.sub')::uuid;
  select performed_by_account_id,revision_number into performer,rn from public.submission_revisions where submission_id=current_setting('test.sub')::uuid;
  if owner<>current_setting('test.l1')::uuid or performer<>current_setting('test.parent')::uuid or rn<>1 then raise exception 'SUBMISSION_OWNERSHIP_OR_REVISION_BAD'; end if;
end $$;
do $$ declare r int; begin perform public.submit_activity(current_setting('test.activity')::uuid,current_setting('test.l1')::uuid,null,current_setting('test.file1')::uuid,'060-submit1'); select count(*) into r from public.submission_revisions where submission_id=current_setting('test.sub')::uuid; if r<>1 then raise exception 'SUBMISSION_RETRY_DUPLICATED_REVISION:%',r; end if; end $$;
do $$ begin perform public.submit_activity(current_setting('test.activity')::uuid,current_setting('test.l1')::uuid,'duplicate',null,'060-submit-different-key'); raise exception 'SECOND_SUBMISSION_WITHOUT_CHANGES_REQUESTED_ALLOWED'; exception when others then if position('SUBMISSION_ALREADY_SUBMITTED' in sqlerrm)=0 then raise; end if; end $$;

select set_config('request.jwt.claim.sub','83333333-3333-3333-3333-333333333333',true);
select public.request_submission_changes(current_setting('test.sub')::uuid,'Please redo questions 7 and 9.','060-changes');
select set_config('request.jwt.claim.sub','82222222-2222-2222-2222-222222222222',true);
select set_config('test.file2',(public.register_file_asset('submissions/060/rahul-r2.jpg','activity_submission','image/jpeg',5200,'060-file2')->>'file_asset_id'),true);
select public.submit_activity(current_setting('test.activity')::uuid,current_setting('test.l1')::uuid,'Corrected questions 7 and 9',current_setting('test.file2')::uuid,'060-submit2');
select set_config('request.jwt.claim.sub','83333333-3333-3333-3333-333333333333',true);
select public.review_submission(current_setting('test.sub')::uuid,'Correct now. Good work.','060-reviewed');
do $$ declare c int; f1 text; o1 text; f2 text; o2 text; begin
  select count(*) into c from public.submission_revisions where submission_id=current_setting('test.sub')::uuid; if c<>2 then raise exception 'REVISION_HISTORY_NOT_PRESERVED:%',c; end if;
  select teacher_feedback,review_outcome into f1,o1 from public.submission_revisions where submission_id=current_setting('test.sub')::uuid and revision_number=1;
  select teacher_feedback,review_outcome into f2,o2 from public.submission_revisions where submission_id=current_setting('test.sub')::uuid and revision_number=2;
  if o1<>'changes_requested' or f1<>'Please redo questions 7 and 9.' or o2<>'reviewed' or f2<>'Correct now. Good work.' then raise exception 'REVISION_FEEDBACK_HISTORY_BAD'; end if;
end $$;
do $$ begin perform public.update_activity(current_setting('test.activity')::uuid,'assignment','Fractions Practice','Updated wording',now()+interval '1 day',false,'060-structural-edit'); raise exception 'ACTIVITY_STRUCTURE_CHANGED_AFTER_SUBMISSION'; exception when others then if position('ACTIVITY_STRUCTURE_LOCKED_AFTER_SUBMISSION' in sqlerrm)=0 then raise; end if; end $$;
do $$ begin perform public.set_material_class_link(current_setting('test.material')::uuid,current_setting('test.class')::uuid,false,'060-unlink-class-material'); raise exception 'ACTIVITY_MATERIAL_BROKEN_BY_CLASS_UNLINK'; exception when others then if position('MATERIAL_STILL_LINKED_TO_ACTIVITY' in sqlerrm)=0 then raise; end if; end $$;
do $$ declare n int; begin select count(*) into n from public.file_assets where id=current_setting('test.file1')::uuid; if n<>1 then raise exception 'TEACHER_CANNOT_READ_SUBMISSION_FILE'; end if; end $$;

select set_config('request.jwt.claim.sub','84444444-4444-4444-4444-444444444444',true);
do $$ declare n int; begin select count(*) into n from public.submissions where id=current_setting('test.sub')::uuid; if n<>0 then raise exception 'CROSS_LEARNER_SUBMISSION_READ_ALLOWED'; end if; select count(*) into n from public.file_assets where id=current_setting('test.file1')::uuid; if n<>0 then raise exception 'CROSS_LEARNER_SUBMISSION_FILE_READ_ALLOWED'; end if; end $$;
select set_config('request.jwt.claim.sub','82222222-2222-2222-2222-222222222222',true);
do $$ declare n int; begin select count(*) into n from public.submission_revisions where submission_id=current_setting('test.sub')::uuid; if n<>2 then raise exception 'LEARNER_REVISION_HISTORY_NOT_VISIBLE'; end if; select count(*) into n from public.file_assets where id=current_setting('test.file1')::uuid; if n<>1 then raise exception 'LEARNER_CANNOT_READ_PARENT_UPLOADED_OWN_WORK'; end if; end $$;

select set_config('request.jwt.claim.sub','81111111-1111-1111-1111-111111111111',true);
select public.leave_class(current_setting('test.m1')::uuid,'060-leave');
do $$ declare n int; begin select count(*) into n from public.activities where id=current_setting('test.activity')::uuid; if n<>0 then raise exception 'LEFT_LEARNER_STILL_HAS_SHARED_ACTIVITY'; end if; select count(*) into n from public.submissions where id=current_setting('test.sub')::uuid; if n<>1 then raise exception 'LEFT_LEARNER_LOST_OWN_SUBMISSION'; end if; end $$;
select set_config('request.jwt.claim.sub','83333333-3333-3333-3333-333333333333',true);
select public.close_activity(current_setting('test.activity')::uuid,'060-close');
select set_config('request.jwt.claim.sub','84444444-4444-4444-4444-444444444444',true);
do $$ begin perform public.submit_activity(current_setting('test.activity')::uuid,current_setting('test.l2')::uuid,'Late after close',null,'060-after-close'); raise exception 'SUBMISSION_ALLOWED_AFTER_ACTIVITY_CLOSE'; exception when others then if position('ACTIVITY_NOT_OPEN' in sqlerrm)=0 then raise; end if; end $$;
do $$ begin update public.submissions set current_status='reviewed' where id=current_setting('test.sub')::uuid; raise exception 'DIRECT_SUBMISSION_WRITE_ALLOWED'; exception when insufficient_privilege then null; end $$;

rollback;
select 'ACTIVITIES_SUBMISSIONS_RUNTIME_TESTS_PASS' as result;
