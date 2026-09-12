-- Raahi Learning V1.2 — Ads inventory / serving runtime smoke
-- Dev/disposable only; entire suite rolls back.

begin;

insert into auth.users(id,aud,role,email) values
('91111111-1111-1111-1111-111111111111','authenticated','authenticated','advertiser@test.invalid'),
('92222222-2222-2222-2222-222222222222','authenticated','authenticated','viewer@test.invalid'),
('93333333-3333-3333-3333-333333333333','authenticated','authenticated','adsops@test.invalid'),
('94444444-4444-4444-4444-444444444444','authenticated','authenticated','reviewer@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','91111111-1111-1111-1111-111111111111',true);
select set_config('test.advertiser',(public.bootstrap_account('Advertiser Teacher')->>'account_id'),true);
select set_config('request.jwt.claim.sub','92222222-2222-2222-2222-222222222222',true);
select set_config('test.viewer',(public.bootstrap_account('Viewer Parent')->>'account_id'),true);
select set_config('request.jwt.claim.sub','93333333-3333-3333-3333-333333333333',true);
select set_config('test.ops',(public.bootstrap_account('Ads Commercial Ops')->>'account_id'),true);
select set_config('request.jwt.claim.sub','94444444-4444-4444-4444-444444444444',true);
select set_config('test.reviewer',(public.bootstrap_account('Platform Reviewer')->>'account_id'),true);

reset role;
insert into public.account_capabilities(account_id,capability_code) values
(current_setting('test.advertiser')::uuid,'teach'),
(current_setting('test.ops')::uuid,'ads_commercial'),
(current_setting('test.reviewer')::uuid,'platform_admin');
insert into public.locations(id,name,slug,state,country_code) values
('90000000-0000-0000-0000-000000000001','Dhanbad','ads-dhanbad','live','IN');
insert into public.learners(id,display_name,avatar_type,created_by_account_id) values
('90000000-0000-0000-0000-000000000010','Rahul','none',current_setting('test.viewer')::uuid);
insert into public.account_learner_access(account_id,learner_id,access_type,status) values
(current_setting('test.viewer')::uuid,'90000000-0000-0000-0000-000000000010','manage','active');

-- Advertiser creates public teaching supply.
set local role authenticated;
select set_config('request.jwt.claim.sub','91111111-1111-1111-1111-111111111111',true);
select public.upsert_teacher_profile('Maths Teacher','Local Maths tuition','10 years','visible','ads-profile');
select set_config('test.option',(public.publish_teaching_option(null,'Maths Tuition','Academics','Maths coaching','both','Dhanbad','₹1000/month',array['90000000-0000-0000-0000-000000000001']::uuid[],'ads-option')->>'teaching_option_id'),true);

-- Eligibility is separate from policy review and commercial clearance.
select set_config('request.jwt.claim.sub','93333333-3333-3333-3333-333333333333',true);
select public.set_advertising_eligibility(current_setting('test.advertiser')::uuid,null,'enabled',null,'eligibility-1');

-- Campaign 1, exact Revision 1, policy approval, commercial clearance.
select set_config('request.jwt.claim.sub','91111111-1111-1111-1111-111111111111',true);
select set_config('test.c1',(public.create_ad_campaign(current_setting('test.advertiser')::uuid,null,'admissions','Fractions Admissions',null,'Academics',now()-interval '1 hour',now()+interval '4 days','c1-create')->>'campaign_id'),true);
select public.set_ad_campaign_targets(current_setting('test.c1')::uuid,jsonb_build_array(jsonb_build_object('location_id','90000000-0000-0000-0000-000000000001','placement_type','home_sponsored')),'c1-targets');
select set_config('test.r1',(public.create_ad_campaign_revision(current_setting('test.c1')::uuid,'Learn Fractions','Friendly local Maths support',null,'teaching_option',current_setting('test.option')::uuid,null,'enquire','c1-r1')->>'revision_id'),true);
select public.submit_ad_campaign_revision(current_setting('test.r1')::uuid,'c1-r1-submit');

select set_config('request.jwt.claim.sub','94444444-4444-4444-4444-444444444444',true);
select public.review_ad_campaign_revision(current_setting('test.r1')::uuid,'platform',null,'approved','EDUCATION_RELEVANT',null,'review-r1');
select set_config('request.jwt.claim.sub','93333333-3333-3333-3333-333333333333',true);
select public.confirm_ad_commercial_clearance(current_setting('test.c1')::uuid,'waiver','TEST-WAIVER',0,'INR','Runtime test','clear-c1');

-- Configure two daily buckets: capacity 2; each campaign can hold at most 1 unit; each viewer max 2 impressions/day.
select public.configure_ad_inventory_day('90000000-0000-0000-0000-000000000001','home_sponsored',current_date,2,1,2,'TEST-RATE','inv-day-1');
select public.configure_ad_inventory_day('90000000-0000-0000-0000-000000000001','home_sponsored',current_date+1,2,1,2,'TEST-RATE','inv-day-2');

-- Advertiser reserves one unit across both days. Retry returns same logical reservation.
select set_config('request.jwt.claim.sub','91111111-1111-1111-1111-111111111111',true);
select set_config('test.res1',(public.reserve_ad_inventory(current_setting('test.c1')::uuid,'90000000-0000-0000-0000-000000000001','home_sponsored',current_date,current_date+1,1,'reserve-c1')->>'reservation_id'),true);
do $$ declare a uuid; b uuid; begin
  a:=current_setting('test.res1')::uuid;
  b:=(public.reserve_ad_inventory(current_setting('test.c1')::uuid,'90000000-0000-0000-0000-000000000001','home_sponsored',current_date,current_date+1,1,'reserve-c1')->>'reservation_id')::uuid;
  if a<>b then raise exception 'RESERVE_RETRY_DUPLICATED'; end if;
end $$;

-- Same Campaign cannot monopolize second unit because max_units_per_campaign=1.
do $$ begin
  perform public.reserve_ad_inventory(current_setting('test.c1')::uuid,'90000000-0000-0000-0000-000000000001','home_sponsored',current_date,current_date+1,1,'reserve-c1-over');
  raise exception 'CAMPAIGN_CONCENTRATION_LIMIT_BYPASSED';
exception when others then if position('AD_CAMPAIGN_CONCENTRATION_LIMIT' in sqlerrm)=0 then raise; end if; end $$;

-- Campaign 2 fills the remaining physical unit.
select set_config('test.c2',(public.create_ad_campaign(current_setting('test.advertiser')::uuid,null,'awareness','Second Campaign',null,'Academics',now()-interval '1 hour',now()+interval '4 days','c2-create')->>'campaign_id'),true);
select public.set_ad_campaign_targets(current_setting('test.c2')::uuid,jsonb_build_array(jsonb_build_object('location_id','90000000-0000-0000-0000-000000000001','placement_type','home_sponsored')),'c2-targets');
select set_config('test.c2r',(public.create_ad_campaign_revision(current_setting('test.c2')::uuid,'Second Creative','Second education campaign',null,'teaching_option',current_setting('test.option')::uuid,null,'enquire','c2-r1')->>'revision_id'),true);
select public.submit_ad_campaign_revision(current_setting('test.c2r')::uuid,'c2-submit');
select set_config('test.res2',(public.reserve_ad_inventory(current_setting('test.c2')::uuid,'90000000-0000-0000-0000-000000000001','home_sponsored',current_date,current_date+1,1,'reserve-c2')->>'reservation_id'),true);

-- Third Campaign cannot oversell either day.
select set_config('test.c3',(public.create_ad_campaign(current_setting('test.advertiser')::uuid,null,'awareness','Third Campaign',null,'Academics',now()-interval '1 hour',now()+interval '4 days','c3-create')->>'campaign_id'),true);
select public.set_ad_campaign_targets(current_setting('test.c3')::uuid,jsonb_build_array(jsonb_build_object('location_id','90000000-0000-0000-0000-000000000001','placement_type','home_sponsored')),'c3-targets');
select set_config('test.c3r',(public.create_ad_campaign_revision(current_setting('test.c3')::uuid,'Third Creative','Third education campaign',null,'teaching_option',current_setting('test.option')::uuid,null,'enquire','c3-r1')->>'revision_id'),true);
select public.submit_ad_campaign_revision(current_setting('test.c3r')::uuid,'c3-submit');
do $$ begin
  perform public.reserve_ad_inventory(current_setting('test.c3')::uuid,'90000000-0000-0000-0000-000000000001','home_sponsored',current_date,current_date+1,1,'reserve-c3-full');
  raise exception 'INVENTORY_OVERSELL_ALLOWED';
exception when others then if position('AD_INVENTORY_CAPACITY_UNAVAILABLE' in sqlerrm)=0 then raise; end if; end $$;

-- Missing required bucket causes whole multi-day request to fail, never partial booking.
do $$ declare before_n int; after_n int; begin
  reset role;
  select count(*) into before_n from public.ad_inventory_reservations;
  set local role authenticated;
  perform set_config('request.jwt.claim.sub','91111111-1111-1111-1111-111111111111',true);
  begin
    perform public.reserve_ad_inventory(current_setting('test.c3')::uuid,'90000000-0000-0000-0000-000000000001','home_sponsored',current_date+1,current_date+2,1,'reserve-missing-day');
    raise exception 'PARTIAL_RESERVATION_ALLOWED';
  exception when others then if position('INVENTORY_NOT_CONFIGURED_FOR_ALL_DAYS' in sqlerrm)=0 then raise; end if; end;
  reset role;
  select count(*) into after_n from public.ad_inventory_reservations;
  if after_n<>before_n then raise exception 'FAILED_RESERVATION_LEFT_PARTIAL_ROWS'; end if;
  set local role authenticated;
  perform set_config('request.jwt.claim.sub','91111111-1111-1111-1111-111111111111',true);
end $$;

select public.confirm_ad_inventory(current_setting('test.res1')::uuid,'confirm-res1');
select public.confirm_ad_inventory(current_setting('test.res1')::uuid,'confirm-res1');

-- Exact approved Revision 1 can create Placement.
select set_config('test.placement',(public.create_ad_placement(current_setting('test.res1')::uuid,'90000000-0000-0000-0000-000000000001','home_sponsored',current_setting('test.r1')::uuid,'placement-1')->>'placement_id'),true);
select public.set_ad_placement_state(current_setting('test.placement')::uuid,'live',null,'placement-live-1');

-- Newer Revision 2 does not replace serving creative just because it exists/submits.
select set_config('test.r2',(public.create_ad_campaign_revision(current_setting('test.c1')::uuid,'Learn Fractions — New','Newer creative still requires exact review',null,'teaching_option',current_setting('test.option')::uuid,null,'enquire','c1-r2')->>'revision_id'),true);
select public.submit_ad_campaign_revision(current_setting('test.r2')::uuid,'c1-r2-submit');
do $$ begin
  perform public.switch_ad_placement_revision(current_setting('test.placement')::uuid,current_setting('test.r2')::uuid,'switch-unapproved');
  raise exception 'UNAPPROVED_REVISION_SWITCH_ALLOWED';
exception when others then if position('SERVING_REVISION_NOT_ELIGIBLE' in sqlerrm)=0 then raise; end if; end $$;
reset role;
do $$ begin
  if (select serving_revision_id from public.ad_placements where id=current_setting('test.placement')::uuid)<>current_setting('test.r1')::uuid then raise exception 'LATEST_REVISION_REPLACED_EXACT_SERVING_REVISION'; end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','94444444-4444-4444-4444-444444444444',true);
select public.review_ad_campaign_revision(current_setting('test.r2')::uuid,'platform',null,'approved','EDUCATION_RELEVANT',null,'review-r2');
select set_config('request.jwt.claim.sub','91111111-1111-1111-1111-111111111111',true);
select public.switch_ad_placement_revision(current_setting('test.placement')::uuid,current_setting('test.r2')::uuid,'switch-r2');

-- Commercial revocation prevents resume; clearance and policy remain independent prerequisites.
select public.set_ad_placement_state(current_setting('test.placement')::uuid,'paused','Commercial check','pause-before-revoke');
select set_config('request.jwt.claim.sub','93333333-3333-3333-3333-333333333333',true);
select public.revoke_ad_commercial_clearance(current_setting('test.c1')::uuid,'Test revoke','revoke-clearance');
select set_config('request.jwt.claim.sub','91111111-1111-1111-1111-111111111111',true);
do $$ begin
  perform public.set_ad_placement_state(current_setting('test.placement')::uuid,'live',null,'resume-without-clearance');
  raise exception 'PLACEMENT_RESUMED_WITHOUT_COMMERCIAL_CLEARANCE';
exception when others then if position('AD_PLACEMENT_PREREQUISITES_NOT_MET' in sqlerrm)=0 then raise; end if; end $$;
select set_config('request.jwt.claim.sub','93333333-3333-3333-3333-333333333333',true);
select public.confirm_ad_commercial_clearance(current_setting('test.c1')::uuid,'waiver','TEST-WAIVER',0,'INR','Restored','clear-c1-again');
select set_config('request.jwt.claim.sub','91111111-1111-1111-1111-111111111111',true);
select public.set_ad_placement_state(current_setting('test.placement')::uuid,'live',null,'resume-after-clearance');

-- Viewer: protected learning surfaces are always ad-free; Home is eligible.
select set_config('request.jwt.claim.sub','92222222-2222-2222-2222-222222222222',true);
do $$ declare x jsonb; begin
  x:=public.get_sponsored_candidate('90000000-0000-0000-0000-000000000001','class');
  if x is not null then raise exception 'SPONSORED_AD_LEAKED_TO_CLASS_SURFACE'; end if;
  x:=public.get_sponsored_candidate('90000000-0000-0000-0000-000000000001','test');
  if x is not null then raise exception 'SPONSORED_AD_LEAKED_TO_TEST_SURFACE'; end if;
end $$;
select set_config('test.served_revision',(public.get_sponsored_candidate('90000000-0000-0000-0000-000000000001','home')->>'serving_revision_id'),true);
do $$ begin if current_setting('test.served_revision')::uuid<>current_setting('test.r2')::uuid then raise exception 'WRONG_EXACT_REVISION_SERVED'; end if; end $$;

-- Hiding is viewer-private and immediately suppresses serving.
select public.hide_sponsored_campaign(current_setting('test.c1')::uuid,true,'Not relevant','hide-c1');
do $$ declare x jsonb; begin x:=public.get_sponsored_candidate('90000000-0000-0000-0000-000000000001','home'); if x is not null then raise exception 'HIDDEN_CAMPAIGN_STILL_SERVED'; end if; end $$;
select public.hide_sponsored_campaign(current_setting('test.c1')::uuid,false,null,'unhide-c1');

-- Second impression is allowed, third is blocked by configured daily cap=2.
do $$ declare x jsonb; begin x:=public.get_sponsored_candidate('90000000-0000-0000-0000-000000000001','home'); if x is null then raise exception 'SECOND_IMPRESSION_NOT_SERVED'; end if; x:=public.get_sponsored_candidate('90000000-0000-0000-0000-000000000001','home'); if x is not null then raise exception 'FREQUENCY_CAP_BYPASSED'; end if; end $$;

-- Click metric is retry-safe, and explicit Sponsored Enquiry uses normal Enquiry relationship with attribution.
select public.record_sponsored_interaction(current_setting('test.placement')::uuid,'open','open-1');
select public.record_sponsored_interaction(current_setting('test.placement')::uuid,'open','open-1');
select set_config('test.enquiry',(public.send_sponsored_enquiry(current_setting('test.placement')::uuid,'90000000-0000-0000-0000-000000000010','I would like to know more.','sponsored-enquiry-1')->>'enquiry_id'),true);
reset role;
do $$ begin
  if not exists(select 1 from public.enquiries where id=current_setting('test.enquiry')::uuid and source_type='sponsored' and source_campaign_id=current_setting('test.c1')::uuid) then raise exception 'SPONSORED_ENQUIRY_ATTRIBUTION_MISSING'; end if;
  if (select opens from public.ad_metrics_daily where ad_placement_id=current_setting('test.placement')::uuid and metric_date=current_date)<>1 then raise exception 'OPEN_METRIC_NOT_IDEMPOTENT'; end if;
  if (select enquiries from public.ad_metrics_daily where ad_placement_id=current_setting('test.placement')::uuid and metric_date=current_date)<>1 then raise exception 'ENQUIRY_METRIC_BAD'; end if;
end $$;

-- Advertiser sees aggregate metrics, never named viewer frequency/hide state.
set local role authenticated;
select set_config('request.jwt.claim.sub','91111111-1111-1111-1111-111111111111',true);
do $$ declare n int; begin
  select count(*) into n from public.get_ad_campaign_metrics(current_setting('test.c1')::uuid); if n<1 then raise exception 'ADVERTISER_AGGREGATE_METRICS_MISSING'; end if;
  select count(*) into n from public.ad_frequency_state where account_id=current_setting('test.viewer')::uuid; if n<>0 then raise exception 'ADVERTISER_CAN_READ_NAMED_FREQUENCY_STATE'; end if;
  select count(*) into n from public.hidden_campaigns where account_id=current_setting('test.viewer')::uuid; if n<>0 then raise exception 'ADVERTISER_CAN_READ_VIEWER_HIDE_STATE'; end if;
  select count(*) into n from public.ad_inventory_days; if n<>0 then raise exception 'ADVERTISER_CAN_READ_RAW_INVENTORY_BUCKETS'; end if;
end $$;

-- Safe availability returns only aggregate remaining capacity.
do $$ declare n int; begin select count(*) into n from public.get_ad_inventory_availability('90000000-0000-0000-0000-000000000001','home_sponsored',current_date,current_date+1); if n<>2 then raise exception 'SAFE_INVENTORY_AVAILABILITY_BAD:%',n; end if; end $$;

-- Cannot release inventory while a live/waiting/paused Placement consumes it.
do $$ begin
  perform public.release_ad_inventory(current_setting('test.res1')::uuid,'release-active');
  raise exception 'ACTIVE_PLACEMENT_RESERVATION_RELEASED';
exception when others then if position('ACTIVE_PLACEMENT_USES_RESERVATION' in sqlerrm)=0 then raise; end if; end $$;
select public.set_ad_placement_state(current_setting('test.placement')::uuid,'cancelled',null,'cancel-placement');
select public.release_ad_inventory(current_setting('test.res1')::uuid,'release-after-cancel');

-- Direct operational mutation remains command-only.
do $$ begin
  insert into public.ad_inventory_reservations(campaign_id,requested_by_account_id,state,hold_expires_at) values(current_setting('test.c1')::uuid,current_setting('test.advertiser')::uuid,'held',now()+interval '1 hour');
  raise exception 'DIRECT_AD_RESERVATION_WRITE_ALLOWED';
exception when insufficient_privilege then null; end $$;

rollback;
select 'ADS_INVENTORY_SERVING_RUNTIME_TESTS_PASS' as result;
