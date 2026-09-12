# Raahi Learning V1 — Physical Database Blueprint v1.1

Status: **REVIEWED PHYSICAL DESIGN — still do not deploy to Supabase until this document is explicitly approved as the SQL source.**

This version supersedes the first physical draft for future technical work. It incorporates the findings in `08-database-blueprint-review-v1.md` while preserving the frozen product/domain rules.

The purpose of this document is to define the relational shape and integrity boundaries before migrations are written. It is not SQL yet.

## Conventions

- PostgreSQL-compatible relational source of truth.
- UUID primary keys unless a simpler composite key is naturally stronger.
- `timestamptz` for timestamps.
- Consequential writes happen through canonical commands/RPCs, not arbitrary UI table updates.
- RLS protects reads/direct access and acts as defense in depth.
- State is kept only where behaviour genuinely changes because of it.
- Files are authorized through their business object; storage URLs are never treated as authorization.
- No Enrollment table, Batch table, Adult/Minor Learner tables, Trial relationship table, Attendance subsystem, or generic Progress %.

---

# 1. Identity, learner ownership and capabilities

## `accounts`

Authenticated human profile.

- `id uuid pk`
- `auth_user_id uuid unique not null` — Supabase `auth.users.id` when implemented
- `display_name text not null`
- `avatar_type text` — `builtin | upload | none`
- `avatar_ref text null`
- `selected_location_id uuid null fk locations` — user preference only; existing relationships do not depend on it
- `lifecycle_status text not null default 'active'` — narrow account lifecycle only, e.g. `active | paused | closed`; safety restrictions are separate
- `created_at`, `updated_at`

Do not add a permanent `role` field.

## `learners`

Person whose learning history/artifacts belong to them, whether or not they can log in.

- `id uuid pk`
- `display_name text not null`
- `avatar_type text` — `builtin | upload | none`
- `avatar_ref text null`
- `created_by_account_id uuid fk accounts`
- minimum optional safety/compliance attributes only when product/legal policy actually requires them
- `created_at`, `updated_at`

Public projections must never expose protected learner identity/photo simply because an avatar exists.

## `account_learner_access`

Who may act for a Learner.

- `id uuid pk`
- `account_id uuid fk accounts`
- `learner_id uuid fk learners`
- `access_type text` — `self | manage`
- `status text` — `active | ended`
- `granted_at`
- `ended_at null`
- `created_at`

Constraints:

- at most one active `self` relationship per Learner in V1;
- at most one active `manage` relationship per Learner in V1;
- prevent duplicate active `(account_id, learner_id, access_type)`.

History is retained if management/self access ends and is later re-granted.

## `account_capabilities`

Small explicit capability mechanism for unscoped permissions not represented by another relationship.

- `account_id uuid fk accounts`
- `capability_code text`
- `status text` — `active | revoked`
- `granted_by_account_id uuid null fk accounts`
- `granted_at`
- `revoked_at null`
- unique active capability per `(account_id, capability_code)`

Examples may include:

- `teach`
- `community_post`
- `platform_admin`
- `safety_reviewer`
- `verifier`
- `ads_commercial`

Organization and Location authority should still come from their scoped relationship tables rather than duplicating that scope here.

## `organizations`

- `id uuid pk`
- `organization_type text` — `school | university | college | coaching | academy | other_education`
- `name text not null`
- `description text null`
- approved public contact/location fields only
- `status text`
- `created_at`, `updated_at`

## `organization_members`

- `id uuid pk`
- `organization_id uuid fk organizations`
- `account_id uuid fk accounts`
- `status text` — `active | ended`
- `created_at`, `ended_at null`

## `organization_member_capabilities`

Normalized capability mapping rather than arbitrary permission JSON.

- `organization_member_id uuid fk organization_members`
- `capability_code text`
- unique `(organization_member_id, capability_code)`

Examples: manage profile, manage teaching options, create classes, manage Ads.

Campaigns/Classes remain owned by the Organization or Class, not by the employee who created them.

---

# 2. Locations and scoped staff authority

## `locations`

- `id uuid pk`
- `name text not null`
- `slug text unique not null`
- region/state/country fields
- optional coverage metadata
- `state text` — `preparing | live | paused | retired`
- `created_at`, `updated_at`

## `location_staff_assignments`

- `id uuid pk`
- `location_id uuid fk locations`
- `account_id uuid fk accounts`
- `staff_type text` — initially `local_manager`
- `status text` — `active | ended`
- `created_at`, `ended_at null`

Every Local Manager command re-checks active Location scope.

---

# 3. Scoped restrictions and safety controls

## `access_restrictions`

Represents explicit scoped restrictions rather than one giant Teacher/Account status.

- `id uuid pk`
- exactly one subject: `account_id uuid null fk accounts` OR `organization_id uuid null fk organizations`
- `restriction_scope text` — e.g. `public_discovery | new_enquiries | messaging | class_access | community | ads`
- `location_id uuid null fk locations` — null means platform-wide for that scope
- `state text` — `active | lifted | expired`
- `reason_code text`
- `details text null`
- `starts_at`
- `ends_at null`
- `applied_by_account_id uuid null fk accounts`
- `lifted_by_account_id uuid null fk accounts`
- `created_at`, `updated_at`

Significant safety/admin changes are audited. This table does not replace domain states such as Membership or Advertising Eligibility.

---

# 4. Teacher/provider discovery

## `teacher_profiles`

- `account_id uuid pk/fk accounts`
- `headline text null`
- `bio text null`
- `experience_summary text null`
- public profile fields permitted by policy
- `visibility_status text` — e.g. `visible | hidden`
- `created_at`, `updated_at`

Independent teaching eligibility should also respect active Account capability/restrictions.

## `teaching_options`

User-facing “What I Teach”. Exactly one owner.

- `id uuid pk`
- `teacher_account_id uuid null fk accounts`
- `organization_id uuid null fk organizations`
- CHECK exactly one owner is non-null
- `title text not null`
- `category text null`
- `description text`
- `teaching_mode text` — `online | in_person | both`
- `area_or_venue_text text null`
- `fee_display_text text null`
- `availability_status text` — `taking_new_learners | not_taking_new_learners | no_longer_offered`
- `created_at`, `updated_at`

## `teaching_option_locations`

- `teaching_option_id uuid fk teaching_options`
- `location_id uuid fk locations`
- primary/unique `(teaching_option_id, location_id)`

Materially different location terms should use separate Teaching Options, not hidden location-specific variants.

## Saved relationships

### `saved_teacher_profiles`
- `account_id uuid fk accounts`
- `teacher_account_id uuid fk accounts`
- `created_at`
- unique pair

### `saved_teaching_options`
- `account_id uuid fk accounts`
- `teaching_option_id uuid fk teaching_options`
- `created_at`
- unique pair

### `saved_organizations`
- `account_id uuid fk accounts`
- `organization_id uuid fk organizations`
- `created_at`
- unique pair

All Saved relationships are private and create no contact permission.

---

# 5. Learning Requests and Enquiries

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

Public view/projection must sanitize learner identity/private data.

Duplicate-open checks are semantic and belong primarily in the command layer, with supporting indexes on Learner + Location + state/category.

## `enquiries`

One controlled learner↔provider relationship context.

- `id uuid pk`
- `learner_id uuid fk learners`
- `created_by_account_id uuid fk accounts`
- exactly one provider target:
  - `provider_account_id uuid null fk accounts`
  - `provider_organization_id uuid null fk organizations`
- `teaching_option_id uuid null fk teaching_options`
- `learning_request_id uuid null fk learning_requests`
- `source_type text` — `direct | learning_request | sponsored`
- `source_campaign_id uuid null fk ad_campaigns`
- `state text` — `pending | active | closed`
- `close_reason text null`
- `created_at`, `activated_at null`, `closed_at null`

Checks/commands must ensure a referenced Teaching Option is actually owned by the provider target.

Prevent duplicate Pending/Active Enquiries for the same meaningful learner/provider/context unless the learning context genuinely differs.

## `enquiry_messages`

- `id uuid pk`
- `enquiry_id uuid fk enquiries`
- `sender_account_id uuid fk accounts`
- `body text`
- `message_type text` — `text | system | controlled_structured`
- `created_at`

Only Active Enquiry participants may send ordinary messages.

## `enquiry_trial_events`

Lightweight feature inside Enquiry.

- `id uuid pk`
- `enquiry_id uuid fk enquiries`
- `proposed_by_account_id uuid fk accounts`
- `scheduled_at timestamptz`
- `status text` — `proposed | scheduled | cancelled | completed`
- `created_at`, `updated_at`

No separate Trial relationship layer.

---

# 6. Classes, invitations, membership and private communication

## `classes`

- `id uuid pk`
- `responsible_teacher_account_id uuid fk accounts`
- `organization_id uuid null fk organizations`
- `location_id uuid null fk locations`
- `title text not null`
- `class_type text` — `one_to_one | group`
- `capacity integer not null check capacity >= 1`
- CHECK one-to-one classes use capacity 1
- `state text` — `draft | active | past`
- `created_at`, `updated_at`

If `organization_id` exists, the responsible teacher's Organization authority is checked by commands.

Capacity cannot be reduced below Active Memberships + valid Pending seat-reserving Invitations.

## `class_invitations`

A Pending Invitation reserves one finite seat in V1.

- `id uuid pk`
- `class_id uuid fk classes`
- `learner_id uuid fk learners`
- `invited_by_account_id uuid fk accounts`
- `state text` — `pending | accepted | declined | expired | cancelled`
- `expires_at timestamptz not null`
- `created_at`, `resolved_at null`

Constraints/rules:

- at most one Pending Invitation for the same Class + Learner;
- sending an Invitation must atomically verify capacity including other unexpired Pending Invitations;
- accepting/declining/cancelling/expiring releases/consumes the reservation consistently;
- `expires_at` is the reservation end; no second `seat_reserved_until` field.

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

Partial unique: at most one Active Membership for `(class_id, learner_id)`.

No Enrollment table.

## `class_sessions`

- `id uuid pk`
- `class_id uuid fk classes`
- `starts_at`
- `ends_at null`
- `delivery_mode text`
- controlled meeting/location fields
- `status text` — `scheduled | cancelled | completed` where completed is actually needed
- `created_at`, `updated_at`

No attendance subsystem.

## `file_assets`

Metadata for protected uploads; actual bytes live in authorized object storage.

- `id uuid pk`
- `uploaded_by_account_id uuid fk accounts`
- `storage_path text unique not null`
- `purpose_code text`
- `mime_type text null`
- `size_bytes bigint null`
- `status text` — `active | removed`
- `created_at`

Business links determine access. A storage path or copied URL never grants permission by itself.

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

Private Class feed content.

- `id uuid pk`
- `class_id uuid fk classes`
- `author_account_id uuid fk accounts`
- `learner_id uuid null fk learners` — set when post is learner-owned/learner-contextual
- `post_type text` — `update | announcement | question`
- `body text not null`
- `importance text` — `normal | important`
- `comments_enabled boolean default true`
- `visibility_status text` — `visible | hidden | removed`
- `created_at`, `updated_at`

This table never feeds public Community projections.

## `class_post_comments`

- `id uuid pk`
- `class_post_id uuid fk class_posts`
- `author_account_id uuid fk accounts`
- `learner_id uuid null fk learners`
- `body text not null`
- `visibility_status text`
- `created_at`, `updated_at`

## `class_learner_threads`

Contextual private thread for one Class + one Learner. This enables existing offline learners to communicate after joining without fabricating an Enquiry.

- `id uuid pk`
- `class_id uuid fk classes`
- `learner_id uuid fk learners`
- `status text` — `active | closed`
- `created_at`, `closed_at null`
- unique `(class_id, learner_id)`

Visibility includes the responsible teacher and learner-side Accounts currently authorized for that Learner according to policy. If an active managing Parent/Guardian exists, this thread is not a hidden teacher↔student DM.

## `class_learner_messages`

- `id uuid pk`
- `thread_id uuid fk class_learner_threads`
- `sender_account_id uuid fk accounts`
- `body text not null`
- `created_at`

No arbitrary cross-platform DM table is introduced.

---

# 7. Activities and submissions

## `activities`

- `id uuid pk`
- `class_id uuid fk classes`
- `created_by_account_id uuid fk accounts`
- `display_type text` — `assignment | practice | exercise`
- `title text not null`
- `instructions text`
- `due_at null`
- `submission_required boolean not null default false`
- `state text` — `draft | open | closed`
- `created_at`, `updated_at`

Due date does not itself imply Closed; teacher may allow late work while Activity remains Open.

## `submissions`

One logical learner submission per Activity.

- `id uuid pk`
- `activity_id uuid fk activities`
- `learner_id uuid fk learners`
- `current_status text` — `submitted | changes_requested | reviewed`
- `created_at`, `updated_at`
- unique `(activity_id, learner_id)`

## `submission_revisions`

- `id uuid pk`
- `submission_id uuid fk submissions`
- `revision_number integer not null`
- `performed_by_account_id uuid fk accounts`
- `text_response text null`
- `file_asset_id uuid null fk file_assets`
- `submitted_at`
- unique `(submission_id, revision_number)`

The Learner owns the work even if a managing Account performs the upload.

Revision allocation/submission is protected by the canonical command to avoid duplicate revision numbers under retries.

---

# 8. Tests and Attempts

## `tests`

- `id uuid pk`
- `class_id uuid fk classes`
- `created_by_account_id uuid fk accounts`
- `title text not null`
- `instructions text null`
- `available_from null`
- `closes_at null`
- `duration_seconds integer null`
- `state text` — `draft | available | closed`
- `results_visible boolean default false`
- `definition_locked_at timestamptz null`
- `created_at`, `updated_at`

`definition_locked_at` is set no later than the first valid Attempt start. Once locked, prompt/question/choice structure cannot be changed by ordinary editing.

## `test_questions`

- `id uuid pk`
- `test_id uuid fk tests`
- `position integer`
- `question_type text` — V1 primarily `mcq`
- `prompt text`
- `points numeric`
- unique `(test_id, position)`

## `test_choices`

- `id uuid pk`
- `question_id uuid fk test_questions`
- `position integer`
- `choice_text text`
- `is_correct boolean not null default false`
- unique `(question_id, position)`

After Test definition lock, answer-key changes happen only through the audited `correct_answer_key` command, which recalculates affected evaluated Attempts transactionally.

## `test_attempts`

- `id uuid pk`
- `test_id uuid fk tests`
- `learner_id uuid fk learners`
- `state text` — `in_progress | submitted | evaluated | invalidated`
- `started_at`
- `submitted_at null`
- `evaluated_at null`
- `score numeric null`
- `invalidation_reason text null`
- unique `(test_id, learner_id)` for V1 single-attempt policy

## `test_attempt_answers`

- `attempt_id uuid fk test_attempts`
- `question_id uuid fk test_questions`
- `selected_choice_id uuid null fk test_choices`
- `text_response text null`
- `saved_at`
- unique `(attempt_id, question_id)`

`start_test` and `submit_test` are idempotent hard commands.

---

# 9. Community

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

Posting permission is evaluated through Account capability + Location legitimacy/policy. Reading does not imply posting authority.

## `community_comments`

- `id uuid pk`
- `post_id uuid fk community_posts`
- `author_account_id uuid fk accounts`
- `body text`
- `visibility_status text`
- `created_at`, `updated_at`

## `community_post_reactions`

- `post_id uuid fk community_posts`
- `account_id uuid fk accounts`
- `reaction_type text` — positive/contextual approved set only
- `created_at`
- unique `(post_id, account_id, reaction_type)`

## `community_comment_reactions`

- `comment_id uuid fk community_comments`
- `account_id uuid fk accounts`
- `reaction_type text`
- `created_at`
- unique `(comment_id, account_id, reaction_type)`

No public downvote model.

---

# 10. Trust, verification, reports and blocks

## `verification_claims`

- `id uuid pk`
- exactly one subject: `account_id uuid null fk accounts` OR `organization_id uuid null fk organizations`
- `claim_type text`
- `status text` — `pending | verified | revoked | rejected`
- `verified_at null`
- `verified_by_account_id uuid null fk accounts`
- `created_at`, `updated_at`

Public label derives from exact Claim type; never infer generic “Verified Teacher”.

## `reports`

- `id uuid pk`
- `reporter_account_id uuid fk accounts`
- `target_type text`
- `target_id uuid`
- `reason_code text`
- `details text null`
- limited evidence/snapshot metadata where legally/safely appropriate
- `status text`
- `created_at`, `resolved_at null`

Generic target validation occurs in the report command. The loose target reference is deliberate so evidence may survive target hiding/removal; do not allow arbitrary client inserts.

## `blocks`

- `blocker_account_id uuid fk accounts`
- `blocked_account_id uuid fk accounts`
- `created_at`
- unique pair

Block affects ordinary contact according to policy; it does not delete history, Reports or Memberships.

---

# 11. Raahi Ads

## `advertising_eligibility`

Exactly one subject.

- `id uuid pk`
- `account_id uuid null fk accounts`
- `organization_id uuid null fk organizations`
- CHECK exactly one subject
- `state text` — `not_enabled | under_review | enabled | restricted | disabled`
- `reason text null`
- `created_at`, `updated_at`

## `ad_campaigns`

- `id uuid pk`
- exactly one owner: `account_id uuid null fk accounts` OR `organization_id uuid null fk organizations`
- `objective text` — `admissions | course_batch | event | awareness`
- `campaign_name text not null`
- `audience_context text null` — simple broad V1 context, not behavioural targeting
- `education_category text null`
- `starts_at`, `ends_at`
- `state text` — `draft | submitted | closed`
- `created_at`, `updated_at`

No `archived` user lifecycle is required; closed campaigns remain available in History.

## `ad_campaign_targets`

Requested target inventory before serving.

- `campaign_id uuid fk ad_campaigns`
- `location_id uuid fk locations`
- `placement_type text` — e.g. `home_sponsored | explore_sponsored | community_event`
- unique `(campaign_id, location_id, placement_type)`

This table drives cross-Location review scope and availability checks.

## `ad_campaign_revisions`

- `id uuid pk`
- `campaign_id uuid fk ad_campaigns`
- `revision_number integer`
- `headline text`
- `body text`
- `image_asset_id uuid null fk file_assets`
- destination fields (`destination_type`, internal target ref or approved external URL)
- `cta_type text`
- `submitted_at null`
- `created_at`
- unique `(campaign_id, revision_number)`

Once submitted for review, a Revision's public creative is immutable. Changes create a new Revision.

## `ad_reviews`

- `id uuid pk`
- `campaign_revision_id uuid fk ad_campaign_revisions`
- `reviewer_account_id uuid fk accounts`
- `review_scope text` — `local | platform`
- `state text` — `under_review | evidence_requested | changes_requested | approved | rejected`
- `reason text null`
- `details text null`
- `created_at`, `decided_at null`

Review always references the exact Revision. Reviewer conflict/scope checks are command-layer authorization.

## `ad_claim_evidence`

- `id uuid pk`
- `campaign_revision_id uuid fk ad_campaign_revisions`
- `file_asset_id uuid null fk file_assets`
- `external_url text null`
- `submitted_by_account_id uuid fk accounts`
- `created_at`

Private to authorized advertiser/review roles.

## `ad_commercial_clearances`

V1 deliberately keeps this small.

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

Payment/commercial clearance never implies policy approval.

## `ad_inventory_days`

Non-overlapping physical capacity buckets.

- `id uuid pk`
- `location_id uuid fk locations`
- `placement_type text`
- `inventory_date date`
- `capacity integer not null check capacity >= 0`
- `rate_card_code text null`
- `created_at`, `updated_at`
- unique `(location_id, placement_type, inventory_date)`

This prevents hidden overlap between arbitrary windows. Packages can still sell contiguous date ranges.

## `ad_inventory_reservations`

Reservation header.

- `id uuid pk`
- `campaign_id uuid fk ad_campaigns`
- `state text` — `held | confirmed | released | expired`
- `hold_expires_at null`
- `created_at`, `updated_at`

Every Held reservation has a finite expiry. Confirmed reservations may outlive the hold expiry.

## `ad_inventory_reservation_days`

Daily units claimed by a Reservation.

- `reservation_id uuid fk ad_inventory_reservations`
- `inventory_day_id uuid fk ad_inventory_days`
- `units integer not null default 1 check units > 0`
- unique `(reservation_id, inventory_day_id)`

`reserve_ad_inventory` atomically locks/checks all requested day buckets so the sum of Held + Confirmed units never exceeds capacity on any day.

## `ad_placements`

Per-Location/placement serving reality.

- `id uuid pk`
- `campaign_id uuid fk ad_campaigns`
- `location_id uuid fk locations`
- `placement_type text`
- `inventory_reservation_id uuid fk ad_inventory_reservations`
- `serving_revision_id uuid fk ad_campaign_revisions`
- `state text` — `waiting | live | paused | ended | cancelled`
- `pause_reason text null`
- `created_at`, `updated_at`
- unique logical placement per Campaign + Location + placement type for the booked period

Hard rule: `serving_revision_id` must belong to the same Campaign and have a valid Approved review before serving. A newer Draft/Under-Review Revision never replaces it implicitly.

## `hidden_campaigns`

- `account_id uuid fk accounts`
- `campaign_id uuid fk ad_campaigns`
- `hide_reason text null`
- `created_at`
- unique pair

Never exposed as named viewer information to advertiser.

## `ad_frequency_state`

Private operational serving state used only to protect user experience.

- `account_id uuid fk accounts`
- `campaign_id uuid fk ad_campaigns`
- `window_started_at`
- `served_count integer`
- `last_served_at null`
- `updated_at`
- unique `(account_id, campaign_id)`

Retention/cleanup should be limited to what frequency control actually needs. Advertisers never receive this table or named viewer history.

## `ad_metrics_daily`

Aggregate advertiser reporting.

- `ad_placement_id uuid fk ad_placements`
- `metric_date date`
- `sponsored_views bigint`
- `opens bigint`
- `enquiries bigint`
- `external_visits bigint`
- unique `(ad_placement_id, metric_date)`

Location/Campaign totals are derived from placements. Do not call mere views/opens “leads”.

---

# 12. Notifications, idempotency and audit

## `notifications`

Derived delivery record only.

- `id uuid pk`
- `recipient_account_id uuid fk accounts`
- `context_learner_id uuid null fk learners`
- `notification_type text`
- source type/reference fields
- read/delivery timestamps
- `created_at`

Core domain state must already be committed before notification delivery.

## `idempotency_keys`

Platform command retry protection.

- `id uuid pk`
- `actor_account_id uuid null fk accounts`
- `command_name text`
- `idempotency_key text`
- `request_fingerprint text`
- resulting object/reference/status fields
- `created_at`, `expires_at null`
- unique `(actor_account_id, command_name, idempotency_key)` for human commands

System jobs should use their own deterministic job/operation keys rather than pretending to be a human Account.

## `audit_log`

Append-oriented significant-action audit.

- `id uuid pk`
- `actor_kind text` — `account | system`
- `actor_account_id uuid null fk accounts`
- `action_type text`
- `target_type text`
- `target_id uuid null`
- optional Location/Organization/Learner scope ids
- `reason text null`
- structured metadata with sensitive-data discipline
- `created_at`

Audit is evidence/history, never the primary state machine.

---

# 13. Critical indexes

At minimum, review/create indexes for actual query paths:

- active Account↔Learner access by Account and Learner;
- active capability/restriction lookup;
- public Teaching Options by Location + availability;
- Saved items by Account;
- Open Learning Requests by Location/category/created time;
- Pending/Active Enquiries by Learner/provider;
- Active Memberships by Learner and by Class;
- Pending unexpired Invitations by Class and Learner;
- Sessions by Class/start time;
- Class posts/messages by Class/thread/time;
- Open Activities by Class/due date;
- Attempts by Test/Learner/state;
- Community Posts by Location/time;
- unresolved Reports by moderation status/time;
- Campaign targets by Location/placement;
- Reviews by Revision/state;
- Ads inventory by Location/placement/date;
- Held/Confirmed reservations by inventory day;
- Live/Waiting Placements by Location/placement;
- aggregate Ads metrics by Placement/date.

Avoid indexes not justified by actual read/command patterns.

---

# 14. Hard integrity/transaction rules

1. Exactly one owner/subject where XOR ownership is required.
2. At most one active Self and one active Manager access relationship per Learner in V1.
3. Teaching Option referenced by Enquiry must match the Enquiry provider target.
4. Pending Class Invitations reserve capacity until their finite expiry/resolution.
5. Active Memberships + valid Pending seat reservations can never exceed Class capacity.
6. Invitation acceptance creates exactly one Membership and resolves the Invitation atomically.
7. Transfer creates destination Membership and marks source Transferred atomically.
8. Parent-assisted Submission preserves Learner ownership while auditing performer.
9. Test structure locks no later than the first Attempt start.
10. One logical Test Attempt per Learner/Test in V1; Start/Submit are idempotent.
11. Campaign Review always targets exact immutable Revision.
12. Ad Placement serves only an approved exact Revision belonging to its Campaign.
13. Held + Confirmed reservation units never exceed any daily Ads capacity bucket.
14. Commercial Clearance never bypasses review; approval never bypasses Commercial Clearance.
15. Current authoritative state wins over stale UI for every transition.

---

# 15. RLS / authorization direction

Do not implement policies as only `auth.uid() = owner_id`.

Reads and business commands must account for:

- Account acting for Learner;
- self vs management access;
- Account capability grants;
- active scoped restrictions;
- responsible teacher and Organization membership/capabilities;
- active Class Membership;
- managing guardian oversight without Test impersonation;
- Class learner thread audience;
- Local Manager Location assignment;
- Platform/safety/verifier/commercial capabilities;
- advertiser Organization membership;
- moderation/commercial/evidence privacy.

Prefer SECURITY DEFINER-style canonical RPC/functions only where carefully reviewed and minimally privileged. RLS still protects direct reads/table access.

Storage policies must align to the linked business object, not only uploader ownership.

---

# 16. Build/migration order

Recommended controlled slices:

1. Accounts, Learners, Account↔Learner Access, Account Capabilities.
2. Locations, staff assignments, scoped Restrictions.
3. Organizations, Organization Membership/Capabilities, Teacher Profiles, Teaching Options, Saved items.
4. Learning Requests, Enquiries, Enquiry messages/trial events.
5. Classes, Invitations, Memberships, Sessions, protected file metadata, Materials.
6. Class feed posts/comments + Class Learner Threads/Messages.
7. Activities, Submissions/Revisions.
8. Tests, Questions/Choices, Attempts/Answers + definition lock/correction command.
9. Community + Verification + Reports + Blocks.
10. Ads eligibility, Campaigns/Targets/Revisions/Reviews/Evidence/Commercial Clearance.
11. Ads daily Inventory, Reservations, Placements, frequency state, aggregate Metrics.
12. Notifications, idempotency, audit, secure projections/search support.

Each slice must include:

- versioned migration;
- canonical commands/RPCs;
- RLS/read-policy tests;
- transaction/concurrency tests where relevant;
- Given/When/Then regression tests;
- rollback/forward migration reasoning.

Do not build the entire schema in one unreviewed migration.

---

# Final pre-Supabase gate

Before writing the first migration, explicitly approve this blueprint against these questions:

1. Does every frozen UI behaviour have a physical home?
2. Did any removed concept accidentally return?
3. Can every capacity invariant survive concurrent requests?
4. Can a Parent act for Rahul without becoming Rahul?
5. Can a Learner's own login coexist with Parent management without duplicate learner identity?
6. Can direct offline Class invitations work without fake Enquiry history?
7. Can copied Class/file URLs be rejected by current authorization?
8. Can Test content change after an Attempt starts? It must not, except governed answer-key correction.
9. Can an Ad ever show an unapproved/latest Draft revision? It must not.
10. Can overlapping Ads packages oversell the same date/placement? Daily buckets must prevent it.
11. Can an advertiser learn named viewer frequency/hide information? It must not.
12. Can one safety restriction accidentally terminate unrelated capabilities because of a giant status field? It must not.

Only after this gate passes should this design be translated into SQL/Supabase migrations.