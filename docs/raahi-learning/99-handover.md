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
- first physical database blueprint draft and formal review;
- corrected **Physical Database Blueprint v1.1**;
- command/permission + acceptance updates;
- SQL-readiness review;
- first SQL Migration Plan and dependency review;
- corrected **SQL Migration Plan v1.1**;
- mandatory **UI Prototype ↔ DB Design Reconciliation**;
- binding reconciliation migration/RPC/RLS delta;
- post-reconciliation **APPROVED FOR CONTROLLED IMPLEMENTATION** decision.

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

## Current canonical technical contract

Read these together:

- `03-database-blueprint-v1.1.md`
- `10-sql-migration-plan-v1.1.md`
- `13-ui-db-reconciliation-v1.md`
- `14-ui-db-implementation-delta-v1.md`
- `12-implementation-approval-v1.md`

If the reconciliation delta conflicts with earlier physical/migration wording, `14-ui-db-implementation-delta-v1.md` wins until a consolidated later revision is produced.

## UI↔DB reconciliation result

The screen/flow audit passed, but it found real corrections that are now binding:

1. selected Location is stored in `account_location_preferences`, not an early Account FK;
2. unavailable/preparing Locations persist authenticated `location_interests` for **Register Interest**;
3. when a Learner has an active Manager, that manager owns formal marketplace/relationship decisions in V1; otherwise self-access may decide for self;
4. Manager authority does not permit Test impersonation;
5. Organization profile supports a public logo/avatar;
6. Class historical access is deterministic by Membership end state rather than another configurable subsystem;
7. Class Learner Threads do not have an independent lifecycle;
8. Session Past is derived from time; Attendance/completed Session machinery remains absent;
9. Activities can link reusable Materials via `activity_material_links`;
10. Reports may carry private `context_learner_id`;
11. Class completion uses one canonical `complete_class` transaction;
12. educational Sponsored serving is surface-based, not Adult/Minor/turning-18 based;
13. existing offline learners do not require fake Enquiry/Trial/Enrollment history.

Read `13-ui-db-reconciliation-v1.md` for the full flow-by-flow mapping.

## Raahi Ads summary

Ads is a first-class commercial module but not a generic ad network.

Important rules:

- clearly labeled Sponsored;
- relevant educational promotion only in V1;
- no paid verification/endorsement/organic ranking;
- no commercial Ads inside My Classes, Class, Activity, Test or private Message surfaces;
- no named viewer lists or behavioral microtargeting;
- finite overlap-safe daily Location × placement inventory;
- inventory holds expire and cannot oversell;
- fixed/configured packages before auctions/CPC/CPM;
- Campaign Revision approval is exact and immutable;
- Ad Placement serves an explicit approved Revision;
- Commercial Clearance is separate from approval;
- multi-Location serving is independent per Location;
- anti-monopoly/no category exclusivity;
- aggregate analytics only unless user deliberately Enquires;
- private user-level frequency controls stay private from advertisers.

## Immediate next operational action

The documentation gate is closed and implementation is approved **only in slices**.

If the user authorizes Supabase execution, first inspect the target Supabase project/environment and implement only:

### Foundation + Identity

- PostgreSQL extensions/common helpers;
- Accounts;
- Learners;
- Account↔Learner Access;
- Account Capabilities;
- Audit + Idempotency infrastructure;
- Identity authorization helpers, including `can_make_learning_decision`;
- Identity canonical RPCs;
- RLS and privilege hardening;
- tests for learner ownership, manager-vs-self decision authority, one active self/manager, idempotency and privilege escalation.

Do **not** create Locations until Foundation + Identity passes all tests.

## Supabase rule

No Raahi Learning migration has been executed yet.

When execution begins:

- use versioned SQL migrations committed to source control;
- no ad-hoc dashboard table edits;
- stop on invariant/permission test failure;
- use forward-fix migrations after anything is applied to a shared environment.

## UI source-of-truth note

Exploratory prototype images may contain drift such as stars/ratings, Enrollment wording, Book Class semantics, overbuilt Ads billing or old Adult/Minor assumptions.

**Written rules and the completed UI↔DB reconciliation override image drift.**

## Recommended prompt for a new chat

> “Continue Raahi Learning V1. Read `RAAHI_LEARNING_HANDOVER.md` and `docs/raahi-learning/99-handover.md` from repo `rajeevbackup42112-coder/raahi`, branch `raahi-learning-v1-docs`. Then read `README.md`, `13-ui-db-reconciliation-v1.md`, `14-ui-db-implementation-delta-v1.md`, `12-implementation-approval-v1.md`, `10-sql-migration-plan-v1.1.md`, and the frozen Product/Domain/Architecture/Command/Acceptance/Ads docs. The UI↔DB reconciliation is complete and the plan is approved for controlled implementation. Supabase has not been touched. Do not build everything at once; if explicitly authorized, inspect Supabase and implement only Foundation + Identity first, then run its tests before proceeding.”
