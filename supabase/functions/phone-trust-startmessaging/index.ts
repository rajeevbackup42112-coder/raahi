import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.116.0';

const SUPABASE_URL=Deno.env.get('SUPABASE_URL')||'';
const SERVICE_ROLE_KEY=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||'';
const BASE='https://api.startmessaging.com';
const PROVIDER='startmessaging';
const MAX_VERIFY_ATTEMPTS=5;
const USER_SENDS_PER_10_MIN=3;
const USER_SENDS_PER_DAY=10;
const PHONE_SENDS_PER_10_MIN=5;
const DEFAULT_TTL=300;
const ALLOWED_ORIGINS=new Set([
  'https://dev.learning.myraahi.co.in',
  'https://learning.myraahi.co.in',
]);

type Json=Record<string,unknown>;

function cors(req:Request){
  const origin=req.headers.get('origin')||'';
  return {
    ...(ALLOWED_ORIGINS.has(origin)?{'access-control-allow-origin':origin}:{}),
    'access-control-allow-headers':'authorization, x-client-info, apikey, content-type',
    'access-control-allow-methods':'POST, OPTIONS',
    'vary':'Origin',
  };
}
function reply(req:Request,status:number,body:Json){
  return new Response(JSON.stringify(body),{
    status,
    headers:{'content-type':'application/json; charset=utf-8','cache-control':'no-store',...cors(req)},
  });
}
function requiredEnv(name:string){
  const value=Deno.env.get(name)?.trim()||'';
  if(!value)throw new Error('STARTMESSAGING_NOT_CONFIGURED');
  return value;
}
function normalizeIndiaPhone(value:unknown){
  const phone=String(value||'').trim().replace(/[\s()-]/g,'');
  if(!/^\+91[6-9][0-9]{9}$/.test(phone))throw new Error('INDIA_PHONE_REQUIRED');
  return phone;
}
function masked(phone:string){return '••••'+phone.slice(-4);}
function fresh(at:string|null|undefined){
  if(!at)return false;
  const t=Date.parse(at);
  return Number.isFinite(t)&&t+90*24*60*60*1000>Date.now();
}
function ttl(){
  const raw=Number(Deno.env.get('STARTMESSAGING_OTP_TTL_SECONDS')||DEFAULT_TTL);
  return Math.max(60,Math.min(600,Number.isFinite(raw)?raw:DEFAULT_TTL));
}
function randomOtp6(){
  const range=1_000_000;
  const limit=Math.floor(0x100000000/range)*range;
  const a=new Uint32Array(1);
  let n=0;
  do{crypto.getRandomValues(a);n=a[0];}while(n>=limit);
  return String(n%range).padStart(6,'0');
}
function hex(buf:ArrayBuffer){
  return Array.from(new Uint8Array(buf),b=>b.toString(16).padStart(2,'0')).join('');
}
async function digest(challengeId:string,phone:string,code:string){
  const enc=new TextEncoder();
  const key=await crypto.subtle.importKey(
    'raw',
    enc.encode(SERVICE_ROLE_KEY),
    {name:'HMAC',hash:'SHA-256'},
    false,
    ['sign'],
  );
  return hex(await crypto.subtle.sign(
    'HMAC',
    key,
    enc.encode(`raahi-phone-trust-startmessaging-v1:${challengeId}:${phone}:${code}`),
  ));
}
function same(a:string,b:string){
  if(a.length!==b.length)return false;
  let diff=0;
  for(let i=0;i<a.length;i++)diff|=a.charCodeAt(i)^b.charCodeAt(i);
  return diff===0;
}

if(!SUPABASE_URL||!SERVICE_ROLE_KEY)throw new Error('SUPABASE_EDGE_ENV_MISSING');
const admin=createClient(SUPABASE_URL,SERVICE_ROLE_KEY,{
  auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},
});

async function requireUser(req:Request){
  const header=req.headers.get('authorization')||'';
  const match=header.match(/^Bearer\s+(.+)$/i);
  if(!match)throw new Error('AUTH_REQUIRED');
  const {data,error}=await admin.auth.getUser(match[1]);
  if(error||!data.user)throw new Error('AUTH_REQUIRED');
  return data.user;
}
async function countChallenges(filters:{authUserId?:string;phone?:string;since:string}){
  let q=admin.from('phone_trust_challenges').select('id',{count:'exact',head:true}).gte('created_at',filters.since);
  if(filters.authUserId)q=q.eq('auth_user_id',filters.authUserId);
  if(filters.phone)q=q.eq('phone_e164',filters.phone);
  const {count,error}=await q;
  if(error)throw error;
  return count||0;
}

async function sendProvider(phone:string,otp:string){
  const apiKey=requiredEnv('STARTMESSAGING_API_KEY');
  const templateId=Deno.env.get('STARTMESSAGING_TEMPLATE_ID')?.trim()||'';
  const payload:Record<string,unknown>={
    phoneNumber:phone,
    variables:{otp,appName:'Raahi Learning'},
  };
  if(templateId)payload.templateId=templateId;

  const res=await fetch(`${BASE}/otp/send`,{
    method:'POST',
    headers:{'content-type':'application/json','x-api-key':apiKey,accept:'application/json'},
    body:JSON.stringify(payload),
  });
  const body=await res.json().catch(()=>({}));
  const statusCode=Number(body?.statusCode??res.status);
  const messageId=body?.data?.messageId;

  if(!res.ok||body?.success!==true||statusCode<200||statusCode>=300||!messageId){
    console.error('[phone-trust-startmessaging] provider send failure',{
      http_status:res.status,
      provider_status_code:statusCode,
      provider_request_id:body?.requestId??null,
      provider_status:body?.data?.status??null,
    });
    if(res.status===401||statusCode===401)throw new Error('STARTMESSAGING_AUTH_FAILED');
    if(res.status===402||statusCode===402)throw new Error('PHONE_OTP_PROVIDER_BALANCE');
    if(res.status===429||statusCode===429)throw new Error('PHONE_OTP_PROVIDER_LIMIT');
    throw new Error('PHONE_OTP_SEND_FAILED');
  }
  return String(messageId);
}

async function sendChallenge(req:Request,user:any,body:any){
  if(fresh(user.phone_confirmed_at)&&!body?.phone)throw new Error('PHONE_ALREADY_FRESH');

  const existing=user.phone?normalizeIndiaPhone(user.phone):null;
  const phone=user.phone_confirmed_at?existing!:normalizeIndiaPhone(body?.phone||existing);

  const now=Date.now();
  const tenMinAgo=new Date(now-10*60*1000).toISOString();
  const dayAgo=new Date(now-24*60*60*1000).toISOString();
  const [user10m,userDay,phone10m]=await Promise.all([
    countChallenges({authUserId:user.id,since:tenMinAgo}),
    countChallenges({authUserId:user.id,since:dayAgo}),
    countChallenges({phone,since:tenMinAgo}),
  ]);
  if(user10m>=USER_SENDS_PER_10_MIN||userDay>=USER_SENDS_PER_DAY||phone10m>=PHONE_SENDS_PER_10_MIN){
    throw new Error('PHONE_OTP_RATE_LIMIT');
  }

  const {data:recent,error:recentError}=await admin
    .from('phone_trust_challenges')
    .select('id,phone_e164,expires_at,created_at')
    .eq('auth_user_id',user.id)
    .eq('phone_e164',phone)
    .eq('provider',PROVIDER)
    .eq('state','sent')
    .gt('expires_at',new Date().toISOString())
    .order('created_at',{ascending:false})
    .limit(1)
    .maybeSingle();
  if(recentError)throw recentError;

  if(recent&&Date.parse(recent.created_at)>now-15_000){
    return reply(req,200,{
      ok:true,
      challenge_id:recent.id,
      masked_phone:masked(recent.phone_e164),
      expires_in:Math.max(1,Math.ceil((Date.parse(recent.expires_at)-now)/1000)),
      provider:PROVIDER,
      reused:true,
    });
  }

  await admin.from('phone_trust_challenges')
    .update({state:'expired',updated_at:new Date().toISOString()})
    .eq('auth_user_id',user.id)
    .eq('state','sent');

  const challengeId=crypto.randomUUID();
  const otp=randomOtp6();
  const otpDigest=await digest(challengeId,phone,otp);
  const messageId=await sendProvider(phone,otp);
  const createdAt=new Date();
  const expiresAt=new Date(createdAt.getTime()+ttl()*1000);

  const {error}=await admin.from('phone_trust_challenges').insert({
    id:challengeId,
    auth_user_id:user.id,
    phone_e164:phone,
    provider:PROVIDER,
    provider_verification_id:messageId,
    otp_digest:otpDigest,
    state:'sent',
    verify_attempts:0,
    expires_at:expiresAt.toISOString(),
    created_at:createdAt.toISOString(),
    updated_at:createdAt.toISOString(),
  });
  if(error)throw error;

  return reply(req,200,{
    ok:true,
    challenge_id:challengeId,
    masked_phone:masked(phone),
    expires_in:ttl(),
    provider:PROVIDER,
    reused:false,
  });
}

async function verifyChallenge(req:Request,user:any,body:any){
  const challengeId=String(body?.challenge_id||'');
  const code=String(body?.code||'').trim();
  if(!/^[0-9a-f-]{36}$/i.test(challengeId))throw new Error('CHALLENGE_NOT_FOUND');
  if(!/^\d{4,6}$/.test(code))throw new Error('INVALID_OTP');

  const {data:c,error}=await admin
    .from('phone_trust_challenges')
    .select('id,auth_user_id,phone_e164,state,verify_attempts,expires_at,otp_digest')
    .eq('id',challengeId)
    .eq('auth_user_id',user.id)
    .eq('provider',PROVIDER)
    .maybeSingle();
  if(error)throw error;
  if(!c)throw new Error('CHALLENGE_NOT_FOUND');

  if(c.state==='verified'){
    const {data:latest}=await admin.auth.admin.getUserById(user.id);
    if(latest.user?.id===user.id&&latest.user?.phone===c.phone_e164&&latest.user?.phone_confirmed_at){
      return reply(req,200,{ok:true,verified:true,masked_phone:masked(c.phone_e164),provider:PROVIDER,replay:true});
    }
    throw new Error('CHALLENGE_NOT_ACTIVE');
  }
  if(c.state!=='sent')throw new Error('CHALLENGE_NOT_ACTIVE');
  if(Date.parse(c.expires_at)<=Date.now()){
    await admin.from('phone_trust_challenges').update({state:'expired',updated_at:new Date().toISOString()}).eq('id',c.id);
    throw new Error('CHALLENGE_EXPIRED');
  }
  if(Number(c.verify_attempts)>=MAX_VERIFY_ATTEMPTS){
    await admin.from('phone_trust_challenges').update({state:'failed',updated_at:new Date().toISOString()}).eq('id',c.id);
    throw new Error('VERIFY_ATTEMPTS_EXCEEDED');
  }

  const next=Number(c.verify_attempts)+1;
  const {data:locked,error:lockError}=await admin
    .from('phone_trust_challenges')
    .update({verify_attempts:next,updated_at:new Date().toISOString()})
    .eq('id',c.id)
    .eq('state','sent')
    .eq('verify_attempts',c.verify_attempts)
    .select('id')
    .maybeSingle();
  if(lockError)throw lockError;
  if(!locked)throw new Error('CHALLENGE_NOT_ACTIVE');

  const submitted=await digest(c.id,c.phone_e164,code);
  if(!c.otp_digest||!same(String(c.otp_digest),submitted)){
    if(next>=MAX_VERIFY_ATTEMPTS){
      await admin.from('phone_trust_challenges').update({state:'failed',updated_at:new Date().toISOString()}).eq('id',c.id);
      throw new Error('VERIFY_ATTEMPTS_EXCEEDED');
    }
    throw new Error('INVALID_OTP');
  }

  const {data:updated,error:updateError}=await admin.auth.admin.updateUserById(user.id,{
    phone:c.phone_e164,
    phone_confirm:true,
  });
  if(updateError){
    console.error('[phone-trust-startmessaging] auth confirm failure',{
      code:updateError.code??null,
      status:updateError.status??null,
    });
    if(/already|exists|registered/i.test(updateError.message||''))throw new Error('PHONE_ALREADY_IN_USE');
    throw new Error('PHONE_CONFIRM_FAILED');
  }
  if(updated.user?.id!==user.id||updated.user?.phone!==c.phone_e164||!updated.user?.phone_confirmed_at){
    throw new Error('IDENTITY_CONTINUITY_FAILED');
  }

  const {error:auditError}=await admin.from('phone_trust_challenges')
    .update({state:'verified',verified_at:updated.user.phone_confirmed_at,updated_at:new Date().toISOString()})
    .eq('id',c.id);
  if(auditError)console.error('[phone-trust-startmessaging] challenge audit update failed',{challenge_id:c.id});

  return reply(req,200,{ok:true,verified:true,masked_phone:masked(c.phone_e164),provider:PROVIDER});
}

function publicError(error:unknown){
  const code=String((error as Error)?.message||error||'PHONE_TRUST_FAILED');
  const map:Record<string,number>={
    AUTH_REQUIRED:401,
    INDIA_PHONE_REQUIRED:400,
    PHONE_ALREADY_FRESH:409,
    PHONE_OTP_RATE_LIMIT:429,
    PHONE_OTP_PROVIDER_LIMIT:429,
    PHONE_OTP_PROVIDER_BALANCE:402,
    PHONE_OTP_SEND_FAILED:502,
    STARTMESSAGING_AUTH_FAILED:502,
    STARTMESSAGING_NOT_CONFIGURED:503,
    CHALLENGE_NOT_FOUND:404,
    CHALLENGE_EXPIRED:410,
    CHALLENGE_NOT_ACTIVE:409,
    VERIFY_ATTEMPTS_EXCEEDED:429,
    INVALID_OTP:400,
    PHONE_ALREADY_IN_USE:409,
    PHONE_CONFIRM_FAILED:502,
    IDENTITY_CONTINUITY_FAILED:409,
  };
  return {code,status:map[code]||500};
}

Deno.serve(async(req:Request)=>{
  if(req.method==='OPTIONS'){
    const origin=req.headers.get('origin')||'';
    if(origin&&!ALLOWED_ORIGINS.has(origin))return reply(req,403,{ok:false,error:'ORIGIN_NOT_ALLOWED'});
    return new Response(null,{status:204,headers:cors(req)});
  }
  if(req.method!=='POST')return reply(req,405,{ok:false,error:'POST_REQUIRED'});

  try{
    const user=await requireUser(req);
    const body=await req.json().catch(()=>({}));
    const action=String(body?.action||'');
    if(action==='send')return await sendChallenge(req,user,body);
    if(action==='verify')return await verifyChallenge(req,user,body);
    return reply(req,400,{ok:false,error:'ACTION_NOT_SUPPORTED'});
  }catch(error){
    const safe=publicError(error);
    if(safe.status>=500)console.error('[phone-trust-startmessaging] request failed',{code:safe.code});
    return reply(req,safe.status,{ok:false,error:safe.code});
  }
});
