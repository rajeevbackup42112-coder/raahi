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
const ARTIFACT_DIR=path.resolve('artifacts-ui-convergence-ads');

const ROUTES=[
  {route:'ads-home',fixtureLabel:'Raahi Ads'},
  {route:'ads-eligibility',fixtureLabel:'Raahi Ads'},
  {route:'ads-create',fixtureLabel:'Raahi Ads'},
  {route:'ads-inventory',fixtureLabel:'Raahi Ads'},
  {route:'ads-analytics',fixtureLabel:'Raahi Ads'}
];

const VIEWPORTS=[
  {name:'desktop',width:1440,height:900},
  {name:'mobile',width:390,height:844}
];

function assert(v,m){if(!v)throw new Error(m);}
function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
function pwd(){return crypto.randomBytes(30).toString('base64url')+'Aa1!';}
function rid(){return 'ui4-ads-'+(process.env.GITHUB_RUN_ID||Date.now())+'-'+(process.env.GITHUB_RUN_ATTEMPT||'1');}
function errText(e){return e?.message||e?.details||e?.hint||String(e);}

async function waitDeployment(sha){
  const deadline=Date.now()+8*60*1000;let last=null;
  while(Date.now()<deadline){
    try{
      const r=await fetch(DEV_ORIGIN+'/build-meta.json?ads='+Date.now(),{cache:'no-store'});
      if(r.ok){last=await r.json();if(last.commit_sha===sha)return last;}
    }catch(e){last={error:String(e)}}
    await sleep(10000);
  }
  throw new Error('DEV_DEPLOYMENT_NOT_CURRENT expected='+sha+' last='+JSON.stringify(last));
}
async function endDeploymentCheck(sha){
  const r=await fetch(DEV_ORIGIN+'/build-meta.json?ads-end='+Date.now(),{cache:'no-store'});
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
function client(){return createClient(SUPABASE_URL,PUBLISHABLE_KEY,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});}
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
async function chooseLiveAdsRole(page){
  const select=page.locator('[data-live-role-select]').first();
  await select.waitFor({state:'visible',timeout:15000});
  const values=await select.locator('option').evaluateAll(xs=>xs.map(x=>x.value));
  assert(values.includes('ads'),'AUTHORIZED_WORKSPACE_OPTION_MISSING_ads options='+values.join(','));
  await select.selectOption('ads');
  await page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/ads-home',{timeout:15000});
  await page.waitForTimeout(900);
  assert((await select.inputValue())==='ads','ADS_WORKSPACE_SELECTION_DID_NOT_STICK');
}
async function fixtureMetrics(browser,item,viewport){
  const ctx=await browser.newContext({viewport:{width:viewport.width,height:viewport.height}});
  const page=await ctx.newPage();
  await page.goto(DEV_ORIGIN+'/?fixture=1#/'+item.route,{waitUntil:'domcontentloaded'});
  await page.locator('h1').first().waitFor({timeout:30000});
  if((await page.locator('h1').first().innerText()).trim()==='Switch workspace'){
    const btn=page.getByRole('button',{name:item.fixtureLabel}).first();
    assert(await btn.count(),'FIXTURE_ADS_WORKSPACE_SWITCH_MISSING');
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
      denied:/Switch workspace|Workspace unavailable|does not currently have access|NOT_AUTHORIZED/i.test(body),
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
  const report={proof:'ui-convergence-ads-v1',run_id:run,commit_sha:sha,deployment:null,checks:[],routes:[],result:'running'};
  let session=null;
  try{
    report.deployment=await waitDeployment(sha);
    const token=await oidc();
    const passwords={org_owner:pwd()};
    const ensured=await edge(token,{action:'ensure_personas',suite:'ui4_ads',run_id:run,passwords});
    const specs=Object.fromEntries(ensured.personas.map(x=>[x.key,x]));
    const c=client();
    const {data,error}=await c.auth.signInWithPassword({email:specs.org_owner.email,password:passwords.org_owner});if(error)throw error;
    assert(data.session,'OWNER_SESSION_MISSING');
    session={client:c,spec:specs.org_owner,password:passwords.org_owner};
    let ac=await boot(c,'UI4 E2E Advertiser Owner');
    let org=ac.organizations?.find(x=>Array.isArray(x.capabilities)&&x.capabilities.includes('manage_ads'))||ac.organizations?.[0]||null;
    if(!org){
      const created=await rpc(c,'create_organization',{
        p_organization_type:'coaching',p_name:'UI4 Advertiser Learning Centre',p_description:'DEV Ads convergence organization',
        p_public_contact_text:'DEV only',p_venue_text:'Dhanbad',p_website_url:null,p_logo_type:'none',p_logo_ref:null,
        p_idempotency_key:run+'-org'
      });
      ac=await rpc(c,'get_my_account_context');
      org=ac.organizations?.find(x=>x.organization_id===created.organization_id)||ac.organizations?.[0]||null;
    }
    assert(org?.organization_id,'ADVERTISER_ORGANIZATION_MISSING');
    assert(Array.isArray(org.capabilities)&&org.capabilities.includes('manage_ads'),'ORGANIZATION_MANAGE_ADS_MISSING');
    await rpc(c,'set_selected_location',{p_location_id:DHANBAD_LOCATION_ID,p_idempotency_key:run+'-location'});
    const campaigns=await rpc(c,'get_my_ad_campaigns');
    report.authority={owner_account_id:ac.account.account_id,organization_id:org.organization_id,manage_ads:true,campaign_count:Array.isArray(campaigns)?campaigns.length:0};
    report.checks.push({check:'real_organization_ads_authority',pass:true});

    const browser=await chromium.launch({headless:true});
    try{
      for(const viewport of VIEWPORTS){
        const live=await authBrowser(browser,session.spec.email,session.password,viewport);
        await chooseLiveAdsRole(live.page);
        for(const item of ROUTES){
          const gold=await fixtureMetrics(browser,item,viewport);
          const actual=await liveMetrics(live.page,item);
          const issues=compare(gold,actual);
          report.routes.push({viewport:viewport.name,route:item.route,gold_title:gold.title,live_title:actual.title,issues});
          await live.page.screenshot({path:path.join(ARTIFACT_DIR,viewport.name+'-'+item.route+'.png'),fullPage:true});
        }
        await live.ctx.close();
      }
    }finally{await browser.close();}

    report.end_deployment=await endDeploymentCheck(sha);
    const issues=report.routes.flatMap(x=>x.issues.map(issue=>({viewport:x.viewport,route:x.route,issue})));
    report.issue_count=issues.length;report.issues=issues;
    assert(issues.length===0,'UI_CONVERGENCE_ISSUES '+JSON.stringify(issues));
    report.result='pass';
    fs.writeFileSync(path.join(ARTIFACT_DIR,'ui-convergence-ads-proof.json'),JSON.stringify(report,null,2));
    console.log('RAAHI_UI_CONVERGENCE_ADS_PASS run_id='+run+' commit='+sha);
  }catch(e){
    report.result='fail';report.failure={message:errText(e),class:'to-classify'};
    fs.writeFileSync(path.join(ARTIFACT_DIR,'ui-convergence-ads-proof.json'),JSON.stringify(report,null,2));
    throw e;
  }finally{
    try{await session?.client?.auth.signOut();}catch(_){}
  }
}
await main();
