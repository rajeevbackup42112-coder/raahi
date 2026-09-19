# Raahi Learning V1.3 — MessageCentral VerifyNow phone-trust integration

Status: **SELECTED + IMPLEMENTED IN DEV SCAFFOLD — REAL PROVIDER CREDENTIAL TEST PENDING**  
Date: 2026-09-19

## 1. Provider decision

Controlled-pilot SMS/phone-verification provider:

**MessageCentral VerifyNow**

Pilot rationale:

- Raahi does not need its own DLT entity/header/template registration for VerifyNow;
- provider-owned/pre-approved OTP sender/template path is available for India;
- pay-as-you-go pricing is appropriate for a small Gomoh + Dhanbad pilot;
- Raahi uses Google as the primary login, so SMS volume is limited to trust-sensitive actions rather than every sign-in;
- integration remains provider-replaceable.

Re-check current commercial pricing immediately before funding the provider account. Pricing is not a frozen product invariant.

Official references reviewed during selection:

- https://www.messagecentral.com/en-in/product/verify-now/api-india
- https://www.messagecentral.com/en-in/product/verify-now/verify-users-otp-sdk
- https://www.messagecentral.com/product/verify-now/overview-india

## 2. Important integration constraint

VerifyNow generates and validates its **own OTP**.

Therefore it is **not** implemented as a Supabase Send SMS Hook carrying a Supabase-generated OTP.

Instead:

1. authenticated Raahi user reaches a trust-sensitive action;
2. PostgreSQL raises the existing `PHONE_TRUST_REQUIRED` gate;
3. public release UI invokes `phone-trust-messagecentral`;
4. MessageCentral creates and sends the OTP;
5. Raahi stores only the provider verification reference and rate-limit/audit state — never the OTP;
6. user submits the code to the Raahi Edge Function;
7. Edge Function asks MessageCentral to validate the code;
8. only after `VERIFICATION_COMPLETED`, the server calls Supabase Auth Admin to set the verified phone and `phone_confirm=true`;
9. the existing `auth.users.phone_confirmed_at` remains Raahi's phone-trust source of truth;
10. the existing 90-day freshness rule remains unchanged.

This is an Integration implementation choice, not a Domain/business-rule change.

## 3. Existing frozen behavior preserved

Unchanged:

- Google remains primary login.
- Phone is periodic trust proof, not primary login.
- Phone freshness remains 90 days.
- Stale phone trust does not block ordinary learning, Tests, Classes, Messages or safety flows.
- Only selected creation/escalation actions require fresh phone trust.
- UI/workspace selection never creates authority.
- No fake OTP/test bypass is permitted for real-provider proof.

Existing DB functions remain authoritative:

- `app_private.read_my_phone_trust()`
- `app_private.has_fresh_phone_trust()`
- `app_private.require_fresh_phone_trust()`
- `public.get_my_phone_trust()`

## 4. Implemented components

### Database

Migration 1035:

`20260919181500_1035_v13_messagecentral_phone_trust_challenges.sql`

Creates:

`public.phone_trust_challenges`

The ledger stores:

- Auth user ID;
- Indian E.164 phone;
- provider name;
- MessageCentral verification ID;
- challenge state;
- verification-attempt count;
- expiry/verified timestamps.

It does **not** store the OTP.

Controls:

- RLS enabled;
- FORCE RLS;
- no anon/authenticated table grants;
- service-role-only DML.

Migration 1036 adds an explicit restrictive deny policy for anon/authenticated so the intended browser-deny posture is unambiguous.

### Edge Function

`supabase/functions/phone-trust-messagecentral/index.ts`

Deployed to Learning DEV as:

`phone-trust-messagecentral`

Current initial deployment:

- version 1;
- `verify_jwt=true`;
- no MessageCentral credentials installed yet;
- therefore incapable of sending paid SMS until provider onboarding is completed.

Controls include:

- authenticated user required;
- allowed browser origins restricted to DEV + planned public Learning origin;
- India-only phone validation for pilot;
- 3 sends / 10 minutes per Account;
- 10 sends / 24 hours per Account;
- 5 sends / 10 minutes per phone;
- max 5 verification attempts;
- short duplicate-send reuse window;
- provider OTP never logged/stored;
- provider auth credential never returned to browser.

### Browser

`apps/raahi-learning/live-product-fix-v13.js`

Behavior:

- DEV defaults to the existing Supabase OTP path;
- release builds use `window.RAAHI_RELEASE_CONFIG.phoneTrustProvider`;
- controlled-pilot release packaging sets provider to `messagecentral`;
- after provider validation, the browser re-reads `get_my_phone_trust()` and resumes the original pending action only if trust is actually `fresh`.

### Release package

`scripts/prepare-learning-release.mjs`

Public controlled-pilot artifacts include only:

`phoneTrustProvider: 'messagecentral'`

No MessageCentral customer ID, password/key, auth token or other secret is embedded in browser files.

## 5. Required provider secrets

At provider cutover, configure these **only in the Supabase Edge Function secret environment**, never in GitHub/browser/public artifact:

- `MESSAGECENTRAL_CUSTOMER_ID`
- `MESSAGECENTRAL_PASSWORD`
- `MESSAGECENTRAL_EMAIL` (registered account email; optional at API level but retained for explicit configuration)

MessageCentral's API expects the account password encoded in Base64 for token generation. Raahi stores the password only as a Supabase Edge secret and performs the Base64 encoding in memory inside the Edge Function; the user must not use an external Base64 website.

Do not paste the raw MessageCentral password or key into source control, chat logs, browser JavaScript or CI artifacts.

## 6. User-held onboarding step

Before real-provider proof:

1. create/activate the MessageCentral account;
2. fund only enough free/paid credits for pilot verification;
3. obtain the customer ID;
4. configure the three secrets directly in the Supabase project;
5. never share the raw password in chat.

This is a user-held credential step.

## 7. Mandatory real-provider proof before pilot

Use real Indian mobile numbers controlled by the test participants.

Minimum smoke:

- Airtel;
- Jio;
- at least one additional carrier if available.

For each:

1. send OTP through the public-path Edge Function;
2. confirm SMS receipt and latency;
3. submit wrong OTP and confirm rejection;
4. submit correct OTP and confirm `VERIFICATION_COMPLETED`;
5. verify `auth.users.phone_confirmed_at` is refreshed;
6. verify `get_my_phone_trust().state = 'fresh'`;
7. verify pending trust-sensitive Raahi action resumes;
8. confirm ordinary Google sign-in still works without phone OTP;
9. confirm resend/attempt rate limits;
10. confirm no OTP/provider token appears in browser/network-visible Raahi responses or logs.

The test must use the same phone only where the real account owner controls that phone. Never fabricate/bypass OTP.

## 8. Cutover failure behavior

If MessageCentral is unavailable:

- Google sign-in and ordinary learning remain available;
- only actions that already require fresh phone trust are blocked;
- Raahi must not silently mark phone trust fresh;
- no fallback provider is enabled for V1 pilot unless explicitly tested and approved.

This preserves fail-closed trust without making the whole learning product unavailable.

## 9. Future replacement

MessageCentral is an integration dependency, not a Domain dependency.

A later provider can replace VerifyNow if the replacement can prove phone possession and the server promotes the verified phone into Supabase Auth only after successful provider verification.

No learning/learner/class/permission model should need to change for a provider swap.
