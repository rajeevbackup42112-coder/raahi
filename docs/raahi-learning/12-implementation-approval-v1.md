# Raahi Learning V1 — Implementation Approval Record

Status: **IMPLEMENTATION APPROVAL PAUSED. Supabase remains untouched.**

The technical SQL plan and written UI↔DB reconciliation are strong, but implementation approval is intentionally paused for one more practical validation gate:

> **Build the real clickable V1 UI pages with hard-coded fixture data, inspect them thoroughly, then run the final inspected UI against the DB/command design.**

The earlier generated images were useful for product discovery but are not precise enough to be the final implementation contract. They also contained known image-generation drift. No Supabase changes have been made, so pausing at this point has no rollback cost.

## Required gate

Follow `15-ui-page-build-review-gate-v1.md`.

Sequence:

1. enumerate the complete V1 page/state inventory;
2. build an inspectable clickable frontend prototype using deterministic hard-coded data only;
3. walk every learner, parent, teacher, organization, Local Manager and Ads journey;
4. inspect permissions, stale states, empty/error/unavailable states, responsive behavior and wording;
5. freeze the inspected UI behavior as v1.1;
6. run the page-level UI ↔ DB reconciliation;
7. revise physical schema/commands/migration plan if the inspected UI proves a gap;
8. only then restore **APPROVED FOR IMPLEMENTATION** and connect to Supabase.

## Technical plan retained as input

The following remain the current technical reference, but they are not permission to execute yet:

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
- `13-ui-db-reconciliation-v1.md`
- `14-ui-db-implementation-delta-v1.md`

## Prototype build constraints

- no Supabase/database integration;
- no temporary schema merely to support the prototype;
- hard-coded fixture data is expected;
- UI may simulate successful/failed transitions locally for inspection, but the future canonical command must be identifiable;
- written frozen rules override old generated images;
- do not reintroduce removed concepts such as Enrollment, Batch, Adult/Minor learner entities, turning-18 lifecycle, attendance, generic progress %, ratings/reviews, public learner directory or tuition-payment collection.

## Approval condition

Implementation may be re-approved only after the inspected real UI pages prove that:

- all V1 journeys are understandable and complete;
- every CTA has a defined resulting state, failure behavior and authority model;
- every displayed field/state can be securely supported by the DB/projection design;
- no DB concept exists only because technical design became too clever;
- no UI page introduces unsupported or removed product behavior;
- every discovered mismatch is corrected in both the UI specification and technical documents.

## Current external state

> **No Raahi Learning migration has been executed against Supabase.**

The next action is UI page inventory and clickable prototype construction, not database execution.