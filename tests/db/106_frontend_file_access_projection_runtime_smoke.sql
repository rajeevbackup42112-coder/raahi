-- Raahi Learning V1.2 — authorized file-coordinate projection runtime smoke.
-- Disposable dev suite; all fixtures roll back.

begin;
insert into auth.users(id,aud,role,email) values
('a6111111-1111-1111-1111-111111111111','authenticated','authenticated','frontend106-owner@test.invalid'),
('a6222222-2222-2222-2222-222222222222','authenticated','authenticated','frontend106-outsider@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','a6111111-1111-1111-1111-111111111111',true);
select set_config('test.owner',(public.bootstrap_account('Frontend File Owner 106')->>'account_id'),true);
select set_config('test.private',(public.register_file_asset('submissions/106/work.jpg','activity_submission','image/jpeg',1234,'106-private')->>'file_asset_id'),true);
select set_config('test.public',(public.register_file_asset('a6111111-1111-1111-1111-111111111111/profile-106.jpg','profile_public','image/jpeg',456,'106-public')->>'file_asset_id'),true);

do $$ declare a jsonb; begin
  a:=public.get_file_asset_access(current_setting('test.private')::uuid);
  if a->>'bucket_id'<>'class-private' or (a->>'public_bucket')::boolean is not false then raise exception 'PRIVATE_FILE_COORDINATES_BAD:%',a; end if;
  a:=public.get_file_asset_access(current_setting('test.public')::uuid);
  if a->>'bucket_id'<>'public-profile-media' or (a->>'public_bucket')::boolean is not true then raise exception 'PUBLIC_FILE_COORDINATES_BAD:%',a; end if;
end $$;

select set_config('request.jwt.claim.sub','a6222222-2222-2222-2222-222222222222',true);
select public.bootstrap_account('Frontend File Outsider 106');
do $$ begin
  perform public.get_file_asset_access(current_setting('test.private')::uuid);
  raise exception 'OUTSIDER_PRIVATE_FILE_COORDINATES_ALLOWED';
exception when others then if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if; end $$;

rollback;
select 'FRONTEND_FILE_ACCESS_PROJECTION_PASS' as result;
