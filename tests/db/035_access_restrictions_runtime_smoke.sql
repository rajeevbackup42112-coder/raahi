-- Raahi Learning V1.2 — Scoped access restrictions runtime smoke
-- Dev/disposable only. Entire suite rolls back.
-- Covers reviewer authority, subject privacy, direct-write denial, idempotency,
-- account/org independence, Location-specific/global discovery effects, unrelated
-- scope independence, lift, expiry and audit minimization.

begin;

insert into auth.users(id,aud,role,email) values
('41111111-1111-1111-1111-111111111111','authenticated','authenticated','reviewer@test.invalid'),
('42222222-2222-2222-2222-222222222222','authenticated','authenticated','teacher@test.invalid'),
('43333333-3333-3333-3333-333333333333','authenticated','authenticated','ordinary@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','41111111-1111-1111-1111-111111111111',true);
select set_config('test.reviewer',(public.bootstrap_account('Safety Reviewer')->>'account_id'),true);
select set_config('request.jwt.claim.sub','42222222-2222-2222-2222-222222222222',true);
select set_config('test.teacher',(public.bootstrap_account('Teacher Subject')->>'account_id'),true);
select set_config('request.jwt.claim.sub','43333333-3333-3333-3333-333333333333',true);
select set_config('test.ordinary',(public.bootstrap_account('Ordinary User')->>'account_id'),true);

reset role;
insert into public.account_capabilities(account_id,capability_code) values
(current_setting('test.reviewer')::uuid,'safety_reviewer'),
(current_setting('test.teacher')::uuid,'teach');
insert into public.locations(id,name,slug,state,country_code) values
('c1111111-1111-1111-1111-111111111111','Dhanbad','dhanbad','live','IN'),
('c2222222-2222-2222-2222-222222222222','Gomoh','gomoh','live','IN');

set local role authenticated;
select set_config('request.jwt.claim.sub','42222222-2222-2222-2222-222222222222',true);
select public.upsert_teacher_profile('Maths Teacher','Public teacher bio','10 years','visible','restr-profile');
select set_config('test.teacher_option',(public.publish_teaching_option(null,'Maths Tuition','Academics','Maths','both','Local','₹1000/month',array['c1111111-1111-1111-1111-111111111111','c2222222-2222-2222-2222-222222222222']::uuid[],'restr-teacher-option')->>'teaching_option_id'),true);
select set_config('test.org',(public.create_organization('academy','Restriction Academy','Public org',null,'Center',null,'none',null,'restr-org')->>'organization_id'),true);
select set_config('test.org_option',(public.publish_teaching_option(current_setting('test.org')::uuid,'Guitar Class','Music','Guitar','in_person','Center','₹800/month',array['c1111111-1111-1111-1111-111111111111','c2222222-2222-2222-2222-222222222222']::uuid[],'restr-org-option')->>'teaching_option_id'),true);

select set_config('request.jwt.claim.sub','43333333-3333-3333-3333-333333333333',true);
do $$ begin
  perform public.apply_access_restriction(current_setting('test.teacher')::uuid,null,'public_discovery','c1111111-1111-1111-1111-111111111111','test',null,null,'ordinary-denied');
  raise exception 'ORDINARY_RESTRICTION_APPLY_ALLOWED';
exception when others then if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if; end $$;

select set_config('request.jwt.claim.sub','41111111-1111-1111-1111-111111111111',true);
select set_config('test.teacher_restriction',(public.apply_access_restriction(current_setting('test.teacher')::uuid,null,'public_discovery','c1111111-1111-1111-1111-111111111111','SAFETY_REVIEW','moderation-private detail',null,'teacher-dhanbad-1')->>'restriction_id'),true);
select public.apply_access_restriction(current_setting('test.teacher')::uuid,null,'ads',null,'ADS_POLICY',null,null,'teacher-ads-global');
select set_config('test.org_restriction',(public.apply_access_restriction(null,current_setting('test.org')::uuid,'public_discovery',null,'ORG_SAFETY',null,null,'org-global')->>'restriction_id'),true);

-- Location-scoped Teacher restriction does not spill to another Location; global
-- Organization restriction applies everywhere; unrelated Ads scope does not hide discovery.
do $$ declare n int; begin
  select count(*) into n from public.discover_teaching_options('c1111111-1111-1111-1111-111111111111',null);
  if n<>0 then raise exception 'DHANBAD_RESTRICTION_RESULT_BAD:%',n; end if;
  select count(*) into n from public.discover_teaching_options('c2222222-2222-2222-2222-222222222222',null);
  if n<>1 then raise exception 'GOMOH_RESTRICTION_RESULT_BAD:%',n; end if;
end $$;

select public.lift_access_restriction(current_setting('test.teacher_restriction')::uuid,'review cleared','lift-teacher-1');
do $$ declare n int; begin
  select count(*) into n from public.discover_teaching_options('c1111111-1111-1111-1111-111111111111',null);
  if n<>1 then raise exception 'LIFT_DID_NOT_RESTORE_TEACHER:%',n; end if;
end $$;

-- Subject cannot inspect moderation rows or directly forge them.
select set_config('request.jwt.claim.sub','42222222-2222-2222-2222-222222222222',true);
do $$ declare n int; begin select count(*) into n from public.access_restrictions; if n<>0 then raise exception 'SUBJECT_CAN_READ_RESTRICTIONS'; end if; end $$;
do $$ begin
  insert into public.access_restrictions(account_id,restriction_scope,reason_code,applied_by_account_id)
  values(current_setting('test.teacher')::uuid,'messaging','FORGED',current_setting('test.teacher')::uuid);
  raise exception 'DIRECT_RESTRICTION_WRITE_ALLOWED';
exception when insufficient_privilege then null; end $$;

-- Expiry runs as a private system operation and is audited.
reset role;
insert into public.access_restrictions(account_id,restriction_scope,reason_code,starts_at,ends_at,applied_by_account_id)
values(current_setting('test.teacher')::uuid,'messaging','TEMP',now()-interval '2 hours',now()-interval '1 hour',current_setting('test.reviewer')::uuid);
do $$ declare n int; begin
  n:=app_private.expire_access_restrictions();
  if n<1 then raise exception 'EXPIRY_HELPER_DID_NOT_EXPIRE'; end if;
  if not exists(select 1 from public.audit_log where actor_kind='system' and action_type='restriction.expire') then raise exception 'EXPIRY_SYSTEM_AUDIT_MISSING'; end if;
  if exists(select 1 from public.audit_log where target_type='access_restriction' and metadata::text like '%moderation-private detail%') then raise exception 'PRIVATE_DETAILS_LEAKED_TO_AUDIT_METADATA'; end if;
end $$;

rollback;
select 'ACCESS_RESTRICTIONS_RUNTIME_TESTS_PASS' as result;
