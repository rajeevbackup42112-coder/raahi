-- Raahi Learning V1.3 — Learner self-access invitation runtime/security smoke
-- Dev/disposable only. Entire suite rolls back.

begin;
insert into auth.users(id,aud,role,email) values
('b1111111-1111-1111-1111-111111111111','authenticated','authenticated','parent-111@test.invalid'),
('b1122222-2222-2222-2222-222222222222','authenticated','authenticated','student-111@test.invalid'),
('b1133333-3333-3333-3333-333333333333','authenticated','authenticated','student2-111@test.invalid'),
('b1144444-4444-4444-4444-444444444444','authenticated','authenticated','newmanager-111@test.invalid'),
('b1155555-5555-5555-5555-555555555555','authenticated','authenticated','admin-111@test.invalid'),
('b1166666-6666-6666-6666-666666666666','authenticated','authenticated','outsider-111@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','b1111111-1111-1111-1111-111111111111',true);
select set_config('t.parent',(public.bootstrap_account('Parent 111')->>'account_id'),true);
select set_config('request.jwt.claim.sub','b1122222-2222-2222-2222-222222222222',true);
select set_config('t.student',(public.bootstrap_account('Student 111')->>'account_id'),true);
select set_config('request.jwt.claim.sub','b1133333-3333-3333-3333-333333333333',true);
select set_config('t.student2',(public.bootstrap_account('Student2 111')->>'account_id'),true);
select set_config('request.jwt.claim.sub','b1144444-4444-4444-4444-444444444444',true);
select set_config('t.newmanager',(public.bootstrap_account('New Manager 111')->>'account_id'),true);
select set_config('request.jwt.claim.sub','b1155555-5555-5555-5555-555555555555',true);
select set_config('t.admin',(public.bootstrap_account('Admin 111')->>'account_id'),true);
select set_config('request.jwt.claim.sub','b1166666-6666-6666-6666-666666666666',true);
select set_config('t.outsider',(public.bootstrap_account('Outsider 111')->>'account_id'),true);
reset role;
insert into public.account_capabilities(account_id,capability_code) values(current_setting('t.admin')::uuid,'platform_admin');

-- A. Issue: token returned once, hash-only at rest, preview requires possession.
set local role authenticated;
select set_config('request.jwt.claim.sub','b1111111-1111-1111-1111-111111111111',true);
select set_config('t.learner',(public.create_learner('Rahul 111','manage','none',null,'111-learner')->>'learner_id'),true);
do $$ declare r jsonb; r2 jsonb; token text; iid uuid; begin
  r:=public.issue_learner_self_access_invitation(current_setting('t.learner')::uuid,'111-issue');
  token:=r->>'invite_token'; iid:=(r->>'invitation_id')::uuid;
  if token is null or token !~ '^rlsa_[A-Za-z0-9_-]{32}$' then raise exception 'BAD_SELF_INVITE_TOKEN'; end if;
  r2:=public.issue_learner_self_access_invitation(current_setting('t.learner')::uuid,'111-issue');
  if r2->>'invitation_id'<>iid::text or r2->>'invite_token' is not null or coalesce((r2->>'secret_available')::boolean,true) then raise exception 'SELF_INVITE_SECRET_REPLAYED'; end if;
  perform set_config('t.token',token,true); perform set_config('t.invite',iid::text,true);
end $$;
reset role;
do $$ declare h text; c int; token text:=current_setting('t.token',true); begin
  select token_hash into h from public.learner_self_access_invitations where id=current_setting('t.invite')::uuid;
  if h<>app_private.private_invite_hash(token) or h=token then raise exception 'SELF_INVITE_NOT_HASH_ONLY'; end if;
  select count(*) into c from public.idempotency_keys where coalesce(result_json::text,'') like '%'||token||'%'; if c<>0 then raise exception 'SELF_TOKEN_IN_IDEMPOTENCY'; end if;
  select count(*) into c from public.audit_log where coalesce(metadata::text,'') like '%'||token||'%'; if c<>0 then raise exception 'SELF_TOKEN_IN_AUDIT'; end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub','b1122222-2222-2222-2222-222222222222',true);
do $$ declare j jsonb; begin j:=public.get_learner_self_access_invitation_preview(current_setting('t.token')); if j->>'learner_name'<>'Rahul 111' then raise exception 'SELF_INVITE_PREVIEW_WRONG:%',j; end if; end $$;

-- Active managing guardian cannot consume the learner's self identity link.
select set_config('request.jwt.claim.sub','b1111111-1111-1111-1111-111111111111',true);
do $$ begin
  perform public.accept_learner_self_access_invitation(current_setting('t.token'),'111-manager-accept');
  raise exception 'MANAGER_BECAME_SELF';
exception when others then if position('TARGET_IS_ACTIVE_MANAGER' in sqlerrm)=0 then raise; end if; end $$;

-- Intended authenticated student accepts; same Learner receives self access.
select set_config('request.jwt.claim.sub','b1122222-2222-2222-2222-222222222222',true);
do $$ declare r jsonb; n int; begin
  r:=public.accept_learner_self_access_invitation(current_setting('t.token'),'111-student-accept');
  if r->>'learner_id'<>current_setting('t.learner') or r->>'state'<>'accepted' then raise exception 'SELF_ACCEPT_WRONG:%',r; end if;
  select count(*) into n from public.account_learner_access where learner_id=current_setting('t.learner')::uuid and account_id=current_setting('t.student')::uuid and access_type='self' and status='active';
  if n<>1 then raise exception 'SELF_ACCESS_NOT_CREATED'; end if;
end $$;
do $$ begin
  perform public.accept_learner_self_access_invitation(current_setting('t.token'),'111-reconsume');
  raise exception 'CONSUMED_SELF_INVITE_REUSED';
exception when others then if position('INVALID_OR_EXPIRED_INVITATION' in sqlerrm)=0 then raise; end if; end $$;

-- B. Paused managing guardian may revoke a still-active link protectively.
select set_config('request.jwt.claim.sub','b1111111-1111-1111-1111-111111111111',true);
select set_config('t.learner2',(public.create_learner('Ananya 111','manage','none',null,'111-learner2')->>'learner_id'),true);
do $$ declare r jsonb; begin r:=public.issue_learner_self_access_invitation(current_setting('t.learner2')::uuid,'111-issue2'); perform set_config('t.invite2',r->>'invitation_id',true); end $$;
select public.pause_account('111-pause-parent');
do $$ declare r jsonb; begin r:=public.revoke_learner_self_access_invitation(current_setting('t.invite2')::uuid,'111-revoke-paused'); if r->>'state'<>'revoked' then raise exception 'PAUSED_MANAGER_REVOKE_FAILED:%',r; end if; end $$;
select public.resume_account('111-resume-parent');

-- C. Link issued by former manager becomes unusable after management transfer.
select set_config('t.learner3',(public.create_learner('Learner Transfer 111','manage','none',null,'111-learner3')->>'learner_id'),true);
do $$ declare r jsonb; begin r:=public.issue_learner_self_access_invitation(current_setting('t.learner3')::uuid,'111-issue3'); perform set_config('t.token3',r->>'invite_token',true); end $$;
select set_config('request.jwt.claim.sub','b1155555-5555-5555-5555-555555555555',true);
select public.transfer_learner_management(current_setting('t.learner3')::uuid,current_setting('t.newmanager')::uuid,'111-transfer-manager');
select set_config('request.jwt.claim.sub','b1133333-3333-3333-3333-333333333333',true);
do $$ begin
  perform public.accept_learner_self_access_invitation(current_setting('t.token3'),'111-old-invite-accept');
  raise exception 'FORMER_MANAGER_LINK_SURVIVED';
exception when others then if position('INVITER_NO_LONGER_AUTHORIZED' in sqlerrm)=0 then raise; end if; end $$;

-- D. Direct table/private resolver/anonymous paths stay closed.
select set_config('request.jwt.claim.sub','b1166666-6666-6666-6666-666666666666',true);
do $$ begin perform count(*) from public.learner_self_access_invitations; raise exception 'DIRECT_SELF_INVITE_READ_ALLOWED'; exception when insufficient_privilege then null; end $$;
do $$ begin perform * from app_private.resolve_active_learner_self_access_invitation('rlsa_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'); raise exception 'PRIVATE_SELF_RESOLVER_EXEC_ALLOWED'; exception when insufficient_privilege then null; end $$;
reset role;
set local role anon;
do $$ begin perform public.get_learner_self_access_invitation_preview('rlsa_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'); raise exception 'ANON_SELF_PREVIEW_ALLOWED'; exception when insufficient_privilege then null; end $$;
do $$ begin perform public.accept_learner_self_access_invitation('rlsa_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA','anon'); raise exception 'ANON_SELF_ACCEPT_ALLOWED'; exception when insufficient_privilege then null; end $$;

rollback;
select 'V13_LEARNER_SELF_ACCESS_INVITATION_PASS' as result;
