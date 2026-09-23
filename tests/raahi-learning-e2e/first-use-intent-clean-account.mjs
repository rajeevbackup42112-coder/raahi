import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { chromium } from 'playwright';
import { createClient } from '@supabase/supabase-js';

const LOCAL_ORIGIN='http://127.0.0.1:4173';
const SUPABASE_URL='https://iiwwmqokaeflaenhlyip.supabase.co';
const PROJECT_REF='iiwwmqokaeflaenhlyip';
const PUBLISHABLE_KEY='sb_publishable_bz0YgDXY-WkKxZnogGsfUg_Qgl7E-Wi';
const EDGE_URL=SUPABASE_URL+'/functions/v1/dev-test-identities';
const OIDC_AUDIENCE='raahi-learning-dev-test-harness';
const ARTIFACT_DIR=path.resolve('artifacts-first-use-alignment');

const INTENTS=[
  {key:'learn',intent:'learner',destination:'learner-setup'},
  {key:'parent',intent:'parent',destination:'learner-add'},
  {key:'teacher',intent:'teacher',destination:'teacher-setup'},
  {key:'institute',intent:'institute',destination:'institute-setup'},
  {key:'explore',intent:'explore',destination:'home'},
];
const VIEWPORTS=[
  {name:'desktop',width:1440,height:900},
  {name:'iphone',width:390,height:844},
  {name:'android',width:412,height:915},
];

function assert(v,m){if(!v)throw new Error(m);}
function pwd(){return crypto.randomBytes(30).toString('base64url')+'Aa1!';}
function runId(){return 'align-'+(process.env.GITHUB_RUN_ID||Date.now())+'-'+(process.env.GITHUB_RUN_ATTEMPT||'1');}
function client(){return createClient(SUPABASE_URL,PUBLISHABLE_KEY,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});}
async function rpc(c,n,a={}){const {data,error}=await c.rpc(n,a);if(error)throw error;return data;}
async function boot(c,name){
  try{return await rpc(c,'get_my_account_context');}
  catch(e){
    if(!/ACCOUNT_NOT_FOUND/i.test(e?.message||String(e)))throw e;
    await rpc(c,'bootstrap_account',{p_display_name:name});
    return rpc(c,'get_my_account_context');
  }
}
async function oidc(){
  const base=process.env.ACTIONS_ID_TOKEN_REQUEST_URL;
  const token=process.env.ACTIONS_ID_TOKEN_REQUEST_TOKEN;
  assert(base&&token,'GITHUB_OIDC_ENV_MISSING');
  const u=new URL(base);u.searchParams.set('audience',OIDC_AUDIENCE);
  const r=await fetch(u,{headers:{authorization:'Bearer '+token}});
  if(!r.ok)throw new Error('GITHUB_OIDC_REQUEST_FAILED_'+r.status);
  const b=await r.json();assert(b.value,'GITHUB_OIDC_TOKEN_MISSING');return b.value;
}
async function edge(token,payload){
  const r=await fetch(EDGE_URL,{method:'POST',headers:{authorization:'Bearer '+token,'content-type':'application/json'},body:JSON.stringify(payload)});
  const b=await r.json().catch(()=>({ok:false,error:'INVALID_JSON'}));
  if(!r.ok||!b.ok)throw new Error('IDENTITY_FACTORY_FAILED '+(b.error||r.status));
  return b;
}
function cleanContext(ctx,label){
  assert(ctx?.account?.account_id,label+'_ACCOUNT_MISSING');
  assert(Array.isArray(ctx.learners)&&ctx.learners.length===0,label+'_LEARNER_STATE_NOT_CLEAN');
  assert(Array.isArray(ctx.capabilities)&&ctx.capabilities.length===0,label+'_CAPABILITY_STATE_NOT_CLEAN');
  assert(Array.isArray(ctx.organizations)&&ctx.organizations.length===0,label+'_ORG_STATE_NOT_CLEAN');
  assert(Array.isArray(ctx.manager_scopes)&&ctx.manager_scopes.length===0,label+'_MANAGER_STATE_NOT_CLEAN');
}
async function browserSignIn(browser,spec,password,viewport){
  const ctx=await browser.newContext({viewport:{width:viewport.width,height:viewport.height}});
  const page=await ctx.newPage();
  await page.goto(LOCAL_ORIGIN+'/dev-test-login-v13.html',{waitUntil:'domcontentloaded'});
  await page.getByText('RAAHI_DEV_TEST_LOGIN_V13').waitFor({timeout:30000});
  await page.locator('#email').fill(spec.email);
  await page.locator('#password').fill(password);
  await page.locator('#signin').click();
  await page.waitForURL(u=>u.origin===LOCAL_ORIGIN&&u.hash==='#/onboarding-intent',{timeout:30000});
  await page.locator('h1').first().waitFor({timeout:30000});
  return {ctx,page};
}

async function main(){
  assert(process.env.GITHUB_REF==='refs/heads/raahi-learning-implementation-v1','IMPLEMENTATION_BRANCH_REQUIRED');
  fs.mkdirSync(ARTIFACT_DIR,{recursive:true});
  const rid=runId();
  const token=await oidc();
  const passwords=Object.fromEntries(INTENTS.map(x=>[x.key,pwd()]));
  const ensured=await edge(token,{action:'ensure_personas',suite:'alignment',run_id:rid,passwords});
  const specs=Object.fromEntries(ensured.personas.map(x=>[x.key,x]));
  for(const x of INTENTS)assert(specs[x.key]?.email&&specs[x.key]?.auth_user_id,'ALIGNMENT_PERSONA_MISSING_'+x.key);

  const sessions={};
  for(const x of INTENTS){
    const c=client();
    const {data,error}=await c.auth.signInWithPassword({email:specs[x.key].email,password:passwords[x.key]});
    if(error)throw error;
    assert(data.user?.id===specs[x.key].auth_user_id,'AUTH_USER_MISMATCH_'+x.key);
    const ctx=await boot(c,specs[x.key].display_name||('Alignment '+x.key));
    cleanContext(ctx,'BOOT_'+x.key);
    sessions[x.key]={client:c,account_id:ctx.account.account_id};
  }

  const browser=await chromium.launch({headless:true});
  const report={
    proof:'first-use-intent-clean-account-browser-v1',
    run_id:rid,
    commit_sha:process.env.GITHUB_SHA||'unknown',
    environment:{frontend:'local exact source',backend_project_ref:PROJECT_REF},
    viewports:[],
    result:'running'
  };

  try{
    for(const viewport of VIEWPORTS){
      const reset=await edge(token,{action:'reset_first_use_alignment',suite:'alignment',run_id:rid+'-'+viewport.name});
      assert(reset.reset?.length===INTENTS.length,'ALIGNMENT_RESET_COUNT_'+viewport.name+'_'+(reset.reset?.length||0));

      for(const x of INTENTS){
        const before=await rpc(sessions[x.key].client,'get_my_account_context');
        cleanContext(before,'BEFORE_'+viewport.name+'_'+x.key);
        assert(Object.prototype.hasOwnProperty.call(before.account,'first_use_completed_at'),'FIRST_USE_FIELD_MISSING_'+x.key);
        assert(before.account.first_use_completed_at===null,'FIRST_USE_NOT_PENDING_'+viewport.name+'_'+x.key);

        const b=await browserSignIn(browser,specs[x.key],passwords[x.key],viewport);
        const {page}=b;
        const bodyBefore=await page.locator('body').innerText();
        assert(/What brings you here today\?/i.test(bodyBefore),'INTENT_QUESTION_MISSING_'+viewport.name+'_'+x.key);
        assert(!/does not currently have access|unavailable/i.test(bodyBefore),'INTENT_SCREEN_DENIED_'+viewport.name+'_'+x.key);

        const target=page.locator('[data-start-intent="'+x.intent+'"]').first();
        await target.waitFor({state:'visible',timeout:15000});
        await target.click();
        await page.waitForURL(u=>u.origin===LOCAL_ORIGIN&&u.hash==='#/'+x.destination,{timeout:30000});
        await page.waitForTimeout(500);

        const after=await rpc(sessions[x.key].client,'get_my_account_context');
        cleanContext(after,'AFTER_'+viewport.name+'_'+x.key);
        assert(after.account.first_use_completed_at,'FIRST_USE_NOT_COMPLETED_'+viewport.name+'_'+x.key);

        const bodyAfter=await page.locator('body').innerText();
        assert(!/Changing the URL cannot grant access/i.test(bodyAfter),'LEGITIMATE_SETUP_COLLIDED_WITH_GUARD_'+viewport.name+'_'+x.key);
        if(x.intent==='teacher'){
          assert(/Set up your teaching presence/i.test(bodyAfter),'TEACHER_SETUP_NOT_REACHED_'+viewport.name);
          assert(/Set it up myself/i.test(bodyAfter)&&/Ask Raahi to help/i.test(bodyAfter),'TEACHER_SETUP_CHOICES_MISSING_'+viewport.name);
        }

        const screenshot=viewport.name+'-'+x.key+'-'+x.destination+'.png';
        await page.screenshot({path:path.join(ARTIFACT_DIR,screenshot),fullPage:true});
        report.viewports.push({viewport:viewport.name,persona:x.key,intent:x.intent,destination:x.destination,pass:true,screenshot});
        await b.ctx.close();
      }

      // Explicitly prove first-use completion did not create Teacher authority.
      const explore=await browserSignInAfterCompletion(browser,specs.explore,passwords.explore,viewport);
      await explore.page.goto(LOCAL_ORIGIN+'/#/teacher-home',{waitUntil:'domcontentloaded'});
      await explore.page.waitForTimeout(700);
      const denied=await explore.page.locator('body').innerText();
      assert(!/Teach locally, without chasing leads/i.test(denied),'FIRST_USE_GRANTED_TEACHER_WORKSPACE_'+viewport.name);
      assert(/Switch workspace|does not currently have access|unavailable/i.test(denied),'TEACHER_DEEP_LINK_NOT_SAFELY_DENIED_'+viewport.name);
      await explore.ctx.close();
    }

    report.result='pass';
    fs.writeFileSync(path.join(ARTIFACT_DIR,'first-use-alignment-proof.json'),JSON.stringify(report,null,2));
    console.log('RAAHI_FIRST_USE_ALIGNMENT_PASS run_id='+rid+' commit='+(process.env.GITHUB_SHA||'unknown'));
  }finally{
    await browser.close();
    for(const x of INTENTS)await sessions[x.key].client.auth.signOut().catch(()=>{});
  }
}

async function browserSignInAfterCompletion(browser,spec,password,viewport){
  const ctx=await browser.newContext({viewport:{width:viewport.width,height:viewport.height}});
  const page=await ctx.newPage();
  await page.goto(LOCAL_ORIGIN+'/dev-test-login-v13.html',{waitUntil:'domcontentloaded'});
  await page.locator('#email').fill(spec.email);
  await page.locator('#password').fill(password);
  await page.locator('#signin').click();
  await page.waitForURL(u=>u.origin===LOCAL_ORIGIN&&u.hash==='#/home',{timeout:30000});
  await page.waitForTimeout(500);
  return {ctx,page};
}

main().catch(error=>{
  fs.mkdirSync(ARTIFACT_DIR,{recursive:true});
  fs.writeFileSync(path.join(ARTIFACT_DIR,'failure.txt'),String(error?.stack||error));
  console.error(error);
  process.exitCode=1;
});
