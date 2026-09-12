-- Raahi Learning V1.2 — registered upload cleanup runtime smoke.
-- Disposable dev suite; rolls back all fixtures.

begin;
insert into auth.users(id,aud,role,email) values
('92111111-1111-1111-1111-111111111111','authenticated','authenticated','fileowner1006@test.invalid'),
('92222222-2222-2222-2222-222222222222','authenticated','authenticated','fileother1006@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','92111111-1111-1111-1111-111111111111',true);
select set_config('test.owner',(public.bootstrap_account('File Owner')->>'account_id'),true);
select set_config('request.jwt.claim.sub','92222222-2222-2222-2222-222222222222',true);
select set_config('test.other',(public.bootstrap_account('File Other')->>'account_id'),true);

select set_config('request.jwt.claim.sub','92111111-1111-1111-1111-111111111111',true);
select set_config('test.file1',(public.register_file_asset('92111111-1111-1111-1111-111111111111/failed-upload.txt','profile_public','text/plain',10,'reg-1')->>'file_asset_id'),true);
select public.abandon_file_asset(current_setting('test.file1')::uuid,'abandon-1');
do $$ begin
  if (select status from public.file_assets where id=current_setting('test.file1')::uuid)<>'removed' then raise exception 'ABANDON_DID_NOT_REMOVE'; end if;
end $$;
select public.abandon_file_asset(current_setting('test.file1')::uuid,'abandon-2');

select set_config('request.jwt.claim.sub','92222222-2222-2222-2222-222222222222',true);
do $$ begin
  perform public.abandon_file_asset(current_setting('test.file1')::uuid,'other-abandon');
  raise exception 'OUTSIDER_ABANDON_ALLOWED';
exception when others then if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if; end $$;

reset role;
insert into public.account_capabilities(account_id,capability_code) values(current_setting('test.owner')::uuid,'teach');
set local role authenticated;
select set_config('request.jwt.claim.sub','92111111-1111-1111-1111-111111111111',true);
select set_config('test.file2',(public.register_file_asset('92111111-1111-1111-1111-111111111111/in-use.txt','class_material','text/plain',10,'reg-2')->>'file_asset_id'),true);
select public.create_material('In-use file',null,'file',current_setting('test.file2')::uuid,null,null,'mat-1');
do $$ begin
  perform public.abandon_file_asset(current_setting('test.file2')::uuid,'abandon-in-use');
  raise exception 'IN_USE_ABANDON_ALLOWED';
exception when others then if position('FILE_ASSET_IN_USE' in sqlerrm)=0 then raise; end if; end $$;

rollback;
select 'FILE_ASSET_ABANDON_RUNTIME_TESTS_PASS' as result;
