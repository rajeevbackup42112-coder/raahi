# Raahi Learning V1.3 — Pre-production execution kit and external-input boundary

Status: **AUTONOMOUS NON-DESTRUCTIVE PREPARATION COMPLETE; EXTERNAL INPUT / COST-CONFIRMATION GATES REACHED**  
Date: 2026-09-19

This checkpoint follows docs 71–74 and records the final non-destructive preparation completed without creating paid infrastructure, changing production settings, or requiring Rajeev-held Google/SMS credentials.

It does **not** authorize public deployment.

## 1. Prepared execution kit

### Production-like read load

- harness: `tests/raahi-learning-e2e/production-like-load.mjs`
- guard tests:
  - `tests/load-harness.test.mjs`
  - `tests/raahi-learning-e2e/production-like-load.test.mjs`
- manual-only workflow: `.github/workflows/raahi-learning-production-like-load.yml`
- exact target-ref binding, forbidden-project guards and DEV-origin guard are enforced;
- workload is read-only and uses genuine isolated user sessions;
- no service-role/admin key is used.

Green guard anchor:

- Model Tests run `35445592409`: PASS.

### Production candidate canary

- harness: `tests/raahi-learning-e2e/production-canary.mjs`
- guard tests: `tests/production-canary.test.mjs`

The canary is read-only and refuses both existing projects. On a future non-DEV Learning target it checks:

- HTTPS `build-meta.json`;
- DEV-only login marker is absent;
- deferred anonymous location RPC remains denied;
- two genuine canary Auth sessions;
- distinct Raahi Accounts;
- own-account RLS read succeeds;
- cross-account Account read is denied in both directions;
- authenticated locations and notifications projections remain healthy.

The canary test users must be dedicated non-personal test identities.

### Database backup

- `scripts/raahi-learning-backup-database.sh`

Safeguards include:

- explicit project/environment binding;
- ride-project rejection;
- DEV cannot be labelled production-like/production;
- DB URL/project-ref consistency check;
- Supabase CLI logical dumps of roles/schema/data;
- SHA-256 manifest;
- `restore_verified=false`;
- no database credential recorded in output metadata.

### Storage backup

- `scripts/raahi-learning-backup-storage.sh`

Safeguards include:

- fixed six Learning buckets;
- ride-project rejection;
- non-destructive `rclone copy`, never `sync`;
- source/destination remotes must differ;
- source/destination count+byte comparison;
- no S3 credential embedded in repository or manifest;
- `restore_verified=false`.

Guard tests:

- `tests/ops-guardrails.test.mjs`;
- backup scripts pass `bash -n` in Model Tests.

### Health/security/recovery inventories

- `scripts/raahi-learning-release-health.sql`
- `scripts/raahi-learning-security-catalog-audit.sql`
- `scripts/raahi-learning-recovery-inventory.sql`

These are read-only.

## 2. Current DEV recovery inventory

The recovery inventory executed successfully at migration 1033.

Snapshot:

- migration: `20260919131110 / 1033_v13_deferred_anonymous_location_rpc_acl`;
- database size: approximately 23.1 MB;
- Auth users: 78;
- Raahi Accounts: 69;
- Learners: 14;
- Account↔Learner access rows: 15;
- Organizations: 10;
- Organization Members: 18;
- Teaching Options: 45;
- Enquiries: 73;
- Enquiry Messages: 16;
- Classes: 57;
- Class Invitations: 52;
- Class Memberships: 57;
- Class Learner Threads: 5;
- Class Learner Messages: 5;
- Activities: 6;
- Submissions: 6;
- Tests: 8;
- Test Attempts: 8;
- Notifications: 417;
- Audit rows: 679;
- File assets: 0;
- Community posts/comments: 0/0;
- Ad campaigns/placements: 0/0.

All six Storage buckets contained 0 objects / 0 bytes.

Security fields inside the same inventory:

- public tables without RLS: 0;
- public tables without forced RLS: 0;
- public views: 0;
- public SECURITY DEFINER functions: 0;
- private SECURITY DEFINER functions executable by PUBLIC: 0;
- private SECURITY DEFINER functions executable by anon: 0.

This inventory is a source baseline for a future isolated restore comparison; it is not itself a backup.

## 3. Dashboard-only configuration inspection

A strict read-only browser attempt was made against the Learning DEV Supabase Dashboard to inspect:

- Health Check Advisors;
- leaked-password protection UI/plan state;
- SSL enforcement;
- network restrictions;
- scheduled backups/PITR;
- Auth rate limits;
- CAPTCHA.

The browser session was no longer authenticated. Supabase presented login plus hCaptcha. No credentials are stored in the TinyFish vault.

No setting was changed.

Therefore these dashboard-only configuration facts remain unverified through the browser until Rajeev re-authenticates a browser session.

The database Security Advisor remains independently readable through the connector and still reports exactly one warning: `auth_leaked_password_protection`.

## 4. Current Supabase organization / cost discovery

Organization:

`zxcnmenntsusjsgmonfz`

Active projects visible through the connected Supabase account:

1. Raahi Learning DEV — `iiwwmqokaeflaenhlyip`;
2. Where Is My Raahi DEV — `hoshprxoyhjyyigxkang`.

The separate ride project remains forbidden for Learning testing/restore.

Current connector cost quotes on 2026-09-19:

- development branch: **USD 0.01344/hour**;
- new project: **USD 0/month**.

These are current tool quotes, not permission to create either resource. Supabase requires explicit cost confirmation before branch/project creation.

A branch is the cheaper temporary isolated schema target, but current Supabase branching guidance makes it unsuitable as the only Raahi Learning production-like environment:

- preview branches are created from schema/migrations and do not copy production data;
- branch workflows are intended for preview/staging migration validation;
- normal GitHub deployment of branch changes does not deploy Auth configuration by default;
- a branch therefore does not by itself prove the final Google/SMS/Auth, backup, Storage-object restore, domain, or production-candidate configuration.

A branch remains useful later for migration experimentation, but the recommended next environment for Raahi Learning is a **dedicated Learning project** in `ap-south-1`, because the remaining gates require independent Auth, Storage, provider configuration, backups, domains and production-candidate behavior.

The current connector quote for a new project is USD 0/month. This is still not permission to create it, and the organization currently already has two active projects. The zero-dollar quote does not prove project-quota availability until creation is explicitly cost-confirmed and attempted.

## 5. External inputs now genuinely required

Further meaningful progress now crosses at least one user-controlled boundary.

### A. Isolated Supabase target

Needed for:

- actual production-like load;
- non-DEV production canary;
- database restore rehearsal;
- Storage restore rehearsal;
- production-candidate configuration/regression.

Creating a branch or project requires explicit cost confirmation.

### B. Supabase Dashboard authentication

Needed to inspect/configure settings not exposed by the current connector:

- leaked-password protection;
- Health Check Advisors;
- SSL enforcement;
- network restrictions;
- backup/PITR controls;
- Auth rate limits/CAPTCHA where dashboard-only.

### C. Recovery objective decision

Before selecting daily backups vs PITR vs additional independent export frequency, Rajeev must choose an acceptable RPO/RTO/cost tradeoff.

Do not invent a business data-loss tolerance from DEV evidence.

### D. Real providers

Periodic same-phone Google/SMS trust refresh still requires user-held provider authentication/ceremony. It remains separate from normal automated regression.

### E. Final production inputs

Still user-controlled:

- final production domain/origin;
- production Google OAuth;
- production SMS provider;
- redirect URLs/secrets;
- alert/escalation destination;
- pilot audience and expected traffic;
- public-launch approval.

## 6. Safe next sequence once inputs are available

1. create/select a dedicated isolated Learning project (recommended over a preview branch for the full remaining gate set);
2. apply/verify migrations through 1033;
3. configure production-like Auth/Storage/environment without DEV-only fixture surfaces;
4. capture source recovery inventory;
5. take logical DB + Storage backup;
6. restore into isolated target;
7. compare recovery inventory and Storage manifest;
8. run production candidate canary;
9. run production-like read load with pilot-derived thresholds;
10. inspect Security/Performance/Health Advisors and platform configuration;
11. run real Google/SMS provider smoke;
12. run production-candidate combined regression;
13. controlled pilot;
14. explicit go/no-go and public-launch approval.

Do not substitute current DEV or the ride project for these gates.
