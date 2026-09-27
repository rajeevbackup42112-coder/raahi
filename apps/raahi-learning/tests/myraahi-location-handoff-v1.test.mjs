import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('../myraahi-location-handoff-v1.js', import.meta.url), 'utf8');

function storage(seed = {}) {
  const map = new Map(Object.entries(seed));
  return {
    getItem: key => map.has(key) ? map.get(key) : null,
    setItem: (key, value) => map.set(key, String(value)),
    removeItem: key => map.delete(key),
    keys: () => [...map.keys()]
  };
}

function makeHarness({ href, live, seed = {} }) {
  const store = storage(seed);
  let current = new URL(href);
  let intervalFn = null;
  let reloads = 0;

  const location = {
    get href() { return current.href; },
    get search() { return current.search; },
    get pathname() { return current.pathname; },
    get hash() { return current.hash; },
    reload() { reloads++; }
  };

  const history = {
    replaceState(_a, _b, next) {
      current = new URL(next, current.origin);
    }
  };

  const context = {
    window: { RaahiLearningLive: live },
    location,
    history,
    sessionStorage: store,
    URL,
    URLSearchParams,
    crypto: { randomUUID: () => 'fixed-idempotency-key' },
    setInterval(fn) { intervalFn = fn; return 1; },
    clearInterval() {},
    setTimeout() {},
    console
  };
  context.window.window = context.window;

  vm.runInNewContext(source, context);

  return {
    store,
    live,
    url: () => current.href,
    reloads: () => reloads,
    tick: async () => { if (intervalFn) await intervalFn(); await new Promise(resolve => setImmediate(resolve)); }
  };
}

const dhanbad = { location_id: 'loc-dhanbad', slug: 'dhanbad', state: 'live' };
const gomoh = { location_id: 'loc-gomoh', slug: 'gomoh', state: 'live' };

test('signed-out handoff is captured, stripped from URL and preserved for auth', async () => {
  const calls = [];
  const live = {
    client: { rpc: async (...args) => { calls.push(args); return { data: null, error: null }; } },
    data: { locations: [dhanbad, gomoh] },
    session: null,
    context: null
  };
  const h = makeHarness({
    href: 'https://learning.example/?raahi_location=dhanbad#/welcome',
    live
  });
  assert.equal(new URL(h.url()).searchParams.has('raahi_location'), false);
  const pending = JSON.parse(h.store.getItem('raahi.learning.pending-myraahi-location.v1'));
  assert.equal(pending.slug, 'dhanbad');
  assert.equal(pending.idempotencyKey, 'myraahi-location-fixed-idempotency-key');
  await h.tick();
  assert.equal(calls.length, 0);
  assert.ok(h.store.getItem('raahi.learning.pending-myraahi-location.v1'));
});

test('authenticated handoff applies canonical selected Location then reloads', async () => {
  const calls = [];
  const live = {
    client: { rpc: async (name, params) => { calls.push({ name, params }); return { data: true, error: null }; } },
    data: { locations: [dhanbad, gomoh] },
    session: { user: { id: 'user-1' } },
    context: { selected_location: { location_id: 'loc-gomoh', slug: 'gomoh' } }
  };
  const h = makeHarness({
    href: 'https://learning.example/?raahi_location=dhanbad#/home',
    live
  });
  await h.tick();
  assert.equal(calls.length, 1);
  assert.equal(calls[0].name, 'set_selected_location');
  assert.equal(calls[0].params.p_location_id, 'loc-dhanbad');
  assert.equal(calls[0].params.p_idempotency_key, 'myraahi-location-fixed-idempotency-key');
  assert.equal(h.store.getItem('raahi.learning.pending-myraahi-location.v1'), null);
  assert.equal(h.reloads(), 1);
});

test('already-selected Location clears pending state without a write', async () => {
  const calls = [];
  const live = {
    client: { rpc: async (...args) => { calls.push(args); return { data: true, error: null }; } },
    data: { locations: [dhanbad] },
    session: { user: { id: 'user-1' } },
    context: { selected_location: { location_id: 'loc-dhanbad', slug: 'dhanbad' } }
  };
  const h = makeHarness({
    href: 'https://learning.example/?raahi_location=dhanbad#/home',
    live
  });
  await h.tick();
  assert.equal(calls.length, 0);
  assert.equal(h.store.getItem('raahi.learning.pending-myraahi-location.v1'), null);
  assert.equal(h.reloads(), 0);
});

test('invalid or non-live hints never become a Location write', async () => {
  const calls = [];
  const live = {
    client: { rpc: async (...args) => { calls.push(args); return { data: true, error: null }; } },
    data: { locations: [{ location_id: 'loc-dhanbad', slug: 'dhanbad', state: 'paused' }] },
    session: { user: { id: 'user-1' } },
    context: { selected_location: { location_id: 'loc-gomoh', slug: 'gomoh' } }
  };
  const invalid = makeHarness({
    href: 'https://learning.example/?raahi_location=..%2Fadmin#/home',
    live
  });
  await invalid.tick();
  assert.equal(calls.length, 0);
  assert.equal(invalid.store.getItem('raahi.learning.pending-myraahi-location.v1'), null);

  const paused = makeHarness({
    href: 'https://learning.example/?raahi_location=dhanbad#/home',
    live
  });
  await paused.tick();
  assert.equal(calls.length, 0);
  assert.equal(paused.store.getItem('raahi.learning.pending-myraahi-location.v1'), null);
});

test('retry reuses the same idempotency key after an uncertain failure', async () => {
  const calls = [];
  let attempt = 0;
  const live = {
    client: {
      rpc: async (name, params) => {
        calls.push({ name, params });
        attempt++;
        return attempt === 1
          ? { data: null, error: new Error('temporary network failure') }
          : { data: true, error: null };
      }
    },
    data: { locations: [dhanbad, gomoh] },
    session: { user: { id: 'user-1' } },
    context: { selected_location: { location_id: 'loc-gomoh', slug: 'gomoh' } }
  };
  const h = makeHarness({
    href: 'https://learning.example/?raahi_location=dhanbad#/home',
    live
  });
  await h.tick();
  assert.equal(calls.length >= 1, true);
  assert.ok(h.store.getItem('raahi.learning.pending-myraahi-location.v1'));
  await h.tick();
  assert.equal(calls.length >= 2, true);
  assert.equal(calls[0].params.p_idempotency_key, calls[1].params.p_idempotency_key);
  assert.equal(h.store.getItem('raahi.learning.pending-myraahi-location.v1'), null);
  assert.equal(h.reloads(), 1);
});
