-- Raahi Learning V1.2 — Enquiry relationship boundary, contextual messaging and optional Trial

create or replace function app_private.has_provider_authority(p_provider_account_id uuid,p_provider_organization_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_actor uuid:=app_private.current_account_id();
begin
  if v_actor is null then return false; end if;
  if app_private.has_account_capability('platform_admin') then return true; end if;
  if p_provider_account_id is not null then
    return p_provider_account_id=v_actor and app_private.has_account_capability('teach')
      and exists(select 1 from public.accounts where id=v_actor and lifecycle_status='active');
  end if;
  if p_provider_organization_id is not null then
    return app_private.has_organization_member_capability(p_provider_organization_id,'manage_teaching_options');
  end if;
  return false;
end; $$;

create or replace function app_private.enquiry_scope_blocked(p_enquiry_id uuid,p_scope text)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_learner uuid; v_location uuid; v_provider_account uuid; v_provider_org uuid; v_learner_account uuid;
begin
  select learner_id,location_id,provider_account_id,provider_organization_id
  into v_learner,v_location,v_provider_account,v_provider_org
  from public.enquiries where id=p_enquiry_id;
  if not found then return true; end if;
  v_learner_account:=app_private.learner_decision_account_id(v_learner);
  if v_learner_account is not null and app_private.has_active_account_restriction(v_learner_account,p_scope,v_location) then return true; end if;
  if v_provider_account is not null and app_private.has_active_account_restriction(v_provider_account,p_scope,v_location) then return true; end if;
  if v_provider_org is not null and app_private.has_active_organization_restriction(v_provider_org,p_scope,v_location) then return true; end if;
  return false;
end; $$;

create or replace function app_private.can_read_enquiry(p_enquiry_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_learner uuid; v_provider_account uuid; v_provider_org uuid;
begin
  select learner_id,provider_account_id,provider_organization_id into v_learner,v_provider_account,v_provider_org
  from public.enquiries where id=p_enquiry_id;
  if not found then return false; end if;
  if app_private.has_account_capability('platform_admin') then return true; end if;
  if app_private.can_make_learning_decision(v_learner) then return true; end if;
  return app_private.has_provider_authority(v_provider_account,v_provider_org);
end; $$;

create or replace function app_private.is_enquiry_receiving_side(p_enquiry_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_source text; v_learner uuid; v_provider_account uuid; v_provider_org uuid;
begin
  select source_type,learner_id,provider_account_id,provider_organization_id into v_source,v_learner,v_provider_account,v_provider_org
  from public.enquiries where id=p_enquiry_id;
  if not found then return false; end if;
  if v_source in ('direct','sponsored') then return app_private.has_provider_authority(v_provider_account,v_provider_org); end if;
  if v_source='learning_request' then return app_private.can_make_learning_decision(v_learner); end if;
  return false;
end; $$;

create or replace function app_private.cmd_send_enquiry(
  p_learner_id uuid,p_teaching_option_id uuid,p_location_id uuid,p_opening_message text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_provider_account uuid; v_provider_org uuid; v_availability text; v_enquiry uuid; v_result jsonb;
begin
  if not app_private.can_make_learning_decision(p_learner_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if not exists(select 1 from public.locations where id=p_location_id and state='live') then raise exception 'LOCATION_NOT_LIVE'; end if;
  select teacher_account_id,organization_id,availability_status into v_provider_account,v_provider_org,v_availability
  from public.teaching_options where id=p_teaching_option_id;
  if not found then raise exception 'TEACHING_OPTION_NOT_FOUND'; end if;
  if v_availability<>'taking_new_learners' then raise exception 'TEACHING_OPTION_NOT_TAKING_LEARNERS'; end if;
  if not exists(select 1 from public.teaching_option_locations where teaching_option_id=p_teaching_option_id and location_id=p_location_id) then raise exception 'TEACHING_OPTION_NOT_IN_LOCATION'; end if;
  if v_provider_account is not null then
    if not exists(select 1 from public.teacher_profiles tp join public.accounts a on a.id=tp.account_id where tp.account_id=v_provider_account and tp.visibility_status='visible' and a.lifecycle_status='active') then raise exception 'PROVIDER_NOT_PUBLIC'; end if;
    if app_private.has_active_account_restriction(v_provider_account,'public_discovery',p_location_id) or app_private.has_active_account_restriction(v_provider_account,'new_enquiries',p_location_id) then raise exception 'PROVIDER_RESTRICTED'; end if;
  else
    if not exists(select 1 from public.organizations where id=v_provider_org and status='active') then raise exception 'PROVIDER_NOT_PUBLIC'; end if;
    if app_private.has_active_organization_restriction(v_provider_org,'public_discovery',p_location_id) or app_private.has_active_organization_restriction(v_provider_org,'new_enquiries',p_location_id) then raise exception 'PROVIDER_RESTRICTED'; end if;
  end if;
  if app_private.has_active_account_restriction(v_actor,'new_enquiries',p_location_id) then raise exception 'ACCOUNT_RESTRICTED'; end if;
  if nullif(btrim(p_opening_message),'') is not null and (
       app_private.has_active_account_restriction(v_actor,'messaging',p_location_id)
       or (v_provider_account is not null and app_private.has_active_account_restriction(v_provider_account,'messaging',p_location_id))
       or (v_provider_org is not null and app_private.has_active_organization_restriction(v_provider_org,'messaging',p_location_id))
     ) then raise exception 'MESSAGING_RESTRICTED'; end if;
  if p_opening_message is not null and char_length(p_opening_message)>8000 then raise exception 'MESSAGE_TOO_LONG'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('learner_id',p_learner_id,'teaching_option_id',p_teaching_option_id,'location_id',p_location_id,'opening_message',p_opening_message));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'send_enquiry',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if exists(select 1 from public.enquiries where learner_id=p_learner_id and teaching_option_id=p_teaching_option_id and source_type in ('direct','sponsored') and state in ('pending','active')) then raise exception 'DUPLICATE_ACTIVE_ENQUIRY'; end if;
  insert into public.enquiries(learner_id,created_by_account_id,location_id,provider_account_id,provider_organization_id,teaching_option_id,source_type,state)
  values(p_learner_id,v_actor,p_location_id,v_provider_account,v_provider_org,p_teaching_option_id,'direct','pending') returning id into v_enquiry;
  if nullif(btrim(p_opening_message),'') is not null then
    insert into public.enquiry_messages(enquiry_id,sender_account_id,body,message_type) values(v_enquiry,v_actor,btrim(p_opening_message),'controlled_structured');
  end if;
  perform app_private.write_audit(v_actor,'enquiry.create','enquiry',v_enquiry,p_learner_id,null,jsonb_build_object('source_type','direct','location_id',p_location_id,'provider_account_id',v_provider_account,'provider_organization_id',v_provider_org));
  v_result:=jsonb_build_object('enquiry_id',v_enquiry,'state','pending','source_type','direct');
  perform app_private.complete_human_idempotent_command(v_actor,'send_enquiry',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_express_interest_in_request(
  p_learning_request_id uuid,p_provider_organization_id uuid,p_opening_message text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_learner uuid; v_location uuid; v_request_state text; v_provider_account uuid; v_enquiry uuid; v_result jsonb;
begin
  select learner_id,location_id,state into v_learner,v_location,v_request_state from public.learning_requests where id=p_learning_request_id for share;
  if not found then raise exception 'LEARNING_REQUEST_NOT_FOUND'; end if;
  if v_request_state<>'open' or not app_private.learning_request_publicly_visible(p_learning_request_id) then raise exception 'LEARNING_REQUEST_NOT_AVAILABLE'; end if;
  if p_provider_organization_id is null then
    v_provider_account:=v_actor;
    if not app_private.has_account_capability('teach') then raise exception 'TEACH_CAPABILITY_REQUIRED'; end if;
    if not exists(select 1 from public.teacher_profiles where account_id=v_actor and visibility_status='visible') then raise exception 'TEACHER_PROFILE_NOT_PUBLIC'; end if;
    if app_private.has_active_account_restriction(v_actor,'new_enquiries',v_location) then raise exception 'PROVIDER_RESTRICTED'; end if;
  else
    if not app_private.has_organization_member_capability(p_provider_organization_id,'manage_teaching_options') then raise exception 'NOT_AUTHORIZED'; end if;
    if not exists(select 1 from public.organizations where id=p_provider_organization_id and status='active') then raise exception 'ORGANIZATION_NOT_ACTIVE'; end if;
    if app_private.has_active_organization_restriction(p_provider_organization_id,'new_enquiries',v_location) then raise exception 'PROVIDER_RESTRICTED'; end if;
  end if;
  if nullif(btrim(p_opening_message),'') is not null and (
       (v_provider_account is not null and app_private.has_active_account_restriction(v_provider_account,'messaging',v_location))
       or (p_provider_organization_id is not null and app_private.has_active_organization_restriction(p_provider_organization_id,'messaging',v_location))
       or app_private.has_active_account_restriction(app_private.learner_decision_account_id(v_learner),'messaging',v_location)
     ) then raise exception 'MESSAGING_RESTRICTED'; end if;
  if p_opening_message is not null and char_length(p_opening_message)>8000 then raise exception 'MESSAGE_TOO_LONG'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('learning_request_id',p_learning_request_id,'provider_organization_id',p_provider_organization_id,'opening_message',p_opening_message));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'express_interest_in_request',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if (v_provider_account is not null and exists(select 1 from public.enquiries where learning_request_id=p_learning_request_id and provider_account_id=v_provider_account and source_type='learning_request' and state in ('pending','active')))
     or (p_provider_organization_id is not null and exists(select 1 from public.enquiries where learning_request_id=p_learning_request_id and provider_organization_id=p_provider_organization_id and source_type='learning_request' and state in ('pending','active'))) then raise exception 'DUPLICATE_ACTIVE_ENQUIRY'; end if;
  insert into public.enquiries(learner_id,created_by_account_id,location_id,provider_account_id,provider_organization_id,learning_request_id,source_type,state)
  values(v_learner,v_actor,v_location,v_provider_account,p_provider_organization_id,p_learning_request_id,'learning_request','pending') returning id into v_enquiry;
  if nullif(btrim(p_opening_message),'') is not null then insert into public.enquiry_messages(enquiry_id,sender_account_id,body,message_type) values(v_enquiry,v_actor,btrim(p_opening_message),'controlled_structured'); end if;
  perform app_private.write_audit(v_actor,'enquiry.create','enquiry',v_enquiry,v_learner,null,jsonb_build_object('source_type','learning_request','location_id',v_location,'provider_account_id',v_provider_account,'provider_organization_id',p_provider_organization_id));
  v_result:=jsonb_build_object('enquiry_id',v_enquiry,'state','pending','source_type','learning_request');
  perform app_private.complete_human_idempotent_command(v_actor,'express_interest_in_request',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_engage_enquiry(p_enquiry_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_state text; v_learner uuid; v_result jsonb;
begin
  select state,learner_id into v_state,v_learner from public.enquiries where id=p_enquiry_id for update;
  if not found then raise exception 'ENQUIRY_NOT_FOUND'; end if;
  if not app_private.is_enquiry_receiving_side(p_enquiry_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if app_private.enquiry_scope_blocked(p_enquiry_id,'new_enquiries') then raise exception 'ENQUIRY_RESTRICTED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('enquiry_id',p_enquiry_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'engage_enquiry',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if v_state='active' then v_result:=jsonb_build_object('enquiry_id',p_enquiry_id,'state','active','already_active',true);
  elsif v_state<>'pending' then raise exception 'ENQUIRY_NOT_PENDING';
  else update public.enquiries set state='active',activated_at=now() where id=p_enquiry_id; v_result:=jsonb_build_object('enquiry_id',p_enquiry_id,'state','active','already_active',false); end if;
  perform app_private.write_audit(v_actor,'enquiry.engage','enquiry',p_enquiry_id,v_learner);
  perform app_private.complete_human_idempotent_command(v_actor,'engage_enquiry',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_decline_enquiry(p_enquiry_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_state text; v_learner uuid; v_result jsonb;
begin
  select state,learner_id into v_state,v_learner from public.enquiries where id=p_enquiry_id for update;
  if not found then raise exception 'ENQUIRY_NOT_FOUND'; end if;
  if not app_private.is_enquiry_receiving_side(p_enquiry_id) then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('enquiry_id',p_enquiry_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'decline_enquiry',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if v_state='closed' then v_result:=jsonb_build_object('enquiry_id',p_enquiry_id,'state','closed','already_closed',true);
  elsif v_state<>'pending' then raise exception 'ENQUIRY_NOT_PENDING';
  else update public.enquiries set state='closed',close_reason='declined',closed_at=now() where id=p_enquiry_id; v_result:=jsonb_build_object('enquiry_id',p_enquiry_id,'state','closed','already_closed',false); end if;
  perform app_private.write_audit(v_actor,'enquiry.decline','enquiry',p_enquiry_id,v_learner);
  perform app_private.complete_human_idempotent_command(v_actor,'decline_enquiry',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_close_enquiry(p_enquiry_id uuid,p_close_reason text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_state text; v_learner uuid; v_creator uuid; v_result jsonb;
begin
  if p_close_reason is null or char_length(btrim(p_close_reason)) not between 1 and 120 then raise exception 'INVALID_CLOSE_REASON'; end if;
  select state,learner_id,created_by_account_id into v_state,v_learner,v_creator from public.enquiries where id=p_enquiry_id for update;
  if not found then raise exception 'ENQUIRY_NOT_FOUND'; end if;
  if not app_private.can_read_enquiry(p_enquiry_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if v_state='pending' and v_creator<>v_actor and not app_private.has_account_capability('platform_admin') then raise exception 'PENDING_ENQUIRY_SENDER_ONLY_CLOSE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('enquiry_id',p_enquiry_id,'close_reason',p_close_reason));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'close_enquiry',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if v_state='closed' then v_result:=jsonb_build_object('enquiry_id',p_enquiry_id,'state','closed','already_closed',true);
  else update public.enquiries set state='closed',close_reason=btrim(p_close_reason),closed_at=now() where id=p_enquiry_id; v_result:=jsonb_build_object('enquiry_id',p_enquiry_id,'state','closed','already_closed',false); end if;
  perform app_private.write_audit(v_actor,'enquiry.close','enquiry',p_enquiry_id,v_learner,null,jsonb_build_object('reason_code',btrim(p_close_reason)));
  perform app_private.complete_human_idempotent_command(v_actor,'close_enquiry',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_send_enquiry_message(p_enquiry_id uuid,p_body text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_state text; v_message uuid; v_result jsonb;
begin
  if p_body is null or char_length(btrim(p_body)) not between 1 and 8000 then raise exception 'INVALID_MESSAGE'; end if;
  select state into v_state from public.enquiries where id=p_enquiry_id for share;
  if not found then raise exception 'ENQUIRY_NOT_FOUND'; end if;
  if v_state<>'active' then raise exception 'ENQUIRY_NOT_ACTIVE'; end if;
  if not app_private.can_read_enquiry(p_enquiry_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if app_private.enquiry_scope_blocked(p_enquiry_id,'messaging') then raise exception 'MESSAGING_RESTRICTED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('enquiry_id',p_enquiry_id,'body',p_body));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'send_enquiry_message',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.enquiry_messages(enquiry_id,sender_account_id,body,message_type) values(p_enquiry_id,v_actor,btrim(p_body),'text') returning id into v_message;
  v_result:=jsonb_build_object('message_id',v_message,'enquiry_id',p_enquiry_id);
  perform app_private.complete_human_idempotent_command(v_actor,'send_enquiry_message',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_schedule_trial_event(p_enquiry_id uuid,p_scheduled_at timestamptz,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_state text; v_event uuid; v_result jsonb;
begin
  if p_scheduled_at is null or p_scheduled_at<=now() then raise exception 'TRIAL_TIME_MUST_BE_FUTURE'; end if;
  select state into v_state from public.enquiries where id=p_enquiry_id for share;
  if not found then raise exception 'ENQUIRY_NOT_FOUND'; end if;
  if v_state<>'active' then raise exception 'ENQUIRY_NOT_ACTIVE'; end if;
  if not app_private.can_read_enquiry(p_enquiry_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if app_private.enquiry_scope_blocked(p_enquiry_id,'messaging') then raise exception 'MESSAGING_RESTRICTED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('enquiry_id',p_enquiry_id,'scheduled_at',p_scheduled_at));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'schedule_trial_event',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.enquiry_trial_events(enquiry_id,proposed_by_account_id,scheduled_at,status) values(p_enquiry_id,v_actor,p_scheduled_at,'scheduled') returning id into v_event;
  v_result:=jsonb_build_object('trial_event_id',v_event,'status','scheduled','scheduled_at',p_scheduled_at);
  perform app_private.complete_human_idempotent_command(v_actor,'schedule_trial_event',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_reschedule_trial_event(p_trial_event_id uuid,p_scheduled_at timestamptz,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_enquiry uuid; v_status text; v_result jsonb;
begin
  if p_scheduled_at is null or p_scheduled_at<=now() then raise exception 'TRIAL_TIME_MUST_BE_FUTURE'; end if;
  select enquiry_id,status into v_enquiry,v_status from public.enquiry_trial_events where id=p_trial_event_id for update;
  if not found then raise exception 'TRIAL_EVENT_NOT_FOUND'; end if;
  if not app_private.can_read_enquiry(v_enquiry) then raise exception 'NOT_AUTHORIZED'; end if;
  if app_private.enquiry_scope_blocked(v_enquiry,'messaging') then raise exception 'MESSAGING_RESTRICTED'; end if;
  if v_status not in ('proposed','scheduled') then raise exception 'TRIAL_EVENT_NOT_RESCHEDULABLE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('trial_event_id',p_trial_event_id,'scheduled_at',p_scheduled_at));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'reschedule_trial_event',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  update public.enquiry_trial_events set scheduled_at=p_scheduled_at,status='scheduled' where id=p_trial_event_id;
  v_result:=jsonb_build_object('trial_event_id',p_trial_event_id,'status','scheduled','scheduled_at',p_scheduled_at);
  perform app_private.complete_human_idempotent_command(v_actor,'reschedule_trial_event',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_cancel_trial_event(p_trial_event_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_enquiry uuid; v_status text; v_result jsonb;
begin
  select enquiry_id,status into v_enquiry,v_status from public.enquiry_trial_events where id=p_trial_event_id for update;
  if not found then raise exception 'TRIAL_EVENT_NOT_FOUND'; end if;
  if not app_private.can_read_enquiry(v_enquiry) then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('trial_event_id',p_trial_event_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'cancel_trial_event',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if v_status='cancelled' then v_result:=jsonb_build_object('trial_event_id',p_trial_event_id,'status','cancelled','already_cancelled',true);
  elsif v_status='completed' then raise exception 'TRIAL_EVENT_ALREADY_COMPLETED';
  else update public.enquiry_trial_events set status='cancelled' where id=p_trial_event_id; v_result:=jsonb_build_object('trial_event_id',p_trial_event_id,'status','cancelled','already_cancelled',false); end if;
  perform app_private.complete_human_idempotent_command(v_actor,'cancel_trial_event',p_idempotency_key,v_result); return v_result;
end; $$;

alter table public.enquiries enable row level security; alter table public.enquiries force row level security;
alter table public.enquiry_messages enable row level security; alter table public.enquiry_messages force row level security;
alter table public.enquiry_trial_events enable row level security; alter table public.enquiry_trial_events force row level security;
create policy enquiries_select_participant on public.enquiries for select to authenticated using(app_private.can_read_enquiry(id));
create policy enquiry_messages_select_participant on public.enquiry_messages for select to authenticated using(app_private.can_read_enquiry(enquiry_id));
create policy enquiry_trials_select_participant on public.enquiry_trial_events for select to authenticated using(app_private.can_read_enquiry(enquiry_id));
revoke all on table public.enquiries,public.enquiry_messages,public.enquiry_trial_events from public,anon,authenticated,service_role;
grant select on table public.enquiries,public.enquiry_messages,public.enquiry_trial_events to authenticated;
grant select,insert,update,delete on table public.enquiries,public.enquiry_messages,public.enquiry_trial_events to service_role;

revoke all on function app_private.has_provider_authority(uuid,uuid),app_private.enquiry_scope_blocked(uuid,text),app_private.can_read_enquiry(uuid),app_private.is_enquiry_receiving_side(uuid),
  app_private.cmd_send_enquiry(uuid,uuid,uuid,text,text),app_private.cmd_express_interest_in_request(uuid,uuid,text,text),app_private.cmd_engage_enquiry(uuid,text),
  app_private.cmd_decline_enquiry(uuid,text),app_private.cmd_close_enquiry(uuid,text,text),app_private.cmd_send_enquiry_message(uuid,text,text),
  app_private.cmd_schedule_trial_event(uuid,timestamptz,text),app_private.cmd_reschedule_trial_event(uuid,timestamptz,text),app_private.cmd_cancel_trial_event(uuid,text)
from public,anon,authenticated,service_role;
grant execute on function app_private.has_provider_authority(uuid,uuid),app_private.enquiry_scope_blocked(uuid,text),app_private.can_read_enquiry(uuid),app_private.is_enquiry_receiving_side(uuid) to authenticated;
grant execute on function app_private.cmd_send_enquiry(uuid,uuid,uuid,text,text),app_private.cmd_express_interest_in_request(uuid,uuid,text,text),app_private.cmd_engage_enquiry(uuid,text),
  app_private.cmd_decline_enquiry(uuid,text),app_private.cmd_close_enquiry(uuid,text,text),app_private.cmd_send_enquiry_message(uuid,text,text),
  app_private.cmd_schedule_trial_event(uuid,timestamptz,text),app_private.cmd_reschedule_trial_event(uuid,timestamptz,text),app_private.cmd_cancel_trial_event(uuid,text) to authenticated;

create or replace function public.send_enquiry(p_learner_id uuid,p_teaching_option_id uuid,p_location_id uuid,p_opening_message text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_send_enquiry(p_learner_id,p_teaching_option_id,p_location_id,p_opening_message,p_idempotency_key); $$;
create or replace function public.express_interest_in_request(p_learning_request_id uuid,p_provider_organization_id uuid,p_opening_message text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_express_interest_in_request(p_learning_request_id,p_provider_organization_id,p_opening_message,p_idempotency_key); $$;
create or replace function public.engage_enquiry(p_enquiry_id uuid,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_engage_enquiry(p_enquiry_id,p_idempotency_key); $$;
create or replace function public.decline_enquiry(p_enquiry_id uuid,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_decline_enquiry(p_enquiry_id,p_idempotency_key); $$;
create or replace function public.close_enquiry(p_enquiry_id uuid,p_close_reason text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_close_enquiry(p_enquiry_id,p_close_reason,p_idempotency_key); $$;
create or replace function public.send_enquiry_message(p_enquiry_id uuid,p_body text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_send_enquiry_message(p_enquiry_id,p_body,p_idempotency_key); $$;
create or replace function public.schedule_trial_event(p_enquiry_id uuid,p_scheduled_at timestamptz,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_schedule_trial_event(p_enquiry_id,p_scheduled_at,p_idempotency_key); $$;
create or replace function public.reschedule_trial_event(p_trial_event_id uuid,p_scheduled_at timestamptz,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_reschedule_trial_event(p_trial_event_id,p_scheduled_at,p_idempotency_key); $$;
create or replace function public.cancel_trial_event(p_trial_event_id uuid,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_cancel_trial_event(p_trial_event_id,p_idempotency_key); $$;

revoke all on function public.send_enquiry(uuid,uuid,uuid,text,text),public.express_interest_in_request(uuid,uuid,text,text),public.engage_enquiry(uuid,text),public.decline_enquiry(uuid,text),
  public.close_enquiry(uuid,text,text),public.send_enquiry_message(uuid,text,text),public.schedule_trial_event(uuid,timestamptz,text),public.reschedule_trial_event(uuid,timestamptz,text),public.cancel_trial_event(uuid,text)
from public,anon,authenticated,service_role;
grant execute on function public.send_enquiry(uuid,uuid,uuid,text,text),public.express_interest_in_request(uuid,uuid,text,text),public.engage_enquiry(uuid,text),public.decline_enquiry(uuid,text),
  public.close_enquiry(uuid,text,text),public.send_enquiry_message(uuid,text,text),public.schedule_trial_event(uuid,timestamptz,text),public.reschedule_trial_event(uuid,timestamptz,text),public.cancel_trial_event(uuid,text)
to authenticated;
