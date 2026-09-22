# Raahi Learning — Current Execution Handover — Global Admin Active / V1.4E — 2026-09-22

Status: **V1.4D PUBLIC LIVE — GLOBAL PLATFORM ADMIN ACTIVE — V1.4E LOCATION ADMIN MANAGEMENT IN IMPLEMENTATION**

Repo: `rajeevbackup42112-coder/raahi`
Branch: `raahi-learning-implementation-v1`
Supabase: `iiwwmqokaeflaenhlyip`
Public: `https://learning.myraahi.co.in`

## Live application

Production remains V1.4D:
- source `89edd9c12c8e37a70e1f8fb46faf544ac75fe6b2`
- deployment `6dd2f1d7-3514-47a7-b7b2-631d079a19be`
- rollback `18f52dbf-fbb7-4371-906a-09734f0fb9df`

## Authority now live

Global Platform Admin:
- `choudhary.ajit2112@gmail.com`
- exactly one active `platform_admin`
- no Local Manager scope required
- bootstrap audit exists: `ops.bootstrap_platform_admin`

Gomoh:
- `rajeev.backup1.2112@gmail.com` = Local Manager, Gomoh only

Dhanbad:
- `rajeev.backup2.2112@gmail.com` = Local Manager, Dhanbad only

## Verification

Ajit's genuine Account context contains `platform_admin`. In the production browser, switching to the authorized **Platform Admin** workspace renders Platform Admin overview and Platform navigation. URL changes alone do not grant authority.

## V1.4E

Contract:
`108-global-admin-location-admin-management-contract-v1.4e.md`

Permanent read migration:
`20260922113814_v14e_global_admin_location_admin_reads`

It adds Platform-only:
- `get_platform_location_admins()`
- `resolve_platform_account_email(email)`

Existing canonical write commands remain:
- `assign_local_manager`
- `end_location_staff_assignment`

Next: qualify V1.4E UI, exact-SHA CI, preview, then production. Do not alter the two current city-admin assignments during canary.
