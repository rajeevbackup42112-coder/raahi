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
- **formal review of the first physical draft**;
- **corrected physical database blueprint v1.1**;
- command/permission and acceptance-test updates reflecting the review.

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

1. add private Class posts/announcements/questions and Class+Learner contextual messaging;
2. add explicit Account capabilities and scoped access restrictions;
3. add Campaign target Locations/placements before serving;
4. replace overlapping Ads windows with overlap-safe daily inventory capacity buckets;
5. pin every Ad Placement to an exact approved serving Revision;
6. add private per-user Ads frequency state without exposing named viewers to advertisers;
7. lock Test definition after valid Attempts begin;
8. make Pending Class Invitation itself the finite seat reservation and require expiry;
9. add Learner avatar support, Saved teacher profiles, selected Location preference and FK-safe Community reactions;
10. aggregate Ads metrics by Placement/date rather than only Campaign+Location.

The corrected current physical blueprint is:

> **`03-database-blueprint-v1.1.md`**

The original v1 file is historical and must not be used for migrations.

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

Read `06-raahi-ads-v1.md`, `08-database-blueprint-review-v1.md`, and `03-database-blueprint-v1.1.md` for detail.

## Immediate next task

**Run the SQL-readiness review of `03-database-blueprint-v1.1.md`. Do not connect to Supabase yet.**

The next pass should decide the exact PostgreSQL implementation contract without changing frozen product behaviour:

1. exact status representation — PostgreSQL enums vs CHECK-constrained text/domain types;
2. PK/FK data types and `ON DELETE`/`ON UPDATE` behaviour;
3. partial unique indexes for active/self/manage/Membership/Invitation rules;
4. capacity transaction strategy for Class Invitations;
5. Test-definition lock enforcement strategy;
6. Ads daily inventory reservation locking strategy across multiple rows;
7. exact RLS read policies and which writes are RPC-only;
8. SECURITY DEFINER function boundaries and least privilege;
9. storage bucket/path + signed URL/RLS policy design;
10. idempotency table/function contract;
11. audit record strategy for Account vs System actors;
12. migration slices and rollback/forward-fix strategy;
13. which constraints can be pure SQL and which require canonical command checks.

After that review, produce the **SQL Migration Plan v1**. Only then should the user be asked to approve touching Supabase.

## Recommended implementation sequence after SQL approval

1. Identity: Accounts, Learners, Account↔Learner Access, Account Capabilities.
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

Do **not** start creating Supabase tables yet. The current stage is SQL-readiness review and migration-plan design.

When approved, use versioned SQL migrations rather than ad-hoc dashboard table edits, and canonical RPC/functions for consequential writes.

## UI source-of-truth note

Many exploratory images were generated during product design. They may contain image-generation drift such as stars/ratings, Enrollment wording, overbuilt Ads billing, or old Adult/Minor assumptions.

**Written rules in this documentation folder override generated images.** Visuals are style/layout inspiration only unless explicitly reconciled with the frozen written behaviour.

## Recommended prompt for a new chat

> “Continue Raahi Learning V1. Read `99-handover.md`, `README.md`, `08-database-blueprint-review-v1.md`, and `03-database-blueprint-v1.1.md` from repo `rajeevbackup42112-coder/raahi`, branch `raahi-learning-v1-docs`, then cross-check `01`, `02`, `04`, `05`, and `06`. Product/UI is frozen and Supabase has not been touched. Continue with the SQL-readiness review: exact PostgreSQL constraints/indexes/RLS/RPC transaction boundaries and migration slicing. Do not connect to Supabase until the SQL Migration Plan is reviewed and approved.”
