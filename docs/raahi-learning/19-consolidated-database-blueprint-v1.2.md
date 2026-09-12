# Raahi Learning V1.2 — Consolidated Physical Database Blueprint

Status: **FINAL PRE-SUPABASE PHYSICAL DESIGN.**

This file consolidates the reviewed physical blueprint plus both UI→DB deltas into one implementation source. It supersedes the need to mentally merge `03-database-blueprint-v1.1.md`, `14-ui-db-implementation-delta-v1.md`, and `17-final-ui-db-implementation-delta-v1.1.md` during implementation.

Older files remain for decision traceability. For new implementation work, this document is the physical data-model source of truth.

## Conventions

- PostgreSQL/Supabase-compatible relational source of truth.
- UUID primary keys unless a natural composite key is stronger.
- `timestamptz` for event/lifecycle timestamps.
- Core history is normally retained; domain rows are not blindly cascade-deleted.
- Consequential state changes happen through canonical commands/RPCs.
- RLS protects reads/direct access; route guards are defense in depth only.
- No permanent Account `role` field.
- No Enrollment table, Batch table, Adult/Minor Learner tables, turning-18 migration, Attendance subsystem, generic Progress %, public Learner directory, or tuition-payment subsystem.

---

# 1. Identity and learner authority

## `accounts`

- `id uuid pk`
- `auth_user_id uuid unique null fk auth.users on delete set null`
- `display_name text not null`
- `avatar_type text not null` — `builtin | upload | none`
- `avatar_ref text null`
- `lifecycle_status text not null default 'active'` — `active | paused | closed`
- `created_at`, `updated_at`

Selected Location is **not** stored on Account.

Account lifecycle is not a substitute for safety restrictions.

## `learners`

- `id uuid pk`
- `display_name text not null`
- `avatar_type text not null` — `builtin | upload | none`
- `avatar_ref text null`
- `created_by_account_id uuid fk accounts`
- only minimum optional compliance/safety fields actually required
- `created_at`, `updated_at`

The Learner owns Classes, Submissions and Attempts even when another Account performs an allowed action on their behalf.

## `account_learner_access`

- `id uuid pk`
- `account_id uuid fk accounts`
- `learner_id uuid fk learners`
- `access_type text` — `self | manage`
- `status text` — `active | ended`
- `granted_at`
- `ended_at null`
- `created_at`

Hard rules:

- at most one active `self` per Learner in V1.2;
- at most one active `manage` per Learner in V1.2;
- history retained after access ends.

Formal marketplace/relationship decisions follow `can_make_learning_decision(learner_id)`: if an active manager exists, the manager owns those formal decisions; otherwise active self-access may decide for self. This does not grant the manager Test-taking impersonation.

## `account_capabilities`

- `account_id uuid fk accounts`
- `capability_code text`
- `status text` — `active | revoked`
- `granted_by_account_id uuid null fk accounts`
- `granted_at`
- `revoked_at null`

Examples: `teach`, `community_post`, `platform_admin`, `safety_reviewer`, `verifier`, `ads_commercial`.

Location and Organization scope comes from scoped relationship tables, not unscoped capability duplication.

## `audit_log`

Append-oriented significant-action history.

- `id uuid pk`
- `actor_kind text` — `account | system`
- `actor_account_id uuid null fk accounts`
- `action_type text`
- `target_type text`
- `target_id uuid null`
- optional `learner_id`, `organization_id`, `location_id`
- `reason text null`
- disciplined structured metadata
- `created_at`

Never use generic audit metadata for secrets, raw share tokens, full messages, or unnecessary child data.

## `idempotency_keys`

- `id uuid pk`
- `actor_account_id uuid null fk accounts`
- `command_name text`
- `idempotency_key text`
- `request_fingerprint text`
- stored result reference/status payload
- `created_at`, `expires_at null`

Human-command uniqueness: `(actor_account_id, command_name, idempotency_key)`.

System jobs use deterministic system operation keys.

---

# 2. Locations

## `locations`

- `id uuid pk`
- `name text not null`
- `slug text unique not null`
- region/state/country fields
- optional coverage metadata
- `state text` — `interest_only | preparing | live | paused | retired`
- `created_at`, `updated_at`

Only `live` supports normal public discovery/community/Ads serving. `interest_only` and `preparing` can collect interest/onboarding without pretending the Location is live.

## `account_location_preferences`

- `account_id uuid pk/fk accounts`
- `selected_location_id uuid fk locations`
- `updated_at`

This is a discovery/community preference only. It never owns Classes, Enquiries, Saved items or history.

## `location_interests`

- `id uuid pk`
- `location_id uuid fk locations`
- `account_id uuid fk accounts`
- `intent_type text` — `learn | teach`
- `state text` — `active | withdrawn`
- `created_at`, `updated_at`

One active tuple per `(location_id, account_id, intent_type)`.

Registering interest never auto-creates a Learning Request or Teaching Option.

## `location_staff_assignments`

- `id uuid pk`
- `location_id uuid fk locations`
- `account_id uuid fk accounts`
- `staff_type text` — initially `local_manager`
- `status text` — `active | ended`
- `created_at`, `ended_at null`

Every Local Manager read/command re-checks current active Location scope.

---

# 3. Organizations

## `organizations`

- `id uuid pk`
- `organization_type text` — `school | university | college | coaching | academy | other_education`
- `name text not null`
- `description text null`
- approved public contact/location fields only
- `logo_type text` — `builtin | upload | none`
- `logo_ref text null`
- `status text`
- `created_at`, `updated_at`

## `organization_members`

- `id uuid pk`
- `organization_id uuid fk organizations`
- `account_id uuid fk accounts`
- `status text` — `active | ended`
- `created_at`, `ended_at null`

## `organization_member_capabilities`

- `organization_member_id uuid fk organization_members`
- `capability_code text`
- unique pair

Examples: manage profile, manage teaching options, create/manage Classes, manage Ads, manage members.

Organization-owned Classes/Campaigns survive an employee leaving.

---

# 4. Scoped restrictions and verification

## `access_restrictions`

Exactly one subject: Account or Organization.

- `id uuid pk`
- `account_id uuid null fk accounts`
- `organization_id uuid null fk organizations`
- `restriction_scope text` — `public_discovery | new_enquiries | messaging | class_access | community | ads | ...`
- `location_id uuid null fk locations` — null means platform-wide for that scope
- `state text` — `active | lifted | expired`
- `reason_code text`
- `details text null`
- `starts_at`, `ends_at null`
- `applied_by_account_id uuid null fk accounts`
- `lifted_by_account_id uuid null fk accounts`
- `created_at`, `updated_at`

Restrictions are precise capabilities, not a giant user status.

## `verification_claims`

Exactly one subject: Account or Organization.

- `id uuid pk`
- `account_id uuid null fk accounts`
- `organization_id uuid null fk organizations`
- `claim_type text`
- `status text` — `pending | verified | revoked | rejected`
- `verified_at null`
- `verified_by_account_id uuid null fk accounts`
- `created_at`, `updated_at`

Public badges derive from exact claim type only; there is no generic paid “Verified Teacher”.

---

# 5. Teacher/provider discovery

## `teacher_profiles`

- `account_id uuid pk/fk accounts`
- `headline text null`
- `bio text null`
- `experience_summary text null`
- approved public profile fields
- `visibility_status text` — `visible | hidden`
- `created_at`, `updated_at`

## `teaching_options`

Exactly one owner: Teacher Account or Organization.

- `id uuid pk`
- `teacher_account_id uuid null fk accounts`
- `organization_id uuid null fk organizations`
- `title text not null`
- `category text null`
- `description text null`
- `teaching_mode text` — `online | in_person | both`
- `area_or_venue_text text null`
- `fee_display_text text null`
- `availability_status text` — `taking_new_learners | not_taking_new_learners | no_longer_offered`
- `created_at`, `updated_at`

## `teaching_option_locations`

- `teaching_option_id uuid fk teaching_options`
- `location_id uuid fk locations`
- unique pair

Materially different fee/schedule/venue terms should use separate Teaching Options instead of hidden per-Location variants.

## Saved relationships

- `saved_teacher_profiles(account_id, teacher_account_id, created_at)`
- `saved_teaching_options(account_id, teaching_option_id, created_at)`
- `saved_organizations(account_id, organization_id, created_at)`

Each pair is unique and private. Saving creates no contact permission and does not notify the saved party.

---

# 6. Learning Requests and Enquiries

## `learning_requests`

- `id uuid pk`
- `learner_id uuid fk learners`
- `created_by_account_id uuid fk accounts`
- `location_id uuid fk locations`
- `need_text text not null`
- `category text null`
- `mode_preference text null`
- `details text null`
- `timing_preference text null`
- `state text` — `draft | open | closed`
- `close_reason text null`
- `created_at`, `updated_at`, `closed_at null`

Public projection is sanitized and must not become a public Learner profile.

## `enquiries`

- `id uuid pk`
- `learner_id uuid fk learners`
- `created_by_account_id uuid fk accounts`
- exactly one provider target: `provider_account_id` or `provider_organization_id`
- `teaching_option_id uuid null fk teaching_options`
- `learning_request_id uuid null fk learning_requests`
- `source_type text` — `direct | learning_request | sponsored`
- `source_campaign_id uuid null fk ad_campaigns` — added only after Ads tables exist
- `state text` — `pending | active | closed`
- `close_reason text null`
- `created_at`, `activated_at null`, `closed_at null`

Referenced Teaching Option must belong to the provider target.

## `enquiry_messages`

- `id uuid pk`
- `enquiry_id uuid fk enquiries`
- `sender_account_id uuid fk accounts`
- `body text`
- `message_type text` — `text | system | controlled_structured`
- `created_at`

Ordinary messages require an Active Enquiry and current contextual authorization.

## `enquiry_trial_events`

- `id uuid pk`
- `enquiry_id uuid fk enquiries`
- `proposed_by_account_id uuid fk accounts`
- `scheduled_at timestamptz`
- `status text` — `proposed | scheduled | cancelled | completed`
- `created_at`, `updated_at`

Trial stays a feature inside Enquiry, not a separate relationship layer.

---

# 7. Private Learner share codes

## `learner_share_codes`

Used only to let an existing offline learner/parent privately identify the correct Learner for a Class Invitation without a public Learner directory or fabricated Enquiry.

- `id uuid pk`
- `learner_id uuid fk learners`
- `created_by_account_id uuid fk accounts`
- `code_hash text unique not null`
- `state text` — `active | consumed | revoked | expired`
- `expires_at timestamptz not null`
- `consumed_at null`
- `revoked_at null`
- `created_at`

Rules:

- unpredictable short-lived one-time token;
- plaintext never stored;
- only learner side with `can_make_learning_decision` can create/revoke;
- resolving the exact code reveals minimum information only;
- teacher/institute cannot browse or search Learners.

---

# 8. Classes, invitations and membership

## `classes`

- `id uuid pk`
- `responsible_teacher_account_id uuid fk accounts`
- `organization_id uuid null fk organizations`
- `location_id uuid null fk locations`
- `title text not null`
- `class_type text` — `one_to_one | group`
- `capacity integer not null check capacity >= 1`
- one-to-one capacity must equal 1
- `state text` — `draft | active | past`
- `created_at`, `updated_at`

## `class_invitations`

A valid Pending Invitation reserves one finite seat immediately.

- `id uuid pk`
- `class_id uuid fk classes`
- `learner_id uuid fk learners`
- `invited_by_account_id uuid fk accounts`
- `state text` — `pending | accepted | declined | expired | cancelled`
- `expires_at timestamptz not null`
- `fee_display_text text null`
- `created_at`, `resolved_at null`

Rules:

- at most one Pending invitation per Class + Learner;
- send is capacity-protected atomically;
- the Pending fee snapshot cannot silently change; material fee change requires cancel/reissue;
- accepting a valid already-reserved invitation does not compete for a second seat;
- resolve/expiry consistently releases or consumes reservation.

## `class_memberships`

- `id uuid pk`
- `class_id uuid fk classes`
- `learner_id uuid fk learners`
- `state text` — `active | completed | left | transferred | removed`
- `joined_via_invitation_id uuid null fk class_invitations`
- `joined_at`
- `ended_at null`
- `end_reason text null`
- `transferred_to_membership_id uuid null fk class_memberships`

At most one Active Membership per Class + Learner.

No Enrollment table.

## `class_sessions`

- `id uuid pk`
- `class_id uuid fk classes`
- `starts_at timestamptz`
- `ends_at timestamptz null`
- `delivery_mode text`
- controlled meeting/location fields
- `cancelled_at null`
- `cancel_reason text null`
- `created_at`, `updated_at`

Past is derived from time. There is no Attendance subsystem or meaningful “completed session” lifecycle in V1.2.

## Historical Class access

Deterministic policy:

- Active → normal allowed access;
- Completed → read-only appropriate Class history/materials + learner’s own artifacts/results;
- Transferred → read-only appropriate source-Class history + learner’s own artifacts/results;
- Left → shared Class feed/material access ends; own appropriate artifacts/results/history remain;
- Removed → Class-private access ends; legitimate own/safety/audit records remain through proper projections only;
- active safety/Class-access restriction can override ordinary historical access.

## Class completion

`complete_class` is the only ordinary completion transition: Class row and eligible Active Memberships transition atomically. Already Left/Transferred/Removed memberships retain their end states.

---

# 9. Files, materials and Class communication

## `file_assets`

- `id uuid pk`
- `uploaded_by_account_id uuid fk accounts`
- `storage_path text unique not null`
- `purpose_code text`
- `mime_type text null`
- `size_bytes bigint null`
- `status text` — `active | removed`
- `created_at`

Business linkage determines access. A copied private storage path/URL is never authorization.

## `materials`

- `id uuid pk`
- `created_by_account_id uuid fk accounts`
- `title text not null`
- `description text null`
- `resource_type text` — `file | external_link | text`
- `file_asset_id uuid null fk file_assets`
- `external_url text null`
- `created_at`, `updated_at`

## `material_class_links`

- `material_id uuid fk materials`
- `class_id uuid fk classes`
- unique pair

## `class_posts`

- `id uuid pk`
- `class_id uuid fk classes`
- `author_account_id uuid fk accounts`
- `learner_id uuid null fk learners`
- `post_type text` — `update | announcement | question`
- `body text not null`
- `importance text` — `normal | important`
- `comments_enabled boolean default true`
- `visibility_status text` — `visible | hidden | removed`
- `created_at`, `updated_at`

## `class_post_comments`

- `id uuid pk`
- `class_post_id uuid fk class_posts`
- `author_account_id uuid fk accounts`
- `learner_id uuid null fk learners`
- `body text not null`
- `visibility_status text`
- `created_at`, `updated_at`

## `class_learner_threads`

- `id uuid pk`
- `class_id uuid fk classes`
- `learner_id uuid fk learners`
- `created_at`
- unique Class + Learner

No independent active/closed lifecycle. Read/write authority derives from current Membership end state, Learner-side authority, responsible Teacher authority and scoped restrictions.

## `class_learner_messages`

- `id uuid pk`
- `thread_id uuid fk class_learner_threads`
- `sender_account_id uuid fk accounts`
- `body text not null`
- `created_at`

No arbitrary global DM table.

---

# 10. Activities and submissions

## `activities`

- `id uuid pk`
- `class_id uuid fk classes`
- `created_by_account_id uuid fk accounts`
- `display_type text` — `assignment | practice | exercise`
- `title text not null`
- `instructions text null`
- `due_at timestamptz null`
- `submission_required boolean default false`
- `state text` — `draft | open | closed`
- `created_at`, `updated_at`

Due date does not automatically close the Activity.

## `activity_material_links`

- `activity_id uuid fk activities`
- `material_id uuid fk materials`
- unique pair

Linked Material must already be authorized/shared to the Activity’s Class.

## `submissions`

- `id uuid pk`
- `activity_id uuid fk activities`
- `learner_id uuid fk learners`
- `current_status text` — `submitted | changes_requested | reviewed`
- `created_at`, `updated_at`
- unique Activity + Learner

## `submission_revisions`

- `id uuid pk`
- `submission_id uuid fk submissions`
- `revision_number integer`
- `performed_by_account_id uuid fk accounts`
- `text_response text null`
- `file_asset_id uuid null fk file_assets`
- `submitted_at`
- unique Submission + revision number

Learner owns the work even when a permitted manager assists with upload. Failed network submission never displays Submitted until authoritative confirmation.

---

# 11. Tests and Attempts

## `tests`

- `id uuid pk`
- `class_id uuid fk classes`
- `created_by_account_id uuid fk accounts`
- `title text not null`
- `instructions text null`
- `available_from timestamptz null`
- `closes_at timestamptz null`
- `duration_seconds integer null`
- `state text` — `draft | available | closed`
- `results_visible boolean default false`
- `definition_locked_at timestamptz null`
- `created_at`, `updated_at`

“Upcoming” is derived from time. Structure locks no later than the first valid Attempt start.

## `test_questions`

- `id uuid pk`
- `test_id uuid fk tests`
- `position integer`
- `question_type text` — V1 primarily `mcq`
- `prompt text`
- `points numeric`
- unique Test + position

## `test_choices`

- `id uuid pk`
- `question_id uuid fk test_questions`
- `position integer`
- `choice_text text`
- `is_correct boolean default false`
- unique Question + position

Post-lock structural changes are prohibited by normal editing. `correct_answer_key` is the explicit audited correction path and transactionally recalculates affected evaluated Attempts.

## `test_attempts`

- `id uuid pk`
- `test_id uuid fk tests`
- `learner_id uuid fk learners`
- `state text` — `in_progress | submitted | evaluated | invalidated`
- `started_at`
- `submitted_at null`
- `evaluated_at null`
- `score numeric null`
- `teacher_feedback text null`
- `invalidation_reason text null`
- unique Test + Learner for V1 single-attempt policy

Manager oversight never grants Test-taking impersonation. Teacher feedback is private learning data and appears only through result visibility/authorized projections.

## `test_attempt_answers`

- `attempt_id uuid fk test_attempts`
- `question_id uuid fk test_questions`
- `selected_choice_id uuid null fk test_choices`
- `text_response text null`
- `saved_at`
- unique Attempt + Question

---

# 12. Community and safety

## `community_posts`

- `id uuid pk`
- `location_id uuid fk locations`
- `author_account_id uuid fk accounts`
- `post_type text`
- `body text`
- `attachment_asset_id uuid null fk file_assets`
- `external_url text null`
- `visibility_status text` — `published | hidden | removed`
- `created_at`, `updated_at`

## `community_comments`

- `id uuid pk`
- `post_id uuid fk community_posts`
- `author_account_id uuid fk accounts`
- `body text`
- `visibility_status text`
- `created_at`, `updated_at`

## Reactions

- `community_post_reactions(post_id, account_id, reaction_type, created_at)`
- `community_comment_reactions(comment_id, account_id, reaction_type, created_at)`

Only approved positive/contextual reaction types; no public downvote model.

## `reports`

- `id uuid pk`
- `reporter_account_id uuid fk accounts`
- `context_learner_id uuid null fk learners`
- `target_type text`
- `target_id uuid`
- `reason_code text`
- `details text null`
- limited preserved evidence/snapshot metadata
- `status text`
- `created_at`, `resolved_at null`

Optional Learner context is moderation-private and accepted only when the reporting Account has a legitimate self/manage/safety relationship to that Learner.

Report creation is a request for review, not automatic punishment.

## `blocks`

- `blocker_account_id uuid fk accounts`
- `blocked_account_id uuid fk accounts`
- `created_at`
- unique pair

Block affects ordinary contact. It does not delete history, Reports, Classes or evidence and is separate from Leave Class.

---

# 13. Raahi Ads

## `advertising_eligibility`

Exactly one subject: Account or Organization.

- `id uuid pk`
- `account_id uuid null fk accounts`
- `organization_id uuid null fk organizations`
- `state text` — `not_enabled | under_review | enabled | restricted | disabled`
- `reason text null`
- `created_at`, `updated_at`

## `ad_campaigns`

Exactly one owner: Account or Organization.

- `id uuid pk`
- `account_id uuid null fk accounts`
- `organization_id uuid null fk organizations`
- `objective text` — `admissions | course_batch | event | awareness`
- `campaign_name text not null`
- `audience_context text null`
- `education_category text null`
- `starts_at`, `ends_at`
- `state text` — `draft | submitted | closed`
- `created_at`, `updated_at`

No behavioural microtargeting.

## `ad_campaign_targets`

- `campaign_id uuid fk ad_campaigns`
- `location_id uuid fk locations`
- `placement_type text` — `home_sponsored | explore_sponsored | community_event | ...`
- unique tuple

Targets exist before serving and drive review/inventory scope.

## `ad_campaign_revisions`

- `id uuid pk`
- `campaign_id uuid fk ad_campaigns`
- `revision_number integer`
- `headline text`
- `body text`
- `image_asset_id uuid null fk file_assets`
- destination fields
- `cta_type text`
- `submitted_at null`
- `created_at`
- unique Campaign + revision number

Submitted public creative becomes immutable; change creates a new revision.

## `ad_reviews`

- `id uuid pk`
- `campaign_revision_id uuid fk ad_campaign_revisions`
- `reviewer_account_id uuid fk accounts`
- `review_scope text` — `local | platform`
- `state text` — `under_review | evidence_requested | changes_requested | approved | rejected`
- `reason text null`
- `details text null`
- `created_at`, `decided_at null`

Review always targets the exact immutable Revision. Conflict-of-interest/scope authorization is command-enforced.

## `ad_claim_evidence`

- `id uuid pk`
- `campaign_revision_id uuid fk ad_campaign_revisions`
- `file_asset_id uuid null fk file_assets`
- `external_url text null`
- `submitted_by_account_id uuid fk accounts`
- `created_at`

Private to advertiser/review roles.

## `ad_commercial_clearances`

- `id uuid pk`
- `campaign_id uuid unique fk ad_campaigns`
- `state text` — `pending | cleared | revoked`
- `clearance_type text` — `paid | waiver | other_authorized`
- `package_code text null`
- `agreed_amount numeric null`
- `currency_code text null`
- `authorized_by_account_id uuid null fk accounts`
- `reason text null`
- `created_at`, `updated_at`

Commercial clearance never means policy approval and approval never means commercial clearance.

## `ad_inventory_days`

- `id uuid pk`
- `location_id uuid fk locations`
- `placement_type text`
- `inventory_date date`
- `capacity integer >= 0`
- `rate_card_code text null`
- `created_at`, `updated_at`
- unique Location + placement + date

Daily buckets prevent overlapping package oversell.

## `ad_inventory_reservations`

- `id uuid pk`
- `campaign_id uuid fk ad_campaigns`
- `state text` — `held | confirmed | released | expired`
- `hold_expires_at null`
- `created_at`, `updated_at`

Every Held reservation has finite expiry.

## `ad_inventory_reservation_days`

- `reservation_id uuid fk ad_inventory_reservations`
- `inventory_day_id uuid fk ad_inventory_days`
- `units integer > 0`
- unique pair

Reservation locks requested daily rows in deterministic order; Held-unexpired + Confirmed units can never exceed any day’s capacity.

## `ad_placements`

- `id uuid pk`
- `campaign_id uuid fk ad_campaigns`
- `location_id uuid fk locations`
- `placement_type text`
- `inventory_reservation_id uuid fk ad_inventory_reservations`
- `serving_revision_id uuid fk ad_campaign_revisions`
- `state text` — `waiting | live | paused | ended | cancelled`
- `pause_reason text null`
- `created_at`, `updated_at`

Serving Revision must belong to Campaign and have the required Approved review. “Latest revision” is never implicit.

## Viewer privacy / serving state

- `hidden_campaigns(account_id, campaign_id, hide_reason, created_at)`
- `ad_frequency_state(account_id, campaign_id, window_started_at, served_count, last_served_at, updated_at)`

These are private operational records, never advertiser viewer lists.

## `ad_metrics_daily`

- `ad_placement_id uuid fk ad_placements`
- `metric_date date`
- `sponsored_views bigint`
- `opens bigint`
- `enquiries bigint`
- `external_visits bigint`
- unique Placement + date

Advertiser reporting is aggregate. Views/opens are not called “leads”.

## Sponsored-surface rule

Sponsored selection may run only on explicitly allowed general surfaces such as Home, Explore and configured Local Community placements. It must return no commercial Sponsored placement for My Classes, individual Class/feed/materials, Activities, Tests, Enquiry/Class private Messages or paid Notifications.

This is surface-based; no Adult/Minor/turning-18 Ads model is introduced.

---

# 14. Notifications

## `notifications`

- `id uuid pk`
- `recipient_account_id uuid fk accounts`
- `context_learner_id uuid null fk learners`
- `notification_type text`
- source type/reference fields
- delivery/read timestamps
- `created_at`

Notifications are derived after core domain commit and never own business state.

---

# 15. Hard transactional invariants

1. Exactly one owner/subject for every XOR-owned row.
2. At most one active self and one active manager relationship per Learner.
3. Current server authorization beats stale UI/navigation state.
4. Consequential commands are idempotent.
5. Teaching Option referenced by Enquiry must match provider target.
6. Pending Class Invitations reserve capacity at send time.
7. Active Memberships + unexpired Pending Invitations cannot exceed Class capacity.
8. Invitation acceptance creates exactly one Membership and resolves the Invitation atomically.
9. Share-code invitation consumes the valid code and creates the Invitation atomically.
10. Transfer creates destination Membership and marks source Transferred atomically.
11. `complete_class` updates Class + eligible Active Memberships atomically.
12. Learner owns Submission even when manager performs the upload.
13. Test definition locks by first valid Attempt start; parent manager cannot take learner Test.
14. One logical V1 Attempt per Learner/Test; Start/Submit are retry-safe.
15. Campaign review always targets exact immutable Revision.
16. Serving always pins exact Approved Revision.
17. Held-unexpired + Confirmed Ads units never exceed any daily bucket.
18. Commercial Clearance and review remain independent.
19. Selected Location changes discovery context only.
20. Public availability changes new discovery only; existing Classes remain independent.
21. Account closure never cascades away another person’s legitimate learning/safety/history records.

---

# 16. Read/data privacy boundaries

### Public/sanitized

Live Locations, visible Teacher/Organization profiles, discoverable Teaching Options, sanitized Open Learning Requests, published Local Community content, eligible Sponsored creative.

### Relationship-private

Learners/access relationships, Enquiries/Messages, Invitations.

### Class-private

Memberships, Sessions, Materials, Class posts/comments, learner threads/messages, Activities/Submissions, Tests/Attempts.

### Moderation-private

Reports, restriction details, verification review evidence, audit data.

### Commercial-private

Ads evidence, commercial clearance, inventory reservations, per-user frequency state.

Private storage access follows current business authorization, never uploader identity alone and never possession of a copied URL.

---

# 17. Account lifecycle commands

`pause_account`:

- Account remains able to authenticate and access legitimate existing private learning/history/responsibilities;
- new public/discovery/commercial activity can be disabled by pause policy;
- existing Classes are not automatically terminated.

`resume_account`:

- returns paused Account to normal active behavior after current restrictions/relationships are rechecked.

`request_account_closure` / `close_account`:

- no partial cascading deletion;
- returns structured blockers for unresolved responsibilities;
- at minimum checks sole active learner management, responsible Teacher/active Class obligations, sole required Organization authority and safety/legal retention conditions;
- after application closure, auth credentials may be detached/deleted separately without destroying retained application history.

---

# 18. Final implementation rule

This consolidated blueprint is the physical design to pair with `20-consolidated-sql-migration-plan-v1.2.md`.

The older blueprint/review/delta files remain evidence of how decisions were reached; they are no longer required to reconstruct the final schema by precedence.

**Supabase has not been touched.**
