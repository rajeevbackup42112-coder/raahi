-- Raahi Learning V1.2 — governed Supabase Storage runtime smoke
-- Metadata-only object rows; entire suite rolls back.

begin;
insert into auth.users(id,aud,role,email) values
('b1111111-1111-1111-1111-111111111111','authenticated','authenticated','storage-parent@test.invalid'),
('b2222222-2222-2222-2222-222222222222','authenticated','authenticated','storage-outsider@test.invalid');
set local role authenticated;
select set_config('request.jwt.claim.sub','b1111111-1111-1111-1111-111111111111',true);
select set_config('test.parent',(public.bootstrap_account('Storage Parent')->>'account_id'),true);
select set_config('test.learner',(public.create_learner('Storage Learner','manage','none',null,'storage-learner')->>'learner_id'),true);
select set_config('request.jwt.claim.sub','b2222222-2222-2222-2222-222222222222',true);
select set_config('test.outsider',(public.bootstrap_account('Storage Outsider')->>'account_id'),true);

-- Registered Class-private upload: metadata reservation comes first, then object upload.
select set_config('request.jwt.claim.sub','b1111111-1111-1111-1111-111111111111',true);
select set_config('test.classfile',(public.register_file_asset('submissions/storage/work.jpg','activity_submission','image/jpeg',1000,'storage-file-1')->>'file_asset_id'),true);
insert into storage.objects(bucket_id,name,owner_id) values('class-private','submissions/storage/work.jpg','b1111111-1111-1111-1111-111111111111');
do $$ declare n int; begin select count(*) into n from storage.objects where bucket_id='class-private' and name='submissions/storage/work.jpg'; if n<>1 then raise exception 'OWNER_CANNOT_READ_REGISTERED_PRIVATE_OBJECT'; end if; end $$;

-- Copied private path is not authorization; outsider also cannot upload unregistered object.
select set_config('request.jwt.claim.sub','b2222222-2222-2222-2222-222222222222',true);
do $$ declare n int; begin select count(*) into n from storage.objects where bucket_id='class-private' and name='submissions/storage/work.jpg'; if n<>0 then raise exception 'COPIED_PRIVATE_PATH_BYPASSED_AUTHORIZATION'; end if; end $$;
do $$ begin insert into storage.objects(bucket_id,name,owner_id) values('class-private','submissions/storage/forged.jpg','b2222222-2222-2222-2222-222222222222'); raise exception 'UNREGISTERED_PRIVATE_UPLOAD_ALLOWED'; exception when insufficient_privilege then null; when check_violation then null; end $$;

-- Learner-private path authority follows current Learner relationship, not uploader identity alone.
select set_config('request.jwt.claim.sub','b1111111-1111-1111-1111-111111111111',true);
insert into storage.objects(bucket_id,name,owner_id) values('learner-private-media',current_setting('test.learner')||'/avatar.jpg','b1111111-1111-1111-1111-111111111111');
do $$ declare n int; begin select count(*) into n from storage.objects where bucket_id='learner-private-media' and name=current_setting('test.learner')||'/avatar.jpg'; if n<>1 then raise exception 'MANAGER_CANNOT_READ_LEARNER_PRIVATE_MEDIA'; end if; end $$;
select set_config('request.jwt.claim.sub','b2222222-2222-2222-2222-222222222222',true);
do $$ declare n int; begin select count(*) into n from storage.objects where bucket_id='learner-private-media' and name=current_setting('test.learner')||'/avatar.jpg'; if n<>0 then raise exception 'OUTSIDER_READ_LEARNER_PRIVATE_MEDIA'; end if; end $$;

-- Public profile path is owner-scoped for writes; bucket itself is deliberately public.
select set_config('request.jwt.claim.sub','b1111111-1111-1111-1111-111111111111',true);
insert into storage.objects(bucket_id,name,owner_id) values('public-profile-media',current_setting('test.parent')||'/profile.jpg','b1111111-1111-1111-1111-111111111111');
select set_config('request.jwt.claim.sub','b2222222-2222-2222-2222-222222222222',true);
do $$ begin insert into storage.objects(bucket_id,name,owner_id) values('public-profile-media',current_setting('test.parent')||'/forged.jpg','b2222222-2222-2222-2222-222222222222'); raise exception 'FOREIGN_PROFILE_PATH_WRITE_ALLOWED'; exception when insufficient_privilege then null; when check_violation then null; end $$;

-- Community public upload still requires registered metadata; Ads public is service-only.
select set_config('request.jwt.claim.sub','b1111111-1111-1111-1111-111111111111',true);
select public.register_file_asset('community/storage/resource.png','community_attachment','image/png',1200,'storage-community');
insert into storage.objects(bucket_id,name,owner_id) values('community-public','community/storage/resource.png','b1111111-1111-1111-1111-111111111111');
do $$ begin insert into storage.objects(bucket_id,name,owner_id) values('ads-public','draft-ad.png','b1111111-1111-1111-1111-111111111111'); raise exception 'AUTHENTICATED_ADS_PUBLIC_WRITE_ALLOWED'; exception when insufficient_privilege then null; when check_violation then null; end $$;

reset role;
do $$ begin
  if not (select public from storage.buckets where id='public-profile-media') then raise exception 'PUBLIC_PROFILE_BUCKET_NOT_PUBLIC'; end if;
  if not (select public from storage.buckets where id='community-public') then raise exception 'COMMUNITY_BUCKET_NOT_PUBLIC'; end if;
  if not (select public from storage.buckets where id='ads-public') then raise exception 'ADS_PUBLIC_BUCKET_NOT_PUBLIC'; end if;
  if (select public from storage.buckets where id='class-private') then raise exception 'CLASS_PRIVATE_BUCKET_PUBLIC'; end if;
  if (select public from storage.buckets where id='learner-private-media') then raise exception 'LEARNER_PRIVATE_BUCKET_PUBLIC'; end if;
  if (select public from storage.buckets where id='ads-review-private') then raise exception 'ADS_REVIEW_PRIVATE_BUCKET_PUBLIC'; end if;
end $$;

rollback;
select 'STORAGE_AUTHORIZATION_RUNTIME_TESTS_PASS' as result;
