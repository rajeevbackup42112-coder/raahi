import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const ORIGIN=process.env.RAAHI_NOTIFICATION_UX_ORIGIN||'http://127.0.0.1:4173';
const HOST='iiwwmqokaeflaenhlyip.supabase.co';
const OUT=path.resolve('artifacts-notification-ux-browser-contract');
const SHA=process.env.GITHUB_SHA||'local';
fs.mkdirSync(OUT,{recursive:true});

const fake=`(() => {
  const clone=v=>JSON.parse(JSON.stringify(v));
  const locationRow={location_id:'22222222-2222-4222-8222-222222222222',id:'22222222-2222-4222-8222-222222222222',name:'Dhanbad',slug:'dhanbad',state:'live'};
  const learner={access_id:'33333333-3333-4333-8333-333333333331',access_type:'manage',learner_id:'33333333-3333-4333-8333-333333333332',display_name:'Aru',avatar_type:'none',avatar_ref:null};
  const context={account:{account_id:'11111111-1111-4111-8111-111111111111',display_name:'Notification Test',avatar_type:'none',avatar_ref:null,lifecycle_status:'active',profile_onboarding_completed_at:'2026-09-20T00:00:00Z',first_use_completed_at:'2026-09-20T00:01:00Z'},selected_location:locationRow,learners:[learner],capabilities:[],organizations:[],manager_scopes:[]};
  const notifications=[
    {notification_id:'n1',notification_type:'class_message',title:'New Class message',body:'You have a new message in a Class.',created_at:'2026-09-25T12:50:00Z',read_at:null,payload:{class_id:'c1',learner_id:learner.learner_id,thread_id:'t1',message_id:'m1'}},
    {notification_id:'n2',notification_type:'activity_submission_reviewed',title:'Activity reviewed',body:'An Activity submission was reviewed.',created_at:'2026-09-25T11:40:00Z',read_at:null,payload:{class_id:'c1',learner_id:learner.learner_id,activity_id:'a1',submission_id:'s1'}},
    {notification_id:'n3',notification_type:'enquiry_received',title:'New Enquiry',body:'A learner sent a new Enquiry.',created_at:'2026-09-24T10:30:00Z',read_at:'2026-09-24T11:00:00Z',payload:{enquiry_id:'e1'}}
  ];
  const state={context,notifications,calls:[]}; window.__RAAHI_NOTIFICATION_UX_FAKE__=state;
  const ok=data=>({data,error:null});
  const rpc=async(name,args={})=>{
    state.calls.push({name,args:clone(args)});
    switch(name){
      case 'list_public_locations': case 'list_live_locations': return ok([locationRow]);
      case 'get_my_account_context': return ok(clone(context));
      case 'get_my_classes': case 'get_my_enquiries': case 'get_my_conversations': case 'get_my_learning_requests': case 'get_my_class_invitations': return ok([]);
      case 'get_my_notifications': return ok(clone(notifications));
      case 'get_my_saved_items': return ok({teachers:[],organizations:[],teaching_options:[]});
      case 'discover_teaching_options': case 'discover_community_posts': return ok([]);
      case 'get_sponsored_candidate': return ok(null);
      case 'mark_notification_read': {
        const n=notifications.find(x=>x.notification_id===args.p_notification_id);
        if(n)n.read_at='2026-09-25T13:00:00Z';
        return ok({notification_id:args.p_notification_id,read_at:'2026-09-25T13:00:00Z'});
      }
      default:return {data:null,error:{message:'NOTIFICATION_UX_FAKE_RPC_'+name}};
    }
  };
  const svg='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80"><rect width="80" height="80" rx="40" fill="%23009999"/><text x="40" y="51" text-anchor="middle" font-size="34" fill="white">N</text></svg>');
  const session={access_token:'fake',user:{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',email:'notification@example.test',user_metadata:{name:'Notification Test',avatar_url:svg}}};
  window.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),signOut:async()=>({error:null})},rpc,functions:{invoke:async()=>({data:null,error:{message:'EDGE_FORBIDDEN'}})}})};
})();`;
function assert(v,m){if(!v)throw new Error(m);}

const browser=await chromium.launch({headless:true});
const context=await browser.newContext({viewport:{width:390,height:844}});
const page=await context.newPage();
await page.route('**/supabase.min.js',route=>route.fulfill({status:200,contentType:'application/javascript',body:fake}));
await page.route('https://'+HOST+'/**',route=>route.abort('blockedbyclient'));
await page.goto(ORIGIN+'/#/notifications',{waitUntil:'domcontentloaded'});
await page.waitForFunction(()=>document.querySelectorAll('.v15-notification-card').length===3,null,{timeout:12000});
await page.waitForTimeout(250);

const before=await page.evaluate(()=>{
  const buttons=[...document.querySelectorAll('.v15-notification-card button')];
  return {
    width:innerWidth,
    scrollWidth:document.documentElement.scrollWidth,
    cards:document.querySelectorAll('.v15-notification-card').length,
    unread:document.querySelectorAll('.v15-notification-card.is-unread').length,
    read:document.querySelectorAll('.v15-notification-card.is-read').length,
    summary:document.querySelector('.v15-notification-summary')?.innerText.replace(/\s+/g,' ').trim(),
    categories:[...document.querySelectorAll('.v15-notification-kind')].map(x=>x.textContent.trim()),
    buttonHeights:buttons.map(b=>Math.round(b.getBoundingClientRect().height)),
    rawSubtitle:document.querySelector('.page-head p')?.textContent?.trim(),
    specialActivityOpen:!!document.querySelector('[data-live-fix-open-activity-submission-notification]')
  };
});
assert(before.scrollWidth<=before.width,'NOTIFICATION_MOBILE_OVERFLOW_'+JSON.stringify(before));
assert(before.cards===3&&before.unread===2&&before.read===1,'NOTIFICATION_ROWS_OR_READ_STATE_LOST_'+JSON.stringify(before));
assert(before.summary==='2 new 1 already read.','NOTIFICATION_SUMMARY_WRONG_'+before.summary);
assert(JSON.stringify(before.categories)===JSON.stringify(['Message','Activity','Enquiry']),'NOTIFICATION_CATEGORIES_WRONG_'+JSON.stringify(before.categories));
assert(before.buttonHeights.every(h=>h>=44),'NOTIFICATION_TOUCH_TARGET_'+JSON.stringify(before.buttonHeights));
assert(before.rawSubtitle==='Updates from your Classes, enquiries and Raahi activity.','NOTIFICATION_HUMAN_SUBTITLE_MISSING');
assert(before.specialActivityOpen,'SPECIALIZED_ACTIVITY_OPEN_ACTION_LOST');
const firstMark=page.locator('[data-live-notification-read]').first();
await firstMark.click();
await page.waitForFunction(()=>document.querySelectorAll('.v15-notification-card.is-unread').length===1,null,{timeout:10000});
const after=await page.evaluate(()=>({
  summary:document.querySelector('.v15-notification-summary')?.innerText.replace(/\s+/g,' ').trim(),
  unread:document.querySelectorAll('.v15-notification-card.is-unread').length,
  markCalls:(window.__RAAHI_NOTIFICATION_UX_FAKE__?.calls||[]).filter(x=>x.name==='mark_notification_read')
}));
assert(after.unread===1,'MARK_READ_VISUAL_STATE_NOT_REFRESHED_'+JSON.stringify(after));
assert(after.summary==='1 new 2 already read.','MARK_READ_SUMMARY_NOT_REFRESHED_'+after.summary);
assert(after.markCalls.length===1&&after.markCalls[0].args.p_notification_id==='n1','MARK_READ_CANONICAL_RPC_NOT_PRESERVED_'+JSON.stringify(after.markCalls));

await page.screenshot({path:path.join(OUT,'notifications-mobile.png'),fullPage:true});
const report={proof:'raahi-notification-ux-browser-contract-v1',commit:SHA,checks:9,before,after,result:'pass'};
fs.writeFileSync(path.join(OUT,'notification-ux-browser-contract.json'),JSON.stringify(report,null,2));
await browser.close();
console.log('RAAHI_NOTIFICATION_UX_BROWSER_CONTRACT_PASS checks=9 commit='+SHA);
