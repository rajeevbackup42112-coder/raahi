# Raahi Learning V1 — Documentation Index

Status: **Product + UI behaviour frozen; conceptual/architecture model frozen; physical database blueprint reviewed; SQL Migration Plan v1.1 technically approved. Supabase remains untouched.**

This folder is the canonical handover point for Raahi Learning V1. It exists so a new ChatGPT conversation, developer, or coding agent can continue without relying on chat history.

> **Source-of-truth rule:** written business rules in this folder override exploratory UI images or older chat drafts whenever they conflict.

## Product in one sentence

Raahi Learning is a **local learning community launched one location at a time**, where people can discover legitimate learning, parents can manage learning for children, teachers/coaches/instructors and institutes can offer learning, relationships form through controlled enquiries, and ongoing learning continues in private Classes.

## Core journey

**Find → Enquire → optional Trial → Class Invitation → Join Class → Learn**

For a parent:

**Find for Rahul → Enquire for Rahul → Join Rahul → support Rahul's learning**

## Canonical documents

1. [`00-product-ui-freeze-v1.md`](00-product-ui-freeze-v1.md) — frozen scope, terminology, navigation and behaviour.
2. [`01-domain-model-v1.md`](01-domain-model-v1.md) — canonical conceptual entities, relationships, states and invariants.
3. [`02-architecture-blueprint-v1.md`](02-architecture-blueprint-v1.md) — module boundaries, command ownership, transactions, realtime, scoped restrictions and audit model.
4. [`08-database-blueprint-review-v1.md`](08-database-blueprint-review-v1.md) — review of the first physical draft.
5. [`03-database-blueprint-v1.1.md`](03-database-blueprint-v1.1.md) — current reviewed physical relational design.
6. [`09-sql-readiness-review-v1.md`](09-sql-readiness-review-v1.md) — SQL-readiness checklist.
7. [`11-sql-migration-plan-review-v1.md`](11-sql-migration-plan-review-v1.md) — review of the first migration-plan draft and dependency corrections.
8. [`10-sql-migration-plan-v1.1.md`](10-sql-migration-plan-v1.1.md) — current corrected SQL implementation contract.
9. [`12-implementation-approval-v1.md`](12-implementation-approval-v1.md) — **final technical approval record and first permitted implementation slice.**
10. [`04-command-permission-matrix-v1.md`](04-command-permission-matrix-v1.md) — canonical commands, authorization and transaction/idempotency requirements.
11. [`05-acceptance-regression-v1.md`](05-acceptance-regression-v1.md) — Given/When/Then and cross-product regression gates.
12. [`06-raahi-ads-v1.md`](06-raahi-ads-v1.md) — Ads product, inventory, review, privacy and commercial rules.
13. [`07-decision-log-v1.md`](07-decision-log-v1.md) — major decisions and explicitly removed/deferred complexity.
14. [`03-database-blueprint-v1.md`](03-database-blueprint-v1.md) — historical first physical draft. Do not deploy from this file.
15. [`10-sql-migration-plan-v1.md`](10-sql-migration-plan-v1.md) — historical first migration-plan draft. Do not implement from this file.
16. [`99-handover.md`](99-handover.md) — exact current state and next actions for another chat/agent.

## Non-negotiable design principles

- One Raahi account may learn, teach, manage a learner, or represent an organization.
- Learner identity is separate from the account acting on the learner's behalf.
- No public learner directory.
- Parent/guardian acts **for** the learner; they do not impersonate the learner.
- UI may read authorized data, but never directly mutates core operational state.
- One canonical business command per meaningful transition.
- Current server state beats stale UI state.
- Consequential commands are idempotent.
- Pending V1 Class Invitations reserve finite Class capacity and must expire.
- Class capacity and Ads inventory may never be oversold.
- Test definition locks when valid Attempts begin; answer-key correction is explicit and audited.
- Safety/platform restrictions are scoped; do not collapse unrelated capabilities into one giant status.
- Realtime invalidates/refetches; it is not the source of truth.
- Organic discovery and Sponsored Ads are separate systems.
- Ad serving is pinned to an exact approved Campaign Revision.
- Paid visibility can never buy verification, endorsement, or organic ranking.
- Per-user Ads frequency/hide/view controls are private operational data, never advertiser viewer lists.

## Current implementation gate

The technical plan has passed its final documentation review and is recorded in `12-implementation-approval-v1.md`.

**Supabase has still not been touched.**

The next operational action requires the user to authorize Supabase execution. Once authorized, implement only **Foundation + Identity** first, through versioned migrations with tests. Do not proceed to Locations until that slice passes.
