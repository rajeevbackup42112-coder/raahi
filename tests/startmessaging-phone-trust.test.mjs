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
  assert.match(edge,/samePhone\(updated\.user\?\.phone,c\.phone_e164\)/);
  assert.match(edge,/canonicalPhone/);
});

test('post-confirmation recovery reconciles equivalent phone formatting without another OTP',()=>{
  assert.match(edge,/Number\(c\.verify_attempts\)>0/);
  assert.match(edge,/confirmedAt>=Date\.parse\(c\.created_at\)/);
  assert.match(edge,/samePhone\(latest\.user\?\.phone,c\.phone_e164\)/);
  assert.match(edge,/reconciled:true/);
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

test('duplicate confirmed phone is rejected before provider send and rechecked before Auth attachment',()=>{
  assert.match(edge,/admin\.auth\.admin\.listUsers/);
  assert.match(edge,/requirePhoneAvailableToUser\(phone,user\.id\)/);
  assert.match(edge,/requirePhoneAvailableToUser\(c\.phone_e164,user\.id\)/);
  assert.match(edge,/PHONE_ALREADY_IN_USE/);
  const sendPos=edge.indexOf('await requirePhoneAvailableToUser(phone,user.id)');
  const providerPos=edge.indexOf('const messageId=await sendProvider(phone,otp)');
  assert(sendPos>=0&&providerPos>sendPos);
});

test('browser surfaces safe duplicate-phone guidance instead of generic Edge errors',()=>{
  assert.match(live,/This mobile number is already linked to another Raahi sign-in/);
  assert.match(live,/PHONE_ALREADY_IN_USE/);
  assert.match(live,/error\.context\.clone\(\)\.json\(\)/);
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

test('Indian phone UX accepts national numbers and adds +91 automatically',()=>{
  assert.match(live,/Indian mobile number/);
  assert.match(live,/Enter your 10-digit mobile number\. Raahi adds \+91 automatically/);
  assert.match(live,/normalizeIndianMobileInput/);
  assert.match(live,/digits\.length === 12 && digits\.startsWith\('91'\)/);
  assert.match(live,/digits\.length === 11 && digits\.startsWith\('0'\)/);
  assert.match(live,/return '\+91' \+ digits/);
  assert.doesNotMatch(live,/Phone in E\.164 format/);
  assert.doesNotMatch(live,/Enter a valid Indian mobile number in \+91 format/);

  assert.match(edge,/digits\.length===12&&digits\.startsWith\('91'\)/);
  assert.match(edge,/digits\.length===11&&digits\.startsWith\('0'\)/);
  assert.match(edge,/return '\+91'\+digits/);
});

test('phone-check exposes a real local-device logout and clears transient phone flow',()=>{
  assert.match(live,/data-live-fix-logout>Log out</);
  assert.match(live,/auth\.signOut\(\{ scope:'local' \}\)/);
  assert.match(live,/sessionStorage\.removeItem\(PHONE_FLOW_KEY\)/);
  assert.match(live,/clearPendingAction\(\)/);
  assert.match(live,/location\.replace\(cleanUrl\)/);
  assert.match(live,/Phone confirmed[\s\S]*data-live-fix-logout>Log out/);
  assert.match(live,/Verification code[\s\S]*data-live-fix-logout>Log out/);
});

test('production release activates StartMessaging after hosted proof without exposing its secret',()=>{
  assert.match(release,/phoneTrustMode:'phone_trust_required'/);
  assert.match(release,/phoneTrustProvider:'startmessaging'/);
  assert.doesNotMatch(release,/controlled_pilot_google_only/);
  assert.doesNotMatch(release,/STARTMESSAGING_API_KEY/);
  assert.doesNotMatch(release,/sm_live_/);
});
