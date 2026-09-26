import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const ORIGIN=process.env.RAAHI_ADS_WORKSPACE_UX_ORIGIN||'http://127.0.0.1:4173';
const HOST='iiwwmqokaeflaenhlyip.supabase.co';
const OUT=path.resolve('artifacts-ads-workspace-ux-browser-contract');
const SHA=process.env.GITHUB_SHA||'local';
fs.mkdirSync(OUT,{recursive:true});

const fake=`(() => {
  const accountId='11111111-1111-4111-8111-111111111111';
  const locationId='22222222-2222-4222-8222-222222222222';
  const locationRow={location_id:locationId,id:locationId,name:'Dhanbad',slug:'dhanbad',state:'live'};
  const context={account:{account_id:accountId,display_name:'Ads Operator',avatar_type:'none',avatar_ref:null,lifecycle_status:'active',profile_onboarding_completed_at:'2026-09-20T00:00:00Z',first_use_completed_at:'2026-09-20T00:01:00Z'},selected_location:locationRow,learners:[],capabilities:['platform_admin','ads_commercial'],organizations:[],manager_scopes:[]};
  const existing={campaign_id:'33333333-3333-4333-8333-333333333333',campaign_name:'Maths admissions',objective:'admissions',starts_at:'2026-09-27T10:00:00Z',ends_at:'2026-10-05T10:00:00Z',state:'draft'};
  const campaigns=[existing];
  const workspaces={};
  workspaces[existing.campaign_id]={campaign:existing,targets:[{location_id:locationId,placement_type:'home_sponsored'}],reservations:[],placements:[],revisions:[]};
  const inventory=[
    {inventory_date:'2026-09-28',placement_type:'home_sponsored',capacity:5,remaining_units:3,max_units_per_campaign:2,rate_card_code:'HOME-A'},
    {inventory_date:'2026-09-29',placement_type:'home_sponsored',capacity:5,remaining_units:2,max_units_per_campaign:2,rate_card_code:'HOME-A'}
  ];
  const metrics=[
    {placement_id:'p1',location_id:locationId,placement_type:'home_sponsored',metric_date:'2026-09-28',sponsored_views:100,opens:12,enquiries:3,external_visits:4},
    {placement_id:'p1',location_id:locationId,placement_type:'home_sponsored',metric_date:'2026-09-29',sponsored_views:150,opens:18,enquiries:2,external_visits:6}
  ];
  const state={context,campaigns,workspaces,inventory,metrics,calls:[]};window.__RAAHI_ADS_UX_FAKE__=state;
  const clone=v=>JSON.parse(JSON.stringify(v)),ok=data=>({data,error:null});
  const rpc=async(name,args={})=>{state.calls.push({name,args:clone(args)});switch(name){
    case 'list_public_locations': case 'list_live_locations': return ok([locationRow]);
    case 'get_my_account_context': return ok(clone(context));
    case 'get_my_classes': case 'get_my_enquiries': case 'get_my_conversations': case 'get_my_learning_requests': case 'get_my_class_invitations': case 'get_my_notifications': return ok([]);
    case 'get_my_saved_items': return ok({teachers:[],organizations:[],teaching_options:[]});
    case 'discover_teaching_options': case 'discover_community_posts': return ok([]);
    case 'get_sponsored_candidate': return ok(null);
    case 'get_local_manager_overview': return ok({location_id:locationId,open_reports:0,active_classes:0,teaching_options:0,live_ad_placements:0,open_learning_requests:0,published_community_posts:0});
    case 'get_local_manager_reports': case 'get_ad_review_queue': case 'get_platform_audit': return ok([]);
    case 'get_platform_operations_summary': return ok({accounts:1,learners:0,locations:1,audit_events:0,open_reports:0,live_ad_placements:0,submitted_campaigns:0});
    case 'get_my_ad_campaigns': return ok(clone(campaigns));
    case 'get_ad_campaign_workspace': return ok(clone(workspaces[args.p_campaign_id]||{campaign:campaigns.find(c=>c.campaign_id===args.p_campaign_id),targets:[],reservations:[],placements:[],revisions:[]}));
    case 'get_ad_inventory_availability': return ok(clone(inventory));
    case 'get_ad_campaign_metrics': return ok(clone(metrics));
    case 'create_ad_campaign': {
      const c={campaign_id:'44444444-4444-4444-8444-444444444444',campaign_name:args.p_campaign_name,objective:args.p_objective,starts_at:args.p_starts_at,ends_at:args.p_ends_at,state:'draft',audience_context:args.p_audience_context,education_category:args.p_education_category,account_id:args.p_account_id,organization_id:args.p_organization_id};
      campaigns.push(c);
      workspaces[c.campaign_id]={campaign:c,targets:[{location_id:locationId,placement_type:'home_sponsored'}],reservations:[],placements:[],revisions:[]};
      return ok({campaign_id:c.campaign_id,state:'draft'});
    }
    default:return {data:null,error:{message:'ADS_UX_FAKE_RPC_'+name}};
  }};
  const svg='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80"><rect width="80" height="80" rx="40" fill="%235d5bd6"/><text x="40" y="51" text-anchor="middle" font-size="34" fill="white">A</text></svg>');
  const session={access_token:'fake',user:{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',email:'ads@example.test',user_metadata:{name:'Ads Operator',avatar_url:svg}}};
  window.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),signOut:async()=>({error:null})},rpc,functions:{invoke:async()=>({data:null,error:{message:'EDGE_FORBIDDEN'}})}})};
})();`;

function assert(v,m){if(!v)throw new Error(m);}
const browser=await chromium.launch({headless:true});
const context=await browser.newContext({viewport:{width:390,height:844}});
const page=await context.newPage();const real=[];
page.on('request',r=>{if(r.url().includes(HOST))real.push(r.url());});
await page.route('**/supabase.min.js',route=>route.fulfill({status:200,contentType:'application/javascript',body:fake}));
await page.route('https://'+HOST+'/**',route=>route.abort('blockedbyclient'));
await page.goto(ORIGIN+'/#/ads-home',{waitUntil:'domcontentloaded'});
await page.waitForFunction(()=>[...document.querySelectorAll('[data-live-role-select] option')].some(o=>o.value==='ads'),null,{timeout:10000});
await page.evaluate(()=>{
  const select=document.querySelector('[data-live-role-select]');
  select.value='ads';
  select.dispatchEvent(new Event('change',{bubbles:true}));
});
await page.waitForFunction(()=>document.querySelector('[data-live-role-select]')?.value==='ads',null,{timeout:10000});
try{
  await page.waitForFunction(()=>document.querySelector('.v15-ad-campaign-card'),null,{timeout:12000});
}catch(error){
  const debug=await page.evaluate(()=>({hash:location.hash,body:(document.body.innerText||'').replace(/\s+/g,' ').trim().slice(0,2200),main:document.querySelector('.main')?.innerHTML?.slice(0,3500)||'',campaigns:window.RaahiLearningLive?.data?.adCampaigns||null,role:document.querySelector('[data-live-role-select]')?.value||null,options:[...document.querySelectorAll('[data-live-role-select] option')].map(o=>o.value),calls:window.__RAAHI_ADS_UX_FAKE__?.calls||[]}));
  throw new Error('ADS_HOME_NOT_READY debug='+JSON.stringify(debug)+' cause='+String(error?.message||error));
}
await page.waitForTimeout(250);

const home=await page.evaluate(()=>({
  width:innerWidth,scrollWidth:document.documentElement.scrollWidth,
  heading:document.querySelector('.page-head h1')?.textContent?.trim(),
  subtitle:document.querySelector('.page-head p')?.textContent?.trim(),
  create:document.querySelector('[data-route="ads-create"]')?.textContent?.trim(),
  campaigns:[...document.querySelectorAll('.v15-ad-campaign-card')].map(c=>c.innerText.replace(/\s+/g,' ').trim()),
  raw:!!document.querySelector('.main code,.main pre')
}));
assert(home.scrollWidth<=home.width,'ADS_HOME_OVERFLOW_'+JSON.stringify(home));
assert(home.heading==='Raahi Ads'&&/Advertising never changes verification or organic ranking/.test(home.subtitle||''),'ADS_HOME_PURPOSE_BAD_'+JSON.stringify(home));
assert(home.create==='Create campaign'&&home.campaigns.length===1&&!home.raw,'ADS_HOME_CAMPAIGN_LIST_BAD_'+JSON.stringify(home));

await page.evaluate(()=>window.RaahiLearningLive.api.go('ads-create'));
await page.waitForFunction(()=>document.querySelector('#live-ad-create-form.v15-ads-form'),null,{timeout:10000});
await page.waitForTimeout(200);
const create=await page.evaluate(()=>({
  heading:document.querySelector('.page-head h1')?.textContent?.trim(),
  subtitle:document.querySelector('.page-head p')?.textContent?.trim(),
  labels:[...document.querySelectorAll('#live-ad-create-form .field label')].map(x=>x.textContent.trim()),
  note:document.querySelector('.v15-ads-form-note')?.textContent?.trim(),
  submit:document.querySelector('#live-ad-create-form button[type="submit"]')?.textContent?.trim(),
  width:innerWidth,scrollWidth:document.documentElement.scrollWidth
}));
assert(create.scrollWidth<=create.width,'ADS_CREATE_OVERFLOW_'+JSON.stringify(create));
assert(create.heading==='Create campaign'&&/review details before anything goes live/.test(create.subtitle||''),'ADS_CREATE_PURPOSE_BAD_'+JSON.stringify(create));
assert(JSON.stringify(create.labels)===JSON.stringify(['Advertiser','Campaign goal','Campaign name','Who should see this?','Learning topic','Starts','Ends']),'ADS_CREATE_LABELS_BAD_'+JSON.stringify(create.labels));
assert(/not shown to learners until/.test(create.note||'')&&create.submit==='Create draft','ADS_CREATE_TRUST_NOTE_BAD_'+JSON.stringify(create));

await page.locator('#live-ad-create-form [name="name"]').fill('Class 10 admissions');
await page.locator('#live-ad-create-form [name="audience"]').fill('Families looking for Class 10 tuition');
await page.locator('#live-ad-create-form [name="category"]').fill('Mathematics');
const beforeCreate=await page.evaluate(()=>window.__RAAHI_ADS_UX_FAKE__.calls.length);
await page.getByRole('button',{name:'Create draft'}).click();
await page.waitForURL(u=>u.hash==='#/ads-campaign',{timeout:12000});
await page.waitForFunction(()=>window.RaahiLearningLive?.selected?.adCampaignId==='44444444-4444-4444-8444-444444444444',null,{timeout:10000});
const createCalls=await page.evaluate(n=>window.__RAAHI_ADS_UX_FAKE__.calls.slice(n),beforeCreate);
const createRpc=createCalls.filter(x=>x.name==='create_ad_campaign');
assert(createRpc.length===1,'ADS_CREATE_RPC_COUNT_'+JSON.stringify(createRpc));
const ca=createRpc[0].args;
assert(ca.p_account_id==='11111111-1111-4111-8111-111111111111'&&ca.p_organization_id===null&&ca.p_objective==='admissions'&&ca.p_campaign_name==='Class 10 admissions'&&ca.p_audience_context==='Families looking for Class 10 tuition'&&ca.p_education_category==='Mathematics','ADS_CREATE_CANONICAL_FIELDS_CHANGED_'+JSON.stringify(ca));
await page.evaluate(()=>window.RaahiLearningLive.api.go('ads-inventory'));
await page.waitForFunction(()=>document.querySelector('#live-ad-inventory-form.v15-ads-form'),null,{timeout:10000});
await page.waitForTimeout(150);
const invHead=await page.evaluate(()=>({heading:document.querySelector('.page-head h1')?.textContent?.trim(),subtitle:document.querySelector('.page-head p')?.textContent?.trim(),units:document.querySelector('[name="units"]')?.closest('.field')?.querySelector('label')?.textContent?.trim(),buttons:[...document.querySelectorAll('#live-ad-inventory-form button')].map(b=>b.textContent.trim())}));
assert(invHead.heading==='Sponsored availability'&&/check or reserve availability/.test(invHead.subtitle||'')&&invHead.units==='Units needed','ADS_INVENTORY_COPY_BAD_'+JSON.stringify(invHead));
assert(JSON.stringify(invHead.buttons)===JSON.stringify(['Check dates','Reserve dates']),'ADS_INVENTORY_ACTIONS_BAD_'+JSON.stringify(invHead.buttons));
await page.getByRole('button',{name:'Check dates'}).click();
await page.waitForFunction(()=>document.querySelectorAll('.v15-ads-availability-row').length===2,null,{timeout:10000});
const inventory=await page.evaluate(()=>({rows:[...document.querySelectorAll('.v15-ads-availability-row')].map(x=>x.innerText.replace(/\s+/g,' ').trim()),raw:!!document.querySelector('.v15-ads-results-card code,.v15-ads-results-card pre'),small:[...document.querySelectorAll('.main button')].filter(b=>{const r=b.getBoundingClientRect();return r.width<44||r.height<44}).map(b=>b.textContent.trim())}));
assert(inventory.rows[0].includes('3 of 5 units available')&&inventory.rows[0].includes('Up to 2 per campaign')&&inventory.rows[1].includes('2 of 5 units available'),'ADS_INVENTORY_VALUES_BAD_'+JSON.stringify(inventory.rows));
assert(!inventory.raw&&inventory.small.length===0,'ADS_INVENTORY_RAW_OR_SMALL_'+JSON.stringify(inventory));

await page.evaluate(()=>window.RaahiLearningLive.api.go('ads-analytics'));
await page.waitForFunction(()=>document.querySelectorAll('.v15-ads-metric-card').length===4,null,{timeout:10000});
await page.waitForTimeout(150);
const analytics=await page.evaluate(()=>({heading:document.querySelector('.page-head h1')?.textContent?.trim(),subtitle:document.querySelector('.page-head p')?.textContent?.trim(),metrics:[...document.querySelectorAll('.v15-ads-metric-card')].map(x=>[x.querySelector('span')?.textContent?.trim(),x.querySelector('strong')?.textContent?.trim()]),raw:!!document.querySelector('.v15-ads-results-card code,.v15-ads-results-card pre'),width:innerWidth,scrollWidth:document.documentElement.scrollWidth}));
assert(analytics.heading==='Campaign results'&&/does not provide a named viewer list/.test(analytics.subtitle||''),'ADS_ANALYTICS_PRIVACY_COPY_BAD_'+JSON.stringify(analytics));
assert(JSON.stringify(analytics.metrics)===JSON.stringify([['Sponsored views','250'],['Opens','30'],['Enquiries','5'],['External visits','10']]),'ADS_ANALYTICS_AGGREGATION_BAD_'+JSON.stringify(analytics.metrics));
assert(!analytics.raw&&analytics.scrollWidth<=analytics.width,'ADS_ANALYTICS_RAW_OR_OVERFLOW_'+JSON.stringify(analytics));
assert(real.length===0,'REAL_SUPABASE_NETWORK_'+real.join(','));

await page.screenshot({path:path.join(OUT,'ads-analytics-mobile.png'),fullPage:true});
const report={proof:'raahi-ads-workspace-ux-browser-contract-v1',commit:SHA,checks:18,home,create,inventory,analytics,createRpc,result:'pass'};
fs.writeFileSync(path.join(OUT,'ads-workspace-ux-browser-contract.json'),JSON.stringify(report,null,2));
await browser.close();
console.log('RAAHI_ADS_WORKSPACE_UX_BROWSER_CONTRACT_PASS checks=18 commit='+SHA);
