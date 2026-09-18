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
const ARTIFACT_DIR=path.resolve('artifacts-sidefx-organization-authority');
const KEYS=['owner','member','unrelated'];

function assert(value,message){if(!value)throw new Error(message);}
function sleep(ms){return new Promise(resolve=>setTimeout(resolve,ms));}
function errText(error){return error?.message||error?.details||error?.hint||String(error);}
function password(){return crypto.randomBytes(30).toString('base64url')+'Aa1!';}
function runId(){return 'orgauthorityfx-'+(process.env.GITHUB_RUN_ID||Date.now())+'-'+(process.env.GITHUB_RUN_ATTEMPT||'1');}
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
      const response=await fetch(DEV_ORIGIN+'/build-meta.json?orgauthorityfx='+Date.now(),{cache:'no-store'});
      if(response.ok){last=await response.json();const compatibility=staticCompatible(last.commit_sha,sha);if(compatibility.compatible)return {...last,compatibility};}
    }catch(error){last={error:String(error)};}
    await sleep(10000);
  }
  throw new Error('DEV_STATIC_DEPLOYMENT_NOT_COMPATIBLE expected='+sha+' last='+JSON.stringify(last));
}
async function endDeploymentCheck(startMeta,sha){
  const response=await fetch(DEV_ORIGIN+'/build-meta.json?orgauthorityfx-end='+Date.now(),{cache:'no-store'});
  assert(response.ok,'DEV_DEPLOYMENT_END_CHECK_FAILED_'+response.status);
  const meta=await response.json();
  assert(meta.commit_sha===startMeta.commit_sha,'DEV_DEPLOYMENT_CHANGED_DURING_ORGANIZATION_AUTHORITY_PROOF start='+startMeta.commit_sha+' actual='+meta.commit_sha);
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
async function expectDenied(supabase,name,args,pattern='NOT_AUTHORIZED'){
  const {error}=await supabase.rpc(name,args);assert(error,'EXPECTED_RPC_DENIAL_'+name);
  assert(new RegExp(pattern,'i').test(errText(error)),'UNEXPECTED_RPC_DENIAL_'+name+'_'+errText(error));
  return errText(error);
}
async function bootstrap(supabase,name){
  try{return await rpc(supabase,'get_my_account_context');}
  catch(error){if(!/ACCOUNT_NOT_FOUND/i.test(errText(error)))throw error;await rpc(supabase,'bootstrap_account',{p_display_name:name});return rpc(supabase,'get_my_account_context');}
}
async function notifications(supabase){const rows=await rpc(supabase,'get_my_notifications',{p_limit:200});return Array.isArray(rows)?rows:[];}
function authoritySignals(rows,memberId,type){return rows.filter(row=>row.notification_type===type&&row.source_type==='organization_member'&&row.source_id===memberId);}
async function pollSignal(supabase,memberId,type){
  const deadline=Date.now()+30000;let signals=[];
  while(Date.now()<deadline){signals=authoritySignals(await notifications(supabase),memberId,type);if(signals.length)return signals;await sleep(500);}
  throw new Error(type.toUpperCase()+'_NOT_FOUND');
}
function assertGenericSignal(signal,{type,title,body,organizationId,memberId}){
  assert(signal.notification_type===type,'NOTIFICATION_TYPE_MISMATCH_'+signal.notification_type);
  assert(signal.title===title,'NOTIFICATION_TITLE_MISMATCH_'+signal.title);
  assert(signal.body===body,'NOTIFICATION_BODY_MISMATCH_'+signal.body);
  assert(signal.source_type==='organization_member'&&signal.source_id===memberId,'NOTIFICATION_SOURCE_MISMATCH');
  assert(signal.payload?.organization_id===organizationId&&signal.payload?.organization_member_id===memberId,'NOTIFICATION_PAYLOAD_IDS_MISMATCH');
  assert(Object.keys(signal.payload||{}).sort().join(',')==='organization_id,organization_member_id','NOTIFICATION_PAYLOAD_EXTRA_FIELDS_'+Object.keys(signal.payload||{}).sort().join(','));
  const serialized=JSON.stringify(signal);
  for(const forbidden of ['manage_profile','capability_code','"enabled"','reason','evidence']){
    assert(!serialized.includes(forbidden),'NOTIFICATION_PRIVATE_DETAIL_LEAK_'+forbidden);
  }
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
async function openNotification(page,notificationId,{reloadSession=false}={}){
  const destination=reloadSession
    ? DEV_ORIGIN+'/?orgauthorityfx='+Date.now()+'#/notifications'
    : DEV_ORIGIN+'/#/notifications';
  await page.goto(destination,{waitUntil:'domcontentloaded'});
  const button=page.locator(`[data-live-fix-open-organization-authority-notification="${notificationId}"]`);
  await button.waitFor({state:'visible',timeout:30000});
  await button.click();
}

async function main(){
  assert(new URL(SUPABASE_URL).hostname.split('.')[0]===PROJECT_REF,'PROJECT_GUARD');
  assert(process.env.GITHUB_REF==='refs/heads/raahi-learning-implementation-v1','BRANCH_GUARD');
  fs.mkdirSync(ARTIFACT_DIR,{recursive:true});
  const run=runId(),sha=process.env.GITHUB_SHA||'unknown';
  const report={proof:'organization-authority-side-effects-v1',run_id:run,commit_sha:sha,deployment:null,checks:[],ids:{},result:'running'};
  const sessions={};

  try{
    report.deployment=await waitDeployment(sha);
    const token=await oidc();
    const passwords=Object.fromEntries(KEYS.map(key=>[key,password()]));
    const ensured=await edge(token,{action:'ensure_personas',suite:'sidefx_org',run_id:run,passwords});
    const specs=Object.fromEntries(ensured.personas.map(persona=>[persona.key,persona]));
    const names={owner:'Organization SideFX E2E Owner',member:'Organization SideFX E2E Member',unrelated:'Organization SideFX E2E Unrelated'};
    for(const key of KEYS){
      const supabase=client();
      const {error}=await supabase.auth.signInWithPassword({email:specs[key].email,password:passwords[key]});
      if(error)throw error;
      const accountContext=await bootstrap(supabase,names[key]);
      sessions[key]={client:supabase,spec:specs[key],password:passwords[key],account_id:accountContext.account.account_id,context:accountContext};
    }
    const {owner,member,unrelated}=sessions;

    const organizationName='Authority SideFX Learning Centre '+run;
    const created=await rpc(owner.client,'create_organization',{
      p_organization_type:'coaching',p_name:organizationName,p_description:'DEV organization authority side-effect proof',
      p_public_contact_text:'DEV only',p_venue_text:'Dhanbad',p_website_url:null,p_logo_type:'none',p_logo_ref:null,
      p_idempotency_key:run+'-organization'
    });
    const organizationId=created.organization_id;
    const invitation=await rpc(owner.client,'issue_organization_member_invitation',{
      p_organization_id:organizationId,p_capability_codes:['manage_profile','manage_ads'],p_idempotency_key:run+'-invitation'
    });
    assert(invitation.secret_available&&invitation.invite_token,'ORGANIZATION_INVITATION_SECRET_MISSING');
    const accepted=await rpc(member.client,'accept_organization_member_invitation',{
      p_token:invitation.invite_token,p_idempotency_key:run+'-accept'
    });
    assert(accepted.state==='accepted'&&accepted.member_id,'ORGANIZATION_INVITATION_ACCEPT_FAILED');
    const memberId=accepted.member_id;
    report.ids={organization_id:organizationId,organization_member_id:memberId};

    let memberContext=await rpc(member.client,'get_my_account_context');
    let memberOrg=memberContext.organizations?.find(item=>item.organization_id===organizationId);
    assert([...(memberOrg?.capabilities||[])].sort().join(',')==='manage_ads,manage_profile','INITIAL_MEMBER_CAPABILITIES_MISMATCH');
    assert(!unrelated.context.organizations?.some(item=>item.organization_id===organizationId),'UNRELATED_INITIAL_ORGANIZATION_VISIBILITY');

    const browser=await chromium.launch({headless:true});
    let signedIn;
    try{
      signedIn=await authBrowser(browser,member.spec.email,member.password);

      const capabilityKey=run+'-disable-profile';
      const changed=await rpc(owner.client,'set_organization_member_capability',{
        p_organization_member_id:memberId,p_capability_code:'manage_profile',p_enabled:false,p_idempotency_key:capabilityKey
      });
      assert(changed.changed===true&&changed.enabled===false,'CAPABILITY_CHANGE_RESULT_MISMATCH');
      let changedSignals=await pollSignal(member.client,memberId,'organization_access_changed');
      assert(changedSignals.length===1,'CAPABILITY_CHANGE_NOTIFICATION_COUNT_'+changedSignals.length);
      assertGenericSignal(changedSignals[0],{
        type:'organization_access_changed',title:'Organization access updated',body:'Your access in an Organization was updated.',
        organizationId,memberId
      });
      const changedRetry=await rpc(owner.client,'set_organization_member_capability',{
        p_organization_member_id:memberId,p_capability_code:'manage_profile',p_enabled:false,p_idempotency_key:capabilityKey
      });
      assert(JSON.stringify(changedRetry)===JSON.stringify(changed),'CAPABILITY_CHANGE_RETRY_RESULT_MISMATCH');
      changedSignals=authoritySignals(await notifications(member.client),memberId,'organization_access_changed');
      assert(changedSignals.length===1,'CAPABILITY_CHANGE_RETRY_DUPLICATE_'+changedSignals.length);
      memberContext=await rpc(member.client,'get_my_account_context');
      memberOrg=memberContext.organizations?.find(item=>item.organization_id===organizationId);
      assert([...(memberOrg?.capabilities||[])].sort().join(',')==='manage_ads','CURRENT_CAPABILITY_PROJECTION_MISMATCH');
      report.checks.push({check:'capability_change_notifies_once_generically_and_exact_retry_is_idempotent',pass:true});

      await openNotification(signedIn.page,changedSignals[0].notification_id);
      await signedIn.page.waitForURL(url=>url.origin===DEV_ORIGIN&&url.hash==='#/org-home',{timeout:15000});
      await signedIn.page.getByRole('heading',{name:organizationName,exact:true}).waitFor({timeout:15000});
      await signedIn.page.waitForTimeout(1200);
      const liveCapabilityState=await signedIn.page.evaluate(({organizationId})=>({
        role:window.RaahiLearningCore?.state?.role,
        selectedOrganizationId:window.RaahiLearningLive?.selected?.organizationId,
        capabilities:(window.RaahiLearningLive?.context?.organizations||[]).find(item=>item.organization_id===organizationId)?.capabilities||[],
        workspaceOrganizationId:window.RaahiLearningLive?.data?.orgWorkspace?.organization?.organization_id||null
      }),{organizationId});
      assert(liveCapabilityState.role==='institute','CAPABILITY_NOTIFICATION_ROLE_NOT_INSTITUTE');
      assert(liveCapabilityState.selectedOrganizationId===organizationId&&liveCapabilityState.workspaceOrganizationId===organizationId,'CAPABILITY_NOTIFICATION_WRONG_WORKSPACE');
      assert([...liveCapabilityState.capabilities].sort().join(',')==='manage_ads','CAPABILITY_NOTIFICATION_USED_STALE_CAPABILITIES');
      await signedIn.page.screenshot({path:path.join(ARTIFACT_DIR,'member-capability-change-open.png'),fullPage:true});
      report.browser_capability_state=liveCapabilityState;
      report.checks.push({check:'capability_notification_open_rechecks_current_authority_and_loads_retained_workspace',pass:true});

      const removalKey=run+'-remove-member';
      const removed=await rpc(owner.client,'remove_organization_member',{
        p_organization_member_id:memberId,p_idempotency_key:removalKey
      });
      assert(removed.already_ended===false,'MEMBER_REMOVAL_RESULT_MISMATCH');
      let removedSignals=await pollSignal(member.client,memberId,'organization_membership_removed');
      assert(removedSignals.length===1,'MEMBER_REMOVAL_NOTIFICATION_COUNT_'+removedSignals.length);
      assertGenericSignal(removedSignals[0],{
        type:'organization_membership_removed',title:'Organization access ended',body:'Your access to an Organization has ended.',
        organizationId,memberId
      });
      const removedRetry=await rpc(owner.client,'remove_organization_member',{
        p_organization_member_id:memberId,p_idempotency_key:removalKey
      });
      assert(JSON.stringify(removedRetry)===JSON.stringify(removed),'MEMBER_REMOVAL_RETRY_RESULT_MISMATCH');
      removedSignals=authoritySignals(await notifications(member.client),memberId,'organization_membership_removed');
      assert(removedSignals.length===1,'MEMBER_REMOVAL_RETRY_DUPLICATE_'+removedSignals.length);
      const denial=await expectDenied(member.client,'get_organization_workspace',{p_organization_id:organizationId});
      memberContext=await rpc(member.client,'get_my_account_context');
      assert(!memberContext.organizations?.some(item=>item.organization_id===organizationId),'REMOVED_ORGANIZATION_STILL_IN_CONTEXT');
      report.removal_denial=denial;
      report.checks.push({check:'member_removal_revokes_server_projection_and_notifies_once_with_idempotent_retry',pass:true});

      // The browser session remains signed in and was showing this Organization before removal.
      // Its notification Open action must refresh current authority and fail safely.
      await openNotification(signedIn.page,removedSignals[0].notification_id,{reloadSession:true});
      await signedIn.page.waitForURL(url=>url.origin===DEV_ORIGIN&&url.hash==='#/home',{timeout:15000});
      await signedIn.page.getByText('Organization access is no longer available.',{exact:true}).waitFor({timeout:15000});
      await signedIn.page.waitForTimeout(1200);
      const liveRemovalState=await signedIn.page.evaluate(({organizationId})=>({
        role:window.RaahiLearningCore?.state?.role,
        selectedOrganizationId:window.RaahiLearningLive?.selected?.organizationId||null,
        hasOrganization:(window.RaahiLearningLive?.context?.organizations||[]).some(item=>item.organization_id===organizationId),
        hasWorkspace:!!window.RaahiLearningLive?.data?.orgWorkspace
      }),{organizationId});
      assert(liveRemovalState.role==='learner','REMOVAL_NOTIFICATION_UNSAFE_ROLE_'+liveRemovalState.role);
      assert(liveRemovalState.selectedOrganizationId===null&&!liveRemovalState.hasOrganization&&!liveRemovalState.hasWorkspace,'REMOVAL_NOTIFICATION_RETAINED_ORGANIZATION_STATE');
      await signedIn.page.screenshot({path:path.join(ARTIFACT_DIR,'member-removal-open-safe-home.png'),fullPage:true});
      report.browser_removal_state=liveRemovalState;
      report.checks.push({check:'stale_browser_session_notification_open_rechecks_and_fails_safely_after_removal',pass:true});
    }finally{
      if(signedIn)await signedIn.context.close();
      await browser.close();
    }

    const audit=await edge(token,{
      action:'inspect_organization_authority_audit',suite:'sidefx_org',run_id:run,organization_member_id:memberId
    });
    const audits=audit.audit_rows||[];
    assert(audits.length===2,'ORGANIZATION_AUTHORITY_AUDIT_COUNT_'+audits.length);
    const capabilityAudit=audits.find(row=>row.action_type==='organization.member_capability_change');
    const removalAudit=audits.find(row=>row.action_type==='organization.member_remove');
    assert(capabilityAudit&&removalAudit,'ORGANIZATION_AUTHORITY_AUDIT_ACTIONS_MISSING');
    for(const row of audits){
      assert(row.actor_account_id===owner.account_id,'ORGANIZATION_AUTHORITY_AUDIT_ACTOR_MISMATCH');
      assert(row.organization_id===organizationId&&row.target_id===memberId,'ORGANIZATION_AUTHORITY_AUDIT_TARGET_MISMATCH');
    }
    assert(capabilityAudit.metadata?.capability_code==='manage_profile'&&capabilityAudit.metadata?.enabled===false,'CAPABILITY_AUDIT_PRIVATE_METADATA_MISMATCH');
    assert(removalAudit.metadata?.account_id===member.account_id,'REMOVAL_AUDIT_PRIVATE_METADATA_MISMATCH');
    report.audit_rows=audits;
    report.checks.push({check:'audit_preserves_owner_actor_and_private_transition_detail_exactly_once',pass:true});

    const unrelatedSignals=(await notifications(unrelated.client)).filter(row=>row.source_type==='organization_member'&&row.source_id===memberId);
    assert(unrelatedSignals.length===0,'UNRELATED_RECEIVED_ORGANIZATION_AUTHORITY_SIGNAL');
    await expectDenied(unrelated.client,'get_organization_workspace',{p_organization_id:organizationId});
    const unrelatedContext=await rpc(unrelated.client,'get_my_account_context');
    assert(!unrelatedContext.organizations?.some(item=>item.organization_id===organizationId),'UNRELATED_ORGANIZATION_CONTEXT_VISIBILITY');
    report.checks.push({check:'unrelated_account_receives_no_signal_and_cannot_read_organization_workspace',pass:true});

    report.end_deployment=await endDeploymentCheck(report.deployment,sha);
    report.result='pass';
    fs.writeFileSync(path.join(ARTIFACT_DIR,'organization-authority-side-effects-proof.json'),JSON.stringify(report,null,2));
    console.log('RAAHI_ORGANIZATION_AUTHORITY_SIDE_EFFECTS_PASS run_id='+run+' commit='+sha);
  }catch(error){
    report.result='fail';report.failure={message:errText(error),class:'to-classify'};
    fs.writeFileSync(path.join(ARTIFACT_DIR,'organization-authority-side-effects-proof.json'),JSON.stringify(report,null,2));
    throw error;
  }finally{
    for(const session of Object.values(sessions)){try{await session.client.auth.signOut();}catch(_){}}
  }
}

main().catch(error=>{console.error(error);process.exit(1);});
