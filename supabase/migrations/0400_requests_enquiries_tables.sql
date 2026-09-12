-- Raahi Learning V1.2 — Learning Requests, Enquiries and optional Trial events
-- Implementation clarification: Enquiry persists location_id so Location-scoped
-- restrictions and historical origin context remain authoritative after the
-- Account later changes selected Location.

create table public.learning_requests (
  id uuid primary key default gen_random_uuid(),
  learner_id uuid not null references public.learners(id),
  created_by_account_id uuid not null references public.accounts(id),
  location_id uuid not null references public.locations(id),
  need_text text not null,
  category text null,
  mode_preference text null,
  details text null,
  timing_preference text null,
  state text not null default 'draft',
  close_reason text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz null,
  constraint learning_requests_need_nonblank check (char_length(btrim(need_text)) between 1 and 500),
  constraint learning_requests_category_length check (category is null or char_length(category) <= 120),
  constraint learning_requests_mode_check check (mode_preference is null or mode_preference in ('online','in_person','either')),
  constraint learning_requests_details_length check (details is null or char_length(details) <= 4000),
  constraint learning_requests_timing_length check (timing_preference is null or char_length(timing_preference) <= 500),
  constraint learning_requests_state_check check (state in ('draft','open','closed')),
  constraint learning_requests_close_consistency check (
    (state='closed' and close_reason is not null and closed_at is not null)
    or (state in ('draft','open') and close_reason is null and closed_at is null)
  )
);

create table public.enquiries (
  id uuid primary key default gen_random_uuid(),
  learner_id uuid not null references public.learners(id),
  created_by_account_id uuid not null references public.accounts(id),
  location_id uuid not null references public.locations(id),
  provider_account_id uuid null references public.accounts(id),
  provider_organization_id uuid null references public.organizations(id),
  teaching_option_id uuid null references public.teaching_options(id),
  learning_request_id uuid null references public.learning_requests(id),
  source_type text not null,
  state text not null default 'pending',
  close_reason text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  activated_at timestamptz null,
  closed_at timestamptz null,
  constraint enquiries_provider_xor check ((provider_account_id is not null)::int + (provider_organization_id is not null)::int = 1),
  constraint enquiries_source_type_check check (source_type in ('direct','learning_request','sponsored')),
  constraint enquiries_source_context_check check (
    (source_type in ('direct','sponsored') and teaching_option_id is not null and learning_request_id is null)
    or (source_type='learning_request' and learning_request_id is not null and teaching_option_id is null)
  ),
  constraint enquiries_state_check check (state in ('pending','active','closed')),
  constraint enquiries_lifecycle_consistency check (
    (state='pending' and activated_at is null and closed_at is null and close_reason is null)
    or (state='active' and activated_at is not null and closed_at is null and close_reason is null)
    or (state='closed' and closed_at is not null and close_reason is not null)
  )
);

create table public.enquiry_messages (
  id uuid primary key default gen_random_uuid(),
  enquiry_id uuid not null references public.enquiries(id),
  sender_account_id uuid null references public.accounts(id),
  body text not null,
  message_type text not null default 'text',
  created_at timestamptz not null default now(),
  constraint enquiry_messages_body_nonblank check (char_length(btrim(body)) between 1 and 8000),
  constraint enquiry_messages_type_check check (message_type in ('text','system','controlled_structured')),
  constraint enquiry_messages_sender_consistency check (message_type='system' or sender_account_id is not null)
);

create table public.enquiry_trial_events (
  id uuid primary key default gen_random_uuid(),
  enquiry_id uuid not null references public.enquiries(id),
  proposed_by_account_id uuid not null references public.accounts(id),
  scheduled_at timestamptz not null,
  status text not null default 'scheduled',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint enquiry_trial_status_check check (status in ('proposed','scheduled','cancelled','completed'))
);

create unique index learning_requests_one_exact_open_need_idx
  on public.learning_requests(learner_id,location_id,lower(btrim(need_text)))
  where state='open';
create index learning_requests_learner_state_idx on public.learning_requests(learner_id,state,updated_at desc);
create index learning_requests_location_open_idx on public.learning_requests(location_id,updated_at desc) where state='open';
create index learning_requests_created_by_idx on public.learning_requests(created_by_account_id,created_at desc);

create unique index enquiries_direct_one_live_context_idx
  on public.enquiries(learner_id,teaching_option_id)
  where source_type in ('direct','sponsored') and state in ('pending','active');
create unique index enquiries_request_teacher_one_live_context_idx
  on public.enquiries(learning_request_id,provider_account_id)
  where source_type='learning_request' and provider_account_id is not null and state in ('pending','active');
create unique index enquiries_request_org_one_live_context_idx
  on public.enquiries(learning_request_id,provider_organization_id)
  where source_type='learning_request' and provider_organization_id is not null and state in ('pending','active');
create index enquiries_learner_state_idx on public.enquiries(learner_id,state,updated_at desc);
create index enquiries_provider_account_state_idx on public.enquiries(provider_account_id,state,updated_at desc) where provider_account_id is not null;
create index enquiries_provider_org_state_idx on public.enquiries(provider_organization_id,state,updated_at desc) where provider_organization_id is not null;
create index enquiries_location_state_idx on public.enquiries(location_id,state,updated_at desc);
create index enquiries_teaching_option_idx on public.enquiries(teaching_option_id) where teaching_option_id is not null;
create index enquiries_learning_request_idx on public.enquiries(learning_request_id) where learning_request_id is not null;
create index enquiries_created_by_idx on public.enquiries(created_by_account_id,created_at desc);

create index enquiry_messages_enquiry_time_idx on public.enquiry_messages(enquiry_id,created_at,id);
create index enquiry_messages_sender_idx on public.enquiry_messages(sender_account_id,created_at desc) where sender_account_id is not null;
create index enquiry_trial_events_enquiry_time_idx on public.enquiry_trial_events(enquiry_id,scheduled_at desc);
create index enquiry_trial_events_proposed_by_idx on public.enquiry_trial_events(proposed_by_account_id,created_at desc);

create trigger learning_requests_set_updated_at before update on public.learning_requests for each row execute function app_private.set_updated_at();
create trigger enquiries_set_updated_at before update on public.enquiries for each row execute function app_private.set_updated_at();
create trigger enquiry_trial_events_set_updated_at before update on public.enquiry_trial_events for each row execute function app_private.set_updated_at();
