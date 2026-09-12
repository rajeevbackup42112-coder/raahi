-- Raahi Learning V1.2 — tighten frontend Test projections to preserve the
-- non-negotiable rule that management authority never becomes Test-taking identity.
-- Guardians may see released/evaluated status through existing overview surfaces,
-- but question/answer attempt projections are available to the learner's active self access
-- or the responsible provider only.

create or replace function app_private.can_read_test_for_learner(p_test_id uuid,p_learner_id uuid)
returns boolean
language sql
stable security definer
set search_path=''
as $$
  select exists(
    select 1
    from public.tests t
    join public.class_memberships m on m.class_id=t.class_id and m.learner_id=p_learner_id
    where t.id=p_test_id
      and exists(
        select 1 from public.account_learner_access ala
        where ala.account_id=app_private.current_account_id()
          and ala.learner_id=p_learner_id
          and ala.access_type='self'
          and ala.status='active'
      )
      and not app_private.current_actor_class_access_blocked(t.class_id)
      and not app_private.class_provider_access_blocked(t.class_id)
  );
$$;

revoke all on function app_private.can_read_test_for_learner(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function app_private.can_read_test_for_learner(uuid,uuid) to authenticated;
