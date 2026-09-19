-- Raahi Learning V1.3
-- Controlled-pilot trust mode.
-- Fail-closed design: if the setting is absent/unknown, phone trust is enforced.
-- The explicit pilot value temporarily treats authenticated Google identity as
-- sufficient trust for the controlled Gomoh + Dhanbad pilot.

create table if not exists app_private.runtime_settings (
  setting_key text primary key,
  setting_value text not null,
  updated_at timestamptz not null default now()
);

revoke all on table app_private.runtime_settings from public, anon, authenticated;

insert into app_private.runtime_settings(setting_key,setting_value,updated_at)
values ('phone_trust_mode','controlled_pilot_google_only',now())
on conflict(setting_key) do update
set setting_value=excluded.setting_value,
    updated_at=excluded.updated_at;

create or replace function app_private.phone_trust_enforcement_enabled()
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select coalesce(
    (
      select setting_value <> 'controlled_pilot_google_only'
      from app_private.runtime_settings
      where setting_key='phone_trust_mode'
    ),
    true
  );
$function$;

revoke all on function app_private.phone_trust_enforcement_enabled() from public, anon, authenticated;

create or replace function app_private.require_fresh_phone_trust()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if not app_private.phone_trust_enforcement_enabled() then
    return;
  end if;

  if not app_private.has_fresh_phone_trust() then
    raise exception 'PHONE_TRUST_REQUIRED';
  end if;
end;
$function$;

revoke all on function app_private.require_fresh_phone_trust() from public, anon;
grant execute on function app_private.require_fresh_phone_trust() to authenticated;

create or replace function public.get_phone_trust_policy()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
  select jsonb_build_object(
    'mode',
      case
        when app_private.phone_trust_enforcement_enabled()
          then 'phone_trust_required'
        else 'controlled_pilot_google_only'
      end,
    'phone_verification_required',
      app_private.phone_trust_enforcement_enabled()
  );
$function$;

revoke all on function public.get_phone_trust_policy() from public, anon;
grant execute on function public.get_phone_trust_policy() to authenticated;
