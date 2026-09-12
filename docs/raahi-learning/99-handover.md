# Raahi Learning V1 — Handover / Current State

**Read this file first in a new conversation.**

Repository: `rajeevbackup42112-coder/raahi`  
Documentation branch: `raahi-learning-v1-docs`  
Canonical folder: `docs/raahi-learning/`

> This branch is intentionally isolated from the existing `main` codebase. Do not assume the existing Raahi ride implementation is Raahi Learning architecture.

## Current project phase

Completed:

- problem/actor/ownership/business-rule passes;
- extensive edge-case and malicious-action audits;
- terminology cleanup;
- learner simplification pass;
- Ads product + scale/inventory pass;
- user-flow visual exploration;
- **Product + UI Behaviour Freeze V1**;
- conceptual Domain Model V1;
- architecture boundaries and canonical command principles;
- first **physical database blueprint draft**.

Not started:

- Supabase project/schema changes for Raahi Learning;
- SQL migrations;
- RLS implementation;
- application implementation from this new model;
- production deployment.

## Product essence

Raahi Learning is a **local learning community launched one Location at a time**.

Core learner journey:

**Find → Enquire → optional Trial → Class Invitation → Join Class → Learn**

No separate Enrollment object.

One Account may learn, teach, manage a Learner, and represent an Organization.

Learner identity is separate from Account, allowing a parent to act for a child while learning history remains owned by the child.

## Highest-value simplifications already agreed

Do NOT casually reintroduce:

- Enrollment;
- Batch entity;
- Adult/Minor learner entity split;
- turning-18 lifecycle;
- complex guardian hierarchy;
- Trial as mandatory/major lifecycle;
- separate Assignment and Practice systems;
- attendance;
- fake overall progress %;
- public ratings/reviews;
- public learner directory;
- global Community;
- multi-teacher Class;
- platform tuition payments in V1.

The reason these were removed is documented in `07-decision-log-v1.md`.

## Core architecture decisions

- modular monolith;
- PostgreSQL-style relational source of truth;
- reads may use secure projections;
- writes go through canonical business commands;
- UI never directly mutates core operational tables;
- actor + acting-for + object + relationship/scope authorization;
- idempotent consequential commands;
- stale UI never overrides server truth;
- atomic protection of Class capacity and Ads inventory;
- realtime invalidates/refetches only;
- notifications happen after core state commits;
- organic discovery and Sponsored serving remain separate;
- significant admin/safety/commercial actions are auditable.

## Raahi Ads summary

Ads is expected to be commercially important for schools, universities, colleges, coaching institutes, academies and relevant educators.

It is a first-class commercial module but not a generic ad network.

Important rules:

- clearly labeled Sponsored;
- relevant educational promotion only in V1;
- no paid verification/endorsement/organic ranking;
- no commercial Ads inside private Classes, Activities, Tests or private Messages;
- no named viewer lists or behavioral microtargeting;
- finite Location × placement × time inventory;
- inventory holds expire and cannot oversell;
- simple fixed/configured packages before auctions/CPC/CPM;
- Campaign Revision approval is exact and immutable;
- Commercial Clearance is separate from approval;
- multi-Location serving is independent per Location;
- anti-monopoly/no category exclusivity;
- aggregate analytics only unless user deliberately Enquires.

Read `06-raahi-ads-v1.md` for full detail.

## Immediate next task

**Review/challenge `03-database-blueprint-v1.md` before connecting to Supabase.**

Run this exact mental/process check:

> “Can this physical design violate any frozen business rule? Does any table introduce a product concept we intentionally removed? Can every important invariant be enforced transactionally and through authorization?”

Review focus:

1. Account ↔ Learner access model.
2. Organization/teacher ownership of Teaching Options.
3. sanitized Learning Request/public projection.
4. Enquiry provider targeting and duplicate-active rules.
5. Class Invitation seat reservation + atomic acceptance.
6. Membership transfer/end reasons.
7. parent-assisted Submission ownership.
8. Test Attempt uniqueness/idempotency.
9. Location-scoped Local Manager permissions.
10. Ads immutable revisions, review scope and Claim Evidence.
11. Ads inventory window/reservation concurrency.
12. RLS and file authorization boundaries.
13. idempotency key design and audit scope.

If the physical blueprint passes, the next phase is:

### Implementation sequence

1. Freeze reviewed SQL/schema design.
2. Create migrations — **not ad-hoc dashboard table edits**.
3. Implement Identity + Learner access first.
4. Add Locations + Organizations/Teaching Options.
5. Add Learning Requests + Enquiries.
6. Add Classes + Invitations + Memberships.
7. Add Activities/Submissions.
8. Add Tests/Attempts.
9. Add Community/Trust/Safety.
10. Add Ads review/commercial model.
11. Add Ads inventory/placement/analytics.
12. Add notifications/audit/projections.

Each slice must include canonical commands, permission/RLS tests and Given/When/Then regression tests before the next slice depends on it.

## Supabase rule

Do **not** start creating Supabase tables just because the blueprint exists. First explicitly approve/revise the blueprint. Then use versioned SQL migrations and canonical RPC/functions for consequential writes.

## UI source-of-truth note

Many exploratory images were generated during product design. They may contain image-generation drift such as stars/ratings, Enrollment wording, overbuilt Ads billing, or old Adult/Minor assumptions.

**Written rules in this documentation folder override generated images.** Visuals are style/layout inspiration only unless explicitly reconciled with the frozen written behaviour.

## Recommended prompt for a new chat

> “Continue Raahi Learning V1. Read the canonical GitHub documentation from `rajeevbackup42112-coder/raahi`, branch `raahi-learning-v1-docs`, folder `docs/raahi-learning/`, starting with `99-handover.md` and `README.md`. Do not code or touch Supabase yet. First review `03-database-blueprint-v1.md` against the frozen Product, Domain Model, Architecture, Command/Permission Matrix and Acceptance tests. Identify contradictions or unnecessary complexity before proposing the final SQL/migration plan.”
