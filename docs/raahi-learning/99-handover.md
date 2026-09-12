# Raahi Learning V1.2 — Handover / Current State

**Read this file first in a new conversation.**

Repository: `rajeevbackup42112-coder/raahi`  
Implementation branch: `raahi-learning-implementation-v1`  
Canonical folder: `docs/raahi-learning/`

> This branch is isolated from older Raahi ride work on `main`.

## Current status

**BACKEND DATABASE IMPLEMENTATION COMPLETE: 14/14 SLICES PASS.**

Supabase dev project: `iiwwmqokaeflaenhlyip`, region `ap-south-1`, PostgreSQL 17.6.

The implementation now includes Identity, Locations, private Learner share codes, Organizations/Discovery, scoped restrictions, Requests/Enquiries, Classes/Invitations/Files, Class Communication, Activities/Submissions, Tests/Attempts, Community/Trust, Ads review/commercial/inventory/serving, Notifications, secure UI read projections, final privilege hardening, complete Account-closure blockers and governed Supabase Storage.

Final durable result: `38-backend-implementation-complete-v1.2.md`.

## Current evidence

- frozen clickable UI: 77 canonical pages;
- UI audit: 154 desktop/mobile checks, 32 privileged deep-link checks, 26 interaction/business-rule checks, 15 semantic/accessibility samples — zero final issues;
- backend-free randomized model suite: 5,349,992 modeled cases/operations, 0 invariant failures;
- every backend slice has real PostgreSQL runtime evidence;
- final Ads inventory/serving runtime marker: `ADS_INVENTORY_SERVING_RUNTIME_TESTS_PASS`;
- final platform marker: `FINAL_PLATFORM_RUNTIME_TESTS_PASS`;
- Storage marker: `STORAGE_AUTHORIZATION_RUNTIME_TESTS_PASS`;
- post-Storage learning-file regression: `ACTIVITIES_SUBMISSIONS_POST_STORAGE_REGRESSION_PASS`;
- Supabase Security Advisor: **0 findings**;
- Performance Advisor: only unused-index INFO notices on the empty dev database;
- final fixture check: 0 Auth users, 0 operational test rows, 0 Storage object rows.

## Frozen product essence

Raahi Learning is a **local learning community launched one Location at a time**.

Core journey:

**Find → Enquire → optional Trial → Class Invitation → Join Class → Learn**

One Account may learn, teach, manage a Learner and represent an Organization. Learner history remains separate from the Account acting for it.

Do not casually restore Enrollment, Batch, Adult/Minor Learner entities, turning-18 migration, Attendance, generic Progress %, public ratings/reviews, public Learner directory, global Community, unrestricted DM, advertiser viewer CRM, platform tuition-payment collection or multi-instructor Classes in V1.2.

## Highest-value implementation rules

- `Account ≠ Learner`; Learner owns learning.
- Active manager owns formal learner-side relationship decisions; otherwise self-access may decide.
- Manager authority does not grant Test-taking impersonation.
- selected Location affects discovery/community only.
- no public Learner directory; offline learner targeting uses private expiring share code.
- Pending Class Invitation reserves capacity at send time.
- transfer is learner-side authority and same-provider only in V1.2.
- Class completion atomically completes eligible Active Memberships.
- Activity unifies Assignment/Practice/Exercise.
- Test definition locks by first valid Attempt; answer-key correction is explicit/audited.
- Reports are requests for review, not automatic guilt.
- Block is not Leave Class.
- Ads never buy verification or organic ranking.
- Ads review, Commercial Clearance and inventory are independent prerequisites.
- Ads serve the exact Approved Revision, never implicit latest revision.
- Sponsored content is excluded from Class/Activity/Test/private-message surfaces and Sponsored viewer push notifications.
- per-viewer Ads frequency/hide state is private from advertisers.
- UI/workspace routing is never authority; server read projections and RPCs re-check scope.
- private Storage access follows current business authorization, not copied URLs.
- direct authenticated DML on public operational tables is denied.

## Storage

Buckets:

- `public-profile-media` — public;
- `learner-private-media` — private;
- `class-private` — private;
- `community-public` — public;
- `ads-review-private` — private;
- `ads-public` — public but authenticated users have no direct write policy; intended for trusted approved publication.

Registered private/domain file metadata stores exact bucket + object name before upload. Private object reads re-check current learner/Class/Ads authorization.

## Primary sources

Read:

1. `00-product-ui-freeze-v1.md`
2. `01-domain-model-v1.md`
3. `02-architecture-blueprint-v1.md`
4. `04-command-permission-matrix-v1.md`
5. `05-acceptance-regression-v1.md`
6. `06-raahi-ads-v1.md`
7. `18-ui-page-inventory-v1.1.md`
8. `19-consolidated-database-blueprint-v1.2.md`
9. `20-consolidated-sql-migration-plan-v1.2.md`
10. `23-final-acceptance-traceability-v1.2.md`
11. `29-master-test-case-catalog-v1.2.md`
12. `31-staging-load-security-chaos-plan-v1.2.md`
13. `38-backend-implementation-complete-v1.2.md`

Historical design/reconciliation files remain decision traceability and do not override the consolidated V1.2 sources or applied forward migrations.

## Next phase

**Frozen UI → real backend integration.**

Next work should:

1. recover/use the exact inspected UI artifact rather than redesigning it;
2. wire Supabase Auth to Welcome/OTP/first-use;
3. replace fixture reads with secure RPC/read projections;
4. replace mock UI actions with canonical RPC commands;
5. integrate governed Storage upload/download paths;
6. preserve route/workspace guards as UX only while server authorization remains authoritative;
7. run browser E2E against the real backend;
8. then run true concurrent capacity/inventory/Test/share-code/transfer races, load/stress/soak, query/RLS performance, failure/chaos and launch-readiness gates.

Do **not** claim real load testing yet. Earlier randomized model tests and runtime transaction suites are strong logical evidence, but p50/p95/p99 and actual concurrent lock/deadlock behavior still require multi-session staging tests.

## Recommended continuation prompt

> “Continue Raahi Learning V1.2 from `raahi-learning-implementation-v1`. Read `RAAHI_LEARNING_HANDOVER.md`, `docs/raahi-learning/99-handover.md`, and `38-backend-implementation-complete-v1.2.md`. Backend is 14/14 PASS with Storage hardening complete. Continue from frozen UI → Supabase integration; do not redesign the product or replay old mobility migrations.”
