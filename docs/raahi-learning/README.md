# Raahi Learning V1.2 — Documentation Index

Status: **CONTROLLED SUPABASE IMPLEMENTATION ACTIVE. FOUNDATION + IDENTITY PASS. LOCATIONS PASS. LEARNER SHARE CODES PASS. CURRENT STOP: BEFORE ORGANIZATIONS / TEACHER DISCOVERY (`0300–0302`).**

This folder is the canonical handover point for Raahi Learning.

> **Source-of-truth rule:** frozen written behavior + inspected clickable UI define the product. Generated/exploratory images are inspiration only where they agree with those sources.

## Product

Raahi Learning is a **local learning community launched one Location at a time**.

Core journey:

**Find → Enquire → optional Trial → Class Invitation → Join Class → Learn**

## Inspected clickable UI

Artifact: `Raahi_Learning_Clickable_UI_v1.1.zip`  
Library: `/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`  
SHA-256: `2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

Final UI audit:

- 77 canonical routes/pages;
- 154 desktop/mobile checks — 0 issues;
- 32 privileged deep-link checks — 0 unguarded;
- 26 interaction/business-rule checks — 0 failures;
- 15 semantic/accessibility samples — 0 issues.

## Read first

1. [`99-handover.md`](99-handover.md) — current state and next gate.
2. [`34-foundation-identity-implementation-result-v1.2.md`](34-foundation-identity-implementation-result-v1.2.md) — Foundation + Identity PASS.
3. [`35-implementation-branch-legacy-migration-isolation.md`](35-implementation-branch-legacy-migration-isolation.md) — migration product-boundary correction.
4. [`36-locations-implementation-result-v1.2.md`](36-locations-implementation-result-v1.2.md) — Locations PASS.
5. [`37-learner-share-codes-implementation-result-v1.2.md`](37-learner-share-codes-implementation-result-v1.2.md) — Learner Share Codes PASS.
6. [`00-product-ui-freeze-v1.md`](00-product-ui-freeze-v1.md) — frozen product behavior.
7. [`01-domain-model-v1.md`](01-domain-model-v1.md) — conceptual model/invariants.
8. [`02-architecture-blueprint-v1.md`](02-architecture-blueprint-v1.md) — architecture boundaries.
9. [`04-command-permission-matrix-v1.md`](04-command-permission-matrix-v1.md) — command/permission intent.
10. [`05-acceptance-regression-v1.md`](05-acceptance-regression-v1.md) — Given/When/Then regressions.
11. [`06-raahi-ads-v1.md`](06-raahi-ads-v1.md) — Ads rules.
12. [`18-ui-page-inventory-v1.1.md`](18-ui-page-inventory-v1.1.md) — inspected UI inventory.
13. [`19-consolidated-database-blueprint-v1.2.md`](19-consolidated-database-blueprint-v1.2.md) — final physical design source.
14. [`20-consolidated-sql-migration-plan-v1.2.md`](20-consolidated-sql-migration-plan-v1.2.md) — final migration sequence.
15. [`22-implementation-runbook-v1.2.md`](22-implementation-runbook-v1.2.md) — slice procedure.
16. [`23-final-acceptance-traceability-v1.2.md`](23-final-acceptance-traceability-v1.2.md) — UI/data/command/test mapping.
17. [`24-supabase-execution-checklist-v1.2.md`](24-supabase-execution-checklist-v1.2.md) — environment checklist.
18. [`29-master-test-case-catalog-v1.2.md`](29-master-test-case-catalog-v1.2.md) — master QA catalog.
19. [`31-staging-load-security-chaos-plan-v1.2.md`](31-staging-load-security-chaos-plan-v1.2.md) — real runtime load/security/chaos plan.
20. [`32-canonical-test-personas-fixtures-v1.2.md`](32-canonical-test-personas-fixtures-v1.2.md) — deterministic test personas.

Pre-Supabase review/history docs `21`, `25–28`, `30`, `33` remain useful evidence. Historical design/delta files `03/08/09/10/11/13/14/15/16/17` remain decision traceability; consolidated V1.2 sources win where wording differs.

## Supabase implementation status

Target dev project:

- ref: `iiwwmqokaeflaenhlyip`
- region: `ap-south-1`
- PostgreSQL 17.6

Read-only inspection occurred before first mutation.

### Foundation + Identity — PASS

Runtime markers:

- `FOUNDATION_IDENTITY_RUNTIME_TESTS_PASS`
- `POST_HARDENING_SECURITY_SMOKE_PASS`

### Locations — PASS

Applied `0200–0204` and passed lifecycle/state, selected-Location independence, Location Interest, Local Manager scope, aggregate readiness, closure responsibility, idempotency/RLS/security tests.

Runtime markers:

- `LOCATIONS_RUNTIME_TESTS_PASS`
- `LOCATIONS_POST_HARDENING_SMOKE_PASS`

### Learner Share Codes — PASS

Applied:

- `0250_learner_share_codes`

Verified real DB behavior includes:

- 192-bit private token generation;
- hash-only persistence;
- one-time plaintext return;
- no secret replay through Idempotency;
- one active code per Learner;
- replacement revocation;
- formal learner-side authority;
- paused protective revoke;
- expired/revoked/consumed non-resolution;
- no public Learner resolver/search/browse endpoint;
- direct table/RPC privilege denial;
- raw-token audit/idempotency exclusion.

Runtime markers:

- `SHARE_CODE_BASIC_PASS`
- `SHARE_CODE_PERMISSION_PASS`
- `SHARE_CODE_STATE_PASS`
- `SHARE_CODE_TERMINAL_PASS`

Security Advisor after Share Codes: **0 findings**. Performance Advisor has only expected `unused_index` INFO notices on the empty dev database.

All synthetic runtime data was rolled back; dev fixture rows remain zero.

## Implementation branch

Branch: `raahi-learning-implementation-v1`

The `supabase/migrations/` subtree is explicitly **Raahi Learning only**. Historical mobility migrations inherited from older Raahi work were removed from this execution path before Locations was applied.

Current real DB tests include:

- `tests/db/010_foundation_identity_runtime_smoke.sql`
- `tests/db/020_locations_runtime_smoke.sql`
- `tests/db/021_locations_post_hardening_smoke.sql`
- `tests/db/025_learner_share_codes_runtime_smoke.sql`

Backend-free model evidence remains at `tests/model/pre_supabase_model_tests.py` with documented expanded run of **5,349,992 cases/operations, 0 invariant failures**.

## Deferred share-code tests

The public invite-by-code command is intentionally not created until Classes (`0502`). Therefore atomic Invitation+consume, second consume through the real path, consume-vs-revoke concurrency, timeout-after-commit retry and endpoint abuse/rate-limit tests remain future gates.

## Current boundary

> **STOP BEFORE ORGANIZATIONS / TEACHER DISCOVERY (`0300–0302`).**

The next eligible slice is Organizations / teacher discovery only. Do not start Restrictions (`0350+`) until that slice passes ownership, capability, public projection, Save privacy, idempotency and RLS/security gates.

## Non-negotiable principles

- Account and Learner are separate identities.
- Learner owns learning history; Account performs actions.
- No public Learner directory.
- Parent/Guardian acts for Learner, never by impersonation.
- Active manager owns formal learner-side marketplace decisions; management does not grant Test-taking.
- UI never directly mutates core operational state.
- Consequential writes use canonical commands and are idempotent.
- Current server state beats stale UI.
- Navigation/workspace is never authorization.
- Pending Class Invitations reserve capacity at send time.
- Class capacity and Ads inventory may never oversell.
- Offline-origin invitation uses a private, expiring, one-time Learner share code.
- Realtime invalidates/refetches; it is not source of truth.
- Organic discovery and Sponsored serving stay separate.
- Paid visibility never buys verification, endorsement or organic rank.
- Do not casually restore Enrollment, Batch, Adult/Minor split, Attendance, generic Progress %, public ratings/reviews, public Learner search, unrestricted DM, global Community or platform tuition payments.