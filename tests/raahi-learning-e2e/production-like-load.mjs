import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const FORBIDDEN_PROJECT_REFS=new Set([
  'iiwwmqokaeflaenhlyip', // Raahi Learning DEV
  'hoshprxoyhjyyigxkang', // separate Where Is My Raahi project
]);
const FORBIDDEN_ORIGINS=new Set([
  'https://dev.learning.myraahi.co.in',
]);
const CONFIRMATION='PRODUCTION_LIKE_ISOLATED';

function required(env,key){
  const value=env[key]?.trim();
  if(!value)throw new Error('MISSING_'+key);
  return value;
}
function integer(env,key,defaultValue,{min,max}){
  const raw=env[key]?.trim();
  const value=raw?Number(raw):defaultValue;
  if(!Number.isInteger(value)||value<min||value>max)throw new Error('INVALID_'+key);
  return value;
}
function optionalNumber(env,key){
  const raw=env[key]?.trim();
  if(!raw)return null;
  const value=Number(raw);
  if(!Number.isFinite(value)||value<0)throw new Error('INVALID_'+key);
  return value;
}
function projectRef(url){
  const host=new URL(url).hostname;
  const match=host.match(/^([a-z0-9]+)\.supabase\.co$/i);
  if(!match)throw new Error('SUPABASE_URL_NOT_MANAGED_PROJECT');
  return match[1];
}
function parseIdentities(raw){
  let parsed;
  try{parsed=JSON.parse(raw);}catch{throw new Error('INVALID_RAAHI_LOAD_IDENTITIES_JSON');}
  if(!Array.isArray(parsed)||parsed.length===0)throw new Error('LOAD_IDENTITIES_EMPTY');
  const clean=parsed.map((x,i)=>{
    if(!x||typeof x.email!=='string'||typeof x.password!=='string'||!x.email.trim()||!x.password)throw new Error('INVALID_LOAD_IDENTITY_'+i);
    return {email:x.email.trim(),password:x.password};
  });
  if(new Set(clean.map(x=>x.email.toLowerCase())).size!==clean.length)throw new Error('LOAD_IDENTITIES_NOT_UNIQUE');
  return clean;
}

export function parseLoadConfig(env=process.env){
  const confirmation=required(env,'RAAHI_LOAD_CONFIRM_TARGET');
  if(confirmation!==CONFIRMATION)throw new Error('LOAD_TARGET_NOT_EXPLICITLY_CONFIRMED');

  const supabaseUrl=required(env,'RAAHI_LOAD_SUPABASE_URL');
  const publishableKey=required(env,'RAAHI_LOAD_PUBLISHABLE_KEY');
  const origin=required(env,'RAAHI_LOAD_ORIGIN').replace(/\/$/,'');
  const ref=projectRef(supabaseUrl);
  if(FORBIDDEN_PROJECT_REFS.has(ref))throw new Error('FORBIDDEN_LOAD_PROJECT_'+ref);
  if(FORBIDDEN_ORIGINS.has(origin))throw new Error('FORBIDDEN_LOAD_ORIGIN');
  if(!origin.startsWith('https://'))throw new Error('LOAD_ORIGIN_MUST_BE_HTTPS');
  if(!publishableKey.startsWith('sb_publishable_'))throw new Error('LOAD_KEY_MUST_BE_PUBLISHABLE');

  const identities=parseIdentities(required(env,'RAAHI_LOAD_IDENTITIES_JSON'));
  const concurrency=integer(env,'RAAHI_LOAD_CONCURRENCY',Math.min(identities.length,20),{min:1,max:200});
  const durationSeconds=integer(env,'RAAHI_LOAD_DURATION_SECONDS',300,{min:10,max:3600});
  if(concurrency>identities.length)throw new Error('LOAD_CONCURRENCY_EXCEEDS_IDENTITIES');

  return {
    supabaseUrl,publishableKey,origin,projectRef:ref,identities,concurrency,durationSeconds,
    maxErrorRate:optionalNumber(env,'RAAHI_LOAD_MAX_ERROR_RATE'),
    maxP95Ms:optionalNumber(env,'RAAHI_LOAD_MAX_P95_MS'),
  };
}

function client(config){
  return createClient(config.supabaseUrl,config.publishableKey,{
    auth:{persistSession:false,autoRefreshToken:true,detectSessionInUrl:false},
  });
}
function percentile(sorted,p){
  if(!sorted.length)return null;
  return sorted[Math.max(0,Math.ceil(sorted.length*p)-1)];
}
export function summarizeSamples(values){
  const sorted=[...values].sort((a,b)=>a-b);
  return {
    count:sorted.length,
    p50_ms:percentile(sorted,.50),
    p95_ms:percentile(sorted,.95),
    p99_ms:percentile(sorted,.99),
    max_ms:sorted.at(-1)??null,
  };
}
async function timed(samples,key,fn){
  const start=performance.now();
  try{return await fn();}
  finally{
    (samples[key]??=[]).push(Math.round(performance.now()-start));
  }
}
async function rpc(c,name,args={}){
  const {data,error}=await c.rpc(name,args);
  if(error)throw error;
  return data;
}
function safeError(error){return error?.message||error?.details||error?.hint||String(error);}

export async function runLoad(config){
  const report={
    proof:'raahi-learning-production-like-read-load-v1',
    started_at:new Date().toISOString(),
    target:{origin:config.origin,project_ref:config.projectRef},
    scope:{
      identities:config.identities.length,
      concurrency:config.concurrency,
      duration_seconds:config.durationSeconds,
      workload:'read-only authenticated account context + notifications + own-account RLS + public locations',
    },
    thresholds:{max_error_rate:config.maxErrorRate,max_p95_ms:config.maxP95Ms},
    samples:{},errors:[],checks:[],result:'running',
  };
  const sessions=[];
  try{
    const build=await fetch(config.origin+'/build-meta.json?load='+Date.now(),{cache:'no-store'});
    if(!build.ok)throw new Error('BUILD_META_HTTP_'+build.status);
    report.build_meta=await build.json();
    report.checks.push('target build-meta reachable');

    for(const identity of config.identities){
      const c=client(config);
      const {data,error}=await c.auth.signInWithPassword(identity);
      if(error)throw error;
      if(!data.session||!data.user)throw new Error('GENUINE_SESSION_NOT_ISSUED');
      const context=await rpc(c,'get_my_account_context');
      if(!context?.account?.account_id)throw new Error('ACCOUNT_CONTEXT_MISSING');
      sessions.push({client:c,accountId:context.account.account_id});
    }
    if(new Set(sessions.map(x=>x.accountId)).size!==sessions.length)throw new Error('LOAD_ACCOUNTS_NOT_UNIQUE');
    report.checks.push('all identities issued genuine unique Account sessions');

    for(let i=0;i<sessions.length;i++){
      const other=sessions[(i+1)%sessions.length];
      if(other===sessions[i])continue;
      const {data,error}=await sessions[i].client.from('accounts').select('id').eq('id',other.accountId);
      if(error)throw error;
      if(data.length!==0)throw new Error('CROSS_ACCOUNT_RLS_LEAK');
    }
    report.checks.push('pre-load cross-account Account reads denied');

    let operations=0;
    const deadline=Date.now()+config.durationSeconds*1000;
    async function worker(workerIndex){
      const s=sessions[workerIndex%sessions.length];
      while(Date.now()<deadline){
        try{
          const context=await timed(report.samples,'account_context_ms',()=>rpc(s.client,'get_my_account_context'));
          if(context.account.account_id!==s.accountId)throw new Error('ACCOUNT_CONTEXT_CHANGED');

          const notifications=await timed(report.samples,'notifications_ms',()=>rpc(s.client,'get_my_notifications',{p_limit:50}));
          if(!Array.isArray(notifications))throw new Error('NOTIFICATIONS_NOT_ARRAY');

          const own=await timed(report.samples,'own_account_rls_ms',()=>s.client.from('accounts').select('id,lifecycle_status').eq('id',s.accountId));
          if(own.error)throw own.error;
          if(own.data.length!==1||own.data[0].id!==s.accountId)throw new Error('OWN_ACCOUNT_RLS_FAILED');

          const locations=await timed(report.samples,'public_locations_ms',()=>rpc(s.client,'list_public_locations'));
          if(!Array.isArray(locations))throw new Error('PUBLIC_LOCATIONS_NOT_ARRAY');
          operations+=4;
        }catch(error){
          report.errors.push({worker:workerIndex,message:safeError(error),at:new Date().toISOString()});
        }
      }
    }
    await Promise.all(Array.from({length:config.concurrency},(_,i)=>worker(i)));

    report.operations=operations;
    report.error_count=report.errors.length;
    report.error_rate=(operations+report.error_count)===0?0:report.error_count/(operations+report.error_count);
    report.metrics=Object.fromEntries(Object.entries(report.samples).map(([k,v])=>[k,summarizeSamples(v)]));
    delete report.samples;

    const p95=Math.max(...Object.values(report.metrics).map(x=>x.p95_ms||0));
    report.observed_max_operation_p95_ms=p95;
    report.threshold_evaluation={
      error_rate:config.maxErrorRate===null?'not-configured':report.error_rate<=config.maxErrorRate,
      p95_ms:config.maxP95Ms===null?'not-configured':p95<=config.maxP95Ms,
    };

    const thresholdsPass=Object.values(report.threshold_evaluation).every(v=>v===true||v==='not-configured');
    report.result=report.error_count===0&&thresholdsPass?'passed':'failed';
    return report;
  }finally{
    for(const s of sessions)await s.client.auth.signOut().catch(()=>{});
    report.finished_at=new Date().toISOString();
  }
}

async function main(){
  const config=parseLoadConfig();
  const report=await runLoad(config);
  const outDir=process.env.RAAHI_LOAD_ARTIFACT_DIR?.trim()||path.resolve('artifacts-production-like-load');
  fs.mkdirSync(outDir,{recursive:true});
  const out=path.join(outDir,'production-like-load-proof.json');
  fs.writeFileSync(out,JSON.stringify(report,null,2));
  console.log(JSON.stringify(report,null,2));
  if(report.result!=='passed')process.exitCode=1;
}

if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
  await main();
}
