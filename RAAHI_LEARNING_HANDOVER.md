# Raahi Learning V1.2 — Start Here

**Repository:** `rajeevbackup42112-coder/raahi`  
**Implementation branch:** `raahi-learning-implementation-v1`  
**Canonical docs:** `docs/raahi-learning/`

## Current status

**BACKEND DATABASE IMPLEMENTATION COMPLETE — 14/14 SLICES PASS IN SUPABASE DEV.**

Target dev project: `iiwwmqokaeflaenhlyip` (`ap-south-1`, PostgreSQL 17.6).

The target was inspected read-only before the first mutation. Implementation then proceeded slice-by-slice with real PostgreSQL runtime gates, forward-only fixes, RLS/privilege checks and Supabase advisor checks.

Read first:

1. `docs/raahi-learning/99-handover.md`
2. `docs/raahi-learning/38-backend-implementation-complete-v1.2.md`
3. `docs/raahi-learning/19-consolidated-database-blueprint-v1.2.md`
4. `docs/raahi-learning/20-consolidated-sql-migration-plan-v1.2.md`
5. `docs/raahi-learning/23-final-acceptance-traceability-v1.2.md`
6. `docs/raahi-learning/29-master-test-case-catalog-v1.2.md`
7. `docs/raahi-learning/31-staging-load-security-chaos-plan-v1.2.md`

## Frozen UI

Canonical inspected artifact: `Raahi_Learning_Clickable_UI_v1.1.zip`  
Persistent Library path: `/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`  
SHA-256: `2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

It contains 77 canonical routes/pages and previously passed 154 desktop/mobile route checks, 32 privileged deep-link checks, 26 interaction/business-rule checks and 15 semantic/accessibility samples with zero final issues.

## Backend gate

Passed domains:

- Foundation + Identity;
- Locations;
- Learner Share Codes;
- Organizations / Teacher Discovery;
- Scoped Restrictions;
- Requests / Enquiries;
- Classes / Invitations / Files;
- Class Communication;
- Activities / Submissions;
- Tests / Attempts;
- Community / Trust & Safety;
- Ads Campaign / Review / Commercial;
- Ads Inventory / Serving;
- Notifications / Read Projections / Final Hardening.

Final Storage authorization is also implemented through `1004_storage_authorization` with governed public/private buckets and relationship-based private reads.

Final Supabase Security Advisor: **0 findings**. Performance Advisor currently reports only unused-index INFO notices on the clean dev database.

All disposable integration tests roll back. Final check: 0 Auth users, 0 application fixture rows and 0 Storage object rows remain.

## Current boundary

The next phase is **not more schema invention**.

Next:

> Frozen UI → Supabase Auth/RPC/read-projection/Storage integration → browser E2E → true concurrent load/security/chaos → launch readiness.

Do not claim production readiness yet. True concurrent p95/p99, soak, deadlock, connection-pool and browser/file-transfer testing remain future evidence gates.

The repository `main` branch contains older Raahi work and must not be treated as Raahi Learning implementation.
