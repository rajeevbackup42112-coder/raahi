# Raahi Learning V1.2 — Supabase Environment Inspection Record

Fill this **before the first mutation**.

## Target identity

- Project name:
- Project ref:
- Environment purpose: dev / test / staging / prod
- Region:
- Date inspected:
- Inspector:

## Existing database state

- Existing schemas:
- Existing Raahi-related tables:
- Existing functions/RPCs:
- Existing triggers:
- Existing RLS policies:
- Existing migration history:
- Existing cron/realtime objects:
- Existing extensions:

## Auth

- Enabled providers:
- OTP configuration relevant to product:
- Existing auth hooks/triggers:
- Notes/conflicts:

## Storage

- Existing buckets:
- Public/private status:
- Existing policies:
- Potential naming conflicts with planned buckets:

## Compatibility classification

For each existing object that overlaps the Raahi Learning plan, classify:

- compatible/reusable;
- unrelated/isolate;
- conflicting/reconcile;
- legacy/do-not-reuse;
- unknown/investigate.

## V1.2 contract comparison

Reference:

- `docs/raahi-learning/19-consolidated-database-blueprint-v1.2.md`
- `docs/raahi-learning/20-consolidated-sql-migration-plan-v1.2.md`

### Blocking conflicts

- None / list:

### Non-blocking differences

- None / list:

## First-slice decision

- Safe to create Foundation + Identity migrations? YES / NO
- If NO, why:
- Required reconciliation before mutation:

## Mutation authorization

Do not fill this simply because inspection finished.

- User explicitly authorized implementation: YES / NO
- First permitted slice: **Foundation + Identity only**
