# Raahi Learning V1.2 — Scoped Access Restrictions Implementation Result

Status: **IMPLEMENTED IN DEV AND PASSED. STOP GATE MOVES TO REQUESTS / ENQUIRIES (`0400–0401`).**

Target Supabase dev project: `iiwwmqokaeflaenhlyip` (`ap-south-1`, PostgreSQL 17.6).

## Applied migrations

- `0350_access_restrictions`
- `0351_access_restriction_rpcs_rls`

## Implemented

`access_restrictions` supports exactly one subject — Account or Organization — and a precise scope:

- `public_discovery`
- `new_enquiries`
- `messaging`
- `class_access`
- `community`
- `ads`

Optional `location_id` makes the restriction Location-scoped; null means platform-wide for that exact scope. State is `active | lifted | expired` and history is retained.

Canonical behavior:

- only active `platform_admin` or `safety_reviewer` authority may apply/lift restrictions;
- ordinary Accounts and Local Manager status alone do not confer restriction authority;
- one active restriction exists per subject/scope/Location tuple;
- consequential apply/lift commands are idempotent and audited;
- timed restrictions can expire through a private system helper with system audit;
- restriction subjects cannot read moderation-private restriction rows;
- normal clients cannot directly mutate the restriction table;
- public-discovery restriction is now enforced by Teacher/Organization discovery/detail projections;
- a Location-scoped discovery restriction stays local;
- unrelated scopes such as `ads` do not silently hide a provider from discovery.

## Runtime result

`ACCESS_RESTRICTIONS_RUNTIME_TESTS_PASS`

Real PostgreSQL/Supabase tests verified:

- non-reviewer apply denied;
- Account restriction apply;
- Organization restriction apply;
- same-key/same-request idempotent replay;
- same key with different request rejected;
- same exact active tuple with a different key reuses one logical active restriction;
- Location-specific Teacher discovery restriction affects only that Location;
- Organization global discovery restriction affects all Locations;
- Account and Organization restrictions remain independent;
- unrelated `ads` restriction does not affect discovery;
- lift restores the affected discovery behavior;
- restriction subject cannot read raw moderation rows;
- direct client insert denied;
- reviewer can read restriction state;
- private details are not copied into generic audit metadata;
- timed restriction expires through the system helper;
- expiry creates a system audit record.

Reusable runtime suite:

`tests/db/035_access_restrictions_runtime_smoke.sql`

All synthetic test data ran inside rollback transactions.

## Advisor review

After the slice:

- Supabase Security Advisor: **0 findings**;
- Performance Advisor: only expected `unused_index` INFO findings on the empty development database; no missing-FK or policy warning remains.

## Gate verdict

**PASS.**

Next eligible slice only:

- `0400_requests_enquiries_tables.sql`
- `0401_requests_enquiries_rls_rpcs.sql`

Do not proceed to Classes until Requests/Enquiries passes its state/privacy/authority/idempotency/RLS gate.
