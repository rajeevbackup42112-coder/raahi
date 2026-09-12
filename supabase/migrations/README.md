# Raahi Learning V1.2 — Migration Sequence

This directory is **Raahi Learning only**. Historical Raahi mobility migrations are deliberately excluded from this execution subtree.

No ad-hoc dashboard schema changes. Every shared/dev DDL change must exist here as a versioned migration; once applied, corrections are forward-only.

## Applied and passed

```text
0001_extensions_helpers.sql
0002_common_updated_at.sql
0100_identity_tables.sql
0101_identity_constraints_indexes.sql
0102_command_infrastructure.sql
0103_identity_rls_helpers.sql
0104_identity_rpcs.sql
0105_identity_hardening_followup.sql
0106_private_function_privileges.sql

0200_locations_tables.sql
0201_account_location_preferences.sql
0202_locations_staff_rls_rpcs.sql
0203_location_interests.sql
0204_locations_rls_policy_consolidation.sql

0250_learner_share_codes.sql
```

Foundation + Identity: **PASS**  
Locations: **PASS**  
Learner Share Codes: **PASS**

## Current stop / next eligible slice

```text
0300_organizations_discovery_tables.sql
0301_organizations_discovery_constraints.sql
0302_organizations_discovery_rls_rpcs.sql
```

Do not create/apply `0350+` until Organizations / teacher discovery passes its own runtime/security gate.

## Planned later sequence

```text
0350_access_restrictions.sql
0351_access_restriction_rpcs_rls.sql

0400_requests_enquiries_tables.sql
0401_requests_enquiries_rls_rpcs.sql

0500_classes_files_tables.sql
0501_class_capacity_constraints.sql
0502_class_invitation_membership_rpcs.sql
0503_classes_rls.sql
0550_class_communication_tables.sql
0551_class_communication_rls_rpcs.sql

0600_activities_submissions_tables.sql
0601_activities_submissions_rls_rpcs.sql

0700_tests_attempts_tables.sql
0701_test_definition_guards.sql
0702_test_attempt_rpcs.sql
0703_tests_rls.sql

0800_community_trust_tables.sql
0801_community_trust_rls_rpcs.sql

0900_ads_campaign_tables.sql
0901_add_sponsored_enquiry_attribution.sql
0902_ads_review_commercial_rpcs.sql
0903_ads_campaign_rls.sql
0950_ads_inventory_tables.sql
0951_ads_inventory_rpcs.sql
0952_ads_serving_revision_guards.sql
0953_ads_frequency_metrics_rls.sql

1000_notifications.sql
1001_read_projections.sql
1002_final_privilege_hardening.sql
1003_account_closure_blockers_complete.sql
```

## Share-code implementation notes

- 192 bits of database-generated randomness, encoded as a private `rl_...` bearer token;
- SHA-256 hash only is persisted; plaintext is returned on the first successful create response only;
- idempotent replay returns the same logical share-code ID but **never replays the plaintext secret**;
- if the first secret response is lost, the client must deliberately create a replacement with a new idempotency key; creating the replacement revokes the prior active code;
- V1 allows one active share code per Learner;
- current V1 TTL is 24 hours through a private policy helper, not a schema invariant;
- no public resolver/search/browse endpoint exists;
- the private exact-token resolver is reserved for the later atomic Class invite-by-code transaction;
- invite consume/revoke race, timeout-after-invite retry, and endpoint rate limiting are deferred to `0502`/staging because the public invite-by-code command does not exist yet.

## Rules

- execute and test one slice at a time;
- successful migration application alone is not a PASS;
- canonical commands/RPCs own consequential writes;
- exposed tables/functions use RLS/least privilege;
- run runtime tests and Supabase advisors after DDL;
- stop on failed invariant/security checks;
- use forward-fix migrations after anything reaches shared/dev.

See the canonical migration contract on the documentation branch: `docs/raahi-learning/20-consolidated-sql-migration-plan-v1.2.md`.