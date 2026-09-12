# Raahi Learning V1.2 — Database Test Scaffold

Database implementation is not complete merely because SQL applies. Every slice must pass its relevant rows from the master QA catalog before the next slice starts.

Primary references:

- `docs/raahi-learning/29-master-test-case-catalog-v1.2.md`
- `docs/raahi-learning/31-staging-load-security-chaos-plan-v1.2.md`
- `docs/raahi-learning/32-canonical-test-personas-fixtures-v1.2.md`
- `docs/raahi-learning/23-final-acceptance-traceability-v1.2.md`

The backend-free model suite in `tests/model/` is design evidence only and never replaces these real DB/RLS/security tests.

## Foundation + Identity

Must cover at minimum:

- one active self relationship per Learner;
- one active manager relationship per Learner;
- Account/Learner separation;
- sibling isolation;
- active manager owns formal learning decisions;
- manager cannot take Learner Test through manage authority;
- forged acting-for Learner denied;
- Account capability escalation denied;
- pause/resume semantics;
- closure blocks unresolved manager/teacher/Organization responsibility;
- idempotency same-key/same-request returns one result;
- same key/different fingerprint rejects;
- unauthorized direct reads/writes denied;
- audit/idempotency tables not client-mutable.

A Foundation + Identity failure blocks Locations.

## Locations

- lifecycle `interest_only/preparing/live/paused/retired`;
- Register Interest eligibility;
- duplicate retry safety;
- selected Location never alters active relationships;
- Local Manager wrong-Location denial.

## Learner share codes

- no plaintext storage;
- one-time use;
- expiry/revocation/consumption;
- no enumeration/public Learner search;
- invite consumes code atomically;
- consume vs revoke race produces one terminal result;
- replay after timeout cannot create duplicate Invitation.

## Classes

- Invitation send race protects last seat;
- Pending Invitation reserves seat at send time;
- duplicate acceptance creates one Membership;
- capacity reduction floor;
- Transfer atomicity and last-seat race;
- `complete_class` atomicity;
- Left/Transferred/Removed states preserved on completion;
- copied private Class/file/thread URL denied without current authorization.

## Activities

- parent-assisted Submission keeps Learner ownership;
- revision retry safe;
- simultaneous resubmits cannot overwrite/duplicate revision order;
- another Learner cannot read another Submission.

## Tests

- first valid Attempt locks Test definition;
- structural edits fail after lock;
- repeated/simultaneous Start returns one logical Attempt;
- double Submit produces one Submitted Attempt;
- manager cannot take child's Test;
- result visibility respected;
- teacher feedback private;
- answer-key correction explicit/audited/recalculated.

## Community / trust

- Location posting scope;
- no public downvote type;
- Report does not auto-punish;
- managed Learner report context allowed only to legitimate actor;
- Block preserves Membership/evidence/history;
- scoped restriction does not disable unrelated capability;
- Local Manager private Class/Test/Submission access denied.

## Ads

- exact immutable Revision review;
- stale review never approves newer Revision;
- commercial clearance independent from review;
- daily inventory race cannot oversell;
- deterministic lock ordering;
- multi-day request atomic;
- exact approved serving Revision;
- per-Location placement independence;
- viewer frequency/hide data not advertiser-readable;
- protected surfaces never return commercial Sponsored content;
- Ads never affect organic rank/verification;
- advertiser cannot read named viewer data.

## Privileged direct-read tests

Test direct data access as well as hidden navigation:

- Teacher management scope;
- Organization scope and ended membership;
- Local Manager Location scope;
- Platform safety/verification/Ads/audit capability scope;
- advertiser eligibility/authority;
- private Class/Learner/Attempt/Submission data.

## Load / chaos progression

Do not run meaningless whole-platform load tests before relevant slices exist. As each high-contention command lands, add its corresponding real concurrency suite. Before launch, run the complete staging tiers/soak/security/chaos program defined in `31-staging-load-security-chaos-plan-v1.2.md`.
