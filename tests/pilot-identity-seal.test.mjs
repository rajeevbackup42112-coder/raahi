import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const file='supabase/functions/dev-test-identities/pilot-sealed-index.ts';
const body=fs.readFileSync(file,'utf8');

test('pilot identity-factory seal is explicitly non-mutating',()=>{
  assert.match(body,/DEV_TEST_IDENTITIES_DISABLED_FOR_CONTROLLED_PILOT/);
  assert.match(body,/status:\s*410/);
  assert.doesNotMatch(body,/SUPABASE_SERVICE_ROLE_KEY/);
  assert.doesNotMatch(body,/auth\.admin/);
  assert.doesNotMatch(body,/createUser|updateUserById|deleteUser/);
  assert.doesNotMatch(body,/\.from\s*\(/);
  assert.doesNotMatch(body,/\.rpc\s*\(/);
});

test('pilot seal source warns not to deploy during Stage',()=>{
  assert.match(body,/Do not deploy during DEV\/STAGE/i);
  assert.match(body,/verify_jwt=true/);
});
