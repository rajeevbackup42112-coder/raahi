-- Raahi Learning V1.3 — read-only release health snapshot
-- Safe to run against DEV or a future production-like project.
-- This script performs no DDL/DML and should be captured with a timestamp.

select
  now() as observed_at,
  datname,
  numbackends,
  xact_commit,
  xact_rollback,
  deadlocks,
  temp_files,
  temp_bytes,
  stats_reset,
  pg_size_pretty(pg_database_size(datname)) as database_size
from pg_stat_database
where datname = current_database();

select
  count(*) filter (where not granted) as waiting_locks,
  count(*) filter (where granted) as granted_locks
from pg_locks
where database = (select oid from pg_database where datname = current_database());

select count(*) as transactions_over_30s
from pg_stat_activity
where datname = current_database()
  and state <> 'idle'
  and xact_start is not null
  and now() - xact_start > interval '30 seconds';

select state, count(*) as connections
from pg_stat_activity
where datname = current_database()
group by state
order by state nulls last;

select
  calls,
  round(total_exec_time::numeric, 2) as total_exec_ms,
  round(mean_exec_time::numeric, 2) as mean_exec_ms,
  rows,
  left(query, 220) as query
from pg_stat_statements
where dbid = (select oid from pg_database where datname = current_database())
order by total_exec_time desc
limit 20;

select
  b.id as bucket_id,
  b.public,
  count(o.id) as object_count,
  coalesce(sum((o.metadata->>'size')::bigint), 0) as object_bytes
from storage.buckets b
left join storage.objects o on o.bucket_id = b.id
group by b.id, b.public
order by b.id;

select indexname, indexdef
from pg_indexes
where schemaname = 'public'
  and indexname in (
    'learner_self_access_invite_accepted_by_idx',
    'organization_member_invite_accepted_by_idx'
  )
order by indexname;


select
  'phone_trust_mode' as setting_key,
  coalesce(
    (select setting_value from app_private.runtime_settings where setting_key='phone_trust_mode'),
    '<missing>'
  ) as setting_value,
  app_private.phone_trust_enforcement_enabled() as phone_trust_enforcement_enabled;
