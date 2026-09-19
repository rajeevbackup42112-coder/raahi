# Raahi Learning V1.3 — Production-like load and operator guard readiness

Status: **HARNESS / WORKFLOW / BACKUP GUARDS PREPARED; PRODUCTION-LIKE EXECUTION NOT YET AUTHORIZED OR POSSIBLE**  
Date: 2026-09-19

This checkpoint follows docs 71–73 and records the non-destructive preparation completed before a dedicated Learning production-like target exists.

It does **not** claim a production-like load pass, restore pass, production backup pass, or launch approval.

## 1. Guarded production-like load harness

Harness:

`tests/raahi-learning-e2e/production-like-load.mjs`

Manual-only workflow:

`.github/workflows/raahi-learning-production-like-load.yml`

The workflow has:

- `workflow_dispatch` only;
- no push trigger;
- no schedule trigger;
- no implicit target selection;
- no DEV identity factory dependency;
- no service-role/admin key;
- read-only application workload only.

The runtime workload is:

- genuine user Auth sessions;
- `get_my_account_context`;
- `get_my_notifications`;
- own-Account RLS read;
- `list_public_locations`;
- pre-load cross-account Account-read denial checks.

No consequential application write RPC is part of the production-like load harness.

## 2. Target-safety controls

Execution requires the exact confirmation phrase:

`PRODUCTION_LIKE_ISOLATED`

It also requires an explicitly typed expected Supabase project reference and verifies that the actual configured Supabase URL resolves to that same ref.

The harness/workflow refuse:

- Raahi Learning DEV project `iiwwmqokaeflaenhlyip`;
- the separate Where Is My Raahi project `hoshprxoyhjyyigxkang`;
- DEV origin `https://dev.learning.myraahi.co.in`;
- non-HTTPS origins;
- non-managed-Supabase URLs;
- non-publishable client keys;
- empty or duplicate identities;
- concurrency greater than available identities;
- out-of-range concurrency/duration;
- a typed project ref that does not match the actual target URL.

This means a stale/misconfigured target secret cannot silently redirect load to a different Supabase project while the operator believes another ref was selected.

## 3. Executable guard proof

Guard tests:

- `tests/load-harness.test.mjs`;
- `tests/raahi-learning-e2e/production-like-load.test.mjs`.

Model Tests install the pinned E2E dependencies before importing the load harness and run both the repository-level operational guard suite and the E2E-local target-guard suite.

Green Model Tests after the guard fixes:

- run: [35445592409](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35445592409)
- result: PASS

The backend-free invariant model still reports zero failures across its existing large-volume property scenarios.

Earlier red Model Test runs after adding the load guards were classified as **Test-Harness / CI plumbing**:

1. the root guard test imported `@supabase/supabase-js` before E2E dependencies were installed;
2. forbidden-project tests changed the Supabase URL without changing the newly required expected project ref, so the mismatch guard correctly fired first.

Fixes:

- install pinned E2E dependencies before root load-harness imports;
- bind the expected ref to the intentionally forbidden URL in forbidden-target tests;
- retain the independent ref-mismatch test.

No product, RLS or authority rule changed to make these tests green.

## 4. Manual workflow inputs and secrets

When a real isolated target exists, the operator must provide workflow-dispatch inputs:

- confirmation: `PRODUCTION_LIKE_ISOLATED`;
- exact target project ref;
- exact HTTPS Learning origin;
- concurrency;
- duration;
- optional maximum error rate;
- optional maximum operation p95.

Repository/Actions secrets required by the workflow:

- `RAAHI_LEARNING_LOAD_SUPABASE_URL`;
- `RAAHI_LEARNING_LOAD_PUBLISHABLE_KEY`;
- `RAAHI_LEARNING_LOAD_IDENTITIES_JSON`.

The identities secret must contain genuine isolated production-like test users. It must not contain personal production users.

No such target/secrets are configured or assumed by this checkpoint.

## 5. Backup scripts already prepared

Database logical backup:

`scripts/raahi-learning-backup-database.sh`

Storage object backup:

`scripts/raahi-learning-backup-storage.sh`

Guard regression:

`tests/ops-guardrails.test.mjs`

### Database backup safeguards

The database backup script:

- uses `set -euo pipefail`;
- uses `umask 077`;
- requires explicit project ref and environment;
- permits only `DEV_TEST`, `PRODUCTION_LIKE`, or `PRODUCTION`;
- forbids the separate ride project;
- forbids labelling Learning DEV as production-like/production;
- verifies the DB URL appears to match the declared project ref;
- requires the Supabase CLI;
- dumps roles, schema and data separately;
- records SHA-256 checksums;
- does not put credential material in the manifest;
- writes `restore_verified=false`.

### Storage backup safeguards

The Storage backup script:

- is fixed to the six Raahi Learning buckets;
- forbids the separate ride project;
- forbids labelling Learning DEV as production-like/production;
- requires different source/destination rclone remotes;
- uses `rclone copy`, not destructive `sync`;
- uses checksum comparison;
- compares source and destination object count/bytes;
- never embeds S3 credentials;
- writes `restore_verified=false`.

The backup scripts prove operator procedure/guard readiness only. They do not prove restore.

## 6. Current execution boundary

Autonomous preparation is now complete for:

- guarded production-like read-load code;
- manual-only workflow;
- target-binding and forbidden-project regression tests;
- database logical-backup script;
- Storage-object backup script;
- backup guard regression tests;
- operations/monitoring/restore runbook;
- read-only health/security catalog checks.

A real production-like load run now requires all of the following external inputs:

1. an isolated Learning Supabase target that is neither current Learning DEV nor the ride project;
2. an HTTPS Learning origin connected to that target;
3. genuine isolated load-test identities;
4. a pilot traffic/concurrency expectation to choose meaningful thresholds;
5. approval to create/configure the target if it incurs cost.

A real restore rehearsal additionally requires:

- an isolated restore target;
- an actual database backup from the chosen environment;
- actual Storage object bytes/manifest;
- target database/Storage credentials through a secure operator channel.

These are genuine environment/operational prerequisites. They should not be simulated by relabelling DEV or reusing another product's project.

## 7. Remaining production-readiness gates

Still open:

1. execute the production-like load/soak/capacity plan on isolated production-like infrastructure;
2. configure and prove operational alert delivery/escalation;
3. choose production DB backup/PITR strategy and RPO/RTO;
4. perform isolated database restore rehearsal;
5. perform actual Storage object backup + restore rehearsal;
6. resolve leaked-password protection or explicitly accept the remaining risk;
7. production SSL/network/Auth/rate-limit/provider configuration;
8. real-provider same-phone Google/SMS trust refresh;
9. production-candidate regression;
10. controlled pilot/go-no-go criteria;
11. explicit public-launch approval.

Do not use this checkpoint to claim production readiness.
