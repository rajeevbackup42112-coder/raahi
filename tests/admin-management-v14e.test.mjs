import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration=fs.readFileSync('supabase/migrations/20260922113814_v14e_global_admin_location_admin_reads.sql','utf8');
const ui=fs.readFileSync('apps/raahi-learning/admin-management-v14e.js','utf8');
const builder=fs.readFileSync('apps/raahi-learning/build-source-v13.mjs','utf8');
const packager=fs.readFileSync('scripts/prepare-learning-release.mjs','utf8');

test('Location-admin read projections require Platform Admin server-side',()=>{
  assert.match(migration,/read_platform_location_admins/);
  assert.match(migration,/resolve_platform_account_email/);
  assert.match(migration,/has_account_capability\('platform_admin'\)/);
  assert.match(migration,/PLATFORM_ADMIN_REQUIRED/);
  assert.match(migration,/lower\(u\.email\) = v_email/);
  assert.doesNotMatch(migration,/ilike|similar to/i);
});

test('public admin read wrappers are invoker functions and browser receives execute only',()=>{
  assert.match(migration,/create or replace function public\.get_platform_location_admins\(\)[\s\S]*security invoker/);
  assert.match(migration,/create or replace function public\.resolve_platform_account_email\(p_email text\)[\s\S]*security invoker/);
  assert.match(migration,/revoke all on function public\.get_platform_location_admins\(\) from public, anon, authenticated, service_role/);
  assert.match(migration,/grant execute on function public\.get_platform_location_admins\(\) to authenticated/);
});

test('Global Admin UI uses exact lookup and existing canonical audited assignment commands',()=>{
  assert.match(ui,/get_platform_location_admins/);
  assert.match(ui,/resolve_platform_account_email/);
  assert.match(ui,/assign_local_manager/);
  assert.match(ui,/end_location_staff_assignment/);
  assert.match(ui,/Enter the exact Google email/);
  assert.match(ui,/This page cannot make someone a Global Platform Admin/);
  assert.doesNotMatch(ui,/grant_account_capability/);
  assert.doesNotMatch(ui,/revoke_account_capability/);
});

test('Admin UI never performs direct table DML or carries privileged secrets',()=>{
  assert.doesNotMatch(ui,/\.from\s*\(/);
  assert.doesNotMatch(ui,/\.insert\s*\(/);
  assert.doesNotMatch(ui,/\.update\s*\(/);
  assert.doesNotMatch(ui,/\.delete\s*\(/);
  assert.doesNotMatch(ui,/service_role|sb_secret_/i);
});

test('Location Admins route is visible only in Platform navigation and denies unauthorized workspace',()=>{
  assert.match(ui,/api\.roleNav\?\.platform/);
  assert.match(ui,/Platform Admin required/);
  assert.match(ui,/capabilities\)\.includes\('platform_admin'\)/);
  assert.doesNotMatch(ui,/roleNav\?\.manager/);
});

test('V1.4E admin layer is reconstructed and release-packaged',()=>{
  assert.match(builder,/admin-management-v14e\.js/);
  assert.match(packager,/admin-management-v14e\.js/);
});
