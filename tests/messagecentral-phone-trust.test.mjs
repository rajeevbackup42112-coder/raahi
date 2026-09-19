import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const edge=fs.readFileSync('supabase/functions/phone-trust-messagecentral/index.ts','utf8');
const migration=fs.readFileSync('supabase/migrations/20260919181500_1035_v13_messagecentral_phone_trust_challenges.sql','utf8');
const live=fs.readFileSync('apps/raahi-learning/live-product-fix-v13.js','utf8');
const release=fs.readFileSync('scripts/prepare-learning-release.mjs','utf8');

test('MessageCentral bridge owns OTP challenge while Supabase remains phone-trust source of truth',()=>{
  assert.match(edge,/cpaas\.messagecentral\.com/);
  assert.match(edge,/MESSAGECENTRAL_PASSWORD/);
  assert.match(edge,/TextEncoder/);
  assert.match(edge,/\/verification\/v3\/send/);
  assert.match(edge,/\/verification\/v3\/validateOtp/);
  assert.match(edge,/VERIFICATION_COMPLETED/);
  assert.match(edge,/auth\.admin\.updateUserById/);
  assert.match(edge,/phone_confirm:\s*true/);
  assert.doesNotMatch(edge,/console\.(?:log|error)\([^\n]*(?:MESSAGECENTRAL_PASSWORD|authToken|token\s*:)/i);
});

test('MessageCentral bridge is authenticated, origin-bounded and rate limited',()=>{
  assert.match(edge,/authorization/);
  assert.match(edge,/admin\.auth\.getUser/);
  assert.match(edge,/https:\/\/dev\.learning\.myraahi\.co\.in/);
  assert.match(edge,/https:\/\/learning\.myraahi\.co\.in/);
  assert.match(edge,/USER_SENDS_PER_10_MIN\s*=\s*3/);
  assert.match(edge,/USER_SENDS_PER_DAY\s*=\s*10/);
  assert.match(edge,/MAX_VERIFY_ATTEMPTS\s*=\s*5/);
  assert.match(edge,/PHONE_OTP_RATE_LIMIT/);
});

test('challenge ledger stores provider references but never OTP codes and has no browser grants',()=>{
  assert.match(migration,/phone_trust_challenges/);
  assert.match(migration,/provider_verification_id/);
  assert.match(migration,/verify_attempts/);
  assert.doesNotMatch(migration,/\botp(?:_code|_value)?\s+(?:text|varchar|integer|bigint|jsonb)\b/i);
  assert.match(migration,/enable row level security/i);
  assert.match(migration,/force row level security/i);
  assert.match(migration,/revoke all on table public\.phone_trust_challenges from public, anon, authenticated/i);
  assert.match(migration,/grant select, insert, update, delete on table public\.phone_trust_challenges to service_role/i);
});

test('DEV remains Supabase-compatible while release selects MessageCentral',()=>{
  assert.match(live,/window\.RAAHI_RELEASE_CONFIG\?\.phoneTrustProvider \|\| 'supabase'/);
  assert.match(live,/messageCentralPhoneTrust/);
  assert.match(live,/provider:'messagecentral'/);
  assert.match(live,/signInWithOtp/);
  assert.match(live,/verifyOtp/);
  assert.match(release,/phoneTrustProvider:'messagecentral'/);
  assert.doesNotMatch(release,/MESSAGECENTRAL_(?:CUSTOMER_ID|PASSWORD|EMAIL)/);
});
