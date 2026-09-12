# Raahi Learning V1.1 — Implementation Approval Record

Status: **APPROVED FOR CONTROLLED IMPLEMENTATION AFTER INSPECTED UI V1.1. Supabase remains untouched.**

This approval is the final pre-Supabase gate. It is issued only after:

1. Product/UI behavior freeze;
2. conceptual Domain/Architecture review;
3. physical database blueprint review;
4. SQL migration-plan review;
5. written UI↔DB reconciliation;
6. construction of a real backend-free clickable UI prototype;
7. desktop/mobile, permission, edge-state and interaction inspection of that prototype;
8. final page-level UI↔DB reconciliation.

The inspected UI gate is documented in:

- `15-ui-page-build-review-gate-v1.md` — gate definition, now closed;
- `16-ui-page-freeze-and-final-reconciliation-v1.1.md` — inspected UI freeze/result;
- `17-final-ui-db-implementation-delta-v1.1.md` — final DB/command changes proved by real pages.

## Canonical implementation contract

Implementation must read the following together:

- `00-product-ui-freeze-v1.md`;
- `01-domain-model-v1.md`;
- `02-architecture-blueprint-v1.md`;
- `03-database-blueprint-v1.1.md`;
- `04-command-permission-matrix-v1.md`;
- `05-acceptance-regression-v1.md`;
- `06-raahi-ads-v1.md`;
- `08-database-blueprint-review-v1.md`;
- `09-sql-readiness-review-v1.md`;
- `10-sql-migration-plan-v1.1.md`;
- `11-sql-migration-plan-review-v1.md`;
- `13-ui-db-reconciliation-v1.md`;
- `14-ui-db-implementation-delta-v1.md`;
- `16-ui-page-freeze-and-final-reconciliation-v1.1.md`;
- `17-final-ui-db-implementation-delta-v1.1.md`.

**Precedence:** where later reconciliation/delta documents conflict with earlier schema or migration wording, the later inspected-UI delta wins. Specifically, `17` overrides `14` where they differ, and both override the earlier migration wording they intentionally correct.

## Inspected UI artifact

Canonical artifact: `Raahi_Learning_Clickable_UI_v1.1.zip`

Persistent Library path: `/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`

SHA-256: `2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

Final audit results:

- 77 canonical routes/pages;
- 154 desktop/mobile route checks, 0 issues;
- 32 privileged deep-link checks, 0 unguarded pages;
- 26 interaction/business-rule checks, 0 failures;
- 15 semantic/accessibility sanity samples, 0 issues.

Generated concept images remain visual inspiration only; the inspected clickable prototype plus frozen written rules define UI behavior.

## Final inspected-UI corrections now approved

In addition to earlier reconciliation corrections, implementation must now include:

1. Location lifecycle begins with `interest_only` before `preparing`;
2. secure one-time private `learner_share_codes` for inviting an existing offline learner without a public learner directory or fabricated Enquiry;
3. optional immutable-while-Pending `class_invitations.fee_display_text` snapshot for the terms displayed at Join;
4. optional private `test_attempts.teacher_feedback` for released Test Results;
5. canonical guarded Account pause/resume/closure commands and responsibility blockers;
6. explicit capability/relationship/scope authorization on every privileged read/deep link; workspace navigation is never authority.

Earlier binding corrections remain, including:

- selected Location in `account_location_preferences`;
- persisted `location_interests`;
- `can_make_learning_decision` for formal learner-side marketplace/relationship decisions;
- Organization logo support;
- deterministic historical Class access by Membership end state;
- no independent Class learner-thread lifecycle;
- Session Past derived from time, no Attendance subsystem;
- reusable `activity_material_links`;
- optional private `reports.context_learner_id`;
- atomic `complete_class`;
- Sponsored serving governed by allowed surface, not Adult/Minor identity.

## Removed complexity remains removed

The inspected real pages did **not** justify restoring:

- Enrollment;
- Batch entity;
- Adult/Minor Learner entities;
- turning-18 migration;
- major Trial relationship object;
- Attendance;
- generic Progress %;
- public ratings/reviews;
- public Learner directory;
- unrestricted direct messaging;
- multi-teacher Class in V1;
- advertiser viewer CRM;
- platform tuition-payment collection.

## First approved implementation slice

Only the following may be implemented first:

### Foundation + Identity

- PostgreSQL extensions/common helpers;
- Accounts;
- Learners;
- Account↔Learner Access;
- Account Capabilities;
- Audit Log;
- Idempotency Keys;
- Identity authorization helpers;
- `can_make_learning_decision(learner_id)`;
- Identity canonical RPCs;
- Account pause/resume/guarded closure command semantics (in the Identity slice or immediate Identity follow-up before Locations);
- RLS and privilege hardening;
- tests for learner ownership, one active self/manager relationship, decision authority, manager-vs-self separation, account lifecycle blockers, idempotency and privilege escalation.

Do **not** implement Locations or later modules until Foundation + Identity passes its migration, RLS, RPC, idempotency and authorization tests.

## Execution rules

Actual Supabase changes must:

- use versioned SQL migrations committed to source control;
- proceed slice-by-slice, never as a one-shot schema push;
- test each slice immediately;
- stop on contradiction or failed invariant;
- use forward-fix migrations after anything has been applied to a shared environment;
- keep private files authorized through current business access rather than copied URLs;
- keep UI/navigation guards as defense-in-depth, never as the only authorization layer;
- never reinterpret old generated screenshots as requirements when they conflict with this contract.

## Current external state

At the time of this approval:

> **No Raahi Learning migration has been executed against Supabase.**

The design/document/UI gate is complete. The next operational action, only when the user authorizes Supabase execution, is to inspect the target Supabase project/environment and implement **Foundation + Identity only**.
