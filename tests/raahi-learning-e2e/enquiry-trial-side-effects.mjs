import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { chromium } from 'playwright';
import { createClient } from '@supabase/supabase-js';

const DEV_ORIGIN='https://dev.learning.myraahi.co.in';
const SUPABASE_URL='https://iiwwmqokaeflaenhlyip.supabase.co';
const PROJECT_REF='iiwwmqokaeflaenhlyip';
const PUBLISHABLE_KEY='sb_publishable_bz0YgDXY-WkKxZnogGsfUg_Qgl7E-Wi';
const EDGE_URL=SUPABASE_URL+'/functions/v1/dev-test-identities';
const OIDC_AUDIENCE='raahi-learning-dev-test-harness';
const DHANBAD_LOCATION_ID='028ee066-2130-45d6-8e17-6ceb9b0f1f80';
const ARTIFACT_DIR=path.resolve('artifacts-sidefx-enquiry-trial');
const KEYS=['learner','teacher','unrelated'];

function assert(v,m){if(!v)throw new Error(m);}
function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
function errText(e){return e?.message||e?.details||e?.hint||String(e);}
function pwd(){return crypto.randomBytes(30).toString('base64url')+'Aa1!';}
function rid(){return 'sidefx-'+(process.env.GITHUB_RUN_ID||Date.now())+'-'+(process.env.GITHUB_RUN_ATTEMPT||'1');}
function isoFuture(hours){return new Date(Date.now()+hours*60*60*1000).toISOString();}

async function waitDeployment(sha){
  const deadline=Date.now()+8*60*1000;let last=null;
  while(Date.now()<deadline){
    try{
      const r=await fetch(DEV_ORIGIN+'/build-meta.json?sidefx='+Date.now(),{cache:'no-store'});
      if(r.ok){last=await r.json();if(last.commit_sha===sha)return last;}
    }catch(e){last={error:String(e)}}
    await sleep(10000);
  }
  throw new Error('DEV_DEPLOYMENT_NOT_CURRENT expected='+sha+' last='+JSON.stringify(last));
}
async function endDeploymentCheck(sha){
  const r=await fetch(DEV_ORIGIN+'/build-meta.json?sidefx-end='+Date.now(),{cache:'no-store'});
  assert(r.ok,'DEV_DEPLOYMENT_END_CHECK_FAILED_'+r.status);
  const m=await r.json();
  assert(m.commit_sha===sha,'DEV_DEPLOYMENT_CHANGED_DURING_SIDEFX_PROOF expected='+sha+' actual='+m.commit_sha);
  return m;
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
async function notifications(c){
  const xs=await rpc(c,'get_my_notifications',{p_limit:200});
  return Array.isArray(xs)?xs:[];
}
function matching(xs,type,pred=()=>true){return xs.filter(x=>x.notification_type===type&&pred(x));}
async function pollNotifications(c,type,pred,label){
  const deadline=Date.now()+30000;let last=[];
  while(Date.now()<deadline){
    last=matching(await notifications(c),type,pred);
    if(last.length)return last;
    await sleep(500);
  }
  throw new Error(label+'_NOT_FOUND');
}
async function authBrowser(browser,email,password){
  const ctx=await browser.newContext({viewport:{width:1280,height:900}});
  const page=await ctx.newPage();
  await page.goto(DEV_ORIGIN+'/dev-test-login-v13.html',{waitUntil:'domcontentloaded'});
  await page.getByText('RAAHI_DEV_TEST_LOGIN_V13').waitFor({timeout:30000});
  await page.locator('#email').fill(email);
  await page.locator('#password').fill(password);
  await page.locator('#signin').click();
  await page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/home',{timeout:30000});
  await page.waitForTimeout(900);
  return {ctx,page};
}

async function main(){
  assert(new URL(SUPABASE_URL).hostname.split('.')[0]===PROJECT_REF,'PROJECT_GUARD');
  assert(process.env.GITHUB_REF==='refs/heads/raahi-learning-implementation-v1','BRANCH_GUARD');
  fs.mkdirSync(ARTIFACT_DIR,{recursive:true});
  const run=rid(),sha=process.env.GITHUB_SHA||'unknown';
  const report={proof:'enquiry-trial-side-effects-v1',run_id:run,commit_sha:sha,deployment:null,checks:[],ids:{},result:'running'};
  const sessions={};
  try{
    report.deployment=await waitDeployment(sha);
    const token=await oidc();
    const passwords=Object.fromEntries(KEYS.map(k=>[k,pwd()]));
    const ensured=await edge(token,{action:'ensure_personas',suite:'sidefx_enquiry',run_id:run,passwords});
    const specs=Object.fromEntries(ensured.personas.map(x=>[x.key,x]));
    const names={learner:'SideFX E2E Learner',teacher:'SideFX E2E Teacher',unrelated:'SideFX E2E Unrelated'};

    for(const key of KEYS){
      const c=client();
      const {data,error}=await c.auth.signInWithPassword({email:specs[key].email,password:passwords[key]});if(error)throw error;
      assert(data.session&&data.user,'SESSION_MISSING_'+key);
      const context=await boot(c,names[key]);
      sessions[key]={client:c,spec:specs[key],context,password:passwords[key],auth_user_id:data.user.id,account_id:context.account.account_id};
    }

    const learner=sessions.learner,teacher=sessions.teacher,unrelated=sessions.unrelated;
    await rpc(teacher.client,'enable_teaching',{p_idempotency_key:run+'-enable-teach'});
    await rpc(teacher.client,'upsert_teacher_profile',{
      p_headline:'SideFX Mathematics teacher',
      p_bio:'DEV side-effect proof teacher',
      p_experience_summary:'Automated proof',
      p_visibility_status:'visible',
      p_idempotency_key:run+'-teacher-profile'
    });
    const option=await rpc(teacher.client,'publish_teaching_option',{
      p_organization_id:null,
      p_title:'SideFX Mathematics '+run,
      p_category:'Mathematics',
      p_description:'DEV side-effect proof',
      p_teaching_mode:'both',
      p_area_or_venue_text:'Dhanbad',
      p_fee_display_text:'DEV proof — no payment collected',
      p_location_ids:[DHANBAD_LOCATION_ID],
      p_idempotency_key:run+'-option'
    });

    let lctx=await rpc(learner.client,'get_my_account_context');
    let self=lctx.learners?.find(x=>x.access_type==='self');
    if(!self){
      await rpc(learner.client,'create_learner',{
        p_display_name:'SideFX Learner Profile',p_access_type:'self',p_avatar_type:'none',p_avatar_ref:null,
        p_idempotency_key:run+'-self'
      });
      lctx=await rpc(learner.client,'get_my_account_context');
      self=lctx.learners?.find(x=>x.access_type==='self');
    }
    assert(self?.learner_id,'SELF_LEARNER_MISSING');

    const opening='SideFX structured opening '+run;
    const first=await rpc(learner.client,'send_enquiry',{
      p_learner_id:self.learner_id,p_teaching_option_id:option.teaching_option_id,p_location_id:DHANBAD_LOCATION_ID,
      p_opening_message:opening,p_idempotency_key:run+'-enquiry-1'
    });
    report.ids.first_enquiry_id=first.enquiry_id;

    let providerNotice=await pollNotifications(
      teacher.client,'enquiry_received',
      n=>n.payload?.enquiry_id===first.enquiry_id,
      'ENQUIRY_RECEIVED'
    );
    assert(providerNotice.length===1,'ENQUIRY_RECEIVED_COUNT_'+providerNotice.length);
    const openingMessageAlerts=matching(await notifications(teacher.client),'enquiry_message',n=>n.payload?.enquiry_id===first.enquiry_id);
    assert(openingMessageAlerts.length===0,'OPENING_MESSAGE_DUPLICATE_ALERT_'+openingMessageAlerts.length);
    report.checks.push({check:'initial_enquiry_one_provider_signal_no_structured_message_duplicate',pass:true});

    const declineKey=run+'-decline';
    await rpc(teacher.client,'decline_enquiry',{p_enquiry_id:first.enquiry_id,p_idempotency_key:declineKey});
    let declineNotices=await pollNotifications(
      learner.client,'enquiry_declined',
      n=>n.payload?.enquiry_id===first.enquiry_id,
      'ENQUIRY_DECLINED'
    );
    assert(declineNotices.length===1,'ENQUIRY_DECLINED_COUNT_'+declineNotices.length);
    assert(!JSON.stringify(declineNotices[0]).includes(opening),'DECLINE_NOTIFICATION_LEAKED_MESSAGE_BODY');
    await rpc(teacher.client,'decline_enquiry',{p_enquiry_id:first.enquiry_id,p_idempotency_key:declineKey});
    declineNotices=matching(await notifications(learner.client),'enquiry_declined',n=>n.payload?.enquiry_id===first.enquiry_id);
    assert(declineNotices.length===1,'ENQUIRY_DECLINE_IDEMPOTENCY_DUPLICATE_'+declineNotices.length);
    report.checks.push({check:'decline_notifies_originating_side_once_and_retry_dedups',pass:true});

    const second=await rpc(learner.client,'send_enquiry',{
      p_learner_id:self.learner_id,p_teaching_option_id:option.teaching_option_id,p_location_id:DHANBAD_LOCATION_ID,
      p_opening_message:null,p_idempotency_key:run+'-enquiry-2'
    });
    report.ids.enquiry_id=second.enquiry_id;
    await rpc(teacher.client,'engage_enquiry',{p_enquiry_id:second.enquiry_id,p_idempotency_key:run+'-engage'});

    const scheduledAt=isoFuture(48);
    const scheduleKey=run+'-trial-schedule';
    const trial=await rpc(learner.client,'schedule_trial_event',{
      p_enquiry_id:second.enquiry_id,p_scheduled_at:scheduledAt,p_idempotency_key:scheduleKey
    });
    report.ids.trial_event_id=trial.trial_event_id;

    let scheduledNotices=await pollNotifications(
      teacher.client,'trial_scheduled',
      n=>n.payload?.trial_event_id===trial.trial_event_id&&n.payload?.enquiry_id===second.enquiry_id,
      'TRIAL_SCHEDULED'
    );
    assert(scheduledNotices.length===1,'TRIAL_SCHEDULED_COUNT_'+scheduledNotices.length);
    assert(scheduledNotices[0].payload?.scheduled_at,'TRIAL_SCHEDULED_TIME_CONTEXT_MISSING');
    assert(!JSON.stringify(scheduledNotices[0]).includes(opening),'TRIAL_SCHEDULED_LEAKED_PRIVATE_MESSAGE');
    await rpc(learner.client,'schedule_trial_event',{
      p_enquiry_id:second.enquiry_id,p_scheduled_at:scheduledAt,p_idempotency_key:scheduleKey
    });
    scheduledNotices=matching(await notifications(teacher.client),'trial_scheduled',n=>n.payload?.trial_event_id===trial.trial_event_id);
    assert(scheduledNotices.length===1,'TRIAL_SCHEDULE_IDEMPOTENCY_DUPLICATE_'+scheduledNotices.length);
    report.checks.push({check:'trial_schedule_notifies_provider_once_with_time_context',pass:true});

    const rescheduledAt=isoFuture(72);
    const rescheduleKey=run+'-trial-reschedule';
    await rpc(teacher.client,'reschedule_trial_event',{
      p_trial_event_id:trial.trial_event_id,p_scheduled_at:rescheduledAt,p_idempotency_key:rescheduleKey
    });
    let rescheduleNotices=await pollNotifications(
      learner.client,'trial_rescheduled',
      n=>n.payload?.trial_event_id===trial.trial_event_id&&n.payload?.enquiry_id===second.enquiry_id,
      'TRIAL_RESCHEDULED'
    );
    assert(rescheduleNotices.length===1,'TRIAL_RESCHEDULED_COUNT_'+rescheduleNotices.length);
    await rpc(teacher.client,'reschedule_trial_event',{
      p_trial_event_id:trial.trial_event_id,p_scheduled_at:rescheduledAt,p_idempotency_key:rescheduleKey
    });
    rescheduleNotices=matching(await notifications(learner.client),'trial_rescheduled',n=>n.payload?.trial_event_id===trial.trial_event_id);
    assert(rescheduleNotices.length===1,'TRIAL_RESCHEDULE_IDEMPOTENCY_DUPLICATE_'+rescheduleNotices.length);
    report.checks.push({check:'trial_reschedule_notifies_learner_side_once',pass:true});

    const cancelKey=run+'-trial-cancel';
    await rpc(learner.client,'cancel_trial_event',{p_trial_event_id:trial.trial_event_id,p_idempotency_key:cancelKey});
    let cancelNotices=await pollNotifications(
      teacher.client,'trial_cancelled',
      n=>n.payload?.trial_event_id===trial.trial_event_id&&n.payload?.enquiry_id===second.enquiry_id,
      'TRIAL_CANCELLED'
    );
    assert(cancelNotices.length===1,'TRIAL_CANCELLED_COUNT_'+cancelNotices.length);
    await rpc(learner.client,'cancel_trial_event',{p_trial_event_id:trial.trial_event_id,p_idempotency_key:cancelKey});
    cancelNotices=matching(await notifications(teacher.client),'trial_cancelled',n=>n.payload?.trial_event_id===trial.trial_event_id);
    assert(cancelNotices.length===1,'TRIAL_CANCEL_IDEMPOTENCY_DUPLICATE_'+cancelNotices.length);
    report.checks.push({check:'trial_cancel_notifies_provider_once',pass:true});

    const closeKey=run+'-close';
    await rpc(learner.client,'close_enquiry',{p_enquiry_id:second.enquiry_id,p_close_reason:'learner_closed',p_idempotency_key:closeKey});
    let closeNotices=await pollNotifications(
      teacher.client,'enquiry_closed',
      n=>n.payload?.enquiry_id===second.enquiry_id,
      'ENQUIRY_CLOSED'
    );
    assert(closeNotices.length===1,'ENQUIRY_CLOSED_COUNT_'+closeNotices.length);
    await rpc(learner.client,'close_enquiry',{p_enquiry_id:second.enquiry_id,p_close_reason:'learner_closed',p_idempotency_key:closeKey});
    closeNotices=matching(await notifications(teacher.client),'enquiry_closed',n=>n.payload?.enquiry_id===second.enquiry_id);
    assert(closeNotices.length===1,'ENQUIRY_CLOSE_IDEMPOTENCY_DUPLICATE_'+closeNotices.length);
    report.checks.push({check:'active_enquiry_close_notifies_opposite_side_once',pass:true});

    const audit=await edge(token,{
      action:'inspect_enquiry_trial_audit',suite:'sidefx_enquiry',run_id:run,trial_event_id:trial.trial_event_id
    });
    const rows=audit.audit_rows||[];
    const rescheduleAudit=rows.filter(x=>x.action_type==='trial.reschedule');
    const cancelAudit=rows.filter(x=>x.action_type==='trial.cancel');
    assert(rescheduleAudit.length===1,'TRIAL_RESCHEDULE_AUDIT_COUNT_'+rescheduleAudit.length);
    assert(cancelAudit.length===1,'TRIAL_CANCEL_AUDIT_COUNT_'+cancelAudit.length);
    assert(rescheduleAudit[0].actor_account_id===teacher.account_id,'TRIAL_RESCHEDULE_AUDIT_ACTOR_MISMATCH');
    assert(cancelAudit[0].actor_account_id===learner.account_id,'TRIAL_CANCEL_AUDIT_ACTOR_MISMATCH');
    assert(rescheduleAudit[0].metadata?.enquiry_id===second.enquiry_id,'TRIAL_RESCHEDULE_AUDIT_ENQUIRY_MISSING');
    assert(cancelAudit[0].metadata?.enquiry_id===second.enquiry_id,'TRIAL_CANCEL_AUDIT_ENQUIRY_MISSING');
    report.audit_rows=rows;
    report.checks.push({check:'trial_reschedule_cancel_audit_actor_history_exactly_once',pass:true});

    let unrelatedDenied=null;
    try{await rpc(unrelated.client,'get_enquiry_thread',{p_enquiry_id:second.enquiry_id});}
    catch(e){unrelatedDenied=errText(e);}
    assert(/NOT_AUTHORIZED/i.test(unrelatedDenied||''),'UNRELATED_ENQUIRY_PROJECTION_NOT_DENIED_'+(unrelatedDenied||'none'));
    report.checks.push({check:'unrelated_enquiry_projection_denied',pass:true});

    const browser=await chromium.launch({headless:true});
    try{
      const learnerBrowser=await authBrowser(browser,learner.spec.email,learner.password);
      await learnerBrowser.page.goto(DEV_ORIGIN+'/#/notifications',{waitUntil:'domcontentloaded'});
      const declinedCard=learnerBrowser.page.locator('.card').filter({hasText:'Enquiry declined'}).first();
      await declinedCard.getByRole('button',{name:'Open'}).click();
      await learnerBrowser.page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/enquiry',{timeout:15000});
      await learnerBrowser.page.locator('h1').first().waitFor({timeout:15000});
      await learnerBrowser.page.screenshot({path:path.join(ARTIFACT_DIR,'learner-enquiry-declined-open.png'),fullPage:true});
      await learnerBrowser.ctx.close();

      const teacherBrowser=await authBrowser(browser,teacher.spec.email,teacher.password);
      await teacherBrowser.page.goto(DEV_ORIGIN+'/#/notifications',{waitUntil:'domcontentloaded'});
      const trialCard=teacherBrowser.page.locator('.card').filter({hasText:'Trial scheduled'}).first();
      await trialCard.getByRole('button',{name:'Open'}).click();
      await teacherBrowser.page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/trial',{timeout:15000});
      await teacherBrowser.page.getByText('Trial Session',{exact:true}).waitFor({timeout:15000});
      await teacherBrowser.page.screenshot({path:path.join(ARTIFACT_DIR,'teacher-trial-notification-open.png'),fullPage:true});
      await teacherBrowser.ctx.close();
    }finally{await browser.close();}
    report.checks.push({check:'notification_open_routes_reauthorize_enquiry_and_trial_context',pass:true});

    report.end_deployment=await endDeploymentCheck(sha);
    report.result='pass';
    fs.writeFileSync(path.join(ARTIFACT_DIR,'enquiry-trial-side-effects-proof.json'),JSON.stringify(report,null,2));
    console.log('RAAHI_ENQUIRY_TRIAL_SIDE_EFFECTS_PASS run_id='+run+' commit='+sha);
  }catch(e){
    report.result='fail';
    report.failure={message:errText(e),class:'to-classify'};
    fs.writeFileSync(path.join(ARTIFACT_DIR,'enquiry-trial-side-effects-proof.json'),JSON.stringify(report,null,2));
    throw e;
  }finally{
    for(const s of Object.values(sessions)){try{await s.client.auth.signOut();}catch(_){}}
  }
}
await main();
