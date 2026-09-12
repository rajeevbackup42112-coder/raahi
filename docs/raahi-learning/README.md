# Raahi Learning V1.1 — Documentation Index

Status: **Product/UI behavior frozen; real clickable UI inspected; final UI↔DB reconciliation passed; implementation approved for controlled execution. Supabase remains untouched.**

This folder is the canonical handover point for Raahi Learning V1.1. It exists so a new ChatGPT conversation, developer or coding agent can continue without relying on chat history.

> **Source-of-truth rule:** frozen written behavior + the inspected clickable UI define the product. Exploratory/generated images are visual inspiration only where they agree with those sources.

## Product in one sentence

Raahi Learning is a **local learning community launched one Location at a time**, where people can discover legitimate learning, parents can manage learning for children, teachers/coaches/instructors and institutes can offer learning, relationships form through controlled Enquiries, and ongoing learning continues in private Classes.

## Core journey

**Find → Enquire → optional Trial → Class Invitation → Join Class → Learn**

For a parent:

**Find for Rahul → Enquire for Rahul → Join Rahul → support Rahul's learning**

## Canonical clickable UI artifact

Artifact: `Raahi_Learning_Clickable_UI_v1.1.zip`

Persistent Library path: `/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`

SHA-256: `2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

Inspection result:

- 77 canonical routes/pages;
- 154 desktop/mobile route checks, 0 issues;
- 32 privileged deep-link checks, 0 unguarded;
- 26 interaction/business-rule checks, 0 failures;
- 15 semantic/accessibility sanity samples, 0 issues.

## Canonical documents

1. [`00-product-ui-freeze-v1.md`](00-product-ui-freeze-v1.md) — original frozen V1 scope, terminology, navigation and behavior.
2. [`01-domain-model-v1.md`](01-domain-model-v1.md) — conceptual entities, relationships, states and invariants.
3. [`02-architecture-blueprint-v1.md`](02-architecture-blueprint-v1.md) — module boundaries, commands, transactions, realtime, restrictions and audit model.
4. [`08-database-blueprint-review-v1.md`](08-database-blueprint-review-v1.md) — review of the first physical DB draft.
5. [`03-database-blueprint-v1.1.md`](03-database-blueprint-v1.1.md) — reviewed physical relational baseline.
6. [`09-sql-readiness-review-v1.md`](09-sql-readiness-review-v1.md) — SQL-readiness checklist.
7. [`11-sql-migration-plan-review-v1.md`](11-sql-migration-plan-review-v1.md) — review of migration sequencing/dependencies.
8. [`10-sql-migration-plan-v1.1.md`](10-sql-migration-plan-v1.1.md) — corrected SQL implementation baseline.
9. [`13-ui-db-reconciliation-v1.md`](13-ui-db-reconciliation-v1.md) — first two-way screen/flow↔DB audit.
10. [`14-ui-db-implementation-delta-v1.md`](14-ui-db-implementation-delta-v1.md) — binding changes from the first UI↔DB audit.
11. [`15-ui-page-build-review-gate-v1.md`](15-ui-page-build-review-gate-v1.md) — real clickable UI build/review gate, now **PASSED/CLOSED**.
12. [`16-ui-page-freeze-and-final-reconciliation-v1.1.md`](16-ui-page-freeze-and-final-reconciliation-v1.1.md) — **final inspected UI behavior freeze + page-level reconciliation**.
13. [`17-final-ui-db-implementation-delta-v1.1.md`](17-final-ui-db-implementation-delta-v1.1.md) — **final binding DB/RPC/RLS delta proved by the real pages**.
14. [`12-implementation-approval-v1.md`](12-implementation-approval-v1.md) — **final approval for controlled implementation and first permitted slice**.
15. [`04-command-permission-matrix-v1.md`](04-command-permission-matrix-v1.md) — canonical command/authorization/transaction map.
16. [`05-acceptance-regression-v1.md`](05-acceptance-regression-v1.md) — Given/When/Then and regression gates.
17. [`06-raahi-ads-v1.md`](06-raahi-ads-v1.md) — Ads product, inventory, review, privacy and commercial rules.
18. [`07-decision-log-v1.md`](07-decision-log-v1.md) — major decisions and intentionally removed/deferred complexity.
19. [`99-handover.md`](99-handover.md) — exact current state and next action for another chat/agent.

Historical drafts retained for traceability only:

- `03-database-blueprint-v1.md` — do not deploy from this file;
- `10-sql-migration-plan-v1.md` — do not implement from this file.

## Implementation contract / precedence

Implementation reads:

> `10-sql-migration-plan-v1.1.md` + `14-ui-db-implementation-delta-v1.md` + `17-final-ui-db-implementation-delta-v1.1.md`

and must also respect the inspected UI freeze in `16-ui-page-freeze-and-final-reconciliation-v1.1.md`.

Where a deliberate later delta conflicts with earlier schema/migration wording, the later delta wins: **17 → 14 → 10**.

## Non-negotiable design principles

- One Account may learn, teach, manage a Learner and represent an Organization.
- Learner identity/history is separate from the Account acting on its behalf.
- No public Learner directory.
- Parent/Guardian acts **for** Learner, never by impersonation.
- Formal learner-side marketplace decisions follow `can_make_learning_decision`; management authority does not grant Test-taking authority.
- UI never directly mutates core operational state; consequential writes use canonical commands.
- Current authoritative state beats stale UI.
- Consequential commands are idempotent.
- Pending Class Invitations reserve finite capacity and expire.
- Class capacity and Ads inventory may never oversell.
- Existing offline learners use a private, expiring, one-time Learner share code rather than public search/fake Enquiry.
- Test definition locks when valid Attempts begin; answer-key correction is explicit/audited.
- Safety/platform restrictions are scoped rather than one giant status.
- Realtime invalidates/refetches; it is not source of truth.
- Organic discovery and Sponsored serving stay separate.
- Live Ads serve an exact approved Campaign Revision.
- Sponsored content is surface-governed and excluded from protected learning/private messaging surfaces.
- Paid visibility can never buy verification, endorsement or organic rank.
- Per-user Ads frequency/hide data is private operational data, never advertiser viewer lists.
- Navigation/workspace selection is never authorization; privileged reads re-check actual capability/relationship/scope.

## Current implementation gate

The complete pre-Supabase design/UI gate is **passed** and controlled implementation is approved by `12-implementation-approval-v1.md`.

**Supabase has still not been touched.**

Once the user authorizes database execution, inspect the target Supabase environment and implement only **Foundation + Identity** first through versioned migrations and tests. Do not proceed to Locations until that slice passes.
