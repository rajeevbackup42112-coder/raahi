# Raahi Learning V1.2 — Documentation Index

Status: **PRE-SUPABASE WORK COMPLETE. Real clickable UI inspected, final UI↔DB reconciliation passed, consolidated physical/migration contract ready, and logical mock/property testing passed. Supabase remains untouched.**

This folder is the canonical handover point for Raahi Learning. It exists so a new ChatGPT conversation, developer or coding agent can continue without relying on chat history.

> **Source-of-truth rule:** frozen written behavior + the inspected clickable UI define the product. Exploratory/generated images are visual inspiration only where they agree with those sources.

## Product in one sentence

Raahi Learning is a **local learning community launched one Location at a time**, where people can discover legitimate learning, parents can manage learning for children, teachers/coaches/instructors and institutes can offer learning, relationships form through controlled Enquiries, and ongoing learning continues in private Classes.

Core journey:

**Find → Enquire → optional Trial → Class Invitation → Join Class → Learn**

## Inspected clickable UI

Artifact: `Raahi_Learning_Clickable_UI_v1.1.zip`

Persistent Library path: `/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`

SHA-256: `2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

Audit result:

- 77 canonical routes/pages;
- 154 desktop/mobile route checks, 0 issues;
- 32 privileged deep-link checks, 0 unguarded pages;
- 26 interaction/business-rule checks, 0 failures;
- 15 semantic/accessibility sanity samples, 0 issues.

## Read these first for new implementation work

1. [`99-handover.md`](99-handover.md) — current status and next action.
2. [`00-product-ui-freeze-v1.md`](00-product-ui-freeze-v1.md) — frozen product rules.
3. [`01-domain-model-v1.md`](01-domain-model-v1.md) — conceptual entities/invariants.
4. [`02-architecture-blueprint-v1.md`](02-architecture-blueprint-v1.md) — architecture boundaries.
5. [`04-command-permission-matrix-v1.md`](04-command-permission-matrix-v1.md) — command/permission intent.
6. [`05-acceptance-regression-v1.md`](05-acceptance-regression-v1.md) — detailed Given/When/Then regressions.
7. [`06-raahi-ads-v1.md`](06-raahi-ads-v1.md) — Ads product rules.
8. [`18-ui-page-inventory-v1.1.md`](18-ui-page-inventory-v1.1.md) — frozen inspected UI page/state inventory.
9. [`19-consolidated-database-blueprint-v1.2.md`](19-consolidated-database-blueprint-v1.2.md) — **single final physical design source**.
10. [`20-consolidated-sql-migration-plan-v1.2.md`](20-consolidated-sql-migration-plan-v1.2.md) — **single final migration sequence**.
11. [`21-pre-supabase-readiness-review-v1.2.md`](21-pre-supabase-readiness-review-v1.2.md) — formal pre-Supabase PASS.
12. [`22-implementation-runbook-v1.2.md`](22-implementation-runbook-v1.2.md) — controlled slice-by-slice implementation procedure.
13. [`23-final-acceptance-traceability-v1.2.md`](23-final-acceptance-traceability-v1.2.md) — UI/data/command/test traceability.
14. [`24-supabase-execution-checklist-v1.2.md`](24-supabase-execution-checklist-v1.2.md) — checklist to use only after Supabase access is authorized.
15. [`25-pre-supabase-package-manifest-v1.2.md`](25-pre-supabase-package-manifest-v1.2.md) — package completeness manifest.
16. [`26-final-pre-supabase-consistency-audit-v1.2.md`](26-final-pre-supabase-consistency-audit-v1.2.md) — final cross-document consistency PASS.
17. [`27-pre-supabase-test-strategy-v1.2.md`](27-pre-supabase-test-strategy-v1.2.md) — comprehensive scenario/state/auth/concurrency/load/security/chaos test strategy.
18. [`28-mock-model-test-results-v1.2.md`](28-mock-model-test-results-v1.2.md) — **executed backend-free randomized/property tests: PASS**.
19. [`12-implementation-approval-v1.md`](12-implementation-approval-v1.md) — final approval record.

## Historical review chain

The following remain valuable for decision traceability but no longer need to be merged manually during implementation:

- `03-database-blueprint-v1.md` — first physical draft;
- `03-database-blueprint-v1.1.md` — reviewed physical baseline;
- `08-database-blueprint-review-v1.md`;
- `09-sql-readiness-review-v1.md`;
- `10-sql-migration-plan-v1.md` — first migration-plan draft;
- `10-sql-migration-plan-v1.1.md` — corrected baseline plan;
- `11-sql-migration-plan-review-v1.md`;
- `13-ui-db-reconciliation-v1.md`;
- `14-ui-db-implementation-delta-v1.md`;
- `15-ui-page-build-review-gate-v1.md` — closed;
- `16-ui-page-freeze-and-final-reconciliation-v1.1.md`;
- `17-final-ui-db-implementation-delta-v1.1.md`.

If historical wording differs from the consolidated V1.2 blueprint/plan, **V1.2 wins**.

## Implementation branch scaffold

A dedicated branch exists for future environment work:

`raahi-learning-implementation-v1`

It currently contains only pre-Supabase scaffolding, including:

- `IMPLEMENTATION_START_HERE.md`;
- `supabase/migrations/README.md`;
- `supabase/ENVIRONMENT_INSPECTION_TEMPLATE.md`;
- `tests/db/README.md`.

No live migration has been executed and no environment-specific SQL has been invented before inspecting the target project.

## Non-negotiable principles

- One Account may learn, teach, manage a Learner and represent an Organization.
- Learner identity/history is separate from the Account acting for it.
- No public Learner directory.
- Parent/Guardian acts **for** Learner, never by impersonation.
- Formal learner-side marketplace decisions follow `can_make_learning_decision`; management authority does not grant Test-taking authority.
- UI never directly mutates core operational state; consequential writes use canonical commands.
- Current authoritative state beats stale UI.
- Consequential commands are idempotent.
- Pending Class Invitations reserve finite capacity **at send time** and expire.
- Class capacity and Ads inventory may never oversell.
- Existing offline learners use a private, expiring one-time Learner share code rather than public search/fake Enquiry.
- Test definition locks when valid Attempts begin; answer-key correction is explicit/audited.
- Safety/platform restrictions are scoped rather than one giant status.
- Realtime invalidates/refetches; it is not source of truth.
- Organic discovery and Sponsored serving stay separate.
- Live Ads serve an exact approved Campaign Revision.
- Sponsored content is surface-governed and excluded from protected learning/private messaging surfaces.
- Paid visibility can never buy verification, endorsement or organic rank.
- Per-user Ads frequency/hide data is private operational data, never advertiser viewer lists.
- Navigation/workspace selection is never authorization; privileged reads re-check actual capability/relationship/scope.

## Mock/model testing result

Backend-free property-style simulations were executed to attack the highest-risk invariants before any database exists.

Passed:

- ~2.5 million randomized Class capacity/Invitation transitions;
- ~2.5 million randomized Ads inventory transitions;
- 100,000 Learner share-code lifecycle operations;
- 100,000 Test Attempt identity/retry operations;
- 100,000 protected Ads-surface decisions;
- 200,000 cross-domain invariant scenario bundles;
- extreme logical contention: 100,000 requests against a 50-seat Class produced exactly 50 reservations, and 100,000 requests against capacity-100 Ads inventory produced exactly 100 units.

No modeled invariant failure was found.

This is a **logical-model pass**, not a runtime performance certification. Real PostgreSQL/Supabase tests for RLS, grants, locks, deadlocks, indexes, Realtime, Storage, failure recovery and p95/p99 latency remain mandatory after a safe staging schema exists.

## Current boundary

**Supabase has not been touched.**

All meaningful product/UI/domain/schema-planning/migration-planning/test-planning/handover work that should happen before touching the target environment is complete.

When the user authorizes Supabase access, the first action is **read-only environment inspection**, then only **Foundation + Identity** is implemented and tested. Do not proceed to Locations until that slice passes.
