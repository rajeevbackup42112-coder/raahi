-- Raahi Learning V1.2 — secure Class/Learner thread projection runtime smoke.
-- Disposable dev suite; all fixtures roll back.

begin;
insert into auth.users(id,aud,role,email) values
('a5111111-1111-1111-1111-111111111111','authenticated','authenticated','frontend105-parent@test.invalid'),
('a5222222-2222-2222-2222-222222222222','authenticated','authenticated','frontend105-self@test.invalid'),
('a5333333-3333-3333-3333-333333333333','authenticated','authenticated','frontend105-teacher@test.invalid'),
('a5444444-4444-4444-4444-444444444444','authenticated','authenticated','frontend105-outsider@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','a5111111-1111-1111-1111-111111111111',true);
select set_config('test.parent',(public.bootstrap_account('Frontend Parent 105')->>'account_id'),true);
select set_config('test.learner',(public.create_learner('Frontend Learner 105','manage','none',null,'105-learner')->>'learner_id'),true);
select set_config('request.jwt.claim.sub','a5222222-2222-2222-2222-222222222222',true);
select set_config('test.self',(public.bootstrap_account('Frontend Self 105')->>'account_id'),true);
select set_config('request.jwt.claim.sub','a5333333-3333-3333-3333-333333333333',true);
select set_config('test.teacher',(public.bootstrap_account('Frontend Teacher 105')->>'account_id'),true);
select public.enable_teaching('105-enable-teaching');
select set_config('request.jwt.claim.sub','a5444444-4444-4444-4444-444444444444',true);
select set_config('test.outsider',(public.bootstrap_account('Frontend Outsider 105')->>'account_id'),true);
reset role;
insert into public.locations(id,name,slug,state,country_code) values
('a5000000-0000-0000-0000-000000000001','Frontend Location 105','frontend-location-105','live','IN');

set local role authenticated;
select set_config('request.jwt.claim.sub','a5111111-1111-1111-1111-111111111111',true);
select public.grant_learner_self_access(current_setting('test.learner')::uuid,current_setting('test.self')::uuid,'105-self-access');
select set_config('test.share',(public.create_learner_share_code(current_setting('test.learner')::uuid,'105-share')->>'share_code'),true);

select set_config('request.jwt.claim.sub','a5333333-3333-3333-3333-333333333333',true);
select set_config('test.class',(public.create_class(null,current_setting('test.teacher')::uuid,'a5000000-0000-0000-0000-000000000001','Frontend Class 105','group',3,'105-class')->>'class_id'),true);
select public.activate_class(current_setting('test.class')::uuid,'105-activate');
select set_config('test.inv',(public.send_class_invitation_with_share_code(current_setting('test.class')::uuid,current_setting('test.share'),'₹600 / month','105-invite')->>'invitation_id'),true);

select set_config('request.jwt.claim.sub','a5111111-1111-1111-1111-111111111111',true);
select public.accept_class_invitation(current_setting('test.inv')::uuid,'105-accept');
do $$ declare n int; begin
  select count(*) into n from public.get_my_class_invitations();
  if n<>1 then raise exception 'CLASS_INVITATION_PROJECTION_MISSING:%',n; end if;
end $$;

select set_config('request.jwt.claim.sub','a5333333-3333-3333-3333-333333333333',true);
select public.send_class_learner_message(current_setting('test.class')::uuid,current_setting('test.learner')::uuid,'Teacher message 105','105-teacher-message');
do $$ declare t jsonb; begin
  t:=public.get_class_learner_thread(current_setting('test.class')::uuid,current_setting('test.learner')::uuid);
  if jsonb_array_length(t->'messages')<>1 then raise exception 'TEACHER_THREAD_PROJECTION_BAD:%',t; end if;
end $$;

select set_config('request.jwt.claim.sub','a5111111-1111-1111-1111-111111111111',true);
do $$ declare t jsonb; begin
  t:=public.get_class_learner_thread(current_setting('test.class')::uuid,current_setting('test.learner')::uuid);
  if t->>'learner_name'<>'Frontend Learner 105' then raise exception 'PARENT_THREAD_PROJECTION_BAD:%',t; end if;
end $$;

select set_config('request.jwt.claim.sub','a5222222-2222-2222-2222-222222222222',true);
do $$ declare t jsonb; begin
  t:=public.get_class_learner_thread(current_setting('test.class')::uuid,current_setting('test.learner')::uuid);
  if t->>'class_title'<>'Frontend Class 105' then raise exception 'SELF_THREAD_PROJECTION_BAD:%',t; end if;
end $$;

select set_config('request.jwt.claim.sub','a5444444-4444-4444-4444-444444444444',true);
do $$ begin
  perform public.get_class_learner_thread(current_setting('test.class')::uuid,current_setting('test.learner')::uuid);
  raise exception 'OUTSIDER_THREAD_PROJECTION_ALLOWED';
exception when others then if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if; end $$;

rollback;
select 'FRONTEND_CLASS_THREAD_PROJECTION_PASS' as result;
