-- Raahi Learning V1.2 — governed Supabase Storage authorization.
-- Completes the storage plan after all business authorization helpers exist.

insert into storage.buckets(id,name,public)
values
  ('public-profile-media','public-profile-media',true),
  ('learner-private-media','learner-private-media',false),
  ('class-private','class-private',false),
  ('community-public','community-public',true),
  ('ads-public','ads-public',true),
  ('ads-review-private','ads-review-private',false)
on conflict (id) do update set name=excluded.name,public=excluded.public;

alter table public.file_assets add column storage_bucket_id text null;
alter table public.file_assets add column storage_object_name text null;
-- Dev is clean; keep a safe forward path for any future pre-hardening row.
update public.file_assets
set storage_bucket_id=case
    when purpose_code in ('activity_submission','class_material') then 'class-private'
    when purpose_code='community_attachment' then 'community-public'
    when purpose_code in ('ad_creative','ad_claim_evidence') then 'ads-review-private'
    when purpose_code='learner_private' then 'learner-private-media'
    when purpose_code='profile_public' then 'public-profile-media'
    else null end,
    storage_object_name=case when position('/' in storage_path)>0 then storage_path else null end
where storage_bucket_id is null;

-- No unknown legacy file metadata may silently become accessible.
do $$ begin
  if exists(select 1 from public.file_assets where storage_bucket_id is null or storage_object_name is null) then
    raise exception 'UNMAPPED_FILE_ASSET_REQUIRES_MANUAL_REVIEW';
  end if;
end $$;

alter table public.file_assets alter column storage_bucket_id set not null;
alter table public.file_assets alter column storage_object_name set not null;
alter table public.file_assets add constraint file_assets_bucket_check check (storage_bucket_id in ('public-profile-media','learner-private-media','class-private','community-public','ads-review-private','ads-public'));
alter table public.file_assets add constraint file_assets_object_name_nonblank check (char_length(btrim(storage_object_name)) between 1 and 900 and storage_object_name !~ '^/' and storage_object_name !~ '(^|/)\.\.(/|$)');
alter table public.file_assets add constraint file_assets_bucket_object_unique unique(storage_bucket_id,storage_object_name);

create or replace function app_private.file_asset_bucket_for_purpose(p_purpose_code text)
returns text language sql immutable set search_path='' as $$
  select case p_purpose_code
    when 'activity_submission' then 'class-private'
    when 'class_material' then 'class-private'
    when 'community_attachment' then 'community-public'
    when 'ad_creative' then 'ads-review-private'
    when 'ad_claim_evidence' then 'ads-review-private'
    when 'learner_private' then 'learner-private-media'
    when 'profile_public' then 'public-profile-media'
    else null
  end;
$$;

create or replace function app_private.cmd_register_file_asset(
  p_storage_path text,p_purpose_code text,p_mime_type text,p_size_bytes bigint,p_idempotency_key text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=app_private.require_current_account(true); v_gate jsonb; v_fp text; v_file uuid; v_result jsonb;
  v_bucket text; v_object text;
begin
  if p_storage_path is null or char_length(btrim(p_storage_path)) not between 1 and 900 then raise exception 'INVALID_STORAGE_OBJECT_NAME'; end if;
  v_object:=btrim(p_storage_path);
  if v_object ~ '^/' or v_object ~ '(^|/)\.\.(/|$)' then raise exception 'INVALID_STORAGE_OBJECT_NAME'; end if;
  v_bucket:=app_private.file_asset_bucket_for_purpose(p_purpose_code);
  if v_bucket is null then raise exception 'INVALID_FILE_PURPOSE'; end if;
  if p_size_bytes is not null and p_size_bytes<0 then raise exception 'INVALID_FILE_SIZE'; end if;
  -- ads-public is service-published only; user creative/evidence is reviewed privately first.
  if v_bucket='ads-public' then raise exception 'ADS_PUBLIC_SERVICE_ONLY'; end if;
  v_fp:=app_private.request_fingerprint(jsonb_build_object('object_name',v_object,'bucket_id',v_bucket,'purpose_code',p_purpose_code,'mime_type',p_mime_type,'size_bytes',p_size_bytes));
  v_gate:=app_private.begin_human_idempotent_command(v_actor,'register_file_asset',p_idempotency_key,v_fp);
  if (v_gate->>'cached')::boolean then return v_gate->'result'; end if;
  insert into public.file_assets(uploaded_by_account_id,storage_path,storage_bucket_id,storage_object_name,purpose_code,mime_type,size_bytes)
  values(v_actor,v_bucket||'/'||v_object,v_bucket,v_object,p_purpose_code,nullif(btrim(p_mime_type),''),p_size_bytes)
  returning id into v_file;
  v_result:=jsonb_build_object('file_asset_id',v_file,'status','active','bucket_id',v_bucket,'object_name',v_object);
  perform app_private.complete_human_idempotent_command(v_actor,'register_file_asset',p_idempotency_key,v_result);
  return v_result;
end; $$;

-- Private business-data read authorization is checked every object read.
create or replace function app_private.can_read_file_asset(p_file_asset_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.file_assets f
    where f.id=p_file_asset_id and f.status='active' and (
      f.uploaded_by_account_id=app_private.current_account_id()
      or exists(select 1 from public.materials m where m.file_asset_id=f.id and app_private.can_read_material(m.id))
      or exists(select 1 from public.submission_revisions sr where sr.file_asset_id=f.id and app_private.can_read_submission(sr.submission_id))
      or exists(select 1 from public.ad_claim_evidence e where e.file_asset_id=f.id and app_private.can_read_ad_evidence(e.campaign_revision_id))
      or exists(select 1 from public.ad_campaign_revisions r where r.image_asset_id=f.id and app_private.can_read_ad_campaign(r.campaign_id))
      or exists(
        select 1 from public.ad_campaign_revisions r join public.ad_placements p on p.serving_revision_id=r.id
        where r.image_asset_id=f.id and p.state='live' and current_date between p.starts_on and p.ends_on
          and app_private.ad_placement_prerequisites_ok(p.campaign_id,p.location_id,p.placement_type,p.inventory_reservation_id,p.serving_revision_id,p.starts_on,p.ends_on)
          and exists(select 1 from public.accounts a where a.id=app_private.current_account_id() and a.lifecycle_status='active')
      )
      or exists(select 1 from public.community_posts cp where cp.attachment_asset_id=f.id and cp.visibility_status='published')
    )
  );
$$;

create or replace function app_private.can_write_registered_storage_object(p_bucket_id text,p_object_name text)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.file_assets f
    where f.storage_bucket_id=p_bucket_id and f.storage_object_name=p_object_name and f.status='active'
      and f.uploaded_by_account_id=app_private.current_account_id()
      and exists(select 1 from public.accounts a where a.id=f.uploaded_by_account_id and a.lifecycle_status='active')
  );
$$;

create or replace function app_private.can_read_registered_storage_object(p_bucket_id text,p_object_name text)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.file_assets f
    where f.storage_bucket_id=p_bucket_id and f.storage_object_name=p_object_name and f.status='active'
      and app_private.can_read_file_asset(f.id)
  );
$$;

create or replace function app_private.storage_first_folder_uuid(p_object_name text)
returns uuid language plpgsql immutable set search_path='' as $$
declare v_text text;
begin
  v_text:=(storage.foldername(p_object_name))[1];
  if v_text is null then return null; end if;
  begin return v_text::uuid; exception when invalid_text_representation then return null; end;
end; $$;

revoke all on function app_private.file_asset_bucket_for_purpose(text),app_private.can_write_registered_storage_object(text,text),app_private.can_read_registered_storage_object(text,text),app_private.storage_first_folder_uuid(text) from public,anon,authenticated,service_role;
grant execute on function app_private.can_write_registered_storage_object(text,text),app_private.can_read_registered_storage_object(text,text),app_private.storage_first_folder_uuid(text),app_private.can_read_file_asset(uuid) to authenticated;

-- Public profile media: deliberately public reads; owner-folder writes only.
create policy raahi_public_profile_insert on storage.objects for insert to authenticated
with check (bucket_id='public-profile-media' and app_private.storage_first_folder_uuid(name)=app_private.current_account_id());
create policy raahi_public_profile_update on storage.objects for update to authenticated
using (bucket_id='public-profile-media' and app_private.storage_first_folder_uuid(name)=app_private.current_account_id())
with check (bucket_id='public-profile-media' and app_private.storage_first_folder_uuid(name)=app_private.current_account_id());
create policy raahi_public_profile_delete on storage.objects for delete to authenticated
using (bucket_id='public-profile-media' and app_private.storage_first_folder_uuid(name)=app_private.current_account_id());

-- Learner-private media: no copied URL/path can bypass current learner relationship.
create policy raahi_learner_private_select on storage.objects for select to authenticated
using (bucket_id='learner-private-media' and app_private.can_access_learner(app_private.storage_first_folder_uuid(name)));
create policy raahi_learner_private_insert on storage.objects for insert to authenticated
with check (bucket_id='learner-private-media' and app_private.can_access_learner(app_private.storage_first_folder_uuid(name)));
create policy raahi_learner_private_update on storage.objects for update to authenticated
using (bucket_id='learner-private-media' and app_private.can_access_learner(app_private.storage_first_folder_uuid(name)))
with check (bucket_id='learner-private-media' and app_private.can_access_learner(app_private.storage_first_folder_uuid(name)));
create policy raahi_learner_private_delete on storage.objects for delete to authenticated
using (bucket_id='learner-private-media' and app_private.can_access_learner(app_private.storage_first_folder_uuid(name)));

-- Registered domain assets: metadata must exist before upload; reads re-check business authorization.
create policy raahi_registered_private_select on storage.objects for select to authenticated
using (bucket_id in ('class-private','ads-review-private') and app_private.can_read_registered_storage_object(bucket_id,name));
create policy raahi_registered_asset_insert on storage.objects for insert to authenticated
with check (bucket_id in ('class-private','community-public','ads-review-private') and app_private.can_write_registered_storage_object(bucket_id,name));
create policy raahi_registered_asset_update on storage.objects for update to authenticated
using (bucket_id in ('class-private','community-public','ads-review-private') and app_private.can_write_registered_storage_object(bucket_id,name))
with check (bucket_id in ('class-private','community-public','ads-review-private') and app_private.can_write_registered_storage_object(bucket_id,name));
create policy raahi_registered_asset_delete on storage.objects for delete to authenticated
using (bucket_id in ('class-private','community-public','ads-review-private') and app_private.can_write_registered_storage_object(bucket_id,name));

-- `ads-public` has no authenticated write policy by design. Approved assets may be copied
-- there only by trusted service-side publication logic during UI/backend integration.
