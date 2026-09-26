import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const ORIGIN=process.env.RAAHI_INSTITUTE_WORKSPACE_UX_ORIGIN||'http://127.0.0.1:4173';
const HOST='iiwwmqokaeflaenhlyip.supabase.co';
const OUT=path.resolve('artifacts-institute-workspace-ux-browser-contract');
const SHA=process.env.GITHUB_SHA||'local';
fs.mkdirSync(OUT,{recursive:true});

const fake=`(() => {
  const q=new URLSearchParams(location.search);
  const scenario=q.get('orgscenario')||'full';
  const orgId='22222222-2222-4222-8222-222222222222';
  const locationRow={location_id:'33333333-3333-4333-8333-333333333333',id:'33333333-3333-4333-8333-333333333333',name:'Dhanbad',slug:'dhanbad',state:'live'};
  const allCaps=['manage_ads','manage_classes','manage_members','manage_profile','manage_teaching_options'];
  const caps=scenario==='limited'?['manage_profile','manage_teaching_options']:allCaps;
  const org={organization_id:orgId,organization_type:'coaching',name:'Bright Minds Academy',description:'Local academic support for Classes 6–12.',public_contact_text:null,venue_text:'Saraidhela, Dhanbad',website_url:null,logo_type:'none',logo_ref:null,status:'active',created_at:'2026-09-20T00:00:00Z',updated_at:'2026-09-25T00:00:00Z'};
  const context={account:{account_id:'11111111-1111-4111-8111-111111111111',display_name:'Institute Operator',avatar_type:'none',avatar_ref:null,lifecycle_status:'active',profile_onboarding_completed_at:'2026-09-20T00:00:00Z',first_use_completed_at:'2026-09-20T00:01:00Z'},selected_location:locationRow,learners:[],capabilities:[],organizations:[{organization_member_id:'44444444-4444-4444-8444-444444444444',organization_id:orgId,name:org.name,organization_type:org.organization_type,status:'active',logo_type:'none',logo_ref:null,capabilities:caps}],manager_scopes:[]};
  const workspace={organization:org,teaching_options:[
    {teaching_option_id:'55555555-5555-4555-8555-555555555551',title:'Class 10 Maths',category:'Mathematics',description:'Evening support.',teaching_mode:'in_person',area_or_venue_text:'Saraidhela',fee_display_text:'₹1800/month',availability_status:'taking_new_learners',locations:[locationRow]},
    {teaching_option_id:'55555555-5555-4555-8555-555555555552',title:'Science Foundation',category:'Science',description:'Weekend support.',teaching_mode:'in_person',area_or_venue_text:'Saraidhela',fee_display_text:'Fee discussed',availability_status:'taking_new_learners',locations:[locationRow]}
  ]};
  const members=[
    {organization_member_id:'m1',organization_id:orgId,account_id:'a1',display_name:'Institute Operator',status:'active',capabilities:allCaps},
    {organization_member_id:'m2',organization_id:orgId,account_id:'a2',display_name:'Teacher A',status:'active',capabilities:['manage_classes']},
    {organization_member_id:'m3',organization_id:orgId,account_id:'a3',display_name:'Former Staff',status:'ended',capabilities:[]}
  ];
  const state={scenario,context,workspace,members,calls:[]};window.__RAAHI_INSTITUTE_UX_FAKE__=state;
  const clone=v=>JSON.parse(JSON.stringify(v)),ok=data=>({data,error:null});
  const rpc=async(name,args={})=>{state.calls.push({name,args:clone(args)});switch(name){
    case 'list_public_locations': case 'list_live_locations': return ok([locationRow]);
    case 'get_my_account_context': return ok(clone(context));
    case 'get_my_classes': case 'get_my_enquiries': case 'get_my_conversations': case 'get_my_learning_requests': case 'get_my_class_invitations': case 'get_my_notifications': return ok([]);
    case 'get_my_saved_items': return ok({teachers:[],organizations:[],teaching_options:[]});
    case 'discover_teaching_options': case 'discover_community_posts': return ok([]);
    case 'get_sponsored_candidate': return ok(null);
    case 'get_organization_workspace': return ok(clone(workspace));
    case 'get_organization_members': return ok(clone(members));
    case 'get_organization_member_invitations': case 'get_eligible_organization_class_teachers': return ok([]);
    default:return {data:null,error:{message:'INSTITUTE_UX_FAKE_RPC_'+name}};
  }};
  const svg='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80"><rect width="80" height="80" rx="40" fill="%23009999"/><text x="40" y="51" text-anchor="middle" font-size="34" fill="white">O</text></svg>');
  const session={access_token:'fake',user:{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',email:'operator@example.test',user_metadata:{name:'Institute Operator',avatar_url:svg}}};
  window.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),signOut:async()=>({error:null})},rpc,functions:{invoke:async()=>({data:null,error:{message:'EDGE_FORBIDDEN'}})}})};
})();`;
function assert(v,m){if(!v)throw new Error(m);}
async function open(browser,scenario){
  const context=await browser.newContext({viewport:{width:390,height:844}});
  const page=await context.newPage();const real=[];
  page.on('request',r=>{if(r.url().includes(HOST))real.push(r.url());});
  await page.route('**/supabase.min.js',route=>route.fulfill({status:200,contentType:'application/javascript',body:fake}));
  await page.route('https://'+HOST+'/**',route=>route.abort('blockedbyclient'));
  await page.goto(ORIGIN+'/?orgscenario='+scenario+'#/org-home',{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>document.querySelector('.v15-institute-profile-card')&&document.querySelector('.v15-institute-dashboard'),null,{timeout:12000});
  await page.waitForTimeout(250);
  return {context,page,real};
}
async function snapshot(page){
  return page.evaluate(()=>{
    const visible=e=>!!(e&&e.getClientRects().length&&getComputedStyle(e).display!=='none'&&getComputedStyle(e).visibility!=='hidden');
    const buttons=[...document.querySelectorAll('.main button')].filter(visible).map(b=>{const r=b.getBoundingClientRect();return{text:(b.innerText||b.textContent||'').trim(),route:b.dataset.route||null,w:Math.round(r.width),h:Math.round(r.height)}});
    return {
      width:innerWidth,scrollWidth:document.documentElement.scrollWidth,scrollHeight:document.documentElement.scrollHeight,
      heading:document.querySelector('.page-head h1')?.textContent?.trim(),
      subtitle:document.querySelector('.page-head p')?.textContent?.trim(),
      profile:document.querySelector('.v15-institute-profile-card')?.innerText?.replace(/\s+/g,' ').trim(),
      mark:document.querySelector('.v15-institute-mark')?.textContent?.trim(),
      markHasImage:!!document.querySelector('.v15-institute-mark img'),
      areaLabels:[...document.querySelectorAll('.v15-institute-area-label')].map(x=>x.textContent.trim()),
      learningValue:document.querySelector('.v15-institute-learning-card .v15-institute-area-value')?.textContent?.trim()||null,
      teamValue:document.querySelector('.v15-institute-team-card .v15-institute-area-value')?.textContent?.trim()||null,
      classHasValue:!!document.querySelector('.v15-institute-classes-card .v15-institute-area-value'),
      buttons,
      exactManage:buttons.filter(b=>b.text==='Manage').length,
      small:buttons.filter(b=>b.w<44||b.h<44)
    };
  });
}
const browser=await chromium.launch({headless:true});
const full=await open(browser,'full');
const fullSnap=await snapshot(full.page);
assert(fullSnap.scrollWidth<=fullSnap.width,'INSTITUTE_HOME_MOBILE_OVERFLOW_'+JSON.stringify(fullSnap));
assert(fullSnap.heading==='Institute workspace'&&fullSnap.subtitle==='Learning, Classes, team and Raahi Ads in one place.','INSTITUTE_PURPOSE_BAD_'+JSON.stringify(fullSnap));
assert(/Bright Minds Academy/.test(fullSnap.profile)&&/Coaching institute/.test(fullSnap.profile)&&/Active/.test(fullSnap.profile)&&/Local academic support for Classes 6–12\./.test(fullSnap.profile)&&/Saraidhela, Dhanbad/.test(fullSnap.profile),'INSTITUTE_IDENTITY_EVIDENCE_MISSING_'+fullSnap.profile);
assert(fullSnap.mark==='BM'&&!fullSnap.markHasImage,'INSTITUTE_PERSONAL_PHOTO_LEAK_OR_MARK_BAD_'+JSON.stringify(fullSnap));
assert(JSON.stringify(fullSnap.areaLabels)===JSON.stringify(['Learning','Classes','Team','Raahi Ads']),'INSTITUTE_AREAS_BAD_'+JSON.stringify(fullSnap.areaLabels));
assert(fullSnap.learningValue==='2'&&fullSnap.teamValue==='2','INSTITUTE_COUNTS_NOT_DERIVED_'+JSON.stringify(fullSnap));
assert(!fullSnap.classHasValue,'INSTITUTE_CLASS_COUNT_INVENTED');
assert(fullSnap.exactManage===0&&JSON.stringify(fullSnap.buttons.map(b=>b.text))===JSON.stringify(['Edit institute profile','Edit learning','Open Classes','Manage team','Open Raahi Ads']),'INSTITUTE_ACTIONS_NOT_SPECIFIC_'+JSON.stringify(fullSnap.buttons));
assert(fullSnap.small.length===0,'INSTITUTE_SMALL_TARGET_'+JSON.stringify(fullSnap.small));
const fullCalls=await full.page.evaluate(()=>window.__RAAHI_INSTITUTE_UX_FAKE__.calls.slice());
const mutationNames=['update_organization_profile','upsert_teaching_option','create_class','invite_organization_member','create_ad_campaign'];
assert(!fullCalls.some(x=>mutationNames.includes(x.name)),'INSTITUTE_HOME_MUTATED_STATE_'+JSON.stringify(fullCalls));
assert(full.real.length===0,'REAL_SUPABASE_NETWORK_FULL_'+full.real.join(','));

await full.page.evaluate(()=>window.RaahiLearningLive.api.go('org-teaching'));
await full.page.waitForFunction(()=>location.hash.startsWith('#/org-teaching'),null,{timeout:10000});
await full.page.waitForTimeout(200);
const learningText=(await full.page.locator('body').innerText()).replace(/\s+/g,' ');
assert(/Learning options offered by this institute\./.test(learningText),'INSTITUTE_LEARNING_SUBTITLE_NOT_HUMAN_'+learningText);
assert(!/staff access/i.test(learningText),'INSTITUTE_LEARNING_INTERNAL_LANGUAGE_'+learningText);

await full.page.screenshot({path:path.join(OUT,'institute-full-mobile.png'),fullPage:true});
await full.context.close();

const limited=await open(browser,'limited');
const limitedSnap=await snapshot(limited.page);
assert(JSON.stringify(limitedSnap.areaLabels)===JSON.stringify(['Learning']),'LIMITED_CAPABILITY_ACTION_LEAK_'+JSON.stringify(limitedSnap.areaLabels));
assert(JSON.stringify(limitedSnap.buttons.map(b=>b.text))===JSON.stringify(['Edit institute profile','Edit learning']),'LIMITED_CAPABILITY_BUTTON_LEAK_'+JSON.stringify(limitedSnap.buttons));
assert(limited.real.length===0,'REAL_SUPABASE_NETWORK_LIMITED_'+limited.real.join(','));
await limited.page.screenshot({path:path.join(OUT,'institute-limited-mobile.png'),fullPage:true});
await limited.context.close();

const report={proof:'raahi-institute-workspace-ux-browser-contract-v1',commit:SHA,checks:15,full:fullSnap,limited:limitedSnap,result:'pass'};
fs.writeFileSync(path.join(OUT,'institute-workspace-ux-browser-contract.json'),JSON.stringify(report,null,2));
await browser.close();
console.log('RAAHI_INSTITUTE_WORKSPACE_UX_BROWSER_CONTRACT_PASS checks=15 commit='+SHA);
