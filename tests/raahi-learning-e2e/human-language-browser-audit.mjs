import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const ORIGIN = process.env.RAAHI_HUMAN_LANGUAGE_ORIGIN || 'http://127.0.0.1:4173';
const OUT = path.resolve('artifacts-human-language-browser-audit');
const VIEWPORTS = [
  { name:'desktop', width:1440, height:900 },
  { name:'iphone', width:390, height:844 }
];
const BANNED = /\b(server-authorized|relationship-scoped|Membership|capabilit(?:y|ies)|authorization|authority|projection|Supabase|RPC|payload|idempotenc\w*|invariant|fixture|prototype|workspace|V1(?:\.\d+)?|serving UI)\b/i;

const shared = [
  'onboarding-intent','avatar-picker','home','explore','teacher','institute','teaching-detail','saved',
  'request-new','request-edit','request-detail','enquiry-new','enquiry','trial','invitation','join-success',
  'classes','class-detail','class-post','materials','sessions','class-thread','class-transfer','class-leave',
  'report-concern','block-user','past-class','activity','submission-review','test-upcoming','test','test-results',
  'notifications','learners','community','community-new','community-post','community-report','messages','settings',
  'location-picker','register-interest','sponsored-detail'
];

const roleRoutes = {
  teacher:['teacher-home','teaching-options','teaching-option-edit','opportunities','teacher-classes','teacher-class',
    'teacher-members','teacher-activity','teacher-test','teacher-material','teacher-profile-edit'],
  institute:['org-home','org-profile','org-teaching','org-members'],
  manager:['manager-home','manager-people','manager-learning','manager-reports','manager-location','manager-ads'],
  platform:['platform-home','platform-safety','platform-ads','platform-audit'],
  ads:['ads-home','ads-eligibility','ads-create','ads-campaign','ads-inventory','ads-creative','ads-analytics']
};
const cases = shared.map(route => ({ role:'parent', route }));
for (const [role,routes] of Object.entries(roleRoutes)) {
  for (const route of routes) cases.push({ role, route });
}
for (const route of ['teacher-classes','teacher-class','teacher-activity','teacher-test','teacher-material',
  'ads-home','ads-create','ads-inventory','ads-analytics']) {
  cases.push({ role:'institute', route });
}

async function visibleCopy(page) {
  return page.evaluate(() => {
    const source = document.querySelector('.main') || document.querySelector('.auth-shell') || document.querySelector('#app');
    const copy = source.cloneNode(true);
    copy.querySelectorAll('.qa-drawer, details code').forEach(node => node.remove());
    return (copy.innerText || copy.textContent || '').replace(/\s+/g,' ').trim();
  });
}

async function chooseRole(page, role) {
  const select = page.locator('[data-role-select]');
  if (!await select.count()) return;
  const values = await select.locator('option').evaluateAll(options => options.map(option => option.value));
  if (!values.includes(role)) throw new Error(`ROLE_NOT_AVAILABLE_${role}`);
  await select.selectOption(role);
}

async function main() {
  const browser = await chromium.launch({ headless:true });
  const failures = [];
  let checks = 0;
  try {
    for (const viewport of VIEWPORTS) {
      const context = await browser.newContext({ viewport:{ width:viewport.width, height:viewport.height } });
      const page = await context.newPage();
      await page.goto(`${ORIGIN}/?fixture=1#/home`, { waitUntil:'domcontentloaded' });
      await page.waitForTimeout(200);
      for (const item of cases) {
        await chooseRole(page,item.role);
        await page.evaluate(route => { location.hash = '#/' + route; }, item.route);
        await page.waitForTimeout(35);
        const copy = await visibleCopy(page);
        const match = copy.match(BANNED);
        checks += 1;
        if (match) {
          failures.push({
            viewport:viewport.name,
            role:item.role,
            route:item.route,
            term:match[0],
            snippet:copy.slice(Math.max(0,match.index-100),match.index+260)
          });
        }
      }
      await context.close();
    }
  } finally {
    await browser.close();
  }

  const report = {
    proof:'raahi-human-language-browser-audit-v1',
    commit:process.env.GITHUB_SHA || 'local',
    route_actor_cases:cases.length,
    viewports:VIEWPORTS.map(v => v.name),
    checks,
    failures,
    result:failures.length ? 'fail' : 'pass'
  };
  fs.mkdirSync(OUT,{recursive:true});
  fs.writeFileSync(path.join(OUT,'human-language-browser-audit.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report,null,2));
  if (failures.length) process.exitCode=1;
}

main().catch(error => {
  console.error(error);
  process.exitCode=1;
});
