import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

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


test('adapter executes canonical location preference transition after auth context is ready', async () => {
  const store = new Map();
  let intervalCallback = null;
  let replacedUrl = null;
  const calls = [];
  let rendered = false;

  const sessionStorage = {
    getItem: key => store.has(key) ? store.get(key) : null,
    setItem: (key, value) => store.set(key, String(value)),
    removeItem: key => store.delete(key),
  };

  const window = {
    location: { href: 'https://dev.learning.myraahi.co.in/?raahi_location=dhanbad#/home' },
    addEventListener: () => {},
    RaahiLearningLive: null,
    RaahiLearningCore: null,
  };

  const context = vm.createContext({
    window,
    sessionStorage,
    history: {
      state: null,
      replaceState: (_state, _title, url) => { replacedUrl = String(url); },
    },
    URL,
    crypto: { randomUUID: () => 'test-uuid' },
    console,
    setInterval: fn => { intervalCallback = fn; return 1; },
    clearInterval: () => {},
  });

  vm.runInContext(source, context);

  assert.equal(typeof intervalCallback, 'function');
  const pendingBeforeAuth = JSON.parse(store.get('raahi.learning.myraahi-location-handoff.v1'));
  assert.equal(pendingBeforeAuth.slug, 'dhanbad');
  assert.match(pendingBeforeAuth.idempotencyKey, /^myraahi-location-dhanbad-/);
  assert.equal(replacedUrl.includes('raahi_location'), false);

  // Before a real Learn Account context exists, the adapter must not write.
  await intervalCallback();
  assert.equal(calls.length, 0);
  assert.ok(store.has('raahi.learning.myraahi-location-handoff.v1'));

  const live = {
    session: { access_token: 'not-read-by-adapter' },
    context: {
      account: { account_id: 'acct-test' },
      selected_location: { location_id: 'loc-gomoh', slug: 'gomoh', name: 'Gomoh', state: 'live' },
    },
    data: {
      locations: [
        { location_id: 'loc-gomoh', slug: 'gomoh', name: 'Gomoh', state: 'live' },
        { location_id: 'loc-dhanbad', slug: 'dhanbad', name: 'Dhanbad', state: 'live' },
      ],
    },
    routeLoads: { clear: () => {} },
    client: {
      rpc: async (name, params) => {
        calls.push({ name, params });
        if (name === 'set_selected_location') return { data: { changed: true }, error: null };
        if (name === 'get_my_account_context') {
          return {
            data: {
              account: { account_id: 'acct-test' },
              selected_location: { location_id: 'loc-dhanbad', slug: 'dhanbad', name: 'Dhanbad', state: 'live' },
            },
            error: null,
          };
        }
        throw new Error('Unexpected RPC ' + name);
      },
    },
  };

  window.RaahiLearningLive = live;
  window.RaahiLearningCore = {
    render: () => { rendered = true; },
    toast: () => {},
  };

  await intervalCallback();

  assert.deepEqual(calls.map(x => x.name), ['set_selected_location', 'get_my_account_context']);
  assert.equal(calls[0].params.p_location_id, 'loc-dhanbad');
  assert.match(calls[0].params.p_idempotency_key, /^myraahi-location-dhanbad-/);
  assert.equal(live.context.selected_location.slug, 'dhanbad');
  assert.equal(live.__myraahiLocationHandoffV1.status, 'applied');
  assert.equal(live.__myraahiLocationHandoffV1.slug, 'dhanbad');
  assert.equal(store.has('raahi.learning.myraahi-location-handoff.v1'), false);
  assert.equal(rendered, true);
});
