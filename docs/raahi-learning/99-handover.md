# Raahi Learning V1.2 — Handover / Current State

**Read this file first in a new conversation.**

Repository: `rajeevbackup42112-coder/raahi`  
Documentation branch: `raahi-learning-v1-docs`  
Implementation branch: `raahi-learning-implementation-v1`  
Canonical folder: `docs/raahi-learning/`

> Raahi Learning is isolated from the older Raahi mobility implementation. Do not infer Learning behavior from old ride code or historical mobility migrations.

## Current phase

Product, UI, domain, architecture, physical design, migration planning, QA strategy and the real clickable UI gate are complete.

Pre-database evidence remains:

- 77 inspected canonical UI routes/pages;
- 154 desktop/mobile checks — 0 issues;
- 32 privileged deep-link checks — 0 unguarded;
- 26 interaction/business-rule checks — 0 failures;
- 15 semantic/accessibility samples — 0 issues;
- backend-free deterministic model suite: **5,349,992 cases/operations, 0 invariant failures**.

Controlled Supabase implementation is active.

## Target Supabase dev project

- ref: `iiwwmqokaeflaenhlyip`
- region: `ap-south-1`
- PostgreSQL: 17.6

The project was inspected read-only before the first mutation and was clean: no Raahi app schema/migrations/users/buckets/Edge Functions or mobility objects.

## Passed implementation slices

### 1. Foundation + Identity — PASS

Applied `0001–0106`.

Runtime markers:

- `FOUNDATION_IDENTITY_RUNTIME_TESTS_PASS`
- `POST_HARDENING_SECURITY_SMOKE_PASS`

See `34-foundation-identity-implementation-result-v1.2.md`.

### 2. Locations — PASS

Applied `0200–0204`.

Runtime markers:

- `LOCATIONS_RUNTIME_TESTS_PASS`
- `LOCATIONS_POST_HARDENING_SMOKE_PASS`

Before Locations, historical mobility migrations inherited on the implementation branch were removed from the Learning migration execution subtree. They had never been applied to the Learning Supabase project. See `35-implementation-branch-legacy-migration-isolation.md` and `36-locations-implementation-result-v1.2.md`.

### 3. Learner Share Codes — PASS

Applied:

- `0250_learner_share_codes`

Implemented:

- private 192-bit database-generated bearer token;
- SHA-256 hash-only persistence;
- plaintext returned on the first successful create response only;
- same-key create replay returns the same logical resource but never replays plaintext;
- 24-hour V1 TTL through a private policy helper;
- one active code per Learner in V1;
- replacement revokes predecessor;
- active `can_make_learning_decision` authority required to create;
- paused current formal learner-side authority may revoke an already-issued code;
- expired/revoked/consumed tokens never resolve through the private helper;
- no public resolve/search/browse Learner endpoint;
- exact-token private resolver reserved for the later atomic Class invite-by-code transaction;
- raw token excluded from Audit metadata and Idempotency stored results;
- direct authenticated table access denied;
- private helper ACLs explicitly hardened.

Real runtime markers:

- `SHARE_CODE_BASIC_PASS`
- `SHARE_CODE_PERMISSION_PASS`
- `SHARE_CODE_STATE_PASS`
- `SHARE_CODE_TERMINAL_PASS`

Security Advisor after Share Codes: **0 findings**.

Performance Advisor: only expected `unused_index` INFO notices on the empty dev database.

All synthetic tests used rollback transactions. Current Auth/application fixture counts remain zero, including Learner Share Codes, Audit and Idempotency rows.

See `37-learner-share-codes-implementation-result-v1.2.md` and implementation-branch `tests/db/025_learner_share_codes_runtime_smoke.sql`.

## Share-code tests deliberately deferred to Classes/staging

Because the public Class invite-by-code command does not exist until `0502`, these are not falsely marked complete yet:

- atomic Invitation creation + share-code consumption;
- second consume rejection through the real invite path;
- real consume-vs-revoke concurrency;
- timeout-after-success retry with exactly one Invitation;
- external endpoint rate limiting / abuse testing.

The private resolver and state model needed for those tests are now implemented and runtime-tested.

## Current stop gate

> **STOP BEFORE ORGANIZATIONS / TEACHER DISCOVERY (`0300–0302`).**

Next eligible slice only:

- `0300_organizations_discovery_tables.sql`
- `0301_organizations_discovery_constraints.sql`
- `0302_organizations_discovery_rls_rpcs.sql`

That slice must prove:

- Organization/member/capability scope;
- one Teaching Option owner only (Teacher XOR Organization);
- Organization-owned objects survive employee access changes;
- Teacher profile and Teaching Option lifecycle/availability rules;
- public discovery only in eligible live Locations;
- safe public projections with no private contact/home data;
- Save/Unsave is private and grants no contact permission;
- direct privileged reads/writes and forged Organization/Teacher scope are denied;
- idempotency/audit for consequential writes.

Do not begin Restrictions (`0350+`) until this slice passes.

## Canonical implementation sources

Read at minimum:

- `00-product-ui-freeze-v1.md`
- `01-domain-model-v1.md`
- `02-architecture-blueprint-v1.md`
- `04-command-permission-matrix-v1.md`
- `05-acceptance-regression-v1.md`
- `06-raahi-ads-v1.md`
- `18-ui-page-inventory-v1.1.md`
- `19-consolidated-database-blueprint-v1.2.md`
- `20-consolidated-sql-migration-plan-v1.2.md`
- `22-implementation-runbook-v1.2.md`
- `23-final-acceptance-traceability-v1.2.md`
- `24-supabase-execution-checklist-v1.2.md`
- `29-master-test-case-catalog-v1.2.md`
- `31-staging-load-security-chaos-plan-v1.2.md`
- `34-foundation-identity-implementation-result-v1.2.md`
- `35-implementation-branch-legacy-migration-isolation.md`
- `36-locations-implementation-result-v1.2.md`
- `37-learner-share-codes-implementation-result-v1.2.md`

Historical `03/08/09/10/11/13/14/15/16/17` files remain decision history; consolidated V1.2 sources win where wording differs.

## UI artifact

`Raahi_Learning_Clickable_UI_v1.1.zip`  
Library: `/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`  
SHA-256: `2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

## Non-negotiable architecture/product rules

- Account ≠ Learner; Learner owns learning history.
- Parent/Guardian acts for Learner through explicit authority, never impersonation.
- Active manager owns formal learner-side marketplace decisions; manager authority does not grant Test-taking.
- No public Learner directory.
- UI never directly mutates core operational state.
- Consequential writes use canonical commands and current authoritative server state.
- Consequential commands are idempotent.
- Navigation/workspace never grants authorization.
- Valid Pending Class Invitation reserves a seat at send time.
- Class capacity and Ads inventory are transactionally protected.
- Private one-time share code replaces public Learner lookup for offline-origin invitation.
- Test definition locks after first valid Attempt.
- Realtime invalidates/refetches; it is not source of truth.
- Organic discovery and Sponsored serving remain separate.
- Significant safety/admin/commercial actions are audited.
- Do not casually restore Enrollment, Batch, Adult/Minor split, turning-18 lifecycle, Attendance, generic Progress %, public ratings/reviews, global Community, unrestricted DM or platform tuition payments.

## Recommended new-chat prompt

> “Continue Raahi Learning V1.2 from `rajeevbackup42112-coder/raahi`. Read `RAAHI_LEARNING_HANDOVER.md`, `docs/raahi-learning/99-handover.md`, and implementation results `34–37`. Supabase project `iiwwmqokaeflaenhlyip` has Foundation + Identity, Locations and Learner Share Codes implemented and runtime-tested PASS; Security Advisor is clean. The current stop gate is before Organizations / Teacher Discovery `0300–0302`. If I authorize continuation, implement and test only that slice, then stop before Restrictions.”