import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
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
const ARTIFACT_DIR=path.resolve('artifacts-ui-convergence-parent-org');

const ROUTES=[
  {route:'home',actor:'parent',fixtureRole:'parent'},
  {route:'explore',actor:'parent',fixtureRole:'parent'},
  {route:'classes',actor:'parent',fixtureRole:'parent'},
  {route:'notifications',actor:'parent',fixtureRole:'parent'},
  {route:'learners',actor:'parent',fixtureRole:'parent'},
  {route:'community',actor:'parent',fixtureRole:'parent'},
  {route:'messages',actor:'parent',fixtureRole:'parent'},
  {route:'settings',actor:'parent',fixtureRole:'parent'},
  {route:'org-home',actor:'org',fixtureRole:'institute'},
  {route:'org-profile',actor:'org',fixtureRole:'institute'},
  {route:'org-teaching',actor:'org',fixtureRole:'institute'},
  {route:'org-members',actor:'org',fixtureRole:'institute'}
];

const VIEWPORTS=[
  {name:'desktop',width:1440,height:900},
  {name:'mobile',width:390,height:844}
];

function assert(v,m){if(!v)throw new Error(m);}
function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
function pwd(){return crypto.randomBytes(30).toString('base64url')+'Aa1!';}
function rid(){return 'ui2-'+(process.env.GITHUB_RUN_ID||Date.now())+'-'+(process.env.GITHUB_RUN_ATTEMPT||'1');}
function errText(e){return e?.message||e?.details||e?.hint||String(e);}

function staticCompatible(deployedSha,targetSha){
  if(deployedSha===targetSha)return {compatible:true,exact:true,changed:[],appChanges:[]};
  try{
    const changed=execFileSync('git',['diff','--name-only',deployedSha,targetSha],{encoding:'utf8'})
      .split(/\r?\n/).map(x=>x.trim()).filter(Boolean);
    const appChanges=changed.filter(x=>x.startsWith('apps/raahi-learning/'));
    return {compatible:appChanges.length===0,exact:false,changed,appChanges};
  }catch{
    return {compatible:false,exact:false,changed:[],appChanges:['unknown-history']};
  }
}

async function waitDeployment(sha){
  const deadline=Date.now()+8*60*1000;let last=null;
  while(Date.now()<deadline){
    try{
      const r=await fetch(DEV_ORIGIN+'/build-meta.json?ui2='+Date.now(),{cache:'no-store'});
      if(r.ok){
        const meta=await r.json();
        const compatibility=staticCompatible(meta.commit_sha,sha);
        last={...meta,compatibility};
        if(compatibility.compatible)return last;
      }
    }catch(e){last={error:String(e)}}
    await sleep(10000);
  }
  throw new Error('DEV_DEPLOYMENT_NOT_SOURCE_COMPATIBLE expected='+sha+' last='+JSON.stringify(last));
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

function client(){
  return createClient(SUPABASE_URL,PUBLISHABLE_KEY,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
}
async function rpc(c,n,a={}){const {data,error}=await c.rpc(n,a);if(error)throw error;return data;}
async function boot(c,name){
  try{return await rpc(c,'get_my_account_context');}
  catch(e){if(!/ACCOUNT_NOT_FOUND/i.test(errText(e)))throw e;await rpc(c,'bootstrap_account',{p_display_name:name});return rpc(c,'get_my_account_context');}
}

async function authBrowser(browser,email,password,viewport){
  const ctx=await browser.newContext({viewport:{width:viewport.width,height:viewport.height}});
  const page=await ctx.newPage();
  await page.goto(DEV_ORIGIN+'/dev-test-login-v13.html',{waitUntil:'domcontentloaded'});
  await page.getByText('RAAHI_DEV_TEST_LOGIN_V13').waitFor({timeout:30000});
  await page.locator('#email').fill(email);await page.locator('#password').fill(password);await page.locator('#signin').click();
  await page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/home',{timeout:30000});
  await page.waitForTimeout(800);
  return {ctx,page};
}

async function chooseRole(page,role){
  const select=page.locator('[data-live-role-select]').first();
  await select.waitFor({state:'visible',timeout:15000});
  const values=await select.locator('option').evaluateAll(xs=>xs.map(x=>x.value));
  const candidates=role==='parent'?['parent','learner']:[role];
  const candidate=candidates.find(x=>values.includes(x));
  assert(candidate,'AUTHORIZED_WORKSPACE_OPTION_MISSING_'+role+' options='+values.join(','));
  await select.selectOption(candidate);
  const expected=candidate==='institute'?'org-home':'home';
  await page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/'+expected,{timeout:15000});
  await page.waitForTimeout(900);
  assert((await select.inputValue())===candidate,'AUTHORIZED_WORKSPACE_SELECTION_DID_NOT_STICK_'+candidate);
  return candidate;
}

async function fixtureMetrics(browser,item,viewport){
  const ctx=await browser.newContext({viewport:{width:viewport.width,height:viewport.height}});
  const page=await ctx.newPage();
  await page.goto(DEV_ORIGIN+'/?fixture=1#/'+item.route,{waitUntil:'domcontentloaded'});
  await page.locator('h1').first().waitFor({timeout:30000});
  if((await page.locator('h1').first().innerText()).trim()==='Switch workspace'){
    const label=item.fixtureRole==='institute'?'Institute':'Parent / Guardian';
    const switcher=page.getByRole('button',{name:label}).first();
    assert(await switcher.count(),'FIXTURE_WORKSPACE_SWITCH_MISSING_'+item.fixtureRole);
    await switcher.click();
    await page.waitForTimeout(150);
    await page.goto(DEV_ORIGIN+'/?fixture=1#/'+item.route,{waitUntil:'domcontentloaded'});
    await page.locator('h1').first().waitFor({timeout:30000});
  }
  const m=await page.evaluate(()=>{
    const box=s=>{const e=document.querySelector(s);if(!e)return null;const r=e.getBoundingClientRect(),cs=getComputedStyle(e);return {x:r.x,y:r.y,w:r.width,h:r.height,display:cs.display}};
    const h1=document.querySelector('h1');
    return {
      title:h1?.textContent?.trim()||'',
      overflow:document.documentElement.scrollWidth>window.innerWidth+1,
      topbar:box('.topbar'),sidebar:box('.sidebar'),main:box('.main'),rightbar:box('.rightbar'),mobileNav:box('.mobile-nav'),
      h1Font:h1?getComputedStyle(h1).fontSize:null,
      bodyBg:getComputedStyle(document.body).backgroundColor
    };
  });
  await ctx.close();return m;
}

async function liveMetrics(page,item){
  await page.goto(DEV_ORIGIN+'/#/'+item.route,{waitUntil:'domcontentloaded'});
  await page.locator('h1').first().waitFor({timeout:30000});
  await page.waitForTimeout(700);
  return page.evaluate(()=>{
    const box=s=>{const e=document.querySelector(s);if(!e)return null;const r=e.getBoundingClientRect(),cs=getComputedStyle(e);return {x:r.x,y:r.y,w:r.width,h:r.height,display:cs.display}};
    const h1=document.querySelector('h1'),body=document.body.innerText;
    return {
      title:h1?.textContent?.trim()||'',
      overflow:document.documentElement.scrollWidth>window.innerWidth+1,
      denied:/Switch workspace|does not currently have access|unavailable/i.test(body),
      topbar:box('.topbar'),sidebar:box('.sidebar'),main:box('.main'),rightbar:box('.rightbar'),mobileNav:box('.mobile-nav'),
      h1Font:h1?getComputedStyle(h1).fontSize:null,
      bodyBg:getComputedStyle(document.body).backgroundColor
    };
  });
}

function visible(b){return !!b&&b.display!=='none'&&b.w>0&&b.h>0;}
function close(a,b,t=3){return Math.abs((a??0)-(b??0))<=t;}
function compare(gold,live,item){
  const issues=[];
  if(item.route==='community'){
    if(!/ Community$/.test(live.title))issues.push('community title missing Location prefix: '+JSON.stringify(live.title));
  }else if(item.route==='org-home'){
    if(!live.title || live.title==='Switch workspace')issues.push('organization home title invalid: '+JSON.stringify(live.title));
  }else if(gold.title!==live.title)issues.push('title expected='+JSON.stringify(gold.title)+' actual='+JSON.stringify(live.title));
  if(live.overflow)issues.push('horizontal overflow');
  if(live.denied)issues.push('unexpected access/guard page');
  if(gold.h1Font!==live.h1Font)issues.push('h1 font '+gold.h1Font+' vs '+live.h1Font);
  if(gold.bodyBg!==live.bodyBg)issues.push('body background mismatch');
  for(const k of ['topbar','sidebar','rightbar','mobileNav'])if(visible(gold[k])!==visible(live[k]))issues.push(k+' visibility mismatch');
  if(visible(gold.topbar)&&visible(live.topbar)&&!close(gold.topbar.h,live.topbar.h,1))issues.push('topbar height mismatch');
  if(visible(gold.main)&&visible(live.main)&&!close(gold.main.x,live.main.x,3))issues.push('main x mismatch '+gold.main.x+' vs '+live.main.x);
  return issues;
}

async function main(){
  assert(new URL(SUPABASE_URL).hostname.split('.')[0]===PROJECT_REF,'PROJECT_GUARD');
  assert(process.env.GITHUB_REF==='refs/heads/raahi-learning-implementation-v1','BRANCH_GUARD');
  fs.mkdirSync(ARTIFACT_DIR,{recursive:true});
  const run=rid(),sha=process.env.GITHUB_SHA||'unknown';
  const report={proof:'ui-convergence-parent-org-v1',run_id:run,commit_sha:sha,deployment:null,checks:[],routes:[],result:'running'};
  const sessions={};

  try{
    report.deployment=await waitDeployment(sha);
    const token=await oidc();
    const passwords={parent:pwd(),org_owner:pwd(),unrelated:pwd(),staff:pwd()};
    const ensured=await edge(token,{action:'ensure_personas',suite:'ui2',run_id:run,passwords});
    const specs=Object.fromEntries(ensured.personas.map(x=>[x.key,x]));

    for(const key of ['parent','org_owner']){
      const c=client();
      const {data,error}=await c.auth.signInWithPassword({email:specs[key].email,password:passwords[key]});if(error)throw error;
      assert(data.session,'SESSION_MISSING_'+key);
      const ac=await boot(c,key==='parent'?'UI2 E2E Parent':'UI2 E2E Organization Owner');
      sessions[key]={client:c,spec:specs[key],account:ac};
    }

    let pc=await rpc(sessions.parent.client,'get_my_account_context');
    let managed=pc.learners?.find(x=>x.access_type==='manage'&&x.status!=='ended');
    if(!managed){
      await rpc(sessions.parent.client,'create_learner',{
        p_display_name:'UI2 Managed Learner',p_access_type:'manage',p_avatar_type:'none',p_avatar_ref:null,p_idempotency_key:run+'-managed'
      });
      pc=await rpc(sessions.parent.client,'get_my_account_context');
      managed=pc.learners.find(x=>x.access_type==='manage');
    }
    assert(managed?.learner_id,'MANAGED_LEARNER_MISSING');
    await rpc(sessions.parent.client,'set_selected_location',{p_location_id:DHANBAD_LOCATION_ID,p_idempotency_key:run+'-parent-location'});

    let oc=await rpc(sessions.org_owner.client,'get_my_account_context');
    let org=oc.organizations?.[0]||null;
    if(!org){
      const created=await rpc(sessions.org_owner.client,'create_organization',{
        p_organization_type:'coaching',
        p_name:'UI2 Learning Centre',
        p_description:'DEV UI convergence organization',
        p_public_contact_text:'DEV only',
        p_venue_text:'Dhanbad',
        p_website_url:null,
        p_logo_type:'none',
        p_logo_ref:null,
        p_idempotency_key:run+'-org'
      });
      oc=await rpc(sessions.org_owner.client,'get_my_account_context');
      org=oc.organizations?.find(x=>x.organization_id===created.organization_id)||oc.organizations?.[0]||null;
    }
    assert(org?.organization_id,'ORGANIZATION_MISSING');
    await rpc(sessions.org_owner.client,'set_selected_location',{p_location_id:DHANBAD_LOCATION_ID,p_idempotency_key:run+'-org-location'});
    const workspace=await rpc(sessions.org_owner.client,'get_organization_workspace',{p_organization_id:org.organization_id});
    assert(workspace?.organization?.organization_id===org.organization_id,'ORG_WORKSPACE_MISSING');
    report.ids={managed_learner_id:managed.learner_id,organization_id:org.organization_id};
    report.checks.push({check:'canonical_parent_and_org_setup',pass:true});

    const browser=await chromium.launch({headless:true});
    try{
      for(const viewport of VIEWPORTS){
        const parent=await authBrowser(browser,sessions.parent.spec.email,passwords.parent,viewport);
        const orgb=await authBrowser(browser,sessions.org_owner.spec.email,passwords.org_owner,viewport);
        const parentLiveRole=await chooseRole(parent.page,'parent');
        const orgLiveRole=await chooseRole(orgb.page,'institute');
        report.checks.push({check:'live_workspace_mapping_'+viewport.name,pass:true,parent_live_role:parentLiveRole,org_live_role:orgLiveRole});

        for(const item of ROUTES){
          const gold=await fixtureMetrics(browser,item,viewport);
          const live=await liveMetrics(item.actor==='parent'?parent.page:orgb.page,item);
          const issues=compare(gold,live,item);
          report.routes.push({viewport:viewport.name,route:item.route,actor:item.actor,gold_title:gold.title,live_title:live.title,issues});
          await (item.actor==='parent'?parent.page:orgb.page).screenshot({path:path.join(ARTIFACT_DIR,viewport.name+'-'+item.route+'.png'),fullPage:true});
        }
        await parent.ctx.close();await orgb.ctx.close();
      }
    }finally{await browser.close();}

    const endMetaResponse=await fetch(DEV_ORIGIN+'/build-meta.json?ui-end='+Date.now(),{cache:'no-store'});
    assert(endMetaResponse.ok,'DEV_DEPLOYMENT_END_CHECK_FAILED_'+endMetaResponse.status);
    const endMeta=await endMetaResponse.json();
    const endCompatibility=staticCompatible(endMeta.commit_sha,sha);
    assert(endCompatibility.compatible,'DEV_DEPLOYMENT_CHANGED_TO_INCOMPATIBLE_UI_SOURCE expected='+sha+' actual='+endMeta.commit_sha+' appChanges='+JSON.stringify(endCompatibility.appChanges));
    report.end_deployment={...endMeta,compatibility:endCompatibility};

    const issues=report.routes.flatMap(x=>x.issues.map(issue=>({viewport:x.viewport,route:x.route,issue})));
    report.issue_count=issues.length;report.issues=issues;
    assert(issues.length===0,'UI_CONVERGENCE_ISSUES '+JSON.stringify(issues));
    report.result='pass';
    fs.writeFileSync(path.join(ARTIFACT_DIR,'ui-convergence-parent-org-proof.json'),JSON.stringify(report,null,2));
    console.log('RAAHI_UI_CONVERGENCE_PARENT_ORG_PASS run_id='+run+' commit='+sha);
  }catch(e){
    report.result='fail';report.failure={message:errText(e),class:'to-classify'};
    fs.writeFileSync(path.join(ARTIFACT_DIR,'ui-convergence-parent-org-proof.json'),JSON.stringify(report,null,2));
    throw e;
  }finally{
    for(const s of Object.values(sessions)){try{await s.client.auth.signOut();}catch(_){}}
  }
}

await main();
