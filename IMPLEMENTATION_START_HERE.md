# Raahi Learning V1.2 — Implementation Branch

This branch was created **before Supabase access** so implementation can start in a controlled, isolated place once the user authorizes the environment boundary.

## Canonical documentation rule

The authoritative documentation branch is:

`raahi-learning-v1-docs`

The implementation branch inherited a documentation snapshot when it was created, but future documentation corrections may land on the docs branch first. Before starting or resuming implementation, read the latest canonical files from `raahi-learning-v1-docs` rather than assuming the inherited copies here are newest.

Primary current documents:

- `docs/raahi-learning/99-handover.md`
- `docs/raahi-learning/19-consolidated-database-blueprint-v1.2.md`
- `docs/raahi-learning/20-consolidated-sql-migration-plan-v1.2.md`
- `docs/raahi-learning/21-pre-supabase-readiness-review-v1.2.md`
- `docs/raahi-learning/22-implementation-runbook-v1.2.md`
- `docs/raahi-learning/23-final-acceptance-traceability-v1.2.md`
- `docs/raahi-learning/24-supabase-execution-checklist-v1.2.md`
- `docs/raahi-learning/26-final-pre-supabase-consistency-audit-v1.2.md`

## Do not mutate Supabase just because this branch exists

Before first write:

1. inspect the exact target Supabase project **read-only**;
2. fill `supabase/ENVIRONMENT_INSPECTION_TEMPLATE.md`;
3. compare the environment with the latest V1.2 contract;
4. reconcile any existing legacy/conflicting objects;
5. obtain explicit user authorization for implementation if not already given.

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

Run all mandatory migration/RLS/RPC/idempotency/authorization/privilege tests before starting Locations.

## Current external state

**No Raahi Learning Supabase migration has been executed.**
