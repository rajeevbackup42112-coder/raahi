# Raahi Learning — Current Execution Handover — V1.4E Public Live — 2026-09-22

Status: **V1.4E PUBLIC LIVE — GLOBAL ADMIN + CITY ADMIN OPERATIONS GREEN**

Repo: `rajeevbackup42112-coder/raahi`
Branch: `raahi-learning-implementation-v1`
Supabase: `iiwwmqokaeflaenhlyip`
Public: `https://learning.myraahi.co.in`

## Read first

1. `111-current-execution-handover-v14e-public-live-2026-09-22.md`
2. `110-v14e-global-admin-location-admins-public-live-evidence-2026-09-22.md`
3. `108-global-admin-location-admin-management-contract-v1.4e.md`
4. `107-current-execution-handover-v14d-public-live-2026-09-21.md`
5. `105-scoped-market-activation-authority-contract-v1.4d.md`
6. `101-founding-supply-assisted-teacher-onboarding-contract-v1.4c.md`
7. `92-market-activation-seeding-blueprint-v1.4.md`
8. `99-handover.md`

Do not restart completed V1.4A/B/C/D/E design or deployment qualification.

## Exact live state

Application source:
`ca4890629e787a5d969edce691dbac6f756f318d`

Production deployment:
`c0ab3d26-185e-45e1-a18b-9cff6504f405`

Immediate rollback:
`6dd2f1d7-3514-47a7-b7b2-631d079a19be` / `89edd9c...`

GitHub CI:
- Raahi Learning Model Tests #658
- run ID `35723224947`
- success

Latest permanent migration:
`20260922113814_v14e_global_admin_location_admin_reads`

## Authority

Global Platform Admin:
- `choudhary.ajit2112@gmail.com`
- exactly one active `platform_admin`

Gomoh Local Manager:
- `rajeev.backup1.2112@gmail.com`
- Gomoh only

Dhanbad Local Manager:
- `rajeev.backup2.2112@gmail.com`
- Dhanbad only

## What V1.4E added

Platform Admin now has a **Location Admins** screen.

It:
- shows Dhanbad/Gomoh and active Local Managers;
- finds one existing Account by exact Google email;
- assigns Local Manager using `assign_local_manager`;
- removes Local Manager using `end_location_staff_assignment`;
- never grants global Platform Admin;
- never writes core tables directly.

A person must sign in to Raahi once before the Global Admin can assign them.

## Evidence

Production exact asset verification:
- hash mismatches: 0
- forbidden public/secret matches: 0

Browser canary:
- non-Platform workspace denied Location Admins;
- Platform Admin workspace rendered the new page;
- Dhanbad backup2 and Gomoh backup1 were listed correctly;
- exact lookup of backup1 returned the existing Account and correctly showed already active in Gomoh;
- no current admin assignment was modified during canary.

Database runtime:
- V1.4E smoke passed
- synthetic residue 0
- active Platform Admin count remains 1

## Next product gate

Move from administration plumbing to genuine market activation.

Use **one real Teacher first**:

1. Real Teacher signs into Raahi.
2. Teacher chooses **Ask Raahi to help** for one real founding Location.
3. Verify private request appears only to the correct city Local Manager and Global Admin.
4. Correct city admin prepares a truthful private draft from details the Teacher actually supplied.
5. Teacher signs in, reviews the exact proposed public details, and accepts or declines.
6. Only Teacher acceptance may create public Teacher Profile + first Teaching Option.
7. Verify the resulting genuine supply appears correctly in Explore.
8. Verify normal Teacher editing/availability controls after acceptance.
9. Then repeat with a very small genuine founding cohort.

Do not manufacture users, Teacher supply, requests, comments, reactions, enquiries, reviews, popularity, or demand.

After the first genuine Teacher flow is green, continue Raahi Desk launch content and Founding Supply according to `92-market-activation-seeding-blueprint-v1.4.md`.
