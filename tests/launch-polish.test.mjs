import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const polish=fs.readFileSync('apps/raahi-learning/launch-polish-v13.js','utf8');
const privacy=fs.readFileSync('apps/raahi-learning/privacy.html','utf8');
const terms=fs.readFileSync('apps/raahi-learning/terms.html','utf8');
const builder=fs.readFileSync('apps/raahi-learning/build-source-v13.mjs','utf8');

test('launch polish is presentation-only and removes internal-facing labels',()=>{
  assert.match(polish,/Taking new learners/);
  assert.match(polish,/Access confirmed/);
  assert.match(polish,/For some sensitive actions, Raahi may ask you to confirm your phone number/);
  assert.match(polish,/Your Classes and learning history stay private/);
  assert.match(polish,/privacy\.html/);
  assert.match(polish,/terms\.html/);
  assert.match(polish,/polishOperationalSummaries/);
  assert.match(polish,/Active Classes/);
  assert.match(polish,/Open learning requests/);
  assert.match(polish,/stripEscapedWhitespaceArtifacts/);
  assert.match(polish,/replaceChildren\(grid\)/);
  assert.doesNotMatch(polish,/\.rpc\s*\(/);
  assert.doesNotMatch(polish,/supabase/i);
  assert.doesNotMatch(polish,/service_role|sb_secret_/i);
  assert.doesNotMatch(polish,/fetch\s*\(/);
});

test('public policy pages contain no DEV or fixture language',()=>{
  for(const [name,body] of [['privacy',privacy],['terms',terms]]){
    assert.match(body,/Raahi Learning/);
    assert.match(body,/support@myraahi\.co\.in/);
    assert.doesNotMatch(body,/dev-test|E2E|fixture|iiwwmqokaeflaenhlyip|sb_secret_/i,name+' contains internal reference');
  }
  assert.match(privacy,/Google is used to authenticate you/);
  assert.match(privacy,/We do not sell personal data to advertisers/);
  assert.match(terms,/early public release in Gomoh and Dhanbad/i);
});

test('reconstructed browser build includes launch polish and policy pages',()=>{
  assert.match(builder,/launch-polish-v13\.js/);
  assert.match(builder,/privacy\.html/);
  assert.match(builder,/terms\.html/);
  assert.match(builder,/theme-color/);
  assert.match(builder,/Find local teachers, Classes and learning opportunities with Raahi Learning/);
});

test('public Google-only copy no longer calls the live service a controlled pilot',()=>{
  assert.match(polish,/Google sign-in is all you need\. Phone verification is not required\./);
  assert.doesNotMatch(polish,/During this controlled pilot/i);
});
