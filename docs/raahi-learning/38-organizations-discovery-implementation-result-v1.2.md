# Raahi Learning V1.2 — Organizations / Teacher Discovery Implementation Result

Status: **IMPLEMENTED IN DEV AND PASSED. STOP GATE MOVES TO RESTRICTIONS (`0350–0351`).**

Target Supabase dev project: `iiwwmqokaeflaenhlyip` (`ap-south-1`, PostgreSQL 17.6).

## Applied migrations

- `0300_organizations_discovery_tables`
- `0301_organizations_discovery_constraints`
- `0302_organizations_discovery_rls_rpcs`
- `0303_teaching_discovery_rpcs`
- `0304_organizations_discovery_rls_projections`
- `0305_discovery_projection_security` — forward security-advisor fix
- `0306_organizations_fk_index` — forward performance-advisor fix

The originally planned `0302` responsibility was split into dependency-ordered files `0302–0304` to keep migration execution/review manageable; product behavior is unchanged.

## Implemented

- lightweight Organizations with education-relevant type, profile/logo/venue/public contact fields;
- active/ended Organization membership history;
- Organization member capabilities: `manage_profile`, `manage_teaching_options`, `manage_classes`, `manage_ads`, `manage_members`;
- creator receives the initial management capabilities;
- Organization-owned objects remain Organization-owned when a member leaves;
- Teacher profiles gated by active `teach` capability;
- Teaching Options with XOR Teacher/Organization owner;
- Location links, live-Location publication rule and Location-aware discovery;
- availability `taking_new_learners | not_taking_new_learners | no_longer_offered`;
- private Save/Unsave tables and canonical commands;
- safe public discovery/detail projections with no Organization membership/Auth data exposure;
- direct management-table reads scoped to actual Organization/Teacher authority;
- Account closure blocker for sole Organization manager responsibility;
- canonical idempotent Organization/Teaching Option commands and scoped audit.

## Runtime test result

`ORGANIZATIONS_DISCOVERY_RUNTIME_TESTS_PASS`

Verified against real PostgreSQL/Supabase behavior:

- Teacher profile and Teacher-owned Teaching Option creation;
- non-live Location publication rejected;
- Organization creation idempotency and request-fingerprint mismatch rejection;
- creator receives all expected Organization capabilities;
- delegated member capability allows Organization Teaching Option management only;
- delegated member cannot escalate into member management;
- physical XOR Teaching Option ownership constraint;
- live discovery returns eligible Teacher + Organization options;
- public projection excludes private Auth/member data;
- `not_taking_new_learners` disappears from new discovery while public detail can still show availability;
- private Save succeeds without creating contact authority;
- unrelated Account cannot directly read Organization management tables;
- direct client Saved-table mutation denied;
- ending member access does not delete Organization Teaching Option;
- ended member loses Organization authority;
- sole Organization manager blocks Account closure;
- anonymous discovery RPC execution denied.

Reusable runtime test:

`tests/db/030_organizations_discovery_runtime_smoke.sql`

All synthetic users/data ran inside a rollback transaction. Current Auth/application fixture counts remain zero.

## Advisor review

Security Advisor initially flagged the four public discovery/detail functions because they were directly exposed as `SECURITY DEFINER`. `0305` moved privileged read logic into the non-exposed `app_private` schema and converted public functions to `SECURITY INVOKER` wrappers.

After the fix:

- Security Advisor: **0 findings**.

Performance Advisor then identified one unindexed FK (`organizations.created_by_account_id`). `0306` added the covering index.

After the fix, only expected `unused_index` INFO notices remain on the empty dev database.

## Gate verdict

**PASS.**

Organizations / Teacher Discovery is complete for this slice. The next eligible slice is only:

- `0350_access_restrictions.sql`
- `0351_access_restriction_rpcs_rls.sql`

Do not begin Requests/Enquiries until Restrictions passes its own scope/audit/RLS gate.
