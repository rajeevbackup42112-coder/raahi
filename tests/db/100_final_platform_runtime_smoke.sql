-- Raahi Learning V1.2 — final derived operations / projections / closure / privilege smoke
-- Dev/disposable only; entire suite rolls back.

begin;

insert into auth.users(id,aud,role,email) values
('a1111111-1111-1111-1111-111111111111','authenticated','authenticated','teacher-final@test.invalid'),
('a2222222-2222-2222-2222-222222222222','authenticated','authenticated','parent-final@test.invalid'),
('a3333333-3333-3333-3333-333333333333','authenticated','authenticated','outsider-final@test.invalid'),
('a4444444-4444-4444-4444-444444444444','authenticated','authenticated','manager-final@test.invalid'),
('a5555555-5555-5555-5555-555555555555','authenticated','authenticated','admin-final@test.invalid'),
('a6666666-6666-6666-6666-666666666666','authenticated','authenticated','closable-final@test.invalid'),
('a7777777-7777-7777-7777-777777777777','authenticated','authenticated','othermanager-final@test.invalid'),
('a8888888-8888-8888-8888-888888888888','authenticated','authenticated','adowner-final@test.invalid'),
('a9999999-9999-9999-9999-999999999999','authenticated','authenticated','safety-target@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','a1111111-1111-1111-1111-111111111111',true); select set_config('test.teacher',(public.bootstrap_account('Final Teacher')->>'account_id'),true);
select set_config('request.jwt.claim.sub','a2222222-2222-2222-2222-222222222222',true); select set_config('test.parent',(public.bootstrap_account('Final Parent')->>'account_id'),true);
select set_config('request.jwt.claim.sub','a3333333-3333-3333-3333-333333333333',true); select set_config('test.outsider',(public.bootstrap_account('Final Outsider')->>'account_id'),true);
select set_config('request.jwt.claim.sub','a4444444-4444-4444-4444-444444444444',true); select set_config('test.manager',(public.bootstrap_account('Final Local Manager')->>'account_id'),true);
select set_config('request.jwt.claim.sub','a5555555-5555-5555-5555-555555555555',true); select set_config('test.admin',(public.bootstrap_account('Final Platform Admin')->>'account_id'),true);
select set_config('request.jwt.claim.sub','a6666666-6666-6666-6666-666666666666',true); select set_config('test.closable',(public.bootstrap_account('Closable Member')->>'account_id'),true);
select set_config('request.jwt.claim.sub','a7777777-7777-7777-7777-777777777777',true); select set_config('test.othermanager',(public.bootstrap_account('Other Org Manager')->>'account_id'),true);
select set_config('request.jwt.claim.sub','a8888888-8888-8888-8888-888888888888',true); select set_config('test.adowner',(public.bootstrap_account('Ad Owner')->>'account_id'),true);
select set_config('request.jwt.claim.sub','a9999999-9999-9999-9999-999999999999',true); select set_config('test.safety_target',(public.bootstrap_account('Safety Target')->>'account_id'),true);

reset role;
insert into public.account_capabilities(account_id,capability_code) values
(current_setting('test.teacher')::uuid,'teach'),
(current_setting('test.admin')::uuid,'platform_admin');
insert into public.locations(id,name,slug,state,country_code) values
('a0000000-0000-0000-0000-000000000001','Dhanbad','final-dhanbad','live','IN'),
('a0000000-0000-0000-0000-000000000002','Gomoh','final-gomoh','live','IN'),
('a0000000-0000-0000-0000-000000000003','Future Place','final-future','preparing','IN');
insert into public.location_staff_assignments(location_id,account_id,staff_type,status) values
('a0000000-0000-0000-0000-000000000001',current_setting('test.manager')::uuid,'local_manager','active');
insert into public.learners(id,display_name,avatar_type,created_by_account_id) values
('a0000000-0000-0000-0000-000000000010','Final Learner','none',current_setting('test.parent')::uuid);
insert into public.account_learner_access(account_id,learner_id,access_type,status) values
(current_setting('test.parent')::uuid,'a0000000-0000-0000-0000-000000000010','manage','active');

-- Representative Class relationship used to verify UI read projections and deep-link guards.
set local role authenticated;
select set_config('request.jwt.claim.sub','a1111111-1111-1111-1111-111111111111',true);
select set_config('test.class',(public.create_class(null,current_setting('test.teacher')::uuid,'a0000000-0000-0000-0000-000000000001','Final Maths Class','group',5,'final-class')->>'class_id'),true);
select public.activate_class(current_setting('test.class')::uuid,'final-class-active');
reset role;
insert into public.class_memberships(class_id,learner_id,state) values(current_setting('test.class')::uuid,'a0000000-0000-0000-0000-000000000010','active');
insert into public.class_posts(class_id,author_account_id,post_type,body,importance,comments_enabled,visibility_status) values(current_setting('test.class')::uuid,current_setting('test.teacher')::uuid,'announcement','Welcome to class','normal',true,'visible');

-- Parent sees own Class projection; unrelated account cannot deep-link into it.
set local role authenticated;
select set_config('request.jwt.claim.sub','a2222222-2222-2222-2222-222222222222',true);
do $$ declare n int; x jsonb; begin
  select count(*) into n from public.get_my_classes(); if n<>1 then raise exception 'MY_CLASSES_PARENT_BAD:%',n; end if;
  x:=public.get_class_learning_overview(current_setting('test.class')::uuid,'a0000000-0000-0000-0000-000000000010');
  if x #>> '{class,title}' <> 'Final Maths Class' then raise exception 'CLASS_OVERVIEW_BAD:%',x; end if;
end $$;
select set_config('request.jwt.claim.sub','a3333333-3333-3333-3333-333333333333',true);
do $$ declare n int; begin
  select count(*) into n from public.get_my_classes(); if n<>0 then raise exception 'OUTSIDER_MY_CLASSES_LEAK'; end if;
  begin perform public.get_class_learning_overview(current_setting('test.class')::uuid,'a0000000-0000-0000-0000-000000000010'); raise exception 'OUTSIDER_CLASS_DEEPLINK_ALLOWED';
  exception when others then if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if; end;
end $$;

-- Teacher roster projection is provider-only.
select set_config('request.jwt.claim.sub','a1111111-1111-1111-1111-111111111111',true);
do $$ declare x jsonb; begin x:=public.get_teacher_class_management(current_setting('test.class')::uuid); if jsonb_array_length(x->'members')<>1 then raise exception 'TEACHER_ROSTER_BAD:%',x; end if; end $$;
select set_config('request.jwt.claim.sub','a2222222-2222-2222-2222-222222222222',true);
do $$ begin perform public.get_teacher_class_management(current_setting('test.class')::uuid); raise exception 'PARENT_TEACHER_DASHBOARD_ALLOWED'; exception when others then if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if; end $$;

-- Local Manager scope is exact; Platform operations remain Platform-only.
select set_config('request.jwt.claim.sub','a4444444-4444-4444-4444-444444444444',true);
do $$ declare x jsonb; begin x:=public.get_local_manager_overview('a0000000-0000-0000-0000-000000000001'); if (x->>'active_classes')::int<>1 then raise exception 'LOCAL_MANAGER_OVERVIEW_BAD:%',x; end if; end $$;
do $$ begin perform public.get_local_manager_overview('a0000000-0000-0000-0000-000000000002'); raise exception 'LOCAL_MANAGER_CROSS_LOCATION_ALLOWED'; exception when others then if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if; end $$;
do $$ begin perform public.get_platform_operations_summary(); raise exception 'LOCAL_MANAGER_PLATFORM_SUMMARY_ALLOWED'; exception when others then if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if; end $$;
select set_config('request.jwt.claim.sub','a5555555-5555-5555-5555-555555555555',true);
do $$ declare x jsonb; begin x:=public.get_platform_operations_summary(); if (x->>'locations')::int<3 then raise exception 'PLATFORM_SUMMARY_BAD:%',x; end if; end $$;

-- Live Location projection does not publish preparing Location as live.
select set_config('request.jwt.claim.sub','a3333333-3333-3333-3333-333333333333',true);
do $$ declare n int; begin select count(*) into n from public.list_live_locations(); if n<>2 then raise exception 'LIVE_LOCATION_PROJECTION_BAD:%',n; end if; end $$;

-- Notifications are derived, private to recipient, and sponsored viewer pushes are forbidden.
reset role;
select set_config('test.notification',app_private.enqueue_notification(current_setting('test.parent')::uuid,'a0000000-0000-0000-0000-000000000010','class_update','class',current_setting('test.class')::uuid,'Class update','New class announcement','{}'::jsonb)::text,true);
do $$ begin
  perform app_private.enqueue_notification(current_setting('test.parent')::uuid,'a0000000-0000-0000-0000-000000000010','sponsored_offer','ad_campaign',null,'Sponsored','Buy now','{}'::jsonb);
  raise exception 'SPONSORED_PUSH_ALLOWED';
exception when others then if position('SPONSORED_PUSH_NOT_ALLOWED' in sqlerrm)=0 then raise; end if; end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','a2222222-2222-2222-2222-222222222222',true);
do $$ declare n int; begin select count(*) into n from public.get_my_notifications(50); if n<>1 then raise exception 'RECIPIENT_NOTIFICATION_MISSING'; end if; end $$;
select public.mark_notification_read(current_setting('test.notification')::uuid,'read-notification');
select set_config('request.jwt.claim.sub','a3333333-3333-3333-3333-333333333333',true);
do $$ declare n int; begin select count(*) into n from public.get_my_notifications(50); if n<>0 then raise exception 'OUTSIDER_NOTIFICATION_LEAK'; end if; end $$;

-- Final Account closure blockers include Class, Local Manager, Ads and safety obligations.
select set_config('request.jwt.claim.sub','a1111111-1111-1111-1111-111111111111',true);
do $$ declare x jsonb; begin x:=public.request_account_closure('close-teacher-blocked'); if (x->>'closed')::boolean or x::text not like '%RESPONSIBLE_TEACHER_ACTIVE_CLASS%' then raise exception 'ACTIVE_CLASS_CLOSURE_BLOCKER_MISSING:%',x; end if; end $$;
select set_config('request.jwt.claim.sub','a4444444-4444-4444-4444-444444444444',true);
do $$ declare x jsonb; begin x:=public.request_account_closure('close-manager-blocked'); if (x->>'closed')::boolean or x::text not like '%ACTIVE_LOCAL_MANAGER_ASSIGNMENT%' then raise exception 'LOCAL_MANAGER_CLOSURE_BLOCKER_MISSING:%',x; end if; end $$;
reset role;
insert into public.ad_campaigns(account_id,objective,campaign_name,starts_at,ends_at,state,created_by_account_id)
values(current_setting('test.adowner')::uuid,'awareness','Closure Campaign',now(),now()+interval '1 day','submitted',current_setting('test.adowner')::uuid);
insert into public.reports(reporter_account_id,location_id,target_type,target_id,reason_code,details,status)
values(current_setting('test.admin')::uuid,'a0000000-0000-0000-0000-000000000001','account',current_setting('test.safety_target')::uuid,'SAFETY_REVIEW','Open review','open');
set local role authenticated;
select set_config('request.jwt.claim.sub','a8888888-8888-8888-8888-888888888888',true);
do $$ declare x jsonb; begin x:=public.request_account_closure('close-adowner-blocked'); if (x->>'closed')::boolean or x::text not like '%ACTIVE_ACCOUNT_AD_CAMPAIGN%' then raise exception 'AD_CLOSURE_BLOCKER_MISSING:%',x; end if; end $$;
select set_config('request.jwt.claim.sub','a9999999-9999-9999-9999-999999999999',true);
do $$ declare x jsonb; begin x:=public.request_account_closure('close-safety-blocked'); if (x->>'closed')::boolean or x::text not like '%UNRESOLVED_SAFETY_REVIEW%' then raise exception 'SAFETY_CLOSURE_BLOCKER_MISSING:%',x; end if; end $$;

-- Successful closure ends non-blocking Organization authority and withdraws launch interest.
reset role;
insert into public.organizations(id,organization_type,name,logo_type,status,created_by_account_id)
values('a0000000-0000-0000-0000-000000000050','academy','Closure Academy','none','active',current_setting('test.closable')::uuid);
insert into public.organization_members(id,organization_id,account_id,status) values
('a0000000-0000-0000-0000-000000000051','a0000000-0000-0000-0000-000000000050',current_setting('test.closable')::uuid,'active'),
('a0000000-0000-0000-0000-000000000052','a0000000-0000-0000-0000-000000000050',current_setting('test.othermanager')::uuid,'active');
insert into public.organization_member_capabilities(organization_member_id,capability_code) values
('a0000000-0000-0000-0000-000000000051','manage_members'),
('a0000000-0000-0000-0000-000000000052','manage_members');
insert into public.location_interests(location_id,account_id,intent_type,state)
values('a0000000-0000-0000-0000-000000000003',current_setting('test.closable')::uuid,'learn','active');
set local role authenticated;
select set_config('request.jwt.claim.sub','a6666666-6666-6666-6666-666666666666',true);
do $$ declare x jsonb; begin x:=public.request_account_closure('close-clean'); if not (x->>'closed')::boolean then raise exception 'NONBLOCKED_CLOSURE_FAILED:%',x; end if; end $$;
reset role;
do $$ begin
  if (select lifecycle_status from public.accounts where id=current_setting('test.closable')::uuid)<>'closed' then raise exception 'ACCOUNT_NOT_CLOSED'; end if;
  if exists(select 1 from public.organization_members where account_id=current_setting('test.closable')::uuid and status='active') then raise exception 'CLOSED_ACCOUNT_LEFT_ACTIVE_ORG_MEMBERSHIP'; end if;
  if exists(select 1 from public.location_interests where account_id=current_setting('test.closable')::uuid and state='active') then raise exception 'CLOSED_ACCOUNT_LEFT_ACTIVE_LOCATION_INTEREST'; end if;
end $$;

-- Privilege hardening: authenticated has no direct DML on any public table;
-- PUBLIC has no execute on app_private functions; all SECURITY DEFINER functions pin search_path.
do $$ declare n int; begin
  select count(*) into n from pg_class c join pg_namespace ns on ns.oid=c.relnamespace
   where ns.nspname='public' and c.relkind in ('r','p') and (
     has_table_privilege('authenticated',c.oid,'INSERT') or has_table_privilege('authenticated',c.oid,'UPDATE') or has_table_privilege('authenticated',c.oid,'DELETE'));
  if n<>0 then raise exception 'AUTHENTICATED_DIRECT_DML_GRANTS_REMAIN:%',n; end if;

  select count(*) into n from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace,
    lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
   where ns.nspname='app_private' and a.grantee=0 and a.privilege_type='EXECUTE';
  if n<>0 then raise exception 'PUBLIC_EXECUTE_REMAINS_ON_APP_PRIVATE:%',n; end if;

  select count(*) into n from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace
   where ns.nspname in ('public','app_private') and p.prosecdef
     and not exists(select 1 from unnest(coalesce(p.proconfig,array[]::text[])) x where x like 'search_path=%');
  if n<>0 then raise exception 'SECURITY_DEFINER_WITHOUT_FIXED_SEARCH_PATH:%',n; end if;
end $$;

rollback;
select 'FINAL_PLATFORM_RUNTIME_TESTS_PASS' as result;
