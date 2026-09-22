-- Raahi Learning V1.4H — activate StartMessaging-backed phone trust.
-- Google remains the primary login. This setting only enables the already-scoped
-- fresh-phone gate for commands listed by command_requires_fresh_phone_trust().

insert into app_private.runtime_settings(setting_key,setting_value,updated_at)
values ('phone_trust_mode','phone_trust_required',now())
on conflict(setting_key) do update
set setting_value=excluded.setting_value,
    updated_at=excluded.updated_at;

do $$
begin
  if not app_private.phone_trust_enforcement_enabled() then
    raise exception 'PHONE_TRUST_ACTIVATION_FAILED';
  end if;
end
$$;
