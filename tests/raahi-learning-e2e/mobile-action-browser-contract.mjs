import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const ORIGIN=process.env.RAAHI_MOBILE_ACTION_ORIGIN||'http://127.0.0.1:4173';
const OUT=path.resolve('artifacts-mobile-action-browser-contract');
const SHA=process.env.GITHUB_SHA||'local';
fs.mkdirSync(OUT,{recursive:true});

const CASES={
  ads:['ads-campaign','ads-creative','ads-eligibility'],
  parent:['block-user','class-leave','class-transfer','community-post','community-report','enquiry-new','invitation','join-success','register-interest','report-concern','request-detail','request-edit','saved','sponsored-detail','test-results','test-upcoming','teacher','institute','google-profile'],
  teacher:['class-post','materials','past-class','sessions','submission-review','teacher-activity','teacher-material','teacher-members','teacher-test','teaching-option-edit']
};

function assert(v,m){if(!v)throw new Error(m);}

const browser=await chromium.launch({headless:true});
const context=await browser.newContext({viewport:{width:390,height:844}});
const page=await context.newPage();
await page.goto(ORIGIN+'/?fixture=1#/home',{waitUntil:'domcontentloaded'});
await page.waitForTimeout(200);

const evidence=[];
for(const [role,routes] of Object.entries(CASES)){
  const select=page.locator('[data-role-select]');
  if(await select.count()){
    const values=await select.locator('option').evaluateAll(os=>os.map(o=>o.value));
    if(values.includes(role)){await select.selectOption(role);await page.waitForTimeout(30);}
  }
  for(const route of routes){
    await page.evaluate(r=>{location.hash='#/'+r},route);
    await page.waitForTimeout(50);
    const result=await page.evaluate(()=>{
      const visible=e=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e);return r.width>0&&r.height>0&&s.display!=='none'&&s.visibility!=='hidden'};
      const controls=[...document.querySelectorAll('.main a,.main button')]
        .filter(visible)
        .filter(e=>!e.closest('.qa-drawer'))
        .map(e=>{const r=e.getBoundingClientRect();return{text:(e.getAttribute('aria-label')||e.innerText||e.textContent||'').replace(/\s+/g,' ').trim(),w:Math.round(r.width),h:Math.round(r.height)}});
      return {
        scrollWidth:document.documentElement.scrollWidth,
        width:innerWidth,
        small:controls.filter(x=>x.w<44||x.h<44),
        controls:controls.length
      };
    });
    assert(result.scrollWidth<=result.width,'MOBILE_CONTENT_OVERFLOW_'+role+'_'+route+'_'+JSON.stringify(result));
    assert(result.small.length===0,'MOBILE_SMALL_TARGET_'+role+'_'+route+'_'+JSON.stringify(result.small));
    evidence.push({role,route,controls:result.controls,pass:true});
  }
}
await page.screenshot({path:path.join(OUT,'representative-mobile.png'),fullPage:true});
await browser.close();

const checks=evidence.length;
const report={proof:'raahi-mobile-action-browser-contract-v1',commit:SHA,checks,evidence,result:'pass'};
fs.writeFileSync(path.join(OUT,'mobile-action-browser-contract.json'),JSON.stringify(report,null,2));
console.log('RAAHI_MOBILE_ACTION_BROWSER_CONTRACT_PASS checks='+checks+' commit='+SHA);
