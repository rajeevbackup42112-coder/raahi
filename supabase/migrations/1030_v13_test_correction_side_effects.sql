-- Raahi Learning V1.3 — released Test answer-key correction side-effect closure (SE-07)
-- Existing correction remains authoritative and auditable.
-- If results are already visible, notify affected evaluated learner-side Accounts generically.
-- Never copy answer text, score, selected choices, or correction reason into notifications.

create or replace function app_private.cmd_correct_answer_key(
  p_question_id uuid,
  p_correct_choice_id uuid,
  p_reason text,
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
  v_test uuid;
  v_class uuid;
  v_locked timestamptz;
  v_results_visible boolean:=false;
  v_recalc integer:=0;
  v_result jsonb;
begin
  if p_reason is null or char_length(btrim(p_reason)) not between 1 and 500 then
    raise exception 'CORRECTION_REASON_REQUIRED';
  end if;

  select q.test_id,t.class_id,t.definition_locked_at,t.results_visible
  into v_test,v_class,v_locked,v_results_visible
  from public.test_questions q
  join public.tests t on t.id=q.test_id
  where q.id=p_question_id
  for update of t;

  if not found then raise exception 'QUESTION_NOT_FOUND'; end if;
  if not app_private.can_manage_class(v_class) then raise exception 'NOT_AUTHORIZED'; end if;
  if v_locked is null then raise exception 'ANSWER_KEY_CORRECTION_REQUIRES_LOCKED_TEST'; end if;
  if not exists(
    select 1 from public.test_choices
    where id=p_correct_choice_id and question_id=p_question_id
  ) then raise exception 'CHOICE_NOT_IN_QUESTION'; end if;

  v_fp:=app_private.request_fingerprint(jsonb_build_object(
    'question_id',p_question_id,
    'correct_choice_id',p_correct_choice_id,
    'reason',p_reason
  ));
  v_gate:=app_private.begin_human_idempotent_command(
    v_actor,'correct_answer_key',p_idempotency_key,v_fp
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  perform set_config('app_private.answer_key_correction','on',true);

  update public.test_choices
  set is_correct=(id=p_correct_choice_id)
  where question_id=p_question_id;

  perform set_config('app_private.answer_key_correction','off',true);

  update public.test_attempts a
  set score=app_private.score_test_attempt(a.id),
      evaluated_at=now()
  where a.test_id=v_test
    and a.state='evaluated';

  get diagnostics v_recalc=row_count;

  perform app_private.write_audit(
    v_actor,
    'test.answer_key_correct',
    'test_question',
    p_question_id,
    null,
    null,
    jsonb_build_object(
      'test_id',v_test,
      'correct_choice_id',p_correct_choice_id,
      'reason_code',btrim(p_reason),
      'recalculated_attempts',v_recalc
    )
  );

  if coalesce(v_results_visible,false) and v_recalc>0 then
    perform app_private.notify_evaluated_test_accounts(
      v_test,
      v_actor,
      'test_results_corrected',
      'test',
      v_test,
      'Test results updated',
      'Results for a completed Test were updated after a correction.',
      jsonb_build_object(
        'test_id',v_test,
        'class_id',v_class
      )
    );
  end if;

  v_result:=jsonb_build_object(
    'question_id',p_question_id,
    'correct_choice_id',p_correct_choice_id,
    'recalculated_attempts',v_recalc
  );

  perform app_private.complete_human_idempotent_command(
    v_actor,'correct_answer_key',p_idempotency_key,v_result
  );
  return v_result;

exception when others then
  perform set_config('app_private.answer_key_correction','off',true);
  raise;
end;
$$;

-- Preserve the canonical 0702 SECURITY INVOKER privilege contract.
grant execute on function app_private.cmd_correct_answer_key(uuid,uuid,text,text)
to authenticated;
