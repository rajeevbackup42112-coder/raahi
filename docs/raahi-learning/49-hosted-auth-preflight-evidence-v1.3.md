# Raahi Learning V1.3 — Hosted Auth Preflight Evidence

Status: **R1 PRECHECK COMPLETE — EXTERNAL BROWSER/AUTH-CONFIG BOUNDARY REMAINS**

Date: 2026-09-13  
Repository: `rajeevbackup42112-coder/raahi`  
Branch: `raahi-learning-implementation-v1`  
Supabase DEV: `iiwwmqokaeflaenhlyip` (`ap-south-1`)

This is execution evidence only. It does not replace `47-ai-builder-v2-internal-retrofit-closure-v1.3.md` or `48-hosted-auth-and-walking-skeleton-runbook-v1.3.md` and does not change frozen product rules.

## Verified read-only state

- Supabase project is `ACTIVE_HEALTHY`.
- `auth.users` = **0**.
- `auth.identities` = **0**.
- `public.accounts` = **0**.
- duplicate non-empty `auth.users.phone_change` groups = **0**.
- migrations through `1021_v13_phone_trust_command_guards` are present.
- Security Advisor = **0 findings**.
- active Supabase publishable key exists; no secret key was copied into repository evidence.
- no Raahi Learning Vercel project/deployment was found in the connected Vercel team, so no new hosting/deployment was performed.

## External boundary confirmed

The connected Supabase capability exposes database/project operations but not the hosted Auth provider configuration surface required to enable/configure Google and SMS/test OTP. The currently authorized Remote Desktop Commander device is offline, so no legitimate interactive browser session is available in this execution context.

Therefore the real hosted Google round trip and phone OTP proof have **not** been claimed as passed. No fake OTP, synthetic Auth user, public deployment, database redesign, or unrelated implementation work was introduced.

## Exact next action

When an authorized browser surface is available, execute `48-hosted-auth-and-walking-skeleton-runbook-v1.3.md` without widening scope:

1. verify/configure hosted Google provider and exact redirect allow list;
2. complete real Google → Supabase Auth → Raahi Account bootstrap and logout/login continuity;
3. verify hosted phone provider/SMS or DEV fixed-test-OTP settings;
4. run initial phone attachment and periodic same-phone trust refresh with Auth-user continuity checks;
5. immediately run the mandatory two-actor walking skeleton:
   **Google → Account/bootstrap → Learner context → discovery → Enquiry → provider engage → Class Invitation → phone interruption/resume → Membership → Class → contextual message**;
6. only after R4 passes continue by vertical slice.

Do not start another horizontal audit or feature pass while this external gate is unresolved.
