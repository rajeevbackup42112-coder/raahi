import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const ORIGIN=process.env.RAAHI_MANAGER_WORKSPACE_UX_ORIGIN||'http://127.0.0.1:4173';
const HOST='iiwwmqokaeflaenhlyip.supabase.co';
const OUT=path.resolve('artifacts-manager-workspace-ux-browser-contract');
const SHA=process.env.GITHUB_SHA||'local';
fs.mkdirSync(OUT,{recursive:true});

const fake=`(() => {
  const locationId='22222222-2222-4222-8222-222222222222';
  const locationRow={location_id:locationId,id:locationId,name:'Dhanbad',slug:'dhanbad',state:'live'};
  const overview={location_id:locationId,open_reports:2,active_classes:7,teaching_options:11,live_ad_placements:1,open_learning_requests:4,published_community_posts:9};
  const context={account:{account_id:'11111111-1111-4111-8111-111111111111',display_name:'Dhanbad Manager',avatar_type:'none',avatar_ref:null,lifecycle_status:'active',profile_onboarding_completed_at:'2026-09-20T00:00:00Z',first_use_completed_at:'2026-09-20T00:01:00Z'},selected_location:locationRow,learners:[],capabilities:[],organizations:[],manager_scopes:[{manager_scope_id:'33333333-3333-4333-8333-333333333333',location_id:locationId,location_name:'Dhanbad',status:'active'}]};
  const state={context,overview,calls:[]};window.__RAAHI_MANAGER_UX_FAKE__=state;
  const clone=v=>JSON.parse(JSON.stringify(v)),ok=data=>({data,error:null});
  const rpc=async(name,args={})=>{state.calls.push({name,args:clone(args)});switch(name){
    case 'list_public_locations': case 'list_live_locations': return ok([locationRow]);
    case 'get_my_account_context': return ok(clone(context));
    case 'get_my_classes': case 'get_my_enquiries': case 'get_my_conversations': case 'get_my_learning_requests': case 'get_my_class_invitations': case 'get_my_notifications': return ok([]);
    case 'get_my_saved_items': return ok({teachers:[],organizations:[],teaching_options:[]});
    case 'discover_teaching_options': case 'discover_community_posts': return ok([]);
    case 'get_sponsored_candidate': return ok(null);
    case 'get_local_manager_overview': return ok(clone(overview));
    case 'get_local_manager_reports': case 'get_ad_review_queue': return ok([]);
    default:return {data:null,error:{message:'MANAGER_UX_FAKE_RPC_'+name}};
  }};
  const svg='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80"><rect width="80" height="80" rx="40" fill="%235d5bd6"/><text x="40" y="51" text-anchor="middle" font-size="34" fill="white">D</text></svg>');
  const session={access_token:'fake',user:{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',email:'manager@example.test',user_metadata:{name:'Dhanbad Manager',avatar_url:svg}}};
  window.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),signOut:async()=>({error:null})},rpc,functions:{invoke:async()=>({data:null,error:{message:'EDGE_FORBIDDEN'}})}})};
})();`;

function assert(v,m){if(!v)throw new Error(m);}
async function snapshot(page){
  return page.evaluate(()=>{
    const visible=e=>!!(e&&e.getClientRects().length&&getComputedStyle(e).display!=='none'&&getComputedStyle(e).visibility!=='hidden');
    const buttons=[...document.querySelectorAll('.main button,.main a')].filter(visible).map(e=>{const r=e.getBoundingClientRect();return{text:(e.innerText||e.textContent||'').replace(/\s+/g,' ').trim(),w:Math.round(r.width),h:Math.round(r.height),route:e.dataset.route||null}});
    return {
      width:innerWidth,scrollWidth:document.documentElement.scrollWidth,scrollHeight:document.documentElement.scrollHeight,
      heading:document.querySelector('.page-head h1')?.textContent?.trim()||'',
      subtitle:document.querySelector('.page-head p')?.textContent?.trim()||'',
      body:(document.body.innerText||'').replace(/\s+/g,' ').trim(),
      scope:document.querySelector('.v15-manager-scope-card')?.innerText?.replace(/\s+/g,' ').trim()||null,
      privacy:document.querySelector('.v15-manager-privacy-card')?.innerText?.replace(/\s+/g,' ').trim()||null,
      metrics:[...document.querySelectorAll('.v15-manager-metric-card')].map(c=>({value:c.querySelector('.v15-manager-metric-value')?.textContent?.trim(),label:c.querySelector('.v15-manager-metric-label')?.textContent?.trim(),copy:c.querySelector('.v15-manager-metric-copy')?.textContent?.trim()})),
      buttons,
      small:buttons.filter(b=>b.w<44||b.h<44),
      rawSummary:!!document.querySelector('.main code,.main pre'),
      generic:buttons.filter(b=>/^(Manage|Open|View|Go)$/i.test(b.text))
    };
  });
}

const browser=await chromium.launch({headless:true});
const context=await browser.newContext({viewport:{width:390,height:844}});
const page=await context.newPage();const real=[];
page.on('request',r=>{if(r.url().includes(HOST))real.push(r.url());});
await page.route('**/supabase.min.js',route=>route.fulfill({status:200,contentType:'application/javascript',body:fake}));
await page.route('https://'+HOST+'/**',route=>route.abort('blockedbyclient'));
await page.goto(ORIGIN+'/#/manager-home',{waitUntil:'domcontentloaded'});
await page.waitForFunction(()=>document.querySelector('.v15-manager-scope-card')&&document.querySelectorAll('.v15-manager-metric-card').length===6,null,{timeout:12000});
await page.waitForTimeout(250);
const home=await snapshot(page);
assert(home.scrollWidth<=home.width,'MANAGER_HOME_OVERFLOW_'+JSON.stringify(home));
assert(home.heading==='Dhanbad operations'&&home.subtitle==='What needs attention and how local learning is moving.','MANAGER_HOME_PURPOSE_BAD_'+JSON.stringify(home));
assert(/local manager dhanbad aggregate local activity only/i.test(home.scope||''),'MANAGER_SCOPE_CONTEXT_MISSING_'+home.scope);
assert(JSON.stringify(home.metrics.map(x=>[x.label,x.value]))===JSON.stringify([
  ['Open reports','2'],['Learning requests','4'],['Active Classes','7'],['Learning options','11'],['Community posts','9'],['Sponsored placements','1']
]),'MANAGER_HOME_METRICS_NOT_EXACT_'+JSON.stringify(home.metrics));
assert(home.small.length===0&&home.generic.length===0,'MANAGER_HOME_ACTION_HIERARCHY_BAD_'+JSON.stringify({small:home.small,generic:home.generic}));
assert(!/Learners\s+\d|Accounts\s+\d/.test(home.body),'MANAGER_HOME_LEARNER_DIRECTORY_SIGNAL_'+home.body);
assert(!home.rawSummary,'MANAGER_HOME_RAW_SUMMARY_RETURNED');

await page.evaluate(()=>window.RaahiLearningLive.api.go('manager-people'));
await page.waitForFunction(()=>document.querySelector('.v15-manager-privacy-card'),null,{timeout:10000});
await page.waitForTimeout(200);
const people=await snapshot(page);
assert(people.scrollWidth<=people.width,'MANAGER_PEOPLE_OVERFLOW_'+JSON.stringify(people));
assert(people.heading==='People & safety'&&/browseable learner directory/.test(people.subtitle),'MANAGER_PEOPLE_PURPOSE_BAD_'+JSON.stringify(people));
assert(/Privacy by design/.test(people.privacy||'')&&/does not expose a learner directory/.test(people.privacy||''),'MANAGER_PRIVACY_BOUNDARY_MISSING_'+people.privacy);
assert(JSON.stringify(people.metrics.map(x=>[x.label,x.value]))===JSON.stringify([['Open reports','2']]),'MANAGER_PEOPLE_REPEATED_METRICS_'+JSON.stringify(people.metrics));
assert(people.buttons.some(b=>b.text==='Review reports'&&b.route==='manager-reports'),'MANAGER_REPORT_ACTION_MISSING_'+JSON.stringify(people.buttons));
assert(!/Active Classes|Learning options|Sponsored placements/.test(people.body),'MANAGER_PEOPLE_AGGREGATE_DUMP_RETURNED_'+people.body);

await page.evaluate(()=>window.RaahiLearningLive.api.go('manager-learning'));
await page.waitForFunction(()=>document.querySelectorAll('.v15-manager-metric-card').length===4,null,{timeout:10000});
await page.waitForTimeout(200);
const learning=await snapshot(page);
assert(learning.scrollWidth<=learning.width,'MANAGER_LEARNING_OVERFLOW_'+JSON.stringify(learning));
assert(learning.heading==='Learning activity'&&learning.subtitle==='Classes, teaching supply and learner demand across Dhanbad.','MANAGER_LEARNING_PURPOSE_BAD_'+JSON.stringify(learning));
assert(JSON.stringify(learning.metrics.map(x=>[x.label,x.value]))===JSON.stringify([
  ['Active Classes','7'],['Learning options','11'],['Learning requests','4'],['Community posts','9']
]),'MANAGER_LEARNING_METRICS_BAD_'+JSON.stringify(learning.metrics));
assert(learning.buttons.some(b=>b.text==='Open Raahi Desk'&&b.route==='raahi-desk')&&learning.buttons.some(b=>b.text==='Founding supply'&&b.route==='founding-supply'),'MANAGER_LEARNING_ACTIONS_BAD_'+JSON.stringify(learning.buttons));
assert(!/Open reports|Sponsored placements/.test(learning.body),'MANAGER_LEARNING_UNRELATED_METRICS_RETURNED_'+learning.body);
assert(learning.small.length===0&&!learning.rawSummary,'MANAGER_LEARNING_GEOMETRY_OR_RAW_SUMMARY_'+JSON.stringify(learning));

const calls=await page.evaluate(()=>window.__RAAHI_MANAGER_UX_FAKE__.calls.slice());
const mutationNames=['review_report','change_location_state','approve_ad_revision','reject_ad_revision','create_founding_teacher_request'];
assert(!calls.some(x=>mutationNames.includes(x.name)),'MANAGER_WORKSPACE_MUTATED_STATE_'+JSON.stringify(calls));
assert(real.length===0,'REAL_SUPABASE_NETWORK_'+real.join(','));

await page.screenshot({path:path.join(OUT,'manager-learning-mobile.png'),fullPage:true});
const report={proof:'raahi-manager-workspace-ux-browser-contract-v1',commit:SHA,checks:20,home,people,learning,result:'pass'};
fs.writeFileSync(path.join(OUT,'manager-workspace-ux-browser-contract.json'),JSON.stringify(report,null,2));
await browser.close();
console.log('RAAHI_MANAGER_WORKSPACE_UX_BROWSER_CONTRACT_PASS checks=20 commit='+SHA);
