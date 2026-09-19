(() => {
  'use strict';

  // Presentation-only launch polish. No authority, routing, data or business-rule changes.
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
     'For some sensitive actions, Raahi may ask you to confirm your phone number.'],
    ['Discover public learning options in the selected Location while Classes and history remain relationship-scoped.',
     'Discover teachers and learning options near you. Your Classes and learning history stay private.'],
    ['Your teacher identity and teaching operations.',
     'Manage your teaching profile, opportunities and Classes.'],
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

  function ensurePublicLinks() {
    const card=[...document.querySelectorAll('.auth-card')].find(el=>/Continue with Google/i.test(el.textContent||''));
    if(!card || card.querySelector('[data-raahi-launch-links]')) return;
    const wrap=document.createElement('div');
    wrap.dataset.raahiLaunchLinks='true';
    wrap.style.cssText='margin-top:18px;padding-top:14px;border-top:1px solid #e6e8f0;text-align:center;font-size:13px;color:#667085;';
    wrap.innerHTML='<a href="./privacy.html" style="color:inherit;text-decoration:none">Privacy</a><span aria-hidden="true"> · </span><a href="./terms.html" style="color:inherit;text-decoration:none">Terms</a>';
    card.appendChild(wrap);
  }

  let scheduled=false;
  function polish(){
    scheduled=false;
    friendlyText();
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
