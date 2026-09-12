-- Raahi Learning V1.2 — secure read projections for frozen UI surfaces.

create or replace function app_private.read_live_locations()
returns setof jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('location_id',l.id,'name',l.name,'slug',l.slug,'region',l.region,'state_or_province',l.state_or_province,'country_code',l.country_code,'state',l.state)
  from public.locations l where l.state='live' order by l.name,l.id;
$$;

create or replace function app_private.read_my_classes()
returns setof jsonb language sql stable security definer set search_path='' as $$
  with actor as (select app_private.current_account_id() id),
  learner_rows as (
    select c.id class_id,c.title,c.class_type,c.state class_state,c.location_id,m.id membership_id,m.state membership_state,
           m.learner_id,l.display_name learner_name,'learner'::text context_kind
    from actor a
    join public.account_learner_access ala on ala.account_id=a.id and ala.status='active'
    join public.class_memberships m on m.learner_id=ala.learner_id and m.state in ('active','completed','transferred','left')
    join public.classes c on c.id=m.class_id
    join public.learners l on l.id=m.learner_id
    where not app_private.current_actor_class_access_blocked(c.id)
  ),
  provider_rows as (
    select c.id class_id,c.title,c.class_type,c.state class_state,c.location_id,null::uuid membership_id,null::text membership_state,
           null::uuid learner_id,null::text learner_name,'provider'::text context_kind
    from public.classes c where app_private.can_read_class_as_provider(c.id)
  )
  select jsonb_build_object('class_id',x.class_id,'title',x.title,'class_type',x.class_type,'class_state',x.class_state,'location_id',x.location_id,
    'context_kind',x.context_kind,'membership_id',x.membership_id,'membership_state',x.membership_state,'learner_id',x.learner_id,'learner_name',x.learner_name)
  from (select * from learner_rows union all select * from provider_rows) x
  order by x.class_state,x.title,x.class_id,x.context_kind;
$$;

create or replace function app_private.read_my_enquiries()
returns setof jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('enquiry_id',e.id,'learner_id',e.learner_id,'location_id',e.location_id,'provider_account_id',e.provider_account_id,
    'provider_organization_id',e.provider_organization_id,'teaching_option_id',e.teaching_option_id,'learning_request_id',e.learning_request_id,
    'source_type',e.source_type,'source_campaign_id',e.source_campaign_id,'state',e.state,'created_at',e.created_at,'activated_at',e.activated_at,'closed_at',e.closed_at,
    'last_message_at',(select max(m.created_at) from public.enquiry_messages m where m.enquiry_id=e.id))
  from public.enquiries e where app_private.can_read_enquiry(e.id)
  order by coalesce((select max(m.created_at) from public.enquiry_messages m where m.enquiry_id=e.id),e.created_at) desc,e.id;
$$;

create or replace function app_private.read_class_learning_overview(p_class_id uuid,p_learner_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_provider boolean; v_learner_allowed boolean:=false; v_membership_state text; v_result jsonb;
begin
  v_provider:=app_private.can_read_class_as_provider(p_class_id);
  if p_learner_id is not null then
    select state into v_membership_state from public.class_memberships where class_id=p_class_id and learner_id=p_learner_id order by joined_at desc limit 1;
    v_learner_allowed:=app_private.can_access_learner(p_learner_id) and v_membership_state in ('active','completed','transferred')
      and not app_private.current_actor_class_access_blocked(p_class_id) and not app_private.class_provider_access_blocked(p_class_id);
  end if;
  if not v_provider and not v_learner_allowed then raise exception 'NOT_AUTHORIZED'; end if;

  select jsonb_build_object(
    'class',jsonb_build_object('class_id',c.id,'title',c.title,'class_type',c.class_type,'capacity',c.capacity,'state',c.state,'location_id',c.location_id,'organization_id',c.organization_id,'responsible_teacher_account_id',c.responsible_teacher_account_id),
    'learner_id',p_learner_id,'membership_state',v_membership_state,
    'sessions',coalesce((select jsonb_agg(jsonb_build_object('session_id',s.id,'starts_at',s.starts_at,'ends_at',s.ends_at,'delivery_mode',s.delivery_mode,'meeting_or_location_text',s.meeting_or_location_text,'cancelled_at',s.cancelled_at,'cancel_reason',s.cancel_reason) order by s.starts_at) from public.class_sessions s where s.class_id=c.id),'[]'::jsonb),
    'materials',coalesce((select jsonb_agg(jsonb_build_object('material_id',m.id,'title',m.title,'description',m.description,'resource_type',m.resource_type,'file_asset_id',m.file_asset_id,'external_url',m.external_url) order by m.updated_at desc) from public.material_class_links ml join public.materials m on m.id=ml.material_id where ml.class_id=c.id),'[]'::jsonb),
    'posts',coalesce((select jsonb_agg(jsonb_build_object('post_id',p.id,'author_account_id',p.author_account_id,'learner_id',p.learner_id,'post_type',p.post_type,'body',p.body,'importance',p.importance,'comments_enabled',p.comments_enabled,'created_at',p.created_at) order by p.created_at desc) from public.class_posts p where p.class_id=c.id and p.visibility_status='visible'),'[]'::jsonb),
    'activities',coalesce((select jsonb_agg(jsonb_build_object('activity_id',a.id,'display_type',a.display_type,'title',a.title,'instructions',a.instructions,'due_at',a.due_at,'submission_required',a.submission_required,'state',a.state) order by a.created_at desc) from public.activities a where a.class_id=c.id and a.state<>'draft'),'[]'::jsonb),
    'tests',coalesce((select jsonb_agg(jsonb_build_object('test_id',t.id,'title',t.title,'available_from',t.available_from,'closes_at',t.closes_at,'duration_seconds',t.duration_seconds,'state',t.state,'results_visible',t.results_visible,
       'display_state',case when t.state='closed' or (t.closes_at is not null and now()>t.closes_at) then 'closed' when t.available_from is not null and now()<t.available_from then 'upcoming' else 'available' end) order by t.created_at desc) from public.tests t where t.class_id=c.id and t.state<>'draft'),'[]'::jsonb)
  ) into v_result from public.classes c where c.id=p_class_id;
  if v_result is null then raise exception 'CLASS_NOT_FOUND'; end if;
  return v_result;
end; $$;

create or replace function app_private.read_teacher_class_management(p_class_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_result jsonb;
begin
  if not app_private.can_read_class_as_provider(p_class_id) then raise exception 'NOT_AUTHORIZED'; end if;
  select jsonb_build_object(
    'class',jsonb_build_object('class_id',c.id,'title',c.title,'class_type',c.class_type,'capacity',c.capacity,'state',c.state,'location_id',c.location_id,'organization_id',c.organization_id),
    'members',coalesce((select jsonb_agg(jsonb_build_object('membership_id',m.id,'learner_id',m.learner_id,'learner_name',l.display_name,'state',m.state,'joined_at',m.joined_at,'ended_at',m.ended_at) order by l.display_name,m.joined_at) from public.class_memberships m join public.learners l on l.id=m.learner_id where m.class_id=c.id and m.state in ('active','completed','transferred','left','removed')),'[]'::jsonb),
    'pending_invitations',coalesce((select jsonb_agg(jsonb_build_object('invitation_id',i.id,'learner_id',i.learner_id,'learner_name',l.display_name,'expires_at',i.expires_at,'fee_display_text',i.fee_display_text) order by i.created_at) from public.class_invitations i join public.learners l on l.id=i.learner_id where i.class_id=c.id and i.state='pending' and i.expires_at>now()),'[]'::jsonb)
  ) into v_result from public.classes c where c.id=p_class_id;
  if v_result is null then raise exception 'CLASS_NOT_FOUND'; end if;
  return v_result;
end; $$;

create or replace function app_private.read_local_manager_overview(p_location_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not (app_private.has_account_capability('platform_admin') or app_private.has_location_staff_scope(p_location_id,'local_manager')) then raise exception 'NOT_AUTHORIZED'; end if;
  return jsonb_build_object(
    'location_id',p_location_id,
    'teaching_options',(select count(*) from public.teaching_option_locations tl join public.teaching_options t on t.id=tl.teaching_option_id where tl.location_id=p_location_id and t.availability_status<>'no_longer_offered'),
    'open_learning_requests',(select count(*) from public.learning_requests r where r.location_id=p_location_id and r.state='open'),
    'active_classes',(select count(*) from public.classes c where c.location_id=p_location_id and c.state='active'),
    'published_community_posts',(select count(*) from public.community_posts p where p.location_id=p_location_id and p.visibility_status='published'),
    'open_reports',(select count(*) from public.reports r where r.location_id=p_location_id and r.status in ('open','under_review')),
    'live_ad_placements',(select count(*) from public.ad_placements p where p.location_id=p_location_id and p.state='live')
  );
end; $$;

create or replace function app_private.read_local_manager_reports(p_location_id uuid,p_limit integer default 100)
returns setof jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not (app_private.has_account_capability('platform_admin') or app_private.has_location_staff_scope(p_location_id,'local_manager')) then raise exception 'NOT_AUTHORIZED'; end if;
  return query
  select jsonb_build_object('report_id',r.id,'reporter_account_id',r.reporter_account_id,'context_learner_id',r.context_learner_id,'target_type',r.target_type,'target_id',r.target_id,'reason_code',r.reason_code,'details',r.details,'status',r.status,'created_at',r.created_at,'resolved_at',r.resolved_at)
  from public.reports r where r.location_id=p_location_id order by r.created_at desc,r.id limit least(greatest(coalesce(p_limit,100),1),500);
end; $$;

create or replace function app_private.read_platform_operations_summary()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not app_private.has_account_capability('platform_admin') then raise exception 'NOT_AUTHORIZED'; end if;
  return jsonb_build_object(
    'locations',(select count(*) from public.locations),
    'accounts',(select count(*) from public.accounts where lifecycle_status<>'closed'),
    'learners',(select count(*) from public.learners),
    'open_reports',(select count(*) from public.reports where status in ('open','under_review')),
    'submitted_campaigns',(select count(*) from public.ad_campaigns where state='submitted'),
    'live_ad_placements',(select count(*) from public.ad_placements where state='live'),
    'audit_events',(select count(*) from public.audit_log)
  );
end; $$;

create or replace function app_private.read_platform_audit(p_limit integer default 100)
returns setof jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not app_private.has_account_capability('platform_admin') then raise exception 'NOT_AUTHORIZED'; end if;
  return query select jsonb_build_object('audit_id',a.id,'actor_kind',a.actor_kind,'actor_account_id',a.actor_account_id,'action_type',a.action_type,'target_type',a.target_type,'target_id',a.target_id,'learner_id',a.learner_id,'reason',a.reason,'metadata',a.metadata,'created_at',a.created_at)
    from public.audit_log a order by a.created_at desc,a.id limit least(greatest(coalesce(p_limit,100),1),500);
end; $$;

revoke all on function app_private.read_live_locations(),app_private.read_my_classes(),app_private.read_my_enquiries(),app_private.read_class_learning_overview(uuid,uuid),app_private.read_teacher_class_management(uuid),app_private.read_local_manager_overview(uuid),app_private.read_local_manager_reports(uuid,integer),app_private.read_platform_operations_summary(),app_private.read_platform_audit(integer) from public,anon,authenticated,service_role;
grant execute on function app_private.read_live_locations(),app_private.read_my_classes(),app_private.read_my_enquiries(),app_private.read_class_learning_overview(uuid,uuid),app_private.read_teacher_class_management(uuid),app_private.read_local_manager_overview(uuid),app_private.read_local_manager_reports(uuid,integer),app_private.read_platform_operations_summary(),app_private.read_platform_audit(integer) to authenticated;

create or replace function public.list_live_locations() returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.read_live_locations(); $$;
create or replace function public.get_my_classes() returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.read_my_classes(); $$;
create or replace function public.get_my_enquiries() returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.read_my_enquiries(); $$;
create or replace function public.get_class_learning_overview(p_class_id uuid,p_learner_id uuid default null) returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.read_class_learning_overview(p_class_id,p_learner_id); $$;
create or replace function public.get_teacher_class_management(p_class_id uuid) returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.read_teacher_class_management(p_class_id); $$;
create or replace function public.get_local_manager_overview(p_location_id uuid) returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.read_local_manager_overview(p_location_id); $$;
create or replace function public.get_local_manager_reports(p_location_id uuid,p_limit integer default 100) returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.read_local_manager_reports(p_location_id,p_limit); $$;
create or replace function public.get_platform_operations_summary() returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.read_platform_operations_summary(); $$;
create or replace function public.get_platform_audit(p_limit integer default 100) returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.read_platform_audit(p_limit); $$;
revoke all on function public.list_live_locations(),public.get_my_classes(),public.get_my_enquiries(),public.get_class_learning_overview(uuid,uuid),public.get_teacher_class_management(uuid),public.get_local_manager_overview(uuid),public.get_local_manager_reports(uuid,integer),public.get_platform_operations_summary(),public.get_platform_audit(integer) from public,anon,authenticated,service_role;
grant execute on function public.list_live_locations(),public.get_my_classes(),public.get_my_enquiries(),public.get_class_learning_overview(uuid,uuid),public.get_teacher_class_management(uuid),public.get_local_manager_overview(uuid),public.get_local_manager_reports(uuid,integer),public.get_platform_operations_summary(),public.get_platform_audit(integer) to authenticated;
