-- Raahi Learning V1.3
-- MessageCentral VerifyNow challenge ledger.
-- Browser roles receive no direct access. The authenticated Edge Function uses
-- the service-role boundary and stores provider references, never OTP codes.

create table public.phone_trust_challenges (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  phone_e164 text not null
    check (phone_e164 ~ '^\\+91[6-9][0-9]{9}$'),
  provider text not null default 'messagecentral'
    check (provider = 'messagecentral'),
  provider_verification_id text not null,
  state text not null default 'sent'
    check (state in ('sent','verified','failed','expired')),
  verify_attempts smallint not null default 0
    check (verify_attempts between 0 and 10),
  expires_at timestamptz not null,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint phone_trust_challenge_expiry_after_create
    check (expires_at > created_at),
  constraint phone_trust_challenge_verified_state
    check ((state = 'verified' and verified_at is not null) or state <> 'verified')
);

create index phone_trust_challenges_user_created_idx
  on public.phone_trust_challenges(auth_user_id, created_at desc);

create index phone_trust_challenges_phone_created_idx
  on public.phone_trust_challenges(phone_e164, created_at desc);

create index phone_trust_challenges_state_expiry_idx
  on public.phone_trust_challenges(state, expires_at);

alter table public.phone_trust_challenges enable row level security;
alter table public.phone_trust_challenges force row level security;

revoke all on table public.phone_trust_challenges from public, anon, authenticated;
grant select, insert, update, delete on table public.phone_trust_challenges to service_role;

comment on table public.phone_trust_challenges is
  'Server-only MessageCentral OTP challenge ledger for Raahi phone trust. Stores no OTP code.';
