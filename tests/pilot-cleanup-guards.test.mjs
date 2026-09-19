import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sql=fs.readFileSync('scripts/raahi-learning-pilot-clean-public-domain.sql','utf8');
const auth=fs.readFileSync('tests/raahi-learning-e2e/pilot-delete-harness-auth.mjs','utf8');

test('pilot public cleanup is fail-closed and preserves Location configuration',()=>{
  assert.match(sql,/PILOT_CLEANUP_CONFIRMATION_REQUIRED/);
  assert.match(sql,/CLEAN_SYNTHETIC_PUBLIC_DOMAIN_FOR_CONTROLLED_PILOT/);
  assert.match(sql,/table_name <> 'locations'/);
  assert.match(sql,/slug='dhanbad' and state='live'/);
  assert.match(sql,/slug='gomoh' and state='preparing'/);
  assert.match(sql,/v_public_tables <> 70/);
  assert.match(sql,/v_non_harness <> 8/);
  assert.match(sql,/v_storage_objects <> 0/);
  assert.match(sql,/truncate table public\.access_restrictions/);
  assert.doesNotMatch(sql,/truncate table[^;]*public\.locations/i);
});

test('pilot Auth cleanup deletes only authoritative harness identities',()=>{
  assert.match(auth,/EXPECTED_URL='https:\/\/iiwwmqokaeflaenhlyip\.supabase\.co'/);
  assert.match(auth,/DELETE_RAAHI_LEARNING_HARNESS_AUTH_USERS_FOR_CONTROLLED_PILOT/);
  assert.match(auth,/user_metadata\?\.raahi_test_harness===true/);
  assert.match(auth,/protectedUsers\.length!==8/);
  assert.match(auth,/admin\.auth\.admin\.deleteUser\(user\.id\)/);
  assert.match(auth,/remainingHarness\.length!==0/);
  assert.match(auth,/remainingProtected\.length!==8/);
  assert.doesNotMatch(auth,/email.*@dev\.learning/i);
});
