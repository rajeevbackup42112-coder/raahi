# Raahi Learning V1.2 — Handover / Current State

**Read this file first in a new conversation.**

Repository: `rajeevbackup42112-coder/raahi`  
Documentation branch: `raahi-learning-v1-docs`  
Implementation branch: `raahi-learning-implementation-v1`  
Canonical folder: `docs/raahi-learning/`

> This project is isolated from the older Raahi ride implementation on `main`. Do not infer Raahi Learning behavior from old ride code.

## Current phase

### Completed before Supabase

- Problem / Actors / Ownership / Business Rules;
- edge-case, malicious-action and concurrency design;
- terminology and complexity-reduction passes;
- learner/guardian simplification;
- Raahi Ads product/inventory/privacy design;
- Product + UI behavior freeze;
- Domain Model and Architecture boundaries;
- physical DB blueprint/review;
- SQL migration plan/review;
- first UI↔DB reconciliation;
- real backend-free clickable UI prototype;
- 77-page/state inventory;
- desktop/mobile/deep-link/interaction/accessibility UI audits;
- final inspected UI freeze and second UI↔DB reconciliation;
- consolidated Database Blueprint V1.2;
- consolidated SQL Migration Plan V1.2;
- final acceptance traceability;
- implementation runbook + Supabase execution checklist;
- pre-Supabase readiness/consistency reviews;
- comprehensive test strategy;
- master QA test catalog across scenario/state/permission/stale/retry/concurrency/security/privacy/load/chaos/migration/UI testing;
- canonical synthetic personas/fixtures;
- backend-free reproducible model-test harness on the implementation branch;
- expanded model/property execution: **5,349,992 cases/operations, 0 invariant failures**;
- staging load/security/chaos/recovery plan;
- pre-Supabase QA readiness verdict: **PASS for everything that can honestly be proven without a real DB**;
- implementation approval for controlled slice execution after read-only environment inspection.

### Not started

- any Raahi Learning Supabase migration;
- production tables/RLS/RPCs;
- backend integration of the prototype;
- real PostgreSQL concurrency/RLS/security/performance testing;
- production deployment.

> **Supabase is still untouched.**

## Clickable UI artifact

Artifact: `Raahi_Learning_Clickable_UI_v1.1.zip`  
Library path: `/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`  
SHA-256: `2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

Final inspected UI:

- 77 canonical routes/pages;
- 154 desktop/mobile route checks — 0 issues;
- 32 privileged deep-link checks — 0 unguarded;
- 26 interaction/business-rule checks — 0 failures;
- 15 semantic/accessibility sanity samples — 0 issues.

## QA package

Read:

- `27-pre-supabase-test-strategy-v1.2.md`
- `29-master-test-case-catalog-v1.2.md`
- `30-expanded-mock-model-test-results-v1.3.md`
- `31-staging-load-security-chaos-plan-v1.2.md`
- `32-canonical-test-personas-fixtures-v1.2.md`
- `33-pre-supabase-qa-readiness-verdict-v1.2.md`

### Current logical-model result

Expanded deterministic model run:

> **5,349,992 modeled cases/operations, 0 invariant failures.**

Covered:

- Learning Request state rules;
- Enquiry contextual messaging;
- Class capacity/Invitation reservations;
- atomic transfer model;
- Test self-vs-manager authority and retry behavior;
- Learner share-code lifecycle;
- Account closure blockers;
- Location preference independence;
- Ads inventory and exact serving Revision;
- protected Sponsored surfaces;
- Report/Block separation;
- Class completion preservation;
- public Learning Request privacy projection.

Earlier concentrated logical contention also passed:

- 100,000 Invitation attempts against capacity 50 → exactly 50 reservations;
- 100,000 Ads reservation attempts against capacity 100 → exactly 100 units.

These are model passes, not PostgreSQL certifications. Real locking/deadlock/RLS/GRANT/Storage/Realtime/query-plan/latency/security tests remain mandatory and are explicitly cataloged.

## Core implementation sources

For actual implementation, read at minimum:

- `00-product-ui-freeze-v1.md`
- `01-domain-model-v1.md`
- `02-architecture-blueprint-v1.md`
- `04-command-permission-matrix-v1.md`
- `05-acceptance-regression-v1.md`
- `06-raahi-ads-v1.md`
- `18-ui-page-inventory-v1.1.md`
- `19-consolidated-database-blueprint-v1.2.md`
- `20-consolidated-sql-migration-plan-v1.2.md`
- `22-implementation-runbook-v1.2.md`
- `23-final-acceptance-traceability-v1.2.md`
- `24-supabase-execution-checklist-v1.2.md`
- `29-master-test-case-catalog-v1.2.md`
- `31-staging-load-security-chaos-plan-v1.2.md`
- `32-canonical-test-personas-fixtures-v1.2.md`
- `12-implementation-approval-v1.md`

Historical `03/08/09/10/11/13/14/15/16/17` files remain decision history. Consolidated V1.2 sources win where wording differs.

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

## Core architecture rules

- one Account may learn, teach, manage a Learner and represent an Organization;
- Learner identity/history is independent from the acting Account;
- parent/guardian acts **for** Learner, not by impersonation;
- formal learner-side marketplace decisions use `can_make_learning_decision`;
- manager authority does not grant Test-taking authority;
- UI never directly mutates core operational state;
- consequential writes use canonical commands/RPCs;
- navigation/workspace is never authorization;
- server current state beats stale UI;
- consequential commands are idempotent;
- valid Pending Class Invitations reserve seats at send time;
- Class capacity and Ads inventory are transactionally protected;
- private share code replaces public Learner search for offline-origin invitation;
- Test definition locks after first valid Attempt;
- Realtime invalidates/refetches only;
- private file URL/path never bypasses current authorization;
- organic discovery and Sponsored serving are separate;
- Sponsored uses exact approved Revision;
- significant safety/admin/commercial actions are auditable.

## Implementation branch test infrastructure

`raahi-learning-implementation-v1` includes:

- `IMPLEMENTATION_START_HERE.md`
- `supabase/ENVIRONMENT_INSPECTION_TEMPLATE.md`
- `supabase/migrations/README.md`
- `tests/db/README.md`
- `tests/model/pre_supabase_model_tests.py`
- `tests/model/README.md`
- `.github/workflows/raahi-learning-model-tests.yml`

No environment-specific migration SQL has been fabricated before inspecting the chosen target project.

## Next operational action

Only when the user authorizes Supabase work:

1. inspect the exact target Supabase project **read-only first**;
2. fill the environment inspection record and compare actual environment state with V1.2;
3. implement only **Foundation + Identity** through versioned migrations;
4. execute all Foundation + Identity test cases from the master catalog: migration, constraints, RLS, RPC authorization, idempotency, lifecycle blockers and privilege attacks;
5. stop on any failed invariant/security test;
6. only after that slice is PASS may Locations begin.

## Recommended new-chat prompt

> “Continue Raahi Learning V1.2 from `rajeevbackup42112-coder/raahi`, branch `raahi-learning-v1-docs`. Read `RAAHI_LEARNING_HANDOVER.md`, `docs/raahi-learning/99-handover.md`, the consolidated blueprint/migration/runbook documents, and QA docs `29`–`33`. The clickable UI and pre-Supabase logical QA gates passed. Supabase is untouched. If I explicitly authorize Supabase, inspect the target environment read-only first, then implement Foundation + Identity only and execute its real DB/security tests before proceeding.”