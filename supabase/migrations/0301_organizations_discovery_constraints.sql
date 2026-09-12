-- Raahi Learning V1.2 — Organizations/discovery constraints and indexes

alter table public.organizations
  add constraint organizations_type_check check (
    organization_type in ('school','university','college','coaching','academy','other_education')
  ),
  add constraint organizations_name_nonblank check (char_length(btrim(name)) between 1 and 160),
  add constraint organizations_description_length check (description is null or char_length(description) <= 4000),
  add constraint organizations_public_contact_length check (public_contact_text is null or char_length(public_contact_text) <= 500),
  add constraint organizations_venue_length check (venue_text is null or char_length(venue_text) <= 500),
  add constraint organizations_website_length check (website_url is null or char_length(website_url) <= 1000),
  add constraint organizations_logo_type_check check (logo_type in ('builtin','upload','none')),
  add constraint organizations_logo_consistency check (
    (logo_type = 'none' and logo_ref is null)
    or (logo_type in ('builtin','upload') and logo_ref is not null)
  ),
  add constraint organizations_status_check check (status in ('active','hidden','closed'));

alter table public.organization_members
  add constraint organization_members_status_check check (status in ('active','ended')),
  add constraint organization_members_end_consistency check (
    (status = 'active' and ended_at is null)
    or (status = 'ended' and ended_at is not null)
  );

alter table public.organization_member_capabilities
  add constraint organization_member_capability_check check (
    capability_code in ('manage_profile','manage_teaching_options','manage_classes','manage_ads','manage_members')
  );

alter table public.teacher_profiles
  add constraint teacher_profiles_headline_length check (headline is null or char_length(headline) <= 240),
  add constraint teacher_profiles_bio_length check (bio is null or char_length(bio) <= 5000),
  add constraint teacher_profiles_experience_length check (experience_summary is null or char_length(experience_summary) <= 2000),
  add constraint teacher_profiles_visibility_check check (visibility_status in ('visible','hidden'));

alter table public.teaching_options
  add constraint teaching_options_owner_xor check (
    (teacher_account_id is not null)::int + (organization_id is not null)::int = 1
  ),
  add constraint teaching_options_title_nonblank check (char_length(btrim(title)) between 1 and 200),
  add constraint teaching_options_category_length check (category is null or char_length(category) <= 120),
  add constraint teaching_options_description_length check (description is null or char_length(description) <= 5000),
  add constraint teaching_options_mode_check check (teaching_mode in ('online','in_person','both')),
  add constraint teaching_options_area_length check (area_or_venue_text is null or char_length(area_or_venue_text) <= 500),
  add constraint teaching_options_fee_length check (fee_display_text is null or char_length(fee_display_text) <= 500),
  add constraint teaching_options_availability_check check (
    availability_status in ('taking_new_learners','not_taking_new_learners','no_longer_offered')
  );

create unique index organization_members_one_active_account_idx
  on public.organization_members (organization_id, account_id)
  where status = 'active';

create index organization_members_account_active_idx
  on public.organization_members (account_id, organization_id)
  where status = 'active';

create index organization_members_org_status_idx
  on public.organization_members (organization_id, status);

create index organization_member_capabilities_code_idx
  on public.organization_member_capabilities (capability_code, organization_member_id);

create index teaching_options_teacher_idx
  on public.teaching_options (teacher_account_id, availability_status)
  where teacher_account_id is not null;

create index teaching_options_organization_idx
  on public.teaching_options (organization_id, availability_status)
  where organization_id is not null;

create index teaching_option_locations_location_idx
  on public.teaching_option_locations (location_id, teaching_option_id);

create index saved_teacher_profiles_teacher_idx
  on public.saved_teacher_profiles (teacher_account_id, created_at desc);

create index saved_teaching_options_option_idx
  on public.saved_teaching_options (teaching_option_id, created_at desc);

create index saved_organizations_org_idx
  on public.saved_organizations (organization_id, created_at desc);
