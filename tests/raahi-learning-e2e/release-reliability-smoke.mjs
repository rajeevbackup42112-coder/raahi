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
const ARTIFACT_DIR=path.resolve('artifacts-release-reliability');
const ROUNDS=10;
const BROWSER_BATCH=5;
const KEYS=[
  'adult_learner','parent_single','parent_multi','teacher','teacher_parent',
  'second_teacher','unrelated','org_owner','org_staff_profile','org_staff_teaching',
  'org_staff_classes','org_staff_members','org_staff_ads','local_manager','admin',
  'safety_reviewer','verifier','ads_commercial','invite_recipient','recovery_actor'
];

function assert(v,m){if(!v)throw new Error(m);}
function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
function safeError(e){return e?.message||e?.details||e?.hint||String(e);}
function password(){return crypto.randomBytes(30).toString('base64url')+'Aa1!';}
function runId(){return 'release-reliability-'+(process.env.GITHUB_RUN_ID||Date.now())+'-'+(process.env.GITHUB_RUN_ATTEMPT||'1');}
function client(){return createClient(SUPABASE_URL,PUBLISHABLE_KEY,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});}
async function rpc(c,name,args={}){const {data,error}=await c.rpc(name,args);if(error)throw error;return data;}

function guards(){
  assert(new URL(DEV_ORIGIN).hostname==='dev.learning.myraahi.co.in','DEV_ORIGIN_GUARD');
  assert(new URL(SUPABASE_URL).hostname===PROJECT_REF+'.supabase.co','PROJECT_GUARD');
  assert(process.env.GITHUB_REF==='refs/heads/raahi-learning-implementation-v1','BRANCH_GUARD');
  assert(KEYS.length===20&&new Set(KEYS).size===20,'PERSONA_SET_GUARD');
}

function staticCompatible(deployed,target){
  if(deployed===target)return {compatible:true,changed:[],appChanges:[]};
  try{
    execFileSync('git',['merge-base','--is-ancestor',deployed,target],{stdio:'ignore'});
    const changed=execFileSync('git',['diff','--name-only',deployed+'..'+target],{encoding:'utf8'})
      .split(/\r?\n/).map(x=>x.trim()).filter(Boolean);
    const appChanges=changed.filter(x=>x.startsWith('apps/raahi-learning/'));
    return {compatible:appChanges.length===0,changed,appChanges};
  }catch{return {compatible:false,changed:[],appChanges:['unknown-history']};}
}

async function deployment(sha){
  const deadline=Date.now()+8*60*1000;let last=null;
  while(Date.now()<deadline){
    try{
      const res=await fetch(DEV_ORIGIN+'/build-meta.json?reliability='+Date.now(),{cache:'no-store'});
      if(res.ok){
        last=await res.json();
        const compatibility=staticCompatible(last.commit_sha,sha);
        if(compatibility.compatible)return {...last,compatibility};
      }
    }catch(e){last={error:String(e)};}
    await sleep(10000);
  }
  throw new Error('DEV_STATIC_DEPLOYMENT_NOT_COMPATIBLE expected='+sha+' last='+JSON.stringify(last));
}

async function deploymentEnd(start,sha){
  const res=await fetch(DEV_ORIGIN+'/build-meta.json?reliability-end='+Date.now(),{cache:'no-store'});
  assert(res.ok,'DEV_DEPLOYMENT_END_CHECK_'+res.status);
  const meta=await res.json();
  const compatibility=staticCompatible(meta.commit_sha,sha);
  assert(compatibility.compatible,'DEV_STATIC_DEPLOYMENT_END_NOT_COMPATIBLE '+JSON.stringify(compatibility));
  return {...meta,compatibility,changed_during_run:meta.commit_sha!==start.commit_sha};
}

async function oidc(){
  const requestUrl=process.env.ACTIONS_ID_TOKEN_REQUEST_URL;
  const requestToken=process.env.ACTIONS_ID_TOKEN_REQUEST_TOKEN;
  assert(requestUrl&&requestToken,'GITHUB_OIDC_ENV_MISSING');
  const u=new URL(requestUrl);u.searchParams.set('audience',OIDC_AUDIENCE);
  const res=await fetch(u,{headers:{authorization:'Bearer '+requestToken}});
  if(!res.ok)throw new Error('GITHUB_OIDC_REQUEST_FAILED_'+res.status);
  const body=await res.json();assert(body.value,'GITHUB_OIDC_TOKEN_MISSING');return body.value;
}

async function edge(token,payload){
  const res=await fetch(EDGE_URL,{method:'POST',headers:{authorization:'Bearer '+token,'content-type':'application/json'},body:JSON.stringify(payload)});
  const body=await res.json().catch(()=>({ok:false,error:'INVALID_JSON'}));
  if(!res.ok||!body.ok)throw new Error('IDENTITY_FACTORY_FAILED '+(body.error||res.status));
  return body;
}

async function bootstrap(c,key){
  try{return await rpc(c,'get_my_account_context');}
  catch(e){
    if(!/ACCOUNT_NOT_FOUND/i.test(safeError(e)))throw e;
    await rpc(c,'bootstrap_account',{p_display_name:'Reliability '+key.replaceAll('_',' ')});
    return rpc(c,'get_my_account_context');
  }
}

function pct(sorted,p){if(!sorted.length)return null;return sorted[Math.max(0,Math.ceil(sorted.length*p)-1)];}
function summarize(values){
  const v=[...values].sort((a,b)=>a-b);
  return {count:v.length,p50_ms:pct(v,.5),p95_ms:pct(v,.95),p99_ms:pct(v,.99),max_ms:v.at(-1)};
}

async function batches(items,size,fn){
  for(let i=0;i<items.length;i+=size)await Promise.all(items.slice(i,i+size).map(fn));
}

async function main(){
  guards();fs.mkdirSync(ARTIFACT_DIR,{recursive:true});
  const rid=runId(),sha=process.env.GITHUB_SHA;
  const report={
    proof:'raahi-learning-release-reliability-smoke-v1',
    run_id:rid,commit_sha:sha,environment:{origin:DEV_ORIGIN,project_ref:PROJECT_REF},
    scope:{personas:20,rounds:ROUNDS,steady_state_calls:20*ROUNDS*4,browser_signins:20,classification:'bounded DEV reliability smoke; not production load/capacity certification'},
    deployment:null,metrics:{auth_login_ms:[],account_context_ms:[],notifications_ms:[],own_account_rls_ms:[],public_locations_ms:[],browser_signin_ms:[]},
    checks:[],warnings:[],result:'running'
  };
  const sessions={};

  async function timed(bucket,fn){
    const start=performance.now();
    try{return await fn();}
    finally{report.metrics[bucket].push(Math.round(performance.now()-start));}
  }

  try{
    report.deployment=await deployment(sha);
    report.checks.push('DEV static artifact is exact or browser-source compatible with workflow SHA');

    const token=await oidc();
    const passwords=Object.fromEntries(KEYS.map(k=>[k,password()]));
    const ensured=await edge(token,{action:'ensure_personas',suite:'cohort',run_id:rid,passwords});
    const specs=Object.fromEntries(ensured.personas.map(x=>[x.key,x]));
    assert(KEYS.every(k=>specs[k]),'MISSING_COHORT_PERSONA');

    await batches(KEYS,5,async key=>{
      const c=client(),spec=specs[key];
      const {data,error}=await timed('auth_login_ms',()=>c.auth.signInWithPassword({email:spec.email,password:passwords[key]}));
      if(error)throw error;
      assert(data.session&&data.user?.id===spec.auth_user_id,'GENUINE_SESSION_FAILED_'+key);
      const context=await bootstrap(c,key);
      sessions[key]={client:c,spec,context,email:spec.email,password:passwords[key]};
    });
    assert(new Set(KEYS.map(k=>sessions[k].context.account.account_id)).size===20,'ACCOUNT_IDS_NOT_UNIQUE');
    report.checks.push('20 genuine sessions and 20 unique Raahi Accounts');

    const accountIds=Object.fromEntries(KEYS.map(k=>[k,sessions[k].context.account.account_id]));
    for(let round=0;round<ROUNDS;round++){
      await Promise.all(KEYS.map(async key=>{
        const s=sessions[key];
        const ctx=await timed('account_context_ms',()=>rpc(s.client,'get_my_account_context'));
        assert(ctx.account.account_id===accountIds[key],'CONTEXT_ACCOUNT_CHANGED_'+key);

        const notifications=await timed('notifications_ms',()=>rpc(s.client,'get_my_notifications',{p_limit:50}));
        assert(Array.isArray(notifications),'NOTIFICATIONS_NOT_ARRAY_'+key);

        const own=await timed('own_account_rls_ms',()=>s.client.from('accounts').select('id,lifecycle_status').eq('id',accountIds[key]));
        if(own.error)throw own.error;
        assert(own.data.length===1&&own.data[0].id===accountIds[key],'OWN_ACCOUNT_RLS_FAILED_'+key);

        const locations=await timed('public_locations_ms',()=>rpc(s.client,'list_public_locations'));
        assert(Array.isArray(locations),'PUBLIC_LOCATIONS_NOT_ARRAY_'+key);
      }));
    }
    report.checks.push('800 authenticated steady-state reads completed without unexpected errors');

    for(let i=0;i<KEYS.length;i++){
      const key=KEYS[i],other=KEYS[(i+1)%KEYS.length],s=sessions[key];
      const {data,error}=await s.client.from('accounts').select('id').eq('id',accountIds[other]);
      if(error)throw error;
      assert(data.length===0,'CROSS_ACCOUNT_RLS_LEAK_'+key+'_TO_'+other);
    }
    report.checks.push('Cross-account Account reads denied for all 20 personas');

    const browser=await chromium.launch({headless:true});
    try{
      await batches(KEYS,BROWSER_BATCH,async key=>{
        const started=performance.now();
        const ctx=await browser.newContext({viewport:{width:1280,height:900}});
        try{
          const page=await ctx.newPage();
          await page.goto(DEV_ORIGIN+'/dev-test-login-v13.html',{waitUntil:'domcontentloaded'});
          await page.locator('#email').fill(sessions[key].email);
          await page.locator('#password').fill(sessions[key].password);
          await page.locator('#signin').click();
          await page.waitForURL(u=>u.origin===DEV_ORIGIN&&u.hash==='#/home',{timeout:30000});
          const body=await page.locator('body').innerText();
          assert(!/Continue with Google/i.test(body),'BROWSER_AUTH_REGRESSION_'+key);
        }finally{
          report.metrics.browser_signin_ms.push(Math.round(performance.now()-started));
          await ctx.close();
        }
      });
    }finally{await browser.close();}
    report.checks.push('20 browser sign-ins completed in batches of five');

    for(const [name,values] of Object.entries(report.metrics))report.metrics[name]=summarize(values);
    const rpcP95=Math.max(
      report.metrics.account_context_ms.p95_ms||0,
      report.metrics.notifications_ms.p95_ms||0,
      report.metrics.own_account_rls_ms.p95_ms||0,
      report.metrics.public_locations_ms.p95_ms||0
    );
    if(rpcP95>2500)report.warnings.push('Observed authenticated-read p95 exceeded 2500 ms in DEV: '+rpcP95+' ms');
    if((report.metrics.browser_signin_ms.p95_ms||0)>12000)report.warnings.push('Observed browser sign-in p95 exceeded 12000 ms in DEV');

    report.deployment_end=await deploymentEnd(report.deployment,sha);
    report.result='passed';
  }catch(error){
    report.result='failed';
    report.error=safeError(error);
    process.exitCode=1;
  }finally{
    fs.writeFileSync(path.join(ARTIFACT_DIR,'release-reliability-proof.json'),JSON.stringify(report,null,2));
    console.log(JSON.stringify(report,null,2));
    for(const s of Object.values(sessions))await s.client.auth.signOut().catch(()=>{});
  }
}
await main();
