-- Raahi Learning V1.3 — contextual inbox + Organization responsible-teacher picker smoke
-- Dev/disposable only. Entire suite rolls back.

begin;

insert into auth.users(id,aud,role,email) values
('a1011111-1111-1111-1111-111111111111','authenticated','authenticated','org-owner-110@test.invalid'),
('a1022222-2222-2222-2222-222222222222','authenticated','authenticated','class-manager-110@test.invalid'),
('a1033333-3333-3333-3333-333333333333','authenticated','authenticated','parent-110@test.invalid'),
('a1044444-4444-4444-4444-444444444444','authenticated','authenticated','teacher-110@test.invalid'),
('a1055555-5555-5555-5555-555555555555','authenticated','authenticated','outsider-110@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','a1011111-1111-1111-1111-111111111111',true);
select set_config('t.owner',(public.bootstrap_account('Org Owner 110')->>'account_id'),true);
select set_config('request.jwt.claim.sub','a1022222-2222-2222-2222-222222222222',true);
select set_config('t.classmgr',(public.bootstrap_account('Class Manager 110')->>'account_id'),true);
select set_config('request.jwt.claim.sub','a1033333-3333-3333-3333-333333333333',true);
select set_config('t.parent',(public.bootstrap_account('Parent 110')->>'account_id'),true);
select set_config('request.jwt.claim.sub','a1044444-4444-4444-4444-444444444444',true);
select set_config('t.teacher',(public.bootstrap_account('Teacher 110')->>'account_id'),true);
select set_config('request.jwt.claim.sub','a1055555-5555-5555-5555-555555555555',true);
select set_config('t.outsider',(public.bootstrap_account('Outsider 110')->>'account_id'),true);

reset role;
insert into public.locations(id,name,slug,state,country_code)
values('a1100000-0000-0000-0000-000000000001','Dhanbad 110','dhanbad-110','live','IN');

-- Organization picker permission seam: manage_classes may pick eligible teachers
-- without gaining the broader manage_members projection.
set local role authenticated;
select set_config('request.jwt.claim.sub','a1011111-1111-1111-1111-111111111111',true);
select set_config('t.org',(public.create_organization('coaching','Institute 110',null,null,null,null,'none',null,'110-org')->>'organization_id'),true);
select set_config('t.member',(public.add_organization_member(current_setting('t.org')::uuid,current_setting('t.classmgr')::uuid,'110-add-classmgr')->>'organization_member_id'),true);
select public.set_organization_member_capability(current_setting('t.member')::uuid,'manage_classes',true,'110-class-cap');

select set_config('request.jwt.claim.sub','a1022222-2222-2222-2222-222222222222',true);
do $$ declare n int; begin
  select count(*) into n from public.get_eligible_organization_class_teachers(current_setting('t.org')::uuid);
  if n<>2 then raise exception 'ELIGIBLE_TEACHER_PICKER_WRONG_COUNT:%',n; end if;
end $$;
do $$ begin
  perform * from public.get_organization_members(current_setting('t.org')::uuid);
  raise exception 'CLASS_MANAGER_GAINED_MEMBER_DIRECTORY';
exception when others then
  if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if;
end $$;

select set_config('request.jwt.claim.sub','a1055555-5555-5555-5555-555555555555',true);
do $$ begin
  perform * from public.get_eligible_organization_class_teachers(current_setting('t.org')::uuid);
  raise exception 'OUTSIDER_USED_TEACHER_PICKER';
exception when others then
  if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if;
end $$;

-- Build one real Enquiry + one real Class learner thread through canonical commands.
select set_config('request.jwt.claim.sub','a1033333-3333-3333-3333-333333333333',true);
select set_config('t.learner',(public.create_learner('Rahul 110','manage','none',null,'110-learner')->>'learner_id'),true);

select set_config('request.jwt.claim.sub','a1044444-4444-4444-4444-444444444444',true);
select public.enable_teaching('110-enable-teach');
select public.upsert_teacher_profile('Maths Teacher','Maths support','10 years','visible','110-profile');
select set_config('t.option',(public.publish_teaching_option(null,'Class 8 Maths','Academics','Maths support','both','Dhanbad','₹1200/month',array['a1100000-0000-0000-0000-000000000001']::uuid[],'110-option')->>'teaching_option_id'),true);

select set_config('request.jwt.claim.sub','a1033333-3333-3333-3333-333333333333',true);
select set_config('t.enquiry',(public.send_enquiry(current_setting('t.learner')::uuid,current_setting('t.option')::uuid,'a1100000-0000-0000-0000-000000000001','Interested in Maths','110-enquiry')->>'enquiry_id'),true);

select set_config('request.jwt.claim.sub','a1044444-4444-4444-4444-444444444444',true);
select public.engage_enquiry(current_setting('t.enquiry')::uuid,'110-engage');
select public.send_enquiry_message(current_setting('t.enquiry')::uuid,'Welcome to Maths','110-enquiry-message');
select set_config('t.class',(public.create_class(null,current_setting('t.teacher')::uuid,'a1100000-0000-0000-0000-000000000001','Maths 110','one_to_one',1,'110-class')->>'class_id'),true);
select public.activate_class(current_setting('t.class')::uuid,'110-class-active');
select set_config('t.inv',(public.send_class_invitation(current_setting('t.class')::uuid,current_setting('t.enquiry')::uuid,'₹1200/month','110-invite')->>'invitation_id'),true);

select set_config('request.jwt.claim.sub','a1033333-3333-3333-3333-333333333333',true);
select public.accept_class_invitation(current_setting('t.inv')::uuid,'110-accept');

select set_config('request.jwt.claim.sub','a1044444-4444-4444-4444-444444444444',true);
select public.send_class_learner_message(current_setting('t.class')::uuid,current_setting('t.learner')::uuid,'First class message','110-class-message');

-- Parent sees exactly the authorized Enquiry and Class thread.
select set_config('request.jwt.claim.sub','a1033333-3333-3333-3333-333333333333',true);
do $$ declare n int; e int; c int; body text; begin
  select count(*) into n from public.get_my_conversations();
  select count(*) into e from public.get_my_conversations() x where x->>'conversation_kind'='enquiry' and (x->>'enquiry_id')::uuid=current_setting('t.enquiry')::uuid;
  select count(*) into c from public.get_my_conversations() x where x->>'conversation_kind'='class_learner' and (x->>'class_id')::uuid=current_setting('t.class')::uuid and (x->>'learner_id')::uuid=current_setting('t.learner')::uuid;
  select x->>'last_message_preview' into body from public.get_my_conversations() x where x->>'conversation_kind'='class_learner' limit 1;
  if n<>2 or e<>1 or c<>1 then raise exception 'PARENT_CONVERSATION_LIST_WRONG:n=% e=% c=%',n,e,c; end if;
  if body<>'First class message' then raise exception 'CLASS_PREVIEW_WRONG:%',body; end if;
end $$;

-- Provider sees the same two authorized contexts, including the learner-specific Class thread.
select set_config('request.jwt.claim.sub','a1044444-4444-4444-4444-444444444444',true);
do $$ declare n int; c int; begin
  select count(*) into n from public.get_my_conversations();
  select count(*) into c from public.get_my_conversations() x where x->>'conversation_kind'='class_learner' and (x->>'learner_id')::uuid=current_setting('t.learner')::uuid;
  if n<>2 or c<>1 then raise exception 'PROVIDER_CONVERSATION_LIST_WRONG:n=% c=%',n,c; end if;
end $$;

-- Unrelated Account cannot enumerate either context.
select set_config('request.jwt.claim.sub','a1055555-5555-5555-5555-555555555555',true);
do $$ declare n int; begin
  select count(*) into n from public.get_my_conversations();
  if n<>0 then raise exception 'OUTSIDER_CONVERSATION_LEAK:%',n; end if;
end $$;

-- Anonymous role cannot execute either projection.
reset role;
set local role anon;
do $$ begin
  perform * from public.get_my_conversations();
  raise exception 'ANON_CONVERSATION_EXEC_ALLOWED';
exception when insufficient_privilege then null; end $$;
do $$ begin
  perform * from public.get_eligible_organization_class_teachers(current_setting('t.org')::uuid);
  raise exception 'ANON_PICKER_EXEC_ALLOWED';
exception when insufficient_privilege then null; end $$;

rollback;
select 'V13_CONTEXTUAL_INBOX_ORG_PICKER_PASS' as result;
