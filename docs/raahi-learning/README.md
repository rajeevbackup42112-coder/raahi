# Raahi Learning V1.3 — Documentation Index

Status: **V1.2 BACKEND COMPLETE; V1.3 UX/BACKEND/BROWSER DELTA IMPLEMENTED + REGRESSION-TESTED IN DEV. NEXT: REAL GOOGLE OAUTH + PHONE-TRUST PROOF.**

This folder is the canonical handover point for Raahi Learning.

> **Source-of-truth rule:** frozen written behavior + later approved V1.3 amendments + applied forward migrations define the product. Older exploratory/generated visuals do not override them.

## Product in one sentence

Raahi Learning is a **local learning community launched one Location at a time**, where people can discover legitimate learning, parents can manage learning for children, teachers/coaches/instructors and institutes can offer learning, relationships form through controlled Enquiries, and ongoing learning continues in private Classes.

Core journey: **Find → Enquire → optional Trial → Class Invitation → Join Class → Learn**

## Read first now

1. [`99-handover.md`](99-handover.md) — current state and exact continuation boundary.
2. [`43-v1.3-implementation-checkpoint.md`](43-v1.3-implementation-checkpoint.md) — current V1.3 implementation evidence and remaining gap.
3. [`41-authentication-phone-trust-v1.3.md`](41-authentication-phone-trust-v1.3.md) — frozen Google-primary + periodic phone-trust policy.
4. [`42-v1.3-ui-db-reconciliation.md`](42-v1.3-ui-db-reconciliation.md) — V1.3 UI ↔ backend reconciliation.
5. [`40-final-product-ux-audit-v1.3-draft.md`](40-final-product-ux-audit-v1.3-draft.md) — final bounded UX audit/change register.
6. [`07-decision-log-v1.md`](07-decision-log-v1.md) — canonical decisions including V1.3 amendment.
7. [`38-backend-implementation-complete-v1.2.md`](38-backend-implementation-complete-v1.2.md) — completed V1.2 backend baseline.
8. [`00-product-ui-freeze-v1.md`](00-product-ui-freeze-v1.md) — original frozen product rules.
9. [`19-consolidated-database-blueprint-v1.2.md`](19-consolidated-database-blueprint-v1.2.md) — consolidated physical design.
10. [`20-consolidated-sql-migration-plan-v1.2.md`](20-consolidated-sql-migration-plan-v1.2.md) — consolidated baseline migration contract.
11. [`23-final-acceptance-traceability-v1.2.md`](23-final-acceptance-traceability-v1.2.md) — baseline UI/data/command/test traceability.
12. [`31-staging-load-security-chaos-plan-v1.2.md`](31-staging-load-security-chaos-plan-v1.2.md) — remaining true runtime/load/chaos plan.

## Frozen + V1.3 UI artifacts

Original inspected V1.1 fixture remains preserved byte-for-byte inside the V1.3 integration:

- `app.fixture.js` SHA-256: `6eb67b36931c45aa4113c77005d82c13bb14ec145500e08cfd92130ebcef576c`
- `styles.css` SHA-256: `b2d89e454f8e13712d10058c876f5efe2c8c69acf73dd6aade158241900f7bdd`

Current V1.3 DEV integration backup:

`/Raahi Learning/Raahi_Learning_Integrated_V1.3_DEV.zip`

SHA-256: `c1acb034d81da01379886cbea7311fd500b30375cb48b99c4e8bdde5e6a8e113`

GitHub source recovery:

```bash
node apps/raahi-learning/build-source-v13.mjs
```

Required tar SHA-256: `9aa71d002775f719970fcf6d48c324f4f3270ac9f65aa1c7e8a2f9f17c2dc9cc`

## Backend status

Supabase DEV: `iiwwmqokaeflaenhlyip`, `ap-south-1`.

The completed V1.2 backend baseline includes Identity, Locations, Learner Share Codes, Organizations/Discovery, Scoped Restrictions, Requests/Enquiries, Classes/Invitations/Files, Class Communication, Activities/Submissions, Tests/Attempts, Community/Trust, Ads Campaign/Review/Commercial, Ads Inventory/Serving, Notifications/Read Projections/Final Hardening and governed Storage.

V1.3 forward migrations applied in DEV:

- `1015_v13_contextual_inbox_and_org_teacher_picker`
- `1016_v13_learner_self_access_invitations`
- `1017_v13_organization_member_invitations`
- `1018_v13_notification_transition_wiring`
- `1019_v13_notification_initial_enquiry_dedup`

V1.3 runtime suites pass; touched V1.2 regressions pass; latest Security Advisor at checkpoint: **0 findings**.

## Browser checkpoint

- 83 canonical V1.3 routes;
- 166/166 desktop/mobile live-contract checks;
- 0 contract issues;
- 0 guard failures;
- focused V1.3 action suite: 7/7 PASS;
- no direct browser DML against operational tables;
- no phone-primary OTP login in `live.js`;
- no raw Account UUID user workflow.

## Non-negotiable principles

- Account and Learner are distinct; Learner owns learning.
- One active managing guardian per Learner in V1.
- Parent acts for Learner, never by identity impersonation.
- Manager formal-decision authority does not grant Test-taking authority.
- no turning-18 migration/lifecycle.
- no public Learner directory.
- UI does not directly mutate core operational state.
- current server state beats stale UI.
- consequential commands are idempotent.
- Pending Invitation reserves Class capacity at send time.
- transfer is learner-side authority and same-provider only in V1.
- Class and Ads capacity cannot oversell.
- Test definition locks at first valid Attempt.
- Realtime invalidates/refetches; PostgreSQL is source of truth.
- Sponsored and organic remain separate; protected learning/private-message surfaces are ad-free.
- workspace/navigation selection is not authorization.
- private Storage reads re-check business authorization.
- authenticated users have no direct DML on public operational tables.

## V1.3 authentication direction

- Google is intended primary authentication.
- Google name/photo are editable onboarding defaults, not authority.
- phone is periodic trust/contact verification, not the normal login path.
- stale phone trust must not remove existing learning/Test/safety access.
- anonymous marketplace browsing remains deferred.
- do not add fake OTP or paid phone MFA merely to implement the product rule.

## Current boundary

The next gate is **hosted Auth evidence**, not another product/schema brainstorming phase:

1. verify current Supabase Auth docs/changelog;
2. configure/test real DEV Google OAuth;
3. verify Google → Supabase → `bootstrap_account` → editable profile → server-derived contexts;
4. configure hosted DEV test SMS OTP using an authorized Auth-management surface;
5. prove server-side phone-verification evidence;
6. implement the minimal durable 90-day phone-trust layer;
7. run the 25-persona real-auth E2E cohort + complete regression/security gate;
8. only then proceed to concurrency/load/chaos and launch readiness.

Do not call the system production-ready yet and do not deploy implicitly.
