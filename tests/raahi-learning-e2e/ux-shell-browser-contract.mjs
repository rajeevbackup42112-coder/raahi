import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const ORIGIN=process.env.RAAHI_UX_SHELL_ORIGIN||'http://127.0.0.1:4173';
const HOST='iiwwmqokaeflaenhlyip.supabase.co';
const OUT=path.resolve('artifacts-ux-shell-browser-contract');
const SHA=process.env.GITHUB_SHA||'local';
fs.mkdirSync(OUT,{recursive:true});

const fakeSupabaseScript=`(() => {
  const q=new URLSearchParams(location.search);
  const scenario=q.get('uxscenario')||'single';
  const account={account_id:'11111111-1111-4111-8111-111111111111',display_name:'Raahi UX Test',avatar_type:'none',avatar_ref:null,lifecycle_status:'active',profile_onboarding_completed_at:'2026-09-20T00:00:00Z',first_use_completed_at:'2026-09-20T00:01:00Z'};
  const locationRow={location_id:'22222222-2222-4222-8222-222222222222',id:'22222222-2222-4222-8222-222222222222',name:'Dhanbad',slug:'dhanbad',state:'live'};
  const managed={access_id:'33333333-3333-4333-8333-333333333331',access_type:'manage',learner_id:'33333333-3333-4333-8333-333333333332',display_name:'Aru',avatar_type:'none',avatar_ref:null};
  const self={access_id:'44444444-4444-4444-8444-444444444441',access_type:'self',learner_id:'44444444-4444-4444-8444-444444444442',display_name:'UX Learner',avatar_type:'none',avatar_ref:null};
  const context={account,selected_location:locationRow,learners:scenario==='multi'?[self,managed]:[managed],capabilities:[],organizations:[],manager_scopes:[]};
  const notifications=[1,2,3].map(i=>({notification_id:'n'+i,notification_type:'class_post_created',title:'Class update',body:'A useful Class update.',created_at:'2026-09-25T10:0'+i+':00Z',read_at:null}));
  const ok=data=>({data,error:null});
  const rpc=async(name,args={})=>{
    switch(name){
      case 'list_public_locations': case 'list_live_locations': return ok([locationRow]);
      case 'get_my_account_context': return ok(context);
      case 'get_my_classes': case 'get_my_enquiries': case 'get_my_conversations': case 'get_my_learning_requests': case 'get_my_class_invitations': return ok([]);
      case 'get_my_notifications': return ok(notifications);
      case 'get_my_saved_items': return ok({teachers:[],organizations:[],teaching_options:[]});
      case 'discover_teaching_options': case 'discover_community_posts': return ok([]);
      case 'get_sponsored_candidate': return ok(null);
      default: return {data:null,error:{message:'UX_FAKE_RPC_'+name}};
    }
  };
  const svg='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80"><rect width="80" height="80" rx="40" fill="%23009999"/><text x="40" y="51" text-anchor="middle" font-size="34" fill="white">R</text></svg>');
  const session=scenario==='signedout'?null:{access_token:'ux-token',user:{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',email:'ux@example.test',user_metadata:{name:'Raahi UX Test',avatar_url:svg}}};
  window.supabase={createClient:()=>({auth:{getSession:async()=>ok({session}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),signOut:async()=>({error:null})},rpc,functions:{invoke:async()=>({data:null,error:{message:'UX_EDGE_FORBIDDEN'}})}})};
})();`;
async function openPage(browser,scenario,viewport,route){
  const context=await browser.newContext({viewport});
  const page=await context.newPage();
  await page.route('**/supabase.min.js',route=>route.fulfill({status:200,contentType:'application/javascript',body:fakeSupabaseScript}));
  await page.route('https://'+HOST+'/**',route=>route.abort('blockedbyclient'));
  await page.goto(ORIGIN+'/?uxscenario='+scenario+'#/'+route,{waitUntil:'domcontentloaded'});
  if(scenario==='signedout'){
    await page.waitForFunction(()=>document.querySelector('.auth-card'),null,{timeout:8000});
  }else{
    await page.waitForFunction(()=>window.RaahiLearningLive?.context&&document.querySelector('.mobile-nav'),null,{timeout:8000});
  }
  await page.waitForTimeout(250);
  return {context,page};
}
function assert(condition,message){if(!condition)throw new Error(message);}
async function shellMetrics(page){
  return page.evaluate(()=>{
    const top=document.querySelector('.topbar');
    const nav=document.querySelector('.mobile-nav');
    const role=document.querySelector('[data-live-role-select]');
    return {
      width:innerWidth,scrollWidth:document.documentElement.scrollWidth,
      topHeight:Math.round(top?.getBoundingClientRect().height||0),
      brandHeight:Math.round(document.querySelector('.v15-shell-brand')?.getBoundingClientRect().height||0),
      shell:top?.className||'',
      bell:!!document.querySelector('.v15-notification-button svg'),
      badge:document.querySelector('.v15-notification-badge')?.textContent||'',
      photo:!!document.querySelector('.v15-account-avatar img'),
      roleVisible:!!role&&getComputedStyle(role).display!=='none',
      roleOptions:role?[...role.options].map(o=>o.textContent.trim()):[],
      navLabels:[...document.querySelectorAll('.mobile-nav a')].map(a=>(a.innerText||a.textContent||'').replace(/\s+/g,' ').trim()),
      navHeights:[...document.querySelectorAll('.mobile-nav a')].map(a=>Math.round(a.getBoundingClientRect().height))
    };
  });
}
const browser=await chromium.launch({headless:true});
const evidence=[];
try{
  {
    const {context,page}=await openPage(browser,'single',{width:390,height:844},'home');
    const m=await shellMetrics(page);
    assert(m.scrollWidth<=m.width,'SINGLE_MOBILE_HORIZONTAL_OVERFLOW '+JSON.stringify(m));
    assert(m.shell.includes('v15-single-context'),'SINGLE_CONTEXT_CLASS_MISSING');
    assert(m.topHeight===64,'SINGLE_HEADER_NOT_COMPACT '+m.topHeight);
    assert(m.brandHeight>=44,'MOBILE_BRAND_TOUCH_TARGET '+m.brandHeight);
    assert(m.bell&&m.badge==='3','NOTIFICATION_BELL_BADGE_MISSING '+JSON.stringify(m));
    assert(m.photo,'PRIVATE_HEADER_PHOTO_FALLBACK_MISSING');
    assert(!m.roleVisible,'SINGLE_ROLE_SELECTOR_SHOULD_BE_HIDDEN');
    assert(JSON.stringify(m.navLabels)===JSON.stringify(['Home','Explore','Classes','Community','Messages']),'MOBILE_NAV_LABELS '+JSON.stringify(m.navLabels));
    assert(m.navHeights.every(h=>h>=44),'MOBILE_NAV_TOUCH_TARGET '+JSON.stringify(m.navHeights));
    await page.screenshot({path:path.join(OUT,'single-mobile-home.png'),fullPage:true});
    evidence.push({case:'single-mobile-home',...m});
    await context.close();
  }
  {
    const {context,page}=await openPage(browser,'multi',{width:390,height:844},'home');
    const m=await shellMetrics(page);
    assert(m.scrollWidth<=m.width,'MULTI_MOBILE_HORIZONTAL_OVERFLOW '+JSON.stringify(m));
    assert(m.shell.includes('v15-multi-context'),'MULTI_CONTEXT_CLASS_MISSING');
    assert(m.topHeight===112,'MULTI_HEADER_SECOND_ROW_MISSING '+m.topHeight);
    assert(m.roleVisible,'MULTI_CONTEXT_SELECTOR_SHOULD_BE_VISIBLE');
    assert(m.roleOptions.length>=2,'MULTI_CONTEXT_OPTIONS_MISSING');
    await page.screenshot({path:path.join(OUT,'multi-mobile-home.png'),fullPage:true});
    evidence.push({case:'multi-mobile-home',...m});
    await context.close();
  }
  {
    const {context,page}=await openPage(browser,'single',{width:390,height:844},'avatar-picker');
    const text=(await page.locator('body').innerText()).replace(/\s+/g,' ');
    assert(/Profile photo/.test(text),'PROFILE_PHOTO_HEADING_MISSING');
    assert(/Use my Google photo/.test(text)&&/Use initials/.test(text),'HUMAN_AVATAR_CHOICES_MISSING');
    assert(!/Avatar type|Avatar reference/.test(text),'RAW_AVATAR_METADATA_VISIBLE');
    assert((await page.evaluate(()=>document.documentElement.scrollWidth))<=390,'AVATAR_MOBILE_OVERFLOW');
    await page.screenshot({path:path.join(OUT,'avatar-mobile.png'),fullPage:true});
    evidence.push({case:'avatar-mobile',pass:true});
    await context.close();
  }
  {
    const {context,page}=await openPage(browser,'signedout',{width:390,height:844},'welcome');
    const text=(await page.locator('body').innerText()).replace(/\s+/g,' ');
    assert(/Learning, closer to home\./.test(text),'WELCOME_PROMISE_MISSING');
    assert(/Continue with Google/.test(text),'WELCOME_GOOGLE_ACTION_MISSING');
    const featureVisible=await page.locator('.v14-welcome-values').evaluate(el=>getComputedStyle(el).display!=='none').catch(()=>false);
    assert(!featureVisible,'WELCOME_MOBILE_FEATURE_BROCHURE_SHOULD_BE_HIDDEN');
    assert((await page.evaluate(()=>document.documentElement.scrollWidth))<=390,'WELCOME_MOBILE_OVERFLOW');
    await page.screenshot({path:path.join(OUT,'welcome-mobile.png'),fullPage:true});
    evidence.push({case:'welcome-mobile',pass:true});
    await context.close();
  }
  {
    const {context,page}=await openPage(browser,'single',{width:1440,height:900},'home');
    const m=await shellMetrics(page);
    assert(m.scrollWidth<=m.width,'DESKTOP_HORIZONTAL_OVERFLOW');
    assert(await page.locator('.brand-text.v14-brand').isVisible(),'DESKTOP_WORDMARK_MISSING');
    evidence.push({case:'single-desktop-home',...m});
    await context.close();
  }
} finally {await browser.close();}
const report={proof:'raahi-ux-shell-browser-contract-v1',commit:SHA,checks:5,evidence,result:'pass'};
fs.writeFileSync(path.join(OUT,'ux-shell-browser-contract.json'),JSON.stringify(report,null,2));
console.log('RAAHI_UX_SHELL_BROWSER_CONTRACT_PASS checks=5 commit='+SHA);
