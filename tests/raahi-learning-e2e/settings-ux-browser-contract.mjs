import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const ORIGIN=process.env.RAAHI_SETTINGS_UX_ORIGIN||'http://127.0.0.1:4173';
const HOST='iiwwmqokaeflaenhlyip.supabase.co';
const OUT=path.resolve('artifacts-settings-ux-browser-contract');
const SHA=process.env.GITHUB_SHA||'local';
fs.mkdirSync(OUT,{recursive:true});

const fake=`(() => {
  const locationRow={location_id:'22222222-2222-4222-8222-222222222222',id:'22222222-2222-4222-8222-222222222222',name:'Dhanbad',slug:'dhanbad',state:'live'};
  const context={account:{account_id:'11111111-1111-4111-8111-111111111111',display_name:'Settings Test',avatar_type:'none',avatar_ref:null,lifecycle_status:'active',profile_onboarding_completed_at:'2026-09-20T00:00:00Z',first_use_completed_at:'2026-09-20T00:01:00Z'},selected_location:locationRow,learners:[{access_id:'a1',access_type:'manage',learner_id:'l1',display_name:'Aru',avatar_type:'none',avatar_ref:null}],capabilities:[],organizations:[],manager_scopes:[]};
  const calls=[];window.__RAAHI_SETTINGS_UX_FAKE__={context,calls};
  const clone=v=>JSON.parse(JSON.stringify(v)),ok=data=>({data,error:null});
  const rpc=async(name,args={})=>{calls.push({name,args:clone(args)});switch(name){
    case 'list_public_locations': case 'list_live_locations': return ok([locationRow]);
    case 'get_my_account_context': return ok(clone(context));
    case 'get_my_classes': case 'get_my_enquiries': case 'get_my_conversations': case 'get_my_learning_requests': case 'get_my_class_invitations': case 'get_my_notifications': return ok([]);
    case 'get_my_saved_items': return ok({teachers:[],organizations:[],teaching_options:[]});
    case 'discover_teaching_options': case 'discover_community_posts': return ok([]);
    case 'get_sponsored_candidate': return ok(null);
    case 'update_account_profile': context.account.display_name=args.p_display_name;return ok({account_id:context.account.account_id});
    case 'pause_account': context.account.lifecycle_status='paused';return ok({status:'paused'});
    case 'resume_account': context.account.lifecycle_status='active';return ok({status:'active'});
    case 'request_account_closure': return ok({status:'closure_requested'});
    default:return {data:null,error:{message:'SETTINGS_UX_FAKE_RPC_'+name}};
  }};
  const svg='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80"><rect width="80" height="80" rx="40" fill="%23009999"/><text x="40" y="51" text-anchor="middle" font-size="34" fill="white">S</text></svg>');
  const session={access_token:'fake',user:{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',email:'settings@example.test',user_metadata:{name:'Settings Test',avatar_url:svg}}};
  window.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),signOut:async()=>({error:null})},rpc,functions:{invoke:async()=>({data:null,error:{message:'EDGE_FORBIDDEN'}})}})};
})();`;
function assert(v,m){if(!v)throw new Error(m);}
const browser=await chromium.launch({headless:true});
const context=await browser.newContext({viewport:{width:390,height:844}});
const page=await context.newPage();
await page.route('**/supabase.min.js',route=>route.fulfill({status:200,contentType:'application/javascript',body:fake}));
await page.route('https://'+HOST+'/**',route=>route.abort('blockedbyclient'));
await page.goto(ORIGIN+'/#/settings',{waitUntil:'domcontentloaded'});
await page.waitForFunction(()=>document.querySelector('.v15-settings-profile')&&document.querySelector('.v15-account-options'),null,{timeout:12000});
await page.waitForTimeout(250);

const before=await page.evaluate(()=>{
  const visible=e=>!!(e&&e.getClientRects().length&&getComputedStyle(e).visibility!=='hidden'&&getComputedStyle(e).display!=='none');
  const controls=[...document.querySelectorAll('.main button,.main summary')].filter(visible);
  const close=document.querySelector('[data-live-close-account]');
  const pause=document.querySelector('[data-live-pause-account],[data-live-resume-account]');
  return {
    width:innerWidth,scrollWidth:document.documentElement.scrollWidth,
    body:(document.body.innerText||'').replace(/\s+/g,' ').trim(),
    detailsOpen:document.querySelector('.v15-account-options')?.open,
    closeVisible:visible(close),pauseVisible:visible(pause),
    minControlHeight:Math.min(...controls.map(e=>Math.round(e.getBoundingClientRect().height))),
    summaryHeight:Math.round(document.querySelector('.v15-account-options summary')?.getBoundingClientRect().height||0),
    signout:!!document.querySelector('[data-live-signout]'),
    phoneRoute:document.querySelector('[data-route="phone-check"]')?.textContent?.trim(),
    labels:[...document.querySelectorAll('.v15-settings-card h3,.v15-settings-section-head h3')].map(x=>x.textContent.trim())
  };
});
assert(before.scrollWidth<=before.width,'SETTINGS_MOBILE_OVERFLOW_'+JSON.stringify(before));
assert(!/Phone trust pending DEV configuration|Account lifecycle|periodic trust proof|source of permissions/i.test(before.body),'SETTINGS_INTERNAL_LANGUAGE_VISIBLE_'+before.body);
assert(before.detailsOpen===false&&!before.closeVisible&&!before.pauseVisible,'DESTRUCTIVE_ACTIONS_NOT_DISCLOSED_'+JSON.stringify(before));
assert(before.summaryHeight>=44&&before.minControlHeight>=44,'SETTINGS_TOUCH_TARGET_'+JSON.stringify(before));
assert(before.signout&&before.phoneRoute==='Phone security','SETTINGS_CORE_ACTIONS_LOST_'+JSON.stringify(before));
assert(before.body.includes('Profile')&&before.body.includes('Security')&&before.body.includes('Account'),'SETTINGS_HIERARCHY_MISSING');
const input=page.locator('#live-profile-form input[name="display"]');
await input.fill('Settings Test Updated');
await page.getByRole('button',{name:'Save name'}).click();
await page.waitForFunction(()=>window.__RAAHI_SETTINGS_UX_FAKE__.calls.some(x=>x.name==='update_account_profile'),null,{timeout:8000});
const profileCall=await page.evaluate(()=>window.__RAAHI_SETTINGS_UX_FAKE__.calls.filter(x=>x.name==='update_account_profile').at(-1));
assert(profileCall?.args?.p_display_name==='Settings Test Updated','PROFILE_CANONICAL_RPC_CHANGED_'+JSON.stringify(profileCall));

await page.locator('.v15-account-options summary').click();
await page.getByRole('button',{name:'Request account closure'}).waitFor({state:'visible'});
const after=await page.evaluate(()=>{
  const close=document.querySelector('[data-live-close-account]');
  const pause=document.querySelector('[data-live-pause-account],[data-live-resume-account]');
  return {
    detailsOpen:document.querySelector('.v15-account-options')?.open,
    closeVisible:!!(close&&close.getClientRects().length),
    pauseVisible:!!(pause&&pause.getClientRects().length),
    closeDanger:close?.classList.contains('danger-btn')||false,
    closeHeight:Math.round(close?.getBoundingClientRect().height||0),
    pauseHeight:Math.round(pause?.getBoundingClientRect().height||0)
  };
});
assert(after.detailsOpen&&after.closeVisible&&after.pauseVisible,'ACCOUNT_DISCLOSURE_DOES_NOT_REVEAL_ACTIONS_'+JSON.stringify(after));
assert(after.closeDanger&&after.closeHeight>=44&&after.pauseHeight>=44,'ACCOUNT_DESTRUCTIVE_HIERARCHY_BAD_'+JSON.stringify(after));

await page.screenshot({path:path.join(OUT,'settings-mobile-open.png'),fullPage:true});
const report={proof:'raahi-settings-ux-browser-contract-v1',commit:SHA,checks:8,before,profileCall,after,result:'pass'};
fs.writeFileSync(path.join(OUT,'settings-ux-browser-contract.json'),JSON.stringify(report,null,2));
await browser.close();
console.log('RAAHI_SETTINGS_UX_BROWSER_CONTRACT_PASS checks=8 commit='+SHA);
