-- Raahi Learning V1.2 — authorized file coordinates for browser download/open flows.
-- Knowing an asset id never bypasses business authorization.

create or replace function app_private.read_file_asset_access(p_file_asset_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path=''
as $$
declare v_result jsonb;
begin
  if not app_private.can_read_file_asset(p_file_asset_id) then raise exception 'NOT_AUTHORIZED'; end if;
  select jsonb_build_object(
    'file_asset_id',f.id,
    'bucket_id',f.storage_bucket_id,
    'object_name',f.storage_object_name,
    'purpose_code',f.purpose_code,
    'mime_type',f.mime_type,
    'size_bytes',f.size_bytes,
    'public_bucket',f.storage_bucket_id in ('public-profile-media','community-public','ads-public')
  ) into v_result
  from public.file_assets f
  where f.id=p_file_asset_id and f.status='active';
  if v_result is null then raise exception 'FILE_ASSET_NOT_FOUND'; end if;
  return v_result;
end;
$$;

revoke all on function app_private.read_file_asset_access(uuid) from public,anon,authenticated,service_role;
grant execute on function app_private.read_file_asset_access(uuid) to authenticated;

create or replace function public.get_file_asset_access(p_file_asset_id uuid)
returns jsonb
language sql
stable security invoker
set search_path=''
as $$ select app_private.read_file_asset_access(p_file_asset_id); $$;

revoke all on function public.get_file_asset_access(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_file_asset_access(uuid) to authenticated;
