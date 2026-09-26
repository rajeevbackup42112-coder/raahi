import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const ORIGIN=process.env.RAAHI_TEACHER_WORKSPACE_UX_ORIGIN||'http://127.0.0.1:4173';
const HOST='iiwwmqokaeflaenhlyip.supabase.co';
const OUT=path.resolve('artifacts-teacher-workspace-ux-browser-contract');
const SHA=process.env.GITHUB_SHA||'local';
fs.mkdirSync(OUT,{recursive:true});

const fake=`(() => {
  const accountId='11111111-1111-4111-8111-111111111111';
  const locationRow={location_id:'22222222-2222-4222-8222-222222222222',id:'22222222-2222-4222-8222-222222222222',name:'Dhanbad',slug:'dhanbad',state:'live'};
  const gomoh={location_id:'33333333-3333-4333-8333-333333333333',name:'Gomoh',slug:'gomoh',state:'live'};
  const context={account:{account_id:accountId,display_name:'Maya Teacher',avatar_type:'none',avatar_ref:null,lifecycle_status:'active',profile_onboarding_completed_at:'2026-09-20T00:00:00Z',first_use_completed_at:'2026-09-20T00:01:00Z'},selected_location:locationRow,learners:[],capabilities:['teach'],organizations:[],manager_scopes:[]};
  const teacherWorkspace={profile:{headline:'Class 9–12 Mathematics Teacher',bio:'Local Mathematics teacher.',experience_summary:'8 years teaching Class 9–12 Mathematics.',visibility_status:'visible'},teaching_options:[{teaching_option_id:'44444444-4444-4444-8444-444444444441',title:'Mathematics Tuition',category:'Mathematics',description:'Home tuition in Gomoh.',teaching_mode:'in_person',fee_display_text:'₹3000/month',area_or_venue_text:'Gomoh',availability_status:'taking_new_learners',locations:[gomoh]}]};
  const classes=[{class_id:'55555555-5555-4555-8555-555555555555',title:'Mathematics Class 10',class_type:'one_to_one',class_state:'draft',location_id:gomoh.location_id,context_kind:'provider',learner_id:null,learner_name:null,membership_id:null,membership_state:null}];
  const notifications=[{notification_id:'n1',notification_type:'enquiry_received',title:'New Enquiry',body:'A learner sent an Enquiry.',created_at:'2026-09-25T10:00:00Z',read_at:null},{notification_id:'n2',notification_type:'class_message',title:'New Class message',body:'New message.',created_at:'2026-09-25T11:00:00Z',read_at:null}];
  const state={context,teacherWorkspace,classes,notifications,calls:[]};window.__RAAHI_TEACHER_UX_FAKE__=state;
  const clone=v=>JSON.parse(JSON.stringify(v)),ok=data=>({data,error:null});
  const rpc=async(name,args={})=>{state.calls.push({name,args:clone(args)});switch(name){
    case 'list_public_locations': case 'list_live_locations': return ok([locationRow,gomoh]);
    case 'get_my_account_context': return ok(clone(context));
    case 'get_my_classes': return ok(clone(classes));
    case 'get_my_enquiries': case 'get_my_conversations': case 'get_my_learning_requests': case 'get_my_class_invitations': return ok([]);
    case 'get_my_notifications': return ok(clone(notifications));
    case 'get_my_saved_items': return ok({teachers:[],organizations:[],teaching_options:[]});
    case 'get_my_teacher_workspace': return ok(clone(teacherWorkspace));
    case 'discover_teaching_options': return ok([]);
    case 'discover_community_posts': return ok([]);
    case 'get_sponsored_candidate': return ok(null);
    default:return {data:null,error:{message:'TEACHER_UX_FAKE_RPC_'+name}};
  }};
  const svg='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80"><rect width="80" height="80" rx="40" fill="%235d5bd6"/><text x="40" y="51" text-anchor="middle" font-size="34" fill="white">M</text></svg>');
  const session={access_token:'fake',user:{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',email:'maya@example.test',user_metadata:{name:'Maya Teacher',avatar_url:svg}}};
  window.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),signOut:async()=>({error:null})},rpc,functions:{invoke:async()=>({data:null,error:{message:'EDGE_FORBIDDEN'}})}})};
})();`;
function assert(v,m){if(!v)throw new Error(m);}
const browser=await chromium.launch({headless:true});
const context=await browser.newContext({viewport:{width:390,height:844}});
const page=await context.newPage();const real=[];
page.on('request',r=>{if(r.url().includes(HOST))real.push(r.url());});
await page.route('**/supabase.min.js',route=>route.fulfill({status:200,contentType:'application/javascript',body:fake}));
await page.route('https://'+HOST+'/**',route=>route.abort('blockedbyclient'));
await page.goto(ORIGIN+'/#/teacher-home',{waitUntil:'domcontentloaded'});
await page.waitForFunction(()=>document.querySelector('.v15-teacher-profile-card')&&document.querySelectorAll('.v15-teacher-stat-card').length===3,null,{timeout:12000});
await page.waitForTimeout(250);

const home=await page.evaluate(()=>{
  const visible=e=>!!(e&&e.getClientRects().length&&getComputedStyle(e).display!=='none'&&getComputedStyle(e).visibility!=='hidden');
  const controls=[...document.querySelectorAll('.main button,.main a')].filter(visible).map(e=>{const r=e.getBoundingClientRect();return{text:(e.innerText||e.textContent||'').replace(/\s+/g,' ').trim(),w:Math.round(r.width),h:Math.round(r.height)}});
  return {
    width:innerWidth,scrollWidth:document.documentElement.scrollWidth,
    heading:document.querySelector('.page-head h1')?.textContent?.trim(),
    subtitle:document.querySelector('.page-head p')?.textContent?.trim(),
    profileText:document.querySelector('.v15-teacher-profile-card')?.innerText?.replace(/\s+/g,' ').trim(),
    privatePhoto:!!document.querySelector('.v15-teacher-avatar img'),
    statValues:[...document.querySelectorAll('.v15-teacher-stat-card')].map(c=>({label:c.querySelector('.v15-teacher-stat-label')?.textContent?.trim(),value:c.querySelector('.v15-teacher-stat-value')?.textContent?.trim(),copy:c.querySelector('.v15-teacher-stat-copy')?.textContent?.trim(),action:c.querySelector('button')?.textContent?.trim()})),
    classTitle:document.querySelector('.v15-teacher-class-card h3')?.textContent?.trim(),
    classState:document.querySelector('.v15-teacher-class-card .badge')?.textContent?.trim(),
    small:controls.filter(x=>x.w<44||x.h<44),
    buttons:controls.map(x=>x.text)
  };
});
assert(home.scrollWidth<=home.width,'TEACHER_HOME_MOBILE_OVERFLOW_'+JSON.stringify(home));
assert(home.heading==='Your teaching'&&home.subtitle==='Profile, Classes and learner activity in one place.','TEACHER_HOME_PURPOSE_BAD_'+JSON.stringify(home));
assert(/MAYA TEACHER/i.test(home.profileText)&&/Class 9–12 Mathematics Teacher/.test(home.profileText)&&/8 years teaching/.test(home.profileText)&&/Profile visible/.test(home.profileText)&&/Gomoh/.test(home.profileText),'TEACHER_IDENTITY_EVIDENCE_MISSING_'+home.profileText);
assert(home.privatePhoto,'TEACHER_PRIVATE_PHOTO_FALLBACK_MISSING');
assert(JSON.stringify(home.statValues)===JSON.stringify([
  {label:'What I teach',value:'1',copy:'teaching option',action:'Edit what I teach'},
  {label:'Classes',value:'1',copy:'current Class',action:'Open Classes'},
  {label:'Updates',value:'2',copy:'unread updates',action:'Messages'}
]),'TEACHER_STATS_NOT_DERIVED_'+JSON.stringify(home.statValues));
assert(home.classTitle==='Mathematics Class 10'&&home.classState==='Draft','TEACHER_CLASS_PRESENCE_LOST_'+JSON.stringify(home));
assert(home.small.length===0,'TEACHER_HOME_SMALL_TARGET_'+JSON.stringify(home.small));
assert(!home.buttons.includes('Manage'),'TEACHER_GENERIC_MANAGE_RETURNED_'+JSON.stringify(home.buttons));
const callsAfterHome=await page.evaluate(()=>window.__RAAHI_TEACHER_UX_FAKE__.calls.slice());
const mutationNames=['update_teacher_profile','upsert_teaching_option','create_class','enable_teaching'];
assert(!callsAfterHome.some(x=>mutationNames.includes(x.name)),'TEACHER_HOME_MUTATED_AUTHORITY_'+JSON.stringify(callsAfterHome));

await page.evaluate(()=>window.RaahiLearningLive.api.go('explore'));
await page.waitForFunction(()=>document.querySelectorAll('.v14-category-chip').length===5,null,{timeout:10000});
const explore=await page.evaluate(()=>({
  scrollWidth:document.documentElement.scrollWidth,width:innerWidth,
  chips:[...document.querySelectorAll('.v14-category-chip')].map(c=>({text:c.textContent.trim(),h:Math.round(c.getBoundingClientRect().height),w:Math.round(c.getBoundingClientRect().width)}))
}));
assert(explore.scrollWidth<=explore.width,'EXPLORE_AFTER_TEACHER_SLICE_OVERFLOW_'+JSON.stringify(explore));
assert(explore.chips.length===5&&explore.chips.every(x=>x.h>=44&&x.w>=44),'EXPLORE_TOPIC_TARGET_REGRESSION_'+JSON.stringify(explore.chips));

await page.screenshot({path:path.join(OUT,'teacher-home-mobile.png'),fullPage:true});
assert(real.length===0,'REAL_SUPABASE_NETWORK_'+real.join(','));
const report={proof:'raahi-teacher-workspace-ux-browser-contract-v1',commit:SHA,checks:10,home,explore,result:'pass'};
fs.writeFileSync(path.join(OUT,'teacher-workspace-ux-browser-contract.json'),JSON.stringify(report,null,2));
await browser.close();
console.log('RAAHI_TEACHER_WORKSPACE_UX_BROWSER_CONTRACT_PASS checks=10 commit='+SHA);
