# Raahi Learning — Current Execution Handover — V1.4F StartMessaging Proof — 2026-09-22

Status: **STARTMESSAGING HOSTED PHONE PROOF PASSED — GLOBAL PHONE-TRUST ENFORCEMENT NOT YET ENABLED**

## Exact state

Public application SHA:
`7f54580503f35ca710e5452a350a988ff6883810`

Latest phone-trust fix source:
`8f0cda2fa1eb3f52ee344d2ae55a56273c25ef5b`

Permanent migration:
`20260922150119_v14f_startmessaging_phone_trust`

Edge Function:
- name: `phone-trust-startmessaging`
- version: 3
- verify_jwt: true
- secret: `STARTMESSAGING_API_KEY` exists in Supabase Edge Function Secrets

## Proven

- StartMessaging KYC approved.
- Provider sandbox real send succeeded.
- Raahi hosted real send succeeded.
- Correct OTP confirmed Ajit's phone in Supabase Auth.
- Ajit's trust projection is now `fresh` for 90 days.
- Same Auth user, Raahi Account and `platform_admin` capability preserved.
- Challenge ledger reconciled to verified.
- OTP plaintext not stored.
- API key not exposed.

## Defect/fix

Supabase Auth stores phone without leading plus while challenge ledger uses +91 E.164. Literal comparison caused a false identity-continuity error after successful confirmation.

Fixed by canonical phone comparison plus crash/partial-failure reconciliation.

CI #661 passed.

## Important

Production release config still intentionally says:
- `controlled_pilot_google_only`
- provider `disabled`

Do not globally enable StartMessaging yet.

## Next

Perform clean logout -> Google login continuity proof for Ajit.
Then verify same Auth user/Account + fresh phone trust and one trust-sensitive action.
Only after that activate release config `phone_trust_required + startmessaging`, preview, canary and production.
