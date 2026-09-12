-- Raahi Learning V1.2 — Class capacity-supporting uniqueness and indexes

create unique index class_invitations_one_pending_per_class_learner_idx
  on public.class_invitations(class_id,learner_id)
  where state='pending';

create unique index class_memberships_one_active_per_class_learner_idx
  on public.class_memberships(class_id,learner_id)
  where state='active';

create index class_invitations_class_pending_expiry_idx
  on public.class_invitations(class_id,expires_at)
  where state='pending';
create index class_invitations_learner_state_idx
  on public.class_invitations(learner_id,state,created_at desc);
create index class_invitations_invited_by_idx
  on public.class_invitations(invited_by_account_id,created_at desc);

create index class_memberships_class_state_idx
  on public.class_memberships(class_id,state,joined_at);
create index class_memberships_learner_state_idx
  on public.class_memberships(learner_id,state,joined_at desc);
create index class_memberships_invitation_idx
  on public.class_memberships(joined_via_invitation_id)
  where joined_via_invitation_id is not null;

create index classes_teacher_state_idx
  on public.classes(responsible_teacher_account_id,state,updated_at desc);
create index classes_organization_state_idx
  on public.classes(organization_id,state,updated_at desc)
  where organization_id is not null;
create index classes_location_state_idx
  on public.classes(location_id,state,updated_at desc)
  where location_id is not null;

create index class_sessions_class_start_idx on public.class_sessions(class_id,starts_at desc);
create index file_assets_uploader_idx on public.file_assets(uploaded_by_account_id,created_at desc);
create index materials_creator_idx on public.materials(created_by_account_id,updated_at desc);
create index materials_file_asset_idx on public.materials(file_asset_id) where file_asset_id is not null;
create index material_class_links_class_idx on public.material_class_links(class_id,material_id);
