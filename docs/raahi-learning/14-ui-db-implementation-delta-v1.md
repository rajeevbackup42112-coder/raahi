# Raahi Learning V1 — UI/DB Reconciliation Implementation Delta

Status: **BINDING IMPLEMENTATION DELTA. Supabase has not been touched.**

This file converts the findings in `13-ui-db-reconciliation-v1.md` into concrete migration/RPC/RLS changes.

Until a consolidated SQL plan revision is published, the implementation contract is:

> `10-sql-migration-plan-v1.1.md` **plus this delta**.

If they conflict, this delta wins because it is later and comes from UI↔DB reconciliation.

---

# 1. Foundation / Identity changes

## Accounts

In `0100_identity_tables.sql`:

- `accounts.auth_user_id` is nullable at the application-record level and references `auth.users(id) ON DELETE SET NULL`.
- do **not** create `selected_location_id` on `accounts`.
- do not introduce Adult/Minor/Parent/Teacher role columns.

## Learning-decision authority helper

Add to `0103_identity_rls_helpers.sql`:

### `can_make_learning_decision(p_learner_id uuid)`

V1 semantics:

1. derive current Account from `auth.uid()`;
2. if Learner has an active `manage` relationship, only that active manager (or explicitly authorized Platform/Safety exceptional path) may make formal learner-side marketplace/relationship decisions;
3. otherwise active `self` access may make the decision;
4. this does not grant Test impersonation;
5. safety Report ability remains separately permitted.

Use this helper for learner-side commands such as:

- post/update/close/reopen Learning Request;
- send/engage learner-side Enquiry decisions as appropriate;
- accept/decline Class Invitation;
- voluntary Leave/Transfer consent actions.

Use `has_learner_self_access` for learner-owned Test start/submit and other learning actions that must not be performed merely by a manager.

Add tests proving a Learner with both `self` and `manage` access cannot bypass active manager decision ownership from the self account for formal marketplace actions.

---

# 2. Location migration changes

Keep:

- `0200_locations_tables.sql`
- `0201_account_location_preferences.sql`
- `0202_locations_staff_rls_rpcs.sql`

Add:

### `0203_location_interests.sql`

Create `location_interests`:

- `id uuid pk default gen_random_uuid()`
- `location_id uuid not null fk locations`
- `account_id uuid not null fk accounts`
- `intent_type text not null check intent_type in ('learn','teach')`
- `state text not null check state in ('active','withdrawn')`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

Partial unique:

- one active `(location_id, account_id, intent_type)`.

Canonical RPCs:

- `register_location_interest(location_id, intent_type, idempotency_key)`;
- `withdraw_location_interest(location_interest_id, idempotency_key)`;
- `set_selected_location(location_id)`.

Rules:

- Location Interest does not publish a Learning Request or Teaching Option;
- Local Manager readiness views use aggregate counts by default;
- changing selected Location never changes existing relationship ownership.

Add tests:

- duplicate retry produces one active Interest;
- same Account can register both `learn` and `teach`;
- Location launch does not auto-create marketplace content;
- switching Location cannot hide active Classes/Enquiries.

---

# 3. Organizations / Discovery changes

In `0300_organizations_discovery_tables.sql`, add public Organization logo/avatar support:

- `logo_type text` constrained to `builtin | upload | none` (or equivalent canonical values);
- `logo_ref text null`.

If implementation chooses a public file-asset reference instead, it must preserve the same UI behavior without creating a private-file authorization dependency.

Do not create Organization-as-Teacher duplicate profiles.

---

# 4. Class migration changes

## Sessions

In `0500_classes_files_tables.sql`, do not model a meaningful `completed` Session lifecycle in V1.

Preferred fields:

- `starts_at`
- `ends_at`
- delivery/location details
- `cancelled_at null`
- `cancel_reason null`

“Past” is derived from time. Attendance remains absent.

## Class completion

In `0502_class_invitation_membership_rpcs.sql`, add/replace with canonical:

### `complete_class(p_class_id, idempotency_key)`

Transaction:

1. derive/authorize responsible Teacher/Organization authority;
2. lock Class row;
3. require current Class `active`;
4. validate no unresolved condition that product rules require before completion;
5. transition eligible Active Memberships to `completed` with common completion timestamp/reason;
6. transition Class to `past` in the same transaction;
7. preserve already Left/Transferred/Removed Membership end states;
8. record idempotency result;
9. commit, then notify.

Do not expose a free `mark_class_past` mutation that can leave unintended Active Memberships.

## Historical Class access

In `0503_classes_rls.sql`, add explicit read helpers/policies:

- Active Membership → normal Class access subject to Restrictions;
- Completed → read-only appropriate Class history/materials + learner's own artifacts/results;
- Transferred → read-only appropriate source-Class history + learner's own artifacts/results;
- Left → shared Class feed/material access ends; learner retains appropriate own artifacts/results/history;
- Removed → Class-private access ends; legitimate own/safety/audit records remain only through their proper projections/policies;
- Safety/Class-access restriction can override ordinary historical access.

Do not add a configurable per-Class historical-access policy table in V1.

---

# 5. Class communication changes

In `0550_class_communication_tables.sql`:

Keep `class_learner_threads` as the contextual relationship:

- `id`
- `class_id`
- `learner_id`
- `created_at`
- unique `(class_id, learner_id)`.

Remove/defer independent:

- `status active|closed`;
- `closed_at`.

Thread read/write eligibility is derived from Membership end state, current learner-side authority, responsible Teacher authority, and active scoped Restrictions.

Add tests:

- direct/offline-origin learner does not require Enquiry to use Class context;
- active manager can see permitted learner context;
- copied thread/Class identifiers do not grant access;
- Left/Removed users cannot continue sending messages;
- Completed/Transferred history is read-only where allowed.

---

# 6. Activity migration changes

In `0600_activities_submissions_tables.sql`, add:

### `activity_material_links`

- `activity_id uuid fk activities`
- `material_id uuid fk materials`
- unique `(activity_id, material_id)`.

Canonical teacher command may link/unlink Materials to an Activity but must ensure Material is authorized/shared to the Activity's Class.

This supports worksheet/reference/resource attachments without creating separate Assignment/Practice file systems.

---

# 7. Trust/Safety migration changes

In `0800_community_trust_tables.sql`, add to `reports`:

- `context_learner_id uuid null fk learners`.

`report_subject` must verify the current Account is allowed to reference that Learner through self/manage/safety context before accepting the field.

The optional Learner context is moderation-private and must not turn into public child identity.

Add tests:

- parent can report a concern for managed Learner;
- learner with self-access can report own concern independently of manager marketplace permissions;
- unrelated Account cannot attach arbitrary Learner context;
- Report creation does not automatically punish target.

---

# 8. Ads serving/UI rule change

No new age state/table is required.

Ads serving function receives/derives an allowed **surface context**.

Sponsored may be selected only for governed general surfaces such as:

- Home;
- Explore;
- explicitly configured Local Community educational/event placements.

Sponsored must be excluded from:

- My Classes;
- individual Class/feed/material;
- Activities;
- Tests;
- private Enquiry/Class messages;
- paid Notifications.

This is surface-based and does not depend on Adult/Minor identity or turning 18.

User/learner private activity must not be used to construct behavioral Ads targeting.

Save from Sponsored content, where offered, saves the underlying Organization/Teaching Option rather than the Campaign itself.

Add serving tests proving protected surface contexts always return no Sponsored placement.

---

# 9. Existing offline learner onboarding

No schema change is required for the core learning model.

V1 rule:

- Class Invitation targets an existing Raahi Learner;
- existing offline learner/parent first creates or links the Learner in Raahi;
- teacher then sends normal Class Invitation;
- no fake Enquiry/Trial/Enrollment history is created.

A future one-time private learner-share code/link may improve discovery of the correct Learner without a public directory, but it is explicitly deferred until the UI needs it enough to justify another security-sensitive token flow.

Do not implement teacher access to a public Learner search directory as a shortcut.

---

# 10. Migration sequence after reconciliation

Canonical sequence becomes:

### Foundation / Identity
- `0001_extensions_helpers.sql`
- `0002_common_updated_at.sql`
- `0100_identity_tables.sql`
- `0101_identity_constraints_indexes.sql`
- `0102_command_infrastructure.sql`
- `0103_identity_rls_helpers.sql` — includes learning-decision authority helper
- `0104_identity_rpcs.sql`

### Locations
- `0200_locations_tables.sql`
- `0201_account_location_preferences.sql`
- `0202_locations_staff_rls_rpcs.sql`
- `0203_location_interests.sql`

### Organizations / Discovery
- `0300_organizations_discovery_tables.sql` — includes Organization public logo
- `0301_organizations_discovery_constraints.sql`
- `0302_organizations_discovery_rls_rpcs.sql`

### Restrictions
- `0350_access_restrictions.sql`
- `0351_access_restriction_rpcs_rls.sql`

### Requests / Enquiries
- unchanged 0400/0401 family; formal learner-side decisions use `can_make_learning_decision`.

### Classes / Files
- `0500_classes_files_tables.sql` — simplified Session state
- `0501_class_capacity_constraints.sql`
- `0502_class_invitation_membership_rpcs.sql` — includes `complete_class`
- `0503_classes_rls.sql` — includes historical access policy

### Class Communication
- `0550_class_communication_tables.sql` — no independent thread lifecycle
- `0551_class_communication_rls_rpcs.sql`

### Activities
- `0600_activities_submissions_tables.sql` — includes `activity_material_links`
- `0601_activities_submissions_rls_rpcs.sql`

### Tests
- unchanged 0700–0703 family.

### Community / Trust
- `0800_community_trust_tables.sql` — includes `reports.context_learner_id`
- `0801_community_trust_rls_rpcs.sql`

### Ads
- unchanged table families except serving selection tests/logic must enforce protected surface exclusion.

### Derived platform operations
- unchanged 1000–1002 family.

---

# 11. First-slice implementation impact

The approved first Foundation + Identity slice is still valid but must include reconciliation changes from this file:

- `auth_user_id` closure-safe nullability;
- no selected-Location FK on Accounts;
- `can_make_learning_decision` helper/authorization tests.

No Location tables are created in the Identity slice.

---

# 12. Gate

Before Supabase execution, the implementation approval record must explicitly state that it approves:

- `10-sql-migration-plan-v1.1.md`; and
- this reconciliation delta.

No later migration may ignore the delta simply because the earlier plan used different wording.