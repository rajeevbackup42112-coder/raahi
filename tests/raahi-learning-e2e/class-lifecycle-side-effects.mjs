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
const ARTIFACT_DIR=path.resolve('artifacts-sidefx-class-lifecycle');
const KEYS=['learner','teacher','unrelated'];

function assert(v,m){if(!v)throw new Error(m);}
function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
function errText(e){return e?.message||e?.details||e?.hint||String(e);}
function pwd(){return crypto.randomBytes(30).toString('base64url')+'Aa1!';}
function rid(){return 'lifefx-'+(process.env.GITHUB_RUN_ID||Date.now())+'-'+(process.env.GITHUB_RUN_ATTEMPT||'1');}
function ensureGitCommit(sha){
  try{execFileSync('git',['cat-file','-e',sha+'^{commit}'],{stdio:'ignore'});}
  catch(_){execFileSync('git',['fetch','--quiet','origin',sha],{stdio:'ignore'});}
}
function staticCompatible(deployed,target){
  if(deployed===target)return {compatible:true,exact:true,changed:[],appChanges:[]};
  try{
    ensureGitCommit(deployed);ensureGitCommit(target);
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
      const r=await fetch(DEV_ORIGIN+'/build-meta.json?lifefx='+Date.now(),{cache:'no-store'});
      if(r.ok){last=await r.json();const compat=staticCompatible(last.commit_sha,sha);if(compat.compatible)return {...last,compatibility:compat};}
    }catch(e){last={error:String(e)}}
    await sleep(10000);
  }
  throw new Error('DEV_STATIC_DEPLOYMENT_NOT_COMPATIBLE expected='+sha+' last='+JSON.stringify(last));
}
async function endDeploymentCheck(startMeta,sha){
  const r=await fetch(DEV_ORIGIN+'/build-meta.json?lifefx-end='+Date.now(),{cache:'no-store'});
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
  const report={proof:'class-membership-lifecycle-side-effects-v1',run_id:run,commit_sha:sha,deployment:null,checks:[],ids:{},result:'running'};
  const sessions={};

  try{
    report.deployment=await waitDeployment(sha);
    const token=await oidc();
    const passwords=Object.fromEntries(KEYS.map(k=>[k,pwd()]));
    const ensured=await edge(token,{action:'ensure_personas',suite:'sidefx_lifecycle',run_id:run,passwords});
    const specs=Object.fromEntries(ensured.personas.map(x=>[x.key,x]));
    const names={learner:'Lifecycle E2E Learner',teacher:'Lifecycle E2E Teacher',unrelated:'Lifecycle E2E Unrelated'};
    for(const key of KEYS){
      const c=client();const {data,error}=await c.auth.signInWithPassword({email:specs[key].email,password:passwords[key]});if(error)throw error;
      const context=await boot(c,names[key]);
      sessions[key]={client:c,spec:specs[key],password:passwords[key],account_id:context.account.account_id,context};
    }
    const {learner,teacher,unrelated}=sessions;

    await rpc(teacher.client,'enable_teaching',{p_idempotency_key:run+'-enable'});
    await rpc(teacher.client,'upsert_teacher_profile',{
      p_headline:'Lifecycle Mathematics teacher',p_bio:'DEV Class lifecycle proof',p_experience_summary:'Automated proof',
      p_visibility_status:'visible',p_idempotency_key:run+'-profile'
    });
    const option=await rpc(teacher.client,'publish_teaching_option',{
      p_organization_id:null,p_title:'Lifecycle Mathematics '+run,p_category:'Mathematics',p_description:'DEV lifecycle proof',
      p_teaching_mode:'both',p_area_or_venue_text:'Dhanbad',p_fee_display_text:'DEV proof — no payment collected',
      p_location_ids:[DHANBAD_LOCATION_ID],p_idempotency_key:run+'-option'
    });

    let lctx=await rpc(learner.client,'get_my_account_context');
    let self=lctx.learners?.find(x=>x.access_type==='self');
    if(!self){
      await rpc(learner.client,'create_learner',{
        p_display_name:'Lifecycle Learner Profile',p_access_type:'self',p_avatar_type:'none',p_avatar_ref:null,p_idempotency_key:run+'-self'
      });
      lctx=await rpc(learner.client,'get_my_account_context');self=lctx.learners?.find(x=>x.access_type==='self');
    }
    assert(self?.learner_id,'SELF_LEARNER_MISSING');

    async function createClass(label,withMembership=true){
      let enquiry=null,invitation=null,membership=null;
      const title='Lifecycle '+label+' '+run;
      const cls=await rpc(teacher.client,'create_class',{
        p_organization_id:null,p_responsible_teacher_account_id:teacher.account_id,p_location_id:DHANBAD_LOCATION_ID,
        p_title:title,p_class_type:'one_to_one',p_capacity:1,p_idempotency_key:run+'-'+label+'-class'
      });
      const activationKey=run+'-'+label+'-activate';
      await rpc(teacher.client,'activate_class',{p_class_id:cls.class_id,p_idempotency_key:activationKey});
      if(withMembership){
        enquiry=await rpc(learner.client,'send_enquiry',{
          p_learner_id:self.learner_id,p_teaching_option_id:option.teaching_option_id,p_location_id:DHANBAD_LOCATION_ID,
          p_opening_message:null,p_idempotency_key:run+'-'+label+'-enquiry'
        });
        await rpc(teacher.client,'engage_enquiry',{p_enquiry_id:enquiry.enquiry_id,p_idempotency_key:run+'-'+label+'-engage'});
        invitation=await rpc(teacher.client,'send_class_invitation',{
          p_class_id:cls.class_id,p_enquiry_id:enquiry.enquiry_id,p_fee_display_text:'DEV proof — no payment collected',
          p_idempotency_key:run+'-'+label+'-invite'
        });
        membership=await rpc(learner.client,'accept_class_invitation',{
          p_invitation_id:invitation.invitation_id,p_idempotency_key:run+'-'+label+'-accept'
        });
        await rpc(learner.client,'close_enquiry',{
          p_enquiry_id:enquiry.enquiry_id,p_close_reason:'fixture_complete',p_idempotency_key:run+'-'+label+'-close-enquiry'
        });
      }
      return {class_id:cls.class_id,title,activationKey,enquiry_id:enquiry?.enquiry_id||null,invitation_id:invitation?.invitation_id||null,membership_id:membership?.membership_id||null};
    }

    const leaveFx=await createClass('Leave');
    const leaveKey=run+'-leave';
    await rpc(learner.client,'leave_class',{p_membership_id:leaveFx.membership_id,p_idempotency_key:leaveKey});
    let leftNotices=await poll(teacher.client,'class_membership_left',n=>n.source_id===leaveFx.membership_id,'CLASS_MEMBERSHIP_LEFT');
    assert(leftNotices.length===1,'CLASS_MEMBERSHIP_LEFT_COUNT_'+leftNotices.length);
    await rpc(learner.client,'leave_class',{p_membership_id:leaveFx.membership_id,p_idempotency_key:leaveKey});
    leftNotices=matching(await notifications(teacher.client),'class_membership_left',n=>n.source_id===leaveFx.membership_id);
    assert(leftNotices.length===1,'CLASS_MEMBERSHIP_LEFT_RETRY_DUPLICATE_'+leftNotices.length);
    report.checks.push({check:'learner_leave_notifies_provider_once',pass:true});

    const removeFx=await createClass('Remove');
    const removalReason='Private removal reason '+run;
    const removeKey=run+'-remove';
    await rpc(teacher.client,'remove_learner_from_class',{p_membership_id:removeFx.membership_id,p_reason:removalReason,p_idempotency_key:removeKey});
    let removedNotices=await poll(learner.client,'class_membership_removed',n=>n.source_id===removeFx.membership_id,'CLASS_MEMBERSHIP_REMOVED');
    assert(removedNotices.length===1,'CLASS_MEMBERSHIP_REMOVED_COUNT_'+removedNotices.length);
    assert(!JSON.stringify(removedNotices[0]).includes(removalReason),'REMOVAL_NOTIFICATION_LEAKED_REASON');
    await rpc(teacher.client,'remove_learner_from_class',{p_membership_id:removeFx.membership_id,p_reason:removalReason,p_idempotency_key:removeKey});
    removedNotices=matching(await notifications(learner.client),'class_membership_removed',n=>n.source_id===removeFx.membership_id);
    assert(removedNotices.length===1,'CLASS_MEMBERSHIP_REMOVED_RETRY_DUPLICATE_'+removedNotices.length);
    report.checks.push({check:'provider_remove_notifies_learner_once_without_reason',pass:true});

    const transferFx=await createClass('TransferSource');
    const destinationFx=await createClass('TransferDestination',false);
    const transferKey=run+'-transfer';
    const transferred=await rpc(learner.client,'transfer_learner',{
      p_source_membership_id:transferFx.membership_id,p_destination_class_id:destinationFx.class_id,p_idempotency_key:transferKey
    });
    assert(transferred.destination_membership_id,'TRANSFER_DESTINATION_MEMBERSHIP_MISSING');
    let transferProvider=await poll(teacher.client,'class_membership_transferred',n=>n.source_id===transferFx.membership_id,'CLASS_TRANSFER_PROVIDER');
    assert(transferProvider.length===1,'CLASS_TRANSFER_PROVIDER_COUNT_'+transferProvider.length);
    assert(transferProvider[0].payload?.source_class_id===transferFx.class_id,'TRANSFER_SOURCE_CLASS_CONTEXT_MISSING');
    assert(transferProvider[0].payload?.destination_class_id===destinationFx.class_id,'TRANSFER_DESTINATION_CLASS_CONTEXT_MISSING');
    const selfTransferSignals=matching(await notifications(learner.client),'class_membership_transferred',n=>n.source_id===transferFx.membership_id);
    assert(selfTransferSignals.length===0,'TRANSFER_SELF_NOTIFICATION_DUPLICATE_'+selfTransferSignals.length);
    await rpc(learner.client,'transfer_learner',{
      p_source_membership_id:transferFx.membership_id,p_destination_class_id:destinationFx.class_id,p_idempotency_key:transferKey
    });
    transferProvider=matching(await notifications(teacher.client),'class_membership_transferred',n=>n.source_id===transferFx.membership_id);
    assert(transferProvider.length===1,'CLASS_TRANSFER_RETRY_DUPLICATE_'+transferProvider.length);
    report.checks.push({check:'transfer_notifies_provider_once_and_avoids_actor_self_notification',pass:true});

    const completeFx=await createClass('Complete');
    const completeKey=run+'-complete';
    await rpc(teacher.client,'complete_class',{p_class_id:completeFx.class_id,p_idempotency_key:completeKey});
    let completeNotices=await poll(learner.client,'class_completed',n=>n.source_id===completeFx.membership_id,'CLASS_COMPLETED');
    assert(completeNotices.length===1,'CLASS_COMPLETED_COUNT_'+completeNotices.length);
    await rpc(teacher.client,'complete_class',{p_class_id:completeFx.class_id,p_idempotency_key:completeKey});
    completeNotices=matching(await notifications(learner.client),'class_completed',n=>n.source_id===completeFx.membership_id);
    assert(completeNotices.length===1,'CLASS_COMPLETED_RETRY_DUPLICATE_'+completeNotices.length);
    report.checks.push({check:'class_completion_notifies_learner_once',pass:true});

    await rpc(teacher.client,'activate_class',{p_class_id:completeFx.class_id,p_idempotency_key:completeFx.activationKey});
    report.checks.push({check:'class_activation_idempotent_replay_completed',pass:true});

    const audit=await edge(token,{
      action:'inspect_class_lifecycle_audit',suite:'sidefx_lifecycle',run_id:run,
      membership_ids:[leaveFx.membership_id,removeFx.membership_id,transferFx.membership_id],
      class_ids:[completeFx.class_id]
    });
    const rows=audit.audit_rows||[];
    const one=(action,target)=>{
      const xs=rows.filter(x=>x.action_type===action&&x.target_id===target);
      assert(xs.length===1,action+'_AUDIT_COUNT_'+xs.length+' target='+target);
      return xs[0];
    };
    assert(one('class.membership_leave',leaveFx.membership_id).actor_account_id===learner.account_id,'LEAVE_AUDIT_ACTOR_MISMATCH');
    assert(one('class.membership_remove',removeFx.membership_id).actor_account_id===teacher.account_id,'REMOVE_AUDIT_ACTOR_MISMATCH');
    assert(one('class.membership_transfer',transferFx.membership_id).actor_account_id===learner.account_id,'TRANSFER_AUDIT_ACTOR_MISMATCH');
    assert(one('class.activate',completeFx.class_id).actor_account_id===teacher.account_id,'ACTIVATE_AUDIT_ACTOR_MISMATCH');
    assert(one('class.complete',completeFx.class_id).actor_account_id===teacher.account_id,'COMPLETE_AUDIT_ACTOR_MISMATCH');
    report.audit_rows=rows;
    report.checks.push({check:'lifecycle_actor_audits_exactly_once',pass:true});

    const browser=await chromium.launch({headless:true});
    try{
      const tb=await authBrowser(browser,teacher.spec.email,teacher.password);
      await chooseRole(tb.page,'teacher');
      await tb.page.goto(DEV_ORIGIN+'/#/notifications',{waitUntil:'domcontentloaded'});
      const leftCard=tb.page.locator('.card').filter({hasText:'Learner left Class'}).first();
      await leftCard.getByRole('button',{name:'Open'}).click();
      await tb.page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/teacher-class',{timeout:15000});
      await tb.page.getByText(leaveFx.title,{exact:true}).waitFor({timeout:15000});
      await tb.page.screenshot({path:path.join(ARTIFACT_DIR,'provider-leave-open.png'),fullPage:true});

      await tb.page.goto(DEV_ORIGIN+'/#/notifications',{waitUntil:'domcontentloaded'});
      const transferCard=tb.page.locator('.card').filter({hasText:'Learner moved Class'}).first();
      await transferCard.getByRole('button',{name:'Open'}).click();
      await tb.page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/teacher-class',{timeout:15000});
      await tb.page.getByText(destinationFx.title,{exact:true}).waitFor({timeout:15000});
      await tb.page.screenshot({path:path.join(ARTIFACT_DIR,'provider-transfer-destination-open.png'),fullPage:true});
      await tb.ctx.close();

      const lb=await authBrowser(browser,learner.spec.email,learner.password);
      await chooseRole(lb.page,'learner');
      await lb.page.goto(DEV_ORIGIN+'/#/notifications',{waitUntil:'domcontentloaded'});
      const removedCard=lb.page.locator('.card').filter({hasText:'Removed from Class'}).first();
      await removedCard.getByRole('button',{name:'Open'}).click();
      await lb.page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/classes',{timeout:15000});
      await lb.page.getByText('My Classes',{exact:true}).waitFor({timeout:15000});
      await lb.page.screenshot({path:path.join(ARTIFACT_DIR,'learner-removed-safe-destination.png'),fullPage:true});

      await lb.page.goto(DEV_ORIGIN+'/#/notifications',{waitUntil:'domcontentloaded'});
      const completedCard=lb.page.locator('.card').filter({hasText:'Class completed'}).first();
      await completedCard.getByRole('button',{name:'Open'}).click();
      await lb.page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/class-detail',{timeout:15000});
      await lb.page.getByText(completeFx.title,{exact:true}).waitFor({timeout:15000});
      await lb.page.screenshot({path:path.join(ARTIFACT_DIR,'learner-completed-class-open.png'),fullPage:true});
      await lb.ctx.close();
    }finally{await browser.close();}
    report.checks.push({check:'lifecycle_notification_destinations_recheck_current_authority',pass:true});

    const completedOverview=await rpc(learner.client,'get_class_learning_overview',{p_class_id:completeFx.class_id,p_learner_id:self.learner_id});
    assert(completedOverview?.class?.state==='past','COMPLETED_CLASS_NOT_PAST');
    assert(completedOverview?.membership_state==='completed','COMPLETED_MEMBERSHIP_NOT_COMPLETED');

    let removedDenied=null;
    try{await rpc(learner.client,'get_class_learning_overview',{p_class_id:removeFx.class_id,p_learner_id:self.learner_id});}catch(e){removedDenied=errText(e);}
    assert(/NOT_AUTHORIZED/i.test(removedDenied||''),'REMOVED_LEARNER_CLASS_DETAIL_STILL_AUTHORIZED');

    let unrelatedDenied=null;
    try{await rpc(unrelated.client,'get_class_learning_overview',{p_class_id:completeFx.class_id,p_learner_id:self.learner_id});}catch(e){unrelatedDenied=errText(e);}
    assert(/NOT_AUTHORIZED/i.test(unrelatedDenied||''),'UNRELATED_COMPLETED_CLASS_NOT_DENIED');
    const unrelatedSignals=(await notifications(unrelated.client)).filter(n=>
      [leaveFx.membership_id,removeFx.membership_id,transferFx.membership_id,completeFx.membership_id].includes(n.source_id)
    );
    assert(unrelatedSignals.length===0,'UNRELATED_RECEIVED_LIFECYCLE_SIGNAL');
    report.checks.push({check:'ended_membership_and_unrelated_access_boundaries_hold',pass:true});

    report.ids={
      learner_id:self.learner_id,
      leave:leaveFx,
      remove:removeFx,
      transfer_source:transferFx,
      transfer_destination:{...destinationFx,membership_id:transferred.destination_membership_id},
      complete:completeFx
    };
    report.end_deployment=await endDeploymentCheck(report.deployment,sha);
    report.result='pass';
    fs.writeFileSync(path.join(ARTIFACT_DIR,'class-lifecycle-side-effects-proof.json'),JSON.stringify(report,null,2));
    console.log('RAAHI_CLASS_LIFECYCLE_SIDE_EFFECTS_PASS run_id='+run+' commit='+sha);
  }catch(e){
    report.result='fail';report.failure={message:errText(e),class:'to-classify'};
    fs.writeFileSync(path.join(ARTIFACT_DIR,'class-lifecycle-side-effects-proof.json'),JSON.stringify(report,null,2));
    throw e;
  }finally{
    for(const s of Object.values(sessions)){try{await s.client.auth.signOut();}catch(_){}}
  }
}
await main();
