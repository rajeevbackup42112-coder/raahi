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
- **SQL Migration Plan V1 draft** covering PostgreSQL constraints, RLS/RPC strategy, transaction locking, storage and migration slicing.

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

The original `03-database-blueprint-v1.md` **did not pass** the implementation gate as written. `08-database-blueprint-review-v1.md` documents the findings.

Important corrections included:

1. private Class posts/announcements/questions and Class+Learner contextual messaging;
2. explicit Account capabilities and scoped access restrictions;
3. Campaign target Locations/placements before serving;
4. overlap-safe daily Ads inventory capacity buckets;
5. exact approved serving Revision on every Ad Placement;
6. private per-user Ads frequency state without named advertiser viewer data;
7. Test definition lock after valid Attempts begin;
8. Pending Class Invitation as the finite seat reservation with required expiry;
9. Learner avatar support, Saved teacher profiles, selected Location preference and FK-safe Community reactions;
10. Placement/day Ads metrics rather than only Campaign+Location metrics.

The corrected physical blueprint is:

> **`03-database-blueprint-v1.1.md`**

The original v1 file is historical and must not be used for migrations.

## SQL implementation decisions now drafted

`10-sql-migration-plan-v1.md` currently proposes:

- UUID PKs + `timestamptz`;
- constrained `text` + CHECK for lifecycle values rather than PostgreSQL enums;
- conservative FK deletion (`RESTRICT/NO ACTION` for business/history; Auth user can `SET NULL` on Account link);
- partial unique indexes for active Learner access, capabilities, Invitations and Memberships;
- Class row locking as the V1 capacity serialization point;
- daily Ads capacity rows locked deterministically across multi-day reservations;
- RPC-only consequential writes with relationship-based RLS reads;
- explicit Test-definition lock and guarded answer-key correction;
- explicit approved `serving_revision_id` for Ads;
- private storage buckets separated by business sensitivity;
- transaction-coupled idempotency keys;
- Account-or-System audit actors;
- small numbered migration slices rather than one giant migration.

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
- physical capacity model must be overlap-safe;
- inventory holds expire and cannot oversell;
- simple fixed/configured packages before auctions/CPC/CPM;
- Campaign Revision approval is exact and immutable;
- Ad Placement serves an explicit approved Revision, never implicit “latest” creative;
- Commercial Clearance is separate from approval;
- multi-Location serving is independent per Location;
- anti-monopoly/no category exclusivity;
- aggregate analytics only unless user deliberately Enquires;
- private user-level frequency controls stay private from advertisers.

## Immediate next task

**Review `10-sql-migration-plan-v1.md` once against the frozen documents. Do not connect to Supabase yet.**

The review should answer:

1. Does the migration plan preserve every frozen product invariant?
2. Did the SQL mechanics introduce any unnecessary product concept?
3. Are FK delete semantics safe for history/safety?
4. Are Class invitation reservation/acceptance/transfer transactions race-safe?
5. Is Test locking strong enough even against accidental privileged writes?
6. Can Ads daily inventory reservation deadlock/oversell under concurrency?
7. Can RLS helpers/SECURITY DEFINER RPCs escalate Learner/Organization/Location scope?
8. Are private storage objects protected even when URLs/paths are copied?
9. Is idempotency committed atomically with domain outcomes?
10. Is the migration slicing small enough to test before the next slice depends on it?

If the plan passes, mark it **APPROVED FOR IMPLEMENTATION** and only then connect to Supabase.

## Recommended implementation sequence after approval

1. Foundation + Identity only.
2. Locations + scoped restrictions.
3. Organizations, teacher profiles, Teaching Options, Saved items.
4. Learning Requests + Enquiries.
5. Classes + Invitations + Memberships + Sessions + Materials/files.
6. Class feed + Class Learner Threads/Messages.
7. Activities/Submissions.
8. Tests/Attempts.
9. Community/Trust/Safety/Verification.
10. Ads Campaign/Target/Review/Commercial model.
11. Ads daily Inventory/Reservation/Placement/Frequency/Analytics.
12. Notifications, idempotency, audit and projections.

Each slice must include canonical commands, permission/RLS tests and Given/When/Then regression tests before the next slice depends on it.

## Supabase rule

Do **not** start creating Supabase tables yet.

When `10-sql-migration-plan-v1.md` is explicitly approved, use versioned SQL migrations rather than ad-hoc dashboard edits and canonical RPC/functions for consequential writes.

## UI source-of-truth note

Many exploratory images were generated during product design. They may contain image-generation drift such as stars/ratings, Enrollment wording, overbuilt Ads billing, or old Adult/Minor assumptions.

**Written rules in this documentation folder override generated images.** Visuals are style/layout inspiration only unless explicitly reconciled with frozen written behaviour.

## Recommended prompt for a new chat

> “Continue Raahi Learning V1. Read `99-handover.md`, `README.md`, `08-database-blueprint-review-v1.md`, `03-database-blueprint-v1.1.md`, `09-sql-readiness-review-v1.md`, and `10-sql-migration-plan-v1.md` from repo `rajeevbackup42112-coder/raahi`, branch `raahi-learning-v1-docs`, then cross-check `00`, `01`, `02`, `04`, `05`, and `06`. Product/UI is frozen and Supabase has not been touched. Review the SQL Migration Plan against the frozen invariants. Do not connect to Supabase unless the plan is explicitly approved for implementation.”
