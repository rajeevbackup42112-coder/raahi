# Raahi Learning V1.2 — Start Here

This branch contains the canonical Raahi Learning product, inspected UI, consolidated technical contract, QA package and current implementation handover.

**Repository:** `rajeevbackup42112-coder/raahi`  
**Documentation branch:** `raahi-learning-v1-docs`  
**Implementation branch:** `raahi-learning-implementation-v1`  
**Canonical folder:** [`docs/raahi-learning/`](docs/raahi-learning/)

## Read first

1. [`docs/raahi-learning/99-handover.md`](docs/raahi-learning/99-handover.md)
2. [`docs/raahi-learning/34-foundation-identity-implementation-result-v1.2.md`](docs/raahi-learning/34-foundation-identity-implementation-result-v1.2.md)
3. [`docs/raahi-learning/19-consolidated-database-blueprint-v1.2.md`](docs/raahi-learning/19-consolidated-database-blueprint-v1.2.md)
4. [`docs/raahi-learning/20-consolidated-sql-migration-plan-v1.2.md`](docs/raahi-learning/20-consolidated-sql-migration-plan-v1.2.md)
5. [`docs/raahi-learning/22-implementation-runbook-v1.2.md`](docs/raahi-learning/22-implementation-runbook-v1.2.md)
6. [`docs/raahi-learning/29-master-test-case-catalog-v1.2.md`](docs/raahi-learning/29-master-test-case-catalog-v1.2.md)

For full product behavior and QA history, see `docs/raahi-learning/README.md`.

## Current Supabase state

Target development project:

- `rajeev.backup3.2112@gmail.com's Project`
- ref: `iiwwmqokaeflaenhlyip`
- region: `ap-south-1`
- PostgreSQL 17.6

The environment was inspected read-only first and found clean.

**Foundation + Identity has now been implemented and runtime-tested PASS.**

Applied slice includes:

- extensions/private helper schema + explicit Data API privilege defaults;
- Accounts;
- Learners;
- Account↔Learner Access;
- Account Capabilities;
- Audit Log;
- Idempotency Keys;
- Identity authorization helpers including `can_make_learning_decision`;
- canonical Identity RPCs;
- Account pause/resume/guarded closure behavior;
- RLS and least-privilege hardening;
- forward fixes from advisor/ACL review.

Real database runtime checks passed for idempotency, manager-vs-self authority, direct-write denial, anonymous denial, privilege escalation, uniqueness, sibling isolation, lifecycle retry behavior and closure blockers.

Security Advisor after hardening: **0 findings**.

No synthetic test data remains; the tests ran inside rolled-back transactions.

## Current gate

> **STOP BEFORE LOCATIONS.**

The next eligible slice is only:

- `0200_locations_tables.sql`
- `0201_account_location_preferences.sql`
- `0202_locations_staff_rls_rpcs.sql`
- `0203_location_interests.sql`

Do not proceed beyond Locations until that slice passes its own migration/RLS/RPC/idempotency/scope tests.

## Clickable UI artifact

`Raahi_Learning_Clickable_UI_v1.1.zip`  
Library: `/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`  
SHA-256: `2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

The inspected UI remains the behavior contract together with the frozen written rules.

The repository `main` branch contains older Raahi ride work and must not be assumed to implement Raahi Learning.