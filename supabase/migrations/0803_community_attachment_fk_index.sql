-- Raahi Learning V1.2 — covering FK index found by Supabase Performance Advisor.
create index community_posts_attachment_asset_idx
  on public.community_posts(attachment_asset_id)
  where attachment_asset_id is not null;
