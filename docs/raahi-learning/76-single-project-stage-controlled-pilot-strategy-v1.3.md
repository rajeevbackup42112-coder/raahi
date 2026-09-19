# Raahi Learning V1.3 — Single-project Stage → Controlled Pilot strategy

Status: **APPROVED PRODUCT/INFRASTRUCTURE DIRECTION**  
Date: 2026-09-19

Decision:

Use the existing Raahi Learning Supabase project `iiwwmqokaeflaenhlyip` through Stage Ready and for the first limited real-user release in **Gomoh + Dhanbad**.

Do not pay for a separate Supabase environment before the pilot demonstrates useful real adoption.

If the controlled pilot receives a good response, move to a paid Supabase organization/project topology and complete the deferred production-isolation/recovery gates before broader expansion.

This is a deliberate cost-conscious pilot strategy, not a claim that one Free project provides full production-environment isolation.

## 1. Environment lifecycle

Use four explicit states:

### A. DEV — current

Purpose:

- product implementation;
- migrations;
- genuine-session automated testing;
- synthetic personas;
- race/recovery/security/regression proof;
- bounded reliability testing.

Synthetic test writes are permitted.

### B. STAGE READY — next

Still the same Supabase project.

Stage Ready means the product behaves as the intended pilot product and all non-provider/non-paid gates that can honestly be proven on this project are closed.

Stage Ready does **not** mean public users are admitted yet.

### C. CONTROLLED PILOT — Gomoh + Dhanbad only

Still the same Supabase project, but operating discipline changes.

Before the first real pilot user is admitted:

1. freeze an exact release commit;
2. capture migration/security/performance/recovery inventory;
3. take the best available off-platform logical DB backup;
4. back up any Storage object bytes separately;
5. clean synthetic application data and DEV Auth identities that must not coexist with real pilot data;
6. stop automated workflows that create/mutate synthetic DEV data against this project;
7. preserve only read-only health/canary checks appropriate for pilot;
8. ensure the public artifact excludes DEV-only login/proof pages;
9. configure real Google/SMS provider settings and public redirect URLs;
10. verify the public origin with a pilot-safe canary;
11. make only Gomoh and Dhanbad live/discoverable for the pilot;
12. keep public launch bounded to the controlled pilot audience.

From this point onward the project contains real user data and must not be treated as a disposable DEV database.

### D. PAID PRODUCTION — after traction

Trigger: evidence from the controlled pilot justifies paying for stronger infrastructure.

Then:

- move to a paid Supabase setup;
- separate production from future development/testing;
- enable/choose managed backup strategy;
- resolve paid-only security controls where appropriate;
- perform isolated database + Storage restore rehearsal;
- perform production-like load/soak/capacity testing;
- wire operational monitoring/alert delivery;
- widen geography only after the new production environment is proven.

## 2. Why this is acceptable for the first pilot

Current official Supabase Free limits are materially above the expected initial Gomoh + Dhanbad pilot scale:

- 500 MB database per project;
- 1 GB Storage;
- 50,000 MAU;
- 500,000 Edge Function invocations;
- 2 million Realtime messages;
- 200 peak Realtime connections.

The current Raahi Learning DEV database is only about 23 MB and Storage currently contains no object bytes.

Therefore capacity quota is not the immediate reason to pay.

The reasons to move paid later are mainly:

- environment isolation;
- managed scheduled backups;
- restore/recovery maturity;
- paid-only security/operations features;
- larger sustained usage;
- operational confidence for wider launch.

## 3. Free-plan limitations we explicitly accept for the controlled pilot

### Database backups

Supabase documents automatic scheduled daily backups for Pro, Team and Enterprise projects.

For Free projects, Supabase recommends regularly exporting data using `supabase db dump` and maintaining off-site backups.

Therefore the controlled pilot must not pretend it has a paid managed-backup SLA.

Our pilot rule:

- take an off-platform logical DB backup before pilot cutover;
- take regular off-platform logical exports during the pilot;
- keep Storage object backup separate from the database;
- record checksums/manifests;
- do not claim restore proof until a paid/isolated target exists.

### Storage

Database backups do not contain Storage object bytes.

Raahi Learning must maintain a separate Storage copy once users begin uploading media/files.

### Leaked-password protection

Supabase leaked-password protection is a Pro-plan feature.

The current Security Advisor warning therefore cannot be fully removed on the Free plan.

Raahi Learning production direction remains Google-primary authentication with periodic phone trust, not password-primary user login.

Before controlled pilot:

- public UI must not expose DEV password-login tooling;
- synthetic password test identities should be removed or isolated from real-user operation;
- Auth provider settings must be reviewed so unnecessary password/signup surfaces are not exposed.

This limitation must be treated as an accepted pilot constraint, not falsely marked resolved.

## 4. Test-data cutover rule

This is the most important discipline of the single-project strategy.

Today DEV contains synthetic test data, including genuine Supabase Auth test users and application records.

Before Controlled Pilot:

- take a recovery inventory;
- identify all synthetic Auth users and application data;
- create/rehearse a deterministic cleanup procedure while no real user exists;
- execute cleanup once;
- independently verify that synthetic data is gone;
- preserve migration history/schema/functions/RLS;
- disable automated synthetic writer workflows against the now-real project.

After the first real user joins:

**never run destructive cleanup, persona factories, race fixtures or broad write-test suites against this project again.**

Future development testing after pilot launch must be backend-free/local where possible until a paid isolated test environment is created.

## 5. Geography rule for pilot

Frozen product positioning remains local-first: Raahi launches one Location at a time.

Pilot geography:

- Dhanbad;
- Gomoh.

Current DEV state on 2026-09-19:

- Dhanbad exists and is `live`;
- Gomoh is not yet configured.

Stage plan:

- add Gomoh through a governed/admin-controlled configuration path;
- keep it `preparing` during staging;
- validate discovery, teacher multi-location behavior, selected-Location isolation and local Community behavior;
- switch Gomoh to `live` only at controlled-pilot cutover;
- do not enable other Locations for pilot discovery.

Selected Location continues to affect discovery/community context only; it must not sever existing private Classes/Enquiries/Saved/history.

## 6. Stage Ready definition

Raahi Learning becomes **Stage Ready** when all of the following are true:

1. canonical product/business rules remain frozen and traceable;
2. current migration ceiling is clean and reproducible;
3. all Model Tests are green;
4. DEV E2E/genuine-session harness is green;
5. bounded reliability/security/race/recovery proofs remain green;
6. Security/Performance Advisor findings are understood and classified;
7. Dhanbad + Gomoh stage configuration is complete;
8. public release packaging excludes DEV-only surfaces;
9. pilot-cutover cleanup script/procedure exists and is tested before real data exists;
10. manual DB backup and Storage-backup procedures are ready;
11. recovery inventory is captured/repeatable;
12. pilot-safe canary exists;
13. Google/SMS real-provider runbook is ready;
14. no public release has occurred.

Stage Ready is the next engineering milestone.

## 7. Controlled Pilot Ready definition

After Stage Ready, the same project becomes **Controlled Pilot Ready** only when:

1. exact release commit is frozen;
2. pre-cutover DB/Storage backup completes;
3. synthetic users/data are cleaned and independently verified;
4. DEV write automation is disabled against the project;
5. public domain/origin is configured;
6. Google production sign-in works;
7. phone trust/SMS works with the real provider;
8. public artifact contains no DEV-login/proof surface;
9. pilot canary passes against the public origin;
10. Dhanbad and Gomoh are the only live pilot Locations;
11. privacy/RLS/security checks pass after cleanup;
12. a simple pilot incident/backup routine is assigned;
13. explicit Rajeev go-live approval is given.

## 8. What remains deferred until paid production

The following are intentionally deferred rather than faked:

- separate DEV/STAGE/PROD Supabase projects;
- isolated destructive restore rehearsal;
- production-like heavy load/soak against isolated infrastructure;
- managed daily backup SLA/PITR;
- paid-only leaked-password protection;
- full production alerting/operations stack;
- broader geographic rollout.

This is an explicit pilot trade-off.

## 9. Promotion trigger to paid production

Do not define success only as raw registrations.

Evaluate the pilot using meaningful signals such as:

- active learners/parents;
- active legitimate teachers/coaching providers;
- successful discovery → enquiry conversions;
- accepted Class invitations;
- repeat learning activity;
- user retention/return;
- safety/support incidents;
- operational burden;
- database/Storage/Realtime usage;
- qualitative evidence that Gomoh/Dhanbad users are solving the intended discovery/learning problem.

When evidence shows the product deserves expansion, move to paid production **before** adding more Locations or materially increasing pilot scale.

## 10. Immediate execution sequence

Continue autonomously now with:

1. prepare Gomoh as the second stage Location;
2. prove Dhanbad/Gomoh locality behavior;
3. prepare deterministic synthetic-data/Auth cleanup for pilot cutover;
4. prepare pilot-safe canary mode for the same Supabase project/public origin;
5. prepare DEV-writer workflow shutdown controls;
6. prepare pre-pilot backup/recovery inventory checklist;
7. keep existing regression/security gates green.

Do not clean data, disable DEV automation, or make Gomoh publicly live yet. Those are pilot-cutover actions, not Stage work.
