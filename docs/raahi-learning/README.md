# Raahi Learning V1.2 — Documentation Index

Status: **CONTROLLED SUPABASE IMPLEMENTATION ACTIVE. FOUNDATION + IDENTITY PASS. LOCATIONS PASS. CURRENT STOP: BEFORE LEARNER SHARE CODES (`0250`).**

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
2. [`34-foundation-identity-implementation-result-v1.2.md`](34-foundation-identity-implementation-result-v1.2.md) — first real DB slice PASS.
3. [`35-implementation-branch-legacy-migration-isolation.md`](35-implementation-branch-legacy-migration-isolation.md) — migration product-boundary correction.
4. [`36-locations-implementation-result-v1.2.md`](36-locations-implementation-result-v1.2.md) — Locations real DB slice PASS.
5. [`00-product-ui-freeze-v1.md`](00-product-ui-freeze-v1.md) — frozen product behavior.
6. [`01-domain-model-v1.md`](01-domain-model-v1.md) — conceptual model/invariants.
7. [`02-architecture-blueprint-v1.md`](02-architecture-blueprint-v1.md) — architecture boundaries.
8. [`04-command-permission-matrix-v1.md`](04-command-permission-matrix-v1.md) — command/permission intent.
9. [`05-acceptance-regression-v1.md`](05-acceptance-regression-v1.md) — Given/When/Then regressions.
10. [`06-raahi-ads-v1.md`](06-raahi-ads-v1.md) — Ads rules.
11. [`18-ui-page-inventory-v1.1.md`](18-ui-page-inventory-v1.1.md) — inspected UI inventory.
12. [`19-consolidated-database-blueprint-v1.2.md`](19-consolidated-database-blueprint-v1.2.md) — final physical design source.
13. [`20-consolidated-sql-migration-plan-v1.2.md`](20-consolidated-sql-migration-plan-v1.2.md) — final migration sequence.
14. [`22-implementation-runbook-v1.2.md`](22-implementation-runbook-v1.2.md) — slice procedure.
15. [`23-final-acceptance-traceability-v1.2.md`](23-final-acceptance-traceability-v1.2.md) — UI/data/command/test mapping.
16. [`24-supabase-execution-checklist-v1.2.md`](24-supabase-execution-checklist-v1.2.md) — environment checklist.
17. [`29-master-test-case-catalog-v1.2.md`](29-master-test-case-catalog-v1.2.md) — master QA catalog.
18. [`31-staging-load-security-chaos-plan-v1.2.md`](31-staging-load-security-chaos-plan-v1.2.md) — real runtime load/security/chaos plan.
19. [`32-canonical-test-personas-fixtures-v1.2.md`](32-canonical-test-personas-fixtures-v1.2.md) — deterministic test personas.

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

Applied `0200–0204` and passed:

- lifecycle/state rules;
- selected-Location independence;
- Location Interest uniqueness/history/eligibility;
- Local Manager exact Location scope;
- aggregate-only readiness;
- Account closure responsibility;
- RLS/direct-write/anon protections;
- idempotency and audit behavior.

Runtime markers:

- `LOCATIONS_RUNTIME_TESTS_PASS`
- `LOCATIONS_POST_HARDENING_SMOKE_PASS`

Security Advisor after Locations: **0 findings**. Performance Advisor has only expected unused-index INFO notices on the empty database.

All synthetic runtime data was rolled back; dev fixture rows remain zero.

## Implementation branch

Branch: `raahi-learning-implementation-v1`

The `supabase/migrations/` subtree is explicitly **Raahi Learning only**. Historical mobility migrations inherited from older Raahi work were removed from this execution path before Locations was applied.

Current real DB tests include:

- `tests/db/010_foundation_identity_runtime_smoke.sql`
- `tests/db/020_locations_runtime_smoke.sql`
- `tests/db/021_locations_post_hardening_smoke.sql`

Backend-free model evidence remains at `tests/model/pre_supabase_model_tests.py` with documented expanded run of **5,349,992 cases/operations, 0 invariant failures**.

## Current boundary

> **STOP BEFORE `0250_learner_share_codes.sql`.**

The next eligible slice is Learner private share codes only. Do not start Organizations/Discovery (`0300+`) until that slice passes its own lifecycle/security/RLS/retry gate.

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