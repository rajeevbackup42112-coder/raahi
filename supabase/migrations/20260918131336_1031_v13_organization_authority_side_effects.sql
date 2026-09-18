-- Raahi Learning V1.3 — organization authority side effects.
-- Notifications are generic, derived conveniences. Current organization membership and
-- capabilities remain the only authority and are rechecked by every destination RPC.

create or replace function app_private.cmd_set_organization_member_capability(
  p_organization_member_id uuid,p_capability_code text,p_enabled boolean,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true);
  v_gate jsonb; v_fp text; v_org uuid; v_status text; v_target_account uuid;
  v_rows integer:=0; v_result jsonb;
begin
  if p_capability_code not in ('manage_profile','manage_teaching_options','manage_classes','manage_ads','manage_members') then
    raise exception 'INVALID_ORGANIZATION_CAPABILITY';
  end if;
  select organization_id,status,account_id into v_org,v_status,v_target_account
  from public.organization_members where id=p_organization_member_id for update;
  if not found then raise exception 'ORGANIZATION_MEMBER_NOT_FOUND'; end if;
  if not app_private.has_organization_member_capability(v_org,'manage_members')
     and not app_private.has_account_capability('platform_admin') then raise exception 'NOT_AUTHORIZED'; end if;
  if v_status<>'active' then raise exception 'ORGANIZATION_MEMBER_NOT_ACTIVE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object(
    'organization_member_id',p_organization_member_id,'capability_code',p_capability_code,'enabled',p_enabled
  ));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'set_organization_member_capability',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  if p_enabled then
    insert into public.organization_member_capabilities(organization_member_id,capability_code)
    values(p_organization_member_id,p_capability_code) on conflict do nothing;
    get diagnostics v_rows=row_count;
  else
    if p_capability_code='manage_members' and not app_private.has_account_capability('platform_admin') and not exists(
      select 1 from public.organization_members om
      join public.organization_member_capabilities c on c.organization_member_id=om.id
      where om.organization_id=v_org and om.status='active' and om.id<>p_organization_member_id
        and c.capability_code='manage_members'
    ) then raise exception 'ORGANIZATION_MUST_RETAIN_MANAGER'; end if;
    delete from public.organization_member_capabilities
    where organization_member_id=p_organization_member_id and capability_code=p_capability_code;
    get diagnostics v_rows=row_count;
  end if;

  if v_rows>0 then
    perform app_private.write_organization_audit(
      v_actor,'organization.member_capability_change',v_org,'organization_member',p_organization_member_id,null,
      jsonb_build_object('capability_code',p_capability_code,'enabled',p_enabled)
    );
    perform app_private.enqueue_notification_safely(
      v_target_account,null,'organization_access_changed','organization_member',p_organization_member_id,
      'Organization access updated','Your access in an Organization was updated.',
      jsonb_build_object('organization_id',v_org,'organization_member_id',p_organization_member_id)
    );
  end if;

  v_result:=jsonb_build_object(
    'member_id',p_organization_member_id,'capability_code',p_capability_code,
    'enabled',p_enabled,'changed',v_rows>0
  );
  perform app_private.complete_human_idempotent_command(
    v_actor,'set_organization_member_capability',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.cmd_remove_organization_member(
  p_organization_member_id uuid,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true);
  v_gate jsonb; v_fp text; v_org uuid; v_status text; v_account uuid; v_result jsonb;
begin
  select organization_id,status,account_id into v_org,v_status,v_account
  from public.organization_members where id=p_organization_member_id for update;
  if not found then raise exception 'ORGANIZATION_MEMBER_NOT_FOUND'; end if;
  if not app_private.has_organization_member_capability(v_org,'manage_members')
     and not app_private.has_account_capability('platform_admin') then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('organization_member_id',p_organization_member_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'remove_organization_member',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  if v_status='ended' then
    v_result:=jsonb_build_object('member_id',p_organization_member_id,'already_ended',true);
  else
    if not app_private.has_account_capability('platform_admin') and exists(
      select 1 from public.organization_member_capabilities
      where organization_member_id=p_organization_member_id and capability_code='manage_members'
    ) and not exists(
      select 1 from public.organization_members om
      join public.organization_member_capabilities c on c.organization_member_id=om.id
      where om.organization_id=v_org and om.status='active' and om.id<>p_organization_member_id
        and c.capability_code='manage_members'
    ) then raise exception 'ORGANIZATION_MUST_RETAIN_MANAGER'; end if;

    update public.organization_members set status='ended',ended_at=now()
    where id=p_organization_member_id;
    perform app_private.write_organization_audit(
      v_actor,'organization.member_remove',v_org,'organization_member',p_organization_member_id,null,
      jsonb_build_object('account_id',v_account)
    );
    perform app_private.enqueue_notification_safely(
      v_account,null,'organization_membership_removed','organization_member',p_organization_member_id,
      'Organization access ended','Your access to an Organization has ended.',
      jsonb_build_object('organization_id',v_org,'organization_member_id',p_organization_member_id)
    );
    v_result:=jsonb_build_object('member_id',p_organization_member_id,'already_ended',false);
  end if;

  perform app_private.complete_human_idempotent_command(
    v_actor,'remove_organization_member',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;
