# Raahi Learning V1 — Implementation Approval Record

Status: **IMPLEMENTATION APPROVAL PAUSED. Supabase remains untouched.**

The technical SQL plan passed its internal schema/architecture review, but implementation approval is intentionally **paused** until one additional gate is completed:

> **UI Prototype ↔ Database Design Reconciliation**

This gate is required because the database must prove it can support every approved UI action/state, and the UI must not imply any behavior, data, permission, or lifecycle that the database/command model does not support.

The previous approval was therefore premature. No Supabase changes were made, so no rollback is required.

## Technical plan already reviewed

The following remain valid inputs to the reconciliation:

- `00-product-ui-freeze-v1.md`
- `01-domain-model-v1.md`
- `02-architecture-blueprint-v1.md`
- `03-database-blueprint-v1.1.md`
- `04-command-permission-matrix-v1.md`
- `05-acceptance-regression-v1.md`
- `06-raahi-ads-v1.md`
- `08-database-blueprint-review-v1.md`
- `09-sql-readiness-review-v1.md`
- `10-sql-migration-plan-v1.1.md`
- `11-sql-migration-plan-review-v1.md`

## Required reconciliation before implementation

For every canonical UI flow/screen/action, verify:

1. what data the screen reads;
2. whether that data exists in the physical design;
3. whether a secure projection/view/RPC can provide it;
4. what command executes each user action;
5. what state transition/results the UI may show;
6. what permissions authorize the action;
7. how stale/double actions behave;
8. whether files/media are authorized correctly;
9. whether notifications/realtime are derived correctly;
10. whether the UI exposes any removed concept or unsupported promise.

Then perform the reverse check:

- every important table/state/command must have a real product/UI purpose;
- remove or defer schema elements that exist only because the technical design became too clever;
- ensure the DB does not silently introduce a second product model.

## Canonical flows to reconcile

At minimum:

- Learn for myself: Explore → Enquire → optional Trial → Class Invitation → Join → My Classes;
- Parent acting for Learner: For Rahul → Enquire/Post Request → Join Rahul → oversight;
- Learning Request: create/open/close/respond/enquiry;
- Teacher/provider: What I Teach → Teaching Opportunities → Enquiry → Class invite → Class operation;
- My Classes: feed, materials, announcements, sessions, activities, submissions, tests, learner-specific communication;
- transfer/leave/remove/past Class;
- Save and Location switching;
- Community;
- Report/Block/Verification/restrictions;
- Organization/institute administration;
- Local Manager operations;
- Raahi Ads advertiser flow;
- Sponsored viewer flow;
- Ads review/commercial/inventory/multi-location flow.

## Visual-drift rule

Generated prototype images are not automatically authoritative because image generation introduced known drift (ratings, Enrollment wording, overbuilt billing, old role assumptions, etc.).

Reconciliation uses:

> **approved intended UI behavior + canonical prototype interaction patterns**

and treats the written frozen product rules as authoritative where a generated image conflicts.

## Approval condition

Implementation may be marked **APPROVED FOR IMPLEMENTATION** only after the UI↔DB reconciliation concludes that:

- every approved UI action is representable and enforceable;
- every required UI read can be projected securely;
- no UI action bypasses a canonical command;
- no table/state creates unapproved product behavior;
- no high-value flow has a missing data relationship;
- all discovered gaps have been corrected in both the schema/migration plan and the UI behavior specification.

## Current external state

> **No Raahi Learning migration has been executed against Supabase.**

Do not connect to or mutate Supabase until the reconciliation gate is closed and this record is re-approved.