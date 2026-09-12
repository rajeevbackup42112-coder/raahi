-- Raahi Learning V1.2 — Class-private communication commands and RLS

create or replace function app_private.has_active_class_membership(p_class_id uuid,p_learner_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.class_memberships where class_id=p_class_id and learner_id=p_learner_id and state='active');
$$;

create or replace function app_private.class_messaging_blocked(p_class_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_actor uuid:=app_private.current_account_id(); v_location uuid; v_teacher uuid; v_org uuid;
begin
  if v_actor is null then return true; end if;
  select location_id,responsible_teacher_account_id,organization_id into v_location,v_teacher,v_org from public.classes where id=p_class_id;
  if not found then return true; end if;
  if app_private.has_active_account_restriction(v_actor,'messaging',v_location) then return true; end if;
  if v_org is not null then return app_private.has_active_organization_restriction(v_org,'messaging',v_location); end if;
  return app_private.has_active_account_restriction(v_teacher,'messaging',v_location);
end; $$;

create or replace function app_private.can_write_class_as_learner(p_class_id uuid,p_learner_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select app_private.has_active_class_membership(p_class_id,p_learner_id)
    and app_private.can_access_learner(p_learner_id)
    and not app_private.current_actor_class_access_blocked(p_class_id)
    and not app_private.class_provider_access_blocked(p_class_id)
    and not app_private.class_messaging_blocked(p_class_id);
$$;

create or replace function app_private.can_read_class_thread(p_thread_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_class uuid; v_learner uuid;
begin
  select class_id,learner_id into v_class,v_learner from public.class_learner_threads where id=p_thread_id;
  if not found then return false; end if;
  if app_private.can_manage_class(v_class) then return true; end if;
  return app_private.can_access_learner(v_learner)
    and exists(select 1 from public.class_memberships where class_id=v_class and learner_id=v_learner and state in ('active','completed','transferred'))
    and not app_private.current_actor_class_access_blocked(v_class)
    and not app_private.class_provider_access_blocked(v_class);
end; $$;

create or replace function app_private.can_read_class_post(p_post_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_class uuid; v_visibility text;
begin
  select class_id,visibility_status into v_class,v_visibility from public.class_posts where id=p_post_id;
  if not found then return false; end if;
  if app_private.can_manage_class(v_class) then return true; end if;
  return v_visibility='visible' and app_private.can_read_class_shared(v_class);
end; $$;

create or replace function app_private.cmd_publish_class_post(
  p_class_id uuid,p_learner_id uuid,p_post_type text,p_body text,p_importance text,p_comments_enabled boolean,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_post uuid; v_result jsonb; v_state text;
begin
  if p_post_type not in ('update','announcement','question') then raise exception 'INVALID_CLASS_POST_TYPE'; end if;
  if p_body is null or char_length(btrim(p_body)) not between 1 and 12000 then raise exception 'INVALID_CLASS_POST_BODY'; end if;
  if p_importance not in ('normal','important') then raise exception 'INVALID_IMPORTANCE'; end if;
  select state into v_state from public.classes where id=p_class_id;
  if not found then raise exception 'CLASS_NOT_FOUND'; end if;
  if v_state<>'active' then raise exception 'CLASS_NOT_ACTIVE'; end if;
  if app_private.can_manage_class(p_class_id) then
    if p_learner_id is not null then raise exception 'TEACHER_POST_LEARNER_CONTEXT_NOT_ALLOWED'; end if;
  else
    if p_learner_id is null or not app_private.can_write_class_as_learner(p_class_id,p_learner_id) then raise exception 'NOT_AUTHORIZED'; end if;
    if p_post_type='announcement' or p_importance<>'normal' then raise exception 'LEARNER_POST_TYPE_NOT_ALLOWED'; end if;
  end if;
  if app_private.class_messaging_blocked(p_class_id) then raise exception 'MESSAGING_RESTRICTED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('class_id',p_class_id,'learner_id',p_learner_id,'post_type',p_post_type,'body',p_body,'importance',p_importance,'comments_enabled',p_comments_enabled));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'publish_class_post',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.class_posts(class_id,author_account_id,learner_id,post_type,body,importance,comments_enabled)
  values(p_class_id,v_actor,p_learner_id,p_post_type,btrim(p_body),p_importance,coalesce(p_comments_enabled,true)) returning id into v_post;
  v_result:=jsonb_build_object('class_post_id',v_post,'class_id',p_class_id,'visibility_status','visible');
  perform app_private.complete_human_idempotent_command(v_actor,'publish_class_post',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_comment_on_class_post(
  p_class_post_id uuid,p_learner_id uuid,p_body text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_class uuid; v_enabled boolean; v_visibility text; v_comment uuid; v_result jsonb;
begin
  if p_body is null or char_length(btrim(p_body)) not between 1 and 8000 then raise exception 'INVALID_COMMENT_BODY'; end if;
  select class_id,comments_enabled,visibility_status into v_class,v_enabled,v_visibility from public.class_posts where id=p_class_post_id;
  if not found or v_visibility<>'visible' then raise exception 'CLASS_POST_NOT_AVAILABLE'; end if;
  if not v_enabled then raise exception 'COMMENTS_DISABLED'; end if;
  if app_private.can_manage_class(v_class) then
    if p_learner_id is not null then raise exception 'TEACHER_COMMENT_LEARNER_CONTEXT_NOT_ALLOWED'; end if;
  else
    if p_learner_id is null or not app_private.can_write_class_as_learner(v_class,p_learner_id) then raise exception 'NOT_AUTHORIZED'; end if;
  end if;
  if app_private.class_messaging_blocked(v_class) then raise exception 'MESSAGING_RESTRICTED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('class_post_id',p_class_post_id,'learner_id',p_learner_id,'body',p_body));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'comment_on_class_post',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.class_post_comments(class_post_id,author_account_id,learner_id,body) values(p_class_post_id,v_actor,p_learner_id,btrim(p_body)) returning id into v_comment;
  v_result:=jsonb_build_object('comment_id',v_comment,'class_post_id',p_class_post_id);
  perform app_private.complete_human_idempotent_command(v_actor,'comment_on_class_post',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_send_class_learner_message(
  p_class_id uuid,p_learner_id uuid,p_body text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_state text; v_thread uuid; v_message uuid; v_result jsonb;
begin
  if p_body is null or char_length(btrim(p_body)) not between 1 and 8000 then raise exception 'INVALID_MESSAGE'; end if;
  select state into v_state from public.classes where id=p_class_id;
  if not found then raise exception 'CLASS_NOT_FOUND'; end if;
  if v_state<>'active' then raise exception 'CLASS_NOT_ACTIVE'; end if;
  if not app_private.has_active_class_membership(p_class_id,p_learner_id) then raise exception 'ACTIVE_MEMBERSHIP_REQUIRED'; end if;
  if not app_private.can_manage_class(p_class_id) and not app_private.can_access_learner(p_learner_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if app_private.current_actor_class_access_blocked(p_class_id) or app_private.class_provider_access_blocked(p_class_id) or app_private.class_messaging_blocked(p_class_id) then raise exception 'MESSAGING_RESTRICTED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('class_id',p_class_id,'learner_id',p_learner_id,'body',p_body));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'send_class_learner_message',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.class_learner_threads(class_id,learner_id) values(p_class_id,p_learner_id)
  on conflict(class_id,learner_id) do nothing;
  select id into v_thread from public.class_learner_threads where class_id=p_class_id and learner_id=p_learner_id;
  insert into public.class_learner_messages(thread_id,sender_account_id,body) values(v_thread,v_actor,btrim(p_body)) returning id into v_message;
  v_result:=jsonb_build_object('thread_id',v_thread,'message_id',v_message,'class_id',p_class_id,'learner_id',p_learner_id);
  perform app_private.complete_human_idempotent_command(v_actor,'send_class_learner_message',p_idempotency_key,v_result); return v_result;
end; $$;

alter table public.class_posts enable row level security; alter table public.class_posts force row level security;
alter table public.class_post_comments enable row level security; alter table public.class_post_comments force row level security;
alter table public.class_learner_threads enable row level security; alter table public.class_learner_threads force row level security;
alter table public.class_learner_messages enable row level security; alter table public.class_learner_messages force row level security;

create policy class_posts_select_authorized on public.class_posts for select to authenticated using(app_private.can_read_class_post(id));
create policy class_post_comments_select_authorized on public.class_post_comments for select to authenticated using(
  app_private.can_read_class_post(class_post_id) and (visibility_status='visible' or exists(select 1 from public.class_posts p where p.id=class_post_id and app_private.can_manage_class(p.class_id)))
);
create policy class_threads_select_authorized on public.class_learner_threads for select to authenticated using(app_private.can_read_class_thread(id));
create policy class_messages_select_authorized on public.class_learner_messages for select to authenticated using(app_private.can_read_class_thread(thread_id));

revoke all on table public.class_posts,public.class_post_comments,public.class_learner_threads,public.class_learner_messages from public,anon,authenticated,service_role;
grant select on table public.class_posts,public.class_post_comments,public.class_learner_threads,public.class_learner_messages to authenticated;
grant select,insert,update,delete on table public.class_posts,public.class_post_comments,public.class_learner_threads,public.class_learner_messages to service_role;

revoke all on function app_private.has_active_class_membership(uuid,uuid),app_private.class_messaging_blocked(uuid),app_private.can_write_class_as_learner(uuid,uuid),app_private.can_read_class_thread(uuid),app_private.can_read_class_post(uuid),
 app_private.cmd_publish_class_post(uuid,uuid,text,text,text,boolean,text),app_private.cmd_comment_on_class_post(uuid,uuid,text,text),app_private.cmd_send_class_learner_message(uuid,uuid,text,text)
from public,anon,authenticated,service_role;
grant execute on function app_private.can_read_class_thread(uuid),app_private.can_read_class_post(uuid) to authenticated;
grant execute on function app_private.cmd_publish_class_post(uuid,uuid,text,text,text,boolean,text),app_private.cmd_comment_on_class_post(uuid,uuid,text,text),app_private.cmd_send_class_learner_message(uuid,uuid,text,text) to authenticated;

create or replace function public.publish_class_post(p_class_id uuid,p_learner_id uuid,p_post_type text,p_body text,p_importance text,p_comments_enabled boolean,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_publish_class_post(p_class_id,p_learner_id,p_post_type,p_body,p_importance,p_comments_enabled,p_idempotency_key); $$;
create or replace function public.comment_on_class_post(p_class_post_id uuid,p_learner_id uuid,p_body text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_comment_on_class_post(p_class_post_id,p_learner_id,p_body,p_idempotency_key); $$;
create or replace function public.send_class_learner_message(p_class_id uuid,p_learner_id uuid,p_body text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_send_class_learner_message(p_class_id,p_learner_id,p_body,p_idempotency_key); $$;
revoke all on function public.publish_class_post(uuid,uuid,text,text,text,boolean,text),public.comment_on_class_post(uuid,uuid,text,text),public.send_class_learner_message(uuid,uuid,text,text) from public,anon,authenticated,service_role;
grant execute on function public.publish_class_post(uuid,uuid,text,text,text,boolean,text),public.comment_on_class_post(uuid,uuid,text,text),public.send_class_learner_message(uuid,uuid,text,text) to authenticated;
