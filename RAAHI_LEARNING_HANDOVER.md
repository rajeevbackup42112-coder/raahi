# Raahi Learning V1.3 — Start Here

**Repository:** `rajeevbackup42112-coder/raahi`  
**Implementation branch:** `raahi-learning-implementation-v1`  
**Canonical docs:** `docs/raahi-learning/`

## Current status

Raahi Learning V1.2 backend remains complete. The bounded **V1.3 product/UX/backend/browser delta is also implemented and regression-tested in Supabase DEV**, while real hosted Google OAuth + phone-trust evidence remains the next unfinished technical gate.

DEV Supabase project: `iiwwmqokaeflaenhlyip` (`ap-south-1`).

Read first:

1. `docs/raahi-learning/99-handover.md`
2. `docs/raahi-learning/43-v1.3-implementation-checkpoint.md`
3. `docs/raahi-learning/41-authentication-phone-trust-v1.3.md`
4. `docs/raahi-learning/42-v1.3-ui-db-reconciliation.md`
5. `docs/raahi-learning/07-decision-log-v1.md`
6. `docs/raahi-learning/38-backend-implementation-complete-v1.2.md`

## V1.3 direction

Do not redesign the domain. The existing rules remain frozen, including `Account ≠ Learner`, one managing guardian in V1, controlled Enquiry, optional Trial, Invitation before Membership, guardian Test non-impersonation, local Community, no public Learner directory and governed education-only Ads.

The principal V1.3 amendment is:

**Google-primary authentication + periodic phone trust.**

Google profile name/photo are editable onboarding defaults only. Phone verification is a periodic trust/contact proof and must not become a second routine login or remove existing learning access merely because it is stale.

Do not add Family Supporters/multi-guardian complexity, anonymous marketplace browsing, fake OTP, attendance, generic progress %, public ratings/reviews, unrestricted DM, global Community, or other deferred complexity without new evidence.

## Applied V1.3 DEV delta

Applied migrations:

- `1015_v13_contextual_inbox_and_org_teacher_picker`
- `1016_v13_learner_self_access_invitations`
- `1017_v13_organization_member_invitations`
- `1018_v13_notification_transition_wiring`
- `1019_v13_notification_initial_enquiry_dedup`

V1.3 runtime markers all pass, touched V1.2 Enquiry/Class Communication/Activities/Tests suites pass, and Supabase Security Advisor is **0 findings**.

## Browser evidence

- 83 canonical routes;
- 83 × desktop/mobile = **166/166** live-contract checks;
- **0 issues**;
- **0 guard failures**;
- focused V1.3 action paths: **7/7 PASS**;
- no direct operational-table browser DML;
- no phone-primary OTP path in `live.js`;
- no raw Account UUID user flow.

A real modal action-delegation bug was found by the focused click suite and fixed centrally before this checkpoint.

## Source recovery

Run:

```bash
node apps/raahi-learning/build-source-v13.mjs
```

Required reconstructed tar SHA-256:

`9aa71d002775f719970fcf6d48c324f4f3270ac9f65aa1c7e8a2f9f17c2dc9cc`

Source-bundle documentation: `apps/raahi-learning/SOURCE_BUNDLE_V1.3.md`.

Persistent backup artifact:

`/Raahi Learning/Raahi_Learning_Integrated_V1.3_DEV.zip`

ZIP SHA-256:

`c1acb034d81da01379886cbea7311fd500b30375cb48b99c4e8bdde5e6a8e113`

## Exact remaining boundary

Next work:

1. check current Supabase Auth docs/changelog;
2. configure/verify real DEV Google OAuth through an authorized hosted-Auth surface;
3. prove Google → Supabase session → `bootstrap_account` → editable profile → server-derived contexts;
4. configure hosted DEV fixed/test phone OTP through an authorized Auth-management surface;
5. prove trustworthy server-side evidence after phone verification;
6. implement/test the frozen 90-day phone-trust policy without blocking ordinary existing learning;
7. run the 25-persona real-auth E2E cohort and full regression/security gate;
8. then concurrency/load/chaos and launch readiness.

Do not claim production readiness or deploy publicly before those gates.

The repository `main` branch contains older Raahi work and must not be treated as the Raahi Learning implementation.
