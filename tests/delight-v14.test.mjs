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
  assert.match(js,/Find teachers\. Find students\. Learn locally\./);
  assert.match(js,/suppressMeaninglessEmptySponsored/);
  assert.match(js,/Find\. Learn\. Grow\./);
  assert.match(js,/Find a teacher/);
  assert.match(js,/I need tuition/);
  assert.match(js,/Are you a teacher\?/);
  assert.match(js,/data-route="teacher-setup">Start teaching/);
  assert.match(css,/v14-teach-entry/);
  assert.doesNotMatch(js,/[\u00c3\u00e2\ufffd]/);
});

test('V1.4 visual layer stays truthful and accessible by construction',()=>{
  assert.doesNotMatch(js,/\b(fake|fabricat(?:e|ed)|dummy user|fake review|fake rating)\b/i);
  assert.match(js,/Google sign-in/);
  assert.match(js,/Privacy-first/);
  assert.match(js,/Switch Locations anytime/);
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
