# Raahi Learning V1.2 — Consolidated SQL Migration Plan

Status: **FINAL PRE-SUPABASE MIGRATION CONTRACT.**

This file consolidates `10-sql-migration-plan-v1.1.md`, `14-ui-db-implementation-delta-v1.md`, and `17-final-ui-db-implementation-delta-v1.1.md` into one dependency-correct execution plan.

Use this file together with `19-consolidated-database-blueprint-v1.2.md`. Older plans/deltas remain for traceability but are no longer required to reconstruct the final migration sequence.

---

# 1. PostgreSQL/Supabase conventions

- UUID PKs via `gen_random_uuid()`.
- `timestamptz` for lifecycle/event timestamps.
- `created_at default now()`.
- shared `updated_at` trigger only on mutable tables that need it.
- lifecycle values use constrained `text` + `CHECK`, not PostgreSQL enum types.
- default core FK delete behavior is `RESTRICT/NO ACTION`.
- credential deletion may use `accounts.auth_user_id → auth.users.id ON DELETE SET NULL`.
- no blind cascades through Enquiries/Messages, Classes/Memberships, Activities/Submissions, Tests/Attempts, Reports/Audit or Ads history.
- consequential writes use canonical RPC/functions; direct client writes to operational states are denied.
- RLS remains active as defense in depth even where `SECURITY DEFINER` commands are used.

---

# 2. Migration sequence

## Foundation

### `0001_extensions_helpers.sql`

- enable `pgcrypto` if needed;
- create private helper schema, e.g. `app_private`;
- revoke public creation/usage where appropriate;
- establish safe helper-function conventions.

### `0002_common_updated_at.sql`

- shared `set_updated_at()` trigger function;
- no business behavior.

---

# 3. Foundation + Identity slice

This is the **first and only initial Supabase execution slice**.

### `0100_identity_tables.sql`

Create:

- `accounts` — nullable `auth_user_id`, no selected-Location FK, lifecycle `active|paused|closed`;
- `learners`;
- `account_learner_access`;
- `account_capabilities`.

### `0101_identity_constraints_indexes.sql`

Required indexes/constraints include:

- one active `self` relationship per Learner;
- one active `manage` relationship per Learner;
- no duplicate active Account/Learner/access-type relationship;
- one active Account capability per capability code;
- useful access lookups by Account and Learner.

### `0102_command_infrastructure.sql`

Create before the first consequential RPC:

- `audit_log`;
- `idempotency_keys`;
- helper functions for idempotency claim/result where implementation chooses a common abstraction.

Human operation key uniqueness:

`(actor_account_id, command_name, idempotency_key)`.

System jobs use deterministic system operation keys.

### `0103_identity_rls_helpers.sql`

Implement carefully reviewed helpers:

- `current_account_id()` derived from `auth.uid()`;
- `has_account_capability(code)`;
- `has_learner_self_access(learner_id)`;
- `can_access_learner(learner_id)`;
- `can_manage_learner(learner_id)`;
- `can_make_learning_decision(learner_id)`.

`can_make_learning_decision` semantics:

1. if an active manager exists, only that manager or an explicitly authorized exceptional platform/safety path may make formal learner-side marketplace/relationship decisions;
2. otherwise active self-access may decide for self;
3. this helper never grants Test-taking impersonation;
4. learner safety reporting remains independently available.

Every `SECURITY DEFINER` function must have fixed safe `search_path`, derive actor from `auth.uid()`, expose minimal results, and have default/public execute revoked before explicit grants.

### `0104_identity_rpcs.sql`

Canonical commands:

- `create_learner`;
- controlled self-access grant/link path;
- transfer learner management through authorized support/platform path;
- end learner access through governed path;
- privileged Account capability grant/revoke;
- `pause_account`;
- `resume_account`;
- guarded `request_account_closure` / `close_account` semantics.

Before Organization/Class tables exist, closure may report Identity-level blockers and call a replaceable blocker helper. Later slices extend blocker detection rather than rewriting history.

### Foundation + Identity slice test gate

Must prove before any Location migration:

- Account and Learner are separate identities;
- parent can act for learner without becoming learner;
- siblings remain isolated;
- one active self and one active manager limit;
- active manager owns formal learning decisions;
- manager cannot acquire learner Test self-access by management alone;
- pause/resume behavior is coherent;
- closure refuses unresolved manager responsibility;
- idempotent retry does not repeat logical operations;
- direct privilege escalation fails;
- unauthorized direct reads/writes fail.

**Stop here on any failure. Do not create Location tables.**

---

# 4. Locations slice

### `0200_locations_tables.sql`

Create:

- `locations` with state `interest_only|preparing|live|paused|retired`;
- `location_staff_assignments`.

Only `live` is eligible for normal public discovery/community/Ads serving.

### `0201_account_location_preferences.sql`

Create `account_location_preferences`.

Changing selected Location must never mutate existing Classes, Enquiries, Saved items or history.

### `0202_locations_staff_rls_rpcs.sql`

- secure Location reads;
- active Local Manager scope helpers;
- `set_selected_location`;
- controlled Location lifecycle/admin commands as authorized.

### `0203_location_interests.sql`

Create `location_interests` plus:

- `register_location_interest`;
- `withdraw_location_interest`.

Allowed for `interest_only` and `preparing` according to policy.

Registering interest does not publish a Learning Request or Teaching Option.

---

# 5. Learner private share-code slice

### `0250_learner_share_codes.sql`

Create `learner_share_codes`:

- store only cryptographic hash;
- state `active|consumed|revoked|expired`;
- finite expiry;
- no public/searchable Learner lookup.

Canonical commands:

- `create_learner_share_code(learner_id, idempotency_key)`;
- `revoke_learner_share_code(share_code_id, idempotency_key)`.

Plaintext token is returned once and never stored/audited.

The Class-invite-by-code command is added later after Classes exist.

---

# 6. Organizations + discovery slice

### `0300_organizations_discovery_tables.sql`

Create:

- `organizations` including public logo/avatar fields;
- `organization_members`;
- `organization_member_capabilities`;
- `teacher_profiles`;
- `teaching_options`;
- `teaching_option_locations`;
- Saved relationship tables.

### `0301_organizations_discovery_constraints.sql`

Enforce:

- Teaching Option XOR owner;
- active Organization member uniqueness;
- validated availability/mode values;
- unique Saved pairs;
- indexes matching real discovery queries.

### `0302_organizations_discovery_rls_rpcs.sql`

Canonical writes/read helpers for:

- Organization creation/member/capability management;
- Teacher profile management;
- Teaching Option publish/update/availability;
- private Save/Unsave actions;
- secure public discovery projections.

Public discovery must not expose private contact/home data.

---

# 7. Scoped restrictions slice

### `0350_access_restrictions.sql`

Create `access_restrictions` only after Accounts + Locations + Organizations exist.

Use XOR Account/Organization subject and optional Location scope.

### `0351_access_restriction_rpcs_rls.sql`

Canonical audited commands:

- apply scoped restriction;
- lift scoped restriction;
- expire restriction through system job/policy.

Restriction scope remains precise (`public_discovery`, `new_enquiries`, `messaging`, `class_access`, `community`, `ads`, etc.).

---

# 8. Requests + Enquiries slice

### `0400_requests_enquiries_tables.sql`

Create:

- `learning_requests`;
- `enquiries` **without** Ads campaign FK initially;
- `enquiry_messages`;
- `enquiry_trial_events`.

### `0401_requests_enquiries_rls_rpcs.sql`

Canonical commands:

- post/update/close/reopen Learning Request using `can_make_learning_decision`;
- send direct Enquiry;
- provider express interest in Request;
- engage/decline/close Enquiry;
- send Enquiry message only when Active and currently authorized;
- schedule/reschedule/cancel Trial event.

Public Learning Request read projection is sanitized and must not become a public Learner directory.

---

# 9. Classes + protected files slice

### `0500_classes_files_tables.sql`

Create:

- `classes`;
- `class_invitations` including immutable-while-Pending `fee_display_text` snapshot;
- `class_memberships`;
- lightweight `class_sessions` with cancellation fields and no Attendance/completed lifecycle;
- `file_assets`;
- `materials`;
- `material_class_links`.

### `0501_class_capacity_constraints.sql`

Required partial indexes/constraints:

- one Pending Invitation per Class + Learner;
- one Active Membership per Class + Learner;
- one-to-one Class capacity = 1;
- supporting capacity lookups.

### `0502_class_invitation_membership_rpcs.sql`

Use the **Class row as serialization point**.

#### `send_class_invitation`

1. derive actor and authorize responsible Teacher/Organization authority;
2. lock Class row `FOR UPDATE`;
3. expire/ignore stale Pending Invitations;
4. count Active Memberships + unexpired Pending Invitations;
5. reject if adding one would exceed capacity;
6. reject duplicate Pending same Learner/Class;
7. insert Pending Invitation with finite expiry and fee snapshot;
8. commit; notify later.

A valid Pending Invitation has already reserved its seat.

#### `send_class_invitation_with_share_code`

Same capacity transaction plus:

- hash/resolve exact active unexpired share code;
- reveal only minimal Learner identity required to create Invitation;
- create normal Pending Invitation;
- consume the share code atomically;
- retry cannot consume twice or duplicate Invitation.

#### `accept_class_invitation`

Lock Invitation + Class; require current Pending/unexpired + learner-side authority; create exactly one Active Membership; mark Invitation Accepted atomically. Do not run a second seat race for a seat already reserved by the valid Pending Invitation.

Other commands:

- decline/cancel/expire Invitation;
- transfer Learner — source/destination Classes locked in deterministic UUID order;
- Leave Class;
- Remove Learner;
- change capacity with Active + Pending reservation floor;
- `complete_class` — Class + eligible Active Memberships transition in one transaction;
- activate/create Class through responsible authority.

### `0503_classes_rls.sql`

Implement deterministic current/historical read behavior by Membership end state and restrictions.

Private file paths/URLs never bypass current authorization.

---

# 10. Class communication slice

### `0550_class_communication_tables.sql`

Create:

- `class_posts`;
- `class_post_comments`;
- `class_learner_threads` without independent status lifecycle;
- `class_learner_messages`.

### `0551_class_communication_rls_rpcs.sql`

Thread/post/message authorization derives from current Membership/historical policy, current Learner-side authority, responsible Teacher authority and scoped restrictions.

A direct/offline-origin learner requires no fabricated Enquiry to use legitimate Class communication after joining.

No unrestricted global DM table is introduced.

---

# 11. Activities slice

### `0600_activities_submissions_tables.sql`

Create:

- `activities`;
- `activity_material_links`;
- `submissions`;
- `submission_revisions`.

### `0601_activities_submissions_rls_rpcs.sql`

Canonical commands:

- publish/close Activity;
- link/unlink Material only if authorized to Activity Class;
- submit Activity work;
- request changes;
- review Submission.

Submission command preserves Learner ownership and records performing Account separately. Revision allocation is retry-safe.

---

# 12. Tests / assessment slice

### `0700_tests_attempts_tables.sql`

Create:

- `tests`;
- `test_questions`;
- `test_choices`;
- `test_attempts` including `teacher_feedback`;
- `test_attempt_answers`.

### `0701_test_definition_guards.sql`

Defense-in-depth structural guards:

- first valid Attempt sets `definition_locked_at` no later than Attempt creation;
- after lock, ordinary question/choice insert/delete/prompt/points/choice-text edits are blocked;
- answer-key correctness changes are not available through ordinary client writes.

### `0702_test_attempt_rpcs.sql`

Canonical commands:

- publish Test;
- start Test — learner **self-access only**, Active Membership, current availability, single Attempt, idempotent;
- save answer;
- submit Test — exact in-progress Attempt, idempotent;
- evaluate Attempt and optional teacher feedback;
- invalidate Attempt — reason + audit;
- `correct_answer_key` — explicit privileged audited correction and transactional recalculation;
- result visibility control.

### `0703_tests_rls.sql`

Parent/manager may see permitted result/status but cannot take learner Test.

Teacher feedback follows result visibility and private result-read authorization.

---

# 13. Community + trust slice

### `0800_community_trust_tables.sql`

Create:

- Community posts/comments/reactions;
- verification claims;
- Reports including private `context_learner_id`;
- Blocks.

### `0801_community_trust_rls_rpcs.sql`

Canonical commands:

- publish/comment/react according to Location legitimacy/capability;
- Report subject — validate optional Learner context authority;
- Block account;
- moderation hide/remove;
- Report resolution;
- verification grant/revoke.

Report creation never automatically punishes the target.

No public downvotes.

---

# 14. Ads campaign / review / commercial slice

### `0900_ads_campaign_tables.sql`

Create:

- advertising eligibility;
- Campaigns;
- Campaign targets;
- immutable Campaign Revisions;
- Reviews;
- claim evidence;
- Commercial Clearance.

### `0901_add_sponsored_enquiry_attribution.sql`

Add nullable `enquiries.source_campaign_id` only now, after Campaigns exist.

### `0902_ads_review_commercial_rpcs.sql`

Canonical commands:

- advertising enable/restrict;
- create Campaign/set targets;
- submit immutable Revision;
- evidence request/submit;
- exact-revision review with current scope/conflict checks;
- confirm/revoke commercial clearance.

Policy review and commercial clearance remain independent.

### `0903_ads_campaign_rls.sql`

Advertiser Organization/Account authority and reviewer scope are enforced on every privileged read.

---

# 15. Ads inventory / serving slice

### `0950_ads_inventory_tables.sql`

Create:

- daily inventory buckets;
- reservation headers;
- reservation-day rows;
- placements with exact `serving_revision_id`;
- hidden campaigns;
- private per-user frequency state;
- aggregate daily metrics.

### `0951_ads_inventory_rpcs.sql`

`reserve_ad_inventory`:

1. authorize advertiser/Ads ops;
2. validate requested targets/date policy;
3. resolve every daily bucket;
4. sort rows deterministically;
5. lock all daily rows `FOR UPDATE` in order;
6. expire/exclude stale Holds;
7. calculate Held-unexpired + Confirmed units;
8. enforce concentration/anti-monopoly policy;
9. fail whole request if any required day lacks capacity;
10. insert Reservation header + day rows atomically.

Do not silently partially book another date/Location.

Confirm/release are idempotent.

### `0952_ads_serving_revision_guards.sql`

- every Placement serves exact approved Revision belonging to same Campaign;
- a newer draft/review Revision never replaces serving creative implicitly;
- resume rechecks approval, commercial, Location, inventory, dates and restrictions.

### `0953_ads_frequency_metrics_rls.sql`

- per-user frequency/hide state never advertiser-readable;
- advertiser metrics are aggregate Placement/day only;
- Sponsored serving function accepts/derives allowed surface context;
- protected learning/private surfaces always return no commercial Sponsored placement.

---

# 16. Derived platform operations

### `1000_notifications.sql`

Derived delivery records only. Core domain transaction commits before notification delivery.

### `1001_read_projections.sql`

At minimum:

- public live Location projection;
- public Teacher/Organization discovery;
- public Teaching Options;
- sanitized Open Learning Requests;
- `my_classes` with Learner context;
- private Class feed/material/activity/test/result projections;
- Local Community feed;
- Teacher Class-management projections;
- Local Manager public/local operations projections;
- Platform moderation/Ads/audit projections with capability guards;
- Sponsored candidate selection separate from organic ranking;
- advertiser aggregate metrics.

Every privileged projection must deny direct unauthorized deep-link/query access even if frontend navigation is bypassed.

### `1002_final_privilege_hardening.sql`

- revoke unnecessary table/function privileges;
- explicitly grant only intended RPC/view execution/read paths;
- verify no consequential operational table accepts direct client mutation;
- review all `SECURITY DEFINER` search paths and object privileges;
- include direct privileged-read denial regression tests.

### `1003_account_closure_blockers_complete.sql`

After all domain tables exist, replace/extend Account closure blocker function so it can check at least:

- sole active manager responsibility with unresolved learner responsibilities;
- responsible Teacher/active Class obligations;
- sole Organization responsibility requiring handoff;
- safety/legal constraints;
- other active platform obligations added by later modules.

No blocker produces partial deletion.

---

# 17. Storage plan

Logical buckets/authorization classes:

- `public-profile-media` — deliberately public Teacher/Organization media only;
- `learner-private-media` — protected Learner avatar/photo;
- `class-private` — Materials and Submission uploads;
- `community-public` — intentionally public Community attachments;
- `ads-public` — approved Sponsored creative;
- `ads-review-private` — claim evidence.

Private retrieval is based on current business relationship/authorization, not uploader ownership or possession of a copied path.

---

# 18. Required tests by slice

Every slice must include:

- migration success;
- constraint/index tests;
- canonical RPC tests;
- RLS/read tests;
- stale-state tests;
- idempotency where applicable;
- concurrency tests where applicable;
- privilege-escalation tests;
- storage authorization tests where applicable;
- Given/When/Then regression mapping to frozen UI behavior.

Highest-risk concurrency suites:

- Pending Invitation reservation race at **send** time;
- duplicate invitation/accept retry;
- Class capacity reduction floor;
- Transfer atomicity;
- Test first-attempt definition lock;
- Test Start/Submit retry;
- Ads multi-day deterministic locking/oversell protection;
- exact Campaign Revision review/serve.

---

# 19. Forward-fix rule

Before execution, draft migration files may still be corrected during review.

After any migration is applied to a shared/production environment:

- do not rewrite migration history;
- use forward corrective migrations;
- rollback only with explicit data/history consequences understood;
- never erase required shared/safety/audit history just to simplify rollback.

---

# 20. Configurable values that do not block schema

Keep these as configuration/policy, not hard-coded architecture:

- default Class Invitation expiry;
- Learner share-code expiry;
- Ads inventory hold duration;
- Ads frequency cap/window;
- Ads rate-card values;
- idempotency retention;
- notification retention;
- detailed Community posting eligibility rules.

---

# 21. Pre-Supabase execution gate

Before connecting to Supabase, the following must be true:

- inspected UI freeze exists and checksum is recorded;
- `19-consolidated-database-blueprint-v1.2.md` approved;
- this consolidated migration plan approved;
- final acceptance/traceability matrix complete;
- implementation runbook complete;
- target Supabase project/environment has **not** been mutated yet.

Once the user authorizes Supabase work, first **inspect** the target project and compare its existing state against this contract. Then implement only Foundation + Identity and run its tests before proceeding.
