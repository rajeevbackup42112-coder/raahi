import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration=fs.readFileSync('supabase/migrations/20260921105250_v14d_scoped_market_activation_authority.sql','utf8');
const deskUi=fs.readFileSync('apps/raahi-learning/market-activation-v14b.js','utf8');
const foundingUi=fs.readFileSync('apps/raahi-learning/founding-supply-v14c.js','utf8');

test('Raahi Desk accepts global Platform Admin or Local Manager only for the target Location',()=>{
  const fn=migration.slice(
    migration.indexOf('create or replace function app_private.cmd_publish_raahi_desk_post'),
    migration.indexOf('create or replace function app_private.cmd_prepare_assisted_teacher_onboarding')
  );
  assert.match(fn,/has_account_capability\('platform_admin'\)/);
  assert.match(fn,/has_location_staff_scope\(p_location_id,'local_manager'\)/);
  assert.match(fn,/MARKET_ACTIVATION_SCOPE_REQUIRED/);
  assert.match(fn,/community\.raahi_desk_publish/);
  assert.match(fn,/location_local_manager/);
  assert.match(fn,/global_platform/);
});

test('Founding Supply prepare and withdraw re-check the request Location server-side',()=>{
  const prepare=migration.slice(
    migration.indexOf('create or replace function app_private.cmd_prepare_assisted_teacher_onboarding'),
    migration.indexOf('create or replace function app_private.cmd_withdraw_assisted_teacher_onboarding')
  );
  const withdraw=migration.slice(
    migration.indexOf('create or replace function app_private.cmd_withdraw_assisted_teacher_onboarding'),
    migration.indexOf('create or replace function app_private.read_platform_assisted_teacher_onboarding')
  );
  for(const fn of [prepare,withdraw]){
    assert.match(fn,/has_account_capability\('platform_admin'\)/);
    assert.match(fn,/has_location_staff_scope\(v_location,'local_manager'\)/);
    assert.match(fn,/MARKET_ACTIVATION_SCOPE_REQUIRED/);
  }
});

test('Founding Supply queue is global for Platform Admin and Location-filtered for Local Manager',()=>{
  const read=migration.slice(migration.indexOf('create or replace function app_private.read_platform_assisted_teacher_onboarding'));
  assert.match(read,/v_global:=app_private\.has_account_capability\('platform_admin'\)/);
  assert.match(read,/lsa\.staff_type='local_manager'/);
  assert.match(read,/v_global\s+or app_private\.has_location_staff_scope\(r\.founding_location_id,'local_manager'\)/);
  assert.match(read,/MARKET_ACTIVATION_SCOPE_REQUIRED/);
});

test('Raahi Desk UI exposes both manager and platform roles but client-side scope never replaces server checks',()=>{
  assert.match(deskUi,/\['platform','manager'\]\.includes\(api\.state\.role\)/);
  assert.match(deskUi,/manager_scopes/);
  assert.match(deskUi,/canOperateLocation/);
  assert.match(deskUi,/This Location is outside your market-activation scope/);
  assert.match(deskUi,/for \(const role of \['platform','manager'\]\)/);
  assert.match(deskUi,/publish_raahi_desk_post/);
  assert.doesNotMatch(deskUi,/\.from\s*\(/);
  assert.doesNotMatch(deskUi,/\.insert\s*\(/);
  assert.doesNotMatch(deskUi,/\.update\s*\(/);
  assert.doesNotMatch(deskUi,/\.delete\s*\(/);
});

test('Founding Supply UI exposes the same scoped manager/platform operator model',()=>{
  assert.match(foundingUi,/\['platform','manager'\]\.includes\(api\.state\.role\)/);
  assert.match(foundingUi,/manager_scopes/);
  assert.match(foundingUi,/get_platform_assisted_teacher_onboarding/);
  assert.match(foundingUi,/You can operate only your assigned Location/);
  assert.match(foundingUi,/for \(const role of \['platform','manager'\]\)/);
  assert.match(foundingUi,/prepare_assisted_teacher_onboarding/);
  assert.match(foundingUi,/withdraw_assisted_teacher_onboarding/);
  assert.doesNotMatch(foundingUi,/\.from\s*\(/);
  assert.doesNotMatch(foundingUi,/\.insert\s*\(/);
  assert.doesNotMatch(foundingUi,/\.update\s*\(/);
  assert.doesNotMatch(foundingUi,/\.delete\s*\(/);
});
