import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { createClient } from '@supabase/supabase-js';
import { chromium } from 'playwright';

const DEV_ORIGIN='https://dev.learning.myraahi.co.in';
const SUPABASE_URL='https://iiwwmqokaeflaenhlyip.supabase.co';
const PROJECT_REF='iiwwmqokaeflaenhlyip';
const PUBLISHABLE_KEY='sb_publishable_bz0YgDXY-WkKxZnogGsfUg_Qgl7E-Wi';
const EDGE_URL=SUPABASE_URL+'/functions/v1/dev-test-identities';
const OIDC_AUDIENCE='raahi-learning-dev-test-harness';
const DHANBAD_LOCATION_ID='028ee066-2130-45d6-8e17-6ceb9b0f1f80';
const ARTIFACT_DIR=path.resolve('artifacts-class-race-recovery');
const KEYS=['learner','teacher','unrelated'];

function assert(value,message){if(!value)throw new Error(message);}
function sleep(ms){return new Promise(resolve=>setTimeout(resolve,ms));}
function errText(error){return error?.message||error?.details||error?.hint||String(error);}
function password(){return crypto.randomBytes(30).toString('base64url')+'Aa1!';}
function runId(){return 'classrace-'+(process.env.GITHUB_RUN_ID||Date.now())+'-'+(process.env.GITHUB_RUN_ATTEMPT||'1');}
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
      const response=await fetch(DEV_ORIGIN+'/build-meta.json?classrace='+Date.now(),{cache:'no-store'});
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
  const response=await fetch(DEV_ORIGIN+'/build-meta.json?classrace-end='+Date.now(),{cache:'no-store'});
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

async function main(){
  assert(new URL(SUPABASE_URL).hostname===PROJECT_REF+'.supabase.co','PROJECT_GUARD');
  assert(process.env.GITHUB_REF==='refs/heads/raahi-learning-implementation-v1','BRANCH_GUARD');
  fs.mkdirSync(ARTIFACT_DIR,{recursive:true});
  const run=runId(),sha=process.env.GITHUB_SHA;
  const report={proof:'class-race-recovery-v3',run_id:run,commit_sha:sha,checks:[],ids:{},result:'running'};
  const sessions={};
  try{
    report.deployment=await waitDeployment(sha);
    const passwords=Object.fromEntries(KEYS.map(k=>[k,password()]));
    const ensured=await edge(await oidc(),{action:'ensure_personas',suite:'sidefx_test',run_id:run,passwords});
    for(const spec of ensured.personas){
      const c=client();const {error}=await c.auth.signInWithPassword({email:spec.email,password:passwords[spec.key]});
      if(error)throw error;
      sessions[spec.key]={client:c,email:spec.email,password:passwords[spec.key],context:await bootstrap(c,'DEV race '+spec.key)};
    }
    const t=sessions.teacher.client;
    await rpc(t,'enable_teaching',{p_idempotency_key:run+'-enable'});
    await rpc(t,'upsert_teacher_profile',{p_headline:'DEV Mathematics race proof',p_bio:'Isolated DEV proof',p_experience_summary:'Automated proof',p_visibility_status:'visible',p_idempotency_key:run+'-profile'});
    const option=await rpc(t,'publish_teaching_option',{p_organization_id:null,p_title:'Race Mathematics '+run,p_category:'Mathematics',p_description:'Isolated DEV race proof',p_teaching_mode:'both',p_area_or_venue_text:'Dhanbad',p_fee_display_text:'DEV proof — no payment collected',p_location_ids:[DHANBAD_LOCATION_ID],p_idempotency_key:run+'-option'});
    for(const k of ['learner','unrelated']){
      const s=sessions[k];let self=s.context.learners?.find(x=>x.access_type==='self');
      if(!self){
        await rpc(s.client,'create_learner',{p_display_name:'DEV race '+k,p_access_type:'self',p_avatar_type:'none',p_avatar_ref:null,p_idempotency_key:run+'-'+k+'-self'});
        self=(await rpc(s.client,'get_my_account_context')).learners.find(x=>x.access_type==='self');
      }
      s.learner_id=self.learner_id;
      const enq=await rpc(s.client,'send_enquiry',{p_learner_id:self.learner_id,p_teaching_option_id:option.teaching_option_id,p_location_id:DHANBAD_LOCATION_ID,p_opening_message:null,p_idempotency_key:run+'-'+k+'-enquiry'});
      s.enquiry_id=enq.enquiry_id;
      await rpc(t,'engage_enquiry',{p_enquiry_id:enq.enquiry_id,p_idempotency_key:run+'-'+k+'-engage'});
    }
    const cls=await rpc(t,'create_class',{p_organization_id:null,p_responsible_teacher_account_id:sessions.teacher.context.account.account_id,p_location_id:DHANBAD_LOCATION_ID,p_title:'Race capacity '+run,p_class_type:'group',p_capacity:1,p_idempotency_key:run+'-class'});
    report.ids.class_id=cls.class_id;
    await rpc(t,'activate_class',{p_class_id:cls.class_id,p_idempotency_key:run+'-activate'});
    const contenders=['learner','unrelated'];
    const inviteArgs=k=>({p_class_id:cls.class_id,p_enquiry_id:sessions[k].enquiry_id,p_fee_display_text:'DEV proof — no payment collected',p_idempotency_key:run+'-'+k+'-invite'});
    const race=await Promise.all(contenders.map(k=>t.rpc('send_class_invitation',inviteArgs(k))));
    assert(race.filter(x=>!x.error).length===1,'LAST_SEAT_MUST_HAVE_ONE_WINNER');
    const winnerIndex=race.findIndex(x=>!x.error),loserIndex=1-winnerIndex;
    assert(/CLASS_CAPACITY_FULL/.test(errText(race[loserIndex].error)),'LAST_SEAT_UNEXPECTED_ERROR '+errText(race[loserIndex].error));
    const winner=sessions[contenders[winnerIndex]],loser=sessions[contenders[loserIndex]],inv=race[winnerIndex].data;
    report.ids.invitation_id=inv.invitation_id;report.ids.learner_id=winner.learner_id;
    report.checks.push('Two concurrent requests: exactly one pending invitation reserves the last seat');
    const denied=await loser.client.rpc('accept_class_invitation',{p_invitation_id:inv.invitation_id,p_idempotency_key:run+'-unauthorized'});
    assert(denied.error&&/NOT_AUTHORIZED/.test(errText(denied.error)),'UNAUTHORIZED_ACCEPTANCE_NOT_DENIED '+errText(denied.error));
    report.checks.push('Other learner cannot accept the winning invitation');
    const acceptArgs={p_invitation_id:inv.invitation_id,p_idempotency_key:run+'-accept'};
    // Commit the first acceptance, but discard its real response at the client boundary.
    // No result or session is fabricated; only the response delivery failure is simulated.
    let responseLost=false;
    try{await rpc(winner.client,'accept_class_invitation',acceptArgs);throw new Error('SIMULATED_POST_COMMIT_RESPONSE_LOSS');}
    catch(error){if(error.message!=='SIMULATED_POST_COMMIT_RESPONSE_LOSS')throw error;responseLost=true;}
    assert(responseLost,'FIRST_ACCEPT_RESPONSE_NOT_LOST');
    const recoveredClient=client();
    const recoveredLogin=await recoveredClient.auth.signInWithPassword({email:winner.email,password:winner.password});
    if(recoveredLogin.error)throw recoveredLogin.error;
    sessions.recovered={client:recoveredClient};
    const recoveredContext=await rpc(recoveredClient,'get_my_account_context');
    assert(recoveredContext.account.account_id===winner.context.account.account_id,'RECOVERY_CHANGED_ACCOUNT');
    const accepted=await Promise.all([rpc(winner.client,'accept_class_invitation',acceptArgs),rpc(recoveredClient,'accept_class_invitation',acceptArgs)]);
    assert(accepted[0].membership_id&&accepted[0].membership_id===accepted[1].membership_id,'DUPLICATE_ACCEPTANCE_MEMBERSHIP_MISMATCH');
    report.ids.membership_id=accepted[0].membership_id;
    report.checks.push('First acceptance response discarded after commit; fresh-client login and concurrent retries recover one membership');
    const lossArgs={...inviteArgs(contenders[winnerIndex])};
    const recovered=await rpc(t,'send_class_invitation',lossArgs);
    assert(recovered.invitation_id===inv.invitation_id,'LOST_RESPONSE_RETRY_CHANGED_INVITATION');
    report.checks.push('Same-key invitation retry returns original invitation');
    const fresh=await rpc(winner.client,'accept_class_invitation',{...acceptArgs,p_idempotency_key:run+'-accept-new-key'});
    assert(fresh.membership_id===accepted[0].membership_id&&fresh.already_accepted===true,'NEW_KEY_ACCEPTANCE_NOT_STABLE');
    const mismatch=await t.rpc('send_class_invitation',{...lossArgs,p_fee_display_text:'Changed request'});
    assert(mismatch.error&&/IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST/.test(errText(mismatch.error)),'CHANGED_PAYLOAD_KEY_REUSE_NOT_REJECTED');
    report.checks.push('Fresh-key acceptance stays stable; reused key with changed payload is rejected');
    for(const [table,expected] of [['class_invitations',inv.invitation_id],['class_memberships',accepted[0].membership_id]]){
      const {data,error}=await t.from(table).select('id,state').eq('class_id',cls.class_id);
      if(error)throw error;
      assert(data.length===1&&data[0].id===expected,'DUPLICATE_ROWS_'+table);
      report[table]=data;
    }
    const signals=await rpc(t,'get_my_notifications',{p_limit:200});
    assert(signals.filter(x=>x.notification_type==='class_invitation_accepted'&&x.source_id===inv.invitation_id).length===1,'ACCEPTED_NOTIFICATION_COUNT');
    report.checks.push('RLS reads show one invitation, one membership, one acceptance notification');
    const sample=[];
    for(let batch=0;batch<5;batch++){
      await Promise.all(Array.from({length:8},async()=>{
        const start=performance.now();
        const value=await rpc(recoveredClient,'accept_class_invitation',acceptArgs);
        assert(value.membership_id===accepted[0].membership_id,'BURST_DUPLICATE_MEMBERSHIP');
        sample.push(Math.round(performance.now()-start));
      }));
    }
    sample.sort((a,b)=>a-b);
    report.bounded_burst={requests:sample.length,concurrency:8,p50_ms:sample[Math.ceil(sample.length*.5)-1],p95_ms:sample[Math.ceil(sample.length*.95)-1],max_ms:sample.at(-1),scope:'same-account cached acceptance RPC; not production load certification'};
    report.checks.push('Forty cached acceptance retries at concurrency eight preserve the membership');
    const before=await winner.client.from('classes').select('id').eq('id',cls.class_id);
    if(before.error)throw before.error;
    assert(before.data.length===1,'WINNER_CLASS_NOT_VISIBLE_BEFORE_REMOVAL');
    const other=await loser.client.from('classes').select('id').eq('id',cls.class_id);
    if(other.error)throw other.error;
    assert(other.data.length===0,'OTHER_LEARNER_CLASS_LEAK');
    const privateBody='Private shared-device recovery message '+run;
    const message=await rpc(winner.client,'send_class_learner_message',{p_class_id:cls.class_id,p_learner_id:winner.learner_id,p_body:privateBody,p_idempotency_key:run+'-private-message'});
    report.ids.message_id=message.message_id;
    const browser=await chromium.launch({headless:true});
    let sharedPage;
    try{
      const context=await browser.newContext();
      const page=await context.newPage();
      sharedPage=page;
      async function login(tab,actor){
        await tab.goto(DEV_ORIGIN+'/dev-test-login-v13.html',{waitUntil:'domcontentloaded'});
        await tab.locator('#email').fill(actor.email);
        await tab.locator('#password').fill(actor.password);
        await tab.locator('#signin').click();
        await tab.waitForURL(u=>u.hash==='#/home',{timeout:30000});
      }
      await login(page,winner);
      const deepLink=DEV_ORIGIN+'/#/class-thread?class_id='+cls.class_id+'&learner_id='+winner.learner_id;
      await page.goto(deepLink,{waitUntil:'domcontentloaded'});
      await page.getByText(privateBody,{exact:true}).waitFor({timeout:30000});
      await page.reload({waitUntil:'domcontentloaded'});
      await page.getByText(privateBody,{exact:true}).waitFor({timeout:30000});
      report.checks.push('Private thread recovers after document reload with genuine persisted session');
      const second=await context.newPage();
      await second.goto(DEV_ORIGIN+'/#/settings',{waitUntil:'domcontentloaded'});
      await second.locator('[data-live-signout]').click();
      await page.waitForURL(u=>u.hash==='#/welcome',{timeout:30000});
      assert(!(await page.locator('body').innerText()).includes(privateBody),'CROSS_TAB_SIGNOUT_LEAK');
      await login(second,loser);
      await page.getByText(loser.context.account.display_name,{exact:true}).first().waitFor({timeout:30000});
      // Keep the first document alive: it must adopt the new account and reject its old link.
      await page.goto(deepLink,{waitUntil:'domcontentloaded'});
      await page.getByText('Class conversation unavailable',{exact:true}).waitFor({timeout:30000});
      assert(!(await page.locator('body').innerText()).includes(privateBody),'SHARED_DEVICE_OLD_MESSAGE_LEAK');
      await page.screenshot({path:path.join(ARTIFACT_DIR,'shared-device-denial.png'),fullPage:true});
      report.checks.push('Shared browser cross-tab signout hides private content; second-account sign-in rejects the old private link');
    }catch(error){
      if(sharedPage){
        report.shared_browser_diagnostic={url:sharedPage.url(),body:(await sharedPage.locator('body').innerText()).slice(0,6000)};
        await sharedPage.screenshot({path:path.join(ARTIFACT_DIR,'shared-device-failure.png'),fullPage:true});
      }
      throw error;
    }finally{await browser.close();}
    await rpc(t,'remove_learner_from_class',{p_membership_id:accepted[0].membership_id,p_reason:'DEV stale-session proof',p_idempotency_key:run+'-remove'});
    const after=await winner.client.from('classes').select('id').eq('id',cls.class_id);
    if(after.error)throw after.error;
    assert(after.data.length===0,'OLD_SESSION_RETAINS_REMOVED_CLASS_ACCESS');
    const deniedWrite=await winner.client.rpc('send_class_learner_message',{p_class_id:cls.class_id,p_learner_id:winner.learner_id,p_body:'Must not be stored after removal',p_idempotency_key:run+'-denied-message'});
    assert(deniedWrite.error&&/ACTIVE_MEMBERSHIP_REQUIRED/.test(errText(deniedWrite.error)),'REMOVED_MESSAGE_DENIAL_WRONG '+errText(deniedWrite.error));
    report.removed_write_error=errText(deniedWrite.error);
    const replay=await rpc(winner.client,'accept_class_invitation',acceptArgs);
    assert(replay.membership_id===accepted[0].membership_id,'POST_REMOVAL_REPLAY_CHANGED_MEMBERSHIP');
    const finalRows=await t.from('class_memberships').select('id,state').eq('class_id',cls.class_id);
    if(finalRows.error)throw finalRows.error;
    assert(finalRows.data.length===1&&finalRows.data[0].state==='removed','REPLAY_REACTIVATED_MEMBERSHIP');
    report.final_memberships=finalRows.data;
    report.checks.push('Removal immediately denies shared Class read and message write to the old session; cached acceptance cannot reactivate membership');
    report.deployment_end=await endDeploymentCheck(report.deployment,sha);
    report.result='passed';
  }catch(error){report.result='failed';report.error=errText(error);process.exitCode=1;}
  finally{
    fs.writeFileSync(path.join(ARTIFACT_DIR,'proof.json'),JSON.stringify(report,null,2));
    console.log(JSON.stringify(report,null,2));
    for(const s of Object.values(sessions))await s.client.auth.signOut().catch(()=>{});
  }
}
await main();
