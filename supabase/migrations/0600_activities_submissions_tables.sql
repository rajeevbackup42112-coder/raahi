-- Raahi Learning V1.2 — Unified Activities and Learner-owned Submission revisions

create table public.activities (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id),
  created_by_account_id uuid not null references public.accounts(id),
  display_type text not null,
  title text not null,
  instructions text null,
  due_at timestamptz null,
  submission_required boolean not null default false,
  state text not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint activities_display_type_check check (display_type in ('assignment','practice','exercise')),
  constraint activities_title_nonblank check (char_length(btrim(title)) between 1 and 300),
  constraint activities_instructions_length check (instructions is null or char_length(instructions) <= 20000),
  constraint activities_state_check check (state in ('draft','open','closed'))
);

create table public.activity_material_links (
  activity_id uuid not null references public.activities(id),
  material_id uuid not null references public.materials(id),
  created_at timestamptz not null default now(),
  primary key(activity_id,material_id)
);

create table public.submissions (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id),
  learner_id uuid not null references public.learners(id),
  current_status text not null default 'submitted',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint submissions_status_check check (current_status in ('submitted','changes_requested','reviewed')),
  constraint submissions_activity_learner_unique unique(activity_id,learner_id)
);

create table public.submission_revisions (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.submissions(id),
  revision_number integer not null,
  performed_by_account_id uuid not null references public.accounts(id),
  text_response text null,
  file_asset_id uuid null references public.file_assets(id),
  submitted_at timestamptz not null default now(),
  review_outcome text null,
  teacher_feedback text null,
  reviewed_by_account_id uuid null references public.accounts(id),
  reviewed_at timestamptz null,
  constraint submission_revisions_revision_positive check (revision_number >= 1),
  constraint submission_revisions_content_present check (text_response is not null or file_asset_id is not null),
  constraint submission_revisions_review_outcome_check check (review_outcome is null or review_outcome in ('changes_requested','reviewed')),
  constraint submission_revisions_review_consistency check (
    (review_outcome is null and teacher_feedback is null and reviewed_by_account_id is null and reviewed_at is null)
    or (review_outcome is not null and reviewed_by_account_id is not null and reviewed_at is not null)
  ),
  constraint submission_revisions_unique_number unique(submission_id,revision_number)
);

create index activities_class_state_idx on public.activities(class_id,state,updated_at desc);
create index activities_created_by_idx on public.activities(created_by_account_id,created_at desc);
create index activities_due_open_idx on public.activities(due_at) where state='open' and due_at is not null;
create index activity_material_links_material_idx on public.activity_material_links(material_id,activity_id);
create index submissions_learner_status_idx on public.submissions(learner_id,current_status,updated_at desc);
create index submissions_activity_status_idx on public.submissions(activity_id,current_status,updated_at desc);
create index submission_revisions_performer_idx on public.submission_revisions(performed_by_account_id,submitted_at desc);
create index submission_revisions_file_idx on public.submission_revisions(file_asset_id) where file_asset_id is not null;
create index submission_revisions_reviewer_idx on public.submission_revisions(reviewed_by_account_id,reviewed_at desc) where reviewed_by_account_id is not null;

create trigger activities_set_updated_at before update on public.activities for each row execute function app_private.set_updated_at();
create trigger submissions_set_updated_at before update on public.submissions for each row execute function app_private.set_updated_at();

comment on column public.submission_revisions.teacher_feedback is
  'Feedback is revision-specific so Changes Requested and Reviewed history shown by the frozen UI is preserved.';
