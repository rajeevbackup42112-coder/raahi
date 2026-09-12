# Raahi Learning V1.3 — Expanded Mock / Model Test Results

Status: **PASS FOR LOGICAL MODEL PROPERTIES. REAL DATABASE TESTS STILL REQUIRED.**

This run expands the earlier model suite after creation of the master QA catalog. It exercises state machines, permissions and cross-domain invariants using a deterministic backend-free model.

Seed: `20260912`

Total cases / modeled operations: **5,349,992**

Observed invariant failures: **0**

Approximate execution time in the test environment: **8.9 seconds**.

## Results

| Suite | Volume | Failures | Result |
|---|---:|---:|---|
| Learning Request state transitions / same-need reopen rule | 200,000 cases | 0 | PASS |
| Enquiry messaging permission (`Active + participant + unrestricted`) | 200,000 cases | 0 | PASS |
| Class Invitation + Membership capacity property | 1,600,000 operations | 0 | PASS |
| Atomic Class transfer model | 100,000 cases | 0 | PASS |
| Test Attempt self-access / manager denial / Start-Submit idempotency | 300,000 cases | 0 | PASS |
| Learner share-code lifecycle | 349,992 operations | 0 | PASS |
| Account closure blocker logic | 200,000 cases | 0 | PASS |
| Selected Location switch preserves established relationships | 200,000 cases | 0 | PASS |
| Ads held/confirmed inventory capacity property | 1,200,000 operations | 0 | PASS |
| Exact approved Campaign Revision serving gate | 200,000 cases | 0 | PASS |
| Sponsored protected-surface exclusion | 300,000 cases | 0 | PASS |
| Report / Block independence from punishment and Membership state | 200,000 cases | 0 | PASS |
| `complete_class` terminal-membership preservation | 100,000 cases | 0 | PASS |
| Sanitized public Learning Request projection privacy | 200,000 cases | 0 | PASS |

## What was asserted

### Learning Request

- Draft can become Open.
- Open can become Closed.
- Closed can reopen only when the underlying need remains materially the same.
- No random transition produced an invalid modeled state change.

### Enquiry

Ordinary messaging was permitted only when all three were true:

1. Enquiry is Active;
2. actor is an authorized contextual participant;
3. no applicable messaging restriction is active.

Pending/Closed or unrelated/restricted actors were denied in the model.

### Class capacity

After every randomized Invite/Accept/Decline/Expire/Cancel/Leave/Remove operation:

`Active Memberships + valid Pending Invitations <= Class capacity`

also held with:

- no learner simultaneously Pending and Active in the same Class;
- accepting a Pending Invitation never consumed a second seat;
- decline/cancel/expiry released the modeled reservation.

### Transfer

A transfer either:

- moved the Learner from source Active → source Transferred + destination Active; or
- changed neither side when destination capacity/preconditions failed.

No partial modeled transfer was observed.

### Test Attempt

- manager/unrelated authority did not create a learner Test Attempt;
- learner self-access could start;
- repeated Start retained one logical Attempt;
- repeated Submit did not create another Attempt.

### Learner share code

- Active → Consumed/Revoked/Expired only;
- terminal code states never returned to Active;
- revoked/expired/consumed codes could not be consumed again in the model.

### Account closure

Closure was denied whenever any modeled blocker existed:

- sole learner manager responsibility;
- active required teacher responsibility;
- sole required Organization authority;
- modeled legal/safety retention blocker.

### Location switch

Changing selected Location changed only the preference. Modeled Classes, Enquiries, Saved items and history remained unchanged.

### Ads inventory

After every randomized Hold/Confirm/Release/Expire operation:

`Held units + Confirmed units <= daily capacity`

held with no modeled oversell.

### Ads exact Revision

Serving was true only when the exact selected serving Revision was approved **and** commercial, Location and inventory gates were valid. A newer/different Revision did not inherit approval.

### Sponsored surfaces

Sponsored serving remained false on:

- My Classes;
- individual Class;
- Activity;
- Test;
- private Messages.

### Safety separation

- creating a Report did not automatically create a Restriction/punishment;
- Block did not alter Class Membership/history.

### Class completion

`complete_class` converted Active Memberships to Completed while preserving Left, Transferred and Removed end states.

### Public Request privacy

The modeled public projection excluded private Learner identifiers/contact/address/manager fields and selected only approved public need/context fields.

## Previous concentrated contention evidence retained

Earlier model runs also passed:

- 100,000 distinct Invitation attempts against capacity 50 → exactly 50 reservations, 0 oversell;
- 100,000 Ads reservation attempts against capacity 100 → exactly 100 units, 0 oversell.

## Interpretation

This is strong evidence that the **business model is internally coherent under random sequencing and logical contention**.

It does **not** prove:

- PostgreSQL transaction isolation or lock ordering;
- deadlock behavior;
- actual uniqueness/constraint implementation;
- RLS or GRANT correctness;
- RPC privilege hardening;
- query/index performance;
- Realtime delivery;
- Storage authorization;
- authentication/session revocation;
- network retry behavior around a real committed transaction;
- real p50/p95/p99 latency or throughput.

Those remain mandatory tests against the actual staging schema.

## Verdict

> **Expanded pre-Supabase logical model suite: PASS (5,349,992 cases/operations, 0 invariant failures).**

This PASS allows the design to proceed to implementation when authorized; it never waives the real database/security/load tests in `29-master-test-case-catalog-v1.2.md`.