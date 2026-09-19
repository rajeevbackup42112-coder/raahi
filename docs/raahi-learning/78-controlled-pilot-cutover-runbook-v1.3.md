# Raahi Learning V1.3 — Controlled Pilot cutover runbook (same Supabase project)

Status: **PREPARED — DO NOT EXECUTE UNTIL STAGE READY + EXPLICIT GO-LIVE APPROVAL**  
Date: 2026-09-19

This runbook implements the approved single-project strategy from docs 76–77.

Target pilot geography:

- Dhanbad;
- Gomoh.

Supabase project remains:

`iiwwmqokaeflaenhlyip`

The purpose of this runbook is to convert the current synthetic DEV/STAGE project into a real-user controlled-pilot project **once**, without pretending it remains a disposable DEV environment afterward.

## 1. Non-negotiable cutover rule

After the first real pilot user enters:

- do not run synthetic writer/race/persona workflows against this project;
- do not recreate DEV personas;
- do not run destructive cleanup;
- do not use the DEV test-login page on the public origin;
- do not treat the database as disposable.

Future broad development testing must be backend-free/local until a paid isolated test environment exists.

## 2. Synthetic DEV write seal — prepared now

Marker:

`.github/RAAHI_LEARNING_DEV_WRITES_ENABLED`

The marker currently exists because Stage is still synthetic-write enabled.

All known DEV synthetic writer workflows now contain a guard:

`test -f .github/RAAHI_LEARNING_DEV_WRITES_ENABLED`

Guarded workflows:

1. `raahi-learning-activity-side-effects.yml`
2. `raahi-learning-class-lifecycle-side-effects.yml`
3. `raahi-learning-class-post-side-effects.yml`
4. `raahi-learning-class-race-recovery.yml`
5. `raahi-learning-class-session-side-effects.yml`
6. `raahi-learning-cohort-20.yml`
7. `raahi-learning-dev-e2e.yml`
8. `raahi-learning-enquiry-trial-side-effects.yml`
9. `raahi-learning-org-staff-boundaries.yml`
10. `raahi-learning-organization-authority-side-effects.yml`
11. `raahi-learning-r4-class-thread.yml`
12. `raahi-learning-release-reliability.yml`
13. `raahi-learning-test-correction-side-effects.yml`
14. `raahi-learning-ui-convergence-ads.yml`
15. `raahi-learning-ui-convergence-core.yml`
16. `raahi-learning-ui-convergence-parent-org.yml`
17. `raahi-learning-ui-convergence-privileged.yml`

Model Tests are intentionally not sealed: they are backend-free/static.

Production-candidate canary and guarded production-like load are intentionally not coupled to this marker because they are separately target-guarded/read-only.

### Pilot seal action

In the cutover commit:

1. delete `.github/RAAHI_LEARNING_DEV_WRITES_ENABLED`;
2. remove automatic push triggers from the 17 writer workflows or otherwise make them explicitly manual/archive-only;
3. preserve Model Tests;
4. preserve controlled-pilot canary;
5. do not run the writer workflows after the marker is removed.

If an old writer workflow is triggered accidentally after marker removal, it must fail before synthetic test execution.

## 3. DEV identity-factory seal

Current Edge Function:

`dev-test-identities`

Current version at the latest readiness snapshot:

`16`

Current trust boundary is already strong: only GitHub Actions OIDC from the canonical repo + implementation branch can call it.

That is appropriate for DEV/STAGE, but not enough once the same project contains real pilot data.

At pilot cutover, after synthetic cleanup:

- deploy a sealed replacement version that performs no persona/admin mutation;
- set `verify_jwt=true` for the sealed version;
- return a fixed disabled response such as `410 DEV_TEST_IDENTITIES_DISABLED_FOR_CONTROLLED_PILOT`;
- independently verify that GitHub OIDC can no longer create/update personas.

Do not leave the mutation-capable v16 as an active pilot control plane.

## 4. Pre-cutover freeze

Before data cleanup:

1. freeze an exact release commit;
2. ensure all intended Stage tests are green;
3. record exact `build-meta.json`;
4. record migration ceiling;
5. capture Security Advisor;
6. capture Performance Advisor;
7. run `scripts/raahi-learning-release-health.sql`;
8. run `scripts/raahi-learning-recovery-inventory.sql`;
9. run `scripts/raahi-learning-pilot-synthetic-inventory.sql`;
10. confirm Dhanbad=`live`, Gomoh=`preparing`.

No further schema/product work should enter the cutover after this freeze except an explicitly reviewed blocker fix.

## 5. Backup before cleanup

Before deleting any synthetic record:

### Database

Run the prepared logical backup procedure:

`scripts/raahi-learning-backup-database.sh`

Store:

- roles.sql;
- schema.sql;
- data.sql;
- SHA256SUMS;
- manifest.

The backup must be off-platform.

### Storage

Run:

`scripts/raahi-learning-backup-storage.sh`

At the current Stage snapshot Storage contains zero object bytes, but re-check at cutover.

If object count is non-zero, copy and verify every Raahi Learning bucket before cleanup.

## 6. Synthetic cleanup decision boundary

Current baseline before further Stage runs:

- 70 harness Auth users;
- 61 harness-linked Accounts;
- 8 non-harness linked Accounts.

Harness Auth identification is deterministic:

- `raw_user_meta_data.raahi_test_harness = true`.

Do not use email pattern alone as the deletion authority.

### The 8 non-harness Accounts

These must be separately classified immediately before cleanup.

Do not automatically delete them.

They may represent:

- real Google/phone hosted-auth proof identities;
- Rajeev/provider-smoke identities;
- other pre-pilot accounts that should be removed;
- accounts intentionally retained into pilot.

This is a cutover decision point.

## 7. Synthetic graph cleanup

Auth deletion alone is insufficient.

`accounts.auth_user_id` uses `ON DELETE SET NULL`.

Many domain tables reference Accounts without cascading delete.

Therefore cleanup must:

1. take the synthetic inventory;
2. derive harness Account IDs from the Auth metadata marker;
3. derive synthetic Learners, Organizations, Teaching Options, Classes and dependent objects from those Accounts;
4. delete dependent domain rows in safe FK order;
5. delete harness-root domain rows;
6. delete harness Accounts;
7. delete harness Auth users through the Supabase Auth Admin API;
8. clear harness idempotency data/audit/notifications that are part of the deleted synthetic graph;
9. verify no harness Auth marker remains;
10. verify no Account points to a harness Auth user;
11. verify no synthetic-root domain row remains;
12. rerun recovery inventory and security catalog audit.

The final deletion SQL/API sequence must be dry-run/rehearsed before execution.

Do not execute the cleanup during Stage.

## 8. Public artifact cutover

Use the guarded release packager.

The public pilot artifact must not include:

- `dev-test-login-v13.html`;
- `dev-phone-signin-v13.html`;
- hosted-auth proof pages;
- learner/provider proof pages;
- other fixture/proof entry points.

The release artifact must carry exact build metadata and file hashes.

The DEV origin may remain available for historical/engineering evidence, but the controlled-pilot canary must use the separate public pilot origin and refuse `dev.learning.myraahi.co.in`.

## 9. Authentication/provider cutover

Pilot production direction remains:

**Google sign-in → Raahi Account → periodic phone trust when required.**

Before public pilot:

- configure the public Google OAuth redirect/origin;
- confirm real Google sign-in on the public origin;
- configure real SMS provider / phone verification path;
- confirm same-phone trust behavior;
- ensure the public UI does not expose password-based DEV login;
- review Supabase Auth signup/provider settings.

Leaked-password protection remains unavailable on Free and is an explicit pilot limitation.

## 10. Pilot geography activation

Immediately before go-live:

- Dhanbad must remain `live`;
- Gomoh changes from `preparing` → `live`;
- no other Location may be `live` for the controlled pilot.

Then rerun:

- authenticated Location projection;
- teaching discovery;
- Learning Request flow;
- Community locality flow;
- selected-Location switching.

Gomoh activation is a cutover action, not a Stage action.

## 11. Controlled-pilot canary

Use workflow:

`.github/workflows/raahi-learning-production-canary.yml`

Mode:

`CONTROLLED_PILOT`

Confirmation:

`CONTROLLED_PILOT_SAME_PROJECT`

Expected project ref:

`iiwwmqokaeflaenhlyip`

Origin:

the final public HTTPS Learning origin, not DEV.

Canary must prove:

- public build-meta available;
- DEV login marker absent;
- deferred anonymous Location RPC still denied;
- two real canary users authenticate;
- own Account allowed;
- cross-Account denied;
- authenticated Location/notification projections healthy.

## 12. Go-live gate

Only after all sections above pass:

1. review exact evidence pack;
2. confirm backup completed;
3. confirm synthetic cleanup completed;
4. confirm DEV writers + identity factory sealed;
5. confirm public Google/SMS;
6. confirm Dhanbad + Gomoh only;
7. confirm canary green;
8. explicit Rajeev go-live approval.

Then admit the controlled pilot audience.

## 13. During Free-plan pilot

Operational discipline:

- regular off-platform DB dumps;
- separate Storage object backup once uploads exist;
- frequent recovery-inventory snapshots;
- Security/Performance Advisor review;
- monitor project quotas;
- do not run synthetic writer suites;
- record meaningful pilot-product metrics rather than vanity registration counts.

## 14. Trigger for paid production

Move to paid production before wider geographic expansion when pilot evidence shows meaningful adoption or the Free project becomes operationally constraining.

Paid migration should then establish:

- isolated DEV/STAGE/PROD;
- managed scheduled backups / chosen RPO;
- actual restore rehearsal;
- paid security features as appropriate;
- production-like load/soak;
- alert delivery/incident ownership;
- broader Location expansion.
