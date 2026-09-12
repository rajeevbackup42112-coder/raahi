# Raahi Learning V1 — Physical Database Blueprint

Status: **DRAFT FOR REVIEW. Do not deploy to Supabase yet.**

This is a proposed PostgreSQL-compatible schema derived from the frozen product/domain/architecture rules. Table/column names may still change during review. The purpose is to catch contradictions **before** implementation.

If Supabase is selected, `accounts.auth_user_id` can reference `auth.users.id`, RLS can enforce read boundaries, and business writes should still use canonical RPC/functions rather than direct table mutation.

## Conventions

- Primary keys: UUID unless there is a clear reason otherwise.
- Timestamps: `timestamptz`.
- Soft/domain ending is represented by explicit lifecycle state/reason, not broad `deleted_at` everywhere.
- Significant destructive user requests may hide records from normal UI while preserving required shared/audit/safety history.
- State values may use PostgreSQL enums or constrained text; prefer migrations that allow deliberate evolution.
- Every business table should have `created_at`; use `updated_at` where mutable.

---

# 1. Identity & access

## `accounts`

Purpose: application profile corresponding to an authenticated human.

Proposed fields:

- `id uuid pk`
- `auth_user_id uuid unique not null` (Supabase: `auth.users.id`)
- `display_name text not null`
- `avatar_type text` (`builtin`, `upload`, `none`)
- `avatar_ref text null`
- `account_status text not null default 'active'`
- `created_at`, `updated_at`

Do **not** add one permanent `role` column such as learner/parent/teacher. Capabilities come from relationships below.

## `learners`

Purpose: person whose learning record is owned by the learner, independent of who logs in.

- `id uuid pk`
- `display_name text not null`
- `created_by_account_id fk accounts`
- optional age/safety attributes only if product/compliance requires them (do not over-collect)
- `created_at`, `updated_at`

## `account_learner_access`

Purpose: who may act for which Learner.

- `account_id fk accounts`
- `learner_id fk learners`
- `access_type text` (`self`, `manage`)
- `status text` (`active`, `ended`)
- `granted_at`, `ended_at`
- composite PK/unique active constraint as appropriate

V1 business rule: at most one active `manage` relationship per learner unless product rules are deliberately expanded later.

## `organizations`

- `id uuid pk`
- `organization_type` (`school`, `university`, `college`, `coaching`, `academy`, `other_education`)
- `name`
- `description`
- public contact/location fields allowed by policy
- `status`
- `created_at`, `updated_at`

## `organization_members`

- `organization_id fk organizations`
- `account_id fk accounts`
- `membership_status`
- `capability_set` (normalized role/capability mapping preferred over arbitrary JSON if permissions become rich)
- `created_at`, `ended_at`

Campaigns/classes belong to the Organization, not to whichever employee created them.

---

# 2. Locations & local authority

## `locations`

- `id uuid pk`
- `name`
- `slug unique`
- `region/state/country`
- optional geographic coverage metadata
- `state` (`preparing`, `live`, `paused`, `retired`)
- `created_at`, `updated_at`

## `location_staff_assignments`

- `location_id fk locations`
- `account_id fk accounts`
- `staff_type` (`local_manager` initially)
- `status`
- `created_at`, `ended_at`

All Local Manager commands must scope through this relationship.

---

# 3. Teacher/provider discovery

## `teacher_profiles`

One-to-one public teaching profile for an individual Account that teaches.

- `account_id pk/fk accounts`
- `headline`
- `bio`
- `experience_summary`
- public profile fields permitted by policy
- `visibility_status`
- `created_at`, `updated_at`

Organization public profile lives in `organizations`; do not duplicate it as a teacher profile.

## `teaching_options`

User-facing “What I Teach”. Exactly one owner: individual teacher OR Organization.

- `id uuid pk`
- `teacher_account_id fk accounts null`
- `organization_id fk organizations null`
- CHECK exactly one owner is non-null
- `title`
- `category text null` (discovery aid, never limits free-text learning)
- `description`
- `teaching_mode` (`online`, `in_person`, `both`)
- optional `fee_display_text`
- `availability_status` (`taking_new_learners`, `not_taking_new_learners`, `no_longer_offered`)
- `created_at`, `updated_at`

## `teaching_option_locations`

- `teaching_option_id fk teaching_options`
- `location_id fk locations`
- composite unique key

If fee/schedule/venue differs materially by Location, create separate Teaching Options rather than hidden per-Location variants.

## `saved_teaching_options`

- `account_id fk accounts`
- `teaching_option_id fk teaching_options`
- `created_at`
- unique `(account_id, teaching_option_id)`

## `saved_organizations`

- `account_id fk accounts`
- `organization_id fk organizations`
- `created_at`
- unique `(account_id, organization_id)`

Saving is private and creates no relationship.

---

# 4. Learning Requests & Enquiries

## `learning_requests`

- `id uuid pk`
- `learner_id fk learners`
- `created_by_account_id fk accounts`
- `location_id fk locations`
- `title/need_text`
- optional `category`
- `mode_preference`
- `details`
- optional `timing_preference`
- `state` (`draft`, `open`, `closed`)
- `close_reason null`
- `created_at`, `updated_at`, `closed_at`

Public projections must sanitize learner identity/private data.

## `enquiries`

One controlled relationship context. Exactly one provider target: individual teacher OR Organization.

- `id uuid pk`
- `learner_id fk learners`
- `created_by_account_id fk accounts`
- `provider_account_id fk accounts null`
- `provider_organization_id fk organizations null`
- CHECK exactly one provider target
- `teaching_option_id fk teaching_options null`
- `learning_request_id fk learning_requests null`
- `source_type` (`direct`, `learning_request`, `sponsored`)
- `source_campaign_id fk ad_campaigns null` (added after Ads table exists)
- `state` (`pending`, `active`, `closed`)
- `close_reason null`
- `created_at`, `activated_at`, `closed_at`

Recommended integrity: prevent more than one Pending/Active Enquiry for the exact same learner + provider + same discovery context unless business meaning differs.

## `enquiry_messages`

- `id uuid pk`
- `enquiry_id fk enquiries`
- `sender_account_id fk accounts`
- `body text`
- `message_type` (`text`, `system`, controlled structured message types)
- `created_at`

No unrestricted public DM table outside permitted contexts.

## `enquiry_trial_events`

Lightweight implementation table, not a separate relationship domain.

- `id uuid pk`
- `enquiry_id fk enquiries`
- `proposed_by_account_id`
- `scheduled_at`
- `status` (`proposed`, `scheduled`, `cancelled`, `completed`)
- `created_at`, `updated_at`

---

# 5. Classes

## `classes`

- `id uuid pk`
- `responsible_teacher_account_id fk accounts`
- `organization_id fk organizations null`
- `location_id fk locations null`
- `title`
- `class_type` (`one_to_one`, `group`)
- `capacity integer not null` (1 for 1:1)
- `state` (`draft`, `active`, `past`)
- `created_at`, `updated_at`

Constraint: `capacity >= 1`.

## `class_invitations`

- `id uuid pk`
- `class_id fk classes`
- `learner_id fk learners`
- `invited_by_account_id fk accounts`
- `state` (`pending`, `accepted`, `declined`, `expired`, `cancelled`)
- `expires_at null`
- `seat_reserved_until null`
- `created_at`, `resolved_at`

Recommended partial unique constraint: one Pending invitation for same Class + Learner.

Invitation acceptance must happen only through an atomic command that protects capacity.

## `class_memberships`

- `id uuid pk`
- `class_id fk classes`
- `learner_id fk learners`
- `state` (`active`, `completed`, `left`, `transferred`, `removed`)
- `joined_via_invitation_id fk class_invitations null`
- `joined_at`
- `ended_at null`
- `end_reason null`
- `transferred_to_membership_id fk class_memberships null`

Recommended partial unique index: at most one Active Membership for `(class_id, learner_id)`.

No separate Enrollment table.

## `class_sessions`

- `id uuid pk`
- `class_id fk classes`
- `starts_at`, `ends_at null`
- `delivery_mode`
- controlled meeting/location details
- `status` (`scheduled`, `cancelled`, `completed` if needed)
- `created_at`, `updated_at`

Keep lightweight; no attendance subsystem in V1.

## `materials`

- `id uuid pk`
- `created_by_account_id`
- `title`
- `description`
- `resource_type`
- `file_or_link_ref`
- `created_at`, `updated_at`

## `material_class_links`

- `material_id fk materials`
- `class_id fk classes`
- unique pair

File access must re-check authorized Class audience.

---

# 6. Activities & submissions

## `activities`

- `id uuid pk`
- `class_id fk classes`
- `created_by_account_id`
- `display_type` (`assignment`, `practice`, `exercise`)
- `title`
- `instructions`
- `due_at null`
- `submission_required boolean`
- `state` (`draft`, `open`, `closed`)
- `created_at`, `updated_at`

## `submissions`

One logical learner submission per Activity.

- `id uuid pk`
- `activity_id fk activities`
- `learner_id fk learners`
- `current_status` (`submitted`, `changes_requested`, `reviewed`)
- `created_at`, `updated_at`
- unique `(activity_id, learner_id)` unless business later permits multiple independent submissions

## `submission_revisions`

- `id uuid pk`
- `submission_id fk submissions`
- `revision_number integer`
- `performed_by_account_id fk accounts` (who uploaded/entered it)
- textual/file payload references
- `submitted_at`
- unique `(submission_id, revision_number)`

Ownership remains with the Learner even if parent performed the upload.

---

# 7. Tests & attempts

## `tests`

- `id uuid pk`
- `class_id fk classes`
- `created_by_account_id`
- `title`
- `instructions`
- `available_from null`
- `closes_at null`
- `duration_seconds null`
- `state` (`draft`, `available`, `closed`)
- `results_visible boolean default false`
- `created_at`, `updated_at`

## `test_questions`

- `id uuid pk`
- `test_id fk tests`
- `position integer`
- `question_type` (V1 primarily MCQ)
- `prompt`
- `points`
- unique `(test_id, position)`

## `test_choices`

- `id uuid pk`
- `question_id fk test_questions`
- `position`
- `choice_text`
- `is_correct` (teacher/private access only)

## `test_attempts`

- `id uuid pk`
- `test_id fk tests`
- `learner_id fk learners`
- `state` (`in_progress`, `submitted`, `evaluated`, `invalidated`)
- `started_at`, `submitted_at`, `evaluated_at`
- `score null`
- `invalidation_reason null`

V1 default: at most one logical attempt per Learner/Test unless test policy explicitly permits retries. Use unique/partial constraints accordingly.

## `test_attempt_answers`

- `attempt_id fk test_attempts`
- `question_id fk test_questions`
- selected choice / response payload
- `saved_at`
- unique `(attempt_id, question_id)`

Answer-key correction/result recalculation must be audited.

---

# 8. Community

## `community_posts`

- `id uuid pk`
- `location_id fk locations`
- `author_account_id fk accounts`
- `post_type`
- `body`
- optional approved attachment/link refs
- `visibility_status` (`published`, `hidden`, `removed`)
- `created_at`, `updated_at`

## `community_comments`

- `id uuid pk`
- `post_id fk community_posts`
- `author_account_id`
- `body`
- `visibility_status`
- `created_at`, `updated_at`

## `community_reactions`

- `post_id` or `comment_id` (implementation choice; prefer FK-safe typed tables if practical)
- `account_id`
- reaction type from positive/contextual set such as Helpful/Thanks/Interested
- unique actor + target + reaction according to product rule

No public downvote model.

---

# 9. Trust, safety & verification

## `verification_claims`

- `id uuid pk`
- subject exactly one of `account_id` / `organization_id`
- `claim_type`
- `status` (`pending`, `verified`, `revoked`, `rejected`)
- `verified_at`, `verified_by_account_id`
- public label derived from exact claim type

Never infer generic “Verified Teacher”.

## `reports`

- `id uuid pk`
- `reporter_account_id`
- `target_type`
- `target_id`
- `reason_code`
- `details`
- `status`
- `created_at`, `resolved_at`

Generic target references require command-layer validation. If FK integrity becomes more valuable, split into typed report-target junctions.

## `blocks`

V1 account-level contact block:

- `blocker_account_id`
- `blocked_account_id`
- `created_at`
- unique pair

Block does not erase Class/history/report evidence and is not equivalent to Leave Class.

---

# 10. Ads

## `advertising_eligibility`

Exactly one subject: Account or Organization.

- `id uuid pk`
- `account_id null`
- `organization_id null`
- CHECK exactly one subject
- `state` (`not_enabled`, `under_review`, `enabled`, `restricted`, `disabled`)
- `reason null`
- `updated_at`

## `ad_campaigns`

- `id uuid pk`
- owner exactly one of `account_id` / `organization_id`
- `objective` (`admissions`, `course_batch`, `event`, `awareness`)
- `campaign_name`
- requested `starts_at`, `ends_at`
- `state` (`draft`, `submitted`, `closed`, `archived` if long-term operational history truly needs it; otherwise omit archive in UI)
- `created_at`, `updated_at`

One V1 campaign uses one promotion/message across selected Locations. Materially different local copy = separate Campaign.

## `ad_campaign_revisions`

- `id uuid pk`
- `campaign_id fk ad_campaigns`
- `revision_number`
- headline/body/image/destination/CTA payload
- `submitted_at null`
- immutable after submission/approval except by creating a new revision
- unique `(campaign_id, revision_number)`

## `ad_reviews`

- `id uuid pk`
- `campaign_revision_id fk ad_campaign_revisions`
- `reviewer_account_id`
- `review_scope` (`local`, `platform`)
- `state` (`under_review`, `evidence_requested`, `changes_requested`, `approved`, `rejected`)
- `reason/details`
- `created_at`, `decided_at`

Review always points to exact revision.

## `ad_claim_evidence`

- `id uuid pk`
- `campaign_revision_id fk ad_campaign_revisions`
- evidence file/link ref
- `submitted_by_account_id`
- `created_at`

Private to authorized advertiser/review roles.

## `ad_commercial_clearances`

- `id uuid pk`
- `campaign_id fk ad_campaigns`
- `state` (`pending`, `cleared`, `revoked`)
- `clearance_type` (`paid`, `waiver`, `other_authorized`)
- optional agreed amount/currency/package reference
- `authorized_by_account_id`
- `reason null`
- `updated_at`

Payment does not imply approval; approval does not imply payment.

## `ad_inventory_windows`

Represents Location × placement × time window capacity.

- `id uuid pk`
- `location_id fk locations`
- `placement_type` (`home_sponsored`, `explore_sponsored`, `community_event` etc.)
- `window_start`, `window_end`
- `capacity integer check capacity >= 0`
- optional rate-card/package reference
- unique `(location_id, placement_type, window_start, window_end)`

## `ad_inventory_reservations`

- `id uuid pk`
- `inventory_window_id fk ad_inventory_windows`
- `campaign_id fk ad_campaigns`
- `state` (`held`, `confirmed`, `released`, `expired`)
- `units integer default 1`
- `hold_expires_at null`
- `created_at`, `updated_at`

Reservation command must lock/protect capacity so held + confirmed units cannot exceed window capacity.

## `ad_placements`

Per Location serving reality.

- `id uuid pk`
- `campaign_id fk ad_campaigns`
- `location_id fk locations`
- `placement_type`
- `inventory_reservation_id fk ad_inventory_reservations`
- `state` (`waiting`, `live`, `paused`, `ended`, `cancelled`)
- `pause_reason null`
- `created_at`, `updated_at`

A campaign may be Live in Dhanbad and Paused in Gomoh.

## `hidden_campaigns`

- `account_id`
- `campaign_id`
- optional hide reason
- `created_at`
- unique pair

Advertiser never sees individual user identity from hides/views.

## `ad_metrics_daily`

Aggregate reporting only:

- `campaign_id`
- `location_id`
- `metric_date`
- `sponsored_views`
- `opens`
- `enquiries`
- `external_visits`
- unique `(campaign_id, location_id, metric_date)`

Do not expose named viewer lists.

---

# 11. Notifications, idempotency and audit

## `notifications`

Derived delivery record only; not source of domain truth.

- `id`, `recipient_account_id`, type, source reference, read/delivery timestamps

## `idempotency_keys`

Recommended platform-level command support:

- `account_id`
- `command_name`
- `idempotency_key`
- request fingerprint/hash
- resulting object/reference/status
- expiry/created timestamps
- unique `(account_id, command_name, idempotency_key)`

## `audit_log`

Append-oriented record for significant actions:

- `id`
- `actor_account_id`
- `action_type`
- `target_type`, `target_id`
- Location/Organization/Learner scope where relevant
- `reason`
- structured metadata with sensitive-data discipline
- `created_at`

Do not turn audit log into the primary source of business state.

---

# 12. Critical indexes

At minimum review indexes for:

- public Teaching Options by Location + availability;
- Open Learning Requests by Location/category/date;
- Enquiries by learner/provider/status;
- Active Class Memberships by learner and by Class;
- Pending Invitations by learner/Class/expiry;
- Sessions by Class/start time;
- Open Activities by Class/due date;
- Test availability by Class/time;
- Community Posts by Location/created time;
- unresolved Reports by moderation scope/time;
- Ads inventory by Location/placement/window;
- Live/Waiting Ads placements by Location/placement;
- Campaign/revision/review status lookups.

Avoid premature indexes unsupported by actual queries.

# 13. Critical database constraints / transaction checks

1. Exactly one owner on Teaching Option, Enquiry provider target, advertising subject/campaign owner.
2. One active Class Membership per learner/Class.
3. Class acceptance transaction enforces active/reserved capacity.
4. One logical Test Attempt per learner/Test according to V1 policy.
5. Campaign review references exact immutable revision.
6. Held + confirmed Ads reservations never exceed Inventory Capacity.
7. One active manager relationship per Learner in V1.
8. Duplicate Saved relationships prevented.
9. Stale lifecycle transitions rejected by canonical commands.

# 14. RLS / authorization direction

Do not implement RLS as only `auth.uid() = owner_id`. Many legitimate actions are relationship-based.

Policies/functions must account for:

- Account acting for Learner;
- responsible teacher and Organization authority;
- active Class Membership;
- parent/guardian oversight without Test impersonation;
- Local Manager Location scope;
- Platform/safety capabilities;
- advertiser Organization membership;
- moderation/commercial privacy.

Prefer business RPC/functions for consequential writes; RLS remains defense-in-depth and protects reads/direct access.

# 15. Migration/build order recommendation

1. Identity: Accounts, Learners, Account↔Learner Access.
2. Locations and scoped staff authority.
3. Organizations, teacher profiles, Teaching Options.
4. Learning Requests and Enquiries.
5. Classes, Invitations, Memberships, Sessions, Materials.
6. Activities, Submissions.
7. Tests, Attempts.
8. Community + Trust/Safety/Verification.
9. Ads Campaign/Review/Commercial model.
10. Ads Inventory/Placement/Analytics.
11. Notifications, audit and operational projections.

Each slice should ship with its canonical commands and tests before the next slice depends on it.

# Review gate before Supabase

Before creating migrations, challenge this blueprint against:

- the frozen Product/UI document;
- the Domain Model;
- command/permission matrix;
- Given/When/Then acceptance tests.

Any physical table that creates a new product concept must be justified or removed. Any frozen business rule that cannot be enforced must cause the schema to be revised before deployment.
