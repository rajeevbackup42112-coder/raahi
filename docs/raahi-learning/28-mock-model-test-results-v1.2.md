# Raahi Learning V1.2 — Mock / Model Test Results

Status: **LOGICAL MODEL TESTS PASSED. NOT A SUBSTITUTE FOR REAL SUPABASE RUNTIME TESTS.**

These tests were executed against an independent in-memory model derived from the frozen Raahi Learning rules. They are intentionally backend-free and validate invariants under large randomized command sequences and contention models.

## Results

### 1. Class capacity / Invitation reservation model — PASS

Randomized simulation:
- 5,000 independent Classes;
- each Class capacity randomly selected from 1–20;
- 500 randomized operations per Class;
- operations included invite, accept, decline, expire, leave and remove;
- invariant checked after every operation.

Assertions held:
- `active_memberships + valid_pending_invitations <= capacity`;
- one Learner cannot be both Pending and Active in the same Class;
- accepting a valid already-reserved Invitation does not consume a second seat;
- decline/expiry releases reservation.

Approximate randomized state transitions exercised: **2.5 million**.

### 2. Ads daily inventory model — PASS

Randomized simulation:
- 5,000 independent daily inventory buckets;
- capacity randomly selected from 0–20;
- 500 randomized hold/confirm/release/expire operations per bucket.

Invariant held after every operation:

`sum(held units) + sum(confirmed units) <= capacity`

Approximate randomized inventory transitions exercised: **2.5 million**.

### 3. Learner share-code lifecycle — PASS

100,000 randomized create/consume/revoke/retry-style operations.

Assertions held:
- consumed code cannot become active again;
- revoked code cannot be consumed;
- active code never simultaneously exists in consumed/revoked sets;
- replacement behavior does not create a reusable old code.

Actual production implementation must additionally use cryptographically strong random tokens, hash-only storage, rate limiting and atomic DB consumption.

### 4. Test Attempt identity/impersonation/idempotency model — PASS

100,000 randomized start/submit operations across many Learners/Tests.

Assertions held:
- manager actor cannot create a Test Attempt merely from management authority;
- learner self actor can start;
- repeated Start returns/retains one logical Attempt;
- repeated Submit does not create another Attempt.

### 5. Protected Ads surfaces — PASS

100,000 randomized serving decisions.

Protected surfaces tested:
- My Classes;
- individual Class;
- Activity;
- Test;
- private Messages.

Assertion: Sponsored selection is always false on protected surfaces, regardless of campaign eligibility.

### 6. Cross-domain invariants — PASS

200,000 randomized scenario bundles checked:
- switching selected Location leaves established Classes/Enquiries/Saved data intact;
- Block does not mutate Membership or Report history;
- creating a Report does not automatically create a Restriction/punishment;
- `complete_class` converts eligible Active Memberships to Completed while preserving Left/Transferred/Removed states;
- Account closure is denied whenever sole-manager, active-teacher-responsibility or sole-required-Organization-authority blockers exist.

### 7. Extreme logical contention — PASS

Two deliberately concentrated bursts were modeled:

#### Class seat contention
- Class capacity: 50
- Invitation attempts: 100,000 distinct requests
- accepted reservations: exactly **50**
- oversell: **0**

#### Ads inventory contention
- inventory capacity: 100
- reservation attempts: 100,000
- successful held units: exactly **100**
- oversell: **0**

These contention tests assume the implementation provides the row/advisory locking or equivalent atomic serialization defined in the migration/command contract. Real DB contention behavior still requires staging tests.

## What these passes mean

They materially strengthen confidence that the frozen rules are internally consistent under random sequencing, retries and extreme contention **if implemented with the specified atomic boundaries**.

They do **not** yet prove:
- PostgreSQL transaction isolation behavior;
- actual row-lock ordering;
- deadlock absence;
- real RLS correctness;
- grants/privilege hardening;
- query/index performance;
- Supabase Realtime behavior;
- Storage authorization;
- network timeout recovery around real commits;
- p95/p99 latency or throughput.

Those are environment/runtime properties and remain mandatory staging tests after the real Foundation + Identity and later slices exist.

## Current verdict

**Pre-Supabase logical model: PASS.**

No invariant failure was found in the executed randomized/property-style simulations.

This result should be used as another gate, not as permission to skip real database tests.