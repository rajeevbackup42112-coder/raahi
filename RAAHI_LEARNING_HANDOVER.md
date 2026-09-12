# Raahi Learning V1 — Start Here

This branch contains the canonical Raahi Learning V1 product and technical documentation.

**Branch:** `raahi-learning-v1-docs`  
**Canonical folder:** [`docs/raahi-learning/`](docs/raahi-learning/)

Start with:

1. [`docs/raahi-learning/99-handover.md`](docs/raahi-learning/99-handover.md)
2. [`docs/raahi-learning/README.md`](docs/raahi-learning/README.md)
3. [`docs/raahi-learning/13-ui-db-reconciliation-v1.md`](docs/raahi-learning/13-ui-db-reconciliation-v1.md)
4. [`docs/raahi-learning/14-ui-db-implementation-delta-v1.md`](docs/raahi-learning/14-ui-db-implementation-delta-v1.md)
5. [`docs/raahi-learning/12-implementation-approval-v1.md`](docs/raahi-learning/12-implementation-approval-v1.md)
6. [`docs/raahi-learning/10-sql-migration-plan-v1.1.md`](docs/raahi-learning/10-sql-migration-plan-v1.1.md)
7. [`docs/raahi-learning/03-database-blueprint-v1.1.md`](docs/raahi-learning/03-database-blueprint-v1.1.md)

For business behavior also read the frozen Product/Domain/Architecture/Command/Acceptance/Ads documents listed in `README.md`.

Historical drafts are retained for traceability but are not implementation sources:

- `03-database-blueprint-v1.md`
- `10-sql-migration-plan-v1.md`

## Current gate

The mandatory UI Prototype ↔ DB reconciliation is complete and the technical plan is **APPROVED FOR CONTROLLED IMPLEMENTATION**.

The implementation contract is `10-sql-migration-plan-v1.1.md` **plus** `14-ui-db-implementation-delta-v1.md`; the later reconciliation delta wins where wording differs.

**No Raahi Learning Supabase migration has been executed yet.**

If the user explicitly authorizes Supabase work, inspect the target project first and implement only **Foundation + Identity**. Run its migration/RLS/RPC/authorization/idempotency tests before proceeding to Locations.

The existing repository `main` branch contains prior Raahi work and must not be assumed to implement Raahi Learning's frozen model.
