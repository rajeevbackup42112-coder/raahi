-- Raahi Learning V1.2 — finite daily Ads inventory, exact-revision Placements and private user serving state.

create table public.ad_inventory_days (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id),
  placement_type text not null,
  inventory_date date not null,
  capacity integer not null,
  max_units_per_campaign integer not null,
  per_account_daily_cap integer not null,
  rate_card_code text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ad_inventory_days_placement_check check (placement_type in ('home_sponsored','explore_sponsored','community_event')),
  constraint ad_inventory_days_capacity_check check (capacity>=0),
  constraint ad_inventory_days_concentration_check check (max_units_per_campaign>=0 and max_units_per_campaign<=capacity),
  constraint ad_inventory_days_frequency_check check (per_account_daily_cap>=1),
  constraint ad_inventory_days_unique unique(location_id,placement_type,inventory_date)
);

create table public.ad_inventory_reservations (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.ad_campaigns(id),
  requested_by_account_id uuid not null references public.accounts(id),
  state text not null default 'held',
  hold_expires_at timestamptz null,
  resolved_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ad_inventory_reservations_state_check check (state in ('held','confirmed','released','expired')),
  constraint ad_inventory_reservations_hold_shape check ((state='held' and hold_expires_at is not null and resolved_at is null) or (state<>'held' and resolved_at is not null))
);

create table public.ad_inventory_reservation_days (
  reservation_id uuid not null references public.ad_inventory_reservations(id),
  inventory_day_id uuid not null references public.ad_inventory_days(id),
  units integer not null,
  created_at timestamptz not null default now(),
  primary key(reservation_id,inventory_day_id),
  constraint ad_inventory_reservation_days_units_check check (units>0)
);

create table public.ad_placements (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.ad_campaigns(id),
  location_id uuid not null references public.locations(id),
  placement_type text not null,
  inventory_reservation_id uuid not null references public.ad_inventory_reservations(id),
  serving_revision_id uuid not null references public.ad_campaign_revisions(id),
  starts_on date not null,
  ends_on date not null,
  state text not null default 'waiting',
  pause_reason text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ad_placements_type_check check (placement_type in ('home_sponsored','explore_sponsored','community_event')),
  constraint ad_placements_dates_check check (ends_on>=starts_on),
  constraint ad_placements_state_check check (state in ('waiting','live','paused','ended','cancelled')),
  constraint ad_placements_pause_shape check ((state='paused' and pause_reason is not null) or state<>'paused'),
  constraint ad_placements_reservation_target_unique unique(inventory_reservation_id,location_id,placement_type)
);

create table public.hidden_campaigns (
  account_id uuid not null references public.accounts(id),
  campaign_id uuid not null references public.ad_campaigns(id),
  hide_reason text null,
  created_at timestamptz not null default now(),
  primary key(account_id,campaign_id)
);

create table public.ad_frequency_state (
  account_id uuid not null references public.accounts(id),
  campaign_id uuid not null references public.ad_campaigns(id),
  window_started_at timestamptz not null,
  served_count integer not null default 0,
  last_served_at timestamptz null,
  updated_at timestamptz not null default now(),
  primary key(account_id,campaign_id),
  constraint ad_frequency_state_count_check check (served_count>=0)
);

create table public.ad_metrics_daily (
  ad_placement_id uuid not null references public.ad_placements(id),
  metric_date date not null,
  sponsored_views bigint not null default 0,
  opens bigint not null default 0,
  enquiries bigint not null default 0,
  external_visits bigint not null default 0,
  updated_at timestamptz not null default now(),
  primary key(ad_placement_id,metric_date),
  constraint ad_metrics_nonnegative check (sponsored_views>=0 and opens>=0 and enquiries>=0 and external_visits>=0)
);

create index ad_inventory_days_lookup_idx on public.ad_inventory_days(location_id,placement_type,inventory_date);
create index ad_inventory_reservations_campaign_state_idx on public.ad_inventory_reservations(campaign_id,state,created_at desc);
create index ad_inventory_reservations_requester_idx on public.ad_inventory_reservations(requested_by_account_id,created_at desc);
create index ad_inventory_reservation_days_day_idx on public.ad_inventory_reservation_days(inventory_day_id,reservation_id);
create index ad_placements_location_state_idx on public.ad_placements(location_id,placement_type,state,starts_on,ends_on);
create index ad_placements_campaign_state_idx on public.ad_placements(campaign_id,state,created_at desc);
create index ad_placements_revision_idx on public.ad_placements(serving_revision_id);
create index ad_placements_reservation_idx on public.ad_placements(inventory_reservation_id);
create index hidden_campaigns_campaign_idx on public.hidden_campaigns(campaign_id);
create index ad_frequency_state_campaign_idx on public.ad_frequency_state(campaign_id,updated_at desc);
create index ad_metrics_daily_date_idx on public.ad_metrics_daily(metric_date,ad_placement_id);

create trigger ad_inventory_days_set_updated_at before update on public.ad_inventory_days for each row execute function app_private.set_updated_at();
create trigger ad_inventory_reservations_set_updated_at before update on public.ad_inventory_reservations for each row execute function app_private.set_updated_at();
create trigger ad_placements_set_updated_at before update on public.ad_placements for each row execute function app_private.set_updated_at();
create trigger ad_frequency_state_set_updated_at before update on public.ad_frequency_state for each row execute function app_private.set_updated_at();
create trigger ad_metrics_daily_set_updated_at before update on public.ad_metrics_daily for each row execute function app_private.set_updated_at();
