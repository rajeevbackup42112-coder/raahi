# Raahi Learning — Current Execution Handover — V1.4H Public Live — 2026-09-23

Status: **PUBLIC LIVE — GOOGLE LOGIN + STARTMESSAGING PHONE TRUST FOR TRUST-SENSITIVE ACTIONS**

Repo: `rajeevbackup42112-coder/raahi`
Branch: `raahi-learning-implementation-v1`
Supabase: `iiwwmqokaeflaenhlyip`
Public: `https://learning.myraahi.co.in`

## Read first

1. `117-current-execution-handover-v14h-public-live-2026-09-23.md`
2. `116-v14h-startmessaging-phone-trust-public-live-evidence-2026-09-23.md`
3. `115-startmessaging-phone-trust-activation-contract-v1.4h.md`
4. `114-current-execution-handover-v14f-startmessaging-proof-2026-09-22.md`
5. `112-startmessaging-phone-trust-provider-contract-v1.4f.md`
6. `111-current-execution-handover-v14e-public-live-2026-09-22.md`
7. `101-founding-supply-assisted-teacher-onboarding-contract-v1.4c.md`
8. `92-market-activation-seeding-blueprint-v1.4.md`
9. `99-handover.md`

Do not restart completed V1.4A/B/C/D/E/F/H design or provider integration.

## Exact live application state

Frontend source SHA:

`5d864733af9f32c6de6f604764e82d26f04856a6`

Production deployment:

`33e55d0e-a346-46d4-a756-0c580a5b08f4`

Immediate frontend rollback anchor:

`cca89cdc-88e4-4c89-9b2b-50c35825a8b3` / source `b9901ac`

GitHub qualification:
- Model Tests #668
- run ID `35786971583`
- success

Release manifest SHA-256:

`6950b83e31769652ce4dc2803496d7ceaf8586220643ac0eb25fee9b4147c2f4`

## Permanent DB migrations

StartMessaging provider bridge schema:

`20260922150119_v14f_startmessaging_phone_trust`

Phone-trust enforcement activation:

`20260922214214_v14h_activate_startmessaging_phone_trust`

Security cleanup removing the unnecessary public policy projection:

`20260922214728_v14h_remove_public_phone_trust_policy_projection`

Current runtime setting:

`phone_trust_mode = phone_trust_required`

## Authentication and trust

Normal login remains **Continue with Google**.

Phone verification:
- is not a second login;
- is requested only when an existing trust-sensitive canonical command needs fresh phone trust;
- uses StartMessaging only as OTP delivery;
- is valid for 90 days after successful confirmation;
- does not alter Raahi roles or learner/admin authority.

StartMessaging API key exists only in Supabase Edge Function Secrets.

## User-facing phone UX

For first phone attach:
- user enters a normal 10-digit Indian mobile number;
- Raahi visibly supplies `+91`;
- helper copy says Raahi adds +91 automatically;
- pasted `+91...`, `91...`, and leading-zero Indian forms normalize safely.

Phone-check also includes **Log out**.

## Proven real continuity

Ajit logged out and signed back in with Google.

The system resolved to:
- same Supabase Auth user;
- same Raahi Account;
- same confirmed phone;
- same global Platform Admin capability;
- phone trust still `fresh`.

Authenticated production phone-check renders **Phone confirmed**.

## Enforced gate proof

With production enforcement active:
- Ajit's fresh-phone protected command passed in a rollback transaction;
- rollback residue = 0;
- an unverified synthetic account was denied with `PHONE_TRUST_REQUIRED`;
- synthetic residue = 0.

The server, not the browser, remains authoritative.

## Authority state

Global Platform Admin:
- `choudhary.ajit2112@gmail.com`

Gomoh Local Manager:
- `rajeev.backup1.2112@gmail.com`

Dhanbad Local Manager:
- `rajeev.backup2.2112@gmail.com`

No role was altered by phone verification.

## Security note

Activation briefly recreated an old public trust-policy SECURITY DEFINER projection. Supabase Security Advisor flagged it. The projection was not used by the browser and was immediately removed in migration `20260922214728`.

After cleanup, there is no new V1.4H Security Advisor finding. The pre-existing leaked-password-protection warning remains.

## Next product gate

Return to genuine market activation.

Use one real Teacher first:

1. Teacher signs in with Google.
2. If a trust-sensitive action requires it, Teacher confirms a real mobile number through the now-live StartMessaging flow.
3. Teacher selects a real Location and submits **Ask Raahi to help**.
4. Correct Local Manager receives the private request.
5. Manager prepares only a truthful bounded draft based on Teacher-supplied details.
6. Teacher reviews and personally accepts or declines.
7. Only Teacher acceptance publishes the Teacher Profile + first Teaching Option.
8. Verify genuine supply appears correctly in Explore.
9. Verify the Teacher can subsequently manage their own profile/availability.
10. Repeat only with a small genuine founding cohort.

Do not fabricate Teachers, Learning Requests, enquiries, comments, reactions, reviews, demand, popularity or traction.

After the first genuine Teacher flow is green, continue factual Raahi Desk launch content and consented Founding Supply according to `92-market-activation-seeding-blueprint-v1.4.md`.
