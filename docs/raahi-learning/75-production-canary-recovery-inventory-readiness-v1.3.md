# Raahi Learning V1.3 — Production-candidate canary and recovery-inventory readiness

Status: **READ-ONLY CANARY + RECOVERY INVENTORY PREPARED; NON-DEV EXECUTION STILL OPEN**  
Date: 2026-09-19

This checkpoint follows docs 71–74. It records two additional release-readiness controls:

1. a guarded read-only production-candidate canary;
2. a repeatable source/restore recovery inventory.

Neither replaces the need for a real isolated Learning target.

## 1. Production-candidate canary

Harness:

`tests/raahi-learning-e2e/production-canary.mjs`

Guard tests:

`tests/production-canary.test.mjs`

Manual-only workflow:

`.github/workflows/raahi-learning-production-canary.yml`

The workflow is `workflow_dispatch` only. It has no push/schedule trigger.

Execution requires the exact phrase:

`NON_DEV_LEARNING_TARGET`

It also requires:

- exact expected Supabase project ref;
- exact HTTPS non-DEV Learning origin;
- configured non-DEV Learning Supabase URL;
- publishable key only;
- primary isolated test identity;
- unrelated isolated test identity.

The harness binds the typed expected project ref to the actual Supabase URL and refuses a mismatch.

It explicitly refuses:

- Learning DEV project `iiwwmqokaeflaenhlyip`;
- the separate Where Is My Raahi project `hoshprxoyhjyyigxkang`;
- DEV origin `https://dev.learning.myraahi.co.in`;
- non-managed Supabase URLs;
- non-HTTPS origins;
- non-publishable client keys;
- identical primary/unrelated identities.

## 2. Canary behavior

The canary is read-only at the application/domain level.

It verifies:

1. `build-meta.json` is reachable;
2. the DEV-only login marker is not exposed on the non-DEV target;
3. deferred anonymous `list_public_locations` remains denied;
4. two genuine Supabase sessions can authenticate;
5. each session resolves to a distinct Raahi Account;
6. each Account can read its own Account row;
7. neither Account can read the other Account row;
8. authenticated location projection succeeds;
9. authenticated notifications projection succeeds.

No application write RPC, service-role key, admin key, fake OTP or RLS bypass is used.

The canary has not been executed because no isolated non-DEV Learning target/credentials exist yet.

## 3. Canary guard evidence

The canary target-binding and forbidden-target tests are included in the normal Model Test suite.

Multiple Model Test runs after the final project-binding change passed. The guarded canary workflow itself is intentionally idle until explicitly dispatched with non-DEV inputs.

Intermediate red runs during guard development were Test-Harness/CI configuration issues only; the final guard state is green.

## 4. Recovery inventory

Script:

`scripts/raahi-learning-recovery-inventory.sql`

Purpose:

- run immediately before a backup/restore rehearsal;
- run again on the isolated restored target;
- compare source and restored inventories before claiming recovery success.

The script is read-only.

It captures:

- observed UTC time;
- database size;
- latest migration;
- selected critical table counts;
- Storage bucket public/private setting, object count and bytes;
- public-table RLS/forced-RLS summary;
- public/private function security summary.

## 5. Live DEV recovery-inventory baseline

Observed:

`2026-09-19 13:27:25 UTC`

Project:

`iiwwmqokaeflaenhlyip`

Latest migration:

`20260919131110 / 1033_v13_deferred_anonymous_location_rpc_acl`

Database size:

`23,080,083 bytes` (~23.1 MB)

Selected counts:

| Entity | Count |
|---|---:|
| Auth users | 78 |
| Accounts | 69 |
| Learners | 14 |
| Account learner access | 15 |
| Organizations | 10 |
| Organization members | 18 |
| Teaching options | 45 |
| Learning requests | 0 |
| Enquiries | 73 |
| Enquiry messages | 16 |
| Classes | 57 |
| Class invitations | 52 |
| Class memberships | 57 |
| Class learner threads | 5 |
| Class learner messages | 5 |
| Activities | 6 |
| Submissions | 6 |
| Tests | 8 |
| Test attempts | 8 |
| Community posts/comments | 0 / 0 |
| Ad campaigns/placements | 0 / 0 |
| Notifications | 417 |
| Audit log | 679 |
| File assets | 0 |

Storage at baseline:

| Bucket | Public | Objects | Bytes |
|---|---:|---:|---:|
| ads-public | yes | 0 | 0 |
| ads-review-private | no | 0 | 0 |
| class-private | no | 0 | 0 |
| community-public | yes | 0 | 0 |
| learner-private-media | no | 0 | 0 |
| public-profile-media | yes | 0 | 0 |

Security/function inventory:

- public tables without RLS: 0;
- public tables without forced RLS: 0;
- public views: 0;
- public functions: 175;
- public SECURITY DEFINER functions: 0;
- private SECURITY DEFINER functions: 299;
- private definers with PUBLIC EXECUTE: 0;
- private definers with anon EXECUTE: 0.

## 6. Fresh platform/advisor state

At the same readiness pass:

- project status: `ACTIVE_HEALTHY`;
- Postgres: 17.6.1;
- Edge Function `dev-test-identities`: ACTIVE, version 16;
- Security Advisor: one warning only — `auth_leaked_password_protection`;
- Performance Advisor: unused-index INFO findings only;
- former unindexed-FK findings remain closed;
- current migration ceiling remains 1033.

The unused-index count decreased from 72 to 71 as DEV traffic began exercising one previously unused index. This reinforces the existing rule: do not remove young-system indexes merely because an informational advisor has not yet observed use.

## 7. Recovery acceptance rule

A future restore rehearsal is not accepted merely because the database starts.

The restored target must match or explain differences in:

- latest intended migration;
- critical entity counts;
- Storage object counts/bytes;
- RLS/forced-RLS state;
- function security summary.

Then the restored target must also pass:

- production-candidate canary;
- relevant regression suites;
- Storage object authorization and checksum verification;
- exact build/environment verification.

Only then may the recovery rehearsal be considered passed.

## 8. Remaining blocker

The following are now fully prepared but cannot be honestly executed without external/user-controlled environment inputs:

- production-candidate canary;
- production-like read load;
- logical DB backup on a production-like/production target;
- Storage object backup with real bytes;
- isolated DB + Storage restore rehearsal.

They require a dedicated non-DEV Learning target and secure credentials. Do not reuse the ride project and do not relabel Learning DEV.
