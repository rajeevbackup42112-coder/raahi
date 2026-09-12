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
- first physical database blueprint draft;
- formal review of that physical draft;
- corrected **Physical Database Blueprint v1.1**;
- command/permission and acceptance-test updates reflecting the review;
- SQL-readiness checklist;
- first SQL Migration Plan draft;
- formal review of migration sequencing/dependencies;
- corrected **SQL Migration Plan v1.1**.

Not started:

- Supabase project/schema changes for Raahi Learning;
- SQL migration execution;
- RLS implementation in Supabase;
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
- actor + acting-for + object + relationship/capability/scope authorization;
- explicit scoped restrictions instead of giant Teacher/Account status;
- idempotent consequential commands;
- stale UI never overrides server truth;
- atomic protection of Class capacity and Ads inventory;
- Pending V1 Class Invitations reserve finite seats until expiry/resolution;
- Test definition locks once valid Attempts begin;
- realtime invalidates/refetches only;
- notifications happen after core state commits;
- organic discovery and Sponsored serving remain separate;
- live Ads serving is pinned to an exact approved Campaign Revision;
- significant admin/safety/commercial actions are auditable.

## Physical database review result

The historical `03-database-blueprint-v1.md` did not pass the gate as written. `08-database-blueprint-review-v1.md` documents the corrections.

The current physical blueprint is:

> **`03-database-blueprint-v1.1.md`**

Key corrections include private Class communication, scoped restrictions/capabilities, exact Ads target/revision handling, overlap-safe daily Ads inventory, private Ads frequency state, Test definition lock, finite seat-reserving Class Invitations, Learner avatar/Saved teacher support, and Placement-level Ads metrics.

## SQL Migration Plan review result

The first `10-sql-migration-plan-v1.md` was also reviewed before Supabase. `11-sql-migration-plan-review-v1.md` found sequencing dependencies and corrected them.

The current SQL implementation plan is:

> **`10-sql-migration-plan-v1.1.md`**

Important corrected sequencing decisions:

1. selected Location is implemented after Locations as `account_location_preferences`, avoiding Identity→Location FK dependency;
2. general scoped Restrictions are created after Organizations exist;
3. Enquiries are created without Ads FK, then Sponsored Campaign attribution is added during Ads migration;
4. Audit + Idempotency are created before early consequential RPCs;
5. post-lock Test structure is immutable while answer-key correction has one explicit audited privileged path.

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
- overlap-safe daily physical capacity;
- inventory holds expire and cannot oversell;
- simple fixed/configured packages before auctions/CPC/CPM;
- Campaign Revision approval is exact and immutable;
- Ad Placement serves an explicit approved Revision, never implicit latest creative;
- Commercial Clearance is separate from approval;
- multi-Location serving is independent per Location;
- anti-monopoly/no category exclusivity;
- aggregate analytics only unless user deliberately Enquires;
- private user-level frequency controls stay private from advertisers.

## Immediate next task

**Run one final cross-document approval pass of `10-sql-migration-plan-v1.1.md`. Do not connect to Supabase yet.**

Check specifically:

1. every frozen Product/UI rule is preserved;
2. no removed concept has returned;
3. FK/delete semantics preserve shared/history/safety records;
4. Class invitation reservation/acceptance/transfer is race-safe;
5. Test lock/correction is safe against ordinary and accidental privileged mutation;
6. Ads daily multi-row locking cannot oversell and uses deterministic lock order;
7. RLS/SECURITY DEFINER boundaries cannot escalate Learner/Organization/Location scope;
8. copied private storage URLs remain unauthorized without current business access;
9. idempotency result commits atomically with domain outcome;
10. migration slices are independently testable.

If the plan passes, change its status to:

> **APPROVED FOR IMPLEMENTATION**

Only after that should Supabase be connected.

## First implementation slice after approval

Implement only:

> **Foundation + Identity**

That means extensions/common helpers → Account/Learner/Account↔Learner/Account Capability tables → Audit/Idempotency infrastructure → RLS helpers → Identity RPCs/tests.

Do not create Locations or later modules until Foundation + Identity migrations and authorization tests pass.

## Supabase rule

Do **not** start creating Supabase tables yet.

Once `10-sql-migration-plan-v1.1.md` is explicitly approved, use versioned SQL migrations rather than ad-hoc dashboard edits and canonical RPC/functions for consequential writes.

## UI source-of-truth note

Many exploratory images were generated during product design. They may contain image-generation drift such as stars/ratings, Enrollment wording, overbuilt Ads billing, or old Adult/Minor assumptions.

**Written rules in this documentation folder override generated images.** Visuals are style/layout inspiration only unless explicitly reconciled with frozen written behaviour.

## Recommended prompt for a new chat

> “Continue Raahi Learning V1. Read `99-handover.md`, `README.md`, `08-database-blueprint-review-v1.md`, `03-database-blueprint-v1.1.md`, `11-sql-migration-plan-review-v1.md`, and `10-sql-migration-plan-v1.1.md` from repo `rajeevbackup42112-coder/raahi`, branch `raahi-learning-v1-docs`, then cross-check `00`, `01`, `02`, `04`, `05`, and `06`. Product/UI is frozen and Supabase has not been touched. Perform the final approval review of the corrected SQL Migration Plan. Do not connect to Supabase until the plan is explicitly marked APPROVED FOR IMPLEMENTATION.”
