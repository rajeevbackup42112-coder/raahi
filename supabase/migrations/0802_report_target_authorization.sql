-- Raahi Learning V1.2 — prevent private-object report IDOR while preserving safety reporting.

create or replace function app_private.can_report_target(p_target_type text,p_target_id uuid,p_location_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_learner uuid; v_author uuid; v_post uuid;
begin
  if app_private.has_account_capability('platform_admin') or app_private.has_account_capability('safety_reviewer') then return true; end if;
  case p_target_type
    when 'account' then return exists(select 1 from public.accounts where id=p_target_id);
    when 'organization' then return exists(select 1 from public.organizations where id=p_target_id);
    when 'teaching_option' then return app_private.is_teaching_option_public(p_target_id,false) or app_private.can_manage_teaching_option(p_target_id);
    when 'learning_request' then
      select learner_id into v_learner from public.learning_requests where id=p_target_id;
      return app_private.learning_request_publicly_visible(p_target_id) or (v_learner is not null and app_private.can_read_learner_relationship(v_learner));
    when 'enquiry' then return app_private.can_read_enquiry(p_target_id);
    when 'class' then return app_private.can_read_class_shared(p_target_id) or app_private.can_read_class_as_provider(p_target_id);
    when 'community_post' then
      select author_account_id into v_author from public.community_posts where id=p_target_id;
      return v_author=app_private.current_account_id() or app_private.get_community_post_projection(p_target_id) is not null or app_private.can_moderate_location(p_location_id);
    when 'community_comment' then
      select c.author_account_id,c.post_id into v_author,v_post from public.community_comments c where c.id=p_target_id;
      return v_author=app_private.current_account_id() or (v_post is not null and app_private.get_community_post_projection(v_post) is not null) or app_private.can_moderate_location(p_location_id);
    else return false;
  end case;
end; $$;

create or replace function app_private.cmd_report_subject(p_target_type text,p_target_id uuid,p_context_learner_id uuid,p_location_id uuid,p_reason_code text,p_details text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(false); v_gate jsonb; v_fp text; v_location uuid; v_report uuid; v_result jsonb;
begin
  if not app_private.report_target_exists(p_target_type,p_target_id) then raise exception 'REPORT_TARGET_NOT_FOUND'; end if;
  v_location:=app_private.derive_report_location(p_target_type,p_target_id,p_location_id);
  if not app_private.can_report_target(p_target_type,p_target_id,v_location) then raise exception 'REPORT_TARGET_NOT_AUTHORIZED'; end if;
  if p_context_learner_id is not null and not (app_private.can_access_learner(p_context_learner_id) or app_private.has_account_capability('safety_reviewer') or app_private.has_account_capability('platform_admin')) then raise exception 'INVALID_REPORT_LEARNER_CONTEXT'; end if;
  if p_reason_code is null or char_length(btrim(p_reason_code)) not between 1 and 120 then raise exception 'INVALID_REPORT_REASON'; end if;
  if p_details is not null and char_length(p_details)>8000 then raise exception 'REPORT_DETAILS_TOO_LONG'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('target_type',p_target_type,'target_id',p_target_id,'context_learner_id',p_context_learner_id,'location_id',v_location,'reason_code',p_reason_code,'details',p_details));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'report_subject',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.reports(reporter_account_id,context_learner_id,location_id,target_type,target_id,reason_code,details,evidence_snapshot)
  values(v_actor,p_context_learner_id,v_location,p_target_type,p_target_id,btrim(p_reason_code),nullif(btrim(p_details),''),jsonb_build_object('target_type',p_target_type,'target_id',p_target_id)) returning id into v_report;
  v_result:=jsonb_build_object('report_id',v_report,'status','open');
  perform app_private.complete_human_idempotent_command(v_actor,'report_subject',p_idempotency_key,v_result); return v_result;
end; $$;

revoke all on function app_private.can_report_target(text,uuid,uuid),app_private.cmd_report_subject(text,uuid,uuid,uuid,text,text,text) from public,anon,authenticated,service_role;
grant execute on function app_private.cmd_report_subject(text,uuid,uuid,uuid,text,text,text) to authenticated;
