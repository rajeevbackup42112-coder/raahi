import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const polish = fs.readFileSync('apps/raahi-learning/launch-polish-v13.js','utf8');
const product = fs.readFileSync('apps/raahi-learning/live-product-fix-v13.js','utf8');
const admin = fs.readFileSync('apps/raahi-learning/admin-management-v14e.js','utf8');

const requiredHumanCopy = [
  'Choose what you want to do first. You can use Raahi in other ways anytime.',
  'Your learning profiles are private and never shown in a public learner directory.',
  'A private conversation about this learner and Class.',
  'Raahi checks that the new Class still has space when you confirm.',
  'You can see Rahul’s Test status and released results',
  'Each Class has one responsible teacher.',
  'This list only includes learners in this Class.',
  'Invite staff with private one-time links.',
  'This view shows local totals and public provider activity',
  'Sensitive actions are logged and limited to what is necessary.',
  'A readable history of important platform actions.',
  'Advertising access is separate from verification.',
  'Live ads are always clearly labelled Sponsored.',
  'Analytics show totals only, never a named viewer list.'
];

test('product-wide presentation layer contains the required human copy',()=>{
  for (const phrase of requiredHumanCopy) assert.ok(polish.includes(phrase),'missing human copy: '+phrase);
});
test('phone security check avoids trust-state implementation language',()=>{
  const start=product.indexOf('function pagePhoneCheck()');
  const end=product.indexOf('live.canOpenRoute',start);
  const block=product.slice(start,end);
  assert.match(block,/Security check/);
  assert.match(block,/Checking your phone/);
  assert.match(block,/You’re ready to continue/);
  assert.doesNotMatch(block,/server-verified trust state|trust is fresh/i);
});

test('Location Admin management uses operator goals instead of backend vocabulary',()=>{
  assert.match(admin,/Manage Local Admin access for each Location/);
  assert.match(admin,/Assign or remove Local Managers for each Location/);
  assert.match(admin,/Currently manages:/);
  assert.doesNotMatch(admin,/without Supabase SQL|administrative authority|Local Manager scope/i);
});

test('presentation replacements cover legacy implementation-shaped phrases',()=>{
  const legacy = [
    'Transfer creates destination Membership',
    'Protected files follow Class authorization',
    'One responsible teacher per Class in V1.',
    'capability-based access',
    'Aggregate/location-scoped operational projection.',
    'Campaign creation is server-authorized.',
    'serving UI',
    'One account may hold several capabilities.'
  ];
  for (const phrase of legacy) assert.ok(polish.includes(phrase),'legacy phrase lacks a presentation replacement: '+phrase);
});
test('human-language changes add no operational table writes or privileged secrets',()=>{
  for (const source of [polish,admin,product]) {
    assert.doesNotMatch(source,/\.insert\s*\(/);
    assert.doesNotMatch(source,/\.update\s*\(/);
    assert.doesNotMatch(source,/service_role|sb_secret_|STARTMESSAGING_API_KEY/i);
  }
});
