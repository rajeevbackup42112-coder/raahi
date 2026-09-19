# Raahi Learning V1.3 — Documentation Index

Status: **V1.3 CORE IMPLEMENTATION + HOSTED AUTH/WALKING SKELETON + SE-01…SE-08 + BOUNDED RECOVERY/RELIABILITY PROVEN IN DEV. NEXT: PRODUCTION READINESS GATES.**

This folder is the canonical handover point for Raahi Learning.

> **Source-of-truth rule:** frozen written behavior + later approved V1.3 amendments + applied forward migrations define the product. Older exploratory/generated visuals do not override them.

## Product in one sentence

Raahi Learning is a **local learning community launched one Location at a time**, where people can discover legitimate learning, parents can manage learning for children, teachers/coaches/instructors and institutes can offer learning, relationships form through controlled Enquiries, and ongoing learning continues in private Classes.

Core journey: **Find → Enquire → optional Trial → Class Invitation → Join Class → Learn**

## Read first now

1. [`99-handover.md`](99-handover.md) — **current resume point and continuation prompt**.
2. [`73-security-catalog-hardening-v1.3.md`](73-security-catalog-hardening-v1.3.md) — latest catalog-security hardening and runtime ACL proof.
3. [`72-production-operations-monitoring-backup-restore-runbook-v1.3.md`](72-production-operations-monitoring-backup-restore-runbook-v1.3.md) — prepared production operations, monitoring, backup and restore procedure.
4. [`71-bounded-reliability-observability-recovery-v1.3.md`](71-bounded-reliability-observability-recovery-v1.3.md) — latest bounded reliability, database-health, rollback and recovery-boundary evidence.
5. [`70-recovery-private-cache-release-readiness-v1.3.md`](70-recovery-private-cache-release-readiness-v1.3.md) — recovery/cache/release-packaging closure.
6. [`69-class-race-recovery-proof-v1.3.md`](69-class-race-recovery-proof-v1.3.md) — race, idempotency, stale-session and shared-browser proof.
7. [`68-post-se08-combined-regression-v1.3.md`](68-post-se08-combined-regression-v1.3.md) — exact post-SE-08 combined-regression anchor.
8. [`52-master-lifecycle-gates-traceability-v1.3.md`](52-master-lifecycle-gates-traceability-v1.3.md) — active lifecycle gate/control document.
9. [`41-authentication-phone-trust-v1.3.md`](41-authentication-phone-trust-v1.3.md) — frozen Google-primary + periodic phone-trust policy.
10. [`07-decision-log-v1.md`](07-decision-log-v1.md) — canonical product decisions.
11. [`38-backend-implementation-complete-v1.2.md`](38-backend-implementation-complete-v1.2.md) — completed V1.2 backend baseline.
12. [`19-consolidated-database-blueprint-v1.2.md`](19-consolidated-database-blueprint-v1.2.md) and [`20-consolidated-sql-migration-plan-v1.2.md`](20-consolidated-sql-migration-plan-v1.2.md) — consolidated physical/schema baseline.

The older index reference to `31-staging-load-security-chaos-plan-v1.2.md` is not a usable file on this implementation branch; do not treat that ghost reference as current evidence.

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
- `1022` through `1031` — closed V1.3 vertical-slice / side-effect migrations recorded in their owning closure documents
- `1032_v13_invitation_acceptance_fk_indexes` — preventive covering indexes for invitation `accepted_by_account_id` foreign keys
- `1033_v13_deferred_anonymous_location_rpc_acl` — removes unusable anonymous location RPC/helper EXECUTE grants while anonymous marketplace browsing remains deferred

Current V1.3 markers include:

- `V13_CONTEXTUAL_INBOX_ORG_PICKER_PASS`
- `V13_LEARNER_SELF_ACCESS_INVITATION_PASS`
- `V13_ORGANIZATION_MEMBER_INVITATION_PASS`
- `V13_NOTIFICATION_TRANSITION_WIRING_PASS`
- `V13_PHONE_TRUST_PROJECTION_PASS`
- `V13_PHONE_TRUST_COMMAND_GATE_CORE_PASS`
- `V13_PHONE_TRUST_COMMAND_GUARDS_PASS`

Historical Security Advisor after 1021: **0 findings**. Current 2026-09-19 DEV Security Advisor reports one warning: leaked-password protection is disabled. The two former unindexed-foreign-key Performance Advisor findings are closed by migration 1032; migration 1033 closes the anonymous-location RPC ACL inconsistency. Remaining unused-index notices are informational for this young DEV workload.

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

The implementation is no longer waiting for the original hosted-Auth/walking-skeleton proof; that work is complete.

Proven in DEV now includes:

- real hosted Google/phone continuity and the walking skeleton;
- genuine-session/OIDC DEV identity harness;
- 20-persona cohort;
- SE-01 through SE-08;
- exact post-SE-08 combined regression;
- bounded Class race/recovery/shared-browser privacy;
- account/session-isolated private-thread cache;
- guarded offline release packaging;
- migration 1032 FK-index closure;
- bounded release reliability: 20 genuine personas, 800 authenticated reads, 20 cross-account denial checks and 20 browser sign-ins with no latency warnings;
- read-only DB health snapshot and repeatable `scripts/raahi-learning-release-health.sql`;
- migration-1032 reverse/recreate transaction rehearsal.

Remaining production-readiness gates are intentionally separate from product redesign:

1. production-like load/soak/capacity testing against expected pilot traffic and production-like compute;
2. production monitoring, alert delivery and escalation ownership;
3. database recovery targets/retention and isolated restore rehearsal;
4. off-platform Storage-object backup plus object restore proof;
5. leaked-password-protection resolution/acceptance and remaining production security configuration;
6. periodic real-provider same-phone Google/SMS trust refresh;
7. dedicated Learning production Supabase project and final domain;
8. production OAuth/SMS/redirect/secrets configuration;
9. production-candidate regression;
10. controlled pilot/go-no-go criteria;
11. explicit Rajeev approval before public launch.

Do not use the separate Where Is My Raahi project as Learning production or restore infrastructure. Do not call the system production-ready and do not deploy publicly without explicit approval.
