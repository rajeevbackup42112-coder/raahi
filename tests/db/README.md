# Raahi Learning V1.2 — Database Test Scaffold

Database implementation is not complete merely because SQL applies. Every slice must pass its relevant tests before the next slice starts.

## Foundation + Identity

Create tests for:

- one active self relationship per Learner;
- one active manager relationship per Learner;
- Account/Learner separation;
- sibling isolation;
- active manager owns formal learning decisions;
- manager cannot take Learner Test through manage authority;
- Account capability escalation denied;
- pause/resume semantics;
- closure blocks unresolved manager responsibility;
- idempotency same-key/same-request;
- idempotency same-key/different-request rejection;
- unauthorized direct reads/writes denied.

## Locations

- lifecycle `interest_only/preparing/live/paused/retired`;
- Register Interest eligibility;
- duplicate retry safety;
- selected Location does not alter active relationships;
- Local Manager wrong-Location denial.

## Learner share codes

- no plaintext storage;
- one-time use;
- expiry/revocation/consumption;
- no enumeration/public Learner search;
- invite consumes code atomically.

## Classes

- Invitation send race protects last seat;
- Pending Invitation reserves seat at send time;
- duplicate acceptance creates one Membership;
- capacity reduction floor;
- Transfer atomicity;
- complete Class atomicity;
- copied private file/Class URL denied without current authorization.

## Activities

- parent-assisted Submission keeps Learner ownership;
- revision retry safe;
- another Learner cannot read another Submission.

## Tests

- first valid Attempt locks Test definition;
- structural edits fail after lock;
- repeated Start returns same logical Attempt;
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
- Block preserves evidence/history.

## Ads

- exact immutable Revision review;
- commercial clearance independent from review;
- daily inventory race cannot oversell;
- deterministic lock ordering;
- multi-day request atomic;
- exact approved serving Revision;
- per-Location placement independence;
- viewer frequency/hide data not advertiser-readable;
- protected surfaces never return commercial Sponsored content;
- Ads never affect organic rank/verification.

## Privileged deep-link/read tests

Test direct data access as well as hidden navigation:

- Teacher management scope;
- Organization scope;
- Local Manager Location scope;
- Platform safety/verification/Ads/audit capability scope;
- advertiser eligibility/authority;
- private Class/Learner content.

See `docs/raahi-learning/23-final-acceptance-traceability-v1.2.md` for the page→data→command→test mapping.
