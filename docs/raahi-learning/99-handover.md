# Raahi Learning V1.2 — Handover / Current State

**Read this file first in a new conversation.**

Repository: `rajeevbackup42112-coder/raahi`  
Documentation branch: `raahi-learning-v1-docs`  
Canonical folder: `docs/raahi-learning/`

> This branch is intentionally isolated from older Raahi ride work on `main`. Do not infer Raahi Learning behavior from old ride code.

## Current status

**PRE-SUPABASE WORK COMPLETE.**

Completed:

- Product/actor/ownership/business-rule passes;
- edge-case, malicious-action and concurrency challenges;
- learner/guardian simplification;
- terminology cleanup;
- Raahi Ads product/inventory/privacy design;
- conceptual Domain Model + Architecture boundaries;
- physical DB review + SQL sequencing review;
- first UI↔DB reconciliation;
- real backend-free clickable UI build;
- full page/state inventory;
- desktop/mobile, deep-link, interaction and semantic audits;
- final inspected UI behavior freeze;
- final page-level UI↔DB reconciliation;
- consolidated V1.2 physical DB blueprint;
- consolidated V1.2 migration plan;
- final UI/data/command/test traceability;
- pre-Supabase readiness review;
- implementation runbook + Supabase execution checklist;
- final controlled-implementation approval.

Not started:

- any Raahi Learning Supabase migration;
- live RLS/RPC execution;
- production database integration;
- production deployment.

**Supabase is still untouched.**

## Inspected UI artifact

Artifact: `Raahi_Learning_Clickable_UI_v1.1.zip`

Persistent Library path:

`/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`

SHA-256:

`2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

Inspection result:

- 77 canonical routes/pages;
- 154 desktop/mobile route checks — 0 issues;
- 32 privileged deep-link checks — 0 unguarded pages;
- 26 interaction/business-rule checks — 0 failures;
- 15 semantic/accessibility sanity samples — 0 issues.

Route inventory: `18-ui-page-inventory-v1.1.md`.

## Product essence

Raahi Learning is a **local learning community launched one Location at a time**.

Core journey:

**Find → Enquire → optional Trial → Class Invitation → Join Class → Learn**

One Account may learn, teach, manage a Learner and represent an Organization.

Learner identity/history is separate from whichever Account is allowed to act for that Learner.

No separate Enrollment object exists.

## Do not casually restore

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
- multi-teacher Class in V1.2;
- unrestricted direct messaging;
- advertiser viewer CRM;
- platform tuition-payment collection.

## Primary implementation sources

Read these first:

1. `README.md`;
2. `00-product-ui-freeze-v1.md`;
3. `01-domain-model-v1.md`;
4. `02-architecture-blueprint-v1.md`;
5. `04-command-permission-matrix-v1.md`;
6. `05-acceptance-regression-v1.md`;
7. `06-raahi-ads-v1.md`;
8. `18-ui-page-inventory-v1.1.md`;
9. **`19-consolidated-database-blueprint-v1.2.md`**;
10. **`20-consolidated-sql-migration-plan-v1.2.md`**;
11. `21-pre-supabase-readiness-review-v1.2.md`;
12. `22-implementation-runbook-v1.2.md`;
13. `23-final-acceptance-traceability-v1.2.md`;
14. `24-supabase-execution-checklist-v1.2.md`;
15. `12-implementation-approval-v1.md`;
16. `25-pre-supabase-package-manifest-v1.2.md`.

Historical `03/08/09/10/11/13/14/15/16/17` documents explain how the design evolved. They do **not** override the consolidated V1.2 blueprint/plan.

## Highest-value final rules

- Parent acts **for** Learner; learner work/history remains Learner-owned.
- If an active manager exists, formal learner marketplace/relationship decisions are manager-owned; otherwise self-access may decide for self.
- Manager authority never grants Test-taking impersonation.
- Selected Location controls discovery/community context only.
- Location lifecycle: `interest_only → preparing → live ↔ paused → retired`.
- No public Learner search/directory; existing offline learners use a private expiring one-time share code.
- Pending Class Invitation reserves finite capacity at **send time**.
- Invitation fee text is a historical informational snapshot, not a payment subsystem.
- Membership is the Class access boundary.
- `complete_class` changes Class + eligible Active Memberships atomically.
- Session past state is time-derived; no Attendance.
- Activity unifies Assignment/Practice/Exercise.
- Test definition locks no later than first valid Attempt; management authority cannot take Test.
- Test result may contain private teacher feedback.
- Account pause/resume/closure is governed; closure cannot strand responsibilities or cascade-delete history.
- UI route/workspace guards are never authority; protected reads re-check actual scope server-side.
- Sponsored and organic systems remain separate.
- Ads use exact approved Campaign Revision and overlap-safe daily inventory.
- Sponsored viewer identity remains private unless the user deliberately Enquires.

## Architecture rules

- modular monolith;
- PostgreSQL/Supabase relational source of truth;
- reads may use secure projections;
- consequential writes use canonical RPCs;
- UI never directly mutates core operational state;
- actor + acting-for + object + relationship/capability/scope authorization;
- current server state beats stale UI;
- consequential commands are idempotent;
- critical capacity/inventory transitions are transactional;
- realtime invalidates/refetches only;
- notifications happen after core commit;
- private storage paths are never authorization;
- significant admin/safety/commercial actions are auditable.

## Next action — only when user authorizes Supabase

1. inspect the target Supabase project **read-only first**;
2. compare it against `19` + `20` and record compatibility/conflicts;
3. implement only **Foundation + Identity** through versioned migrations;
4. run migration/RLS/RPC/idempotency/authorization tests;
5. stop on any failed invariant;
6. do not create Locations until Foundation + Identity passes.

Use `22-implementation-runbook-v1.2.md` and `24-supabase-execution-checklist-v1.2.md` while executing.

## Recommended prompt for a new chat

> “Continue Raahi Learning V1.2. Read `RAAHI_LEARNING_HANDOVER.md` and `docs/raahi-learning/99-handover.md` from repo `rajeevbackup42112-coder/raahi`, branch `raahi-learning-v1-docs`. Then read `README.md`, `19-consolidated-database-blueprint-v1.2.md`, `20-consolidated-sql-migration-plan-v1.2.md`, `21-pre-supabase-readiness-review-v1.2.md`, `22-implementation-runbook-v1.2.md`, `23-final-acceptance-traceability-v1.2.md`, `24-supabase-execution-checklist-v1.2.md`, and the frozen Product/Domain/Architecture/Command/Acceptance/Ads docs. The real clickable UI was inspected and the final pre-Supabase package is complete. Supabase is untouched. Do not mutate Supabase until explicitly authorized; when authorized, inspect read-only first and implement Foundation + Identity only.”
