# Raahi Learning V1.2 — Start Here

This branch contains the canonical Raahi Learning product, inspected UI, consolidated technical contract, QA package and current implementation handover.

**Repository:** `rajeevbackup42112-coder/raahi`  
**Documentation branch:** `raahi-learning-v1-docs`  
**Implementation branch:** `raahi-learning-implementation-v1`  
**Canonical folder:** [`docs/raahi-learning/`](docs/raahi-learning/)

## Read first

1. [`docs/raahi-learning/99-handover.md`](docs/raahi-learning/99-handover.md)
2. [`docs/raahi-learning/34-foundation-identity-implementation-result-v1.2.md`](docs/raahi-learning/34-foundation-identity-implementation-result-v1.2.md)
3. [`docs/raahi-learning/35-implementation-branch-legacy-migration-isolation.md`](docs/raahi-learning/35-implementation-branch-legacy-migration-isolation.md)
4. [`docs/raahi-learning/36-locations-implementation-result-v1.2.md`](docs/raahi-learning/36-locations-implementation-result-v1.2.md)
5. [`docs/raahi-learning/37-learner-share-codes-implementation-result-v1.2.md`](docs/raahi-learning/37-learner-share-codes-implementation-result-v1.2.md)
6. [`docs/raahi-learning/19-consolidated-database-blueprint-v1.2.md`](docs/raahi-learning/19-consolidated-database-blueprint-v1.2.md)
7. [`docs/raahi-learning/20-consolidated-sql-migration-plan-v1.2.md`](docs/raahi-learning/20-consolidated-sql-migration-plan-v1.2.md)
8. [`docs/raahi-learning/22-implementation-runbook-v1.2.md`](docs/raahi-learning/22-implementation-runbook-v1.2.md)
9. [`docs/raahi-learning/29-master-test-case-catalog-v1.2.md`](docs/raahi-learning/29-master-test-case-catalog-v1.2.md)

For full product behavior and QA history, see `docs/raahi-learning/README.md`.

## Current Supabase state

Target development project:

- ref: `iiwwmqokaeflaenhlyip`
- region: `ap-south-1`
- PostgreSQL 17.6

The environment was inspected read-only before first mutation and found clean.

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

- `0250_learner_share_codes`

Implemented private, one-time Learner identification without a public Learner directory:

- 192-bit database-generated bearer token;
- plaintext returned only on the first successful create response;
- SHA-256 hash-only persistence;
- 24-hour V1 TTL through private policy helper;
- one active code per Learner;
- replacement revokes predecessor;
- formal learner-side authority required for creation;
- paused current formal authority may revoke an existing code;
- no direct client table access;
- no public resolve/search/browse Learner endpoint;
- private exact-token resolver reserved for later atomic Class invitation + consumption;
- token excluded from Audit and Idempotency persisted results.

Runtime markers:

- `SHARE_CODE_BASIC_PASS`
- `SHARE_CODE_PERMISSION_PASS`
- `SHARE_CODE_STATE_PASS`
- `SHARE_CODE_TERMINAL_PASS`

Security Advisor after Share Codes: **0 findings**. Performance Advisor has only expected unused-index INFO notices on this empty dev database.

Synthetic test data was rolled back; the dev Auth/application tables remain empty.

The implementation branch migration subtree is explicitly **Raahi Learning only**; inherited mobility migrations were removed before Locations execution.

## Current gate

> **STOP BEFORE ORGANIZATIONS / TEACHER DISCOVERY (`0300–0302`).**

Next eligible slice:

- `0300_organizations_discovery_tables.sql`
- `0301_organizations_discovery_constraints.sql`
- `0302_organizations_discovery_rls_rpcs.sql`

Do not proceed to Restrictions (`0350+`) until Organization ownership/capability, Teaching Option ownership, public discovery, Save privacy, idempotency, RLS and direct-access security tests pass.

The share-code consume/invite race is intentionally still deferred until Classes (`0502`) exists; no fake Class objects were introduced early.

## Clickable UI artifact

`Raahi_Learning_Clickable_UI_v1.1.zip`  
Library: `/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`  
SHA-256: `2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

The inspected UI plus frozen written rules remains the product behavior contract.

The repository `main` branch contains older Raahi mobility work and must not be assumed to implement Raahi Learning.