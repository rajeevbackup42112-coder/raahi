# Raahi Learning V1.2 — Backend Implementation Complete

Status: **14/14 BACKEND SLICES IMPLEMENTED AND RUNTIME-GATED IN SUPABASE DEV.**

Target dev project: `iiwwmqokaeflaenhlyip` (`ap-south-1`, PostgreSQL 17.6).

This document records the completion of the controlled database/backend implementation phase. It does **not** claim that frontend integration, true concurrent load testing, soak testing, or production launch has been completed.

## Completed slices

1. Foundation + Identity — PASS
2. Locations — PASS
3. Learner Share Codes — PASS
4. Organizations / Teacher Discovery — PASS
5. Scoped Access Restrictions — PASS
6. Learning Requests / Enquiries — PASS
7. Classes / Invitations / Files — PASS
8. Class Communication — PASS
9. Activities / Submissions — PASS
10. Tests / Attempts — PASS
11. Community / Trust & Safety — PASS
12. Ads Campaign / Review / Commercial — PASS
13. Ads Inventory / Serving — PASS
14. Notifications / Read Projections / Final Hardening — PASS

A final storage-hardening migration (`1004_storage_authorization`) completes the frozen Storage authorization plan after all business-domain authorization helpers exist.

## Final runtime markers

Representative real PostgreSQL markers include:

- `FOUNDATION_IDENTITY_RUNTIME_TESTS_PASS`
- `POST_HARDENING_SECURITY_SMOKE_PASS`
- `LOCATIONS_RUNTIME_TESTS_PASS`
- `LOCATIONS_POST_HARDENING_SMOKE_PASS`
- Share-code basic/permission/state/terminal PASS markers
- `REQUESTS_ENQUIRIES_RUNTIME_TESTS_PASS`
- `CLASSES_FILES_RUNTIME_TESTS_PASS`
- `CLASS_COMMUNICATION_RUNTIME_TESTS_PASS`
- `ACTIVITIES_SUBMISSIONS_RUNTIME_TESTS_PASS`
- `TESTS_ATTEMPTS_RUNTIME_TESTS_PASS`
- `COMMUNITY_TRUST_RUNTIME_TESTS_PASS`
- `ADS_CAMPAIGN_REVIEW_COMMERCIAL_RUNTIME_TESTS_PASS`
- `ADS_INVENTORY_SERVING_RUNTIME_TESTS_PASS`
- `FINAL_PLATFORM_RUNTIME_TESTS_PASS`
- `STORAGE_AUTHORIZATION_RUNTIME_TESTS_PASS`
- `ACTIVITIES_SUBMISSIONS_POST_STORAGE_REGRESSION_PASS`

All disposable runtime suites use transaction rollback. Final fixture/data check after implementation: **0 Auth users and 0 application/test rows** in the tested operational tables; `storage.objects` is also empty. Only configured schema/migrations and the six intended Storage buckets remain.

## Slice 13 — Ads inventory/serving proof

The implementation now enforces:

- inventory as `Location × placement type × day`;
- deterministic row-lock order for multi-day reservations;
- all-or-nothing date-range reservation;
- Held/Confirmed capacity accounting;
- finite hold expiry;
- per-Campaign concentration limits;
- no oversell in tested runtime scenarios;
- exact approved serving Revision;
- explicit Revision switch only after current approval;
- Commercial Clearance remains independent from policy approval;
- resume/live transitions revalidate current Location, eligibility, restrictions, review, clearance and inventory;
- Sponsored serving only on governed Home/Explore/Community surfaces;
- protected learning/private surfaces return no commercial Sponsored candidate;
- per-user frequency/hide state remains viewer-private;
- advertiser analytics are aggregate only;
- deliberate Sponsored Enquiry uses the normal Enquiry relationship and stores campaign attribution;
- direct operational table mutation remains denied.

## Slice 14 — final platform proof

Final platform/runtime tests prove:

- secure My Classes / Enquiries / Class-learning projections;
- Teacher Class roster projection is provider-only;
- Local Manager projections enforce exact Location scope;
- Platform projections require Platform Admin capability;
- live Location projection excludes preparing/non-live Locations;
- Notifications are recipient-private and derived rather than business-state owners;
- Sponsored viewer push notification types are rejected;
- Account closure blocks unresolved learner management, Local Manager scope, sole Organization authority, active responsible-Teacher Classes, active provider Enquiries, submitted account-owned Ads Campaigns and unresolved safety review;
- successful closure ends non-blocking scoped authority and withdraws launch interests without cascading history deletion;
- authenticated direct DML grants on public operational tables are removed;
- PUBLIC execute is removed from private helpers;
- every inspected `SECURITY DEFINER` function pins `search_path`.

## Storage authorization completion

Six logical buckets now exist:

- `public-profile-media` — deliberately public;
- `learner-private-media` — private, current Learner relationship required;
- `class-private` — private, current business authorization required;
- `community-public` — deliberately public but writes require registered metadata;
- `ads-review-private` — private advertiser/reviewer/eligible-serving authorization;
- `ads-public` — deliberately public and reserved for trusted service-side publication; authenticated users have no direct write policy.

`file_assets` now records exact bucket + object name. Registered domain assets must be reserved through the canonical file command before upload. A copied Class/private object path is not authorization.

Storage runtime smoke proved owner upload, outsider denial, learner-private relationship gating, owner-scoped public-profile writes, registered Community writes, and no authenticated direct Ads-public upload.

## Advisor status

Final Supabase Security Advisor result: **0 findings**.

Performance Advisor has only `unused_index` informational notices on the clean/empty dev database. No current missing-FK-index or structural performance lint remains. Index pruning should wait for realistic integration/load traffic rather than deleting design indexes before they have usage statistics.

## What is not yet proven

Do not reinterpret this backend gate as production readiness. The following remain separate stages:

- wiring the frozen 77-page UI to Supabase Auth/RPCs/projections/Storage;
- real browser end-to-end testing against the backend;
- multi-session **true concurrent** last-seat, inventory, Test submit, share-code consume/revoke and transfer races;
- p50/p95/p99 performance measurements;
- connection-pool/RLS/query-plan testing under realistic traffic;
- multi-hour soak and deliberate deadlock/timeout/worker-failure tests;
- real file upload/download through Supabase Storage APIs;
- deployment, monitoring, backup/restore and launch controls.

The earlier backend-free randomized model suite remains useful evidence (5,349,992 modeled operations, 0 invariant failures), but it is not a substitute for true concurrent staging load.

## Current boundary

**BACKEND DATABASE IMPLEMENTATION GATE: CLOSED/PASS.**

Next phase:

> **Frozen UI → real Supabase integration → real E2E/security/concurrency/load/chaos → launch readiness.**

Do not redesign business rules during UI integration unless an actual contradiction is found. When one is found, perform impact analysis before changing the backend contract.
