import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { chromium } from 'playwright';
import { createClient } from '@supabase/supabase-js';

const DEV_ORIGIN='https://dev.learning.myraahi.co.in';
const EXPECTED_HOST='dev.learning.myraahi.co.in';
const SUPABASE_URL='https://iiwwmqokaeflaenhlyip.supabase.co';
const PROJECT_REF='iiwwmqokaeflaenhlyip';
const PUBLISHABLE_KEY='sb_publishable_bz0YgDXY-WkKxZnogGsfUg_Qgl7E-Wi';
const EDGE_URL=SUPABASE_URL+'/functions/v1/dev-test-identities';
const OIDC_AUDIENCE='raahi-learning-dev-test-harness';
const ARTIFACT_DIR=path.resolve('artifacts-cohort');

const COHORT_KEYS=[
  'adult_learner','parent_single','parent_multi','teacher','teacher_parent',
  'second_teacher','unrelated','org_owner','org_staff_profile','org_staff_teaching',
  'org_staff_classes','org_staff_members','org_staff_ads','local_manager','admin',
  'safety_reviewer','verifier','ads_commercial','invite_recipient','recovery_actor'
];

function assert(v,m){if(!v)throw new Error(m);}
function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
function safeError(e){return e?.message||e?.details||e?.hint||String(e);}
function runId(){return 'cohort-'+(process.env.GITHUB_RUN_ID||Date.now())+'-'+(process.env.GITHUB_RUN_ATTEMPT||'1');}
function password(){return crypto.randomBytes(30).toString('base64url')+'Aa1!';}

function guards(){
  assert(new URL(DEV_ORIGIN).hostname===EXPECTED_HOST,'DEV_ORIGIN_GUARD_FAILED');
  assert(new URL(SUPABASE_URL).hostname.split('.')[0]===PROJECT_REF,'SUPABASE_PROJECT_GUARD_FAILED');
  assert(process.env.GITHUB_REF==='refs/heads/raahi-learning-implementation-v1','GITHUB_REF_GUARD_FAILED');
  assert(COHORT_KEYS.length===20,'COHORT_SIZE_NOT_20');
  assert(new Set(COHORT_KEYS).size===20,'COHORT_KEYS_NOT_UNIQUE');
}

async function waitForDeployment(sha){
  const deadline=Date.now()+8*60*1000;let last=null;
  while(Date.now()<deadline){
    try{
      const res=await fetch(DEV_ORIGIN+'/build-meta.json?cohort='+Date.now(),{cache:'no-store'});
      if(res.ok){last=await res.json();if(last.commit_sha===sha)return last;}
    }catch(e){last={error:String(e)}}
    await sleep(10000);
  }
  throw new Error('DEV_DEPLOYMENT_NOT_CURRENT expected='+sha+' last='+JSON.stringify(last));
}

async function oidcToken(){
  const requestUrl=process.env.ACTIONS_ID_TOKEN_REQUEST_URL;
  const requestToken=process.env.ACTIONS_ID_TOKEN_REQUEST_TOKEN;
  assert(requestUrl&&requestToken,'GITHUB_OIDC_ENV_MISSING');
  const u=new URL(requestUrl);u.searchParams.set('audience',OIDC_AUDIENCE);
  const res=await fetch(u,{headers:{authorization:'Bearer '+requestToken}});
  if(!res.ok)throw new Error('GITHUB_OIDC_REQUEST_FAILED_'+res.status);
  const body=await res.json();assert(body.value,'GITHUB_OIDC_TOKEN_MISSING');return body.value;
}

async function edgeCall(token,payload){
  const res=await fetch(EDGE_URL,{
    method:'POST',
    headers:{authorization:'Bearer '+token,'content-type':'application/json'},
    body:JSON.stringify(payload)
  });
  const body=await res.json().catch(()=>({ok:false,error:'INVALID_JSON_RESPONSE'}));
  if(!res.ok||!body.ok)throw new Error('DEV_IDENTITY_FACTORY_FAILED '+(body.error||res.status));
  return body;
}

function supa(){
  return createClient(SUPABASE_URL,PUBLISHABLE_KEY,{
    auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}
  });
}

async function rpc(c,name,args={}){
  const {data,error}=await c.rpc(name,args);if(error)throw error;return data;
}

async function bootstrap(c,key){
  try{return await rpc(c,'get_my_account_context');}
  catch(e){
    if(!/ACCOUNT_NOT_FOUND/i.test(safeError(e)))throw e;
    const display='Cohort '+key.replaceAll('_',' ');
    await rpc(c,'bootstrap_account',{p_display_name:display});
    return rpc(c,'get_my_account_context');
  }
}

async function browserSignIn(browser,spec,passwordValue,key){
  const ctx=await browser.newContext({viewport:{width:1280,height:900}});
  const page=await ctx.newPage();
  await page.goto(DEV_ORIGIN+'/dev-test-login-v13.html',{waitUntil:'domcontentloaded'});
  await page.getByText('RAAHI_DEV_TEST_LOGIN_V13').waitFor({timeout:30000});
  await page.locator('#email').fill(spec.email);
  await page.locator('#password').fill(passwordValue);
  await page.locator('#signin').click();
  await page.waitForURL(url=>url.origin===DEV_ORIGIN&&url.hash==='#/home',{timeout:30000});
  await page.waitForTimeout(900);
  const body=await page.locator('body').innerText();
  assert(!/Continue with Google/i.test(body),'BROWSER_RETURNED_TO_GOOGLE_'+key);
  await page.screenshot({path:path.join(ARTIFACT_DIR,'cohort-'+key+'.png'),fullPage:true});
  await ctx.close();
}

async function main(){
  guards();fs.mkdirSync(ARTIFACT_DIR,{recursive:true});
  const rid=runId(),sha=process.env.GITHUB_SHA||'unknown';
  const report={
    proof:'raahi-learning-20-persona-session-cohort-v1',
    run_id:rid,commit_sha:sha,deployment:null,
    intended_scenarios:{},personas:{},checks:[],result:'running'
  };
  const sessions={};

  try{
    report.deployment=await waitForDeployment(sha);
    report.checks.push({check:'exact_commit_deployed',pass:true});

    const unauth=await fetch(EDGE_URL,{
      method:'POST',
      headers:{'content-type':'application/json'},
      body:JSON.stringify({action:'ensure_personas',suite:'cohort',run_id:rid,passwords:{}})
    });
    assert(unauth.status===403,'IDENTITY_FACTORY_UNAUTHENTICATED_GUARD_FAILED_'+unauth.status);
    report.checks.push({check:'identity_factory_rejects_unauthenticated',pass:true});

    const token=await oidcToken();
    const passwords=Object.fromEntries(COHORT_KEYS.map(k=>[k,password()]));
    const ensured=await edgeCall(token,{action:'ensure_personas',suite:'cohort',run_id:rid,passwords});
    assert(ensured.suite==='cohort','WRONG_PERSONA_SUITE');
    assert(Array.isArray(ensured.personas)&&ensured.personas.length===20,'IDENTITY_FACTORY_COUNT_'+(ensured.personas?.length||0));

    const specs=Object.fromEntries(ensured.personas.map(x=>[x.key,x]));
    assert(COHORT_KEYS.every(k=>specs[k]),'MISSING_COHORT_PERSONA');
    assert(new Set(ensured.personas.map(x=>x.auth_user_id)).size===20,'AUTH_IDS_NOT_UNIQUE');
    assert(new Set(ensured.personas.map(x=>x.email)).size===20,'EMAILS_NOT_UNIQUE');
    assert(new Set(ensured.personas.map(x=>x.phone)).size===20,'PHONES_NOT_UNIQUE');
    report.checks.push({check:'twenty_unique_auth_identities',pass:true});

    for(const key of COHORT_KEYS){
      const spec=specs[key],c=supa();
      const {data,error}=await c.auth.signInWithPassword({email:spec.email,password:passwords[key]});
      if(error)throw error;
      assert(data.session&&data.user,'GENUINE_SESSION_NOT_ISSUED_'+key);
      assert(data.user.id===spec.auth_user_id,'AUTH_USER_MISMATCH_'+key);
      const account=await bootstrap(c,key);
      assert(account?.account?.account_id,'ACCOUNT_CONTEXT_MISSING_'+key);
      assert(account.account.lifecycle_status==='active','ACCOUNT_NOT_ACTIVE_'+key);

      sessions[key]={client:c,spec,account};
      report.intended_scenarios[key]=spec.scenario;
      report.personas[key]={
        scenario:spec.scenario,
        auth_user_id:data.user.id,
        account_id:account.account.account_id,
        lifecycle_status:account.account.lifecycle_status,
        browser_signed_in:false
      };
    }

    assert(new Set(Object.values(report.personas).map(x=>x.account_id)).size===20,'ACCOUNT_IDS_NOT_UNIQUE');
    report.checks.push({check:'twenty_genuine_sessions_and_unique_accounts',pass:true});

    const accountIds=Object.fromEntries(COHORT_KEYS.map(k=>[k,report.personas[k].account_id]));
    for(let i=0;i<COHORT_KEYS.length;i++){
      const key=COHORT_KEYS[i],s=sessions[key];
      const {data,error}=await s.client.from('accounts').select('id,auth_user_id,lifecycle_status');
      if(error)throw error;
      assert(Array.isArray(data)&&data.length===1,'ACCOUNT_RLS_ROW_COUNT_'+key+'_'+(data?.length??'null'));
      assert(data[0].id===accountIds[key],'ACCOUNT_RLS_WRONG_ACCOUNT_'+key);
      assert(data[0].auth_user_id===s.spec.auth_user_id,'ACCOUNT_RLS_WRONG_AUTH_'+key);

      const other=COHORT_KEYS[(i+1)%COHORT_KEYS.length];
      const {data:otherRows,error:otherError}=await s.client.from('accounts').select('id').eq('id',accountIds[other]);
      if(otherError)throw otherError;
      assert(Array.isArray(otherRows)&&otherRows.length===0,'ACCOUNT_RLS_CROSS_PERSONA_LEAK_'+key+'_TO_'+other);
    }
    report.checks.push({check:'own_account_rls_allow_cross_account_deny_for_all_twenty',pass:true});

    const browser=await chromium.launch({headless:true});
    try{
      for(const key of COHORT_KEYS){
        await browserSignIn(browser,sessions[key].spec,passwords[key],key);
        report.personas[key].browser_signed_in=true;
      }
    }finally{await browser.close();}
    report.checks.push({check:'twenty_isolated_chromium_signins',pass:true});

    for(const key of COHORT_KEYS){
      await sessions[key].client.auth.signOut();
    }

    report.result='pass';
    fs.writeFileSync(path.join(ARTIFACT_DIR,'cohort-20-proof.json'),JSON.stringify(report,null,2));
    console.log('RAAHI_20_PERSONA_COHORT_PASS run_id='+rid+' commit='+sha);
  }catch(error){
    report.result='fail';
    report.failure={message:safeError(error),class:'test-harness-or-environment'};
    fs.writeFileSync(path.join(ARTIFACT_DIR,'cohort-20-proof.json'),JSON.stringify(report,null,2));
    throw error;
  }
}

await main();
