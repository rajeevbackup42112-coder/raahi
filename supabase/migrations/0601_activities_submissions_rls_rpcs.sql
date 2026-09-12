-- Raahi Learning V1.2 — Activity lifecycle, Material links, Submission revisions and RLS

create or replace function app_private.can_manage_activity(p_activity_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.activities a where a.id=p_activity_id and app_private.can_manage_class(a.class_id));
$$;

create or replace function app_private.can_read_activity(p_activity_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_class uuid; v_state text;
begin
  select class_id,state into v_class,v_state from public.activities where id=p_activity_id;
  if not found then return false; end if;
  if app_private.can_read_class_as_provider(v_class) then
    return not app_private.current_actor_class_access_blocked(v_class)
      and not app_private.class_provider_access_blocked(v_class);
  end if;
  return v_state in ('open','closed') and app_private.can_read_class_shared(v_class);
end; $$;

create or replace function app_private.can_read_submission(p_submission_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_learner uuid; v_class uuid;
begin
  select s.learner_id,a.class_id into v_learner,v_class
  from public.submissions s join public.activities a on a.id=s.activity_id
  where s.id=p_submission_id;
  if not found then return false; end if;
  if app_private.can_read_class_as_provider(v_class) then
    return not app_private.current_actor_class_access_blocked(v_class)
      and not app_private.class_provider_access_blocked(v_class);
  end if;
  return app_private.can_access_learner(v_learner)
    and not app_private.current_actor_class_access_blocked(v_class);
end; $$;

create or replace function app_private.cmd_create_activity(
  p_class_id uuid,p_display_type text,p_title text,p_instructions text,p_due_at timestamptz,
  p_submission_required boolean,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_class_state text; v_activity uuid; v_result jsonb;
begin
  if not app_private.can_manage_class(p_class_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if p_display_type not in ('assignment','practice','exercise') then raise exception 'INVALID_ACTIVITY_TYPE'; end if;
  if p_title is null or char_length(btrim(p_title)) not between 1 and 300 then raise exception 'INVALID_ACTIVITY_TITLE'; end if;
  select state into v_class_state from public.classes where id=p_class_id;
  if not found then raise exception 'CLASS_NOT_FOUND'; end if;
  if v_class_state='past' then raise exception 'CLASS_PAST'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('class_id',p_class_id,'display_type',p_display_type,'title',p_title,'instructions',p_instructions,'due_at',p_due_at,'submission_required',p_submission_required));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'create_activity',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.activities(class_id,created_by_account_id,display_type,title,instructions,due_at,submission_required,state)
  values(p_class_id,v_actor,p_display_type,btrim(p_title),nullif(btrim(p_instructions),''),p_due_at,coalesce(p_submission_required,false),'draft')
  returning id into v_activity;
  v_result:=jsonb_build_object('activity_id',v_activity,'class_id',p_class_id,'state','draft');
  perform app_private.complete_human_idempotent_command(v_actor,'create_activity',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_update_activity(
  p_activity_id uuid,p_display_type text,p_title text,p_instructions text,p_due_at timestamptz,
  p_submission_required boolean,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_state text; v_old_type text; v_old_required boolean; v_has_submission boolean; v_result jsonb;
begin
  if not app_private.can_manage_activity(p_activity_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if p_display_type not in ('assignment','practice','exercise') then raise exception 'INVALID_ACTIVITY_TYPE'; end if;
  if p_title is null or char_length(btrim(p_title)) not between 1 and 300 then raise exception 'INVALID_ACTIVITY_TITLE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('activity_id',p_activity_id,'display_type',p_display_type,'title',p_title,'instructions',p_instructions,'due_at',p_due_at,'submission_required',p_submission_required));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'update_activity',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select state,display_type,submission_required into v_state,v_old_type,v_old_required from public.activities where id=p_activity_id for update;
  if not found then raise exception 'ACTIVITY_NOT_FOUND'; end if;
  if v_state='closed' then raise exception 'ACTIVITY_CLOSED'; end if;
  select exists(select 1 from public.submissions where activity_id=p_activity_id) into v_has_submission;
  if v_has_submission and (v_old_type is distinct from p_display_type or v_old_required is distinct from p_submission_required) then
    raise exception 'ACTIVITY_STRUCTURE_LOCKED_AFTER_SUBMISSION';
  end if;
  update public.activities set display_type=p_display_type,title=btrim(p_title),instructions=nullif(btrim(p_instructions),''),due_at=p_due_at,submission_required=coalesce(p_submission_required,false)
  where id=p_activity_id;
  v_result:=jsonb_build_object('activity_id',p_activity_id,'state',v_state,'updated',true);
  perform app_private.complete_human_idempotent_command(v_actor,'update_activity',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_publish_activity(p_activity_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_class uuid; v_state text; v_result jsonb;
begin
  if not app_private.can_manage_activity(p_activity_id) then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('activity_id',p_activity_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'publish_activity',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select class_id,state into v_class,v_state from public.activities where id=p_activity_id for update;
  if not found then raise exception 'ACTIVITY_NOT_FOUND'; end if;
  if not exists(select 1 from public.classes where id=v_class and state='active') then raise exception 'CLASS_NOT_ACTIVE'; end if;
  if v_state='open' then v_result:=jsonb_build_object('activity_id',p_activity_id,'state','open','already_open',true);
  elsif v_state<>'draft' then raise exception 'ACTIVITY_NOT_DRAFT';
  else update public.activities set state='open' where id=p_activity_id; v_result:=jsonb_build_object('activity_id',p_activity_id,'state','open','already_open',false); end if;
  perform app_private.complete_human_idempotent_command(v_actor,'publish_activity',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_close_activity(p_activity_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_state text; v_result jsonb;
begin
  if not app_private.can_manage_activity(p_activity_id) then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('activity_id',p_activity_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'close_activity',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select state into v_state from public.activities where id=p_activity_id for update; if not found then raise exception 'ACTIVITY_NOT_FOUND'; end if;
  if v_state='closed' then v_result:=jsonb_build_object('activity_id',p_activity_id,'state','closed','already_closed',true);
  elsif v_state<>'open' then raise exception 'ACTIVITY_NOT_OPEN';
  else update public.activities set state='closed' where id=p_activity_id; v_result:=jsonb_build_object('activity_id',p_activity_id,'state','closed','already_closed',false); end if;
  perform app_private.complete_human_idempotent_command(v_actor,'close_activity',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_set_activity_material_link(
  p_activity_id uuid,p_material_id uuid,p_linked boolean,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_class uuid; v_rows integer:=0; v_result jsonb;
begin
  if not app_private.can_manage_activity(p_activity_id) then raise exception 'NOT_AUTHORIZED'; end if;
  select class_id into v_class from public.activities where id=p_activity_id;
  if not found then raise exception 'ACTIVITY_NOT_FOUND'; end if;
  if p_linked and not exists(select 1 from public.material_class_links where material_id=p_material_id and class_id=v_class) then raise exception 'MATERIAL_NOT_SHARED_TO_ACTIVITY_CLASS'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('activity_id',p_activity_id,'material_id',p_material_id,'linked',p_linked));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'set_activity_material_link',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if p_linked then insert into public.activity_material_links(activity_id,material_id) values(p_activity_id,p_material_id) on conflict do nothing; get diagnostics v_rows=row_count;
  else delete from public.activity_material_links where activity_id=p_activity_id and material_id=p_material_id; get diagnostics v_rows=row_count; end if;
  v_result:=jsonb_build_object('activity_id',p_activity_id,'material_id',p_material_id,'linked',p_linked,'changed',v_rows>0);
  perform app_private.complete_human_idempotent_command(v_actor,'set_activity_material_link',p_idempotency_key,v_result); return v_result;
end; $$;

-- Forward-hardening: a Material cannot be removed from a Class while an Activity
-- in that Class still references it. Unlink the Activity first.
create or replace function app_private.cmd_set_material_class_link(p_material_id uuid,p_class_id uuid,p_linked boolean,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_rows integer:=0; v_result jsonb;
begin
  if not app_private.can_manage_class(p_class_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if not app_private.can_manage_material(p_material_id) then raise exception 'MATERIAL_NOT_AUTHORIZED'; end if;
  if not p_linked and exists(
    select 1 from public.activity_material_links aml
    join public.activities a on a.id=aml.activity_id
    where aml.material_id=p_material_id and a.class_id=p_class_id
  ) then raise exception 'MATERIAL_STILL_LINKED_TO_ACTIVITY'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('material_id',p_material_id,'class_id',p_class_id,'linked',p_linked));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'set_material_class_link',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if p_linked then insert into public.material_class_links(material_id,class_id) values(p_material_id,p_class_id) on conflict do nothing; get diagnostics v_rows=row_count;
  else delete from public.material_class_links where material_id=p_material_id and class_id=p_class_id; get diagnostics v_rows=row_count; end if;
  v_result:=jsonb_build_object('material_id',p_material_id,'class_id',p_class_id,'linked',p_linked,'changed',v_rows>0);
  perform app_private.complete_human_idempotent_command(v_actor,'set_material_class_link',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_submit_activity(
  p_activity_id uuid,p_learner_id uuid,p_text_response text,p_file_asset_id uuid,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_class uuid; v_state text;
  v_submission uuid; v_status text; v_revision integer; v_revision_id uuid; v_result jsonb;
begin
  if p_text_response is null and p_file_asset_id is null then raise exception 'SUBMISSION_CONTENT_REQUIRED'; end if;
  select class_id,state into v_class,v_state from public.activities where id=p_activity_id;
  if not found then raise exception 'ACTIVITY_NOT_FOUND'; end if;
  if v_state<>'open' then raise exception 'ACTIVITY_NOT_OPEN'; end if;
  if not app_private.has_active_class_membership(v_class,p_learner_id) then raise exception 'ACTIVE_MEMBERSHIP_REQUIRED'; end if;
  if not app_private.can_access_learner(p_learner_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if app_private.current_actor_class_access_blocked(v_class) or app_private.class_provider_access_blocked(v_class) then raise exception 'CLASS_ACCESS_RESTRICTED'; end if;
  if p_file_asset_id is not null and not exists(select 1 from public.file_assets where id=p_file_asset_id and uploaded_by_account_id=v_actor and status='active') then raise exception 'SUBMISSION_FILE_NOT_OWNED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('activity_id',p_activity_id,'learner_id',p_learner_id,'text_response',p_text_response,'file_asset_id',p_file_asset_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'submit_activity',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select id,current_status into v_submission,v_status from public.submissions
  where activity_id=p_activity_id and learner_id=p_learner_id for update;
  if v_submission is null then
    insert into public.submissions(activity_id,learner_id,current_status)
    values(p_activity_id,p_learner_id,'submitted') returning id into v_submission;
    v_revision:=1;
  else
    if v_status='submitted' then raise exception 'SUBMISSION_ALREADY_SUBMITTED'; end if;
    if v_status='reviewed' then raise exception 'SUBMISSION_ALREADY_REVIEWED'; end if;
    if v_status<>'changes_requested' then raise exception 'SUBMISSION_NOT_RESUBMITTABLE'; end if;
    select coalesce(max(revision_number),0)+1 into v_revision from public.submission_revisions where submission_id=v_submission;
    update public.submissions set current_status='submitted' where id=v_submission;
  end if;

  insert into public.submission_revisions(submission_id,revision_number,performed_by_account_id,text_response,file_asset_id)
  values(v_submission,v_revision,v_actor,nullif(btrim(p_text_response),''),p_file_asset_id)
  returning id into v_revision_id;

  v_result:=jsonb_build_object('submission_id',v_submission,'revision_id',v_revision_id,'revision_number',v_revision,'status','submitted','learner_id',p_learner_id);
  perform app_private.complete_human_idempotent_command(v_actor,'submit_activity',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_review_submission(
  p_submission_id uuid,p_outcome text,p_teacher_feedback text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_activity uuid; v_class uuid; v_status text;
  v_revision_id uuid; v_result jsonb;
begin
  if p_outcome not in ('changes_requested','reviewed') then raise exception 'INVALID_REVIEW_OUTCOME'; end if;
  select s.activity_id,a.class_id,s.current_status into v_activity,v_class,v_status
  from public.submissions s join public.activities a on a.id=s.activity_id
  where s.id=p_submission_id for update of s;
  if not found then raise exception 'SUBMISSION_NOT_FOUND'; end if;
  if not app_private.can_manage_class(v_class) then raise exception 'NOT_AUTHORIZED'; end if;
  if app_private.current_actor_class_access_blocked(v_class) or app_private.class_provider_access_blocked(v_class) then raise exception 'CLASS_ACCESS_RESTRICTED'; end if;
  if v_status<>'submitted' then raise exception 'SUBMISSION_NOT_AWAITING_REVIEW'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('submission_id',p_submission_id,'outcome',p_outcome,'teacher_feedback',p_teacher_feedback));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'review_submission',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select id into v_revision_id from public.submission_revisions where submission_id=p_submission_id order by revision_number desc limit 1 for update;
  if v_revision_id is null then raise exception 'SUBMISSION_REVISION_MISSING'; end if;
  update public.submission_revisions set review_outcome=p_outcome,teacher_feedback=nullif(btrim(p_teacher_feedback),''),reviewed_by_account_id=v_actor,reviewed_at=now()
  where id=v_revision_id;
  update public.submissions set current_status=p_outcome where id=p_submission_id;
  v_result:=jsonb_build_object('submission_id',p_submission_id,'revision_id',v_revision_id,'status',p_outcome);
  perform app_private.complete_human_idempotent_command(v_actor,'review_submission',p_idempotency_key,v_result); return v_result;
end; $$;

alter table public.activities enable row level security; alter table public.activities force row level security;
alter table public.activity_material_links enable row level security; alter table public.activity_material_links force row level security;
alter table public.submissions enable row level security; alter table public.submissions force row level security;
alter table public.submission_revisions enable row level security; alter table public.submission_revisions force row level security;

create policy activities_select_authorized on public.activities for select to authenticated using(app_private.can_read_activity(id));
create policy activity_material_links_select_authorized on public.activity_material_links for select to authenticated using(app_private.can_read_activity(activity_id));
create policy submissions_select_authorized on public.submissions for select to authenticated using(app_private.can_read_submission(id));
create policy submission_revisions_select_authorized on public.submission_revisions for select to authenticated using(app_private.can_read_submission(submission_id));

revoke all on table public.activities,public.activity_material_links,public.submissions,public.submission_revisions from public,anon,authenticated,service_role;
grant select on table public.activities,public.activity_material_links,public.submissions,public.submission_revisions to authenticated;
grant select,insert,update,delete on table public.activities,public.activity_material_links,public.submissions,public.submission_revisions to service_role;

-- Submission file visibility becomes a business-authorization path in addition
-- to uploader-owned files and Class Materials.
create or replace function app_private.can_read_file_asset(p_file_asset_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
      select 1 from public.file_assets f
      where f.id=p_file_asset_id and f.status='active'
        and f.uploaded_by_account_id=app_private.current_account_id()
    )
    or exists(
      select 1 from public.materials m
      where m.file_asset_id=p_file_asset_id and app_private.can_read_material(m.id)
    )
    or exists(
      select 1 from public.submission_revisions sr
      where sr.file_asset_id=p_file_asset_id and app_private.can_read_submission(sr.submission_id)
    );
$$;

revoke all on function app_private.can_manage_activity(uuid),app_private.can_read_activity(uuid),app_private.can_read_submission(uuid),
 app_private.cmd_create_activity(uuid,text,text,text,timestamptz,boolean,text),app_private.cmd_update_activity(uuid,text,text,text,timestamptz,boolean,text),
 app_private.cmd_publish_activity(uuid,text),app_private.cmd_close_activity(uuid,text),app_private.cmd_set_activity_material_link(uuid,uuid,boolean,text),
 app_private.cmd_submit_activity(uuid,uuid,text,uuid,text),app_private.cmd_review_submission(uuid,text,text,text)
from public,anon,authenticated,service_role;
grant execute on function app_private.can_read_activity(uuid),app_private.can_read_submission(uuid) to authenticated;
grant execute on function app_private.cmd_create_activity(uuid,text,text,text,timestamptz,boolean,text),app_private.cmd_update_activity(uuid,text,text,text,timestamptz,boolean,text),
 app_private.cmd_publish_activity(uuid,text),app_private.cmd_close_activity(uuid,text),app_private.cmd_set_activity_material_link(uuid,uuid,boolean,text),
 app_private.cmd_submit_activity(uuid,uuid,text,uuid,text),app_private.cmd_review_submission(uuid,text,text,text) to authenticated;

create or replace function public.create_activity(p_class_id uuid,p_display_type text,p_title text,p_instructions text,p_due_at timestamptz,p_submission_required boolean,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_create_activity(p_class_id,p_display_type,p_title,p_instructions,p_due_at,p_submission_required,p_idempotency_key); $$;
create or replace function public.update_activity(p_activity_id uuid,p_display_type text,p_title text,p_instructions text,p_due_at timestamptz,p_submission_required boolean,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_update_activity(p_activity_id,p_display_type,p_title,p_instructions,p_due_at,p_submission_required,p_idempotency_key); $$;
create or replace function public.publish_activity(p_activity_id uuid,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_publish_activity(p_activity_id,p_idempotency_key); $$;
create or replace function public.close_activity(p_activity_id uuid,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_close_activity(p_activity_id,p_idempotency_key); $$;
create or replace function public.set_activity_material_link(p_activity_id uuid,p_material_id uuid,p_linked boolean,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_set_activity_material_link(p_activity_id,p_material_id,p_linked,p_idempotency_key); $$;
create or replace function public.submit_activity(p_activity_id uuid,p_learner_id uuid,p_text_response text,p_file_asset_id uuid,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_submit_activity(p_activity_id,p_learner_id,p_text_response,p_file_asset_id,p_idempotency_key); $$;
create or replace function public.request_submission_changes(p_submission_id uuid,p_teacher_feedback text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_review_submission(p_submission_id,'changes_requested',p_teacher_feedback,p_idempotency_key); $$;
create or replace function public.review_submission(p_submission_id uuid,p_teacher_feedback text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_review_submission(p_submission_id,'reviewed',p_teacher_feedback,p_idempotency_key); $$;

revoke all on function public.create_activity(uuid,text,text,text,timestamptz,boolean,text),public.update_activity(uuid,text,text,text,timestamptz,boolean,text),
 public.publish_activity(uuid,text),public.close_activity(uuid,text),public.set_activity_material_link(uuid,uuid,boolean,text),
 public.submit_activity(uuid,uuid,text,uuid,text),public.request_submission_changes(uuid,text,text),public.review_submission(uuid,text,text)
from public,anon,authenticated,service_role;
grant execute on function public.create_activity(uuid,text,text,text,timestamptz,boolean,text),public.update_activity(uuid,text,text,text,timestamptz,boolean,text),
 public.publish_activity(uuid,text),public.close_activity(uuid,text),public.set_activity_material_link(uuid,uuid,boolean,text),
 public.submit_activity(uuid,uuid,text,uuid,text),public.request_submission_changes(uuid,text,text),public.review_submission(uuid,text,text)
to authenticated;
