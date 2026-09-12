# Raahi Learning V1 — Documentation Index

Status: **Product + UI behaviour frozen; technical blueprint in progress. No Supabase/database implementation has started.**

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
3. [`02-architecture-blueprint-v1.md`](02-architecture-blueprint-v1.md) — module boundaries, command ownership, transactions, realtime and audit model.
4. [`03-database-blueprint-v1.md`](03-database-blueprint-v1.md) — proposed physical relational schema and integrity constraints. **Draft until reviewed; do not deploy yet.**
5. [`04-command-permission-matrix-v1.md`](04-command-permission-matrix-v1.md) — canonical commands, authorization and transaction/idempotency requirements.
6. [`05-acceptance-regression-v1.md`](05-acceptance-regression-v1.md) — Given/When/Then and cross-product regression gates.
7. [`06-raahi-ads-v1.md`](06-raahi-ads-v1.md) — Ads product, inventory, review, privacy and commercial rules.
8. [`07-decision-log-v1.md`](07-decision-log-v1.md) — major decisions and explicitly removed/deferred complexity.
9. [`99-handover.md`](99-handover.md) — exact current state and next actions for another chat/agent.

## Non-negotiable design principles

- One Raahi account may learn, teach, manage a learner, or represent an organization.
- Learner identity is separate from the account acting on the learner's behalf.
- No public learner directory.
- Parent/guardian acts **for** the learner; they do not impersonate the learner.
- UI may read authorized data, but **never directly mutates core operational state**.
- One canonical business command per meaningful transition.
- Current server state beats stale UI state.
- Consequential commands are idempotent.
- Class capacity and Ads inventory may never be oversold.
- Realtime invalidates/refetches; it is not the source of truth.
- Organic discovery and Sponsored Ads are separate systems.
- Paid visibility can never buy verification, endorsement, or organic ranking.

## Implementation gate

Do **not** create Supabase tables or production code solely from chat history. First review and approve the physical blueprint in `03-database-blueprint-v1.md` and the command/permission matrix.

Once approved, implementation should proceed in controlled slices with migrations and tests, not as one giant schema push.
