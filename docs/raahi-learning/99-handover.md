# Raahi Learning V1.3 — Handover / Current State

**Read this file first in a new conversation.**

Repository: `rajeevbackup42112-coder/raahi`  
Implementation branch: `raahi-learning-implementation-v1`  
Canonical docs: `docs/raahi-learning/`

> This branch is isolated from older Raahi ride work on `main`. Do not replay mobility migrations or overwrite the older commute app.

## Current status

**V1.2 backend remains complete, and the bounded V1.3 UX/backend/browser delta is implemented and regression-tested in DEV.**

Supabase DEV project: `iiwwmqokaeflaenhlyip`, region `ap-south-1`.

The V1.3 product/UX review is closed. The existing domain model was deliberately preserved. Google-primary authentication plus periodic phone trust is the principal product amendment; real hosted-Auth evidence for that amendment remains the next unfinished technical gate.

Read `43-v1.3-implementation-checkpoint.md` for the exact checkpoint.

## Product rules that remain frozen

- `Account ≠ Learner`; Learner owns learning history.
- One Account may learn, teach, manage a Learner and represent an Organization.
- One active managing guardian per Learner in V1; do not add Family Supporters/multi-guardian hierarchy without new evidence.
- No turning-18 migration/lifecycle.
- Active manager owns formal learner-side marketplace/relationship decisions where a manager exists; otherwise active self-access may act.
- Guardian authority never grants Test-taking impersonation.
- No public Learner directory.
- Direct discovery and Learning Request journeys converge on controlled Enquiry.
- Trial is optional and remains inside Enquiry rather than becoming a mandatory lifecycle.
- Pending Class Invitation reserves capacity; Membership begins only after acceptance.
- One responsible Teacher per Class in V1.
- Activity unifies Assignment / Practice / Exercise.
- Test definition locks at first valid Attempt; guardian receives oversight only, not learner Attempt/definition authority.
- Selected Location changes discovery/community, not existing private Classes/Messages/history.
- Community remains local/authenticated; no global Community or unrestricted DM.
- No attendance, generic progress percentage, public star ratings/reviews, institute ERP/payroll, or platform tuition-payment collection.
- Ads are education-only, Sponsored-labelled, aggregate-only for advertisers and excluded from Class/Activity/Test/private-message surfaces.
- UI/workspace selection is never authorization; server relationships/capabilities remain authoritative.
- UI does not directly mutate operational tables; canonical RPCs own consequential transitions.
- Realtime invalidates/refetches only.

## V1.3 auth/trust direction

Intended production flow:

**Google sign-in → Raahi Account → editable Raahi name/photo → intent-based setup → phone verification when first required → ordinary Google/session returns thereafter.**

Rules:

- Google is primary authentication.
- Google name/photo are onboarding defaults only; they are not legal verification or authority data.
- Phone is periodic trust/contact proof, not the normal login method.
- Roughly 90-day phone freshness is intended.
- Stale phone trust must not block ordinary existing learning, Test-taking, existing Class access or safety access.
- Fresh phone trust should gate only the selected trust-sensitive/new-relationship actions defined in `41-authentication-phone-trust-v1.3.md`.
- Do not use paid Advanced Phone MFA merely to implement this rule.
- Do not add an application fake-OTP bypass.
- Anonymous marketplace browsing is deferred, not required for V1.3.

## Applied V1.3 backend delta

DEV migrations after the completed V1.2 baseline:

- `1015_v13_contextual_inbox_and_org_teacher_picker`
- `1016_v13_learner_self_access_invitations`
- `1017_v13_organization_member_invitations`
- `1018_v13_notification_transition_wiring`
- `1019_v13_notification_initial_enquiry_dedup`

Implemented contracts include:

- unified authorized conversation projection;
- narrow eligible Organization responsible-teacher picker;
- private expiring Learner self-access invitation issue/preview/accept/revoke;
- private expiring Organization member invitation issue/preview/accept/revoke;
- derived best-effort notifications for important Enquiry/Class/Activity/Test transitions.

Invitation secrets are hash-only at rest, one-time/expiring, and acceptance rechecks current authority. No public Account/Learner directory was added.

## Runtime/security evidence

V1.3 markers:

- `V13_CONTEXTUAL_INBOX_ORG_PICKER_PASS`
- `V13_LEARNER_SELF_ACCESS_INVITATION_PASS`
- `V13_ORGANIZATION_MEMBER_INVITATION_PASS`
- `V13_NOTIFICATION_TRANSITION_WIRING_PASS`

Touched V1.2 regressions rerun successfully:

- `REQUESTS_ENQUIRIES_RUNTIME_TESTS_PASS`
- `CLASS_COMMUNICATION_RUNTIME_TESTS_PASS`
- `ACTIVITIES_SUBMISSIONS_RUNTIME_TESTS_PASS`
- `TESTS_ATTEMPTS_RUNTIME_TESTS_PASS`

Supabase Security Advisor after the V1.3 delta: **0 findings**.

Do not claim real load/stress/soak evidence yet.

## Browser/frontend checkpoint

V1.3 browser integration includes Google-primary entry UX, first-use intent/setup, Add Learner, private Learner login links, private staff invitations, Organization teacher picker, unified Messages and real notification destinations.

A focused action test found and fixed a real modal event-delegation bug; confirmation modals rendered outside `#app`, so delegation was corrected centrally.

Evidence:

- canonical V1.3 routes: **83**;
- desktop/mobile live contract: **166/166**;
- issues: **0**;
- guard failures: **0**;
- focused V1.3 action paths: **7/7 PASS**;
- no direct browser DML against operational tables;
- no phone-primary OTP flow in `live.js`;
- no raw Account-UUID user workflow.

Frozen anchors remain byte-identical:

- `app.fixture.js`: `6eb67b36931c45aa4113c77005d82c13bb14ec145500e08cfd92130ebcef576c`
- `styles.css`: `b2d89e454f8e13712d10058c876f5efe2c8c69acf73dd6aade158241900f7bdd`

## Source recovery / persistent artifact

GitHub reconstruction:

```bash
node apps/raahi-learning/build-source-v13.mjs
```

Required reconstructed tar SHA-256:

`9aa71d002775f719970fcf6d48c324f4f3270ac9f65aa1c7e8a2f9f17c2dc9cc`

See `apps/raahi-learning/SOURCE_BUNDLE_V1.3.md`.

Persistent ChatGPT Library backup:

`/Raahi Learning/Raahi_Learning_Integrated_V1.3_DEV.zip`

ZIP SHA-256:

`c1acb034d81da01379886cbea7311fd500b30375cb48b99c4e8bdde5e6a8e113`

## What remains

The next work is **not another product redesign**. Execute in this order:

1. Verify current Supabase Auth docs/changelog before changes.
2. Configure/verify real DEV Google OAuth through an authorized hosted-Auth surface.
3. Prove Google → Supabase session → `bootstrap_account` → editable profile → server-derived contexts.
4. Configure hosted DEV fixed/test phone OTP through an authorized Auth-management surface. The connected database connector does not currently expose this config.
5. Prove trustworthy server-side evidence after phone verification.
6. Implement the minimal durable phone-trust record/commands and 90-day guards according to `41-authentication-phone-trust-v1.3.md`.
7. Run the 25-persona real-auth E2E cohort, including multi-workspace, parent/Learner, private invitations, institute, Messages/notifications, Tests, safety and Ads boundaries.
8. Rerun complete DB/browser/security regressions + Security Advisor.
9. Then perform concurrency/load/chaos and production launch-readiness gates. Do not deploy implicitly.

## Primary continuation sources

Read in this order:

1. `43-v1.3-implementation-checkpoint.md`
2. `41-authentication-phone-trust-v1.3.md`
3. `42-v1.3-ui-db-reconciliation.md`
4. `40-final-product-ux-audit-v1.3-draft.md`
5. `07-decision-log-v1.md`
6. `38-backend-implementation-complete-v1.2.md`
7. `19-consolidated-database-blueprint-v1.2.md`
8. `20-consolidated-sql-migration-plan-v1.2.md`
9. `23-final-acceptance-traceability-v1.2.md`
10. `31-staging-load-security-chaos-plan-v1.2.md`

Historical design/reconciliation files remain decision traceability; they do not override the later applied forward migrations or the V1.3 checkpoint.

## Change-control rule

Do not reopen V1.3 because another platform behaves differently. A new business-rule/UX change needs a discovered contradiction, a security/privacy defect, failed E2E/usability evidence, or real pilot-user evidence.

## Recommended continuation prompt

> Continue Raahi Learning V1.3 from `raahi-learning-implementation-v1`. Read `RAAHI_LEARNING_HANDOVER.md`, `docs/raahi-learning/99-handover.md`, and `docs/raahi-learning/43-v1.3-implementation-checkpoint.md`. Product/UX review is closed; V1.3 migrations 1015–1019 and browser integration are regression-tested. Continue with real DEV Google OAuth + hosted test-phone configuration, then prove and implement the frozen 90-day phone-trust policy. Do not redesign the domain, add fake OTP, replay mobility work, or deploy publicly.
