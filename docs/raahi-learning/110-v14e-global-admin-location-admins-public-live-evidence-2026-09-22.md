# Raahi Learning V1.4E — Global Admin Location Admin Management Public Live Evidence — 2026-09-22

Status: **PUBLIC LIVE — ROUTINE LOCATION-ADMIN MANAGEMENT INSIDE RAAHI**

Repository: `rajeevbackup42112-coder/raahi`
Branch: `raahi-learning-implementation-v1`
Supabase: `iiwwmqokaeflaenhlyip`
Public origin: `https://learning.myraahi.co.in`

## 1. Exact source

Application source SHA:

`ca4890629e787a5d969edce691dbac6f756f318d`

Commit:

`Add Global Admin location-admin management`

GitHub Model Tests:
- run #658
- run ID `35723224947`
- conclusion: success

## 2. Global-admin state

Exactly one active Global Platform Admin exists:

`choudhary.ajit2112@gmail.com`

The first-admin bootstrap is complete and audited.

Current Local Managers remain:
- Gomoh: `rajeev.backup1.2112@gmail.com`
- Dhanbad: `rajeev.backup2.2112@gmail.com`

Neither city admin was converted to global authority.

## 3. V1.4E contract

The Global Platform Admin can now manage routine Location-admin assignments from Raahi Learning itself.

New Platform workspace route:

`Location Admins`

The screen:
- lists all non-retired Locations;
- lists current active Local Managers;
- resolves one existing Raahi Account by exact Google email;
- assigns that Account through canonical `assign_local_manager`;
- removes Local Manager access through canonical `end_location_staff_assignment`;
- requires a reason on removal;
- never grants or revokes `platform_admin`;
- performs no direct table DML.

A future Local Admin must first have a genuine active Raahi Account. If the email has never signed in to Raahi, the UI instructs the Platform Admin to have that person sign in once and retry.

## 4. Permanent migration

Applied migration:

`20260922113814_v14e_global_admin_location_admin_reads`

It adds Platform-only read projections:
- `get_platform_location_admins()`
- `resolve_platform_account_email(email)`

The write authority remains on the pre-existing audited commands:
- `assign_local_manager`
- `end_location_staff_assignment`

## 5. Qualification

Static / operational tests:
- 76/76 production/operational Node tests passed
- V1.4E focused tests passed
- syntax checks passed
- release-package tests passed

Model/property suite:
- 5,349,572 cases
- 0 failures

Production-like load guards:
- 9/9 passed

Database runtime smoke:
- `V14E_GLOBAL_ADMIN_LOCATION_ADMIN_READS_PASS`

Residue after rollback:
- V1.4E synthetic Auth users: 0
- V1.4E synthetic Locations: 0

Supabase advisors:
- no new V1.4E security finding;
- pre-existing leaked-password-protection warning remains;
- unused-index findings remain informational.

## 6. Release artifact

Release manifest SHA-256:

`070eec6c085f146033a9d865677eb8ec5d3f072c481baec53d3727b9730cf553`

Packaging:
- 15 deployable public files
- 14 content hashes in build-meta
- deploy-copy mismatches: 0
- forbidden public DEV/secret matches: 0
- DEV login file absent
- `admin-management-v14e.js` present

## 7. Preview

Latest preview:
- ID: `447bd223-329d-4dc4-8685-febceb59a3af`
- branch: `v14e-ca48906-preview`
- source: `ca48906`
- exact URL: `https://447bd223.raahi-learning-prod.pages.dev`
- alias: `https://v14e-ca48906-preview.raahi-learning-prod.pages.dev`

Preview artifact verification:
- exact SHA match
- hash mismatches: 0
- forbidden public matches: 0
- admin-management file hash:
  `0c22926a1aa9feac55167d3c4db46e2c8387c6b3f540978471ac581bea7c00eb`

## 8. Production

Production deployment:
- ID: `c0ab3d26-185e-45e1-a18b-9cff6504f405`
- branch: `main`
- source: `ca48906`
- exact Pages URL: `https://c0ab3d26.raahi-learning-prod.pages.dev`
- custom origin: `https://learning.myraahi.co.in`

Immediate rollback anchor:
- ID: `6dd2f1d7-3514-47a7-b7b2-631d079a19be`
- source: `89edd9c`

Production verification:
- build-meta exact SHA: `ca4890629e787a5d969edce691dbac6f756f318d`
- hash mismatches: 0
- forbidden public matches: 0
- admin-management file hash exact

## 9. Production browser canary

Using Ajit's already-authenticated production browser session:

1. Direct Location Admins route while not in Platform workspace failed closed with **Platform Admin required**.
2. Authorized workspace was switched to **Platform Admin**.
3. Platform Admin navigation exposed **Location Admins**.
4. Location Admins rendered:
   - Dhanbad → `rajeev.backup2.2112@gmail.com`
   - Gomoh → `rajeev.backup1.2112@gmail.com`
5. Gomoh **Assign Local Admin** was opened.
6. Exact email lookup for `rajeev.backup1.2112@gmail.com` resolved the existing genuine Account.
7. UI correctly reported:
   - current Local Manager scope: Gomoh;
   - already active for this Location.
8. No assignment or removal command was executed during the canary.

Post-canary server verification:
- active Global Platform Admins: 1
- Gomoh Local Manager still active
- Dhanbad Local Manager still active
- V1.4E synthetic users: 0
- V1.4E synthetic Locations: 0

## 10. Result

Routine Local Admin management no longer requires Supabase SQL.

The one-time first Global Admin bootstrap remains historical only.

The next product activation gate is the first genuine Teacher end-to-end Founding Supply flow:
Teacher requests help → correct city admin prepares private draft → Teacher reviews and accepts → genuine supply appears in Explore.
