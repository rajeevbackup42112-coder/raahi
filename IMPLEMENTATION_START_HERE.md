# Raahi Learning V1.2 — Implementation Branch

This branch was created **before Supabase access** so implementation can start in a controlled, isolated place once the user authorizes the environment boundary.

Canonical documentation remains under `docs/raahi-learning/` and is inherited from `raahi-learning-v1-docs`.

## Do not mutate Supabase just because this branch exists

Before first write:

1. read `docs/raahi-learning/99-handover.md`;
2. read `docs/raahi-learning/19-consolidated-database-blueprint-v1.2.md`;
3. read `docs/raahi-learning/20-consolidated-sql-migration-plan-v1.2.md`;
4. read `docs/raahi-learning/22-implementation-runbook-v1.2.md`;
5. read `docs/raahi-learning/24-supabase-execution-checklist-v1.2.md`;
6. inspect the exact target Supabase project read-only and record compatibility/conflicts.

Only then create/apply the first migration slice.

## First permitted slice

Foundation + Identity only:

- `0001_extensions_helpers.sql`
- `0002_common_updated_at.sql`
- `0100_identity_tables.sql`
- `0101_identity_constraints_indexes.sql`
- `0102_command_infrastructure.sql`
- `0103_identity_rls_helpers.sql`
- `0104_identity_rpcs.sql`

Do not start Locations until the slice passes all mandatory tests.

## Current external state

**No Raahi Learning Supabase migration has been executed.**
