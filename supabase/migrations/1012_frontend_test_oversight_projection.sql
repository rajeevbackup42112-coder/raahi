-- Raahi Learning V1.2 — limited Test oversight projection for guardians/managers.
-- This deliberately does NOT expose protected Test questions, answer choices, saved answers,
-- or the learner's Attempt-taking workspace. Management authority is oversight, not identity.

create or replace function app_private.read_test_oversight(p_test_id uuid,p_learner_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path=''
as $$
declare
  v_class_id uuid;
  v_provider boolean:=false;
  v_learner_allowed boolean:=false;
  v_membership_state text;
  v_result jsonb;
begin
  select t.class_id into v_class_id from public.tests t where t.id=p_test_id;
  if v_class_id is null then return null; end if;

  v_provider:=app_private.can_read_class_as_provider(v_class_id);
  select m.state into v_membership_state
  from public.class_memberships m
  where m.class_id=v_class_id and m.learner_id=p_learner_id
  order by m.joined_at desc
  limit 1;

  v_learner_allowed:=app_private.can_access_learner(p_learner_id)
    and v_membership_state in ('active','completed','transferred')
    and not app_private.current_actor_class_access_blocked(v_class_id)
    and not app_private.class_provider_access_blocked(v_class_id);

  if not v_provider and not v_learner_allowed then return null; end if;

  select jsonb_build_object(
    'test_id',t.id,
    'learner_id',p_learner_id,
    'title',t.title,
    'available_from',t.available_from,
    'closes_at',t.closes_at,
    'duration_seconds',t.duration_seconds,
    'test_state',t.state,
    'display_state',case
      when t.state='closed' or (t.closes_at is not null and now()>t.closes_at) then 'closed'
      when t.available_from is not null and now()<t.available_from then 'upcoming'
      else 'available'
    end,
    'results_visible',t.results_visible,
    'attempt_state',a.state,
    'submitted_at',a.submitted_at,
    'evaluated_at',case when t.results_visible and a.state='evaluated' then a.evaluated_at else null end,
    'score',case when t.results_visible and a.state='evaluated' then a.score else null end,
    'teacher_feedback',case when t.results_visible and a.state='evaluated' then a.teacher_feedback else null end
  ) into v_result
  from public.tests t
  left join public.test_attempts a on a.test_id=t.id and a.learner_id=p_learner_id
  where t.id=p_test_id;

  return v_result;
end;
$$;

revoke all on function app_private.read_test_oversight(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function app_private.read_test_oversight(uuid,uuid) to authenticated;

create or replace function public.get_test_oversight(p_test_id uuid,p_learner_id uuid)
returns jsonb
language sql
stable security invoker
set search_path=''
as $$ select app_private.read_test_oversight(p_test_id,p_learner_id); $$;

revoke all on function public.get_test_oversight(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_test_oversight(uuid,uuid) to authenticated;
