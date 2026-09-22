-- Raahi Learning V1.4H — activate StartMessaging-backed phone trust.
-- Google remains the primary login. This setting only enables the already-scoped
-- fresh-phone gate for commands listed by command_requires_fresh_phone_trust().

insert into app_private.runtime_settings(setting_key,setting_value,updated_at)
values ('phone_trust_mode','phone_trust_required',now())
on conflict(setting_key) do update
set setting_value=excluded.setting_value,
    updated_at=excluded.updated_at;

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

do $
begin
  if not app_private.phone_trust_enforcement_enabled() then
    raise exception 'PHONE_TRUST_ACTIVATION_FAILED';
  end if;
  if (public.get_phone_trust_policy()->>'mode') <> 'phone_trust_required' then
    raise exception 'PHONE_TRUST_POLICY_PROJECTION_FAILED';
  end if;
end
$;
