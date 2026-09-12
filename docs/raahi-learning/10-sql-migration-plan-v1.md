# Raahi Learning V1 — SQL Migration Plan

Status: **DRAFT SQL IMPLEMENTATION CONTRACT — no Supabase changes have been made.**

This plan translates `03-database-blueprint-v1.1.md` into PostgreSQL/Supabase migration mechanics. It does not change frozen product behaviour.

## 1. PostgreSQL representation decisions

### IDs and timestamps

- UUID primary keys generated in PostgreSQL (`gen_random_uuid()`).
- `timestamptz` for all event/lifecycle timestamps.
- `created_at default now()`.
- `updated_at` maintained by a small shared trigger where useful.

### Lifecycle/status values

Use **`text` + explicit `CHECK` constraints** for V1 lifecycle/status fields rather than PostgreSQL enums.

Reasons:

- product states may evolve after real usage;
- changing CHECK constraints is simpler/safer than enum surgery;
- values still remain database-constrained, not free-form.

Examples:

```sql
state text not null check (state in ('draft','open','closed'))
```

Use lookup/config tables only for values genuinely managed as business configuration (for example future rate-card definitions), not simple lifecycle states.

### Money

Where Ads commercial snapshots need amounts:

- `numeric(14,2)` for rupee/fiat amount;
- `currency_code text` constrained to a supported set, initially `INR` if that is the only launched currency.

No tuition payment tables are introduced.

---

# 2. Foreign-key / deletion policy

Default for core business/history records: **`ON DELETE RESTRICT` / `NO ACTION`**.

Raahi ends/hides records through business state transitions rather than destructive cascades.

Important exceptions/decisions:

### Supabase auth → Account

`accounts.auth_user_id` should be **nullable after account closure** and reference `auth.users(id) ON DELETE SET NULL`.

Reason: deleting/closing authentication credentials must not destroy Learner/Class/Safety/Audit history owned by the application record.

### Creator/actor historical references

Fields such as `learners.created_by_account_id` that are historical attribution rather than current authority may be nullable with `ON DELETE SET NULL` if Account records are ever physically purged after retention rules. In normal V1 operation Accounts should be lifecycle-closed, not hard-deleted.

### Pure junction/bookmark rows

Low-value derivative relationships such as Saved items or reaction junctions may use `ON DELETE CASCADE` from the bookmark/reaction target only if hard deletion is otherwise allowed. This is convenience cleanup, not business-state behaviour.

### Business child records

Do **not** use blind cascading deletion for:

- Enquiry → Messages;
- Class → Invitations/Memberships/Posts/Activities/Tests;
- Activity → Submissions;
- Test → Attempts;
- Campaign → Revisions/Reviews/Reservations/Placements;
- Reports/Audit evidence.

If a Draft-only object needs true deletion, a guarded command may explicitly remove its child Draft records in a transaction after verifying no business history exists.

---

# 3. Exact high-value unique indexes

The following should be created as database constraints/indexes, not merely application checks.

## Account ↔ Learner Access

```sql
create unique index uq_learner_one_active_self
on account_learner_access (learner_id)
where status = 'active' and access_type = 'self';

create unique index uq_learner_one_active_manager
on account_learner_access (learner_id)
where status = 'active' and access_type = 'manage';
```

These also prevent duplicate active same-type access for the Learner in V1.

## Account capability

```sql
create unique index uq_account_active_capability
on account_capabilities (account_id, capability_code)
where status = 'active';
```

## Organization membership

```sql
create unique index uq_org_active_member
on organization_members (organization_id, account_id)
where status = 'active';
```

## Location staff assignment

```sql
create unique index uq_location_active_staff
on location_staff_assignments (location_id, account_id, staff_type)
where status = 'active';
```

## Scoped restrictions

Use separate subject-specific partial indexes. Treat null Location as platform-wide using a sentinel expression:

```sql
create unique index uq_active_account_restriction
on access_restrictions (
  account_id,
  restriction_scope,
  coalesce(location_id, '00000000-0000-0000-0000-000000000000'::uuid)
)
where state = 'active' and account_id is not null;
```

Equivalent index for Organization restrictions.

## Class Invitation

```sql
create unique index uq_pending_invite_per_learner_class
on class_invitations (class_id, learner_id)
where state = 'pending';
```

The sending command should first expire any stale Pending invite whose `expires_at <= now()` before attempting a new insert.

## Active Membership

```sql
create unique index uq_active_membership_per_learner_class
on class_memberships (class_id, learner_id)
where state = 'active';
```

## Class learner thread

Normal unique constraint:

```sql
unique (class_id, learner_id)
```

## Submission

```sql
unique (activity_id, learner_id)
```

## Test Attempt

V1 single logical attempt:

```sql
unique (test_id, learner_id)
```

## Ads subject uniqueness

Partial unique indexes ensure one Advertising Eligibility row per Account or Organization subject.

## Ads inventory day

```sql
unique (location_id, placement_type, inventory_date)
```

## Ads placement

At minimum unique Campaign + Location + placement type for the Campaign's single requested date range in V1.

---

# 4. XOR ownership CHECK constraints

Use database CHECK constraints for entities with exactly one owner/subject.

Pattern:

```sql
check ((teacher_account_id is not null)::int + (organization_id is not null)::int = 1)
```

Required for at least:

- Teaching Option owner;
- Enquiry provider target;
- Verification subject;
- Advertising Eligibility subject;
- Ad Campaign owner;
- Access Restriction subject.

Cross-table consistency that CHECK cannot express (for example Enquiry Teaching Option owner must equal Enquiry provider) belongs in canonical RPC validation and may have a defense-in-depth trigger where valuable.

---

# 5. Class capacity locking contract

The **Class row is the serialization point** for V1 Class capacity changes.

## `send_class_invitation`

Transaction outline:

1. resolve caller from `auth.uid()`;
2. validate caller is responsible Teacher / authorized Organization actor;
3. `SELECT ... FROM classes WHERE id = p_class_id FOR UPDATE`;
4. verify Class state/capacity and relevant restrictions;
5. mark stale Pending invitations for this Class expired where `expires_at <= now()` (or exclude them from counts and update them in same transaction);
6. count Active Memberships;
7. count Pending Invitations with `expires_at > now()`;
8. reject if adding one would exceed Class capacity;
9. reject duplicate current Pending invite for Learner;
10. insert Pending Invitation with finite expiry;
11. commit, then notify asynchronously.

No separate seat-reservation row is required: the unexpired Pending Invitation is the reservation.

## `accept_class_invitation`

1. lock Invitation and Class rows;
2. verify current Pending state and expiry;
3. verify learner-side actor authority;
4. verify Class remains active/eligible and reservation still valid;
5. ensure no Active duplicate Membership;
6. insert Membership;
7. set Invitation Accepted/resolved;
8. commit atomically.

Because the seat was already reserved on send, acceptance consumes rather than creates additional capacity.

## `decline` / `cancel` / `expire`

Resolve the Invitation state atomically; once no longer Pending, it no longer counts toward reserved capacity.

## `change_class_capacity`

Lock Class, expire stale invites, calculate Active Memberships + unexpired Pending Invitations, and reject a lower capacity beneath that obligation count.

## `transfer_learner`

Lock source and destination Class rows in deterministic UUID order to reduce deadlocks. Verify destination capacity, create destination Membership, and mark source Transferred in one transaction.

---

# 6. Test integrity contract

Direct authenticated client writes to Test definitions, Questions, Choices and Attempt state are prohibited.

## Draft edits

Guarded RPCs may create/edit Test structure only while `definition_locked_at IS NULL`.

## `start_test`

Transaction:

1. derive Account from `auth.uid()`;
2. verify self-access for Learner (management authority alone is insufficient);
3. verify Active Class Membership and Test availability;
4. lock Test row `FOR UPDATE`;
5. if existing Attempt exists, return/resume according to state rather than create another;
6. if first valid Attempt, set `definition_locked_at = coalesce(definition_locked_at, now())`;
7. insert one Attempt under the unique `(test_id, learner_id)` constraint;
8. commit.

## Defense-in-depth Test lock

Question/Choice mutation functions reject any structural change if parent Test is locked.

A trigger should also reject ordinary INSERT/UPDATE/DELETE against Questions/Choices of a locked Test, protecting against accidental privileged SQL paths.

## `correct_answer_key`

Post-lock answer-key correction is the only supported key mutation path:

1. authorize responsible Teacher/exceptional Admin;
2. lock Test;
3. record old/new correctness details in Audit metadata without unnecessary learner data;
4. change the intended answer-key fields only (not prompt/choice structure);
5. identify evaluated Attempts;
6. recalculate affected scores transactionally;
7. audit result correction.

---

# 7. Ads capacity locking contract

Physical inventory uses **daily non-overlapping buckets** even when advertisers buy a 7/14/30-day package.

## `reserve_ad_inventory`

Transaction:

1. derive/authorize advertiser actor;
2. validate Campaign targets, advertiser eligibility and hold policy;
3. resolve every required `ad_inventory_days` row for all selected Locations/placements/dates;
4. sort rows deterministically by `(location_id, placement_type, inventory_date, id)`;
5. lock all resolved inventory-day rows `FOR UPDATE` in that order;
6. treat expired Held reservations as non-capacity and update them to Expired where appropriate;
7. for every day, calculate units belonging to Held-unexpired + Confirmed reservations;
8. apply advertiser concentration/anti-monopoly command rules;
9. if any day lacks capacity, fail the **entire requested reservation**;
10. insert one Reservation header and Reservation-Day rows;
11. commit.

Do not partially reserve an arbitrary subset of dates inside this RPC. Alternative dates/partial-location options must be presented and explicitly chosen before a new reservation command.

## `confirm_ad_inventory`

Lock Reservation and relevant Campaign state; require the configured confirmation conditions (including valid hold, required review/commercial state according to policy) before setting Confirmed.

## `release_ad_inventory`

Idempotently transitions eligible Held/Confirmed reservation according to authorized business rules; Reservation-Day rows remain historical but no longer count toward active capacity after state changes.

---

# 8. Ad revision/serving contract

## Immutable submitted Revision

Once `ad_campaign_revisions.submitted_at` is set, ordinary creative UPDATE/DELETE is prohibited. Material change creates the next Revision.

Use command-only writes plus a defense-in-depth trigger rejecting modification of immutable creative fields after submission.

## Exact review

`ad_reviews.campaign_revision_id` is immutable. Review commands never resolve “latest revision”.

## Exact serving revision

`ad_placements.serving_revision_id` is mandatory before state can become Live.

`set_ad_serving_revision` must verify:

- Revision belongs to same Campaign;
- required Approved review exists for that exact Revision and review scope;
- advertiser eligibility is not blocking Ads;
- Campaign/Placement is otherwise eligible.

A defense-in-depth trigger may enforce same-Campaign ownership and Approved-review existence on insert/update.

Public serving always joins through `serving_revision_id`; never `MAX(revision_number)`.

---

# 9. RLS and RPC classification

The exact SQL policies will be written per migration, but the following ownership model is fixed.

## Public / sanitized read surfaces

Prefer security-barrier views or controlled SELECT policies for:

- Live Locations;
- visible Teacher profiles;
- active/public Organizations;
- discoverable Teaching Options;
- sanitized Open Learning Requests (never raw Learner/private columns);
- published Community content;
- eligible Sponsored creative returned by Ads-serving function/view.

Public/anonymous access should be granted only where the actual UI requires it.

## Relationship-private reads

Raw tables use RLS/helper predicates for:

- Learners and Account↔Learner access;
- Enquiries/Messages;
- Class Invitations;
- Classes/Memberships/Sessions/Materials;
- Class Posts and Class+Learner Threads;
- Activities/Submissions;
- Tests/Attempts;
- Organization private administration.

## Moderation/commercial-private

No broad authenticated reads for:

- Reports/internal moderation notes;
- Scoped restriction details;
- Verification review data;
- Ad Claim Evidence;
- Commercial Clearance;
- Inventory Reservations;
- per-user Ad Frequency state;
- Audit/Idempotency.

## RPC-only / no direct client mutation

At minimum:

- Account↔Learner access transitions;
- privileged Account capabilities;
- scoped restrictions;
- Enquiry lifecycle transitions/messages if message policy requires guarded context;
- Class Invitation lifecycle;
- Membership lifecycle/capacity changes;
- Class+Learner message writes;
- Activity Submission revisions;
- Test definition edits after publication, Attempt lifecycle, result correction;
- Verification decisions;
- Ad review/commercial/inventory/placement transitions;
- Audit and Idempotency internals.

Low-risk profile/preferences may use tightly scoped direct RLS writes if implementation simplicity warrants it, but they must not mutate core operational state.

---

# 10. Authorization helper functions

Create a small private helper schema (for example `app_private`) containing reviewed helper predicates used by RLS/RPCs.

Likely helpers:

- `current_account_id()` — maps `auth.uid()` to application Account;
- `can_act_for_learner(learner_id)`;
- `has_learner_self_access(learner_id)`;
- `has_account_capability(code)`;
- `has_org_capability(org_id, code)`;
- `is_responsible_teacher(class_id)`;
- `can_access_class(class_id, learner_id optional)`;
- `is_location_manager(location_id)`;
- `has_active_restriction(subject, scope, location optional)`;
- `can_review_ad_revision(revision_id)`.

Where helpers are `SECURITY DEFINER`:

- set explicit safe `search_path` inside function;
- owner is a dedicated migration/function owner, not arbitrary client role;
- revoke public execute by default and grant only required roles;
- never trust caller-provided Account IDs when `auth.uid()` can derive actor;
- helper returns minimal boolean/ID output;
- tests must prove no cross-Learner/Organization/Location escalation.

Avoid recursive RLS by carefully choosing helper ownership and table policy structure.

---

# 11. Storage plan

Recommended logical buckets for V1:

## `public-profile-media`

For explicitly public Teacher/Organization profile images only.

Do not place protected learner imagery here by default.

## `learner-private-media`

For Learner avatars/photos that are not public discovery assets.

Access through current learner-side/authorized learning context.

## `class-private`

For Class Materials and Submission uploads.

Object path should include a non-authoritative identifier for organization only; authorization still derives from linked DB record + current Class/Learner permission.

## `community-public`

For moderated Community attachments intended to be public within Community visibility rules.

## `ads-public`

For approved Sponsored creative intended for public serving.

## `ads-review-private`

For Claim Evidence and other private review material.

Private buckets use authenticated/signed access. A copied path is not sufficient permission.

The `file_assets` table stores business-linked metadata; bucket/path alone does not decide authorization.

---

# 12. Idempotency contract

Human command requests supply an unpredictable operation key (UUID recommended).

Table rules:

- partial unique index for human commands on `(actor_account_id, command_name, idempotency_key)` where actor Account is not null;
- separate unique rule for System operations where actor is null, using deterministic `(command_name, idempotency_key)`.

RPC behaviour:

1. calculate request fingerprint from normalized material inputs;
2. claim the key inside the same transaction as domain mutation;
3. on existing key:
   - same fingerprint + completed result → return stored result;
   - different fingerprint → reject misuse;
   - concurrent in-progress operation → serialize/wait/retry safely;
4. domain mutation and recorded command result commit together.

Retention should exceed normal mobile/network retry windows; exact cleanup period remains operational configuration rather than product behaviour.

Mandatory commands include Invitation send/accept, Transfer, Submission, Test start/submit, Ad revision submission/review where retried, Ads inventory reserve/confirm/release, and Commercial Clearance confirmation.

---

# 13. Audit contract

`audit_log` is append-oriented and writable only by trusted RPC/internal paths.

Supports:

- `actor_kind = account | system`;
- nullable `actor_account_id` when System;
- action type;
- target type/id;
- optional Learner/Organization/Location scope;
- reason where required;
- carefully limited JSON metadata;
- timestamp.

Never store in generic audit metadata:

- passwords/tokens;
- full message bodies by default;
- unnecessary child/private profile data;
- full private evidence files.

Audit must not become the primary source of domain state.

---

# 14. Read projections / views

Plan dedicated read surfaces for the high-value UI queries:

1. `public_teacher_discovery_v` — visible teacher + Teaching Option + Location/verification summaries without private account data.
2. `public_learning_requests_v` — sanitized Open Requests with only safe need context.
3. `my_classes_v` — authorized Account/Learner Class summaries, including “For Rahul” context.
4. `class_feed_v` or authorized function — private Class posts/announcements/questions.
5. `location_community_feed_v` — published Community content for selected Location.
6. `eligible_sponsored_candidates(...)` — server-controlled Sponsored candidate selection using Placement/Revision/current eligibility; not organic ranking.
7. `advertiser_campaign_metrics_v` — aggregate Placement/day metrics, never named viewer/frequency data.

Views do not own business truth; commands and base relational state do.

---

# 15. Migration file sequence

Use small versioned migrations rather than one schema dump. Suggested naming:

### Foundation
- `0001_extensions_helpers.sql`
- `0002_common_updated_at.sql`

### Identity
- `0100_identity_tables.sql`
- `0101_identity_constraints_indexes.sql`
- `0102_identity_rls_helpers.sql`
- `0103_identity_rpcs.sql`

### Locations / restrictions
- `0200_locations_restrictions_tables.sql`
- `0201_locations_restrictions_rls_rpcs.sql`

### Organizations / discovery
- `0300_organizations_discovery_tables.sql`
- `0301_organizations_discovery_constraints.sql`
- `0302_organizations_discovery_rls_rpcs.sql`

### Requests / Enquiries
- `0400_requests_enquiries_tables.sql`
- `0401_requests_enquiries_rls_rpcs.sql`

### Classes / files
- `0500_classes_files_tables.sql`
- `0501_class_capacity_constraints.sql`
- `0502_class_invitation_membership_rpcs.sql`
- `0503_classes_rls.sql`

### Class feed / contextual messaging
- `0550_class_communication_tables.sql`
- `0551_class_communication_rls_rpcs.sql`

### Activities
- `0600_activities_submissions_tables.sql`
- `0601_activities_submissions_rls_rpcs.sql`

### Tests
- `0700_tests_attempts_tables.sql`
- `0701_test_definition_guards.sql`
- `0702_test_attempt_rpcs.sql`
- `0703_tests_rls.sql`

### Community / Trust
- `0800_community_trust_tables.sql`
- `0801_community_trust_rls_rpcs.sql`

### Ads campaign/review/commercial
- `0900_ads_campaign_tables.sql`
- `0901_ads_review_commercial_rpcs.sql`
- `0902_ads_campaign_rls.sql`

### Ads inventory/serving
- `0950_ads_inventory_tables.sql`
- `0951_ads_inventory_rpcs.sql`
- `0952_ads_serving_revision_guards.sql`
- `0953_ads_frequency_metrics_rls.sql`

### Platform operations
- `1000_notifications_idempotency_audit.sql`
- `1001_read_projections.sql`
- `1002_final_privilege_hardening.sql`

Migration numbering leaves room for forward fixes without rewriting history once execution begins.

---

# 16. Tests required before each slice is accepted

## Identity

- one active self / one active manager constraints;
- sibling isolation;
- parent acting for learner without becoming learner;
- privilege escalation attempts fail.

## Classes

- invitation reserve race;
- double send/accept retry;
- expiry release;
- capacity reduction guard;
- transfer atomicity;
- copied Class/file URL denial;
- contextual thread access after management change.

## Activities

- parent-assisted ownership;
- revision retry/idempotency;
- other learner cannot read Submission.

## Tests

- first attempt locks definition;
- normal structural edit blocked after lock;
- start/submit retries;
- parent cannot take child Test;
- answer-key correction audit + recalculation.

## Safety

- discovery-only restriction does not destroy Class Membership;
- Class-access restriction blocks only intended surface/scope;
- Report remains independent of Block.

## Ads

- exact revision review;
- exact serving Revision;
- overlapping package date race cannot oversell daily bucket;
- stale availability fails;
- Commercial Clearance cannot override rejection;
- Location pause independent serving;
- frequency state invisible to advertiser;
- Ads cannot alter organic ranking.

---

# 17. Forward-fix / rollback philosophy

Before production data exists, an unexecuted migration may be edited during review.

Once a migration has been applied to a shared/production environment:

- do not rewrite migration history;
- create a forward corrective migration;
- rollback only when it is demonstrably safer and data-loss semantics are understood;
- business-state rollback must not erase audit/safety/history evidence.

Schema change and product behaviour change are separate review decisions.

---

# 18. Remaining pre-Supabase decisions

The SQL plan is now specific enough that no further product modelling is required before implementation.

The following are operational/configuration values and can remain configurable until migration execution/testing:

- exact Class Invitation expiry duration;
- exact Ads inventory hold duration;
- exact Ads frequency caps/window length;
- initial Ads rate-card values;
- idempotency retention duration;
- notification retention;
- detailed Community posting eligibility policy.

These values do not require new entities or lifecycles.

## Gate

**Do not connect or mutate Supabase until this SQL Migration Plan is reviewed once against the frozen documents and explicitly approved for implementation.**

After approval, the first implementation slice should be only Foundation + Identity, with tests, before moving to Locations or Discovery.