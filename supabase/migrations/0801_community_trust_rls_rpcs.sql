-- Raahi Learning V1.2 — Community, Reports, Blocks and exact verification commands.

create or replace function app_private.account_has_location_connection(p_location_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.account_location_preferences p where p.account_id=app_private.current_account_id() and p.selected_location_id=p_location_id)
    or app_private.has_location_staff_scope(p_location_id,'local_manager')
    or exists(
      select 1 from public.teaching_options t
      join public.teaching_option_locations x on x.teaching_option_id=t.id and x.location_id=p_location_id
      where t.teacher_account_id=app_private.current_account_id()
    )
    or exists(
      select 1 from public.organization_members om
      join public.teaching_options t on t.organization_id=om.organization_id
      join public.teaching_option_locations x on x.teaching_option_id=t.id and x.location_id=p_location_id
      where om.account_id=app_private.current_account_id() and om.status='active'
    )
    or exists(
      select 1 from public.account_learner_access ala
      join public.class_memberships m on m.learner_id=ala.learner_id
      join public.classes c on c.id=m.class_id and c.location_id=p_location_id
      where ala.account_id=app_private.current_account_id() and ala.status='active'
    );
$$;

create or replace function app_private.can_moderate_location(p_location_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select app_private.has_account_capability('platform_admin')
    or app_private.has_account_capability('safety_reviewer')
    or (p_location_id is not null and app_private.has_location_staff_scope(p_location_id,'local_manager'));
$$;

create or replace function app_private.community_blocked_between(p_other_account_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.blocks b
    where b.state='active'
      and ((b.blocker_account_id=app_private.current_account_id() and b.blocked_account_id=p_other_account_id)
        or (b.blocked_account_id=app_private.current_account_id() and b.blocker_account_id=p_other_account_id))
  );
$$;

create or replace function app_private.cmd_publish_community_post(p_location_id uuid,p_post_type text,p_body text,p_attachment_asset_id uuid,p_external_url text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_post uuid; v_result jsonb;
begin
  if not app_private.has_account_capability('community_post') then raise exception 'COMMUNITY_POST_CAPABILITY_REQUIRED'; end if;
  if not exists(select 1 from public.locations where id=p_location_id and state='live') then raise exception 'LOCATION_NOT_LIVE'; end if;
  if not app_private.account_has_location_connection(p_location_id) then raise exception 'LOCATION_CONNECTION_REQUIRED'; end if;
  if app_private.has_active_account_restriction(v_actor,'community',p_location_id) then raise exception 'COMMUNITY_RESTRICTED'; end if;
  if p_post_type not in ('discussion','question','resource','event','update') then raise exception 'INVALID_POST_TYPE'; end if;
  if p_body is null or char_length(btrim(p_body)) not between 1 and 12000 then raise exception 'INVALID_POST_BODY'; end if;
  if p_attachment_asset_id is not null and not exists(select 1 from public.file_assets where id=p_attachment_asset_id and uploaded_by_account_id=v_actor and status='active') then raise exception 'ATTACHMENT_NOT_OWNED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('location_id',p_location_id,'post_type',p_post_type,'body',p_body,'attachment_asset_id',p_attachment_asset_id,'external_url',p_external_url));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'publish_community_post',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.community_posts(location_id,author_account_id,post_type,body,attachment_asset_id,external_url)
  values(p_location_id,v_actor,p_post_type,btrim(p_body),p_attachment_asset_id,nullif(btrim(p_external_url),'')) returning id into v_post;
  v_result:=jsonb_build_object('post_id',v_post,'visibility_status','published');
  perform app_private.complete_human_idempotent_command(v_actor,'publish_community_post',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_comment_on_community_post(p_post_id uuid,p_body text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_location uuid; v_author uuid; v_comment uuid; v_result jsonb;
begin
  select location_id,author_account_id into v_location,v_author from public.community_posts where id=p_post_id and visibility_status='published'; if not found then raise exception 'COMMUNITY_POST_NOT_AVAILABLE'; end if;
  if not exists(select 1 from public.locations where id=v_location and state='live') then raise exception 'LOCATION_NOT_LIVE'; end if;
  if not app_private.account_has_location_connection(v_location) then raise exception 'LOCATION_CONNECTION_REQUIRED'; end if;
  if app_private.has_active_account_restriction(v_actor,'community',v_location) then raise exception 'COMMUNITY_RESTRICTED'; end if;
  if app_private.community_blocked_between(v_author) then raise exception 'COMMUNITY_RELATION_BLOCKED'; end if;
  if p_body is null or char_length(btrim(p_body)) not between 1 and 8000 then raise exception 'INVALID_COMMENT_BODY'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('post_id',p_post_id,'body',p_body)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'comment_on_community_post',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.community_comments(post_id,author_account_id,body) values(p_post_id,v_actor,btrim(p_body)) returning id into v_comment;
  v_result:=jsonb_build_object('comment_id',v_comment,'post_id',p_post_id,'visibility_status','published');
  perform app_private.complete_human_idempotent_command(v_actor,'comment_on_community_post',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_react_to_community_content(p_target_type text,p_target_id uuid,p_reaction_type text,p_enabled boolean,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_location uuid; v_author uuid; v_result jsonb;
begin
  if p_reaction_type not in ('helpful','thanks','support','interesting') then raise exception 'INVALID_REACTION_TYPE'; end if;
  if p_target_type='post' then select location_id,author_account_id into v_location,v_author from public.community_posts where id=p_target_id and visibility_status='published';
  elsif p_target_type='comment' then select p.location_id,c.author_account_id into v_location,v_author from public.community_comments c join public.community_posts p on p.id=c.post_id where c.id=p_target_id and c.visibility_status='published' and p.visibility_status='published';
  else raise exception 'INVALID_REACTION_TARGET'; end if;
  if v_location is null then raise exception 'COMMUNITY_CONTENT_NOT_AVAILABLE'; end if;
  if not app_private.account_has_location_connection(v_location) then raise exception 'LOCATION_CONNECTION_REQUIRED'; end if;
  if app_private.has_active_account_restriction(v_actor,'community',v_location) then raise exception 'COMMUNITY_RESTRICTED'; end if;
  if app_private.community_blocked_between(v_author) then raise exception 'COMMUNITY_RELATION_BLOCKED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('target_type',p_target_type,'target_id',p_target_id,'reaction_type',p_reaction_type,'enabled',p_enabled)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'react_to_community_content',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if p_target_type='post' then
    if p_enabled then insert into public.community_post_reactions(post_id,account_id,reaction_type) values(p_target_id,v_actor,p_reaction_type) on conflict(post_id,account_id) do update set reaction_type=excluded.reaction_type,created_at=now();
    else delete from public.community_post_reactions where post_id=p_target_id and account_id=v_actor; end if;
  else
    if p_enabled then insert into public.community_comment_reactions(comment_id,account_id,reaction_type) values(p_target_id,v_actor,p_reaction_type) on conflict(comment_id,account_id) do update set reaction_type=excluded.reaction_type,created_at=now();
    else delete from public.community_comment_reactions where comment_id=p_target_id and account_id=v_actor; end if;
  end if;
  v_result:=jsonb_build_object('target_type',p_target_type,'target_id',p_target_id,'reaction_type',p_reaction_type,'enabled',p_enabled);
  perform app_private.complete_human_idempotent_command(v_actor,'react_to_community_content',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_moderate_community_content(p_target_type text,p_target_id uuid,p_visibility_status text,p_reason text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_location uuid; v_result jsonb;
begin
  if p_visibility_status not in ('published','hidden','removed') then raise exception 'INVALID_VISIBILITY_STATUS'; end if;
  if p_reason is null or char_length(btrim(p_reason)) not between 1 and 500 then raise exception 'MODERATION_REASON_REQUIRED'; end if;
  if p_target_type='post' then select location_id into v_location from public.community_posts where id=p_target_id for update;
  elsif p_target_type='comment' then select p.location_id into v_location from public.community_comments c join public.community_posts p on p.id=c.post_id where c.id=p_target_id for update of c;
  else raise exception 'INVALID_COMMUNITY_TARGET'; end if;
  if v_location is null then raise exception 'COMMUNITY_CONTENT_NOT_FOUND'; end if;
  if not app_private.can_moderate_location(v_location) then raise exception 'NOT_AUTHORIZED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('target_type',p_target_type,'target_id',p_target_id,'visibility_status',p_visibility_status,'reason',p_reason)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'moderate_community_content',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if p_target_type='post' then update public.community_posts set visibility_status=p_visibility_status where id=p_target_id;
  else update public.community_comments set visibility_status=p_visibility_status where id=p_target_id; end if;
  perform app_private.write_location_audit(v_actor,'community.moderate',v_location,'community_'||p_target_type,p_target_id,btrim(p_reason),jsonb_build_object('visibility_status',p_visibility_status));
  v_result:=jsonb_build_object('target_type',p_target_type,'target_id',p_target_id,'visibility_status',p_visibility_status);
  perform app_private.complete_human_idempotent_command(v_actor,'moderate_community_content',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.report_target_exists(p_target_type text,p_target_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
begin
  case p_target_type
    when 'account' then return exists(select 1 from public.accounts where id=p_target_id);
    when 'organization' then return exists(select 1 from public.organizations where id=p_target_id);
    when 'teaching_option' then return exists(select 1 from public.teaching_options where id=p_target_id);
    when 'learning_request' then return exists(select 1 from public.learning_requests where id=p_target_id);
    when 'enquiry' then return exists(select 1 from public.enquiries where id=p_target_id);
    when 'class' then return exists(select 1 from public.classes where id=p_target_id);
    when 'community_post' then return exists(select 1 from public.community_posts where id=p_target_id);
    when 'community_comment' then return exists(select 1 from public.community_comments where id=p_target_id);
    else return false;
  end case;
end; $$;

create or replace function app_private.derive_report_location(p_target_type text,p_target_id uuid,p_requested_location uuid)
returns uuid language plpgsql stable security definer set search_path='' as $$
declare v_location uuid;
begin
  if p_target_type='community_post' then select location_id into v_location from public.community_posts where id=p_target_id;
  elsif p_target_type='community_comment' then select p.location_id into v_location from public.community_comments c join public.community_posts p on p.id=c.post_id where c.id=p_target_id;
  elsif p_target_type='learning_request' then select location_id into v_location from public.learning_requests where id=p_target_id;
  elsif p_target_type='enquiry' then select location_id into v_location from public.enquiries where id=p_target_id;
  elsif p_target_type='class' then select location_id into v_location from public.classes where id=p_target_id;
  else v_location:=p_requested_location; end if;
  if p_requested_location is not null and v_location is not null and p_requested_location<>v_location then raise exception 'REPORT_LOCATION_MISMATCH'; end if;
  return coalesce(v_location,p_requested_location);
end; $$;

create or replace function app_private.cmd_report_subject(p_target_type text,p_target_id uuid,p_context_learner_id uuid,p_location_id uuid,p_reason_code text,p_details text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(false); v_gate jsonb; v_fp text; v_location uuid; v_report uuid; v_result jsonb;
begin
  if not app_private.report_target_exists(p_target_type,p_target_id) then raise exception 'REPORT_TARGET_NOT_FOUND'; end if;
  if p_context_learner_id is not null and not (app_private.can_access_learner(p_context_learner_id) or app_private.has_account_capability('safety_reviewer') or app_private.has_account_capability('platform_admin')) then raise exception 'INVALID_REPORT_LEARNER_CONTEXT'; end if;
  if p_reason_code is null or char_length(btrim(p_reason_code)) not between 1 and 120 then raise exception 'INVALID_REPORT_REASON'; end if;
  if p_details is not null and char_length(p_details)>8000 then raise exception 'REPORT_DETAILS_TOO_LONG'; end if;
  v_location:=app_private.derive_report_location(p_target_type,p_target_id,p_location_id);
  v_fp:=app_private.request_fingerprint(jsonb_build_object('target_type',p_target_type,'target_id',p_target_id,'context_learner_id',p_context_learner_id,'location_id',v_location,'reason_code',p_reason_code,'details',p_details)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'report_subject',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.reports(reporter_account_id,context_learner_id,location_id,target_type,target_id,reason_code,details,evidence_snapshot)
  values(v_actor,p_context_learner_id,v_location,p_target_type,p_target_id,btrim(p_reason_code),nullif(btrim(p_details),''),jsonb_build_object('target_type',p_target_type,'target_id',p_target_id)) returning id into v_report;
  v_result:=jsonb_build_object('report_id',v_report,'status','open');
  perform app_private.complete_human_idempotent_command(v_actor,'report_subject',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_resolve_report(p_report_id uuid,p_resolution_code text,p_resolution_note text,p_dismissed boolean,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_location uuid; v_status text; v_result jsonb;
begin
  select location_id,status into v_location,v_status from public.reports where id=p_report_id for update; if not found then raise exception 'REPORT_NOT_FOUND'; end if;
  if not app_private.can_moderate_location(v_location) then raise exception 'NOT_AUTHORIZED'; end if;
  if p_resolution_code is null or char_length(btrim(p_resolution_code)) not between 1 and 120 then raise exception 'RESOLUTION_CODE_REQUIRED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('report_id',p_report_id,'resolution_code',p_resolution_code,'resolution_note',p_resolution_note,'dismissed',p_dismissed)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'resolve_report',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if v_status in ('resolved','dismissed') then v_result:=jsonb_build_object('report_id',p_report_id,'status',v_status,'already_resolved',true);
  else
    update public.reports set status=case when p_dismissed then 'dismissed' else 'resolved' end,resolved_by_account_id=v_actor,resolution_code=btrim(p_resolution_code),resolution_note=nullif(btrim(p_resolution_note),''),resolved_at=now() where id=p_report_id;
    perform app_private.write_audit(v_actor,'report.resolve','report',p_report_id,null,null,jsonb_build_object('resolution_code',btrim(p_resolution_code),'dismissed',p_dismissed));
    v_result:=jsonb_build_object('report_id',p_report_id,'status',case when p_dismissed then 'dismissed' else 'resolved' end,'already_resolved',false);
  end if;
  perform app_private.complete_human_idempotent_command(v_actor,'resolve_report',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_set_block(p_blocked_account_id uuid,p_blocked boolean,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(false); v_gate jsonb; v_fp text; v_id uuid; v_result jsonb;
begin
  if p_blocked_account_id=v_actor then raise exception 'CANNOT_BLOCK_SELF'; end if;
  if not exists(select 1 from public.accounts where id=p_blocked_account_id and lifecycle_status<>'closed') then raise exception 'ACCOUNT_NOT_BLOCKABLE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('blocked_account_id',p_blocked_account_id,'blocked',p_blocked)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'set_block',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if p_blocked then
    select id into v_id from public.blocks where blocker_account_id=v_actor and blocked_account_id=p_blocked_account_id and state='active';
    if v_id is null then insert into public.blocks(blocker_account_id,blocked_account_id,state) values(v_actor,p_blocked_account_id,'active') returning id into v_id; end if;
  else
    update public.blocks set state='lifted',lifted_at=now() where blocker_account_id=v_actor and blocked_account_id=p_blocked_account_id and state='active' returning id into v_id;
  end if;
  v_result:=jsonb_build_object('blocked_account_id',p_blocked_account_id,'blocked',p_blocked,'block_id',v_id);
  perform app_private.complete_human_idempotent_command(v_actor,'set_block',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_grant_verification_claim(p_account_id uuid,p_organization_id uuid,p_claim_type text,p_reason text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_claim uuid; v_result jsonb;
begin
  if not (app_private.has_account_capability('verifier') or app_private.has_account_capability('platform_admin')) then raise exception 'NOT_AUTHORIZED'; end if;
  if (p_account_id is not null)::int+(p_organization_id is not null)::int<>1 then raise exception 'VERIFICATION_SUBJECT_REQUIRED'; end if;
  if p_claim_type not in ('identity','qualification','organization_registration','accreditation') then raise exception 'INVALID_CLAIM_TYPE'; end if;
  if p_account_id is not null and not exists(select 1 from public.accounts where id=p_account_id) then raise exception 'ACCOUNT_NOT_FOUND'; end if;
  if p_organization_id is not null and not exists(select 1 from public.organizations where id=p_organization_id) then raise exception 'ORGANIZATION_NOT_FOUND'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('account_id',p_account_id,'organization_id',p_organization_id,'claim_type',p_claim_type,'reason',p_reason)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'grant_verification_claim',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select id into v_claim from public.verification_claims where account_id is not distinct from p_account_id and organization_id is not distinct from p_organization_id and claim_type=p_claim_type and status in ('pending','verified') order by created_at desc limit 1 for update;
  if v_claim is null then insert into public.verification_claims(account_id,organization_id,claim_type,status,verified_at,verified_by_account_id,reason) values(p_account_id,p_organization_id,p_claim_type,'verified',now(),v_actor,nullif(btrim(p_reason),'')) returning id into v_claim;
  else update public.verification_claims set status='verified',verified_at=now(),verified_by_account_id=v_actor,revoked_at=null,revoked_by_account_id=null,reason=nullif(btrim(p_reason),'') where id=v_claim; end if;
  perform app_private.write_audit(v_actor,'verification.grant','verification_claim',v_claim,null,null,jsonb_build_object('claim_type',p_claim_type,'account_id',p_account_id,'organization_id',p_organization_id));
  v_result:=jsonb_build_object('claim_id',v_claim,'claim_type',p_claim_type,'status','verified'); perform app_private.complete_human_idempotent_command(v_actor,'grant_verification_claim',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_revoke_verification_claim(p_claim_id uuid,p_reason text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_status text; v_claim_type text; v_result jsonb;
begin
  if not (app_private.has_account_capability('verifier') or app_private.has_account_capability('platform_admin')) then raise exception 'NOT_AUTHORIZED'; end if;
  if p_reason is null or char_length(btrim(p_reason)) not between 1 and 500 then raise exception 'REVOCATION_REASON_REQUIRED'; end if;
  select status,claim_type into v_status,v_claim_type from public.verification_claims where id=p_claim_id for update; if not found then raise exception 'CLAIM_NOT_FOUND'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('claim_id',p_claim_id,'reason',p_reason)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'revoke_verification_claim',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if v_status='revoked' then v_result:=jsonb_build_object('claim_id',p_claim_id,'status','revoked','already_revoked',true);
  elsif v_status<>'verified' then raise exception 'CLAIM_NOT_VERIFIED';
  else update public.verification_claims set status='revoked',revoked_at=now(),revoked_by_account_id=v_actor,reason=btrim(p_reason) where id=p_claim_id; perform app_private.write_audit(v_actor,'verification.revoke','verification_claim',p_claim_id,null,null,jsonb_build_object('claim_type',v_claim_type,'reason_code',btrim(p_reason))); v_result:=jsonb_build_object('claim_id',p_claim_id,'status','revoked','already_revoked',false); end if;
  perform app_private.complete_human_idempotent_command(v_actor,'revoke_verification_claim',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.discover_community_posts(p_location_id uuid,p_limit integer default 50)
returns setof jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('post_id',p.id,'location_id',p.location_id,'post_type',p.post_type,'body',p.body,'external_url',p.external_url,'created_at',p.created_at,
    'author_account_id',p.author_account_id,'author_name',a.display_name,
    'comment_count',(select count(*) from public.community_comments c where c.post_id=p.id and c.visibility_status='published'),
    'reaction_count',(select count(*) from public.community_post_reactions r where r.post_id=p.id))
  from public.community_posts p join public.accounts a on a.id=p.author_account_id
  where p.location_id=p_location_id and p.visibility_status='published'
    and exists(select 1 from public.locations l where l.id=p.location_id and l.state='live')
    and not app_private.community_blocked_between(p.author_account_id)
  order by p.created_at desc,p.id limit greatest(1,least(coalesce(p_limit,50),100));
$$;

create or replace function app_private.get_community_post_projection(p_post_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('post_id',p.id,'location_id',p.location_id,'post_type',p.post_type,'body',p.body,'external_url',p.external_url,'created_at',p.created_at,
    'author_account_id',p.author_account_id,'author_name',a.display_name,
    'comments',coalesce((select jsonb_agg(jsonb_build_object('comment_id',c.id,'author_account_id',c.author_account_id,'author_name',ca.display_name,'body',c.body,'created_at',c.created_at,'reaction_count',(select count(*) from public.community_comment_reactions r where r.comment_id=c.id)) order by c.created_at,c.id) from public.community_comments c join public.accounts ca on ca.id=c.author_account_id where c.post_id=p.id and c.visibility_status='published' and not app_private.community_blocked_between(c.author_account_id)),'[]'::jsonb))
  from public.community_posts p join public.accounts a on a.id=p.author_account_id
  where p.id=p_post_id and p.visibility_status='published' and not app_private.community_blocked_between(p.author_account_id);
$$;

create or replace function app_private.get_public_verification_claims(p_account_id uuid,p_organization_id uuid)
returns setof text language sql stable security definer set search_path='' as $$
  select claim_type from public.verification_claims
  where status='verified' and account_id is not distinct from p_account_id and organization_id is not distinct from p_organization_id
  order by claim_type;
$$;

alter table public.community_posts enable row level security; alter table public.community_posts force row level security;
alter table public.community_comments enable row level security; alter table public.community_comments force row level security;
alter table public.community_post_reactions enable row level security; alter table public.community_post_reactions force row level security;
alter table public.community_comment_reactions enable row level security; alter table public.community_comment_reactions force row level security;
alter table public.reports enable row level security; alter table public.reports force row level security;
alter table public.blocks enable row level security; alter table public.blocks force row level security;
alter table public.verification_claims enable row level security; alter table public.verification_claims force row level security;

create policy community_posts_authenticated_deny on public.community_posts for select to authenticated using(false);
create policy community_comments_authenticated_deny on public.community_comments for select to authenticated using(false);
create policy community_post_reactions_authenticated_deny on public.community_post_reactions for select to authenticated using(false);
create policy community_comment_reactions_authenticated_deny on public.community_comment_reactions for select to authenticated using(false);
create policy reports_select_authorized on public.reports for select to authenticated using(reporter_account_id=app_private.current_account_id() or app_private.can_moderate_location(location_id));
create policy blocks_select_owner on public.blocks for select to authenticated using(blocker_account_id=app_private.current_account_id());
create policy verification_claims_select_reviewer on public.verification_claims for select to authenticated using(app_private.has_account_capability('verifier') or app_private.has_account_capability('platform_admin'));

revoke all on table public.community_posts,public.community_comments,public.community_post_reactions,public.community_comment_reactions,public.reports,public.blocks,public.verification_claims from public,anon,authenticated,service_role;
grant select on table public.reports,public.blocks,public.verification_claims to authenticated;
grant select,insert,update,delete on table public.community_posts,public.community_comments,public.community_post_reactions,public.community_comment_reactions,public.reports,public.blocks,public.verification_claims to service_role;

revoke all on function app_private.account_has_location_connection(uuid),app_private.can_moderate_location(uuid),app_private.community_blocked_between(uuid),app_private.report_target_exists(text,uuid),app_private.derive_report_location(text,uuid,uuid),
 app_private.cmd_publish_community_post(uuid,text,text,uuid,text,text),app_private.cmd_comment_on_community_post(uuid,text,text),app_private.cmd_react_to_community_content(text,uuid,text,boolean,text),app_private.cmd_moderate_community_content(text,uuid,text,text,text),
 app_private.cmd_report_subject(text,uuid,uuid,uuid,text,text,text),app_private.cmd_resolve_report(uuid,text,text,boolean,text),app_private.cmd_set_block(uuid,boolean,text),app_private.cmd_grant_verification_claim(uuid,uuid,text,text,text),app_private.cmd_revoke_verification_claim(uuid,text,text),
 app_private.discover_community_posts(uuid,integer),app_private.get_community_post_projection(uuid),app_private.get_public_verification_claims(uuid,uuid)
from public,anon,authenticated,service_role;
grant execute on function app_private.account_has_location_connection(uuid),app_private.can_moderate_location(uuid),app_private.community_blocked_between(uuid),app_private.discover_community_posts(uuid,integer),app_private.get_community_post_projection(uuid),app_private.get_public_verification_claims(uuid,uuid) to authenticated;
grant execute on function app_private.cmd_publish_community_post(uuid,text,text,uuid,text,text),app_private.cmd_comment_on_community_post(uuid,text,text),app_private.cmd_react_to_community_content(text,uuid,text,boolean,text),app_private.cmd_moderate_community_content(text,uuid,text,text,text),app_private.cmd_report_subject(text,uuid,uuid,uuid,text,text,text),app_private.cmd_resolve_report(uuid,text,text,boolean,text),app_private.cmd_set_block(uuid,boolean,text),app_private.cmd_grant_verification_claim(uuid,uuid,text,text,text),app_private.cmd_revoke_verification_claim(uuid,text,text) to authenticated;

create or replace function public.publish_community_post(p_location_id uuid,p_post_type text,p_body text,p_attachment_asset_id uuid,p_external_url text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_publish_community_post(p_location_id,p_post_type,p_body,p_attachment_asset_id,p_external_url,p_idempotency_key); $$;
create or replace function public.comment_on_community_post(p_post_id uuid,p_body text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_comment_on_community_post(p_post_id,p_body,p_idempotency_key); $$;
create or replace function public.react_to_community_content(p_target_type text,p_target_id uuid,p_reaction_type text,p_enabled boolean,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_react_to_community_content(p_target_type,p_target_id,p_reaction_type,p_enabled,p_idempotency_key); $$;
create or replace function public.moderate_community_content(p_target_type text,p_target_id uuid,p_visibility_status text,p_reason text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_moderate_community_content(p_target_type,p_target_id,p_visibility_status,p_reason,p_idempotency_key); $$;
create or replace function public.report_subject(p_target_type text,p_target_id uuid,p_context_learner_id uuid,p_location_id uuid,p_reason_code text,p_details text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_report_subject(p_target_type,p_target_id,p_context_learner_id,p_location_id,p_reason_code,p_details,p_idempotency_key); $$;
create or replace function public.resolve_report(p_report_id uuid,p_resolution_code text,p_resolution_note text,p_dismissed boolean,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_resolve_report(p_report_id,p_resolution_code,p_resolution_note,p_dismissed,p_idempotency_key); $$;
create or replace function public.set_block(p_blocked_account_id uuid,p_blocked boolean,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_set_block(p_blocked_account_id,p_blocked,p_idempotency_key); $$;
create or replace function public.grant_verification_claim(p_account_id uuid,p_organization_id uuid,p_claim_type text,p_reason text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_grant_verification_claim(p_account_id,p_organization_id,p_claim_type,p_reason,p_idempotency_key); $$;
create or replace function public.revoke_verification_claim(p_claim_id uuid,p_reason text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_revoke_verification_claim(p_claim_id,p_reason,p_idempotency_key); $$;
create or replace function public.discover_community_posts(p_location_id uuid,p_limit integer default 50) returns setof jsonb language sql stable security invoker set search_path='' as $$ select * from app_private.discover_community_posts(p_location_id,p_limit); $$;
create or replace function public.get_community_post(p_post_id uuid) returns jsonb language sql stable security invoker set search_path='' as $$ select app_private.get_community_post_projection(p_post_id); $$;
create or replace function public.get_public_verification_claims(p_account_id uuid,p_organization_id uuid) returns setof text language sql stable security invoker set search_path='' as $$ select * from app_private.get_public_verification_claims(p_account_id,p_organization_id); $$;

revoke all on function public.publish_community_post(uuid,text,text,uuid,text,text),public.comment_on_community_post(uuid,text,text),public.react_to_community_content(text,uuid,text,boolean,text),public.moderate_community_content(text,uuid,text,text,text),public.report_subject(text,uuid,uuid,uuid,text,text,text),public.resolve_report(uuid,text,text,boolean,text),public.set_block(uuid,boolean,text),public.grant_verification_claim(uuid,uuid,text,text,text),public.revoke_verification_claim(uuid,text,text),public.discover_community_posts(uuid,integer),public.get_community_post(uuid),public.get_public_verification_claims(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.publish_community_post(uuid,text,text,uuid,text,text),public.comment_on_community_post(uuid,text,text),public.react_to_community_content(text,uuid,text,boolean,text),public.moderate_community_content(text,uuid,text,text,text),public.report_subject(text,uuid,uuid,uuid,text,text,text),public.resolve_report(uuid,text,text,boolean,text),public.set_block(uuid,boolean,text),public.grant_verification_claim(uuid,uuid,text,text,text),public.revoke_verification_claim(uuid,text,text),public.discover_community_posts(uuid,integer),public.get_community_post(uuid),public.get_public_verification_claims(uuid,uuid) to authenticated;
