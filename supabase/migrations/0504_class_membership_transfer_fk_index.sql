-- Raahi Learning V1.2 — Performance advisor follow-up
create index class_memberships_transferred_to_idx
  on public.class_memberships(transferred_to_membership_id)
  where transferred_to_membership_id is not null;
