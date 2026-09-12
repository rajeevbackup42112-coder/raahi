-- Raahi Learning V1.2 — Private Class feed and contextual learner threads

create table public.class_posts (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id),
  author_account_id uuid not null references public.accounts(id),
  learner_id uuid null references public.learners(id),
  post_type text not null,
  body text not null,
  importance text not null default 'normal',
  comments_enabled boolean not null default true,
  visibility_status text not null default 'visible',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint class_posts_type_check check (post_type in ('update','announcement','question')),
  constraint class_posts_body_nonblank check (char_length(btrim(body)) between 1 and 12000),
  constraint class_posts_importance_check check (importance in ('normal','important')),
  constraint class_posts_visibility_check check (visibility_status in ('visible','hidden','removed'))
);

create table public.class_post_comments (
  id uuid primary key default gen_random_uuid(),
  class_post_id uuid not null references public.class_posts(id),
  author_account_id uuid not null references public.accounts(id),
  learner_id uuid null references public.learners(id),
  body text not null,
  visibility_status text not null default 'visible',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint class_post_comments_body_nonblank check (char_length(btrim(body)) between 1 and 8000),
  constraint class_post_comments_visibility_check check (visibility_status in ('visible','hidden','removed'))
);

create table public.class_learner_threads (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id),
  learner_id uuid not null references public.learners(id),
  created_at timestamptz not null default now(),
  constraint class_learner_threads_unique unique(class_id,learner_id)
);

create table public.class_learner_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.class_learner_threads(id),
  sender_account_id uuid not null references public.accounts(id),
  body text not null,
  created_at timestamptz not null default now(),
  constraint class_learner_messages_body_nonblank check (char_length(btrim(body)) between 1 and 8000)
);

create index class_posts_class_time_idx on public.class_posts(class_id,created_at desc,id);
create index class_posts_learner_idx on public.class_posts(learner_id,created_at desc) where learner_id is not null;
create index class_posts_author_idx on public.class_posts(author_account_id,created_at desc);
create index class_post_comments_post_time_idx on public.class_post_comments(class_post_id,created_at,id);
create index class_post_comments_author_idx on public.class_post_comments(author_account_id,created_at desc);
create index class_post_comments_learner_idx on public.class_post_comments(learner_id,created_at desc) where learner_id is not null;
create index class_learner_threads_learner_idx on public.class_learner_threads(learner_id,class_id);
create index class_learner_messages_thread_time_idx on public.class_learner_messages(thread_id,created_at,id);
create index class_learner_messages_sender_idx on public.class_learner_messages(sender_account_id,created_at desc);

create trigger class_posts_set_updated_at before update on public.class_posts for each row execute function app_private.set_updated_at();
create trigger class_post_comments_set_updated_at before update on public.class_post_comments for each row execute function app_private.set_updated_at();
