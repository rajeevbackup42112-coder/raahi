# Raahi Learning V1.3 — Security catalog hardening checkpoint

Status: **CATALOG SECURITY PASS IN DEV; ONE AUTH CONFIG WARNING REMAINS**  
Date: 2026-09-19

This checkpoint records a deeper Postgres/Supabase catalog audit performed after the bounded reliability and operations-readiness work in docs 71–72.

It supplements, not replaces, the existing RLS/browser/adversarial proofs.

## 1. Scope

The audit reviewed:

- RLS enablement/forcing across all public tables;
- direct table privileges for `anon` and `authenticated`;
- public views/materialized views;
- public RPC execution privileges and `SECURITY DEFINER` use;
- `app_private` schema privileges;
- `app_private` `SECURITY DEFINER` search paths and EXECUTE grants;
- policy use of deprecated `auth.role()`;
- policy/function use of user-editable user metadata for authorization;
- Storage object/bucket RLS and policy inventory;
- the frozen V1.3 boundary that anonymous marketplace browsing is deferred.

Repeatable audit:

`scripts/raahi-learning-security-catalog-audit.sql`

## 2. Catalog result

At the 2026-09-19 DEV checkpoint:

- public tables without RLS: **0**;
- public views/materialized views: **0**;
- public `SECURITY DEFINER` functions: **0**;
- public RPCs with default `PUBLIC` EXECUTE: **0**;
- public RPCs executable by `anon`: **0** after migration 1033;
- `app_private` `SECURITY DEFINER` functions executable by `PUBLIC`: **0**;
- `app_private` `SECURITY DEFINER` functions executable by `anon`: **0** after migration 1033;
- authenticated direct INSERT/UPDATE/DELETE grants on public operational tables: **0**;
- RLS policies using `auth.role()`: **0**;
- RLS policies using user-editable `user_metadata`: **0**;
- public/app-private function bodies using `auth.role()` or user-editable metadata for authorization: **0**.

All public tables currently have both RLS enabled and `FORCE ROW LEVEL SECURITY` enabled.

All audited `app_private` `SECURITY DEFINER` helpers pin `search_path` to empty.

## 3. Anonymous location RPC defect and migration 1033

Before this audit:

- `public.list_public_locations()` had EXECUTE granted to `anon`;
- `app_private.read_public_locations()` had EXECUTE granted to `anon`;
- `anon` intentionally had no USAGE on `app_private`;
- therefore the public wrapper could not actually complete for an anonymous caller and failed with `permission denied for schema app_private`.

This was classified as an **Integration / ACL defect**, not a Domain defect.

The frozen V1.3 product boundary says anonymous marketplace browsing is deferred. The fix therefore removed the unusable anonymous RPC grants rather than opening the private schema.

Migration:

`20260919131110 / 1033_v13_deferred_anonymous_location_rpc_acl`

Repository file:

`supabase/migrations/20260919131110_1033_v13_deferred_anonymous_location_rpc_acl.sql`

Change:

- revoke `anon` EXECUTE on `public.list_public_locations()`;
- revoke `anon` EXECUTE on `app_private.read_public_locations()`.

Authenticated RPC behavior remains unchanged and was verified after the migration.

Runtime proof commit:

`486bcb9a9f623358169e347a200d6a3954e8284f`

DEV E2E Harness run:

[35445058520](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35445058520)

Artifact:

- id: `10585212464`
- digest: `sha256:01569e57692c22c143cb6f70b78bfa3198cb7849e33a508e1f7dd44b2aa00ed6`

The artifact reports:

- `exact_dev_commit_deployed = true`;
- `deferred_anonymous_location_rpc_denied = true`;
- unauthenticated identity-factory rejection still passes;
- four genuine Supabase sessions still pass;
- authorized learner read / unrelated RLS denial still passes;
- four isolated browser sign-ins still pass.

The existing `public.locations` reference table still has an anonymous SELECT policy for non-retired Location reference rows. That exposes only the bounded Location directory/reference data and does not enable anonymous marketplace discovery, Enquiry, Class, messaging or private data.

## 4. Runtime regression guard

`tests/raahi-learning-e2e/dev-session-harness.mjs` now performs an unauthenticated publishable-key RPC call to `list_public_locations` and requires the call to be denied.

This keeps the deferred anonymous-RPC rule tied to a real PostgREST/Supabase runtime boundary rather than only to SQL grants on paper.

## 5. Private helper layer

The private helper design remains structurally sound:

- `PUBLIC` has no USAGE on `app_private`;
- `anon` has no USAGE on `app_private`;
- `authenticated` has USAGE but no CREATE privilege;
- private `SECURITY DEFINER` helpers do not retain `PUBLIC` or `anon` EXECUTE;
- every audited private `SECURITY DEFINER` helper sets `search_path = ''`;
- public RPC wrappers are `SECURITY INVOKER`, not `SECURITY DEFINER`;
- no public RPC retains default `PUBLIC` EXECUTE.

Authenticated EXECUTE on selected private helpers remains intentional where RLS policies/public RPC implementations require those helpers. That is different from exposing the private schema as a public Data API surface.

## 6. Storage authorization snapshot

Supabase-managed `storage.objects` and `storage.buckets` have RLS enabled.

Raahi-specific Storage object policies remain scoped to authenticated users and governed helpers for:

- `learner-private-media`;
- `public-profile-media` write ownership;
- registered `class-private`, `community-public`, and `ads-review-private` objects;
- authorized private reads.

Public bucket serving remains a separate Storage behavior and is not treated as private authorization.

At the current DEV snapshot all six Raahi Learning buckets still contain zero objects, so object-byte restore evidence remains open as documented in docs 71–72.

## 7. Current advisor state

Security Advisor still reports exactly one warning:

`auth_leaked_password_protection`

That Auth setting remains unresolved.

Performance Advisor continues to report only unused-index informational findings. The previous unindexed-foreign-key findings remain closed by migration 1032.

## 8. Current migration / advisor anchor

- DEV migration ceiling: `20260919131110 / 1033_v13_deferred_anonymous_location_rpc_acl`.
- Security Advisor: one warning, `auth_leaked_password_protection`.
- Performance Advisor: unused-index informational findings only.
- No public-launch authorization.

## 9. Remaining security/production gates

This catalog pass does not close:

1. leaked-password protection;
2. production SSL/network restriction review;
3. production OAuth/SMS/rate-limit configuration;
4. real-provider same-phone trust refresh;
5. production alert delivery/incident escalation;
6. database plus Storage-object restore rehearsal;
7. production-like load/soak/capacity;
8. production-candidate regression;
9. controlled pilot/public-launch approval.

No RLS rule or authority boundary was weakened during this hardening.
