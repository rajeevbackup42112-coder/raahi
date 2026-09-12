-- Raahi Learning V1.2 — secure Class + Learner thread read projection for UI integration.

create or replace function app_private.read_class_learner_thread(p_class_id uuid,p_learner_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path=''
as $$
declare v_thread uuid; v_result jsonb;
begin
  select t.id into v_thread
  from public.class_learner_threads t
  where t.class_id=p_class_id and t.learner_id=p_learner_id;

  -- A thread may not exist until the first message. Authorization is still derived
  -- from Class + Learner relationship rather than from knowing a thread id.
  if app_private.can_read_class_as_provider(p_class_id) then
    if app_private.current_actor_class_access_blocked(p_class_id) or app_private.class_provider_access_blocked(p_class_id) then
      raise exception 'NOT_AUTHORIZED';
    end if;
  elsif not (
    app_private.can_access_learner(p_learner_id)
    and exists(select 1 from public.class_memberships m where m.class_id=p_class_id and m.learner_id=p_learner_id and m.state in ('active','completed','transferred'))
    and not app_private.current_actor_class_access_blocked(p_class_id)
    and not app_private.class_provider_access_blocked(p_class_id)
  ) then
    raise exception 'NOT_AUTHORIZED';
  end if;

  select jsonb_build_object(
    'thread_id',v_thread,
    'class_id',p_class_id,
    'learner_id',p_learner_id,
    'learner_name',(select l.display_name from public.learners l where l.id=p_learner_id),
    'class_title',(select c.title from public.classes c where c.id=p_class_id),
    'messages',coalesce((
      select jsonb_agg(jsonb_build_object(
        'message_id',m.id,'sender_account_id',m.sender_account_id,'sender_name',a.display_name,
        'body',m.body,'created_at',m.created_at
      ) order by m.created_at,m.id)
      from public.class_learner_messages m
      join public.accounts a on a.id=m.sender_account_id
      where m.thread_id=v_thread
    ),'[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function app_private.read_class_learner_thread(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function app_private.read_class_learner_thread(uuid,uuid) to authenticated;

create or replace function public.get_class_learner_thread(p_class_id uuid,p_learner_id uuid)
returns jsonb
language sql
stable security invoker
set search_path=''
as $$ select app_private.read_class_learner_thread(p_class_id,p_learner_id); $$;

revoke all on function public.get_class_learner_thread(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_class_learner_thread(uuid,uuid) to authenticated;
