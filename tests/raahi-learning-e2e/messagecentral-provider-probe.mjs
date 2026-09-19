import crypto from 'node:crypto';
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL='https://iiwwmqokaeflaenhlyip.supabase.co';
const PROJECT_REF='iiwwmqokaeflaenhlyip';
const PUBLISHABLE_KEY='sb_publishable_bz0YgDXY-WkKxZnogGsfUg_Qgl7E-Wi';
const DEV_ORIGIN='https://dev.learning.myraahi.co.in';
const FACTORY_URL=SUPABASE_URL+'/functions/v1/dev-test-identities';
const PROBE_URL=SUPABASE_URL+'/functions/v1/phone-trust-messagecentral';
const OIDC_AUDIENCE='raahi-learning-dev-test-harness';

function assert(v,m){if(!v)throw new Error(m);}
function pwd(){return crypto.randomBytes(30).toString('base64url')+'Aa1!';}
function rid(){return 'messagecentral-probe-'+(process.env.GITHUB_RUN_ID||Date.now())+'-'+(process.env.GITHUB_RUN_ATTEMPT||'1');}

async function oidc(){
  const requestUrl=process.env.ACTIONS_ID_TOKEN_REQUEST_URL;
  const requestToken=process.env.ACTIONS_ID_TOKEN_REQUEST_TOKEN;
  assert(requestUrl&&requestToken,'GITHUB_OIDC_ENV_MISSING');
  const url=new URL(requestUrl);
  url.searchParams.set('audience',OIDC_AUDIENCE);
  const response=await fetch(url,{headers:{authorization:'Bearer '+requestToken}});
  assert(response.ok,'GITHUB_OIDC_REQUEST_FAILED_'+response.status);
  const body=await response.json();
  assert(body.value,'GITHUB_OIDC_TOKEN_MISSING');
  return body.value;
}

async function factory(token,payload){
  const response=await fetch(FACTORY_URL,{
    method:'POST',
    headers:{authorization:'Bearer '+token,'content-type':'application/json'},
    body:JSON.stringify(payload),
  });
  const body=await response.json().catch(()=>({ok:false,error:'INVALID_JSON'}));
  if(!response.ok||!body.ok)throw new Error('IDENTITY_FACTORY_FAILED_'+(body.error||response.status));
  return body;
}

async function rpc(client,name,args={}){
  const {data,error}=await client.rpc(name,args);
  if(error)throw error;
  return data;
}

async function main(){
  assert(new URL(SUPABASE_URL).hostname.split('.')[0]===PROJECT_REF,'PROJECT_GUARD');
  assert(process.env.GITHUB_REF==='refs/heads/raahi-learning-implementation-v1','BRANCH_GUARD');

  const run=rid();
  const token=await oidc();
  const passwords={learner:pwd(),teacher:pwd(),parent:pwd(),unrelated:pwd()};
  const ensured=await factory(token,{action:'ensure_personas',suite:'mcprobe',run_id:run,passwords});
  const specs=Object.fromEntries(ensured.personas.map(x=>[x.key,x]));
  assert(specs.learner?.email,'LEARNER_PERSONA_MISSING');

  const client=createClient(SUPABASE_URL,PUBLISHABLE_KEY,{
    auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},
  });

  const {data,error}=await client.auth.signInWithPassword({
    email:specs.learner.email,
    password:passwords.learner,
  });
  if(error)throw error;
  assert(data.session?.access_token,'SESSION_MISSING');

  const before=await rpc(client,'get_my_phone_trust');

  const response=await fetch(PROBE_URL,{
    method:'POST',
    headers:{
      authorization:'Bearer '+data.session.access_token,
      apikey:PUBLISHABLE_KEY,
      origin:DEV_ORIGIN,
      'content-type':'application/json',
    },
    body:JSON.stringify({action:'probe'}),
  });
  const body=await response.json().catch(()=>({ok:false,error:'INVALID_JSON'}));
  if(!response.ok||!body.ok)throw new Error('MESSAGECENTRAL_PROBE_FAILED_'+(body.error||response.status));
  assert(body.provider==='messagecentral','PROVIDER_MISMATCH');
  assert(body.configured===true,'PROVIDER_NOT_CONFIGURED');
  assert(!('token' in body)&&!('authToken' in body),'PROVIDER_TOKEN_EXPOSED');

  const after=await rpc(client,'get_my_phone_trust');
  assert(JSON.stringify(after)===JSON.stringify(before),'PHONE_TRUST_CHANGED_DURING_PROVIDER_PROBE');

  await client.auth.signOut().catch(()=>{});
  console.log('RAAHI_MESSAGECENTRAL_PROVIDER_PROBE_PASS provider=messagecentral configured=true phone_trust_unchanged=true');
}

await main();
