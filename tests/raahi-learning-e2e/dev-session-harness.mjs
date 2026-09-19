import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { chromium } from 'playwright';
import { createClient } from '@supabase/supabase-js';

const DEV_ORIGIN = 'https://dev.learning.myraahi.co.in';
const EXPECTED_HOST = 'dev.learning.myraahi.co.in';
const SUPABASE_URL = 'https://iiwwmqokaeflaenhlyip.supabase.co';
const PROJECT_REF = 'iiwwmqokaeflaenhlyip';
const PUBLISHABLE_KEY = 'sb_publishable_bz0YgDXY-WkKxZnogGsfUg_Qgl7E-Wi';
const EDGE_URL = SUPABASE_URL + '/functions/v1/dev-test-identities';
const OIDC_AUDIENCE = 'raahi-learning-dev-test-harness';
const PERSONA_KEYS = ['learner', 'teacher', 'unrelated', 'admin'];
const ARTIFACT_DIR = path.resolve('artifacts');

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function guardTargets() {
  assert(new URL(DEV_ORIGIN).hostname === EXPECTED_HOST, 'DEV_ORIGIN_GUARD_FAILED');
  assert(new URL(SUPABASE_URL).hostname.split('.')[0] === PROJECT_REF, 'SUPABASE_PROJECT_GUARD_FAILED');
  assert(process.env.GITHUB_REF === 'refs/heads/raahi-learning-implementation-v1', 'GITHUB_REF_GUARD_FAILED');
}

function makePassword() {
  return crypto.randomBytes(30).toString('base64url') + 'Aa1!';
}

function runId() {
  const raw = process.env.GITHUB_RUN_ID || Date.now().toString();
  const attempt = process.env.GITHUB_RUN_ATTEMPT || '1';
  return 'gha-' + raw + '-' + attempt;
}

async function waitForDeployment(commitSha) {
  const deadline = Date.now() + 8 * 60 * 1000;
  let last = null;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(DEV_ORIGIN + '/build-meta.json?wait=' + Date.now(), { cache: 'no-store' });
      if (res.ok) {
        const meta = await res.json();
        last = meta;
        if (meta.commit_sha === commitSha) return meta;
      }
    } catch (error) {
      last = { error: String(error) };
    }
    await new Promise((resolve) => setTimeout(resolve, 10000));
  }
  throw new Error('DEV_DEPLOYMENT_NOT_CURRENT: expected ' + commitSha + ', last=' + JSON.stringify(last));
}

async function githubOidcToken() {
  const requestUrl = process.env.ACTIONS_ID_TOKEN_REQUEST_URL;
  const requestToken = process.env.ACTIONS_ID_TOKEN_REQUEST_TOKEN;
  assert(requestUrl && requestToken, 'GITHUB_OIDC_ENV_MISSING');
  const url = new URL(requestUrl);
  url.searchParams.set('audience', OIDC_AUDIENCE);
  const res = await fetch(url, { headers: { Authorization: 'Bearer ' + requestToken } });
  if (!res.ok) throw new Error('GITHUB_OIDC_REQUEST_FAILED_' + res.status);
  const body = await res.json();
  assert(body.value, 'GITHUB_OIDC_TOKEN_MISSING');
  return body.value;
}

async function edgeCall(token, payload) {
  const res = await fetch(EDGE_URL, {
    method: 'POST',
    headers: {
      authorization: 'Bearer ' + token,
      'content-type': 'application/json',
    },
    body: JSON.stringify(payload),
  });
  const body = await res.json().catch(() => ({ ok: false, error: 'INVALID_JSON_RESPONSE' }));
  if (!res.ok || !body.ok) throw new Error('DEV_IDENTITY_FACTORY_FAILED: ' + (body.error || res.status));
  return body;
}

function client() {
  return createClient(SUPABASE_URL, PUBLISHABLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
}

async function rpc(c, name, args = {}) {
  const { data, error } = await c.rpc(name, args);
  if (error) throw error;
  return data;
}

async function accountContext(c) {
  return rpc(c, 'get_my_account_context');
}

async function bootstrapIfNeeded(c, displayName) {
  try {
    return await accountContext(c);
  } catch (error) {
    if (!/ACCOUNT_NOT_FOUND/i.test(error?.message || '')) throw error;
    await rpc(c, 'bootstrap_account', { p_display_name: displayName });
    return accountContext(c);
  }
}

async function main() {
  guardTargets();
  fs.mkdirSync(ARTIFACT_DIR, { recursive: true });

  const commit = process.env.GITHUB_SHA || 'unknown';
  const rid = runId();
  const report = {
    harness: 'raahi-learning-dev-test-session-v1',
    run_id: rid,
    commit_sha: commit,
    environment: { origin: DEV_ORIGIN, project_ref: PROJECT_REF },
    deployment: null,
    personas: {},
    checks: [],
    result: 'running',
  };

  try {
    report.deployment = await waitForDeployment(commit);
    report.checks.push({ check: 'exact_dev_commit_deployed', pass: true });

    const anonymousClient = client();
    const anonymousLocations = await anonymousClient.rpc('list_public_locations');
    assert(anonymousLocations.error, 'ANON_PUBLIC_LOCATION_RPC_NOT_DENIED');
    report.checks.push({ check: 'deferred_anonymous_location_rpc_denied', pass: true });

    const unauthenticated = await fetch(EDGE_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ action: 'ensure_personas', run_id: rid, passwords: {} }),
    });
    assert(unauthenticated.status === 403, 'IDENTITY_FACTORY_UNAUTHENTICATED_GUARD_FAILED_' + unauthenticated.status);
    report.checks.push({ check: 'identity_factory_rejects_unauthenticated', pass: true });

    const oidc = await githubOidcToken();
    const passwords = Object.fromEntries(PERSONA_KEYS.map((key) => [key, makePassword()]));
    const ensured = await edgeCall(oidc, { action: 'ensure_personas', run_id: rid, passwords });
    const specs = Object.fromEntries(ensured.personas.map((x) => [x.key, x]));

    const sessions = {};
    const displayNames = {
      learner: 'E2E Learner Account',
      teacher: 'E2E Teacher Account',
      unrelated: 'E2E Unrelated Account',
      admin: 'E2E Platform Admin',
    };

    for (const key of PERSONA_KEYS) {
      const c = client();
      const spec = specs[key];
      assert(spec?.email && spec?.auth_user_id, 'PERSONA_FACTORY_RESULT_MISSING_' + key);
      const { data, error } = await c.auth.signInWithPassword({ email: spec.email, password: passwords[key] });
      if (error) throw error;
      assert(data.session && data.user, 'GENUINE_SESSION_NOT_ISSUED_' + key);
      assert(data.user.id === spec.auth_user_id, 'AUTH_USER_MISMATCH_' + key);
      const context = await bootstrapIfNeeded(c, displayNames[key]);
      sessions[key] = { client: c, auth_user_id: data.user.id, email: spec.email, context };
      report.personas[key] = {
        auth_user_id: data.user.id,
        account_id: context.account.account_id,
        display_name: context.account.display_name,
        capabilities: context.capabilities,
        browser_signed_in: false,
      };
    }
    report.checks.push({ check: 'four_genuine_supabase_sessions', pass: true });

    const stageLocations = await rpc(sessions.learner.client, 'list_public_locations');
    const dhanbadLocation = stageLocations.find((x) => x.slug === 'dhanbad');
    const gomohLocation = stageLocations.find((x) => x.slug === 'gomoh');
    assert(dhanbadLocation?.state === 'live', 'DHANBAD_NOT_LIVE_IN_STAGE');
    assert(gomohLocation?.state === 'preparing', 'GOMOH_NOT_PREPARING_IN_STAGE');

    const liveLocations = await rpc(sessions.learner.client, 'list_live_locations');
    assert(liveLocations.some((x) => x.slug === 'dhanbad' && x.state === 'live'), 'DHANBAD_MISSING_FROM_LIVE_LOCATIONS');
    assert(!liveLocations.some((x) => x.slug === 'gomoh'), 'GOMOH_PREMATURELY_EXPOSED_AS_LIVE');

    const gomohTeaching = await rpc(sessions.learner.client, 'discover_teaching_options', {
      p_location_id: gomohLocation.location_id,
      p_query: null,
    });
    const gomohRequests = await rpc(sessions.learner.client, 'discover_learning_requests', {
      p_location_id: gomohLocation.location_id,
      p_query: null,
    });
    const gomohCommunity = await rpc(sessions.learner.client, 'discover_community_posts', {
      p_location_id: gomohLocation.location_id,
      p_limit: 20,
    });
    assert(Array.isArray(gomohTeaching) && gomohTeaching.length === 0, 'GOMOH_PREPARING_TEACHING_DISCOVERY_NOT_EMPTY');
    assert(Array.isArray(gomohRequests) && gomohRequests.length === 0, 'GOMOH_PREPARING_REQUEST_DISCOVERY_NOT_EMPTY');
    assert(Array.isArray(gomohCommunity) && gomohCommunity.length === 0, 'GOMOH_PREPARING_COMMUNITY_DISCOVERY_NOT_EMPTY');
    report.stage_locations = {
      dhanbad: { location_id: dhanbadLocation.location_id, state: dhanbadLocation.state },
      gomoh: { location_id: gomohLocation.location_id, state: gomohLocation.state },
    };
    report.checks.push({ check: 'stage_location_visibility_and_preparing_isolation', pass: true });

    const teacher = sessions.teacher;
    await rpc(teacher.client, 'enable_teaching', { p_idempotency_key: rid + '-teacher-enable' });
    teacher.context = await accountContext(teacher.client);
    assert(teacher.context.capabilities.includes('teach'), 'TEACH_CAPABILITY_NOT_ACTIVE');
    report.personas.teacher.capabilities = teacher.context.capabilities;
    report.checks.push({ check: 'teacher_canonical_enable_teaching', pass: true });

    const learner = sessions.learner;
    learner.context = await accountContext(learner.client);
    let selfLearner = learner.context.learners.find((x) => x.access_type === 'self');
    if (!selfLearner) {
      await rpc(learner.client, 'create_learner', {
        p_display_name: 'E2E Learner Profile',
        p_access_type: 'self',
        p_avatar_type: 'none',
        p_avatar_ref: null,
        p_idempotency_key: rid + '-self-learner',
      });
      learner.context = await accountContext(learner.client);
      selfLearner = learner.context.learners.find((x) => x.access_type === 'self');
    }
    assert(selfLearner?.learner_id, 'SELF_LEARNER_NOT_AVAILABLE');
    report.personas.learner.learner_id = selfLearner.learner_id;
    report.checks.push({ check: 'learner_canonical_self_profile', pass: true });

    let gomohWriteDenied = false;
    try {
      await rpc(learner.client, 'post_learning_request', {
        p_learner_id: selfLearner.learner_id,
        p_location_id: report.stage_locations.gomoh.location_id,
        p_need_text: 'Stage-only Gomoh write must be rejected',
        p_category: 'stage-proof',
        p_mode_preference: 'either',
        p_details: null,
        p_timing_preference: null,
        p_idempotency_key: rid + '-gomoh-preparing-write-denial',
      });
    } catch (error) {
      gomohWriteDenied = /LOCATION_NOT_LIVE/i.test(error?.message || '');
    }
    assert(gomohWriteDenied, 'GOMOH_PREPARING_LEARNING_REQUEST_WRITE_NOT_DENIED');
    report.checks.push({ check: 'gomoh_preparing_write_rejected', pass: true });

    const adminSeed = await edgeCall(oidc, { action: 'ensure_admin_capability', run_id: rid });
    const admin = sessions.admin;
    admin.context = await accountContext(admin.client);
    assert(admin.context.capabilities.includes('platform_admin'), 'PLATFORM_ADMIN_CAPABILITY_NOT_ACTIVE');
    report.personas.admin.capabilities = admin.context.capabilities;
    report.personas.admin.seed_account_id = adminSeed.admin.account_id;
    report.checks.push({ check: 'dev_seed_admin_capability', pass: true });

    const unrelated = sessions.unrelated;
    unrelated.context = await accountContext(unrelated.client);
    assert(!unrelated.context.learners.some((x) => x.learner_id === selfLearner.learner_id), 'UNRELATED_CONTEXT_LEAKED_LEARNER');

    const { data: deniedRows, error: deniedError } = await unrelated.client
      .from('learners')
      .select('id')
      .eq('id', selfLearner.learner_id);
    if (deniedError) throw deniedError;
    assert(Array.isArray(deniedRows) && deniedRows.length === 0, 'UNRELATED_RLS_LEAKED_LEARNER');

    const { data: allowedRows, error: allowedError } = await learner.client
      .from('learners')
      .select('id')
      .eq('id', selfLearner.learner_id);
    if (allowedError) throw allowedError;
    assert(Array.isArray(allowedRows) && allowedRows.length === 1, 'AUTHORIZED_LEARNER_RLS_READ_FAILED');
    report.checks.push({ check: 'learner_rls_allow_unrelated_rls_deny', pass: true });

    const browser = await chromium.launch({ headless: true });
    try {
      for (const key of PERSONA_KEYS) {
        const context = await browser.newContext();
        const page = await context.newPage();
        await page.goto(DEV_ORIGIN + '/dev-test-login-v13.html', { waitUntil: 'domcontentloaded' });
        await page.getByText('RAAHI_DEV_TEST_LOGIN_V13').waitFor();
        await page.locator('#email').fill(sessions[key].email);
        await page.locator('#password').fill(passwords[key]);
        await page.locator('#signin').click();
        await page.waitForURL((url) => url.origin === DEV_ORIGIN && url.hash === '#/home', { timeout: 30000 });
        await page.waitForLoadState('domcontentloaded');
        await page.waitForTimeout(1200);
        const body = await page.locator('body').innerText();
        assert(!/Continue with Google/i.test(body), 'BROWSER_RETURNED_TO_GOOGLE_SIGNIN_' + key);
        await page.screenshot({ path: path.join(ARTIFACT_DIR, 'browser-' + key + '.png'), fullPage: true });
        report.personas[key].browser_signed_in = true;
        await context.close();
      }
    } finally {
      await browser.close();
    }
    report.checks.push({ check: 'four_isolated_browser_contexts_signed_in', pass: true });

    for (const key of PERSONA_KEYS) {
      await sessions[key].client.auth.signOut();
    }

    report.result = 'pass';
    fs.writeFileSync(path.join(ARTIFACT_DIR, 'dev-harness-proof.json'), JSON.stringify(report, null, 2));
    console.log('RAAHI_DEV_TEST_HARNESS_PASS run_id=' + rid + ' commit=' + commit);
  } catch (error) {
    report.result = 'fail';
    report.failure = {
      message: error instanceof Error ? error.message : String(error),
      class: 'test-harness-or-environment',
    };
    fs.writeFileSync(path.join(ARTIFACT_DIR, 'dev-harness-proof.json'), JSON.stringify(report, null, 2));
    throw error;
  }
}

await main();
