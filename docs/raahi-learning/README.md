# Raahi Learning V1.2 — Documentation Index

Status: **BACKEND DATABASE IMPLEMENTATION COMPLETE — 14/14 SLICES PASS. NEXT: FROZEN UI → REAL SUPABASE INTEGRATION.**

This folder is the canonical handover point for Raahi Learning.

> **Source-of-truth rule:** frozen written behavior + the inspected clickable UI define the product. Applied forward migrations on `raahi-learning-implementation-v1` are the implementation record. Older exploratory/generated visuals do not override them.

## Product in one sentence

Raahi Learning is a **local learning community launched one Location at a time**, where people can discover legitimate learning, parents can manage learning for children, teachers/coaches/instructors and institutes can offer learning, relationships form through controlled Enquiries, and ongoing learning continues in private Classes.

Core journey: **Find → Enquire → optional Trial → Class Invitation → Join Class → Learn**

## Frozen UI

Artifact: `Raahi_Learning_Clickable_UI_v1.1.zip`  
Library path: `/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`  
SHA-256: `2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

Audit: 77 canonical pages; 154 desktop/mobile route checks, 32 privileged deep-link checks, 26 interaction/business-rule checks and 15 semantic/accessibility samples — zero final issues.

## Read first now

1. [`99-handover.md`](99-handover.md) — current state and exact continuation boundary.
2. [`38-backend-implementation-complete-v1.2.md`](38-backend-implementation-complete-v1.2.md) — final backend implementation result.
3. [`00-product-ui-freeze-v1.md`](00-product-ui-freeze-v1.md) — frozen product rules.
4. [`01-domain-model-v1.md`](01-domain-model-v1.md) — conceptual entities/invariants.
5. [`02-architecture-blueprint-v1.md`](02-architecture-blueprint-v1.md) — architecture boundaries.
6. [`04-command-permission-matrix-v1.md`](04-command-permission-matrix-v1.md) — command/permission intent.
7. [`05-acceptance-regression-v1.md`](05-acceptance-regression-v1.md) — Given/When/Then regressions.
8. [`06-raahi-ads-v1.md`](06-raahi-ads-v1.md) — Ads rules.
9. [`18-ui-page-inventory-v1.1.md`](18-ui-page-inventory-v1.1.md) — inspected UI inventory.
10. [`19-consolidated-database-blueprint-v1.2.md`](19-consolidated-database-blueprint-v1.2.md) — consolidated physical design.
11. [`20-consolidated-sql-migration-plan-v1.2.md`](20-consolidated-sql-migration-plan-v1.2.md) — consolidated migration contract.
12. [`23-final-acceptance-traceability-v1.2.md`](23-final-acceptance-traceability-v1.2.md) — UI/data/command/test traceability.
13. [`29-master-test-case-catalog-v1.2.md`](29-master-test-case-catalog-v1.2.md) — QA catalog.
14. [`31-staging-load-security-chaos-plan-v1.2.md`](31-staging-load-security-chaos-plan-v1.2.md) — remaining true runtime/load/chaos plan.

## Backend implementation status

Supabase dev: `iiwwmqokaeflaenhlyip`, `ap-south-1`, PostgreSQL 17.6.

Passed slices:

1. Foundation + Identity
2. Locations
3. Learner Share Codes
4. Organizations / Teacher Discovery
5. Scoped Restrictions
6. Requests / Enquiries
7. Classes / Invitations / Files
8. Class Communication
9. Activities / Submissions
10. Tests / Attempts
11. Community / Trust & Safety
12. Ads Campaign / Review / Commercial
13. Ads Inventory / Serving
14. Notifications / Read Projections / Final Hardening

Storage authorization is completed by forward migration `1004_storage_authorization`.

Final Security Advisor: **0 findings**. Current Performance Advisor findings are only unused-index INFO notices on the empty dev DB.

## Non-negotiable principles

- Account and Learner are distinct; Learner owns learning.
- Parent acts for Learner, never by identity impersonation.
- Manager formal-decision authority does not grant Test-taking authority.
- no public Learner directory.
- UI does not directly mutate core operational state.
- current server state beats stale UI.
- consequential commands are idempotent.
- Pending Invitation reserves Class capacity at send time.
- transfer is learner-side authority and same-provider only in V1.2.
- Class and Ads capacity cannot oversell.
- private share-code targeting replaces public learner search/fake Enquiry.
- Test definition locks at first valid Attempt.
- safety restrictions are scope-specific.
- Realtime invalidates/refetches; it is not source of truth.
- Sponsored and organic remain separate.
- Ads serve exact Approved Revision and require independent commercial clearance/inventory.
- protected learning/private-message surfaces are ad-free.
- per-user Ads frequency/hide data is private from advertisers.
- workspace/navigation selection is not authorization.
- private Storage reads re-check business authorization; copied paths are not access.
- authenticated users have no direct DML on public operational tables.

## Historical review chain

`03/08/09/10/11/13/14/15/16/17` remain useful decision traceability. Pre-Supabase readiness/runbook docs `21–26` explain how controlled implementation was entered. They do not override the applied forward migration record.

## Current boundary

The database/backend gate is closed successfully. Do not invent another schema phase merely to delay integration.

Next: use the **exact frozen clickable UI**, wire Supabase Auth/RPC/read projections/Storage, then execute browser E2E and the real concurrent load/security/chaos program.

Do not call the system load-tested or production-ready yet: true multi-session concurrency, p50/p95/p99, soak, deadlock/timeout and real file-transfer evidence still remain.
