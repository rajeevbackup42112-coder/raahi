-- Raahi Learning V1.2 — Test/Attempt RLS and safe result projections.

create or replace function app_private.can_read_test_for_learner(p_test_id uuid,p_learner_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1
    from public.tests t
    join public.class_memberships m on m.class_id=t.class_id and m.learner_id=p_learner_id
    where t.id=p_test_id
      and app_private.can_access_learner(p_learner_id)
      and not app_private.current_actor_class_access_blocked(t.class_id)
      and not app_private.class_provider_access_blocked(t.class_id)
  );
$$;

create or replace function app_private.get_test_definition_projection(p_test_id uuid,p_learner_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_class uuid; v_state text; v_results_visible boolean; v_provider boolean; v_learner_ok boolean:=false; v_reveal boolean:=false; v_attempt_state text; v_out jsonb;
begin
  select class_id,state,results_visible into v_class,v_state,v_results_visible from public.tests where id=p_test_id;
  if not found then return null; end if;
  v_provider:=app_private.can_read_class_as_provider(v_class);
  if p_learner_id is not null then v_learner_ok:=app_private.can_read_test_for_learner(p_test_id,p_learner_id); end if;
  if not v_provider and not v_learner_ok then return null; end if;
  if not v_provider and v_state='draft' then return null; end if;
  if v_provider then v_reveal:=true;
  elsif v_results_visible then
    select state into v_attempt_state from public.test_attempts where test_id=p_test_id and learner_id=p_learner_id;
    v_reveal:=coalesce(v_attempt_state='evaluated',false);
  end if;

  select jsonb_build_object(
    'test_id',t.id,'class_id',t.class_id,'title',t.title,'instructions',t.instructions,
    'available_from',t.available_from,'closes_at',t.closes_at,'duration_seconds',t.duration_seconds,
    'state',t.state,'results_visible',t.results_visible,'definition_locked',t.definition_locked_at is not null,
    'questions',coalesce((
      select jsonb_agg(jsonb_build_object(
        'question_id',q.id,'position',q.position,'question_type',q.question_type,'prompt',q.prompt,'points',q.points,
        'choices',coalesce((select jsonb_agg(jsonb_build_object('choice_id',c.id,'position',c.position,'choice_text',c.choice_text,'is_correct',case when v_reveal then c.is_correct else null end) order by c.position,c.id) from public.test_choices c where c.question_id=q.id),'[]'::jsonb)
      ) order by q.position,q.id)
      from public.test_questions q where q.test_id=t.id
    ),'[]'::jsonb)
  ) into v_out
  from public.tests t where t.id=p_test_id;
  return v_out;
end; $$;

create or replace function app_private.get_test_attempt_projection(p_test_id uuid,p_learner_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_class uuid; v_results_visible boolean; v_provider boolean; v_learner_ok boolean; v_attempt public.test_attempts%rowtype; v_show_result boolean; v_out jsonb;
begin
  select class_id,results_visible into v_class,v_results_visible from public.tests where id=p_test_id; if not found then return null; end if;
  v_provider:=app_private.can_read_class_as_provider(v_class);
  v_learner_ok:=app_private.can_read_test_for_learner(p_test_id,p_learner_id);
  if not v_provider and not v_learner_ok then return null; end if;
  select * into v_attempt from public.test_attempts where test_id=p_test_id and learner_id=p_learner_id;
  if not found then return jsonb_build_object('test_id',p_test_id,'learner_id',p_learner_id,'attempt',null); end if;
  v_show_result:=v_provider or (v_results_visible and v_attempt.state='evaluated');
  select jsonb_build_object(
    'attempt_id',v_attempt.id,'test_id',p_test_id,'learner_id',p_learner_id,'state',v_attempt.state,
    'started_at',v_attempt.started_at,'submitted_at',v_attempt.submitted_at,'evaluated_at',case when v_show_result then v_attempt.evaluated_at else null end,
    'score',case when v_show_result then v_attempt.score else null end,
    'teacher_feedback',case when v_show_result then v_attempt.teacher_feedback else null end,
    'invalidation_reason',case when v_provider or v_learner_ok then v_attempt.invalidation_reason else null end,
    'answers',coalesce((select jsonb_agg(jsonb_build_object('question_id',aa.question_id,'selected_choice_id',aa.selected_choice_id,'text_response',aa.text_response,'saved_at',aa.saved_at) order by q.position,q.id)
      from public.test_attempt_answers aa join public.test_questions q on q.id=aa.question_id where aa.attempt_id=v_attempt.id),'[]'::jsonb)
  ) into v_out;
  return v_out;
end; $$;

alter table public.tests enable row level security; alter table public.tests force row level security;
alter table public.test_questions enable row level security; alter table public.test_questions force row level security;
alter table public.test_choices enable row level security; alter table public.test_choices force row level security;
alter table public.test_attempts enable row level security; alter table public.test_attempts force row level security;
alter table public.test_attempt_answers enable row level security; alter table public.test_attempt_answers force row level security;

create policy tests_select_authorized on public.tests for select to authenticated
using(app_private.can_read_test(id));

-- Base definition/attempt tables deliberately have no authenticated SELECT grant.
-- Correct-answer keys, feedback and unreleased scores are exposed only through the safe projections above.
revoke all on table public.tests,public.test_questions,public.test_choices,public.test_attempts,public.test_attempt_answers from public,anon,authenticated,service_role;
grant select on table public.tests to authenticated;
grant select,insert,update,delete on table public.tests,public.test_questions,public.test_choices,public.test_attempts,public.test_attempt_answers to service_role;

revoke all on function app_private.can_read_test_for_learner(uuid,uuid),app_private.get_test_definition_projection(uuid,uuid),app_private.get_test_attempt_projection(uuid,uuid)
from public,anon,authenticated,service_role;
grant execute on function app_private.can_read_test_for_learner(uuid,uuid),app_private.get_test_definition_projection(uuid,uuid),app_private.get_test_attempt_projection(uuid,uuid) to authenticated;

create or replace function public.get_test_definition(p_test_id uuid,p_learner_id uuid default null)
returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.get_test_definition_projection(p_test_id,p_learner_id); $$;
create or replace function public.get_test_attempt(p_test_id uuid,p_learner_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.get_test_attempt_projection(p_test_id,p_learner_id); $$;

revoke all on function public.get_test_definition(uuid,uuid),public.get_test_attempt(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_test_definition(uuid,uuid),public.get_test_attempt(uuid,uuid) to authenticated;
