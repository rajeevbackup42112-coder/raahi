# Raahi Learning V1.2 — Start Here

This branch contains the canonical Raahi Learning product, inspected UI, consolidated technical contract and complete pre-Supabase QA package.

**Repository:** `rajeevbackup42112-coder/raahi`  
**Documentation branch:** `raahi-learning-v1-docs`  
**Implementation branch:** `raahi-learning-implementation-v1`  
**Canonical folder:** [`docs/raahi-learning/`](docs/raahi-learning/)

## Read first

1. [`docs/raahi-learning/99-handover.md`](docs/raahi-learning/99-handover.md)
2. [`docs/raahi-learning/README.md`](docs/raahi-learning/README.md)
3. [`docs/raahi-learning/19-consolidated-database-blueprint-v1.2.md`](docs/raahi-learning/19-consolidated-database-blueprint-v1.2.md)
4. [`docs/raahi-learning/20-consolidated-sql-migration-plan-v1.2.md`](docs/raahi-learning/20-consolidated-sql-migration-plan-v1.2.md)
5. [`docs/raahi-learning/22-implementation-runbook-v1.2.md`](docs/raahi-learning/22-implementation-runbook-v1.2.md)
6. [`docs/raahi-learning/23-final-acceptance-traceability-v1.2.md`](docs/raahi-learning/23-final-acceptance-traceability-v1.2.md)
7. [`docs/raahi-learning/24-supabase-execution-checklist-v1.2.md`](docs/raahi-learning/24-supabase-execution-checklist-v1.2.md)
8. [`docs/raahi-learning/29-master-test-case-catalog-v1.2.md`](docs/raahi-learning/29-master-test-case-catalog-v1.2.md)
9. [`docs/raahi-learning/30-expanded-mock-model-test-results-v1.3.md`](docs/raahi-learning/30-expanded-mock-model-test-results-v1.3.md)
10. [`docs/raahi-learning/31-staging-load-security-chaos-plan-v1.2.md`](docs/raahi-learning/31-staging-load-security-chaos-plan-v1.2.md)
11. [`docs/raahi-learning/32-canonical-test-personas-fixtures-v1.2.md`](docs/raahi-learning/32-canonical-test-personas-fixtures-v1.2.md)
12. [`docs/raahi-learning/33-pre-supabase-qa-readiness-verdict-v1.2.md`](docs/raahi-learning/33-pre-supabase-qa-readiness-verdict-v1.2.md)
13. [`docs/raahi-learning/12-implementation-approval-v1.md`](docs/raahi-learning/12-implementation-approval-v1.md)

For full product behavior, also read the Product/Domain/Architecture/Command/Acceptance/Ads documents indexed in `README.md`.

## Clickable UI artifact

`Raahi_Learning_Clickable_UI_v1.1.zip`  
Library: `/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`  
SHA-256: `2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

UI audit passed:

- 77 routes/pages;
- 154 desktop/mobile checks — 0 issues;
- 32 privileged deep-link checks — 0 unguarded;
- 26 interaction/business-rule checks — 0 failures;
- 15 semantic/accessibility sanity samples — 0 issues.

## Pre-Supabase QA result

A reproducible backend-free model suite now exists on the implementation branch and the expanded run exercised:

> **5,349,992 modeled cases/operations with 0 invariant failures.**

This includes Class capacity, transfer atomicity, Test self-vs-manager authority, Learner share codes, Location independence, Account closure blockers, Ads inventory/exact Revision serving, safety separation and public Request privacy.

The master catalog also defines all remaining real database/security/load/chaos tests. Runtime tests are deliberately not called PASS until PostgreSQL/Supabase exists.

## Current gate

- real clickable UI gate: **PASSED/CLOSED**;
- final UI↔DB reconciliation: **PASSED**;
- consolidated physical design: **COMPLETE**;
- consolidated migration plan: **COMPLETE**;
- master QA catalog: **COMPLETE**;
- pre-Supabase logical model QA: **PASS**;
- staging load/security/chaos plan: **COMPLETE**;
- implementation approval: **APPROVED FOR READ-ONLY ENVIRONMENT INSPECTION AND CONTROLLED SLICE IMPLEMENTATION**.

## Implementation branch

`raahi-learning-implementation-v1` already contains:

- environment inspection template;
- migration scaffold;
- database-test scaffold;
- reproducible model test harness;
- model-test README;
- GitHub Actions workflow for backend-free model tests.

No environment-specific SQL has been fabricated before inspection.

## Supabase state

> **No Raahi Learning Supabase migration has been executed.**

When the user explicitly authorizes Supabase:

1. inspect the exact project read-only;
2. compare environment state with V1.2;
3. implement only **Foundation + Identity** through versioned migrations;
4. execute all relevant real RLS/RPC/constraint/idempotency/security tests from the master catalog;
5. do not proceed to Locations until that slice passes.

Do not build the entire database in one push. The repository `main` branch contains older Raahi work and must not be assumed to implement this model.