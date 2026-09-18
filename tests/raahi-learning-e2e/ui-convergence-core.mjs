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
const ARTIFACT_DIR=path.resolve('artifacts-ui-convergence');

const ROUTES=[
  {route:'home',actor:'learner',fixtureRole:'parent',title:'Learn locally. Keep learning together.'},
  {route:'explore',actor:'learner',fixtureRole:'parent',title:'Explore'},
  {route:'classes',actor:'learner',fixtureRole:'parent',title:'My Classes'},
  {route:'notifications',actor:'learner',fixtureRole:'parent',title:'Notifications'},
  {route:'learners',actor:'learner',fixtureRole:'parent',title:'Learning profiles'},
  {route:'community',actor:'learner',fixtureRole:'parent',titlePattern:/ Community$/},
  {route:'messages',actor:'learner',fixtureRole:'parent',title:'Messages'},
  {route:'settings',actor:'learner',fixtureRole:'parent',title:'Settings'},
  {route:'teacher-home',actor:'teacher',fixtureRole:'teacher',title:'Teach locally, without chasing leads.'},
  {route:'teaching-options',actor:'teacher',fixtureRole:'teacher',title:'What I Teach'},
  {route:'opportunities',actor:'teacher',fixtureRole:'teacher',title:'Teaching Opportunities'},
  {route:'teacher-classes',actor:'teacher',fixtureRole:'teacher',title:'Manage Classes'},
  {route:'teacher-profile-edit',actor:'teacher',fixtureRole:'teacher',title:'Teacher Profile'}
];

const VIEWPORTS=[
  {name:'desktop',width:1440,height:900},
  {name:'mobile',width:390,height:844}
];

function assert(v,m){if(!v)throw new Error(m);}
function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
function pwd(){return crypto.randomBytes(30).toString('base64url')+'Aa1!';}
function rid(){return 'ui-'+(process.env.GITHUB_RUN_ID||Date.now())+'-'+(process.env.GITHUB_RUN_ATTEMPT||'1');}
function errText(e){return e?.message||e?.details||e?.hint||String(e);}

async function waitDeployment(sha){
  const deadline=Date.now()+8*60*1000;let last=null;
  while(Date.now()<deadline){
    try{
      const r=await fetch(DEV_ORIGIN+'/build-meta.json?ui='+Date.now(),{cache:'no-store'});
      if(r.ok){last=await r.json();if(last.commit_sha===sha)return last;}
    }catch(e){last={error:String(e)}}
    await sleep(10000);
  }
  throw new Error('DEV_DEPLOYMENT_NOT_CURRENT expected='+sha+' last='+JSON.stringify(last));
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

async function chooseLiveRole(page,role){
  const el=page.locator('[data-live-role="'+role+'"]');
  if(await el.count()){await el.first().click();await page.waitForTimeout(700);return;}
  const select=page.locator('[data-role-select]');
  if(await select.count()){await select.selectOption(role);await page.waitForTimeout(700);return;}
}

async function fixtureMetrics(browser,item,viewport){
  const ctx=await browser.newContext({viewport:{width:viewport.width,height:viewport.height}});
  const page=await ctx.newPage();
  await page.goto(DEV_ORIGIN+'/?fixture=1#/'+item.route,{waitUntil:'domcontentloaded'});
  const select=page.locator('[data-role-select]');
  if(await select.count()){
    await select.selectOption(item.fixtureRole);
    await page.waitForTimeout(100);
    await page.goto(DEV_ORIGIN+'/?fixture=1#/'+item.route,{waitUntil:'domcontentloaded'});
  }
  await page.locator('h1').first().waitFor({timeout:30000});
  const m=await page.evaluate(()=> {
    const box=s=>{const e=document.querySelector(s);if(!e)return null;const r=e.getBoundingClientRect();const cs=getComputedStyle(e);return {x:r.x,y:r.y,w:r.width,h:r.height,display:cs.display,position:cs.position}};
    return {
      title:document.querySelector('h1')?.textContent?.trim()||'',
      overflow:document.documentElement.scrollWidth>window.innerWidth+1,
      topbar:box('.topbar'),sidebar:box('.sidebar'),main:box('.main'),rightbar:box('.rightbar'),mobileNav:box('.mobile-nav'),
      h1Font:getComputedStyle(document.querySelector('h1')).fontSize,
      bodyBg:getComputedStyle(document.body).backgroundColor
    };
  });
  await ctx.close();return m;
}

async function liveMetrics(page,item,viewport){
  await page.goto(DEV_ORIGIN+'/#/'+item.route,{waitUntil:'domcontentloaded'});
  await page.locator('h1').first().waitFor({timeout:30000});
  await page.waitForTimeout(700);
  const m=await page.evaluate(()=> {
    const box=s=>{const e=document.querySelector(s);if(!e)return null;const r=e.getBoundingClientRect();const cs=getComputedStyle(e);return {x:r.x,y:r.y,w:r.width,h:r.height,display:cs.display,position:cs.position}};
    return {
      title:document.querySelector('h1')?.textContent?.trim()||'',
      overflow:document.documentElement.scrollWidth>window.innerWidth+1,
      denied:/Switch workspace|unavailable|not currently have access/i.test(document.body.innerText),
      topbar:box('.topbar'),sidebar:box('.sidebar'),main:box('.main'),rightbar:box('.rightbar'),mobileNav:box('.mobile-nav'),
      h1Font:getComputedStyle(document.querySelector('h1')).fontSize,
      bodyBg:getComputedStyle(document.body).backgroundColor
    };
  });
  return m;
}

function visible(box){return !!box&&box.display!=='none'&&box.w>0&&box.h>0;}
function close(a,b,t=2){return Math.abs((a??0)-(b??0))<=t;}

function compare(item,viewport,gold,live){
  const issues=[];
  if(item.title && live.title!==item.title)issues.push('title expected='+JSON.stringify(item.title)+' actual='+JSON.stringify(live.title));
  if(item.titlePattern && !item.titlePattern.test(live.title))issues.push('title pattern '+item.titlePattern+' actual='+JSON.stringify(live.title));
  if(live.overflow)issues.push('horizontal overflow');
  if(live.denied)issues.push('unexpected access/guard page');
  if(gold.h1Font!==live.h1Font)issues.push('h1 font '+gold.h1Font+' vs '+live.h1Font);
  if(gold.bodyBg!==live.bodyBg)issues.push('body background mismatch');
  if(visible(gold.topbar)!==visible(live.topbar))issues.push('topbar visibility mismatch');
  if(visible(gold.sidebar)!==visible(live.sidebar))issues.push('sidebar visibility mismatch');
  if(visible(gold.rightbar)!==visible(live.rightbar))issues.push('rightbar visibility mismatch');
  if(visible(gold.mobileNav)!==visible(live.mobileNav))issues.push('mobile nav visibility mismatch');
  if(visible(gold.topbar)&&visible(live.topbar)&&!close(gold.topbar.h,live.topbar.h,1))issues.push('topbar height mismatch');
  if(visible(gold.main)&&visible(live.main)&&!close(gold.main.x,live.main.x,3))issues.push('main x mismatch '+gold.main.x+' vs '+live.main.x);
  return issues;
}

async function main(){
  assert(new URL(SUPABASE_URL).hostname.split('.')[0]===PROJECT_REF,'PROJECT_GUARD');
  assert(process.env.GITHUB_REF==='refs/heads/raahi-learning-implementation-v1','BRANCH_GUARD');
  fs.mkdirSync(ARTIFACT_DIR,{recursive:true});
  const run=rid(),sha=process.env.GITHUB_SHA||'unknown';
  const report={proof:'ui-convergence-core-v1',run_id:run,commit_sha:sha,deployment:null,checks:[],routes:[],result:'running'};
  const sessions={};
  try{
    report.deployment=await waitDeployment(sha);
    const token=await oidc();
    const passwords={learner:pwd(),teacher:pwd(),parent:pwd(),unrelated:pwd()};
    const ensured=await edge(token,{action:'ensure_personas',suite:'ui',run_id:run,passwords});
    const specs=Object.fromEntries(ensured.personas.map(x=>[x.key,x]));

    for(const key of ['learner','teacher']){
      const c=client();const {data,error}=await c.auth.signInWithPassword({email:specs[key].email,password:passwords[key]});if(error)throw error;
      assert(data.session,'SESSION_MISSING_'+key);
      let ac=await boot(c,key==='learner'?'UI E2E Learner':'UI E2E Teacher');
      sessions[key]={client:c,spec:specs[key],account:ac};
    }

    let lc=sessions.learner.account;let self=lc.learners?.find(x=>x.access_type==='self');
    if(!self){
      await rpc(sessions.learner.client,'create_learner',{p_display_name:'UI Adult Learner',p_access_type:'self',p_avatar_type:'none',p_avatar_ref:null,p_idempotency_key:run+'-self'});
      lc=await rpc(sessions.learner.client,'get_my_account_context');self=lc.learners.find(x=>x.access_type==='self');
    }
    assert(self?.learner_id,'SELF_LEARNER_MISSING');
    await rpc(sessions.learner.client,'set_selected_location',{p_location_id:DHANBAD_LOCATION_ID,p_idempotency_key:run+'-learner-location'});

    await rpc(sessions.teacher.client,'enable_teaching',{p_idempotency_key:run+'-teach'});
    await rpc(sessions.teacher.client,'upsert_teacher_profile',{
      p_headline:'UI convergence Mathematics teacher',p_bio:'DEV UI convergence profile',p_experience_summary:'UI proof',
      p_visibility_status:'visible',p_idempotency_key:run+'-teacher-profile'
    });
    await rpc(sessions.teacher.client,'set_selected_location',{p_location_id:DHANBAD_LOCATION_ID,p_idempotency_key:run+'-teacher-location'});
    report.checks.push({check:'canonical_ui_actor_setup',pass:true});

    const browser=await chromium.launch({headless:true});
    try{
      for(const viewport of VIEWPORTS){
        const liveBrowsers={};
        for(const actor of ['learner','teacher']){
          liveBrowsers[actor]=await authBrowser(browser,sessions[actor].spec.email,passwords[actor],viewport);
          await chooseLiveRole(liveBrowsers[actor].page,actor==='learner'?'learner':'teacher');
        }

        for(const item of ROUTES){
          const gold=await fixtureMetrics(browser,item,viewport);
          const live=await liveMetrics(liveBrowsers[item.actor].page,item,viewport);
          const issues=compare(item,viewport,gold,live);
          const entry={viewport:viewport.name,route:item.route,actor:item.actor,gold_title:gold.title,live_title:live.title,issues};
          report.routes.push(entry);
          await liveBrowsers[item.actor].page.screenshot({path:path.join(ARTIFACT_DIR,viewport.name+'-'+item.route+'.png'),fullPage:true});
        }
        for(const b of Object.values(liveBrowsers))await b.ctx.close();
      }
    }finally{await browser.close();}

    const endMetaResponse=await fetch(DEV_ORIGIN+'/build-meta.json?ui-end='+Date.now(),{cache:'no-store'});
    assert(endMetaResponse.ok,'DEV_DEPLOYMENT_END_CHECK_FAILED_'+endMetaResponse.status);
    const endMeta=await endMetaResponse.json();
    assert(endMeta.commit_sha===sha,'DEV_DEPLOYMENT_CHANGED_DURING_UI_PROOF expected='+sha+' actual='+endMeta.commit_sha);
    report.end_deployment=endMeta;

    const issues=report.routes.flatMap(x=>x.issues.map(issue=>({viewport:x.viewport,route:x.route,issue})));
    report.issue_count=issues.length;
    report.issues=issues;
    assert(issues.length===0,'UI_CONVERGENCE_ISSUES '+JSON.stringify(issues));
    report.result='pass';
    fs.writeFileSync(path.join(ARTIFACT_DIR,'ui-convergence-core-proof.json'),JSON.stringify(report,null,2));
    console.log('RAAHI_UI_CONVERGENCE_CORE_PASS run_id='+run+' commit='+sha);
  }catch(e){
    report.result='fail';report.failure={message:errText(e),class:'to-classify'};
    fs.writeFileSync(path.join(ARTIFACT_DIR,'ui-convergence-core-proof.json'),JSON.stringify(report,null,2));
    throw e;
  }finally{
    for(const s of Object.values(sessions)){try{await s.client.auth.signOut();}catch(_){}}
  }
}
await main();
