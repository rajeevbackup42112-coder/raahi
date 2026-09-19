-- Raahi Learning V1.3 — invitation acceptance foreign-key indexes.
-- Performance-only migration: no authority, RLS, state or RPC semantics change.
-- Supabase Database Advisor identified both accepted_by_account_id foreign keys
-- as lacking covering indexes. Keep the indexes even if young DEV traffic has
-- not yet exercised them; they support relationship joins and FK maintenance
-- as these invitation tables grow.

create index if not exists learner_self_access_invite_accepted_by_idx
  on public.learner_self_access_invitations (accepted_by_account_id);

create index if not exists organization_member_invite_accepted_by_idx
  on public.organization_member_invitations (accepted_by_account_id);
