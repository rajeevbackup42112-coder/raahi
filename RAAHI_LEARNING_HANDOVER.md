# Raahi Learning V1.1 — Start Here

This branch contains the canonical Raahi Learning V1.1 product, inspected UI and technical handover.

**Repository:** `rajeevbackup42112-coder/raahi`  
**Branch:** `raahi-learning-v1-docs`  
**Canonical folder:** [`docs/raahi-learning/`](docs/raahi-learning/)

## Read first

1. [`docs/raahi-learning/99-handover.md`](docs/raahi-learning/99-handover.md)
2. [`docs/raahi-learning/README.md`](docs/raahi-learning/README.md)
3. [`docs/raahi-learning/16-ui-page-freeze-and-final-reconciliation-v1.1.md`](docs/raahi-learning/16-ui-page-freeze-and-final-reconciliation-v1.1.md)
4. [`docs/raahi-learning/17-final-ui-db-implementation-delta-v1.1.md`](docs/raahi-learning/17-final-ui-db-implementation-delta-v1.1.md)
5. [`docs/raahi-learning/12-implementation-approval-v1.md`](docs/raahi-learning/12-implementation-approval-v1.md)
6. [`docs/raahi-learning/14-ui-db-implementation-delta-v1.md`](docs/raahi-learning/14-ui-db-implementation-delta-v1.md)
7. [`docs/raahi-learning/10-sql-migration-plan-v1.1.md`](docs/raahi-learning/10-sql-migration-plan-v1.1.md)
8. [`docs/raahi-learning/03-database-blueprint-v1.1.md`](docs/raahi-learning/03-database-blueprint-v1.1.md)

For full business behavior, also read the Product/Domain/Architecture/Command/Acceptance/Ads documents indexed in `README.md`.

## Clickable UI artifact

Canonical inspected artifact:

`Raahi_Learning_Clickable_UI_v1.1.zip`

Persistent Library path:

`/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`

SHA-256:

`2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

The inspected prototype covers 77 canonical routes/pages and passed its final desktop/mobile, deep-link permission, interaction/business-rule and semantic/accessibility audit suites.

## Current gate

The real clickable UI build/review gate is **PASSED/CLOSED**.

The final inspected page-level UI↔DB reconciliation is **PASSED**.

The technical plan is:

> **APPROVED FOR CONTROLLED IMPLEMENTATION**

Implementation contract:

> `10-sql-migration-plan-v1.1.md` + `14-ui-db-implementation-delta-v1.md` + `17-final-ui-db-implementation-delta-v1.1.md`

with later intentional deltas taking precedence (**17 → 14 → 10**) and `16-ui-page-freeze-and-final-reconciliation-v1.1.md` defining the inspected UI behavior that implementation must preserve.

Important final UI-proven additions include:

- `interest_only` Location state;
- private expiring one-time Learner share codes;
- Class Invitation fee-display snapshot;
- Test Attempt teacher feedback;
- guarded Account pause/resume/closure flows;
- explicit capability/relationship/scope checks on privileged deep links/reads.

## Supabase state

**No Raahi Learning Supabase migration has been executed.**

If the user explicitly authorizes database execution, inspect the target Supabase project/environment first and implement only **Foundation + Identity** through versioned migrations. Run its RLS/RPC/authorization/idempotency/privilege tests before proceeding to Locations.

Do not build the entire database in one push.

The repository `main` branch contains earlier Raahi work and must not be assumed to implement this frozen Raahi Learning model.
