# Raahi Learning V1.2 — Implementation Branch Legacy Migration Isolation

Status: **COMPLETED BEFORE LOCATIONS EXECUTION.**

During the Locations preflight, the implementation branch was found to have inherited the older Raahi mobility application's historical timestamped SQL migrations under `supabase/migrations/`.

Those files were **not** present in the clean Raahi Learning Supabase project and were never applied there. Foundation + Identity had been applied only through the explicit Raahi Learning Supabase migrations.

Leaving old mobility migrations beside Learning migrations would have created a future operational hazard: a normal CLI reset/push could attempt to replay unrelated ride/driver/booking schema into the Learning project.

## Correction completed

Before the Locations migrations were applied, the implementation branch `supabase/migrations/` subtree was replaced with a **Raahi Learning-only** migration chain.

Preserved/allowed there:

- `0001_extensions_helpers.sql`
- `0002_common_updated_at.sql`
- `0100_identity_tables.sql`
- `0101_identity_constraints_indexes.sql`
- `0102_command_infrastructure.sql`
- `0103_identity_rls_helpers.sql`
- `0104_identity_rpcs.sql`
- `0105_identity_hardening_followup.sql`
- `0106_private_function_privileges.sql`
- `0200_locations_tables.sql`
- `0201_account_location_preferences.sql`
- `0202_locations_staff_rls_rpcs.sql`
- `0203_location_interests.sql`
- subsequent Raahi Learning forward migrations only.

Historical mobility SQL remains recoverable from the older repository history/main branch and is deliberately excluded from the Learning execution directory.

## Permanent rule

`raahi-learning-implementation-v1/supabase/migrations/` is **Raahi Learning only**.

Old ride code elsewhere on the inherited repository must not be treated as Raahi Learning implementation. The Learning database execution contract is defined by the Learning migration chain and canonical docs.