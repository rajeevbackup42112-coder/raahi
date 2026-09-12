# Raahi Learning V1.2 — Start Here

This branch contains the canonical Raahi Learning product, inspected UI and complete pre-Supabase technical handover.

**Repository:** `rajeevbackup42112-coder/raahi`  
**Branch:** `raahi-learning-v1-docs`  
**Canonical folder:** [`docs/raahi-learning/`](docs/raahi-learning/)

## Read first

1. [`docs/raahi-learning/99-handover.md`](docs/raahi-learning/99-handover.md)
2. [`docs/raahi-learning/README.md`](docs/raahi-learning/README.md)
3. [`docs/raahi-learning/19-consolidated-database-blueprint-v1.2.md`](docs/raahi-learning/19-consolidated-database-blueprint-v1.2.md)
4. [`docs/raahi-learning/20-consolidated-sql-migration-plan-v1.2.md`](docs/raahi-learning/20-consolidated-sql-migration-plan-v1.2.md)
5. [`docs/raahi-learning/21-pre-supabase-readiness-review-v1.2.md`](docs/raahi-learning/21-pre-supabase-readiness-review-v1.2.md)
6. [`docs/raahi-learning/22-implementation-runbook-v1.2.md`](docs/raahi-learning/22-implementation-runbook-v1.2.md)
7. [`docs/raahi-learning/23-final-acceptance-traceability-v1.2.md`](docs/raahi-learning/23-final-acceptance-traceability-v1.2.md)
8. [`docs/raahi-learning/24-supabase-execution-checklist-v1.2.md`](docs/raahi-learning/24-supabase-execution-checklist-v1.2.md)
9. [`docs/raahi-learning/12-implementation-approval-v1.md`](docs/raahi-learning/12-implementation-approval-v1.md)

For full product behavior, also read the Product/Domain/Architecture/Command/Acceptance/Ads documents indexed in `README.md`.

## Clickable UI artifact

Canonical inspected artifact:

`Raahi_Learning_Clickable_UI_v1.1.zip`

Persistent Library path:

`/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`

SHA-256:

`2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

The prototype contains 77 canonical routes/pages and passed desktop/mobile, privileged deep-link, interaction/business-rule and semantic/accessibility audit suites with zero final issues.

## Current gate

- real clickable UI gate: **PASSED/CLOSED**;
- final page-level UI↔DB reconciliation: **PASSED**;
- consolidated physical design: **COMPLETE**;
- consolidated migration plan: **COMPLETE**;
- final acceptance traceability: **COMPLETE**;
- pre-Supabase readiness review: **PASS**;
- implementation approval: **APPROVED FOR READ-ONLY ENVIRONMENT INSPECTION AND CONTROLLED SLICE IMPLEMENTATION**.

Historical `03/08/09/10/11/13/14/15/16/17` files remain decision history. New implementation should use consolidated V1.2 docs instead of manually merging old deltas.

## Supabase state

**No Raahi Learning Supabase migration has been executed.**

When the user explicitly authorizes Supabase access:

1. inspect the exact target project read-only first;
2. compare existing environment state with the V1.2 contract;
3. implement only **Foundation + Identity** through versioned migrations;
4. run its RLS/RPC/authorization/idempotency/privilege tests;
5. do not proceed to Locations until the slice passes.

Do not build the entire database in one push.

The repository `main` branch contains older Raahi work and must not be assumed to implement this Raahi Learning model.
