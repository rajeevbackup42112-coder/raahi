import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const sealed=fs.readFileSync('supabase/functions/phone-trust-messagecentral/pilot-disabled-index.ts','utf8');
const release=fs.readFileSync('scripts/prepare-learning-release.mjs','utf8');

test('MessageCentral is sealed during Google-only controlled pilot',()=>{
  assert.match(sealed,/PHONE_PROVIDER_DISABLED_DURING_GOOGLE_ONLY_PILOT/);
  assert.match(sealed,/status:\s*410/);
  assert.doesNotMatch(sealed,/MESSAGECENTRAL_/);
  assert.doesNotMatch(sealed,/fetch\s*\(/);
  assert.match(release,/phoneTrustProvider:'disabled'/);
});
