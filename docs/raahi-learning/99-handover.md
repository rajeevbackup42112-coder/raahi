# Raahi Learning V1.2 — Handover / Current State

**Read this file first in a new conversation.**

Repository: `rajeevbackup42112-coder/raahi`  
Documentation branch: `raahi-learning-v1-docs`  
Implementation branch: `raahi-learning-implementation-v1`  
Canonical folder: `docs/raahi-learning/`

> This project is isolated from the older Raahi ride implementation on `main`. Do not infer Raahi Learning behavior from old ride code.

## Current phase

### Product / UI / design / QA completed

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
- master QA catalog;
- canonical synthetic personas/fixtures;
- reproducible backend-free model-test harness;
- expanded model/property execution: **5,349,992 cases/operations, 0 invariant failures**;
- staging load/security/chaos/recovery plan;
- pre-Supabase QA readiness verdict.

### Supabase implementation completed

Target project:

- name: `rajeev.backup3.2112@gmail.com's Project`
- ref: `iiwwmqokaeflaenhlyip`
- region: `ap-south-1`
- PostgreSQL: 17.6

The target was inspected read-only first and was clean: no Raahi application tables, migrations, users, buckets, Edge Functions or legacy mobility objects.

**Foundation + Identity is now implemented in the dev project and its first-slice gate PASSED.**

Applied migrations:

1. `0001_extensions_helpers`
2. `0002_common_updated_at`
3. `0100_identity_tables`
4. `0101_identity_constraints_indexes`
5. `0102_command_infrastructure`
6. `0103_identity_rls_helpers`
7. `0104_identity_rpcs`
8. `0105_identity_hardening_followup`
9. `0106_private_function_privileges`

Implemented application tables:

- `accounts`
- `learners`
- `account_learner_access`
- `account_capabilities`
- `audit_log`
- `idempotency_keys`

Implemented identity behavior includes Account/Learner separation, one active self and manager relationship per Learner, manager-vs-self formal decision authority, no Test-taking impersonation from manager authority, governed self-access grant, privileged management transfer/capability grant-revoke, pause/resume/guarded closure, idempotency and audit.

All public application tables have RLS enabled and forced. Authenticated clients have safe reads only where intended; core state writes go through canonical RPCs. `anon` cannot call protected Identity RPCs. Private helper function PUBLIC EXECUTE defaults were removed after ACL inspection.

Runtime test results:

- `FOUNDATION_IDENTITY_RUNTIME_TESTS_PASS`
- `POST_HARDENING_SECURITY_SMOKE_PASS`

Verified real DB behavior includes idempotency, request-fingerprint mismatch rejection, manager/self authority, sibling isolation, direct-write denial, anonymous denial, privilege-escalation denial, second-manager physical uniqueness, account lifecycle retry behavior, sole-manager closure blocker, audit generation and idempotency records.

All synthetic runtime data was executed inside rollback transactions. Current dev data remains empty.

Security Advisor after hardening: **0 findings**.
Performance Advisor: only expected `unused_index` informational notices on the new empty database; no missing-FK-index finding remains.

See:

- `34-foundation-identity-implementation-result-v1.2.md`
- implementation branch `supabase/ENVIRONMENT_INSPECTION_2026-09-12.md`
- implementation branch `tests/db/010_foundation_identity_runtime_smoke.sql`

## Current implementation gate

> **STOP BEFORE LOCATIONS.**

Foundation + Identity passed, so the next eligible slice is Locations, but it has **not** been implemented yet.

Next slice only:

- `0200_locations_tables.sql`
- `0201_account_location_preferences.sql`
- `0202_locations_staff_rls_rpcs.sql`
- `0203_location_interests.sql`

Do not proceed beyond Locations until its migration/constraint/RLS/RPC/idempotency/scope tests pass.

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
- `34-foundation-identity-implementation-result-v1.2.md`

## Core implementation sources

For implementation, read at minimum:

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
- `34-foundation-identity-implementation-result-v1.2.md`

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

## Recommended new-chat prompt

> “Continue Raahi Learning V1.2 from `rajeevbackup42112-coder/raahi`. Read `RAAHI_LEARNING_HANDOVER.md`, `docs/raahi-learning/99-handover.md`, `34-foundation-identity-implementation-result-v1.2.md`, the consolidated blueprint/migration/runbook docs and QA docs. Supabase project `iiwwmqokaeflaenhlyip` has Foundation + Identity implemented and runtime-tested PASS. Security Advisor is clean. Stop gate is currently before Locations. If authorized to continue, implement and test only Locations `0200–0203`, then stop again on any failed gate.”