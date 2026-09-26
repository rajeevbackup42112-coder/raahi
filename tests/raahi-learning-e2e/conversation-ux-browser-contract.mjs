import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const ORIGIN=process.env.RAAHI_CONVERSATION_UX_ORIGIN||'http://127.0.0.1:4173';
const HOST='iiwwmqokaeflaenhlyip.supabase.co';
const OUT=path.resolve('artifacts-conversation-ux-browser-contract');
const SHA=process.env.GITHUB_SHA||'local';
fs.mkdirSync(OUT,{recursive:true});

const fake=`(() => {
  const accountId='11111111-1111-4111-8111-111111111111';
  const teacherId='99999999-9999-4999-8999-999999999999';
  const learnerId='33333333-3333-4333-8333-333333333332';
  const classId='44444444-4444-4444-8444-444444444444';
  const enquiryId='55555555-5555-4555-8555-555555555555';
  const locationRow={location_id:'22222222-2222-4222-8222-222222222222',id:'22222222-2222-4222-8222-222222222222',name:'Dhanbad',slug:'dhanbad',state:'live'};
  const context={account:{account_id:accountId,display_name:'Conversation Parent',avatar_type:'none',avatar_ref:null,lifecycle_status:'active',profile_onboarding_completed_at:'2026-09-20T00:00:00Z',first_use_completed_at:'2026-09-20T00:01:00Z'},selected_location:locationRow,learners:[{access_id:'33333333-3333-4333-8333-333333333331',access_type:'manage',learner_id:learnerId,display_name:'Aru',avatar_type:'none',avatar_ref:null}],capabilities:[],organizations:[],manager_scopes:[]};
  const classRow={class_id:classId,title:'Science Class',class_state:'active',context_kind:'learner',learner_id:learnerId,learner_name:'Aru'};
  const enquiryRow={enquiry_id:enquiryId,state:'active',provider_name:'Teacher Meera',learner_name:'Aru',teaching_option_title:'Science tuition',source_type:'teaching_option',location_name:'Dhanbad'};
  const conversations=[
    {conversation_kind:'class_learner',class_id:classId,learner_id:learnerId,class_title:'Science Class',learner_name:'Aru',context_state:'active',provider_name:'Teacher Meera',conversation_id:'77777777-7777-4777-8777-777777777777',last_message_at:'2026-09-25T12:00:00Z',last_message_preview:'Latest Class message'},
    {conversation_kind:'enquiry',class_id:null,thread_id:null,enquiry_id:enquiryId,learner_id:learnerId,class_title:null,provider_name:'Teacher Meera',learner_name:'Aru',context_state:'active',conversation_id:enquiryId,last_message_at:'2026-09-25T11:00:00Z',last_message_preview:'Latest Enquiry message'}
  ];
  const makeMessages=(prefix,count)=>Array.from({length:count},(_,i)=>({message_id:prefix+(i+1),body:(prefix==='e'?'Enquiry':'Class')+' message '+(i+1),created_at:new Date(Date.UTC(2026,8,25,8,0,i)).toISOString(),sender_name:i%3===0?'Conversation Parent':'Teacher Meera',sender_account_id:i%3===0?accountId:teacherId,message_type:'text'}));
  const state={context,classes:[classRow],enquiries:[enquiryRow],conversations,enquiryMessages:makeMessages('e',9),classMessages:makeMessages('c',14),calls:[]};
  window.__RAAHI_CONVERSATION_UX_FAKE__=state;
  const clone=v=>JSON.parse(JSON.stringify(v)),ok=data=>({data,error:null});
  const rpc=async(name,args={})=>{
    state.calls.push({name,args:clone(args)});
    switch(name){
      case 'list_public_locations': case 'list_live_locations': return ok([locationRow]);
      case 'get_my_account_context': return ok(clone(state.context));
      case 'get_my_classes': return ok(clone(state.classes));
      case 'get_my_enquiries': return ok(clone(state.enquiries));
      case 'get_my_conversations': return ok(clone(state.conversations));
      case 'get_my_learning_requests': case 'get_my_class_invitations': case 'get_my_notifications': return ok([]);
      case 'get_my_saved_items': return ok({teachers:[],organizations:[],teaching_options:[]});
      case 'discover_teaching_options': case 'discover_community_posts': return ok([]);
      case 'get_sponsored_candidate': return ok(null);
      case 'get_enquiry_thread': return ok({enquiry:clone(enquiryRow),messages:clone(state.enquiryMessages),can_engage:false,can_message:true,trial_events:[]});
      case 'get_class_learner_thread': return ok({class_id:classId,thread_id:'77777777-7777-4777-8777-777777777777',learner_id:learnerId,class_title:'Science Class',learner_name:'Aru',messages:clone(state.classMessages)});
      case 'send_enquiry_message': {
        state.enquiryMessages.push({message_id:'e-sent-'+state.enquiryMessages.length,body:args.p_body,created_at:'2026-09-25T13:00:00Z',sender_name:'Conversation Parent',sender_account_id:accountId,message_type:'text'});
        return ok({message_id:state.enquiryMessages.at(-1).message_id});
      }
      case 'send_class_learner_message': {
        return new Promise(resolve=>setTimeout(()=>{state.classMessages.push({message_id:'c-sent-'+state.classMessages.length,body:args.p_body,created_at:'2026-09-25T13:05:00Z',sender_name:'Conversation Parent',sender_account_id:accountId,message_type:'text'});resolve(ok({message_id:state.classMessages.at(-1).message_id}));},120));
      }
      default:return {data:null,error:{message:'CONVERSATION_UX_FAKE_RPC_'+name}};
    }
  };
  const svg='data:image/svg+xml,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80"><rect width="80" height="80" rx="40" fill="%23009999"/><text x="40" y="51" text-anchor="middle" font-size="34" fill="white">C</text></svg>');
  const session={access_token:'fake',user:{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',email:'conversation@example.test',user_metadata:{name:'Conversation Parent',avatar_url:svg}}};
  window.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),signOut:async()=>({error:null})},rpc,functions:{invoke:async()=>({data:null,error:{message:'EDGE_FORBIDDEN'}})}})};
})();`;
function assert(v,m){if(!v)throw new Error(m);}
async function metrics(page){
  return page.evaluate(()=>{
    const visible=e=>!!(e&&e.getClientRects().length&&getComputedStyle(e).display!=='none'&&getComputedStyle(e).visibility!=='hidden');
    const list=document.querySelector('.v15-message-list');
    const composer=document.querySelector('.v15-conversation-composer');
    const nav=document.querySelector('.mobile-nav');
    const composerRect=composer?.getBoundingClientRect();
    const navRect=nav?.getBoundingClientRect();
    const controls=[...document.querySelectorAll('.v15-conversation-page button,.v15-conversation-page textarea')].filter(visible).map(e=>{const r=e.getBoundingClientRect();return{w:Math.round(r.width),h:Math.round(r.height),text:(e.getAttribute('aria-label')||e.textContent||'').trim()}});
    return {
      width:innerWidth,scrollWidth:document.documentElement.scrollWidth,scrollHeight:document.documentElement.scrollHeight,
      bubbles:document.querySelectorAll('.v15-message-bubble').length,
      mine:document.querySelectorAll('.v15-message-bubble.is-mine').length,
      theirs:document.querySelectorAll('.v15-message-bubble.is-theirs').length,
      continuations:document.querySelectorAll('.v15-message-bubble.is-continuation').length,
      list:list?{clientHeight:list.clientHeight,scrollHeight:list.scrollHeight,scrollTop:list.scrollTop}:null,
      composer:!!composer,
      composerBottom:Math.round(composerRect?.bottom||0),
      navTop:Math.round(navRect?.top||innerHeight),
      placeholder:document.querySelector('.v15-conversation-composer textarea')?.getAttribute('placeholder')||'',
      smallControls:controls.filter(x=>x.w<44||x.h<44).length,
      subtitle:document.querySelector('.page-head p')?.textContent?.trim()||''
    };
  });
}
function atLatest(m){return !!m.list&&(m.list.scrollTop+m.list.clientHeight>=m.list.scrollHeight-4);}

const browser=await chromium.launch({headless:true});
const context=await browser.newContext({viewport:{width:390,height:844}});
const page=await context.newPage();const real=[];
page.on('request',r=>{if(r.url().includes(HOST))real.push(r.url());});
await page.route('**/supabase.min.js',route=>route.fulfill({status:200,contentType:'application/javascript',body:fake}));
await page.route('https://'+HOST+'/**',route=>route.abort('blockedbyclient'));
await page.goto(ORIGIN+'/#/messages',{waitUntil:'domcontentloaded'});
try{
  await page.waitForFunction(()=>document.querySelectorAll('.v15-conversation-preview').length===2,null,{timeout:12000});
}catch(error){
  const debug=await page.evaluate(()=>({body:(document.body.innerText||'').slice(0,1600),calls:window.__RAAHI_CONVERSATION_UX_FAKE__?.calls||[],live:{route:location.hash,context:!!window.RaahiLearningLive?.context,conversations:window.RaahiLearningLive?.data?.conversations||null}})).catch(()=>null);
  throw new Error('MESSAGES_NOT_READY debug='+JSON.stringify(debug)+' cause='+String(error?.message||error));
}
const messageSubtitle=await page.locator('.page-head p').innerText();
assert(messageSubtitle==='Your conversations with teachers and Classes.','MESSAGES_SUBTITLE_NOT_HUMAN_'+messageSubtitle);
assert((await page.evaluate(()=>document.documentElement.scrollWidth))<=390,'MESSAGES_MOBILE_OVERFLOW');

await page.locator('[data-live-enquiry][data-route="enquiry"]').click();
await page.waitForFunction(()=>document.querySelectorAll('.v15-message-bubble').length===9,null,{timeout:12000});
await page.waitForTimeout(250);
const enquiryBefore=await metrics(page);
assert(enquiryBefore.scrollWidth<=enquiryBefore.width,'ENQUIRY_MOBILE_OVERFLOW_'+JSON.stringify(enquiryBefore));
assert(enquiryBefore.bubbles===9&&enquiryBefore.mine>0&&enquiryBefore.theirs>0,'ENQUIRY_BUBBLE_OWNERSHIP_LOST_'+JSON.stringify(enquiryBefore));
assert(enquiryBefore.composer&&enquiryBefore.placeholder==='Write a message…','ENQUIRY_COMPOSER_MISSING_'+JSON.stringify(enquiryBefore));
assert(enquiryBefore.composerBottom<=enquiryBefore.navTop,'ENQUIRY_COMPOSER_NAV_OVERLAP_'+JSON.stringify(enquiryBefore));
assert(enquiryBefore.smallControls===0,'ENQUIRY_SMALL_CONTROLS_'+JSON.stringify(enquiryBefore));
assert(atLatest(enquiryBefore),'ENQUIRY_NOT_OPENED_AT_LATEST_'+JSON.stringify(enquiryBefore));
const enquiryCallsBefore=await page.evaluate(()=>window.__RAAHI_CONVERSATION_UX_FAKE__.calls.length);
await page.locator('#live-enquiry-message').fill('Contract enquiry reply');
await page.locator('[data-live-send-enquiry-message]').click();
await page.waitForFunction(()=>document.querySelectorAll('.v15-message-bubble').length===10,null,{timeout:10000});
const enquiryAfterCalls=await page.evaluate(n=>window.__RAAHI_CONVERSATION_UX_FAKE__.calls.slice(n),enquiryCallsBefore);
const enquirySends=enquiryAfterCalls.filter(x=>x.name==='send_enquiry_message');
assert(enquirySends.length===1&&enquirySends[0].args.p_body==='Contract enquiry reply','ENQUIRY_CANONICAL_SEND_CHANGED_'+JSON.stringify(enquirySends));
assert(enquiryAfterCalls.some(x=>x.name==='get_enquiry_thread'),'ENQUIRY_AUTHORITATIVE_REFETCH_MISSING_'+JSON.stringify(enquiryAfterCalls.map(x=>x.name)));
await page.screenshot({path:path.join(OUT,'enquiry-mobile.png'),fullPage:true});

await page.evaluate(()=>window.RaahiLearningLive.api.go('messages'));
await page.waitForFunction(()=>document.querySelector('[data-live-conversation-class][data-route="class-thread"]'),null,{timeout:10000});
await page.locator('[data-live-conversation-class][data-route="class-thread"]').click();
await page.waitForFunction(()=>document.querySelectorAll('.v15-message-bubble').length===14,null,{timeout:12000});
await page.waitForTimeout(250);
const classBefore=await metrics(page);
assert(classBefore.scrollWidth<=classBefore.width,'CLASS_THREAD_MOBILE_OVERFLOW_'+JSON.stringify(classBefore));
assert(classBefore.bubbles===14&&classBefore.mine>0&&classBefore.theirs>0,'CLASS_THREAD_BUBBLE_OWNERSHIP_LOST_'+JSON.stringify(classBefore));
assert(classBefore.subtitle==='Private Class conversation about Aru.','CLASS_THREAD_HUMAN_CONTEXT_MISSING_'+classBefore.subtitle);
assert(classBefore.composer&&classBefore.smallControls===0,'CLASS_THREAD_COMPOSER_BAD_'+JSON.stringify(classBefore));
assert(classBefore.composerBottom<=classBefore.navTop,'CLASS_THREAD_COMPOSER_NAV_OVERLAP_'+JSON.stringify(classBefore));
assert(atLatest(classBefore),'CLASS_THREAD_NOT_OPENED_AT_LATEST_'+JSON.stringify(classBefore));

const classCallsBefore=await page.evaluate(()=>window.__RAAHI_CONVERSATION_UX_FAKE__.calls.length);
await page.locator('#live-class-message').fill('Contract Class reply');
await page.evaluate(()=>{const b=document.querySelector('[data-live-send-class-message]');b.click();b.click();});
await page.waitForFunction(()=>document.querySelectorAll('.v15-message-bubble').length===15,null,{timeout:10000});
const classAfterCalls=await page.evaluate(n=>window.__RAAHI_CONVERSATION_UX_FAKE__.calls.slice(n),classCallsBefore);
const classSends=classAfterCalls.filter(x=>x.name==='send_class_learner_message');
assert(classSends.length===1&&classSends[0].args.p_body==='Contract Class reply','CLASS_DOUBLE_SEND_OR_RPC_CHANGED_'+JSON.stringify(classSends));
assert(classAfterCalls.some(x=>x.name==='get_class_learner_thread'),'CLASS_AUTHORITATIVE_REFETCH_MISSING_'+JSON.stringify(classAfterCalls.map(x=>x.name)));
const classAfter=await metrics(page);
assert(classAfter.bubbles===15&&atLatest(classAfter),'CLASS_AFTER_SEND_NOT_LATEST_'+JSON.stringify(classAfter));
assert(real.length===0,'REAL_SUPABASE_NETWORK_'+real.join(','));
await page.screenshot({path:path.join(OUT,'class-thread-mobile.png'),fullPage:true});

const report={proof:'raahi-conversation-ux-browser-contract-v1',commit:SHA,checks:16,enquiryBefore,classBefore,classAfter,enquiryAfterCalls:enquiryAfterCalls.map(x=>x.name),classAfterCalls:classAfterCalls.map(x=>x.name),result:'pass'};
fs.writeFileSync(path.join(OUT,'conversation-ux-browser-contract.json'),JSON.stringify(report,null,2));
await browser.close();
console.log('RAAHI_CONVERSATION_UX_BROWSER_CONTRACT_PASS checks=16 commit='+SHA);
