-- Raahi Learning V1.3 — read-only security catalog audit
-- Expected use: DEV and future production-like projects before a release.
-- All "finding" queries should return zero rows unless an exception is explicitly
-- documented in the owning security/release-readiness document.
-- This script performs no DDL/DML.

-- 1. Exposed public tables must have RLS enabled.
select 'PUBLIC_TABLE_RLS_DISABLED' as finding, c.relname as object_name
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r','p')
  and not c.relrowsecurity
order by c.relname;

-- 2. Raahi Learning currently forces RLS on all public operational tables.
-- Treat a deviation as review-required rather than silently accepting it.
select 'PUBLIC_TABLE_RLS_NOT_FORCED' as finding, c.relname as object_name
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r','p')
  and not c.relforcerowsecurity
order by c.relname;

-- 3. No public view/materialized view should become an accidental RLS bypass.
select
  'PUBLIC_VIEW_REVIEW_REQUIRED' as finding,
  c.relname as object_name,
  c.relkind,
  c.reloptions,
  has_table_privilege('anon', c.oid, 'SELECT') as anon_select,
  has_table_privilege('authenticated', c.oid, 'SELECT') as authenticated_select
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('v','m')
  and (
    has_table_privilege('anon', c.oid, 'SELECT')
    or has_table_privilege('authenticated', c.oid, 'SELECT')
  )
  and not (
    c.relkind = 'v'
    and coalesce(c.reloptions, array[]::text[]) @> array['security_invoker=true']
  )
order by c.relname;

-- 4. Public RPCs must not be SECURITY DEFINER and must not retain default PUBLIC execute.
select
  case
    when p.prosecdef then 'PUBLIC_RPC_SECURITY_DEFINER'
    else 'PUBLIC_RPC_PUBLIC_EXECUTE'
  end as finding,
  p.proname,
  pg_get_function_identity_arguments(p.oid) as args
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prokind = 'f'
  and (
    p.prosecdef
    or has_function_privilege('public', p.oid, 'EXECUTE')
  )
order by p.proname, args;

-- 5. RLS policies must not use deprecated auth.role() or user-editable user_metadata.
select
  'RLS_POLICY_AUTH_PATTERN_REVIEW' as finding,
  schemaname,
  tablename,
  policyname,
  cmd,
  roles,
  qual,
  with_check
from pg_policies
where schemaname in ('public','storage')
  and (
    coalesce(qual,'') ilike '%auth.role()%'
    or coalesce(with_check,'') ilike '%auth.role()%'
    or coalesce(qual,'') ilike '%user_metadata%'
    or coalesce(with_check,'') ilike '%user_metadata%'
  )
order by schemaname, tablename, policyname;

-- 6. app_private must not be available to PUBLIC/anon, and authenticated must not CREATE there.
select 'APP_PRIVATE_SCHEMA_PRIVILEGE' as finding, n.nspname as object_name,
  has_schema_privilege('public', n.oid, 'USAGE') as public_usage,
  has_schema_privilege('anon', n.oid, 'USAGE') as anon_usage,
  has_schema_privilege('authenticated', n.oid, 'CREATE') as authenticated_create
from pg_namespace n
where n.nspname = 'app_private'
  and (
    has_schema_privilege('public', n.oid, 'USAGE')
    or has_schema_privilege('anon', n.oid, 'USAGE')
    or has_schema_privilege('authenticated', n.oid, 'CREATE')
  );

-- 7. SECURITY DEFINER helpers must pin search_path and must not be executable by PUBLIC/anon.
select
  case
    when has_function_privilege('public', p.oid, 'EXECUTE') then 'PRIVATE_DEFINER_PUBLIC_EXECUTE'
    when has_function_privilege('anon', p.oid, 'EXECUTE') then 'PRIVATE_DEFINER_ANON_EXECUTE'
    else 'PRIVATE_DEFINER_SEARCH_PATH'
  end as finding,
  p.proname,
  pg_get_function_identity_arguments(p.oid) as args,
  p.proconfig,
  p.proacl
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'app_private'
  and p.prokind = 'f'
  and p.prosecdef
  and (
    has_function_privilege('public', p.oid, 'EXECUTE')
    or has_function_privilege('anon', p.oid, 'EXECUTE')
    or p.proconfig is null
    or not exists (
      select 1 from unnest(p.proconfig) cfg where cfg = 'search_path=""'
    )
  )
order by p.proname, args;

-- 8. Deferred anonymous marketplace/location RPC contract.
select 'DEFERRED_ANON_LOCATION_RPC_REGRANTED' as finding, 'public.list_public_locations()' as object_name
where has_function_privilege('anon', 'public.list_public_locations()', 'EXECUTE')
union all
select 'DEFERRED_ANON_LOCATION_HELPER_REGRANTED', 'app_private.read_public_locations()'
where has_function_privilege('anon', 'app_private.read_public_locations()', 'EXECUTE');

-- 9. Authenticated application clients must not get direct operational-table DML grants.
select
  'AUTHENTICATED_DIRECT_OPERATIONAL_DML' as finding,
  c.relname as object_name,
  has_table_privilege('authenticated', c.oid, 'INSERT') as can_insert,
  has_table_privilege('authenticated', c.oid, 'UPDATE') as can_update,
  has_table_privilege('authenticated', c.oid, 'DELETE') as can_delete
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r','p')
  and (
    has_table_privilege('authenticated', c.oid, 'INSERT')
    or has_table_privilege('authenticated', c.oid, 'UPDATE')
    or has_table_privilege('authenticated', c.oid, 'DELETE')
  )
order by c.relname;

-- 10. Inventory Storage policies for review. This section is evidence, not a zero-row assertion.
select schemaname, tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'storage'
  and tablename in ('objects','buckets')
order by tablename, policyname;
