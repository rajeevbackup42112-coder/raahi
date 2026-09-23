import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const product=fs.readFileSync('apps/raahi-learning/live-product-fix-v13.js','utf8');
const assisted=fs.readFileSync('apps/raahi-learning/founding-supply-v14c.js','utf8');

test('sensitive-action runner preserves destination and can restore Teacher view after server success',()=>{
  assert.match(product,/const pendingAction = \{ \.\.\.action, successRoute: action\.successRoute \|\| successRoute \|\| null \}/);
  assert.match(product,/if \(action\.postRole\) api\.state\.role = action\.postRole/);
  assert.match(product,/action\.postRole === 'teacher'[\s\S]*get_my_teacher_workspace/);
  assert.match(product,/live\.runSensitiveActionV13 = runSensitiveAction/);
  assert.match(product,/savePendingAction\(pendingAction\)/);
});

test('self-service teaching enable uses trust-aware resume and opens About you',()=>{
  assert.match(product,/data-live-enable-teaching/);
  assert.match(product,/rpc:'enable_teaching'/);
  assert.match(product,/successRoute:'teacher-profile-edit'/);
  assert.match(product,/postRole:'teacher'/);
  assert.match(product,/Teaching setup started/);
});

test('first self-service profile continues to first What I Teach',()=>{
  const start=product.indexOf("form.id === 'live-teacher-profile-form'");
  const end=product.indexOf("if (form.id === 'live-option-form'",start);
  const block=product.slice(start,end);
  assert.match(block,/options\.length === 0/);
  assert.match(block,/rpc:'upsert_teacher_profile'/);
  assert.match(block,/successRoute:'teaching-option-edit'/);
  assert.match(block,/clearTeachingOption:true/);
});

test('first What I Teach publish includes Locations and finishes at Teacher Home',()=>{
  const start=product.indexOf("form.id === 'live-option-form'");
  const end=product.indexOf("document.addEventListener('click'",start);
  const block=product.slice(start,end);
  assert.match(block,/options\.length === 0/);
  assert.match(block,/input\[name="locations"\]:checked/);
  assert.match(block,/rpc:'publish_teaching_option'/);
  assert.match(block,/p_location_ids:locationIds/);
  assert.match(block,/successRoute:'teacher-home'/);
  assert.match(block,/Your teaching setup is ready/);
});

test('assisted Teacher acceptance uses the same trust-aware continuation path',()=>{
  const start=assisted.indexOf("if (target.matches('[data-founding-accept]'))");
  const end=assisted.indexOf("if (target.matches('[data-founding-open-teacher]'))",start);
  const block=assisted.slice(start,end);
  assert.match(block,/accept_assisted_teacher_onboarding/);
  assert.match(block,/runSensitiveActionV13/);
  assert.match(block,/successRoute:'teacher-home'/);
  assert.match(block,/postRole:'teacher'/);
});

test('Teacher onboarding continuity adds no direct browser table mutation or secret handling',()=>{
  for(const source of [product,assisted]){
    assert.doesNotMatch(source,/\.from\s*\(/);
    assert.doesNotMatch(source,/\.insert\s*\(/);
    assert.doesNotMatch(source,/\.update\s*\(/);
    assert.doesNotMatch(source,/\.delete\s*\(/);
    assert.doesNotMatch(source,/service_role|sb_secret_|STARTMESSAGING_API_KEY/i);
  }
});
