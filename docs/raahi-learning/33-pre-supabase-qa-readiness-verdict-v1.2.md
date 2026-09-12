# Raahi Learning V1.2 — Pre-Supabase QA Readiness Verdict

Status: **PASS FOR EVERYTHING THAT CAN BE HONESTLY PROVEN WITHOUT A REAL DATABASE.**

## Verdict

The pre-Supabase QA design gate is complete.

### Passed now

- inspected clickable UI regression suite;
- route/mobile/desktop checks;
- privileged deep-link presentation checks;
- core interaction/business-rule UI checks;
- semantic/accessibility sanity checks;
- backend-free state-machine/property tests;
- logical Class-capacity contention model;
- logical Ads-inventory contention model;
- Test manager-vs-self authorization model;
- share-code lifecycle model;
- Account closure blocker model;
- Location preference independence model;
- Report/Block separation model;
- Class completion preservation model;
- public Learning Request privacy projection model;
- exact Campaign Revision Ads serving model;
- protected Sponsored-surface model.

Expanded model run result:

> **5,349,992 cases/operations; 0 invariant failures.**

### Fully specified but deliberately not called PASS yet

The following require actual PostgreSQL/Supabase/staging behavior and therefore remain mandatory runtime gates:

- RLS and GRANT enforcement;
- RPC execution privileges;
- real Class/Ads concurrency locking;
- deadlock behavior;
- unique/partial constraint behavior under races;
- idempotency around actual commits/timeouts;
- Storage authorization and signed access;
- Realtime delay/drop behavior;
- Auth/session revocation behavior;
- scheduled expiry/background jobs;
- query plans/index effectiveness;
- connection-pool limits;
- real p50/p95/p99 latency and throughput;
- soak/stress/breakpoint behavior;
- chaos/failure injection around actual transactions.

These are not design gaps. They are environment/runtime properties and are mapped in:

- `29-master-test-case-catalog-v1.2.md`;
- `31-staging-load-security-chaos-plan-v1.2.md`;
- `32-canonical-test-personas-fixtures-v1.2.md`.

## QA coverage principle

Every important production behavior now has at least one of:

1. an already-passed UI/mock test;
2. a planned real database test;
3. a planned security test;
4. a planned load/concurrency test;
5. a planned chaos/recovery test.

High-risk commands have explicit stale-state, retry/idempotency and concurrency coverage.

## Hard launch blockers

Regardless of performance, the system cannot launch if any staging suite shows:

- Class capacity oversell;
- Ads inventory oversell;
- duplicate logical Membership/Test Attempt from retries;
- unauthorized private Learner/Class/Test/Submission access;
- manager Test impersonation;
- public Learner enumeration;
- private Storage URL bypass;
- Local Manager cross-Location/private-data access;
- advertiser named-viewer data access;
- Ads commercial payment bypassing review;
- wrong/unapproved Campaign Revision serving;
- partial Class transfer/completion corruption;
- secret/share-token leakage in logs/audit.

## Engineering targets vs invariants

Latency/throughput targets may be refined with evidence from staging. Business/security invariants may **not** be weakened to make a benchmark pass.

## Final pre-Supabase conclusion

There is no additional mock test category that needs to be invented before the environment boundary.

The next QA work becomes executable only after the first real schema slice exists:

> Foundation + Identity migration → real RLS/RPC/constraint tests → security tests → slice PASS → only then Locations.

Supabase remains untouched at this verdict.