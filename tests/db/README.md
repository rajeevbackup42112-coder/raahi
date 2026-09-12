# Raahi Learning V1.2 — Database Test Scaffold

Database implementation is not complete merely because SQL applies. Every slice must pass its relevant rows from the master QA catalog before the next slice starts.

Primary references:

- `docs/raahi-learning/29-master-test-case-catalog-v1.2.md`
- `docs/raahi-learning/31-staging-load-security-chaos-plan-v1.2.md`
- `docs/raahi-learning/32-canonical-test-personas-fixtures-v1.2.md`
- `docs/raahi-learning/23-final-acceptance-traceability-v1.2.md`

The backend-free model suite in `tests/model/` is design evidence only and never replaces real DB/RLS/security tests.

## Passed real-runtime suites

### Foundation + Identity — PASS

- `010_foundation_identity_runtime_smoke.sql`
- runtime marker: `FOUNDATION_IDENTITY_RUNTIME_TESTS_PASS`
- post-hardening marker: `POST_HARDENING_SECURITY_SMOKE_PASS`

Verified Account/Learner separation, self/manage uniqueness, manager decision authority, no Test impersonation, idempotency, RLS isolation, direct-write denial, privilege escalation denial, lifecycle blockers and audit behavior.

### Locations — PASS

- `020_locations_runtime_smoke.sql`
- `021_locations_post_hardening_smoke.sql`
- runtime marker: `LOCATIONS_RUNTIME_TESTS_PASS`
- post-hardening marker: `LOCATIONS_POST_HARDENING_SMOKE_PASS`

Verified Location lifecycle, selected-Location independence, Interest eligibility/history/uniqueness, Local Manager exact scope, aggregate-only readiness, wrong-Location denial, retired visibility, account-closure responsibility, direct-write denial, idempotency and RLS policy behavior.

Security Advisor after Locations: **0 findings**. Only expected empty-database unused-index INFO notices remain in the Performance Advisor.

## Current stop gate — Learner share codes

The next slice must cover at minimum:

- no plaintext token storage;
- cryptographically strong token generation;
- finite expiry;
- one-time consumption;
- explicit revocation;
- no public Learner enumeration/search;
- only legitimate learner-side authority may create/revoke;
- consume vs revoke race has one terminal outcome;
- replay/retry after success cannot double-consume;
- raw token never enters audit/idempotency metadata/logs.

The later Class invite-by-code atomic consumption test cannot be completed until Classes exist; the share-code slice must still prove its independent lifecycle/security now.

Do not begin Organizations/Discovery until this slice passes.

## Later gates retained

### Classes

- Invitation send race protects last seat;
- Pending Invitation reserves seat at send time;
- duplicate acceptance creates one Membership;
- capacity reduction floor;
- Transfer atomicity and last-seat race;
- `complete_class` atomicity;
- Left/Transferred/Removed preserved on completion;
- copied private Class/file/thread URL denied.

### Activities

- parent-assisted Submission keeps Learner ownership;
- revision retry safe;
- simultaneous resubmits cannot overwrite/duplicate revision order;
- cross-Learner Submission reads denied.

### Tests / assessment

- first valid Attempt locks definition;
- structural edits fail after lock;
- repeated/simultaneous Start returns one Attempt;
- double Submit gives one Submitted Attempt;
- manager cannot take child's Test;
- result visibility and teacher feedback privacy;
- answer-key correction explicit/audited/recalculated.

### Community / trust

- Location posting scope;
- Report does not auto-punish;
- Block preserves evidence/history;
- scoped restrictions do not disable unrelated capability;
- Local Manager private Class/Test/Submission access denied.

### Ads

- exact immutable Revision review;
- stale review cannot approve newer Revision;
- commercial clearance independent from review;
- daily inventory no-oversell under real concurrency;
- deterministic lock order;
- multi-day atomicity;
- exact approved serving Revision;
- viewer state not advertiser-readable;
- protected surfaces never serve Sponsored;
- Ads never affect organic rank/verification.

## Load / chaos progression

Do not run meaningless whole-platform load tests before relevant slices exist. As each high-contention command lands, add its corresponding real concurrency suite. Before launch, run the complete staging tiers/soak/security/chaos program defined in `31-staging-load-security-chaos-plan-v1.2.md`.