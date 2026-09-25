import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const js=fs.readFileSync('apps/raahi-learning/delight-v14.js','utf8');
const css=fs.readFileSync('apps/raahi-learning/delight-v14.css','utf8');
const builder=fs.readFileSync('apps/raahi-learning/build-source-v13.mjs','utf8');
const packager=fs.readFileSync('scripts/prepare-learning-release.mjs','utf8');

test('V1.4 delight layer is presentation-only',()=>{
  for(const forbidden of [/\brpc\s*\(/i,/supabase/i,/\.from\s*\(/i,/\bfetch\s*\(/i,/\.insert\s*\(/i,/\.update\s*\(/i,/\.delete\s*\(/i]){
    assert.doesNotMatch(js,forbidden);
  }
  assert.match(js,/Presentation-only V1\.4 delight layer/);
  assert.match(js,/Your local learning network/);
  assert.match(js,/Learning, closer to home\./);
  assert.match(js,/suppressMeaninglessEmptySponsored/);
  assert.match(js,/Find\. Learn\. Grow\./);
  assert.match(js,/Find a teacher/);
  assert.match(js,/I need tuition/);
  assert.match(js,/Are you a teacher\?/);
  assert.match(js,/href="#\/teacher-setup" data-v14-start-teaching>Start teaching/);
  assert.match(css,/hero\.v14-local-hero:before[\s\S]*pointer-events:none/);
  assert.match(css,/v14-teach-entry[^}]*z-index:2/);
  assert.doesNotMatch(js,/[\u00c3\u00e2\ufffd]/);
});

test('V1.4 visual layer stays truthful and accessible by construction',()=>{
  assert.doesNotMatch(js,/\b(fake|fabricat(?:e|ed)|dummy user|fake review|fake rating)\b/i);
  assert.match(js,/Google sign-in/);
  assert.match(js,/Privacy-first/);
  assert.match(js,/Find teachers, Classes and local learning around Dhanbad and Gomoh\./);
  assert.match(js,/v15-notification-button/);
  assert.match(js,/v15-context-select/);
  assert.match(js,/v15-account-avatar/);
  assert.match(js,/Use my Google photo/);
  assert.match(js,/Updates from your Classes, enquiries and Raahi activity\./);
  assert.match(js,/v15-notification-card/);
  assert.match(css,/v15-notification-summary/);
  assert.match(css,/prefers-reduced-motion/);
  assert.match(css,/v14-welcome-values/);
  assert.match(css,/v14-local-hero/);
});

test('canonical reconstruction and release packaging include delight V1.4',()=>{
  for(const source of [builder,packager]){
    assert.match(source,/delight-v14\.css/);
    assert.match(source,/delight-v14\.js/);
  }
  assert.match(packager,/Raahi Learning Network/);
});
