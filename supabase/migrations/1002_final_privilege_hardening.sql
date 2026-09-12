-- Raahi Learning V1.2 — final privilege hardening.
-- Consequential state changes remain RPC-only; direct authenticated DML is denied.

revoke create on schema public from public,anon,authenticated;
revoke execute on all functions in schema app_private from public;
revoke execute on all functions in schema public from public;
revoke insert,update,delete,truncate,references,trigger on all tables in schema public from public,anon,authenticated;

alter default privileges in schema app_private revoke execute on functions from public;
alter default privileges in schema public revoke execute on functions from public;
alter default privileges in schema public revoke all on tables from public;

-- Keep app_private non-discoverable except for explicitly granted RPC helper execution.
revoke create on schema app_private from public,anon,authenticated;
