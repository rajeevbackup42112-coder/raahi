-- Raahi Learning V1.4E runtime smoke. Transaction wrapped; no residue.
begin;

insert into auth.users(id,aud,role,email) values
('8e111111-1111-1111-1111-111111111111','authenticated','authenticated','v14e-platform@test.invalid'),
('8e222222-2222-2222-2222-222222222222','authenticated','authenticated','v14e-manager@test.invalid'),
('8e333333-3333-3333-3333-333333333333','authenticated','authenticated','v14e-ordinary@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','8e111111-1111-1111-1111-111111111111',true);
select set_config('v14e.platform',(public.bootstrap_account('V14E Platform')->>'account_id'),true);
select set_config('request.jwt.claim.sub','8e222222-2222-2222-2222-222222222222',true);
select set_config('v14e.manager',(public.bootstrap_account('V14E Manager')->>'account_id'),true);
select set_config('request.jwt.claim.sub','8e333333-3333-3333-3333-333333333333',true);
select set_config('v14e.ordinary',(public.bootstrap_account('V14E Ordinary')->>'account_id'),true);
reset role;

insert into public.locations(id,name,slug,state,country_code)
values('8e444444-4444-4444-4444-444444444444','V14E Location','v14e-location','live','IN');

insert into public.account_capabilities(account_id,capability_code,status,granted_by_account_id)
values(current_setting('v14e.platform')::uuid,'platform_admin','active',current_setting('v14e.platform')::uuid);

insert into public.location_staff_assignments(location_id,account_id,staff_type,status)
values('8e444444-4444-4444-4444-444444444444',current_setting('v14e.manager')::uuid,'local_manager','active');

set local role authenticated;
select set_config('request.jwt.claim.sub','8e111111-1111-1111-1111-111111111111',true);

do $$
declare v_rows integer; v_manager_email text; v_resolved jsonb;
begin
  select count(*) into v_rows
  from public.get_platform_location_admins() x
  where x->>'location_id'='8e444444-4444-4444-4444-444444444444';
  if v_rows<>1 then raise exception 'PLATFORM_LOCATION_ADMIN_LIST_FAILED:%',v_rows; end if;

  select x->'local_managers'->0->>'email' into v_manager_email
  from public.get_platform_location_admins() x
  where x->>'location_id'='8e444444-4444-4444-4444-444444444444';
  if v_manager_email<>'v14e-manager@test.invalid' then raise exception 'PLATFORM_MANAGER_EMAIL_PROJECTION_FAILED:%',v_manager_email; end if;

  select public.resolve_platform_account_email('V14E-MANAGER@TEST.INVALID') into v_resolved;
  if not (v_resolved->>'found')::boolean then raise exception 'EXACT_EMAIL_RESOLVE_FAILED'; end if;
  if v_resolved->>'account_id'<>current_setting('v14e.manager') then raise exception 'EXACT_EMAIL_WRONG_ACCOUNT'; end if;

  select public.resolve_platform_account_email('missing-v14e@test.invalid') into v_resolved;
  if (v_resolved->>'found')::boolean then raise exception 'MISSING_EMAIL_RESOLVED'; end if;
end $$;

select set_config('request.jwt.claim.sub','8e333333-3333-3333-3333-333333333333',true);
do $$
begin
  perform public.get_platform_location_admins();
  raise exception 'ORDINARY_READ_LOCATION_ADMINS';
exception when others then
  if position('PLATFORM_ADMIN_REQUIRED' in sqlerrm)=0 then raise; end if;
end $$;
do $$
begin
  perform public.resolve_platform_account_email('v14e-manager@test.invalid');
  raise exception 'ORDINARY_RESOLVED_EMAIL';
exception when others then
  if position('PLATFORM_ADMIN_REQUIRED' in sqlerrm)=0 then raise; end if;
end $$;

rollback;
select 'V14E_GLOBAL_ADMIN_LOCATION_ADMIN_READS_PASS' as result;
