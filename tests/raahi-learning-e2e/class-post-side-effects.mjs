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
const ARTIFACT_DIR=path.resolve('artifacts-sidefx-class-posts');
const KEYS=['learner','teacher','unrelated'];

function assert(v,m){if(!v)throw new Error(m);}
function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
function errText(e){return e?.message||e?.details||e?.hint||String(e);}
function pwd(){return crypto.randomBytes(30).toString('base64url')+'Aa1!';}
function rid(){return 'postfx-'+(process.env.GITHUB_RUN_ID||Date.now())+'-'+(process.env.GITHUB_RUN_ATTEMPT||'1');}
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
      const r=await fetch(DEV_ORIGIN+'/build-meta.json?postfx='+Date.now(),{cache:'no-store'});
      if(r.ok){last=await r.json();const compat=staticCompatible(last.commit_sha,sha);if(compat.compatible)return {...last,compatibility:compat};}
    }catch(e){last={error:String(e)}}
    await sleep(10000);
  }
  throw new Error('DEV_STATIC_DEPLOYMENT_NOT_COMPATIBLE expected='+sha+' last='+JSON.stringify(last));
}
async function endDeploymentCheck(startMeta,sha){
  const r=await fetch(DEV_ORIGIN+'/build-meta.json?postfx-end='+Date.now(),{cache:'no-store'});
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

async function setupClass(run,s){
  const {learner,teacher}=s;
  await rpc(teacher.client,'enable_teaching',{p_idempotency_key:run+'-enable'});
  await rpc(teacher.client,'upsert_teacher_profile',{
    p_headline:'Post SideFX Mathematics teacher',p_bio:'DEV Class post proof',p_experience_summary:'Automated proof',
    p_visibility_status:'visible',p_idempotency_key:run+'-profile'
  });
  const option=await rpc(teacher.client,'publish_teaching_option',{
    p_organization_id:null,p_title:'Post SideFX Mathematics '+run,p_category:'Mathematics',p_description:'DEV Class post proof',
    p_teaching_mode:'both',p_area_or_venue_text:'Dhanbad',p_fee_display_text:'DEV proof — no payment collected',
    p_location_ids:[DHANBAD_LOCATION_ID],p_idempotency_key:run+'-option'
  });
  let ctx=await rpc(learner.client,'get_my_account_context');
  let self=ctx.learners?.find(x=>x.access_type==='self');
  if(!self){
    await rpc(learner.client,'create_learner',{p_display_name:'Post SideFX Learner Profile',p_access_type:'self',p_avatar_type:'none',p_avatar_ref:null,p_idempotency_key:run+'-self'});
    ctx=await rpc(learner.client,'get_my_account_context');self=ctx.learners?.find(x=>x.access_type==='self');
  }
  assert(self?.learner_id,'SELF_LEARNER_MISSING');
  const enquiry=await rpc(learner.client,'send_enquiry',{
    p_learner_id:self.learner_id,p_teaching_option_id:option.teaching_option_id,p_location_id:DHANBAD_LOCATION_ID,p_opening_message:null,p_idempotency_key:run+'-enquiry'
  });
  await rpc(teacher.client,'engage_enquiry',{p_enquiry_id:enquiry.enquiry_id,p_idempotency_key:run+'-engage'});
  const title='Post SideFX One-to-One '+run;
  const cls=await rpc(teacher.client,'create_class',{
    p_organization_id:null,p_responsible_teacher_account_id:teacher.account_id,p_location_id:DHANBAD_LOCATION_ID,
    p_title:title,p_class_type:'one_to_one',p_capacity:1,p_idempotency_key:run+'-class'
  });
  await rpc(teacher.client,'activate_class',{p_class_id:cls.class_id,p_idempotency_key:run+'-activate'});
  const inv=await rpc(teacher.client,'send_class_invitation',{
    p_class_id:cls.class_id,p_enquiry_id:enquiry.enquiry_id,p_fee_display_text:'DEV proof — no payment collected',p_idempotency_key:run+'-invite'
  });
  const membership=await rpc(learner.client,'accept_class_invitation',{p_invitation_id:inv.invitation_id,p_idempotency_key:run+'-accept'});
  return {learner:self,class_id:cls.class_id,title,membership_id:membership.membership_id};
}

async function main(){
  assert(new URL(SUPABASE_URL).hostname.split('.')[0]===PROJECT_REF,'PROJECT_GUARD');
  assert(process.env.GITHUB_REF==='refs/heads/raahi-learning-implementation-v1','BRANCH_GUARD');
  fs.mkdirSync(ARTIFACT_DIR,{recursive:true});
  const run=rid(),sha=process.env.GITHUB_SHA||'unknown';
  const report={proof:'class-post-side-effects-v1',run_id:run,commit_sha:sha,deployment:null,checks:[],ids:{},result:'running'};
  const sessions={};
  try{
    report.deployment=await waitDeployment(sha);
    const token=await oidc();
    const passwords=Object.fromEntries(KEYS.map(k=>[k,pwd()]));
    const ensured=await edge(token,{action:'ensure_personas',suite:'sidefx_posts',run_id:run,passwords});
    const specs=Object.fromEntries(ensured.personas.map(x=>[x.key,x]));
    const names={learner:'Post SideFX E2E Learner',teacher:'Post SideFX E2E Teacher',unrelated:'Post SideFX E2E Unrelated'};
    for(const key of KEYS){
      const c=client();const {data,error}=await c.auth.signInWithPassword({email:specs[key].email,password:passwords[key]});if(error)throw error;
      const context=await boot(c,names[key]);
      sessions[key]={client:c,spec:specs[key],password:passwords[key],account_id:context.account.account_id,context};
    }
    const {learner,teacher,unrelated}=sessions;
    const fx=await setupClass(run,sessions);
    report.ids={learner_id:fx.learner.learner_id,class_id:fx.class_id,membership_id:fx.membership_id};

    const normalSecret='Ordinary provider body '+run;
    const normal=await rpc(teacher.client,'publish_class_post',{
      p_class_id:fx.class_id,p_learner_id:null,p_post_type:'update',p_body:normalSecret,p_importance:'normal',p_comments_enabled:true,p_idempotency_key:run+'-normal-provider'
    });
    await sleep(750);
    assert(matching(await notifications(learner.client),'class_announcement',n=>n.source_id===normal.class_post_id).length===0,'ORDINARY_PROVIDER_POST_PUSHED');
    report.checks.push({check:'ordinary_provider_post_refresh_only',pass:true});

    const announcementSecret='Private announcement body '+run;
    const announcementKey=run+'-announcement';
    const announcement=await rpc(teacher.client,'publish_class_post',{
      p_class_id:fx.class_id,p_learner_id:null,p_post_type:'announcement',p_body:announcementSecret,p_importance:'normal',p_comments_enabled:true,p_idempotency_key:announcementKey
    });
    let notices=await poll(learner.client,'class_announcement',n=>n.source_id===announcement.class_post_id,'CLASS_ANNOUNCEMENT');
    assert(notices.length===1,'CLASS_ANNOUNCEMENT_COUNT_'+notices.length);
    assert(!JSON.stringify(notices[0]).includes(announcementSecret),'CLASS_ANNOUNCEMENT_LEAKED_BODY');
    await rpc(teacher.client,'publish_class_post',{
      p_class_id:fx.class_id,p_learner_id:null,p_post_type:'announcement',p_body:announcementSecret,p_importance:'normal',p_comments_enabled:true,p_idempotency_key:announcementKey
    });
    notices=matching(await notifications(learner.client),'class_announcement',n=>n.source_id===announcement.class_post_id);
    assert(notices.length===1,'CLASS_ANNOUNCEMENT_RETRY_DUPLICATE_'+notices.length);
    report.ids.announcement_post_id=announcement.class_post_id;
    report.checks.push({check:'provider_announcement_notifies_learner_once_without_body',pass:true});

    const importantSecret='Private important update '+run;
    const important=await rpc(teacher.client,'publish_class_post',{
      p_class_id:fx.class_id,p_learner_id:null,p_post_type:'update',p_body:importantSecret,p_importance:'important',p_comments_enabled:true,p_idempotency_key:run+'-important'
    });
    const importantNotices=await poll(learner.client,'class_announcement',n=>n.source_id===important.class_post_id,'IMPORTANT_CLASS_UPDATE');
    assert(importantNotices.length===1,'IMPORTANT_CLASS_UPDATE_COUNT_'+importantNotices.length);
    assert(!JSON.stringify(importantNotices[0]).includes(importantSecret),'IMPORTANT_CLASS_UPDATE_LEAKED_BODY');
    report.checks.push({check:'provider_important_update_notifies_learner_once',pass:true});

    const learnerNormal=await rpc(learner.client,'publish_class_post',{
      p_class_id:fx.class_id,p_learner_id:fx.learner.learner_id,p_post_type:'update',p_body:'Learner ordinary update '+run,
      p_importance:'normal',p_comments_enabled:true,p_idempotency_key:run+'-learner-normal'
    });
    await sleep(750);
    assert(matching(await notifications(teacher.client),'class_question',n=>n.source_id===learnerNormal.class_post_id).length===0,'LEARNER_NORMAL_POST_PUSHED');
    report.checks.push({check:'learner_ordinary_post_refresh_only',pass:true});

    const questionSecret='Private learner question '+run;
    const questionKey=run+'-question';
    const question=await rpc(learner.client,'publish_class_post',{
      p_class_id:fx.class_id,p_learner_id:fx.learner.learner_id,p_post_type:'question',p_body:questionSecret,
      p_importance:'normal',p_comments_enabled:true,p_idempotency_key:questionKey
    });
    let qNotices=await poll(teacher.client,'class_question',n=>n.source_id===question.class_post_id,'CLASS_QUESTION');
    assert(qNotices.length===1,'CLASS_QUESTION_COUNT_'+qNotices.length);
    assert(!JSON.stringify(qNotices[0]).includes(questionSecret),'CLASS_QUESTION_LEAKED_BODY');
    await rpc(learner.client,'publish_class_post',{
      p_class_id:fx.class_id,p_learner_id:fx.learner.learner_id,p_post_type:'question',p_body:questionSecret,
      p_importance:'normal',p_comments_enabled:true,p_idempotency_key:questionKey
    });
    qNotices=matching(await notifications(teacher.client),'class_question',n=>n.source_id===question.class_post_id);
    assert(qNotices.length===1,'CLASS_QUESTION_RETRY_DUPLICATE_'+qNotices.length);
    report.ids.question_post_id=question.class_post_id;
    report.checks.push({check:'learner_question_notifies_provider_once_without_body',pass:true});

    const commentBefore=(await notifications(teacher.client)).filter(n=>/^class_/.test(n.notification_type||'')).length;
    await rpc(learner.client,'comment_on_class_post',{
      p_class_post_id:announcement.class_post_id,p_learner_id:fx.learner.learner_id,p_body:'No-push comment '+run,p_idempotency_key:run+'-comment'
    });
    await sleep(750);
    const commentAfter=(await notifications(teacher.client)).filter(n=>/^class_/.test(n.notification_type||'')).length;
    assert(commentAfter===commentBefore,'CLASS_COMMENT_CREATED_PUSH');
    report.checks.push({check:'class_post_comments_remain_explicit_no_push',pass:true});

    const browser=await chromium.launch({headless:true});
    try{
      const lb=await authBrowser(browser,learner.spec.email,learner.password);
      await chooseRole(lb.page,'learner');
      await lb.page.goto(DEV_ORIGIN+'/#/notifications',{waitUntil:'domcontentloaded'});
      const acard=lb.page.locator('.card').filter({hasText:'Class update'}).first();
      await acard.getByRole('button',{name:'Open'}).click();
      await lb.page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/class-detail',{timeout:15000});
      await lb.page.getByText(fx.title,{exact:true}).waitFor({timeout:15000});
      await lb.page.screenshot({path:path.join(ARTIFACT_DIR,'learner-announcement-open.png'),fullPage:true});
      await lb.ctx.close();

      const tb=await authBrowser(browser,teacher.spec.email,teacher.password);
      await chooseRole(tb.page,'teacher');
      await tb.page.goto(DEV_ORIGIN+'/#/notifications',{waitUntil:'domcontentloaded'});
      const qcard=tb.page.locator('.card').filter({hasText:'New learner question'}).first();
      await qcard.getByRole('button',{name:'Open'}).click();
      await tb.page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/teacher-class',{timeout:15000});
      await tb.page.getByText(fx.title,{exact:true}).waitFor({timeout:15000});
      await tb.page.screenshot({path:path.join(ARTIFACT_DIR,'teacher-question-open.png'),fullPage:true});
      await tb.ctx.close();
    }finally{await browser.close();}
    report.checks.push({check:'class_post_notification_open_reauthorizes_class',pass:true});

    let denied=null;
    try{await rpc(unrelated.client,'get_class_learning_overview',{p_class_id:fx.class_id,p_learner_id:fx.learner.learner_id});}catch(e){denied=errText(e);}
    assert(/NOT_AUTHORIZED/i.test(denied||''),'UNRELATED_CLASS_PROJECTION_NOT_DENIED_'+(denied||'none'));
    const unrelatedSignals=(await notifications(unrelated.client)).filter(n=>n.source_id===announcement.class_post_id||n.source_id===important.class_post_id||n.source_id===question.class_post_id);
    assert(unrelatedSignals.length===0,'UNRELATED_RECEIVED_CLASS_POST_NOTIFICATION');
    report.checks.push({check:'unrelated_account_receives_no_signal_and_projection_denied',pass:true});

    report.end_deployment=await endDeploymentCheck(report.deployment,sha);
    report.result='pass';
    fs.writeFileSync(path.join(ARTIFACT_DIR,'class-post-side-effects-proof.json'),JSON.stringify(report,null,2));
    console.log('RAAHI_CLASS_POST_SIDE_EFFECTS_PASS run_id='+run+' commit='+sha);
  }catch(e){
    report.result='fail';report.failure={message:errText(e),class:'to-classify'};
    fs.writeFileSync(path.join(ARTIFACT_DIR,'class-post-side-effects-proof.json'),JSON.stringify(report,null,2));
    throw e;
  }finally{
    for(const s of Object.values(sessions)){try{await s.client.auth.signOut();}catch(_){}}
  }
}
await main();
