# Raahi Learning V1.2 — Foundation + Identity Implementation Result

Status: **IMPLEMENTED IN DEV AND PASSED FIRST-SLICE GATE. STOP BEFORE LOCATIONS.**

Target Supabase project:

- name: `rajeev.backup3.2112@gmail.com's Project`
- ref: `iiwwmqokaeflaenhlyip`
- region: `ap-south-1`
- PostgreSQL: 17.6

## Read-only environment inspection

The project was clean before implementation:

- zero custom `public` tables/views/functions/triggers;
- zero Raahi application migrations;
- zero Auth users/sessions;
- zero Storage buckets/objects;
- zero Edge Functions;
- no Realtime publication tables;
- no legacy Raahi mobility objects;
- no blocking security/performance advisor findings.

The exact inspection record is on implementation branch:

`supabase/ENVIRONMENT_INSPECTION_2026-09-12.md`

## Applied migration history

Applied, in order:

1. `0001_extensions_helpers`
2. `0002_common_updated_at`
3. `0100_identity_tables`
4. `0101_identity_constraints_indexes`
5. `0102_command_infrastructure`
6. `0103_identity_rls_helpers`
7. `0104_identity_rpcs`
8. `0105_identity_hardening_followup`
9. `0106_private_function_privileges`

The source SQL is committed under `supabase/migrations/` on branch `raahi-learning-implementation-v1`.

## Implemented objects

Tables:

- `accounts`
- `learners`
- `account_learner_access`
- `account_capabilities`
- `audit_log`
- `idempotency_keys`

Identity behavior includes:

- Account distinct from Learner;
- one active self relationship per Learner;
- one active manager relationship per Learner;
- explicit manager-vs-self authority;
- `can_make_learning_decision` semantics;
- manager does not gain Learner self/Test-taking authority;
- governed self-access grant;
- platform-governed management transfer/capability grant/revoke;
- pause/resume/guarded closure;
- idempotent consequential commands;
- append-oriented audit records.

Security:

- all public application tables have RLS enabled and forced;
- ordinary clients receive safe read grants only where required;
- core operational writes are not directly granted to authenticated clients;
- canonical writes use RPCs;
- `anon` cannot execute protected Identity RPCs;
- private helper schema is not exposed as Data API schema;
- PUBLIC EXECUTE was explicitly removed from private functions after ACL inspection;
- security advisor after hardening: **0 findings**.

## Runtime tests executed

A transactional test suite was executed with synthetic Auth users and then rolled back.

Verified:

- bootstrap Account from `auth.uid()`;
- create managed Learner;
- same-key/same-request idempotent retry creates no duplicate;
- same key with different request fingerprint is rejected;
- active manager has formal decision authority;
- manager does not have self/Test-taking authority;
- learner self Account can be linked to same Learner;
- learner self cannot override formal manager decision while manager remains active;
- sibling/other-Learner isolation through RLS;
- direct authenticated table inserts/updates are denied;
- anonymous table/RPC access is denied;
- non-admin privilege escalation is denied;
- second active manager is rejected by physical uniqueness constraint;
- pause/resume retry returns one logical result;
- sole-manager closure blocker prevents closure;
- audit/idempotency rows are produced during commands;
- post-hardening permission smoke passed.

Primary runtime result:

`FOUNDATION_IDENTITY_RUNTIME_TESTS_PASS`

Post-hardening result:

`POST_HARDENING_SECURITY_SMOKE_PASS`

Reusable smoke SQL is committed at:

`tests/db/010_foundation_identity_runtime_smoke.sql`

All synthetic test data was run inside rollback transactions. Final counts remained zero for Auth users, Accounts, Learners, access rows, audit rows and idempotency rows.

## Advisor review

Security advisor after forward fixes:

- **0 findings**

Performance advisor:

- no missing-FK-index finding remains;
- only `unused_index` informational notices remain, expected because this is a newly created empty development database. These indexes correspond to planned lookup/RLS/audit paths and should not be removed before representative workload exists.

## First-slice verdict

**PASS.**

Foundation + Identity has passed its initial migration, constraint, RLS, RPC, authorization, idempotency, privilege and lifecycle gate.

Per the controlled implementation plan, implementation now **stops before Locations**. The next slice is `0200–0203` only after deliberate continuation from this checkpoint.
