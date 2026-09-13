# Raahi Learning V1.3 — Handover / Current State

**Read this file first in a new conversation.**

Repository: `rajeevbackup42112-coder/raahi`  
Implementation branch: `raahi-learning-implementation-v1`  
Canonical docs: `docs/raahi-learning/`

> This branch is isolated from older Raahi ride work on `main`. Do not replay mobility migrations or overwrite the older commute app.

## Current status

**V1.2 backend remains complete. The bounded V1.3 UX/backend/browser delta is implemented in DEV, and the project has now entered a one-time AI Builder Cheat Code v2 retrofit gate before any further broad implementation.**

Supabase DEV project: `iiwwmqokaeflaenhlyip`, region `ap-south-1`.

Do **not** restart product design and do **not** continue random bug fixing. Read `44-ai-builder-v2-retrofit-gate-v1.3.md` and close the missing execution gates: technology proof, complete Screen↔Backend contracts, permission symmetry, side-effects matrix, real walking-skeleton E2E, then vertical slices only.

Read `43-v1.3-implementation-checkpoint.md` for the packaged/browser checkpoint and `44-ai-builder-v2-retrofit-gate-v1.3.md` for the current execution method.

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

## V1.3 authentication + phone-trust direction

Intended production flow:

**Google sign-in → Raahi Account → editable Raahi name/photo → intent-based setup → phone verification when first required → ordinary Google/session returns thereafter.**

Rules:

- Google is primary authentication.
- Google name/photo are onboarding defaults only; they are not legal verification or authority data.
- Phone is periodic trust/contact proof, not the normal login method.
- Roughly 90-day phone freshness is intended.
- Stale phone trust must not block ordinary existing learning, Test-taking, existing Class access or safety access.
- Fresh phone trust gates only the selected trust-sensitive/new-relationship actions defined in `41-authentication-phone-trust-v1.3.md`.
- Do not use paid Advanced Phone MFA merely to implement this rule.
- Do not add an application fake-OTP bypass.
- Anonymous marketplace browsing is deferred, not required for V1.3.

### Resolved technical implementation

Supabase Auth's server-owned `auth.users.phone_confirmed_at` is now the durable phone-trust clock. Do **not** add a duplicate Raahi `phone_trust_verified_at` field merely to represent freshness.

DEV migration `1020_v13_phone_trust_projection` derives `unverified / stale / fresh` from Auth state and a 90-day window. Runtime marker: `V13_PHONE_TRUST_PROJECTION_PASS`.

DEV migration `1021_v13_phone_trust_command_guards` is applied and the central command-gate invariant passes: `V13_PHONE_TRUST_COMMAND_GATE_CORE_PASS`. Public-RPC/conditional teaching regression coverage for 1021 is still being completed; do not mark the entire 1021 slice closed until those tests and source reconciliation are committed.

## Applied V1.3 backend delta

Applied DEV migrations after the completed V1.2 baseline:

- `1015_v13_contextual_inbox_and_org_teacher_picker`
- `1016_v13_learner_self_access_invitations`
- `1017_v13_organization_member_invitations`
- `1018_v13_notification_transition_wiring`
- `1019_v13_notification_initial_enquiry_dedup`
- `1020_v13_phone_trust_projection`
- `1021_v13_phone_trust_command_guards` — applied, final public-RPC regression/source checkpoint still open.

Implemented/verified contracts include:

- unified authorized conversation projection;
- narrow eligible Organization responsible-teacher picker;
- private expiring Learner self-access invitation issue/preview/accept/revoke;
- private expiring Organization member invitation issue/preview/accept/revoke;
- derived best-effort notifications for important Enquiry/Class/Activity/Test transitions;
- server-derived phone-trust state without a client-supplied trust timestamp;
- central phone-trust command gating that preserves completed idempotent retries and does not intentionally block protective/de-escalating actions.

Invitation secrets are hash-only at rest, one-time/expiring, and acceptance rechecks current authority. No public Account/Learner directory was added.

## Runtime/security evidence

V1.3 markers currently include:

- `V13_CONTEXTUAL_INBOX_ORG_PICKER_PASS`
- `V13_LEARNER_SELF_ACCESS_INVITATION_PASS`
- `V13_ORGANIZATION_MEMBER_INVITATION_PASS`
- `V13_NOTIFICATION_TRANSITION_WIRING_PASS`
- `V13_PHONE_TRUST_PROJECTION_PASS`
- `V13_PHONE_TRUST_COMMAND_GATE_CORE_PASS`

Touched V1.2 regressions previously rerun successfully:

- `REQUESTS_ENQUIRIES_RUNTIME_TESTS_PASS`
- `CLASS_COMMUNICATION_RUNTIME_TESTS_PASS`
- `ACTIVITIES_SUBMISSIONS_RUNTIME_TESTS_PASS`
- `TESTS_ATTEMPTS_RUNTIME_TESTS_PASS`

Supabase Security Advisor after migration 1020: **0 findings**. Run it again after the full 1021 regression/source checkpoint.

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

## Current execution gate — AI Builder v2 retrofit

Read `44-ai-builder-v2-retrofit-gate-v1.3.md`.

The sequence is now:

1. **Finish Screen ↔ Backend contract coverage** for all actionable V1.3 routes.
2. **Finish read/write permission symmetry review** — a writer must be able to read the minimum safe inputs required for the action.
3. **Finish the side-effects matrix** for notifications, audit, Storage, deep links, jobs and explicit no-side-effect decisions.
4. **Finish 1021 public-RPC/conditional-path regression + source reconciliation** without broadening phone-trust gates beyond the frozen policy.
5. **Complete real DEV Google OAuth technology proof** through an authorized hosted-Auth surface.
6. **Complete real DEV phone attach/reverify proof** using supported Auth configuration; no Raahi OTP bypass.
7. **Run the mandatory real walking skeleton:** browser → Auth → Account/bootstrap/context → Enquiry → provider engage → Invitation → phone interruption/resume → Membership → Class/message.
8. Only after the walking skeleton passes, continue remaining work **one vertical slice at a time**.
9. Run full persona/adversarial E2E.
10. Run true concurrency/load/security/chaos and production launch-readiness gates.

### Defect handling rule

Before changing product design, classify each significant failure as:

- Domain defect;
- Integration defect;
- Implementation defect;
- Test/harness defect.

Only a genuine domain defect triggers full impact analysis:

`rules → entities → relationships → states → permissions → UI → tests → architecture/DB`.

Do not modify a frozen business rule just to turn a failing test green.

## Primary continuation sources

Read in this order:

1. `44-ai-builder-v2-retrofit-gate-v1.3.md`
2. `43-v1.3-implementation-checkpoint.md`
3. `41-authentication-phone-trust-v1.3.md`
4. `42-v1.3-ui-db-reconciliation.md`
5. `40-final-product-ux-audit-v1.3-draft.md`
6. `07-decision-log-v1.md`
7. `38-backend-implementation-complete-v1.2.md`
8. `19-consolidated-database-blueprint-v1.2.md`
9. `20-consolidated-sql-migration-plan-v1.2.md`
10. `23-final-acceptance-traceability-v1.2.md`
11. `31-staging-load-security-chaos-plan-v1.2.md`

Historical design/reconciliation files remain decision traceability; they do not override later applied forward migrations or the V1.3 checkpoint.

## Change-control rule

Do not reopen V1.3 because another platform behaves differently. A new business-rule/UX change needs a discovered contradiction, a security/privacy defect, failed E2E/usability evidence, a regulatory requirement, real pilot-user evidence, or a proven technical impossibility.

## Recommended continuation prompt

> Continue Raahi Learning V1.3 from `raahi-learning-implementation-v1`. Read `docs/raahi-learning/44-ai-builder-v2-retrofit-gate-v1.3.md`, `docs/raahi-learning/99-handover.md`, and `43-v1.3-implementation-checkpoint.md`. Do not restart product design or continue random bug fixing. Finish the AI Builder v2 retrofit in order: Screen↔Backend contracts + permission symmetry → side-effects matrix → close 1021 regression/source reconciliation → real Google/phone technology proof → mandatory real walking skeleton → vertical slices only → persona/adversarial E2E → load/security/launch gates. Do not add fake OTP or deploy publicly.
