-- Raahi Learning V1.3 — contextual Messages inbox + narrow Organization responsible-teacher picker
-- Read-only projections only. No domain state or authority model is changed.

create or replace function app_private.read_eligible_organization_class_teachers(
  p_organization_id uuid
)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (
    app_private.has_organization_member_capability(p_organization_id,'manage_classes')
    or app_private.has_account_capability('platform_admin')
  ) then
    raise exception 'NOT_AUTHORIZED';
  end if;

  return query
  select jsonb_build_object(
    'organization_member_id',om.id,
    'organization_id',om.organization_id,
    'account_id',om.account_id,
    'display_name',a.display_name
  )
  from public.organization_members om
  join public.accounts a on a.id=om.account_id and a.lifecycle_status='active'
  where om.organization_id=p_organization_id
    and om.status='active'
    and exists (
      select 1
      from public.organization_member_capabilities c
      where c.organization_member_id=om.id
        and c.capability_code='manage_classes'
    )
  order by a.display_name,om.id;
end;
$$;

create or replace function app_private.read_my_conversations()
returns setof jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with enquiry_rows as (
    select
      'enquiry'::text conversation_kind,
      e.id conversation_id,
      e.id enquiry_id,
      null::uuid thread_id,
      null::uuid class_id,
      e.learner_id,
      lr.display_name learner_name,
      null::text class_title,
      coalesce(pa.display_name,o.name,'Provider') provider_name,
      e.state context_state,
      e.created_at context_created_at,
      lm.created_at last_message_at,
      lm.body last_message_preview
    from public.enquiries e
    join public.learners lr on lr.id=e.learner_id
    left join public.accounts pa on pa.id=e.provider_account_id
    left join public.organizations o on o.id=e.provider_organization_id
    left join lateral (
      select m.created_at,m.body
      from public.enquiry_messages m
      where m.enquiry_id=e.id
      order by m.created_at desc,m.id desc
      limit 1
    ) lm on true
    where app_private.can_read_enquiry(e.id)
  ),
  class_rows as (
    select
      'class_learner'::text conversation_kind,
      t.id conversation_id,
      null::uuid enquiry_id,
      t.id thread_id,
      t.class_id,
      t.learner_id,
      lr.display_name learner_name,
      c.title class_title,
      coalesce(a.display_name,o.name,'Teacher') provider_name,
      c.state context_state,
      t.created_at context_created_at,
      lm.created_at last_message_at,
      lm.body last_message_preview
    from public.class_learner_threads t
    join public.classes c on c.id=t.class_id
    join public.learners lr on lr.id=t.learner_id
    left join public.accounts a on a.id=c.responsible_teacher_account_id
    left join public.organizations o on o.id=c.organization_id
    left join lateral (
      select m.created_at,m.body
      from public.class_learner_messages m
      where m.thread_id=t.id
      order by m.created_at desc,m.id desc
      limit 1
    ) lm on true
    where app_private.can_read_class_thread(t.id)
  ),
  all_rows as (
    select * from enquiry_rows
    union all
    select * from class_rows
  )
  select jsonb_build_object(
    'conversation_kind',x.conversation_kind,
    'conversation_id',x.conversation_id,
    'enquiry_id',x.enquiry_id,
    'thread_id',x.thread_id,
    'class_id',x.class_id,
    'learner_id',x.learner_id,
    'learner_name',x.learner_name,
    'class_title',x.class_title,
    'provider_name',x.provider_name,
    'context_state',x.context_state,
    'last_message_at',x.last_message_at,
    'last_message_preview',x.last_message_preview
  )
  from all_rows x
  order by coalesce(x.last_message_at,x.context_created_at) desc,x.conversation_kind,x.conversation_id;
$$;

revoke all on function app_private.read_eligible_organization_class_teachers(uuid) from public,anon,authenticated,service_role;
revoke all on function app_private.read_my_conversations() from public,anon,authenticated,service_role;
grant execute on function app_private.read_eligible_organization_class_teachers(uuid) to authenticated;
grant execute on function app_private.read_my_conversations() to authenticated;

create or replace function public.get_eligible_organization_class_teachers(
  p_organization_id uuid
)
returns setof jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select * from app_private.read_eligible_organization_class_teachers(p_organization_id);
$$;

create or replace function public.get_my_conversations()
returns setof jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select * from app_private.read_my_conversations();
$$;

revoke all on function public.get_eligible_organization_class_teachers(uuid) from public,anon,authenticated,service_role;
revoke all on function public.get_my_conversations() from public,anon,authenticated,service_role;
grant execute on function public.get_eligible_organization_class_teachers(uuid) to authenticated;
grant execute on function public.get_my_conversations() to authenticated;
