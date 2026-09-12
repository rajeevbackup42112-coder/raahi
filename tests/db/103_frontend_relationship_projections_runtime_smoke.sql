-- Raahi Learning V1.2 — frontend relationship projections runtime smoke.
-- Disposable dev suite; all fixtures roll back.

begin;
insert into auth.users(id,aud,role,email) values
('a3111111-1111-1111-1111-111111111111','authenticated','authenticated','frontend103-parent@test.invalid'),
('a3222222-2222-2222-2222-222222222222','authenticated','authenticated','frontend103-teacher@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','a3111111-1111-1111-1111-111111111111',true);
select set_config('test.parent',(public.bootstrap_account('Frontend Parent 103')->>'account_id'),true);
select set_config('test.learner',(public.create_learner('Frontend Learner 103','manage','none',null,'103-learner')->>'learner_id'),true);
select set_config('request.jwt.claim.sub','a3222222-2222-2222-2222-222222222222',true);
select set_config('test.teacher',(public.bootstrap_account('Frontend Teacher 103')->>'account_id'),true);
select public.enable_teaching('103-enable-teaching');
reset role;
insert into public.locations(id,name,slug,state,country_code) values
('a3000000-0000-0000-0000-000000000001','Frontend Location 103','frontend-location-103','live','IN');

set local role authenticated;
select set_config('request.jwt.claim.sub','a3111111-1111-1111-1111-111111111111',true);
select set_config('test.request',(public.post_learning_request(
  current_setting('test.learner')::uuid,'a3000000-0000-0000-0000-000000000001',
  'Need Maths help','Academics','either','Fractions and algebra','Weekday evenings','103-request'
)->>'learning_request_id'),true);
do $$ declare r jsonb; begin
  select x into r from public.get_my_learning_requests() x limit 1;
  if r->>'learning_request_id' is distinct from current_setting('test.request') then raise exception 'MY_REQUEST_PROJECTION_BAD:%',r; end if;
  if r->>'learner_name'<>'Frontend Learner 103' or r->>'location_name'<>'Frontend Location 103' then raise exception 'MY_REQUEST_NAMES_BAD:%',r; end if;
end $$;

select set_config('request.jwt.claim.sub','a3222222-2222-2222-2222-222222222222',true);
select public.upsert_teacher_profile('Maths Teacher 103','Bio 103','Experience 103','visible','103-profile');
select set_config('test.option',(public.publish_teaching_option(
  null,'Maths Tuition 103','Academics','Fractions','both','Near station','₹500 / class',
  array['a3000000-0000-0000-0000-000000000001'::uuid],'103-option'
)->>'teaching_option_id'),true);
do $$ declare w jsonb; begin
  w:=public.get_my_teacher_workspace();
  if w #>> '{profile,headline}' <> 'Maths Teacher 103' then raise exception 'TEACHER_PROFILE_PROJECTION_BAD:%',w; end if;
  if jsonb_array_length(w->'teaching_options')<>1 then raise exception 'TEACHING_OPTIONS_PROJECTION_BAD:%',w; end if;
end $$;

select set_config('request.jwt.claim.sub','a3111111-1111-1111-1111-111111111111',true);
select set_config('test.enquiry',(public.send_enquiry(
  current_setting('test.learner')::uuid,current_setting('test.option')::uuid,
  'a3000000-0000-0000-0000-000000000001','Can we discuss timing?','103-enquiry'
)->>'enquiry_id'),true);
do $$ declare t jsonb; begin
  t:=public.get_enquiry_thread(current_setting('test.enquiry')::uuid);
  if t #>> '{enquiry,state}' <> 'pending' then raise exception 'PENDING_ENQUIRY_PROJECTION_BAD:%',t; end if;
  if jsonb_array_length(t->'messages')<>1 then raise exception 'OPENING_MESSAGE_MISSING:%',t; end if;
end $$;

select set_config('request.jwt.claim.sub','a3222222-2222-2222-2222-222222222222',true);
select public.engage_enquiry(current_setting('test.enquiry')::uuid,'103-engage');
select public.send_enquiry_message(current_setting('test.enquiry')::uuid,'Yes, weekday evenings work.','103-message');
do $$ declare t jsonb; begin
  t:=public.get_enquiry_thread(current_setting('test.enquiry')::uuid);
  if t #>> '{enquiry,state}' <> 'active' or (t->>'can_message')::boolean is not true then raise exception 'ACTIVE_ENQUIRY_PROJECTION_BAD:%',t; end if;
  if jsonb_array_length(t->'messages')<>2 then raise exception 'THREAD_MESSAGE_COUNT_BAD:%',t; end if;
end $$;

rollback;
select 'FRONTEND_RELATIONSHIP_PROJECTIONS_PASS' as result;
