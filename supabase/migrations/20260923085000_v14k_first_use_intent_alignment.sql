-- Raahi Learning V1.4K — restore canonical first-use intent orchestration.
-- This metadata records only that the one-time guidance screen was completed.
-- It never grants Learner, Teacher, Organization, staff or platform authority.

alter table public.accounts
  add column first_use_completed_at timestamptz null;

comment on column public.accounts.first_use_completed_at is
  'Server-owned completion time for one-time first-use intent guidance. Not an authorization, role or capability signal.';

-- Existing Accounts that already entered a meaningful Raahi relationship/authority
-- must not be forced back through first-use onboarding. Truly empty Accounts remain
-- null and will receive the intended intent screen on their next authenticated entry.
update public.accounts a
set first_use_completed_at = coalesce(a.updated_at,a.created_at,now())
where a.first_use_completed_at is null
  and (
    exists (
      select 1 from public.account_learner_access ala
      where ala.account_id=a.id and ala.status='active'
    )
    or exists (
      select 1 from public.account_capabilities ac
      where ac.account_id=a.id and ac.status='active'
    )
    or exists (
      select 1 from public.organization_members om
      where om.account_id=a.id and om.status='active'
    )
    or exists (
      select 1 from public.location_staff_assignments lsa
      where lsa.account_id=a.id and lsa.status='active'
    )
    or exists (
      select 1 from public.assisted_teacher_onboarding_requests ato
      where ato.teacher_account_id=a.id
    )
    or exists (
      select 1 from public.teacher_profiles tp
      where tp.account_id=a.id
    )
    or exists (
      select 1 from public.teaching_options t
      where t.teacher_account_id=a.id
    )
  );

create or replace function app_private.cmd_complete_first_use_onboarding(
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.require_current_account(true);
  v_gate jsonb;
  v_fp text;
  v_completed_at timestamptz;
  v_result jsonb;
begin
  v_fp:=app_private.request_fingerprint(
    jsonb_build_object('action','complete_first_use_onboarding')
  );
  v_gate:=app_private.begin_human_idempotent_command(
    v_actor,'complete_first_use_onboarding',p_idempotency_key,v_fp
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  update public.accounts
  set first_use_completed_at=coalesce(first_use_completed_at,now())
  where id=v_actor
  returning first_use_completed_at into v_completed_at;

  if v_completed_at is null then raise exception 'ACCOUNT_NOT_FOUND'; end if;

  v_result:=jsonb_build_object(
    'account_id',v_actor,
    'first_use_completed_at',v_completed_at
  );

  perform app_private.complete_human_idempotent_command(
    v_actor,'complete_first_use_onboarding',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;

revoke all on function app_private.cmd_complete_first_use_onboarding(text)
from public,anon,authenticated,service_role;
grant execute on function app_private.cmd_complete_first_use_onboarding(text)
to authenticated;

create or replace function public.complete_first_use_onboarding(
  p_idempotency_key text
)
returns jsonb
language sql
security invoker
set search_path=''
as $$
  select app_private.cmd_complete_first_use_onboarding(p_idempotency_key);
$$;

revoke all on function public.complete_first_use_onboarding(text)
from public,anon,authenticated,service_role;
grant execute on function public.complete_first_use_onboarding(text)
to authenticated;

-- Extend the existing account-context JSON without changing its authority semantics.
create or replace function app_private.read_my_account_context()
returns jsonb
language plpgsql
stable security definer
set search_path=''
as $$
declare
  v_auth_uid uuid := auth.uid();
  v_actor uuid;
  v_result jsonb;
begin
  if v_auth_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  v_actor := app_private.current_account_id();
  if v_actor is null then
    raise exception 'ACCOUNT_NOT_FOUND';
  end if;

  select jsonb_build_object(
    'account',jsonb_build_object(
      'account_id',a.id,'display_name',a.display_name,'avatar_type',a.avatar_type,
      'avatar_ref',a.avatar_ref,'lifecycle_status',a.lifecycle_status,
      'first_use_completed_at',a.first_use_completed_at
    ),
    'selected_location',(
      select jsonb_build_object('location_id',l.id,'name',l.name,'slug',l.slug,'state',l.state)
      from public.account_location_preferences p join public.locations l on l.id=p.selected_location_id
      where p.account_id=a.id
    ),
    'learners',coalesce((
      select jsonb_agg(jsonb_build_object(
        'access_id',ala.id,'access_type',ala.access_type,'learner_id',lr.id,
        'display_name',lr.display_name,'avatar_type',lr.avatar_type,'avatar_ref',lr.avatar_ref
      ) order by case ala.access_type when 'self' then 1 else 2 end,lr.display_name,lr.id)
      from public.account_learner_access ala join public.learners lr on lr.id=ala.learner_id
      where ala.account_id=a.id and ala.status='active'
    ),'[]'::jsonb),
    'capabilities',coalesce((
      select jsonb_agg(ac.capability_code order by ac.capability_code)
      from public.account_capabilities ac where ac.account_id=a.id and ac.status='active'
    ),'[]'::jsonb),
    'organizations',coalesce((
      select jsonb_agg(jsonb_build_object(
        'organization_member_id',om.id,'organization_id',o.id,'name',o.name,
        'organization_type',o.organization_type,'status',o.status,'logo_type',o.logo_type,'logo_ref',o.logo_ref,
        'capabilities',coalesce((select jsonb_agg(c.capability_code order by c.capability_code)
          from public.organization_member_capabilities c where c.organization_member_id=om.id),'[]'::jsonb)
      ) order by o.name,o.id)
      from public.organization_members om join public.organizations o on o.id=om.organization_id
      where om.account_id=a.id and om.status='active'
    ),'[]'::jsonb),
    'manager_scopes',coalesce((
      select jsonb_agg(jsonb_build_object(
        'assignment_id',s.id,'staff_type',s.staff_type,'location_id',l.id,'location_name',l.name,'location_state',l.state
      ) order by l.name,l.id)
      from public.location_staff_assignments s join public.locations l on l.id=s.location_id
      where s.account_id=a.id and s.status='active'
    ),'[]'::jsonb)
  ) into v_result
  from public.accounts a where a.id=v_actor;

  if v_result is null then
    raise exception 'ACCOUNT_NOT_FOUND';
  end if;

  return v_result;
end;
$$;

revoke all on function app_private.read_my_account_context()
from public,anon,authenticated,service_role;
grant execute on function app_private.read_my_account_context()
to authenticated;
