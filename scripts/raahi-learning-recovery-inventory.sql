-- Raahi Learning V1.3 — read-only recovery inventory
-- Capture immediately before a backup/restore rehearsal and again on the
-- isolated restored target. Compare the JSON inventories before claiming
-- recovery success. This script performs no DDL/DML.

with latest_migration as (
  select version, name
  from supabase_migrations.schema_migrations
  order by version desc
  limit 1
),
bucket_inventory as (
  select coalesce(
    jsonb_object_agg(
      b.id,
      jsonb_build_object(
        'public', b.public,
        'object_count', coalesce(x.object_count, 0),
        'object_bytes', coalesce(x.object_bytes, 0)
      )
      order by b.id
    ),
    '{}'::jsonb
  ) as value
  from storage.buckets b
  left join (
    select
      bucket_id,
      count(*)::bigint as object_count,
      coalesce(sum((metadata->>'size')::bigint),0)::bigint as object_bytes
    from storage.objects
    group by bucket_id
  ) x on x.bucket_id=b.id
),
security_summary as (
  select jsonb_build_object(
    'public_tables_without_rls',
      count(*) filter (where not c.relrowsecurity),
    'public_tables_without_forced_rls',
      count(*) filter (where not c.relforcerowsecurity),
    'public_views',
      count(*) filter (where c.relkind in ('v','m'))
  ) as value
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relkind in ('r','p','v','m')
),
function_summary as (
  select jsonb_build_object(
    'public_functions', count(*) filter (where n.nspname='public'),
    'public_security_definer_functions',
      count(*) filter (where n.nspname='public' and p.prosecdef),
    'private_security_definer_functions',
      count(*) filter (where n.nspname='app_private' and p.prosecdef),
    'private_definers_with_public_execute',
      count(*) filter (
        where n.nspname='app_private'
          and p.prosecdef
          and has_function_privilege('public',p.oid,'EXECUTE')
      ),
    'private_definers_with_anon_execute',
      count(*) filter (
        where n.nspname='app_private'
          and p.prosecdef
          and has_function_privilege('anon',p.oid,'EXECUTE')
      )
  ) as value
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','app_private')
    and p.prokind='f'
)
select jsonb_pretty(jsonb_build_object(
  'observed_at_utc', now(),
  'database_size_bytes', pg_database_size(current_database()),
  'latest_migration', (select to_jsonb(latest_migration) from latest_migration),
  'counts', jsonb_build_object(
    'auth_users', (select count(*) from auth.users),
    'accounts', (select count(*) from public.accounts),
    'learners', (select count(*) from public.learners),
    'account_learner_access', (select count(*) from public.account_learner_access),
    'organizations', (select count(*) from public.organizations),
    'organization_members', (select count(*) from public.organization_members),
    'teaching_options', (select count(*) from public.teaching_options),
    'learning_requests', (select count(*) from public.learning_requests),
    'enquiries', (select count(*) from public.enquiries),
    'enquiry_messages', (select count(*) from public.enquiry_messages),
    'class_invitations', (select count(*) from public.class_invitations),
    'classes', (select count(*) from public.classes),
    'class_memberships', (select count(*) from public.class_memberships),
    'class_learner_threads', (select count(*) from public.class_learner_threads),
    'class_learner_messages', (select count(*) from public.class_learner_messages),
    'activities', (select count(*) from public.activities),
    'submissions', (select count(*) from public.submissions),
    'tests', (select count(*) from public.tests),
    'test_attempts', (select count(*) from public.test_attempts),
    'community_posts', (select count(*) from public.community_posts),
    'community_comments', (select count(*) from public.community_comments),
    'ad_campaigns', (select count(*) from public.ad_campaigns),
    'ad_placements', (select count(*) from public.ad_placements),
    'notifications', (select count(*) from public.notifications),
    'audit_log', (select count(*) from public.audit_log),
    'file_assets', (select count(*) from public.file_assets)
  ),
  'storage', (select value from bucket_inventory),
  'security', (select value from security_summary),
  'functions', (select value from function_summary)
)) as recovery_inventory;
