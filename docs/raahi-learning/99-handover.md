# Raahi Learning V1.3 — Handover / Current State

**Read this file first in a new conversation.**

Repository: `rajeevbackup42112-coder/raahi`  
Implementation branch: `raahi-learning-implementation-v1`  
Canonical docs: `docs/raahi-learning/`

> This branch is isolated from older Raahi ride work on `main`. Do not replay mobility migrations or overwrite the older commute app.

## Current status

**V1.2 backend, the bounded V1.3 backend/browser delta, the AI Builder v2 retrofit, hosted Auth core proof, the DEV genuine-session harness, and the mandatory R4 walking skeleton are all closed/proven in DEV. The 20-persona genuine-session cohort is now proven. The active sequence is advertiser/Raahi Ads convergence → bounded Organization staff capability convergence → remaining vertical slices → adversarial/reliability/security/launch gates.**

Supabase DEV project: `iiwwmqokaeflaenhlyip`, region `ap-south-1`.

The old 2026-09-13 zero-Auth preflight is historical only. Real hosted Google/phone identities now exist, Auth→Account continuity is proven, the original Rajeev R4 phone-interruption/resume chain remains durable, and the final Class-message / notification / copied-link privacy boundary is autonomously proven in isolated cloud browsers. The normal regression foundation now uses DEV-only OIDC-protected test identities with genuine Supabase sessions and intact RLS. See `50-dev-test-identity-session-harness-v1.3.md`, `51-hosted-auth-r4-walking-skeleton-closure-v1.3.md`, and `52-master-lifecycle-gates-traceability-v1.3.md`.

Do **not** restart product design, rebuild the database, continue random bug fixing, or deploy publicly.

Read next:

1. `52-master-lifecycle-gates-traceability-v1.3.md`
2. `51-hosted-auth-r4-walking-skeleton-closure-v1.3.md`
3. `50-dev-test-identity-session-harness-v1.3.md`
4. `47-ai-builder-v2-internal-retrofit-closure-v1.3.md`
5. `44-ai-builder-v2-retrofit-gate-v1.3.md`
6. `45-v1.3-screen-backend-contract-audit.md`
7. `46-v1.3-side-effects-matrix-audit.md`
8. `41-authentication-phone-trust-v1.3.md`
9. `48-hosted-auth-and-walking-skeleton-runbook-v1.3.md` (historical/regression runbook)
10. `49-hosted-auth-preflight-evidence-v1.3.md` (historical preflight only)

## Frozen product rules

- `Account ≠ Learner`; Learner owns learning history.
- One Account may learn, teach, manage a Learner and represent an Organization.
- One active managing guardian per Learner in V1.
- No turning-18 migration/lifecycle.
- Active manager owns formal learner-side marketplace/relationship decisions where a manager exists; otherwise active self-access may act.
- Guardian authority never grants Test-taking impersonation.
- No public Learner directory.
- Discovery/Learning Request journeys converge on controlled Enquiry.
- Trial remains optional inside Enquiry.
- Pending Class Invitation reserves capacity; Membership begins only after acceptance.
- One responsible Teacher per Class in V1.
- Activity unifies Assignment/Practice/Exercise.
- Test definition locks at first valid Attempt; guardian receives oversight only.
- Selected Location changes discovery/community, not existing private Classes/Messages/history.
- Community remains local/authenticated; no global Community or unrestricted DM.
- No attendance, generic progress percentage, public star ratings/reviews, institute ERP/payroll, or platform tuition-payment collection.
- Ads are education-only, Sponsored-labelled, aggregate-only for advertisers and excluded from Class/Activity/Test/private-message surfaces.
- UI/workspace selection never grants authority.
- UI does not directly mutate operational tables; canonical RPCs own consequential transitions.
- Realtime invalidates/refetches only.

## V1.3 authentication + phone-trust direction

Intended production flow:

**Google sign-in → Raahi Account → editable Raahi name/photo → intent-based setup → phone verification when first required → ordinary Google/session returns thereafter.**

Rules:

- Google is primary authentication.
- Google name/photo are onboarding defaults only, not authority/legal verification.
- Phone is periodic trust/contact proof, not routine login.
- 90-day phone freshness is the frozen V1.3 policy.
- Stale phone trust does not block ordinary existing learning, Test-taking, existing Class access, existing contextual messaging or safety actions.
- Fresh trust gates only selected creation/escalation actions.
- Do not use paid Advanced Phone MFA merely to implement this rule.
- Do not add an application fake-OTP bypass.
- Anonymous marketplace browsing remains deferred.

### Backend implementation

Supabase Auth's server-owned phone confirmation state is the trust clock; no duplicate client-owned Raahi trust timestamp is used.

Applied DEV migrations after V1.2:

- `1015_v13_contextual_inbox_and_org_teacher_picker`
- `1016_v13_learner_self_access_invitations`
- `1017_v13_organization_member_invitations`
- `1018_v13_notification_transition_wiring`
- `1019_v13_notification_initial_enquiry_dedup`
- `1020_v13_phone_trust_projection`
- `1021_v13_phone_trust_command_guards`

Runtime markers include:

- `V13_CONTEXTUAL_INBOX_ORG_PICKER_PASS`
- `V13_LEARNER_SELF_ACCESS_INVITATION_PASS`
- `V13_ORGANIZATION_MEMBER_INVITATION_PASS`
- `V13_NOTIFICATION_TRANSITION_WIRING_PASS`
- `V13_PHONE_TRUST_PROJECTION_PASS`
- `V13_PHONE_TRUST_COMMAND_GUARDS_PASS`

Security Advisor after 1021: **0 findings**.

## AI Builder v2 internal retrofit closure

The finite internal Screen ↔ Backend findings are closed:

- `teacher-members` renderer;
- exact Community report target;
- `community-post` included in route inventory;
- capability-aware Organization controls;
- safe Notification destinations;
- private invitation bearer removed from OAuth redirect query and kept only through local same-origin handoff;
- stronger route/capability/deep-link/test oracles.

The side-effects matrix is complete/frozen. Remaining non-walking-skeleton side-effect implementation stays queued for owning vertical slices after the real walking skeleton.

## Browser/frontend evidence

- reachable canonical routes: **84**;
- desktop/mobile live contract: **168/168 PASS**;
- issues: **0**;
- guard failures: **0**;
- focused V1.3 action contracts: **12/12 PASS**;
- privileged deep-link checks: **32/32 PASS**;
- semantic checks: **15/15 PASS**;
- workspace checks: **154/154 PASS**;
- interaction checks: **26/26 PASS**;
- no direct operational-table browser DML;
- no phone-primary login path in `live.js`;
- no raw Account UUID workflow.

Frozen anchors:

- `app.fixture.js`: `6eb67b36931c45aa4113c77005d82c13bb14ec145500e08cfd92130ebcef576c`
- `styles.css`: `b2d89e454f8e13712d10058c876f5efe2c8c69acf73dd6aade158241900f7bdd`

Current retrofit anchors:

- `app.live-core-v13.js`: `b8fea9446bba5171aa399d709eede2a0403949e96015157aa0ab1db320834a0f`
- `live.js`: `cdc44f514b1f396799313c977a4a48fe8efad33ae1f6054db776682c977796aa`

## Source recovery / persistent artifact

GitHub reconstruction:

```bash
node apps/raahi-learning/build-source-v13.mjs
```

Verified immutable base tar:

`9aa71d002775f719970fcf6d48c324f4f3270ac9f65aa1c7e8a2f9f17c2dc9cc`

Verified retrofit patch:

- gzip SHA-256: `8a68163024ef1b100ebc4d56b8b1cfa56bf3459fc9f897952b6ca5602a19afa9`
- raw SHA-256: `ced0f5ca5b590e8ca344011f8f008c8fa719d57cca6ca3ead63b01a4fc6efc08`

Persistent ChatGPT Library backup:

`/Raahi Learning/Raahi_Learning_Integrated_V1.3_DEV.zip`

ZIP SHA-256:

`379dece3fb33fadd68843823a82917469b77e39b8d24448328b713ff98b246ef`

## Current execution gate

R4 is closed. Do **not** repeat the manual Rajeev multi-browser walking skeleton unless a regression specifically requires provider-smoke evidence.

Current sequence:

1. core learner/teacher, managed-parent/Organization, and Local Manager/Platform Admin UI convergence are already proven (docs 54–56);
2. converge advertiser/Raahi Ads workspace with real Organization advertising authority;
3. converge bounded capability-specific Organization staff surfaces;
4. every defect is classified Domain / Integration / Implementation / Test-Harness before a fix;
5. close remaining work one vertical slice at a time;
6. then run adversarial/recovery/race testing;
7. finally complete reliability, security, load, provider-smoke and launch-readiness gates.

The R4 on-demand workflow is `.github/workflows/raahi-learning-r4-class-thread.yml`. It is regression evidence, not an ordinary per-commit mutation suite.

### Defect handling rule

Before changing product design, classify failures as Domain, Integration, Implementation, or Test/Harness. Only a genuine Domain defect triggers:

`rules → entities → relationships → states → permissions → UI → tests → architecture/DB`.

Do not modify frozen business rules merely to turn a failing test green.

## Recommended continuation prompt

> Continue Raahi Learning V1.3 from `raahi-learning-implementation-v1`. Read `docs/raahi-learning/52-master-lifecycle-gates-traceability-v1.3.md`, `51-hosted-auth-r4-walking-skeleton-closure-v1.3.md`, `50-dev-test-identity-session-harness-v1.3.md`, `47-ai-builder-v2-internal-retrofit-closure-v1.3.md`, and `99-handover.md`. Do not restart product design, hosted-Auth setup, or R4. The active sequence is advertiser/Raahi Ads convergence, then bounded Organization staff capability convergence, using genuine DEV sessions. Keep Google/SMS as small provider-smoke suites; no fake OTP and no public deployment.
