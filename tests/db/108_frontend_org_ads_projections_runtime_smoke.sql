-- Raahi Learning V1.2 — frontend Organization + Ads projections runtime smoke.
-- Disposable dev suites; each fixture set rolls back.

begin;
insert into auth.users(id,aud,role,email) values
('b8111111-1111-1111-1111-111111111111','authenticated','authenticated','frontend108-owner@test.invalid'),
('b8222222-2222-2222-2222-222222222222','authenticated','authenticated','frontend108-member@test.invalid');
set local role authenticated;
select set_config('request.jwt.claim.sub','b8111111-1111-1111-1111-111111111111',true);
select set_config('test.owner',(public.bootstrap_account('Frontend Org Owner 108')->>'account_id'),true);
select set_config('request.jwt.claim.sub','b8222222-2222-2222-2222-222222222222',true);
select set_config('test.member',(public.bootstrap_account('Frontend Org Member 108')->>'account_id'),true);
select set_config('request.jwt.claim.sub','b8111111-1111-1111-1111-111111111111',true);
select set_config('test.org',(public.create_organization('academy','Frontend Academy 108','Education only',null,null,null,'none',null,'108-org')->>'organization_id'),true);
select set_config('test.member_row',(public.add_organization_member(current_setting('test.org')::uuid,current_setting('test.member')::uuid,'108-add-member')->>'member_id'),true);
select public.set_organization_member_capability(current_setting('test.member_row')::uuid,'manage_classes',true,'108-member-classes');
do $$ declare n int; begin
  select count(*) into n from public.get_organization_members(current_setting('test.org')::uuid);
  if n<>2 then raise exception 'ORG_MEMBER_PROJECTION_COUNT_BAD:%',n; end if;
end $$;
select set_config('request.jwt.claim.sub','b8222222-2222-2222-2222-222222222222',true);
do $$ begin
  perform public.get_organization_members(current_setting('test.org')::uuid);
  raise exception 'NON_MANAGER_MEMBER_LIST_ALLOWED';
exception when others then if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if; end $$;
rollback;
select 'FRONTEND_ORG_MEMBERS_PROJECTION_PASS' as result;

begin;
insert into auth.users(id,aud,role,email) values
('b8311111-1111-1111-1111-111111111111','authenticated','authenticated','frontend108-advertiser@test.invalid'),
('b8333333-3333-3333-3333-333333333333','authenticated','authenticated','frontend108-manager@test.invalid'),
('b8444444-4444-4444-4444-444444444444','authenticated','authenticated','frontend108-platform@test.invalid');
set local role authenticated;
select set_config('request.jwt.claim.sub','b8311111-1111-1111-1111-111111111111',true);
select set_config('test.advertiser',(public.bootstrap_account('Frontend Advertiser 108')->>'account_id'),true);
select set_config('request.jwt.claim.sub','b8333333-3333-3333-3333-333333333333',true);
select set_config('test.manager',(public.bootstrap_account('Frontend Manager 108')->>'account_id'),true);
select set_config('request.jwt.claim.sub','b8444444-4444-4444-4444-444444444444',true);
select set_config('test.platform',(public.bootstrap_account('Frontend Platform 108')->>'account_id'),true);
reset role;
insert into public.account_capabilities(account_id,capability_code) values(current_setting('test.platform')::uuid,'platform_admin');
insert into public.locations(id,name,slug,state,country_code) values('b8000000-0000-0000-0000-000000000001','Frontend Ads 108','frontend-ads-108','live','IN');
set local role authenticated;
select set_config('request.jwt.claim.sub','b8444444-4444-4444-4444-444444444444',true);
select public.set_advertising_eligibility(current_setting('test.advertiser')::uuid,null,'enabled','Integration smoke','108-eligibility');
select public.assign_local_manager('b8000000-0000-0000-0000-000000000001',current_setting('test.manager')::uuid,'108-manager');
select set_config('request.jwt.claim.sub','b8311111-1111-1111-1111-111111111111',true);
select set_config('test.campaign',(public.create_ad_campaign(current_setting('test.advertiser')::uuid,null,'awareness','Frontend Campaign 108',null,'Education',now()+interval '1 day',now()+interval '8 days','108-campaign')->>'campaign_id'),true);
select public.set_ad_campaign_targets(current_setting('test.campaign')::uuid,jsonb_build_array(jsonb_build_object('location_id','b8000000-0000-0000-0000-000000000001','placement_type','home_sponsored')),'108-targets');
select set_config('test.revision',(public.create_ad_campaign_revision(current_setting('test.campaign')::uuid,'Education 108','Education-only sponsored content',null,'external_url',null,'https://example.invalid','learn_more','108-revision')->>'revision_id'),true);
select public.submit_ad_campaign_revision(current_setting('test.revision')::uuid,'108-submit');
do $$ declare n int; w jsonb; begin
  select count(*) into n from public.get_my_ad_campaigns();
  if n<>1 then raise exception 'MY_AD_CAMPAIGNS_BAD:%',n; end if;
  w:=public.get_ad_campaign_workspace(current_setting('test.campaign')::uuid);
  if w #>> '{campaign,campaign_name}'<>'Frontend Campaign 108' or jsonb_array_length(w->'revisions')<>1 then raise exception 'AD_WORKSPACE_BAD:%',w; end if;
end $$;
select set_config('request.jwt.claim.sub','b8333333-3333-3333-3333-333333333333',true);
do $$ declare n int; begin
  select count(*) into n from public.get_ad_review_queue('b8000000-0000-0000-0000-000000000001');
  if n<>1 then raise exception 'LOCAL_REVIEW_QUEUE_BAD:%',n; end if;
end $$;
select set_config('request.jwt.claim.sub','b8444444-4444-4444-4444-444444444444',true);
do $$ declare n int; w jsonb; begin
  select count(*) into n from public.get_ad_review_queue(null);
  if n<>1 then raise exception 'PLATFORM_REVIEW_QUEUE_BAD:%',n; end if;
  w:=public.get_ad_campaign_workspace(current_setting('test.campaign')::uuid);
  if w is null then raise exception 'PLATFORM_WORKSPACE_MISSING'; end if;
end $$;
rollback;
select 'FRONTEND_ADS_PROJECTIONS_PASS' as result;
