-- Raahi Learning V1.3 — Class / Membership lifecycle side-effect closure (SE-05A..SE-05E)
-- Notifications remain best-effort derived records. Membership/Class state remains authoritative.

create or replace function app_private.trg_notify_class_membership_state_update()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_actor uuid:=app_private.current_account_id();
  v_destination_class uuid;
begin
  if old.state='active' and new.state='left' then
    perform app_private.notify_class_provider_accounts(
      new.class_id,v_actor,
      'class_membership_left','class_membership',new.id,
      'Learner left Class','A learner left a Class.',
      jsonb_build_object(
        'class_id',new.class_id,
        'learner_id',new.learner_id,
        'membership_id',new.id
      )
    );

  elsif old.state='active' and new.state='removed' then
    perform app_private.notify_learner_accounts(
      new.learner_id,v_actor,
      'class_membership_removed','class_membership',new.id,
      'Removed from Class','A learning provider removed this learner from a Class.',
      jsonb_build_object(
        'class_id',new.class_id,
        'learner_id',new.learner_id,
        'membership_id',new.id
      )
    );

  elsif old.state='active' and new.state='transferred' then
    select class_id into v_destination_class
    from public.class_memberships
    where id=new.transferred_to_membership_id;

    if v_destination_class is not null then
      perform app_private.notify_class_provider_accounts(
        v_destination_class,v_actor,
        'class_membership_transferred','class_membership',new.id,
        'Learner moved Class','A learner moved to another Class.',
        jsonb_build_object(
          'learner_id',new.learner_id,
          'source_class_id',new.class_id,
          'destination_class_id',v_destination_class,
          'source_membership_id',new.id,
          'destination_membership_id',new.transferred_to_membership_id
        )
      );

      perform app_private.notify_learner_accounts(
        new.learner_id,v_actor,
        'class_membership_transferred','class_membership',new.id,
        'Class changed','This learner moved to another Class.',
        jsonb_build_object(
          'learner_id',new.learner_id,
          'source_class_id',new.class_id,
          'destination_class_id',v_destination_class,
          'source_membership_id',new.id,
          'destination_membership_id',new.transferred_to_membership_id
        )
      );
    end if;

  elsif old.state='active' and new.state='completed' then
    perform app_private.notify_learner_accounts(
      new.learner_id,v_actor,
      'class_completed','class_membership',new.id,
      'Class completed','This Class has been completed and moved to Past learning.',
      jsonb_build_object(
        'class_id',new.class_id,
        'learner_id',new.learner_id,
        'membership_id',new.id
      )
    );
  end if;

  return new;
end;
$$;

create or replace function app_private.cmd_leave_class(
  p_membership_id uuid,
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
  v_learner uuid;
  v_state text;
  v_result jsonb;
  v_changed boolean:=false;
begin
  v_fp:=app_private.request_fingerprint(jsonb_build_object('membership_id',p_membership_id));
  v_gate:=app_private.begin_human_idempotent_command(
    v_actor,'leave_class',p_idempotency_key,v_fp
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select class_id,learner_id,state into v_class,v_learner,v_state
  from public.class_memberships
  where id=p_membership_id
  for update;
  if not found then raise exception 'MEMBERSHIP_NOT_FOUND'; end if;
  if not app_private.can_make_learning_decision(v_learner) then raise exception 'NOT_AUTHORIZED'; end if;

  if v_state='active' then
    update public.class_memberships
    set state='left',ended_at=now(),end_reason='learner_left'
    where id=p_membership_id;
    v_changed:=true;
    v_result:=jsonb_build_object('membership_id',p_membership_id,'state','left','changed',true);
  elsif v_state='left' then
    v_result:=jsonb_build_object('membership_id',p_membership_id,'state','left','changed',false);
  else
    raise exception 'MEMBERSHIP_NOT_ACTIVE';
  end if;

  if v_changed then
    perform app_private.write_audit(
      v_actor,'class.membership_leave','class_membership',p_membership_id,v_learner,null,
      jsonb_build_object('class_id',v_class)
    );
  end if;

  perform app_private.complete_human_idempotent_command(
    v_actor,'leave_class',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;

create or replace function app_private.cmd_activate_class(
  p_class_id uuid,
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
  v_state text;
  v_result jsonb;
  v_changed boolean:=false;
begin
  if not app_private.can_manage_class(p_class_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if app_private.current_actor_class_access_blocked(p_class_id)
     or app_private.class_provider_access_blocked(p_class_id)
  then raise exception 'CLASS_ACCESS_RESTRICTED'; end if;

  v_fp:=app_private.request_fingerprint(jsonb_build_object('class_id',p_class_id));
  v_gate:=app_private.begin_human_idempotent_command(
    v_actor,'activate_class',p_idempotency_key,v_fp
  );
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select state into v_state
  from public.classes
  where id=p_class_id
  for update;
  if not found then raise exception 'CLASS_NOT_FOUND'; end if;

  if v_state='active' then
    v_result:=jsonb_build_object('class_id',p_class_id,'state','active','already_active',true);
  elsif v_state<>'draft' then
    raise exception 'CLASS_NOT_DRAFT';
  else
    update public.classes set state='active' where id=p_class_id;
    v_changed:=true;
    v_result:=jsonb_build_object('class_id',p_class_id,'state','active','already_active',false);
  end if;

  if v_changed then
    perform app_private.write_audit(
      v_actor,'class.activate','class',p_class_id,null,null,'{}'::jsonb
    );
  end if;

  perform app_private.complete_human_idempotent_command(
    v_actor,'activate_class',p_idempotency_key,v_result
  );
  return v_result;
end;
$$;

drop trigger if exists notify_class_membership_state_update on public.class_memberships;
create trigger notify_class_membership_state_update
after update of state,transferred_to_membership_id on public.class_memberships
for each row execute function app_private.trg_notify_class_membership_state_update();

revoke all on function app_private.trg_notify_class_membership_state_update()
from public,anon,authenticated,service_role;
