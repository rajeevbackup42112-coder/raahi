# Raahi Learning V1.4H — StartMessaging Phone Trust Public Live Evidence — 2026-09-23

Status: **PUBLIC LIVE — STARTMESSAGING PHONE TRUST ENFORCED FOR TRUST-SENSITIVE ACTIONS**

Repository: `rajeevbackup42112-coder/raahi`
Branch: `raahi-learning-implementation-v1`
Supabase: `iiwwmqokaeflaenhlyip`
Public origin: `https://learning.myraahi.co.in`

## 1. Exact frontend source

Production application source SHA:

`5d864733af9f32c6de6f604764e82d26f04856a6`

GitHub Model Tests:
- run #668
- run ID `35786971583`
- conclusion: success

Release manifest SHA-256:

`6950b83e31769652ce4dc2803496d7ceaf8586220643ac0eb25fee9b4147c2f4`

Release packaging:
- 15 deployable public files
- 14 content hashes in build-meta
- deploy-copy mismatches: 0
- forbidden public DEV/secret matches: 0
- DEV login file absent
- phone trust config: `phone_trust_required`
- provider config: `startmessaging`

## 2. Preview

Preview deployment:
- ID: `49f4a4bc-ce5f-4e4e-8388-66849d4f4b6b`
- branch: `v14h-5d86473-preview`
- source: `5d86473`
- exact URL: `https://49f4a4bc.raahi-learning-prod.pages.dev`
- alias: `https://v14h-5d86473-preview.raahi-learning-prod.pages.dev`

Preview verification:
- exact commit match
- hash mismatches: 0
- forbidden public matches: 0
- `phone_trust_required`: true
- `startmessaging` provider: true

## 3. Production deployment

Production deployment:
- ID: `33e55d0e-a346-46d4-a756-0c580a5b08f4`
- branch: `main`
- source: `5d86473`
- exact Pages URL: `https://33e55d0e.raahi-learning-prod.pages.dev`
- custom origin: `https://learning.myraahi.co.in`

Immediate frontend rollback anchor:
- ID: `cca89cdc-88e4-4c89-9b2b-50c35825a8b3`
- source: `b9901ac`

Production custom-domain verification:
- exact build-meta SHA: `5d864733af9f32c6de6f604764e82d26f04856a6`
- hash mismatches: 0
- forbidden public/secret matches: 0
- `phone_trust_required`: true
- `startmessaging` provider: true

## 4. Permanent database activation

Applied migration:

`20260922214214_v14h_activate_startmessaging_phone_trust`

It changes the runtime setting to:

`phone_trust_mode = phone_trust_required`

The existing private enforcement function now returns enabled and the existing command-scoped trust gate is active.

A temporary public `get_phone_trust_policy()` convenience projection was recreated by the activation migration because an older source migration suggested it should exist. Live inspection showed that projection had intentionally been removed by migration 1038 and was unnecessary to the browser.

Security follow-up applied immediately:

`20260922214728_v14h_remove_public_phone_trust_policy_projection`

This removed the unnecessary exposed SECURITY DEFINER RPC again. The enforcement helpers remain private.

After that cleanup, Supabase Security Advisor returned no new V1.4H finding. The only remaining security warning is the pre-existing leaked-password-protection setting.

## 5. Identity continuity proof

After the user deliberately logged out and signed back in with Google:

- Google identity: `choudhary.ajit2112@gmail.com`
- Auth user ID remained `60588d97-ed6a-46d1-a22c-7671c5c56a3d`
- Raahi Account remained `dab468e9-6998-41d1-a58e-4bee8607a49f`
- lifecycle status remained active
- `platform_admin` capability remained active
- confirmed phone remained attached to the same Auth user
- the new login event updated `last_sign_in_at`
- phone trust remained `fresh`

Fresh trust:
- verified at: `2026-09-22T15:23:54.233721Z`
- fresh until: `2026-12-21T15:23:54.233721Z`
- trust horizon: 90 days

Phone OTP did not create another Account or alter Raahi authority.

## 6. Enforced protected-command proof

Before permanent activation, `phone_trust_required` was temporarily enabled inside a rollback transaction and a real protected canonical Raahi Desk publish command succeeded for Ajit's fresh-phone session.

After permanent activation, the same protected command was run again inside a rollback transaction.

Result:
- fresh trusted account: allowed through phone-trust gate
- content residue after rollback: 0

A synthetic authenticated account without phone trust was also tested inside a rollback transaction.

Result:
- `app_private.require_fresh_phone_trust()` rejected it with `PHONE_TRUST_REQUIRED`
- synthetic Auth residue: 0

Thus the server now distinguishes fresh vs unverified users while leaving no synthetic production data.

## 7. Production browser canaries

Authenticated Ajit production browser, cache-busted after activation:

`#/phone-check`

Rendered:
- **Phone trust**
- **Phone confirmed**
- **Your current phone trust is fresh.**
- **Continue**
- **Log out**

Signed-out production browser rendered the normal Welcome page:
- **Continue with Google**
- public Privacy / Terms
- copy explaining that some sensitive actions may request phone confirmation

No phone OTP became a primary login.

## 8. Phone UX

Normal users no longer need to type `+91`.

The phone field:
- is labelled **Indian mobile number**
- asks for a normal 10-digit number such as `9876543210`
- displays a fixed `+91` prefix
- states: **Raahi adds +91 automatically**
- safely normalizes pasted `+91...`, `91...`, or leading-zero Indian numbers

The phone-check surface also exposes a clear **Log out** action.

## 9. Security model

Google remains the primary authentication mechanism.

StartMessaging:
- only delivers OTPs for trust-sensitive actions
- cannot grant roles or learner/admin authority
- receives a server-generated OTP
- has its API key only in Supabase Edge Function Secrets
- is never exposed in browser JavaScript, GitHub source, Cloudflare public config, or application tables

Raahi persists only a keyed OTP digest, never OTP plaintext.

Supabase Auth remains the durable source of confirmed phone and `phone_confirmed_at`.

## 10. Current result

V1.4H is public live.

The next product gate is no longer phone-provider plumbing. It is genuine market activation: prove one real Teacher through the Founding Supply flow end-to-end, then expand only with real consented supply and factual Raahi Desk content.
