-- Raahi Learning V1.2 — Learning Request authority, lifecycle, privacy and public projection

create or replace function app_private.learner_decision_account_id(p_learner_id uuid)
returns uuid language sql stable security definer set search_path='' as $$
  select coalesce(
    (select account_id from public.account_learner_access where learner_id=p_learner_id and access_type='manage' and status='active' limit 1),
    (select account_id from public.account_learner_access where learner_id=p_learner_id and access_type='self' and status='active' limit 1)
  );
$$;

-- Read access to formal relationship history follows the current formal learner-side
-- authority but permits a paused Account to retain legitimate existing history.
-- It intentionally does not give the Learner self Account access while an active
-- manager owns the formal relationship boundary.
create or replace function app_private.can_read_learner_relationship(p_learner_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select app_private.has_account_capability('platform_admin') or exists(
    select 1 from public.accounts a
    where a.id=app_private.current_account_id()
      and a.lifecycle_status<>'closed'
      and a.id=app_private.learner_decision_account_id(p_learner_id)
  );
$$;

create or replace function app_private.public_request_text_safe(p_text text)
returns boolean language sql immutable set search_path='' as $$
  select p_text is null or (
    p_text !~* '[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}'
    and p_text !~* '(^|[^0-9])([+]91[- ]?)?[6-9][0-9]{9}([^0-9]|$)'
    and p_text !~* '(https?://|www\.)'
  );
$$;

create or replace function app_private.learning_request_publicly_visible(p_request_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1
    from public.learning_requests r
    join public.locations l on l.id=r.location_id and l.state='live'
    join public.accounts a on a.id=app_private.learner_decision_account_id(r.learner_id) and a.lifecycle_status='active'
    where r.id=p_request_id and r.state='open'
      and not app_private.has_active_account_restriction(a.id,'public_discovery',r.location_id)
      and not app_private.has_active_account_restriction(a.id,'new_enquiries',r.location_id)
  );
$$;

create or replace function app_private.cmd_post_learning_request(
  p_learner_id uuid,p_location_id uuid,p_need_text text,p_category text,p_mode_preference text,
  p_details text,p_timing_preference text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_request uuid; v_result jsonb;
begin
  if not app_private.can_make_learning_decision(p_learner_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if p_need_text is null or char_length(btrim(p_need_text)) not between 1 and 500 then raise exception 'INVALID_LEARNING_NEED'; end if;
  if p_mode_preference is not null and p_mode_preference not in ('online','in_person','either') then raise exception 'INVALID_MODE_PREFERENCE'; end if;
  if not app_private.public_request_text_safe(p_need_text) or not app_private.public_request_text_safe(p_category) or not app_private.public_request_text_safe(p_timing_preference) then
    raise exception 'PUBLIC_REQUEST_CONTACT_DATA_NOT_ALLOWED';
  end if;
  if not exists(select 1 from public.locations where id=p_location_id and state='live') then raise exception 'LOCATION_NOT_LIVE'; end if;
  if app_private.has_active_account_restriction(v_actor,'public_discovery',p_location_id)
     or app_private.has_active_account_restriction(v_actor,'new_enquiries',p_location_id) then raise exception 'ACCOUNT_RESTRICTED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('learner_id',p_learner_id,'location_id',p_location_id,'need_text',p_need_text,
    'category',p_category,'mode_preference',p_mode_preference,'details',p_details,'timing_preference',p_timing_preference));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'post_learning_request',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if exists(select 1 from public.learning_requests where learner_id=p_learner_id and location_id=p_location_id and state='open' and lower(btrim(need_text))=lower(btrim(p_need_text))) then
    raise exception 'DUPLICATE_OPEN_LEARNING_REQUEST';
  end if;
  insert into public.learning_requests(learner_id,created_by_account_id,location_id,need_text,category,mode_preference,details,timing_preference,state)
  values(p_learner_id,v_actor,p_location_id,btrim(p_need_text),nullif(btrim(p_category),''),p_mode_preference,nullif(btrim(p_details),''),nullif(btrim(p_timing_preference),''),'open')
  returning id into v_request;
  perform app_private.write_audit(v_actor,'learning_request.post','learning_request',v_request,p_learner_id,null,jsonb_build_object('location_id',p_location_id));
  v_result:=jsonb_build_object('learning_request_id',v_request,'state','open');
  perform app_private.complete_human_idempotent_command(v_actor,'post_learning_request',p_idempotency_key,v_result);
  return v_result;
end; $$;

create or replace function app_private.cmd_update_learning_request(
  p_request_id uuid,p_need_text text,p_category text,p_mode_preference text,p_details text,p_timing_preference text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_learner uuid; v_location uuid; v_state text; v_old_need text; v_old_category text; v_result jsonb;
begin
  select learner_id,location_id,state,need_text,category into v_learner,v_location,v_state,v_old_need,v_old_category
  from public.learning_requests where id=p_request_id for update;
  if not found then raise exception 'LEARNING_REQUEST_NOT_FOUND'; end if;
  if not app_private.can_make_learning_decision(v_learner) then raise exception 'NOT_AUTHORIZED'; end if;
  if v_state='closed' then raise exception 'LEARNING_REQUEST_CLOSED'; end if;
  if p_need_text is null or char_length(btrim(p_need_text)) not between 1 and 500 then raise exception 'INVALID_LEARNING_NEED'; end if;
  if p_mode_preference is not null and p_mode_preference not in ('online','in_person','either') then raise exception 'INVALID_MODE_PREFERENCE'; end if;
  if not app_private.public_request_text_safe(p_need_text) or not app_private.public_request_text_safe(p_category) or not app_private.public_request_text_safe(p_timing_preference) then raise exception 'PUBLIC_REQUEST_CONTACT_DATA_NOT_ALLOWED'; end if;
  if v_state='open' and (lower(btrim(p_need_text))<>lower(btrim(v_old_need)) or coalesce(lower(btrim(p_category)),'')<>coalesce(lower(btrim(v_old_category)),'')) then
    raise exception 'MATERIAL_CHANGE_REQUIRES_NEW_REQUEST';
  end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('request_id',p_request_id,'need_text',p_need_text,'category',p_category,
    'mode_preference',p_mode_preference,'details',p_details,'timing_preference',p_timing_preference));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'update_learning_request',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  update public.learning_requests set need_text=btrim(p_need_text),category=nullif(btrim(p_category),''),mode_preference=p_mode_preference,
    details=nullif(btrim(p_details),''),timing_preference=nullif(btrim(p_timing_preference),'') where id=p_request_id;
  v_result:=jsonb_build_object('learning_request_id',p_request_id,'state',v_state,'updated',true);
  perform app_private.complete_human_idempotent_command(v_actor,'update_learning_request',p_idempotency_key,v_result);
  return v_result;
end; $$;

create or replace function app_private.cmd_close_learning_request(p_request_id uuid,p_close_reason text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_learner uuid; v_state text; v_result jsonb;
begin
  if p_close_reason not in ('found','no_longer_looking','plans_changed','other') then raise exception 'INVALID_CLOSE_REASON'; end if;
  select learner_id,state into v_learner,v_state from public.learning_requests where id=p_request_id for update;
  if not found then raise exception 'LEARNING_REQUEST_NOT_FOUND'; end if;
  if not app_private.can_make_learning_decision(v_learner) then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('request_id',p_request_id,'close_reason',p_close_reason));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'close_learning_request',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if v_state='closed' then
    v_result:=jsonb_build_object('learning_request_id',p_request_id,'state','closed','already_closed',true);
  elsif v_state<>'open' then raise exception 'LEARNING_REQUEST_NOT_OPEN';
  else
    update public.learning_requests set state='closed',close_reason=p_close_reason,closed_at=now() where id=p_request_id;
    v_result:=jsonb_build_object('learning_request_id',p_request_id,'state','closed','already_closed',false);
  end if;
  perform app_private.complete_human_idempotent_command(v_actor,'close_learning_request',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_reopen_learning_request(p_request_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_learner uuid; v_location uuid; v_need text; v_state text; v_result jsonb;
begin
  select learner_id,location_id,need_text,state into v_learner,v_location,v_need,v_state from public.learning_requests where id=p_request_id for update;
  if not found then raise exception 'LEARNING_REQUEST_NOT_FOUND'; end if;
  if not app_private.can_make_learning_decision(v_learner) then raise exception 'NOT_AUTHORIZED'; end if;
  if not exists(select 1 from public.locations where id=v_location and state='live') then raise exception 'LOCATION_NOT_LIVE'; end if;
  if app_private.has_active_account_restriction(v_actor,'public_discovery',v_location) or app_private.has_active_account_restriction(v_actor,'new_enquiries',v_location) then raise exception 'ACCOUNT_RESTRICTED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('request_id',p_request_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'reopen_learning_request',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if v_state='open' then v_result:=jsonb_build_object('learning_request_id',p_request_id,'state','open','already_open',true);
  elsif v_state<>'closed' then raise exception 'LEARNING_REQUEST_NOT_CLOSED';
  else
    if exists(select 1 from public.learning_requests where id<>p_request_id and learner_id=v_learner and location_id=v_location and state='open' and lower(btrim(need_text))=lower(btrim(v_need))) then raise exception 'DUPLICATE_OPEN_LEARNING_REQUEST'; end if;
    update public.learning_requests set state='open',close_reason=null,closed_at=null where id=p_request_id;
    v_result:=jsonb_build_object('learning_request_id',p_request_id,'state','open','already_open',false);
  end if;
  perform app_private.complete_human_idempotent_command(v_actor,'reopen_learning_request',p_idempotency_key,v_result); return v_result;
end; $$;

alter table public.learning_requests enable row level security;
alter table public.learning_requests force row level security;
create policy learning_requests_select_authority on public.learning_requests for select to authenticated
using(app_private.can_read_learner_relationship(learner_id) or app_private.has_account_capability('platform_admin'));
revoke all on table public.learning_requests from public,anon,authenticated,service_role;
grant select on table public.learning_requests to authenticated;
grant select,insert,update,delete on table public.learning_requests to service_role;

create or replace function app_private.discover_learning_requests(p_location_id uuid,p_query text default null)
returns setof jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('learning_request_id',r.id,'location_id',r.location_id,'location_name',l.name,
    'need_text',r.need_text,'category',r.category,'mode_preference',r.mode_preference,'timing_preference',r.timing_preference,'created_at',r.created_at)
  from public.learning_requests r join public.locations l on l.id=r.location_id
  where r.location_id=p_location_id and app_private.learning_request_publicly_visible(r.id)
    and (nullif(btrim(p_query),'') is null or r.need_text ilike '%'||btrim(p_query)||'%' or coalesce(r.category,'') ilike '%'||btrim(p_query)||'%')
  order by r.updated_at desc,r.id;
$$;

create or replace function app_private.get_learning_request_public(p_request_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('learning_request_id',r.id,'location_id',r.location_id,'location_name',l.name,
    'need_text',r.need_text,'category',r.category,'mode_preference',r.mode_preference,'timing_preference',r.timing_preference,'created_at',r.created_at)
  from public.learning_requests r join public.locations l on l.id=r.location_id
  where r.id=p_request_id and app_private.learning_request_publicly_visible(r.id);
$$;

revoke all on function app_private.learner_decision_account_id(uuid),app_private.can_read_learner_relationship(uuid),app_private.public_request_text_safe(text),app_private.learning_request_publicly_visible(uuid),
  app_private.cmd_post_learning_request(uuid,uuid,text,text,text,text,text,text),app_private.cmd_update_learning_request(uuid,text,text,text,text,text,text),
  app_private.cmd_close_learning_request(uuid,text,text),app_private.cmd_reopen_learning_request(uuid,text),
  app_private.discover_learning_requests(uuid,text),app_private.get_learning_request_public(uuid)
from public,anon,authenticated,service_role;
grant execute on function app_private.learner_decision_account_id(uuid),app_private.can_read_learner_relationship(uuid) to authenticated;
grant execute on function app_private.cmd_post_learning_request(uuid,uuid,text,text,text,text,text,text),app_private.cmd_update_learning_request(uuid,text,text,text,text,text,text),
  app_private.cmd_close_learning_request(uuid,text,text),app_private.cmd_reopen_learning_request(uuid,text),app_private.discover_learning_requests(uuid,text),app_private.get_learning_request_public(uuid) to authenticated;

create or replace function public.post_learning_request(p_learner_id uuid,p_location_id uuid,p_need_text text,p_category text,p_mode_preference text,p_details text,p_timing_preference text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_post_learning_request(p_learner_id,p_location_id,p_need_text,p_category,p_mode_preference,p_details,p_timing_preference,p_idempotency_key); $$;
create or replace function public.update_learning_request(p_request_id uuid,p_need_text text,p_category text,p_mode_preference text,p_details text,p_timing_preference text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_update_learning_request(p_request_id,p_need_text,p_category,p_mode_preference,p_details,p_timing_preference,p_idempotency_key); $$;
create or replace function public.close_learning_request(p_request_id uuid,p_close_reason text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_close_learning_request(p_request_id,p_close_reason,p_idempotency_key); $$;
create or replace function public.reopen_learning_request(p_request_id uuid,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_reopen_learning_request(p_request_id,p_idempotency_key); $$;
create or replace function public.discover_learning_requests(p_location_id uuid,p_query text default null)
returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.discover_learning_requests(p_location_id,p_query); $$;
create or replace function public.get_learning_request_public(p_request_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.get_learning_request_public(p_request_id); $$;

revoke all on function public.post_learning_request(uuid,uuid,text,text,text,text,text,text),public.update_learning_request(uuid,text,text,text,text,text,text),
  public.close_learning_request(uuid,text,text),public.reopen_learning_request(uuid,text),public.discover_learning_requests(uuid,text),public.get_learning_request_public(uuid)
from public,anon,authenticated,service_role;
grant execute on function public.post_learning_request(uuid,uuid,text,text,text,text,text,text),public.update_learning_request(uuid,text,text,text,text,text,text),
  public.close_learning_request(uuid,text,text),public.reopen_learning_request(uuid,text),public.discover_learning_requests(uuid,text),public.get_learning_request_public(uuid)
to authenticated;
