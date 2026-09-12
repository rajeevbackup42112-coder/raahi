-- Raahi Learning V1.2 — integration-safe cleanup for registered uploads that never become attached.

create or replace function app_private.cmd_abandon_file_asset(p_file_asset_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(false); v_gate jsonb; v_fp text;
  v_owner uuid; v_status text; v_result jsonb;
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('file_asset_id',p_file_asset_id));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'abandon_file_asset',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select uploaded_by_account_id,status into v_owner,v_status
  from public.file_assets where id=p_file_asset_id for update;
  if not found then raise exception 'FILE_ASSET_NOT_FOUND'; end if;
  if v_owner<>v_actor and not app_private.has_account_capability('platform_admin') then raise exception 'NOT_AUTHORIZED'; end if;

  if v_status='removed' then
    v_result:=jsonb_build_object('file_asset_id',p_file_asset_id,'status','removed','already_removed',true);
    perform app_private.complete_human_idempotent_command(v_actor,'abandon_file_asset',p_idempotency_key,v_result);
    return v_result;
  end if;

  if exists(select 1 from public.materials where file_asset_id=p_file_asset_id)
     or exists(select 1 from public.submission_revisions where file_asset_id=p_file_asset_id)
     or exists(select 1 from public.community_posts where attachment_asset_id=p_file_asset_id)
     or exists(select 1 from public.ad_claim_evidence where file_asset_id=p_file_asset_id)
     or exists(select 1 from public.ad_campaign_revisions where image_asset_id=p_file_asset_id)
  then raise exception 'FILE_ASSET_IN_USE'; end if;

  update public.file_assets set status='removed' where id=p_file_asset_id;
  perform app_private.write_audit(v_actor,'file_asset.abandon','file_asset',p_file_asset_id,null,'unattached_upload_cleanup','{}'::jsonb);
  v_result:=jsonb_build_object('file_asset_id',p_file_asset_id,'status','removed','already_removed',false);
  perform app_private.complete_human_idempotent_command(v_actor,'abandon_file_asset',p_idempotency_key,v_result);
  return v_result;
end; $$;

revoke all on function app_private.cmd_abandon_file_asset(uuid,text) from public,anon,authenticated,service_role;
grant execute on function app_private.cmd_abandon_file_asset(uuid,text) to authenticated;

create or replace function public.abandon_file_asset(p_file_asset_id uuid,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$
  select app_private.cmd_abandon_file_asset(p_file_asset_id,p_idempotency_key);
$$;
revoke all on function public.abandon_file_asset(uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.abandon_file_asset(uuid,text) to authenticated;
