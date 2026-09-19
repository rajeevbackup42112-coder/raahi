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
const ARTIFACT_DIR=path.resolve('artifacts-sidefx-activity');
const KEYS=['learner','teacher','unrelated'];

function assert(v,m){if(!v)throw new Error(m);}
function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
function errText(e){return e?.message||e?.details||e?.hint||String(e);}
function pwd(){return crypto.randomBytes(30).toString('base64url')+'Aa1!';}
function rid(){return 'activityfx-'+(process.env.GITHUB_RUN_ID||Date.now())+'-'+(process.env.GITHUB_RUN_ATTEMPT||'1');}
function future(hours){return new Date(Date.now()+hours*3600000).toISOString();}
function staticCompatible(deployed,target){
  if(deployed===target)return {compatible:true,exact:true,changed:[],appChanges:[]};
  try{
    const changed=execFileSync('git',['diff','--name-only',deployed,target],{encoding:'utf8'})
      .split(/\r?\n/).map(x=>x.trim()).filter(Boolean);
    const appChanges=changed.filter(p=>p.startsWith('apps/raahi-learning/'));
    return {compatible:appChanges.length===0,exact:false,changed,appChanges};
  }catch(_){return {compatible:false,exact:false,changed:[],appChanges:['unknown-history']};}
}
async function waitDeployment(sha){
  const deadline=Date.now()+8*60*1000;let last=null;
  while(Date.now()<deadline){
    try{
      const r=await fetch(DEV_ORIGIN+'/build-meta.json?activityfx='+Date.now(),{cache:'no-store'});
      if(r.ok){last=await r.json();const compat=staticCompatible(last.commit_sha,sha);if(compat.compatible)return {...last,compatibility:compat};}
    }catch(e){last={error:String(e)}}
    await sleep(10000);
  }
  throw new Error('DEV_STATIC_DEPLOYMENT_NOT_COMPATIBLE expected='+sha+' last='+JSON.stringify(last));
}
async function endDeploymentCheck(startMeta,sha){
  const r=await fetch(DEV_ORIGIN+'/build-meta.json?activityfx-end='+Date.now(),{cache:'no-store'});
  assert(r.ok,'DEV_DEPLOYMENT_END_CHECK_FAILED_'+r.status);
  const m=await r.json();
  const compat=staticCompatible(m.commit_sha,sha);
  assert(compat.compatible,'DEV_STATIC_DEPLOYMENT_END_NOT_COMPATIBLE '+JSON.stringify(compat));
  return {...m,compatibility:compat};
}
async function oidc(){
  const u0=process.env.ACTIONS_ID_TOKEN_REQUEST_URL,t=process.env.ACTIONS_ID_TOKEN_REQUEST_TOKEN;
  assert(u0&&t,'GITHUB_OIDC_ENV_MISSING');
  const u=new URL(u0);u.searchParams.set('audience',OIDC_AUDIENCE);
  const r=await fetch(u,{headers:{authorization:'Bearer '+t}});
  if(!r.ok)throw new Error('GITHUB_OIDC_REQUEST_FAILED_'+r.status);
  const b=await r.json();assert(b.value,'GITHUB_OIDC_TOKEN_MISSING');return b.value;
}
async function edge(token,payload){
  const r=await fetch(EDGE_URL,{method:'POST',headers:{authorization:'Bearer '+token,'content-type':'application/json'},body:JSON.stringify(payload)});
  const b=await r.json().catch(()=>({ok:false,error:'INVALID_JSON'}));
  if(!r.ok||!b.ok)throw new Error('IDENTITY_FACTORY_FAILED '+(b.error||r.status));
  return b;
}
function client(){return createClient(SUPABASE_URL,PUBLISHABLE_KEY,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});}
async function rpc(c,n,a={}){const {data,error}=await c.rpc(n,a);if(error)throw error;return data;}
async function boot(c,name){
  try{return await rpc(c,'get_my_account_context');}
  catch(e){if(!/ACCOUNT_NOT_FOUND/i.test(errText(e)))throw e;await rpc(c,'bootstrap_account',{p_display_name:name});return rpc(c,'get_my_account_context');}
}
async function notifications(c){const x=await rpc(c,'get_my_notifications',{p_limit:200});return Array.isArray(x)?x:[];}
function matching(xs,type,pred=()=>true){return xs.filter(x=>x.notification_type===type&&pred(x));}
async function poll(c,type,pred,label){
  const deadline=Date.now()+30000;let xs=[];
  while(Date.now()<deadline){xs=matching(await notifications(c),type,pred);if(xs.length)return xs;await sleep(500);}
  throw new Error(label+'_NOT_FOUND');
}
async function authBrowser(browser,email,password){
  const ctx=await browser.newContext({viewport:{width:1280,height:900}});
  const page=await ctx.newPage();
  await page.goto(DEV_ORIGIN+'/dev-test-login-v13.html',{waitUntil:'domcontentloaded'});
  await page.getByText('RAAHI_DEV_TEST_LOGIN_V13').waitFor({timeout:30000});
  await page.locator('#email').fill(email);await page.locator('#password').fill(password);await page.locator('#signin').click();
  await page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/home',{timeout:30000});
  await page.waitForTimeout(900);
  return {ctx,page};
}
async function chooseRole(page,role){
  const s=page.locator('[data-live-role-select]').first();
  if(!(await s.count()))return;
  const values=await s.locator('option').evaluateAll(xs=>xs.map(x=>x.value));
  if(!values.includes(role))return;
  await s.selectOption(role);await page.waitForTimeout(800);
}

async function main(){
  assert(new URL(SUPABASE_URL).hostname.split('.')[0]===PROJECT_REF,'PROJECT_GUARD');
  assert(process.env.GITHUB_REF==='refs/heads/raahi-learning-implementation-v1','BRANCH_GUARD');
  fs.mkdirSync(ARTIFACT_DIR,{recursive:true});
  const run=rid(),sha=process.env.GITHUB_SHA||'unknown';
  const report={proof:'activity-submission-side-effects-v1',run_id:run,commit_sha:sha,deployment:null,checks:[],ids:{},result:'running'};
  const sessions={};

  try{
    report.deployment=await waitDeployment(sha);
    const token=await oidc();
    const passwords=Object.fromEntries(KEYS.map(k=>[k,pwd()]));
    const ensured=await edge(token,{action:'ensure_personas',suite:'sidefx_activity',run_id:run,passwords});
    const specs=Object.fromEntries(ensured.personas.map(x=>[x.key,x]));
    const names={learner:'Activity E2E Learner',teacher:'Activity E2E Teacher',unrelated:'Activity E2E Unrelated'};
    for(const key of KEYS){
      const c=client();const {data,error}=await c.auth.signInWithPassword({email:specs[key].email,password:passwords[key]});if(error)throw error;
      const context=await boot(c,names[key]);
      sessions[key]={client:c,spec:specs[key],password:passwords[key],account_id:context.account.account_id,context};
    }
    const {learner,teacher,unrelated}=sessions;

    await rpc(teacher.client,'enable_teaching',{p_idempotency_key:run+'-enable'});
    await rpc(teacher.client,'upsert_teacher_profile',{
      p_headline:'Activity Mathematics teacher',p_bio:'DEV Activity proof',p_experience_summary:'Automated proof',
      p_visibility_status:'visible',p_idempotency_key:run+'-profile'
    });
    const option=await rpc(teacher.client,'publish_teaching_option',{
      p_organization_id:null,p_title:'Activity Mathematics '+run,p_category:'Mathematics',p_description:'DEV Activity proof',
      p_teaching_mode:'both',p_area_or_venue_text:'Dhanbad',p_fee_display_text:'DEV proof — no payment collected',
      p_location_ids:[DHANBAD_LOCATION_ID],p_idempotency_key:run+'-option'
    });
    let lctx=await rpc(learner.client,'get_my_account_context');
    let self=lctx.learners?.find(x=>x.access_type==='self');
    if(!self){
      await rpc(learner.client,'create_learner',{p_display_name:'Activity Learner Profile',p_access_type:'self',p_avatar_type:'none',p_avatar_ref:null,p_idempotency_key:run+'-self'});
      lctx=await rpc(learner.client,'get_my_account_context');self=lctx.learners?.find(x=>x.access_type==='self');
    }
    assert(self?.learner_id,'SELF_LEARNER_MISSING');

    const enquiry=await rpc(learner.client,'send_enquiry',{
      p_learner_id:self.learner_id,p_teaching_option_id:option.teaching_option_id,p_location_id:DHANBAD_LOCATION_ID,p_opening_message:null,p_idempotency_key:run+'-enquiry'
    });
    await rpc(teacher.client,'engage_enquiry',{p_enquiry_id:enquiry.enquiry_id,p_idempotency_key:run+'-engage'});
    const classTitle='Activity SideFX Class '+run;
    const cls=await rpc(teacher.client,'create_class',{
      p_organization_id:null,p_responsible_teacher_account_id:teacher.account_id,p_location_id:DHANBAD_LOCATION_ID,
      p_title:classTitle,p_class_type:'one_to_one',p_capacity:1,p_idempotency_key:run+'-class'
    });
    await rpc(teacher.client,'activate_class',{p_class_id:cls.class_id,p_idempotency_key:run+'-activate'});
    const inv=await rpc(teacher.client,'send_class_invitation',{
      p_class_id:cls.class_id,p_enquiry_id:enquiry.enquiry_id,p_fee_display_text:'DEV proof — no payment collected',p_idempotency_key:run+'-invite'
    });
    const membership=await rpc(learner.client,'accept_class_invitation',{p_invitation_id:inv.invitation_id,p_idempotency_key:run+'-accept'});

    const activityTitle='Activity SideFX Assignment '+run;
    const activity=await rpc(teacher.client,'create_activity',{
      p_class_id:cls.class_id,p_display_type:'assignment',p_title:activityTitle,p_instructions:'Authorized Activity proof',
      p_due_at:future(72),p_submission_required:true,p_idempotency_key:run+'-activity'
    });
    await rpc(teacher.client,'publish_activity',{p_activity_id:activity.activity_id,p_idempotency_key:run+'-publish'});
    report.ids={learner_id:self.learner_id,class_id:cls.class_id,membership_id:membership.membership_id,activity_id:activity.activity_id};

    const response1='Private learner response one '+run;
    const submitKey=run+'-submit-1';
    const first=await rpc(learner.client,'submit_activity',{
      p_activity_id:activity.activity_id,p_learner_id:self.learner_id,p_text_response:response1,p_file_asset_id:null,p_idempotency_key:submitKey
    });
    report.ids.submission_id=first.submission_id;report.ids.revision_1=first.revision_id;
    let providerSignals=await poll(teacher.client,'activity_submission_received',n=>n.source_id===first.revision_id,'ACTIVITY_SUBMISSION_RECEIVED');
    assert(providerSignals.length===1,'ACTIVITY_SUBMISSION_SIGNAL_COUNT_'+providerSignals.length);
    assert(!JSON.stringify(providerSignals[0]).includes(response1),'ACTIVITY_SUBMISSION_NOTIFICATION_LEAKED_RESPONSE');
    await rpc(learner.client,'submit_activity',{
      p_activity_id:activity.activity_id,p_learner_id:self.learner_id,p_text_response:response1,p_file_asset_id:null,p_idempotency_key:submitKey
    });
    providerSignals=matching(await notifications(teacher.client),'activity_submission_received',n=>n.source_id===first.revision_id);
    assert(providerSignals.length===1,'ACTIVITY_SUBMISSION_RETRY_DUPLICATE_'+providerSignals.length);
    report.checks.push({check:'initial_submission_notifies_provider_once_without_response',pass:true});

    const browser=await chromium.launch({headless:true});
    try{
      const tb=await authBrowser(browser,teacher.spec.email,teacher.password);
      await chooseRole(tb.page,'teacher');
      await tb.page.goto(DEV_ORIGIN+'/#/notifications',{waitUntil:'domcontentloaded'});
      const card=tb.page.locator('.card').filter({hasText:'Activity submission received'}).first();
      await card.getByRole('button',{name:'Open'}).click();
      await tb.page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/submission-review',{timeout:15000});
      await tb.page.getByText('Submission feedback',{exact:true}).waitFor({timeout:15000});
      await tb.page.screenshot({path:path.join(ARTIFACT_DIR,'provider-submission-review-open.png'),fullPage:true});
      await tb.ctx.close();
    }finally{await browser.close();}
    report.checks.push({check:'provider_submission_notification_opens_authorized_submission_context',pass:true});

    const feedback1='Private change feedback '+run;
    const changeKey=run+'-changes';
    await rpc(teacher.client,'request_submission_changes',{
      p_submission_id:first.submission_id,p_teacher_feedback:feedback1,p_idempotency_key:changeKey
    });
    let changeSignals=await poll(learner.client,'activity_submission_changes_requested',n=>n.source_id===first.revision_id,'ACTIVITY_CHANGES_REQUESTED');
    assert(changeSignals.length===1,'ACTIVITY_CHANGES_SIGNAL_COUNT_'+changeSignals.length);
    assert(!JSON.stringify(changeSignals[0]).includes(feedback1),'ACTIVITY_CHANGES_NOTIFICATION_LEAKED_FEEDBACK');
    await rpc(teacher.client,'request_submission_changes',{
      p_submission_id:first.submission_id,p_teacher_feedback:feedback1,p_idempotency_key:changeKey
    });
    changeSignals=matching(await notifications(learner.client),'activity_submission_changes_requested',n=>n.source_id===first.revision_id);
    assert(changeSignals.length===1,'ACTIVITY_CHANGES_RETRY_DUPLICATE_'+changeSignals.length);
    report.checks.push({check:'changes_requested_notifies_learner_once_without_feedback',pass:true});

    const browser2=await chromium.launch({headless:true});
    try{
      const lb=await authBrowser(browser2,learner.spec.email,learner.password);
      await chooseRole(lb.page,'learner');
      await lb.page.goto(DEV_ORIGIN+'/#/notifications',{waitUntil:'domcontentloaded'});
      const card=lb.page.locator('.card').filter({hasText:'Activity changes requested'}).first();
      await card.getByRole('button',{name:'Open'}).click();
      await lb.page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/activity',{timeout:15000});
      await lb.page.getByText(activityTitle,{exact:true}).waitFor({timeout:15000});
      await lb.page.screenshot({path:path.join(ARTIFACT_DIR,'learner-changes-requested-open.png'),fullPage:true});
      await lb.ctx.close();
    }finally{await browser2.close();}

    const response2='Private learner response two '+run;
    const resubmitKey=run+'-submit-2';
    const second=await rpc(learner.client,'submit_activity',{
      p_activity_id:activity.activity_id,p_learner_id:self.learner_id,p_text_response:response2,p_file_asset_id:null,p_idempotency_key:resubmitKey
    });
    assert(second.submission_id===first.submission_id,'RESUBMIT_CHANGED_SUBMISSION_ID');
    assert(second.revision_number===2,'RESUBMIT_REVISION_NUMBER_'+second.revision_number);
    report.ids.revision_2=second.revision_id;
    let resubmitSignals=await poll(teacher.client,'activity_submission_received',n=>n.source_id===second.revision_id,'ACTIVITY_RESUBMITTED');
    assert(resubmitSignals.length===1,'ACTIVITY_RESUBMIT_SIGNAL_COUNT_'+resubmitSignals.length);
    assert(!JSON.stringify(resubmitSignals[0]).includes(response2),'ACTIVITY_RESUBMIT_NOTIFICATION_LEAKED_RESPONSE');
    await rpc(learner.client,'submit_activity',{
      p_activity_id:activity.activity_id,p_learner_id:self.learner_id,p_text_response:response2,p_file_asset_id:null,p_idempotency_key:resubmitKey
    });
    resubmitSignals=matching(await notifications(teacher.client),'activity_submission_received',n=>n.source_id===second.revision_id);
    assert(resubmitSignals.length===1,'ACTIVITY_RESUBMIT_RETRY_DUPLICATE_'+resubmitSignals.length);
    report.checks.push({check:'resubmission_notifies_provider_once_without_response',pass:true});

    const feedback2='Private final review feedback '+run;
    const reviewKey=run+'-review';
    await rpc(teacher.client,'review_submission',{
      p_submission_id:first.submission_id,p_teacher_feedback:feedback2,p_idempotency_key:reviewKey
    });
    let reviewedSignals=await poll(learner.client,'activity_submission_reviewed',n=>n.source_id===second.revision_id,'ACTIVITY_REVIEWED');
    assert(reviewedSignals.length===1,'ACTIVITY_REVIEWED_SIGNAL_COUNT_'+reviewedSignals.length);
    assert(!JSON.stringify(reviewedSignals[0]).includes(feedback2),'ACTIVITY_REVIEW_NOTIFICATION_LEAKED_FEEDBACK');
    await rpc(teacher.client,'review_submission',{
      p_submission_id:first.submission_id,p_teacher_feedback:feedback2,p_idempotency_key:reviewKey
    });
    reviewedSignals=matching(await notifications(learner.client),'activity_submission_reviewed',n=>n.source_id===second.revision_id);
    assert(reviewedSignals.length===1,'ACTIVITY_REVIEW_RETRY_DUPLICATE_'+reviewedSignals.length);
    report.checks.push({check:'final_review_notifies_learner_once_without_feedback',pass:true});

    const history=await edge(token,{action:'inspect_activity_revision_history',suite:'sidefx_activity',run_id:run,submission_id:first.submission_id});
    const revisions=history.revisions||[];
    assert(revisions.length===2,'ACTIVITY_REVISION_HISTORY_COUNT_'+revisions.length);
    for(const rev of revisions){
      assert(rev.performed_by_account_id===learner.account_id,'REVISION_PERFORMER_MISMATCH_'+rev.revision_number);
      assert(rev.reviewed_by_account_id===teacher.account_id,'REVISION_REVIEWER_MISMATCH_'+rev.revision_number);
      assert(!!rev.submitted_at&&!!rev.reviewed_at,'REVISION_TIMESTAMPS_MISSING_'+rev.revision_number);
    }
    assert(revisions[0].review_outcome==='changes_requested','REVISION1_OUTCOME_'+revisions[0].review_outcome);
    assert(revisions[1].review_outcome==='reviewed','REVISION2_OUTCOME_'+revisions[1].review_outcome);
    report.revisions=revisions;
    report.checks.push({check:'revision_rows_preserve_performer_reviewer_time_outcome',pass:true});

    const browser3=await chromium.launch({headless:true});
    try{
      const lb=await authBrowser(browser3,learner.spec.email,learner.password);
      await chooseRole(lb.page,'learner');
      await lb.page.goto(DEV_ORIGIN+'/#/notifications',{waitUntil:'domcontentloaded'});
      const card=lb.page.locator('.card').filter({hasText:'Activity reviewed'}).first();
      await card.getByRole('button',{name:'Open'}).click();
      await lb.page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/activity',{timeout:15000});
      await lb.page.getByText(activityTitle,{exact:true}).waitFor({timeout:15000});
      await lb.page.screenshot({path:path.join(ARTIFACT_DIR,'learner-reviewed-open.png'),fullPage:true});
      await lb.ctx.close();
    }finally{await browser3.close();}
    report.checks.push({check:'learner_review_notifications_open_authorized_activity',pass:true});

    let denied=null;
    try{await rpc(unrelated.client,'get_activity_detail',{p_activity_id:activity.activity_id,p_learner_id:self.learner_id});}catch(e){denied=errText(e);}
    assert(/NOT_AUTHORIZED/i.test(denied||''),'UNRELATED_ACTIVITY_DETAIL_NOT_DENIED');
    const unrelatedSignals=(await notifications(unrelated.client)).filter(n=>[first.revision_id,second.revision_id].includes(n.source_id));
    assert(unrelatedSignals.length===0,'UNRELATED_RECEIVED_ACTIVITY_SIGNAL');
    report.checks.push({check:'unrelated_activity_context_denied_and_no_signal',pass:true});

    report.end_deployment=await endDeploymentCheck(report.deployment,sha);
    report.result='pass';
    fs.writeFileSync(path.join(ARTIFACT_DIR,'activity-side-effects-proof.json'),JSON.stringify(report,null,2));
    console.log('RAAHI_ACTIVITY_SIDE_EFFECTS_PASS run_id='+run+' commit='+sha);
  }catch(e){
    report.result='fail';report.failure={message:errText(e),class:'to-classify'};
    fs.writeFileSync(path.join(ARTIFACT_DIR,'activity-side-effects-proof.json'),JSON.stringify(report,null,2));
    throw e;
  }finally{
    for(const s of Object.values(sessions)){try{await s.client.auth.signOut();}catch(_){}}
  }
}
await main();
