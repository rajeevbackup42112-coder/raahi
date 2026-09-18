-- Raahi Learning V1.3 — Class post side-effect closure (SE-04A, SE-04B)
-- Ordinary Class posts/comments remain refresh-only. Only provider announcements/important posts
-- and learner questions create derived attention signals.

create or replace function app_private.trg_notify_class_post_insert()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if new.learner_id is null then
    if new.post_type='announcement' or new.importance='important' then
      perform app_private.notify_active_class_learner_accounts(
        new.class_id,
        new.author_account_id,
        'class_announcement',
        'class_post',
        new.id,
        'Class update',
        case
          when new.post_type='announcement' then 'A new Class announcement was posted.'
          else 'An important Class update was posted.'
        end,
        jsonb_build_object(
          'class_id',new.class_id,
          'class_post_id',new.id,
          'post_type',new.post_type,
          'importance',new.importance
        )
      );
    end if;
  elsif new.post_type='question' then
    perform app_private.notify_class_provider_accounts(
      new.class_id,
      new.author_account_id,
      'class_question',
      'class_post',
      new.id,
      'New learner question',
      'A learner posted a question in a Class.',
      jsonb_build_object(
        'class_id',new.class_id,
        'class_post_id',new.id,
        'learner_id',new.learner_id
      )
    );
  end if;
  return new;
end;
$$;

drop trigger if exists notify_class_post_insert on public.class_posts;
create trigger notify_class_post_insert
after insert on public.class_posts
for each row execute function app_private.trg_notify_class_post_insert();

revoke all on function app_private.trg_notify_class_post_insert()
from public,anon,authenticated,service_role;
