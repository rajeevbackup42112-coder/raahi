-- Raahi Learning V1.4L — Realtime is invalidation only.
-- PostgreSQL/RPC projections remain authoritative; clients refetch after an allowed change.
-- Publish only low-risk invalidation surfaces. Sensitive message/content tables stay out.
do $$
declare
  v_table text;
  v_tables text[] := array[
    'notifications',
    'teacher_profiles',
    'teaching_options',
    'teaching_option_locations',
    'organizations',
    'learning_requests',
    'community_posts',
    'community_comments',
    'community_post_reactions',
    'community_comment_reactions'
  ];
begin
  if not exists (select 1 from pg_publication where pubname='supabase_realtime') then
    raise exception 'SUPABASE_REALTIME_PUBLICATION_MISSING';
  end if;

  foreach v_table in array v_tables loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname='supabase_realtime'
        and schemaname='public'
        and tablename=v_table
    ) then
      execute format('alter publication supabase_realtime add table public.%I',v_table);
    end if;
  end loop;
end
$$;
