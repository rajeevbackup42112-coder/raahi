import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const teacher=fs.readFileSync('apps/raahi-learning/founding-supply-v14c.js','utf8');
const product=fs.readFileSync('apps/raahi-learning/live-product-fix-v13.js','utf8');
const delight=fs.readFileSync('apps/raahi-learning/delight-v14.js','utf8');

function slice(source,start,end){
  const a=source.indexOf(start);
  const b=source.indexOf(end,a+1);
  assert(a>=0,'missing start '+start);
  assert(b>a,'missing end '+end);
  return source.slice(a,b);
}

test('Teacher first-use setup uses human goals rather than authority vocabulary',()=>{
  const s=slice(teacher,'function selfServiceTeacherSetup','function proposalSummary');
  for(const expected of ['About you','What you teach','Where and how','Review and publish','You stay in control'])
    assert(s.includes(expected),'missing '+expected);
  assert.doesNotMatch(s,/Teacher capability|Server-authorized|authorization|capability/i);
});

test('Teacher review preserves consent but hides implementation version codes',()=>{
  const s=slice(teacher,"if (r.state === 'draft_ready')","if (r.state === 'accepted')");
  assert.match(s,/Publish these details/);
  assert.match(s,/confirm that the information above is accurate/);
  assert.doesNotMatch(s,/Consent version|consent_text_version|<code>/i);
});

test('Teacher accepted state speaks in normal ownership/edit language',()=>{
  const s=slice(teacher,"if (r.state === 'accepted')","return api.layout");
  assert.match(s,/Teacher Profile and first teaching option are now live/);
  assert.match(s,/edit them anytime/);
  assert.doesNotMatch(s,/owned by your Account/i);
});

test('My Classes ordinary copy hides Membership and authority mechanics',()=>{
  const s=slice(product,'function pageClasses','function pageInvitation');
  const i=slice(product,'function pageInvitation','function pageLearners');
  assert.match(s,/Your current Classes and pending invitations/);
  assert.match(i,/invitation is still valid/);
  assert.doesNotMatch(s+i,/relationship-scoped|Membership|current authority/i);
});

test('Learning profiles ordinary copy avoids Account and invariant vocabulary',()=>{
  const s=slice(product,'function pageLearners','function normalizeIndianMobileInput');
  assert.match(s,/My learning/);
  assert.match(s,/Managed by you/);
  assert.match(s,/another valid way to access or manage their learning/);
  assert.doesNotMatch(s,/Managed by this Account|learner-side access path|server rechecks|invariant/i);
});

test('phone trust explains security without exposing role/authority terminology',()=>{
  const s=slice(product,'function pagePhoneCheck','const originalRender = live.renderRoute');
  assert.match(s,/security check for sensitive actions/);
  assert.match(s,/does not change what you can do in Raahi/);
  assert.doesNotMatch(s,/does not change your Raahi roles or learner authority/i);
});


test('public positioning does not imply a learner directory',()=>{
  assert.match(delight,/Find teachers\. Share what you need\. Learn locally\./);
  assert.doesNotMatch(delight,/Find students/i);
});

test('copy-only alignment does not add operational table writes',()=>{
  for(const source of [teacher,product]){
    assert.doesNotMatch(source,/\.insert\s*\(/);
    assert.doesNotMatch(source,/\.update\s*\(/);
    assert.doesNotMatch(source,/\.delete\s*\(/);
  }
});
