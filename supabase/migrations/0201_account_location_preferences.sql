-- Raahi Learning V1.2 — Account selected Location preference

create table public.account_location_preferences (
  account_id uuid primary key references public.accounts(id),
  selected_location_id uuid not null references public.locations(id),
  updated_at timestamptz not null default now()
);

comment on table public.account_location_preferences is 'Discovery/community Location preference only. It does not own or move established relationships/history.';

create index account_location_preferences_location_idx
  on public.account_location_preferences (selected_location_id);

create trigger account_location_preferences_set_updated_at
before update on public.account_location_preferences
for each row execute function app_private.set_updated_at();