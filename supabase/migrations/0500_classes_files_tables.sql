-- Raahi Learning V1.2 — Classes, Invitations, Memberships, Sessions and protected file/material metadata

create table public.classes (
  id uuid primary key default gen_random_uuid(),
  responsible_teacher_account_id uuid not null references public.accounts(id),
  organization_id uuid null references public.organizations(id),
  location_id uuid null references public.locations(id),
  title text not null,
  class_type text not null,
  capacity integer not null,
  state text not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint classes_title_nonblank check (char_length(btrim(title)) between 1 and 200),
  constraint classes_type_check check (class_type in ('one_to_one','group')),
  constraint classes_capacity_positive check (capacity >= 1),
  constraint classes_one_to_one_capacity check (class_type <> 'one_to_one' or capacity = 1),
  constraint classes_state_check check (state in ('draft','active','past'))
);

create table public.class_invitations (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id),
  learner_id uuid not null references public.learners(id),
  invited_by_account_id uuid not null references public.accounts(id),
  state text not null default 'pending',
  expires_at timestamptz not null,
  fee_display_text text null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz null,
  constraint class_invitations_state_check check (state in ('pending','accepted','declined','expired','cancelled')),
  constraint class_invitations_expiry_after_creation check (expires_at > created_at),
  constraint class_invitations_resolution_check check (
    (state='pending' and resolved_at is null)
    or (state in ('accepted','declined','expired','cancelled') and resolved_at is not null)
  ),
  constraint class_invitations_fee_length check (fee_display_text is null or char_length(fee_display_text) <= 500)
);

create table public.class_memberships (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id),
  learner_id uuid not null references public.learners(id),
  state text not null default 'active',
  joined_via_invitation_id uuid null references public.class_invitations(id),
  joined_at timestamptz not null default now(),
  ended_at timestamptz null,
  end_reason text null,
  transferred_to_membership_id uuid null references public.class_memberships(id),
  created_at timestamptz not null default now(),
  constraint class_memberships_state_check check (state in ('active','completed','left','transferred','removed')),
  constraint class_memberships_end_consistency check (
    (state='active' and ended_at is null)
    or (state in ('completed','left','transferred','removed') and ended_at is not null)
  ),
  constraint class_memberships_transfer_consistency check (
    (state='transferred' and transferred_to_membership_id is not null)
    or (state<>'transferred' and transferred_to_membership_id is null)
  )
);

create table public.class_sessions (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id),
  starts_at timestamptz not null,
  ends_at timestamptz null,
  delivery_mode text not null,
  meeting_or_location_text text null,
  cancelled_at timestamptz null,
  cancel_reason text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint class_sessions_delivery_check check (delivery_mode in ('online','in_person')),
  constraint class_sessions_end_after_start check (ends_at is null or ends_at > starts_at),
  constraint class_sessions_cancel_consistency check (
    (cancelled_at is null and cancel_reason is null)
    or (cancelled_at is not null and cancel_reason is not null)
  )
);

create table public.file_assets (
  id uuid primary key default gen_random_uuid(),
  uploaded_by_account_id uuid not null references public.accounts(id),
  storage_path text not null unique,
  purpose_code text not null,
  mime_type text null,
  size_bytes bigint null,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  constraint file_assets_storage_path_nonblank check (char_length(btrim(storage_path)) between 1 and 1000),
  constraint file_assets_purpose_nonblank check (char_length(btrim(purpose_code)) between 1 and 120),
  constraint file_assets_size_nonnegative check (size_bytes is null or size_bytes >= 0),
  constraint file_assets_status_check check (status in ('active','removed'))
);

create table public.materials (
  id uuid primary key default gen_random_uuid(),
  created_by_account_id uuid not null references public.accounts(id),
  title text not null,
  description text null,
  resource_type text not null,
  file_asset_id uuid null references public.file_assets(id),
  external_url text null,
  text_content text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint materials_title_nonblank check (char_length(btrim(title)) between 1 and 300),
  constraint materials_resource_type_check check (resource_type in ('file','external_link','text')),
  constraint materials_resource_consistency check (
    (resource_type='file' and file_asset_id is not null and external_url is null and text_content is null)
    or (resource_type='external_link' and file_asset_id is null and external_url is not null and text_content is null)
    or (resource_type='text' and file_asset_id is null and external_url is null and text_content is not null)
  )
);

create table public.material_class_links (
  material_id uuid not null references public.materials(id),
  class_id uuid not null references public.classes(id),
  created_at timestamptz not null default now(),
  primary key(material_id,class_id)
);

create trigger classes_set_updated_at before update on public.classes for each row execute function app_private.set_updated_at();
create trigger class_sessions_set_updated_at before update on public.class_sessions for each row execute function app_private.set_updated_at();
create trigger materials_set_updated_at before update on public.materials for each row execute function app_private.set_updated_at();
