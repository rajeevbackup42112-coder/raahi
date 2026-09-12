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

Controlled Supabase implementation has now begun.

## Target Supabase dev project

- ref: `iiwwmqokaeflaenhlyip`
- region: `ap-south-1`
- PostgreSQL: 17.6

The project was inspected read-only before the first mutation and was clean: no Raahi app schema/migrations/users/buckets/Edge Functions or mobility objects.

## Passed implementation slices

### 1. Foundation + Identity — PASS

Applied:

- `0001_extensions_helpers`
- `0002_common_updated_at`
- `0100_identity_tables`
- `0101_identity_constraints_indexes`
- `0102_command_infrastructure`
- `0103_identity_rls_helpers`
- `0104_identity_rpcs`
- `0105_identity_hardening_followup`
- `0106_private_function_privileges`

Real runtime markers:

- `FOUNDATION_IDENTITY_RUNTIME_TESTS_PASS`
- `POST_HARDENING_SECURITY_SMOKE_PASS`

See `34-foundation-identity-implementation-result-v1.2.md`.

### 2. Locations — PASS

Before Locations, an implementation-branch safety problem was found: historical mobility migration files were still present in the inherited `supabase/migrations/` directory. They had never reached the Learning database, but could have been replayed by future CLI operations. The subtree was replaced with a **Raahi Learning-only** migration chain before Locations execution. See `35-implementation-branch-legacy-migration-isolation.md`.

Applied:

- `0200_locations_tables`
- `0201_account_location_preferences`
- `0202_locations_staff_rls_rpcs`
- `0203_location_interests`
- `0204_locations_rls_policy_consolidation` — forward performance/RLS cleanup

Implemented:

- Location lifecycle `interest_only → preparing → live ↔ paused → retired`;
- selected Location preference independent of established relationships/history;
- explicit Location-scoped Local Manager assignments;
- Local Manager responsibility included in Account-closure blockers;
- authenticated `learn|teach` Location Interest with active uniqueness/history;
- aggregate Local Manager launch-readiness counts without named interest-row access;
- retired Location visibility restrictions;
- canonical Location/Interest commands with idempotency/audit;
- RLS and least-privilege grants.

Real runtime markers:

- `LOCATIONS_RUNTIME_TESTS_PASS`
- `LOCATIONS_POST_HARDENING_SMOKE_PASS`

Verified real DB behavior includes lifecycle rules, valid/invalid transitions, selected-Location independence, retired-selection rejection, Interest eligibility/retry/history, learn+teach coexistence, direct-write denial, exact Local Manager scope, wrong-Location denial, aggregate-only readiness, closure blocker, retired visibility and post-policy-consolidation RLS behavior.

Security Advisor after Locations: **0 findings**.

Performance Advisor: only expected `unused_index` INFO notices on the empty dev database. The overlapping permissive-policy warning was fixed with `0204`; no missing-FK-index warning remains.

All synthetic tests used rollback transactions. Current Auth/application fixture counts remain zero.

See `36-locations-implementation-result-v1.2.md`.

## Current stop gate

> **STOP BEFORE LEARNER SHARE CODES (`0250`).**

Do not start Organizations/Discovery (`0300+`) yet.

The next eligible slice, only after deliberate continuation, is:

- `0250_learner_share_codes.sql`

That slice must prove:

- cryptographically strong one-time token;
- hash-only storage, no plaintext persistence/audit;
- finite expiry;
- explicit revocation;
- one-time consumption semantics;
- legitimate learner-side authority only;
- no public Learner search/enumeration;
- retry/replay safety;
- consume-vs-revoke concurrency behavior where possible at this stage.

The later atomic **invite-by-code + consume** path is completed when Classes exist; do not fabricate Class/Invitation objects early.

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

> “Continue Raahi Learning V1.2 from `rajeevbackup42112-coder/raahi`. Read `RAAHI_LEARNING_HANDOVER.md`, `docs/raahi-learning/99-handover.md`, and implementation results `34–36`. Supabase project `iiwwmqokaeflaenhlyip` has Foundation + Identity and Locations implemented and runtime-tested PASS; Security Advisor is clean. The current stop gate is before `0250_learner_share_codes.sql`. If I authorize continuation, implement and test only that share-code slice, then stop before Organizations/Discovery.”