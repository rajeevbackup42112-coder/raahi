-- Raahi Learning V1.2 — Foundation + Identity runtime smoke
-- Run only in a disposable/dev environment. Entire test rolls back.

begin;

insert into auth.users(id,aud,role,email) values
('11111111-1111-1111-1111-111111111111','authenticated','authenticated','parent@test.invalid'),
('22222222-2222-2222-2222-222222222222','authenticated','authenticated','learner@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
select set_config('test.parent_account',(public.bootstrap_account('Parent Test')->>'account_id'),true);
select set_config('test.learner',(public.create_learner('Learner Test','manage','none',null,'create-learner-1')->>'learner_id'),true);

-- Idempotent retry returns the same logical learner.
do $$
declare v_before integer; v_after integer; v_result jsonb;
begin
  select count(*) into v_before from public.learners;
  v_result := public.create_learner('Learner Test','manage','none',null,'create-learner-1');
  select count(*) into v_after from public.learners;
  if v_after <> v_before then raise exception 'IDEMPOTENCY_DUPLICATED_LEARNER'; end if;
  if v_result->>'learner_id' <> current_setting('test.learner',true) then raise exception 'IDEMPOTENCY_RESULT_MISMATCH'; end if;
end $$;

-- Same key, different request is rejected.
do $$
begin
  perform public.create_learner('Different','manage','none',null,'create-learner-1');
  raise exception 'FINGERPRINT_REUSE_NOT_REJECTED';
exception when others then
  if position('IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST' in sqlerrm)=0 then raise; end if;
end $$;

-- Client table mutation is denied.
do $$
begin
  insert into public.learners(display_name,created_by_account_id)
  values ('Forbidden',current_setting('test.parent_account',true)::uuid);
  raise exception 'DIRECT_WRITE_ALLOWED';
exception when insufficient_privilege then null;
end $$;

-- Parent has manage/formal-decision authority, but not learner self/Test authority.
do $$
begin
  if not app_private.can_manage_learner(current_setting('test.learner',true)::uuid) then raise exception 'MANAGER_MISSING'; end if;
  if not app_private.can_make_learning_decision(current_setting('test.learner',true)::uuid) then raise exception 'FORMAL_DECISION_MISSING'; end if;
  if app_private.has_learner_self_access(current_setting('test.learner',true)::uuid) then raise exception 'MANAGER_GOT_SELF_ACCESS'; end if;
end $$;

select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',true);
select set_config('test.self_account',(public.bootstrap_account('Learner Login')->>'account_id'),true);
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
select public.grant_learner_self_access(current_setting('test.learner',true)::uuid,current_setting('test.self_account',true)::uuid,'self-1');

select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',true);
do $$
begin
  if not app_private.has_learner_self_access(current_setting('test.learner',true)::uuid) then raise exception 'SELF_ACCESS_MISSING'; end if;
  if app_private.can_make_learning_decision(current_setting('test.learner',true)::uuid) then raise exception 'SELF_OVERRULED_MANAGER'; end if;
end $$;

-- Anonymous caller cannot invoke protected RPCs.
reset role;
set local role anon;
do $$
begin
  perform public.bootstrap_account('Anon');
  raise exception 'ANON_RPC_ALLOWED';
exception when insufficient_privilege then null;
end $$;

rollback;
select 'FOUNDATION_IDENTITY_RUNTIME_SMOKE_PASS' as result;
