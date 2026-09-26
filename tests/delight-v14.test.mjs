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
  assert.match(css,/V1\.4O mobile action ergonomics/);
  assert.match(css,/\.main \.small[\s\S]*min-height:44px/);
  assert.match(css,/\.main \.chip[\s\S]*min-height:44px/);
  assert.match(js,/Your profile, sign-in and account\./);
  assert.match(js,/Pause or close account/);
  assert.match(js,/Phone security/);
  assert.match(css,/v15-account-options:not\(\[open\]\)/);
  assert.match(js,/Your conversations with teachers and Classes\./);
  assert.match(js,/Private Class conversation about/);
  assert.match(js,/Write a message…/);
  assert.match(js,/v15-message-bubble/);
  assert.match(css,/v15-conversation-composer/);
  assert.match(css,/v15-message-bubble\.is-mine/);
  assert.match(js,/Your teaching/);
  assert.match(js,/Profile, Classes and learner activity in one place\./);
  assert.match(js,/Edit what I teach/);
  assert.match(js,/Open Classes/);
  assert.match(js,/v15-teacher-profile-card/);
  assert.match(css,/v15-teacher-dashboard/);
  assert.match(css,/\.v14-category-chip[\s\S]*min-height:44px/);
  assert.match(js,/Institute workspace/);
  assert.match(js,/Learning, Classes, team and Raahi Ads in one place\./);
  assert.match(js,/Edit institute profile/);
  assert.match(js,/Open Raahi Ads/);
  assert.match(js,/v15-institute-profile-card/);
  assert.match(css,/v15-institute-dashboard/);
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
