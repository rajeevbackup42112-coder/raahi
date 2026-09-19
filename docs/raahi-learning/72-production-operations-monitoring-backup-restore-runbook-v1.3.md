# Raahi Learning V1.3 — Production operations, monitoring, backup and restore runbook

Status: **PREPARED; REQUIRES PRODUCTION TARGET/CREDENTIALS FOR EXECUTION PROOF**  
Date: 2026-09-19

This runbook is the operational continuation of doc 71. It defines the procedure that can be prepared without creating or modifying production infrastructure.

It is not evidence that production monitoring, backups or restores are already configured.

## 1. Guardrails

Never:

- use the separate Where Is My Raahi project for Learning backup/restore testing;
- restore over the only Learning DEV project merely to prove a runbook;
- put database passwords, Supabase Management tokens, Storage S3 secret keys, SMS credentials or OAuth client secrets in Git;
- print those secrets into GitHub Action logs;
- use client publishable keys as backup/administration credentials;
- weaken RLS or Storage policies to make a backup or restore test easier;
- assume a successful database restore also restored Storage object bytes;
- perform a public production deployment without explicit Rajeev approval.

Production/database/Storage credentials must live only in an approved secret store.

## 2. Release-health evidence pack

Before a production-candidate go/no-go, capture:

1. exact Git commit;
2. exact production-candidate artifact metadata / `build-meta.json`;
3. exact Supabase project reference and region;
4. migration ceiling;
5. active Edge Function versions;
6. Security Advisor;
7. Performance Advisor;
8. `scripts/raahi-learning-release-health.sql` output;
9. production-candidate regression artifact digests;
10. real-provider Google/SMS smoke evidence;
11. latest backup timestamp and backup inventory;
12. latest restore-rehearsal result.

Do not call a release exact-build if the deployment marker does not correspond to the intended source or a deliberately proven source-compatible state.

## 3. Monitoring design

### 3.1 External/application canaries

Minimum signals:

- HTTPS application origin responds;
- `build-meta.json` is readable and carries the intended environment/project metadata;
- public discovery canary succeeds;
- genuine Auth canary succeeds;
- authenticated `get_my_account_context` succeeds;
- one RLS-negative canary confirms a different Account cannot read the canary Account;
- browser sign-in canary reaches the expected authenticated route.

Do not use fake OTPs as a production provider canary.

### 3.2 Database signals

Collect and trend:

- connection utilization;
- waiting locks;
- transactions over the chosen long-transaction threshold;
- deadlock **delta**;
- transaction rollback/error trend;
- temporary-file byte **delta**;
- database/disk growth;
- hot/slow query changes;
- Security Advisor findings;
- Performance Advisor findings.

Use deltas/rates for cumulative PostgreSQL counters. A large lifetime counter by itself is not an incident.

### 3.3 Auth/provider signals

Track separately:

- Google OAuth failure/error trend;
- SMS send failure trend;
- SMS verify failure trend;
- rate-limit events;
- phone-trust refresh completion;
- provider status/outages.

Third-party provider incidents must not be mistaken for authorization defects.

### 3.4 Storage signals

Track:

- object count/bytes per bucket;
- governed upload/download/delete canary;
- backup completion timestamp;
- backup object count/bytes;
- sample checksum verification;
- failed-copy count;
- restore-sample result.

## 4. Initial technical alert classes

These are operational classes, not business SLO commitments.

### SEV-0 / security or authority

Examples:

- cross-account private-data exposure;
- RLS/authorization bypass;
- private object accessible without authority;
- credential/secret exposure.

Immediate response:

1. stop release/deployment progression;
2. preserve exact commit, build-meta, request/audit identifiers and timestamps;
3. determine affected surface and time window;
4. do not relax RLS as a workaround;
5. remediate through reviewed code/configuration/migration;
6. rerun the smallest authoritative proof, then the combined security/regression suite;
7. assess notification/legal obligations before reopening affected functionality.

### SEV-1 / data integrity or broad outage

Examples:

- duplicate irreversible transitions;
- corrupted relationship state;
- widespread sign-in/API/database outage;
- restore mismatch.

Response:

1. identify application vs database vs platform vs provider failure domain;
2. preserve audit/evidence;
3. pause risky writes/deployments when practical;
4. choose reviewed forward fix vs explicitly reversible rollback;
5. verify DB and Storage consistency independently;
6. run exact recovery/regression checks before reopening.

### SEV-2 / degradation

Examples:

- sustained latency/error growth;
- lock/connection pressure;
- isolated provider degradation.

Response:

1. compare current deltas with baseline;
2. identify hot query/provider/deployment correlation;
3. avoid speculative schema/index changes;
4. fix only a demonstrated bottleneck;
5. verify with the same measurement used to detect it.

## 5. Database backup procedure

Supabase currently documents:

- daily platform backups for paid projects;
- PITR as a paid/add-on option;
- manual logical export with the Supabase CLI;
- database restore may make the project unavailable while restoring.

For a portable logical backup, use an operator-controlled environment with the Supabase CLI and a secret database connection string.

Official pattern:

```bash
supabase db dump --db-url "$RAAHI_LEARNING_DB_URL" -f roles.sql --role-only
supabase db dump --db-url "$RAAHI_LEARNING_DB_URL" -f schema.sql
supabase db dump --db-url "$RAAHI_LEARNING_DB_URL" -f data.sql --use-copy --data-only
```

Never place `RAAHI_LEARNING_DB_URL` in source control or command output.

For every logical backup, record:

- project reference;
- source commit/migration ceiling;
- UTC timestamp;
- SHA-256 of each dump;
- file size;
- secure off-platform destination;
- retention/expiry date;
- operator/run identifier.

A backup is not considered proven until it can be restored into an isolated target and verified.

## 6. Storage-object backup procedure

Database backups contain Storage metadata but not object bytes.

Supabase Storage exposes an S3-compatible endpoint. Server-side S3 access keys have full Storage access and bypass RLS, so they are highly privileged operator credentials.

Endpoint shape from current Supabase guidance:

`https://<project-ref>.storage.supabase.co/storage/v1/s3`

Required operator-only values:

- project ref;
- region;
- S3 Access Key ID;
- S3 Secret Access Key.

Use an S3-compatible tool such as rclone or AWS CLI from a controlled backup runner.

For each backup run:

1. list source buckets;
2. copy every required bucket to an off-platform destination;
3. record source bucket public/private configuration;
4. record object count and bytes;
5. produce a manifest of object path, size and checksum where practical;
6. fail the backup if any copy/check fails;
7. store manifest and logs without secrets;
8. verify a sample from both public and private bucket classes.

Current Raahi Learning bucket inventory:

Public:
- `ads-public`
- `community-public`
- `public-profile-media`

Private:
- `ads-review-private`
- `class-private`
- `learner-private-media`

At the 2026-09-19 DEV snapshot all six buckets were empty, so no real object-byte restore is yet proven.

Supabase S3 object versioning is not available. Do not rely on the source bucket itself as deletion recovery.

## 7. Configuration backup

Database and Storage copies are not the whole system.

Record, without secret values:

- Auth provider enablement and non-secret settings;
- Google OAuth redirect/callback URLs;
- SMS provider identity/configuration;
- Auth rate-limit settings;
- leaked-password protection state;
- email/phone confirmation rules;
- Edge Function names, versions and repository source;
- environment/secret **names**;
- Storage bucket configuration;
- custom domains and DNS intent;
- Realtime/publication settings;
- production origin and allowed redirect origins.

Secret values must be recoverable from the chosen secret manager/operator account, not from this document.

## 8. Isolated restore rehearsal

Do not perform this against Learning DEV.

Required target:

- a disposable Supabase branch/project or dedicated production-like restore target;
- never the Where Is My Raahi project.

### 8.1 Database restore verification

Restore the approved database backup according to the target type and current Supabase restore guidance.

Then verify at minimum:

- migration/schema objects;
- RLS policies;
- canonical RPCs;
- auth user/account continuity expectations appropriate to the target;
- row counts for critical tables;
- functions/triggers/extensions;
- audit history;
- the read-only health SQL;
- Security/Performance Advisors.

For a CLI/self-hosted-style logical restore, Supabase's documented pattern uses `psql --single-transaction --variable ON_ERROR_STOP=1` with roles/schema/data dumps. A managed-project rehearsal must follow the then-current managed-project restore procedure instead of blindly copying a self-hosted command.

### 8.2 Storage restore verification

After database/bucket metadata is present:

1. restore objects through the supported Storage/S3 API;
2. compare object count/bytes with the backup manifest;
3. verify sample checksums;
4. confirm public objects are reachable only as intended;
5. confirm private objects still require the correct business authorization;
6. verify application file references resolve.

### 8.3 End-to-end restore acceptance

After DB + Storage restore:

- deploy a non-public production-candidate application configured for the isolated target;
- run genuine-session Account bootstrap/context;
- run representative read/write vertical-slice checks;
- run copied-private-link denial;
- run a governed Storage upload/read check;
- confirm old source-project credentials are not required by the restored target.

Record measured restore time and the actual recoverable timestamp. Only then can RTO/RPO claims be evidence-based.

## 9. RPO/RTO decision gate

Do not invent a business recovery objective from DEV evidence.

Before pilot, Rajeev must choose an acceptable maximum data-loss window and recovery-time target.

Technical options include:

- paid daily Supabase backups: simpler/lower cost, coarser recovery point;
- PITR: materially smaller database RPO, additional cost/compute requirements;
- independent logical exports: portable secondary database copy;
- independent Storage-object export: required regardless, because DB backups do not include object bytes.

The final choice should consider pilot size, acceptable loss, cost, and operational complexity.

## 10. Migration rollback / forward-fix rule

For production:

- every schema change must be represented as a reviewed forward migration;
- prefer forward-fix after a deployed migration;
- document explicit reverse SQL only when the change is genuinely reversible;
- never assume dropping a column/table/data transformation is safely reversible;
- before a rollback, confirm application version compatibility with the older schema;
- after a forward fix or rollback, rerun exact health/advisor/security/regression evidence.

Migration 1032 already has a DEV transactional reverse/recreate rehearsal recorded in doc 71.

## 11. Launch blocker summary

This runbook can be fully executed only after the following exist:

1. dedicated Learning production or isolated production-like Supabase target;
2. approved plan/backup choice;
3. operator access to database/S3 credentials through a secure channel;
4. production domain/origin;
5. OAuth/SMS production configuration;
6. alert delivery/escalation destination;
7. controlled pilot audience and traffic expectation.

Those are explicit launch inputs, not reasons to modify frozen product rules.
