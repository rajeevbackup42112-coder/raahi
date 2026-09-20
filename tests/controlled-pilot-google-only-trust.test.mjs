import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration=fs.readFileSync('supabase/migrations/20260920020500_1037_v13_controlled_pilot_google_only_trust.sql','utf8');
const live=fs.readFileSync('apps/raahi-learning/live-product-fix-v13.js','utf8');
const release=fs.readFileSync('scripts/prepare-learning-release.mjs','utf8');
const polish=fs.readFileSync('apps/raahi-learning/launch-polish-v13.js','utf8');

test('pilot trust mode is explicit and fails closed when missing',()=>{
  assert.match(migration,/controlled_pilot_google_only/);
  assert.match(migration,/app_private\.runtime_settings/);
  assert.match(migration,/phone_trust_enforcement_enabled/);
  assert.match(migration,/coalesce\([\s\S]*true[\s\S]*\)/i);
  assert.match(migration,/if not app_private\.phone_trust_enforcement_enabled\(\) then[\s\S]*return;/i);
  assert.match(migration,/if not app_private\.has_fresh_phone_trust\(\) then[\s\S]*PHONE_TRUST_REQUIRED/i);
});

test('controlled-pilot release disables phone provider and OTP UI',()=>{
  assert.match(release,/phoneTrustMode:'controlled_pilot_google_only'/);
  assert.match(release,/phoneTrustProvider:'disabled'/);
  assert.doesNotMatch(release,/phoneTrustProvider:'messagecentral'/);
  assert.match(live,/phoneTrustMode/);
  assert.match(live,/Google sign-in is enough for this pilot/);
  assert.match(live,/Phone verification is not required during this pilot/);
  assert.match(polish,/Google sign-in is all you need\. Phone verification is not required\./);
  assert.doesNotMatch(polish,/During this controlled pilot/i);
});

test('future phone-trust machinery is preserved rather than deleted',()=>{
  assert.match(live,/PHONE_TRUST_REQUIRED/);
  assert.match(live,/sendPhoneOtp/);
  assert.match(live,/verifyPhoneOtp/);
  assert.match(live,/get_my_phone_trust/);
  assert.match(migration,/phone_trust_required/);
});
