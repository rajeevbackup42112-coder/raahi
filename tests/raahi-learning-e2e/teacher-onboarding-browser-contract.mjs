import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const ORIGIN='http://127.0.0.1:4173';
const SUPABASE_HOST='iiwwmqokaeflaenhlyip.supabase.co';
const ARTIFACT_DIR=path.resolve('artifacts-teacher-onboarding-browser-contract');
const VIEWPORTS=[{name:'desktop',width:1440,height:900},{name:'iphone',width:390,height:844}];
const fakeSupabaseScript="(() => {\n  const clone=v=>JSON.parse(JSON.stringify(v));\n  const params=new URLSearchParams(location.search);\n  const scenario=params.get('scenario')||'self';\n  const state={scenario,phoneFresh:false,phone:null,calls:[],\n    context:{account:{account_id:'11111111-1111-4111-8111-111111111111',display_name:'Teacher Test',avatar_type:'none',avatar_ref:null,lifecycle_status:'active',profile_onboarding_completed_at:'2026-09-23T05:00:00Z',first_use_completed_at:'2026-09-23T05:01:00Z'},selected_location:{location_id:'22222222-2222-4222-8222-222222222222',name:'Dhanbad',slug:'dhanbad',state:'live'},learners:[],capabilities:[],organizations:[],manager_scopes:[]},\n    teacherWorkspace:{profile:null,teaching_options:[]},\n    assisted:scenario==='assisted'?[{request_id:'33333333-3333-4333-8333-333333333333',teacher_account_id:'11111111-1111-4111-8111-111111111111',founding_location_id:'22222222-2222-4222-8222-222222222222',founding_location_name:'Dhanbad',state:'draft_ready',consent_text_version:'founding-supply-v1',proposed_headline:'Mathematics Teacher',proposed_bio:'I help learners understand mathematics clearly.',proposed_experience_summary:'Experienced local teacher',proposed_option_title:'Mathematics tuition',proposed_option_category:'Mathematics',proposed_option_description:'Classes for school learners',proposed_teaching_mode:'in_person',proposed_area_or_venue_text:'Dhanbad',proposed_fee_display_text:'Contact for details'}]:[]\n  };\n  window.__RAAHI_TEACHER_FAKE__=state;\n  const ok=data=>({data,error:null});\n  const gate=()=>({data:null,error:{message:'PHONE_TRUST_REQUIRED'}});\n  const rpc=async(name,args={})=>{state.calls.push({name,args:clone(args)});switch(name){\n    case 'list_public_locations': case 'list_live_locations': return ok([{location_id:'22222222-2222-4222-8222-222222222222',id:'22222222-2222-4222-8222-222222222222',name:'Dhanbad',slug:'dhanbad',state:'live'}]);\n    case 'get_my_account_context': return ok(clone(state.context));\n    case 'get_my_classes': case 'get_my_enquiries': case 'get_my_conversations': case 'get_my_learning_requests': case 'get_my_class_invitations': case 'get_my_notifications': return ok([]);\n    case 'get_my_saved_items': return ok({teachers:[],organizations:[],teaching_options:[]});\n    case 'discover_teaching_options': case 'discover_community_posts': return ok([]);\n    case 'get_sponsored_candidate': return ok(null);\n    case 'get_my_phone_trust': return ok({state:state.phoneFresh?'fresh':'unverified',has_phone:!!state.phone,masked_phone:state.phone?'******'+state.phone.slice(-4):null});\n    case 'enable_teaching': if(!state.phoneFresh)return gate(); if(!state.context.capabilities.includes('teach'))state.context.capabilities.push('teach'); return ok({capability_code:'teach'});\n    case 'get_my_teacher_workspace': return ok(clone(state.teacherWorkspace));\n    case 'upsert_teacher_profile': if(args.p_visibility_status==='visible'&&!state.phoneFresh)return gate(); state.teacherWorkspace.profile={headline:args.p_headline,bio:args.p_bio,experience_summary:args.p_experience_summary,visibility_status:args.p_visibility_status}; return ok({teacher_account_id:state.context.account.account_id,visibility_status:args.p_visibility_status});\n    case 'publish_teaching_option': if(!state.phoneFresh)return gate(); const option={teaching_option_id:'44444444-4444-4444-8444-444444444444',title:args.p_title,category:args.p_category,description:args.p_description,teaching_mode:args.p_teaching_mode,area_or_venue_text:args.p_area_or_venue_text,fee_display_text:args.p_fee_display_text,availability_status:'taking_new_learners',locations:(args.p_location_ids||[]).map(location_id=>({location_id,name:'Dhanbad'}))}; state.teacherWorkspace.teaching_options=[option]; return ok({teaching_option_id:option.teaching_option_id,availability_status:'taking_new_learners'});\n    case 'get_my_assisted_teacher_onboarding': return ok(clone(state.assisted));\n    case 'accept_assisted_teacher_onboarding': if(!state.phoneFresh)return gate(); state.context.capabilities=['teach']; state.teacherWorkspace.profile={headline:state.assisted[0].proposed_headline,bio:state.assisted[0].proposed_bio,experience_summary:state.assisted[0].proposed_experience_summary,visibility_status:'visible'}; state.teacherWorkspace.teaching_options=[{teaching_option_id:'55555555-5555-4555-8555-555555555555',title:state.assisted[0].proposed_option_title,category:state.assisted[0].proposed_option_category,teaching_mode:state.assisted[0].proposed_teaching_mode,availability_status:'taking_new_learners',locations:[{location_id:state.assisted[0].founding_location_id,name:'Dhanbad'}]}]; state.assisted[0].state='accepted'; return ok({request_id:state.assisted[0].request_id,state:'accepted'});\n    default: return {data:null,error:{message:'FAKE_RPC_NOT_IMPLEMENTED_'+name}};\n  }};\n  const session={access_token:'fake-access-token',user:{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',email:'teacher@example.test',phone:null,user_metadata:{name:'Teacher Test'}}};\n  const auth={\n    getSession:async()=>({data:{session},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),\n    updateUser:async({phone})=>{state.phone=phone;session.user.phone=phone;return {data:{user:session.user},error:null};},\n    verifyOtp:async()=>{state.phoneFresh=true;return {data:{session,user:session.user},error:null};},\n    getUser:async()=>({data:{user:session.user},error:null}),refreshSession:async()=>({data:{session},error:null}),signOut:async()=>({error:null})\n  };\n  window.supabase={createClient:()=>({auth,rpc,functions:{invoke:async()=>({data:null,error:{message:'FAKE_EDGE_CALL_FORBIDDEN'}})}})};\n})();";

function assert(v,m){if(!v)throw new Error(m);}

async function open(browser,viewport,scenario,route){
  const context=await browser.newContext({viewport:{width:viewport.width,height:viewport.height}});
  const page=await context.newPage();
  const real=[];
  page.on('request',r=>{if(r.url().includes(SUPABASE_HOST))real.push(r.url());});
  await page.route('**/supabase.min.js',r=>r.fulfill({status:200,contentType:'application/javascript',body:fakeSupabaseScript}));
  await page.route('https://'+SUPABASE_HOST+'/**',r=>r.abort('blockedbyclient'));
  await page.goto(ORIGIN+'/?scenario='+scenario+'#/'+route,{waitUntil:'domcontentloaded'});
  return {context,page,real};
}

async function phoneCheck(page){
  await page.getByRole('heading',{name:/Add a phone for trust-sensitive actions/i}).waitFor({timeout:20000});
  await page.locator('#live-fix-phone').fill('9876543210');
  await page.getByRole('button',{name:'Send phone code'}).click();
  await page.locator('#live-fix-phone-otp').fill('123456');
  await page.getByRole('button',{name:'Verify & continue'}).click();
}

async function proveSelf(browser,viewport){
  const {context,page,real}=await open(browser,viewport,'self','teacher-setup');
  try{
    await page.getByRole('heading',{name:'Set up your teaching presence'}).waitFor({timeout:20000});
    await page.getByRole('button',{name:'Set it up myself'}).click();
    await phoneCheck(page);

    await page.waitForURL(u=>u.hash==='#/teacher-profile-edit',{timeout:20000});
    await page.getByRole('heading',{name:'Teacher Profile'}).waitFor({timeout:10000});
    let body=await page.locator('body').innerText();
    assert(/Tell learners about your teaching experience and approach/i.test(body),'TEACHER_PROFILE_COPY_NOT_HUMAN_'+viewport.name);

    await page.locator('form#live-teacher-profile-form input[name="headline"]').fill('Mathematics Teacher');
    await page.locator('form#live-teacher-profile-form textarea[name="bio"]').fill('Clear, friendly mathematics teaching.');
    await page.locator('form#live-teacher-profile-form textarea[name="experience"]').fill('Experienced local teacher.');
    await page.getByRole('button',{name:'Save profile'}).click();

    await page.waitForURL(u=>u.hash==='#/teaching-option-edit',{timeout:20000});
    await page.getByRole('heading',{name:'New What I Teach'}).waitFor({timeout:10000});
    body=await page.locator('body').innerText();
    assert(/Add what you teach, how you teach, and where learners can find you/i.test(body),'WHAT_I_TEACH_COPY_NOT_HUMAN_'+viewport.name);

    await page.locator('form#live-option-form input[name="title"]').fill('Mathematics tuition');
    await page.locator('form#live-option-form input[name="category"]').fill('Mathematics');
    await page.locator('form#live-option-form textarea[name="description"]').fill('Classes for school learners.');
    await page.getByRole('button',{name:'Publish'}).click();

    await page.waitForURL(u=>u.hash==='#/teacher-home',{timeout:20000});
    await page.getByRole('heading',{name:'Teach locally, without chasing leads.'}).waitFor({timeout:10000});
    const state=await page.evaluate(()=>window.__RAAHI_TEACHER_FAKE__);
    assert(state.phoneFresh,'PHONE_NOT_FRESH_'+viewport.name);
    assert(state.context.capabilities.includes('teach'),'TEACH_NOT_GRANTED_BY_SERVER_'+viewport.name);
    assert(state.teacherWorkspace.profile?.headline==='Mathematics Teacher','PROFILE_NOT_CREATED_'+viewport.name);
    assert(state.teacherWorkspace.teaching_options.length===1,'FIRST_OPTION_NOT_CREATED_'+viewport.name);
    assert(state.calls.filter(x=>x.name==='enable_teaching').length>=2,'ENABLE_NOT_RESUMED_AFTER_PHONE_'+viewport.name);
    assert(real.length===0,'REAL_SUPABASE_NETWORK_'+real.join(','));
    const file=viewport.name+'-self-service.png';
    await page.screenshot({path:path.join(ARTIFACT_DIR,file),fullPage:true});
    return {viewport:viewport.name,scenario:'self-service',pass:true,screenshot:file};
  }finally{await context.close();}
}

async function proveAssisted(browser,viewport){
  const {context,page,real}=await open(browser,viewport,'assisted','founding-supply-help');
  try{
    await page.getByRole('heading',{name:'Review your teaching draft'}).waitFor({timeout:20000});
    await page.getByRole('button',{name:'Publish these details'}).click();
    await phoneCheck(page);
    await page.waitForURL(u=>u.hash==='#/teacher-home',{timeout:20000});
    await page.getByRole('heading',{name:'Teach locally, without chasing leads.'}).waitFor({timeout:10000});
    const state=await page.evaluate(()=>window.__RAAHI_TEACHER_FAKE__);
    assert(state.phoneFresh,'ASSISTED_PHONE_NOT_FRESH_'+viewport.name);
    assert(state.assisted[0].state==='accepted','ASSISTED_NOT_ACCEPTED_'+viewport.name);
    assert(state.teacherWorkspace.profile?.headline==='Mathematics Teacher','ASSISTED_PROFILE_NOT_CREATED_'+viewport.name);
    assert(state.teacherWorkspace.teaching_options.length===1,'ASSISTED_OPTION_NOT_CREATED_'+viewport.name);
    assert(state.calls.filter(x=>x.name==='accept_assisted_teacher_onboarding').length>=2,'ASSISTED_ACTION_NOT_RESUMED_'+viewport.name);
    assert(real.length===0,'REAL_SUPABASE_NETWORK_'+real.join(','));
    const file=viewport.name+'-assisted.png';
    await page.screenshot({path:path.join(ARTIFACT_DIR,file),fullPage:true});
    return {viewport:viewport.name,scenario:'assisted',pass:true,screenshot:file};
  }finally{await context.close();}
}

async function main(){
  fs.mkdirSync(ARTIFACT_DIR,{recursive:true});
  const browser=await chromium.launch({headless:true});
  const report={proof:'teacher-onboarding-browser-contract-v1.4k',commit:process.env.GITHUB_SHA||'unknown',checks:[],result:'running'};
  try{
    for(const viewport of VIEWPORTS){
      report.checks.push(await proveSelf(browser,viewport));
      report.checks.push(await proveAssisted(browser,viewport));
    }
    report.result='pass';
    fs.writeFileSync(path.join(ARTIFACT_DIR,'teacher-onboarding-browser-contract.json'),JSON.stringify(report,null,2));
    console.log('RAAHI_TEACHER_ONBOARDING_BROWSER_CONTRACT_PASS checks='+report.checks.length+' commit='+report.commit);
  }catch(error){
    report.result='fail';report.error=String(error?.stack||error);
    fs.writeFileSync(path.join(ARTIFACT_DIR,'teacher-onboarding-browser-contract.json'),JSON.stringify(report,null,2));
    throw error;
  }finally{await browser.close();}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
