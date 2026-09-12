-- Raahi Learning V1.2 — onboarding account commands runtime smoke.
-- Disposable dev suite; rolls back all fixtures.

begin;
insert into auth.users(id,aud,role,email) values
('93111111-1111-1111-1111-111111111111','authenticated','authenticated','onboarding1007@test.invalid');
set local role authenticated;
select set_config('request.jwt.claim.sub','93111111-1111-1111-1111-111111111111',true);
select set_config('test.account',(public.bootstrap_account('Before Name')->>'account_id'),true);
select public.enable_teaching('teach-1');
select public.enable_teaching('teach-1');
select public.update_account_profile('After Name','builtin','avatar-3','profile-1');
do $$ begin
  if not exists(select 1 from public.account_capabilities where account_id=current_setting('test.account')::uuid and capability_code='teach' and status='active') then raise exception 'TEACH_NOT_ENABLED'; end if;
  if (select display_name from public.accounts where id=current_setting('test.account')::uuid)<>'After Name' then raise exception 'PROFILE_NOT_UPDATED'; end if;
end $$;
reset role;
update public.account_capabilities set status='revoked',revoked_at=now() where account_id=current_setting('test.account')::uuid and capability_code='teach' and status='active';
set local role authenticated;
select set_config('request.jwt.claim.sub','93111111-1111-1111-1111-111111111111',true);
do $$ begin
  perform public.enable_teaching('teach-after-revoke');
  raise exception 'REVOKED_TEACH_SELF_REENABLED';
exception when others then if position('TEACHING_REENABLE_REQUIRES_REVIEW' in sqlerrm)=0 then raise; end if; end $$;
rollback;
select 'ONBOARDING_ACCOUNT_COMMANDS_PASS' as result;
