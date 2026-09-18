import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { chromium } from 'playwright';
import { createClient } from '@supabase/supabase-js';

const DEV_ORIGIN='https://dev.learning.myraahi.co.in';
const EXPECTED_HOST='dev.learning.myraahi.co.in';
const SUPABASE_URL='https://iiwwmqokaeflaenhlyip.supabase.co';
const PROJECT_REF='iiwwmqokaeflaenhlyip';
const PUBLISHABLE_KEY='sb_publishable_bz0YgDXY-WkKxZnogGsfUg_Qgl7E-Wi';
const EDGE_URL=SUPABASE_URL+'/functions/v1/dev-test-identities';
const OIDC_AUDIENCE='raahi-learning-dev-test-harness';
const DHANBAD_LOCATION_ID='028ee066-2130-45d6-8e17-6ceb9b0f1f80';
const PERSONA_KEYS=['learner','teacher','unrelated','admin'];
const ARTIFACT_DIR=path.resolve('artifacts-r4');

function assert(v,m){if(!v)throw new Error(m);}
function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
function idk(rid,suffix){return rid+'-'+suffix;}
function randomPassword(){return crypto.randomBytes(30).toString('base64url')+'Aa1!';}
function runId(){return 'r4-'+(process.env.GITHUB_RUN_ID||Date.now())+'-'+(process.env.GITHUB_RUN_ATTEMPT||'1');}
function safeError(e){return e?.message||e?.details||e?.hint||String(e);}

function guards(){
  assert(new URL(DEV_ORIGIN).hostname===EXPECTED_HOST,'DEV_ORIGIN_GUARD_FAILED');
  assert(new URL(SUPABASE_URL).hostname.split('.')[0]===PROJECT_REF,'SUPABASE_PROJECT_GUARD_FAILED');
  assert(process.env.GITHUB_REF==='refs/heads/raahi-learning-implementation-v1','GITHUB_REF_GUARD_FAILED');
}

async function waitForDeployment(sha){
  const deadline=Date.now()+8*60*1000;
  let last=null;
  while(Date.now()<deadline){
    try{
      const res=await fetch(DEV_ORIGIN+'/build-meta.json?r4='+Date.now(),{cache:'no-store'});
      if(res.ok){last=await res.json();if(last.commit_sha===sha)return last;}
    }catch(e){last={error:String(e)}}
    await sleep(10000);
  }
  throw new Error('DEV_DEPLOYMENT_NOT_CURRENT expected='+sha+' last='+JSON.stringify(last));
}

async function githubOidc(){
  const requestUrl=process.env.ACTIONS_ID_TOKEN_REQUEST_URL;
  const requestToken=process.env.ACTIONS_ID_TOKEN_REQUEST_TOKEN;
  assert(requestUrl&&requestToken,'GITHUB_OIDC_ENV_MISSING');
  const u=new URL(requestUrl);u.searchParams.set('audience',OIDC_AUDIENCE);
  const res=await fetch(u,{headers:{authorization:'Bearer '+requestToken}});
  if(!res.ok)throw new Error('GITHUB_OIDC_REQUEST_FAILED_'+res.status);
  const body=await res.json();assert(body.value,'GITHUB_OIDC_TOKEN_MISSING');return body.value;
}

async function edgeCall(token,payload){
  const res=await fetch(EDGE_URL,{method:'POST',headers:{authorization:'Bearer '+token,'content-type':'application/json'},body:JSON.stringify(payload)});
  const body=await res.json().catch(()=>({ok:false,error:'INVALID_JSON_RESPONSE'}));
  if(!res.ok||!body.ok)throw new Error('DEV_IDENTITY_FACTORY_FAILED '+(body.error||res.status));
  return body;
}

function supa(){
  return createClient(SUPABASE_URL,PUBLISHABLE_KEY,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
}
async function rpc(c,name,args={}){
  const {data,error}=await c.rpc(name,args);if(error)throw error;return data;
}
async function context(c){return rpc(c,'get_my_account_context');}
async function bootstrap(c,name){
  try{return await context(c);}catch(e){
    if(!/ACCOUNT_NOT_FOUND/i.test(safeError(e)))throw e;
    await rpc(c,'bootstrap_account',{p_display_name:name});
    return context(c);
  }
}

async function signInBrowser(browser,email,password){
  const ctx=await browser.newContext();
  const page=await ctx.newPage();
  await page.goto(DEV_ORIGIN+'/dev-test-login-v13.html',{waitUntil:'domcontentloaded'});
  await page.getByText('RAAHI_DEV_TEST_LOGIN_V13').waitFor({timeout:30000});
  await page.locator('#email').fill(email);
  await page.locator('#password').fill(password);
  await page.locator('#signin').click();
  await page.waitForURL(url=>url.origin===DEV_ORIGIN&&url.hash==='#/home',{timeout:30000});
  await page.waitForTimeout(1000);
  assert(!/Continue with Google/i.test(await page.locator('body').innerText()),'BROWSER_RETURNED_TO_GOOGLE');
  return {ctx,page};
}

async function poll(fn,accept,label,timeout=30000){
  const deadline=Date.now()+timeout;let last=null;
  while(Date.now()<deadline){
    try{last=await fn();if(accept(last))return last;}catch(e){last={error:safeError(e)}}
    await sleep(700);
  }
  throw new Error(label+' timeout last='+JSON.stringify(last));
}

async function main(){
  guards();fs.mkdirSync(ARTIFACT_DIR,{recursive:true});
  const rid=runId(),sha=process.env.GITHUB_SHA||'unknown';
  const report={proof:'r4-class-thread-privacy-v1',run_id:rid,commit_sha:sha,deployment:null,ids:{},checks:[],result:'running'};
  const sessions={};

  try{
    report.deployment=await waitForDeployment(sha);
    report.checks.push({check:'exact_commit_deployed',pass:true});

    const oidc=await githubOidc();
    const passwords=Object.fromEntries(PERSONA_KEYS.map(k=>[k,randomPassword()]));
    const ensured=await edgeCall(oidc,{action:'ensure_personas',suite:'r4',run_id:rid,passwords});
    report.persona_suite=ensured.suite;
    const specs=Object.fromEntries(ensured.personas.map(x=>[x.key,x]));
    const names={learner:'R4 E2E Learner Account',teacher:'R4 E2E Teacher Account',unrelated:'R4 E2E Unrelated Account',admin:'R4 E2E Platform Admin'};

    for(const key of PERSONA_KEYS){
      const c=supa(),spec=specs[key];
      const {data,error}=await c.auth.signInWithPassword({email:spec.email,password:passwords[key]});
      if(error)throw error;
      assert(data.session&&data.user&&data.user.id===spec.auth_user_id,'GENUINE_SESSION_FAILED_'+key);
      const acct=await bootstrap(c,names[key]);
      sessions[key]={client:c,email:spec.email,auth_user_id:data.user.id,account:acct};
    }
    report.checks.push({check:'genuine_sessions_ready',pass:true});

    const learner=sessions.learner,teacher=sessions.teacher,unrelated=sessions.unrelated;

    await rpc(teacher.client,'enable_teaching',{p_idempotency_key:idk(rid,'enable-teach')});
    await rpc(teacher.client,'upsert_teacher_profile',{
      p_headline:'R4 automated Mathematics teacher',
      p_bio:'Deterministic DEV walking-skeleton provider.',
      p_experience_summary:'Automated R4 proof',
      p_visibility_status:'visible',
      p_idempotency_key:idk(rid,'teacher-profile')
    });
    const option=await rpc(teacher.client,'publish_teaching_option',{
      p_organization_id:null,
      p_title:'R4 Automated Mathematics '+rid,
      p_category:'Mathematics',
      p_description:'DEV walking skeleton option',
      p_teaching_mode:'both',
      p_area_or_venue_text:'Dhanbad',
      p_fee_display_text:'DEV proof — no payment collected',
      p_location_ids:[DHANBAD_LOCATION_ID],
      p_idempotency_key:idk(rid,'publish-option')
    });
    assert(option.teaching_option_id,'TEACHING_OPTION_NOT_CREATED');

    let learnerCtx=await context(learner.client);
    let self=learnerCtx.learners.find(x=>x.access_type==='self');
    if(!self){
      await rpc(learner.client,'create_learner',{
        p_display_name:'R4 E2E Learner Profile',p_access_type:'self',p_avatar_type:'none',p_avatar_ref:null,
        p_idempotency_key:idk(rid,'create-self')
      });
      learnerCtx=await context(learner.client);
      self=learnerCtx.learners.find(x=>x.access_type==='self');
    }
    assert(self?.learner_id,'SELF_LEARNER_MISSING');

    const enquiry=await rpc(learner.client,'send_enquiry',{
      p_learner_id:self.learner_id,
      p_teaching_option_id:option.teaching_option_id,
      p_location_id:DHANBAD_LOCATION_ID,
      p_opening_message:'R4 automated learner enquiry.',
      p_idempotency_key:idk(rid,'send-enquiry')
    });
    await rpc(teacher.client,'engage_enquiry',{p_enquiry_id:enquiry.enquiry_id,p_idempotency_key:idk(rid,'engage-enquiry')});
    await rpc(teacher.client,'send_enquiry_message',{
      p_enquiry_id:enquiry.enquiry_id,
      p_body:'R4 automated provider reply.',
      p_idempotency_key:idk(rid,'provider-reply')
    });

    const cls=await rpc(teacher.client,'create_class',{
      p_organization_id:null,
      p_responsible_teacher_account_id:teacher.account.account.account_id,
      p_location_id:DHANBAD_LOCATION_ID,
      p_title:'R4 Automated One-to-One '+rid,
      p_class_type:'one_to_one',
      p_capacity:1,
      p_idempotency_key:idk(rid,'create-class')
    });
    await rpc(teacher.client,'activate_class',{p_class_id:cls.class_id,p_idempotency_key:idk(rid,'activate-class')});
    const invitation=await rpc(teacher.client,'send_class_invitation',{
      p_class_id:cls.class_id,
      p_enquiry_id:enquiry.enquiry_id,
      p_fee_display_text:'DEV R4 proof — no payment collected',
      p_idempotency_key:idk(rid,'invite')
    });
    const accepted=await rpc(learner.client,'accept_class_invitation',{
      p_invitation_id:invitation.invitation_id,
      p_idempotency_key:idk(rid,'accept')
    });
    assert(accepted.membership_id,'MEMBERSHIP_NOT_CREATED');

    const learnerClasses=await rpc(learner.client,'get_my_classes');
    const rows=(Array.isArray(learnerClasses)?learnerClasses:[learnerClasses]).filter(x=>x.class_id===cls.class_id&&x.context_kind==='learner'&&x.membership_state==='active');
    assert(rows.length===1,'ACTIVE_MEMBERSHIP_CARDINALITY_'+rows.length);

    const before=await rpc(learner.client,'get_class_learner_thread',{p_class_id:cls.class_id,p_learner_id:self.learner_id});
    assert(before&&before.thread_id===null&&Array.isArray(before.messages)&&before.messages.length===0,'THREAD_SHOULD_BE_LAZY_BEFORE_FIRST_MESSAGE');

    report.ids={
      learner_id:self.learner_id,learner_name:self.display_name,
      teaching_option_id:option.teaching_option_id,enquiry_id:enquiry.enquiry_id,
      class_id:cls.class_id,class_title:'R4 Automated One-to-One '+rid,
      invitation_id:invitation.invitation_id,membership_id:accepted.membership_id
    };
    report.checks.push({check:'canonical_relationship_to_active_membership',pass:true});
    report.checks.push({check:'thread_absent_before_first_message',pass:true});

    const messageBody='R4 automated contextual Class message '+rid;
    const deepLink=DEV_ORIGIN+'/#/class-thread?class_id='+encodeURIComponent(cls.class_id)+'&learner_id='+encodeURIComponent(self.learner_id);
    assert(!deepLink.includes(messageBody)&&!deepLink.includes('@')&&!/token|password|access_token/i.test(deepLink),'DEEPLINK_CONTAINS_SENSITIVE_DATA');

    const browser=await chromium.launch({headless:true});
    try{
      const learnerBrowser=await signInBrowser(browser,learner.email,passwords.learner);
      await learnerBrowser.page.goto(deepLink,{waitUntil:'domcontentloaded'});
      await learnerBrowser.page.locator('#live-class-message').waitFor({timeout:30000});
      await learnerBrowser.page.locator('#live-class-message').fill(messageBody);
      await learnerBrowser.page.locator('[data-live-send-class-message]').click();
      await learnerBrowser.page.getByText(messageBody,{exact:true}).waitFor({timeout:30000});
      await learnerBrowser.page.screenshot({path:path.join(ARTIFACT_DIR,'r4-learner-message-sent.png'),fullPage:true});
      await learnerBrowser.ctx.close();
      report.checks.push({check:'learner_sent_contextual_class_message_via_normal_ui',pass:true});

      const teacherNotifications=await poll(
        ()=>rpc(teacher.client,'get_my_notifications',{p_limit:100}),
        xs=>(Array.isArray(xs)?xs:[]).some(n=>n.notification_type==='class_message'&&n.payload?.class_id===cls.class_id&&n.payload?.learner_id===self.learner_id),
        'TEACHER_CLASS_MESSAGE_NOTIFICATION'
      );
      const matching=(Array.isArray(teacherNotifications)?teacherNotifications:[]).filter(n=>n.notification_type==='class_message'&&n.payload?.class_id===cls.class_id&&n.payload?.learner_id===self.learner_id);
      assert(matching.length===1,'CLASS_MESSAGE_NOTIFICATION_CARDINALITY_'+matching.length);
      const notice=matching[0];
      report.ids.notification_id=notice.notification_id;
      report.ids.thread_id=notice.payload.thread_id;
      report.ids.message_id=notice.payload.message_id;
      report.checks.push({check:'teacher_notification_created_once',pass:true});

      const teacherBrowser=await signInBrowser(browser,teacher.email,passwords.teacher);
      await teacherBrowser.page.goto(DEV_ORIGIN+'/#/notifications',{waitUntil:'domcontentloaded'});
      await teacherBrowser.page.getByText('New Class message',{exact:true}).first().waitFor({timeout:30000});
      await teacherBrowser.page.screenshot({path:path.join(ARTIFACT_DIR,'r4-teacher-notification.png'),fullPage:true});
      await teacherBrowser.page.getByRole('button',{name:'Open'}).first().click();
      await teacherBrowser.page.locator('#live-class-message').waitFor({timeout:30000});
      await teacherBrowser.page.getByText(messageBody,{exact:true}).waitFor({timeout:30000});
      await teacherBrowser.page.getByText(self.display_name,{exact:false}).first().waitFor({timeout:30000});
      const notificationDeepLink=teacherBrowser.page.url();
      const parsedNotificationDeepLink=new URL(notificationDeepLink);
      assert(parsedNotificationDeepLink.origin===DEV_ORIGIN,'NOTIFICATION_DEEPLINK_WRONG_ORIGIN');
      assert(parsedNotificationDeepLink.hash.includes('#/class-thread?'),'NOTIFICATION_DID_NOT_OPEN_CLASS_THREAD '+notificationDeepLink);
      assert(parsedNotificationDeepLink.hash.includes('class_id='+encodeURIComponent(cls.class_id)),'NOTIFICATION_DEEPLINK_CLASS_ID_MISSING');
      assert(parsedNotificationDeepLink.hash.includes('learner_id='+encodeURIComponent(self.learner_id)),'NOTIFICATION_DEEPLINK_LEARNER_ID_MISSING');
      assert(!notificationDeepLink.includes(messageBody)&&!notificationDeepLink.includes('@')&&!/access_token|password=/i.test(notificationDeepLink),'NOTIFICATION_DEEPLINK_CONTAINS_SENSITIVE_DATA');
      report.notification_deep_link=parsedNotificationDeepLink.origin+parsedNotificationDeepLink.pathname+parsedNotificationDeepLink.hash;
      await teacherBrowser.page.screenshot({path:path.join(ARTIFACT_DIR,'r4-teacher-deeplink-authorized.png'),fullPage:true});
      await teacherBrowser.ctx.close();
      report.checks.push({check:'teacher_notification_open_button_routes_to_authorized_deeplink',pass:true});

      let denyError=null;
      try{await rpc(unrelated.client,'get_class_learner_thread',{p_class_id:cls.class_id,p_learner_id:self.learner_id});}
      catch(e){denyError=safeError(e);}
      assert(/NOT_AUTHORIZED/i.test(denyError||''),'UNRELATED_PROJECTION_DID_NOT_DENY '+(denyError||'no error'));

      const {data:threadRows,error:threadErr}=await unrelated.client
        .from('class_learner_threads').select('id').eq('class_id',cls.class_id).eq('learner_id',self.learner_id);
      if(threadErr)throw threadErr;
      assert(Array.isArray(threadRows)&&threadRows.length===0,'UNRELATED_RLS_LEAKED_THREAD');

      const unrelatedBrowser=await signInBrowser(browser,unrelated.email,passwords.unrelated);
      await unrelatedBrowser.page.goto(report.notification_deep_link,{waitUntil:'domcontentloaded'});
      await unrelatedBrowser.page.getByText('Class conversation unavailable',{exact:true}).waitFor({timeout:30000});
      const deniedBody=await unrelatedBrowser.page.locator('body').innerText();
      assert(!deniedBody.includes(messageBody),'UNRELATED_BROWSER_LEAKED_MESSAGE_BODY');
      assert(!deniedBody.includes(self.display_name),'UNRELATED_BROWSER_LEAKED_LEARNER_NAME');
      assert(!deniedBody.includes(report.ids.class_title),'UNRELATED_BROWSER_LEAKED_CLASS_TITLE');
      await unrelatedBrowser.page.screenshot({path:path.join(ARTIFACT_DIR,'r4-unrelated-safe-denial.png'),fullPage:true});
      await unrelatedBrowser.ctx.close();
      report.checks.push({check:'unrelated_projection_rls_and_browser_denied',pass:true});
    }finally{await browser.close();}

    const after=await rpc(learner.client,'get_class_learner_thread',{p_class_id:cls.class_id,p_learner_id:self.learner_id});
    const exactMessages=(after.messages||[]).filter(m=>m.message_id===report.ids.message_id&&m.body===messageBody);
    assert(after.thread_id===report.ids.thread_id,'THREAD_ID_MISMATCH');
    assert(exactMessages.length===1,'MESSAGE_CARDINALITY_'+exactMessages.length);
    report.checks.push({check:'single_thread_single_exact_message_server_verified',pass:true});

    report.result='pass';
    report.deep_link_shape='#/class-thread?class_id=<opaque-uuid>&learner_id=<opaque-uuid>';
    fs.writeFileSync(path.join(ARTIFACT_DIR,'r4-class-thread-proof.json'),JSON.stringify(report,null,2));
    console.log('RAAHI_R4_CLASS_THREAD_PROOF_PASS run_id='+rid+' commit='+sha);
  }catch(error){
    report.result='fail';
    report.failure={message:safeError(error),class:'to-classify'};
    fs.writeFileSync(path.join(ARTIFACT_DIR,'r4-class-thread-proof.json'),JSON.stringify(report,null,2));
    throw error;
  }finally{
    for(const s of Object.values(sessions)){try{await s.client.auth.signOut();}catch(_){}}
  }
}

await main();
