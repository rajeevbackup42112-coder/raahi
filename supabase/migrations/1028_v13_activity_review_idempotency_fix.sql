-- Raahi Learning V1.3 — Activity review idempotency ordering fix
-- Exact retries must return the cached result even after the first successful review
-- changed submission.current_status away from 'submitted'.
-- Authority is still checked before replay; lifecycle validation remains required for new requests.

create or replace function app_private.cmd_review_submission(
  p_submission_id uuid,
  p_outcome text,
  p_teacher_feedback text,
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
  v_activity uuid;
  v_class uuid;
  v_status text;
  v_revision_id uuid;
  v_result jsonb;
begin
  if p_outcome not in ('changes_requested','reviewed') then
    raise exception 'INVALID_REVIEW_OUTCOME';
  end if;

  select s.activity_id,a.class_id,s.current_status
  into v_activity,v_class,v_status
  from public.submissions s
  join public.activities a on a.id=s.activity_id
  where s.id=p_submission_id
  for update of s;

  if not found then raise exception 'SUBMISSION_NOT_FOUND'; end if;
  if not app_private.can_manage_class(v_class) then raise exception 'NOT_AUTHORIZED'; end if;
  if app_private.current_actor_class_access_blocked(v_class)
     or app_private.class_provider_access_blocked(v_class) then
    raise exception 'CLASS_ACCESS_RESTRICTED';
  end if;

  v_fp:=app_private.request_fingerprint(jsonb_build_object(
    'submission_id',p_submission_id,
    'outcome',p_outcome,
    'teacher_feedback',p_teacher_feedback
  ));
  v_gate:=app_private.begin_human_idempotent_command(
    v_actor,'review_submission',p_idempotency_key,v_fp
  );

  -- A completed exact retry must replay before validating the post-transition state.
  if (v_gate->>'cached')::boolean then
    return v_gate->'result';
  end if;

  if v_status<>'submitted' then
    raise exception 'SUBMISSION_NOT_AWAITING_REVIEW';
  end if;

  select id into v_revision_id
  from public.submission_revisions
  where submission_id=p_submission_id
  order by revision_number desc
  limit 1
  for update;

  if v_revision_id is null then raise exception 'SUBMISSION_REVISION_MISSING'; end if;

  update public.submission_revisions
  set review_outcome=p_outcome,
      teacher_feedback=nullif(btrim(p_teacher_feedback),''),
      reviewed_by_account_id=v_actor,
      reviewed_at=now()
  where id=v_revision_id;

  update public.submissions
  set current_status=p_outcome
  where id=p_submission_id;

  v_result:=jsonb_build_object(
    'submission_id',p_submission_id,
    'revision_id',v_revision_id,
    'status',p_outcome
  );

  perform app_private.complete_human_idempotent_command(
    v_actor,'review_submission',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;

revoke all on function app_private.cmd_review_submission(uuid,text,text,text)
from public,anon,authenticated,service_role;
