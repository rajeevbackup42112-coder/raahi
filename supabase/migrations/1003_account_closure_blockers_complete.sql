-- Raahi Learning V1.2 — complete Account closure blockers after all V1 domains exist.

create or replace function app_private.account_closure_blockers(p_account_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
with blockers as (
  select jsonb_build_object('code','SOLE_MANAGER_RESPONSIBILITY','learner_id',ala.learner_id) blocker
  from public.account_learner_access ala
  where ala.account_id=p_account_id and ala.access_type='manage' and ala.status='active'
    and not exists(
      select 1 from public.account_learner_access s join public.accounts a on a.id=s.account_id and a.lifecycle_status<>'closed'
      where s.learner_id=ala.learner_id and s.access_type='self' and s.status='active'
    )

  union all
  select jsonb_build_object('code','ACTIVE_LOCAL_MANAGER_ASSIGNMENT','location_id',lsa.location_id,'assignment_id',lsa.id)
  from public.location_staff_assignments lsa
  where lsa.account_id=p_account_id and lsa.status='active'

  union all
  select jsonb_build_object('code','SOLE_ORGANIZATION_MANAGER','organization_id',om.organization_id,'member_id',om.id)
  from public.organization_members om
  join public.organization_member_capabilities c on c.organization_member_id=om.id and c.capability_code='manage_members'
  where om.account_id=p_account_id and om.status='active'
    and not exists(
      select 1 from public.organization_members other
      join public.organization_member_capabilities oc on oc.organization_member_id=other.id and oc.capability_code='manage_members'
      join public.accounts oa on oa.id=other.account_id and oa.lifecycle_status='active'
      where other.organization_id=om.organization_id and other.status='active' and other.id<>om.id
    )

  union all
  select jsonb_build_object('code','RESPONSIBLE_TEACHER_ACTIVE_CLASS','class_id',c.id)
  from public.classes c
  where c.responsible_teacher_account_id=p_account_id and c.state in ('draft','active')

  union all
  select jsonb_build_object('code','ACTIVE_PROVIDER_ENQUIRY','enquiry_id',e.id)
  from public.enquiries e
  where e.provider_account_id=p_account_id and e.state in ('pending','active')

  union all
  select jsonb_build_object('code','ACTIVE_ACCOUNT_AD_CAMPAIGN','campaign_id',c.id)
  from public.ad_campaigns c
  where c.account_id=p_account_id and c.state='submitted'

  union all
  select jsonb_build_object('code','UNRESOLVED_SAFETY_REVIEW','report_id',r.id)
  from public.reports r
  where r.target_type='account' and r.target_id=p_account_id and r.status in ('open','under_review')
)
select coalesce(jsonb_agg(blocker),'[]'::jsonb) from blockers;
$$;

-- Final closure implementation also ends non-blocking scoped authority so a closed
-- Account cannot remain a phantom active Organization member or launch-interest signal.
create or replace function app_private.cmd_request_account_closure(p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(false); v_gate jsonb;
  v_fingerprint text:=app_private.request_fingerprint('{}'::jsonb); v_status text; v_blockers jsonb; v_result jsonb;
begin
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'request_account_closure',p_idempotency_key,v_fingerprint);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select lifecycle_status into v_status from public.accounts where id=v_actor for update;
  if v_status='closed' then
    v_result:=jsonb_build_object('closed',true,'already_closed',true,'blockers','[]'::jsonb);
    perform app_private.complete_human_idempotent_command(v_actor,'request_account_closure',p_idempotency_key,v_result);
    return v_result;
  end if;

  v_blockers:=app_private.account_closure_blockers(v_actor);
  if jsonb_array_length(v_blockers)>0 then
    v_result:=jsonb_build_object('closed',false,'already_closed',false,'blockers',v_blockers);
    perform app_private.complete_human_idempotent_command(v_actor,'request_account_closure',p_idempotency_key,v_result);
    return v_result;
  end if;

  update public.account_learner_access set status='ended',ended_at=now() where account_id=v_actor and status='active';
  update public.account_capabilities set status='revoked',revoked_at=now() where account_id=v_actor and status='active';
  update public.organization_members set status='ended',ended_at=now() where account_id=v_actor and status='active';
  update public.location_interests set state='withdrawn' where account_id=v_actor and state='active';
  update public.accounts set lifecycle_status='closed' where id=v_actor;

  perform app_private.write_audit(v_actor,'account.close','account',v_actor);
  v_result:=jsonb_build_object('closed',true,'already_closed',false,'blockers','[]'::jsonb);
  perform app_private.complete_human_idempotent_command(v_actor,'request_account_closure',p_idempotency_key,v_result);
  return v_result;
end; $$;

revoke all on function app_private.account_closure_blockers(uuid),app_private.cmd_request_account_closure(text) from public,anon,authenticated,service_role;
grant execute on function app_private.account_closure_blockers(uuid),app_private.cmd_request_account_closure(text) to authenticated;
