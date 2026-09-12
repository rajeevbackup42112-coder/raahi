# Raahi Learning V1 — Documentation Index

Status: **Product + UI behaviour frozen; conceptual/architecture model frozen; physical database blueprint reviewed to v1.1; SQL Migration Plan drafted. Supabase remains untouched.**

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
2. [`01-domain-model-v1.md`](01-domain-model-v1.md) — canonical conceptual entities, relationships, states and invariants, updated after schema review.
3. [`02-architecture-blueprint-v1.md`](02-architecture-blueprint-v1.md) — module boundaries, command ownership, transactions, realtime, scoped restrictions and audit model.
4. [`08-database-blueprint-review-v1.md`](08-database-blueprint-review-v1.md) — review of the first physical draft; explains blocking corrections found.
5. [`03-database-blueprint-v1.1.md`](03-database-blueprint-v1.1.md) — **current reviewed physical relational design**.
6. [`09-sql-readiness-review-v1.md`](09-sql-readiness-review-v1.md) — PostgreSQL/Supabase implementation-mechanics review checklist.
7. [`10-sql-migration-plan-v1.md`](10-sql-migration-plan-v1.md) — **current draft SQL implementation contract and migration sequence**. This is the immediate review target before Supabase.
8. [`04-command-permission-matrix-v1.md`](04-command-permission-matrix-v1.md) — canonical commands, authorization and transaction/idempotency requirements.
9. [`05-acceptance-regression-v1.md`](05-acceptance-regression-v1.md) — Given/When/Then and cross-product regression gates.
10. [`06-raahi-ads-v1.md`](06-raahi-ads-v1.md) — Ads product, inventory, review, privacy and commercial rules.
11. [`07-decision-log-v1.md`](07-decision-log-v1.md) — major decisions and explicitly removed/deferred complexity.
12. [`03-database-blueprint-v1.md`](03-database-blueprint-v1.md) — historical first physical draft. **Do not deploy from this file.**
13. [`99-handover.md`](99-handover.md) — exact current state and next actions for another chat/agent.

## Non-negotiable design principles

- One Raahi account may learn, teach, manage a learner, or represent an organization.
- Learner identity is separate from the account acting on the learner's behalf.
- No public learner directory.
- Parent/guardian acts **for** the learner; they do not impersonate the learner.
- UI may read authorized data, but **never directly mutates core operational state**.
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

Do **not** connect to or mutate Supabase yet.

The current review target is `10-sql-migration-plan-v1.md`. Cross-check it once against Product, Domain, Architecture, Commands and Acceptance tests. If it passes without reopening product behaviour, explicitly approve the plan.

Only then begin versioned migrations, starting with **Foundation + Identity only**, with constraints/RLS/RPC tests before moving to the next slice.
