-- Raahi Learning V1.2 — tighten app_private function EXECUTE defaults
-- Forward-fix after inspecting pg_proc ACLs in the shared dev project.

revoke execute on all functions in schema app_private from public;

-- RLS/read helpers needed by authenticated policy evaluation and authorized callers.
grant execute on function app_private.current_account_id() to authenticated;
grant execute on function app_private.current_account_status() to authenticated;
grant execute on function app_private.has_account_capability(text) to authenticated;
grant execute on function app_private.has_learner_self_access(uuid) to authenticated;
grant execute on function app_private.can_manage_learner(uuid) to authenticated;
grant execute on function app_private.can_access_learner(uuid) to authenticated;
grant execute on function app_private.can_make_learning_decision(uuid) to authenticated;

-- Private command implementations are not exposed through PostgREST because
-- app_private is not an exposed schema. Public SECURITY INVOKER wrappers call
-- these functions, so authenticated requires EXECUTE.
grant execute on function app_private.cmd_bootstrap_account(text) to authenticated;
grant execute on function app_private.cmd_create_learner(text,text,text,text,text) to authenticated;
grant execute on function app_private.cmd_grant_learner_self_access(uuid,uuid,text) to authenticated;
grant execute on function app_private.cmd_transfer_learner_management(uuid,uuid,text) to authenticated;
grant execute on function app_private.cmd_end_learner_access(uuid,text) to authenticated;
grant execute on function app_private.cmd_grant_account_capability(uuid,text,text) to authenticated;
grant execute on function app_private.cmd_revoke_account_capability(uuid,text,text) to authenticated;
grant execute on function app_private.cmd_pause_account(text) to authenticated;
grant execute on function app_private.cmd_resume_account(text) to authenticated;
grant execute on function app_private.cmd_request_account_closure(text) to authenticated;
