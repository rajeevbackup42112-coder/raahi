-- Raahi Learning V1.2 — Ads campaign authority, immutable revision review and commercial clearance.

create or replace function app_private.has_advertiser_authority(p_account_id uuid,p_organization_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select app_private.has_account_capability('platform_admin')
    or (
      p_account_id is not null
      and p_account_id=app_private.current_account_id()
      and exists(select 1 from public.accounts a where a.id=p_account_id and a.lifecycle_status='active')
    )
    or (
      p_organization_id is not null
      and app_private.has_organization_member_capability(p_organization_id,'manage_ads')
    );
$$;

create or replace function app_private.campaign_advertiser_authority(p_campaign_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select app_private.has_advertiser_authority(c.account_id,c.organization_id)
  from public.ad_campaigns c where c.id=p_campaign_id;
$$;

create or replace function app_private.advertising_enabled(p_account_id uuid,p_organization_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.advertising_eligibility e
    where e.account_id is not distinct from p_account_id
      and e.organization_id is not distinct from p_organization_id
      and e.state='enabled'
  );
$$;

create or replace function app_private.advertiser_ads_restricted(p_account_id uuid,p_organization_id uuid,p_location_id uuid default null)
returns boolean language sql stable security definer set search_path='' as $$
  select case
    when p_account_id is not null then app_private.has_active_account_restriction(p_account_id,'ads',p_location_id)
    when p_organization_id is not null then app_private.has_active_organization_restriction(p_organization_id,'ads',p_location_id)
    else true
  end;
$$;

create or replace function app_private.ad_reviewer_conflicted(p_revision_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1
    from public.ad_campaign_revisions r
    join public.ad_campaigns c on c.id=r.campaign_id
    where r.id=p_revision_id
      and (
        c.account_id=app_private.current_account_id()
        or (
          c.organization_id is not null
          and exists(select 1 from public.organization_members om where om.organization_id=c.organization_id and om.account_id=app_private.current_account_id() and om.status='active')
        )
      )
  );
$$;

create or replace function app_private.revision_approved_for_location(p_revision_id uuid,p_location_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_platform_state text;
begin
  select state into v_platform_state from public.ad_reviews where campaign_revision_id=p_revision_id and review_scope='platform';
  if v_platform_state is not null then return v_platform_state='approved'; end if;
  return exists(select 1 from public.ad_reviews where campaign_revision_id=p_revision_id and review_scope='local' and location_id=p_location_id and state='approved');
end; $$;

create or replace function app_private.revision_approved_for_all_targets(p_revision_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.ad_campaign_revisions where id=p_revision_id and submitted_at is not null)
     and not exists(
       select 1
       from (
         select distinct t.location_id
         from public.ad_campaign_revisions r join public.ad_campaign_targets t on t.campaign_id=r.campaign_id
         where r.id=p_revision_id
       ) x
       where not app_private.revision_approved_for_location(p_revision_id,x.location_id)
     )
     and exists(
       select 1 from public.ad_campaign_revisions r join public.ad_campaign_targets t on t.campaign_id=r.campaign_id where r.id=p_revision_id
     );
$$;

create or replace function app_private.cmd_set_advertising_eligibility(p_account_id uuid,p_organization_id uuid,p_state text,p_reason text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_id uuid; v_result jsonb;
begin
  if not (app_private.has_account_capability('platform_admin') or app_private.has_account_capability('ads_commercial')) then raise exception 'NOT_AUTHORIZED'; end if;
  if (p_account_id is not null)::int+(p_organization_id is not null)::int<>1 then raise exception 'ADVERTISING_SUBJECT_REQUIRED'; end if;
  if p_state not in ('not_enabled','under_review','enabled','restricted','disabled') then raise exception 'INVALID_ELIGIBILITY_STATE'; end if;
  if p_state in ('restricted','disabled') and nullif(btrim(p_reason),'') is null then raise exception 'ELIGIBILITY_REASON_REQUIRED'; end if;
  if p_account_id is not null and not exists(select 1 from public.accounts where id=p_account_id and lifecycle_status<>'closed') then raise exception 'ACCOUNT_NOT_ELIGIBLE'; end if;
  if p_organization_id is not null and not exists(select 1 from public.organizations where id=p_organization_id and status<>'closed') then raise exception 'ORGANIZATION_NOT_ELIGIBLE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('account_id',p_account_id,'organization_id',p_organization_id,'state',p_state,'reason',p_reason));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'set_advertising_eligibility',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.advertising_eligibility(account_id,organization_id,state,reason)
  values(p_account_id,p_organization_id,p_state,nullif(btrim(p_reason),''))
  on conflict (account_id) where account_id is not null do update set state=excluded.state,reason=excluded.reason
  returning id into v_id;
  if v_id is null then
    insert into public.advertising_eligibility(account_id,organization_id,state,reason)
    values(p_account_id,p_organization_id,p_state,nullif(btrim(p_reason),''))
    on conflict (organization_id) where organization_id is not null do update set state=excluded.state,reason=excluded.reason
    returning id into v_id;
  end if;
  perform app_private.write_audit(v_actor,'ads.eligibility_set','advertising_eligibility',v_id,null,null,jsonb_build_object('account_id',p_account_id,'organization_id',p_organization_id,'state',p_state));
  v_result:=jsonb_build_object('eligibility_id',v_id,'state',p_state);
  perform app_private.complete_human_idempotent_command(v_actor,'set_advertising_eligibility',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_create_ad_campaign(p_account_id uuid,p_organization_id uuid,p_objective text,p_campaign_name text,p_audience_context text,p_education_category text,p_starts_at timestamptz,p_ends_at timestamptz,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_campaign uuid; v_result jsonb;
begin
  if (p_account_id is not null)::int+(p_organization_id is not null)::int<>1 then raise exception 'CAMPAIGN_OWNER_REQUIRED'; end if;
  if not app_private.has_advertiser_authority(p_account_id,p_organization_id) then raise exception 'NOT_AUTHORIZED'; end if;
  if not app_private.advertising_enabled(p_account_id,p_organization_id) then raise exception 'ADVERTISING_NOT_ENABLED'; end if;
  if app_private.advertiser_ads_restricted(p_account_id,p_organization_id,null) then raise exception 'ADS_RESTRICTED'; end if;
  if p_objective not in ('admissions','course_batch','event','awareness') then raise exception 'INVALID_CAMPAIGN_OBJECTIVE'; end if;
  if p_campaign_name is null or char_length(btrim(p_campaign_name)) not between 1 and 200 then raise exception 'INVALID_CAMPAIGN_NAME'; end if;
  if p_starts_at is null or p_ends_at is null or p_ends_at<=p_starts_at or p_ends_at<=now() then raise exception 'INVALID_CAMPAIGN_DATES'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('account_id',p_account_id,'organization_id',p_organization_id,'objective',p_objective,'campaign_name',p_campaign_name,'audience_context',p_audience_context,'education_category',p_education_category,'starts_at',p_starts_at,'ends_at',p_ends_at));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'create_ad_campaign',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.ad_campaigns(account_id,organization_id,objective,campaign_name,audience_context,education_category,starts_at,ends_at,created_by_account_id)
  values(p_account_id,p_organization_id,p_objective,btrim(p_campaign_name),nullif(btrim(p_audience_context),''),nullif(btrim(p_education_category),''),p_starts_at,p_ends_at,v_actor) returning id into v_campaign;
  insert into public.ad_commercial_clearances(campaign_id,state) values(v_campaign,'pending');
  v_result:=jsonb_build_object('campaign_id',v_campaign,'state','draft');
  perform app_private.complete_human_idempotent_command(v_actor,'create_ad_campaign',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_set_ad_campaign_targets(p_campaign_id uuid,p_targets jsonb,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_state text; v_account uuid; v_org uuid; v_bad uuid; v_count int; v_result jsonb;
begin
  if not app_private.campaign_advertiser_authority(p_campaign_id) then raise exception 'NOT_AUTHORIZED'; end if;
  select state,account_id,organization_id into v_state,v_account,v_org from public.ad_campaigns where id=p_campaign_id for update; if not found then raise exception 'CAMPAIGN_NOT_FOUND'; end if;
  if v_state<>'draft' then raise exception 'CAMPAIGN_TARGETS_LOCKED_AFTER_SUBMISSION'; end if;
  if p_targets is null or jsonb_typeof(p_targets)<>'array' or jsonb_array_length(p_targets)=0 then raise exception 'CAMPAIGN_REQUIRES_TARGET'; end if;
  if exists(select 1 from jsonb_to_recordset(p_targets) as x(location_id uuid,placement_type text) where x.location_id is null or x.placement_type not in ('home_sponsored','explore_sponsored','community_event')) then raise exception 'INVALID_CAMPAIGN_TARGET'; end if;
  select x.location_id into v_bad from jsonb_to_recordset(p_targets) as x(location_id uuid,placement_type text) left join public.locations l on l.id=x.location_id where l.id is null or l.state<>'live' limit 1;
  if v_bad is not null then raise exception 'TARGET_LOCATION_NOT_LIVE'; end if;
  select x.location_id into v_bad from jsonb_to_recordset(p_targets) as x(location_id uuid,placement_type text) where app_private.advertiser_ads_restricted(v_account,v_org,x.location_id) limit 1;
  if v_bad is not null then raise exception 'ADS_RESTRICTED_IN_TARGET_LOCATION'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('campaign_id',p_campaign_id,'targets',p_targets)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'set_ad_campaign_targets',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  delete from public.ad_campaign_targets where campaign_id=p_campaign_id;
  insert into public.ad_campaign_targets(campaign_id,location_id,placement_type)
  select p_campaign_id,x.location_id,x.placement_type from jsonb_to_recordset(p_targets) as x(location_id uuid,placement_type text) group by x.location_id,x.placement_type;
  select count(*) into v_count from public.ad_campaign_targets where campaign_id=p_campaign_id;
  v_result:=jsonb_build_object('campaign_id',p_campaign_id,'target_count',v_count);
  perform app_private.complete_human_idempotent_command(v_actor,'set_ad_campaign_targets',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_create_ad_campaign_revision(p_campaign_id uuid,p_headline text,p_body text,p_image_asset_id uuid,p_destination_type text,p_destination_id uuid,p_external_url text,p_cta_type text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_state text; v_account uuid; v_org uuid; v_rev_no int; v_revision uuid; v_result jsonb;
begin
  if not app_private.campaign_advertiser_authority(p_campaign_id) then raise exception 'NOT_AUTHORIZED'; end if;
  select state,account_id,organization_id into v_state,v_account,v_org from public.ad_campaigns where id=p_campaign_id for update; if not found then raise exception 'CAMPAIGN_NOT_FOUND'; end if;
  if v_state='closed' then raise exception 'CAMPAIGN_CLOSED'; end if;
  if not app_private.advertising_enabled(v_account,v_org) then raise exception 'ADVERTISING_NOT_ENABLED'; end if;
  if p_headline is null or char_length(btrim(p_headline)) not between 1 and 180 or p_body is null or char_length(btrim(p_body)) not between 1 and 4000 then raise exception 'INVALID_AD_CREATIVE'; end if;
  if p_destination_type not in ('teaching_option','organization','external_url') or p_cta_type not in ('enquire','learn_more','visit_site') then raise exception 'INVALID_AD_DESTINATION'; end if;
  if p_destination_type='teaching_option' and not exists(select 1 from public.teaching_options t where t.id=p_destination_id and ((v_account is not null and t.teacher_account_id=v_account) or (v_org is not null and t.organization_id=v_org))) then raise exception 'TEACHING_OPTION_NOT_OWNED_BY_ADVERTISER'; end if;
  if p_destination_type='organization' and (v_org is null or p_destination_id<>v_org) then raise exception 'ORGANIZATION_DESTINATION_NOT_OWNED'; end if;
  if p_destination_type='external_url' and nullif(btrim(p_external_url),'') is null then raise exception 'EXTERNAL_URL_REQUIRED'; end if;
  if p_destination_type<>'external_url' and p_external_url is not null then raise exception 'EXTERNAL_URL_NOT_ALLOWED'; end if;
  if p_destination_type<>'external_url' and p_destination_id is null then raise exception 'DESTINATION_ID_REQUIRED'; end if;
  if p_image_asset_id is not null and not exists(select 1 from public.file_assets where id=p_image_asset_id and uploaded_by_account_id=v_actor and status='active') then raise exception 'IMAGE_ASSET_NOT_OWNED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('campaign_id',p_campaign_id,'headline',p_headline,'body',p_body,'image_asset_id',p_image_asset_id,'destination_type',p_destination_type,'destination_id',p_destination_id,'external_url',p_external_url,'cta_type',p_cta_type)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'create_ad_campaign_revision',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select coalesce(max(revision_number),0)+1 into v_rev_no from public.ad_campaign_revisions where campaign_id=p_campaign_id;
  insert into public.ad_campaign_revisions(campaign_id,revision_number,headline,body,image_asset_id,destination_type,destination_id,external_url,cta_type,created_by_account_id)
  values(p_campaign_id,v_rev_no,btrim(p_headline),btrim(p_body),p_image_asset_id,p_destination_type,p_destination_id,nullif(btrim(p_external_url),''),p_cta_type,v_actor) returning id into v_revision;
  v_result:=jsonb_build_object('revision_id',v_revision,'campaign_id',p_campaign_id,'revision_number',v_rev_no,'submitted',false);
  perform app_private.complete_human_idempotent_command(v_actor,'create_ad_campaign_revision',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_submit_ad_campaign_revision(p_revision_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_campaign uuid; v_submitted timestamptz; v_account uuid; v_org uuid; v_state text; v_bad uuid; v_result jsonb;
begin
  select r.campaign_id,r.submitted_at,c.account_id,c.organization_id,c.state into v_campaign,v_submitted,v_account,v_org,v_state from public.ad_campaign_revisions r join public.ad_campaigns c on c.id=r.campaign_id where r.id=p_revision_id for update of r,c; if not found then raise exception 'REVISION_NOT_FOUND'; end if;
  if not app_private.campaign_advertiser_authority(v_campaign) then raise exception 'NOT_AUTHORIZED'; end if;
  if v_state='closed' then raise exception 'CAMPAIGN_CLOSED'; end if;
  if not app_private.advertising_enabled(v_account,v_org) then raise exception 'ADVERTISING_NOT_ENABLED'; end if;
  if not exists(select 1 from public.ad_campaign_targets where campaign_id=v_campaign) then raise exception 'CAMPAIGN_REQUIRES_TARGET'; end if;
  select t.location_id into v_bad from public.ad_campaign_targets t join public.locations l on l.id=t.location_id where t.campaign_id=v_campaign and (l.state<>'live' or app_private.advertiser_ads_restricted(v_account,v_org,t.location_id)) limit 1;
  if v_bad is not null then raise exception 'CAMPAIGN_TARGET_NOT_ELIGIBLE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('revision_id',p_revision_id)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'submit_ad_campaign_revision',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if v_submitted is null then update public.ad_campaign_revisions set submitted_at=now() where id=p_revision_id; update public.ad_campaigns set state='submitted' where id=v_campaign and state='draft'; end if;
  v_result:=jsonb_build_object('revision_id',p_revision_id,'campaign_id',v_campaign,'submitted',true,'already_submitted',v_submitted is not null);
  perform app_private.complete_human_idempotent_command(v_actor,'submit_ad_campaign_revision',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_submit_ad_evidence(p_revision_id uuid,p_file_asset_id uuid,p_external_url text,p_note text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_campaign uuid; v_evidence uuid; v_result jsonb;
begin
  select campaign_id into v_campaign from public.ad_campaign_revisions where id=p_revision_id and submitted_at is not null; if not found then raise exception 'SUBMITTED_REVISION_REQUIRED'; end if;
  if not app_private.campaign_advertiser_authority(v_campaign) then raise exception 'NOT_AUTHORIZED'; end if;
  if p_file_asset_id is null and nullif(btrim(p_external_url),'') is null then raise exception 'EVIDENCE_REQUIRED'; end if;
  if p_file_asset_id is not null and not exists(select 1 from public.file_assets where id=p_file_asset_id and uploaded_by_account_id=v_actor and status='active') then raise exception 'EVIDENCE_FILE_NOT_OWNED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('revision_id',p_revision_id,'file_asset_id',p_file_asset_id,'external_url',p_external_url,'note',p_note)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'submit_ad_evidence',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.ad_claim_evidence(campaign_revision_id,file_asset_id,external_url,submitted_by_account_id,note) values(p_revision_id,p_file_asset_id,nullif(btrim(p_external_url),''),v_actor,nullif(btrim(p_note),'')) returning id into v_evidence;
  v_result:=jsonb_build_object('evidence_id',v_evidence,'revision_id',p_revision_id);
  perform app_private.complete_human_idempotent_command(v_actor,'submit_ad_evidence',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_review_ad_campaign_revision(p_revision_id uuid,p_review_scope text,p_location_id uuid,p_decision text,p_reason text,p_details text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_campaign uuid; v_submitted timestamptz; v_review uuid; v_old_state text; v_result jsonb;
begin
  select campaign_id,submitted_at into v_campaign,v_submitted from public.ad_campaign_revisions where id=p_revision_id; if not found then raise exception 'REVISION_NOT_FOUND'; end if;
  if v_submitted is null then raise exception 'SUBMITTED_REVISION_REQUIRED'; end if;
  if app_private.ad_reviewer_conflicted(p_revision_id) then raise exception 'AD_REVIEW_CONFLICT_OF_INTEREST'; end if;
  if p_review_scope='local' then
    if p_location_id is null or not app_private.has_location_staff_scope(p_location_id,'local_manager') then raise exception 'LOCAL_REVIEW_SCOPE_REQUIRED'; end if;
    if not exists(select 1 from public.ad_campaign_targets where campaign_id=v_campaign and location_id=p_location_id) then raise exception 'LOCATION_NOT_TARGETED'; end if;
  elsif p_review_scope='platform' then
    if p_location_id is not null or not app_private.has_account_capability('platform_admin') then raise exception 'PLATFORM_REVIEW_SCOPE_REQUIRED'; end if;
  else raise exception 'INVALID_REVIEW_SCOPE'; end if;
  if p_decision not in ('evidence_requested','changes_requested','approved','rejected') then raise exception 'INVALID_REVIEW_DECISION'; end if;
  if p_decision<>'approved' and nullif(btrim(p_reason),'') is null then raise exception 'REVIEW_REASON_REQUIRED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('revision_id',p_revision_id,'review_scope',p_review_scope,'location_id',p_location_id,'decision',p_decision,'reason',p_reason,'details',p_details)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'review_ad_campaign_revision',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  select id,state into v_review,v_old_state from public.ad_reviews where campaign_revision_id=p_revision_id and review_scope=p_review_scope and location_id is not distinct from p_location_id for update;
  if v_review is not null and v_old_state in ('approved','rejected') then raise exception 'AD_REVIEW_ALREADY_FINAL'; end if;
  if v_review is null then
    insert into public.ad_reviews(campaign_revision_id,reviewer_account_id,review_scope,location_id,state,reason,details,decided_at)
    values(p_revision_id,v_actor,p_review_scope,p_location_id,p_decision,nullif(btrim(p_reason),''),nullif(btrim(p_details),''),case when p_decision in ('approved','rejected') then now() else null end) returning id into v_review;
  else
    update public.ad_reviews set reviewer_account_id=v_actor,state=p_decision,reason=nullif(btrim(p_reason),''),details=nullif(btrim(p_details),''),decided_at=case when p_decision in ('approved','rejected') then now() else null end where id=v_review;
  end if;
  perform app_private.write_audit(v_actor,'ads.revision_review','ad_review',v_review,null,null,jsonb_build_object('revision_id',p_revision_id,'scope',p_review_scope,'location_id',p_location_id,'decision',p_decision));
  v_result:=jsonb_build_object('review_id',v_review,'revision_id',p_revision_id,'state',p_decision,'review_scope',p_review_scope,'location_id',p_location_id);
  perform app_private.complete_human_idempotent_command(v_actor,'review_ad_campaign_revision',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_confirm_ad_commercial_clearance(p_campaign_id uuid,p_clearance_type text,p_package_code text,p_agreed_amount numeric,p_currency_code text,p_reason text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_clearance uuid; v_result jsonb;
begin
  if not (app_private.has_account_capability('ads_commercial') or app_private.has_account_capability('platform_admin')) then raise exception 'NOT_AUTHORIZED'; end if;
  if not exists(select 1 from public.ad_campaigns where id=p_campaign_id and state<>'closed') then raise exception 'CAMPAIGN_NOT_ELIGIBLE'; end if;
  if p_clearance_type not in ('paid','waiver','other_authorized') then raise exception 'INVALID_CLEARANCE_TYPE'; end if;
  if p_agreed_amount is not null and p_agreed_amount<0 then raise exception 'INVALID_AGREED_AMOUNT'; end if;
  if p_currency_code is not null and char_length(p_currency_code)<>3 then raise exception 'INVALID_CURRENCY_CODE'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('campaign_id',p_campaign_id,'clearance_type',p_clearance_type,'package_code',p_package_code,'agreed_amount',p_agreed_amount,'currency_code',upper(p_currency_code),'reason',p_reason)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'confirm_ad_commercial_clearance',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.ad_commercial_clearances(campaign_id,state,clearance_type,package_code,agreed_amount,currency_code,authorized_by_account_id,reason)
  values(p_campaign_id,'cleared',p_clearance_type,nullif(btrim(p_package_code),''),p_agreed_amount,case when p_currency_code is null then null else upper(p_currency_code) end,v_actor,nullif(btrim(p_reason),''))
  on conflict(campaign_id) do update set state='cleared',clearance_type=excluded.clearance_type,package_code=excluded.package_code,agreed_amount=excluded.agreed_amount,currency_code=excluded.currency_code,authorized_by_account_id=excluded.authorized_by_account_id,reason=excluded.reason
  returning id into v_clearance;
  perform app_private.write_audit(v_actor,'ads.commercial_clear','ad_commercial_clearance',v_clearance,null,null,jsonb_build_object('campaign_id',p_campaign_id,'clearance_type',p_clearance_type,'package_code',p_package_code));
  v_result:=jsonb_build_object('clearance_id',v_clearance,'campaign_id',p_campaign_id,'state','cleared');
  perform app_private.complete_human_idempotent_command(v_actor,'confirm_ad_commercial_clearance',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_revoke_ad_commercial_clearance(p_campaign_id uuid,p_reason text,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_clearance uuid; v_state text; v_result jsonb;
begin
  if not (app_private.has_account_capability('ads_commercial') or app_private.has_account_capability('platform_admin')) then raise exception 'NOT_AUTHORIZED'; end if;
  if nullif(btrim(p_reason),'') is null then raise exception 'REVOCATION_REASON_REQUIRED'; end if;
  select id,state into v_clearance,v_state from public.ad_commercial_clearances where campaign_id=p_campaign_id for update; if not found then raise exception 'CLEARANCE_NOT_FOUND'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('campaign_id',p_campaign_id,'reason',p_reason)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'revoke_ad_commercial_clearance',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if v_state='revoked' then v_result:=jsonb_build_object('clearance_id',v_clearance,'campaign_id',p_campaign_id,'state','revoked','already_revoked',true);
  else update public.ad_commercial_clearances set state='revoked',reason=btrim(p_reason),authorized_by_account_id=v_actor where id=v_clearance; perform app_private.write_audit(v_actor,'ads.commercial_revoke','ad_commercial_clearance',v_clearance,null,null,jsonb_build_object('campaign_id',p_campaign_id,'reason_code',btrim(p_reason))); v_result:=jsonb_build_object('clearance_id',v_clearance,'campaign_id',p_campaign_id,'state','revoked','already_revoked',false); end if;
  perform app_private.complete_human_idempotent_command(v_actor,'revoke_ad_commercial_clearance',p_idempotency_key,v_result); return v_result;
end; $$;

create or replace function app_private.cmd_close_ad_campaign(p_campaign_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_state text; v_result jsonb;
begin
  if not app_private.campaign_advertiser_authority(p_campaign_id) then raise exception 'NOT_AUTHORIZED'; end if;
  select state into v_state from public.ad_campaigns where id=p_campaign_id for update; if not found then raise exception 'CAMPAIGN_NOT_FOUND'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('campaign_id',p_campaign_id)); v_gate:=app_private.begin_human_idempotent_command(v_actor,'close_ad_campaign',p_idempotency_key,v_fp); if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  if v_state='closed' then v_result:=jsonb_build_object('campaign_id',p_campaign_id,'state','closed','already_closed',true); else update public.ad_campaigns set state='closed' where id=p_campaign_id; v_result:=jsonb_build_object('campaign_id',p_campaign_id,'state','closed','already_closed',false); end if;
  perform app_private.complete_human_idempotent_command(v_actor,'close_ad_campaign',p_idempotency_key,v_result); return v_result;
end; $$;

revoke all on function app_private.has_advertiser_authority(uuid,uuid),app_private.campaign_advertiser_authority(uuid),app_private.advertising_enabled(uuid,uuid),app_private.advertiser_ads_restricted(uuid,uuid,uuid),app_private.ad_reviewer_conflicted(uuid),app_private.revision_approved_for_location(uuid,uuid),app_private.revision_approved_for_all_targets(uuid),
 app_private.cmd_set_advertising_eligibility(uuid,uuid,text,text,text),app_private.cmd_create_ad_campaign(uuid,uuid,text,text,text,text,timestamptz,timestamptz,text),app_private.cmd_set_ad_campaign_targets(uuid,jsonb,text),app_private.cmd_create_ad_campaign_revision(uuid,text,text,uuid,text,uuid,text,text,text),app_private.cmd_submit_ad_campaign_revision(uuid,text),app_private.cmd_submit_ad_evidence(uuid,uuid,text,text,text),app_private.cmd_review_ad_campaign_revision(uuid,text,uuid,text,text,text,text),app_private.cmd_confirm_ad_commercial_clearance(uuid,text,text,numeric,text,text,text),app_private.cmd_revoke_ad_commercial_clearance(uuid,text,text),app_private.cmd_close_ad_campaign(uuid,text)
from public,anon,authenticated,service_role;

grant execute on function app_private.has_advertiser_authority(uuid,uuid),app_private.campaign_advertiser_authority(uuid),app_private.advertising_enabled(uuid,uuid),app_private.advertiser_ads_restricted(uuid,uuid,uuid),app_private.revision_approved_for_location(uuid,uuid),app_private.revision_approved_for_all_targets(uuid) to authenticated;
grant execute on function app_private.cmd_set_advertising_eligibility(uuid,uuid,text,text,text),app_private.cmd_create_ad_campaign(uuid,uuid,text,text,text,text,timestamptz,timestamptz,text),app_private.cmd_set_ad_campaign_targets(uuid,jsonb,text),app_private.cmd_create_ad_campaign_revision(uuid,text,text,uuid,text,uuid,text,text,text),app_private.cmd_submit_ad_campaign_revision(uuid,text),app_private.cmd_submit_ad_evidence(uuid,uuid,text,text,text),app_private.cmd_review_ad_campaign_revision(uuid,text,uuid,text,text,text,text),app_private.cmd_confirm_ad_commercial_clearance(uuid,text,text,numeric,text,text,text),app_private.cmd_revoke_ad_commercial_clearance(uuid,text,text),app_private.cmd_close_ad_campaign(uuid,text) to authenticated;

create or replace function public.set_advertising_eligibility(p_account_id uuid,p_organization_id uuid,p_state text,p_reason text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_set_advertising_eligibility(p_account_id,p_organization_id,p_state,p_reason,p_idempotency_key); $$;
create or replace function public.create_ad_campaign(p_account_id uuid,p_organization_id uuid,p_objective text,p_campaign_name text,p_audience_context text,p_education_category text,p_starts_at timestamptz,p_ends_at timestamptz,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_create_ad_campaign(p_account_id,p_organization_id,p_objective,p_campaign_name,p_audience_context,p_education_category,p_starts_at,p_ends_at,p_idempotency_key); $$;
create or replace function public.set_ad_campaign_targets(p_campaign_id uuid,p_targets jsonb,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_set_ad_campaign_targets(p_campaign_id,p_targets,p_idempotency_key); $$;
create or replace function public.create_ad_campaign_revision(p_campaign_id uuid,p_headline text,p_body text,p_image_asset_id uuid,p_destination_type text,p_destination_id uuid,p_external_url text,p_cta_type text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_create_ad_campaign_revision(p_campaign_id,p_headline,p_body,p_image_asset_id,p_destination_type,p_destination_id,p_external_url,p_cta_type,p_idempotency_key); $$;
create or replace function public.submit_ad_campaign_revision(p_revision_id uuid,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_submit_ad_campaign_revision(p_revision_id,p_idempotency_key); $$;
create or replace function public.submit_ad_evidence(p_revision_id uuid,p_file_asset_id uuid,p_external_url text,p_note text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_submit_ad_evidence(p_revision_id,p_file_asset_id,p_external_url,p_note,p_idempotency_key); $$;
create or replace function public.review_ad_campaign_revision(p_revision_id uuid,p_review_scope text,p_location_id uuid,p_decision text,p_reason text,p_details text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_review_ad_campaign_revision(p_revision_id,p_review_scope,p_location_id,p_decision,p_reason,p_details,p_idempotency_key); $$;
create or replace function public.confirm_ad_commercial_clearance(p_campaign_id uuid,p_clearance_type text,p_package_code text,p_agreed_amount numeric,p_currency_code text,p_reason text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_confirm_ad_commercial_clearance(p_campaign_id,p_clearance_type,p_package_code,p_agreed_amount,p_currency_code,p_reason,p_idempotency_key); $$;
create or replace function public.revoke_ad_commercial_clearance(p_campaign_id uuid,p_reason text,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_revoke_ad_commercial_clearance(p_campaign_id,p_reason,p_idempotency_key); $$;
create or replace function public.close_ad_campaign(p_campaign_id uuid,p_idempotency_key text) returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_close_ad_campaign(p_campaign_id,p_idempotency_key); $$;

revoke all on function public.set_advertising_eligibility(uuid,uuid,text,text,text),public.create_ad_campaign(uuid,uuid,text,text,text,text,timestamptz,timestamptz,text),public.set_ad_campaign_targets(uuid,jsonb,text),public.create_ad_campaign_revision(uuid,text,text,uuid,text,uuid,text,text,text),public.submit_ad_campaign_revision(uuid,text),public.submit_ad_evidence(uuid,uuid,text,text,text),public.review_ad_campaign_revision(uuid,text,uuid,text,text,text,text),public.confirm_ad_commercial_clearance(uuid,text,text,numeric,text,text,text),public.revoke_ad_commercial_clearance(uuid,text,text),public.close_ad_campaign(uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.set_advertising_eligibility(uuid,uuid,text,text,text),public.create_ad_campaign(uuid,uuid,text,text,text,text,timestamptz,timestamptz,text),public.set_ad_campaign_targets(uuid,jsonb,text),public.create_ad_campaign_revision(uuid,text,text,uuid,text,uuid,text,text,text),public.submit_ad_campaign_revision(uuid,text),public.submit_ad_evidence(uuid,uuid,text,text,text),public.review_ad_campaign_revision(uuid,text,uuid,text,text,text,text),public.confirm_ad_commercial_clearance(uuid,text,text,numeric,text,text,text),public.revoke_ad_commercial_clearance(uuid,text,text),public.close_ad_campaign(uuid,text) to authenticated;
