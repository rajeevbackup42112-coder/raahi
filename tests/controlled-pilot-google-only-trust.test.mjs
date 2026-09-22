import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration=fs.readFileSync('supabase/migrations/20260920020500_1037_v13_controlled_pilot_google_only_trust.sql','utf8');
const activation=fs.readFileSync('supabase/migrations/20260922214214_v14h_activate_startmessaging_phone_trust.sql','utf8');
const live=fs.readFileSync('apps/raahi-learning/live-product-fix-v13.js','utf8');
const release=fs.readFileSync('scripts/prepare-learning-release.mjs','utf8');
const polish=fs.readFileSync('apps/raahi-learning/launch-polish-v13.js','utf8');

test('historical pilot trust mode remains fail-closed when the setting is absent or unknown',()=>{
  assert.match(migration,/controlled_pilot_google_only/);
  assert.match(migration,/app_private\.runtime_settings/);
  assert.match(migration,/phone_trust_enforcement_enabled/);
  assert.match(migration,/coalesce\([\s\S]*true[\s\S]*\)/i);
  assert.match(migration,/if not app_private\.phone_trust_enforcement_enabled\(\) then[\s\S]*return;/i);
  assert.match(migration,/if not app_private\.has_fresh_phone_trust\(\) then[\s\S]*PHONE_TRUST_REQUIRED/i);
});

test('post-proof release activates StartMessaging phone trust while keeping Google primary sign-in',()=>{
  assert.match(activation,/phone_trust_required/);
  assert.match(release,/phoneTrustMode:'phone_trust_required'/);
  assert.match(release,/phoneTrustProvider:'startmessaging'/);
  assert.doesNotMatch(release,/phoneTrustProvider:'messagecentral'/);
  assert.doesNotMatch(release,/phoneTrustProvider:'disabled'/);
  assert.match(live,/phoneTrustMode/);
  assert.match(live,/For some sensitive actions|Quick phone check|Phone confirmed/);
  assert.match(polish,/For some sensitive actions, Raahi may ask you to confirm your phone number/);
});

test('phone-trust machinery remains server-authorized and action scoped',()=>{
  assert.match(live,/PHONE_TRUST_REQUIRED/);
  assert.match(live,/sendPhoneOtp/);
  assert.match(live,/verifyPhoneOtp/);
  assert.match(live,/get_my_phone_trust/);
  assert.match(migration,/phone_trust_required/);
});
