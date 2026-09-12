-- Raahi Learning V1.2 — Locations post-hardening smoke
-- Run only in disposable/dev environment. Entire suite rolls back.

begin;

insert into auth.users(id,aud,role,email) values
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','authenticated','authenticated','admin2@test.invalid'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','authenticated','authenticated','manager2@test.invalid'),
('cccccccc-cccc-cccc-cccc-cccccccccccc','authenticated','authenticated','member2@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',true);
select set_config('test.admin',(public.bootstrap_account('Admin 2')->>'account_id'),true);
select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',true);
select set_config('test.manager',(public.bootstrap_account('Manager 2')->>'account_id'),true);
select set_config('request.jwt.claim.sub','cccccccc-cccc-cccc-cccc-cccccccccccc',true);
select set_config('test.member',(public.bootstrap_account('Member 2')->>'account_id'),true);
reset role;
insert into public.account_capabilities(account_id,capability_code,status)
values (current_setting('test.admin',true)::uuid,'platform_admin','active');

set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',true);
select set_config('test.loc',(public.create_location('Lifecycle Test','lifecycle-test',null,'Jharkhand','IN','{}'::jsonb,'life-create')->>'location_id'),true);
select set_config('test.retired',(public.create_location('Retired Scope Test','retired-scope-test',null,'Jharkhand','IN','{}'::jsonb,'ret-create')->>'location_id'),true);
select public.set_location_state(current_setting('test.retired',true)::uuid,'retired','retire','ret-state');
select public.set_location_state(current_setting('test.loc',true)::uuid,'preparing','prep','life-state-1');

select set_config('request.jwt.claim.sub','cccccccc-cccc-cccc-cccc-cccccccccccc',true);
select public.register_location_interest(current_setting('test.loc',true)::uuid,'learn','prep-interest-2');

select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',true);
select public.set_location_state(current_setting('test.loc',true)::uuid,'live','launch','life-state-2');
select public.set_location_state(current_setting('test.loc',true)::uuid,'paused','pause','life-state-3');

select set_config('request.jwt.claim.sub','cccccccc-cccc-cccc-cccc-cccccccccccc',true);
do $$
begin
  perform public.register_location_interest(current_setting('test.loc',true)::uuid,'teach','paused-interest');
  raise exception 'PAUSED_LOCATION_ACCEPTED_INTEREST';
exception when others then
  if position('LOCATION_NOT_ACCEPTING_INTEREST' in sqlerrm)=0 then raise; end if;
end $$;

select public.set_selected_location(current_setting('test.loc',true)::uuid,'member-select');
do $$
declare v_pref integer;
begin
  select count(*) into v_pref from public.account_location_preferences
  where account_id=current_setting('test.admin',true)::uuid;
  if v_pref <> 0 then raise exception 'CROSS_ACCOUNT_PREFERENCE_VISIBLE'; end if;
end $$;

do $$
begin
  insert into public.location_staff_assignments(location_id,account_id,staff_type)
  values(current_setting('test.loc',true)::uuid,current_setting('test.manager',true)::uuid,'local_manager');
  raise exception 'DIRECT_STAFF_WRITE_ALLOWED';
exception when insufficient_privilege then null;
end $$;

select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',true);
do $$
begin
  perform public.assign_local_manager(current_setting('test.retired',true)::uuid,current_setting('test.manager',true)::uuid,'retired-assign');
  raise exception 'RETIRED_LOCATION_GOT_MANAGER';
exception when others then
  if position('LOCATION_RETIRED' in sqlerrm)=0 then raise; end if;
end $$;

select public.set_location_state(current_setting('test.loc',true)::uuid,'live','resume','life-state-4');

-- Consolidated post-0204 policy behavior.
select set_config('request.jwt.claim.sub','cccccccc-cccc-cccc-cccc-cccccccccccc',true);
do $$
declare v_count integer;
begin
  select count(*) into v_count from public.locations where id=current_setting('test.retired',true)::uuid;
  if v_count <> 0 then raise exception 'CONSOLIDATED_RLS_LEAKED_RETIRED'; end if;
end $$;

select set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',true);
do $$
declare v_count integer;
begin
  select count(*) into v_count from public.locations where id=current_setting('test.retired',true)::uuid;
  if v_count <> 1 then raise exception 'CONSOLIDATED_RLS_BLOCKED_ADMIN'; end if;
end $$;

rollback;
select 'LOCATIONS_POST_HARDENING_SMOKE_PASS' as result;