-- Raahi Learning V1.2 — Preserve legitimate Enquiry history access while Account is paused
-- Write/decision commands still require active authority. This helper is read-only.

create or replace function app_private.can_read_provider_enquiry(p_provider_account_id uuid,p_provider_organization_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select app_private.has_account_capability('platform_admin')
    or (
      p_provider_account_id is not null
      and p_provider_account_id=app_private.current_account_id()
      and exists(select 1 from public.accounts a where a.id=p_provider_account_id and a.lifecycle_status<>'closed')
    )
    or (
      p_provider_organization_id is not null
      and exists(
        select 1
        from public.organization_members om
        join public.organization_member_capabilities c on c.organization_member_id=om.id and c.capability_code='manage_teaching_options'
        join public.accounts a on a.id=om.account_id
        join public.organizations o on o.id=om.organization_id
        where om.organization_id=p_provider_organization_id
          and om.account_id=app_private.current_account_id()
          and om.status='active'
          and a.lifecycle_status<>'closed'
          and o.status<>'closed'
      )
    );
$$;

create or replace function app_private.can_read_enquiry(p_enquiry_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_learner uuid; v_provider_account uuid; v_provider_org uuid;
begin
  select learner_id,provider_account_id,provider_organization_id into v_learner,v_provider_account,v_provider_org
  from public.enquiries where id=p_enquiry_id;
  if not found then return false; end if;
  if app_private.has_account_capability('platform_admin') then return true; end if;
  if app_private.can_read_learner_relationship(v_learner) then return true; end if;
  return app_private.can_read_provider_enquiry(v_provider_account,v_provider_org);
end; $$;

revoke all on function app_private.can_read_provider_enquiry(uuid,uuid) from public,anon,authenticated,service_role;
revoke all on function app_private.can_read_enquiry(uuid) from public,anon,authenticated,service_role;
grant execute on function app_private.can_read_provider_enquiry(uuid,uuid),app_private.can_read_enquiry(uuid) to authenticated;
