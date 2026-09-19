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
const ARTIFACT_DIR=path.resolve('artifacts-org-staff-capabilities');

function assert(v,m){if(!v)throw new Error(m);}
function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
function pwd(){return crypto.randomBytes(30).toString('base64url')+'Aa1!';}
function rid(){return 'ui4-staff-'+(process.env.GITHUB_RUN_ID||Date.now())+'-'+(process.env.GITHUB_RUN_ATTEMPT||'1');}
function errText(e){return e?.message||e?.details||e?.hint||String(e);}

function ensureGitCommit(sha){
  try{execFileSync('git',['cat-file','-e',sha+'^{commit}'],{stdio:'ignore'});}
  catch(_){execFileSync('git',['fetch','--quiet','origin',sha],{stdio:'ignore'});}
}
function staticCompatible(deployed,target){
  if(deployed===target)return {compatible:true,exact:true,changed:[],appChanges:[]};
  try{
    ensureGitCommit(deployed);ensureGitCommit(target);
    const changed=execFileSync('git',['diff','--name-only',deployed,target],{encoding:'utf8'})
      .split(/\r?\n/).map(value=>value.trim()).filter(Boolean);
    const appChanges=changed.filter(file=>file.startsWith('apps/raahi-learning/'));
    return {compatible:appChanges.length===0,exact:false,changed,appChanges};
  }catch(_){return {compatible:false,exact:false,changed:[],appChanges:['unknown-history']};}
}
async function waitDeployment(sha){
  const deadline=Date.now()+8*60*1000;let last=null;
  while(Date.now()<deadline){
    try{
      const r=await fetch(DEV_ORIGIN+'/build-meta.json?staff='+Date.now(),{cache:'no-store'});
      if(r.ok){
        last=await r.json();
        const compatibility=staticCompatible(last.commit_sha,sha);
        if(compatibility.compatible)return {...last,compatibility};
      }
    }catch(e){last={error:String(e)}}
    await sleep(10000);
  }
  throw new Error('DEV_STATIC_DEPLOYMENT_NOT_COMPATIBLE expected='+sha+' last='+JSON.stringify(last));
}
async function endDeploymentCheck(sha){
  const r=await fetch(DEV_ORIGIN+'/build-meta.json?staff-end='+Date.now(),{cache:'no-store'});
  assert(r.ok,'DEV_DEPLOYMENT_END_CHECK_FAILED_'+r.status);
  const m=await r.json();
  const compatibility=staticCompatible(m.commit_sha,sha);
  assert(compatibility.compatible,'DEV_STATIC_DEPLOYMENT_END_NOT_COMPATIBLE '+JSON.stringify(compatibility));
  return {...m,compatibility};
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
async function expectRpcDenied(c,n,a,pattern='NOT_AUTHORIZED'){
  const {error}=await c.rpc(n,a);
  assert(error,'EXPECTED_RPC_DENIAL_'+n);
  assert(new RegExp(pattern,'i').test(errText(error)),'UNEXPECTED_RPC_DENIAL_'+n+' '+errText(error));
  return errText(error);
}
async function boot(c,name){
  try{return await rpc(c,'get_my_account_context');}
  catch(e){if(!/ACCOUNT_NOT_FOUND/i.test(errText(e)))throw e;await rpc(c,'bootstrap_account',{p_display_name:name});return rpc(c,'get_my_account_context');}
}
function orgCaps(context,orgId){
  const o=context?.organizations?.find(x=>x.organization_id===orgId);
  return [...(o?.capabilities||[])].sort();
}

async function authBrowser(browser,email,password){
  const ctx=await browser.newContext({viewport:{width:390,height:844}});
  const page=await ctx.newPage();
  await page.goto(DEV_ORIGIN+'/dev-test-login-v13.html',{waitUntil:'domcontentloaded'});
  await page.getByText('RAAHI_DEV_TEST_LOGIN_V13').waitFor({timeout:30000});
  await page.locator('#email').fill(email);await page.locator('#password').fill(password);await page.locator('#signin').click();
  await page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/home',{timeout:30000});
  await page.waitForTimeout(900);
  return {ctx,page};
}
async function workspaceOptions(page){
  const select=page.locator('[data-live-role-select]').first();
  await select.waitFor({state:'visible',timeout:15000});
  return select.locator('option').evaluateAll(xs=>xs.map(x=>x.value));
}
async function selectRole(page,role){
  const select=page.locator('[data-live-role-select]').first();
  const values=await workspaceOptions(page);
  assert(values.includes(role),'WORKSPACE_OPTION_MISSING_'+role+' options='+values.join(','));
  await select.selectOption(role);
  const expected=role==='ads'?'ads-home':role==='institute'?'org-home':'home';
  await page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/'+expected,{timeout:15000});
  await page.waitForTimeout(900);
  assert((await select.inputValue())===role,'WORKSPACE_SELECTION_DID_NOT_STICK_'+role);
}
async function openRoute(page,route){
  await page.goto(DEV_ORIGIN+'/#/'+route,{waitUntil:'domcontentloaded'});
  await page.locator('h1').first().waitFor({timeout:30000});
  await page.waitForTimeout(700);
  return {
    title:(await page.locator('h1').first().innerText()).trim(),
    body:await page.locator('body').innerText(),
    overflow:await page.evaluate(()=>document.documentElement.scrollWidth>window.innerWidth+1)
  };
}

async function main(){
  assert(new URL(SUPABASE_URL).hostname.split('.')[0]===PROJECT_REF,'PROJECT_GUARD');
  assert(process.env.GITHUB_REF==='refs/heads/raahi-learning-implementation-v1','BRANCH_GUARD');
  fs.mkdirSync(ARTIFACT_DIR,{recursive:true});
  const run=rid(),sha=process.env.GITHUB_SHA||'unknown';
  const report={proof:'organization-staff-capability-boundaries-v1',run_id:run,commit_sha:sha,deployment:null,checks:[],browser:[],result:'running'};
  const sessions={};
  try{
    report.deployment=await waitDeployment(sha);
    const token=await oidc();
    const passwords={org_owner:pwd(),staff_profile:pwd(),staff_ads:pwd(),unrelated:pwd()};
    const ensured=await edge(token,{action:'ensure_personas',suite:'ui4_staff',run_id:run,passwords});
    const specs=Object.fromEntries(ensured.personas.map(x=>[x.key,x]));

    const bootstrapNames={
      org_owner:'UI4 Staff E2E Owner',
      staff_profile:'UI4 Staff E2E Profile',
      staff_ads:'UI4 Staff E2E Ads',
      unrelated:'UI4 Staff E2E Unrelated'
    };
    for(const key of Object.keys(passwords)){
      const c=client(); const {data,error}=await c.auth.signInWithPassword({email:specs[key].email,password:passwords[key]});if(error)throw error;
      assert(data.session,'SESSION_MISSING_'+key);
      const context=await boot(c,bootstrapNames[key]);
      sessions[key]={client:c,spec:specs[key],context,password:passwords[key]};
    }

    let ownerContext=sessions.org_owner.context;
    let org=ownerContext.organizations?.find(x=>(x.capabilities||[]).includes('manage_members'))||null;
    if(!org){
      const created=await rpc(sessions.org_owner.client,'create_organization',{
        p_organization_type:'coaching',p_name:'UI4 Capability Learning Centre',p_description:'DEV bounded staff capability proof',
        p_public_contact_text:'DEV only',p_venue_text:'Dhanbad',p_website_url:null,p_logo_type:'none',p_logo_ref:null,
        p_idempotency_key:run+'-org'
      });
      ownerContext=await rpc(sessions.org_owner.client,'get_my_account_context');
      org=ownerContext.organizations?.find(x=>x.organization_id===created.organization_id)||null;
    }
    assert(org?.organization_id,'OWNER_ORGANIZATION_MISSING');
    assert((org.capabilities||[]).includes('manage_members'),'OWNER_MANAGE_MEMBERS_MISSING');
    await rpc(sessions.org_owner.client,'set_selected_location',{p_location_id:DHANBAD_LOCATION_ID,p_idempotency_key:run+'-owner-loc'});

    const profileInvite=await rpc(sessions.org_owner.client,'issue_organization_member_invitation',{
      p_organization_id:org.organization_id,p_capability_codes:['manage_profile'],p_idempotency_key:run+'-profile-invite'
    });
    const adsInvite=await rpc(sessions.org_owner.client,'issue_organization_member_invitation',{
      p_organization_id:org.organization_id,p_capability_codes:['manage_ads'],p_idempotency_key:run+'-ads-invite'
    });
    assert(profileInvite.secret_available&&profileInvite.invite_token,'PROFILE_INVITE_TOKEN_MISSING');
    assert(adsInvite.secret_available&&adsInvite.invite_token,'ADS_INVITE_TOKEN_MISSING');

    const pAccept=await rpc(sessions.staff_profile.client,'accept_organization_member_invitation',{
      p_token:profileInvite.invite_token,p_idempotency_key:run+'-profile-accept'
    });
    const aAccept=await rpc(sessions.staff_ads.client,'accept_organization_member_invitation',{
      p_token:adsInvite.invite_token,p_idempotency_key:run+'-ads-accept'
    });
    assert(pAccept.state==='accepted'&&aAccept.state==='accepted','STAFF_ACCEPT_FAILED');

    sessions.staff_profile.context=await rpc(sessions.staff_profile.client,'get_my_account_context');
    sessions.staff_ads.context=await rpc(sessions.staff_ads.client,'get_my_account_context');
    sessions.unrelated.context=await rpc(sessions.unrelated.client,'get_my_account_context');

    const profileCaps=orgCaps(sessions.staff_profile.context,org.organization_id);
    const adsCaps=orgCaps(sessions.staff_ads.context,org.organization_id);
    assert(profileCaps.join(',')==='manage_profile','PROFILE_CAPABILITY_SCOPE_WRONG '+profileCaps.join(','));
    assert(adsCaps.join(',')==='manage_ads','ADS_CAPABILITY_SCOPE_WRONG '+adsCaps.join(','));
    assert(!sessions.unrelated.context.organizations?.some(x=>x.organization_id===org.organization_id),'UNRELATED_ORG_VISIBILITY');

    const deniedProfileInvite=await expectRpcDenied(sessions.staff_profile.client,'issue_organization_member_invitation',{
      p_organization_id:org.organization_id,p_capability_codes:['manage_members'],p_idempotency_key:run+'-forbidden-invite'
    });
    const deniedAdsProfile=await expectRpcDenied(sessions.staff_ads.client,'update_organization_profile',{
      p_organization_id:org.organization_id,p_name:'Forbidden',p_description:null,p_public_contact_text:null,p_venue_text:null,p_website_url:null,p_logo_type:'none',p_logo_ref:null,p_idempotency_key:run+'-forbidden-profile'
    });
    await expectRpcDenied(sessions.unrelated.client,'get_organization_workspace',{p_organization_id:org.organization_id});

    report.authority={
      organization_id:org.organization_id,
      profile_member_id:pAccept.member_id,
      ads_member_id:aAccept.member_id,
      profile_capabilities:profileCaps,
      ads_capabilities:adsCaps
    };
    report.checks.push({check:'canonical_invitation_acceptance',pass:true});
    report.checks.push({check:'exact_bounded_capabilities',pass:true});
    report.checks.push({check:'server_denials',pass:true,profile_invite_error:deniedProfileInvite,ads_profile_error:deniedAdsProfile});

    const browser=await chromium.launch({headless:true});
    try{
      const profile=await authBrowser(browser,sessions.staff_profile.spec.email,sessions.staff_profile.password);
      const ads=await authBrowser(browser,sessions.staff_ads.spec.email,sessions.staff_ads.password);
      const unrelated=await authBrowser(browser,sessions.unrelated.spec.email,sessions.unrelated.password);

      const profileOptions=await workspaceOptions(profile.page);
      assert(profileOptions.includes('institute'),'PROFILE_STAFF_INSTITUTE_WORKSPACE_MISSING');
      assert(!profileOptions.includes('ads'),'PROFILE_STAFF_ADS_WORKSPACE_LEAK');
      await selectRole(profile.page,'institute');

      let view=await openRoute(profile.page,'org-profile');
      assert(view.title==='Institute Profile'&&!/does not include manage_profile/i.test(view.body),'PROFILE_STAFF_PROFILE_DENIED');
      assert(!view.overflow,'PROFILE_STAFF_PROFILE_OVERFLOW');
      report.browser.push({actor:'staff_profile',route:'org-profile',allowed:true,title:view.title});

      view=await openRoute(profile.page,'org-teaching');
      assert(/does not include manage_teaching_options/i.test(view.body),'PROFILE_STAFF_TEACHING_NOT_DENIED');
      assert(!(await profile.page.locator('[data-live-new-option]').count()),'PROFILE_STAFF_TEACHING_ACTION_LEAK');
      report.browser.push({actor:'staff_profile',route:'org-teaching',allowed:false,title:view.title});

      view=await openRoute(profile.page,'org-members');
      assert(/does not include manage_members/i.test(view.body),'PROFILE_STAFF_MEMBERS_NOT_DENIED');
      assert(!(await profile.page.locator('[data-live-invite-org-member]').count()),'PROFILE_STAFF_MEMBER_ACTION_LEAK');
      report.browser.push({actor:'staff_profile',route:'org-members',allowed:false,title:view.title});

      const adsOptions=await workspaceOptions(ads.page);
      assert(adsOptions.includes('institute')&&adsOptions.includes('ads'),'ADS_STAFF_WORKSPACES_MISSING '+adsOptions.join(','));
      await selectRole(ads.page,'ads');
      view=await openRoute(ads.page,'ads-home');
      assert(view.title==='Raahi Ads'&&!/Workspace unavailable/i.test(view.body),'ADS_STAFF_ADS_HOME_DENIED');
      assert(!view.overflow,'ADS_STAFF_ADS_HOME_OVERFLOW');
      report.browser.push({actor:'staff_ads',route:'ads-home',allowed:true,title:view.title});

      view=await openRoute(ads.page,'ads-create');
      assert(view.title==='Create Campaign'&&!/Workspace unavailable/i.test(view.body),'ADS_STAFF_CREATE_DENIED');
      assert(!view.overflow,'ADS_STAFF_CREATE_OVERFLOW');
      report.browser.push({actor:'staff_ads',route:'ads-create',allowed:true,title:view.title});

      await selectRole(ads.page,'institute');
      view=await openRoute(ads.page,'org-profile');
      assert(/does not include manage_profile/i.test(view.body),'ADS_STAFF_PROFILE_NOT_DENIED');
      report.browser.push({actor:'staff_ads',route:'org-profile',allowed:false,title:view.title});

      const unrelatedSelect=unrelated.page.locator('[data-live-role-select]').first();
      const unrelatedOptions=await unrelatedSelect.count()
        ? await unrelatedSelect.locator('option').evaluateAll(xs=>xs.map(x=>x.value))
        : [];
      assert(!unrelatedOptions.includes('institute')&&!unrelatedOptions.includes('ads'),'UNRELATED_PRIVILEGED_WORKSPACE_LEAK '+unrelatedOptions.join(','));
      view=await openRoute(unrelated.page,'org-home');
      assert(/Workspace unavailable|Changing the URL cannot grant access/i.test(view.body),'UNRELATED_DEEP_LINK_NOT_DENIED');
      report.browser.push({actor:'unrelated',route:'org-home',allowed:false,title:view.title});

      await profile.page.screenshot({path:path.join(ARTIFACT_DIR,'staff-profile-final.png'),fullPage:true});
      await ads.page.screenshot({path:path.join(ARTIFACT_DIR,'staff-ads-final.png'),fullPage:true});
      await unrelated.page.screenshot({path:path.join(ARTIFACT_DIR,'unrelated-final.png'),fullPage:true});
      await profile.ctx.close();await ads.ctx.close();await unrelated.ctx.close();
    }finally{await browser.close();}

    report.end_deployment=await endDeploymentCheck(sha);
    report.result='pass';
    fs.writeFileSync(path.join(ARTIFACT_DIR,'organization-staff-capability-proof.json'),JSON.stringify(report,null,2));
    console.log('RAAHI_ORGANIZATION_STAFF_CAPABILITIES_PASS run_id='+run+' commit='+sha);
  }catch(e){
    report.result='fail';report.failure={message:errText(e),class:'to-classify'};
    fs.writeFileSync(path.join(ARTIFACT_DIR,'organization-staff-capability-proof.json'),JSON.stringify(report,null,2));
    throw e;
  }finally{
    for(const s of Object.values(sessions)){try{await s.client.auth.signOut();}catch(_){}}
  }
}
await main();
