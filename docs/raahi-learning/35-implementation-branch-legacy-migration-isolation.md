# Raahi Learning V1.2 — Implementation Branch Legacy Migration Isolation

Status: **REQUIRED SAFETY CORRECTION BEFORE LOCATIONS.**

During the Locations preflight, the implementation branch was found to have inherited the older Raahi mobility application's historical timestamped SQL migrations under `supabase/migrations/`.

Those files were **not** present in the clean Raahi Learning Supabase project and were never applied there. Foundation + Identity had been applied only through the explicit Supabase migration actions recorded in the implementation result.

However, leaving old mobility migrations beside Raahi Learning migrations creates a future operational hazard: a normal `supabase db push` or local reset could attempt to replay unrelated ride/driver/booking schema into the Learning project.

## Correction

Before continuing with Locations, the implementation branch migration directory is to be reduced to the Raahi Learning migration chain only:

- `0001_extensions_helpers.sql`
- `0002_common_updated_at.sql`
- `0100_identity_tables.sql`
- `0101_identity_constraints_indexes.sql`
- `0102_command_infrastructure.sql`
- `0103_identity_rls_helpers.sql`
- `0104_identity_rpcs.sql`
- `0105_identity_hardening_followup.sql`
- `0106_private_function_privileges.sql`
- subsequent Raahi Learning migrations only

Historical mobility SQL remains available through the older repository history/main branch and does not belong in the Learning migration execution directory.

## Rule

`raahi-learning-implementation-v1/supabase/migrations/` is henceforth **Raahi Learning only**.

Old ride code elsewhere on the inherited branch must not be treated as Raahi Learning implementation. The database execution contract is defined by the Learning migration chain and canonical docs.