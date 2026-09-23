import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const product=fs.readFileSync('apps/raahi-learning/live-product-fix-v13.js','utf8');
const buildSource=fs.readFileSync('apps/raahi-learning/build-source-v13.mjs','utf8');
const releaseSource=fs.readFileSync('scripts/prepare-learning-release.mjs','utf8');
const migration=fs.readFileSync('supabase/migrations/20260923134900_v14l_realtime_invalidation_publication.sql','utf8');

test('Learner creation clears cached route loads before returning home',()=>{
  const start=product.indexOf("rpc('create_learner'");
  const block=product.slice(start,start+1200);
  assert.match(block,/live\.routeLoads\.clear\(\)[\s\S]*refreshCoreState\(\)[\s\S]*api\.go\('home'\)/);
});

test('Institute creation uses the same resumable phone-trust path as other sensitive actions',()=>{
  const start=product.indexOf("rpc:'create_organization'");
  const block=product.slice(Math.max(0,start-700),start+1200);
  assert.match(block,/runSensitiveAction/);
  assert.match(block,/successRoute:'org-home'/);
  assert.match(block,/postRole:'institute'/);
  assert.match(product,/action\.postRole === 'institute'[\s\S]*get_organization_workspace/);
});

test('Class learning cards select their server IDs before opening detail routes',()=>{
  assert.match(product,/\[data-live-activity\]/);
  assert.match(product,/live\.selected\.activityId = t\.dataset\.liveActivity[\s\S]*api\.go\('activity'\)/);
  assert.match(product,/\[data-live-test\]/);
  assert.match(product,/live\.selected\.testId = t\.dataset\.liveTest[\s\S]*api\.go\(t\.dataset\.route === 'test-upcoming' \? 'test-upcoming' : 'test'\)/);
});

test('Self Learners can create the same private Class code as other learning decision makers',()=>{
  const start=product.indexOf('function pageLearners()');
  const block=product.slice(start,start+2400);
  assert.match(block,/access_type === 'self' \? 'My learning' : 'Managed by you'/);
  assert.match(block,/data-live-share-learner/);
  assert.match(block,/access_type === 'manage'[\s\S]*Set up learner login[\s\S]*: ''}<button class="pill-btn small" data-live-share-learner/);
});

test('Teacher Activity review uses human UI and canonical review RPCs',()=>{
  assert.match(product,/function pageSubmissionReviewHuman\(\)/);
  assert.match(product,/route === 'submission-review'[\s\S]*pageSubmissionReviewHuman\(\)/);
  assert.match(product,/data-live-fix-request-submission-changes/);
  assert.match(product,/data-live-fix-review-submission/);
  assert.match(product,/request_submission_changes/);
  assert.match(product,/review_submission/);
  assert.match(product,/Add feedback so the learner knows what to change\./);
  assert.match(product,/get_activity_detail/);
});

test('Teacher Test review uses provider-safe projections and canonical evaluation/release RPCs',()=>{
  assert.match(product,/data-live-fix-test-review-section/);
  assert.match(product,/data-live-fix-open-test-attempt/);
  assert.match(product,/get_test_definition/);
  assert.match(product,/get_test_attempt/);
  assert.match(product,/function pageTeacherTestReview\(\)/);
  assert.match(product,/evaluate_test_attempt/);
  assert.match(product,/set_test_results_visibility/);
  assert.match(product,/Release result to learner/);
  assert.match(product,/route === 'test-results'[\s\S]*pageTeacherTestReview\(\)/);
});

test('Enquiry mutations immediately refetch the authoritative thread for the acting browser',()=>{
  assert.match(product,/data-live-engage-enquiry[\s\S]*engage_enquiry[\s\S]*refreshCurrentEnquiryThread\(\)[\s\S]*api\.render\(\)/);
  assert.match(product,/data-live-send-enquiry-message[\s\S]*send_enquiry_message[\s\S]*refreshCurrentEnquiryThread\(\)[\s\S]*api\.render\(\)/);
});

test('Duplicate active enquiry opens the existing relationship with human guidance',()=>{
  assert.match(product,/data-live-confirm-enquiry/);
  assert.match(product,/DUPLICATE_ACTIVE_ENQUIRY/);
  assert.match(product,/You already have an active enquiry here\. Opening it\./);
  assert.match(product,/teaching_option_id === teachingOptionId/);
  assert.match(product,/learner_id === learner\.learner_id/);
});

test('Draft Class management exposes a canonical activation path',()=>{
  assert.match(product,/data-live-fix-activate-class/);
  assert.match(product,/rpc\('activate_class'/);
  assert.match(product,/route === 'teacher-class'[\s\S]*state === 'draft'[\s\S]*Activate Class/);
  assert.match(product,/refreshCurrentClassManagement\(\)/);
});

test('Local Manager overview uses operational scope rather than a general browsing Location',()=>{
  assert.match(product,/managerOperationalLocationName/);
  assert.match(product,/manager_scopes/);
  assert.match(product,/manager-home'[\s\S]*managerOperationalLocationName\(\)/);
});

test('Authenticated shell exposes notifications without changing authority',()=>{
  assert.match(product,/data-live-fix-notifications-link/);
  assert.match(product,/href = '#\/notifications'/);
  assert.match(product,/get_my_notifications/);
});

test('Realtime publication is invalidation-only and excludes sensitive message payload tables',()=>{
  for(const table of [
    'notifications','teacher_profiles','teaching_options','teaching_option_locations',
    'organizations','learning_requests','community_posts','community_comments'
  ]) assert.match(migration,new RegExp("'"+table+"'"));
  assert.doesNotMatch(migration,/'enquiry_messages'|'class_learner_messages'|'test_attempt_answers'/);
  assert.match(migration,/PostgreSQL\/RPC projections remain authoritative/i);
});

test('product-fix bootstrap is injected before the async live bootstrap can paint setup forms',()=>{
  assert.match(buildSource,/const appAnchor='<div id="app"><\/div>'/);
  assert.match(buildSource,/indexHtml\.replace\(appAnchor,`\$\{appAnchor\}\\\\n<script src="\.\/live-product-fix-v13\.js"><\/script>`\)/);
  const releaseFix=releaseSource.indexOf('<script src="./live-product-fix-v13.js"></script>');
  const releaseLive=releaseSource.indexOf('<script src="./live.js"></script>');
  assert.ok(releaseFix>=0 && releaseLive>releaseFix,'release bootstrap must load product-fix before live.js');
  assert.match(product,/replayEarlySetupSubmit/);
  assert.match(product,/document\.getElementById\(formId\)/);
  assert.match(product,/new FormData\(form\)\.entries\(\)/);
  assert.match(product,/button\[type="submit"\],input\[type="submit"\]/);
  assert.match(product,/queueSetupFormSubmit\(form\)/);
  assert.match(product,/retries >= 200/);
  assert.match(product,/__productFixV13Ready/);
  assert.match(product,/api\.render\(\);[\s\S]*live\.__productFixV13Ready = true/);
  assert.match(product,/querySelector\('button\[type="submit"\],input\[type="submit"\]'\)/);
  assert.match(product,/submitter\.click\(\)/);
  assert.match(product,/current\.requestSubmit\(\)/);
});

test('pre-launch repairs add no direct browser table mutation or privileged secrets',()=>{
  assert.doesNotMatch(product,/\.from\s*\(/);
  assert.doesNotMatch(product,/\.insert\s*\(/);
  assert.doesNotMatch(product,/\.update\s*\(/);
  assert.doesNotMatch(product,/\.delete\s*\(/);
  assert.doesNotMatch(product,/service_role|sb_secret_|STARTMESSAGING_API_KEY/i);
});
