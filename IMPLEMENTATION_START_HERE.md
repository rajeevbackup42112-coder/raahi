# Raahi Learning V1.2 — Implementation Branch

This branch is the controlled Raahi Learning Supabase implementation branch.

## Canonical documentation rule

The authoritative documentation branch is:

`raahi-learning-v1-docs`

Before starting/resuming implementation, read the latest canonical files from that branch, especially:

- `docs/raahi-learning/99-handover.md`
- `docs/raahi-learning/19-consolidated-database-blueprint-v1.2.md`
- `docs/raahi-learning/20-consolidated-sql-migration-plan-v1.2.md`
- `docs/raahi-learning/22-implementation-runbook-v1.2.md`
- `docs/raahi-learning/23-final-acceptance-traceability-v1.2.md`
- `docs/raahi-learning/24-supabase-execution-checklist-v1.2.md`
- `docs/raahi-learning/29-master-test-case-catalog-v1.2.md`
- `docs/raahi-learning/31-staging-load-security-chaos-plan-v1.2.md`
- `docs/raahi-learning/34-foundation-identity-implementation-result-v1.2.md`
- `docs/raahi-learning/35-implementation-branch-legacy-migration-isolation.md`
- `docs/raahi-learning/36-locations-implementation-result-v1.2.md`
- `docs/raahi-learning/37-learner-share-codes-implementation-result-v1.2.md`

## Target dev environment

Supabase project ref: `iiwwmqokaeflaenhlyip`  
Region: `ap-south-1`

Read-only environment inspection was completed before the first mutation.

## Passed slices

### Foundation + Identity — PASS

Applied `0001–0106`.

Runtime markers:

- `FOUNDATION_IDENTITY_RUNTIME_TESTS_PASS`
- `POST_HARDENING_SECURITY_SMOKE_PASS`

### Locations — PASS

Applied `0200–0204`.

Runtime markers:

- `LOCATIONS_RUNTIME_TESTS_PASS`
- `LOCATIONS_POST_HARDENING_SMOKE_PASS`

### Learner Share Codes — PASS

Applied:

- `0250_learner_share_codes.sql`

Executed markers:

- `SHARE_CODE_BASIC_PASS`
- `SHARE_CODE_PERMISSION_PASS`
- `SHARE_CODE_STATE_PASS`
- `SHARE_CODE_TERMINAL_PASS`

Implemented behavior:

- private 192-bit bearer token returned only on first successful create response;
- only SHA-256 hash persisted;
- one active share code per Learner in V1;
- 24-hour TTL via private policy helper;
- replacement revokes predecessor;
- active manager/formal learner-side authority controls creation;
- paused current formal authority may revoke but cannot create;
- expired/revoked/consumed token does not resolve;
- no direct client table access;
- no public resolve/search/browse Learner API;
- private exact-token resolver reserved for future `send_class_invitation_with_share_code` transaction;
- secret omitted from Audit and Idempotency persisted results;
- same-key create retry returns same logical resource but never replays plaintext secret.

Security Advisor after Share Codes: **0 findings**. Performance Advisor has only expected empty-database unused-index INFO notices.

All synthetic test data was rolled back; the dev database currently has no application/Auth fixture rows.

## Migration product boundary

`supabase/migrations/` on this branch is **Raahi Learning only**. Historical mobility migrations inherited from old Raahi work were removed from this execution subtree before Locations was applied, preventing accidental replay into the Learning project.

## Current stop gate

**STOP BEFORE ORGANIZATIONS / TEACHER DISCOVERY.**

The next eligible slice, only after deliberate continuation, is:

- `0300_organizations_discovery_tables.sql`
- `0301_organizations_discovery_constraints.sql`
- `0302_organizations_discovery_rls_rpcs.sql`

That slice must prove ownership XOR rules, Organization member/capability scope, durable Organization ownership, teacher profile/Teaching Option behavior, live-Location discovery gating, private Saves, and secure public projections. Do not proceed into Restrictions (`0350+`) until this slice passes.

The later invite-by-share-code consumption path is intentionally deferred until Classes (`0502`) exists; real consume-vs-revoke concurrency, timeout-after-invite retry and endpoint rate limiting remain future tests rather than being falsely marked complete now.

## Implementation rules remain binding

- versioned migrations only;
- forward-fix anything already applied to shared/dev;
- one slice at a time;
- consequential writes through canonical commands;
- RLS + least privilege on exposed tables/functions;
- run runtime/security/advisor checks after each slice;
- stop immediately on invariant/security failure;
- never treat old ride code as Raahi Learning behavior.