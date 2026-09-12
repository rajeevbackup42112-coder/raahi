# Raahi Learning V1.2 — Supabase Environment Inspection Record

Status: **READ-ONLY INSPECTION COMPLETE — CLEAN DEV PROJECT / SAFE FOR FOUNDATION + IDENTITY.**

## Target identity

- Project name: `rajeev.backup3.2112@gmail.com's Project`
- Project ref: `iiwwmqokaeflaenhlyip`
- Environment purpose: **development** for Raahi Learning
- Region: `ap-south-1` (India)
- PostgreSQL: 17.6
- Date inspected: 2026-09-12
- Inspector: ChatGPT via connected Supabase tools

## Existing database state

- Existing schemas: `auth`, `extensions`, `graphql`, `graphql_public`, `public`, `realtime`, `storage`, `vault`
- Existing Raahi-related tables: **none**
- Existing custom `public` tables: **0**
- Existing custom `public` views: **0**
- Existing custom `public` functions/RPCs: **0**
- Existing custom `public` triggers: **0**
- Existing `public` RLS policies: **0** because no application tables exist
- Existing Supabase migration history: **none** (`list_migrations` returned empty)
- Existing development branches: **none**
- Existing Edge Functions: **none**
- Existing Realtime publication tables: **none**
- Existing extensions installed: `pgcrypto`, `pg_stat_statements`, `uuid-ossp`, `supabase_vault`, `plpgsql`
- Available but not installed: `pg_cron`, `pg_net`, `vector`, `pg_graphql`
- Security advisor: **0 findings** before Raahi schema
- Performance advisor: **0 findings** before Raahi schema

## Auth

- `auth.users`: **0 users**
- `auth.sessions`: **0 sessions**
- Existing custom auth triggers: **none observed**
- Standard Supabase Auth internal schema exists.
- Enabled provider/dashboard configuration is not surfaced by the current connector and is not required to create the Foundation + Identity database layer.
- OTP/email-provider configuration must be verified separately before UI Auth integration; it is **not a blocker for the database slice**.

## Storage

- Existing buckets: **0**
- Existing objects: **0**
- Existing custom Storage policies: **none**
- Potential naming conflicts with future Raahi buckets: **none**
- Standard Supabase Storage internal tables/triggers exist and must not be modified directly.

## API / privilege observations

- `anon`, `authenticated`, and `service_role` have `USAGE` on `public`, but no application-table privileges exist because `public` is empty.
- New Supabase projects no longer automatically expose new `public` tables through the Data API in the old way. Raahi migrations must use explicit least-privilege grants together with RLS.
- Public application tables must have RLS enabled immediately.
- Privileged helper functions should live in a non-exposed private schema with fixed `search_path`, explicit `auth.uid()` checks, and restricted `EXECUTE` privileges.

## Compatibility classification

There are no overlapping Raahi Learning application objects.

- Supabase-managed `auth`, `storage`, `realtime`, `vault`: **compatible/reusable platform infrastructure**
- `public`: **clean / available for Raahi application objects**
- existing extensions: **compatible**
- legacy Raahi mobility objects: **none in this project**
- migration conflicts: **none**

## V1.2 contract comparison

References:

- `docs/raahi-learning/19-consolidated-database-blueprint-v1.2.md`
- `docs/raahi-learning/20-consolidated-sql-migration-plan-v1.2.md`
- `docs/raahi-learning/29-master-test-case-catalog-v1.2.md`

### Blocking conflicts

**None found.**

### Non-blocking implementation notes

1. This is a clean September-2026 Supabase project; explicit Data API grants should be designed intentionally rather than assumed.
2. Auth provider/OTP dashboard settings still need verification when the frontend Auth slice is connected.
3. `pg_cron` is available but not installed; no need to install it in Foundation + Identity.
4. Realtime has no published Raahi tables yet; add only when a later slice proves the need.
5. Storage is clean; no bucket is needed in Foundation + Identity.

## First-slice decision

- Safe to create Foundation + Identity migrations? **YES**
- Required reconciliation before mutation: **none**
- First permitted slice: **Foundation + Identity only**

## Mutation authorization

- User explicitly authorized proceeding in this Supabase project: **YES** (`go` after project verification and read-only-inspection plan)
- Do not proceed to Locations until Foundation + Identity passes all mandatory migration/constraint/RLS/RPC/idempotency/authorization/security checks.
