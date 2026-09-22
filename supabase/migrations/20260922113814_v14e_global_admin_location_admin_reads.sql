-- Raahi Learning V1.4E — Global Admin read projections for routine Location-admin management.
-- Consequential writes remain on existing canonical assign/end commands.

create or replace function app_private.read_platform_location_admins()
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if app_private.current_account_id() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not app_private.has_account_capability('platform_admin') then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;

  return query
  select jsonb_build_object(
    'location_id', l.id,
    'location_name', l.name,
    'location_slug', l.slug,
    'location_state', l.state,
    'local_managers',
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'assignment_id', lsa.id,
            'account_id', a.id,
            'display_name', a.display_name,
            'email', u.email,
            'created_at', lsa.created_at
          )
          order by lsa.created_at, a.display_name
        ) filter (where lsa.id is not null),
        '[]'::jsonb
      )
  )
  from public.locations l
  left join public.location_staff_assignments lsa
    on lsa.location_id = l.id and lsa.staff_type = 'local_manager' and lsa.status = 'active'
  left join public.accounts a on a.id = lsa.account_id
  left join auth.users u on u.id = a.auth_user_id
  where l.state <> 'retired'
  group by l.id, l.name, l.slug, l.state
  order by case l.state when 'live' then 0 when 'preparing' then 1 when 'paused' then 2 else 3 end, l.name, l.id;
end;
$$;

create or replace function app_private.resolve_platform_account_email(p_email text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_email text;
  v_account uuid;
  v_display_name text;
  v_lifecycle text;
  v_is_platform boolean;
  v_manager_locations jsonb;
begin
  if app_private.current_account_id() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not app_private.has_account_capability('platform_admin') then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;

  v_email := lower(btrim(coalesce(p_email, '')));
  if char_length(v_email) not between 3 and 320 or position('@' in v_email) = 0 then raise exception 'INVALID_EMAIL'; end if;

  select a.id, a.display_name, a.lifecycle_status
    into v_account, v_display_name, v_lifecycle
  from public.accounts a
  join auth.users u on u.id = a.auth_user_id
  where lower(u.email) = v_email
  limit 1;

  if v_account is null or v_lifecycle <> 'active' then
    return jsonb_build_object('found', false, 'email', v_email);
  end if;

  select exists(
    select 1 from public.account_capabilities ac
    where ac.account_id = v_account and ac.capability_code = 'platform_admin' and ac.status = 'active'
  ) into v_is_platform;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'location_id', l.id,
        'location_name', l.name,
        'location_state', l.state,
        'assignment_id', lsa.id
      ) order by l.name, l.id
    ),
    '[]'::jsonb
  )
  into v_manager_locations
  from public.location_staff_assignments lsa
  join public.locations l on l.id = lsa.location_id
  where lsa.account_id = v_account and lsa.staff_type = 'local_manager' and lsa.status = 'active';

  return jsonb_build_object(
    'found', true,
    'account_id', v_account,
    'display_name', v_display_name,
    'email', v_email,
    'lifecycle_status', v_lifecycle,
    'is_platform_admin', v_is_platform,
    'manager_locations', v_manager_locations
  );
end;
$$;

revoke all on function app_private.read_platform_location_admins() from public, anon, authenticated, service_role;
revoke all on function app_private.resolve_platform_account_email(text) from public, anon, authenticated, service_role;
grant execute on function app_private.read_platform_location_admins() to authenticated;
grant execute on function app_private.resolve_platform_account_email(text) to authenticated;

create or replace function public.get_platform_location_admins()
returns setof jsonb
language sql stable security invoker set search_path = ''
as $$ select * from app_private.read_platform_location_admins(); $$;

create or replace function public.resolve_platform_account_email(p_email text)
returns jsonb
language sql stable security invoker set search_path = ''
as $$ select app_private.resolve_platform_account_email(p_email); $$;

revoke all on function public.get_platform_location_admins() from public, anon, authenticated, service_role;
revoke all on function public.resolve_platform_account_email(text) from public, anon, authenticated, service_role;
grant execute on function public.get_platform_location_admins() to authenticated;
grant execute on function public.resolve_platform_account_email(text) to authenticated;
