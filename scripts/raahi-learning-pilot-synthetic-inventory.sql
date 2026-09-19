-- Raahi Learning V1.3 — read-only synthetic/pilot cutover inventory.
-- Safe before Stage/Pilot cutover. Performs no DDL/DML.
-- Harness users are identified by the authoritative DEV identity-factory marker.

with test_users as (
  select id
  from auth.users
  where coalesce((raw_user_meta_data->>'raahi_test_harness')::boolean,false)
),
test_accounts as (
  select a.id
  from public.accounts a
  join test_users u on u.id=a.auth_user_id
),
non_test_linked_accounts as (
  select a.id
  from public.accounts a
  join auth.users u on u.id=a.auth_user_id
  where not coalesce((u.raw_user_meta_data->>'raahi_test_harness')::boolean,false)
),
test_learners as (
  select id from public.learners
  where created_by_account_id in (select id from test_accounts)
),
test_orgs as (
  select id from public.organizations
  where created_by_account_id in (select id from test_accounts)
),
test_classes as (
  select id from public.classes
  where responsible_teacher_account_id in (select id from test_accounts)
     or organization_id in (select id from test_orgs)
)
select jsonb_pretty(jsonb_build_object(
  'observed_at_utc', now(),
  'auth', jsonb_build_object(
    'test_harness_users', (select count(*) from test_users),
    'test_harness_linked_accounts', (select count(*) from test_accounts),
    'non_test_linked_accounts', (select count(*) from non_test_linked_accounts)
  ),
  'synthetic_roots', jsonb_build_object(
    'learners_created_by_test_accounts', (select count(*) from test_learners),
    'organizations_created_by_test_accounts', (select count(*) from test_orgs),
    'teacher_profiles_for_test_accounts', (
      select count(*) from public.teacher_profiles
      where account_id in (select id from test_accounts)
    ),
    'teaching_options_owned_by_test_accounts_or_orgs', (
      select count(*) from public.teaching_options
      where teacher_account_id in (select id from test_accounts)
         or organization_id in (select id from test_orgs)
    ),
    'classes_owned_by_test_accounts_or_orgs', (select count(*) from test_classes),
    'learning_requests_from_test_graph', (
      select count(*) from public.learning_requests
      where created_by_account_id in (select id from test_accounts)
         or learner_id in (select id from test_learners)
    ),
    'enquiries_from_test_graph', (
      select count(*) from public.enquiries
      where created_by_account_id in (select id from test_accounts)
         or provider_account_id in (select id from test_accounts)
         or provider_organization_id in (select id from test_orgs)
         or learner_id in (select id from test_learners)
    ),
    'class_memberships_for_test_graph', (
      select count(*) from public.class_memberships
      where class_id in (select id from test_classes)
         or learner_id in (select id from test_learners)
    ),
    'notifications_for_test_accounts', (
      select count(*) from public.notifications
      where recipient_account_id in (select id from test_accounts)
    ),
    'idempotency_keys_for_test_accounts', (
      select count(*) from public.idempotency_keys
      where actor_account_id in (select id from test_accounts)
    ),
    'audit_rows_by_test_accounts', (
      select count(*) from public.audit_log
      where actor_account_id in (select id from test_accounts)
    )
  ),
  'pilot_configuration', jsonb_build_object(
    'locations', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id',id,'name',name,'slug',slug,'state',state
      ) order by name),'[]'::jsonb)
      from public.locations
    ),
    'storage_objects', (select count(*) from storage.objects)
  )
)) as pilot_synthetic_inventory;
