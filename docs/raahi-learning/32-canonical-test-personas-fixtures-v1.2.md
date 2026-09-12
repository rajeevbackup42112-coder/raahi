# Raahi Learning V1.2 — Canonical Test Personas & Fixtures

Status: **CANONICAL QA FIXTURE DESIGN.**

Purpose: make scenario, permission, load and regression tests reproducible. These are synthetic test identities/states only; they are not production users.

## 1. Accounts and Learners

### Accounts

| Key | Display | Capabilities / purpose |
|---|---|---|
| `A_NEHA` | Neha Sharma | managing parent for Rahul; ordinary learner-side Account |
| `A_RAHUL` | Rahul Sharma | learner self-access for Rahul |
| `A_ANANYA_PARENT` | Neha Sharma (same Account) | same Account manages Ananya as separate Learner context |
| `A_ARUN` | Arun Kumar | teacher capability; responsible teacher for several Classes |
| `A_MEERA` | Meera Singh | second teacher; used for wrong-teacher and transfer tests |
| `A_ADULT` | Priya Verma | self-managed adult Learner |
| `A_UNRELATED` | Vikram Das | no relationship to Rahul/Classes; negative permission actor |
| `A_ORG_OWNER` | Kavita Rao | authorized primary member of Bright Future Academy |
| `A_ORG_STAFF` | Suresh Jain | Organization member with limited teaching capability |
| `A_ORG_EX_STAFF` | Former Staff | ended Organization membership; stale-session tests |
| `A_GOMOH_MANAGER` | Local Manager Gomoh | active Local Manager assignment for Gomoh only |
| `A_DHANBAD_MANAGER` | Local Manager Dhanbad | active Local Manager assignment for Dhanbad only |
| `A_PLATFORM_ADMIN` | Platform Admin | platform-admin capability |
| `A_SAFETY` | Safety Reviewer | safety-review capability |
| `A_VERIFIER` | Verification Reviewer | verifier capability |
| `A_ADS_COMMERCIAL` | Ads Commercial | commercial-clearance capability |

### Learners

| Key | Learner | Access relationships |
|---|---|---|
| `L_RAHUL` | Rahul Sharma | active manager = `A_NEHA`; active self = `A_RAHUL` |
| `L_ANANYA` | Ananya Sharma | active manager = `A_NEHA`; no self-access initially |
| `L_PRIYA` | Priya Verma | active self = `A_ADULT`; no manager |
| `L_OFFLINE` | Rohan Offline | manager/self authority exists on learner side; no Enquiry with target teacher; share-code scenario |
| `L_UNRELATED` | Mohit Das | unrelated to Neha/Rahul test actors |

Critical fixture rule: `L_RAHUL` deliberately has **both** self and manager access so tests prove formal marketplace decisions remain manager-owned while Test-taking remains self-owned.

## 2. Locations

| Key | Name | State |
|---|---|---|
| `LOC_GOMOH` | Gomoh | `live` |
| `LOC_DHANBAD` | Dhanbad | `live` |
| `LOC_PATNA` | Patna | `preparing` |
| `LOC_BOKARO` | Bokaro | `interest_only` |
| `LOC_PAUSED` | Synthetic Paused Location | `paused` |
| `LOC_RETIRED` | Synthetic Retired Location | `retired` |

Assignments:

- `A_GOMOH_MANAGER` → Gomoh only.
- `A_DHANBAD_MANAGER` → Dhanbad only.

## 3. Organizations

### `ORG_BRIGHT_FUTURE`

- type: academy/coaching;
- active;
- primary authorized member: `A_ORG_OWNER`;
- limited member: `A_ORG_STAFF`;
- ended member: `A_ORG_EX_STAFF`.

Use capability variations so tests can prove that Organization membership alone does not grant every capability.

## 4. Teaching Options

### `TO_ARUN_MATHS`

- owner: `A_ARUN`;
- title: Class 8 Maths;
- Locations: Gomoh, Dhanbad;
- status: taking new learners;
- fee display: ₹1,500/month;
- mode: both.

### `TO_ARUN_GUITAR`

- owner: `A_ARUN`;
- title: Beginner Guitar;
- status: not taking new learners;
- used to prove existing Classes survive availability change.

### `TO_ORG_JEE`

- owner: `ORG_BRIGHT_FUTURE`;
- title: JEE Foundation;
- used for Organization-scoped authority tests.

## 5. Learning Requests

### `LR_RAHUL_MATHS_OPEN`

- learner: Rahul;
- manager-created by Neha;
- Location: Gomoh;
- need: Class 8 Maths;
- state: Open.

### `LR_RAHUL_MATHS_CLOSED`

Same meaningful need but Closed; used for reopen tests.

### `LR_ANANYA_DRAWING_OPEN`

Different Learner and need; used to prove sibling/context isolation.

## 6. Enquiries

### `ENQ_RAHUL_ARUN_PENDING`

- Rahul ↔ Arun;
- source Teaching Option: Maths;
- state Pending;
- ordinary message must be denied.

### `ENQ_RAHUL_ARUN_ACTIVE`

Same participants, Active; ordinary contextual messaging allowed.

### `ENQ_PRIYA_ORG_ACTIVE`

Adult self-managed Learner ↔ Bright Future Academy.

### `ENQ_CLOSED`

Closed relationship; history readable according to policy, ordinary new messages denied.

## 7. Classes and capacity fixtures

### `CLS_MATHS_FULL_MINUS_ONE`

- group Class;
- capacity 10;
- 8 Active Memberships;
- 1 valid Pending Invitation;
- exactly 1 unreserved seat remains.

Use for last-seat concurrency.

### `CLS_MATHS_FULL`

- capacity fully occupied by Active + valid Pending reservations;
- new Invitation send must fail.

### `CLS_RAHUL_ACTIVE`

- responsible teacher Arun;
- Rahul Active Membership;
- Class Active;
- includes Session, Material, Activity, Test and Class-thread fixtures.

### `CLS_RAHUL_PAST`

- Rahul Membership Completed;
- used for read-only historical-access testing.

### `CLS_LEFT`

- learner Membership Left;
- shared feed/material access should be absent while own eligible artifacts/history remain.

### `CLS_REMOVED`

- learner Membership Removed;
- copied private URL must not restore access.

### `CLS_TRANSFER_SOURCE`

- learner Active;
- destination fixtures below.

### `CLS_TRANSFER_DEST_ONE_SEAT`

- exactly one remaining capacity unit;
- use with two simultaneous transfer candidates.

## 8. Invitation fixtures

| Key | State | Purpose |
|---|---|---|
| `INV_VALID` | Pending, unexpired | happy accept + retry |
| `INV_EXPIRED` | Pending by stale UI but authoritative expiry passed | stale-screen rejection |
| `INV_DECLINED` | Declined | terminal repeat behavior |
| `INV_CANCELLED` | Cancelled | teacher cancel terminal behavior |
| `INV_FEE_1500` | Pending | fee snapshot immutability |

## 9. Learner share-code fixtures

Do not persist plaintext in any actual DB fixture after creation.

Logical states:

- `SHARE_ACTIVE` — active/unexpired;
- `SHARE_EXPIRED`;
- `SHARE_REVOKED`;
- `SHARE_CONSUMED`;
- `SHARE_RACE` — generated immediately before concurrent consume/revoke test.

Test harness may retain plaintext outside DB only for the duration of the test process.

## 10. Activity and Submission fixtures

### `ACT_ASSIGNMENT_OPEN`

- label: Assignment;
- state Open;
- submission required;
- linked worksheet Material.

### `ACT_PRACTICE_OPEN`

- same underlying Activity engine;
- label Practice;
- submission optional.

### `SUB_RAHUL_CHANGES`

- learner owner Rahul;
- revision 1 submitted;
- status Changes Requested;
- used to prove revision 2 preserves revision 1.

## 11. Test fixtures

### `TEST_UPCOMING`

- available_from in future;
- UI derives Upcoming.

### `TEST_AVAILABLE_UNLOCKED`

- available now;
- no Attempt exists;
- definition not yet locked.

### `TEST_IN_PROGRESS_RAHUL`

- one In-Progress Attempt for Rahul;
- definition locked.

### `TEST_SUBMITTED_HIDDEN`

- Attempt Submitted/Evaluated as needed;
- results_visible false.

### `TEST_RESULT_VISIBLE`

- evaluated;
- results visible;
- includes teacher feedback.

## 12. Safety fixtures

### Reports

- open Report with Rahul as moderation-private learner context;
- resolved Report with no Restriction outcome;
- serious Report with separately applied scoped restriction.

### Restrictions

- messaging-only Account restriction;
- public-discovery-only Teacher restriction;
- Class-access restriction;
- Location-scoped Ads restriction.

Fixtures must prove one restriction does not silently disable unrelated capabilities.

### Blocks

- Neha blocks another Account while Class relationship/history remains untouched.

## 13. Ads fixtures

### `CAMPAIGN_APPROVED_R1`

- Campaign has Revision 1 Approved;
- Revision 2 Draft/Under Review;
- serving Revision pinned to R1;
- proves newer revision does not inherit approval.

### `CAMPAIGN_PAID_NOT_APPROVED`

- Commercial Clearance valid;
- Review not approved;
- cannot serve.

### `CAMPAIGN_APPROVED_NOT_CLEARED`

- Review approved;
- clearance pending;
- cannot serve.

### `CAMPAIGN_MULTI_LOCATION`

- Gomoh Live placement;
- Dhanbad Paused placement;
- same Campaign; per-Location serving independence.

### Inventory

- `INV_DAY_EMPTY` capacity 0;
- `INV_DAY_ONE_LEFT` exactly one unit available;
- `INV_DAY_100` capacity 100 for stress test;
- three-day package with middle day full for atomic multi-day reservation test.

## 14. UI stale-state fixtures

Each should be representable without changing business rules:

- Invite page loaded valid, then Invitation expires;
- Class shows one seat, then another invite reserves it;
- Test page loaded before capability/Membership revoked;
- Local Manager page open, then assignment ends;
- Organization page open, then member capability revoked;
- Campaign review page open on R1 while advertiser submits R2;
- Ads availability page shows slot, then another Campaign reserves it;
- Submission UI loses response after server commit;
- Realtime update delayed while authoritative state changed.

## 15. Synthetic data generation rules

For load testing generate data with realistic skew rather than perfectly uniform random data:

- most Accounts manage 0–2 Learners;
- some Teachers have many Classes;
- a small percentage of Classes are large/hot;
- recent Community posts receive most reads;
- a small set of popular Teaching Options receive disproportionate Explore/Profile traffic;
- Ads inventory contention concentrates on popular Locations/dates/placements;
- retain realistic historical rows so indexes/RLS are tested against nontrivial history.

Avoid using real child/person contact data in synthetic fixtures.

## 16. Fixture reset principle

Automated tests must be repeatable:

- fixed identifiers or stable fixture lookup keys;
- deterministic seed where randomness is used;
- isolation between destructive/concurrency suites;
- no dependence on manually edited dashboard state;
- fixture setup and teardown are version-controlled;
- production data is never copied into local/staging merely for convenience.

These fixtures are the default vocabulary for the master test catalog and future automated suites.