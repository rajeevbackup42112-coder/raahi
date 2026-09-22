import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration=fs.readFileSync('supabase/migrations/20260922213000_v14h_activate_startmessaging_phone_trust.sql','utf8');
const release=fs.readFileSync('scripts/prepare-learning-release.mjs','utf8');
const live=fs.readFileSync('apps/raahi-learning/live-product-fix-v13.js','utf8');
const edge=fs.readFileSync('supabase/functions/phone-trust-startmessaging/index.ts','utf8');

test('activation sets the server trust mode to required',()=>{
  assert.match(migration,/setting_key,setting_value/);
  assert.match(migration,/phone_trust_mode','phone_trust_required/);
  assert.match(migration,/phone_trust_enforcement_enabled/);
  assert.match(migration,/create or replace function public\.get_phone_trust_policy/);
  assert.match(migration,/PHONE_TRUST_ACTIVATION_FAILED/);
  assert.match(migration,/PHONE_TRUST_POLICY_PROJECTION_FAILED/);
});

test('release UI and server provider are activated as one coherent contract',()=>{
  assert.match(release,/phoneTrustMode:'phone_trust_required'/);
  assert.match(release,/phoneTrustProvider:'startmessaging'/);
  assert.match(live,/provider === 'startmessaging'/);
  assert.match(edge,/STARTMESSAGING_API_KEY/);
  assert.match(edge,/auth\.admin\.updateUserById/);
});

test('activation does not turn phone OTP into a primary login or expose provider secrets',()=>{
  assert.match(live,/This is not a second login/);
  assert.doesNotMatch(release,/STARTMESSAGING_API_KEY/);
  assert.doesNotMatch(release,/sm_live_/);
  assert.doesNotMatch(live,/STARTMESSAGING_API_KEY|sm_live_/);
});
