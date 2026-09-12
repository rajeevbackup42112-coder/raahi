# Raahi Learning V1.2 — Locations Implementation Result

Status: **IMPLEMENTED IN DEV AND PASSED LOCATIONS GATE. STOP BEFORE LEARNER SHARE CODES.**

Target Supabase project:

- project ref: `iiwwmqokaeflaenhlyip`
- region: `ap-south-1`
- PostgreSQL: 17.6

## Preflight safety correction

Before applying Locations, the inherited implementation branch was found to contain historical Raahi mobility migrations in `supabase/migrations/`. They had never been applied to the clean Learning project, but could have been replayed accidentally by future CLI operations.

The migration subtree was therefore isolated to **Raahi Learning only** before Locations execution. See `35-implementation-branch-legacy-migration-isolation.md`.

## Applied migration history for this slice

Applied in order:

1. `0200_locations_tables`
2. `0201_account_location_preferences`
3. `0202_locations_staff_rls_rpcs`
4. `0203_location_interests`
5. `0204_locations_rls_policy_consolidation` — forward performance/RLS cleanup after advisor review

`0204` consolidates overlapping authenticated Location SELECT policies into one authenticated policy plus one anon policy; no business behavior changed.

## Implemented objects and behavior

Tables:

- `locations`
- `location_staff_assignments`
- `account_location_preferences`
- `location_interests`

Audit was extended with optional `location_id` context.

Location lifecycle:

`interest_only → preparing → live ↔ paused → retired`

Implemented rules:

- new Location starts `interest_only`;
- only platform-admin capability may create/govern Location lifecycle;
- `retired` is terminal in this V1.2 command path;
- selected Location is an Account preference only and does not own/move established relationships;
- retired Location cannot become the selected Location;
- Local Manager authority is an explicit active Location-scoped assignment;
- Local Manager authority never comes from navigation/workspace selection;
- active Local Manager responsibility blocks Account closure until assignment is ended;
- `Register Interest` requires an authenticated active Account;
- Location Interest is allowed only in `interest_only` or `preparing`;
- `learn` and `teach` interest may coexist;
- only one active `(Location, Account, intent)` row exists;
- withdrawal preserves history and later re-registration may create a new active historical row;
- registering interest never creates a Learning Request or Teaching Option;
- Local Manager gets aggregate interest counts for their own Location, not named interest rows;
- platform admins retain cross-Location governance visibility;
- ordinary/anon users cannot see retired Locations;
- normal clients have no direct mutation grants on Location operational tables.

## Canonical commands added

- `create_location`
- `set_location_state`
- `assign_local_manager`
- `end_location_staff_assignment`
- `set_selected_location`
- `register_location_interest`
- `withdraw_location_interest`
- `get_location_interest_counts`

Private authorization/command helpers remain in `app_private`; public RPC wrappers are `SECURITY INVOKER` and granted only to the intended role.

## Real runtime test result

Primary transactional suite returned:

`LOCATIONS_RUNTIME_TESTS_PASS`

It verified against the real PostgreSQL/Supabase runtime:

- platform admin creates Location;
- non-admin creation/governance denied;
- valid lifecycle transitions succeed;
- skipped/invalid lifecycle transition fails;
- Location creation and selection idempotency/fingerprint behavior;
- selected-Location changes do not mutate Learner/access relationships;
- retired Location selection rejected;
- Interest registration works for `interest_only` and `preparing`;
- live Location rejects launch interest;
- duplicate/retry Interest registration produces one active tuple;
- `learn` + `teach` can coexist;
- withdraw + re-register preserves history with one active tuple;
- direct authenticated writes to preferences/interests denied;
- duplicate Local Manager assignment does not create duplicate active assignment;
- exact-Location Local Manager aggregate readiness allowed;
- wrong-Location Local Manager aggregate request denied;
- Local Manager cannot read other users' named Interest rows;
- Local Manager cannot govern Location lifecycle;
- active Local Manager assignment blocks Account closure;
- ordinary authenticated/anon callers cannot see retired Location;
- platform admin can see retired Location;
- anon cannot execute protected Interest RPC;
- ending Local Manager assignment removes scope and closure blocker;
- Location-scoped audit and idempotency records are written.

A second focused suite after the RLS forward fix returned:

`LOCATIONS_POST_HARDENING_SMOKE_PASS`

It additionally verified:

- `live → paused → live` behavior;
- paused Location rejects launch interest;
- cross-account preference isolation;
- direct staff-assignment mutation denial;
- retired Location rejects new Local Manager assignment;
- consolidated Location RLS still hides retired rows from ordinary users while allowing platform-admin visibility.

Reusable SQL is committed on the implementation branch:

- `tests/db/020_locations_runtime_smoke.sql`
- `tests/db/021_locations_post_hardening_smoke.sql`

All synthetic Auth/application data was executed inside rollback transactions.

Final counts after both suites:

- Auth users: 0
- Accounts: 0
- Learners: 0
- Locations: 0
- Location staff assignments: 0
- Location preferences: 0
- Location interests: 0
- Audit rows: 0
- Idempotency rows: 0

## Advisor / privilege review

Security Advisor after Locations: **0 findings**.

Performance Advisor initially reported one warning for multiple permissive authenticated SELECT policies on `locations`. `0204_locations_rls_policy_consolidation` fixed it. After the forward fix, only expected `unused_index` INFO notices remain on the empty development database; there are no missing-FK-index or overlapping-policy warnings.

Function ACL inspection confirmed no unintended `PUBLIC EXECUTE` on new private Location functions. Sensitive internal helpers such as audit/blocker helpers remain postgres-only; only explicitly required helper/command functions are executable by `authenticated`.

## Locations gate verdict

**PASS.**

The Locations slice has passed migration, lifecycle, RLS, command, idempotency, scope, privacy, account-responsibility and post-hardening checks.

Per the controlled implementation plan, implementation now **stops before `0250_learner_share_codes.sql`**. Learner share codes or later modules must not begin until a deliberate continuation from this checkpoint.