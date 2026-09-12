# Raahi Learning V1.2 — Implementation Runbook

Status: **READY FOR USE ONCE SUPABASE ACCESS IS AUTHORIZED.**

This runbook defines exactly how implementation should proceed so a future chat/developer does not turn “start Supabase” into a one-shot schema push.

It does **not** authorize connecting to Supabase by itself.

---

# 1. Before any mutation

1. Read:
   - `99-handover.md`;
   - `18-ui-page-inventory-v1.1.md`;
   - `19-consolidated-database-blueprint-v1.2.md`;
   - `20-consolidated-sql-migration-plan-v1.2.md`;
   - `21-pre-supabase-readiness-review-v1.2.md`;
   - frozen Product/Architecture/Command/Acceptance/Ads docs when a rule is unclear.
2. Verify prototype checksum if the UI artifact is being used for implementation reference.
3. Confirm the exact target Supabase project/environment with the user if more than one exists.
4. Inspect the project **read-only first**:
   - project identity/environment;
   - existing schemas/tables/functions/policies;
   - auth configuration relevant to the design;
   - storage buckets/policies;
   - enabled extensions;
   - migration history;
   - whether any old Raahi ride/tuitions objects share the project.
5. Produce a short environment-diff report before writing anything.
6. If target environment conflicts materially with the V1.2 contract, stop and reconcile before mutation.

---

# 2. Source-control rule

All database changes must be represented as versioned migration files in source control before or at the moment of execution.

Never treat manual dashboard edits as the canonical implementation.

After a migration reaches a shared environment:

- do not rewrite its history;
- fix forward with a new migration;
- only rollback with understood data/history consequences.

---

# 3. Branching rule

Use a dedicated Raahi Learning implementation branch isolated from older Raahi ride code until integration is intentionally decided.

Suggested branch:

`raahi-learning-implementation-v1`

The existing `main` branch must not be assumed to represent this product model.

---

# 4. Slice execution loop

For **every** slice:

1. create/review migration files;
2. review FK/constraint/delete semantics;
3. review RLS/read paths;
4. review every `SECURITY DEFINER` function;
5. review command transaction/idempotency behavior;
6. apply migration to the intended non-production environment;
7. run schema assertions;
8. run permission/RLS tests;
9. run canonical RPC tests;
10. run stale/retry tests;
11. run concurrency tests where required;
12. run UI-related Given/When/Then regression tests;
13. record results;
14. stop if any invariant fails;
15. only then start the next slice.

Never stack untested slices merely because migrations applied successfully.

---

# 5. Slice 1 — Foundation + Identity

Migrations:

- `0001_extensions_helpers.sql`
- `0002_common_updated_at.sql`
- `0100_identity_tables.sql`
- `0101_identity_constraints_indexes.sql`
- `0102_command_infrastructure.sql`
- `0103_identity_rls_helpers.sql`
- `0104_identity_rpcs.sql`

Must prove:

- one Account can own self-learning and manage another Learner without mixing identities;
- Learner exists independently of login;
- siblings are isolated;
- at most one active self and manager relationship per Learner;
- manager owns formal relationship decisions when active;
- management does not grant learner Test self-access;
- Account capability cannot be forged by normal client;
- Account pause/resume behaves as specified;
- closure refuses unresolved learner-management responsibility;
- direct table writes cannot bypass commands;
- idempotency same-key/same-request returns same outcome;
- same-key/different-request is rejected;
- unauthorized reads fail.

**Go/no-go:** no Location migration until every mandatory Identity test passes.

---

# 6. Slice 2 — Locations

Migrations:

- `0200_locations_tables.sql`
- `0201_account_location_preferences.sql`
- `0202_locations_staff_rls_rpcs.sql`
- `0203_location_interests.sql`

Must prove:

- `interest_only`, `preparing`, `live`, `paused`, `retired` behave distinctly;
- only `live` is normal public discovery/community context;
- Register Interest works only where policy permits;
- duplicate interest retries produce one logical active Interest;
- selected Location changes discovery preference only;
- Local Manager scope is Location-bound;
- direct wrong-Location privileged reads fail.

---

# 7. Slice 3 — Learner share codes

Migration:

- `0250_learner_share_codes.sql`

Must prove:

- plaintext token is never stored;
- exact token possession is required to resolve;
- token is short-lived and one-time;
- expired/revoked/consumed token fails;
- unrelated actor cannot enumerate/search Learners;
- create/revoke is learner-side-authority protected;
- token never appears in generic Audit metadata.

Do not enable teacher invite-by-code until Classes exist.

---

# 8. Slice 4 — Organizations / teacher discovery

Migrations:

- `0300_organizations_discovery_tables.sql`
- `0301_organizations_discovery_constraints.sql`
- `0302_organizations_discovery_rls_rpcs.sql`

Must prove:

- one Teaching Option owner only;
- Organization employee capabilities are scoped;
- Organization-owned objects outlive employee access changes;
- public discovery exposes only intended fields;
- Save is private and creates no contact permission;
- `not_taking_new_learners` affects new discovery, not existing learning.

---

# 9. Slice 5 — Restrictions

Migrations:

- `0350_access_restrictions.sql`
- `0351_access_restriction_rpcs_rls.sql`

Must prove scope independence:

- discovery-only restriction does not end Class Membership;
- Ads-only restriction does not erase learning history;
- Class-access restriction affects intended Class access behavior only;
- Location-scoped restriction does not silently become platform-wide;
- apply/lift is auditable.

---

# 10. Slice 6 — Requests / Enquiries

Migrations:

- `0400_requests_enquiries_tables.sql`
- `0401_requests_enquiries_rls_rpcs.sql`

Must prove:

- parent posts for Learner without impersonating Learner;
- public Request is sanitized;
- direct Teaching Option and Learning Request routes converge into Enquiry;
- Pending Enquiry does not allow ordinary messaging;
- Active Enquiry does;
- duplicate same-context Enquiry is controlled;
- close Request does not auto-delete existing Enquiries;
- Trial remains optional feature inside Enquiry.

---

# 11. Slice 7 — Classes / invitations / files

Migrations:

- `0500_classes_files_tables.sql`
- `0501_class_capacity_constraints.sql`
- `0502_class_invitation_membership_rpcs.sql`
- `0503_classes_rls.sql`

Mandatory race tests:

### Invitation send race

Given one remaining Class seat and two concurrent send attempts, at most one new Pending reservation can be created.

### Accept retry

Repeated acceptance of the same valid Invitation creates one Membership only.

### Reserved-seat rule

Acceptance of an already-valid Pending Invitation must not lose the seat to a later sender; reservation happened at send time.

### Share-code invitation

Code consumption + Pending Invitation creation is atomic and retry-safe.

### Capacity reduction

Cannot reduce capacity below Active Memberships + valid Pending reservations.

### Transfer

Destination Active Membership + source Transferred state commit atomically.

### Complete Class

Class Past + eligible Active Memberships Completed commit atomically; Left/Transferred/Removed remain unchanged.

Storage tests must prove copied private paths fail without current Class authorization.

---

# 12. Slice 8 — Class communication

Migrations:

- `0550_class_communication_tables.sql`
- `0551_class_communication_rls_rpcs.sql`

Must prove:

- learner can have valid Class communication without fabricated Enquiry history;
- active manager sees permitted learner context;
- teacher cannot use contextual thread as unrestricted cross-platform DM;
- Left/Removed cannot continue ordinary sending;
- Completed/Transferred history is read-only where policy permits;
- copied thread identifiers do not grant access.

---

# 13. Slice 9 — Activities

Migrations:

- `0600_activities_submissions_tables.sql`
- `0601_activities_submissions_rls_rpcs.sql`

Must prove:

- one logical Submission per Learner/Activity;
- retry does not create duplicate revision;
- parent-assisted upload records performer but preserves Learner ownership;
- failed request does not become Submitted;
- Material link is valid for Activity Class;
- another learner cannot read another learner's Submission.

---

# 14. Slice 10 — Tests

Migrations:

- `0700_tests_attempts_tables.sql`
- `0701_test_definition_guards.sql`
- `0702_test_attempt_rpcs.sql`
- `0703_tests_rls.sql`

Mandatory tests:

- first valid Attempt locks Test definition;
- structural edits fail after lock;
- refresh/retry resumes same Attempt;
- multiple Start retries create one Attempt;
- double Submit yields one Submitted Attempt;
- manager/parent cannot take child's Test merely through manage authority;
- result hidden until visibility permits;
- teacher feedback follows private result permission;
- answer-key correction is explicit/audited and recalculates affected evaluated Attempts.

---

# 15. Slice 11 — Community / trust

Migrations:

- `0800_community_trust_tables.sql`
- `0801_community_trust_rls_rpcs.sql`

Must prove:

- posting scope is Location/policy constrained;
- no downvote type accepted;
- Report creation is not punishment;
- parent may attach managed Learner context to safety Report;
- unrelated Account cannot attach arbitrary Learner context;
- Block does not delete evidence/history;
- moderation/verification decisions are audited.

---

# 16. Slice 12 — Ads campaign / review / commercial

Migrations:

- `0900_ads_campaign_tables.sql`
- `0901_add_sponsored_enquiry_attribution.sql`
- `0902_ads_review_commercial_rpcs.sql`
- `0903_ads_campaign_rls.sql`

Must prove:

- Revision becomes immutable once submitted;
- Review points to exact Revision;
- reviewer cannot approve their own conflicted campaign where policy forbids;
- local reviewer cannot exceed Location scope;
- commercial clearance cannot override rejection;
- approval cannot imply commercial clearance;
- paid flow cannot mutate verification/organic rank.

---

# 17. Slice 13 — Ads inventory / serving

Migrations:

- `0950_ads_inventory_tables.sql`
- `0951_ads_inventory_rpcs.sql`
- `0952_ads_serving_revision_guards.sql`
- `0953_ads_frequency_metrics_rls.sql`

Mandatory concurrency tests:

- two overlapping package reservations cannot exceed any shared daily bucket;
- daily locks are acquired in deterministic order;
- stale availability fails rather than oversells;
- a multi-day request is atomic—no silent partial booking;
- held reservation expires correctly;
- exact serving Revision is approved and belongs to Campaign;
- Dhanbad placement can pause independently of Gomoh placement;
- frequency/hide records are never advertiser-readable;
- protected surfaces return zero commercial Sponsored placements.

---

# 18. Slice 14 — Derived operations / hardening

Migrations:

- `1000_notifications.sql`
- `1001_read_projections.sql`
- `1002_final_privilege_hardening.sql`
- `1003_account_closure_blockers_complete.sql`

Must prove:

- Notifications occur after business commit;
- secure projections are no more permissive than underlying RLS/business policy;
- direct privileged deep-link/query access fails for wrong Teacher/Organization/Location/Platform/Ads scope;
- Account closure now checks downstream Class/Organization/safety responsibilities;
- no consequential state table remains directly mutable by normal clients.

---

# 19. Frontend connection rule

Do not replace the inspected UI behavior with whatever happens to be easiest to query.

For each page in `18-ui-page-inventory-v1.1.md`:

- map reads to secure projection/function;
- map each CTA to canonical command;
- preserve loading/error/stale/denied states;
- show success only after authoritative command success;
- use realtime only to invalidate/refetch;
- never use frontend workspace state as authority.

---

# 20. Deployment rule

The first production-like launch should be small and Location-controlled.

Before enabling a Location:

- launch readiness confirmed;
- local supply/interest reviewed;
- moderation ownership assigned;
- critical monitoring/logging works;
- backup/recovery expectations understood;
- serious safety escalation path exists;
- Ads should not be enabled merely because learning launch is enabled.

---

# Final runbook rule

If a future agent is tempted to say “the SQL applied, continue,” stop and ask:

> Did the slice pass its authorization, stale-state, idempotency, concurrency and regression tests?

If not, the slice is not complete.
