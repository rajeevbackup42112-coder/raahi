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
const ARTIFACT_DIR=path.resolve('artifacts-ui-convergence-privileged');

const ROUTES=[
  {route:'manager-home',actor:'manager',fixtureRole:'manager',fixtureLabel:'Local Manager'},
  {route:'manager-people',actor:'manager',fixtureRole:'manager',fixtureLabel:'Local Manager'},
  {route:'manager-learning',actor:'manager',fixtureRole:'manager',fixtureLabel:'Local Manager'},
  {route:'manager-reports',actor:'manager',fixtureRole:'manager',fixtureLabel:'Local Manager'},
  {route:'manager-ads',actor:'manager',fixtureRole:'manager',fixtureLabel:'Local Manager'},
  {route:'manager-location',actor:'manager',fixtureRole:'manager',fixtureLabel:'Local Manager'},
  {route:'platform-home',actor:'admin',fixtureRole:'platform',fixtureLabel:'Platform Admin'},
  {route:'platform-safety',actor:'admin',fixtureRole:'platform',fixtureLabel:'Platform Admin'},
  {route:'platform-ads',actor:'admin',fixtureRole:'platform',fixtureLabel:'Platform Admin'},
  {route:'manager-location',actor:'admin',fixtureRole:'platform',fixtureLabel:'Platform Admin'},
  {route:'platform-audit',actor:'admin',fixtureRole:'platform',fixtureLabel:'Platform Admin'}
];

const VIEWPORTS=[
  {name:'desktop',width:1440,height:900},
  {name:'mobile',width:390,height:844}
];

function assert(v,m){if(!v)throw new Error(m);}
function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
function pwd(){return crypto.randomBytes(30).toString('base64url')+'Aa1!';}
function rid(){return 'ui3-'+(process.env.GITHUB_RUN_ID||Date.now())+'-'+(process.env.GITHUB_RUN_ATTEMPT||'1');}
function errText(e){return e?.message||e?.details||e?.hint||String(e);}

async function waitDeployment(sha){
  const deadline=Date.now()+8*60*1000;let last=null;
  while(Date.now()<deadline){
    try{
      const r=await fetch(DEV_ORIGIN+'/build-meta.json?ui3='+Date.now(),{cache:'no-store'});
      if(r.ok){last=await r.json();if(last.commit_sha===sha)return last;}
    }catch(e){last={error:String(e)}}
    await sleep(10000);
  }
  throw new Error('DEV_DEPLOYMENT_NOT_CURRENT expected='+sha+' last='+JSON.stringify(last));
}

async function endDeploymentCheck(sha){
  const r=await fetch(DEV_ORIGIN+'/build-meta.json?ui3-end='+Date.now(),{cache:'no-store'});
  assert(r.ok,'DEV_DEPLOYMENT_END_CHECK_FAILED_'+r.status);
  const m=await r.json();
  assert(m.commit_sha===sha,'DEV_DEPLOYMENT_CHANGED_DURING_UI_PROOF expected='+sha+' actual='+m.commit_sha);
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
  await page.waitForTimeout(900);
  return {ctx,page};
}

async function chooseLiveRole(page,role){
  const candidates=[role];
  for(const candidate of candidates){
    const el=page.locator('[data-live-role="'+candidate+'"]');
    if(await el.count()){await el.first().click();await page.waitForTimeout(900);return candidate;}
    const select=page.locator('[data-role-select]');
    if(await select.count()){
      const values=await select.locator('option').evaluateAll(xs=>xs.map(x=>x.value));
      if(values.includes(candidate)){await select.selectOption(candidate);await page.waitForTimeout(900);return candidate;}
    }
  }
  return 'implicit-default';
}

async function fixtureMetrics(browser,item,viewport){
  const ctx=await browser.newContext({viewport:{width:viewport.width,height:viewport.height}});
  const page=await ctx.newPage();
  await page.goto(DEV_ORIGIN+'/?fixture=1#/'+item.route,{waitUntil:'domcontentloaded'});
  await page.locator('h1').first().waitFor({timeout:30000});
  if((await page.locator('h1').first().innerText()).trim()==='Switch workspace'){
    const btn=page.getByRole('button',{name:item.fixtureLabel}).first();
    assert(await btn.count(),'FIXTURE_WORKSPACE_SWITCH_MISSING_'+item.fixtureRole);
    await btn.click();await page.waitForTimeout(150);
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
  await page.waitForTimeout(900);
  return page.evaluate(()=>{
    const box=s=>{const e=document.querySelector(s);if(!e)return null;const r=e.getBoundingClientRect(),cs=getComputedStyle(e);return {x:r.x,y:r.y,w:r.width,h:r.height,display:cs.display}};
    const h1=document.querySelector('h1'),body=document.body.innerText;
    return {
      title:h1?.textContent?.trim()||'',
      overflow:document.documentElement.scrollWidth>window.innerWidth+1,
      denied:/Switch workspace|does not currently have access|unavailable|NOT_AUTHORIZED/i.test(body),
      topbar:box('.topbar'),sidebar:box('.sidebar'),main:box('.main'),rightbar:box('.rightbar'),mobileNav:box('.mobile-nav'),
      h1Font:h1?getComputedStyle(h1).fontSize:null,
      bodyBg:getComputedStyle(document.body).backgroundColor
    };
  });
}

function visible(b){return !!b&&b.display!=='none'&&b.w>0&&b.h>0;}
function close(a,b,t=3){return Math.abs((a??0)-(b??0))<=t;}
function compare(gold,live){
  const issues=[];
  if(gold.title!==live.title)issues.push('title expected='+JSON.stringify(gold.title)+' actual='+JSON.stringify(live.title));
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
  const report={proof:'ui-convergence-privileged-v1',run_id:run,commit_sha:sha,deployment:null,checks:[],routes:[],result:'running'};
  const sessions={};

  try{
    report.deployment=await waitDeployment(sha);
    const token=await oidc();
    const passwords={manager:pwd(),admin:pwd(),ads_operator:pwd(),safety:pwd()};
    const ensured=await edge(token,{action:'ensure_personas',suite:'ui3',run_id:run,passwords});
    const specs=Object.fromEntries(ensured.personas.map(x=>[x.key,x]));

    for(const key of ['manager','admin']){
      const c=client();
      const {data,error}=await c.auth.signInWithPassword({email:specs[key].email,password:passwords[key]});if(error)throw error;
      assert(data.session,'SESSION_MISSING_'+key);
      const ac=await boot(c,key==='manager'?'UI3 E2E Local Manager':'UI3 E2E Platform Admin');
      sessions[key]={client:c,spec:specs[key],account:ac};
    }

    const adminFixture=await edge(token,{action:'ensure_admin_capability',suite:'ui3',run_id:run});
    assert(adminFixture?.admin?.account_id===sessions.admin.account.account.account_id,'PLATFORM_ADMIN_FIXTURE_ACCOUNT_MISMATCH');
    let adminContext=await rpc(sessions.admin.client,'get_my_account_context');
    assert(adminContext?.capabilities?.includes('platform_admin'),'PLATFORM_ADMIN_CAPABILITY_NOT_VISIBLE');

    const assignment=await rpc(sessions.admin.client,'assign_local_manager',{
      p_location_id:DHANBAD_LOCATION_ID,
      p_target_account_id:sessions.manager.account.account.account_id,
      p_idempotency_key:run+'-assign-manager'
    });
    assert(assignment?.assignment_id,'LOCAL_MANAGER_ASSIGNMENT_MISSING');

    await rpc(sessions.manager.client,'set_selected_location',{p_location_id:DHANBAD_LOCATION_ID,p_idempotency_key:run+'-manager-location'});
    await rpc(sessions.admin.client,'set_selected_location',{p_location_id:DHANBAD_LOCATION_ID,p_idempotency_key:run+'-admin-location'});
    const managerOverview=await rpc(sessions.manager.client,'get_local_manager_overview',{p_location_id:DHANBAD_LOCATION_ID});
    const platformSummary=await rpc(sessions.admin.client,'get_platform_operations_summary');
    assert(managerOverview,'MANAGER_OVERVIEW_MISSING');
    assert(platformSummary,'PLATFORM_SUMMARY_MISSING');
    report.authority={manager_assignment_id:assignment.assignment_id,admin_account_id:sessions.admin.account.account.account_id,manager_account_id:sessions.manager.account.account.account_id};
    report.checks.push({check:'real_privileged_authority_setup',pass:true});

    const browser=await chromium.launch({headless:true});
    try{
      for(const viewport of VIEWPORTS){
        const manager=await authBrowser(browser,sessions.manager.spec.email,passwords.manager,viewport);
        const admin=await authBrowser(browser,sessions.admin.spec.email,passwords.admin,viewport);
        const managerRole=await chooseLiveRole(manager.page,'manager');
        const adminRole=await chooseLiveRole(admin.page,'platform');
        report.checks.push({check:'live_privileged_workspace_mapping_'+viewport.name,pass:true,manager_role:managerRole,platform_role:adminRole});

        for(const item of ROUTES){
          const gold=await fixtureMetrics(browser,item,viewport);
          const live=await liveMetrics(item.actor==='manager'?manager.page:admin.page,item);
          const issues=compare(gold,live);
          report.routes.push({viewport:viewport.name,route:item.route,actor:item.actor,gold_title:gold.title,live_title:live.title,issues});
          await (item.actor==='manager'?manager.page:admin.page).screenshot({path:path.join(ARTIFACT_DIR,viewport.name+'-'+item.actor+'-'+item.route+'.png'),fullPage:true});
        }
        await manager.ctx.close();await admin.ctx.close();
      }
    }finally{await browser.close();}

    report.end_deployment=await endDeploymentCheck(sha);
    const issues=report.routes.flatMap(x=>x.issues.map(issue=>({viewport:x.viewport,route:x.route,actor:x.actor,issue})));
    report.issue_count=issues.length;report.issues=issues;
    assert(issues.length===0,'UI_CONVERGENCE_ISSUES '+JSON.stringify(issues));
    report.result='pass';
    fs.writeFileSync(path.join(ARTIFACT_DIR,'ui-convergence-privileged-proof.json'),JSON.stringify(report,null,2));
    console.log('RAAHI_UI_CONVERGENCE_PRIVILEGED_PASS run_id='+run+' commit='+sha);
  }catch(e){
    report.result='fail';report.failure={message:errText(e),class:'to-classify'};
    fs.writeFileSync(path.join(ARTIFACT_DIR,'ui-convergence-privileged-proof.json'),JSON.stringify(report,null,2));
    throw e;
  }finally{
    for(const s of Object.values(sessions)){try{await s.client.auth.signOut();}catch(_){}}
  }
}
await main();
