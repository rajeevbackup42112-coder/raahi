-- Raahi Learning V1.4F — StartMessaging phone-trust provider support.
-- Browser roles keep no direct challenge-table access.
-- OTP plaintext is never persisted; StartMessaging only delivers the code.

-- Repair the legacy E.164 check: the original migration double-escaped
-- the regex backslash, so a valid +91 number could not satisfy the constraint.
alter table public.phone_trust_challenges
  drop constraint phone_trust_challenges_phone_e164_check;

alter table public.phone_trust_challenges
  add constraint phone_trust_challenges_phone_e164_check
  check (phone_e164 ~ '^\+91[6-9][0-9]{9}$');

alter table public.phone_trust_challenges
  drop constraint phone_trust_challenges_provider_check;

alter table public.phone_trust_challenges
  add constraint phone_trust_challenges_provider_check
  check (provider in ('messagecentral','startmessaging'));

alter table public.phone_trust_challenges
  add column otp_digest text;

alter table public.phone_trust_challenges
  add constraint phone_trust_challenges_startmessaging_digest_check
  check (
    provider <> 'startmessaging'
    or (otp_digest is not null and otp_digest ~ '^[0-9a-f]{64}$')
  );

comment on table public.phone_trust_challenges is
  'Server-only phone-trust OTP challenge ledger. Stores provider references and, for StartMessaging, only a keyed OTP digest; never OTP plaintext.';

comment on column public.phone_trust_challenges.otp_digest is
  'Server-only keyed digest for providers that deliver but do not validate OTPs. Never expose to browser roles.';
