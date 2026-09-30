import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { chromium } from 'playwright';

const DEV_ORIGIN = 'https://dev.learning.myraahi.co.in';
const EXPECTED_HOST = 'dev.learning.myraahi.co.in';
const TARGET_SHA = process.env.GITHUB_SHA || 'unknown';
const ARTIFACT_DIR = path.resolve('artifacts-myraahi-location-handoff-readonly');

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function staticCompatible(deployedSha, targetSha) {
  if (deployedSha === targetSha) return { compatible: true, exact: true, changed: [], appChanges: [] };
  try {
    execFileSync('git', ['merge-base', '--is-ancestor', deployedSha, targetSha], { stdio: 'ignore' });
    const changed = execFileSync('git', ['diff', '--name-only', deployedSha + '..' + targetSha], { encoding: 'utf8' })
      .split(/\r?\n/).map(x => x.trim()).filter(Boolean);
    const appChanges = changed.filter(x => x.startsWith('apps/raahi-learning/'));
    return { compatible: appChanges.length === 0, exact: false, changed, appChanges };
  } catch {
    return { compatible: false, exact: false, changed: [], appChanges: ['unknown-history'] };
  }
}

async function waitForDeployment() {
  const deadline = Date.now() + 8 * 60 * 1000;
  let last = null;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(DEV_ORIGIN + '/build-meta.json?myraahi=' + Date.now(), { cache: 'no-store' });
      if (res.ok) {
        const meta = await res.json();
        const compatibility = staticCompatible(meta.commit_sha, TARGET_SHA);
        last = { ...meta, compatibility };
        if (compatibility.compatible) return last;
      }
    } catch (error) {
      last = { error: String(error) };
    }
    await new Promise(resolve => setTimeout(resolve, 10000));
  }
  throw new Error('DEV_DEPLOYMENT_NOT_SOURCE_COMPATIBLE: ' + JSON.stringify(last));
}

async function main() {
  assert(new URL(DEV_ORIGIN).hostname === EXPECTED_HOST, 'DEV_ORIGIN_GUARD_FAILED');
  fs.mkdirSync(ARTIFACT_DIR, { recursive: true });

  const deployment = await waitForDeployment();

  const adapterRes = await fetch(DEV_ORIGIN + '/myraahi-location-handoff-v1.js?proof=' + Date.now(), { cache: 'no-store' });
  assert(adapterRes.ok, 'DEPLOYED_HANDOFF_ADAPTER_MISSING_' + adapterRes.status);
  const adapterText = await adapterRes.text();
  assert(adapterText.includes("const PARAM = 'raahi_location'"), 'DEPLOYED_HANDOFF_ADAPTER_WRONG_CONTENT');
  assert(adapterText.includes("rpc('set_selected_location'") || adapterText.includes("rpc('set_selected_location',"), 'DEPLOYED_HANDOFF_CANONICAL_RPC_MISSING');

  const browser = await chromium.launch({ headless: true });
  const observedWriteRequests = [];
  try {
    const context = await browser.newContext();
    const page = await context.newPage();

    page.on('request', request => {
      if (/\/rest\/v1\/rpc\/set_selected_location(?:\?|$)/.test(request.url())) {
        observedWriteRequests.push(request.url());
      }
    });

    await page.goto(DEV_ORIGIN + '/?raahi_location=dhanbad#/home', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(1800);

    const result = await page.evaluate(() => {
      let pending = null;
      try {
        pending = JSON.parse(sessionStorage.getItem('raahi.learning.myraahi-location-handoff.v1') || 'null');
      } catch {}
      return {
        href: location.href,
        pendingSlug: pending?.slug || null,
        hasIdempotencyKey: typeof pending?.idempotencyKey === 'string' && pending.idempotencyKey.startsWith('myraahi-location-dhanbad-'),
        sessionPresent: Boolean(window.RaahiLearningLive?.session),
        adapterDebugStatus: window.RaahiLearningLive?.__myraahiLocationHandoffV1?.status || null,
      };
    });

    assert(result.pendingSlug === 'dhanbad', 'HANDOFF_HINT_NOT_CAPTURED');
    assert(result.hasIdempotencyKey, 'HANDOFF_IDEMPOTENCY_KEY_NOT_CAPTURED');
    assert(new URL(result.href).searchParams.has('raahi_location') === false, 'HANDOFF_QUERY_NOT_CLEANED');
    assert(observedWriteRequests.length === 0, 'LOGGED_OUT_HANDOFF_MUST_NOT_WRITE');

    const report = {
      harness: 'myraahi-learning-location-handoff-readonly-v1',
      target_sha: TARGET_SHA,
      deployment,
      checks: {
        adapter_asset_present: true,
        location_hint_captured: true,
        query_cleaned: true,
        logged_out_write_count: observedWriteRequests.length,
      },
      result: 'pass',
    };

    fs.writeFileSync(path.join(ARTIFACT_DIR, 'proof.json'), JSON.stringify(report, null, 2));
    await page.screenshot({ path: path.join(ARTIFACT_DIR, 'logged-out-location-handoff.png'), fullPage: true });
    await context.close();
  } finally {
    await browser.close();
  }

  console.log('MYRAAHI_LEARN_LOCATION_HANDOFF_READONLY_PASS commit=' + TARGET_SHA);
}

main().catch(error => {
  fs.mkdirSync(ARTIFACT_DIR, { recursive: true });
  fs.writeFileSync(path.join(ARTIFACT_DIR, 'failure.json'), JSON.stringify({
    result: 'fail',
    message: error instanceof Error ? error.message : String(error),
  }, null, 2));
  console.error(error);
  process.exit(1);
});
