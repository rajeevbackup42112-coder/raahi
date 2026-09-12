-- Raahi Learning V1.2 — frontend onboarding commands.
-- Teaching is a self-selected product capability; verification remains separate.

create or replace function app_private.cmd_enable_teaching(p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb;
  v_fp text:=app_private.request_fingerprint('{}'::jsonb); v_id uuid; v_result jsonb;
begin
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'enable_teaching',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  select id into v_id from public.account_capabilities
  where account_id=v_actor and capability_code='teach' and status='active' limit 1;
  if v_id is not null then
    v_result:=jsonb_build_object('capability_id',v_id,'capability_code','teach','already_active',true);
    perform app_private.complete_human_idempotent_command(v_actor,'enable_teaching',p_idempotency_key,v_result);
    return v_result;
  end if;

  if exists(select 1 from public.account_capabilities where account_id=v_actor and capability_code='teach' and status='revoked') then
    raise exception 'TEACHING_REENABLE_REQUIRES_REVIEW';
  end if;

  insert into public.account_capabilities(account_id,capability_code,granted_by_account_id)
  values(v_actor,'teach',v_actor) returning id into v_id;
  perform app_private.write_audit(v_actor,'account.teaching_enable','account',v_actor,null,null,'{}'::jsonb);
  v_result:=jsonb_build_object('capability_id',v_id,'capability_code','teach','already_active',false);
  perform app_private.complete_human_idempotent_command(v_actor,'enable_teaching',p_idempotency_key,v_result);
  return v_result;
end; $$;

create or replace function app_private.cmd_update_account_profile(
  p_display_name text,p_avatar_type text,p_avatar_ref text,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(false); v_gate jsonb; v_fp text; v_result jsonb;
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_display_name is null or char_length(btrim(p_display_name)) not between 1 and 120 then raise exception 'INVALID_DISPLAY_NAME'; end if;
  if p_avatar_type not in ('builtin','upload','none') then raise exception 'INVALID_AVATAR_TYPE'; end if;
  if (p_avatar_type='none' and p_avatar_ref is not null)
     or (p_avatar_type in ('builtin','upload') and nullif(btrim(p_avatar_ref),'') is null)
  then raise exception 'INVALID_AVATAR_REFERENCE'; end if;

  v_fp:=app_private.request_fingerprint(jsonb_build_object('display_name',p_display_name,'avatar_type',p_avatar_type,'avatar_ref',p_avatar_ref));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'update_account_profile',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;

  update public.accounts set display_name=btrim(p_display_name),avatar_type=p_avatar_type,avatar_ref=p_avatar_ref where id=v_actor;
  perform app_private.write_audit(v_actor,'account.profile_update','account',v_actor);
  v_result:=jsonb_build_object('account_id',v_actor,'display_name',btrim(p_display_name),'avatar_type',p_avatar_type,'avatar_ref',p_avatar_ref);
  perform app_private.complete_human_idempotent_command(v_actor,'update_account_profile',p_idempotency_key,v_result);
  return v_result;
end; $$;

revoke all on function app_private.cmd_enable_teaching(text),app_private.cmd_update_account_profile(text,text,text,text) from public,anon,authenticated,service_role;
grant execute on function app_private.cmd_enable_teaching(text),app_private.cmd_update_account_profile(text,text,text,text) to authenticated;

create or replace function public.enable_teaching(p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_enable_teaching(p_idempotency_key); $$;
create or replace function public.update_account_profile(p_display_name text,p_avatar_type text,p_avatar_ref text,p_idempotency_key text)
returns jsonb language sql security invoker set search_path='' as $$ select app_private.cmd_update_account_profile(p_display_name,p_avatar_type,p_avatar_ref,p_idempotency_key); $$;
revoke all on function public.enable_teaching(text),public.update_account_profile(text,text,text,text) from public,anon,authenticated,service_role;
grant execute on function public.enable_teaching(text),public.update_account_profile(text,text,text,text) to authenticated;
