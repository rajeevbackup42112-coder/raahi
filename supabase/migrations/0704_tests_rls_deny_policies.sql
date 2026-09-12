-- Raahi Learning V1.2 — explicit deny policies for base Test internals.
-- These tables are intentionally projection/RPC-only for authenticated clients.

create policy test_questions_authenticated_deny
on public.test_questions for select to authenticated using(false);
create policy test_choices_authenticated_deny
on public.test_choices for select to authenticated using(false);
create policy test_attempts_authenticated_deny
on public.test_attempts for select to authenticated using(false);
create policy test_attempt_answers_authenticated_deny
on public.test_attempt_answers for select to authenticated using(false);
