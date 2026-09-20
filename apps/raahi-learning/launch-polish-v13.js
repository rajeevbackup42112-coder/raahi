(() => {
  'use strict';

  // Presentation-only launch polish. No authority, routing, data or business-rule changes.
  const pilotGoogleOnly = window.RAAHI_RELEASE_CONFIG?.phoneTrustMode === 'controlled_pilot_google_only';
  const replacements = new Map([
    ['taking_new_learners', 'Taking new learners'],
    ['not_taking_new_learners', 'Not taking new learners'],
    ['server-authorized', 'Access confirmed'],
    ['visible', 'Public'],
    ['Google is the primary Raahi sign-in. Your learning roles and permissions still come from Raahi’s server-authorized relationships—not from Google profile data.',
     'Sign in securely with Google. Your Raahi learning profile and access stay separate from your Google profile.'],
    ['Google is the primary Raahi sign-in. Your learning roles and permissions still come from Raahi\'s server-authorized relationships—not from Google profile data.',
     'Sign in securely with Google. Your Raahi learning profile and access stay separate from your Google profile.'],
    ['Phone is not a primary login in V1.3. Raahi asks for a phone trust check only for selected sensitive actions.',
     pilotGoogleOnly
       ? 'Google sign-in is all you need. Phone verification is not required.'
       : 'For some sensitive actions, Raahi may ask you to confirm your phone number.'],
    ['Discover public learning options in the selected Location while Classes and history remain relationship-scoped.',
     'Discover teachers and learning options near you. Your Classes and learning history stay private.'],
    ['Your teacher identity and teaching operations.',
     'Manage your teaching profile, opportunities and Classes.'],
    ['Aggregate/location-scoped operational projection.',
     'A quick view of learning activity in this Location.'],
    ['Cross-Location operational summary.',
     'A quick view of Raahi Learning across active Locations.'],
    ['No Sponsored card is eligible',
     'No sponsored learning opportunities right now'],
    ['Raahi has no eligible education-only Sponsored placement for this surface right now.',
     'There are no sponsored learning opportunities for this area right now.'],
  ]);

  function friendlyText(root=document.body) {
    if (!root) return;
    const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);
    const nodes=[];
    while(walker.nextNode()) nodes.push(walker.currentNode);
    for(const node of nodes){
      const raw=node.nodeValue;
      if(!raw) continue;
      const trimmed=raw.trim();
      if(!trimmed) continue;
      if(replacements.has(trimmed)){
        const lead=raw.match(/^\s*/)?.[0]||'';
        const trail=raw.match(/\s*$/)?.[0]||'';
        node.nodeValue=lead+replacements.get(trimmed)+trail;
      }
    }
  }

  function stripEscapedWhitespaceArtifacts() {
    if (!document.body) return;
    for (const node of [...document.body.childNodes]) {
      if (node.nodeType !== Node.TEXT_NODE) continue;
      const compact=String(node.nodeValue||'').replace(/\s/g,'');
      if (compact && /^(?:\\n)+$/.test(compact)) node.remove();
    }
  }

  const metricLabels = {
    accounts:'Accounts',
    learners:'Learners',
    locations:'Locations',
    audit_events:'Audited actions',
    open_reports:'Open reports',
    active_classes:'Active Classes',
    teaching_options:'Learning options',
    live_ad_placements:'Live sponsored placements',
    submitted_campaigns:'Submitted campaigns',
    open_learning_requests:'Open learning requests',
    published_community_posts:'Community posts',
  };

  function polishOperationalSummaries() {
    const candidates=[...document.querySelectorAll('.main code, .main pre')];
    for (const source of candidates) {
      if (source.dataset.raahiSummaryPolished === 'true') continue;
      const raw=(source.textContent||'').trim();
      if (!raw.startsWith('{') || !raw.endsWith('}')) continue;
      let data;
      try { data=JSON.parse(raw); } catch (_) { continue; }
      if (!data || Array.isArray(data) || typeof data !== 'object') continue;

      const rows=Object.entries(data)
        .filter(([key,value]) => key !== 'location_id' && metricLabels[key] && (typeof value === 'number' || typeof value === 'string'));

      if (!rows.length) continue;

      const grid=document.createElement('div');
      grid.dataset.raahiSummaryPolished='true';
      grid.style.cssText='display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;width:100%;';

      for (const [key,value] of rows) {
        const metric=document.createElement('div');
        metric.style.cssText='background:#fff;border:1px solid #e6e8f0;border-radius:14px;padding:14px 16px;min-width:0;';
        const valueEl=document.createElement('div');
        valueEl.style.cssText='font-size:26px;font-weight:800;line-height:1.15;color:#17213c;';
        valueEl.textContent=String(value);
        const label=document.createElement('div');
        label.style.cssText='margin-top:5px;font-size:13px;line-height:1.35;color:#667085;';
        label.textContent=metricLabels[key];
        metric.append(valueEl,label);
        grid.appendChild(metric);
      }

      const container=source.closest('.notice') || source.parentElement;
      if (!container) continue;
      container.dataset.raahiSummaryPolished='true';
      container.style.background='transparent';
      container.style.border='0';
      container.style.padding='0';
      container.replaceChildren(grid);
    }
  }

  function ensurePublicLinks() {
    const card=[...document.querySelectorAll('.auth-card')].find(el=>/Continue with Google/i.test(el.textContent||''));
    if(!card) return;
    if(!card.querySelector('[data-raahi-public-intro]')){
      const intro=document.createElement('p');
      intro.dataset.raahiPublicIntro='true';
      intro.className='muted';
      intro.style.cssText='margin:14px 0 0;line-height:1.55;';
      intro.textContent='Find local teachers, Classes and learning opportunities in your area.';
      const button=[...card.querySelectorAll('button')].find(el=>/Continue with Google/i.test(el.textContent||''));
      if(button) button.insertAdjacentElement('beforebegin',intro); else card.appendChild(intro);
    }
    if(card.querySelector('[data-raahi-launch-links]')) return;
    const wrap=document.createElement('div');
    wrap.dataset.raahiLaunchLinks='true';
    wrap.style.cssText='margin-top:18px;padding-top:14px;border-top:1px solid #e6e8f0;text-align:center;font-size:13px;color:#667085;';
    wrap.innerHTML='<a href="./privacy.html" style="color:inherit;text-decoration:none">Privacy</a><span aria-hidden="true"> · </span><a href="./terms.html" style="color:inherit;text-decoration:none">Terms</a>';
    card.appendChild(wrap);
  }

  let scheduled=false;
  function polish(){
    scheduled=false;
    stripEscapedWhitespaceArtifacts();
    friendlyText();
    polishOperationalSummaries();
    ensurePublicLinks();
  }
  function schedule(){
    if(scheduled) return;
    scheduled=true;
    queueMicrotask(polish);
  }

  const observer=new MutationObserver(schedule);
  observer.observe(document.documentElement,{subtree:true,childList:true,characterData:true});
  window.addEventListener('hashchange',schedule);
  window.addEventListener('load',schedule);
  schedule();
})();
