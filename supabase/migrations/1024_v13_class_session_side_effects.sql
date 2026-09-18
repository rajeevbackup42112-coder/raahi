-- Raahi Learning V1.3 — Class Session side-effect closure (SE-03A, SE-03B)
-- Domain state/authority remain unchanged. Notifications are best-effort derived records.
-- Session actor history is written by the canonical commands.

create or replace function app_private.trg_notify_class_session_insert()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_actor uuid:=app_private.current_account_id();
begin
  perform app_private.notify_active_class_learner_accounts(
    new.class_id,
    v_actor,
    'class_session_scheduled',
    'class_session',
    new.id,
    'Class session scheduled',
    'A Class session is scheduled for ' ||
      to_char(new.starts_at at time zone 'UTC','YYYY-MM-DD HH24:MI') || ' UTC.',
    jsonb_build_object(
      'class_id',new.class_id,
      'session_id',new.id,
      'starts_at',new.starts_at,
      'ends_at',new.ends_at,
      'delivery_mode',new.delivery_mode
    )
  );
  return new;
end;
$$;

create or replace function app_private.trg_notify_class_session_update()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_actor uuid:=app_private.current_account_id();
begin
  if old.cancelled_at is null and new.cancelled_at is not null then
    perform app_private.notify_active_class_learner_accounts(
      new.class_id,
      v_actor,
      'class_session_cancelled',
      'class_session',
      new.id,
      'Class session cancelled',
      'A scheduled Class session was cancelled.',
      jsonb_build_object(
        'class_id',new.class_id,
        'session_id',new.id,
        'cancelled_at',new.cancelled_at
      )
    );
  end if;
  return new;
end;
$$;

create or replace function app_private.cmd_schedule_class_session(
  p_class_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_delivery_mode text,
  p_meeting_or_location_text text,
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
  v_session uuid;
  v_result jsonb;
begin
  if not app_private.can_manage_class(p_class_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if not exists(select 1 from public.classes where id=p_class_id and state='active') then raise exception 'CLASS_NOT_ACTIVE'; end if;
  if p_starts_at is null or p_starts_at<=now() then raise exception 'SESSION_START_MUST_BE_FUTURE'; end if;
  if p_ends_at is not null and p_ends_at<=p_starts_at then raise exception 'INVALID_SESSION_END'; end if;
  if p_delivery_mode not in ('online','in_person') then raise exception 'INVALID_DELIVERY_MODE'; end if;

  v_fp:=app_private.request_fingerprint(jsonb_build_object(
    'class_id',p_class_id,
    'starts_at',p_starts_at,
    'ends_at',p_ends_at,
    'delivery_mode',p_delivery_mode,
    'meeting_or_location_text',p_meeting_or_location_text
  ));
  v_gate:=app_private.begin_human_idempotent_command(
    v_actor,'schedule_class_session',p_idempotency_key,v_fp
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  insert into public.class_sessions(
    class_id,starts_at,ends_at,delivery_mode,meeting_or_location_text
  )
  values(
    p_class_id,p_starts_at,p_ends_at,p_delivery_mode,nullif(btrim(p_meeting_or_location_text),'')
  )
  returning id into v_session;

  perform app_private.write_audit(
    v_actor,'class_session.schedule','class_session',v_session,null,null,
    jsonb_build_object(
      'class_id',p_class_id,
      'starts_at',p_starts_at,
      'ends_at',p_ends_at,
      'delivery_mode',p_delivery_mode
    )
  );

  v_result:=jsonb_build_object('session_id',v_session,'class_id',p_class_id);
  perform app_private.complete_human_idempotent_command(
    v_actor,'schedule_class_session',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.cmd_cancel_class_session(
  p_session_id uuid,
  p_reason text,
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
  v_class uuid;
  v_cancelled timestamptz;
  v_result jsonb;
  v_did_cancel boolean:=false;
begin
  select class_id,cancelled_at into v_class,v_cancelled
  from public.class_sessions
  where id=p_session_id
  for update;
  if not found then raise exception 'SESSION_NOT_FOUND'; end if;
  if not app_private.can_manage_class(v_class) then raise exception 'NOT_AUTHORIZED'; end if;
  if p_reason is null or btrim(p_reason)='' then raise exception 'CANCEL_REASON_REQUIRED'; end if;

  v_fp:=app_private.request_fingerprint(jsonb_build_object(
    'session_id',p_session_id,'reason',p_reason
  ));
  v_gate:=app_private.begin_human_idempotent_command(
    v_actor,'cancel_class_session',p_idempotency_key,v_fp
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  if v_cancelled is null then
    update public.class_sessions
    set cancelled_at=now(),cancel_reason=btrim(p_reason)
    where id=p_session_id;
    v_did_cancel:=true;
  end if;

  if v_did_cancel then
    perform app_private.write_audit(
      v_actor,'class_session.cancel','class_session',p_session_id,null,btrim(p_reason),
      jsonb_build_object('class_id',v_class)
    );
  end if;

  v_result:=jsonb_build_object(
    'session_id',p_session_id,
    'cancelled',true,
    'already_cancelled',v_cancelled is not null
  );
  perform app_private.complete_human_idempotent_command(
    v_actor,'cancel_class_session',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;

drop trigger if exists notify_class_session_insert on public.class_sessions;
create trigger notify_class_session_insert
after insert on public.class_sessions
for each row execute function app_private.trg_notify_class_session_insert();

drop trigger if exists notify_class_session_update on public.class_sessions;
create trigger notify_class_session_update
after update of cancelled_at on public.class_sessions
for each row execute function app_private.trg_notify_class_session_update();

revoke all on function app_private.trg_notify_class_session_insert()
from public,anon,authenticated,service_role;
revoke all on function app_private.trg_notify_class_session_update()
from public,anon,authenticated,service_role;
