-- Raahi Learning V1.4C — covering indexes for assisted-onboarding foreign keys.
-- Added from the post-migration Supabase performance advisor before release freeze.

create index assisted_teacher_requested_by_idx
  on public.assisted_teacher_onboarding_requests(requested_by_account_id);

create index assisted_teacher_founding_location_idx
  on public.assisted_teacher_onboarding_requests(founding_location_id);

create index assisted_teacher_prepared_by_idx
  on public.assisted_teacher_onboarding_requests(proposal_prepared_by_account_id)
  where proposal_prepared_by_account_id is not null;

create index assisted_teacher_resolved_by_idx
  on public.assisted_teacher_onboarding_requests(resolved_by_account_id)
  where resolved_by_account_id is not null;

create index teacher_profiles_assisted_request_idx
  on public.teacher_profiles(assisted_onboarding_request_id)
  where assisted_onboarding_request_id is not null;
