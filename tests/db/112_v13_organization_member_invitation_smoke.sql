-- Raahi Learning V1.3 — Organization member invitation runtime/security smoke
-- Dev/disposable only. Entire suite rolls back.

begin;
insert into auth.users(id,aud,role,email) values
('c1211111-1111-1111-1111-111111111111','authenticated','authenticated','owner-112@test.invalid'),
('c1222222-2222-2222-2222-222222222222','authenticated','authenticated','staff-112@test.invalid'),
('c1233333-3333-3333-3333-333333333333','authenticated','authenticated','manager2-112@test.invalid'),
('c1244444-4444-4444-4444-444444444444','authenticated','authenticated','staff2-112@test.invalid'),
('c1255555-5555-5555-5555-555555555555','authenticated','authenticated','outsider-112@test.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','c1211111-1111-1111-1111-111111111111',true);
select set_config('t.owner',(public.bootstrap_account('Owner 112')->>'account_id'),true);
select set_config('request.jwt.claim.sub','c1222222-2222-2222-2222-222222222222',true);
select set_config('t.staff',(public.bootstrap_account('Staff 112')->>'account_id'),true);
select set_config('request.jwt.claim.sub','c1233333-3333-3333-3333-333333333333',true);
select set_config('t.manager2',(public.bootstrap_account('Manager 2 112')->>'account_id'),true);
select set_config('request.jwt.claim.sub','c1244444-4444-4444-4444-444444444444',true);
select set_config('t.staff2',(public.bootstrap_account('Staff 2 112')->>'account_id'),true);
select set_config('request.jwt.claim.sub','c1255555-5555-5555-5555-555555555555',true);
select set_config('t.outsider',(public.bootstrap_account('Outsider 112')->>'account_id'),true);

-- A. Issue token once; normalize capabilities; secret never persisted/replayed.
select set_config('request.jwt.claim.sub','c1211111-1111-1111-1111-111111111111',true);
select set_config('t.org',(public.create_organization('coaching','Institute 112',null,null,null,null,'none',null,'112-org')->>'organization_id'),true);
do $$ declare r jsonb; r2 jsonb; token text; iid uuid; caps text[]; begin
  r:=public.issue_organization_member_invitation(current_setting('t.org')::uuid,array['manage_classes','manage_profile','manage_classes']::text[],'112-issue');
  token:=r->>'invite_token'; iid:=(r->>'invitation_id')::uuid;
  if token is null or token !~ '^rloi_[A-Za-z0-9_-]{32}$' then raise exception 'BAD_ORG_INVITE_TOKEN'; end if;
  select array_agg(x order by x) into caps from jsonb_array_elements_text(r->'capability_codes') x;
  if caps<>array['manage_classes','manage_profile']::text[] then raise exception 'CAPABILITIES_NOT_NORMALIZED:%',caps; end if;
  r2:=public.issue_organization_member_invitation(current_setting('t.org')::uuid,array['manage_profile','manage_classes']::text[],'112-issue');
  if r2->>'invitation_id'<>iid::text or r2->>'invite_token' is not null or coalesce((r2->>'secret_available')::boolean,true) then raise exception 'ORG_INVITE_SECRET_REPLAYED'; end if;
  perform set_config('t.token',token,true); perform set_config('t.invite',iid::text,true);
end $$;
reset role;
do $$ declare h text; c int; token text:=current_setting('t.token',true); begin
  select token_hash into h from public.organization_member_invitations where id=current_setting('t.invite')::uuid;
  if h<>app_private.private_invite_hash(token) or h=token then raise exception 'ORG_INVITE_NOT_HASH_ONLY'; end if;
  select count(*) into c from public.idempotency_keys where coalesce(result_json::text,'') like '%'||token||'%'; if c<>0 then raise exception 'ORG_TOKEN_IN_IDEMPOTENCY'; end if;
  select count(*) into c from public.organization_audit_log where coalesce(metadata::text,'') like '%'||token||'%'; if c<>0 then raise exception 'ORG_TOKEN_IN_AUDIT'; end if;
end $$;

-- B. Authenticated recipient previews and accepts; intended capabilities are applied.
set local role authenticated;
select set_config('request.jwt.claim.sub','c1222222-2222-2222-2222-222222222222',true);
do $$ declare j jsonb; begin j:=public.get_organization_member_invitation_preview(current_setting('t.token')); if j->>'organization_name'<>'Institute 112' then raise exception 'ORG_INVITE_PREVIEW_WRONG:%',j; end if; end $$;
do $$ declare r jsonb; m uuid; n int; begin
  r:=public.accept_organization_member_invitation(current_setting('t.token'),'112-accept');
  if r->>'state'<>'accepted' or r->>'organization_id'<>current_setting('t.org') then raise exception 'ORG_INVITE_ACCEPT_WRONG:%',r; end if;
  m:=(r->>'member_id')::uuid;
  select count(*) into n from public.organization_member_capabilities where organization_member_id=m and capability_code in ('manage_classes','manage_profile');
  if n<>2 then raise exception 'ORG_INVITE_CAPABILITIES_MISSING:%',n; end if;
end $$;
do $$ begin perform public.accept_organization_member_invitation(current_setting('t.token'),'112-reconsume'); raise exception 'CONSUMED_ORG_INVITE_REUSED'; exception when others then if position('INVALID_OR_EXPIRED_INVITATION' in sqlerrm)=0 then raise; end if; end $$;

-- C. Only manage_members can enumerate/issue/revoke staff invitations.
select set_config('request.jwt.claim.sub','c1211111-1111-1111-1111-111111111111',true);
do $$ declare n int; begin select count(*) into n from public.get_organization_member_invitations(current_setting('t.org')::uuid); if n<>1 then raise exception 'ORG_INVITE_LIST_WRONG:%',n; end if; end $$;
select set_config('request.jwt.claim.sub','c1222222-2222-2222-2222-222222222222',true);
do $$ begin perform * from public.get_organization_member_invitations(current_setting('t.org')::uuid); raise exception 'NON_MANAGER_LISTED_ORG_INVITES'; exception when others then if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if; end $$;
do $$ begin perform public.issue_organization_member_invitation(current_setting('t.org')::uuid,array['manage_ads']::text[],'112-staff-issue'); raise exception 'NON_MANAGER_ISSUED_ORG_INVITE'; exception when others then if position('NOT_AUTHORIZED' in sqlerrm)=0 then raise; end if; end $$;

-- D. Revocation makes token unusable.
select set_config('request.jwt.claim.sub','c1211111-1111-1111-1111-111111111111',true);
do $$ declare r jsonb; begin r:=public.issue_organization_member_invitation(current_setting('t.org')::uuid,array['manage_ads']::text[],'112-revoke-issue'); perform set_config('t.revoke_token',r->>'invite_token',true); perform set_config('t.revoke_id',r->>'invitation_id',true); end $$;
select public.revoke_organization_member_invitation(current_setting('t.revoke_id')::uuid,'112-revoke');
select set_config('request.jwt.claim.sub','c1244444-4444-4444-4444-444444444444',true);
do $$ begin perform public.accept_organization_member_invitation(current_setting('t.revoke_token'),'112-revoked-accept'); raise exception 'REVOKED_ORG_INVITE_ACCEPTED'; exception when others then if position('INVALID_OR_EXPIRED_INVITATION' in sqlerrm)=0 then raise; end if; end $$;

-- E. An invitation does not preserve authority after its issuer loses manage_members.
select set_config('request.jwt.claim.sub','c1211111-1111-1111-1111-111111111111',true);
select set_config('t.manager2member',(public.add_organization_member(current_setting('t.org')::uuid,current_setting('t.manager2')::uuid,'112-add-manager2')->>'member_id'),true);
select public.set_organization_member_capability(current_setting('t.manager2member')::uuid,'manage_members',true,'112-manager2-cap');
do $$ declare r jsonb; begin r:=public.issue_organization_member_invitation(current_setting('t.org')::uuid,array['manage_classes']::text[],'112-old-authority'); perform set_config('t.old_token',r->>'invite_token',true); end $$;
select set_config('t.ownermember',(select id::text from public.organization_members where organization_id=current_setting('t.org')::uuid and account_id=current_setting('t.owner')::uuid and status='active'),true);
select public.set_organization_member_capability(current_setting('t.ownermember')::uuid,'manage_members',false,'112-remove-owner-manager');
select set_config('request.jwt.claim.sub','c1244444-4444-4444-4444-444444444444',true);
do $$ begin
  perform public.accept_organization_member_invitation(current_setting('t.old_token'),'112-old-authority-accept');
  raise exception 'OLD_ORG_AUTHORITY_SURVIVED';
exception when others then if position('INVITER_NO_LONGER_AUTHORIZED' in sqlerrm)=0 then raise; end if; end $$;

-- F. Invalid capabilities, direct table/private resolver and anonymous paths stay closed.
select set_config('request.jwt.claim.sub','c1233333-3333-3333-3333-333333333333',true);
do $$ begin perform public.issue_organization_member_invitation(current_setting('t.org')::uuid,array['super_admin']::text[],'112-bad-cap'); raise exception 'INVALID_CAPABILITY_INVITE_ALLOWED'; exception when others then if position('INVALID_ORGANIZATION_CAPABILITY' in sqlerrm)=0 then raise; end if; end $$;
select set_config('request.jwt.claim.sub','c1255555-5555-5555-5555-555555555555',true);
do $$ begin perform count(*) from public.organization_member_invitations; raise exception 'DIRECT_ORG_INVITE_READ_ALLOWED'; exception when insufficient_privilege then null; end $$;
do $$ begin perform * from app_private.resolve_active_organization_member_invitation('rloi_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'); raise exception 'PRIVATE_ORG_RESOLVER_EXEC_ALLOWED'; exception when insufficient_privilege then null; end $$;
reset role;
set local role anon;
do $$ begin perform public.get_organization_member_invitation_preview('rloi_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'); raise exception 'ANON_ORG_PREVIEW_ALLOWED'; exception when insufficient_privilege then null; end $$;
do $$ begin perform public.accept_organization_member_invitation('rloi_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA','anon'); raise exception 'ANON_ORG_ACCEPT_ALLOWED'; exception when insufficient_privilege then null; end $$;

rollback;
select 'V13_ORGANIZATION_MEMBER_INVITATION_PASS' as result;
