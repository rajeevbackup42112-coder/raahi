# Raahi Learning V1.2 — Migration Sequence Scaffold

Do not add ad-hoc dashboard schema changes. Migration files should be created here only after the target Supabase environment is inspected and reconciled with the V1.2 contract.

Canonical sequence:

```text
0001_extensions_helpers.sql
0002_common_updated_at.sql
0100_identity_tables.sql
0101_identity_constraints_indexes.sql
0102_command_infrastructure.sql
0103_identity_rls_helpers.sql
0104_identity_rpcs.sql

0200_locations_tables.sql
0201_account_location_preferences.sql
0202_locations_staff_rls_rpcs.sql
0203_location_interests.sql
0250_learner_share_codes.sql

0300_organizations_discovery_tables.sql
0301_organizations_discovery_constraints.sql
0302_organizations_discovery_rls_rpcs.sql
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

## Rules

- Do not create all files blindly before read-only environment inspection if existing project objects may conflict.
- Every applied migration must be represented in source control.
- Once applied to a shared environment, never rewrite history; fix forward.
- Execute and test one slice at a time.
- Foundation + Identity is the first permitted slice.

See `docs/raahi-learning/20-consolidated-sql-migration-plan-v1.2.md` for the full contract.
