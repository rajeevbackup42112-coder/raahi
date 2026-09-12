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

## Target dev environment

Supabase project ref: `iiwwmqokaeflaenhlyip`  
Region: `ap-south-1`

Read-only environment inspection was completed before the first mutation.

## Passed slices

### Foundation + Identity — PASS

Applied:

- `0001_extensions_helpers.sql`
- `0002_common_updated_at.sql`
- `0100_identity_tables.sql`
- `0101_identity_constraints_indexes.sql`
- `0102_command_infrastructure.sql`
- `0103_identity_rls_helpers.sql`
- `0104_identity_rpcs.sql`
- `0105_identity_hardening_followup.sql`
- `0106_private_function_privileges.sql`

Runtime markers:

- `FOUNDATION_IDENTITY_RUNTIME_TESTS_PASS`
- `POST_HARDENING_SECURITY_SMOKE_PASS`

### Locations — PASS

Applied:

- `0200_locations_tables.sql`
- `0201_account_location_preferences.sql`
- `0202_locations_staff_rls_rpcs.sql`
- `0203_location_interests.sql`
- `0204_locations_rls_policy_consolidation.sql`

Runtime markers:

- `LOCATIONS_RUNTIME_TESTS_PASS`
- `LOCATIONS_POST_HARDENING_SMOKE_PASS`

Security Advisor after Locations: **0 findings**.

All synthetic test data was rolled back; the dev database currently has no application/Auth fixture rows.

## Migration product boundary

`supabase/migrations/` on this branch is now **Raahi Learning only**. Historical mobility migrations inherited from old Raahi work were removed from this execution subtree before Locations was applied, preventing accidental replay into the Learning project.

## Current stop gate

**STOP BEFORE LEARNER SHARE CODES.**

The next eligible slice, only after deliberate continuation, is:

- `0250_learner_share_codes.sql`

That slice must implement and test private, expiring, hash-only, one-time Learner share codes. Do not proceed into Organizations/Discovery (`0300+`) until share codes pass their own gate.

## Implementation rules remain binding

- versioned migrations only;
- forward-fix anything already applied to shared/dev;
- one slice at a time;
- consequential writes through canonical commands;
- RLS + least privilege on exposed tables/functions;
- run runtime/security/advisor checks after each slice;
- stop immediately on invariant/security failure;
- never treat old ride code as Raahi Learning behavior.