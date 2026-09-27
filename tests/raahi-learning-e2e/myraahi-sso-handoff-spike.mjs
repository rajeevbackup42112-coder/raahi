import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://iiwwmqokaeflaenhlyip.supabase.co';
const PUBLISHABLE_KEY = 'sb_publishable_bz0YgDXY-WkKxZnogGsfUg_Qgl7E-Wi';
const EDGE_URL = SUPABASE_URL + '/functions/v1/dev-test-identities';
const OIDC_AUDIENCE = 'raahi-learning-dev-test-harness';
const MYRAAHI_STAGING = 'https://myraahi-shell-gate13-staging.rajeev-backup4-2112.workers.dev';
const PERSONA_KEYS = ['learner', 'teacher', 'unrelated', 'admin'];
const ARTIFACT_DIR = path.resolve('artifacts-myraahi-sso-handoff');

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function makePassword() {
  return crypto.randomBytes(30).toString('base64url') + 'Aa1!';
}

function runId() {
  return 'gha-' + (process.env.GITHUB_RUN_ID || Date.now().toString()) + '-' + (process.env.GITHUB_RUN_ATTEMPT || '1');
}

function guardTargets() {
  assert(process.env.GITHUB_REF === 'refs/heads/raahi-learning-implementation-v1', 'GITHUB_REF_GUARD_FAILED');
  assert(new URL(SUPABASE_URL).hostname.split('.')[0] === 'iiwwmqokaeflaenhlyip', 'SUPABASE_PROJECT_GUARD_FAILED');
  assert(new URL(MYRAAHI_STAGING).hostname.endsWith('.workers.dev'), 'MYRAAHI_STAGING_GUARD_FAILED');
  assert(new URL(MYRAAHI_STAGING).hostname.startsWith('myraahi-shell-gate13-staging.'), 'MYRAAHI_STAGING_NAME_GUARD_FAILED');
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
  if (!res.ok || !body.ok) throw new Error('DEV_IDENTITY_FACTORY_FAILED_' + (body.error || res.status));
  return body;
}

function supabaseClient() {
  return createClient(SUPABASE_URL, PUBLISHABLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
}

function cookiePair(setCookie) {
  assert(setCookie, 'HANDOFF_COOKIE_MISSING');
  const lower = setCookie.toLowerCase();
  assert(lower.includes('httponly'), 'HANDOFF_COOKIE_NOT_HTTPONLY');
  assert(lower.includes('secure'), 'HANDOFF_COOKIE_NOT_SECURE');
  assert(lower.includes('samesite=lax'), 'HANDOFF_COOKIE_NOT_SAMESITE_LAX');
  const pair = setCookie.split(';', 1)[0];
  assert(/^raahi_gate13_sso=/.test(pair), 'HANDOFF_COOKIE_NAME_INVALID');
  return pair;
}

async function handoff(accessToken) {
  const res = await fetch(MYRAAHI_STAGING + '/api/v1/_spike/auth/learning-handoff', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ access_token: accessToken }),
    redirect: 'manual',
  });
  assert(res.status === 303, 'HANDOFF_STATUS_' + res.status);
  assert(res.headers.get('location') === '/?sso_spike=ok', 'HANDOFF_LOCATION_INVALID');
  return cookiePair(res.headers.get('set-cookie'));
}

async function me(cookie) {
  const res = await fetch(MYRAAHI_STAGING + '/api/v1/_spike/auth/me', {
    headers: { cookie },
    redirect: 'manual',
  });
  const body = await res.json().catch(() => ({}));
  return { status: res.status, body };
}

async function logout(cookie) {
  return fetch(MYRAAHI_STAGING + '/api/v1/_spike/auth/logout', {
    method: 'POST',
    headers: { cookie },
    redirect: 'manual',
  });
}

async function expectRejectedToken(accessToken) {
  const res = await fetch(MYRAAHI_STAGING + '/api/v1/_spike/auth/learning-handoff', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ access_token: accessToken }),
    redirect: 'manual',
  });
  assert(res.status === 401, 'INVALID_TOKEN_NOT_REJECTED_' + res.status);
}

async function main() {
  guardTargets();
  fs.mkdirSync(ARTIFACT_DIR, { recursive: true });

  const rid = runId();
  const report = {
    proof: 'myraahi-gate13d-sso-handoff',
    run_id: rid,
    result: 'running',
    persona: 'synthetic_unrelated',
    checks: [],
  };

  let c = null;
  try {
    const anonymousFactory = await fetch(EDGE_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ action: 'ensure_personas', suite: 'core', run_id: rid, passwords: {} }),
    });
    assert(anonymousFactory.status === 403, 'IDENTITY_FACTORY_ANON_GUARD_' + anonymousFactory.status);
    report.checks.push('identity_factory_rejects_unauthenticated');

    const initialMe = await fetch(MYRAAHI_STAGING + '/api/v1/_spike/auth/me', { redirect: 'manual' });
    assert(initialMe.status === 401, 'STAGING_ME_WITHOUT_COOKIE_' + initialMe.status);
    report.checks.push('shared_session_requires_cookie');

    await expectRejectedToken('not-a-jwt');
    report.checks.push('invalid_token_rejected');

    const oidc = await githubOidcToken();
    const passwords = Object.fromEntries(PERSONA_KEYS.map((key) => [key, makePassword()]));
    const ensured = await edgeCall(oidc, {
      action: 'ensure_personas',
      suite: 'core',
      run_id: rid,
      passwords,
    });
    const unrelated = ensured.personas.find((x) => x.key === 'unrelated');
    assert(unrelated?.email && unrelated?.auth_user_id, 'UNRELATED_PERSONA_NOT_ENSURED');
    report.checks.push('oidc_guarded_synthetic_persona_ready');

    c = supabaseClient();
    const { data, error } = await c.auth.signInWithPassword({
      email: unrelated.email,
      password: passwords.unrelated,
    });
    if (error) throw error;
    assert(data.session?.access_token && data.user?.id, 'GENUINE_SUPABASE_SESSION_NOT_ISSUED');
    assert(data.user.id === unrelated.auth_user_id, 'SYNTHETIC_AUTH_SUBJECT_MISMATCH');
    report.checks.push('genuine_supabase_session_issued');

    const accessToken = data.session.access_token;

    const cookie1 = await handoff(accessToken);
    const first = await me(cookie1);
    assert(first.status === 200 && first.body?.authenticated === true, 'FIRST_SHARED_ME_FAILED');
    assert(first.body.identity_source === 'raahi_learn', 'IDENTITY_SOURCE_MISMATCH');
    assert(first.body.issuer === SUPABASE_URL + '/auth/v1', 'IDENTITY_ISSUER_MISMATCH');
    assert(Array.isArray(first.body.capabilities) && first.body.capabilities.length === 0, 'CAPABILITY_LEAK');
    assert(Array.isArray(first.body.product_roles) && first.body.product_roles.length === 0, 'PRODUCT_ROLE_LEAK');
    assert(typeof first.body.account_id === 'string' && first.body.account_id.length > 8, 'SHARED_ACCOUNT_ID_MISSING');
    report.checks.push('first_handoff_authenticated');
    report.checks.push('no_learning_authority_copied');

    const cookie2 = await handoff(accessToken);
    const second = await me(cookie2);
    assert(second.status === 200 && second.body?.authenticated === true, 'SECOND_SHARED_ME_FAILED');
    assert(second.body.account_id === first.body.account_id, 'SAME_IDENTITY_CREATED_DIFFERENT_ACCOUNT');
    report.checks.push('same_identity_reuses_same_shared_account');

    const tampered = accessToken.slice(0, -1) + (accessToken.endsWith('a') ? 'b' : 'a');
    await expectRejectedToken(tampered);
    report.checks.push('tampered_token_rejected');

    const logout1 = await logout(cookie1);
    assert(logout1.status === 200, 'LOGOUT_ONE_FAILED_' + logout1.status);
    const afterLogout1 = await me(cookie1);
    assert(afterLogout1.status === 401, 'LOGOUT_ONE_SESSION_STILL_VALID');
    report.checks.push('first_shared_session_revoked');

    const secondStillValid = await me(cookie2);
    assert(secondStillValid.status === 200, 'SECOND_SESSION_COUPLED_TO_FIRST_LOGOUT');
    report.checks.push('shared_sessions_are_independent');

    const logout2 = await logout(cookie2);
    assert(logout2.status === 200, 'LOGOUT_TWO_FAILED_' + logout2.status);
    const afterLogout2 = await me(cookie2);
    assert(afterLogout2.status === 401, 'LOGOUT_TWO_SESSION_STILL_VALID');
    report.checks.push('second_shared_session_revoked');

    report.account_hash = crypto.createHash('sha256').update(first.body.account_id).digest('hex').slice(0, 16);
    report.result = 'pass';
    fs.writeFileSync(path.join(ARTIFACT_DIR, 'myraahi-sso-handoff-proof.json'), JSON.stringify(report, null, 2));
    console.log('MYRAAHI_SSO_HANDOFF_SPIKE_PASS run_id=' + rid + ' account_hash=' + report.account_hash);
  } catch (error) {
    report.result = 'fail';
    report.failure = {
      message: error instanceof Error ? error.message : String(error),
      class: 'technology-spike-or-test-harness',
    };
    fs.writeFileSync(path.join(ARTIFACT_DIR, 'myraahi-sso-handoff-proof.json'), JSON.stringify(report, null, 2));
    throw error;
  } finally {
    if (c) {
      try { await c.auth.signOut(); } catch {}
    }
  }
}

await main();
