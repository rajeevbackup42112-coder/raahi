import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const ORIGIN='http://127.0.0.1:4173';
const ARTIFACT_DIR=path.resolve('artifacts-onboarding-browser-contract');
const SUPABASE_HOST='iiwwmqokaeflaenhlyip.supabase.co';

const INTENTS=[
  {key:'learn',label:'I want to learn',intent:'learner',destination:'learner-setup',expect:/Create your learning profile/i},
  {key:'parent',label:'I’m helping someone learn',intent:'parent',destination:'learner-add',expect:/Who are you managing\?/i},
  {key:'teacher',label:'I teach',intent:'teacher',destination:'teacher-setup',expect:/Set up your teaching presence/i},
  {key:'institute',label:'I represent an institute',intent:'institute',destination:'institute-setup',expect:/Create your institute on Raahi/i},
  {key:'explore',label:'I’m just exploring',intent:'explore',destination:'home',expect:/Find\. Learn\. Grow\./i},
];
const VIEWPORTS=[
  {name:'desktop',width:1440,height:900},
  {name:'iphone',width:390,height:844},
  {name:'android',width:412,height:915},
];

function assert(value,message){if(!value)throw new Error(message);}

const fakeSupabaseScript="(() => {\n  const clone=v=>JSON.parse(JSON.stringify(v));\n  const state={\n    context:{\n      account:{account_id:'11111111-1111-4111-8111-111111111111',display_name:'Google Default Name',avatar_type:'none',avatar_ref:null,lifecycle_status:'active',profile_onboarding_completed_at:null,first_use_completed_at:null},\n      selected_location:{location_id:'22222222-2222-4222-8222-222222222222',name:'Dhanbad',slug:'dhanbad',state:'live'},\n      learners:[],capabilities:[],organizations:[],manager_scopes:[]\n    },calls:[]\n  };\n  window.__RAAHI_ONBOARDING_FAKE__=state;\n  const rpc=async(name,args={})=>{\n    state.calls.push({name,args:clone(args)});\n    switch(name){\n      case 'list_public_locations':\n      case 'list_live_locations': return {data:[{location_id:'22222222-2222-4222-8222-222222222222',id:'22222222-2222-4222-8222-222222222222',name:'Dhanbad',slug:'dhanbad',state:'live'}],error:null};\n      case 'get_my_account_context': return {data:clone(state.context),error:null};\n      case 'get_my_classes': case 'get_my_enquiries': case 'get_my_conversations': case 'get_my_learning_requests': case 'get_my_class_invitations': case 'get_my_notifications': return {data:[],error:null};\n      case 'get_my_saved_items': return {data:{teachers:[],organizations:[],teaching_options:[]},error:null};\n      case 'discover_teaching_options': case 'discover_community_posts': return {data:[],error:null};\n      case 'get_sponsored_candidate': return {data:null,error:null};\n      case 'update_account_profile': state.context.account.display_name=args.p_display_name; state.context.account.avatar_type=args.p_avatar_type||'none'; state.context.account.avatar_ref=args.p_avatar_ref||null; return {data:{account_id:state.context.account.account_id},error:null};\n      case 'complete_profile_onboarding': state.context.account.profile_onboarding_completed_at='2026-09-23T05:00:00.000Z'; return {data:{account_id:state.context.account.account_id,profile_onboarding_completed_at:state.context.account.profile_onboarding_completed_at},error:null};\n      case 'complete_first_use_onboarding': state.context.account.first_use_completed_at='2026-09-23T05:01:00.000Z'; return {data:{account_id:state.context.account.account_id,first_use_completed_at:state.context.account.first_use_completed_at},error:null};\n      default: return {data:null,error:{message:'FAKE_RPC_NOT_IMPLEMENTED_'+name}};\n    }\n  };\n  const session={access_token:'fake-access-token',user:{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',email:'new.user@example.test',user_metadata:{name:'Google Default Name'}}};\n  const client={auth:{getSession:async()=>({data:{session},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),signOut:async()=>({error:null})},rpc,functions:{invoke:async()=>({data:null,error:{message:'FAKE_EDGE_CALL_FORBIDDEN'}})}};\n  window.supabase={createClient:()=>client};\n})();";

async function installNetworkSeal(page){
  const realRequests=[];
  page.on('request',request=>{
    const url=request.url();
    if(url.includes(SUPABASE_HOST)) realRequests.push(url);
  });
  await page.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.116.0/dist/umd/supabase.min.js',async route=>{
    await route.fulfill({status:200,contentType:'application/javascript',body:fakeSupabaseScript});
  });
  await page.route('https://'+SUPABASE_HOST+'/**',async route=>{
    await route.abort('blockedbyclient');
  });
  return realRequests;
}

async function openFresh(browser,viewport){
  const context=await browser.newContext({viewport:{width:viewport.width,height:viewport.height}});
  const page=await context.newPage();
  const realRequests=await installNetworkSeal(page);
  await page.goto(ORIGIN+'/#/teacher-home',{waitUntil:'domcontentloaded'});
  await page.getByRole('heading',{name:'Make this profile yours'}).waitFor({timeout:30000});
  return {context,page,realRequests};
}

async function proveOne(browser,viewport,intent){
  const {context,page,realRequests}=await openFresh(browser,viewport);
  try{
    assert(page.url().endsWith('#/google-profile'),'PROFILE_ROUTE_NOT_FORCED_'+viewport.name+'_'+intent.key+' url='+page.url());
    const input=page.locator('form#live-google-profile-form input[name="display"]');
    await input.fill('My Raahi Name');
    await page.getByRole('button',{name:'Save & continue'}).click();

    await page.getByRole('heading',{name:'What brings you here today?'}).waitFor({timeout:15000});
    assert(page.url().endsWith('#/onboarding-intent'),'INTENT_ROUTE_NOT_REACHED_'+viewport.name+'_'+intent.key);

    const fakeAfterProfile=await page.evaluate(()=>window.__RAAHI_ONBOARDING_FAKE__);
    assert(fakeAfterProfile.context.account.display_name==='My Raahi Name','PROFILE_NAME_NOT_SAVED_'+viewport.name+'_'+intent.key);
    assert(fakeAfterProfile.context.account.profile_onboarding_completed_at,'PROFILE_MARKER_NOT_COMPLETED_'+viewport.name+'_'+intent.key);
    assert(fakeAfterProfile.context.account.first_use_completed_at===null,'FIRST_USE_COMPLETED_TOO_EARLY_'+viewport.name+'_'+intent.key);
    assert(fakeAfterProfile.calls.some(x=>x.name==='update_account_profile'),'PROFILE_RPC_NOT_CALLED_'+viewport.name+'_'+intent.key);
    assert(fakeAfterProfile.calls.some(x=>x.name==='complete_profile_onboarding'),'PROFILE_COMPLETE_RPC_NOT_CALLED_'+viewport.name+'_'+intent.key);

    const choice=page.locator('[data-live-first-use-intent="'+intent.intent+'"]');
    await choice.waitFor({state:'visible',timeout:15000});
    assert((await choice.innerText()).includes(intent.label),'INTENT_LABEL_MISMATCH_'+intent.key);
    await choice.click();

    await page.waitForURL(u=>u.origin===ORIGIN&&u.hash==='#/'+intent.destination,{timeout:15000});
    await page.waitForTimeout(350);
    const body=await page.locator('body').innerText();
    assert(intent.expect.test(body),'DESTINATION_CONTENT_MISSING_'+viewport.name+'_'+intent.key+' body='+body.slice(0,300));

    const finalState=await page.evaluate(()=>window.__RAAHI_ONBOARDING_FAKE__);
    assert(finalState.context.account.first_use_completed_at,'FIRST_USE_MARKER_NOT_COMPLETED_'+viewport.name+'_'+intent.key);
    assert(finalState.context.learners.length===0,'INTENT_GRANTED_LEARNER_'+intent.key);
    assert(finalState.context.capabilities.length===0,'INTENT_GRANTED_CAPABILITY_'+intent.key);
    assert(finalState.context.organizations.length===0,'INTENT_GRANTED_ORGANIZATION_'+intent.key);
    assert(finalState.context.manager_scopes.length===0,'INTENT_GRANTED_MANAGER_'+intent.key);
    assert(finalState.calls.some(x=>x.name==='complete_first_use_onboarding'),'FIRST_USE_RPC_NOT_CALLED_'+intent.key);
    assert(realRequests.length===0,'REAL_SUPABASE_NETWORK_ATTEMPT_'+realRequests.join(','));

    const filename=viewport.name+'-'+intent.key+'.png';
    await page.screenshot({path:path.join(ARTIFACT_DIR,filename),fullPage:true});
    return {viewport:viewport.name,intent:intent.key,destination:intent.destination,screenshot:filename,pass:true};
  }finally{
    await context.close();
  }
}

async function main(){
  fs.mkdirSync(ARTIFACT_DIR,{recursive:true});
  const browser=await chromium.launch({headless:true});
  const report={proof:'onboarding-browser-contract-v1.4k',commit:process.env.GITHUB_SHA||'unknown',checks:[],result:'running'};
  try{
    for(const viewport of VIEWPORTS){
      for(const intent of INTENTS){
        report.checks.push(await proveOne(browser,viewport,intent));
      }
    }
    report.result='pass';
    fs.writeFileSync(path.join(ARTIFACT_DIR,'onboarding-browser-contract.json'),JSON.stringify(report,null,2));
    console.log('RAAHI_ONBOARDING_BROWSER_CONTRACT_PASS checks='+report.checks.length+' commit='+report.commit);
  }catch(error){
    report.result='fail';
    report.error=String(error?.stack||error);
    fs.writeFileSync(path.join(ARTIFACT_DIR,'onboarding-browser-contract.json'),JSON.stringify(report,null,2));
    throw error;
  }finally{
    await browser.close();
  }
}

main().catch(error=>{console.error(error);process.exitCode=1;});
