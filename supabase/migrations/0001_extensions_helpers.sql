-- Raahi Learning V1.2 — Foundation
-- Safe defaults, private helper schema, and explicit Data API exposure policy.

create extension if not exists pgcrypto with schema extensions;

create schema if not exists app_private authorization postgres;

revoke all on schema app_private from public, anon, authenticated, service_role;
revoke create on schema public from public;

-- New application objects are opt-in to the Data API. Every intended grant is
-- made explicitly in the migration that also defines RLS/policies.
alter default privileges for role postgres in schema public
  revoke select, insert, update, delete on tables from anon, authenticated, service_role;

alter default privileges for role postgres in schema public
  revoke execute on functions from anon, authenticated, service_role;

alter default privileges for role postgres in schema public
  revoke usage, select on sequences from anon, authenticated, service_role;

alter default privileges for role postgres in schema public
  revoke execute on functions from public;

comment on schema app_private is
  'Raahi Learning internal helpers. Not an exposed Data API schema.';
