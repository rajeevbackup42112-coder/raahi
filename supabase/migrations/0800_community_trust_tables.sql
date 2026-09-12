-- Raahi Learning V1.2 — Location Community, Reports, Blocks and exact verification claims.

create table public.community_posts (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations(id),
  author_account_id uuid not null references public.accounts(id),
  post_type text not null default 'discussion',
  body text not null,
  attachment_asset_id uuid null references public.file_assets(id),
  external_url text null,
  visibility_status text not null default 'published',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint community_posts_type_check check (post_type in ('discussion','question','resource','event','update')),
  constraint community_posts_body_nonblank check (char_length(btrim(body)) between 1 and 12000),
  constraint community_posts_visibility_check check (visibility_status in ('published','hidden','removed'))
);

create table public.community_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id),
  author_account_id uuid not null references public.accounts(id),
  body text not null,
  visibility_status text not null default 'published',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint community_comments_body_nonblank check (char_length(btrim(body)) between 1 and 8000),
  constraint community_comments_visibility_check check (visibility_status in ('published','hidden','removed'))
);

create table public.community_post_reactions (
  post_id uuid not null references public.community_posts(id),
  account_id uuid not null references public.accounts(id),
  reaction_type text not null,
  created_at timestamptz not null default now(),
  primary key(post_id,account_id),
  constraint community_post_reaction_type_check check (reaction_type in ('helpful','thanks','support','interesting'))
);

create table public.community_comment_reactions (
  comment_id uuid not null references public.community_comments(id),
  account_id uuid not null references public.accounts(id),
  reaction_type text not null,
  created_at timestamptz not null default now(),
  primary key(comment_id,account_id),
  constraint community_comment_reaction_type_check check (reaction_type in ('helpful','thanks','support','interesting'))
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_account_id uuid not null references public.accounts(id),
  context_learner_id uuid null references public.learners(id),
  location_id uuid null references public.locations(id),
  target_type text not null,
  target_id uuid not null,
  reason_code text not null,
  details text null,
  evidence_snapshot jsonb not null default '{}'::jsonb,
  status text not null default 'open',
  resolved_by_account_id uuid null references public.accounts(id),
  resolution_code text null,
  resolution_note text null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz null,
  constraint reports_target_type_check check (target_type in ('account','organization','teaching_option','learning_request','enquiry','class','community_post','community_comment')),
  constraint reports_reason_nonblank check (char_length(btrim(reason_code)) between 1 and 120),
  constraint reports_details_length check (details is null or char_length(details)<=8000),
  constraint reports_status_check check (status in ('open','under_review','resolved','dismissed')),
  constraint reports_resolution_consistency check (
    (status in ('resolved','dismissed') and resolved_at is not null and resolved_by_account_id is not null and resolution_code is not null)
    or (status in ('open','under_review') and resolved_at is null and resolved_by_account_id is null and resolution_code is null)
  )
);

create table public.blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_account_id uuid not null references public.accounts(id),
  blocked_account_id uuid not null references public.accounts(id),
  state text not null default 'active',
  created_at timestamptz not null default now(),
  lifted_at timestamptz null,
  constraint blocks_no_self check (blocker_account_id<>blocked_account_id),
  constraint blocks_state_check check (state in ('active','lifted')),
  constraint blocks_lift_consistency check ((state='active' and lifted_at is null) or (state='lifted' and lifted_at is not null))
);

create table public.verification_claims (
  id uuid primary key default gen_random_uuid(),
  account_id uuid null references public.accounts(id),
  organization_id uuid null references public.organizations(id),
  claim_type text not null,
  status text not null default 'pending',
  verified_at timestamptz null,
  verified_by_account_id uuid null references public.accounts(id),
  revoked_at timestamptz null,
  revoked_by_account_id uuid null references public.accounts(id),
  reason text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint verification_claims_subject_xor check ((account_id is not null)::int+(organization_id is not null)::int=1),
  constraint verification_claims_type_nonblank check (char_length(btrim(claim_type)) between 1 and 120),
  constraint verification_claims_status_check check (status in ('pending','verified','revoked','rejected')),
  constraint verification_claims_verified_consistency check ((status='verified' and verified_at is not null and verified_by_account_id is not null and revoked_at is null and revoked_by_account_id is null) or status<>'verified'),
  constraint verification_claims_revoked_consistency check ((status='revoked' and revoked_at is not null and revoked_by_account_id is not null) or status<>'revoked')
);

create unique index blocks_one_active_pair_idx on public.blocks(blocker_account_id,blocked_account_id) where state='active';
create index blocks_blocked_active_idx on public.blocks(blocked_account_id) where state='active';
create index community_posts_location_time_idx on public.community_posts(location_id,created_at desc) where visibility_status='published';
create index community_posts_author_idx on public.community_posts(author_account_id,created_at desc);
create index community_comments_post_time_idx on public.community_comments(post_id,created_at);
create index community_comments_author_idx on public.community_comments(author_account_id,created_at desc);
create index community_post_reactions_account_idx on public.community_post_reactions(account_id,created_at desc);
create index community_comment_reactions_account_idx on public.community_comment_reactions(account_id,created_at desc);
create index reports_reporter_time_idx on public.reports(reporter_account_id,created_at desc);
create index reports_location_status_idx on public.reports(location_id,status,created_at) where location_id is not null;
create index reports_status_time_idx on public.reports(status,created_at);
create index reports_context_learner_idx on public.reports(context_learner_id,created_at desc) where context_learner_id is not null;
create index reports_resolved_by_idx on public.reports(resolved_by_account_id) where resolved_by_account_id is not null;
create unique index verification_claims_account_live_idx on public.verification_claims(account_id,claim_type) where account_id is not null and status in ('pending','verified');
create unique index verification_claims_org_live_idx on public.verification_claims(organization_id,claim_type) where organization_id is not null and status in ('pending','verified');
create index verification_claims_verified_by_idx on public.verification_claims(verified_by_account_id) where verified_by_account_id is not null;
create index verification_claims_revoked_by_idx on public.verification_claims(revoked_by_account_id) where revoked_by_account_id is not null;

create trigger community_posts_set_updated_at before update on public.community_posts for each row execute function app_private.set_updated_at();
create trigger community_comments_set_updated_at before update on public.community_comments for each row execute function app_private.set_updated_at();
create trigger verification_claims_set_updated_at before update on public.verification_claims for each row execute function app_private.set_updated_at();
