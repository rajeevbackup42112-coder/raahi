# Raahi Learning V1.3 — Documentation Index

Status: **V1.2 BACKEND COMPLETE; V1.3 DELTA + AI BUILDER v2 INTERNAL RETROFIT CLOSED IN DEV. NEXT: REAL HOSTED GOOGLE/PHONE AUTH PROOF → WALKING SKELETON.**

This folder is the canonical handover point for Raahi Learning.

> **Source-of-truth rule:** frozen written behavior + later approved V1.3 amendments + applied forward migrations define the product. Older exploratory/generated visuals do not override them.

## Product in one sentence

Raahi Learning is a **local learning community launched one Location at a time**, where people can discover legitimate learning, parents can manage learning for children, teachers/coaches/instructors and institutes can offer learning, relationships form through controlled Enquiries, and ongoing learning continues in private Classes.

Core journey: **Find → Enquire → optional Trial → Class Invitation → Join Class → Learn**

## Read first now

1. [`47-ai-builder-v2-internal-retrofit-closure-v1.3.md`](47-ai-builder-v2-internal-retrofit-closure-v1.3.md) — **current canonical execution checkpoint**.
2. [`99-handover.md`](99-handover.md) — current handover summary and continuation prompt.
3. [`44-ai-builder-v2-retrofit-gate-v1.3.md`](44-ai-builder-v2-retrofit-gate-v1.3.md) — strict retrofit method/gates.
4. [`45-v1.3-screen-backend-contract-audit.md`](45-v1.3-screen-backend-contract-audit.md) — Screen↔Backend + permission-symmetry audit.
5. [`46-v1.3-side-effects-matrix-audit.md`](46-v1.3-side-effects-matrix-audit.md) — side-effects decisions.
6. [`41-authentication-phone-trust-v1.3.md`](41-authentication-phone-trust-v1.3.md) — frozen Google-primary + periodic phone-trust policy.
7. [`07-decision-log-v1.md`](07-decision-log-v1.md) — canonical product decisions including V1.3 amendment.
8. [`43-v1.3-implementation-checkpoint.md`](43-v1.3-implementation-checkpoint.md) — historical earlier V1.3 checkpoint; file 47 supersedes its current numbers/status.
9. [`38-backend-implementation-complete-v1.2.md`](38-backend-implementation-complete-v1.2.md) — completed V1.2 backend baseline.
10. [`19-consolidated-database-blueprint-v1.2.md`](19-consolidated-database-blueprint-v1.2.md) — consolidated physical design.
11. [`20-consolidated-sql-migration-plan-v1.2.md`](20-consolidated-sql-migration-plan-v1.2.md) — consolidated baseline migration contract.
12. [`23-final-acceptance-traceability-v1.2.md`](23-final-acceptance-traceability-v1.2.md) — baseline traceability.
13. [`31-staging-load-security-chaos-plan-v1.2.md`](31-staging-load-security-chaos-plan-v1.2.md) — later real runtime/load/chaos plan.

## Frozen + current V1.3 artifacts

Frozen V1.1 anchors preserved byte-for-byte:

- `app.fixture.js` SHA-256: `6eb67b36931c45aa4113c77005d82c13bb14ec145500e08cfd92130ebcef576c`
- `styles.css` SHA-256: `b2d89e454f8e13712d10058c876f5efe2c8c69acf73dd6aade158241900f7bdd`

Current retrofit source anchors:

- `app.live-core-v13.js`: `b8fea9446bba5171aa399d709eede2a0403949e96015157aa0ab1db320834a0f`
- `live.js`: `cdc44f514b1f396799313c977a4a48fe8efad33ae1f6054db776682c977796aa`

Persistent current DEV backup:

`/Raahi Learning/Raahi_Learning_Integrated_V1.3_DEV.zip`

SHA-256:

`379dece3fb33fadd68843823a82917469b77e39b8d24448328b713ff98b246ef`

GitHub source recovery:

```bash
node apps/raahi-learning/build-source-v13.mjs
```

Integrity anchors:

- immutable base tar SHA-256: `9aa71d002775f719970fcf6d48c324f4f3270ac9f65aa1c7e8a2f9f17c2dc9cc`
- retrofit patch gzip SHA-256: `8a68163024ef1b100ebc4d56b8b1cfa56bf3459fc9f897952b6ca5602a19afa9`
- retrofit patch raw SHA-256: `ced0f5ca5b590e8ca344011f8f008c8fa719d57cca6ca3ead63b01a4fc6efc08`

## Backend status

Supabase DEV: `iiwwmqokaeflaenhlyip`, `ap-south-1`.

V1.2 backend baseline is complete. V1.3 forward migrations applied in DEV:

- `1015_v13_contextual_inbox_and_org_teacher_picker`
- `1016_v13_learner_self_access_invitations`
- `1017_v13_organization_member_invitations`
- `1018_v13_notification_transition_wiring`
- `1019_v13_notification_initial_enquiry_dedup`
- `1020_v13_phone_trust_projection`
- `1021_v13_phone_trust_command_guards`

Current V1.3 markers include:

- `V13_CONTEXTUAL_INBOX_ORG_PICKER_PASS`
- `V13_LEARNER_SELF_ACCESS_INVITATION_PASS`
- `V13_ORGANIZATION_MEMBER_INVITATION_PASS`
- `V13_NOTIFICATION_TRANSITION_WIRING_PASS`
- `V13_PHONE_TRUST_PROJECTION_PASS`
- `V13_PHONE_TRUST_COMMAND_GATE_CORE_PASS`
- `V13_PHONE_TRUST_COMMAND_GUARDS_PASS`

Supabase Security Advisor after 1021: **0 findings**.

Phone trust is derived from Supabase Auth's server-owned `auth.users.phone_confirmed_at`; do not add a duplicate client-owned Raahi trust timestamp merely to represent freshness.

## AI Builder v2 browser/integration checkpoint

- reachable routes: **84**;
- desktop + mobile live contract: **168/168 PASS**;
- contract issues: **0**;
- guard failures: **0**;
- focused V1.3 action contracts: **12/12 PASS**;
- privileged deep-link checks: **32/32 PASS**;
- semantic checks: **15/15 PASS**;
- workspace checks: **154/154 PASS**;
- interaction checks: **26/26 PASS**;
- no direct browser DML against operational tables;
- no phone-primary login path in `live.js`;
- no raw Account UUID ordinary-user workflow.

Retrofit gaps closed include `teacher-members`, exact Community report targeting, `community-post` route coverage, capability-aware Organization UI, safe Notification destinations, private invitation OAuth query hardening, and stronger browser/test oracles.

The side-effects matrix is complete. Remaining attention-signal gaps are intentionally queued for their owning vertical slices **after** the walking skeleton rather than being implemented as a new horizontal notification project.

## Non-negotiable principles

- Account and Learner are distinct; Learner owns learning.
- One active managing guardian per Learner in V1.
- Parent acts for Learner, never by identity impersonation.
- Manager formal-decision authority does not grant Test-taking authority.
- No turning-18 migration/lifecycle.
- No public Learner directory.
- UI does not directly mutate core operational state.
- Current server state beats stale UI.
- Consequential commands are idempotent.
- Pending Invitation reserves Class capacity at send time.
- Class and Ads capacity cannot oversell.
- Test definition locks at first valid Attempt.
- Realtime invalidates/refetches; PostgreSQL is source of truth.
- Sponsored and organic remain separate; protected learning/private-message surfaces are ad-free.
- Workspace/navigation selection is not authorization.
- Private Storage reads re-check business authorization.

## Current boundary

The next unknown is external, not another product/schema brainstorming phase.

The connected Supabase management capability does not expose hosted Auth provider/test-OTP configuration, and no authenticated remote browser was connected at the current checkpoint.

Next prove:

1. hosted DEV Google provider configuration;
2. real browser Google → Supabase Auth session;
3. `bootstrap_account` resolves/creates exactly one Raahi Account and same Google returns to the same Account/history;
4. hosted DEV phone attach/reverify through supported SMS/test-OTP configuration;
5. server-owned phone confirmation evidence updates and migration 1020 reports fresh state;
6. interrupted trust-sensitive action resumes after verification.

Then execute the mandatory real walking skeleton:

**Google sign-in → Account/bootstrap → Learner context → discovery → Enquiry → provider engage → Class Invitation → real phone interruption/resume → Membership → Class → contextual message.**

Only after the walking skeleton passes continue by vertical slice, then persona/adversarial E2E, concurrency/load/security/chaos and explicit production go/no-go.

Do not call the system production-ready and do not deploy implicitly.
