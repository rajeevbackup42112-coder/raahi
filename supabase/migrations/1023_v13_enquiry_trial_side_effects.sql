-- Raahi Learning V1.3 — Enquiry / Trial side-effect closure (SE-01, SE-02A, SE-02B)
-- Domain state and authority remain unchanged. Notifications are derived/best-effort.
-- Reschedule/cancel audit records are authoritative history side effects.

create or replace function app_private.notify_enquiry_opposite_accounts(
  p_enquiry_id uuid,
  p_actor_account_id uuid,
  p_notification_type text,
  p_source_type text,
  p_source_id uuid,
  p_title text,
  p_body text,
  p_payload jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare
  v_learner uuid;
  v_provider_account uuid;
  v_provider_org uuid;
  v_actor_on_learner_side boolean:=false;
  v_actor_on_provider_side boolean:=false;
  v_count integer:=0;
begin
  select learner_id,provider_account_id,provider_organization_id
  into v_learner,v_provider_account,v_provider_org
  from public.enquiries
  where id=p_enquiry_id;

  if not found then return 0; end if;

  if p_actor_account_id is not null then
    select exists(
      select 1
      from public.account_learner_access ala
      where ala.learner_id=v_learner
        and ala.account_id=p_actor_account_id
        and ala.status='active'
    ) into v_actor_on_learner_side;

    v_actor_on_provider_side :=
      (v_provider_account is not null and v_provider_account=p_actor_account_id)
      or
      (
        v_provider_org is not null
        and exists(
          select 1
          from public.organization_members om
          join public.organization_member_capabilities c on c.organization_member_id=om.id
          where om.organization_id=v_provider_org
            and om.account_id=p_actor_account_id
            and om.status='active'
            and c.capability_code='manage_teaching_options'
        )
      );
  end if;

  if v_actor_on_learner_side then
    return app_private.notify_enquiry_provider_accounts(
      p_enquiry_id,p_actor_account_id,p_notification_type,p_source_type,p_source_id,
      p_title,p_body,p_payload
    );
  end if;

  if v_actor_on_provider_side then
    return app_private.notify_learner_decision_account(
      v_learner,p_actor_account_id,p_notification_type,p_source_type,p_source_id,
      p_title,p_body,p_payload
    );
  end if;

  -- System/platform intervention is not one of the two business sides.
  -- Notify both currently authorized sides, excluding the acting Account if present.
  v_count:=v_count+app_private.notify_learner_decision_account(
    v_learner,p_actor_account_id,p_notification_type,p_source_type,p_source_id,
    p_title,p_body,p_payload
  );
  v_count:=v_count+app_private.notify_enquiry_provider_accounts(
    p_enquiry_id,p_actor_account_id,p_notification_type,p_source_type,p_source_id,
    p_title,p_body,p_payload
  );
  return v_count;
end;
$$;

create or replace function app_private.trg_notify_enquiry_state_update()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.current_account_id();
  v_type text;
  v_title text;
  v_body text;
begin
  if old.state='pending' and new.state='active' then
    if new.source_type in ('direct','sponsored') then
      perform app_private.notify_learner_decision_account(
        new.learner_id,v_actor,'enquiry_engaged','enquiry',new.id,
        'Your Enquiry was accepted','The teacher or learning provider accepted your Enquiry.',
        jsonb_build_object('enquiry_id',new.id)
      );
    elsif new.source_type='learning_request' then
      perform app_private.notify_enquiry_provider_accounts(
        new.id,v_actor,'learning_request_interest_accepted','enquiry',new.id,
        'Your interest was accepted','The learner side accepted your interest in the Learning Request.',
        jsonb_build_object('enquiry_id',new.id)
      );
    end if;
  elsif old.state is distinct from 'closed' and new.state='closed' then
    if new.close_reason='declined' then
      v_type:='enquiry_declined';
      v_title:='Enquiry declined';
      v_body:='The other side declined this Enquiry.';
    else
      v_type:='enquiry_closed';
      v_title:='Enquiry closed';
      v_body:='The other side closed this Enquiry.';
    end if;

    perform app_private.notify_enquiry_opposite_accounts(
      new.id,v_actor,v_type,'enquiry',new.id,v_title,v_body,
      jsonb_build_object('enquiry_id',new.id,'state','closed')
    );
  end if;
  return new;
end;
$$;

create or replace function app_private.trg_notify_trial_insert()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  perform app_private.notify_enquiry_opposite_accounts(
    new.enquiry_id,new.proposed_by_account_id,'trial_scheduled','trial_event',new.id,
    'Trial scheduled',
    'A Trial has been scheduled for ' || to_char(new.scheduled_at at time zone 'UTC','YYYY-MM-DD HH24:MI') || ' UTC.',
    jsonb_build_object(
      'enquiry_id',new.enquiry_id,
      'trial_event_id',new.id,
      'scheduled_at',new.scheduled_at
    )
  );
  return new;
end;
$$;

create or replace function app_private.trg_notify_trial_update()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_actor uuid:=app_private.current_account_id();
begin
  if old.status is distinct from 'cancelled' and new.status='cancelled' then
    perform app_private.notify_enquiry_opposite_accounts(
      new.enquiry_id,v_actor,'trial_cancelled','trial_event',new.id,
      'Trial cancelled','A scheduled Trial was cancelled.',
      jsonb_build_object('enquiry_id',new.enquiry_id,'trial_event_id',new.id,'status','cancelled')
    );
  elsif old.scheduled_at is distinct from new.scheduled_at and new.status='scheduled' then
    perform app_private.notify_enquiry_opposite_accounts(
      new.enquiry_id,v_actor,'trial_rescheduled','trial_event',new.id,
      'Trial rescheduled',
      'The Trial was rescheduled for ' || to_char(new.scheduled_at at time zone 'UTC','YYYY-MM-DD HH24:MI') || ' UTC.',
      jsonb_build_object(
        'enquiry_id',new.enquiry_id,
        'trial_event_id',new.id,
        'scheduled_at',new.scheduled_at
      )
    );
  end if;
  return new;
end;
$$;

create or replace function app_private.cmd_reschedule_trial_event(
  p_trial_event_id uuid,
  p_scheduled_at timestamptz,
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
  v_enquiry uuid;
  v_status text;
  v_result jsonb;
begin
  if p_scheduled_at is null or p_scheduled_at<=now() then raise exception 'TRIAL_TIME_MUST_BE_FUTURE'; end if;
  select enquiry_id,status into v_enquiry,v_status
  from public.enquiry_trial_events
  where id=p_trial_event_id
  for update;
  if not found then raise exception 'TRIAL_EVENT_NOT_FOUND'; end if;
  if not app_private.can_read_enquiry(v_enquiry) then raise exception 'NOT_AUTHORIZED'; end if;
  if app_private.enquiry_scope_blocked(v_enquiry,'messaging') then raise exception 'MESSAGING_RESTRICTED'; end if;
  if v_status not in ('proposed','scheduled') then raise exception 'TRIAL_EVENT_NOT_RESCHEDULABLE'; end if;

  v_fp:=app_private.request_fingerprint(jsonb_build_object('trial_event_id',p_trial_event_id,'scheduled_at',p_scheduled_at));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'reschedule_trial_event',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  update public.enquiry_trial_events
  set scheduled_at=p_scheduled_at,status='scheduled'
  where id=p_trial_event_id;

  perform app_private.write_audit(
    v_actor,'trial.reschedule','enquiry_trial_event',p_trial_event_id,null,null,
    jsonb_build_object('enquiry_id',v_enquiry,'scheduled_at',p_scheduled_at)
  );

  v_result:=jsonb_build_object(
    'trial_event_id',p_trial_event_id,'status','scheduled','scheduled_at',p_scheduled_at
  );
  perform app_private.complete_human_idempotent_command(
    v_actor,'reschedule_trial_event',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.cmd_cancel_trial_event(
  p_trial_event_id uuid,
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
  v_enquiry uuid;
  v_status text;
  v_result jsonb;
  v_did_cancel boolean:=false;
begin
  select enquiry_id,status into v_enquiry,v_status
  from public.enquiry_trial_events
  where id=p_trial_event_id
  for update;
  if not found then raise exception 'TRIAL_EVENT_NOT_FOUND'; end if;
  if not app_private.can_read_enquiry(v_enquiry) then raise exception 'NOT_AUTHORIZED'; end if;

  v_fp:=app_private.request_fingerprint(jsonb_build_object('trial_event_id',p_trial_event_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'cancel_trial_event',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  if v_status='cancelled' then
    v_result:=jsonb_build_object('trial_event_id',p_trial_event_id,'status','cancelled','already_cancelled',true);
  elsif v_status='completed' then
    raise exception 'TRIAL_EVENT_ALREADY_COMPLETED';
  else
    update public.enquiry_trial_events set status='cancelled' where id=p_trial_event_id;
    v_did_cancel:=true;
    v_result:=jsonb_build_object('trial_event_id',p_trial_event_id,'status','cancelled','already_cancelled',false);
  end if;

  if v_did_cancel then
    perform app_private.write_audit(
      v_actor,'trial.cancel','enquiry_trial_event',p_trial_event_id,null,null,
      jsonb_build_object('enquiry_id',v_enquiry)
    );
  end if;

  perform app_private.complete_human_idempotent_command(
    v_actor,'cancel_trial_event',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;

drop trigger if exists notify_trial_insert on public.enquiry_trial_events;
create trigger notify_trial_insert
after insert on public.enquiry_trial_events
for each row execute function app_private.trg_notify_trial_insert();

drop trigger if exists notify_trial_update on public.enquiry_trial_events;
create trigger notify_trial_update
after update of scheduled_at,status on public.enquiry_trial_events
for each row execute function app_private.trg_notify_trial_update();

revoke all on function app_private.notify_enquiry_opposite_accounts(uuid,uuid,text,text,uuid,text,text,jsonb)
from public,anon,authenticated,service_role;
revoke all on function app_private.trg_notify_enquiry_state_update()
from public,anon,authenticated,service_role;
revoke all on function app_private.trg_notify_trial_insert()
from public,anon,authenticated,service_role;
revoke all on function app_private.trg_notify_trial_update()
from public,anon,authenticated,service_role;
