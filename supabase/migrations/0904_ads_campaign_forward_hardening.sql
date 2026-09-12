-- Raahi Learning V1.2 — forward hardening after real runtime/advisor checks.
-- Keeps clean migration replay consistent with the functions exercised in dev.

create index ad_campaign_revisions_created_by_idx
  on public.ad_campaign_revisions(created_by_account_id,created_at desc);

create or replace function app_private.cmd_set_advertising_eligibility(p_account_id uuid,p_organization_id uuid,p_state text,p_reason text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_id uuid; v_result jsonb;
begin
  if not (app_private.has_account_capability('platform_admin') or app_private.has_account_capability('ads_commercial')) then raise exception 'NOT_AUTHORIZED'; end if;
  if (p_account_id is not null)::int+(p_organization_id is not null)::int<>1 then raise exception 'ADVERTISING_SUBJECT_REQUIRED'; end if;
  if p_state not in ('not_enabled','under_review','enabled','restricted','disabled') then raise exception 'INVALID_ELIGIBILITY_STATE'; end if;
  if p_state in ('restricted','disabled') and nullif(btrim(p_reason),'') is null then raise exception 'ELIGIBILITY_REASON_REQUIRED'; end if;
  if p_account_id is not null and not exists(select 1 from public.accounts where id=p_account_id and lifecycle_status<>'closed') then raise exception 'ACCOUNT_NOT_ELIGIBLE'; end if;
  if p_organization_id is not null and not exists(select 1 from public.organizations where id=p_organization_id and status<>'closed') then raise exception 'ORGANIZATION_NOT_ELIGIBLE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('account_id',p_account_id,'organization_id',p_organization_id,'state',p_state,'reason',p_reason));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'set_advertising_eligibility',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if p_account_id is not null then
    insert into public.advertising_eligibility(account_id,organization_id,state,reason) values(p_account_id,null,p_state,nullif(btrim(p_reason),''))
      on conflict (account_id) where account_id is not null do update set state=excluded.state,reason=excluded.reason returning id into v_id;
  else
    insert into public.advertising_eligibility(account_id,organization_id,state,reason) values(null,p_organization_id,p_state,nullif(btrim(p_reason),''))
      on conflict (organization_id) where organization_id is not null do update set state=excluded.state,reason=excluded.reason returning id into v_id;
  end if;
  perform app_private.write_audit(v_actor,'ads.eligibility_set','advertising_eligibility',v_id,null,null,jsonb_build_object('account_id',p_account_id,'organization_id',p_organization_id,'state',p_state));
  v_result:=jsonb_build_object('eligibility_id',v_id,'state',p_state);
  perform app_private.complete_human_idempotent_command(v_actor,'set_advertising_eligibility',p_idempotency_key,v_result); return v_result;
end; $$;

-- `Enquire` is meaningful only when Sponsored creative points at a Teaching Option;
-- the actual Sponsored Enquiry is created later from an eligible Placement.
create or replace function app_private.validate_ad_revision_destination(p_campaign_id uuid,p_destination_type text,p_destination_id uuid,p_external_url text,p_cta_type text)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_account uuid; v_org uuid;
begin
  select account_id,organization_id into v_account,v_org from public.ad_campaigns where id=p_campaign_id;
  if not found then return false; end if;
  if p_destination_type not in ('teaching_option','organization','external_url') or p_cta_type not in ('enquire','learn_more','visit_site') then return false; end if;
  if p_cta_type='enquire' and p_destination_type<>'teaching_option' then return false; end if;
  if p_destination_type='teaching_option' then
    return p_external_url is null and p_destination_id is not null and exists(select 1 from public.teaching_options t where t.id=p_destination_id and ((v_account is not null and t.teacher_account_id=v_account) or (v_org is not null and t.organization_id=v_org)));
  elsif p_destination_type='organization' then
    return p_external_url is null and v_org is not null and p_destination_id=v_org;
  else
    return p_destination_id is null and nullif(btrim(p_external_url),'') is not null;
  end if;
end; $$;

revoke all on function app_private.validate_ad_revision_destination(uuid,text,uuid,text,text) from public,anon,authenticated,service_role;
