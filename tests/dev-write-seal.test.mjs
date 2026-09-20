import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const marker='.github/RAAHI_LEARNING_DEV_WRITES_ENABLED';
const workflows=[
  '.github/workflows/raahi-learning-activity-side-effects.yml',
  '.github/workflows/raahi-learning-class-lifecycle-side-effects.yml',
  '.github/workflows/raahi-learning-class-post-side-effects.yml',
  '.github/workflows/raahi-learning-class-race-recovery.yml',
  '.github/workflows/raahi-learning-class-session-side-effects.yml',
  '.github/workflows/raahi-learning-cohort-20.yml',
  '.github/workflows/raahi-learning-dev-e2e.yml',
  '.github/workflows/raahi-learning-enquiry-trial-side-effects.yml',
  '.github/workflows/raahi-learning-org-staff-boundaries.yml',
  '.github/workflows/raahi-learning-organization-authority-side-effects.yml',
  '.github/workflows/raahi-learning-r4-class-thread.yml',
  '.github/workflows/raahi-learning-release-reliability.yml',
  '.github/workflows/raahi-learning-test-correction-side-effects.yml',
  '.github/workflows/raahi-learning-ui-convergence-ads.yml',
  '.github/workflows/raahi-learning-ui-convergence-core.yml',
  '.github/workflows/raahi-learning-ui-convergence-parent-org.yml',
  '.github/workflows/raahi-learning-ui-convergence-privileged.yml',
];

test('DEV write marker is absent after controlled-pilot seal',()=>{
  assert.equal(fs.existsSync(marker), false, 'Pilot cutover must delete the DEV write marker');
});

test('every known synthetic writer workflow fails closed on missing marker',()=>{
  for(const file of workflows){
    const body=fs.readFileSync(file,'utf8');
    assert.match(body,/name:\s*Guard DEV synthetic writes/, file+' missing named DEV write guard');
    assert.match(
      body,
      /test -f \.github\/RAAHI_LEARNING_DEV_WRITES_ENABLED/,
      file+' missing marker fail-closed command',
    );
    const checkout=body.indexOf('uses: actions/checkout@v4');
    const guard=body.indexOf('name: Guard DEV synthetic writes');
    assert.ok(checkout>=0 && guard>checkout, file+' guard must run after checkout');
  }
});

test('synthetic writer workflows are manual-only after controlled-pilot seal',()=>{
  for(const file of workflows){
    const body=fs.readFileSync(file,'utf8');
    assert.match(body,/^  workflow_dispatch:\s*$/m, file+' must retain manual workflow_dispatch');
    assert.doesNotMatch(body,/^  push:\s*$/m, file+' must not auto-run on push after pilot seal');
  }
});

test('read-only/pilot workflows are not coupled to DEV write marker',()=>{
  for(const file of [
    '.github/workflows/raahi-learning-model-tests.yml',
    '.github/workflows/raahi-learning-production-canary.yml',
    '.github/workflows/raahi-learning-production-like-load.yml',
  ]){
    const body=fs.readFileSync(file,'utf8');
    assert.doesNotMatch(body,/Guard DEV synthetic writes/, file+' should remain independently guarded/read-only');
  }
});

test('Model Tests remain allowed to run on push',()=>{
  const body=fs.readFileSync('.github/workflows/raahi-learning-model-tests.yml','utf8');
  assert.match(body,/^  push:\s*$/m);
  assert.match(body,/raahi-learning-implementation-v1/);
});

test('writer inventory remains explicit and unique',()=>{
  assert.equal(workflows.length,17);
  assert.equal(new Set(workflows).size,17);
});
