-- Raahi Learning V1.2 — derived notifications. Notifications never own domain state.

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_account_id uuid not null references public.accounts(id),
  context_learner_id uuid null references public.learners(id),
  notification_type text not null,
  source_type text null,
  source_id uuid null,
  title text not null,
  body text null,
  payload jsonb not null default '{}'::jsonb,
  delivered_at timestamptz null,
  read_at timestamptz null,
  created_at timestamptz not null default now(),
  constraint notifications_type_nonblank check (char_length(btrim(notification_type)) between 1 and 120),
  constraint notifications_title_nonblank check (char_length(btrim(title)) between 1 and 300),
  constraint notifications_body_length check (body is null or char_length(body)<=4000),
  constraint notifications_no_sponsored_push check (notification_type !~* '^(sponsored|ad_viewer|promotion)')
);

create index notifications_recipient_time_idx on public.notifications(recipient_account_id,created_at desc);
create index notifications_recipient_unread_idx on public.notifications(recipient_account_id,created_at desc) where read_at is null;
create index notifications_context_learner_idx on public.notifications(context_learner_id,created_at desc) where context_learner_id is not null;

alter table public.notifications enable row level security;
alter table public.notifications force row level security;
create policy notifications_recipient_select on public.notifications for select to authenticated
using(recipient_account_id=app_private.current_account_id() or app_private.has_account_capability('platform_admin'));

revoke all on table public.notifications from public,anon,authenticated,service_role;
grant select on table public.notifications to authenticated;
grant select,insert,update,delete on table public.notifications to service_role;

create or replace function app_private.enqueue_notification(
  p_recipient_account_id uuid,p_context_learner_id uuid,p_notification_type text,p_source_type text,p_source_id uuid,
  p_title text,p_body text,p_payload jsonb default '{}'::jsonb
)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
  if p_notification_type is null or btrim(p_notification_type)='' then raise exception 'INVALID_NOTIFICATION_TYPE'; end if;
  if p_notification_type ~* '^(sponsored|ad_viewer|promotion)' then raise exception 'SPONSORED_PUSH_NOT_ALLOWED'; end if;
  if not exists(select 1 from public.accounts where id=p_recipient_account_id and lifecycle_status<>'closed') then raise exception 'RECIPIENT_NOT_AVAILABLE'; end if;
  if p_context_learner_id is not null and not exists(select 1 from public.account_learner_access where account_id=p_recipient_account_id and learner_id=p_context_learner_id and status='active') then raise exception 'INVALID_NOTIFICATION_LEARNER_CONTEXT'; end if;
  insert into public.notifications(recipient_account_id,context_learner_id,notification_type,source_type,source_id,title,body,payload)
  values(p_recipient_account_id,p_context_learner_id,btrim(p_notification_type),nullif(btrim(p_source_type),''),p_source_id,btrim(p_title),nullif(btrim(p_body),''),coalesce(p_payload,'{}'::jsonb))
  returning id into v_id;
  return v_id;
end; $$;

create or replace function app_private.cmd_mark_notification_read(p_notification_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(false); v_gate jsonb; v_fp text; v_read timestamptz; v_result jsonb;
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
  select read_at into v_read from public.notifications where id=p_notification_id and recipient_account_id=v_actor for update;
  if not found then raise exception 'NOTIFICATION_NOT_FOUND'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('notification_id',p_notification_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'mark_notification_read',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if v_read is null then update public.notifications set read_at=now() where id=p_notification_id returning read_at into v_read; end if;
  v_result:=jsonb_build_object('notification_id',p_notification_id,'read_at',v_read);
  perform app_private.complete_human_idempotent_command(v_actor,'mark_notification_read',p_idempotency_key,v_result);
  return v_result;
end; $$;

create or replace function app_private.get_my_notifications(p_limit integer default 50)
returns setof jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('notification_id',n.id,'context_learner_id',n.context_learner_id,'notification_type',n.notification_type,
    'source_type',n.source_type,'source_id',n.source_id,'title',n.title,'body',n.body,'payload',n.payload,'read_at',n.read_at,'created_at',n.created_at)
  from public.notifications n
  where n.recipient_account_id=app_private.current_account_id()
  order by n.created_at desc,n.id
  limit least(greatest(coalesce(p_limit,50),1),200);
$$;

revoke all on function app_private.enqueue_notification(uuid,uuid,text,text,uuid,text,text,jsonb) from public,anon,authenticated;
grant execute on function app_private.enqueue_notification(uuid,uuid,text,text,uuid,text,text,jsonb) to service_role;
revoke all on function app_private.cmd_mark_notification_read(uuid,text),app_private.get_my_notifications(integer) from public,anon,authenticated,service_role;
grant execute on function app_private.cmd_mark_notification_read(uuid,text),app_private.get_my_notifications(integer) to authenticated;

create or replace function public.mark_notification_read(p_notification_id uuid,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_mark_notification_read(p_notification_id,p_idempotency_key); $$;
create or replace function public.get_my_notifications(p_limit integer default 50)
returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.get_my_notifications(p_limit); $$;
revoke all on function public.mark_notification_read(uuid,text),public.get_my_notifications(integer) from public,anon,authenticated,service_role;
grant execute on function public.mark_notification_read(uuid,text),public.get_my_notifications(integer) to authenticated;
