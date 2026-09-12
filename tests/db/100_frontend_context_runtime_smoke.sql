-- Raahi Learning V1.2 — frontend context projections runtime smoke.
-- Disposable dev suite; all fixture data is rolled back.

begin;
insert into auth.users(id,aud,role,email) values
('91111111-1111-1111-1111-111111111111','authenticated','authenticated','frontend1005@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','91111111-1111-1111-1111-111111111111',true);
select set_config('test.account',(public.bootstrap_account('Frontend User')->>'account_id'),true);
reset role;

insert into public.locations(id,name,slug,state,country_code) values
('91000000-0000-0000-0000-000000000001','Live UI','live-ui','live','IN'),
('91000000-0000-0000-0000-000000000002','Preparing UI','preparing-ui','preparing','IN'),
('91000000-0000-0000-0000-000000000003','Interest UI','interest-ui','interest_only','IN'),
('91000000-0000-0000-0000-000000000004','Paused UI','paused-ui','paused','IN'),
('91000000-0000-0000-0000-000000000005','Retired UI','retired-ui','retired','IN');

set local role authenticated;
select set_config('request.jwt.claim.sub','91111111-1111-1111-1111-111111111111',true);
select public.set_selected_location('91000000-0000-0000-0000-000000000001','frontend-location');
select public.create_learner('Self UI','self','none',null,'frontend-learner');

do $$ declare c jsonb; n int; begin
  c:=public.get_my_account_context();
  if c->'account'->>'display_name'<>'Frontend User' then raise exception 'BAD_ACCOUNT_CONTEXT'; end if;
  if c->'selected_location'->>'name'<>'Live UI' then raise exception 'BAD_SELECTED_LOCATION'; end if;
  if jsonb_array_length(c->'learners')<>1 then raise exception 'BAD_LEARNER_CONTEXT'; end if;
  select count(*) into n from public.list_public_locations();
  if n<>4 then raise exception 'PUBLIC_LOCATION_DIRECTORY_BAD:%',n; end if;
end $$;

rollback;
select 'FRONTEND_CONTEXT_PROJECTIONS_PASS' as result;
