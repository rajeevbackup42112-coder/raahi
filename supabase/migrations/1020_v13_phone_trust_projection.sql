-- Raahi Learning V1.3 — phone trust derived from Supabase Auth
-- No duplicate application timestamp: auth.users.phone_confirmed_at is server-owned
-- and is refreshed by successful phone_change and SMS OTP verification.

create or replace function app_private.read_my_phone_trust()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid := auth.uid();
  v_phone text;
  v_confirmed_at timestamptz;
  v_fresh_until timestamptz;
  v_state text;
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select nullif(trim(u.phone),''), u.phone_confirmed_at
    into v_phone, v_confirmed_at
  from auth.users u
  where u.id=v_uid;

  if not found then
    raise exception 'AUTH_USER_NOT_FOUND';
  end if;

  if v_phone is null or v_confirmed_at is null then
    v_state := 'unverified';
    v_fresh_until := null;
  else
    v_fresh_until := v_confirmed_at + interval '90 days';
    if v_fresh_until > now() then
      v_state := 'fresh';
    else
      v_state := 'stale';
    end if;
  end if;

  return jsonb_build_object(
    'state', v_state,
    'has_phone', v_phone is not null,
    'masked_phone', case when v_phone is null then null else '••••' || right(v_phone,4) end,
    'verified_at', v_confirmed_at,
    'fresh_until', v_fresh_until,
    'fresh_for_days', 90,
    'source', 'supabase_auth_phone_confirmed_at'
  );
end;
$$;

create or replace function app_private.has_fresh_phone_trust()
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select coalesce((app_private.read_my_phone_trust()->>'state')='fresh',false);
$$;

create or replace function app_private.require_fresh_phone_trust()
returns void
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if not app_private.has_fresh_phone_trust() then
    raise exception 'PHONE_TRUST_REQUIRED';
  end if;
end;
$$;

revoke all on function app_private.read_my_phone_trust(),
  app_private.has_fresh_phone_trust(),
  app_private.require_fresh_phone_trust()
from public,anon,authenticated,service_role;

grant execute on function app_private.read_my_phone_trust(),
  app_private.has_fresh_phone_trust(),
  app_private.require_fresh_phone_trust()
to authenticated;

create or replace function public.get_my_phone_trust()
returns jsonb
language sql
stable
security invoker
set search_path=''
as $$
  select app_private.read_my_phone_trust();
$$;

revoke all on function public.get_my_phone_trust() from public,anon,authenticated,service_role;
grant execute on function public.get_my_phone_trust() to authenticated;
