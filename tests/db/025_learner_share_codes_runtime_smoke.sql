-- Raahi Learning V1.2 — Learner Share Codes runtime/security smoke
-- Dev/disposable only. Each section rolls back all synthetic Auth/application data.

-- -----------------------------------------------------------------------------
-- A. Basic creation, one-time secret return, hash-only persistence, private resolve
-- Expected marker: SHARE_CODE_BASIC_PASS
-- -----------------------------------------------------------------------------
begin;
insert into auth.users(id,aud,role,email) values
('41111111-1111-1111-1111-111111111111','authenticated','authenticated','parent-a@test.invalid');
set local role authenticated;
select set_config('request.jwt.claim.sub','41111111-1111-1111-1111-111111111111',true);
select set_config('t.account',(public.bootstrap_account('Parent A')->>'account_id'),true);
select set_config('t.learner',(public.create_learner('Learner A','manage','none',null,'learner-a')->>'learner_id'),true);
do $$
declare r jsonb; token text; id uuid; r2 jsonb;
begin
  r := public.create_learner_share_code(current_setting('t.learner',true)::uuid,'code-a');
  token := r->>'share_code'; id := (r->>'share_code_id')::uuid;
  if token is null or token !~ '^rl_[A-Za-z0-9_-]{32}$' then raise exception 'BAD_TOKEN'; end if;
  r2 := public.create_learner_share_code(current_setting('t.learner',true)::uuid,'code-a');
  if r2->>'share_code_id' <> id::text then raise exception 'IDEMPOTENCY_ID_MISMATCH'; end if;
  if r2->>'share_code' is not null then raise exception 'SECRET_REPLAYED'; end if;
  perform set_config('t.token',token,true); perform set_config('t.code_id',id::text,true);
end $$;
reset role;
do $$
declare token text:=current_setting('t.token',true); h text; c integer;
begin
  select code_hash into h from public.learner_share_codes where id=current_setting('t.code_id',true)::uuid;
  if h <> app_private.learner_share_code_hash(token) or h = token then raise exception 'HASH_STORAGE_FAILED'; end if;
  select count(*) into c from public.idempotency_keys where command_name='create_learner_share_code' and coalesce(result_json::text,'') like '%'||token||'%';
  if c<>0 then raise exception 'TOKEN_IN_IDEMPOTENCY'; end if;
  select count(*) into c from public.audit_log where action_type like 'learner.share_code%' and coalesce(metadata::text,'') like '%'||token||'%';
  if c<>0 then raise exception 'TOKEN_IN_AUDIT'; end if;
  select count(*) into c from app_private.resolve_active_learner_share_code(token);
  if c<>1 then raise exception 'EXACT_TOKEN_NOT_RESOLVED'; end if;
end $$;
rollback;
select 'SHARE_CODE_BASIC_PASS' as result;

-- -----------------------------------------------------------------------------
-- B. Formal authority, RLS/grants, no public Learner resolver/search
-- Expected marker: SHARE_CODE_PERMISSION_PASS
-- -----------------------------------------------------------------------------
begin;
insert into auth.users(id,aud,role,email) values
('42111111-1111-1111-1111-111111111111','authenticated','authenticated','parent-b@test.invalid'),
('42222222-2222-2222-2222-222222222222','authenticated','authenticated','self-b@test.invalid'),
('42333333-3333-3333-3333-333333333333','authenticated','authenticated','outsider-b@test.invalid');
set local role authenticated;
select set_config('request.jwt.claim.sub','42111111-1111-1111-1111-111111111111',true);
select set_config('t.parent',(public.bootstrap_account('Parent B')->>'account_id'),true);
select set_config('t.learner',(public.create_learner('Learner B','manage','none',null,'learner-b')->>'learner_id'),true);
select set_config('request.jwt.claim.sub','42222222-2222-2222-2222-222222222222',true);
select set_config('t.self',(public.bootstrap_account('Self B')->>'account_id'),true);
select set_config('request.jwt.claim.sub','42111111-1111-1111-1111-111111111111',true);
select public.grant_learner_self_access(current_setting('t.learner',true)::uuid,current_setting('t.self',true)::uuid,'self-link-b');
select set_config('request.jwt.claim.sub','42222222-2222-2222-2222-222222222222',true);
do $$ begin
  perform public.create_learner_share_code(current_setting('t.learner',true)::uuid,'self-denied-b');
  raise exception 'SELF_OVERRULED_MANAGER';
exception when others then if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if; end $$;
select set_config('request.jwt.claim.sub','42333333-3333-3333-3333-333333333333',true);
select public.bootstrap_account('Outsider B');
do $$ begin
  perform public.create_learner_share_code(current_setting('t.learner',true)::uuid,'outsider-denied-b');
  raise exception 'OUTSIDER_CREATED_CODE';
exception when others then if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if; end $$;
do $$ begin
  perform count(*) from public.learner_share_codes;
  raise exception 'DIRECT_READ_ALLOWED';
exception when insufficient_privilege then null; end $$;
do $$ begin
  perform * from app_private.resolve_active_learner_share_code('rl_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA');
  raise exception 'PRIVATE_RESOLVER_CLIENT_EXECUTABLE';
exception when insufficient_privilege then null; end $$;
reset role;
do $$ declare c integer; begin
  select count(*) into c from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and (p.proname like '%resolve%share%code%' or p.proname like '%search%learner%' or p.proname like '%browse%learner%');
  if c<>0 then raise exception 'PUBLIC_LEARNER_RESOLVER_OR_SEARCH_EXISTS'; end if;
end $$;
set local role anon;
do $$ begin
  perform public.create_learner_share_code(current_setting('t.learner',true)::uuid,'anon-b');
  raise exception 'ANON_CREATE_ALLOWED';
exception when insufficient_privilege then null; end $$;
rollback;
select 'SHARE_CODE_PERMISSION_PASS' as result;

-- -----------------------------------------------------------------------------
-- C. Replacement, unique-active invariant, expiry, paused protective revoke
-- Expected marker: SHARE_CODE_STATE_PASS
-- -----------------------------------------------------------------------------
begin;
insert into auth.users(id,aud,role,email) values
('43111111-1111-1111-1111-111111111111','authenticated','authenticated','parent-c@test.invalid');
set local role authenticated;
select set_config('request.jwt.claim.sub','43111111-1111-1111-1111-111111111111',true);
select set_config('t.parent',(public.bootstrap_account('Parent C')->>'account_id'),true);
select set_config('t.learner1',(public.create_learner('Learner C1','manage','none',null,'learner-c1')->>'learner_id'),true);
select set_config('t.learner2',(public.create_learner('Learner C2','manage','none',null,'learner-c2')->>'learner_id'),true);
do $$ declare r jsonb; begin r:=public.create_learner_share_code(current_setting('t.learner1',true)::uuid,'create-c1'); perform set_config('t.code1',r->>'share_code_id',true); perform set_config('t.token1',r->>'share_code',true); end $$;
do $$ begin
  perform public.create_learner_share_code(current_setting('t.learner2',true)::uuid,'create-c1');
  raise exception 'FINGERPRINT_REUSE_ALLOWED';
exception when others then if position('IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST' in sqlerrm)=0 then raise; end if; end $$;
do $$ declare r jsonb; begin r:=public.create_learner_share_code(current_setting('t.learner1',true)::uuid,'create-c2'); perform set_config('t.code2',r->>'share_code_id',true); perform set_config('t.token2',r->>'share_code',true); end $$;
reset role;
do $$ declare s text; c integer; begin
  select state into s from public.learner_share_codes where id=current_setting('t.code1',true)::uuid;
  if s<>'revoked' then raise exception 'PREDECESSOR_NOT_REVOKED'; end if;
  select count(*) into c from public.learner_share_codes where learner_id=current_setting('t.learner1',true)::uuid and state='active';
  if c<>1 then raise exception 'ONE_ACTIVE_INVARIANT_FAILED'; end if;
end $$;
do $$ begin
  insert into public.learner_share_codes(learner_id,created_by_account_id,code_hash,expires_at)
  values(current_setting('t.learner1',true)::uuid,current_setting('t.parent',true)::uuid,app_private.learner_share_code_hash('rl_BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'),now()+interval '1 hour');
  raise exception 'SECOND_ACTIVE_PHYSICALLY_ALLOWED';
exception when unique_violation then null; end $$;
update public.learner_share_codes set created_at=now()-interval '2 days',expires_at=now()-interval '1 day' where id=current_setting('t.code2',true)::uuid;
set local role authenticated;
select set_config('request.jwt.claim.sub','43111111-1111-1111-1111-111111111111',true);
do $$ declare r jsonb; begin r:=public.revoke_learner_share_code(current_setting('t.code2',true)::uuid,'expire-c2'); if r->>'state'<>'expired' then raise exception 'EXPIRED_STATE_RECORD_FAILED'; end if; end $$;
do $$ declare r jsonb; begin r:=public.create_learner_share_code(current_setting('t.learner1',true)::uuid,'create-c3'); perform set_config('t.code3',r->>'share_code_id',true); end $$;
select public.pause_account('pause-c');
do $$ declare r jsonb; begin r:=public.revoke_learner_share_code(current_setting('t.code3',true)::uuid,'revoke-c3'); if r->>'state'<>'revoked' then raise exception 'PAUSED_MANAGER_REVOKE_FAILED'; end if; end $$;
select public.resume_account('resume-c');
rollback;
select 'SHARE_CODE_STATE_PASS' as result;

-- -----------------------------------------------------------------------------
-- D. Consumed terminal state and timestamp consistency
-- Expected marker: SHARE_CODE_TERMINAL_PASS
-- -----------------------------------------------------------------------------
begin;
insert into auth.users(id,aud,role,email) values ('44111111-1111-1111-1111-111111111111','authenticated','authenticated','parent-d@test.invalid');
set local role authenticated;
select set_config('request.jwt.claim.sub','44111111-1111-1111-1111-111111111111',true);
select set_config('t.parent',(public.bootstrap_account('Parent D')->>'account_id'),true);
select set_config('t.learner',(public.create_learner('Learner D','manage','none',null,'learner-d')->>'learner_id'),true);
do $$ declare r jsonb; begin r:=public.create_learner_share_code(current_setting('t.learner',true)::uuid,'code-d'); perform set_config('t.code',r->>'share_code_id',true); perform set_config('t.token',r->>'share_code',true); end $$;
reset role;
update public.learner_share_codes set state='consumed',consumed_at=now() where id=current_setting('t.code',true)::uuid;
do $$ declare c integer; begin select count(*) into c from app_private.resolve_active_learner_share_code(current_setting('t.token',true)); if c<>0 then raise exception 'CONSUMED_TOKEN_RESOLVED'; end if; end $$;
do $$ begin update public.learner_share_codes set state='revoked',revoked_at=now() where id=current_setting('t.code',true)::uuid; raise exception 'TERMINAL_CONSTRAINT_NOT_ENFORCED'; exception when check_violation then null; end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','44111111-1111-1111-1111-111111111111',true);
do $$ declare r jsonb; begin r:=public.revoke_learner_share_code(current_setting('t.code',true)::uuid,'revoke-consumed-d'); if r->>'state'<>'consumed' or coalesce((r->>'revoked')::boolean,true) then raise exception 'CONSUMED_REVOKE_WRONG'; end if; end $$;
rollback;
select 'SHARE_CODE_TERMINAL_PASS' as result;
