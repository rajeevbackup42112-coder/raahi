# Raahi Learning V1.2 — Staging Load, Security & Chaos Validation Plan

Status: **MANDATORY POST-SCHEMA / PRE-LAUNCH PLAN.**

This document defines the tests that cannot honestly be completed before a real PostgreSQL/Supabase environment exists. It is deliberately prepared now so implementation does not redefine success after the fact.

## 1. Traffic tiers

These are engineering test tiers, not business forecasts or contractual capacity promises.

### Tier A — local pilot

Representative of an early single-Location launch:

- 50 concurrent active users;
- 5–10 consequential writes/second bursts;
- 20–50 read requests/second;
- 5,000 Accounts/Learners combined synthetic data;
- 1,000 active Classes;
- 25,000 historical Class posts/messages/artifacts;
- 5,000 current/historical Enquiries;
- 1,000 Campaigns/placements across synthetic history.

### Tier B — multi-Location growth

- 250 concurrent active users;
- 25–50 consequential writes/second bursts;
- 100–250 reads/second;
- 50,000 Accounts/Learners;
- 10,000 Classes;
- 500,000 historical posts/messages/artifacts;
- 50,000 Enquiries;
- substantial Ads inventory/reservation history.

### Tier C — stress / breakpoint

Increase concurrency progressively until latency/error SLO is exceeded. The objective is to learn the safe operating envelope and confirm graceful failure **without any invariant breach**.

Recommended steps: 500 → 1,000 → 2,000 concurrent virtual users where infrastructure limits permit.

## 2. Initial performance targets

These are provisional engineering targets for V1; refine after first staging baseline rather than weakening them silently.

- Public/simple authenticated read p95: **≤ 500 ms** server/API time under Tier A.
- Common consequential RPC p95: **≤ 750 ms** under Tier A, excluding large file upload time.
- p99 common RPC: **≤ 1.5 s** under Tier A.
- Error rate from application/DB capacity under normal Tier A: **< 1%**, excluding intentionally rejected business-rule requests.
- Invariant violation tolerance: **0** at every tier.
- Authorization/privacy violation tolerance: **0**.
- Deadlock causing user-visible failed committed operation: target **0** in canonical contention suites; any observed deadlock requires analysis/lock-order correction or explicit safe retry behavior.

A command returning a correct business rejection such as `CLASS_FULL` is not counted as a system error.

## 3. Load mix

### Read-heavy mix

Simulate:

- Home/Explore public projections;
- Teacher/Organization profiles;
- My Classes;
- Class feed/material/session reads;
- Community feed;
- notifications;
- Ads eligibility/serving projection where permitted.

### Write mix

Simulate realistic ratios across:

- Save/Unsave;
- Learning Request create/update/close;
- Enquiry send/engage/message;
- Class Invitation send/accept/decline;
- Activity submission;
- Test Start/save-answer/Submit;
- Community post/comment/reaction;
- Report/Block;
- Ads campaign/revision/reservation actions.

Do not benchmark only trivial reads and claim the platform is load-tested.

## 4. High-contention suites

### Class last-seat test

Setup:

- Active group Class;
- capacity 50;
- 49 occupied/reserved seats;
- 100–1,000 simultaneous distinct `send_class_invitation` calls.

Pass:

- exactly one additional valid reservation maximum;
- no duplicate Pending invite per Learner/Class;
- no capacity >50 at any observable committed point;
- losing callers receive deterministic business rejection;
- no partial audit/notification artifact implying success.

### Class idempotent send test

100 simultaneous/retried requests with the **same** actor/command/idempotency key.

Pass: one logical Invitation and one stored result.

### Invitation accept test

Simultaneous Accept from two devices/tabs for same Invitation.

Pass: one Membership; both clients converge on same logical outcome.

### Transfer race

Two source learners compete for one remaining seat in destination Class.

Pass: one atomic transfer; other source remains Active.

### Test first-attempt race

Same Learner starts same Test from two tabs while definition is not yet locked.

Pass:

- one logical Attempt;
- definition locks once;
- both clients resolve to same Attempt;
- structural edit cannot sneak between Attempt creation and definition lock.

### Test Submit race

Multiple Submit requests around timeout boundary.

Pass: one submitted Attempt, deterministic final saved answers, no double evaluation trigger.

### Learner share-code race

Simultaneous valid Invite consume + Revoke + duplicate Invite requests.

Pass: exactly one terminal result path; no reusable code and no Invitation from invalidated token.

### Ads multi-day inventory race

Many Campaigns request overlapping multi-day packages where one day has only one unit left.

Pass:

- per-day Held + Confirmed never exceeds capacity;
- requested atomic package does not create hidden partial reservation unless product contract explicitly allows partial selection before confirmation;
- lock order is deterministic across day buckets to minimize deadlocks.

## 5. Soak tests

Run representative Tier A or B load continuously for at least 2–4 hours during staging validation.

Observe:

- DB connection count;
- pool saturation;
- lock waits;
- long-running transactions;
- memory/CPU;
- index bloat or unexpected sequential scans;
- Realtime subscription stability;
- notification/backlog growth;
- scheduled expiry backlog;
- error accumulation.

Pass only if behavior remains stable over time, not merely during a 30-second burst.

## 6. Query-plan / index tests

For each critical projection/command, capture `EXPLAIN (ANALYZE, BUFFERS)` in safe staging data volumes.

Priority paths:

- current Account lookup by `auth_user_id`;
- active Account↔Learner access;
- `can_make_learning_decision`;
- public Teaching Options by Location/availability;
- Open Learning Requests by Location/category/time;
- Pending/Active Enquiries by participant;
- My Classes by Learner;
- Active Memberships/Pending Invitations by Class;
- Class feed/messages by time;
- Test Attempt by Test+Learner;
- Community feed by Location/time;
- unresolved moderation Reports;
- Ads daily inventory/reservations;
- live/waiting placements;
- aggregate Ads metrics.

Any index is justified by actual plans/workload, not added mechanically.

## 7. RLS performance tests

Measure the same protected reads with realistic relationship counts.

Specific concerns:

- learners with parent/self access;
- teacher with many Classes;
- Organization member with capabilities;
- Local Manager with multiple assigned Locations;
- large historical Membership set;
- Class historical access helper complexity.

RLS must remain correct even if optimization later uses helper functions/security-definer views; performance is never a reason to bypass authorization.

## 8. Security dynamic test plan

### Object-level authorization / IDOR

Attempt direct reads/writes using valid UUIDs belonging to another Account/Learner/Class/Attempt/Report/Campaign.

Pass: deny unless explicit relationship/scope exists.

### Acting-for forgery

Client supplies another Learner ID while authenticated as a legitimate parent of a different Learner.

Pass: deny.

### Capability escalation

- call Platform Admin RPC without capability;
- call Local Manager RPC outside assignment;
- call Organization management RPC after membership ended;
- call teacher RPC without current authority.

Pass: deny at server/RLS/RPC layer independent of UI.

### Raw-table mutation

Try `insert/update/delete` directly against core operational tables as `authenticated` and `anon` roles.

Pass: prohibited except explicitly intended low-risk tables/views; core transitions require RPCs.

### Learner enumeration

Try wildcard/browse/guessing behaviors against Learner/share-code resolution.

Pass: no public directory; share-code endpoint reveals minimal info only after exact high-entropy token and rate controls.

### Storage authorization

- reuse expired/signed URL where applicable;
- copy a private Material URL to unrelated Account;
- remove Membership then retry access.

Pass: current authorization controls future retrieval; copied path is not authority.

### Session/capability revocation

Keep a page/session open, revoke role/capability/manager access, then issue new request.

Pass: server denies based on current state.

### Ads privacy

Advertiser attempts to read `hidden_campaigns`, `ad_frequency_state`, named viewer/open histories.

Pass: denied; only aggregate permitted analytics.

### Review/commercial bypass

Try serving with:

- payment only;
- approval only;
- wrong Revision;
- expired inventory;
- paused Location;
- restricted advertiser;
- protected surface.

Pass: no serve unless every gate is valid.

### Audit integrity

Normal clients cannot edit/delete audit rows. Audit payload does not contain raw share tokens, passwords, full private messages or unnecessary child PII.

## 9. Abuse and rate-limit tests

Test abuse controls for:

- OTP/login attempts;
- share-code resolution;
- Enquiry spam;
- Learning Request spam;
- Community post/comment spam;
- Report spam;
- Campaign submission/evidence upload spam.

Rate limits must not become the sole authorization control; correctly authorized requests are still validated against business rules.

## 10. Failure/chaos injection plan

### Timeout after commit

Force client/API timeout immediately after server commits a consequential command.

Retry same idempotency key.

Pass: existing result returned; no duplicate logical action.

### Notification failure

Make notification delivery fail after Class Invitation/Submission/Test/Campaign transition.

Pass: domain state remains correct; notification is retriable/observable separately.

### Realtime failure/delay

Suppress invalidation event.

Pass: manual/navigation refetch returns authoritative state; Realtime absence never corrupts domain state.

### Expiry worker interruption

Crash halfway through Invitation/Ads hold expiry sweep.

Pass: completed expiries stay terminal; next run safely processes remaining rows; no double-release.

### Storage outage

Fail upload/object retrieval around file metadata linking.

Pass: no broken business object falsely presented as successfully uploaded; recovery path defined.

### DB connection pressure

Exhaust most pool connections while high-priority canonical commands execute.

Pass: graceful rejection/timeout behavior; no half-committed transition.

### Transaction deadlock injection

Intentionally acquire contested resources in adverse order in a test harness.

Pass: canonical functions use deterministic lock ordering or safe retry; no invariant violation.

## 11. Recovery tests

- restart API/frontend during active operations;
- restart background worker;
- recover after temporary Realtime outage;
- restore normal load after spike;
- rerun expired-item reconciliation;
- confirm idempotency keys and authoritative DB state allow clients to recover safely.

## 12. Observability required during tests

Capture at least:

- request/RPC latency histogram;
- business rejection vs system error counts;
- DB CPU/connections;
- lock waits/deadlocks;
- slow query samples;
- row counts for capacity/inventory invariants before/after tests;
- background-job lag;
- Realtime delivery lag where used;
- application errors grouped by command;
- security-denial counts without logging sensitive payloads.

## 13. Pass/fail hierarchy

A performance target may be tuned after evidence. These may **not** be tuned away:

- zero Class capacity oversell;
- zero Ads inventory oversell;
- zero duplicate logical Membership/Attempt from retries;
- zero unauthorized private-data access;
- zero manager Test impersonation;
- zero public Learner directory leakage;
- zero paid-review/verification/organic-ranking bypass;
- zero partial transfer/class-completion corruption;
- zero secret/token leakage in audit/logging.

If a Tier C stress test exceeds latency targets but invariants and security remain intact, that identifies capacity limits. If any invariant/security rule breaks at any tier, the implementation fails regardless of throughput.