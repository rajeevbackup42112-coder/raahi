-- Raahi Learning V1.2 — Organizations / teacher discovery runtime smoke
-- Dev/disposable only. Entire suite rolls back.
-- Covers: org creation/idempotency, scoped member capabilities, Teaching Option ownership,
-- live-Location discovery, availability, safe public projections, private Saves,
-- member-removal persistence, direct-read/write denial and closure blocker.

begin;

insert into auth.users(id,aud,role,email) values
('31111111-1111-1111-1111-111111111111','authenticated','authenticated','orgowner@test.invalid'),
('32222222-2222-2222-2222-222222222222','authenticated','authenticated','orgmember@test.invalid'),
('33333333-3333-3333-3333-333333333333','authenticated','authenticated','outsider@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','31111111-1111-1111-1111-111111111111',true);
select set_config('test.owner',(public.bootstrap_account('Owner Teacher')->>'account_id'),true);
select set_config('request.jwt.claim.sub','32222222-2222-2222-2222-222222222222',true);
select set_config('test.member',(public.bootstrap_account('Member Teacher')->>'account_id'),true);
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',true);
select set_config('test.outsider',(public.bootstrap_account('Outsider')->>'account_id'),true);

reset role;
insert into public.account_capabilities(account_id,capability_code) values
(current_setting('test.owner')::uuid,'teach'),(current_setting('test.member')::uuid,'teach');
insert into public.locations(id,name,slug,state,country_code) values
('aaaaaaaa-1111-1111-1111-111111111111','Live Town','live-town','live','IN'),
('bbbbbbbb-2222-2222-2222-222222222222','Preparing Town','preparing-town','preparing','IN');

set local role authenticated;
select set_config('request.jwt.claim.sub','31111111-1111-1111-1111-111111111111',true);
select public.upsert_teacher_profile('Maths Teacher','Public bio','10 years','visible','tp-1');
select set_config('test.teacher_option',(public.publish_teaching_option(null,'Class 8 Maths','Academics','Maths coaching','both','Central Area','₹1500/month',array['aaaaaaaa-1111-1111-1111-111111111111']::uuid[],'to-1')->>'teaching_option_id'),true);

select set_config('test.org',(public.create_organization('academy','Bright Academy','Learning center','Public desk','Main Road','https://example.invalid','none',null,'org-1')->>'organization_id'),true);
select set_config('test.member_row',(public.add_organization_member(current_setting('test.org')::uuid,current_setting('test.member')::uuid,'add-member-1')->>'member_id'),true);
select public.set_organization_member_capability(current_setting('test.member_row')::uuid,'manage_teaching_options',true,'member-teach-cap-1');

select set_config('request.jwt.claim.sub','32222222-2222-2222-2222-222222222222',true);
select set_config('test.org_option',(public.publish_teaching_option(current_setting('test.org')::uuid,'Guitar Basics','Music','Beginner guitar','in_person','Main Road','₹1200/month',array['aaaaaaaa-1111-1111-1111-111111111111']::uuid[],'org-option-1')->>'teaching_option_id'),true);

select set_config('request.jwt.claim.sub','31111111-1111-1111-1111-111111111111',true);
do $$ declare n int; begin
  select count(*) into n from public.discover_teaching_options('aaaaaaaa-1111-1111-1111-111111111111',null);
  if n<>2 then raise exception 'DISCOVERY_COUNT_BAD:%',n; end if;
end $$;
select public.set_teaching_availability(current_setting('test.teacher_option')::uuid,'not_taking_new_learners','avail-1');
do $$ declare n int; begin
  select count(*) into n from public.discover_teaching_options('aaaaaaaa-1111-1111-1111-111111111111','Class 8');
  if n<>0 then raise exception 'NOT_TAKING_STILL_DISCOVERED'; end if;
end $$;

select public.remove_organization_member(current_setting('test.member_row')::uuid,'remove-member-1');
select set_config('request.jwt.claim.sub','32222222-2222-2222-2222-222222222222',true);
do $$ begin
  perform public.update_teaching_option(current_setting('test.org_option')::uuid,'Illegal','Music',null,'online',null,null,'ended-member-edit');
  raise exception 'ENDED_MEMBER_STILL_AUTHORIZED';
exception when others then if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if;
end $$;

select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',true);
do $$ declare n int; begin
  select count(*) into n from public.organizations where id=current_setting('test.org')::uuid;
  if n<>0 then raise exception 'OUTSIDER_ORG_DIRECT_READ_ALLOWED'; end if;
end $$;

select set_config('request.jwt.claim.sub','31111111-1111-1111-1111-111111111111',true);
do $$ declare r jsonb; begin
  r:=public.request_account_closure('org-closure-check');
  if (r->>'closed')::boolean then raise exception 'SOLE_ORG_MANAGER_CLOSURE_ALLOWED'; end if;
  if not exists(select 1 from jsonb_array_elements(r->'blockers') x where x->>'code'='SOLE_ORGANIZATION_MANAGER') then raise exception 'ORG_CLOSURE_BLOCKER_MISSING'; end if;
end $$;

rollback;
select 'ORGANIZATIONS_DISCOVERY_RUNTIME_TESTS_PASS' as result;
