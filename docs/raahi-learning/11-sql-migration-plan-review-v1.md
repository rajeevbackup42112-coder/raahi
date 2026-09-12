# Raahi Learning V1 — SQL Migration Plan Review

Status: **REVIEW COMPLETE — migration plan is sound in direction but needs sequencing corrections before approval. Supabase remains untouched.**

This review challenged `10-sql-migration-plan-v1.md` against the physical blueprint, architecture, command matrix and acceptance gates.

## Verdict

The transaction/RLS/security approach is good and no removed product concept needs to return.

However, the current migration order has a few cross-module foreign-key/infrastructure dependencies that must be corrected before the plan can be marked **APPROVED FOR IMPLEMENTATION**.

---

## Blocking sequencing findings

### 1. `accounts.selected_location_id` creates an Identity → Locations dependency

The physical blueprint places `selected_location_id` on `accounts`, while the migration plan creates Identity before Locations.

That creates an avoidable FK sequencing dependency.

**Decision:** do not make selected Location part of the Account core row in the first Identity migration. Implement it after Locations as a small preference relationship, for example:

`account_location_preferences(account_id pk/fk accounts, selected_location_id fk locations, updated_at)`

This is a UI preference, not Account identity or domain lifecycle.

Anonymous/pre-login location selection may remain client-side until login.

### 2. `access_restrictions.organization_id` depends on Organizations

The proposed migration order creates Locations/Restrictions before Organizations, but scoped restrictions can target an Organization.

**Decision:** create Locations first, then Organizations, then the general `access_restrictions` table once Account + Organization + Location FKs all exist.

No product rule changes.

### 3. `enquiries.source_campaign_id` depends on Ads created much later

Requests/Enquiries are intentionally implemented before Ads.

**Decision:** create Enquiries initially without the Sponsored Campaign FK. In the Ads campaign migration, add nullable `source_campaign_id` and its FK/index with `ALTER TABLE`.

`source_type='sponsored'` becomes valid only after the Ads attribution migration exists.

This keeps the core Enquiry module independent from future Ads rollout.

### 4. Audit and idempotency infrastructure is scheduled too late

Identity, management transfer, privileged capability grants and other early commands are already supposed to be audited/idempotent. Creating `audit_log` and `idempotency_keys` at the very end would force early commands either to ship without those guarantees or later be rewritten.

**Decision:** create command infrastructure immediately after core Account tables and before the first consequential RPCs.

Notifications may remain late because they are derived side effects.

Suggested early sequence:

- Identity tables
- Audit + Idempotency tables/helpers
- Identity RLS/auth helpers
- Identity RPCs

### 5. Test lock trigger vs answer-key correction needs a precise exception path

A blanket trigger blocking all Choice updates after Test lock would also block the legitimate audited `correct_answer_key` command.

**Decision:** after lock:

- structural mutations are always blocked: Question insert/delete, prompt change, Choice insert/delete, Choice text change;
- `is_correct` may be changed only by the dedicated privileged correction RPC;
- ordinary client/Table API update permission on Test Questions/Choices remains revoked;
- correction RPC audits old/new key and transactionally recalculates affected results.

Do not solve this by disabling triggers dynamically.

---

## Important clarifications

### Class Invitation capacity model passes

Using the locked Class row as the capacity serialization point is acceptable for V1.

Because sending a Pending Invitation reserves the seat, concurrency is resolved primarily at `send_class_invitation`, while acceptance consumes the already-reserved capacity.

All capacity-changing commands must lock the same Class serialization row.

### Ads daily bucket model passes

The daily capacity model correctly prevents overlapping package ranges from double-selling the same date.

Multi-row inventory locking must use deterministic order and fail the whole requested reservation if any required bucket lacks capacity.

### RLS + canonical RPC model passes

The plan correctly avoids relying on simple `auth.uid() = owner_id` policies and preserves actor + acting-for + object + relationship/capability/scope checks.

The final SQL should keep privileged helper/RPC functions in a controlled schema with explicit `search_path`, minimal `EXECUTE` grants and no trust in caller-supplied actor IDs.

### Storage model passes with one discipline

`file_assets` is metadata, not authorization. Every private-object retrieval still needs current business authorization.

Public buckets should contain only content deliberately public by product design. Learner-private media, Class files and Ad Claim Evidence must never become public merely for convenience.

### FK deletion philosophy passes

Core/shared/history records should default to `RESTRICT/NO ACTION`; authentication credential removal may `SET NULL` on the Account auth reference so application history survives.

### Idempotency contract passes

Idempotency record/result must commit in the same database transaction as the consequential domain outcome. The same key with a different request fingerprint must fail.

---

## Revised migration sequence

Recommended final order:

### Foundation / Identity

- `0001_extensions_helpers.sql`
- `0002_common_updated_at.sql`
- `0100_identity_tables.sql`
- `0101_identity_constraints_indexes.sql`
- `0102_command_infrastructure.sql` — Audit + Idempotency
- `0103_identity_rls_helpers.sql`
- `0104_identity_rpcs.sql`

### Locations

- `0200_locations_tables.sql`
- `0201_account_location_preferences.sql`
- `0202_locations_staff_rls_rpcs.sql`

### Organizations / Discovery

- `0300_organizations_discovery_tables.sql`
- `0301_organizations_discovery_constraints.sql`
- `0302_organizations_discovery_rls_rpcs.sql`

### Scoped restrictions

- `0350_access_restrictions.sql`
- `0351_access_restriction_rpcs_rls.sql`

### Requests / Enquiries

- `0400_requests_enquiries_tables.sql`
- `0401_requests_enquiries_rls_rpcs.sql`

At this stage there is no FK to Ads yet.

### Classes / Files

- `0500_classes_files_tables.sql`
- `0501_class_capacity_constraints.sql`
- `0502_class_invitation_membership_rpcs.sql`
- `0503_classes_rls.sql`

### Class communication

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

### Ads Campaign / Review / Commercial

- `0900_ads_campaign_tables.sql`
- `0901_add_sponsored_enquiry_attribution.sql` — adds `enquiries.source_campaign_id`
- `0902_ads_review_commercial_rpcs.sql`
- `0903_ads_campaign_rls.sql`

### Ads Inventory / Serving

- `0950_ads_inventory_tables.sql`
- `0951_ads_inventory_rpcs.sql`
- `0952_ads_serving_revision_guards.sql`
- `0953_ads_frequency_metrics_rls.sql`

### Derived platform operations

- `1000_notifications.sql`
- `1001_read_projections.sql`
- `1002_final_privilege_hardening.sql`

Audit/Idempotency are intentionally **not** deferred to this final stage.

---

## Exact pre-Supabase approval gate

Before connecting Supabase, update the SQL Migration Plan to reflect this revised sequence and explicitly state:

1. selected Location preference is created after Locations, not as an Identity FK dependency;
2. Organization-scoped Restrictions are created only after Organizations;
3. Sponsored Enquiry attribution FK is added in Ads migration;
4. Audit/Idempotency exist before early consequential RPCs;
5. Test post-lock structural edits are blocked while answer-key correction has one explicit audited privileged path.

Once those corrections are incorporated, the migration plan can be reviewed one final time for approval.

No additional product-design work is required by these findings.