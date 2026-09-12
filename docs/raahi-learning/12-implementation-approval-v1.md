# Raahi Learning V1.2 — Implementation Approval Record

Status: **PRE-SUPABASE PRODUCT + UI + TECHNICAL + QA WORK COMPLETE. APPROVED FOR READ-ONLY ENVIRONMENT INSPECTION AND CONTROLLED IMPLEMENTATION. SUPABASE REMAINS UNTOUCHED.**

This approval is issued only after completing:

1. Product/UI behavior freeze;
2. conceptual Domain/Architecture review;
3. physical database blueprint review;
4. SQL migration-plan review;
5. written UI↔DB reconciliation;
6. real backend-free clickable UI construction;
7. desktop/mobile/permission/edge-state/interaction inspection;
8. final page-level UI↔DB reconciliation;
9. consolidated V1.2 database blueprint;
10. consolidated V1.2 migration plan;
11. final acceptance/UI/data traceability;
12. pre-Supabase readiness and consistency reviews;
13. implementation runbook + Supabase execution checklist;
14. master QA catalog spanning scenario/state/permission/stale/retry/concurrency/security/privacy/load/chaos/migration/UI tests;
15. canonical synthetic personas/fixtures;
16. expanded backend-free model/property execution;
17. staging load/security/chaos/recovery plan;
18. final pre-Supabase QA readiness verdict.

## Canonical implementation contract

Primary implementation sources:

- `00-product-ui-freeze-v1.md`
- `01-domain-model-v1.md`
- `02-architecture-blueprint-v1.md`
- `04-command-permission-matrix-v1.md`
- `05-acceptance-regression-v1.md`
- `06-raahi-ads-v1.md`
- `18-ui-page-inventory-v1.1.md`
- `19-consolidated-database-blueprint-v1.2.md`
- `20-consolidated-sql-migration-plan-v1.2.md`
- `21-pre-supabase-readiness-review-v1.2.md`
- `22-implementation-runbook-v1.2.md`
- `23-final-acceptance-traceability-v1.2.md`
- `24-supabase-execution-checklist-v1.2.md`
- `29-master-test-case-catalog-v1.2.md`
- `31-staging-load-security-chaos-plan-v1.2.md`
- `32-canonical-test-personas-fixtures-v1.2.md`
- `33-pre-supabase-qa-readiness-verdict-v1.2.md`

Historical review/delta files (`03`, `08`, `09`, `10`, `11`, `13`, `14`, `15`, `16`, `17`) remain useful for decision traceability. Where historical wording differs from consolidated V1.2, V1.2 wins.

## Inspected UI artifact

`Raahi_Learning_Clickable_UI_v1.1.zip`  
Library: `/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`  
SHA-256: `2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

UI audit:

- 77 canonical routes/pages;
- 154 desktop/mobile route checks — 0 issues;
- 32 privileged deep-link checks — 0 unguarded;
- 26 interaction/business-rule checks — 0 failures;
- 15 semantic/accessibility sanity samples — 0 issues.

## Pre-Supabase QA evidence

Expanded deterministic backend-free model run:

> **5,349,992 cases/operations, 0 invariant failures.**

Covered state/permission/invariant behavior for Learning Requests, Enquiries, Class capacity and transfer, Test authority/idempotency, Learner share codes, Account closure, Location preference independence, Ads inventory/exact Revision serving, protected Sponsored surfaces, Report/Block separation, Class completion and public Request privacy.

Earlier concentrated model contention also passed:

- 100,000 requests against a 50-seat Class → exactly 50 reservations;
- 100,000 requests against Ads capacity 100 → exactly 100 units.

This is logical design evidence only. Actual RLS/GRANT/locking/deadlock/Storage/Realtime/query-plan/latency/security behavior remains a mandatory runtime gate after real schema slices exist.

## Removed complexity remains removed

Do not casually reintroduce:

- Enrollment;
- Batch entity;
- Adult/Minor Learner entities;
- turning-18 migration;
- major Trial relationship object;
- Attendance;
- generic Progress %;
- public ratings/reviews;
- public Learner directory;
- unrestricted direct messaging;
- multi-teacher Class in V1.2;
- advertiser viewer CRM;
- platform tuition-payment collection.

## First approved execution slice

After the user explicitly authorizes Supabase access:

1. inspect the target environment **read-only first**;
2. produce a compatibility/diff record;
3. implement only **Foundation + Identity**;
4. execute all relevant Foundation + Identity cases from `29-master-test-case-catalog-v1.2.md` — migration, constraints, RLS, RPC permissions, acting-for rules, idempotency, Account lifecycle blockers and privilege escalation;
5. stop on any failed invariant/security test;
6. do not proceed to Locations until the slice passes.

Foundation + Identity includes extensions/common helpers, Accounts, Learners, Account↔Learner Access, Account Capabilities, Audit Log, Idempotency Keys, Identity authorization helpers including `can_make_learning_decision`, Identity RPCs, Account pause/resume/guarded closure semantics, RLS and privilege hardening.

## Execution rules

Actual Supabase changes must:

- use versioned SQL migrations committed to source control;
- proceed slice-by-slice, never as a one-shot schema push;
- test every slice immediately;
- stop on contradiction or failed invariant;
- use forward-fix migrations after anything reaches a shared environment;
- keep private files authorized through current business access rather than copied URLs;
- treat frontend route/workspace guards only as defense in depth;
- never weaken security/business invariants to make a performance benchmark pass.

## Current external state

> **No Raahi Learning migration has been executed against Supabase.**

Everything that can reasonably and honestly be completed before touching the target environment is now closed. The next boundary crossing is read-only environment inspection, only when explicitly authorized.