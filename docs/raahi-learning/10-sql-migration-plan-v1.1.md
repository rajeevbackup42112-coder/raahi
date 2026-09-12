# Raahi Learning V1 — SQL Migration Plan v1.1

Status: **CORRECTED IMPLEMENTATION PLAN — ready for final approval review; Supabase remains untouched.**

This document supersedes `10-sql-migration-plan-v1.md` for future implementation planning and incorporates `11-sql-migration-plan-review-v1.md`.

It translates `03-database-blueprint-v1.1.md` into PostgreSQL/Supabase mechanics without changing frozen product behaviour.

---

# 1. Core PostgreSQL decisions

## IDs / time

- UUID PKs via `gen_random_uuid()`.
- `timestamptz` for lifecycle/event timestamps.
- `created_at default now()`.
- shared `updated_at` trigger only on mutable tables that need it.

## States

Use `text` + explicit `CHECK` constraints rather than PostgreSQL enums for V1 lifecycle values.

Reason: states remain DB-constrained while future product evolution does not require enum migration surgery.

## Money

Ads commercial snapshots use `numeric(14,2)` + constrained currency code; initially INR where applicable.

No tuition-payment schema.

---

# 2. FK / deletion policy

Default core behaviour: `ON DELETE RESTRICT` / `NO ACTION`.

Raahi normally closes/hides state rather than physically deleting business history.

Key decisions:

- `accounts.auth_user_id` may be nullable and reference `auth.users(id) ON DELETE SET NULL` so credential removal cannot destroy application history.
- historical creator/actor references may use nullable `SET NULL` only where current authorization does not depend on them.
- pure bookmark/reaction junctions may cascade if the target is ever legitimately hard-deleted.
- no blind cascade across Enquiries/Messages, Classes/Memberships, Activities/Submissions, Tests/Attempts, Campaign/Revisions/Reviews/Reservations/Placements, Reports or Audit.

Draft-only deletion, where allowed, must happen through guarded commands after proving no business history exists.

---

# 3. Cross-module dependency decisions

## Selected Location preference

Do **not** place the selected-Location FK in the first Account migration.

Create after Locations:

`account_location_preferences(account_id pk/fk accounts, selected_location_id fk locations, updated_at)`.

This is a UI preference only; changing it never changes existing relationships.

## Scoped Restrictions

General `access_restrictions` is created only after Accounts + Locations + Organizations exist because its subject may be Account or Organization and scope may be Location.

## Sponsored Enquiry attribution

Create core Enquiries without `source_campaign_id`.

During Ads campaign migration add nullable Campaign attribution FK with `ALTER TABLE enquiries ...`.

Core learning therefore does not depend on Ads being installed first.

## Audit / Idempotency

Create Audit + Idempotency **before the first consequential Identity RPCs**, not at the end of the project.

Notifications remain late because they are derived side effects.

---

# 4. Required partial/unique indexes

At minimum:

```sql
create unique index uq_learner_one_active_self
on account_learner_access (learner_id)
where status='active' and access_type='self';

create unique index uq_learner_one_active_manager
on account_learner_access (learner_id)
where status='active' and access_type='manage';

create unique index uq_account_active_capability
on account_capabilities (account_id, capability_code)
where status='active';

create unique index uq_org_active_member
on organization_members (organization_id, account_id)
where status='active';

create unique index uq_location_active_staff
on location_staff_assignments (location_id, account_id, staff_type)
where status='active';

create unique index uq_pending_invite_per_learner_class
on class_invitations (class_id, learner_id)
where state='pending';

create unique index uq_active_membership_per_learner_class
on class_memberships (class_id, learner_id)
where state='active';
```

Normal unique constraints also cover:

- Class+Learner contextual thread;
- Activity+Learner logical Submission;
- Test+Learner V1 Attempt;
- Ads Location+placement+date inventory bucket;
- Saved relationships;
- Blocks;
- Ads Campaign Target tuple.

Scoped restriction active uniqueness uses subject-specific partial unique indexes and a null-Location normalization strategy.

Advertising Eligibility uses separate partial unique subject indexes for Account and Organization.

---

# 5. XOR constraints

Use CHECK constraints where exactly one owner/subject is valid.

Pattern:

```sql
check (((a_id is not null)::int + (b_id is not null)::int) = 1)
```

Apply to:

- Teaching Option owner;
- Enquiry provider target;
- Verification subject;
- Advertising Eligibility subject;
- Campaign owner;
- Access Restriction subject.

Cross-table semantic consistency remains command-enforced, e.g. Enquiry's Teaching Option must belong to the provider target.

---

# 6. Class capacity transaction contract

Use the **Class row as the serialization point**.

## Send Invitation

1. derive actor from `auth.uid()`;
2. authorize responsible Teacher/Organization authority;
3. lock Class row `FOR UPDATE`;
4. expire/ignore stale Pending Invitations whose expiry passed;
5. count Active Memberships + unexpired Pending Invitations;
6. reject if adding one exceeds capacity;
7. reject duplicate Pending Invitation for same Learner/Class;
8. insert Pending Invitation with finite `expires_at`;
9. commit; notify afterward.

The Pending Invitation itself is the V1 seat reservation.

## Accept Invitation

Lock Invitation + Class; validate current Pending/unexpired state and learner-side authority; create exactly one Active Membership; resolve Invitation Accepted atomically.

## Decline/Cancel/Expire

Resolve state atomically. Once not Pending, it no longer consumes reserved capacity.

## Change capacity

Lock Class and reject any capacity below Active Memberships + valid Pending Invitations.

## Transfer

Lock source + destination Classes in deterministic UUID order. Destination Membership creation and source `Transferred` state commit atomically.

---

# 7. Test definition / Attempt contract

Direct client writes to Test definition, Questions, Choices and Attempt lifecycle are prohibited.

## Start Test

Lock Test; verify learner self-access, Active Membership and availability; return existing valid Attempt on retry; set `definition_locked_at` no later than first valid Attempt; create one Attempt under unique `(test_id, learner_id)`.

## Post-lock editing

After lock:

- Question insert/delete blocked;
- question prompt/points/structure change blocked;
- Choice insert/delete blocked;
- Choice text change blocked;
- ordinary `is_correct` update blocked by permissions.

Use a structural guard trigger/function as defense-in-depth.

## Correct answer key

`correct_answer_key` is a dedicated privileged RPC that may change only the answer-key correctness fields. It:

- locks Test;
- records old/new key in Audit metadata;
- updates correctness;
- recalculates affected evaluated Attempts transactionally;
- does not alter prompt/choice structure.

Do **not** dynamically disable triggers to perform the correction.

---

# 8. Ads inventory contract

Physical capacity uses overlap-safe daily rows:

`Location × placement_type × inventory_date × capacity`.

Advertisers may still buy 7/14/30-day packages.

## Reserve inventory

1. authorize advertiser;
2. validate Campaign targets and hold policy;
3. resolve every daily row needed across all selected Locations/placements/dates;
4. sort rows deterministically;
5. lock all daily rows `FOR UPDATE` in that order;
6. expire/exclude stale Holds;
7. sum Held-unexpired + Confirmed units per day;
8. apply anti-monopoly/concentration policy;
9. if any required day lacks capacity, fail the whole request;
10. insert Reservation header + Reservation-Day rows atomically.

Partial alternative dates/Locations require a new user-approved request; never silently partially book a campaign.

## Confirm / Release

Confirmation revalidates hold + configured approval/commercial requirements. Release is idempotent and historical Reservation-Day rows remain for audit/history but stop counting after Reservation state changes.

---

# 9. Ads exact-revision contract

Submitted Campaign Revision creative becomes immutable.

Review points to exact Revision.

Every Ad Placement has explicit `serving_revision_id`.

`set_ad_serving_revision` verifies:

- Revision belongs to Campaign;
- exact Revision has required Approved review scope;
- advertiser/Campaign/Placement remains eligible.

Public serving joins by `serving_revision_id` only. Never render “latest Revision”.

Defense-in-depth trigger may verify same-Campaign + approved review on Placement revision changes.

---

# 10. RLS / RPC model

## Public/sanitized reads

Use controlled views/policies for:

- Live Locations;
- visible Teacher/Organization profiles;
- discoverable Teaching Options;
- sanitized Open Learning Requests;
- published Community;
- eligible Sponsored creative.

## Relationship-private reads

RLS/helper checks for:

- Learners / learner access;
- Enquiries/Messages;
- Classes/Invitations/Memberships/Sessions/Materials;
- Class Posts + contextual Class/Learner threads;
- Activities/Submissions;
- Tests/Attempts;
- Organization administration.

## Moderation/commercial private

No broad authenticated reads for:

- Reports/internal moderation;
- sensitive Restriction reasons;
- private Verification review data;
- Ad Claim Evidence;
- Commercial Clearance;
- Inventory Reservations;
- per-user Ad Frequency state;
- Audit/Idempotency internals.

## RPC-only consequential writes

At minimum:

- learner access transitions;
- privileged capabilities;
- scoped restrictions;
- Enquiry lifecycle/context messaging;
- Class invitation/Membership/capacity transitions;
- Class learner messages;
- Submission revisions;
- Test structure/Attempt/result correction;
- Verification decisions;
- Ads review/commercial/inventory/placement;
- Audit/Idempotency.

Low-risk account/profile preference writes may use tightly scoped RLS if convenient.

---

# 11. SECURITY DEFINER discipline

Use a private helper schema such as `app_private`.

Likely helpers:

- current Account from `auth.uid()`;
- can act for Learner;
- learner self-access;
- Account capability;
- Organization capability;
- responsible Teacher/Class access;
- Location Manager scope;
- active scoped restriction;
- Ad review authority.

For every `SECURITY DEFINER` function:

- explicit fixed safe `search_path`;
- minimal object privileges;
- derive actor from `auth.uid()` rather than trusting caller Account ID;
- re-check relationships inside transaction;
- minimal return data;
- revoke default/public execute and explicitly grant only intended roles;
- automated privilege-escalation tests.

---

# 12. Storage plan

Logical V1 buckets:

- `public-profile-media` — deliberately public Teacher/Organization assets only;
- `learner-private-media` — protected Learner avatars/photos;
- `class-private` — Materials and Submission uploads;
- `community-public` — intended public Community attachments;
- `ads-public` — Sponsored creative;
- `ads-review-private` — Claim Evidence.

`file_assets` metadata links storage objects to business context. A copied path/URL is never sufficient permission for private assets.

Private retrieval uses authenticated authorization/signed access based on the current business relationship, not uploader identity alone.

---

# 13. Idempotency contract

Create command infrastructure before early RPCs.

Human operations use unique `(actor_account_id, command_name, idempotency_key)`; System jobs use deterministic system operation keys.

Inside the same domain transaction:

1. normalize material inputs and compute request fingerprint;
2. claim operation key;
3. same key + same fingerprint + completed → return stored result;
4. same key + different fingerprint → reject;
5. concurrent in-progress same key → serialize/wait safely;
6. domain outcome + idempotency result commit together.

Priority: Invitation send/accept, Transfer, Submission, Test start/submit, Ads revision/review, inventory reserve/confirm/release, Commercial Clearance.

---

# 14. Audit contract

Create Audit before consequential Identity RPCs.

Append-oriented, internal/RPC-only.

Supports Account or System actor, action, target, optional Learner/Organization/Location scope, reason and minimal metadata.

Never put secrets/full messages/unnecessary child data into generic audit metadata.

---

# 15. Secure read projections

Plan/read-test:

- `public_teacher_discovery_v`;
- `public_learning_requests_v`;
- `my_classes_v` with Learner context;
- private Class feed projection/function;
- Location Community feed;
- Sponsored candidate selection function/view separate from organic ranking;
- advertiser aggregate Placement/day metrics.

Views are projections only, never command authority.

---

# 16. Final migration sequence

## Foundation / Identity

- `0001_extensions_helpers.sql`
- `0002_common_updated_at.sql`
- `0100_identity_tables.sql`
- `0101_identity_constraints_indexes.sql`
- `0102_command_infrastructure.sql` — Audit + Idempotency
- `0103_identity_rls_helpers.sql`
- `0104_identity_rpcs.sql`

## Locations

- `0200_locations_tables.sql`
- `0201_account_location_preferences.sql`
- `0202_locations_staff_rls_rpcs.sql`

## Organizations / Discovery

- `0300_organizations_discovery_tables.sql`
- `0301_organizations_discovery_constraints.sql`
- `0302_organizations_discovery_rls_rpcs.sql`

## Scoped Restrictions

- `0350_access_restrictions.sql`
- `0351_access_restriction_rpcs_rls.sql`

## Requests / Enquiries

- `0400_requests_enquiries_tables.sql`
- `0401_requests_enquiries_rls_rpcs.sql`

No Ads FK yet.

## Classes / Files

- `0500_classes_files_tables.sql`
- `0501_class_capacity_constraints.sql`
- `0502_class_invitation_membership_rpcs.sql`
- `0503_classes_rls.sql`

## Class Communication

- `0550_class_communication_tables.sql`
- `0551_class_communication_rls_rpcs.sql`

## Activities

- `0600_activities_submissions_tables.sql`
- `0601_activities_submissions_rls_rpcs.sql`

## Tests

- `0700_tests_attempts_tables.sql`
- `0701_test_definition_guards.sql`
- `0702_test_attempt_rpcs.sql`
- `0703_tests_rls.sql`

## Community / Trust

- `0800_community_trust_tables.sql`
- `0801_community_trust_rls_rpcs.sql`

## Ads Campaign / Review / Commercial

- `0900_ads_campaign_tables.sql`
- `0901_add_sponsored_enquiry_attribution.sql` — adds `enquiries.source_campaign_id`
- `0902_ads_review_commercial_rpcs.sql`
- `0903_ads_campaign_rls.sql`

## Ads Inventory / Serving

- `0950_ads_inventory_tables.sql`
- `0951_ads_inventory_rpcs.sql`
- `0952_ads_serving_revision_guards.sql`
- `0953_ads_frequency_metrics_rls.sql`

## Derived platform operations

- `1000_notifications.sql`
- `1001_read_projections.sql`
- `1002_final_privilege_hardening.sql`

---

# 17. Slice acceptance requirements

No slice is considered complete until it has:

- migrations;
- constraints/indexes;
- canonical RPCs;
- RLS/read policies;
- idempotency where required;
- concurrency tests where required;
- Given/When/Then regression tests;
- privilege-escalation tests;
- storage tests where applicable.

Especially prove:

### Identity

- one active self/manager;
- siblings isolated;
- parent acts for Learner without becoming Learner.

### Classes

- invitation reservation race;
- duplicate retry;
- expiry release;
- capacity reduction guard;
- Transfer atomicity;
- copied Class/file URLs fail without current authorization;
- Class learner thread access follows current Learner authority.

### Tests

- first Attempt locks definition;
- structural edits fail after lock;
- answer-key correction is explicit/audited;
- retry does not create second Attempt/submission;
- parent cannot take child's Test.

### Restrictions

- discovery-only restriction does not end Class Membership;
- Class/messaging restriction affects only intended scope;
- Ads-only restriction does not destroy learning history.

### Ads

- overlapping packages cannot oversell same day;
- deterministic locking prevents race/deadlock pattern;
- exact Review Revision;
- exact serving Revision;
- stale availability fails;
- payment cannot override rejection;
- per-Location serving independent;
- frequency records never advertiser-readable;
- paid system cannot affect organic rank.

---

# 18. Forward-fix rule

Before execution, draft migrations may change during review.

After any migration is applied to a shared/production environment:

- never rewrite migration history;
- use forward corrective migrations;
- rollback only with explicit data/history consequences understood;
- never erase required safety/audit/shared history merely to make schema rollback easier.

---

# 19. Remaining configurable values

These do not block implementation design and do not require new entities:

- default Class Invitation expiry duration;
- Ads inventory hold duration;
- Ads frequency cap/window;
- Ads rate-card values;
- idempotency retention duration;
- notification retention;
- detailed Community posting eligibility policy.

They should be configuration/policy, not hard-coded product architecture.

---

# Final implementation gate

This plan is now internally consistent with the physical blueprint review and migration dependency order.

**Supabase must still not be touched until this v1.1 plan receives one final cross-document approval pass.**

Once approved, implement only the first controlled slice:

> Foundation + Identity

Run its migration/RLS/RPC/concurrency/authorization tests before creating the Locations slice.