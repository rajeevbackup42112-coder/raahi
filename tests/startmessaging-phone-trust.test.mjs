import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const edge=fs.readFileSync('supabase/functions/phone-trust-startmessaging/index.ts','utf8');
const migration=fs.readFileSync('supabase/migrations/20260922150119_v14f_startmessaging_phone_trust.sql','utf8');
const live=fs.readFileSync('apps/raahi-learning/live-product-fix-v13.js','utf8');
const release=fs.readFileSync('scripts/prepare-learning-release.mjs','utf8');

test('StartMessaging is delivery-only while Supabase Auth remains durable trust source',()=>{
  assert.match(edge,/https:\/\/api\.startmessaging\.com/);
  assert.match(edge,/STARTMESSAGING_API_KEY/);
  assert.match(edge,/X-API-Key|x-api-key/i);
  assert.match(edge,/\/otp\/send/);
  assert.match(edge,/phoneNumber:phone/);
  assert.match(edge,/variables:\{otp,appName:'Raahi Learning'\}/);
  assert.match(edge,/randomOtp6/);
  assert.match(edge,/HMAC/);
  assert.match(edge,/SHA-256/);
  assert.match(edge,/auth\.admin\.updateUserById/);
  assert.match(edge,/phone_confirm:true/);
  assert.match(edge,/updated\.user\?\.id!==user\.id/);
});

test('OTP plaintext is never persisted or returned by the StartMessaging bridge',()=>{
  assert.match(migration,/add column otp_digest text/);
  assert.match(migration,/startmessaging/);
  assert.match(migration,/\^\[0-9a-f\]\{64\}\$/);
  assert.match(edge,/otp_digest:otpDigest/);
  assert.doesNotMatch(edge,/otp_code\s*:/i);
  assert.doesNotMatch(edge,/otp_value\s*:/i);
  assert.doesNotMatch(edge,/reply\([^\n]+\{[^\n]*otp/i);
  assert.doesNotMatch(edge,/console\.(?:log|error)\([^\n]*(?:STARTMESSAGING_API_KEY|\botp\b)/i);
});

test('StartMessaging bridge remains authenticated, origin-bounded and rate limited',()=>{
  assert.match(edge,/authorization/);
  assert.match(edge,/admin\.auth\.getUser/);
  assert.match(edge,/https:\/\/dev\.learning\.myraahi\.co\.in/);
  assert.match(edge,/https:\/\/learning\.myraahi\.co\.in/);
  assert.match(edge,/USER_SENDS_PER_10_MIN=3/);
  assert.match(edge,/USER_SENDS_PER_DAY=10/);
  assert.match(edge,/PHONE_SENDS_PER_10_MIN=5/);
  assert.match(edge,/MAX_VERIFY_ATTEMPTS=5/);
  assert.match(edge,/PHONE_OTP_RATE_LIMIT/);
  assert.match(edge,/VERIFY_ATTEMPTS_EXCEEDED/);
});

test('Provider errors are reduced to safe public codes',()=>{
  assert.match(edge,/STARTMESSAGING_AUTH_FAILED/);
  assert.match(edge,/PHONE_OTP_PROVIDER_BALANCE/);
  assert.match(edge,/PHONE_OTP_PROVIDER_LIMIT/);
  assert.match(edge,/PHONE_OTP_SEND_FAILED/);
  assert.doesNotMatch(edge,/return reply\([^\n]+body/i);
});

test('browser bridge supports StartMessaging without exposing the API key',()=>{
  assert.match(live,/phone-trust-startmessaging/);
  assert.match(live,/provider === 'startmessaging'/);
  assert.match(live,/flow\.provider === 'messagecentral' \|\| flow\.provider === 'startmessaging'/);
  assert.doesNotMatch(live,/STARTMESSAGING_API_KEY/);
  assert.doesNotMatch(live,/sm_live_/);
});

test('production activation remains sealed until hosted Raahi provider proof completes',()=>{
  assert.match(release,/phoneTrustMode:'controlled_pilot_google_only'/);
  assert.match(release,/phoneTrustProvider:'disabled'/);
  assert.doesNotMatch(release,/phoneTrustProvider:'startmessaging'/);
  assert.doesNotMatch(release,/STARTMESSAGING_API_KEY/);
});
