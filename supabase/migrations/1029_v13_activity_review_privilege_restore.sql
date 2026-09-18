-- Raahi Learning V1.3 — restore canonical Activity review execution grant after 1028 replacement.
-- Public request/review wrappers are SECURITY INVOKER and depend on authenticated execute
-- for app_private.cmd_review_submission, as originally established by migration 0601.

grant execute on function app_private.cmd_review_submission(uuid,text,text,text)
to authenticated;
