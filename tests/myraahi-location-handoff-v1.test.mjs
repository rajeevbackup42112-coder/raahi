import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const adapterPath = new URL('../apps/raahi-learning/myraahi-location-handoff-v1.js', import.meta.url);
const buildPath = new URL('../apps/raahi-learning/build-source-v13.mjs', import.meta.url);
const source = fs.readFileSync(adapterPath, 'utf8');
const build = fs.readFileSync(buildPath, 'utf8');

test('MyRaahi handoff consumes only the safe location hint', () => {
  assert.match(source, /const PARAM = 'raahi_location'/);
  assert.match(source, /sessionStorage/);
  assert.match(source, /normalizeSlug/);
  assert.doesNotMatch(source, /access_token|refresh_token|email|phone/i);
});

test('MyRaahi handoff uses Learning canonical Location state and RPC', () => {
  assert.match(source, /target\.state !== 'live'/);
  assert.match(source, /live\.client\.rpc\('set_selected_location'/);
  assert.match(source, /live\.client\.rpc\('get_my_account_context'/);
  assert.doesNotMatch(source, /account_location_preferences/);
  assert.doesNotMatch(source, /\.from\(['"]account_location_preferences['"]\)/);
});

test('MyRaahi handoff does not reinterpret Location as authority', () => {
  assert.doesNotMatch(source, /platform_admin|local_manager|account_capabilities|location_staff_assignments/);
});

test('Learning build packages and injects the handoff overlay', () => {
  assert.match(build, /myraahi-location-handoff-v1\.js/);
  assert.match(build, /<script src="\.\/myraahi-location-handoff-v1\.js"><\/script>/);
});
