# Raahi Learning V1.4F — StartMessaging Hosted Phone Trust Proof — 2026-09-22

Status: **HOSTED PROVIDER PROOF PASSED — GLOBAL ENFORCEMENT STILL DISABLED**

## Provider proof

StartMessaging KYC is approved. A real provider sandbox OTP send returned success/201 and status `sent`.

Raahi then performed a real hosted send through the production Supabase Edge Function:
- function: `phone-trust-startmessaging`
- provider: `startmessaging`
- challenge state created as `sent`
- OTP plaintext was never persisted
- keyed digest was present
- provider API key stayed in Supabase Edge Function Secrets only

## Production application

Dormant StartMessaging-capable client bridge is public live from application SHA:

`7f54580503f35ca710e5452a350a988ff6883810`

Production deployment:

`37fb558e.raahi-learning-prod.pages.dev`

Public release config remains:
- `phoneTrustMode = controlled_pilot_google_only`
- `phoneTrustProvider = disabled`

Thus normal users are not yet forced through phone verification.

## Migration

Applied:

`20260922150119_v14f_startmessaging_phone_trust`

It:
- adds `startmessaging` provider support to the server-only challenge ledger;
- stores only a 64-hex keyed digest for StartMessaging challenges;
- repairs the historical +91 E.164 regex constraint;
- preserves browser denial on the challenge table.

## Real Ajit hosted proof

Authenticated Auth user:
`60588d97-ed6a-46d1-a22c-7671c5c56a3d`

Raahi Account:
`dab468e9-6998-41d1-a58e-4bee8607a49f`

Capability:
`platform_admin`

A real OTP challenge was sent to Ajit's phone.

The correct OTP attempt successfully updated Supabase Auth:
- same Auth user ID;
- confirmed phone present;
- `phone_confirmed_at` set;
- `get_my_phone_trust()` returns `fresh`;
- trust horizon = 90 days;
- same Raahi Account and Platform Admin capability preserved.

## Defect discovered

Supabase Auth normalizes the stored phone without the leading `+`, while the Raahi challenge stores canonical E.164 with `+91...`.

The first implementation compared those strings literally after successful Auth confirmation. That caused the browser to see an identity-continuity error even though the phone had already been confirmed correctly.

This was a Raahi postcondition-formatting defect, not a StartMessaging delivery failure and not an OTP failure.

## Fix

Edge Function source now canonicalizes both phone representations to digits before equality checks.

It also supports safe partial-failure reconciliation when:
- the challenge belongs to the same Auth user;
- at least one prior verification attempt occurred;
- Auth now holds the same canonical phone;
- `phone_confirmed_at` is at or after challenge creation.

The ledger was reconciled to:
- provider = `startmessaging`
- state = `verified`
- verify attempts = 1
- verified timestamp = Auth `phone_confirmed_at`

No second OTP was required.

Patch commit:

`8f0cda2fa1eb3f52ee344d2ae55a56273c25ef5b`

GitHub Model Tests:
- run #661
- run ID `35747990429`
- conclusion: success

Deployed Edge Function:
- `phone-trust-startmessaging`
- version 3
- JWT verification enabled

## Current safety state

Exactly one global Platform Admin remains Ajit.
City-admin scopes are unchanged.
StartMessaging API key is not in Git, browser assets, Cloudflare public config or application tables.

## Remaining activation gate

Before switching normal production users from Google-only controlled pilot to enforced StartMessaging phone trust:
1. clean browser refresh;
2. logout;
3. Google login again;
4. confirm same Auth user and same Raahi Account;
5. confirm phone trust remains `fresh`;
6. verify one trust-sensitive action can resume normally;
7. then update production release config to `phone_trust_required + startmessaging`;
8. preview/canary;
9. production promotion.
