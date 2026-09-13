-- Raahi Learning DEV ONLY — one-time first-platform-admin bootstrap
-- Project: iiwwmqokaeflaenhlyip (raahi-learning-dev)
--
-- This is deliberately NOT under supabase/migrations/. It must never be applied
-- automatically to production. Normal capability grants must use the canonical
-- public.grant_account_capability() command after a platform administrator exists.
--
-- Safety guards:
--   * refuses to run if any active platform_admin already exists;
--   * targets exactly one active Raahi Account joined to the designated DEV Google identity;
--   * records a system audit event;
--   * uses granted_by_account_id = NULL only for this first-environment bootstrap.

DO $bootstrap$
DECLARE
  v_target_account_id uuid;
  v_active_admin_count integer;
BEGIN
  SELECT count(*)
    INTO v_active_admin_count
  FROM public.account_capabilities
  WHERE capability_code = 'platform_admin'
    AND status = 'active';

  IF v_active_admin_count <> 0 THEN
    RAISE EXCEPTION 'DEV_BOOTSTRAP_REFUSED: active platform_admin already exists';
  END IF;

  SELECT a.id
    INTO STRICT v_target_account_id
  FROM public.accounts a
  JOIN auth.users u ON u.id = a.auth_user_id
  WHERE lower(u.email) = lower('rajeev.backup5.2112@gmail.com')
    AND a.lifecycle_status = 'active';

  INSERT INTO public.account_capabilities (
    account_id,
    capability_code,
    status,
    granted_by_account_id
  ) VALUES (
    v_target_account_id,
    'platform_admin',
    'active',
    NULL
  );

  INSERT INTO public.audit_log (
    actor_kind,
    actor_account_id,
    action_type,
    target_type,
    target_id,
    reason,
    metadata
  ) VALUES (
    'system',
    NULL,
    'dev.bootstrap_platform_admin',
    'account',
    v_target_account_id,
    'One-time first-administrator bootstrap for Raahi Learning DEV project iiwwmqokaeflaenhlyip.',
    jsonb_build_object(
      'environment', 'dev',
      'project_ref', 'iiwwmqokaeflaenhlyip',
      'designated_google_identity', 'rajeev.backup5.2112@gmail.com'
    )
  );
END
$bootstrap$;
