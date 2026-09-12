# Raahi Learning V1 — Implementation Approval Record

Status: **APPROVED FOR CONTROLLED IMPLEMENTATION AFTER UI↔DB RECONCILIATION. Supabase has not yet been touched.**

This approval is issued only after completing the mandatory two-way UI Prototype ↔ Database Design reconciliation documented in:

- `13-ui-db-reconciliation-v1.md`
- `14-ui-db-implementation-delta-v1.md`

The reconciliation found real design gaps, corrected them, and confirmed that the simplified V1 model still works without reintroducing removed complexity.

## Canonical implementation contract

Implementation must read the following together:

- `00-product-ui-freeze-v1.md`
- `01-domain-model-v1.md`
- `02-architecture-blueprint-v1.md`
- `03-database-blueprint-v1.1.md`
- `04-command-permission-matrix-v1.md`
- `05-acceptance-regression-v1.md`
- `06-raahi-ads-v1.md`
- `08-database-blueprint-review-v1.md`
- `09-sql-readiness-review-v1.md`
- `10-sql-migration-plan-v1.1.md`
- `11-sql-migration-plan-review-v1.md`
- `13-ui-db-reconciliation-v1.md`
- `14-ui-db-implementation-delta-v1.md`

Where `14-ui-db-implementation-delta-v1.md` conflicts with the earlier schema/migration wording, the reconciliation delta wins.

## Reconciliation corrections now approved

The implementation contract now explicitly includes:

1. `accounts.auth_user_id` closure-safe nullability and no early Location FK on Accounts.
2. selected Location stored in `account_location_preferences`.
3. persisted `location_interests` for unavailable/preparing Location “Register Interest”.
4. manager-owned formal learner decisions when an active `manage` relationship exists; otherwise self-access may decide for self.
5. manager authority does not grant Test-taking impersonation.
6. Organization public logo/avatar support.
7. deterministic historical Class access by Membership end state rather than another configurable policy subsystem.
8. no independent Class Learner Thread lifecycle; permissions derive from Membership/authority/restrictions.
9. lightweight Sessions with Past derived from time rather than Attendance/completion machinery.
10. reusable `activity_material_links` for Activity resources/attachments.
11. optional moderation-private `reports.context_learner_id`.
12. canonical `complete_class` transaction so a Class cannot be marked Past while leaving unintended Active Memberships.
13. surface-based educational Sponsored serving rather than Adult/Minor/turning-18 Ads logic.
14. existing offline learners do not require fake Enquiry/Trial/Enrollment history; normal Class Invitation begins only after the Learner exists in Raahi.

## Core model still approved

The reconciliation did **not** justify bringing back:

- Enrollment;
- Batch entity;
- Adult Learner / Minor Learner entities;
- turning-18 migration;
- Trial relationship object;
- Attendance;
- generic Progress %;
- public ratings/reviews;
- public Learner directory;
- global Community;
- advertiser viewer/lead directory;
- platform tuition payments.

## First implementation slice

Only the following may be implemented first:

### Foundation + Identity

- PostgreSQL extensions/common helpers;
- Accounts;
- Learners;
- Account↔Learner Access;
- Account Capabilities;
- Audit Log;
- Idempotency Keys;
- Identity authorization helpers;
- `can_make_learning_decision(learner_id)`;
- Identity canonical RPCs;
- RLS and privilege hardening;
- tests for learner ownership, one active self/manager, decision authority, manager-vs-self separation, idempotency and privilege escalation.

Do **not** create Locations until this first slice passes.

## Execution rules

Actual Supabase implementation must:

- use versioned SQL migrations committed to source control;
- proceed slice by slice rather than as a one-shot schema push;
- run invariant/permission/concurrency tests after each slice;
- stop on contradiction or failed test;
- use forward-fix migrations after anything has been applied to a shared environment;
- never treat generated UI images as a source of truth when they conflict with frozen written behavior.

## Current external state

At the time of this approval:

> **No Raahi Learning migration has been executed against Supabase.**

The next operational action, once explicitly authorized, is to inspect the target Supabase project/environment and implement only the Foundation + Identity slice.