import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { createClient } from '@supabase/supabase-js';

const FORBIDDEN_REFS=new Set([
  'iiwwmqokaeflaenhlyip',
  'hoshprxoyhjyyigxkang',
]);
const FORBIDDEN_ORIGINS=new Set(['https://dev.learning.myraahi.co.in']);
const NON_DEV_CONFIRMATION='NON_DEV_LEARNING_TARGET';

function required(env,key){
  const value=env[key]?.trim();
  if(!value)throw new Error('MISSING_'+key);
  return value;
}
function refFromUrl(url){
  const host=new URL(url).hostname;
  const match=host.match(/^([a-z0-9]+)\.supabase\.co$/i);
  if(!match)throw new Error('SUPABASE_URL_NOT_MANAGED_PROJECT');
  return match[1];
}
export function parseCanaryConfig(env=process.env){
  const mode=(env.RAAHI_CANARY_MODE||'NON_DEV').trim();
  const confirmation=required(env,'RAAHI_CANARY_CONFIRM_TARGET');
  const supabaseUrl=required(env,'RAAHI_CANARY_SUPABASE_URL');
  const projectRef=refFromUrl(supabaseUrl);
  const expectedProjectRef=required(env,'RAAHI_CANARY_EXPECTED_PROJECT_REF');
  if(expectedProjectRef!==projectRef)throw new Error('CANARY_PROJECT_REF_MISMATCH');
  const origin=required(env,'RAAHI_CANARY_ORIGIN').replace(/\/$/,'');
  const publishableKey=required(env,'RAAHI_CANARY_PUBLISHABLE_KEY');

  if(mode==='CONTROLLED_PILOT')throw new Error('CONTROLLED_PILOT_GOOGLE_BROWSER_CANARY_REQUIRED');
  if(mode!=='NON_DEV')throw new Error('INVALID_RAAHI_CANARY_MODE');
  if(confirmation!==NON_DEV_CONFIRMATION)throw new Error('CANARY_TARGET_NOT_EXPLICITLY_CONFIRMED');
  if(FORBIDDEN_REFS.has(projectRef))throw new Error('FORBIDDEN_CANARY_PROJECT_'+projectRef);

  if(FORBIDDEN_ORIGINS.has(origin))throw new Error('FORBIDDEN_CANARY_ORIGIN');
  if(!origin.startsWith('https://'))throw new Error('CANARY_ORIGIN_MUST_BE_HTTPS');
  if(!publishableKey.startsWith('sb_publishable_'))throw new Error('CANARY_KEY_MUST_BE_PUBLISHABLE');

  const primary={email:required(env,'RAAHI_CANARY_PRIMARY_EMAIL'),password:required(env,'RAAHI_CANARY_PRIMARY_PASSWORD')};
  const unrelated={email:required(env,'RAAHI_CANARY_UNRELATED_EMAIL'),password:required(env,'RAAHI_CANARY_UNRELATED_PASSWORD')};
  if(primary.email.toLowerCase()===unrelated.email.toLowerCase())throw new Error('CANARY_IDENTITIES_MUST_DIFFER');

  return {mode,supabaseUrl,projectRef,expectedProjectRef,origin,publishableKey,primary,unrelated};
}

function client(config){
  return createClient(config.supabaseUrl,config.publishableKey,{
    auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},
  });
}
async function rpc(c,name,args={}){
  const {data,error}=await c.rpc(name,args);
  if(error)throw error;
  return data;
}
async function timed(metrics,key,fn){
  const start=performance.now();
  try{return await fn();}
  finally{metrics[key]=Math.round(performance.now()-start);}
}
function safeError(e){return e?.message||e?.details||e?.hint||String(e);}

export async function runCanary(config){
  const report={
    proof:'raahi-learning-production-candidate-canary-v1',
    started_at:new Date().toISOString(),
    target:{origin:config.origin,project_ref:config.projectRef},
    checks:[],metrics:{},result:'running',
  };
  const sessions=[];
  try{
    const build=await timed(report.metrics,'build_meta_ms',async()=>{
      const response=await fetch(config.origin+'/build-meta.json?canary='+Date.now(),{cache:'no-store'});
      if(!response.ok)throw new Error('BUILD_META_HTTP_'+response.status);
      return response.json();
    });
    report.build_meta=build;
    report.checks.push('build-meta reachable');

    const devLogin=await fetch(config.origin+'/dev-test-login-v13.html?canary='+Date.now(),{cache:'no-store'});
    const devLoginText=await devLogin.text().catch(()=> '');
    if(devLoginText.includes('RAAHI_DEV_TEST_LOGIN_V13'))throw new Error('DEV_TEST_LOGIN_EXPOSED_ON_NON_DEV_TARGET');
    report.checks.push('DEV-only login marker absent');

    const anonymous=client(config);
    const anonLocations=await anonymous.rpc('list_public_locations');
    if(!anonLocations.error)throw new Error('DEFERRED_ANONYMOUS_LOCATION_RPC_AVAILABLE');
    report.checks.push('deferred anonymous location RPC denied');

    for(const [key,identity] of [['primary',config.primary],['unrelated',config.unrelated]]){
      const c=client(config);
      const {data,error}=await timed(report.metrics,key+'_auth_ms',()=>c.auth.signInWithPassword(identity));
      if(error)throw error;
      if(!data.session||!data.user)throw new Error('GENUINE_SESSION_NOT_ISSUED_'+key);
      const context=await timed(report.metrics,key+'_account_context_ms',()=>rpc(c,'get_my_account_context'));
      if(!context?.account?.account_id)throw new Error('ACCOUNT_CONTEXT_MISSING_'+key);
      sessions.push({key,client:c,accountId:context.account.account_id});
    }
    if(sessions[0].accountId===sessions[1].accountId)throw new Error('CANARY_ACCOUNTS_NOT_UNIQUE');
    report.checks.push('two genuine sessions mapped to distinct Raahi Accounts');

    for(const s of sessions){
      const own=await timed(report.metrics,s.key+'_own_account_rls_ms',()=>s.client.from('accounts').select('id,lifecycle_status').eq('id',s.accountId));
      if(own.error)throw own.error;
      if(own.data.length!==1||own.data[0].id!==s.accountId)throw new Error('OWN_ACCOUNT_RLS_FAILED_'+s.key);

      const other=sessions.find(x=>x!==s);
      const cross=await timed(report.metrics,s.key+'_cross_account_rls_ms',()=>s.client.from('accounts').select('id').eq('id',other.accountId));
      if(cross.error)throw cross.error;
      if(cross.data.length!==0)throw new Error('CROSS_ACCOUNT_RLS_LEAK_'+s.key);

      const locations=await timed(report.metrics,s.key+'_locations_rpc_ms',()=>rpc(s.client,'list_public_locations'));
      if(!Array.isArray(locations))throw new Error('AUTH_LOCATIONS_NOT_ARRAY_'+s.key);

      const notifications=await timed(report.metrics,s.key+'_notifications_rpc_ms',()=>rpc(s.client,'get_my_notifications',{p_limit:20}));
      if(!Array.isArray(notifications))throw new Error('NOTIFICATIONS_NOT_ARRAY_'+s.key);
    }
    report.checks.push('own-account RLS allow / cross-account deny for both canaries');
    report.checks.push('authenticated location and notification projections healthy');

    report.result='passed';
  }catch(error){
    report.result='failed';
    report.error=safeError(error);
  }finally{
    for(const s of sessions)await s.client.auth.signOut().catch(()=>{});
    report.finished_at=new Date().toISOString();
  }
  return report;
}

async function main(){
  const report=await runCanary(parseCanaryConfig());
  const outDir=process.env.RAAHI_CANARY_ARTIFACT_DIR?.trim()||path.resolve('artifacts-production-canary');
  fs.mkdirSync(outDir,{recursive:true});
  fs.writeFileSync(path.join(outDir,'production-canary-proof.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report,null,2));
  if(report.result!=='passed')process.exitCode=1;
}

if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
  await main();
}
