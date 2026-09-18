import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { chromium } from 'playwright';
import { createClient } from '@supabase/supabase-js';

const DEV_ORIGIN='https://dev.learning.myraahi.co.in';
const SUPABASE_URL='https://iiwwmqokaeflaenhlyip.supabase.co';
const PROJECT_REF='iiwwmqokaeflaenhlyip';
const PUBLISHABLE_KEY='sb_publishable_bz0YgDXY-WkKxZnogGsfUg_Qgl7E-Wi';
const EDGE_URL=SUPABASE_URL+'/functions/v1/dev-test-identities';
const OIDC_AUDIENCE='raahi-learning-dev-test-harness';
const DHANBAD_LOCATION_ID='028ee066-2130-45d6-8e17-6ceb9b0f1f80';
const ARTIFACT_DIR=path.resolve('artifacts-sidefx-test-correction');
const KEYS=['learner','teacher','unrelated'];

function assert(value,message){if(!value)throw new Error(message);}
function sleep(ms){return new Promise(resolve=>setTimeout(resolve,ms));}
function errText(error){return error?.message||error?.details||error?.hint||String(error);}
function password(){return crypto.randomBytes(30).toString('base64url')+'Aa1!';}
function runId(){return 'testcorrectionfx-'+(process.env.GITHUB_RUN_ID||Date.now())+'-'+(process.env.GITHUB_RUN_ATTEMPT||'1');}
function future(hours){return new Date(Date.now()+hours*3600000).toISOString();}
function staticCompatible(deployed,target){
  if(deployed===target)return {compatible:true,changed:[]};
  try{
    execFileSync('git',['merge-base','--is-ancestor',deployed,target],{stdio:'ignore'});
    const changed=execFileSync('git',['diff','--name-only',deployed+'..'+target],{encoding:'utf8'})
      .split(/\r?\n/).map(value=>value.trim()).filter(Boolean);
    const appChanges=changed.filter(file=>file.startsWith('apps/raahi-learning/'));
    return {compatible:appChanges.length===0,changed,appChanges};
  }catch(_){return {compatible:false,changed:[],appChanges:['unknown-history']};}
}
async function waitDeployment(sha){
  const deadline=Date.now()+8*60*1000;let last=null;
  while(Date.now()<deadline){
    try{
      const response=await fetch(DEV_ORIGIN+'/build-meta.json?testcorrectionfx='+Date.now(),{cache:'no-store'});
      if(response.ok){
        last=await response.json();
        const compatibility=staticCompatible(last.commit_sha,sha);
        if(compatibility.compatible)return {...last,compatibility};
      }
    }catch(error){last={error:String(error)};}
    await sleep(10000);
  }
  throw new Error('DEV_STATIC_DEPLOYMENT_NOT_COMPATIBLE expected='+sha+' last='+JSON.stringify(last));
}
async function endDeploymentCheck(startMeta,sha){
  const response=await fetch(DEV_ORIGIN+'/build-meta.json?testcorrectionfx-end='+Date.now(),{cache:'no-store'});
  assert(response.ok,'DEV_DEPLOYMENT_END_CHECK_FAILED_'+response.status);
  const meta=await response.json();
  assert(meta.commit_sha===startMeta.commit_sha,'DEV_DEPLOYMENT_CHANGED_DURING_TEST_CORRECTION_PROOF start='+startMeta.commit_sha+' actual='+meta.commit_sha);
  const compatibility=staticCompatible(meta.commit_sha,sha);
  assert(compatibility.compatible,'DEV_STATIC_DEPLOYMENT_END_NOT_COMPATIBLE '+JSON.stringify(compatibility));
  return {...meta,compatibility};
}
async function oidc(){
  const requestUrl=process.env.ACTIONS_ID_TOKEN_REQUEST_URL;
  const requestToken=process.env.ACTIONS_ID_TOKEN_REQUEST_TOKEN;
  assert(requestUrl&&requestToken,'GITHUB_OIDC_ENV_MISSING');
  const url=new URL(requestUrl);url.searchParams.set('audience',OIDC_AUDIENCE);
  const response=await fetch(url,{headers:{authorization:'Bearer '+requestToken}});
  if(!response.ok)throw new Error('GITHUB_OIDC_REQUEST_FAILED_'+response.status);
  const body=await response.json();assert(body.value,'GITHUB_OIDC_TOKEN_MISSING');return body.value;
}
async function edge(token,payload){
  const response=await fetch(EDGE_URL,{method:'POST',headers:{authorization:'Bearer '+token,'content-type':'application/json'},body:JSON.stringify(payload)});
  const body=await response.json().catch(()=>({ok:false,error:'INVALID_JSON'}));
  if(!response.ok||!body.ok)throw new Error('IDENTITY_FACTORY_FAILED '+(body.error||response.status));
  return body;
}
function client(){return createClient(SUPABASE_URL,PUBLISHABLE_KEY,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});}
async function rpc(supabase,name,args={}){const {data,error}=await supabase.rpc(name,args);if(error)throw error;return data;}
async function bootstrap(supabase,name){
  try{return await rpc(supabase,'get_my_account_context');}
  catch(error){
    if(!/ACCOUNT_NOT_FOUND/i.test(errText(error)))throw error;
    await rpc(supabase,'bootstrap_account',{p_display_name:name});
    return rpc(supabase,'get_my_account_context');
  }
}
async function notifications(supabase){const rows=await rpc(supabase,'get_my_notifications',{p_limit:200});return Array.isArray(rows)?rows:[];}
function correctionSignals(rows,testId){return rows.filter(row=>row.notification_type==='test_results_corrected'&&row.source_id===testId&&row.payload?.test_id===testId);}
async function pollCorrections(supabase,testId,label){
  const deadline=Date.now()+30000;let signals=[];
  while(Date.now()<deadline){signals=correctionSignals(await notifications(supabase),testId);if(signals.length)return signals;await sleep(500);}
  throw new Error(label+'_NOT_FOUND');
}
async function authBrowser(browser,email,secret){
  const context=await browser.newContext({viewport:{width:1280,height:900}});
  const page=await context.newPage();
  await page.goto(DEV_ORIGIN+'/dev-test-login-v13.html',{waitUntil:'domcontentloaded'});
  await page.getByText('RAAHI_DEV_TEST_LOGIN_V13').waitFor({timeout:30000});
  await page.locator('#email').fill(email);await page.locator('#password').fill(secret);await page.locator('#signin').click();
  await page.waitForURL(url=>url.origin===DEV_ORIGIN&&url.hash==='#/home',{timeout:30000});
  await page.waitForTimeout(900);
  return {context,page};
}
async function chooseRole(page,role){
  const select=page.locator('[data-live-role-select]').first();
  if(!(await select.count()))return;
  const values=await select.locator('option').evaluateAll(options=>options.map(option=>option.value));
  if(!values.includes(role))return;
  await select.selectOption(role);await page.waitForTimeout(800);
}

async function makeEvaluatedTest({teacher,learner,learnerId,classId,run,suffix}){
  const title='Test correction '+suffix+' '+run;
  const prompt='Private question '+suffix+' '+run;
  const originalText='Private original answer '+suffix+' '+run;
  const correctedText='Private corrected answer '+suffix+' '+run;
  const test=await rpc(teacher.client,'create_test',{
    p_class_id:classId,p_title:title,p_instructions:'Authorized Test correction proof',p_available_from:null,
    p_closes_at:future(72),p_duration_seconds:3600,p_idempotency_key:run+'-'+suffix+'-test'
  });
  const question=await rpc(teacher.client,'add_test_question',{
    p_test_id:test.test_id,p_position:1,p_prompt:prompt,p_points:10,p_idempotency_key:run+'-'+suffix+'-question'
  });
  const original=await rpc(teacher.client,'add_test_choice',{
    p_question_id:question.question_id,p_position:1,p_choice_text:originalText,p_is_correct:true,p_idempotency_key:run+'-'+suffix+'-choice-original'
  });
  const corrected=await rpc(teacher.client,'add_test_choice',{
    p_question_id:question.question_id,p_position:2,p_choice_text:correctedText,p_is_correct:false,p_idempotency_key:run+'-'+suffix+'-choice-corrected'
  });
  await rpc(teacher.client,'publish_test',{p_test_id:test.test_id,p_idempotency_key:run+'-'+suffix+'-publish'});
  const attempt=await rpc(learner.client,'start_test',{
    p_test_id:test.test_id,p_learner_id:learnerId,p_idempotency_key:run+'-'+suffix+'-start'
  });
  await rpc(learner.client,'save_test_answer',{
    p_attempt_id:attempt.attempt_id,p_question_id:question.question_id,p_selected_choice_id:original.choice_id,
    p_text_response:null,p_idempotency_key:run+'-'+suffix+'-answer'
  });
  await rpc(learner.client,'submit_test',{p_attempt_id:attempt.attempt_id,p_idempotency_key:run+'-'+suffix+'-submit'});
  const evaluation=await rpc(teacher.client,'evaluate_test_attempt',{
    p_attempt_id:attempt.attempt_id,p_teacher_feedback:'Private teacher feedback '+suffix+' '+run,
    p_idempotency_key:run+'-'+suffix+'-evaluate'
  });
  assert(Number(evaluation.score)===10,'INITIAL_TEST_SCORE_NOT_TEN_'+suffix+'_'+evaluation.score);
  return {
    title,prompt,originalText,correctedText,test_id:test.test_id,question_id:question.question_id,
    original_choice_id:original.choice_id,corrected_choice_id:corrected.choice_id,attempt_id:attempt.attempt_id
  };
}

async function main(){
  assert(new URL(SUPABASE_URL).hostname.split('.')[0]===PROJECT_REF,'PROJECT_GUARD');
  assert(process.env.GITHUB_REF==='refs/heads/raahi-learning-implementation-v1','BRANCH_GUARD');
  fs.mkdirSync(ARTIFACT_DIR,{recursive:true});
  const run=runId(),sha=process.env.GITHUB_SHA||'unknown';
  const report={proof:'test-correction-side-effects-v1',run_id:run,commit_sha:sha,deployment:null,checks:[],ids:{},result:'running'};
  const sessions={};

  try{
    report.deployment=await waitDeployment(sha);
    const token=await oidc();
    const passwords=Object.fromEntries(KEYS.map(key=>[key,password()]));
    const ensured=await edge(token,{action:'ensure_personas',suite:'sidefx_test',run_id:run,passwords});
    const specs=Object.fromEntries(ensured.personas.map(persona=>[persona.key,persona]));
    const names={learner:'Test SideFX E2E Learner',teacher:'Test SideFX E2E Teacher',unrelated:'Test SideFX E2E Unrelated'};
    for(const key of KEYS){
      const supabase=client();
      const {error}=await supabase.auth.signInWithPassword({email:specs[key].email,password:passwords[key]});
      if(error)throw error;
      const accountContext=await bootstrap(supabase,names[key]);
      sessions[key]={client:supabase,spec:specs[key],password:passwords[key],account_id:accountContext.account.account_id,context:accountContext};
    }
    const {learner,teacher,unrelated}=sessions;

    await rpc(teacher.client,'enable_teaching',{p_idempotency_key:run+'-enable'});
    await rpc(teacher.client,'upsert_teacher_profile',{
      p_headline:'Test correction Mathematics teacher',p_bio:'DEV Test correction proof',p_experience_summary:'Automated proof',
      p_visibility_status:'visible',p_idempotency_key:run+'-profile'
    });
    const option=await rpc(teacher.client,'publish_teaching_option',{
      p_organization_id:null,p_title:'Test correction Mathematics '+run,p_category:'Mathematics',p_description:'DEV Test correction proof',
      p_teaching_mode:'both',p_area_or_venue_text:'Dhanbad',p_fee_display_text:'DEV proof — no payment collected',
      p_location_ids:[DHANBAD_LOCATION_ID],p_idempotency_key:run+'-option'
    });
    let learnerContext=await rpc(learner.client,'get_my_account_context');
    let self=learnerContext.learners?.find(item=>item.access_type==='self');
    if(!self){
      await rpc(learner.client,'create_learner',{
        p_display_name:'Test correction Learner Profile',p_access_type:'self',p_avatar_type:'none',p_avatar_ref:null,
        p_idempotency_key:run+'-self'
      });
      learnerContext=await rpc(learner.client,'get_my_account_context');
      self=learnerContext.learners?.find(item=>item.access_type==='self');
    }
    assert(self?.learner_id,'SELF_LEARNER_MISSING');

    const enquiry=await rpc(learner.client,'send_enquiry',{
      p_learner_id:self.learner_id,p_teaching_option_id:option.teaching_option_id,p_location_id:DHANBAD_LOCATION_ID,
      p_opening_message:null,p_idempotency_key:run+'-enquiry'
    });
    await rpc(teacher.client,'engage_enquiry',{p_enquiry_id:enquiry.enquiry_id,p_idempotency_key:run+'-engage'});
    const cls=await rpc(teacher.client,'create_class',{
      p_organization_id:null,p_responsible_teacher_account_id:teacher.account_id,p_location_id:DHANBAD_LOCATION_ID,
      p_title:'Test correction SideFX Class '+run,p_class_type:'one_to_one',p_capacity:1,p_idempotency_key:run+'-class'
    });
    await rpc(teacher.client,'activate_class',{p_class_id:cls.class_id,p_idempotency_key:run+'-activate'});
    const invitation=await rpc(teacher.client,'send_class_invitation',{
      p_class_id:cls.class_id,p_enquiry_id:enquiry.enquiry_id,p_fee_display_text:'DEV proof — no payment collected',
      p_idempotency_key:run+'-invite'
    });
    const membership=await rpc(learner.client,'accept_class_invitation',{
      p_invitation_id:invitation.invitation_id,p_idempotency_key:run+'-accept'
    });
    report.ids={learner_id:self.learner_id,class_id:cls.class_id,membership_id:membership.membership_id};

    const visible=await makeEvaluatedTest({teacher,learner,learnerId:self.learner_id,classId:cls.class_id,run,suffix:'visible'});
    report.ids.visible_test_id=visible.test_id;report.ids.visible_question_id=visible.question_id;report.ids.visible_attempt_id=visible.attempt_id;
    await rpc(teacher.client,'set_test_results_visibility',{
      p_test_id:visible.test_id,p_visible:true,p_idempotency_key:run+'-visible-release'
    });
    const visibleBaseline=correctionSignals(await notifications(learner.client),visible.test_id).length;
    assert(visibleBaseline===0,'VISIBLE_CORRECTION_BASELINE_NOT_ZERO_'+visibleBaseline);
    const visibleReason='Private visible correction reason '+run;
    const visibleKey=run+'-visible-correct';
    const firstCorrection=await rpc(teacher.client,'correct_answer_key',{
      p_question_id:visible.question_id,p_correct_choice_id:visible.corrected_choice_id,p_reason:visibleReason,p_idempotency_key:visibleKey
    });
    assert(Number(firstCorrection.recalculated_attempts)===1,'VISIBLE_RECALCULATION_COUNT_'+firstCorrection.recalculated_attempts);
    let visibleSignals=await pollCorrections(learner.client,visible.test_id,'VISIBLE_TEST_CORRECTION');
    assert(visibleSignals.length===1,'VISIBLE_CORRECTION_SIGNAL_COUNT_'+visibleSignals.length);
    const signal=visibleSignals[0];
    assert(signal.title==='Test results updated','VISIBLE_CORRECTION_TITLE_'+signal.title);
    assert(signal.body==='Results for a completed Test were updated after a correction.','VISIBLE_CORRECTION_BODY_'+signal.body);
    assert(signal.source_type==='test'&&signal.source_id===visible.test_id,'VISIBLE_CORRECTION_SOURCE_MISMATCH');
    assert(signal.payload?.test_id===visible.test_id&&signal.payload?.class_id===cls.class_id,'VISIBLE_CORRECTION_PAYLOAD_IDS_MISMATCH');
    assert(Object.keys(signal.payload||{}).sort().join(',')==='class_id,test_id','VISIBLE_CORRECTION_PAYLOAD_HAS_EXTRA_FIELDS_'+Object.keys(signal.payload||{}).sort().join(','));
    const serializedSignal=JSON.stringify(signal);
    for(const forbidden of [visible.prompt,visible.originalText,visible.correctedText,visibleReason,visible.original_choice_id,visible.corrected_choice_id,'"score"']){
      assert(!serializedSignal.includes(forbidden),'VISIBLE_CORRECTION_NOTIFICATION_LEAK_'+forbidden);
    }
    await rpc(teacher.client,'correct_answer_key',{
      p_question_id:visible.question_id,p_correct_choice_id:visible.corrected_choice_id,p_reason:visibleReason,p_idempotency_key:visibleKey
    });
    visibleSignals=correctionSignals(await notifications(learner.client),visible.test_id);
    assert(visibleSignals.length===1,'VISIBLE_CORRECTION_RETRY_DUPLICATE_'+visibleSignals.length);
    const visibleAttempt=await rpc(learner.client,'get_test_attempt',{p_test_id:visible.test_id,p_learner_id:self.learner_id});
    assert(visibleAttempt?.state==='evaluated'&&Number(visibleAttempt.score)===0,'VISIBLE_CORRECTED_SCORE_NOT_AUTHORIZED_ZERO');
    report.checks.push({check:'visible_results_correction_notifies_once_generically_and_retry_is_idempotent',pass:true});

    const hidden=await makeEvaluatedTest({teacher,learner,learnerId:self.learner_id,classId:cls.class_id,run,suffix:'hidden'});
    report.ids.hidden_test_id=hidden.test_id;report.ids.hidden_question_id=hidden.question_id;report.ids.hidden_attempt_id=hidden.attempt_id;
    const hiddenReason='Private hidden correction reason '+run;
    const hiddenKey=run+'-hidden-correct';
    const hiddenCorrection=await rpc(teacher.client,'correct_answer_key',{
      p_question_id:hidden.question_id,p_correct_choice_id:hidden.corrected_choice_id,p_reason:hiddenReason,p_idempotency_key:hiddenKey
    });
    assert(Number(hiddenCorrection.recalculated_attempts)===1,'HIDDEN_RECALCULATION_COUNT_'+hiddenCorrection.recalculated_attempts);
    await sleep(1500);
    let hiddenSignals=correctionSignals(await notifications(learner.client),hidden.test_id);
    assert(hiddenSignals.length===0,'HIDDEN_CORRECTION_SIGNAL_COUNT_'+hiddenSignals.length);
    await rpc(teacher.client,'correct_answer_key',{
      p_question_id:hidden.question_id,p_correct_choice_id:hidden.corrected_choice_id,p_reason:hiddenReason,p_idempotency_key:hiddenKey
    });
    hiddenSignals=correctionSignals(await notifications(learner.client),hidden.test_id);
    assert(hiddenSignals.length===0,'HIDDEN_CORRECTION_RETRY_SIGNAL_COUNT_'+hiddenSignals.length);
    const hiddenAttempt=await rpc(learner.client,'get_test_attempt',{p_test_id:hidden.test_id,p_learner_id:self.learner_id});
    assert(hiddenAttempt?.state==='evaluated'&&hiddenAttempt.score===null,'HIDDEN_RESULTS_LEAKED_SCORE');
    report.checks.push({check:'hidden_results_correction_writes_no_notification_and_retry_is_idempotent',pass:true});

    const audit=await edge(token,{
      action:'inspect_test_correction_audit',suite:'sidefx_test',run_id:run,question_ids:[visible.question_id,hidden.question_id]
    });
    const audits=audit.audit_rows||[];
    for(const testCase of [visible,hidden]){
      const rows=audits.filter(row=>row.target_id===testCase.question_id);
      assert(rows.length===1,'TEST_CORRECTION_AUDIT_COUNT_'+testCase.question_id+'_'+rows.length);
      assert(rows[0].actor_account_id===teacher.account_id,'TEST_CORRECTION_AUDIT_ACTOR_MISMATCH_'+testCase.question_id);
      assert(rows[0].metadata?.test_id===testCase.test_id,'TEST_CORRECTION_AUDIT_TEST_MISMATCH_'+testCase.question_id);
      assert(Number(rows[0].metadata?.recalculated_attempts)===1,'TEST_CORRECTION_AUDIT_RECALCULATION_MISMATCH_'+testCase.question_id);
    }
    report.audit_rows=audits;
    report.checks.push({check:'one_audit_row_per_correction_preserves_teacher_actor_and_recalculation_history',pass:true});

    const browser=await chromium.launch({headless:true});
    try{
      const signedIn=await authBrowser(browser,learner.spec.email,learner.password);
      await chooseRole(signedIn.page,'learner');
      await signedIn.page.goto(DEV_ORIGIN+'/#/notifications',{waitUntil:'domcontentloaded'});
      const card=signedIn.page.locator('.card').filter({hasText:'Test results updated'}).first();
      await card.getByRole('button',{name:'Open'}).click();
      await signedIn.page.waitForURL(url=>url.origin===DEV_ORIGIN&&url.hash==='#/test-results',{timeout:15000});
      await signedIn.page.getByText(visible.title,{exact:true}).waitFor({timeout:15000});
      await signedIn.page.screenshot({path:path.join(ARTIFACT_DIR,'learner-test-correction-open.png'),fullPage:true});
      await signedIn.context.close();
    }finally{await browser.close();}
    report.checks.push({check:'learner_actual_notification_open_rechecks_and_loads_authorized_test_results',pass:true});

    const unrelatedDefinition=await rpc(unrelated.client,'get_test_definition',{p_test_id:visible.test_id,p_learner_id:self.learner_id});
    const unrelatedAttempt=await rpc(unrelated.client,'get_test_attempt',{p_test_id:visible.test_id,p_learner_id:self.learner_id});
    const unrelatedOversight=await rpc(unrelated.client,'get_test_oversight',{p_test_id:visible.test_id,p_learner_id:self.learner_id});
    assert(unrelatedDefinition===null,'UNRELATED_TEST_DEFINITION_NOT_DENIED');
    assert(unrelatedAttempt===null,'UNRELATED_TEST_ATTEMPT_NOT_DENIED');
    assert(unrelatedOversight===null,'UNRELATED_TEST_OVERSIGHT_NOT_DENIED');
    const unrelatedSignals=(await notifications(unrelated.client)).filter(row=>[visible.test_id,hidden.test_id].includes(row.source_id));
    assert(unrelatedSignals.length===0,'UNRELATED_RECEIVED_TEST_CORRECTION_SIGNAL');
    report.checks.push({check:'unrelated_account_receives_no_signal_and_all_test_projections_are_denied',pass:true});

    report.end_deployment=await endDeploymentCheck(report.deployment,sha);
    report.result='pass';
    fs.writeFileSync(path.join(ARTIFACT_DIR,'test-correction-side-effects-proof.json'),JSON.stringify(report,null,2));
    console.log('RAAHI_TEST_CORRECTION_SIDE_EFFECTS_PASS run_id='+run+' commit='+sha);
  }catch(error){
    report.result='fail';report.failure={message:errText(error),class:'to-classify'};
    fs.writeFileSync(path.join(ARTIFACT_DIR,'test-correction-side-effects-proof.json'),JSON.stringify(report,null,2));
    throw error;
  }finally{
    for(const session of Object.values(sessions)){try{await session.client.auth.signOut();}catch(_){}}
  }
}

await main();
