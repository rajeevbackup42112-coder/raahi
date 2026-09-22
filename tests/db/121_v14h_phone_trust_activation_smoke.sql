-- Raahi Learning V1.4H activation smoke.
-- Run inside a transaction; no production residue.

begin;

insert into auth.users(id,aud,role,email,phone,phone_confirmed_at)
values(
  '8a111111-1111-4111-8111-111111111111',
  'authenticated',
  'authenticated',
  'v14h-fresh@test.invalid',
  '919111111111',
  now()
);

insert into auth.users(id,aud,role,email)
values(
  '8a222222-2222-4222-8222-222222222222',
  'authenticated',
  'authenticated',
  'v14h-unverified@test.invalid'
);

set local role authenticated;

select set_config('request.jwt.claim.sub','8a111111-1111-4111-8111-111111111111',true);
select public.bootstrap_account('V14H Fresh');
do $$
begin
  perform app_private.require_fresh_phone_trust();
  if (public.get_phone_trust_policy()->>'mode') <> 'phone_trust_required' then
    raise exception 'ACTIVATED_POLICY_NOT_VISIBLE';
  end if;
end
$$;

select set_config('request.jwt.claim.sub','8a222222-2222-4222-8222-222222222222',true);
select public.bootstrap_account('V14H Unverified');
do $$
begin
  perform app_private.require_fresh_phone_trust();
  raise exception 'UNVERIFIED_ACCOUNT_BYPASSED_PHONE_TRUST';
exception when others then
  if position('PHONE_TRUST_REQUIRED' in sqlerrm)=0 then raise; end if;
end
$$;

rollback;

select 'V14H_PHONE_TRUST_ACTIVATION_SMOKE_PASS' as result;
