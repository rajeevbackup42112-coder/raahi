-- Raahi Learning V1.2 — Tests, immutable-after-start definition and single Attempts

create table public.tests (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id),
  created_by_account_id uuid not null references public.accounts(id),
  title text not null,
  instructions text null,
  available_from timestamptz null,
  closes_at timestamptz null,
  duration_seconds integer null,
  state text not null default 'draft',
  results_visible boolean not null default false,
  definition_locked_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tests_title_nonblank check (char_length(btrim(title)) between 1 and 300),
  constraint tests_instructions_length check (instructions is null or char_length(instructions) <= 20000),
  constraint tests_duration_positive check (duration_seconds is null or duration_seconds > 0),
  constraint tests_window_check check (available_from is null or closes_at is null or closes_at > available_from),
  constraint tests_state_check check (state in ('draft','available','closed'))
);

create table public.test_questions (
  id uuid primary key default gen_random_uuid(),
  test_id uuid not null references public.tests(id),
  position integer not null,
  question_type text not null default 'mcq',
  prompt text not null,
  points numeric(10,2) not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint test_questions_position_positive check (position >= 1),
  constraint test_questions_type_check check (question_type in ('mcq')),
  constraint test_questions_prompt_nonblank check (char_length(btrim(prompt)) between 1 and 12000),
  constraint test_questions_points_positive check (points > 0),
  constraint test_questions_unique_position unique(test_id,position)
);

create table public.test_choices (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.test_questions(id),
  position integer not null,
  choice_text text not null,
  is_correct boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint test_choices_position_positive check (position >= 1),
  constraint test_choices_text_nonblank check (char_length(btrim(choice_text)) between 1 and 4000),
  constraint test_choices_unique_position unique(question_id,position)
);

create table public.test_attempts (
  id uuid primary key default gen_random_uuid(),
  test_id uuid not null references public.tests(id),
  learner_id uuid not null references public.learners(id),
  state text not null default 'in_progress',
  started_at timestamptz not null default now(),
  submitted_at timestamptz null,
  evaluated_at timestamptz null,
  score numeric(12,2) null,
  teacher_feedback text null,
  invalidation_reason text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint test_attempts_state_check check (state in ('in_progress','submitted','evaluated','invalidated')),
  constraint test_attempts_state_timestamps check (
    (state='in_progress' and submitted_at is null and evaluated_at is null and invalidation_reason is null)
    or (state='submitted' and submitted_at is not null and evaluated_at is null and invalidation_reason is null)
    or (state='evaluated' and submitted_at is not null and evaluated_at is not null and invalidation_reason is null)
    or (state='invalidated' and invalidation_reason is not null)
  ),
  constraint test_attempts_test_learner_unique unique(test_id,learner_id)
);

create table public.test_attempt_answers (
  attempt_id uuid not null references public.test_attempts(id),
  question_id uuid not null references public.test_questions(id),
  selected_choice_id uuid null references public.test_choices(id),
  text_response text null,
  saved_at timestamptz not null default now(),
  primary key(attempt_id,question_id),
  constraint test_attempt_answers_content check (selected_choice_id is not null or text_response is not null)
);

create index tests_class_state_idx on public.tests(class_id,state,updated_at desc);
create index tests_availability_idx on public.tests(state,available_from,closes_at);
create index tests_created_by_idx on public.tests(created_by_account_id,created_at desc);
create index test_questions_test_idx on public.test_questions(test_id,position);
create index test_choices_question_idx on public.test_choices(question_id,position);
create index test_attempts_learner_state_idx on public.test_attempts(learner_id,state,started_at desc);
create index test_attempts_test_state_idx on public.test_attempts(test_id,state,started_at desc);
create index test_attempt_answers_question_idx on public.test_attempt_answers(question_id,attempt_id);
create index test_attempt_answers_choice_idx on public.test_attempt_answers(selected_choice_id) where selected_choice_id is not null;

create trigger tests_set_updated_at before update on public.tests for each row execute function app_private.set_updated_at();
create trigger test_questions_set_updated_at before update on public.test_questions for each row execute function app_private.set_updated_at();
create trigger test_choices_set_updated_at before update on public.test_choices for each row execute function app_private.set_updated_at();
create trigger test_attempts_set_updated_at before update on public.test_attempts for each row execute function app_private.set_updated_at();
