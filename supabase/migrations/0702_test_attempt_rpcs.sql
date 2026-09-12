-- Raahi Learning V1.2 — Test authoring, Attempts, evaluation and explicit answer-key correction.

create or replace function app_private.can_read_test(p_test_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.tests t
    where t.id=p_test_id
      and (app_private.can_read_class_shared(t.class_id) or app_private.can_read_class_as_provider(t.class_id))
  );
$$;

create or replace function app_private.test_attempt_deadline(p_attempt_id uuid)
returns timestamptz language sql stable security definer set search_path='' as $$
  select case
    when t.duration_seconds is null then t.closes_at
    when t.closes_at is null then a.started_at + make_interval(secs=>t.duration_seconds)
    else least(t.closes_at,a.started_at + make_interval(secs=>t.duration_seconds))
  end
  from public.test_attempts a join public.tests t on t.id=a.test_id
  where a.id=p_attempt_id;
$$;

create or replace function app_private.score_test_attempt(p_attempt_id uuid)
returns numeric language sql stable security definer set search_path='' as $$
  select coalesce(sum(case when c.is_correct then q.points else 0 end),0)::numeric
  from public.test_attempts a
  join public.test_questions q on q.test_id=a.test_id
  left join public.test_attempt_answers aa on aa.attempt_id=a.id and aa.question_id=q.id
  left join public.test_choices c on c.id=aa.selected_choice_id and c.question_id=q.id
  where a.id=p_attempt_id;
$$;

create or replace function app_private.cmd_create_test(
  p_class_id uuid,p_title text,p_instructions text,p_available_from timestamptz,p_closes_at timestamptz,p_duration_seconds integer,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_test uuid; v_result jsonb;
begin
  if not app_private.can_manage_class(p_class_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if not exists(select 1 from public.classes where id=p_class_id and state in ('draft','active')) then raise exception 'CLASS_NOT_ELIGIBLE'; end if;
  if p_title is null or char_length(btrim(p_title)) not between 1 and 300 then raise exception 'INVALID_TEST_TITLE'; end if;
  if p_duration_seconds is not null and p_duration_seconds<=0 then raise exception 'INVALID_DURATION'; end if;
  if p_available_from is not null and p_closes_at is not null and p_closes_at<=p_available_from then raise exception 'INVALID_TEST_WINDOW'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('class_id',p_class_id,'title',p_title,'instructions',p_instructions,'available_from',p_available_from,'closes_at',p_closes_at,'duration_seconds',p_duration_seconds));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'create_test',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.tests(class_id,created_by_account_id,title,instructions,available_from,closes_at,duration_seconds)
  values(p_class_id,v_actor,btrim(p_title),nullif(btrim(p_instructions),''),p_available_from,p_closes_at,p_duration_seconds) returning id into v_test;
  v_result:=jsonb_build_object('test_id',v_test,'state','draft');
  perform app_private.complete_human_idempotent_command(v_actor,'create_test',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_add_test_question(p_test_id uuid,p_position integer,p_prompt text,p_points numeric,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_class uuid; v_state text; v_locked timestamptz; v_question uuid; v_result jsonb;
begin
  select class_id,state,definition_locked_at into v_class,v_state,v_locked from public.tests where id=p_test_id;
  if not found then raise exception 'TEST_NOT_FOUND'; end if;
  if not app_private.can_manage_class(v_class) then raise exception 'NOT_AUTHORIZED'; end if;
  if v_state<>'draft' or v_locked is not null then raise exception 'TEST_DEFINITION_NOT_EDITABLE'; end if;
  if p_position is null or p_position<1 then raise exception 'INVALID_QUESTION_POSITION'; end if;
  if p_prompt is null or char_length(btrim(p_prompt)) not between 1 and 12000 then raise exception 'INVALID_QUESTION_PROMPT'; end if;
  if p_points is null or p_points<=0 then raise exception 'INVALID_QUESTION_POINTS'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('test_id',p_test_id,'position',p_position,'prompt',p_prompt,'points',p_points));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'add_test_question',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.test_questions(test_id,position,prompt,points) values(p_test_id,p_position,btrim(p_prompt),p_points) returning id into v_question;
  v_result:=jsonb_build_object('question_id',v_question,'test_id',p_test_id);
  perform app_private.complete_human_idempotent_command(v_actor,'add_test_question',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_add_test_choice(p_question_id uuid,p_position integer,p_choice_text text,p_is_correct boolean,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_test uuid; v_class uuid; v_state text; v_locked timestamptz; v_choice uuid; v_result jsonb;
begin
  select q.test_id,t.class_id,t.state,t.definition_locked_at into v_test,v_class,v_state,v_locked from public.test_questions q join public.tests t on t.id=q.test_id where q.id=p_question_id;
  if not found then raise exception 'QUESTION_NOT_FOUND'; end if;
  if not app_private.can_manage_class(v_class) then raise exception 'NOT_AUTHORIZED'; end if;
  if v_state<>'draft' or v_locked is not null then raise exception 'TEST_DEFINITION_NOT_EDITABLE'; end if;
  if p_position is null or p_position<1 then raise exception 'INVALID_CHOICE_POSITION'; end if;
  if p_choice_text is null or char_length(btrim(p_choice_text)) not between 1 and 4000 then raise exception 'INVALID_CHOICE_TEXT'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('question_id',p_question_id,'position',p_position,'choice_text',p_choice_text,'is_correct',p_is_correct));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'add_test_choice',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.test_choices(question_id,position,choice_text,is_correct) values(p_question_id,p_position,btrim(p_choice_text),coalesce(p_is_correct,false)) returning id into v_choice;
  v_result:=jsonb_build_object('choice_id',v_choice,'question_id',p_question_id);
  perform app_private.complete_human_idempotent_command(v_actor,'add_test_choice',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_publish_test(p_test_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_class uuid; v_state text; v_bad uuid; v_result jsonb;
begin
  select class_id,state into v_class,v_state from public.tests where id=p_test_id for update; if not found then raise exception 'TEST_NOT_FOUND'; end if;
  if not app_private.can_manage_class(v_class) then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('test_id',p_test_id)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'publish_test',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if v_state='available' then v_result:=jsonb_build_object('test_id',p_test_id,'state','available','already_available',true);
  elsif v_state<>'draft' then raise exception 'TEST_NOT_DRAFT';
  else
    if not exists(select 1 from public.test_questions where test_id=p_test_id) then raise exception 'TEST_REQUIRES_QUESTION'; end if;
    select q.id into v_bad from public.test_questions q where q.test_id=p_test_id and ((select count(*) from public.test_choices c where c.question_id=q.id)<2 or (select count(*) from public.test_choices c where c.question_id=q.id and c.is_correct)<>1) limit 1;
    if v_bad is not null then raise exception 'QUESTION_REQUIRES_TWO_CHOICES_AND_ONE_CORRECT:%',v_bad; end if;
    if exists(select 1 from public.tests where id=p_test_id and closes_at is not null and closes_at<=now()) then raise exception 'TEST_ALREADY_CLOSED_BY_TIME'; end if;
    update public.tests set state='available' where id=p_test_id;
    v_result:=jsonb_build_object('test_id',p_test_id,'state','available','already_available',false);
  end if;
  perform app_private.complete_human_idempotent_command(v_actor,'publish_test',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_close_test(p_test_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_class uuid; v_state text; v_result jsonb;
begin
  select class_id,state into v_class,v_state from public.tests where id=p_test_id for update; if not found then raise exception 'TEST_NOT_FOUND'; end if;
  if not app_private.can_manage_class(v_class) then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('test_id',p_test_id)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'close_test',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if v_state='closed' then v_result:=jsonb_build_object('test_id',p_test_id,'state','closed','already_closed',true);
  elsif v_state<>'available' then raise exception 'TEST_NOT_AVAILABLE';
  else update public.tests set state='closed' where id=p_test_id; v_result:=jsonb_build_object('test_id',p_test_id,'state','closed','already_closed',false); end if;
  perform app_private.complete_human_idempotent_command(v_actor,'close_test',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_start_test(p_test_id uuid,p_learner_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_class uuid; v_state text; v_from timestamptz; v_close timestamptz; v_attempt uuid; v_attempt_state text; v_result jsonb;
begin
  if not app_private.has_learner_self_access(p_learner_id) then raise exception 'LEARNER_SELF_ACCESS_REQUIRED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('test_id',p_test_id,'learner_id',p_learner_id)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'start_test',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select class_id,state,available_from,closes_at into v_class,v_state,v_from,v_close from public.tests where id=p_test_id for update; if not found then raise exception 'TEST_NOT_FOUND'; end if;
  if v_state<>'available' then raise exception 'TEST_NOT_AVAILABLE'; end if;
  if v_from is not null and now()<v_from then raise exception 'TEST_NOT_OPEN_YET'; end if;
  if v_close is not null and now()>=v_close then raise exception 'TEST_CLOSED_BY_TIME'; end if;
  if not app_private.has_active_class_membership(v_class,p_learner_id) then raise exception 'ACTIVE_MEMBERSHIP_REQUIRED'; end if;
  if app_private.current_actor_class_access_blocked(v_class) or app_private.class_provider_access_blocked(v_class) then raise exception 'CLASS_ACCESS_RESTRICTED'; end if;
  select id,state into v_attempt,v_attempt_state from public.test_attempts where test_id=p_test_id and learner_id=p_learner_id for update;
  if v_attempt is null then
    update public.tests set definition_locked_at=coalesce(definition_locked_at,now()) where id=p_test_id;
    insert into public.test_attempts(test_id,learner_id,state) values(p_test_id,p_learner_id,'in_progress') returning id,state into v_attempt,v_attempt_state;
  end if;
  v_result:=jsonb_build_object('attempt_id',v_attempt,'test_id',p_test_id,'learner_id',p_learner_id,'state',v_attempt_state,'deadline',app_private.test_attempt_deadline(v_attempt));
  perform app_private.complete_human_idempotent_command(v_actor,'start_test',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_save_test_answer(p_attempt_id uuid,p_question_id uuid,p_selected_choice_id uuid,p_text_response text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_test uuid; v_learner uuid; v_state text; v_deadline timestamptz; v_result jsonb;
begin
  select test_id,learner_id,state into v_test,v_learner,v_state from public.test_attempts where id=p_attempt_id for update; if not found then raise exception 'ATTEMPT_NOT_FOUND'; end if;
  if not app_private.has_learner_self_access(v_learner) then raise exception 'LEARNER_SELF_ACCESS_REQUIRED'; end if;
  if v_state<>'in_progress' then raise exception 'ATTEMPT_NOT_IN_PROGRESS'; end if;
  v_deadline:=app_private.test_attempt_deadline(p_attempt_id); if v_deadline is not null and now()>=v_deadline then raise exception 'ATTEMPT_TIME_EXPIRED'; end if;
  if not exists(select 1 from public.test_questions where id=p_question_id and test_id=v_test) then raise exception 'QUESTION_NOT_IN_TEST'; end if;
  if p_selected_choice_id is not null and not exists(select 1 from public.test_choices where id=p_selected_choice_id and question_id=p_question_id) then raise exception 'CHOICE_NOT_IN_QUESTION'; end if;
  if p_selected_choice_id is null and nullif(btrim(p_text_response),'') is null then raise exception 'ANSWER_REQUIRED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('attempt_id',p_attempt_id,'question_id',p_question_id,'selected_choice_id',p_selected_choice_id,'text_response',p_text_response));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'save_test_answer',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.test_attempt_answers(attempt_id,question_id,selected_choice_id,text_response,saved_at)
  values(p_attempt_id,p_question_id,p_selected_choice_id,nullif(btrim(p_text_response),''),now())
  on conflict(attempt_id,question_id) do update set selected_choice_id=excluded.selected_choice_id,text_response=excluded.text_response,saved_at=excluded.saved_at;
  v_result:=jsonb_build_object('attempt_id',p_attempt_id,'question_id',p_question_id,'saved',true);
  perform app_private.complete_human_idempotent_command(v_actor,'save_test_answer',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_submit_test(p_attempt_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_learner uuid; v_state text; v_result jsonb;
begin
  v_fp:=app_private.request_fingerprint(jsonb_build_object('attempt_id',p_attempt_id)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'submit_test',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select learner_id,state into v_learner,v_state from public.test_attempts where id=p_attempt_id for update; if not found then raise exception 'ATTEMPT_NOT_FOUND'; end if;
  if not app_private.has_learner_self_access(v_learner) then raise exception 'LEARNER_SELF_ACCESS_REQUIRED'; end if;
  if v_state='in_progress' then update public.test_attempts set state='submitted',submitted_at=now() where id=p_attempt_id; v_state:='submitted';
  elsif v_state not in ('submitted','evaluated') then raise exception 'ATTEMPT_NOT_SUBMITTABLE'; end if;
  v_result:=jsonb_build_object('attempt_id',p_attempt_id,'state',v_state);
  perform app_private.complete_human_idempotent_command(v_actor,'submit_test',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_evaluate_test_attempt(p_attempt_id uuid,p_teacher_feedback text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_test uuid; v_class uuid; v_state text; v_score numeric; v_result jsonb;
begin
  select a.test_id,t.class_id,a.state into v_test,v_class,v_state from public.test_attempts a join public.tests t on t.id=a.test_id where a.id=p_attempt_id for update of a; if not found then raise exception 'ATTEMPT_NOT_FOUND'; end if;
  if not app_private.can_manage_class(v_class) then raise exception 'NOT_AUTHORIZED'; end if;
  if v_state not in ('submitted','evaluated') then raise exception 'ATTEMPT_NOT_EVALUATABLE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('attempt_id',p_attempt_id,'teacher_feedback',p_teacher_feedback)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'evaluate_test_attempt',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  v_score:=app_private.score_test_attempt(p_attempt_id);
  update public.test_attempts set state='evaluated',score=v_score,evaluated_at=coalesce(evaluated_at,now()),teacher_feedback=nullif(btrim(p_teacher_feedback),'') where id=p_attempt_id;
  v_result:=jsonb_build_object('attempt_id',p_attempt_id,'state','evaluated','score',v_score);
  perform app_private.complete_human_idempotent_command(v_actor,'evaluate_test_attempt',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_invalidate_test_attempt(p_attempt_id uuid,p_reason text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_class uuid; v_learner uuid; v_state text; v_result jsonb;
begin
  if p_reason is null or char_length(btrim(p_reason)) not between 1 and 500 then raise exception 'INVALID_INVALIDATION_REASON'; end if;
  select t.class_id,a.learner_id,a.state into v_class,v_learner,v_state from public.test_attempts a join public.tests t on t.id=a.test_id where a.id=p_attempt_id for update of a; if not found then raise exception 'ATTEMPT_NOT_FOUND'; end if;
  if not app_private.can_manage_class(v_class) and not app_private.has_account_capability('platform_admin') then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('attempt_id',p_attempt_id,'reason',p_reason)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'invalidate_test_attempt',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if v_state='invalidated' then v_result:=jsonb_build_object('attempt_id',p_attempt_id,'state','invalidated','already_invalidated',true);
  else update public.test_attempts set state='invalidated',invalidation_reason=btrim(p_reason) where id=p_attempt_id; perform app_private.write_audit(v_actor,'test.attempt_invalidate','test_attempt',p_attempt_id,v_learner,null,jsonb_build_object('reason_code',btrim(p_reason))); v_result:=jsonb_build_object('attempt_id',p_attempt_id,'state','invalidated','already_invalidated',false); end if;
  perform app_private.complete_human_idempotent_command(v_actor,'invalidate_test_attempt',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_correct_answer_key(p_question_id uuid,p_correct_choice_id uuid,p_reason text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_test uuid; v_class uuid; v_locked timestamptz; v_recalc integer:=0; v_result jsonb;
begin
  if p_reason is null or char_length(btrim(p_reason)) not between 1 and 500 then raise exception 'CORRECTION_REASON_REQUIRED'; end if;
  select q.test_id,t.class_id,t.definition_locked_at into v_test,v_class,v_locked from public.test_questions q join public.tests t on t.id=q.test_id where q.id=p_question_id for update of t; if not found then raise exception 'QUESTION_NOT_FOUND'; end if;
  if not app_private.can_manage_class(v_class) then raise exception 'NOT_AUTHORIZED'; end if;
  if v_locked is null then raise exception 'ANSWER_KEY_CORRECTION_REQUIRES_LOCKED_TEST'; end if;
  if not exists(select 1 from public.test_choices where id=p_correct_choice_id and question_id=p_question_id) then raise exception 'CHOICE_NOT_IN_QUESTION'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('question_id',p_question_id,'correct_choice_id',p_correct_choice_id,'reason',p_reason)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'correct_answer_key',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  perform set_config('app_private.answer_key_correction','on',true);
  update public.test_choices set is_correct=(id=p_correct_choice_id) where question_id=p_question_id;
  perform set_config('app_private.answer_key_correction','off',true);
  update public.test_attempts a set score=app_private.score_test_attempt(a.id),evaluated_at=now() where a.test_id=v_test and a.state='evaluated';
  get diagnostics v_recalc=row_count;
  perform app_private.write_audit(v_actor,'test.answer_key_correct','test_question',p_question_id,null,null,jsonb_build_object('test_id',v_test,'correct_choice_id',p_correct_choice_id,'reason_code',btrim(p_reason),'recalculated_attempts',v_recalc));
  v_result:=jsonb_build_object('question_id',p_question_id,'correct_choice_id',p_correct_choice_id,'recalculated_attempts',v_recalc);
  perform app_private.complete_human_idempotent_command(v_actor,'correct_answer_key',p_idempotency_key,v_result); return v_result;
exception when others then
  perform set_config('app_private.answer_key_correction','off',true);
  raise;
end; $$;

create or replace function app_private.cmd_set_test_results_visibility(p_test_id uuid,p_visible boolean,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_class uuid; v_result jsonb;
begin
  select class_id into v_class from public.tests where id=p_test_id for update; if not found then raise exception 'TEST_NOT_FOUND'; end if;
  if not app_private.can_manage_class(v_class) then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('test_id',p_test_id,'visible',p_visible)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'set_test_results_visibility',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  update public.tests set results_visible=p_visible where id=p_test_id;
  v_result:=jsonb_build_object('test_id',p_test_id,'results_visible',p_visible);
  perform app_private.complete_human_idempotent_command(v_actor,'set_test_results_visibility',p_idempotency_key,v_result); return v_result;
end; $$;

revoke all on function app_private.can_read_test(uuid),app_private.test_attempt_deadline(uuid),app_private.score_test_attempt(uuid),
 app_private.cmd_create_test(uuid,text,text,timestamptz,timestamptz,integer,text),app_private.cmd_add_test_question(uuid,integer,text,numeric,text),
 app_private.cmd_add_test_choice(uuid,integer,text,boolean,text),app_private.cmd_publish_test(uuid,text),app_private.cmd_close_test(uuid,text),
 app_private.cmd_start_test(uuid,uuid,text),app_private.cmd_save_test_answer(uuid,uuid,uuid,text,text),app_private.cmd_submit_test(uuid,text),
 app_private.cmd_evaluate_test_attempt(uuid,text,text),app_private.cmd_invalidate_test_attempt(uuid,text,text),app_private.cmd_correct_answer_key(uuid,uuid,text,text),
 app_private.cmd_set_test_results_visibility(uuid,boolean,text)
from public,anon,authenticated,service_role;

grant execute on function app_private.can_read_test(uuid),app_private.test_attempt_deadline(uuid) to authenticated;
grant execute on function app_private.cmd_create_test(uuid,text,text,timestamptz,timestamptz,integer,text),app_private.cmd_add_test_question(uuid,integer,text,numeric,text),
 app_private.cmd_add_test_choice(uuid,integer,text,boolean,text),app_private.cmd_publish_test(uuid,text),app_private.cmd_close_test(uuid,text),
 app_private.cmd_start_test(uuid,uuid,text),app_private.cmd_save_test_answer(uuid,uuid,uuid,text,text),app_private.cmd_submit_test(uuid,text),
 app_private.cmd_evaluate_test_attempt(uuid,text,text),app_private.cmd_invalidate_test_attempt(uuid,text,text),app_private.cmd_correct_answer_key(uuid,uuid,text,text),
 app_private.cmd_set_test_results_visibility(uuid,boolean,text) to authenticated;

create or replace function public.create_test(p_class_id uuid,p_title text,p_instructions text,p_available_from timestamptz,p_closes_at timestamptz,p_duration_seconds integer,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_create_test(p_class_id,p_title,p_instructions,p_available_from,p_closes_at,p_duration_seconds,p_idempotency_key); $$;
create or replace function public.add_test_question(p_test_id uuid,p_position integer,p_prompt text,p_points numeric,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_add_test_question(p_test_id,p_position,p_prompt,p_points,p_idempotency_key); $$;
create or replace function public.add_test_choice(p_question_id uuid,p_position integer,p_choice_text text,p_is_correct boolean,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_add_test_choice(p_question_id,p_position,p_choice_text,p_is_correct,p_idempotency_key); $$;
create or replace function public.publish_test(p_test_id uuid,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_publish_test(p_test_id,p_idempotency_key); $$;
create or replace function public.close_test(p_test_id uuid,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_close_test(p_test_id,p_idempotency_key); $$;
create or replace function public.start_test(p_test_id uuid,p_learner_id uuid,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_start_test(p_test_id,p_learner_id,p_idempotency_key); $$;
create or replace function public.save_test_answer(p_attempt_id uuid,p_question_id uuid,p_selected_choice_id uuid,p_text_response text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_save_test_answer(p_attempt_id,p_question_id,p_selected_choice_id,p_text_response,p_idempotency_key); $$;
create or replace function public.submit_test(p_attempt_id uuid,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_submit_test(p_attempt_id,p_idempotency_key); $$;
create or replace function public.evaluate_test_attempt(p_attempt_id uuid,p_teacher_feedback text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_evaluate_test_attempt(p_attempt_id,p_teacher_feedback,p_idempotency_key); $$;
create or replace function public.invalidate_test_attempt(p_attempt_id uuid,p_reason text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_invalidate_test_attempt(p_attempt_id,p_reason,p_idempotency_key); $$;
create or replace function public.correct_answer_key(p_question_id uuid,p_correct_choice_id uuid,p_reason text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_correct_answer_key(p_question_id,p_correct_choice_id,p_reason,p_idempotency_key); $$;
create or replace function public.set_test_results_visibility(p_test_id uuid,p_visible boolean,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_set_test_results_visibility(p_test_id,p_visible,p_idempotency_key); $$;

revoke all on function public.create_test(uuid,text,text,timestamptz,timestamptz,integer,text),public.add_test_question(uuid,integer,text,numeric,text),public.add_test_choice(uuid,integer,text,boolean,text),
 public.publish_test(uuid,text),public.close_test(uuid,text),public.start_test(uuid,uuid,text),public.save_test_answer(uuid,uuid,uuid,text,text),public.submit_test(uuid,text),
 public.evaluate_test_attempt(uuid,text,text),public.invalidate_test_attempt(uuid,text,text),public.correct_answer_key(uuid,uuid,text,text),public.set_test_results_visibility(uuid,boolean,text)
from public,anon,authenticated,service_role;
grant execute on function public.create_test(uuid,text,text,timestamptz,timestamptz,integer,text),public.add_test_question(uuid,integer,text,numeric,text),public.add_test_choice(uuid,integer,text,boolean,text),
 public.publish_test(uuid,text),public.close_test(uuid,text),public.start_test(uuid,uuid,text),public.save_test_answer(uuid,uuid,uuid,text,text),public.submit_test(uuid,text),
 public.evaluate_test_attempt(uuid,text,text),public.invalidate_test_attempt(uuid,text,text),public.correct_answer_key(uuid,uuid,text,text),public.set_test_results_visibility(uuid,boolean,text)
to authenticated;
