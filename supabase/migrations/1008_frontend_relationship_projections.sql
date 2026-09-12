-- Raahi Learning V1.2 — frontend relationship/detail projections.
-- Read models only. They do not own state and remain authorization checked server-side.

create or replace function app_private.read_my_learning_requests()
returns setof jsonb
language sql
stable security definer
set search_path=''
as $$
  select jsonb_build_object(
    'learning_request_id',r.id,
    'learner_id',r.learner_id,
    'learner_name',l.display_name,
    'location_id',r.location_id,
    'location_name',loc.name,
    'need_text',r.need_text,
    'category',r.category,
    'mode_preference',r.mode_preference,
    'details',r.details,
    'timing_preference',r.timing_preference,
    'state',r.state,
    'close_reason',r.close_reason,
    'created_at',r.created_at,
    'updated_at',r.updated_at,
    'closed_at',r.closed_at
  )
  from public.learning_requests r
  join public.learners l on l.id=r.learner_id
  join public.locations loc on loc.id=r.location_id
  where app_private.can_access_learner(r.learner_id)
  order by r.updated_at desc,r.id;
$$;

create or replace function app_private.read_enquiry_thread(p_enquiry_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path=''
as $$
declare v_result jsonb;
begin
  if not app_private.can_read_enquiry(p_enquiry_id) then raise exception 'NOT_AUTHORIZED'; end if;

  select jsonb_build_object(
    'enquiry',jsonb_build_object(
      'enquiry_id',e.id,
      'learner_id',e.learner_id,
      'learner_name',lr.display_name,
      'location_id',e.location_id,
      'location_name',loc.name,
      'provider_account_id',e.provider_account_id,
      'provider_organization_id',e.provider_organization_id,
      'provider_name',coalesce(pa.display_name,o.name,'Provider'),
      'teaching_option_id',e.teaching_option_id,
      'teaching_option_title',t.title,
      'learning_request_id',e.learning_request_id,
      'source_type',e.source_type,
      'source_campaign_id',e.source_campaign_id,
      'state',e.state,
      'close_reason',e.close_reason,
      'created_at',e.created_at,
      'activated_at',e.activated_at,
      'closed_at',e.closed_at
    ),
    'messages',coalesce((
      select jsonb_agg(jsonb_build_object(
        'message_id',m.id,
        'sender_account_id',m.sender_account_id,
        'sender_name',coalesce(sa.display_name,case when m.sender_account_id is null then 'Raahi' else 'Account' end),
        'body',m.body,
        'message_type',m.message_type,
        'created_at',m.created_at
      ) order by m.created_at,m.id)
      from public.enquiry_messages m
      left join public.accounts sa on sa.id=m.sender_account_id
      where m.enquiry_id=e.id
    ),'[]'::jsonb),
    'trial_events',coalesce((
      select jsonb_agg(jsonb_build_object(
        'trial_event_id',tr.id,
        'proposed_by_account_id',tr.proposed_by_account_id,
        'scheduled_at',tr.scheduled_at,
        'status',tr.status,
        'created_at',tr.created_at,
        'updated_at',tr.updated_at
      ) order by tr.created_at,tr.id)
      from public.enquiry_trial_events tr where tr.enquiry_id=e.id
    ),'[]'::jsonb),
    'can_engage',app_private.is_enquiry_receiving_side(e.id) and e.state='pending',
    'can_message',e.state='active' and not app_private.enquiry_scope_blocked(e.id,'messaging')
  ) into v_result
  from public.enquiries e
  join public.learners lr on lr.id=e.learner_id
  join public.locations loc on loc.id=e.location_id
  left join public.accounts pa on pa.id=e.provider_account_id
  left join public.organizations o on o.id=e.provider_organization_id
  left join public.teaching_options t on t.id=e.teaching_option_id
  where e.id=p_enquiry_id;

  if v_result is null then raise exception 'ENQUIRY_NOT_FOUND'; end if;
  return v_result;
end;
$$;

create or replace function app_private.read_my_class_invitations()
returns setof jsonb
language sql
stable security definer
set search_path=''
as $$
  select jsonb_build_object(
    'invitation_id',i.id,
    'class_id',i.class_id,
    'class_title',c.title,
    'class_type',c.class_type,
    'class_state',c.state,
    'location_id',c.location_id,
    'location_name',loc.name,
    'learner_id',i.learner_id,
    'learner_name',lr.display_name,
    'provider_name',coalesce(a.display_name,o.name,'Provider'),
    'state',i.state,
    'display_state',case when i.state='pending' and i.expires_at<=now() then 'expired' else i.state end,
    'expires_at',i.expires_at,
    'fee_display_text',i.fee_display_text,
    'created_at',i.created_at,
    'resolved_at',i.resolved_at
  )
  from public.class_invitations i
  join public.classes c on c.id=i.class_id
  join public.learners lr on lr.id=i.learner_id
  left join public.locations loc on loc.id=c.location_id
  left join public.accounts a on a.id=c.responsible_teacher_account_id
  left join public.organizations o on o.id=c.organization_id
  where app_private.can_read_class_invitation(i.id)
  order by case i.state when 'pending' then 0 else 1 end,i.created_at desc,i.id;
$$;

create or replace function app_private.read_activity_detail(p_activity_id uuid,p_learner_id uuid default null)
returns jsonb
language plpgsql
stable security definer
set search_path=''
as $$
declare v_result jsonb; v_class_id uuid; v_provider boolean;
begin
  if not app_private.can_read_activity(p_activity_id) then raise exception 'NOT_AUTHORIZED'; end if;
  select class_id into v_class_id from public.activities where id=p_activity_id;
  if v_class_id is null then raise exception 'ACTIVITY_NOT_FOUND'; end if;
  v_provider:=app_private.can_read_class_as_provider(v_class_id);
  if p_learner_id is not null and not v_provider and not app_private.can_access_learner(p_learner_id) then
    raise exception 'NOT_AUTHORIZED';
  end if;

  select jsonb_build_object(
    'activity',jsonb_build_object(
      'activity_id',a.id,'class_id',a.class_id,'display_type',a.display_type,'title',a.title,
      'instructions',a.instructions,'due_at',a.due_at,'submission_required',a.submission_required,
      'state',a.state,'created_at',a.created_at,'updated_at',a.updated_at
    ),
    'materials',coalesce((
      select jsonb_agg(jsonb_build_object(
        'material_id',m.id,'title',m.title,'description',m.description,'resource_type',m.resource_type,
        'file_asset_id',m.file_asset_id,'external_url',m.external_url,'text_content',m.text_content
      ) order by m.updated_at desc,m.id)
      from public.activity_material_links aml join public.materials m on m.id=aml.material_id
      where aml.activity_id=a.id and app_private.can_read_material(m.id)
    ),'[]'::jsonb),
    'submission',case when p_learner_id is null then null else (
      select jsonb_build_object(
        'submission_id',s.id,'learner_id',s.learner_id,'current_status',s.current_status,
        'created_at',s.created_at,'updated_at',s.updated_at,
        'revisions',coalesce((
          select jsonb_agg(jsonb_build_object(
            'revision_id',sr.id,'revision_number',sr.revision_number,'performed_by_account_id',sr.performed_by_account_id,
            'text_response',sr.text_response,'file_asset_id',sr.file_asset_id,'submitted_at',sr.submitted_at,
            'review_outcome',sr.review_outcome,'teacher_feedback',sr.teacher_feedback,'reviewed_at',sr.reviewed_at
          ) order by sr.revision_number)
          from public.submission_revisions sr where sr.submission_id=s.id
        ),'[]'::jsonb)
      )
      from public.submissions s where s.activity_id=a.id and s.learner_id=p_learner_id
    ) end
  ) into v_result
  from public.activities a where a.id=p_activity_id;

  return v_result;
end;
$$;

create or replace function app_private.read_my_teacher_workspace()
returns jsonb
language plpgsql
stable security definer
set search_path=''
as $$
declare v_actor uuid:=app_private.current_account_id(); v_result jsonb;
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if not app_private.has_account_capability('teach') then raise exception 'TEACH_CAPABILITY_REQUIRED'; end if;
  select jsonb_build_object(
    'profile',(select jsonb_build_object('headline',p.headline,'bio',p.bio,'experience_summary',p.experience_summary,'visibility_status',p.visibility_status,'updated_at',p.updated_at) from public.teacher_profiles p where p.account_id=v_actor),
    'teaching_options',coalesce((
      select jsonb_agg(jsonb_build_object(
        'teaching_option_id',t.id,'title',t.title,'category',t.category,'description',t.description,'teaching_mode',t.teaching_mode,
        'area_or_venue_text',t.area_or_venue_text,'fee_display_text',t.fee_display_text,'availability_status',t.availability_status,
        'locations',coalesce((select jsonb_agg(jsonb_build_object('location_id',l.id,'name',l.name,'state',l.state) order by l.name,l.id)
          from public.teaching_option_locations x join public.locations l on l.id=x.location_id where x.teaching_option_id=t.id),'[]'::jsonb)
      ) order by t.updated_at desc,t.id)
      from public.teaching_options t where t.teacher_account_id=v_actor
    ),'[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$$;

revoke all on function app_private.read_my_learning_requests(),app_private.read_enquiry_thread(uuid),app_private.read_my_class_invitations(),app_private.read_activity_detail(uuid,uuid),app_private.read_my_teacher_workspace() from public,anon,authenticated,service_role;
grant execute on function app_private.read_my_learning_requests(),app_private.read_enquiry_thread(uuid),app_private.read_my_class_invitations(),app_private.read_activity_detail(uuid,uuid),app_private.read_my_teacher_workspace() to authenticated;

create or replace function public.get_my_learning_requests() returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.read_my_learning_requests(); $$;
create or replace function public.get_enquiry_thread(p_enquiry_id uuid) returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.read_enquiry_thread(p_enquiry_id); $$;
create or replace function public.get_my_class_invitations() returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.read_my_class_invitations(); $$;
create or replace function public.get_activity_detail(p_activity_id uuid,p_learner_id uuid default null) returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.read_activity_detail(p_activity_id,p_learner_id); $$;
create or replace function public.get_my_teacher_workspace() returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.read_my_teacher_workspace(); $$;

revoke all on function public.get_my_learning_requests(),public.get_enquiry_thread(uuid),public.get_my_class_invitations(),public.get_activity_detail(uuid,uuid),public.get_my_teacher_workspace() from public,anon,authenticated,service_role;
grant execute on function public.get_my_learning_requests(),public.get_enquiry_thread(uuid),public.get_my_class_invitations(),public.get_activity_detail(uuid,uuid),public.get_my_teacher_workspace() to authenticated;
