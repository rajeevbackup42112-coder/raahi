-- Raahi Learning V1.3 — server-derived phone trust smoke
begin;

insert into auth.users(id,aud,role,email,phone,phone_confirmed_at) values
('b1000000-0000-0000-0000-000000000001','authenticated','authenticated','unverified114@test.invalid',null,null),
('b1000000-0000-0000-0000-000000000002','authenticated','authenticated','stale114@test.invalid','+919000000002',now()-interval '91 days'),
('b1000000-0000-0000-0000-000000000003','authenticated','authenticated','fresh114@test.invalid','+919000000003',now()-interval '1 minute');

set local role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
do $$ declare j jsonb; begin
  j:=public.get_my_phone_trust();
  if j->>'state'<>'unverified' or (j->>'has_phone')::boolean then raise exception 'UNVERIFIED_STATE_BAD:%',j; end if;
end $$;
do $$ begin
  perform app_private.require_fresh_phone_trust();
  raise exception 'UNVERIFIED_TRUST_ALLOWED';
exception when others then if position('PHONE_TRUST_REQUIRED' in sqlerrm)=0 then raise; end if; end $$;

select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000002',true);
do $$ declare j jsonb; begin
  j:=public.get_my_phone_trust();
  if j->>'state'<>'stale' or j->>'masked_phone'<>'••••0002' then raise exception 'STALE_STATE_BAD:%',j; end if;
end $$;
do $$ begin
  perform app_private.require_fresh_phone_trust();
  raise exception 'STALE_TRUST_ALLOWED';
exception when others then if position('PHONE_TRUST_REQUIRED' in sqlerrm)=0 then raise; end if; end $$;

select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000003',true);
do $$ declare j jsonb; begin
  j:=public.get_my_phone_trust();
  if j->>'state'<>'fresh' or not (j->>'has_phone')::boolean then raise exception 'FRESH_STATE_BAD:%',j; end if;
  if (j->>'fresh_for_days')::int<>90 then raise exception 'FRESH_WINDOW_BAD:%',j; end if;
end $$;
select app_private.require_fresh_phone_trust();

reset role;
update auth.users set phone_confirmed_at=now() where id='b1000000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000002',true);
do $$ declare j jsonb; begin
  j:=public.get_my_phone_trust();
  if j->>'state'<>'fresh' then raise exception 'AUTH_REFRESH_NOT_REFLECTED:%',j; end if;
end $$;

reset role;
set local role anon;
do $$ begin
  perform public.get_my_phone_trust();
  raise exception 'ANON_PHONE_TRUST_READ_ALLOWED';
exception when insufficient_privilege then null; end $$;

rollback;
select 'V13_PHONE_TRUST_PROJECTION_PASS' as result;
