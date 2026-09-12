-- Raahi Learning V1.2 — Ads eligibility, Campaigns, immutable revisions, review and commercial clearance.

create table public.advertising_eligibility (
  id uuid primary key default gen_random_uuid(),
  account_id uuid null references public.accounts(id),
  organization_id uuid null references public.organizations(id),
  state text not null default 'not_enabled',
  reason text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint advertising_eligibility_subject_xor check ((account_id is not null)::int+(organization_id is not null)::int=1),
  constraint advertising_eligibility_state_check check (state in ('not_enabled','under_review','enabled','restricted','disabled'))
);

create table public.ad_campaigns (
  id uuid primary key default gen_random_uuid(),
  account_id uuid null references public.accounts(id),
  organization_id uuid null references public.organizations(id),
  objective text not null,
  campaign_name text not null,
  audience_context text null,
  education_category text null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  state text not null default 'draft',
  created_by_account_id uuid not null references public.accounts(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ad_campaigns_owner_xor check ((account_id is not null)::int+(organization_id is not null)::int=1),
  constraint ad_campaigns_objective_check check (objective in ('admissions','course_batch','event','awareness')),
  constraint ad_campaigns_name_nonblank check (char_length(btrim(campaign_name)) between 1 and 200),
  constraint ad_campaigns_dates_check check (ends_at>starts_at),
  constraint ad_campaigns_state_check check (state in ('draft','submitted','closed'))
);

create table public.ad_campaign_targets (
  campaign_id uuid not null references public.ad_campaigns(id),
  location_id uuid not null references public.locations(id),
  placement_type text not null,
  created_at timestamptz not null default now(),
  primary key(campaign_id,location_id,placement_type),
  constraint ad_campaign_targets_placement_check check (placement_type in ('home_sponsored','explore_sponsored','community_event'))
);

create table public.ad_campaign_revisions (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.ad_campaigns(id),
  revision_number integer not null,
  headline text not null,
  body text not null,
  image_asset_id uuid null references public.file_assets(id),
  destination_type text not null,
  destination_id uuid null,
  external_url text null,
  cta_type text not null,
  submitted_at timestamptz null,
  created_by_account_id uuid not null references public.accounts(id),
  created_at timestamptz not null default now(),
  constraint ad_campaign_revisions_number_positive check (revision_number>=1),
  constraint ad_campaign_revisions_headline_nonblank check (char_length(btrim(headline)) between 1 and 180),
  constraint ad_campaign_revisions_body_nonblank check (char_length(btrim(body)) between 1 and 4000),
  constraint ad_campaign_revisions_destination_check check (destination_type in ('teaching_option','organization','external_url')),
  constraint ad_campaign_revisions_destination_shape check ((destination_type='external_url' and external_url is not null and destination_id is null) or (destination_type in ('teaching_option','organization') and destination_id is not null and external_url is null)),
  constraint ad_campaign_revisions_cta_check check (cta_type in ('enquire','learn_more','visit_site')),
  constraint ad_campaign_revisions_campaign_number_unique unique(campaign_id,revision_number)
);

create table public.ad_reviews (
  id uuid primary key default gen_random_uuid(),
  campaign_revision_id uuid not null references public.ad_campaign_revisions(id),
  reviewer_account_id uuid not null references public.accounts(id),
  review_scope text not null,
  location_id uuid null references public.locations(id),
  state text not null default 'under_review',
  reason text null,
  details text null,
  created_at timestamptz not null default now(),
  decided_at timestamptz null,
  updated_at timestamptz not null default now(),
  constraint ad_reviews_scope_check check (review_scope in ('local','platform')),
  constraint ad_reviews_scope_location_check check ((review_scope='local' and location_id is not null) or (review_scope='platform' and location_id is null)),
  constraint ad_reviews_state_check check (state in ('under_review','evidence_requested','changes_requested','approved','rejected')),
  constraint ad_reviews_decision_consistency check ((state in ('approved','rejected') and decided_at is not null) or state not in ('approved','rejected'))
);

create table public.ad_claim_evidence (
  id uuid primary key default gen_random_uuid(),
  campaign_revision_id uuid not null references public.ad_campaign_revisions(id),
  file_asset_id uuid null references public.file_assets(id),
  external_url text null,
  submitted_by_account_id uuid not null references public.accounts(id),
  note text null,
  created_at timestamptz not null default now(),
  constraint ad_claim_evidence_shape check ((file_asset_id is not null)::int+(external_url is not null)::int>=1)
);

create table public.ad_commercial_clearances (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null unique references public.ad_campaigns(id),
  state text not null default 'pending',
  clearance_type text null,
  package_code text null,
  agreed_amount numeric(14,2) null,
  currency_code text null,
  authorized_by_account_id uuid null references public.accounts(id),
  reason text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ad_commercial_clearances_state_check check (state in ('pending','cleared','revoked')),
  constraint ad_commercial_clearances_type_check check (clearance_type is null or clearance_type in ('paid','waiver','other_authorized')),
  constraint ad_commercial_clearances_amount_check check (agreed_amount is null or agreed_amount>=0),
  constraint ad_commercial_clearances_currency_check check (currency_code is null or char_length(currency_code)=3),
  constraint ad_commercial_cleared_shape check (state<>'cleared' or (clearance_type is not null and authorized_by_account_id is not null))
);

create unique index advertising_eligibility_account_idx on public.advertising_eligibility(account_id) where account_id is not null;
create unique index advertising_eligibility_org_idx on public.advertising_eligibility(organization_id) where organization_id is not null;
create index ad_campaigns_account_state_idx on public.ad_campaigns(account_id,state,created_at desc) where account_id is not null;
create index ad_campaigns_org_state_idx on public.ad_campaigns(organization_id,state,created_at desc) where organization_id is not null;
create index ad_campaigns_created_by_idx on public.ad_campaigns(created_by_account_id,created_at desc);
create index ad_campaign_targets_location_idx on public.ad_campaign_targets(location_id,placement_type,campaign_id);
create index ad_campaign_revisions_campaign_time_idx on public.ad_campaign_revisions(campaign_id,created_at desc);
create index ad_campaign_revisions_image_idx on public.ad_campaign_revisions(image_asset_id) where image_asset_id is not null;
create unique index ad_reviews_platform_one_idx on public.ad_reviews(campaign_revision_id) where review_scope='platform';
create unique index ad_reviews_local_one_idx on public.ad_reviews(campaign_revision_id,location_id) where review_scope='local';
create index ad_reviews_reviewer_idx on public.ad_reviews(reviewer_account_id,created_at desc);
create index ad_reviews_location_state_idx on public.ad_reviews(location_id,state,created_at) where location_id is not null;
create index ad_claim_evidence_revision_idx on public.ad_claim_evidence(campaign_revision_id,created_at);
create index ad_claim_evidence_file_idx on public.ad_claim_evidence(file_asset_id) where file_asset_id is not null;
create index ad_claim_evidence_submitter_idx on public.ad_claim_evidence(submitted_by_account_id,created_at desc);
create index ad_commercial_authorized_by_idx on public.ad_commercial_clearances(authorized_by_account_id) where authorized_by_account_id is not null;

create trigger advertising_eligibility_set_updated_at before update on public.advertising_eligibility for each row execute function app_private.set_updated_at();
create trigger ad_campaigns_set_updated_at before update on public.ad_campaigns for each row execute function app_private.set_updated_at();
create trigger ad_reviews_set_updated_at before update on public.ad_reviews for each row execute function app_private.set_updated_at();
create trigger ad_commercial_clearances_set_updated_at before update on public.ad_commercial_clearances for each row execute function app_private.set_updated_at();

create or replace function app_private.guard_submitted_ad_revision()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if old.submitted_at is not null then raise exception 'SUBMITTED_AD_REVISION_IMMUTABLE'; end if;
  return new;
end; $$;
create trigger ad_campaign_revisions_immutable_after_submit before update or delete on public.ad_campaign_revisions for each row execute function app_private.guard_submitted_ad_revision();
revoke all on function app_private.guard_submitted_ad_revision() from public,anon,authenticated,service_role;
