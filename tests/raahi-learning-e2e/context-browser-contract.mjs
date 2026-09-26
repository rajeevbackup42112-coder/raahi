import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const ORIGIN='http://127.0.0.1:4173';
const HOST='iiwwmqokaeflaenhlyip.supabase.co';
const OUT=path.resolve('artifacts-context-browser-contract');
const VIEWPORTS=[{name:'desktop',width:1440,height:900},{name:'iphone',width:390,height:844}];
const fake="(() => {\n const clone=v=>JSON.parse(JSON.stringify(v)); const q=new URLSearchParams(location.search); const scenario=q.get('scenario')||'self';\n const base={account:{account_id:'11111111-1111-4111-8111-111111111111',display_name:'Context Test',avatar_type:'none',avatar_ref:null,lifecycle_status:'active',profile_onboarding_completed_at:'2026-09-23T05:00:00Z',first_use_completed_at:'2026-09-23T05:01:00Z'},selected_location:{location_id:'22222222-2222-4222-8222-222222222222',name:'Dhanbad',slug:'dhanbad',state:'live'},learners:[],capabilities:[],organizations:[],manager_scopes:[]};\n if(scenario==='multi'){base.learners=[{access_id:'30000000-0000-4000-8000-000000000001',access_type:'manage',learner_id:'30000000-0000-4000-8000-000000000002',display_name:'Aru',avatar_type:'none',avatar_ref:null}];base.capabilities=['teach'];}\n const state={scenario,context:base,calls:[],teacherWorkspace:{profile:{headline:'Math Teacher',bio:'',experience_summary:'',visibility_status:'visible'},teaching_options:[]},orgWorkspace:null}; window.__RAAHI_CONTEXT_FAKE__=state;\n const ok=data=>({data,error:null});\n const rpc=async(name,args={})=>{state.calls.push({name,args:clone(args)});switch(name){\n case 'list_public_locations': case 'list_live_locations': return ok([{location_id:'22222222-2222-4222-8222-222222222222',id:'22222222-2222-4222-8222-222222222222',name:'Dhanbad',slug:'dhanbad',state:'live'}]);\n case 'get_my_account_context': return ok(clone(state.context));\n case 'get_my_classes': case 'get_my_enquiries': case 'get_my_conversations': case 'get_my_learning_requests': case 'get_my_class_invitations': case 'get_my_notifications': return ok([]);\n case 'get_my_saved_items': return ok({teachers:[],organizations:[],teaching_options:[]});\n case 'discover_teaching_options': case 'discover_community_posts': return ok([]); case 'get_sponsored_candidate': return ok(null);\n case 'get_my_teacher_workspace': return ok(clone(state.teacherWorkspace));\n case 'create_learner': {const self=args.p_access_type==='self';const learner={access_id:'40000000-0000-4000-8000-000000000001',access_type:args.p_access_type,learner_id:'40000000-0000-4000-8000-000000000002',display_name:args.p_display_name,avatar_type:'none',avatar_ref:null};state.context.learners=[learner];return ok({learner_id:learner.learner_id,access_id:learner.access_id,access_type:learner.access_type});}\n case 'create_organization': {const org={organization_member_id:'50000000-0000-4000-8000-000000000001',organization_id:'50000000-0000-4000-8000-000000000002',name:args.p_name,organization_type:args.p_organization_type,status:'active',logo_type:'none',logo_ref:null,capabilities:['manage_profile','manage_teaching_options','manage_classes','manage_ads','manage_members']};state.context.organizations=[org];state.orgWorkspace={organization:org,teaching_options:[],classes:[]};return ok({organization_id:org.organization_id,member_id:org.organization_member_id,status:'active'});}\n case 'get_organization_workspace': return ok(clone(state.orgWorkspace||{organization:state.context.organizations[0]||null,teaching_options:[],classes:[]}));\n case 'get_organization_members': case 'get_organization_member_invitations': case 'get_eligible_organization_class_teachers': return ok([]);\n default:return {data:null,error:{message:'FAKE_RPC_NOT_IMPLEMENTED_'+name}}; }};\n const session={access_token:'fake',user:{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',email:'context@example.test',user_metadata:{name:'Context Test'}}};\n window.supabase={createClient:()=>({auth:{getSession:async()=>({data:{session},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),signOut:async()=>({error:null})},rpc,functions:{invoke:async()=>({data:null,error:{message:'EDGE_FORBIDDEN'}})}})};\n})();";
function assert(v,m){if(!v)throw new Error(m);}

async function open(browser,viewport,scenario,route){
 const context=await browser.newContext({viewport:{width:viewport.width,height:viewport.height}});
 const page=await context.newPage(); const real=[];
 page.on('request',r=>{if(r.url().includes(HOST))real.push(r.url());});
 await page.route('**/supabase.min.js',r=>r.fulfill({status:200,contentType:'application/javascript',body:fake}));
 await page.route('https://'+HOST+'/**',r=>r.abort('blockedbyclient'));
 await page.goto(ORIGIN+'/?scenario='+scenario+'#/'+route,{waitUntil:'domcontentloaded'});
 return {context,page,real};
}

async function selfJourney(browser,v){
 const {context,page,real}=await open(browser,v,'self','learner-setup');
 try{
  await page.getByRole('heading',{name:'Create your learning profile'}).waitFor({timeout:20000});
  const form=page.locator('#live-create-self-learner-form'); await form.locator('input[name="name"]').fill('Raj Learner');
  await form.getByRole('button',{name:'Create my learning profile'}).click();
  await page.waitForURL(u=>u.hash==='#/home',{timeout:20000});
  await page.getByRole('heading',{name:'Find. Learn. Grow.'}).waitFor({timeout:10000});
  const st=await page.evaluate(()=>window.__RAAHI_CONTEXT_FAKE__);
  assert(st.context.learners.length===1&&st.context.learners[0].access_type==='self','SELF_RELATIONSHIP_MISSING_'+v.name);
  assert(st.context.capabilities.length===0&&st.context.organizations.length===0,'SELF_AUTHORITY_OVERGRANT_'+v.name);
  const sel=page.locator('[data-live-role-select]'); assert(await sel.count()===1,'SELF_CONTEXT_SWITCHER_MISSING_'+v.name);
  assert((await sel.locator('option').allTextContents()).includes('My learning'),'SELF_HUMAN_LABEL_MISSING_'+v.name);
  assert(real.length===0,'REAL_NETWORK_SELF_'+real.join(','));
  const shot=v.name+'-self-learner.png';await page.screenshot({path:path.join(OUT,shot),fullPage:true});
  return {viewport:v.name,scenario:'self-learner',pass:true,screenshot:shot};
 }finally{await context.close();}
}

async function parentJourney(browser,v){
 const {context,page,real}=await open(browser,v,'parent','learner-add');
 try{
  await page.getByRole('heading',{name:'Who are you managing?'}).waitFor({timeout:20000});
  const form=page.locator('#live-create-managed-learner-form');await form.locator('input[name="name"]').fill('Aru');
  await form.getByRole('button',{name:'Add learner'}).click();
  try {
    await page.waitForURL(u=>u.hash==='#/home',{timeout:7000});
  } catch (error) {
    const body=(await page.locator('body').innerText().catch(()=>'' )).slice(0,1000);
    const debug=await page.evaluate(()=>window.__RAAHI_CONTEXT_FAKE__).catch(()=>null);
    throw new Error('PARENT_HOME_NOT_REACHED_'+v.name+' url='+page.url()+' body='+JSON.stringify(body)+' calls='+JSON.stringify(debug?.calls||[])+' cause='+String(error?.message||error));
  }
  await page.getByRole('heading',{name:'Find. Learn. Grow.'}).waitFor({timeout:10000});
  const st=await page.evaluate(()=>window.__RAAHI_CONTEXT_FAKE__);
  assert(st.context.learners.length===1&&st.context.learners[0].access_type==='manage','MANAGED_RELATIONSHIP_MISSING_'+v.name);
  assert(st.context.capabilities.length===0&&st.context.organizations.length===0,'PARENT_AUTHORITY_OVERGRANT_'+v.name);
  const options=await page.locator('[data-live-role-select] option').allTextContents();
  assert(options.includes('Learners I manage'),'PARENT_HUMAN_LABEL_MISSING_'+v.name);
  assert(real.length===0,'REAL_NETWORK_PARENT_'+real.join(','));
  const shot=v.name+'-parent.png';await page.screenshot({path:path.join(OUT,shot),fullPage:true});
  return {viewport:v.name,scenario:'parent',pass:true,screenshot:shot};
 }finally{await context.close();}
}

async function instituteJourney(browser,v){
 const {context,page,real}=await open(browser,v,'institute','institute-setup');
 try{
  await page.getByRole('heading',{name:'Create your institute on Raahi'}).waitFor({timeout:20000});
  const form=page.locator('#live-create-org-form');await form.locator('input[name="name"]').fill('Dhanbad Learning Centre');
  await form.locator('select[name="type"]').selectOption('coaching');await form.locator('textarea[name="description"]').fill('Local coaching for school learners.');
  await form.getByRole('button',{name:'Create institute'}).click();
  try {
    await page.waitForFunction(()=>location.hash==='#/org-home',null,{timeout:7000});
  } catch (error) {
    const body=(await page.locator('body').innerText().catch(()=>'' )).slice(0,1000);
    const debug=await page.evaluate(()=>window.__RAAHI_CONTEXT_FAKE__).catch(()=>null);
    throw new Error('INSTITUTE_HOME_NOT_REACHED_'+v.name+' url='+page.url()+' body='+JSON.stringify(body)+' calls='+JSON.stringify(debug?.calls||[])+' cause='+String(error?.message||error));
  }
  await page.getByText('Dhanbad Learning Centre',{exact:true}).first().waitFor({timeout:10000});
  const st=await page.evaluate(()=>window.__RAAHI_CONTEXT_FAKE__);
  assert(st.context.organizations.length===1,'ORG_NOT_CREATED_'+v.name);
  assert(st.context.learners.length===0&&st.context.capabilities.length===0,'ORG_UNRELATED_AUTHORITY_GRANTED_'+v.name);
  const options=await page.locator('[data-live-role-select] option').allTextContents();
  assert(options.includes('Institute'),'INSTITUTE_CONTEXT_MISSING_'+v.name);
  assert(!options.includes('Platform operations'),'PLATFORM_CONTEXT_LEAK_'+v.name);
  assert(real.length===0,'REAL_NETWORK_ORG_'+real.join(','));
  const shot=v.name+'-institute.png';await page.screenshot({path:path.join(OUT,shot),fullPage:true});
  return {viewport:v.name,scenario:'institute',pass:true,screenshot:shot};
 }finally{await context.close();}
}

async function switchJourney(browser,v){
 const {context,page,real}=await open(browser,v,'multi','home');
 try{
  await page.getByRole('heading',{name:'Find. Learn. Grow.'}).waitFor({timeout:20000});
  const select=page.locator('[data-live-role-select]').first();await select.waitFor({state:'visible',timeout:10000});
  const values=await select.locator('option').evaluateAll(xs=>xs.map(x=>({value:x.value,text:x.textContent.trim()})));
  assert(values.some(x=>x.value==='parent'&&x.text==='Learners I manage'),'MULTI_PARENT_OPTION_BAD_'+v.name);
  assert(values.some(x=>x.value==='teacher'&&x.text==='Teaching'),'MULTI_TEACH_OPTION_BAD_'+v.name);
  assert(!values.some(x=>x.value==='platform'||x.value==='institute'),'UNAUTHORIZED_CONTEXT_OFFERED_'+v.name);
  const before=(await page.evaluate(()=>window.__RAAHI_CONTEXT_FAKE__.calls.length));
  await select.selectOption('teacher');
  await page.waitForURL(u=>u.hash==='#/teacher-home',{timeout:15000});
  await page.getByRole('heading',{name:'Your teaching'}).waitFor({timeout:10000});
  const afterCalls=await page.evaluate(()=>window.__RAAHI_CONTEXT_FAKE__.calls.slice());
  const mutations=afterCalls.slice(before).filter(x=>['enable_teaching','create_learner','create_organization'].includes(x.name));
  assert(mutations.length===0,'CONTEXT_SWITCH_MUTATED_AUTHORITY_'+v.name);
  const teacherSelect=page.locator('[data-live-role-select]').first();await teacherSelect.selectOption('parent');
  await page.waitForURL(u=>u.hash==='#/home',{timeout:15000});
  assert(real.length===0,'REAL_NETWORK_SWITCH_'+real.join(','));
  const shot=v.name+'-multi-context.png';await page.screenshot({path:path.join(OUT,shot),fullPage:true});
  return {viewport:v.name,scenario:'multi-context-switch',pass:true,screenshot:shot};
 }finally{await context.close();}
}

async function main(){
 fs.mkdirSync(OUT,{recursive:true});const browser=await chromium.launch({headless:true});
 const report={proof:'first-use-context-browser-contract-v1.4k',commit:process.env.GITHUB_SHA||'unknown',checks:[],result:'running'};
 try{for(const v of VIEWPORTS){report.checks.push(await selfJourney(browser,v));report.checks.push(await parentJourney(browser,v));report.checks.push(await instituteJourney(browser,v));report.checks.push(await switchJourney(browser,v));}
 report.result='pass';fs.writeFileSync(path.join(OUT,'context-browser-contract.json'),JSON.stringify(report,null,2));console.log('RAAHI_CONTEXT_BROWSER_CONTRACT_PASS checks='+report.checks.length+' commit='+report.commit);
 }catch(e){report.result='fail';report.error=String(e?.stack||e);fs.writeFileSync(path.join(OUT,'context-browser-contract.json'),JSON.stringify(report,null,2));throw e;}finally{await browser.close();}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
