# Raahi Learning V1.3 — Bounded reliability, observability and recovery readiness

Status: **BOUNDED DEV RELIABILITY PASS; OPERATIONAL/RESTORE GATES PARTIALLY OPEN**  
Date: 2026-09-19

This document records the first post-recovery reliability smoke, the current database-health evidence, the migration rollback/forward-fix rehearsal, and the remaining monitoring/backup/restore boundaries.

It does **not** certify production capacity, production alert delivery, production backup retention, Storage-object recovery, or public launch.

## 1. Reliability workflow

Workflow:

`.github/workflows/raahi-learning-release-reliability.yml`

Harness:

`tests/raahi-learning-e2e/release-reliability-smoke.mjs`

Final harness-fix commit:

`10111144a2d00fb28d02a4217c4225a5188673b6`

Successful workflows for that commit:

| Workflow | Run | Result |
|---|---:|---|
| Release Reliability Smoke | [35442347699](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35442347699) | PASS |
| DEV E2E Harness | [35442347698](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35442347698) | PASS |
| Model Tests | [35442347728](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35442347728) | PASS |

Reliability artifact:

- artifact id: `10584680141`
- digest: `sha256:e816dc32630d89849ec559d708ef460ca60b21e6a2e02c30608a97efdbec2652`

## 2. Workload and result

The successful run used the existing OIDC-protected DEV identity factory and genuine Supabase sessions.

Scope:

- 20 distinct cohort personas;
- 20 genuine Supabase Auth sessions;
- 20 unique Raahi Accounts;
- 10 steady-state rounds;
- 800 authenticated application/database reads in total;
- 20 cross-account RLS denial checks;
- 20 isolated browser sign-ins in batches of five.

Per persona per round the harness exercised:

1. `get_my_account_context`;
2. `get_my_notifications`;
3. authorized own-Account RLS read;
4. `list_public_locations`.

All 800 steady-state calls completed without an unexpected error. All 20 cross-account Account reads returned no unauthorized row. All 20 browser sign-ins completed.

No latency warnings were raised.

### Observed timings

| Operation | Count | p50 | p95 | p99 | Max |
|---|---:|---:|---:|---:|---:|
| Auth login | 20 | 509 ms | 996 ms | 997 ms | 997 ms |
| Account context | 200 | 292 ms | 816 ms | 885 ms | 907 ms |
| Notifications | 200 | 276 ms | 795 ms | 815 ms | 826 ms |
| Own-Account RLS read | 200 | 275 ms | 795 ms | 811 ms | 815 ms |
| Public locations | 200 | 273 ms | 789 ms | 814 ms | 825 ms |
| Browser sign-in | 20 | 1091 ms | 1210 ms | 1226 ms | 1226 ms |

These are DEV observations from one bounded run. They are not production SLOs and should not be extrapolated to production capacity.

## 3. First-run oracle correction

The first reliability run, [35442182201](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35442182201), was red even though:

- all 800 authenticated reads completed;
- all cross-account RLS checks passed;
- all 20 browser sign-ins completed;
- no latency warning fired.

The sole failure was `DEV_DEPLOYMENT_CHANGED_DURING_RELIABILITY_RUN`.

A source-compatible non-application deployment advanced while the harness was running. Requiring an identical `build-meta` commit from start to finish was therefore a harness oracle defect.

The corrected oracle accepts a deployment rotation only when the ending deployment remains browser/app-source compatible with the workflow commit. It does not accept an unproven Raahi Learning application-source change.

In the successful run:

- start deployment commit: `b63f631ddf0782c0c13e1864c7b563f1ce059149`;
- end deployment commit: `10111144a2d00fb28d02a4217c4225a5188673b6`;
- `changed_during_run: true`;
- both were app-source compatible with the tested workflow state;
- no `apps/raahi-learning/` change was crossed.

This means canonical docs should not describe a documentation/test-only build-meta SHA as a permanent “current deployed product commit.” The stable product-security anchor remains the exact product-code proof, while build-meta must be read at execution time.

## 4. Database-health snapshot

A read-only health snapshot after the reliability work found:

- database size: approximately 22 MB;
- active backend count at observation: 17;
- waiting locks: 0;
- transactions older than 30 seconds: 0;
- recorded deadlocks since statistics reset: 0;
- statistics reset: 2026-08-25 20:41:21 UTC.

The cumulative database statistics showed approximately 29.7 GB of temporary-file bytes since that August statistics reset. Because this is a cumulative counter across weeks of development/test activity, it is **not** classified as a current incident. Future operational checks should monitor the **delta over a bounded interval**, not the raw lifetime counter.

The higher cumulative query-time entries include platform/tooling catalog queries as well as application RPCs. Representative application means in `pg_stat_statements` at the snapshot were approximately:

- `get_my_conversations`: 44 ms;
- `get_my_enquiries`: 32 ms;
- `get_my_class_invitations`: 22 ms;
- `get_my_classes`: 11 ms;
- `get_my_account_context`: 7 ms.

These are cumulative database execution means and are not equivalent to end-user browser latency.

Repeatable read-only snapshot:

`scripts/raahi-learning-release-health.sql`

## 5. Performance-advisor status

Migration 1032 added covering indexes for:

- `learner_self_access_invitations.accepted_by_account_id`;
- `organization_member_invitations.accepted_by_account_id`.

Post-rehearsal advisor state:

- no `unindexed_foreign_keys` finding remains;
- Performance Advisor reports only unused-index informational findings;
- no index is being removed merely because a young DEV workload has not exercised it.

## 6. Migration rollback / forward-fix rehearsal

A non-persistent transaction rehearsal was executed in DEV for migration 1032:

1. begin transaction;
2. drop both new indexes;
3. recreate both indexes with the forward definitions;
4. assert both recreated relations exist;
5. roll back the entire transaction.

After rollback:

- both real indexes still existed;
- their definitions were unchanged;
- the unindexed-FK findings remained closed.

This proves the exact reverse/recreate SQL path for migration 1032 and PostgreSQL transactional DDL behavior in DEV. It is not a substitute for a full application rollback exercise against a production-like environment.

Operational migration rule remains:

- prefer a reviewed forward fix after a production schema change;
- use reversal only when the change is explicitly reversible and dependency impact is understood;
- never edit production schema ad hoc to make a failing test green;
- verify exact application/database compatibility before and after any rollback or forward fix.

## 7. Security-advisor state

Fresh Security Advisor result:

`auth_leaked_password_protection`

Leaked-password protection remains disabled.

No authorization/RLS control was weakened during the reliability or migration-rehearsal work.

Official remediation remains the Supabase password-security configuration. This gate is still open because the connected capability does not expose the relevant Auth setting mutation.

## 8. Storage and backup boundary

Current DEV Storage buckets:

Public:

- `ads-public`;
- `community-public`;
- `public-profile-media`.

Private:

- `ads-review-private`;
- `class-private`;
- `learner-private-media`.

At the readiness snapshot, all six buckets contained **0 objects / 0 bytes**.

That means current DEV can prove bucket/policy existence, but it cannot honestly prove restore of real Storage object bytes.

Current Supabase platform guidance states:

- paid projects receive scheduled database backups;
- PITR is a paid/add-on recovery option;
- database backups contain Storage metadata but **not Storage object bytes**;
- important Storage objects must be separately downloaded/exported outside Supabase;
- Supabase Storage's S3 compatibility does not provide S3 object versioning; deleted objects are permanently removed from Storage;
- a database restore can make the project inaccessible during the restore window.

Therefore Raahi Learning needs two distinct recovery tracks before launch:

1. database backup/restore;
2. off-platform Storage-object backup/restore.

A database backup alone is not a complete Raahi Learning backup.

## 9. Restore-rehearsal blocker

The connected Supabase account currently exposes no development branches for the Learning project.

A destructive restore will **not** be rehearsed against the only Learning DEV project, and the separate `Where Is My Raahi` project will not be repurposed.

A real restore rehearsal therefore needs a disposable isolated target: either a dedicated Learning production-like project or a paid Supabase branch/project created for the rehearsal.

Project/branch creation follows a cost-confirmation flow, so this becomes a genuine user-controlled gate once the remaining non-destructive preparation is complete.

## 10. Monitoring and incident-response readiness

Supabase's current observability guidance supports querying health/security/performance/usage signals and turning trusted read-only checks into scheduled monitoring.

Before production, Raahi Learning should continuously observe at least:

### Availability / application

- production origin reachable over HTTPS;
- `build-meta.json` present and expected environment/project metadata;
- public discovery canary succeeds;
- genuine Auth canary succeeds;
- authenticated Account-context canary succeeds.

### Database

- waiting-lock count;
- long-running transactions;
- connection utilization/saturation;
- deadlock delta;
- error/rollback trend;
- temp-file byte **delta**;
- slow/hot query changes;
- Security Advisor;
- Performance Advisor.

### Auth / provider

- Google sign-in availability;
- SMS send/verify availability;
- Auth error/rate-limit trend;
- phone-trust refresh journey.

### Storage

- upload/read/delete correctness for governed private/public paths;
- object-backup completion/freshness;
- backup inventory/count/bytes;
- restore-sample verification.

### Incident classes

- **Security/privacy:** cross-account/private-data exposure or authority bypass. Stop release progression, preserve evidence, identify exact build/database state, and correct through reviewed code/migration; never relax RLS as mitigation.
- **Data integrity:** duplicate/invalid state transition or backup/restore discrepancy. Freeze the affected change path, preserve identifiers/audit evidence, and choose forward-fix vs explicitly safe rollback.
- **Availability:** widespread Auth/API/database/application failure. Identify whether the fault is application, Supabase, OAuth/SMS provider or deployment; avoid schema changes until the failure domain is known.
- **Performance/degradation:** sustained latency/error/connection/lock deterioration. Compare with traffic and database observability before scaling or changing indexes.

Production notification delivery and escalation ownership are not yet wired, so the monitoring/incident-response gate is **designed but not operationally closed**.

## 11. What is now closed vs still open

Closed for DEV evidence:

- bounded recovery/race/shared-browser correctness;
- private cache account/session isolation;
- release packaging guards;
- two missing FK indexes;
- bounded 20-persona / 800-read reliability smoke;
- current DB health snapshot;
- repeatable health SQL;
- migration-1032 reverse/recreate transaction rehearsal.

Still open:

1. production-scale/load/soak/capacity testing against production-like compute and expected traffic;
2. real production monitoring + alert delivery + escalation ownership;
3. production database backup retention/RPO/RTO decision;
4. off-platform Storage-object backup implementation;
5. isolated database + Storage restore rehearsal;
6. leaked-password protection;
7. production SSL/network/Auth/provider configuration review;
8. real-provider same-phone Google/SMS trust refresh;
9. dedicated Learning production Supabase project;
10. final production domain;
11. production-candidate regression;
12. controlled pilot and go/no-go criteria;
13. explicit public-launch approval.

No public deployment is authorized.
