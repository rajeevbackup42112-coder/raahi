-- Raahi Learning V1.3 — Activity submission/review side-effect closure (SE-06A, SE-06B)
-- Submission revision rows already preserve performer/reviewer/time/outcome.
-- Notifications remain derived and never copy submission text or teacher feedback.

create or replace function app_private.trg_notify_submission_revision_insert()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_activity uuid;
  v_class uuid;
  v_learner uuid;
begin
  select s.activity_id,s.learner_id,a.class_id
  into v_activity,v_learner,v_class
  from public.submissions s
  join public.activities a on a.id=s.activity_id
  where s.id=new.submission_id;

  if v_activity is null or v_class is null or v_learner is null then return new; end if;

  perform app_private.notify_class_provider_accounts(
    v_class,
    new.performed_by_account_id,
    'activity_submission_received',
    'submission_revision',
    new.id,
    case when new.revision_number>1 then 'Activity resubmitted' else 'Activity submission received' end,
    case when new.revision_number>1
      then 'A learner resubmitted work for an Activity.'
      else 'A learner submitted work for an Activity.'
    end,
    jsonb_build_object(
      'class_id',v_class,
      'activity_id',v_activity,
      'submission_id',new.submission_id,
      'revision_id',new.id,
      'revision_number',new.revision_number,
      'learner_id',v_learner
    )
  );
  return new;
end;
$$;

create or replace function app_private.trg_notify_submission_revision_review()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_activity uuid;
  v_class uuid;
  v_learner uuid;
  v_type text;
  v_title text;
  v_body text;
begin
  if old.reviewed_at is not null or new.reviewed_at is null then return new; end if;

  select s.activity_id,s.learner_id,a.class_id
  into v_activity,v_learner,v_class
  from public.submissions s
  join public.activities a on a.id=s.activity_id
  where s.id=new.submission_id;

  if v_activity is null or v_class is null or v_learner is null then return new; end if;

  if new.review_outcome='changes_requested' then
    v_type:='activity_submission_changes_requested';
    v_title:='Activity changes requested';
    v_body:='Changes were requested for an Activity submission. Open the Activity to review feedback.';
  else
    v_type:='activity_submission_reviewed';
    v_title:='Activity reviewed';
    v_body:='An Activity submission was reviewed. Open the Activity to see the outcome.';
  end if;

  perform app_private.notify_learner_accounts(
    v_learner,
    new.reviewed_by_account_id,
    v_type,
    'submission_revision',
    new.id,
    v_title,
    v_body,
    jsonb_build_object(
      'class_id',v_class,
      'activity_id',v_activity,
      'submission_id',new.submission_id,
      'revision_id',new.id,
      'revision_number',new.revision_number,
      'learner_id',v_learner,
      'outcome',new.review_outcome
    )
  );
  return new;
end;
$$;

drop trigger if exists notify_submission_revision_insert on public.submission_revisions;
create trigger notify_submission_revision_insert
after insert on public.submission_revisions
for each row execute function app_private.trg_notify_submission_revision_insert();

drop trigger if exists notify_submission_revision_review on public.submission_revisions;
create trigger notify_submission_revision_review
after update of review_outcome,reviewed_at on public.submission_revisions
for each row execute function app_private.trg_notify_submission_revision_review();

revoke all on function app_private.trg_notify_submission_revision_insert()
from public,anon,authenticated,service_role;
revoke all on function app_private.trg_notify_submission_revision_review()
from public,anon,authenticated,service_role;
