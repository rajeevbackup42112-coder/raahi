# Raahi Learning V1.2 — Documentation Index

Status: **PRE-SUPABASE WORK COMPLETE. Product/UI frozen, clickable UI inspected, UI↔DB reconciliation passed, consolidated physical/migration contract ready, and pre-Supabase logical QA passed. Supabase remains untouched.**

This folder is the canonical handover point for Raahi Learning. It exists so another ChatGPT conversation, developer or coding agent can continue without reconstructing chat history.

> **Source-of-truth rule:** frozen written behavior + the inspected clickable UI define the product. Exploratory/generated images are visual inspiration only where they agree with those sources.

## Product

Raahi Learning is a **local learning community launched one Location at a time**.

Core journey:

**Find → Enquire → optional Trial → Class Invitation → Join Class → Learn**

## Inspected clickable UI

Artifact: `Raahi_Learning_Clickable_UI_v1.1.zip`  
Library path: `/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`  
SHA-256: `2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

Final UI audit:

- 77 canonical routes/pages;
- 154 desktop/mobile route checks — 0 issues;
- 32 privileged deep-link checks — 0 unguarded pages;
- 26 interaction/business-rule checks — 0 failures;
- 15 semantic/accessibility sanity samples — 0 issues.

## Canonical implementation and QA documents

Read these first for new implementation work:

1. [`99-handover.md`](99-handover.md) — current state and next action.
2. [`00-product-ui-freeze-v1.md`](00-product-ui-freeze-v1.md) — frozen product behavior.
3. [`01-domain-model-v1.md`](01-domain-model-v1.md) — conceptual entities, relationships and invariants.
4. [`02-architecture-blueprint-v1.md`](02-architecture-blueprint-v1.md) — architecture boundaries and command model.
5. [`04-command-permission-matrix-v1.md`](04-command-permission-matrix-v1.md) — canonical command/permission intent.
6. [`05-acceptance-regression-v1.md`](05-acceptance-regression-v1.md) — detailed Given/When/Then business regression set.
7. [`06-raahi-ads-v1.md`](06-raahi-ads-v1.md) — Ads product/privacy/inventory rules.
8. [`18-ui-page-inventory-v1.1.md`](18-ui-page-inventory-v1.1.md) — frozen inspected UI page/state inventory.
9. [`19-consolidated-database-blueprint-v1.2.md`](19-consolidated-database-blueprint-v1.2.md) — **single final physical-design source**.
10. [`20-consolidated-sql-migration-plan-v1.2.md`](20-consolidated-sql-migration-plan-v1.2.md) — **single final migration sequence**.
11. [`21-pre-supabase-readiness-review-v1.2.md`](21-pre-supabase-readiness-review-v1.2.md) — technical readiness PASS.
12. [`22-implementation-runbook-v1.2.md`](22-implementation-runbook-v1.2.md) — controlled slice-by-slice procedure.
13. [`23-final-acceptance-traceability-v1.2.md`](23-final-acceptance-traceability-v1.2.md) — UI → data → command → invariant mapping.
14. [`24-supabase-execution-checklist-v1.2.md`](24-supabase-execution-checklist-v1.2.md) — checklist for the future environment boundary.
15. [`25-pre-supabase-package-manifest-v1.2.md`](25-pre-supabase-package-manifest-v1.2.md) — package completeness manifest.
16. [`26-final-pre-supabase-consistency-audit-v1.2.md`](26-final-pre-supabase-consistency-audit-v1.2.md) — cross-document consistency PASS.
17. [`27-pre-supabase-test-strategy-v1.2.md`](27-pre-supabase-test-strategy-v1.2.md) — comprehensive test taxonomy.
18. [`28-mock-model-test-results-v1.2.md`](28-mock-model-test-results-v1.2.md) — first logical model/property PASS.
19. [`29-master-test-case-catalog-v1.2.md`](29-master-test-case-catalog-v1.2.md) — **master QA catalog covering scenario/state/permission/stale/retry/race/security/load/chaos/migration/UI tests**.
20. [`30-expanded-mock-model-test-results-v1.3.md`](30-expanded-mock-model-test-results-v1.3.md) — **expanded executed model suite: 5,349,992 cases/operations, 0 invariant failures**.
21. [`31-staging-load-security-chaos-plan-v1.2.md`](31-staging-load-security-chaos-plan-v1.2.md) — real PostgreSQL/Supabase load, security, chaos and recovery plan.
22. [`32-canonical-test-personas-fixtures-v1.2.md`](32-canonical-test-personas-fixtures-v1.2.md) — deterministic QA personas/data states.
23. [`33-pre-supabase-qa-readiness-verdict-v1.2.md`](33-pre-supabase-qa-readiness-verdict-v1.2.md) — **PASS for everything that can honestly be proven before a real DB exists**.
24. [`12-implementation-approval-v1.md`](12-implementation-approval-v1.md) — implementation approval record.

## Historical review chain

`03/08/09/10/11/13/14/15/16/17` remain valuable decision history. They no longer need to be manually merged for new implementation work. Where historical wording differs from the consolidated V1.2 blueprint/plan, **V1.2 wins**.

## Dedicated implementation branch

Branch: `raahi-learning-implementation-v1`

It contains only pre-environment scaffolding and test infrastructure so far:

- `IMPLEMENTATION_START_HERE.md`;
- `supabase/migrations/README.md`;
- `supabase/ENVIRONMENT_INSPECTION_TEMPLATE.md`;
- `tests/db/README.md`;
- `tests/model/pre_supabase_model_tests.py`;
- `tests/model/README.md`;
- `.github/workflows/raahi-learning-model-tests.yml`.

No environment-specific SQL has been invented before inspecting the target project, and no Supabase migration has been executed.

## QA result before Supabase

The inspected UI already passed its UI/regression gates.

The expanded backend-free model/property suite then exercised **5,349,992** cases/operations with **0 invariant failures**, including:

- Learning Request state rules;
- Enquiry messaging authority;
- Class capacity/reservation invariants;
- Class transfer atomicity model;
- Test self-vs-manager authority and retry behavior;
- Learner share-code lifecycle;
- Account closure blockers;
- Location preference independence;
- Ads capacity and exact-Revision serving;
- protected Sponsored surfaces;
- Report/Block separation;
- Class completion behavior;
- public Learning Request privacy projection.

Earlier concentrated logical contention also produced exactly 50 reservations from 100,000 attempts against a 50-seat Class and exactly 100 units from 100,000 attempts against Ads capacity 100.

This is **not** a real runtime performance/security certification. `29` and `31` explicitly preserve the real RLS/GRANT/locking/deadlock/Storage/Realtime/query-plan/latency/security tests that must run after staging exists.

## Non-negotiable principles

- One Account may learn, teach, manage a Learner and represent an Organization.
- Learner identity/history is separate from the Account acting for it.
- No public Learner directory.
- Parent/Guardian acts **for** Learner, never by impersonation.
- Formal learner-side marketplace decisions follow `can_make_learning_decision`; management authority does not grant Test-taking authority.
- UI never directly mutates core operational state; consequential writes use canonical commands.
- Current authoritative state beats stale UI.
- Consequential commands are idempotent.
- Pending Class Invitations reserve capacity **at send time** and expire.
- Class capacity and Ads inventory may never oversell.
- Existing offline learners use a private, expiring, one-time Learner share code.
- Test definition locks when valid Attempts begin; answer-key correction is explicit/audited.
- Safety/platform restrictions are scoped rather than one giant status.
- Realtime invalidates/refetches; it is not source of truth.
- Organic discovery and Sponsored serving stay separate.
- Live Ads serve an exact approved Campaign Revision.
- Sponsored content is excluded from protected learning/private messaging surfaces.
- Paid visibility can never buy verification, endorsement or organic rank.
- Advertisers never receive named viewer/frequency/hide histories.
- Navigation/workspace selection is never authorization.

## Current boundary

> **Supabase has not been touched.**

Everything meaningful that can be designed, inspected, modeled and test-planned before the environment boundary is now complete.

When the user authorizes Supabase access, first inspect the exact target project **read-only**, then implement only **Foundation + Identity** through versioned migrations and move its relevant `PLANNED-DB/SEC/LOAD` test cases to PASS before proceeding to Locations.