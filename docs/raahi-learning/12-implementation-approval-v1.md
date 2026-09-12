# Raahi Learning V1 — Implementation Approval Record

Status: **TECHNICAL PLAN APPROVED FOR IMPLEMENTATION. Supabase has not yet been touched.**

This record documents the final cross-document review of:

- `00-product-ui-freeze-v1.md`
- `01-domain-model-v1.md`
- `02-architecture-blueprint-v1.md`
- `03-database-blueprint-v1.1.md`
- `04-command-permission-matrix-v1.md`
- `05-acceptance-regression-v1.md`
- `06-raahi-ads-v1.md`
- `08-database-blueprint-review-v1.md`
- `09-sql-readiness-review-v1.md`
- `11-sql-migration-plan-review-v1.md`
- `10-sql-migration-plan-v1.1.md`

## Approval conclusion

The corrected SQL Migration Plan v1.1 preserves the frozen V1 product behaviour and does not reintroduce intentionally removed complexity.

The following implementation invariants are sufficiently specified to begin controlled migrations:

1. Account and Learner remain separate identities.
2. Parent/Guardian acts for Learner through explicit access relationship.
3. No permanent mutually exclusive Account role is required.
4. Class Invitation is separate from Membership and Pending V1 invitations reserve finite capacity until expiry/resolution.
5. Enrollment and Batch remain absent.
6. Class capacity uses one authoritative locked Class-row serialization point.
7. Private Class communication works for direct/offline learners without fabricated Enquiry history.
8. Test definition locks once valid Attempts begin; answer-key correction has one explicit audited path.
9. Scoped safety restrictions do not collapse unrelated capabilities.
10. Ads inventory uses non-overlapping daily capacity buckets with deterministic multi-row locking.
11. Ad serving is pinned to an exact approved Campaign Revision.
12. Commercial Clearance cannot override review and review cannot override commercial/inventory eligibility.
13. Organic discovery and Sponsored serving remain separate.
14. Per-user Ads frequency/hide data remains private from advertisers.
15. Consequential commands are RPC/command-owned, idempotent where required, and re-check current authorization/state.
16. Private files require current business authorization; copied paths/URLs are not access grants.
17. Audit and Idempotency infrastructure exists before early consequential RPCs.
18. Migration dependencies are ordered so no module requires a future table prematurely.

## Specific sequencing decisions approved

- selected Location preference is created after Locations, not as an early Account FK;
- general Organization-capable Restrictions are created after Organizations;
- Sponsored Enquiry attribution is added only when Ads Campaigns exist;
- Audit/Idempotency are part of early command infrastructure;
- notifications remain derived and can be implemented later;
- migrations proceed in small tested slices, not a single schema push.

## First approved implementation slice

Only the following should be implemented first:

### Foundation + Identity

- PostgreSQL extensions/common helpers;
- Accounts;
- Learners;
- Account↔Learner Access;
- Account Capabilities;
- required constraints/partial indexes;
- Audit Log;
- Idempotency Keys;
- Identity authorization helpers;
- Identity canonical RPCs;
- RLS and privilege-hardening for this slice;
- automated/SQL tests for learner ownership, one active self/manager relationship, idempotency and privilege escalation.

Do **not** implement Locations or later modules until this first slice passes its tests.

## Execution rule

This document approves the **technical plan**, not an unreviewed one-shot deployment.

Actual Supabase changes must:

- be made through versioned SQL migrations;
- be committed to source control;
- be executed slice by slice;
- be tested immediately after each slice;
- stop on contradiction or failed invariant;
- use forward-fix migrations once a migration has been applied to a shared environment.

## Current external state

At the time of this approval record:

> **No Raahi Learning migration has been executed against Supabase.**

The next operational action, once the user authorizes Supabase execution, is to inspect the target Supabase project/environment and implement only the Foundation + Identity slice.