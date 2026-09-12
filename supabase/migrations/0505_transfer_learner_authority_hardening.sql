-- Raahi Learning V1.2 — make the learner-side decision boundary explicit for Class transfer.
-- Forward-fix/replay reconciliation: transfer is a formal learner-side decision;
-- a teacher cannot unilaterally move a learner merely because both Classes share a provider.

create or replace function app_private.cmd_transfer_learner(
  p_source_membership_id uuid,
  p_destination_class_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := app_private.require_current_account(true);
  v_gate jsonb;
  v_fp text;
  v_source_class uuid;
  v_learner uuid;
  v_source_state text;
  v_s_teacher uuid;
  v_s_org uuid;
  v_d_teacher uuid;
  v_d_org uuid;
  v_capacity int;
  v_occupied int;
  v_new_membership uuid;
  v_result jsonb;
  v_first uuid;
  v_second uuid;
begin
  v_fp := app_private.request_fingerprint(jsonb_build_object(
    'source_membership_id', p_source_membership_id,
    'destination_class_id', p_destination_class_id
  ));
  v_gate := app_private.begin_human_idempotent_command(
    v_actor, 'transfer_learner', p_idempotency_key, v_fp
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select class_id, learner_id, state
    into v_source_class, v_learner, v_source_state
  from public.class_memberships
  where id = p_source_membership_id
  for update;
  if not found then raise exception 'MEMBERSHIP_NOT_FOUND'; end if;
  if v_source_class = p_destination_class_id then raise exception 'TRANSFER_DESTINATION_MUST_DIFFER'; end if;

  -- This is the frozen product rule: transfer consent belongs to the learner side.
  if not app_private.can_make_learning_decision(v_learner) then
    raise exception 'LEARNER_SIDE_TRANSFER_AUTHORITY_REQUIRED';
  end if;

  -- Deterministic lock order prevents source/destination transfer deadlocks.
  v_first := least(v_source_class, p_destination_class_id);
  v_second := greatest(v_source_class, p_destination_class_id);
  perform 1 from public.classes where id = v_first for update;
  perform 1 from public.classes where id = v_second for update;

  select responsible_teacher_account_id, organization_id
    into v_s_teacher, v_s_org
  from public.classes where id = v_source_class;

  select responsible_teacher_account_id, organization_id, capacity
    into v_d_teacher, v_d_org, v_capacity
  from public.classes
  where id = p_destination_class_id and state = 'active';
  if not found then raise exception 'DESTINATION_CLASS_NOT_ACTIVE'; end if;

  if v_s_teacher is distinct from v_d_teacher or v_s_org is distinct from v_d_org then
    raise exception 'TRANSFER_REQUIRES_SAME_PROVIDER';
  end if;
  if v_source_state <> 'active' then raise exception 'SOURCE_MEMBERSHIP_NOT_ACTIVE'; end if;

  if app_private.current_actor_class_access_blocked(v_source_class)
     or app_private.current_actor_class_access_blocked(p_destination_class_id)
     or app_private.class_provider_access_blocked(v_source_class)
     or app_private.class_provider_access_blocked(p_destination_class_id) then
    raise exception 'CLASS_ACCESS_RESTRICTED';
  end if;

  perform app_private.expire_pending_class_invitations(p_destination_class_id);

  if exists(
    select 1 from public.class_invitations
    where class_id = p_destination_class_id
      and learner_id = v_learner
      and state = 'pending'
  ) then raise exception 'DESTINATION_PENDING_INVITATION_EXISTS'; end if;

  if exists(
    select 1 from public.class_memberships
    where class_id = p_destination_class_id
      and learner_id = v_learner
      and state = 'active'
  ) then raise exception 'DESTINATION_MEMBERSHIP_ALREADY_ACTIVE'; end if;

  v_occupied := app_private.class_reserved_occupancy(p_destination_class_id);
  if v_occupied >= v_capacity then raise exception 'DESTINATION_CLASS_FULL'; end if;

  insert into public.class_memberships(class_id, learner_id, state)
  values (p_destination_class_id, v_learner, 'active')
  returning id into v_new_membership;

  update public.class_memberships
  set state = 'transferred',
      ended_at = now(),
      end_reason = 'transferred',
      transferred_to_membership_id = v_new_membership
  where id = p_source_membership_id;

  perform app_private.write_audit(
    v_actor, 'class.membership_transfer', 'class_membership',
    p_source_membership_id, v_learner, null,
    jsonb_build_object(
      'source_class_id', v_source_class,
      'destination_class_id', p_destination_class_id,
      'destination_membership_id', v_new_membership
    )
  );

  v_result := jsonb_build_object(
    'source_membership_id', p_source_membership_id,
    'source_state', 'transferred',
    'destination_membership_id', v_new_membership,
    'destination_class_id', p_destination_class_id
  );
  perform app_private.complete_human_idempotent_command(
    v_actor, 'transfer_learner', p_idempotency_key, v_result
  );
  return v_result;
end;
$$;

revoke all on function app_private.cmd_transfer_learner(uuid,uuid,text)
from public, anon, authenticated, service_role;
grant execute on function app_private.cmd_transfer_learner(uuid,uuid,text) to authenticated;
