import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration=fs.readFileSync('supabase/migrations/20260923103500_v14k_google_profile_confirmation_alignment.sql','utf8');
const ui=fs.readFileSync('apps/raahi-learning/live-product-fix-v13.js','utf8');

test('profile onboarding state is minimal metadata and all existing Accounts are grandfathered',()=>{
  assert.match(migration,/add column profile_onboarding_completed_at timestamptz null/);
  assert.match(migration,/update public\.accounts[\s\S]*profile_onboarding_completed_at=coalesce\(updated_at,created_at,now\(\)\)/);
  assert.match(migration,/Not a verification, role, capability or authorization signal/);
  assert.doesNotMatch(migration,/profile_onboarding_(role|capability|verified)/i);
});

test('profile completion command is current-Account scoped, idempotent and authority neutral',()=>{
  const start=migration.indexOf('create or replace function app_private.cmd_complete_profile_onboarding');
  const end=migration.indexOf('revoke all on function app_private.cmd_complete_profile_onboarding');
  const cmd=migration.slice(start,end);
  assert.match(cmd,/require_current_account\(true\)/);
  assert.match(cmd,/begin_human_idempotent_command/);
  assert.match(cmd,/complete_human_idempotent_command/);
  assert.match(cmd,/profile_onboarding_completed_at=coalesce\(profile_onboarding_completed_at,now\(\)\)/);
  for(const forbidden of [
    /account_capabilities/i,/account_learner_access/i,/learners/i,/organizations/i,
    /organization_members/i,/location_staff_assignments/i,/teacher_profiles/i,/teaching_options/i
  ]) assert.doesNotMatch(cmd,forbidden);
});

test('account context exposes profile and first-use completion independently',()=>{
  assert.match(migration,/'profile_onboarding_completed_at',a\.profile_onboarding_completed_at/);
  assert.match(migration,/'first_use_completed_at',a\.first_use_completed_at/);
  assert.match(migration,/create or replace function public\.complete_profile_onboarding/);
  assert.match(migration,/security invoker/);
});

test('frontend fails safe and forces profile confirmation before first-use intent',()=>{
  assert.match(ui,/Object\.prototype\.hasOwnProperty\.call\(account,'profile_onboarding_completed_at'\)/);
  assert.match(ui,/account\.profile_onboarding_completed_at === null/);
  const profilePos=ui.indexOf("!live.pendingInvite && profileOnboardingPending()");
  const intentPos=ui.indexOf("!live.pendingInvite && firstUsePending()");
  assert(profilePos>=0 && intentPos>profilePos,'profile gate must precede intent gate');
  assert.match(ui,/history\.replaceState\(null,'','#\/google-profile'\)/);
  assert.match(ui,/return originalRender\('google-profile', coreApi\)/);
});

test('Google profile form saves Raahi profile then completes profile onboarding',()=>{
  const start=ui.indexOf("form.id !== 'live-google-profile-form'");
  const end=ui.indexOf("document.addEventListener('click'",start);
  const flow=ui.slice(start,end);
  assert.match(flow,/update_account_profile/);
  assert.match(flow,/complete_profile_onboarding/);
  assert.match(flow,/get_my_account_context/);
  assert.match(flow,/api\.go\('onboarding-intent'\)/);
  assert(flow.indexOf('update_account_profile') < flow.indexOf('complete_profile_onboarding'));
});

test('profile onboarding does not alter Google photo opt-in semantics or add direct table writes',()=>{
  assert.doesNotMatch(ui,/\.from\s*\(/);
  assert.doesNotMatch(ui,/\.insert\s*\(/);
  assert.doesNotMatch(ui,/\.update\s*\(/);
  assert.doesNotMatch(ui,/\.delete\s*\(/);
});
