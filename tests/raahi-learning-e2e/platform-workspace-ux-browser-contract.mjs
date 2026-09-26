import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const ORIGIN=process.env.RAAHI_PLATFORM_WORKSPACE_UX_ORIGIN||'http://127.0.0.1:4173';
const HOST='iiwwmqokaeflaenhlyip.supabase.co';
const OUT=path.resolve('artifacts-platform-workspace-ux-browser-contract');
const SHA=process.env.GITHUB_SHA||'local';
fs.mkdirSync(OUT,{recursive:true});

const fake=`(() => {
  const locationId='22222222-2222-4222-8222-222222222222';
  const locationRow={location_id:locationId,id:locationId,name:'Dhanbad',slug:'dhanbad',state:'live'};
  const summary={accounts:10,learners:3,locations:2,audit_events:45,open_reports:2,live_ad_placements:1,submitted_campaigns:2};
  const context={account:{account_id:'11111111-1111-4111-8111-111111111111',display_name:'Platform Admin',avatar_type:'none',avatar_ref:null,lifecycle_status:'active',profile_onboarding_completed_at:'2026-09-20T00:00:00Z',first_use_completed_at:'2026-09-20T00:01:00Z'},selected_location:locationRow,learners:[],capabilities:['platform_admin','ads_commercial'],organizations:[],manager_scopes:[]};
  const platformReviews=[{revision_id:'99999999-9999-4999-8999-999999999991',campaign_name:'School admissions',headline:'Admissions open',current_review_state:'submitted'}];
  const audit=[{audit_id:'a1',action_code:'location_state_changed',target_type:'location',target_label:'Dhanbad',occurred_at:'2026-09-25T10:00:00Z'}];
  const state={context,summary,platformReviews,audit,calls:[]};window.__RAAHI_PLATFORM_UX_FAKE__=state;
  const clone=v=>JSON.parse(JSON.stringify(v)),ok=data=>({data,error:null});
  const rpc=async(name,args={})=>{state.calls.push({name,args:clone(args)});switch(name){
    case 'list_public_locations': case 'list_live_locations': return ok([locationRow]);
    case 'get_my_account_context': return ok(clone(context));
    case 'get_my_classes': case 'get_my_enquiries': case 'get_my_conversations': case 'get_my_learning_requests': case 'get_my_class_invitations': case 'get_my_notifications': return ok([]);
    case 'get_my_saved_items': return ok({teachers:[],organizations:[],teaching_options:[]});
    case 'discover_teaching_options': case 'discover_community_posts': return ok([]);
    case 'get_sponsored_candidate': return ok(null);
    case 'get_local_manager_overview': return ok({location_id:locationId,open_reports:2,active_classes:7,teaching_options:11,live_ad_placements:1,open_learning_requests:4,published_community_posts:9});
    case 'get_local_manager_reports': return ok([]);
    case 'get_platform_operations_summary': return ok(clone(summary));
    case 'get_platform_audit': return ok(clone(audit));
    case 'get_ad_review_queue': return ok(args.p_location_id==null?clone(state.platformReviews):[]);
    case 'review_ad_campaign_revision': {
      if(args.p_review_scope==='platform'&&args.p_decision==='approved') state.platformReviews=[];
      return ok({revision_id:args.p_revision_id,review_scope:args.p_review_scope,state:args.p_decision});
    }
    case 'get_my_ad_campaigns': return ok([]);
    default:return {data:null,error:{message:'PLATFORM_UX_FAKE_RPC_'+name}};
  }};
  const svg='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80"><rect width="80" height="80" rx="40" fill="%234f46e5"/><text x="40" y="51" text-anchor="middle" font-size="34" fill="white">P</text></svg>');
  const session={access_token:'fake',user:{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',email:'platform@example.test',user_metadata:{name:'Platform Admin',avatar_url:svg}}};
  window.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),signOut:async()=>({error:null})},rpc,functions:{invoke:async()=>({data:null,error:{message:'EDGE_FORBIDDEN'}})}})};
})();`;

function assert(v,m){if(!v)throw new Error(m);}
async function snap(page){
  return page.evaluate(()=>{
    const visible=e=>!!(e&&e.getClientRects().length&&getComputedStyle(e).display!=='none'&&getComputedStyle(e).visibility!=='hidden');
    const buttons=[...document.querySelectorAll('.main button,.main a')].filter(visible).map(e=>{const r=e.getBoundingClientRect();return{text:(e.innerText||e.textContent||'').replace(/\s+/g,' ').trim(),route:e.dataset.route||null,w:Math.round(r.width),h:Math.round(r.height),decision:e.dataset.decision||null}});
    return {
      width:innerWidth,scrollWidth:document.documentElement.scrollWidth,heading:document.querySelector('.page-head h1')?.textContent?.trim()||'',subtitle:document.querySelector('.page-head p')?.textContent?.trim()||'',
      body:(document.body.innerText||'').replace(/\s+/g,' ').trim(),
      metrics:[...document.querySelectorAll('.v15-platform-metric-card')].map(c=>({value:c.querySelector('.v15-platform-metric-value')?.textContent?.trim(),label:c.querySelector('.v15-platform-metric-label')?.textContent?.trim()})),
      context:document.querySelector('.v15-platform-context-card')?.innerText?.replace(/\s+/g,' ').trim()||null,
      buttons,small:buttons.filter(b=>b.w<44||b.h<44),raw:!!document.querySelector('.main code,.main pre'),
      reviewCards:document.querySelectorAll('.v15-platform-review-card').length
    };
  });
}
const browser=await chromium.launch({headless:true});
const context=await browser.newContext({viewport:{width:390,height:844}});
const page=await context.newPage();const real=[];
page.on('request',r=>{if(r.url().includes(HOST))real.push(r.url());});
await page.route('**/supabase.min.js',route=>route.fulfill({status:200,contentType:'application/javascript',body:fake}));
await page.route('https://'+HOST+'/**',route=>route.abort('blockedbyclient'));
await page.goto(ORIGIN+'/#/platform-home',{waitUntil:'domcontentloaded'});
await page.waitForFunction(()=>document.querySelector('.v15-platform-context-card')&&document.querySelectorAll('.v15-platform-metric-card').length===7,null,{timeout:12000});
await page.waitForTimeout(250);
const home=await snap(page);
assert(home.scrollWidth<=home.width,'PLATFORM_HOME_OVERFLOW_'+JSON.stringify(home));
assert(home.heading==='Platform operations'&&/System activity/.test(home.subtitle),'PLATFORM_HOME_PURPOSE_BAD_'+JSON.stringify(home));
assert(/Governed platform view/.test(home.context||'')&&/does not mean unrestricted access/.test(home.context||''),'PLATFORM_GOVERNANCE_CONTEXT_MISSING_'+home.context);
assert(JSON.stringify(home.metrics.map(x=>[x.label,x.value]))===JSON.stringify([
  ['Open reports','2'],['Submitted campaigns','2'],['Active Locations','2'],['Accounts','10'],['Learner profiles','3'],['Audited actions','45'],['Sponsored placements','1']
]),'PLATFORM_HOME_METRICS_BAD_'+JSON.stringify(home.metrics));
assert(home.small.length===0&&!home.raw,'PLATFORM_HOME_GEOMETRY_OR_RAW_'+JSON.stringify(home));
assert(['Safety review','Ads review','Location admins','Audit log'].every(t=>home.buttons.some(b=>b.text===t)),'PLATFORM_HOME_ACTIONS_BAD_'+JSON.stringify(home.buttons));

await page.waitForFunction(()=>[...document.querySelectorAll('[data-live-role-select] option')].some(o=>o.value==='platform'),null,{timeout:10000});
await page.evaluate(()=>{
  const select=document.querySelector('[data-live-role-select]');
  select.value='platform';
  select.dispatchEvent(new Event('change',{bubbles:true}));
});
await page.waitForFunction(()=>document.querySelector('[data-live-role-select]')?.value==='platform',null,{timeout:10000});
await page.evaluate(()=>window.RaahiLearningLive.api.go('home'));
await page.waitForFunction(()=>document.querySelector('.v15-platform-context-card')&&document.querySelector('.page-head h1')?.textContent==='Platform operations',null,{timeout:10000});
const platformHomeAlias=await snap(page);
assert(platformHomeAlias.heading==='Platform operations'&&platformHomeAlias.metrics.length===7,'PLATFORM_GENERIC_HOME_NOT_CONVERGED_'+JSON.stringify(platformHomeAlias));

await page.evaluate(()=>window.RaahiLearningLive.api.go('platform-safety'));
await page.waitForFunction(()=>document.querySelectorAll('.v15-platform-metric-card').length===2,null,{timeout:10000});
await page.waitForTimeout(200);
const safety=await snap(page);
assert(safety.heading==='Safety & trust'&&/without treating reports as findings/.test(safety.subtitle),'PLATFORM_SAFETY_PURPOSE_BAD_'+JSON.stringify(safety));
assert(JSON.stringify(safety.metrics.map(x=>[x.label,x.value]))===JSON.stringify([['Open reports','2'],['Audited actions','45']]),'PLATFORM_SAFETY_REPEATED_SUMMARY_'+JSON.stringify(safety.metrics));
assert(!/Accounts 10|Learner profiles 3|Submitted campaigns 2/.test(safety.body),'PLATFORM_SAFETY_UNRELATED_METRICS_'+safety.body);

await page.evaluate(()=>window.RaahiLearningLive.api.go('platform-ads'));
try{
  await page.waitForFunction(()=>document.querySelector('.v15-platform-review-card'),null,{timeout:10000});
}catch(error){
  const debug=await page.evaluate(()=>({hash:location.hash,body:(document.body.innerText||'').replace(/\s+/g,' ').trim().slice(0,2400),mainChildren:[...document.querySelector('.main')?.children||[]].map(e=>({tag:e.tagName,cls:e.className,text:(e.innerText||'').replace(/\s+/g,' ').trim().slice(0,500)})),sections:[...document.querySelectorAll('.main .section')].map(e=>({cls:e.className,text:(e.innerText||'').replace(/\s+/g,' ').trim().slice(0,800)})),review:window.RaahiLearningLive?.data?.platformAdReview||null,calls:window.__RAAHI_PLATFORM_UX_FAKE__?.calls||[]}));
  throw new Error('PLATFORM_ADS_NOT_READY debug='+JSON.stringify(debug)+' cause='+String(error?.message||error));
}
await page.waitForTimeout(200);
const ads=await snap(page);
assert(ads.heading==='Ads review'&&/separately from commercial approval and inventory/.test(ads.subtitle),'PLATFORM_ADS_PURPOSE_BAD_'+JSON.stringify(ads));
assert(JSON.stringify(ads.metrics.map(x=>[x.label,x.value]))===JSON.stringify([['Submitted campaigns','2'],['Live placements','1']]),'PLATFORM_ADS_METRICS_BAD_'+JSON.stringify(ads.metrics));
assert(ads.reviewCards===1&&ads.buttons.some(b=>b.text==='Request changes'),'PLATFORM_REVIEW_QUEUE_BAD_'+JSON.stringify(ads));
assert(ads.small.length===0,'PLATFORM_ADS_SMALL_TARGET_'+JSON.stringify(ads.small));

const before=await page.evaluate(()=>window.__RAAHI_PLATFORM_UX_FAKE__.calls.length);
await page.locator('[data-live-ad-review][data-review-scope="platform"][data-decision="approved"]').click();
await page.waitForFunction(()=>window.__RAAHI_PLATFORM_UX_FAKE__.platformReviews.length===0,null,{timeout:10000});
const afterCalls=await page.evaluate(n=>window.__RAAHI_PLATFORM_UX_FAKE__.calls.slice(n),before);
const reviews=afterCalls.filter(x=>x.name==='review_ad_campaign_revision');
assert(reviews.length===1&&reviews[0].args.p_review_scope==='platform'&&reviews[0].args.p_location_id===null&&reviews[0].args.p_decision==='approved','PLATFORM_CANONICAL_REVIEW_CHANGED_'+JSON.stringify(reviews));
assert(real.length===0,'REAL_SUPABASE_NETWORK_'+real.join(','));
await page.screenshot({path:path.join(OUT,'platform-ads-mobile.png'),fullPage:true});

const report={proof:'raahi-platform-workspace-ux-browser-contract-v1',commit:SHA,checks:17,home,platformHomeAlias,safety,ads,reviewCalls:reviews,result:'pass'};
fs.writeFileSync(path.join(OUT,'platform-workspace-ux-browser-contract.json'),JSON.stringify(report,null,2));
await browser.close();
console.log('RAAHI_PLATFORM_WORKSPACE_UX_BROWSER_CONTRACT_PASS checks=17 commit='+SHA);
