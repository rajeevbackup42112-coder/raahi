-- Raahi Learning V1.3 — CONTROLLED PILOT public-domain cleanup.
-- DANGEROUS BY DESIGN: never run during DEV/STAGE.
-- This script intentionally preserves public.locations and Auth identities.
-- It refuses to run unless the caller sets the exact transaction-local confirmation:
--
--   begin;
--   set local "raahi.pilot_cleanup_confirmation" = 'CLEAN_SYNTHETIC_PUBLIC_DOMAIN_FOR_CONTROLLED_PILOT';
--   -- then execute this script in the same transaction/session
--
-- The launch operator must first complete the backup + writer seal gates in doc 78.

do $$
declare
  v_confirm text := current_setting('raahi.pilot_cleanup_confirmation', true);
  v_public_tables integer;
  v_non_harness integer;
  v_storage_objects integer;
begin
  if v_confirm is distinct from 'CLEAN_SYNTHETIC_PUBLIC_DOMAIN_FOR_CONTROLLED_PILOT' then
    raise exception 'PILOT_CLEANUP_CONFIRMATION_REQUIRED';
  end if;

  select count(*) into v_public_tables
  from information_schema.tables
  where table_schema='public' and table_type='BASE TABLE';

  if v_public_tables <> 69 then
    raise exception 'PILOT_CLEANUP_SCHEMA_DRIFT public_table_count=%', v_public_tables;
  end if;

  select count(*) into v_non_harness
  from auth.users
  where not coalesce((raw_user_meta_data->>'raahi_test_harness')::boolean,false);

  if v_non_harness <> 8 then
    raise exception 'PILOT_CLEANUP_NON_HARNESS_AUTH_REVIEW_REQUIRED count=%', v_non_harness;
  end if;

  select count(*) into v_storage_objects from storage.objects;
  if v_storage_objects <> 0 then
    raise exception 'PILOT_CLEANUP_STORAGE_MUST_BE_BACKED_UP_AND_EMPTIED objects=%', v_storage_objects;
  end if;

  if (select count(*) from public.locations) <> 2 then
    raise exception 'PILOT_CLEANUP_LOCATION_COUNT_GUARD_FAILED';
  end if;
  if not exists(select 1 from public.locations where slug='dhanbad' and state='live') then
    raise exception 'PILOT_CLEANUP_DHANBAD_STATE_GUARD_FAILED';
  end if;
  if not exists(select 1 from public.locations where slug='gomoh' and state='preparing') then
    raise exception 'PILOT_CLEANUP_GOMOH_STATE_GUARD_FAILED';
  end if;
end $$;

truncate table public.access_restrictions, public.account_capabilities, public.account_learner_access, public.account_location_preferences, public.accounts, public.activities, public.activity_material_links, public.ad_campaign_revisions, public.ad_campaign_targets, public.ad_campaigns, public.ad_claim_evidence, public.ad_commercial_clearances, public.ad_frequency_state, public.ad_inventory_days, public.ad_inventory_reservation_days, public.ad_inventory_reservations, public.ad_metrics_daily, public.ad_placements, public.ad_reviews, public.advertising_eligibility, public.audit_log, public.blocks, public.class_invitations, public.class_learner_messages, public.class_learner_threads, public.class_memberships, public.class_post_comments, public.class_posts, public.class_sessions, public.classes, public.community_comment_reactions, public.community_comments, public.community_post_reactions, public.community_posts, public.enquiries, public.enquiry_messages, public.enquiry_trial_events, public.file_assets, public.hidden_campaigns, public.idempotency_keys, public.learner_self_access_invitations, public.learner_share_codes, public.learners, public.learning_requests, public.location_interests, public.location_staff_assignments, public.material_class_links, public.materials, public.notifications, public.organization_member_capabilities, public.organization_member_invitations, public.organization_members, public.organizations, public.reports, public.saved_organizations, public.saved_teacher_profiles, public.saved_teaching_options, public.submission_revisions, public.submissions, public.teacher_profiles, public.teaching_option_locations, public.teaching_options, public.test_attempt_answers, public.test_attempts, public.test_choices, public.test_questions, public.tests, public.verification_claims restart identity cascade;

do $$
declare
  r record;
  v_count bigint;
begin
  for r in
    select table_name
    from information_schema.tables
    where table_schema='public' and table_type='BASE TABLE' and table_name <> 'locations'
    order by table_name
  loop
    execute format('select count(*) from public.%I',r.table_name) into v_count;
    if v_count <> 0 then
      raise exception 'PILOT_CLEANUP_POSTCONDITION_FAILED table=% count=%', r.table_name, v_count;
    end if;
  end loop;

  if (select count(*) from public.locations) <> 2 then
    raise exception 'PILOT_CLEANUP_LOCATION_PRESERVATION_FAILED';
  end if;
end $$;

-- The launch operator commits the surrounding transaction only after verifying
-- the postconditions above. Otherwise ROLLBACK.
