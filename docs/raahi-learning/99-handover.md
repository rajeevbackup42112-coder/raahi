# Raahi Learning V1.2 — Handover / Current State

**Read this file first in a new conversation.**

Repository: `rajeevbackup42112-coder/raahi`  
Documentation branch: `raahi-learning-v1-docs`  
Implementation branch: `raahi-learning-implementation-v1`  
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
- real backend-free clickable UI prototype;
- complete page/state inventory;
- desktop/mobile route audit;
- privileged deep-link/workspace audit;
- core journey/business-rule interaction audit;
- semantic/accessibility sanity audit;
- visual inspection of representative learner/teacher/manager/platform/mobile states;
- final inspected UI behavior freeze V1.1;
- final page-level UI↔DB reconciliation;
- final UI-proven DB/RPC/RLS delta;
- consolidated Database Blueprint V1.2;
- consolidated SQL Migration Plan V1.2;
- pre-Supabase readiness review and consistency audit;
- implementation runbook + execution checklist;
- dedicated implementation scaffold branch;
- comprehensive pre-Supabase test strategy;
- **backend-free randomized/property mock testing — PASS**;
- **APPROVED FOR CONTROLLED IMPLEMENTATION** decision.

### Not started

- any Raahi Learning Supabase migration;
- production tables/RLS/RPCs;
- backend integration of the clickable prototype;
- production deployment.

**Supabase is still untouched.**

## Canonical clickable UI artifact

Artifact: `Raahi_Learning_Clickable_UI_v1.1.zip`

Persistent Library path: `/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`

SHA-256: `2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

Inspection result:

- 77 canonical routes/pages;
- 154 desktop/mobile route checks, 0 issues;
- 32 privileged deep-link checks, 0 unguarded;
- 26 interaction/business-rule checks, 0 failures;
- 15 semantic/accessibility sanity samples, 0 issues.

## Mock/model test result

See:

- `27-pre-supabase-test-strategy-v1.2.md`
- `28-mock-model-test-results-v1.2.md`

Executed logical simulations passed:

- ~2.5M randomized Class Invitation/Membership capacity transitions;
- ~2.5M randomized Ads inventory transitions;
- 100k Learner share-code lifecycle operations;
- 100k Test Attempt identity/retry operations;
- 100k protected Ads-surface decisions;
- 200k cross-domain invariant bundles;
- 100k-request extreme Class contention against 50 seats -> exactly 50 reservations, 0 modeled oversell;
- 100k-request Ads contention against capacity 100 -> exactly 100 units, 0 modeled oversell.

This proves logical consistency **assuming the implementation enforces the specified atomic transaction boundaries**. It does not replace real staging tests for PostgreSQL locking/deadlocks, RLS, grants, indexes, Supabase Realtime/Storage, network failures, or p95/p99 latency.

## Product essence

Raahi Learning is a local learning community launched one Location at a time.

Core journey:

**Find → Enquire → optional Trial → Class Invitation → Join Class → Learn**

One Account may learn, teach, manage a Learner and represent an Organization.

Learner identity/history is separate from Account.

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

1. Location lifecycle begins with `interest_only` before `preparing`;
2. existing offline learner invitation uses a private, expiring, one-time Learner share code;
3. `class_invitations` includes optional `fee_display_text` snapshot;
4. `test_attempts` includes optional private `teacher_feedback`;
5. Settings uses guarded Account pause/resume/closure commands with responsibility blockers;
6. privileged reads/deep links re-check real capability/relationship/Organization/Location scope; UI workspace selection is never authority.

Earlier binding corrections also apply: selected Location preference relationship, location interests, manager decision authority, Organization logo, deterministic historical Class access, no independent Class-thread lifecycle, Session Past derived from time, reusable Activity Materials, report Learner context, atomic Class completion, surface-based Sponsored serving, and no fake Enquiry/Enrollment history for offline learners.

## Current implementation sources

Read these first:

- `19-consolidated-database-blueprint-v1.2.md`
- `20-consolidated-sql-migration-plan-v1.2.md`
- `21-pre-supabase-readiness-review-v1.2.md`
- `22-implementation-runbook-v1.2.md`
- `23-final-acceptance-traceability-v1.2.md`
- `24-supabase-execution-checklist-v1.2.md`
- `27-pre-supabase-test-strategy-v1.2.md`
- `28-mock-model-test-results-v1.2.md`
- `12-implementation-approval-v1.md`

Historical review/delta files remain for traceability. Consolidated V1.2 implementation documents win where old wording differs.

## Core architecture rules

- modular monolith;
- PostgreSQL/Supabase-compatible relational source of truth;
- secure read projections allowed;
- consequential writes use canonical business commands/RPCs;
- UI never directly mutates core operational tables;
- actor + acting-for + object + relationship/capability/scope authorization;
- navigation/workspace labels never grant authority;
- scoped restrictions instead of one giant status;
- current server state beats stale UI;
- consequential commands idempotent;
- Class capacity and Ads inventory transactionally protected;
- valid Pending Class Invitations reserve seats at send time;
- Test definition locks after valid Attempts begin;
- realtime invalidates/refetches only;
- notifications after core commit;
- private file path/URL never bypasses authorization;
- organic discovery and Sponsored serving remain separate;
- Sponsored serves exact approved Campaign Revision;
- significant admin/safety/commercial actions audited.

## Next operational action

When the user explicitly authorizes Supabase execution:

1. inspect the exact target Supabase project **read-only first**;
2. fill the environment inspection record;
3. implement only **Foundation + Identity** through versioned SQL migrations;
4. run migration/RLS/RPC/idempotency/authorization/privilege tests;
5. add real runtime/concurrency tests for that slice;
6. stop on any failed invariant;
7. do not create Locations until Foundation + Identity passes.

## Supabase rule

No Raahi Learning migration has been executed.

When execution begins, use versioned migrations, no ad-hoc dashboard schema edits, test every slice, use forward-fix migrations on shared environments, and preserve required history/safety/audit evidence.
