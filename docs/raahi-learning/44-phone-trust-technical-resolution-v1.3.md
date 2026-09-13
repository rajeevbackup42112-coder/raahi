# Raahi Learning V1.3 — Phone Trust Technical Resolution

Status: **IMPLEMENTATION RESOLUTION PRESERVED; FIRST-ATTACH HARDENING + REAL HOSTED PROOF REMAIN GATES.**

This document does not change which actions require fresh phone trust. It resolves how freshness is represented/proven server-side and records a current Supabase Auth edge case that must be handled before production use.

## 1. Durable trust source remains valid

V1.3 continues to use Supabase Auth's server-owned `auth.users.phone_confirmed_at` as the phone-trust clock.

The live DEV database shape confirms:

- `phone` exists and is protected by a unique index;
- `phone_confirmed_at` exists;
- pending `phone_change`, `phone_change_token` and `phone_change_sent_at` exist;
- `phone_change` itself has **no unique index**;
- reauthentication fields exist, but a sent reauthentication timestamp is not proof that the user completed phone verification.

Current Supabase Auth source behavior also confirms:

- `phone_change` verification calls the phone-change confirmation path and updates the confirmed phone plus `phone_confirmed_at`;
- normal `sms` verification finds the existing user by the confirmed phone and calls `ConfirmPhone`, which sets `phone_confirmed_at = now()`;
- successful SMS verification then issues an OTP-authenticated session.

Therefore the earlier idea of adding a separate browser/app-owned freshness timestamp is still unnecessary.

## 2. V1.3 implementation decision

Do **not** add `accounts.phone_trust_verified_at` merely to mirror Auth state.

DEV migration `1020_v13_phone_trust_projection` derives:

- `unverified`: no confirmed Auth phone / no `phone_confirmed_at`;
- `fresh`: confirmed phone exists and `phone_confirmed_at + 90 days > now()`;
- `stale`: confirmed phone exists but that 90-day window has expired.

Public authenticated projection:

`get_my_phone_trust()`

Private helpers:

- `app_private.read_my_phone_trust()`
- `app_private.has_fresh_phone_trust()`
- `app_private.require_fresh_phone_trust()`

No client-supplied timestamp or boolean is accepted.

Migration `1021_v13_phone_trust_command_guards` uses that derived state on the frozen set of trust-sensitive creation/escalation commands only.

## 3. Initial phone attachment — supported path, new hardening requirement

For a Google-authenticated Account without a confirmed phone, the intended supported flow remains:

1. capture the initiating Auth user ID;
2. user enters an E.164 phone number in the Raahi phone-check UX;
3. browser calls Supabase Auth `updateUser({ phone })`;
4. Supabase sends a phone-change OTP;
5. browser verifies with `verifyOtp({ phone, token, type: 'phone_change' })`;
6. returned Auth user ID must equal the initiating Auth user ID;
7. Google identity must still belong to that same Auth user;
8. Supabase confirms the phone and updates `phone_confirmed_at`;
9. `get_my_phone_trust()` must derive `fresh`;
10. the original Raahi action is resumed through its normal canonical command, which rechecks current state/authority/capacity.

No second Raahi "confirm trust" write is required merely to create a freshness timestamp.

### Current Supabase `phone_change` edge case

Supabase published a troubleshooting advisory on 2026-09-11 describing a current `updateUser({ phone })` edge case: phone-change verification locates a user through `auth.users.phone_change`, while `phone_change` is not unique. Abandoned duplicate pending changes can therefore cause verification to affect an unintended Auth user.

The canonical DEV schema matches that precondition: `phone` is unique, `phone_change` is not.

Raahi must therefore not treat initial phone attachment as production-ready until the following mitigation is implemented and tested:

- define a pending-phone-change grace period **longer than the configured OTP validity plus safety margin**;
- clear stale pending `phone_change` state according to the current Supabase-recommended cleanup pattern;
- before initiating a Raahi-managed attachment, fail closed if another non-stale pending claim exists for the same normalized phone;
- after verification, compare Auth user ID before/after and fail closed on any mismatch;
- re-read current Auth identity/phone state rather than trusting the browser request that initiated the flow;
- verify logout → Google login still resolves the same Auth user and same Raahi Account.

Do **not** add a uniqueness constraint/index directly to Supabase-managed `auth.users.phone_change` without explicit vendor support; that would couple Raahi to internal Auth schema behavior.

Do **not** implement stale cleanup until hosted Auth OTP expiry/settings are known, because the cleanup grace period must not invalidate a still-valid OTP.

## 4. Periodic same-phone re-verification — trust clock is technically supported

When the already-confirmed phone becomes stale, do **not** call `updateUser({ phone: samePhone })` merely to force a new phone-change event.

The intended periodic flow is:

1. preserve the intended Raahi action/draft;
2. capture the currently signed-in Auth user ID and confirmed phone;
3. request an OTP for that already-linked phone using Supabase phone OTP with user creation disabled;
4. verify using normal `sms` OTP;
5. current Supabase Auth source calls `ConfirmPhone`, refreshing `phone_confirmed_at`, and returns an OTP-authenticated session;
6. returned Auth user ID must equal the initiating Auth user ID;
7. confirmed phone must be unchanged;
8. Google identity must still remain linked to the same Auth user;
9. re-read `get_my_phone_trust()` and require `fresh`;
10. resume the original canonical Raahi command;
11. later logout → Google login must still resolve the same Auth user and same Raahi Account.

The Raahi UI does **not** expose phone OTP as its normal login button. Google remains the product's primary sign-in UX. The temporary OTP-authenticated session is an implementation consequence of proving control of the already-linked phone, not a Raahi capability/authority grant.

Real hosted proof is still mandatory before this flow becomes live.

## 5. Why `reauthenticate()` is not the trust clock

Supabase `reauthenticate()` can send a nonce to a signed-in user's email or phone for sensitive account operations, but current evidence does not show completion of that flow updating `phone_confirmed_at`.

`reauthentication_sent_at` proves only that a challenge was sent, not that phone control was successfully demonstrated.

Therefore V1.3 must not derive 90-day phone freshness from:

- `reauthentication_sent_at`;
- a client boolean;
- a client timestamp;
- "OTP sent" state;
- UI completion alone.

The durable trust clock remains completed phone confirmation evidence.

## 6. Identity-continuity invariants

Phone verification is trust proof, not Raahi authorization.

Mandatory invariants for both first attach and periodic refresh:

- initiating Auth user ID is captured before the phone step;
- successful verification must return the same Auth user ID;
- expected confirmed phone must match after verification;
- the Google identity must remain associated with the same Auth user;
- `bootstrap_account` / Account resolution must still return the same Raahi Account;
- phone verification never changes Learner, guardian, teacher, Organization or admin authority;
- resumed actions always call the ordinary canonical command and re-check current server state;
- stale phone trust never removes ordinary existing learning/Test/safety access;
- no public phone-primary login UI is introduced;
- user creation must be disabled during periodic phone OTP proof;
- any identity mismatch fails closed and the intended command is not resumed.

## 7. DEV runtime evidence already proved

`V13_PHONE_TRUST_PROJECTION_PASS`

proves database derivation of:

- no phone → `unverified`;
- old confirmation → `stale`;
- recent confirmation → `fresh`;
- private guard rejects unverified/stale;
- changing the server-owned Auth confirmation timestamp changes trust;
- anonymous callers cannot read the projection.

`V13_PHONE_TRUST_COMMAND_GUARDS_PASS`

proves the selected command gates, including that completed idempotent retries and protective/non-escalating actions are not incorrectly blocked.

Supabase Security Advisor after migration 1021: **0 findings**.

These are database/command proofs, not substitutes for hosted Auth proof.

## 8. Canonical DEV Auth state at this checkpoint

At the 2026-09-13 technology-proof checkpoint, canonical Learning DEV has:

- `auth.users`: **0 users**;
- `auth.identities`: **0 identities**.

Therefore no real Google OAuth or phone verification round trip has yet completed on project `iiwwmqokaeflaenhlyip`.

The packaged V1.3 Learning frontend does point to this canonical DEV project. A repository-root `.env` points to a different older Raahi project and must not be used as Learning Auth evidence or casually repointed, because that root application belongs to older mobility work.

## 9. External proof required before live phone-check implementation

The following must be demonstrated against hosted DEV Auth:

### Google continuity

1. hosted Google provider enabled/configured;
2. real browser Google sign-in succeeds;
3. one `auth.users` row + Google identity exist;
4. `bootstrap_account` resolves exactly one Raahi Account;
5. logout → Google login returns the same Auth user and Raahi Account.

### First phone attachment

6. hosted phone/test-OTP configuration is known, including OTP validity;
7. stale pending-change cleanup grace can be derived safely;
8. signed-in Google user attaches phone through `phone_change` verification;
9. before/after Auth user ID is identical;
10. Google identity remains linked;
11. `phone_confirmed_at` becomes recent and trust becomes `fresh`;
12. logout → Google login still returns the same user/Account.

### Periodic refresh

13. make/provision trust stale in DEV without changing the business relationship;
14. same confirmed phone receives an OTP with user creation disabled;
15. normal `sms` verification returns the same Auth user;
16. `phone_confirmed_at` advances;
17. Google identity remains linked;
18. trust returns to `fresh`;
19. preserved trust-sensitive action resumes and revalidates current state.

Only after these pass should the browser phone-check stub be replaced by live Auth calls.

## 10. Current boundary

The connected Supabase capability can manage/query database state but does not expose the hosted Auth provider/test-OTP configuration surface needed for this proof. Do not add fake application OTP logic to bypass that boundary.

No migration rollback or 1020/1021 redesign is justified by the current evidence. The trust clock survives review; the remaining work is hosted-Auth configuration, first-attach hardening, and real identity-continuity proof.