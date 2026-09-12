# Raahi Learning V1.2 — Implementation Approval Record

Status: **PRE-SUPABASE WORK COMPLETE. APPROVED FOR READ-ONLY ENVIRONMENT INSPECTION AND CONTROLLED IMPLEMENTATION. SUPABASE REMAINS UNTOUCHED.**

This approval is issued only after completing:

1. Product/UI behavior freeze;
2. conceptual Domain/Architecture review;
3. physical database blueprint review;
4. SQL migration-plan review;
5. first written UI↔DB reconciliation;
6. construction of a real backend-free clickable UI prototype;
7. desktop/mobile, permission, edge-state and interaction inspection of that prototype;
8. final page-level UI↔DB reconciliation;
9. consolidated V1.2 physical database blueprint;
10. consolidated V1.2 migration plan;
11. final acceptance/UI/data traceability;
12. pre-Supabase readiness review and implementation runbook.

## Canonical implementation contract

For **new implementation work**, read these as the primary contract:

- `00-product-ui-freeze-v1.md` — frozen product behavior;
- `01-domain-model-v1.md` — domain concepts/invariants;
- `02-architecture-blueprint-v1.md` — architectural boundaries;
- `04-command-permission-matrix-v1.md` — command ownership/permission intent;
- `05-acceptance-regression-v1.md` — detailed Given/When/Then regressions;
- `06-raahi-ads-v1.md` — Ads business model;
- `18-ui-page-inventory-v1.1.md` — inspected 77-page UI surface inventory;
- `19-consolidated-database-blueprint-v1.2.md` — **single final physical design source**;
- `20-consolidated-sql-migration-plan-v1.2.md` — **single final migration sequence**;
- `21-pre-supabase-readiness-review-v1.2.md` — readiness decision;
- `22-implementation-runbook-v1.2.md` — slice-by-slice execution procedure;
- `23-final-acceptance-traceability-v1.2.md` — UI/data/command/test mapping;
- `24-supabase-execution-checklist-v1.2.md` — environment execution checklist.

Historical review/delta files (`03`, `08`, `09`, `10`, `11`, `13`, `14`, `15`, `16`, `17`) remain useful for decision traceability but no longer need to be mentally merged to reconstruct the final model. Where historical wording differs from the consolidated V1.2 blueprint/plan, V1.2 wins.

## Inspected UI artifact

Canonical artifact:

`Raahi_Learning_Clickable_UI_v1.1.zip`

Persistent Library path:

`/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`

SHA-256:

`2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

Final audit results:

- 77 canonical routes/pages;
- 154 desktop/mobile route checks, 0 issues;
- 32 privileged deep-link checks, 0 unguarded pages;
- 26 interaction/business-rule checks, 0 failures;
- 15 semantic/accessibility sanity samples, 0 issues.

Generated concept images remain inspiration only; the inspected clickable prototype plus frozen written rules define intended UI behavior.

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

1. **inspect the target environment read-only first**;
2. produce a compatibility/diff note;
3. implement only **Foundation + Identity**;
4. run all mandatory migration/RLS/RPC/idempotency/authorization tests;
5. do not proceed to Locations until the slice passes.

Foundation + Identity includes:

- extensions/common helpers;
- Accounts;
- Learners;
- Account↔Learner Access;
- Account Capabilities;
- Audit Log;
- Idempotency Keys;
- Identity authorization helpers including `can_make_learning_decision`;
- Identity canonical RPCs;
- Account pause/resume/guarded closure semantics;
- RLS and privilege hardening;
- ownership, manager-vs-self, account lifecycle, idempotency and privilege-escalation tests.

## Execution rules

Actual Supabase changes must:

- use versioned SQL migrations committed to source control;
- proceed slice-by-slice, never as a one-shot schema push;
- test each slice immediately;
- stop on contradiction or failed invariant;
- use forward-fix migrations after anything reaches a shared environment;
- keep private files authorized through current business access rather than copied URLs;
- treat frontend route/workspace guards only as defense in depth;
- never reinterpret old generated screenshots as requirements when they conflict with the V1.2 contract.

## Current external state

> **No Raahi Learning migration has been executed against Supabase.**

All meaningful work that should be completed **before** touching the target Supabase environment is now documented and closed. The next boundary crossing is environment inspection, only when explicitly authorized by the user.
