import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration=fs.readFileSync('supabase/migrations/20260923085000_v14k_first_use_intent_alignment.sql','utf8');
const ui=fs.readFileSync('apps/raahi-learning/live-product-fix-v13.js','utf8');

test('first-use state is minimal metadata and never a role signal',()=>{
  assert.match(migration,/add column first_use_completed_at timestamptz null/);
  assert.match(migration,/Not an authorization, role or capability signal/);
  assert.doesNotMatch(migration,/first_use_(role|capability|persona)/i);
  assert.doesNotMatch(migration,/initial_intent|first_use_intent/i);
});

test('established relationships are backfilled while empty Accounts may remain pending',()=>{
  for(const relation of [
    'account_learner_access',
    'account_capabilities',
    'organization_members',
    'location_staff_assignments',
    'assisted_teacher_onboarding_requests',
    'teacher_profiles',
    'teaching_options'
  ]) assert.match(migration,new RegExp(relation));
  assert.match(migration,/where a\.first_use_completed_at is null/);
});

test('canonical completion command is current-Account scoped and authority neutral',()=>{
  const start=migration.indexOf('create or replace function app_private.cmd_complete_first_use_onboarding');
  const end=migration.indexOf('revoke all on function app_private.cmd_complete_first_use_onboarding');
  const cmd=migration.slice(start,end);
  assert.match(cmd,/require_current_account\(true\)/);
  assert.match(cmd,/begin_human_idempotent_command/);
  assert.match(cmd,/complete_human_idempotent_command/);
  assert.match(cmd,/first_use_completed_at=coalesce\(first_use_completed_at,now\(\)\)/);
  for(const forbidden of [
    /insert into public\.account_capabilities/i,
    /insert into public\.account_learner_access/i,
    /insert into public\.learners/i,
    /insert into public\.organizations/i,
    /insert into public\.organization_members/i,
    /insert into public\.location_staff_assignments/i,
    /insert into public\.teacher_profiles/i,
    /insert into public\.teaching_options/i
  ]) assert.doesNotMatch(cmd,forbidden);
});

test('account context exposes server-owned first-use completion',()=>{
  assert.match(migration,/'first_use_completed_at',a\.first_use_completed_at/);
  assert.match(migration,/create or replace function public\.complete_first_use_onboarding/);
  assert.match(migration,/security invoker/);
  assert.match(migration,/grant execute on function public\.complete_first_use_onboarding\(text\)[\s\S]*to authenticated/);
});

test('frontend fails safe when backend field is absent and keeps pending Accounts inside intent',()=>{
  assert.match(ui,/Object\.prototype\.hasOwnProperty\.call\(account,'first_use_completed_at'\)/);
  assert.match(ui,/account\.first_use_completed_at === null/);
  assert.match(ui,/!live\.pendingInvite && firstUsePending\(\)/);
  assert.match(ui,/history\.replaceState\(null,'','#\/onboarding-intent'\)/);
  assert.match(ui,/return pageFirstUseIntent\(\)/);
});

test('first-use choice records guidance completion before existing setup route',()=>{
  assert.match(ui,/data-live-first-use-intent="learner"/);
  assert.match(ui,/data-live-first-use-intent="parent"/);
  assert.match(ui,/data-live-first-use-intent="teacher"/);
  assert.match(ui,/data-live-first-use-intent="institute"/);
  assert.match(ui,/data-live-first-use-intent="explore"/);
  assert.match(ui,/What brings you here today\?/);
  assert.match(ui,/I’m helping someone learn/);
  assert.match(ui,/I’m just exploring/);
  assert.match(ui,/complete_first_use_onboarding/);
  assert.match(ui,/live\.context = await rpc\('get_my_account_context'\)/);
  for(const [intent,route] of [
    ['learner','learner-setup'],
    ['parent','learner-add'],
    ['teacher','teacher-setup'],
    ['institute','institute-setup'],
    ['explore','home']
  ]) assert.match(ui,new RegExp(intent+":'"+route+"'"));
});

test('first-use frontend adds no direct operational table writes',()=>{
  assert.doesNotMatch(ui,/\.from\s*\(/);
  assert.doesNotMatch(ui,/\.insert\s*\(/);
  assert.doesNotMatch(ui,/\.update\s*\(/);
  assert.doesNotMatch(ui,/\.delete\s*\(/);
});
