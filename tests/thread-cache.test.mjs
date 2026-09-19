import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

test('Late private responses cannot cross account changes; reopening rechecks access',async()=>{
  const requests=[],auth=[],timers=[];let start;
  const live={session:{user:{id:'user-a'}},context:{account:{account_id:'account-a'}},data:{},selected:{},renderRoute:()=> 'signed-out',afterRender:()=>{},client:{auth:{onAuthStateChange:cb=>auth.push(cb)},rpc:()=>new Promise(resolve=>requests.push(resolve))}};
  let html='';
  const api={escapeHtml:x=>x,layout:x=>x,pageHead:x=>x,render:()=>{html=live.renderRoute('class-thread',api);}};
  vm.runInNewContext(fs.readFileSync('apps/raahi-learning/live-thread-deeplink-v13.js','utf8'),{
    window:{RaahiLearningLive:live,RaahiLearningCore:api},location:{hash:'#/class-thread?class_id=class&learner_id=learner'},
    URLSearchParams,document:{addEventListener:()=>{}},setInterval:cb=>{start=cb;return 1;},clearInterval:()=>{},setTimeout:cb=>{timers.push(cb);}
  });
  const flush=()=>{while(timers.length)timers.shift()();};
  start();api.render();flush();assert.equal(requests.length,1);
  live.session={user:{id:'user-b'}};live.context={account:{account_id:'account-b'}};
  auth[0]();flush();assert.equal(requests.length,2);
  requests[0]({data:{messages:[{body:'old private message'}]},error:null});await new Promise(setImmediate);
  assert.equal(live.data.classThread,null);assert.equal(html.includes('old private message'),false);
  requests[1]({data:null,error:{message:'NOT_AUTHORIZED'}});await new Promise(setImmediate);
  assert.match(html,/Class conversation unavailable/);
  live.renderRoute('home',api);api.render();flush();assert.equal(requests.length,3);
  requests[2]({data:null,error:{message:'NOT_AUTHORIZED'}});await new Promise(setImmediate);
});
