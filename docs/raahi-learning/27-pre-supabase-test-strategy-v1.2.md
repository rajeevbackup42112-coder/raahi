# Raahi Learning V1.2 — Comprehensive Test Strategy

Status: **PRE-SUPABASE TEST DESIGN.**

Purpose: prove as much as possible before touching the target Supabase environment, while clearly separating what can be validated logically now from what requires a real PostgreSQL/Supabase runtime later.

## Test layers

### A. Product/business scenario tests
BDD/Given-When-Then tests for learner, parent, teacher, institute, Local Manager, Platform Admin and Ads flows.

Focus: allowed action, forbidden action, resulting state, stale state, double tap/retry, historical access and safety behavior.

### B. State-machine tests
For every stateful object, verify allowed and forbidden transitions, terminal behavior and reopening rules.

Coverage includes: Account lifecycle, Location lifecycle, Learning Request, Enquiry, Class, Class Invitation, Membership, Activity, Submission, Test, Test Attempt, Report, Restriction, Campaign Revision/Review, Commercial Clearance, Reservation and Placement.

### C. Authorization/negative-permission tests
Test actor + acting-for + target + relationship/capability/scope, not just navigation visibility.

Examples:
- manager may accept Rahul's Class Invitation but may not take Rahul's Test;
- unrelated Account cannot access Rahul's Class/Attempt/Submission;
- Local Manager cannot casually read private Class data;
- Platform capability must be explicit;
- Organization member loses access when membership/capability ends;
- direct privileged URL cannot bypass authorization.

### D. Concurrency/race tests
High-risk operations must be attacked with many logically simultaneous requests.

Required races:
- last Class seat / multiple invitation sends;
- duplicate Invitation acceptance;
- learner transfer into nearly-full destination Class;
- Activity submission retries/revisions;
- first Test Attempt start / definition lock;
- Test submit double-click;
- Learner share-code consume vs revoke vs retry;
- last Ads inventory unit across many Campaigns;
- Ad review of stale revision;
- Account closure while responsibility state changes.

### E. Idempotency/retry tests
Repeat the same consequential command with the same idempotency key and prove one logical outcome.

Mandatory examples:
- send Class Invitation;
- accept Invitation;
- transfer Learner;
- submit Activity;
- start Test;
- submit Test;
- create/consume Learner share code where appropriate;
- reserve/confirm/release Ads inventory;
- Commercial Clearance confirmation;
- Account lifecycle commands.

### F. Stale-UI / optimistic-state tests
Simulate screen loaded at T1, state changed at T2, user acts at T3.

The authoritative server state must win. UI must not permanently show Joined, Submitted, Approved or Reserved before the command succeeds.

### G. Model-based/property tests
Generate thousands of random command sequences and assert invariants always remain true.

Core invariants:
- Active Memberships + valid Pending Invitations never exceed Class capacity;
- no Learner has duplicate Active Membership in one Class;
- one valid Pending Invitation per Class/Learner;
- one logical Test Attempt per Learner/Test in V1;
- Held + Confirmed Ad reservation units never exceed daily inventory capacity;
- share code cannot be consumed twice;
- Location switch never destroys/hides established relationships;
- Block does not delete Membership/Report/history;
- Report creation alone does not punish target;
- Class completion preserves Left/Transferred/Removed states;
- Account closure cannot strand sole responsibilities.

### H. Logical load/contention tests (pre-Supabase)
Model large request bursts to test invariant behavior under contention. This validates business logic, not database latency.

Examples:
- 100,000 invitation attempts for a 50-seat Class -> exactly 50 reservations maximum;
- 100,000 Ads reservation attempts for capacity 100 -> exactly 100 units maximum;
- repeated start/submit retries -> one logical Test Attempt/result;
- high-volume Location-interest registrations -> uniqueness preserved conceptually.

### I. Real database load/performance tests (post-staging only)
These cannot be honestly passed before a real PostgreSQL/Supabase runtime exists.

Measure later:
- p50/p95/p99 RPC latency;
- lock wait/deadlock behavior;
- query-plan/index quality;
- RLS overhead;
- connection-pool behavior;
- Realtime fan-out cost;
- storage signed-access behavior;
- background expiry jobs;
- sustained throughput and recovery after spikes.

### J. Security/abuse tests
- IDOR/direct-object access attempts;
- role/capability escalation;
- forged acting-for Learner;
- copied private storage path;
- public Learner enumeration attempts;
- share-code brute-force/reuse/replay;
- stale privileged session after capability revoke;
- advertiser access to named viewer data;
- paid path bypassing Ads review;
- Local Manager conflict-of-interest case;
- report spam / block abuse;
- unsafe raw table writes denied.

### K. Privacy/data-minimization tests
- child/private Learner identity never appears in public projection;
- moderation evidence remains moderation-private;
- Ads viewer/frequency state never exposed to advertiser;
- Saved actions remain private;
- audit metadata excludes raw secrets/messages/share tokens;
- closure preserves legitimate shared/safety/audit history without exposing it incorrectly.

### L. Failure-injection / chaos tests
Post-staging, deliberately fail steps around transaction boundaries:
- network timeout after commit but before response;
- notification failure after successful command;
- Realtime delay/drop;
- worker crash during expiry sweep;
- object-storage failure during metadata write;
- command retry after client disconnect;
- partial external service outage.

Core state must remain correct even when derived delivery fails.

### M. Migration/data-integrity tests
- fresh install from zero;
- migration order/dependency correctness;
- repeated local reset/rebuild;
- constraints/indexes present;
- grants/RLS default-deny behavior;
- no direct mutation privilege on core tables;
- forward-fix migration behavior after shared deployment.

### N. UI/responsive/accessibility regression
Retain the already-passed clickable-prototype checks and rerun after backend integration:
- mobile/desktop route rendering;
- no privileged deep-link leak;
- CTA/result-state correctness;
- accessible labels/semantics;
- protected surfaces remain ad-free;
- no removed concepts reintroduced.

## Exit gates

### Pre-Supabase gate
Pass when:
1. complete test catalog exists;
2. model/property simulations pass;
3. no unresolved business-rule contradiction remains;
4. every high-risk command has a planned concurrency/idempotency/authorization test;
5. staging-only tests are explicitly identified rather than falsely marked passed.

### Foundation + Identity implementation gate
After Supabase begins, Foundation + Identity must pass migration, RLS, RPC, idempotency, authorization, account-lifecycle and privilege-escalation tests before Locations start.

### Pre-launch gate
All scenario, security, privacy, concurrency, load/performance, failure-injection and regression suites pass against staging-like infrastructure with production-equivalent constraints.

## Principle

A mock/model pass proves that the **business design is internally coherent**. It does not prove PostgreSQL locking, RLS, indexes or real latency. Those are deliberately tested only after the real schema exists in a safe staging environment.