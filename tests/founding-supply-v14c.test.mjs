import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const ui=fs.readFileSync('apps/raahi-learning/founding-supply-v14c.js','utf8');
const migration=fs.readFileSync('supabase/migrations/20260921093000_v14c_founding_supply_assisted_teacher_onboarding.sql','utf8');
const fkIndexes=fs.readFileSync('supabase/migrations/20260921094500_v14c_founding_supply_fk_indexes.sql','utf8');
const explicitDeny=fs.readFileSync('supabase/migrations/20260921095000_v14c_founding_supply_explicit_browser_deny.sql','utf8');
const builder=fs.readFileSync('apps/raahi-learning/build-source-v13.mjs','utf8');
const packager=fs.readFileSync('scripts/prepare-learning-release.mjs','utf8');

test('Founding Supply is Teacher-requested assistance, not silent platform onboarding',()=>{
  assert.match(migration,/cmd_request_assisted_teacher_onboarding/);
  assert.match(migration,/teacher_account_id,requested_by_account_id,founding_location_id/);
  assert.match(migration,/values\(v_actor,v_actor,p_location_id\)/);
  assert.match(migration,/assisted_teacher_request_self_check/);
  assert.match(migration,/cmd_prepare_assisted_teacher_onboarding/);
  assert.match(migration,/has_account_capability\('platform_admin'\)/);
  assert.match(migration,/if v_state<>'requested' then raise exception 'ASSISTED_ONBOARDING_NOT_PREPARABLE'/);
  assert.doesNotMatch(migration,/cmd_prepare_assisted_teacher_onboarding\([\s\S]{0,500}p_teacher_account_id/i);
});

test('private draft has no public-supply side effect before Teacher acceptance',()=>{
  const prepare=migration.slice(
    migration.indexOf('create or replace function app_private.cmd_prepare_assisted_teacher_onboarding'),
    migration.indexOf('create or replace function app_private.cmd_accept_assisted_teacher_onboarding')
  );
  assert.match(prepare,/update public\.assisted_teacher_onboarding_requests/);
  assert.doesNotMatch(prepare,/insert into public\.teacher_profiles/);
  assert.doesNotMatch(prepare,/insert into public\.teaching_options/);
  assert.doesNotMatch(prepare,/insert into public\.teaching_option_locations/);
});

test('Teacher acceptance is self-authorized, atomic and creates canonical assisted supply',()=>{
  const accept=migration.slice(
    migration.indexOf('create or replace function app_private.cmd_accept_assisted_teacher_onboarding'),
    migration.indexOf('create or replace function app_private.cmd_decline_assisted_teacher_onboarding')
  );
  assert.match(accept,/if v_request\.teacher_account_id<>v_actor then raise exception 'NOT_AUTHORIZED'/);
  assert.match(accept,/if v_request\.state<>'draft_ready' then raise exception 'ASSISTED_ONBOARDING_NOT_ACCEPTABLE'/);
  assert.match(accept,/insert into public\.teacher_profiles/);
  assert.match(accept,/'visible'/);
  assert.match(accept,/'assisted'/);
  assert.match(accept,/insert into public\.teaching_options/);
  assert.match(accept,/'taking_new_learners'/);
  assert.match(accept,/insert into public\.teaching_option_locations/);
  assert.match(accept,/state='accepted'/);
  assert.match(accept,/founding_supply\.teacher_accepted/);
  assert.match(accept,/consent_text_version/);
});

test('organic and assisted creation provenance cannot be forged inconsistently',()=>{
  assert.match(migration,/teacher_profiles[\s\S]*add column creation_provenance text not null default 'organic'/);
  assert.match(migration,/teaching_options[\s\S]*add column creation_provenance text not null default 'organic'/);
  assert.match(migration,/creation_provenance in \('organic','assisted'\)/);
  assert.match(migration,/creation_provenance='organic' and assisted_onboarding_request_id is null/);
  assert.match(migration,/creation_provenance='assisted' and assisted_onboarding_request_id is not null/);
  assert.match(migration,/teaching_options_one_assisted_option_per_request_idx/);
});

test('assisted acceptance remains future phone-trust compatible',()=>{
  assert.match(migration,/'accept_assisted_teacher_onboarding'/);
  assert.match(migration,/command_requires_fresh_phone_trust/);
});

test('browser roles get RPCs, not direct assisted-onboarding table writes',()=>{
  assert.match(migration,/alter table public\.assisted_teacher_onboarding_requests enable row level security/);
  assert.match(migration,/force row level security/);
  const tableAcl=migration.slice(
    migration.indexOf('revoke all on table public.assisted_teacher_onboarding_requests'),
    migration.indexOf('alter table public.teacher_profiles')
  );
  assert.match(tableAcl,/revoke all on table public\.assisted_teacher_onboarding_requests[\s\S]*from public,anon,authenticated,service_role/);
  assert.match(tableAcl,/grant select,insert,update,delete on table public\.assisted_teacher_onboarding_requests[\s\S]*to service_role/);
  assert.doesNotMatch(tableAcl,/to authenticated/i);
  assert.match(migration,/create or replace function public\.request_assisted_teacher_onboarding/);
  assert.match(migration,/create or replace function public\.prepare_assisted_teacher_onboarding/);
  assert.match(migration,/create or replace function public\.accept_assisted_teacher_onboarding/);
  assert.match(migration,/security invoker/);
});

test('UI keeps self-service and adds explicit consented help without direct table mutation',()=>{
  assert.match(ui,/Set it up myself/);
  assert.match(ui,/Ask Raahi to help/);
  assert.match(ui,/Nothing is published through assisted setup until you review and accept the exact draft/);
  assert.match(ui,/request_assisted_teacher_onboarding/);
  assert.match(ui,/prepare_assisted_teacher_onboarding/);
  assert.match(ui,/accept_assisted_teacher_onboarding/);
  assert.match(ui,/Publish these details/);
  assert.match(ui,/No silent onboarding/);
  assert.match(ui,/private draft only/);
  assert.doesNotMatch(ui,/\.from\s*\(/);
  assert.doesNotMatch(ui,/\.insert\s*\(/);
  assert.doesNotMatch(ui,/\.update\s*\(/);
  assert.doesNotMatch(ui,/\.delete\s*\(/);
  assert.doesNotMatch(ui,/service_role|sb_secret_/i);
});

test('post-migration hardening closes browser reads and covers new foreign keys',()=>{
  assert.match(explicitDeny,/create policy assisted_teacher_onboarding_deny_authenticated/);
  assert.match(explicitDeny,/for all[\s\S]*to authenticated[\s\S]*using \(false\)[\s\S]*with check \(false\)/);
  for(const name of [
    'assisted_teacher_requested_by_idx',
    'assisted_teacher_founding_location_idx',
    'assisted_teacher_prepared_by_idx',
    'assisted_teacher_resolved_by_idx',
    'teacher_profiles_assisted_request_idx'
  ]) assert.match(fkIndexes,new RegExp(name));
});

test('Founding Supply is shipped by reconstruction and release packaging',()=>{
  assert.match(builder,/founding-supply-v14c\.js/);
  assert.match(packager,/founding-supply-v14c\.js/);
});
