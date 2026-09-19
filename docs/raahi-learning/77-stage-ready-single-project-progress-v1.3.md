# Raahi Learning V1.3 — Stage-ready progression on single Free project

Status: **STAGE PREPARATION ACTIVE; SAME-PROJECT CONTROLLED PILOT STRATEGY ADOPTED**  
Date: 2026-09-19

This checkpoint supersedes the earlier assumption that a separate non-DEV Supabase target must be created before the first real-user release.

Approved strategy:

**DEV → Stage Ready → Controlled Pilot (Gomoh + Dhanbad) on the same Free Supabase project → Paid Production after traction.**

Canonical strategy: doc 76.

## 1. Supabase environment decision

Continue using:

- project: `iiwwmqokaeflaenhlyip`;
- region: `ap-south-1`;
- plan: Free;
- current DB engine: PostgreSQL 17.

Do not:

- pause/delete the separate Where Is My Raahi project;
- create a paid branch merely for pre-pilot proof;
- relabel the current project as full isolated production;
- widen the pilot beyond Gomoh + Dhanbad before traction justifies paid production.

Supabase currently allows only two active Free projects for this owner/admin across organizations, and both free slots are already occupied.

## 2. Free-plan pilot trade-off

Current Supabase guidance states:

- Free projects receive 500 MB database per project;
- 1 GB Storage;
- 50,000 MAU;
- 500,000 Edge Function invocations;
- 2 million Realtime messages;
- 200 peak Realtime connections;
- managed daily backups are documented for Pro/Team/Enterprise;
- Free projects should regularly export data with `supabase db dump` and keep off-site backups;
- leaked-password protection is a Pro-plan feature.

Current Raahi Learning data footprint is ~23 MB with zero Storage objects, so quota/capacity is not the immediate reason to pay.

The deferred value of paid production is environment isolation, managed backup/recovery, paid security/operations controls and headroom after traction.

## 3. Gomoh stage configuration

Applied migration:

`20260919142407 / 1034_v13_stage_gomoh_location`

Repository file:

`supabase/migrations/20260919142407_1034_v13_stage_gomoh_location.sql`

Current Location state:

| Location | Slug | State |
|---|---|---|
| Dhanbad | `dhanbad` | `live` |
| Gomoh | `gomoh` | `preparing` |

Gomoh is intentionally **not live yet**.

Its coverage metadata records the Stage / controlled-pilot purpose.

## 4. Locality contract proof

Current database contracts preserve the intended Location lifecycle.

`list_live_locations()` returns only `state='live'`.

`list_public_locations()` may expose non-retired Locations, including `preparing`, so a preparing Location can be represented before launch.

`set_selected_location()` allows a non-retired Location to be selected. This is not treated as a defect: selected Location is user context, while marketplace/community operational commands enforce live state separately.

The following consequential operations require a live Location:

- publish teaching option → `TEACHING_LOCATION_NOT_LIVE`;
- post Learning Request → `LOCATION_NOT_LIVE`;
- publish Community post → `LOCATION_NOT_LIVE`.

Discovery also suppresses non-live activity:

- teaching discovery joins Location with `state='live'`;
- Community discovery requires Location `state='live'`;
- Learning Request creation itself requires live Location, preventing new preparing-location requests.

Therefore Gomoh can be visible/preparing without accidentally opening its marketplace/community before pilot cutover.

## 5. Controlled-pilot canary mode

Existing production-candidate canary has been extended without weakening its existing non-DEV guards.

Harness:

`tests/raahi-learning-e2e/production-canary.mjs`

Manual workflow:

`.github/workflows/raahi-learning-production-canary.yml`

Two explicit modes now exist.

### NON_DEV

Requires:

`NON_DEV_LEARNING_TARGET`

Still forbids:

- Learning DEV ref;
- ride project ref;
- DEV web origin.

### CONTROLLED_PILOT

Requires:

`CONTROLLED_PILOT_SAME_PROJECT`

Requires exact project ref:

`iiwwmqokaeflaenhlyip`

Still refuses:

- the DEV web origin `https://dev.learning.myraahi.co.in`;
- the ride project;
- target-ref mismatch;
- non-HTTPS public origin;
- non-publishable keys.

This lets the public pilot origin use the existing Learning Supabase backend while still preventing accidental canarying of the DEV website.

The workflow remains manual-only.

## 6. Synthetic-data boundary

DEV identity factory marks every generated test Auth user with:

`raahi_test_harness: true`

and uses the `@dev.learning.myraahi.co.in` email domain.

Read-only inventory:

`scripts/raahi-learning-pilot-synthetic-inventory.sql`

Baseline observed 2026-09-19 14:28:52 UTC:

- harness Auth users: 70;
- harness-linked Accounts: 61;
- non-harness linked Accounts: 8;
- Storage objects: 0.

Synthetic-root counts at that snapshot:

| Root / evidence | Count |
|---|---:|
| Learners created by harness Accounts | 11 |
| Organizations created by harness Accounts | 10 |
| Teacher profiles for harness Accounts | 9 |
| Teaching options owned by harness Accounts/orgs | 44 |
| Classes owned by harness Accounts/orgs | 56 |
| Enquiries in harness graph | 72 |
| Class memberships in harness graph | 56 |
| Notifications for harness Accounts | 411 |
| Idempotency keys for harness Accounts | 1169 |
| Audit rows by harness Accounts | 654 |

Important:

Deleting Auth users alone is insufficient.

`accounts.auth_user_id` uses `ON DELETE SET NULL`, and many domain tables reference Accounts without cascading deletion. A pilot cleanup must therefore delete synthetic application-domain graph data in dependency order and then remove harness Auth users.

No cleanup has been executed.

The 8 non-harness linked Accounts remain explicitly outside automatic cleanup until they are separately classified at pilot cutover.

## 7. CI evidence after strategy/Gomoh changes

Recent green evidence includes:

- Model Tests run `35448857541`: PASS;
- Model Tests run `35448790762`: PASS;
- Model Tests run `35448777096`: PASS;
- Model Tests run `35448765105`: PASS;
- DEV E2E / genuine-session run `35448765073`: PASS;
- earlier post-Gomoh DEV E2E run `35448646829`: PASS.

No product rule/RLS relaxation was used.

## 8. Current advisor state

Security Advisor:

- one warning: `auth_leaked_password_protection`.

This cannot be fully resolved on Free because leaked-password protection is a Pro-plan feature.

Performance Advisor:

- unused-index INFO notices only;
- no unindexed-FK warning.

Do not remove young-system indexes merely because the advisor has not observed use.

## 9. Stage Ready work still open

Before declaring Stage Ready:

1. complete/rehearse the synthetic-domain cleanup procedure without executing final cleanup;
2. **CLOSED / PREPARED:** all 17 known synthetic writer workflows now fail closed if `.github/RAAHI_LEARNING_DEV_WRITES_ENABLED` is removed; pilot cutover procedure is doc 78;
3. verify release packaging/public artifact excludes DEV-only login/proof surfaces;
4. prepare exact pre-pilot backup + recovery-inventory checklist;
5. finish the current genuine-session locality proof and verify Gomoh/Dhanbad UI/Location-state presentation;
6. keep security/regression suites green;
7. prepare real Google/SMS provider cutover steps;
8. choose the public pilot origin/domain.

Do not activate Gomoh yet.

Do not delete synthetic data yet.

Do not disable DEV automation yet.

## 10. Pilot-cutover actions that remain intentionally blocked

At the actual controlled-pilot cutover:

- freeze exact release commit;
- take DB + Storage backup;
- classify the 8 non-harness pre-pilot Accounts;
- execute verified synthetic cleanup;
- seal DEV identity factory / write-test automation;
- configure real public Auth/provider settings;
- configure public origin;
- switch Gomoh to `live`;
- run CONTROLLED_PILOT canary;
- obtain explicit Rajeev go-live approval.

Only after those steps should real Gomoh/Dhanbad users be admitted.


## 11. DEV writer seal preparation

Prepared marker:

`.github/RAAHI_LEARNING_DEV_WRITES_ENABLED`

All 17 known synthetic-mutating DEV workflows now check this marker immediately after checkout.

During Stage the marker remains present.

At Controlled Pilot cutover the marker will be removed and automatic writer triggers sealed in the same reviewed commit. This prevents an accidental old CI workflow from mutating real pilot data.

Exact cutover procedure: doc 78.
