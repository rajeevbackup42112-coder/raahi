-- Raahi Learning V1.2 — Community / Trust & Safety runtime smoke
-- Dev/disposable only; entire suite rolls back.

begin;
insert into auth.users(id,aud,role,email) values
('81111111-1111-1111-1111-111111111111','authenticated','authenticated','poster@test.invalid'),
('82222222-2222-2222-2222-222222222222','authenticated','authenticated','participant@test.invalid'),
('83333333-3333-3333-3333-333333333333','authenticated','authenticated','localmanager@test.invalid'),
('84444444-4444-4444-4444-444444444444','authenticated','authenticated','verifier@test.invalid'),
('85555555-5555-5555-5555-555555555555','authenticated','authenticated','outsider@test.invalid');
set local role authenticated;
select set_config('request.jwt.claim.sub','81111111-1111-1111-1111-111111111111',true); select set_config('test.poster',(public.bootstrap_account('Poster')->>'account_id'),true);
select set_config('request.jwt.claim.sub','82222222-2222-2222-2222-222222222222',true); select set_config('test.participant',(public.bootstrap_account('Participant')->>'account_id'),true);
select set_config('request.jwt.claim.sub','83333333-3333-3333-3333-333333333333',true); select set_config('test.localmanager',(public.bootstrap_account('Dhanbad Manager')->>'account_id'),true);
select set_config('request.jwt.claim.sub','84444444-4444-4444-4444-444444444444',true); select set_config('test.verifier',(public.bootstrap_account('Verifier')->>'account_id'),true);
select set_config('request.jwt.claim.sub','85555555-5555-5555-5555-555555555555',true); select set_config('test.outsider',(public.bootstrap_account('Outsider')->>'account_id'),true);
reset role;
insert into public.locations(id,name,slug,state,country_code) values('80000000-0000-0000-0000-000000000001','Dhanbad','community-dhanbad','live','IN'),('80000000-0000-0000-0000-000000000002','Gomoh','community-gomoh','live','IN');
insert into public.account_capabilities(account_id,capability_code) values(current_setting('test.poster')::uuid,'community_post'),(current_setting('test.poster')::uuid,'teach'),(current_setting('test.verifier')::uuid,'verifier');
insert into public.location_staff_assignments(location_id,account_id,staff_type,status) values('80000000-0000-0000-0000-000000000001',current_setting('test.localmanager')::uuid,'local_manager','active');
insert into public.account_location_preferences(account_id,selected_location_id) values(current_setting('test.poster')::uuid,'80000000-0000-0000-0000-000000000001'),(current_setting('test.participant')::uuid,'80000000-0000-0000-0000-000000000001'),(current_setting('test.outsider')::uuid,'80000000-0000-0000-0000-000000000002');
insert into public.learners(id,display_name,avatar_type,created_by_account_id) values('80000000-0000-0000-0000-000000000010','Managed Learner','none',current_setting('test.participant')::uuid);
insert into public.account_learner_access(account_id,learner_id,access_type,status) values(current_setting('test.participant')::uuid,'80000000-0000-0000-0000-000000000010','manage','active');
insert into public.classes(id,responsible_teacher_account_id,location_id,title,class_type,capacity,state) values('80000000-0000-0000-0000-000000000020',current_setting('test.poster')::uuid,'80000000-0000-0000-0000-000000000001','Community Safety Class','group',5,'active');
insert into public.class_memberships(class_id,learner_id,state) values('80000000-0000-0000-0000-000000000020','80000000-0000-0000-0000-000000000010','active');

set local role authenticated;
select set_config('request.jwt.claim.sub','81111111-1111-1111-1111-111111111111',true);
select set_config('test.post',(public.publish_community_post('80000000-0000-0000-0000-000000000001','question','Any tips for learning fractions?',null,null,'post-1')->>'post_id'),true);
select set_config('request.jwt.claim.sub','82222222-2222-2222-2222-222222222222',true);
select public.comment_on_community_post(current_setting('test.post')::uuid,'Use visual pieces first.','comment-1');
select public.react_to_community_content('post',current_setting('test.post')::uuid,'helpful',true,'react-1');
do $$ begin perform public.react_to_community_content('post',current_setting('test.post')::uuid,'downvote',true,'bad-reaction'); raise exception 'DOWNVOTE_ALLOWED'; exception when others then if position('INVALID_REACTION_TYPE' in sqlerrm)=0 then raise; end if; end $$;
do $$ begin perform public.publish_community_post('80000000-0000-0000-0000-000000000001','discussion','Should fail',null,null,'no-cap'); raise exception 'POST_WITHOUT_CAPABILITY_ALLOWED'; exception when others then if position('COMMUNITY_POST_CAPABILITY_REQUIRED' in sqlerrm)=0 then raise; end if; end $$;
select set_config('test.report',(public.report_subject('community_post',current_setting('test.post')::uuid,'80000000-0000-0000-0000-000000000010',null,'SAFETY_CONCERN','Please review','report-1')->>'report_id'),true);

reset role;
do $$ begin if exists(select 1 from public.access_restrictions where account_id=current_setting('test.poster')::uuid and state='active') then raise exception 'REPORT_AUTO_PUNISHED_TARGET'; end if; if (select state from public.class_memberships where class_id='80000000-0000-0000-0000-000000000020' and learner_id='80000000-0000-0000-0000-000000000010')<>'active' then raise exception 'REPORT_CHANGED_MEMBERSHIP'; end if; end $$;

set local role authenticated; select set_config('request.jwt.claim.sub','85555555-5555-5555-5555-555555555555',true);
do $$ begin perform public.report_subject('account',current_setting('test.poster')::uuid,'80000000-0000-0000-0000-000000000010','80000000-0000-0000-0000-000000000002','TEST','bad context','bad-context'); raise exception 'FOREIGN_CONTEXT_ALLOWED'; exception when others then if position('INVALID_REPORT_LEARNER_CONTEXT' in sqlerrm)=0 then raise; end if; end $$;
select set_config('request.jwt.claim.sub','81111111-1111-1111-1111-111111111111',true);
do $$ declare n int; begin select count(*) into n from public.reports where id=current_setting('test.report')::uuid; if n<>0 then raise exception 'REPORT_VISIBLE_TO_TARGET'; end if; end $$;

select set_config('request.jwt.claim.sub','83333333-3333-3333-3333-333333333333',true);
select public.resolve_report(current_setting('test.report')::uuid,'REVIEWED','Reviewed without automatic sanction',false,'resolve-1');
select public.moderate_community_content('post',current_setting('test.post')::uuid,'hidden','Moderation decision','hide-1');
do $$ declare n int; begin select count(*) into n from public.discover_community_posts('80000000-0000-0000-0000-000000000001',50); if n<>0 then raise exception 'HIDDEN_POST_VISIBLE'; end if; end $$;
select public.moderate_community_content('post',current_setting('test.post')::uuid,'published','Restore','restore-1');

select set_config('request.jwt.claim.sub','82222222-2222-2222-2222-222222222222',true);
select public.set_block(current_setting('test.poster')::uuid,true,'block-1');
do $$ declare n int; begin select count(*) into n from public.discover_community_posts('80000000-0000-0000-0000-000000000001',50); if n<>0 then raise exception 'BLOCK_FILTER_FAILED'; end if; end $$;
reset role;
do $$ begin if (select state from public.class_memberships where class_id='80000000-0000-0000-0000-000000000020' and learner_id='80000000-0000-0000-0000-000000000010')<>'active' then raise exception 'BLOCK_SILENTLY_LEFT_CLASS'; end if; end $$;

set local role authenticated; select set_config('request.jwt.claim.sub','84444444-4444-4444-4444-444444444444',true);
select set_config('test.claim',(public.grant_verification_claim(current_setting('test.poster')::uuid,null,'qualification','Evidence reviewed','verify-1')->>'claim_id'),true);
select set_config('request.jwt.claim.sub','82222222-2222-2222-2222-222222222222',true);
do $$ declare n int; begin select count(*) into n from public.get_public_verification_claims(current_setting('test.poster')::uuid,null); if n<>1 then raise exception 'PUBLIC_CLAIM_MISSING'; end if; select count(*) into n from public.verification_claims; if n<>0 then raise exception 'PRIVATE_CLAIM_METADATA_VISIBLE'; end if; end $$;
select set_config('request.jwt.claim.sub','84444444-4444-4444-4444-444444444444',true); select public.revoke_verification_claim(current_setting('test.claim')::uuid,'Expired','revoke-1');
select set_config('request.jwt.claim.sub','82222222-2222-2222-2222-222222222222',true);
do $$ declare n int; begin select count(*) into n from public.get_public_verification_claims(current_setting('test.poster')::uuid,null); if n<>0 then raise exception 'REVOKED_CLAIM_PUBLIC'; end if; end $$;
do $$ begin insert into public.community_posts(location_id,author_account_id,post_type,body) values('80000000-0000-0000-0000-000000000001',current_setting('test.participant')::uuid,'discussion','forged'); raise exception 'DIRECT_WRITE_ALLOWED'; exception when insufficient_privilege then null; end $$;

rollback;
select 'COMMUNITY_TRUST_RUNTIME_TESTS_PASS' as result;
