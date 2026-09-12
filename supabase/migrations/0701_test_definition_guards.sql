-- Raahi Learning V1.2 — defense-in-depth guards for Test definition integrity.

create or replace function app_private.test_definition_locked_for_question(p_question_id uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select exists(
    select 1
    from public.test_questions q
    join public.tests t on t.id=q.test_id
    where q.id=p_question_id and t.definition_locked_at is not null
  );
$$;

create or replace function app_private.guard_test_question_definition()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_test_id uuid;
begin
  v_test_id := coalesce(new.test_id,old.test_id);
  if exists(select 1 from public.tests where id=v_test_id and definition_locked_at is not null) then
    raise exception 'TEST_DEFINITION_LOCKED';
  end if;
  return coalesce(new,old);
end;
$$;

create or replace function app_private.guard_test_choice_definition()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_question_id uuid := coalesce(new.question_id,old.question_id);
begin
  if app_private.test_definition_locked_for_question(v_question_id) then
    -- Only the explicit audited answer-key correction path may flip correctness.
    if tg_op='UPDATE'
       and new.question_id=old.question_id
       and new.position=old.position
       and new.choice_text=old.choice_text
       and new.is_correct is distinct from old.is_correct
       and current_setting('app_private.answer_key_correction',true)='on' then
      return new;
    end if;
    raise exception 'TEST_DEFINITION_LOCKED';
  end if;
  return coalesce(new,old);
end;
$$;

create trigger test_questions_definition_guard
before insert or update or delete on public.test_questions
for each row execute function app_private.guard_test_question_definition();

create trigger test_choices_definition_guard
before insert or update or delete on public.test_choices
for each row execute function app_private.guard_test_choice_definition();

revoke all on function app_private.test_definition_locked_for_question(uuid),
  app_private.guard_test_question_definition(),
  app_private.guard_test_choice_definition()
from public,anon,authenticated,service_role;
