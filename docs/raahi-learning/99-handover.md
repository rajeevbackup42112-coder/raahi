# Raahi Learning V1.1 — Handover / Current State

**Read this file first in a new conversation.**

Repository: `rajeevbackup42112-coder/raahi`  
Documentation branch: `raahi-learning-v1-docs`  
Canonical folder: `docs/raahi-learning/`

> This branch is intentionally isolated from the existing Raahi ride implementation on `main`. Do not infer Raahi Learning behavior from old ride code.

## Current project phase

### Completed

- Problem / Actors / Ownership / Business Rules;
- extensive edge-case, malicious-action and concurrency thinking;
- terminology cleanup;
- learner/guardian simplification;
- Raahi Ads product/inventory/privacy design;
- generated visual exploration;
- Product + UI behavior freeze;
- Domain Model and Architecture boundaries;
- physical DB blueprint and formal review;
- SQL migration plan and sequencing review;
- first written UI↔DB reconciliation + technical delta;
- **real backend-free clickable UI prototype**;
- complete page/state inventory;
- desktop/mobile route audit;
- privileged deep-link/workspace audit;
- core journey/business-rule interaction audit;
- semantic/accessibility sanity audit;
- visual inspection of representative learner/teacher/manager/platform/mobile states;
- **final inspected UI behavior freeze V1.1**;
- **final page-level UI↔DB reconciliation**;
- **final UI-proven DB/RPC/RLS delta**;
- **APPROVED FOR CONTROLLED IMPLEMENTATION** decision.

### Not started

- any Raahi Learning Supabase migration;
- production tables/RLS/RPCs;
- backend integration of the clickable prototype;
- production deployment.

**Supabase is still untouched.**

## Canonical clickable UI artifact

Artifact: `Raahi_Learning_Clickable_UI_v1.1.zip`

Persistent Library path:

`/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`

SHA-256:

`2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

The zip contains the exact inspected backend-free UI build, deterministic fixture data, audit scripts/results and screenshots.

Inspection result:

- **77 canonical routes/pages**;
- **154** desktop/mobile route checks, **0 issues**;
- **32** privileged deep-link checks, **0 unguarded**;
- **26** interaction/business-rule checks, **0 failures**;
- **15** semantic/accessibility sanity samples, **0 issues**.

## Product essence

Raahi Learning is a **local learning community launched one Location at a time**.

Core journey:

**Find → Enquire → optional Trial → Class Invitation → Join Class → Learn**

One Account may learn, teach, manage a Learner and represent an Organization.

Learner identity/history is separate from the Account acting on the Learner’s behalf.

No separate Enrollment object exists.

## Highest-value simplifications — do not casually restore

- Enrollment;
- Batch entity;
- Adult/Minor Learner split;
- turning-18 lifecycle;
- complex guardian hierarchy;
- Trial as mandatory/major relationship lifecycle;
- separate Assignment and Practice engines;
- Attendance;
- fake overall Progress %;
- public ratings/reviews;
- public Learner directory;
- global Community;
- multi-teacher Class in V1;
- unrestricted direct messaging;
- advertiser viewer CRM;
- platform tuition-payment collection.

## Final inspected-UI findings now binding

Real pages proved several requirements that earlier image prototypes had not made precise enough:

1. Location lifecycle begins with `interest_only` before `preparing`;
2. existing offline learner invitation needs a **private, expiring, one-time Learner share code**, not a public learner search or fake Enquiry;
3. `class_invitations` needs an optional `fee_display_text` snapshot for the exact terms displayed at Join;
4. `test_attempts` needs optional private `teacher_feedback` for released Test Results;
5. Settings needs canonical guarded Account pause/resume/closure commands and responsibility blockers;
6. privileged reads/deep links must always re-check real capability/relationship/Organization/Location scope; UI workspace selection is never authority.

Earlier binding UI↔DB corrections still apply:

- selected Location lives in `account_location_preferences`;
- persisted `location_interests`;
- `can_make_learning_decision` for formal learner-side marketplace/relationship decisions;
- Organization public logo/avatar;
- deterministic historical Class access by Membership end state;
- no independent Class learner-thread lifecycle;
- Session Past derived from time; no Attendance subsystem;
- reusable `activity_material_links`;
- optional moderation-private `reports.context_learner_id`;
- atomic `complete_class` command;
- surface-based Sponsored serving;
- direct/offline-origin learners do not need fabricated Enquiry/Trial/Enrollment history.

## Canonical implementation contract

Read these together:

- `00-product-ui-freeze-v1.md`;
- `01-domain-model-v1.md`;
- `02-architecture-blueprint-v1.md`;
- `03-database-blueprint-v1.1.md`;
- `04-command-permission-matrix-v1.md`;
- `05-acceptance-regression-v1.md`;
- `06-raahi-ads-v1.md`;
- `08-database-blueprint-review-v1.md`;
- `09-sql-readiness-review-v1.md`;
- `10-sql-migration-plan-v1.1.md`;
- `11-sql-migration-plan-review-v1.md`;
- `13-ui-db-reconciliation-v1.md`;
- `14-ui-db-implementation-delta-v1.md`;
- `15-ui-page-build-review-gate-v1.md`;
- `16-ui-page-freeze-and-final-reconciliation-v1.1.md`;
- `17-final-ui-db-implementation-delta-v1.1.md`;
- `12-implementation-approval-v1.md`.

### Precedence for implementation

Use:

`10-sql-migration-plan-v1.1.md` + `14-ui-db-implementation-delta-v1.md` + `17-final-ui-db-implementation-delta-v1.1.md`

where the later intentional delta wins on conflict: **17 → 14 → 10**.

The inspected UI behavior in `16` must also be preserved.

## Core architecture rules

- modular monolith;
- PostgreSQL/Supabase-compatible relational source of truth;
- secure read projections are allowed;
- consequential writes use canonical business commands/RPCs;
- UI never directly mutates core operational state;
- actor + acting-for + object + relationship/capability/scope authorization;
- navigation/workspace labels are never authorization;
- scoped restrictions instead of one giant account/provider status;
- current server state beats stale UI;
- consequential commands are idempotent;
- Class capacity and Ads inventory are transactionally protected;
- valid Pending Class Invitations reserve seats until expiry/resolution;
- Test definition locks after valid Attempts begin;
- realtime invalidates/refetches only;
- notifications occur after core state commits;
- private file paths/URLs do not bypass current authorization;
- organic discovery and Sponsored serving remain separate;
- Sponsored serves an exact approved Campaign Revision;
- significant admin/safety/commercial actions are auditable.

## Raahi Ads summary

- educational/relevant Sponsored content only in V1;
- clear Sponsored labeling;
- no paid verification/endorsement/organic ranking;
- excluded from My Classes, Class, Activity, Test and private Message surfaces;
- no named viewer list or behavioral microtargeting;
- daily overlap-safe Location × placement inventory;
- no inventory oversell;
- finite holds with expiry;
- fixed/configured packages before auction/CPC complexity;
- exact immutable submitted Campaign Revisions;
- exact approved `serving_revision_id`;
- Review, Commercial Clearance and inventory are independent gates;
- multi-Location serving is independent by Location;
- aggregate advertiser analytics only;
- per-user hide/frequency state private from advertiser.

## Next operational action

The pre-Supabase design/UI/document gate is complete.

**Do not build the entire database.**

When the user explicitly authorizes Supabase execution:

1. inspect the target Supabase project/environment first;
2. implement only **Foundation + Identity** through versioned SQL migrations;
3. run its RLS/RPC/idempotency/authorization/privilege tests;
4. stop on any contradiction or failed invariant;
5. do not create Locations until Foundation + Identity passes.

### Foundation + Identity scope

- extensions/common helpers;
- Accounts;
- Learners;
- Account↔Learner Access;
- Account Capabilities;
- Audit Log;
- Idempotency Keys;
- Identity authorization helpers including `can_make_learning_decision`;
- Identity canonical RPCs;
- Account pause/resume/guarded closure behavior (in first slice or immediate Identity follow-up before Locations);
- RLS/privilege hardening;
- tests for learner ownership, one active self/manager, decision authority, manager-vs-self separation, account lifecycle blockers, retries/idempotency and privilege escalation.

## Supabase rule

No Raahi Learning migration has been executed.

When execution begins:

- use versioned migrations committed to source control;
- do not make ad-hoc dashboard schema edits;
- test every slice before proceeding;
- use forward-fix migrations after anything reaches a shared environment;
- never delete required shared/safety/audit history just to simplify rollback.

## Recommended prompt for a new chat

> “Continue Raahi Learning V1.1. Read `RAAHI_LEARNING_HANDOVER.md` and `docs/raahi-learning/99-handover.md` from `rajeevbackup42112-coder/raahi`, branch `raahi-learning-v1-docs`. Then read `README.md`, `16-ui-page-freeze-and-final-reconciliation-v1.1.md`, `17-final-ui-db-implementation-delta-v1.1.md`, `12-implementation-approval-v1.md`, `14-ui-db-implementation-delta-v1.md`, `10-sql-migration-plan-v1.1.md`, and the frozen Product/Domain/Architecture/Command/Acceptance/Ads docs. The real clickable UI has been inspected and the final UI↔DB gate passed. Supabase is untouched. If explicitly authorized, inspect Supabase and implement only Foundation + Identity first, then test it before proceeding.”
