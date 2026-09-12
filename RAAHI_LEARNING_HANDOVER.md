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
5. [`docs/raahi-learning/19-consolidated-database-blueprint-v1.2.md`](docs/raahi-learning/19-consolidated-database-blueprint-v1.2.md)
6. [`docs/raahi-learning/20-consolidated-sql-migration-plan-v1.2.md`](docs/raahi-learning/20-consolidated-sql-migration-plan-v1.2.md)
7. [`docs/raahi-learning/22-implementation-runbook-v1.2.md`](docs/raahi-learning/22-implementation-runbook-v1.2.md)
8. [`docs/raahi-learning/29-master-test-case-catalog-v1.2.md`](docs/raahi-learning/29-master-test-case-catalog-v1.2.md)

For full product behavior and QA history, see `docs/raahi-learning/README.md`.

## Current Supabase state

Target development project:

- ref: `iiwwmqokaeflaenhlyip`
- region: `ap-south-1`
- PostgreSQL 17.6

The environment was inspected read-only before first mutation and found clean.

### Foundation + Identity — PASS

Real runtime markers:

- `FOUNDATION_IDENTITY_RUNTIME_TESTS_PASS`
- `POST_HARDENING_SECURITY_SMOKE_PASS`

### Locations — PASS

Implemented Location lifecycle, selected Location preference, scoped Local Manager authority, Location Interests, aggregate launch-readiness counts, closure responsibility and RLS/least-privilege controls.

Real runtime markers:

- `LOCATIONS_RUNTIME_TESTS_PASS`
- `LOCATIONS_POST_HARDENING_SMOKE_PASS`

Locations applied migrations:

- `0200_locations_tables`
- `0201_account_location_preferences`
- `0202_locations_staff_rls_rpcs`
- `0203_location_interests`
- `0204_locations_rls_policy_consolidation`

Security Advisor after Locations: **0 findings**. Synthetic test data was rolled back; the dev application/Auth data remains empty.

The implementation branch migration subtree is now explicitly **Raahi Learning only**; inherited mobility migrations were removed before Locations execution.

## Current gate

> **STOP BEFORE `0250_learner_share_codes.sql`.**

The next eligible implementation slice is private one-time Learner share codes only. Do not proceed to Organizations/Discovery (`0300+`) until that slice passes its own lifecycle/RLS/security/retry gate.

## Clickable UI artifact

`Raahi_Learning_Clickable_UI_v1.1.zip`  
Library: `/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`  
SHA-256: `2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

The inspected UI plus frozen written rules remains the product behavior contract.

The repository `main` branch contains older Raahi mobility work and must not be assumed to implement Raahi Learning.