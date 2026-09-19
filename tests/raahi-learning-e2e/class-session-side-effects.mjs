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
const ARTIFACT_DIR=path.resolve('artifacts-sidefx-class-session');
const KEYS=['learner','teacher','unrelated'];

function assert(v,m){if(!v)throw new Error(m);}
function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
function errText(e){return e?.message||e?.details||e?.hint||String(e);}
function pwd(){return crypto.randomBytes(30).toString('base64url')+'Aa1!';}
function rid(){return 'classfx-'+(process.env.GITHUB_RUN_ID||Date.now())+'-'+(process.env.GITHUB_RUN_ATTEMPT||'1');}
function isoFuture(hours){return new Date(Date.now()+hours*60*60*1000).toISOString();}

function staticDeploymentCompatible(deployedSha,targetSha){
  if(deployedSha===targetSha)return {compatible:true,exact:true,changed:[],appChanges:[]};
  try{
    const changed=execFileSync('git',['diff','--name-only',deployedSha,targetSha],{encoding:'utf8'})
      .split(/\r?\n/).map(x=>x.trim()).filter(Boolean);
    const appChanges=changed.filter(p=>p.startsWith('apps/raahi-learning/'));
    return {compatible:appChanges.length===0,exact:false,changed,appChanges};
  }catch(_){return {compatible:false,exact:false,changed:[],appChanges:['unknown-history']};}
}
async function waitDeployment(sha){
  const deadline=Date.now()+8*60*1000;let last=null;
  while(Date.now()<deadline){
    try{
      const r=await fetch(DEV_ORIGIN+'/build-meta.json?classfx='+Date.now(),{cache:'no-store'});
      if(r.ok){
        last=await r.json();
        const compat=staticDeploymentCompatible(last.commit_sha,sha);
        if(compat.compatible)return {...last,compatibility:compat};
      }
    }catch(e){last={error:String(e)}}
    await sleep(10000);
  }
  throw new Error('DEV_STATIC_DEPLOYMENT_NOT_COMPATIBLE expected='+sha+' last='+JSON.stringify(last));
}
async function endDeploymentCheck(startMeta,sha){
  const r=await fetch(DEV_ORIGIN+'/build-meta.json?classfx-end='+Date.now(),{cache:'no-store'});
  assert(r.ok,'DEV_DEPLOYMENT_END_CHECK_FAILED_'+r.status);
  const m=await r.json();
  const compat=staticDeploymentCompatible(m.commit_sha,sha);
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
  await page.locator('#email').fill(email);await page.locator('#password').fill(password);await page.locator('#signin').click();
  await page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/home',{timeout:30000});
  await page.waitForTimeout(900);
  return {ctx,page};
}

async function main(){
  assert(new URL(SUPABASE_URL).hostname.split('.')[0]===PROJECT_REF,'PROJECT_GUARD');
  assert(process.env.GITHUB_REF==='refs/heads/raahi-learning-implementation-v1','BRANCH_GUARD');
  fs.mkdirSync(ARTIFACT_DIR,{recursive:true});
  const run=rid(),sha=process.env.GITHUB_SHA||'unknown';
  const report={proof:'class-session-side-effects-v1',run_id:run,commit_sha:sha,deployment:null,checks:[],ids:{},result:'running'};
  const sessions={};

  try{
    report.deployment=await waitDeployment(sha);
    const token=await oidc();
    const passwords=Object.fromEntries(KEYS.map(k=>[k,pwd()]));
    const ensured=await edge(token,{action:'ensure_personas',suite:'sidefx_class',run_id:run,passwords});
    const specs=Object.fromEntries(ensured.personas.map(x=>[x.key,x]));
    const names={learner:'Class SideFX E2E Learner',teacher:'Class SideFX E2E Teacher',unrelated:'Class SideFX E2E Unrelated'};

    for(const key of KEYS){
      const c=client();
      const {data,error}=await c.auth.signInWithPassword({email:specs[key].email,password:passwords[key]});if(error)throw error;
      assert(data.session&&data.user,'SESSION_MISSING_'+key);
      const context=await boot(c,names[key]);
      sessions[key]={client:c,spec:specs[key],password:passwords[key],account_id:context.account.account_id,context};
    }

    const learner=sessions.learner,teacher=sessions.teacher,unrelated=sessions.unrelated;
    await rpc(teacher.client,'enable_teaching',{p_idempotency_key:run+'-enable-teach'});
    await rpc(teacher.client,'upsert_teacher_profile',{
      p_headline:'Class SideFX Mathematics teacher',p_bio:'DEV Class Session proof',
      p_experience_summary:'Automated proof',p_visibility_status:'visible',p_idempotency_key:run+'-profile'
    });
    const option=await rpc(teacher.client,'publish_teaching_option',{
      p_organization_id:null,p_title:'Class SideFX Mathematics '+run,p_category:'Mathematics',
      p_description:'DEV Class Session side-effect proof',p_teaching_mode:'both',p_area_or_venue_text:'Dhanbad',
      p_fee_display_text:'DEV proof — no payment collected',p_location_ids:[DHANBAD_LOCATION_ID],p_idempotency_key:run+'-option'
    });

    let lctx=await rpc(learner.client,'get_my_account_context');
    let self=lctx.learners?.find(x=>x.access_type==='self');
    if(!self){
      await rpc(learner.client,'create_learner',{
        p_display_name:'Class SideFX Learner Profile',p_access_type:'self',p_avatar_type:'none',p_avatar_ref:null,p_idempotency_key:run+'-self'
      });
      lctx=await rpc(learner.client,'get_my_account_context');
      self=lctx.learners?.find(x=>x.access_type==='self');
    }
    assert(self?.learner_id,'SELF_LEARNER_MISSING');

    const enquiry=await rpc(learner.client,'send_enquiry',{
      p_learner_id:self.learner_id,p_teaching_option_id:option.teaching_option_id,p_location_id:DHANBAD_LOCATION_ID,
      p_opening_message:null,p_idempotency_key:run+'-enquiry'
    });
    await rpc(teacher.client,'engage_enquiry',{p_enquiry_id:enquiry.enquiry_id,p_idempotency_key:run+'-engage'});

    const classTitle='Class SideFX One-to-One '+run;
    const cls=await rpc(teacher.client,'create_class',{
      p_organization_id:null,p_responsible_teacher_account_id:teacher.account_id,p_location_id:DHANBAD_LOCATION_ID,
      p_title:classTitle,p_class_type:'one_to_one',p_capacity:1,p_idempotency_key:run+'-class'
    });
    await rpc(teacher.client,'activate_class',{p_class_id:cls.class_id,p_idempotency_key:run+'-activate'});
    const invitation=await rpc(teacher.client,'send_class_invitation',{
      p_class_id:cls.class_id,p_enquiry_id:enquiry.enquiry_id,p_fee_display_text:'DEV proof — no payment collected',
      p_idempotency_key:run+'-invite'
    });
    const accepted=await rpc(learner.client,'accept_class_invitation',{
      p_invitation_id:invitation.invitation_id,p_idempotency_key:run+'-accept'
    });
    assert(accepted.membership_id,'MEMBERSHIP_NOT_CREATED');

    report.ids={learner_id:self.learner_id,enquiry_id:enquiry.enquiry_id,class_id:cls.class_id,invitation_id:invitation.invitation_id,membership_id:accepted.membership_id};

    const startsAt=isoFuture(48),endsAt=isoFuture(49);
    const privateLocation='Private Class location '+run;
    const scheduleKey=run+'-schedule-session';
    const scheduled=await rpc(teacher.client,'schedule_class_session',{
      p_class_id:cls.class_id,p_starts_at:startsAt,p_ends_at:endsAt,p_delivery_mode:'in_person',
      p_meeting_or_location_text:privateLocation,p_idempotency_key:scheduleKey
    });
    report.ids.session_id=scheduled.session_id;

    let scheduleNotices=await pollNotifications(
      learner.client,'class_session_scheduled',
      n=>n.payload?.session_id===scheduled.session_id&&n.payload?.class_id===cls.class_id,
      'CLASS_SESSION_SCHEDULED'
    );
    assert(scheduleNotices.length===1,'CLASS_SESSION_SCHEDULED_COUNT_'+scheduleNotices.length);
    assert(scheduleNotices[0].payload?.starts_at,'CLASS_SESSION_TIME_CONTEXT_MISSING');
    assert(!JSON.stringify(scheduleNotices[0]).includes(privateLocation),'CLASS_SESSION_NOTIFICATION_LEAKED_PRIVATE_LOCATION');
    await rpc(teacher.client,'schedule_class_session',{
      p_class_id:cls.class_id,p_starts_at:startsAt,p_ends_at:endsAt,p_delivery_mode:'in_person',
      p_meeting_or_location_text:privateLocation,p_idempotency_key:scheduleKey
    });
    scheduleNotices=matching(await notifications(learner.client),'class_session_scheduled',n=>n.payload?.session_id===scheduled.session_id);
    assert(scheduleNotices.length===1,'CLASS_SESSION_SCHEDULE_RETRY_DUPLICATE_'+scheduleNotices.length);
    report.checks.push({check:'session_schedule_notification_exactly_once_without_location_leak',pass:true});

    let audit=await edge(token,{action:'inspect_class_session_audit',suite:'sidefx_class',run_id:run,session_id:scheduled.session_id});
    let scheduleAudit=(audit.audit_rows||[]).filter(x=>x.action_type==='class_session.schedule');
    assert(scheduleAudit.length===1,'CLASS_SESSION_SCHEDULE_AUDIT_COUNT_'+scheduleAudit.length);
    assert(scheduleAudit[0].actor_account_id===teacher.account_id,'CLASS_SESSION_SCHEDULE_AUDIT_ACTOR_MISMATCH');
    report.checks.push({check:'session_schedule_actor_audit_exactly_once',pass:true});

    const browser=await chromium.launch({headless:true});
    try{
      const b=await authBrowser(browser,learner.spec.email,learner.password);
      await b.page.goto(DEV_ORIGIN+'/#/notifications',{waitUntil:'domcontentloaded'});
      const card=b.page.locator('.card').filter({hasText:'Class session scheduled'}).first();
      await card.getByRole('button',{name:'Open'}).click();
      await b.page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/class-detail',{timeout:15000});
      await b.page.getByText(classTitle,{exact:true}).waitFor({timeout:15000});
      await b.page.screenshot({path:path.join(ARTIFACT_DIR,'learner-session-scheduled-open.png'),fullPage:true});
      await b.ctx.close();
    }finally{await browser.close();}
    report.checks.push({check:'scheduled_notification_open_reauthorizes_class',pass:true});

    const cancelReason='Private provider cancellation reason '+run;
    const cancelKey=run+'-cancel-session';
    await rpc(teacher.client,'cancel_class_session',{p_session_id:scheduled.session_id,p_reason:cancelReason,p_idempotency_key:cancelKey});

    let cancelNotices=await pollNotifications(
      learner.client,'class_session_cancelled',
      n=>n.payload?.session_id===scheduled.session_id&&n.payload?.class_id===cls.class_id,
      'CLASS_SESSION_CANCELLED'
    );
    assert(cancelNotices.length===1,'CLASS_SESSION_CANCELLED_COUNT_'+cancelNotices.length);
    assert(!JSON.stringify(cancelNotices[0]).includes(cancelReason),'CLASS_SESSION_CANCEL_NOTIFICATION_LEAKED_REASON');
    await rpc(teacher.client,'cancel_class_session',{p_session_id:scheduled.session_id,p_reason:cancelReason,p_idempotency_key:cancelKey});
    cancelNotices=matching(await notifications(learner.client),'class_session_cancelled',n=>n.payload?.session_id===scheduled.session_id);
    assert(cancelNotices.length===1,'CLASS_SESSION_CANCEL_RETRY_DUPLICATE_'+cancelNotices.length);
    report.checks.push({check:'session_cancel_notification_exactly_once_without_reason_leak',pass:true});

    audit=await edge(token,{action:'inspect_class_session_audit',suite:'sidefx_class',run_id:run,session_id:scheduled.session_id});
    const rows=audit.audit_rows||[];
    scheduleAudit=rows.filter(x=>x.action_type==='class_session.schedule');
    const cancelAudit=rows.filter(x=>x.action_type==='class_session.cancel');
    assert(scheduleAudit.length===1,'CLASS_SESSION_SCHEDULE_AUDIT_FINAL_COUNT_'+scheduleAudit.length);
    assert(cancelAudit.length===1,'CLASS_SESSION_CANCEL_AUDIT_COUNT_'+cancelAudit.length);
    assert(cancelAudit[0].actor_account_id===teacher.account_id,'CLASS_SESSION_CANCEL_AUDIT_ACTOR_MISMATCH');
    assert(cancelAudit[0].reason===cancelReason,'CLASS_SESSION_CANCEL_AUDIT_REASON_MISMATCH');
    report.audit_rows=rows;
    report.checks.push({check:'session_cancel_actor_audit_exactly_once',pass:true});

    const browser2=await chromium.launch({headless:true});
    try{
      const b=await authBrowser(browser2,learner.spec.email,learner.password);
      await b.page.goto(DEV_ORIGIN+'/#/notifications',{waitUntil:'domcontentloaded'});
      const card=b.page.locator('.card').filter({hasText:'Class session cancelled'}).first();
      await card.getByRole('button',{name:'Open'}).click();
      await b.page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/class-detail',{timeout:15000});
      await b.page.getByText(classTitle,{exact:true}).waitFor({timeout:15000});
      await b.page.screenshot({path:path.join(ARTIFACT_DIR,'learner-session-cancelled-open.png'),fullPage:true});
      await b.ctx.close();
    }finally{await browser2.close();}
    report.checks.push({check:'cancelled_notification_open_reauthorizes_class',pass:true});

    let unrelatedDenied=null;
    try{await rpc(unrelated.client,'get_class_learning_overview',{p_class_id:cls.class_id,p_learner_id:self.learner_id});}
    catch(e){unrelatedDenied=errText(e);}
    assert(/NOT_AUTHORIZED/i.test(unrelatedDenied||''),'UNRELATED_CLASS_PROJECTION_NOT_DENIED_'+(unrelatedDenied||'none'));

    const {data:sessionRows,error:sessionError}=await unrelated.client.from('class_sessions').select('id').eq('id',scheduled.session_id);
    if(sessionError)throw sessionError;
    assert(Array.isArray(sessionRows)&&sessionRows.length===0,'UNRELATED_CLASS_SESSION_RLS_LEAK');
    report.checks.push({check:'unrelated_projection_and_rls_denied',pass:true});

    report.end_deployment=await endDeploymentCheck(report.deployment,sha);
    report.result='pass';
    fs.writeFileSync(path.join(ARTIFACT_DIR,'class-session-side-effects-proof.json'),JSON.stringify(report,null,2));
    console.log('RAAHI_CLASS_SESSION_SIDE_EFFECTS_PASS run_id='+run+' commit='+sha);
  }catch(e){
    report.result='fail';report.failure={message:errText(e),class:'to-classify'};
    fs.writeFileSync(path.join(ARTIFACT_DIR,'class-session-side-effects-proof.json'),JSON.stringify(report,null,2));
    throw e;
  }finally{
    for(const s of Object.values(sessions)){try{await s.client.auth.signOut();}catch(_){}}
  }
}
await main();
