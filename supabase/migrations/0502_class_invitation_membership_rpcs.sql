-- Raahi Learning V1.2 — Class lifecycle, finite-seat Invitations, Memberships,
-- Sessions, Materials and private learner-code invite integration.

create or replace function app_private.class_invitation_ttl()
returns interval language sql immutable set search_path='' as $$ select interval '7 days'; $$;

create or replace function app_private.can_manage_class(p_class_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_teacher uuid; v_org uuid; v_actor uuid:=app_private.current_account_id(); v_status text;
begin
  if v_actor is null then return false; end if;
  if app_private.has_account_capability('platform_admin') then return true; end if;
  select responsible_teacher_account_id,organization_id into v_teacher,v_org from public.classes where id=p_class_id;
  if not found then return false; end if;
  select lifecycle_status into v_status from public.accounts where id=v_actor;
  if v_status<>'active' then return false; end if;
  if v_org is null then return v_teacher=v_actor and app_private.has_account_capability('teach'); end if;
  return app_private.has_organization_member_capability(v_org,'manage_classes');
end; $$;

create or replace function app_private.class_provider_access_blocked(p_class_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_teacher uuid; v_org uuid; v_location uuid;
begin
  select responsible_teacher_account_id,organization_id,location_id into v_teacher,v_org,v_location from public.classes where id=p_class_id;
  if not found then return true; end if;
  if v_org is not null then return app_private.has_active_organization_restriction(v_org,'class_access',v_location); end if;
  return app_private.has_active_account_restriction(v_teacher,'class_access',v_location);
end; $$;

create or replace function app_private.current_actor_class_access_blocked(p_class_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_location uuid; v_actor uuid:=app_private.current_account_id();
begin
  if v_actor is null then return true; end if;
  select location_id into v_location from public.classes where id=p_class_id;
  if not found then return true; end if;
  return app_private.has_active_account_restriction(v_actor,'class_access',v_location);
end; $$;

create or replace function app_private.expire_pending_class_invitations(p_class_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare v_count integer;
begin
  update public.class_invitations
  set state='expired',resolved_at=now()
  where class_id=p_class_id and state='pending' and expires_at<=now();
  get diagnostics v_count=row_count;
  return v_count;
end; $$;

create or replace function app_private.class_reserved_occupancy(p_class_id uuid)
returns integer language sql stable security definer set search_path='' as $$
  select
    (select count(*)::int from public.class_memberships where class_id=p_class_id and state='active')
    +
    (select count(*)::int from public.class_invitations where class_id=p_class_id and state='pending' and expires_at>now());
$$;

create or replace function app_private.cmd_create_class(
  p_organization_id uuid,p_responsible_teacher_account_id uuid,p_location_id uuid,
  p_title text,p_class_type text,p_capacity integer,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_class uuid; v_result jsonb;
begin
  if p_title is null or char_length(btrim(p_title)) not between 1 and 200 then raise exception 'INVALID_CLASS_TITLE'; end if;
  if p_class_type not in ('one_to_one','group') then raise exception 'INVALID_CLASS_TYPE'; end if;
  if p_capacity is null or p_capacity<1 or (p_class_type='one_to_one' and p_capacity<>1) then raise exception 'INVALID_CLASS_CAPACITY'; end if;
  if p_location_id is not null and not exists(select 1 from public.locations where id=p_location_id and state<>'retired') then raise exception 'INVALID_CLASS_LOCATION'; end if;
  if p_organization_id is null then
    if p_responsible_teacher_account_id<>v_actor or not app_private.has_account_capability('teach') then raise exception 'NOT_AUTHORIZED'; end if;
  else
    if not app_private.has_organization_member_capability(p_organization_id,'manage_classes') then raise exception 'NOT_AUTHORIZED'; end if;
    if not exists(
      select 1 from public.organization_members om
      join public.organization_member_capabilities c on c.organization_member_id=om.id and c.capability_code='manage_classes'
      join public.accounts a on a.id=om.account_id and a.lifecycle_status='active'
      where om.organization_id=p_organization_id and om.account_id=p_responsible_teacher_account_id and om.status='active'
    ) then raise exception 'RESPONSIBLE_TEACHER_NOT_ELIGIBLE'; end if;
  end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('organization_id',p_organization_id,'responsible_teacher_account_id',p_responsible_teacher_account_id,
    'location_id',p_location_id,'title',p_title,'class_type',p_class_type,'capacity',p_capacity));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'create_class',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.classes(responsible_teacher_account_id,organization_id,location_id,title,class_type,capacity)
  values(p_responsible_teacher_account_id,p_organization_id,p_location_id,btrim(p_title),p_class_type,p_capacity)
  returning id into v_class;
  perform app_private.write_audit(v_actor,'class.create','class',v_class,null,null,jsonb_build_object('organization_id',p_organization_id,'location_id',p_location_id,'class_type',p_class_type,'capacity',p_capacity));
  v_result:=jsonb_build_object('class_id',v_class,'state','draft','capacity',p_capacity);
  perform app_private.complete_human_idempotent_command(v_actor,'create_class',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_activate_class(p_class_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_state text; v_result jsonb;
begin
  if not app_private.can_manage_class(p_class_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if app_private.current_actor_class_access_blocked(p_class_id) or app_private.class_provider_access_blocked(p_class_id) then raise exception 'CLASS_ACCESS_RESTRICTED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('class_id',p_class_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'activate_class',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select state into v_state from public.classes where id=p_class_id for update;
  if not found then raise exception 'CLASS_NOT_FOUND'; end if;
  if v_state='active' then v_result:=jsonb_build_object('class_id',p_class_id,'state','active','already_active',true);
  elsif v_state<>'draft' then raise exception 'CLASS_NOT_DRAFT';
  else update public.classes set state='active' where id=p_class_id; v_result:=jsonb_build_object('class_id',p_class_id,'state','active','already_active',false); end if;
  perform app_private.complete_human_idempotent_command(v_actor,'activate_class',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_set_class_capacity(p_class_id uuid,p_capacity integer,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_type text; v_old int; v_occupied int; v_result jsonb;
begin
  if not app_private.can_manage_class(p_class_id) then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('class_id',p_class_id,'capacity',p_capacity));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'set_class_capacity',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select class_type,capacity into v_type,v_old from public.classes where id=p_class_id for update;
  if not found then raise exception 'CLASS_NOT_FOUND'; end if;
  if p_capacity is null or p_capacity<1 or (v_type='one_to_one' and p_capacity<>1) then raise exception 'INVALID_CLASS_CAPACITY'; end if;
  perform app_private.expire_pending_class_invitations(p_class_id);
  v_occupied:=app_private.class_reserved_occupancy(p_class_id);
  if p_capacity<v_occupied then raise exception 'CAPACITY_BELOW_ACTIVE_AND_RESERVED:%',v_occupied; end if;
  update public.classes set capacity=p_capacity where id=p_class_id;
  v_result:=jsonb_build_object('class_id',p_class_id,'old_capacity',v_old,'capacity',p_capacity,'obligated',v_occupied);
  perform app_private.complete_human_idempotent_command(v_actor,'set_class_capacity',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.create_pending_class_invitation_locked(
  p_class_id uuid,p_learner_id uuid,p_actor uuid,p_fee_display_text text
)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_capacity int; v_state text; v_occupied int; v_inv uuid;
begin
  select capacity,state into v_capacity,v_state from public.classes where id=p_class_id for update;
  if not found then raise exception 'CLASS_NOT_FOUND'; end if;
  if v_state<>'active' then raise exception 'CLASS_NOT_ACTIVE'; end if;
  perform app_private.expire_pending_class_invitations(p_class_id);
  if exists(select 1 from public.class_memberships where class_id=p_class_id and learner_id=p_learner_id and state='active') then raise exception 'LEARNER_ALREADY_ACTIVE_IN_CLASS'; end if;
  if exists(select 1 from public.class_invitations where class_id=p_class_id and learner_id=p_learner_id and state='pending') then raise exception 'PENDING_INVITATION_ALREADY_EXISTS'; end if;
  v_occupied:=app_private.class_reserved_occupancy(p_class_id);
  if v_occupied>=v_capacity then raise exception 'CLASS_CAPACITY_FULL'; end if;
  insert into public.class_invitations(class_id,learner_id,invited_by_account_id,state,expires_at,fee_display_text)
  values(p_class_id,p_learner_id,p_actor,'pending',now()+app_private.class_invitation_ttl(),nullif(btrim(p_fee_display_text),'')) returning id into v_inv;
  return v_inv;
end; $$;

create or replace function app_private.cmd_send_class_invitation(
  p_class_id uuid,p_enquiry_id uuid,p_fee_display_text text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_learner uuid; v_e_state text; v_e_account uuid; v_e_org uuid; v_c_teacher uuid; v_c_org uuid; v_location uuid; v_inv uuid; v_result jsonb; v_decider uuid;
begin
  if not app_private.can_manage_class(p_class_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if app_private.current_actor_class_access_blocked(p_class_id) or app_private.class_provider_access_blocked(p_class_id) then raise exception 'CLASS_ACCESS_RESTRICTED'; end if;
  select learner_id,state,provider_account_id,provider_organization_id into v_learner,v_e_state,v_e_account,v_e_org from public.enquiries where id=p_enquiry_id;
  if not found or v_e_state<>'active' then raise exception 'ACTIVE_ENQUIRY_REQUIRED'; end if;
  select responsible_teacher_account_id,organization_id,location_id into v_c_teacher,v_c_org,v_location from public.classes where id=p_class_id;
  if (v_c_org is null and (v_e_account is distinct from v_c_teacher or v_e_org is not null))
     or (v_c_org is not null and (v_e_org is distinct from v_c_org or v_e_account is not null)) then raise exception 'ENQUIRY_PROVIDER_DOES_NOT_MATCH_CLASS'; end if;
  v_decider:=app_private.learner_decision_account_id(v_learner);
  if v_decider is null or app_private.has_active_account_restriction(v_decider,'class_access',v_location) then raise exception 'LEARNER_SIDE_CLASS_ACCESS_RESTRICTED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('class_id',p_class_id,'enquiry_id',p_enquiry_id,'fee_display_text',p_fee_display_text));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'send_class_invitation',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  v_inv:=app_private.create_pending_class_invitation_locked(p_class_id,v_learner,v_actor,p_fee_display_text);
  perform app_private.write_audit(v_actor,'class.invitation_send','class_invitation',v_inv,v_learner,null,jsonb_build_object('class_id',p_class_id,'enquiry_id',p_enquiry_id));
  v_result:=jsonb_build_object('invitation_id',v_inv,'class_id',p_class_id,'learner_id',v_learner,'state','pending');
  perform app_private.complete_human_idempotent_command(v_actor,'send_class_invitation',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_send_class_invitation_with_share_code(
  p_class_id uuid,p_share_code text,p_fee_display_text text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_share_id uuid; v_learner uuid; v_inv uuid; v_result jsonb; v_location uuid; v_decider uuid;
begin
  if not app_private.can_manage_class(p_class_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if app_private.current_actor_class_access_blocked(p_class_id) or app_private.class_provider_access_blocked(p_class_id) then raise exception 'CLASS_ACCESS_RESTRICTED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('class_id',p_class_id,'share_code_hash',app_private.learner_share_code_hash(p_share_code),'fee_display_text',p_fee_display_text));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'send_class_invitation_with_share_code',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  perform 1 from public.classes where id=p_class_id for update;
  if not found then raise exception 'CLASS_NOT_FOUND'; end if;
  select share_code_id,learner_id into v_share_id,v_learner from app_private.resolve_active_learner_share_code(p_share_code);
  if v_share_id is null then raise exception 'INVALID_OR_EXPIRED_SHARE_CODE'; end if;
  select location_id into v_location from public.classes where id=p_class_id;
  v_decider:=app_private.learner_decision_account_id(v_learner);
  if v_decider is null or app_private.has_active_account_restriction(v_decider,'class_access',v_location) then raise exception 'LEARNER_SIDE_CLASS_ACCESS_RESTRICTED'; end if;
  v_inv:=app_private.create_pending_class_invitation_locked(p_class_id,v_learner,v_actor,p_fee_display_text);
  update public.learner_share_codes set state='consumed',consumed_at=now() where id=v_share_id and state='active';
  if not found then raise exception 'SHARE_CODE_CONSUME_RACE_LOST'; end if;
  perform app_private.write_audit(v_actor,'class.invitation_send_share_code','class_invitation',v_inv,v_learner,null,
    jsonb_build_object('class_id',p_class_id,'share_code_id',v_share_id));
  v_result:=jsonb_build_object('invitation_id',v_inv,'class_id',p_class_id,'learner_id',v_learner,'state','pending');
  perform app_private.complete_human_idempotent_command(v_actor,'send_class_invitation_with_share_code',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_accept_class_invitation(p_invitation_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_class uuid; v_learner uuid; v_state text; v_expires timestamptz; v_class_state text; v_membership uuid; v_result jsonb;
begin
  v_fp:=app_private.request_fingerprint(jsonb_build_object('invitation_id',p_invitation_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'accept_class_invitation',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select class_id,learner_id,state,expires_at into v_class,v_learner,v_state,v_expires from public.class_invitations where id=p_invitation_id for update;
  if not found then raise exception 'INVITATION_NOT_FOUND'; end if;
  if not app_private.can_make_learning_decision(v_learner) then raise exception 'NOT_AUTHORIZED'; end if;
  if app_private.current_actor_class_access_blocked(v_class) or app_private.class_provider_access_blocked(v_class) then raise exception 'CLASS_ACCESS_RESTRICTED'; end if;
  select state into v_class_state from public.classes where id=v_class for update;
  if v_class_state<>'active' then raise exception 'CLASS_NOT_ACTIVE'; end if;
  if v_state='accepted' then
    select id into v_membership from public.class_memberships where joined_via_invitation_id=p_invitation_id and state='active' limit 1;
    if v_membership is null then raise exception 'ACCEPTED_INVITATION_MEMBERSHIP_MISSING'; end if;
    v_result:=jsonb_build_object('invitation_id',p_invitation_id,'membership_id',v_membership,'state','accepted','already_accepted',true);
  elsif v_state<>'pending' then raise exception 'INVITATION_NOT_PENDING';
  elsif v_expires<=now() then raise exception 'INVITATION_EXPIRED';
  else
    if exists(select 1 from public.class_memberships where class_id=v_class and learner_id=v_learner and state='active') then raise exception 'ACTIVE_MEMBERSHIP_ALREADY_EXISTS'; end if;
    insert into public.class_memberships(class_id,learner_id,state,joined_via_invitation_id)
    values(v_class,v_learner,'active',p_invitation_id) returning id into v_membership;
    update public.class_invitations set state='accepted',resolved_at=now() where id=p_invitation_id;
    perform app_private.write_audit(v_actor,'class.invitation_accept','class_membership',v_membership,v_learner,null,jsonb_build_object('class_id',v_class,'invitation_id',p_invitation_id));
    v_result:=jsonb_build_object('invitation_id',p_invitation_id,'membership_id',v_membership,'state','accepted','already_accepted',false);
  end if;
  perform app_private.complete_human_idempotent_command(v_actor,'accept_class_invitation',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_decline_class_invitation(p_invitation_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_learner uuid; v_state text; v_expires timestamptz; v_result jsonb;
begin
  v_fp:=app_private.request_fingerprint(jsonb_build_object('invitation_id',p_invitation_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'decline_class_invitation',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select learner_id,state,expires_at into v_learner,v_state,v_expires from public.class_invitations where id=p_invitation_id for update;
  if not found then raise exception 'INVITATION_NOT_FOUND'; end if;
  if not app_private.can_make_learning_decision(v_learner) then raise exception 'NOT_AUTHORIZED'; end if;
  if v_state='pending' and v_expires<=now() then update public.class_invitations set state='expired',resolved_at=now() where id=p_invitation_id; v_result:=jsonb_build_object('invitation_id',p_invitation_id,'state','expired');
  elsif v_state='pending' then update public.class_invitations set state='declined',resolved_at=now() where id=p_invitation_id; v_result:=jsonb_build_object('invitation_id',p_invitation_id,'state','declined');
  elsif v_state='declined' then v_result:=jsonb_build_object('invitation_id',p_invitation_id,'state','declined','already_declined',true);
  else raise exception 'INVITATION_NOT_PENDING'; end if;
  perform app_private.complete_human_idempotent_command(v_actor,'decline_class_invitation',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_cancel_class_invitation(p_invitation_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_class uuid; v_state text; v_result jsonb;
begin
  v_fp:=app_private.request_fingerprint(jsonb_build_object('invitation_id',p_invitation_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'cancel_class_invitation',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select class_id,state into v_class,v_state from public.class_invitations where id=p_invitation_id for update;
  if not found then raise exception 'INVITATION_NOT_FOUND'; end if;
  if not app_private.can_manage_class(v_class) then raise exception 'NOT_AUTHORIZED'; end if;
  if v_state='pending' then update public.class_invitations set state='cancelled',resolved_at=now() where id=p_invitation_id; v_result:=jsonb_build_object('invitation_id',p_invitation_id,'state','cancelled','already_cancelled',false);
  elsif v_state='cancelled' then v_result:=jsonb_build_object('invitation_id',p_invitation_id,'state','cancelled','already_cancelled',true);
  else raise exception 'INVITATION_NOT_PENDING'; end if;
  perform app_private.complete_human_idempotent_command(v_actor,'cancel_class_invitation',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_leave_class(p_membership_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_learner uuid; v_state text; v_result jsonb;
begin
  v_fp:=app_private.request_fingerprint(jsonb_build_object('membership_id',p_membership_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'leave_class',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select learner_id,state into v_learner,v_state from public.class_memberships where id=p_membership_id for update;
  if not found then raise exception 'MEMBERSHIP_NOT_FOUND'; end if;
  if not app_private.can_make_learning_decision(v_learner) then raise exception 'NOT_AUTHORIZED'; end if;
  if v_state='active' then update public.class_memberships set state='left',ended_at=now(),end_reason='learner_left' where id=p_membership_id; v_result:=jsonb_build_object('membership_id',p_membership_id,'state','left','changed',true);
  elsif v_state='left' then v_result:=jsonb_build_object('membership_id',p_membership_id,'state','left','changed',false);
  else raise exception 'MEMBERSHIP_NOT_ACTIVE'; end if;
  perform app_private.complete_human_idempotent_command(v_actor,'leave_class',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_remove_learner_from_class(p_membership_id uuid,p_reason text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_class uuid; v_learner uuid; v_state text; v_result jsonb;
begin
  v_fp:=app_private.request_fingerprint(jsonb_build_object('membership_id',p_membership_id,'reason',p_reason));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'remove_learner_from_class',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select class_id,learner_id,state into v_class,v_learner,v_state from public.class_memberships where id=p_membership_id for update;
  if not found then raise exception 'MEMBERSHIP_NOT_FOUND'; end if;
  if not app_private.can_manage_class(v_class) then raise exception 'NOT_AUTHORIZED'; end if;
  if v_state='active' then update public.class_memberships set state='removed',ended_at=now(),end_reason=coalesce(nullif(btrim(p_reason),''),'removed') where id=p_membership_id; v_result:=jsonb_build_object('membership_id',p_membership_id,'state','removed','changed',true);
  elsif v_state='removed' then v_result:=jsonb_build_object('membership_id',p_membership_id,'state','removed','changed',false);
  else raise exception 'MEMBERSHIP_NOT_ACTIVE'; end if;
  perform app_private.write_audit(v_actor,'class.membership_remove','class_membership',p_membership_id,v_learner,null,jsonb_build_object('class_id',v_class,'reason_code',coalesce(nullif(btrim(p_reason),''),'removed')));
  perform app_private.complete_human_idempotent_command(v_actor,'remove_learner_from_class',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_transfer_learner(
  p_source_membership_id uuid,p_destination_class_id uuid,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text;
  v_source_class uuid; v_learner uuid; v_source_state text; v_s_teacher uuid; v_s_org uuid; v_d_teacher uuid; v_d_org uuid;
  v_capacity int; v_occupied int; v_new_membership uuid; v_result jsonb; v_first uuid; v_second uuid;
begin
  v_fp:=app_private.request_fingerprint(jsonb_build_object('source_membership_id',p_source_membership_id,'destination_class_id',p_destination_class_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'transfer_learner',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select class_id,learner_id,state into v_source_class,v_learner,v_source_state from public.class_memberships where id=p_source_membership_id for update;
  if not found then raise exception 'MEMBERSHIP_NOT_FOUND'; end if;
  if v_source_class=p_destination_class_id then raise exception 'TRANSFER_DESTINATION_MUST_DIFFER'; end if;
  v_first:=least(v_source_class,p_destination_class_id); v_second:=greatest(v_source_class,p_destination_class_id);
  perform 1 from public.classes where id=v_first for update;
  perform 1 from public.classes where id=v_second for update;
  select responsible_teacher_account_id,organization_id into v_s_teacher,v_s_org from public.classes where id=v_source_class;
  select responsible_teacher_account_id,organization_id,capacity into v_d_teacher,v_d_org,v_capacity from public.classes where id=p_destination_class_id and state='active';
  if not found then raise exception 'DESTINATION_CLASS_NOT_ACTIVE'; end if;
  if v_s_teacher is distinct from v_d_teacher or v_s_org is distinct from v_d_org then raise exception 'TRANSFER_REQUIRES_SAME_PROVIDER'; end if;
  if not app_private.can_make_learning_decision(v_learner)
     and not (app_private.can_manage_class(v_source_class) and app_private.can_manage_class(p_destination_class_id)) then raise exception 'NOT_AUTHORIZED'; end if;
  if v_source_state<>'active' then raise exception 'SOURCE_MEMBERSHIP_NOT_ACTIVE'; end if;
  if app_private.current_actor_class_access_blocked(v_source_class) or app_private.current_actor_class_access_blocked(p_destination_class_id)
     or app_private.class_provider_access_blocked(v_source_class) or app_private.class_provider_access_blocked(p_destination_class_id) then raise exception 'CLASS_ACCESS_RESTRICTED'; end if;
  perform app_private.expire_pending_class_invitations(p_destination_class_id);
  if exists(select 1 from public.class_invitations where class_id=p_destination_class_id and learner_id=v_learner and state='pending') then raise exception 'DESTINATION_PENDING_INVITATION_EXISTS'; end if;
  if exists(select 1 from public.class_memberships where class_id=p_destination_class_id and learner_id=v_learner and state='active') then raise exception 'DESTINATION_MEMBERSHIP_ALREADY_ACTIVE'; end if;
  v_occupied:=app_private.class_reserved_occupancy(p_destination_class_id);
  if v_occupied>=v_capacity then raise exception 'DESTINATION_CLASS_FULL'; end if;
  insert into public.class_memberships(class_id,learner_id,state) values(p_destination_class_id,v_learner,'active') returning id into v_new_membership;
  update public.class_memberships set state='transferred',ended_at=now(),end_reason='transferred',transferred_to_membership_id=v_new_membership where id=p_source_membership_id;
  perform app_private.write_audit(v_actor,'class.membership_transfer','class_membership',p_source_membership_id,v_learner,null,
    jsonb_build_object('source_class_id',v_source_class,'destination_class_id',p_destination_class_id,'destination_membership_id',v_new_membership));
  v_result:=jsonb_build_object('source_membership_id',p_source_membership_id,'source_state','transferred','destination_membership_id',v_new_membership,'destination_class_id',p_destination_class_id);
  perform app_private.complete_human_idempotent_command(v_actor,'transfer_learner',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_complete_class(p_class_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_state text; v_completed int; v_result jsonb;
begin
  if not app_private.can_manage_class(p_class_id) then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('class_id',p_class_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'complete_class',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select state into v_state from public.classes where id=p_class_id for update;
  if not found then raise exception 'CLASS_NOT_FOUND'; end if;
  if v_state='past' then v_result:=jsonb_build_object('class_id',p_class_id,'state','past','memberships_completed',0,'already_past',true);
  elsif v_state<>'active' then raise exception 'CLASS_NOT_ACTIVE';
  else
    update public.class_memberships set state='completed',ended_at=now(),end_reason='class_completed' where class_id=p_class_id and state='active';
    get diagnostics v_completed=row_count;
    update public.class_invitations set state='cancelled',resolved_at=now() where class_id=p_class_id and state='pending';
    update public.classes set state='past' where id=p_class_id;
    perform app_private.write_audit(v_actor,'class.complete','class',p_class_id,null,null,jsonb_build_object('memberships_completed',v_completed));
    v_result:=jsonb_build_object('class_id',p_class_id,'state','past','memberships_completed',v_completed,'already_past',false);
  end if;
  perform app_private.complete_human_idempotent_command(v_actor,'complete_class',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_schedule_class_session(
  p_class_id uuid,p_starts_at timestamptz,p_ends_at timestamptz,p_delivery_mode text,p_meeting_or_location_text text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_session uuid; v_result jsonb;
begin
  if not app_private.can_manage_class(p_class_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if not exists(select 1 from public.classes where id=p_class_id and state='active') then raise exception 'CLASS_NOT_ACTIVE'; end if;
  if p_starts_at is null or p_starts_at<=now() then raise exception 'SESSION_START_MUST_BE_FUTURE'; end if;
  if p_ends_at is not null and p_ends_at<=p_starts_at then raise exception 'INVALID_SESSION_END'; end if;
  if p_delivery_mode not in ('online','in_person') then raise exception 'INVALID_DELIVERY_MODE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('class_id',p_class_id,'starts_at',p_starts_at,'ends_at',p_ends_at,'delivery_mode',p_delivery_mode,'meeting_or_location_text',p_meeting_or_location_text));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'schedule_class_session',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.class_sessions(class_id,starts_at,ends_at,delivery_mode,meeting_or_location_text)
  values(p_class_id,p_starts_at,p_ends_at,p_delivery_mode,nullif(btrim(p_meeting_or_location_text),'')) returning id into v_session;
  v_result:=jsonb_build_object('session_id',v_session,'class_id',p_class_id);
  perform app_private.complete_human_idempotent_command(v_actor,'schedule_class_session',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_cancel_class_session(p_session_id uuid,p_reason text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_class uuid; v_cancelled timestamptz; v_result jsonb;
begin
  select class_id,cancelled_at into v_class,v_cancelled from public.class_sessions where id=p_session_id for update;
  if not found then raise exception 'SESSION_NOT_FOUND'; end if;
  if not app_private.can_manage_class(v_class) then raise exception 'NOT_AUTHORIZED'; end if;
  if p_reason is null or btrim(p_reason)='' then raise exception 'CANCEL_REASON_REQUIRED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('session_id',p_session_id,'reason',p_reason));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'cancel_class_session',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if v_cancelled is null then update public.class_sessions set cancelled_at=now(),cancel_reason=btrim(p_reason) where id=p_session_id; end if;
  v_result:=jsonb_build_object('session_id',p_session_id,'cancelled',true,'already_cancelled',v_cancelled is not null);
  perform app_private.complete_human_idempotent_command(v_actor,'cancel_class_session',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_register_file_asset(
  p_storage_path text,p_purpose_code text,p_mime_type text,p_size_bytes bigint,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_file uuid; v_result jsonb;
begin
  if p_storage_path is null or char_length(btrim(p_storage_path)) not between 1 and 1000 then raise exception 'INVALID_STORAGE_PATH'; end if;
  if p_purpose_code is null or char_length(btrim(p_purpose_code)) not between 1 and 120 then raise exception 'INVALID_PURPOSE_CODE'; end if;
  if p_size_bytes is not null and p_size_bytes<0 then raise exception 'INVALID_FILE_SIZE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('storage_path',p_storage_path,'purpose_code',p_purpose_code,'mime_type',p_mime_type,'size_bytes',p_size_bytes));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'register_file_asset',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.file_assets(uploaded_by_account_id,storage_path,purpose_code,mime_type,size_bytes)
  values(v_actor,btrim(p_storage_path),btrim(p_purpose_code),nullif(btrim(p_mime_type),''),p_size_bytes) returning id into v_file;
  v_result:=jsonb_build_object('file_asset_id',v_file,'status','active');
  perform app_private.complete_human_idempotent_command(v_actor,'register_file_asset',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.actor_can_create_material()
returns boolean language sql stable security definer set search_path='' as $$
  select app_private.has_account_capability('teach') or app_private.has_account_capability('platform_admin') or exists(
    select 1 from public.organization_members om join public.organization_member_capabilities c on c.organization_member_id=om.id and c.capability_code='manage_classes'
    join public.accounts a on a.id=om.account_id and a.lifecycle_status='active'
    where om.account_id=app_private.current_account_id() and om.status='active'
  );
$$;

create or replace function app_private.cmd_create_material(
  p_title text,p_description text,p_resource_type text,p_file_asset_id uuid,p_external_url text,p_text_content text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_material uuid; v_result jsonb;
begin
  if not app_private.actor_can_create_material() then raise exception 'NOT_AUTHORIZED'; end if;
  if p_title is null or char_length(btrim(p_title)) not between 1 and 300 then raise exception 'INVALID_MATERIAL_TITLE'; end if;
  if p_resource_type not in ('file','external_link','text') then raise exception 'INVALID_RESOURCE_TYPE'; end if;
  if p_resource_type='file' and (p_file_asset_id is null or p_external_url is not null or p_text_content is not null) then raise exception 'INVALID_MATERIAL_RESOURCE'; end if;
  if p_resource_type='external_link' and (p_file_asset_id is not null or p_external_url is null or p_text_content is not null) then raise exception 'INVALID_MATERIAL_RESOURCE'; end if;
  if p_resource_type='text' and (p_file_asset_id is not null or p_external_url is not null or p_text_content is null) then raise exception 'INVALID_MATERIAL_RESOURCE'; end if;
  if p_file_asset_id is not null and not exists(select 1 from public.file_assets where id=p_file_asset_id and uploaded_by_account_id=v_actor and status='active') then raise exception 'FILE_ASSET_NOT_OWNED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('title',p_title,'description',p_description,'resource_type',p_resource_type,'file_asset_id',p_file_asset_id,'external_url',p_external_url,'text_content',p_text_content));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'create_material',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.materials(created_by_account_id,title,description,resource_type,file_asset_id,external_url,text_content)
  values(v_actor,btrim(p_title),nullif(btrim(p_description),''),p_resource_type,p_file_asset_id,nullif(btrim(p_external_url),''),p_text_content) returning id into v_material;
  v_result:=jsonb_build_object('material_id',v_material,'resource_type',p_resource_type);
  perform app_private.complete_human_idempotent_command(v_actor,'create_material',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.can_manage_material(p_material_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select app_private.has_account_capability('platform_admin')
    or exists(select 1 from public.materials m where m.id=p_material_id and m.created_by_account_id=app_private.current_account_id())
    or exists(select 1 from public.material_class_links l where l.material_id=p_material_id and app_private.can_manage_class(l.class_id));
$$;

create or replace function app_private.cmd_set_material_class_link(p_material_id uuid,p_class_id uuid,p_linked boolean,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_changed boolean:=false; v_result jsonb;
begin
  if not app_private.can_manage_class(p_class_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if not app_private.can_manage_material(p_material_id) then raise exception 'MATERIAL_NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('material_id',p_material_id,'class_id',p_class_id,'linked',p_linked));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'set_material_class_link',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if p_linked then insert into public.material_class_links(material_id,class_id) values(p_material_id,p_class_id) on conflict do nothing; get diagnostics v_changed=row_count;
  else delete from public.material_class_links where material_id=p_material_id and class_id=p_class_id; get diagnostics v_changed=row_count; end if;
  v_result:=jsonb_build_object('material_id',p_material_id,'class_id',p_class_id,'linked',p_linked,'changed',v_changed);
  perform app_private.complete_human_idempotent_command(v_actor,'set_material_class_link',p_idempotency_key,v_result); return v_result;
end; $$;

-- Extend closure blockers with unresolved responsible-teacher Class obligations.
create or replace function app_private.account_closure_blockers(p_account_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
with blockers as (
  select jsonb_build_object('code','SOLE_MANAGER_RESPONSIBILITY','learner_id',ala.learner_id) blocker
  from public.account_learner_access ala
  where ala.account_id=p_account_id and ala.access_type='manage' and ala.status='active'
    and not exists(select 1 from public.account_learner_access s where s.learner_id=ala.learner_id and s.access_type='self' and s.status='active')
  union all
  select jsonb_build_object('code','ACTIVE_LOCAL_MANAGER_ASSIGNMENT','location_id',lsa.location_id,'assignment_id',lsa.id)
  from public.location_staff_assignments lsa where lsa.account_id=p_account_id and lsa.status='active'
  union all
  select jsonb_build_object('code','SOLE_ORGANIZATION_MANAGER','organization_id',om.organization_id,'member_id',om.id)
  from public.organization_members om join public.organization_member_capabilities c on c.organization_member_id=om.id and c.capability_code='manage_members'
  where om.account_id=p_account_id and om.status='active'
    and not exists(select 1 from public.organization_members other join public.organization_member_capabilities oc on oc.organization_member_id=other.id and oc.capability_code='manage_members'
      where other.organization_id=om.organization_id and other.status='active' and other.id<>om.id)
  union all
  select jsonb_build_object('code','RESPONSIBLE_TEACHER_ACTIVE_CLASS','class_id',c.id)
  from public.classes c where c.responsible_teacher_account_id=p_account_id and c.state in ('draft','active')
)
select coalesce(jsonb_agg(blocker),'[]'::jsonb) from blockers;
$$;

revoke all on function app_private.class_invitation_ttl(),app_private.can_manage_class(uuid),app_private.class_provider_access_blocked(uuid),
 app_private.current_actor_class_access_blocked(uuid),app_private.expire_pending_class_invitations(uuid),app_private.class_reserved_occupancy(uuid),
 app_private.create_pending_class_invitation_locked(uuid,uuid,uuid,text),app_private.actor_can_create_material(),app_private.can_manage_material(uuid)
from public,anon,authenticated,service_role;
revoke all on function app_private.cmd_create_class(uuid,uuid,uuid,text,text,integer,text),app_private.cmd_activate_class(uuid,text),app_private.cmd_set_class_capacity(uuid,integer,text),
 app_private.cmd_send_class_invitation(uuid,uuid,text,text),app_private.cmd_send_class_invitation_with_share_code(uuid,text,text,text),
 app_private.cmd_accept_class_invitation(uuid,text),app_private.cmd_decline_class_invitation(uuid,text),app_private.cmd_cancel_class_invitation(uuid,text),
 app_private.cmd_leave_class(uuid,text),app_private.cmd_remove_learner_from_class(uuid,text,text),app_private.cmd_transfer_learner(uuid,uuid,text),app_private.cmd_complete_class(uuid,text),
 app_private.cmd_schedule_class_session(uuid,timestamptz,timestamptz,text,text,text),app_private.cmd_cancel_class_session(uuid,text,text),
 app_private.cmd_register_file_asset(text,text,text,bigint,text),app_private.cmd_create_material(text,text,text,uuid,text,text,text),app_private.cmd_set_material_class_link(uuid,uuid,boolean,text)
from public,anon,authenticated,service_role;

grant execute on function app_private.can_manage_class(uuid) to authenticated;
grant execute on function app_private.cmd_create_class(uuid,uuid,uuid,text,text,integer,text),app_private.cmd_activate_class(uuid,text),app_private.cmd_set_class_capacity(uuid,integer,text),
 app_private.cmd_send_class_invitation(uuid,uuid,text,text),app_private.cmd_send_class_invitation_with_share_code(uuid,text,text,text),
 app_private.cmd_accept_class_invitation(uuid,text),app_private.cmd_decline_class_invitation(uuid,text),app_private.cmd_cancel_class_invitation(uuid,text),
 app_private.cmd_leave_class(uuid,text),app_private.cmd_remove_learner_from_class(uuid,text,text),app_private.cmd_transfer_learner(uuid,uuid,text),app_private.cmd_complete_class(uuid,text),
 app_private.cmd_schedule_class_session(uuid,timestamptz,timestamptz,text,text,text),app_private.cmd_cancel_class_session(uuid,text,text),
 app_private.cmd_register_file_asset(text,text,text,bigint,text),app_private.cmd_create_material(text,text,text,uuid,text,text,text),app_private.cmd_set_material_class_link(uuid,uuid,boolean,text)
to authenticated;

create or replace function public.create_class(p_organization_id uuid,p_responsible_teacher_account_id uuid,p_location_id uuid,p_title text,p_class_type text,p_capacity integer,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_create_class(p_organization_id,p_responsible_teacher_account_id,p_location_id,p_title,p_class_type,p_capacity,p_idempotency_key); $$;
create or replace function public.activate_class(p_class_id uuid,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_activate_class(p_class_id,p_idempotency_key); $$;
create or replace function public.set_class_capacity(p_class_id uuid,p_capacity integer,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_set_class_capacity(p_class_id,p_capacity,p_idempotency_key); $$;
create or replace function public.send_class_invitation(p_class_id uuid,p_enquiry_id uuid,p_fee_display_text text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_send_class_invitation(p_class_id,p_enquiry_id,p_fee_display_text,p_idempotency_key); $$;
create or replace function public.send_class_invitation_with_share_code(p_class_id uuid,p_share_code text,p_fee_display_text text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_send_class_invitation_with_share_code(p_class_id,p_share_code,p_fee_display_text,p_idempotency_key); $$;
create or replace function public.accept_class_invitation(p_invitation_id uuid,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_accept_class_invitation(p_invitation_id,p_idempotency_key); $$;
create or replace function public.decline_class_invitation(p_invitation_id uuid,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_decline_class_invitation(p_invitation_id,p_idempotency_key); $$;
create or replace function public.cancel_class_invitation(p_invitation_id uuid,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_cancel_class_invitation(p_invitation_id,p_idempotency_key); $$;
create or replace function public.leave_class(p_membership_id uuid,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_leave_class(p_membership_id,p_idempotency_key); $$;
create or replace function public.remove_learner_from_class(p_membership_id uuid,p_reason text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_remove_learner_from_class(p_membership_id,p_reason,p_idempotency_key); $$;
create or replace function public.transfer_learner(p_source_membership_id uuid,p_destination_class_id uuid,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_transfer_learner(p_source_membership_id,p_destination_class_id,p_idempotency_key); $$;
create or replace function public.complete_class(p_class_id uuid,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_complete_class(p_class_id,p_idempotency_key); $$;
create or replace function public.schedule_class_session(p_class_id uuid,p_starts_at timestamptz,p_ends_at timestamptz,p_delivery_mode text,p_meeting_or_location_text text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_schedule_class_session(p_class_id,p_starts_at,p_ends_at,p_delivery_mode,p_meeting_or_location_text,p_idempotency_key); $$;
create or replace function public.cancel_class_session(p_session_id uuid,p_reason text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_cancel_class_session(p_session_id,p_reason,p_idempotency_key); $$;
create or replace function public.register_file_asset(p_storage_path text,p_purpose_code text,p_mime_type text,p_size_bytes bigint,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_register_file_asset(p_storage_path,p_purpose_code,p_mime_type,p_size_bytes,p_idempotency_key); $$;
create or replace function public.create_material(p_title text,p_description text,p_resource_type text,p_file_asset_id uuid,p_external_url text,p_text_content text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_create_material(p_title,p_description,p_resource_type,p_file_asset_id,p_external_url,p_text_content,p_idempotency_key); $$;
create or replace function public.set_material_class_link(p_material_id uuid,p_class_id uuid,p_linked boolean,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_set_material_class_link(p_material_id,p_class_id,p_linked,p_idempotency_key); $$;

revoke all on function public.create_class(uuid,uuid,uuid,text,text,integer,text),public.activate_class(uuid,text),public.set_class_capacity(uuid,integer,text),
 public.send_class_invitation(uuid,uuid,text,text),public.send_class_invitation_with_share_code(uuid,text,text,text),public.accept_class_invitation(uuid,text),
 public.decline_class_invitation(uuid,text),public.cancel_class_invitation(uuid,text),public.leave_class(uuid,text),public.remove_learner_from_class(uuid,text,text),
 public.transfer_learner(uuid,uuid,text),public.complete_class(uuid,text),public.schedule_class_session(uuid,timestamptz,timestamptz,text,text,text),
 public.cancel_class_session(uuid,text,text),public.register_file_asset(text,text,text,bigint,text),public.create_material(text,text,text,uuid,text,text,text),public.set_material_class_link(uuid,uuid,boolean,text)
from public,anon,authenticated,service_role;
grant execute on function public.create_class(uuid,uuid,uuid,text,text,integer,text),public.activate_class(uuid,text),public.set_class_capacity(uuid,integer,text),
 public.send_class_invitation(uuid,uuid,text,text),public.send_class_invitation_with_share_code(uuid,text,text,text),public.accept_class_invitation(uuid,text),
 public.decline_class_invitation(uuid,text),public.cancel_class_invitation(uuid,text),public.leave_class(uuid,text),public.remove_learner_from_class(uuid,text,text),
 public.transfer_learner(uuid,uuid,text),public.complete_class(uuid,text),public.schedule_class_session(uuid,timestamptz,timestamptz,text,text,text),
 public.cancel_class_session(uuid,text,text),public.register_file_asset(text,text,text,bigint,text),public.create_material(text,text,text,uuid,text,text,text),public.set_material_class_link(uuid,uuid,boolean,text)
to authenticated;
