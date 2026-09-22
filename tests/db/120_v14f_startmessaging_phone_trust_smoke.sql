-- Raahi Learning V1.4F StartMessaging schema smoke.
-- Transaction wrapped; no residue.

begin;

insert into auth.users(id,aud,role,email)
values('8f111111-1111-1111-1111-111111111111','authenticated','authenticated','v14f-phone@test.invalid');

insert into public.phone_trust_challenges(
  id,auth_user_id,phone_e164,provider,provider_verification_id,otp_digest,state,verify_attempts,expires_at
) values (
  '8f222222-2222-2222-2222-222222222222',
  '8f111111-1111-1111-1111-111111111111',
  '+919876543210',
  'startmessaging',
  'provider-message-id',
  repeat('a',64),
  'sent',
  0,
  now()+interval '5 minutes'
);

insert into public.phone_trust_challenges(
  id,auth_user_id,phone_e164,provider,provider_verification_id,state,verify_attempts,expires_at
) values (
  '8f333333-3333-3333-3333-333333333333',
  '8f111111-1111-1111-1111-111111111111',
  '+919876543210',
  'messagecentral',
  'legacy-verification-id',
  'sent',
  0,
  now()+interval '5 minutes'
);

do $$
begin
  begin
    insert into public.phone_trust_challenges(
      auth_user_id,phone_e164,provider,provider_verification_id,state,expires_at
    ) values (
      '8f111111-1111-1111-1111-111111111111',
      '+919876543210',
      'startmessaging',
      'missing-digest',
      'sent',
      now()+interval '5 minutes'
    );
    raise exception 'STARTMESSAGING_NULL_DIGEST_ACCEPTED';
  exception when check_violation then null;
  end;

  begin
    insert into public.phone_trust_challenges(
      auth_user_id,phone_e164,provider,provider_verification_id,otp_digest,state,expires_at
    ) values (
      '8f111111-1111-1111-1111-111111111111',
      '+919876543210',
      'startmessaging',
      'bad-digest',
      'plaintext-123456',
      'sent',
      now()+interval '5 minutes'
    );
    raise exception 'STARTMESSAGING_BAD_DIGEST_ACCEPTED';
  exception when check_violation then null;
  end;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub','8f111111-1111-1111-1111-111111111111',true);

do $$
begin
  perform 1 from public.phone_trust_challenges limit 1;
  raise exception 'AUTHENTICATED_BROWSER_READ_CHALLENGE_LEDGER';
exception when insufficient_privilege then null;
end $$;

do $$
begin
  insert into public.phone_trust_challenges(
    auth_user_id,phone_e164,provider,provider_verification_id,otp_digest,state,expires_at
  ) values (
    '8f111111-1111-1111-1111-111111111111',
    '+919876543210',
    'startmessaging',
    'browser-forged',
    repeat('b',64),
    'sent',
    now()+interval '5 minutes'
  );
  raise exception 'AUTHENTICATED_BROWSER_WROTE_CHALLENGE_LEDGER';
exception when insufficient_privilege then null;
end $$;

reset role;
rollback;

select 'V14F_STARTMESSAGING_SCHEMA_SMOKE_PASS' as result;
