(() => {
  'use strict';

  // Presentation-only V1.4 delight layer. No data fetches, RPCs, writes or authority changes.
  const icons={
    home:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M3.5 10.7 12 3.8l8.5 6.9v8.2a1.6 1.6 0 0 1-1.6 1.6H5.1a1.6 1.6 0 0 1-1.6-1.6v-8.2Z" stroke="currentColor" stroke-width="1.8"/><path d="M9.2 20.5v-6.2h5.6v6.2" stroke="currentColor" stroke-width="1.8"/></svg>',
    explore:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><circle cx="11" cy="11" r="6.5" stroke="currentColor" stroke-width="1.8"/><path d="m16 16 4.4 4.4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>',
    classes:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 5.5h6.8c1.2 0 2.2.7 2.2 1.8v11.2c0-1.1-1-1.8-2.2-1.8H4V5.5Zm16 0h-6.8c-1.2 0-2.2.7-2.2 1.8v11.2c0-1.1 1-1.8 2.2-1.8H20V5.5Z" stroke="currentColor" stroke-width="1.7"/></svg>',
    community:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M7.5 12.5a3.2 3.2 0 1 0 0-6.4 3.2 3.2 0 0 0 0 6.4Zm9.2-1.3a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5ZM2.8 19c.4-3 2.2-4.7 4.7-4.7s4.4 1.7 4.8 4.7m1.2-5.2c1-.8 2-1 3.2-1 2.2 0 3.8 1.4 4.1 3.8" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>',
    messages:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 5.5h16v11.3H9l-5 3.4V5.5Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M8 9.4h8M8 13h5" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>',
    location:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 21s6-5.9 6-11a6 6 0 1 0-12 0c0 5.1 6 11 6 11Z" stroke="currentColor" stroke-width="1.8"/><circle cx="12" cy="10" r="2.2" stroke="currentColor" stroke-width="1.8"/></svg>',
    bell:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M6.5 9.8a5.5 5.5 0 0 1 11 0v3.1l1.7 2.6H4.8l1.7-2.6V9.8Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M9.6 18.2c.5 1.2 1.3 1.8 2.4 1.8s1.9-.6 2.4-1.8" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>',
    teaching:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><circle cx="12" cy="12" r="8" stroke="currentColor" stroke-width="1.7"/><circle cx="12" cy="12" r="3" stroke="currentColor" stroke-width="1.7"/><path d="M12 4v3M20 12h-3M12 20v-3M4 12h3" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>',
    people:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><circle cx="9" cy="8" r="3" stroke="currentColor" stroke-width="1.7"/><circle cx="17" cy="9" r="2.4" stroke="currentColor" stroke-width="1.7"/><path d="M3.5 19c.5-3.4 2.5-5.3 5.5-5.3s5 1.9 5.5 5.3M14.3 14.1c.8-.6 1.7-.9 2.7-.9 2.3 0 3.8 1.5 4.2 4.2" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>',
    sparkle:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 3c.6 4.7 2.3 6.4 7 7-4.7.6-6.4 2.3-7 7-.6-4.7-2.3-6.4-7-7 4.7-.6 6.4-2.3 7-7Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/></svg>',
    flag:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M6 21V4m0 1h10l-1.8 3L16 11H6" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>',
    diamond:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="m12 3 8 9-8 9-8-9 8-9Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/></svg>',
    settings:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><circle cx="12" cy="12" r="3" stroke="currentColor" stroke-width="1.7"/><path d="M12 3.8v2.1M12 18.1v2.1M20.2 12h-2.1M5.9 12H3.8M17.8 6.2l-1.5 1.5M7.7 16.3l-1.5 1.5M17.8 17.8l-1.5-1.5M7.7 7.7 6.2 6.2" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>',
    shield:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 3 19 6v5.3c0 4.4-2.7 7.5-7 9.7-4.3-2.2-7-5.3-7-9.7V6l7-3Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/></svg>',
    plus:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>',
    grid:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="4" y="4" width="6" height="6" rx="1" stroke="currentColor" stroke-width="1.7"/><rect x="14" y="4" width="6" height="6" rx="1" stroke="currentColor" stroke-width="1.7"/><rect x="4" y="14" width="6" height="6" rx="1" stroke="currentColor" stroke-width="1.7"/><rect x="14" y="14" width="6" height="6" rx="1" stroke="currentColor" stroke-width="1.7"/></svg>',
    chart:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M5 19V11M12 19V5M19 19v-6" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>',
    audit:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M7 5h10M7 10h10M7 15h7M5 5h.1M5 10h.1M5 15h.1" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>',
  };

  const route=()=>location.hash.replace(/^#\//,'').split('?')[0]||'home';
  const locationName=()=>document.querySelector('[data-route="location-picker"] .label')?.textContent?.trim()
    || [...document.querySelectorAll('.rightbar .strong')].map(x=>x.textContent.trim()).find(Boolean)
    || 'your area';

  function polishBrand(){
    for(const el of document.querySelectorAll('.brand-text:not([data-v14-brand])')){
      el.dataset.v14Brand='true'; el.classList.add('v14-brand');
      el.innerHTML='<strong>RAAHI</strong><span class="brand-sub">Your local learning network</span>';
    }
  }

  function polishIcons(){
    const routeIcons={
      home:'home',explore:'explore',classes:'classes',community:'community',messages:'messages',
      'teacher-home':'home',opportunities:'teaching','teacher-classes':'classes',
      'org-home':'home','org-teaching':'classes','ads-home':'diamond',
      'manager-home':'home','manager-people':'people','manager-learning':'classes','raahi-desk':'sparkle',
      'founding-supply':'people','manager-reports':'flag','manager-ads':'diamond','manager-location':'settings',
      'platform-home':'home','platform-safety':'shield','platform-ads':'diamond','location-admins':'people','platform-audit':'audit',
      'ads-create':'plus','ads-inventory':'grid','ads-analytics':'chart'
    };
    for(const link of document.querySelectorAll('.nav-item[href^="#/"],.mobile-nav a[href^="#/"]')){
      const key=(link.getAttribute('href')||'').replace('#/','').split('?')[0];
      const svg=icons[routeIcons[key]]; if(!svg) continue;
      const target=link.querySelector('.nav-icon,b'); if(target && target.innerHTML!==svg) target.innerHTML=svg;
    }
    const search=document.querySelector('.top-search .icon'); if(search && search.dataset.v14Icon!=='true'){
      search.dataset.v14Icon='true'; search.innerHTML=icons.explore;
    }
    for(const button of document.querySelectorAll('button[data-route="location-picker"]')){
      if(button.dataset.v14Location==='true') continue;
      const label=button.querySelector('.label'); if(!label) continue;
      button.dataset.v14Location='true'; button.classList.add('v14-location-pill');
      button.innerHTML=icons.location+'<span class="label">'+label.textContent+'</span>';
      button.setAttribute('aria-label','Change learning Location');
    }
    for(const button of document.querySelectorAll('[data-live-community-menu],[data-live-ad-menu]')){
      if(button.dataset.v14Menu==='true') continue;
      button.dataset.v14Menu='true'; button.textContent='\u2022\u2022\u2022'; button.setAttribute('aria-label','More options');
    }
  }

  const mobileNavLabels={
    home:'Home',explore:'Explore',classes:'Classes',community:'Community',messages:'Messages',
    'teacher-home':'Home',opportunities:'Opportunities','teacher-classes':'Classes',
    'org-home':'Overview','org-teaching':'Learning','ads-home':'Ads',
    'manager-home':'Overview','manager-people':'People','manager-learning':'Learning','raahi-desk':'Raahi',
    'founding-supply':'Founding','manager-reports':'Reports','manager-ads':'Ads','manager-location':'Settings',
    'platform-home':'Overview','platform-safety':'Safety','platform-ads':'Ads','location-admins':'Admins','platform-audit':'Audit',
    'ads-create':'Create','ads-inventory':'Inventory','ads-analytics':'Analytics'
  };

  function polishShell(){
    const top=document.querySelector('.topbar');
    if(!top) return;
    top.classList.add('v15-shell');
    const brand=top.querySelector('.brand');
    if(brand){
      brand.classList.add('v15-shell-brand');
      brand.setAttribute('aria-label','Raahi Learning home');
    }
    const actions=top.querySelector('.top-actions');
    if(!actions) return;
    actions.classList.add('v15-shell-actions');

    const notification=actions.querySelector('[data-live-fix-notifications-link]');
    if(notification){
      notification.classList.add('v15-notification-button');
      const aria=notification.getAttribute('aria-label')||'Notifications';
      const match=aria.match(/(\d+)\s+unread/i);
      const unread=match?Number(match[1]):0;
      notification.innerHTML=icons.bell;
      if(unread>0){
        const badge=document.createElement('span');
        badge.className='v15-notification-badge';
        badge.textContent=unread>99?'99+':String(unread);
        notification.appendChild(badge);
      }
      notification.title=unread?(String(unread)+' unread notifications'):'Notifications';
    }

    const locationButton=actions.querySelector('.v14-location-pill,[data-route="location-picker"],button[aria-label^="Local operations are scoped to"]');
    if(locationButton){
      locationButton.classList.add('v14-location-pill','v15-location-button');
      const label=locationButton.querySelector('.label');
      if(label && !locationButton.querySelector('svg')){
        locationButton.innerHTML=icons.location+'<span class="label">'+label.textContent+'</span>';
      }
    }

    const roleSelect=actions.querySelector('[data-live-role-select]');
    const roleCount=roleSelect?.options?.length||0;
    top.classList.toggle('v15-multi-context',roleCount>1);
    top.classList.toggle('v15-single-context',roleCount<=1);
    if(roleSelect){
      roleSelect.classList.add('v15-context-select');
      roleSelect.setAttribute('aria-label','Switch Raahi view');
      roleSelect.title=roleCount>1?'Switch Raahi view':'Current Raahi view';
    }

    const settings=actions.querySelector('[data-route="settings"]');
    if(settings){
      settings.classList.add('v15-account-button');
      settings.title='Account and settings';
      const live=window.RaahiLearningLive;
      const account=live?.context?.account||{};
      const meta=live?.session?.user?.user_metadata||{};
      const googlePhoto=meta.avatar_url||meta.picture||'';
      if((!account.avatar_ref||account.avatar_type==='none')&&googlePhoto&&settings.dataset.v15PrivateAvatar!==googlePhoto){
        settings.textContent='';
        const wrap=document.createElement('span');
        wrap.className='avatar v15-account-avatar';
        const img=document.createElement('img');
        img.src=googlePhoto;
        img.alt='';
        img.referrerPolicy='no-referrer';
        wrap.appendChild(img);
        settings.appendChild(wrap);
        settings.dataset.v15PrivateAvatar=googlePhoto;
      }
    }

    for(const link of document.querySelectorAll('.mobile-nav a[href^="#/"]')){
      const key=(link.getAttribute('href')||'').replace('#/','').split('?')[0];
      const icon=link.querySelector('b');
      if(!icon) continue;
      for(const node of [...link.childNodes]){
        if(node!==icon && node.nodeType===Node.TEXT_NODE) node.remove();
      }
      let label=link.querySelector('.v15-mobile-label');
      if(!label){
        label=document.createElement('span');
        label.className='v15-mobile-label';
        link.appendChild(label);
      }
      label.textContent=mobileNavLabels[key]||key.replace(/-/g,' ');
      link.classList.add('v15-mobile-item');
      link.setAttribute('aria-label',label.textContent);
    }
  }

  function polishWelcome(){
    const card=[...document.querySelectorAll('.auth-card')].find(x=>/Continue with Google/i.test(x.textContent||''));
    if(!card) return;
    card.classList.add('v14-welcome-card'); card.closest('.auth-shell')?.classList.add('v14-auth-shell');
    const copy=card.querySelector('.auth-copy'); if(copy){
      const eyebrow=copy.querySelector('.eyebrow'); if(eyebrow) eyebrow.textContent='RAAHI · YOUR LOCAL LEARNING NETWORK';
      const h1=copy.querySelector('h1'); if(h1) h1.textContent='Learning, closer to home.';
      const p=copy.querySelector('p'); if(p) p.textContent='Find teachers, Classes and local learning around Dhanbad and Gomoh.';
    }
    if(!card.querySelector('.v14-welcome-values')){
      const values=document.createElement('div'); values.className='v14-welcome-values';
      values.innerHTML=`<div class="v14-value"><div class="v14-value-icon">${icons.explore}</div><strong>Find the right teacher</strong><span>Discover learning options in the Location you choose.</span></div><div class="v14-value"><div class="v14-value-icon">${icons.messages}</div><strong>Share what you need</strong><span>Post a genuine learning need and connect through Raahi.</span></div><div class="v14-value"><div class="v14-value-icon">${icons.community}</div><strong>Learn with your community</strong><span>Useful local questions, opportunities and conversations.</span></div>`;
      const button=[...card.querySelectorAll('button')].find(x=>/Continue with Google/i.test(x.textContent||''));
      if(button) button.insertAdjacentElement('afterend',values);
    }
    if(!card.querySelector('.v14-trust-strip')){
      const strip=document.createElement('div'); strip.className='v14-trust-strip';
      strip.innerHTML='<span>Google sign-in</span><span>Privacy-first</span><span>Local learning relationships</span>';
      const button=[...card.querySelectorAll('button')].find(x=>/Continue with Google/i.test(x.textContent||''));
      if(button) button.insertAdjacentElement('afterend',strip);
    }
    const intro=card.querySelector('[data-raahi-public-intro]');
    if(intro) intro.textContent='One Raahi account for learning, teaching and the people you support.';
    for(const p of card.querySelectorAll('p.tiny,p.muted')){
      if(/sensitive actions|phone number|phone confirmation/i.test(p.textContent||'')) p.textContent='Raahi may ask you to confirm your phone before sensitive changes.';
    }
  }

  function polishHome(){
    const main=document.querySelector('.main');
    if(route()!=='home'){ main?.classList.remove('v14-simple-home'); return; }
    if(!main) return;
    main.classList.add('v14-simple-home');
    const hero=main.querySelector('.hero'); if(!hero) return;
    hero.classList.add('v14-local-hero');
    const loc=locationName();
    const eyebrow=hero.querySelector('.eyebrow'); if(eyebrow) eyebrow.textContent=loc.toUpperCase();
    const h1=hero.querySelector('h1'); if(h1) h1.textContent='Find. Learn. Grow.';
    const p=hero.querySelector('p'); if(p) p.textContent='Teachers and learning near you.';
    const find=hero.querySelector('[data-route="explore"]'); if(find) find.textContent='Find a teacher';
    const need=hero.querySelector('[data-route="request-new"]'); if(need) need.textContent='I need tuition';

    const live=window.RaahiLearningLive;
    const canTeach=Array.isArray(live?.context?.capabilities) && live.context.capabilities.includes('teach');
    if(!canTeach && !hero.querySelector('.v14-teach-entry')){
      const entry=document.createElement('div');
      entry.className='v14-teach-entry';
      entry.innerHTML='<span>Are you a teacher?</span><a class="ghost-btn small" href="#/teacher-setup" data-v14-start-teaching>Start teaching</a>';
      const actions=hero.querySelector('.hero-actions');
      (actions||hero).insertAdjacentElement('afterend',entry);
    }

    for(const section of main.querySelectorAll(':scope > .section')){
      const title=section.querySelector(':scope > .section-title h2'); if(!title) continue;
      const text=title.textContent.trim();
      if(/^Continue |^My Classes$/i.test(text)) title.textContent='Your learning';
      if(/^Discover(?: in .*)?$/i.test(text)) title.textContent=`For you in ${loc}`;
      if(/^Sponsored learning opportunities$/i.test(text)) title.textContent='Featured';
    }

    const learningSection=[...main.querySelectorAll(':scope > .section')].find(section=>section.querySelector(':scope > .section-title h2')?.textContent.trim()==='Your learning');
    if(learningSection?.querySelector('.empty')) learningSection.style.display='none';

    const discoverySection=[...main.querySelectorAll(':scope > .section')].find(section=>/^For you in /i.test(section.querySelector(':scope > .section-title h2')?.textContent||''));
    if(discoverySection){
      const cards=[...discoverySection.querySelectorAll('.grid > .card,[data-live-option].card')];
      cards.slice(2).forEach(card=>card.classList.add('v14-home-extra-card'));
      cards.slice(0,2).forEach(card=>card.classList.add('v14-home-discovery-card'));
    }
    for(const card of main.querySelectorAll('.teacher-card')) card.closest('.card')?.classList.add('v14-home-teacher-card');
  }

  function polishPageHead(){
    const head=document.querySelector('.main .page-head'); if(!head) return;
    const title=head.querySelector('h1'), sub=head.querySelector('p'), loc=locationName();
    const r=route();
    const updates={
      explore:[`Explore ${loc}`,`Find teachers and learning opportunities in ${loc}.`],
      community:[`${loc} Learning Community`,`Questions, updates and useful learning conversations from ${loc}.`],
      messages:['Messages',`Talk safely with teachers and learning connections you've already connected with.`],
      classes:['My Classes','Your current Classes and invitations, all in one place.'],
      settings:['Settings','Your profile, learning access, privacy and account.'],
      'location-picker':['Choose a learning Location','Explore a local learning community. You can switch anytime.'],
    };
    if(!updates[r]) return;
    if(title) title.textContent=updates[r][0]; if(sub) sub.textContent=updates[r][1];
  }

  function polishEmptyStates(){
    const loc=locationName();
    const copy={
      'No active Classes':['Your Classes will live here',"When you join a teacher or learning group, you'll find it here.",'classes'],
      'No Classes':['Your Classes will live here','When you join a Class, its teacher, activities and updates will appear here.','classes'],
      'No current public options':[`We're growing ${loc}'s learning network`,`Tell Raahi what you want to learn, or explore another Location.`,'explore'],
      'No Community posts':[`Start the conversation in ${loc}`,`Ask a useful local learning question or share something that could help others.`,'community'],
      'No conversations':['No conversations yet','Start by asking a teacher about a learning option.','messages'],
    };
    for(const empty of document.querySelectorAll('.empty')){
      const h3=empty.querySelector('h3'), p=empty.querySelector('p'); if(!h3) continue;
      const next=copy[h3.textContent.trim()]; if(!next) continue;
      empty.classList.add('v14-empty'); h3.textContent=next[0]; if(p) p.textContent=next[1];
      const icon=empty.querySelector('.empty-icon'); if(icon){
        const svg=next[2]==='community'?icons.community:next[2]==='messages'?icons.messages:next[2]==='classes'?icons.classes:icons.explore;
        icon.innerHTML=svg;
      }
    }
  }

  function suppressMeaninglessEmptySponsored(){
    for(const empty of document.querySelectorAll('.empty')){
      if(!/No sponsored learning opportunities right now|No Sponsored card is eligible/i.test(empty.textContent||'')) continue;
      const section=empty.closest('.section');
      if(section) section.style.display='none'; else empty.style.display='none';
    }
  }

  function polishLocationPicker(){
    if(route()!=='location-picker') return;
    for(const card of document.querySelectorAll('.main .stack > .card')){
      if(card.dataset.v14LocationCard==='true') continue;
      const choose=card.querySelector('[data-live-location],[data-live-interest-location]'); if(!choose) continue;
      card.dataset.v14LocationCard='true'; card.classList.add('v14-location-card');
      const info=card.querySelector('p.card-sub');
      if(info && !card.querySelector('.v14-location-copy')){
        const line=document.createElement('div'); line.className='v14-location-copy tiny muted';
        line.style.marginTop='7px'; line.textContent='Local teachers, Classes and Community'; info.insertAdjacentElement('afterend',line);
      }
    }
  }


  function initials(name=''){
    return String(name).trim().split(/\s+/).filter(Boolean).slice(0,2).map(x=>x[0]).join('').toUpperCase() || 'R';
  }

  function addHomeArt(){
    if(route()!=='home') return;
    const hero=document.querySelector('.main .hero'); if(!hero || hero.querySelector('.v14-hero-art')) return;
    const art=document.createElement('div'); art.className='v14-hero-art'; art.setAttribute('aria-hidden','true');
    art.innerHTML='<div class="v14-orb one">'+icons.classes+'</div><div class="v14-orb two">'+icons.location+'</div><div class="v14-orb three">'+icons.community+'</div>';
    hero.appendChild(art);
  }

  function polishExploreBrowse(){
    if(route()!=='explore') return;
    const searchCard=document.querySelector('.main > .card'); if(!searchCard || searchCard.querySelector('.v14-category-strip') || searchCard.querySelector('.chip')) return;
    const strip=document.createElement('div'); strip.className='v14-category-strip'; strip.setAttribute('aria-label','Browse learning topics');
    for(const term of ['Maths','Science','English','Coding','Music']){
      const b=document.createElement('button'); b.type='button'; b.className='v14-category-chip'; b.textContent=term;
      b.addEventListener('click',()=>{const input=document.querySelector('#live-search');if(input){input.value=term;document.querySelector('[data-live-search]')?.click();}});
      strip.appendChild(b);
    }
    searchCard.appendChild(strip);
  }

  function polishDiscoveryPeople(){
    const live=window.RaahiLearningLive; if(!live?.data?.discovery) return;
    for(const card of document.querySelectorAll('[data-live-option].card')){
      if(card.querySelector('.v14-provider-mini')) continue;
      const o=live.data.discovery.find(x=>String(x.teaching_option_id)===String(card.dataset.liveOption)); if(!o) continue;
      card.classList.add('v14-market-card');
      const mini=document.createElement('div'); mini.className='v14-provider-mini';
      const descriptor=o.headline || (o.provider_type==='organization'?'Learning organisation':'Local teacher');
      mini.innerHTML='<div class="v14-provider-avatar" aria-hidden="true">'+initials(o.provider_name)+'</div><div><strong></strong><span></span></div>';
      mini.querySelector('strong').textContent=o.provider_name||'Learning provider';
      mini.querySelector('span').textContent=descriptor;
      const meta=card.querySelector('.meta-list'); if(meta) meta.insertAdjacentElement('beforebegin',mini); else card.appendChild(mini);
    }
  }

  function polishCommunityPeople(){
    if(route()!=='community') return;
    for(const card of document.querySelectorAll('.main .stack > .card')){
      if(card.dataset.v14Community==='true') continue;
      const between=card.querySelector(':scope > .between'); const author=between?.querySelector('strong'); if(!between||!author) continue;
      card.dataset.v14Community='true'; card.classList.add('v14-community-card');
      const avatar=document.createElement('div'); avatar.className='v14-feed-avatar'; avatar.setAttribute('aria-hidden','true'); avatar.textContent=initials(author.textContent);
      between.classList.add('v14-community-header'); between.insertBefore(avatar,between.firstChild);
    }
  }

  function polishMessagePeople(){
    if(route()!=='messages') return;
    for(const card of document.querySelectorAll('.main .stack > .card')){
      if(card.dataset.v14Message==='true') continue;
      const between=card.querySelector(':scope > .between'); const name=between?.querySelector('h3'); if(!between||!name) continue;
      card.dataset.v14Message='true'; card.classList.add('v14-message-card');
      const avatar=document.createElement('div'); avatar.className='v14-feed-avatar'; avatar.setAttribute('aria-hidden','true'); avatar.textContent=initials(name.textContent);
      between.insertBefore(avatar,between.firstChild);
    }
  }

  function polishLearningRequest(){
    if(!['request-new','request-edit'].includes(route())) return;
    const head=document.querySelector('.main .page-head');
    const title=head?.querySelector('h1'), sub=head?.querySelector('p');
    if(title && route()==='request-new') title.textContent='What are you looking to learn?';
    if(sub) sub.textContent='Share the learning need and let relevant local teachers understand how they can help.';
    const card=document.querySelector('.main .form-card'); if(card) card.classList.add('v14-request-card');
    const labelMap=new Map([['What do you need?','What are you looking to learn?'],['Category','Subject or skill'],['Details','Anything else that would help a teacher understand?'],['Timing preference','When would you prefer to learn?']]);
    for(const label of document.querySelectorAll('.main .field label')){const next=labelMap.get(label.textContent.trim());if(next)label.textContent=next;}
  }

  function polishProviderDetail(){
    if(route()!=='teaching-detail') return;
    const live=window.RaahiLearningLive; if(!live?.data || document.querySelector('.v14-provider-profile')) return;
    const t=live.data.teacherPublic, o=live.data.orgPublic, d=live.data.teachingDetail;
    const provider=t||o; if(!provider) return;
    const card=document.createElement('div'); card.className='card v14-provider-profile section';
    const name=t?.display_name||o?.name||d?.provider_name||'Learning provider';
    const descriptor=t?.headline||o?.organization_type||'Learning provider';
    card.innerHTML='<div class="v14-provider-row"><div class="v14-provider-avatar" aria-hidden="true"></div><div class="v14-provider-copy"><h3></h3><span></span></div></div><p class="v14-provider-bio"></p>';
    card.querySelector('.v14-provider-avatar').textContent=initials(name);
    card.querySelector('h3').textContent=name; card.querySelector('.v14-provider-copy span').textContent=descriptor;
    const bio=t?.bio||o?.description||''; const exp=t?.experience_summary||'';
    card.querySelector('.v14-provider-bio').textContent=[bio,exp].filter(Boolean).join(' ');
    if(!card.querySelector('.v14-provider-bio').textContent) card.querySelector('.v14-provider-bio').remove();
    const mainCard=document.querySelector('.main .page-head + .card'); if(mainCard) mainCard.insertAdjacentElement('afterend',card);
    const enquire=document.querySelector('[data-live-enquire-option]'); if(enquire) enquire.textContent='Ask about this';
  }

  function polishTeacherWorkspace(){
    if(route()!=='teacher-home') return;
    const live=window.RaahiLearningLive;
    const main=document.querySelector('.main');
    const workspace=live?.data?.teacherWorkspace;
    if(!main||!workspace) return;

    const head=main.querySelector('.page-head');
    const title=head?.querySelector('h1');
    const subtitle=head?.querySelector('p');
    if(title) title.textContent='Your teaching';
    if(subtitle) subtitle.textContent='Profile, Classes and learner activity in one place.';

    const grid=main.querySelector(':scope > .grid.two');
    if(!grid) return;
    grid.classList.add('v15-teacher-dashboard');

    const cards=[...grid.children].filter(el=>el.classList.contains('card'));
    const profileCard=cards[0];
    const optionCard=cards[1];
    const account=live.context?.account||{};
    const profile=workspace.profile||null;
    const options=Array.isArray(workspace.teaching_options)?workspace.teaching_options:[];
    const providerClasses=(Array.isArray(live.data?.classes)?live.data.classes:[]).filter(c=>c.context_kind==='provider');
    const unread=(Array.isArray(live.data?.notifications)?live.data.notifications:[]).filter(n=>!n.read_at).length;
    const name=account.display_name||'Teacher';
    const headline=profile?.headline||'Build your public teacher profile';
    const experience=profile?.experience_summary||'';
    const visible=profile?.visibility_status==='visible';
    const teachingLocations=[...new Set(options.flatMap(o=>Array.isArray(o.locations)?o.locations.map(l=>l?.name).filter(Boolean):[]))];

    const editProfile=head?.querySelector('[data-route="teacher-profile-edit"]')||main.querySelector('[data-route="teacher-profile-edit"]');
    if(profileCard && profileCard.dataset.v15TeacherHero!=='true'){
      profileCard.dataset.v15TeacherHero='true';
      profileCard.className='card v15-teacher-profile-card';

      const row=document.createElement('div');
      row.className='v15-teacher-profile-row';
      const avatar=document.createElement('div');
      avatar.className='v15-teacher-avatar';
      const headerImage=document.querySelector('.v15-account-avatar img');
      if(headerImage){
        const img=document.createElement('img');
        img.src=headerImage.src;
        img.alt='';
        avatar.appendChild(img);
      }else avatar.textContent=initials(name);

      const copy=document.createElement('div');
      copy.className='v15-teacher-profile-copy';
      const eyebrow=document.createElement('span');
      eyebrow.className='v15-teacher-eyebrow';
      eyebrow.textContent=name;
      const h=document.createElement('h2');
      h.textContent=headline;
      const meta=document.createElement('div');
      meta.className='v15-teacher-profile-meta';
      const status=document.createElement('span');
      status.className='badge '+(visible?'success':'');
      status.textContent=visible?'Profile visible':'Profile hidden';
      meta.appendChild(status);
      if(teachingLocations.length){
        const loc=document.createElement('span');
        loc.className='v15-teacher-location';
        loc.innerHTML=icons.location;
        const txt=document.createElement('span');
        txt.textContent=teachingLocations.slice(0,2).join(', ');
        loc.appendChild(txt);
        meta.appendChild(loc);
      }
      copy.append(eyebrow,h,meta);
      if(experience){
        const exp=document.createElement('p');
        exp.className='v15-teacher-experience';
        exp.textContent=experience;
        copy.appendChild(exp);
      }
      row.append(avatar,copy);
      profileCard.replaceChildren(row);
      if(editProfile){
        editProfile.textContent=profile?'Edit profile':'Set up profile';
        editProfile.classList.add('v15-teacher-edit');
        profileCard.appendChild(editProfile);
      }
    }

    if(optionCard && optionCard.dataset.v15TeacherStat!=='true'){
      optionCard.dataset.v15TeacherStat='true';
      optionCard.className='card v15-teacher-stat-card';
      const manage=optionCard.querySelector('[data-route="teaching-options"]');
      if(manage) manage.remove();
      optionCard.innerHTML='<span class="v15-teacher-stat-label">What I teach</span><strong class="v15-teacher-stat-value"></strong><span class="v15-teacher-stat-copy"></span>';
      optionCard.querySelector('.v15-teacher-stat-value').textContent=String(options.length);
      optionCard.querySelector('.v15-teacher-stat-copy').textContent=options.length===1?'teaching option':'teaching options';
      if(manage){
        manage.textContent='Edit what I teach';
        manage.className='pill-btn v15-teacher-stat-action';
        optionCard.appendChild(manage);
      }
    }

    if(!grid.querySelector('.v15-teacher-classes-stat')){
      const classCard=document.createElement('div');
      classCard.className='card v15-teacher-stat-card v15-teacher-classes-stat';
      classCard.innerHTML='<span class="v15-teacher-stat-label">Classes</span><strong class="v15-teacher-stat-value"></strong><span class="v15-teacher-stat-copy"></span><button class="pill-btn v15-teacher-stat-action" data-route="teacher-classes">Open Classes</button>';
      classCard.querySelector('.v15-teacher-stat-value').textContent=String(providerClasses.length);
      classCard.querySelector('.v15-teacher-stat-copy').textContent=providerClasses.length===1?'current Class':'current Classes';
      grid.appendChild(classCard);
    }

    if(!grid.querySelector('.v15-teacher-updates-stat')){
      const updateCard=document.createElement('div');
      updateCard.className='card v15-teacher-stat-card v15-teacher-updates-stat';
      updateCard.innerHTML='<span class="v15-teacher-stat-label">Updates</span><strong class="v15-teacher-stat-value"></strong><span class="v15-teacher-stat-copy"></span><button class="pill-btn v15-teacher-stat-action" data-route="messages">Messages</button>';
      updateCard.querySelector('.v15-teacher-stat-value').textContent=String(unread);
      updateCard.querySelector('.v15-teacher-stat-copy').textContent=unread===1?'unread update':'unread updates';
      grid.appendChild(updateCard);
    }

    const section=main.querySelector(':scope > .section');
    if(section){
      section.classList.add('v15-teacher-classes-section');
      if(!section.querySelector('.v15-teacher-section-title')){
        const sectionHead=document.createElement('div');
        sectionHead.className='section-title v15-teacher-section-title';
        const h2=document.createElement('h2');
        h2.textContent='Your Classes';
        const open=document.createElement('button');
        open.className='ghost-btn';
        open.dataset.route='teacher-classes';
        open.textContent='See all';
        sectionHead.append(h2,open);
        section.prepend(sectionHead);
      }
      section.querySelectorAll('.stack > .card').forEach(card=>{
        card.classList.add('v15-teacher-class-card');
        const badge=card.querySelector('.badge');
        if(badge&&badge.textContent) badge.textContent=badge.textContent.replace(/^./,c=>c.toUpperCase());
      });
    }
  }

  function polishInstituteWorkspace(){
    if(route()!=='org-home') return;
    const live=window.RaahiLearningLive;
    const main=document.querySelector('.main');
    const workspace=live?.data?.orgWorkspace;
    const organization=workspace?.organization;
    if(!main||!organization) return;

    const head=main.querySelector('.page-head');
    const title=head?.querySelector('h1');
    const subtitle=head?.querySelector('p');
    if(title) title.textContent='Institute workspace';
    if(subtitle) subtitle.textContent='Learning, Classes, team and Raahi Ads in one place.';

    const grid=main.querySelector(':scope > .grid.two');
    if(!grid) return;
    grid.classList.add('v15-institute-dashboard');

    if(!main.querySelector('.v15-institute-profile-card')){
      const hero=document.createElement('div');
      hero.className='card v15-institute-profile-card';

      const identity=document.createElement('div');
      identity.className='v15-institute-profile-row';

      const mark=document.createElement('div');
      mark.className='v15-institute-mark';
      mark.textContent=initials(organization.name||'Institute');

      const copy=document.createElement('div');
      copy.className='v15-institute-profile-copy';
      const eyebrow=document.createElement('span');
      eyebrow.className='v15-institute-eyebrow';
      eyebrow.textContent='Institute';
      const h=document.createElement('h2');
      h.textContent=organization.name||'Institute';

      const meta=document.createElement('div');
      meta.className='v15-institute-profile-meta';
      const type=document.createElement('span');
      type.className='badge';
      const typeMap={coaching:'Coaching institute',school:'School',college:'College',university:'University',training_centre:'Training centre',training_center:'Training centre'};
      type.textContent=typeMap[organization.organization_type]||String(organization.organization_type||'Institute').replace(/_/g,' ').replace(/^./,c=>c.toUpperCase());
      meta.appendChild(type);
      if(organization.status){
        const status=document.createElement('span');
        status.className='badge '+(organization.status==='active'?'success':'');
        status.textContent=String(organization.status).replace(/_/g,' ').replace(/^./,c=>c.toUpperCase());
        meta.appendChild(status);
      }
      copy.append(eyebrow,h,meta);

      if(organization.description){
        const desc=document.createElement('p');
        desc.className='v15-institute-description';
        desc.textContent=organization.description;
        copy.appendChild(desc);
      }
      if(organization.venue_text){
        const venue=document.createElement('div');
        venue.className='v15-institute-venue';
        venue.innerHTML=icons.location;
        const txt=document.createElement('span');
        txt.textContent=organization.venue_text;
        venue.appendChild(txt);
        copy.appendChild(venue);
      }

      identity.append(mark,copy);
      hero.appendChild(identity);

      const edit=head?.querySelector('[data-route="org-profile"]');
      if(edit){
        edit.textContent='Edit institute profile';
        edit.classList.add('v15-institute-edit');
        hero.appendChild(edit);
      }
      grid.insertAdjacentElement('beforebegin',hero);
    }

    const cards=[...grid.children].filter(el=>el.classList.contains('card'));
    for(const card of cards){
      const learning=card.querySelector('[data-route="org-teaching"]');
      const classes=card.querySelector('[data-route="teacher-classes"]');
      const team=card.querySelector('[data-route="org-members"]');
      const ads=card.querySelector('[data-route="ads-home"]');

      if(learning){
        card.className='card v15-institute-area-card v15-institute-learning-card';
        const count=Array.isArray(workspace.teaching_options)?workspace.teaching_options.length:0;
        card.innerHTML='<span class="v15-institute-area-label">Learning</span><strong class="v15-institute-area-value"></strong><span class="v15-institute-area-copy"></span>';
        card.querySelector('.v15-institute-area-value').textContent=String(count);
        card.querySelector('.v15-institute-area-copy').textContent=count===1?'public learning option':'public learning options';
        learning.textContent='Edit learning';
        learning.className='pill-btn v15-institute-area-action';
        card.appendChild(learning);
        continue;
      }

      if(classes){
        card.className='card v15-institute-area-card v15-institute-classes-card';
        card.innerHTML='<span class="v15-institute-area-label">Classes</span><strong class="v15-institute-area-title">Run your Classes</strong><span class="v15-institute-area-copy">Create and manage institute Classes.</span>';
        classes.textContent='Open Classes';
        classes.className='pill-btn v15-institute-area-action';
        card.appendChild(classes);
        continue;
      }

      if(team){
        card.className='card v15-institute-area-card v15-institute-team-card';
        const members=Array.isArray(live.data?.orgMembers)?live.data.orgMembers:[];
        const active=members.filter(m=>!m.status||m.status==='active').length;
        card.innerHTML='<span class="v15-institute-area-label">Team</span><strong class="v15-institute-area-value"></strong><span class="v15-institute-area-copy"></span>';
        card.querySelector('.v15-institute-area-value').textContent=String(active);
        card.querySelector('.v15-institute-area-copy').textContent=active===1?'active member':'active members';
        team.textContent='Manage team';
        team.className='pill-btn v15-institute-area-action';
        card.appendChild(team);
        continue;
      }

      if(ads){
        card.className='card v15-institute-area-card v15-institute-ads-card';
        card.innerHTML='<span class="v15-institute-area-label">Raahi Ads</span><strong class="v15-institute-area-title">Reach local learners</strong><span class="v15-institute-area-copy">Education-only campaigns for your institute.</span>';
        ads.textContent='Open Raahi Ads';
        ads.className='pill-btn v15-institute-area-action';
        card.appendChild(ads);
      }
    }
  }

  function polishPlatformWorkspace(){
    const r=route();
    if(!['platform-home','platform-safety','platform-ads'].includes(r)) return;
    const live=window.RaahiLearningLive;
    const main=document.querySelector('.main');
    const summary=live?.data?.platformSummary;
    if(!main||!summary||typeof summary!=='object') return;
    if(main.dataset.v15PlatformRoute===r) return;
    main.dataset.v15PlatformRoute=r;

    const head=main.querySelector('.page-head');
    const title=head?.querySelector('h1');
    const subtitle=head?.querySelector('p');
    const valueOf=key=>Object.prototype.hasOwnProperty.call(summary,key)&&summary[key]!=null?String(summary[key]):'—';
    const numberOf=key=>Object.prototype.hasOwnProperty.call(summary,key)&&summary[key]!=null?Number(summary[key]):null;
    const metric=(key,label,help,kind='')=>{
      const card=document.createElement('div');
      card.className='card v15-platform-metric-card'+(kind?' '+kind:'');
      const value=document.createElement('strong');
      value.className='v15-platform-metric-value';
      value.textContent=valueOf(key);
      const lab=document.createElement('span');
      lab.className='v15-platform-metric-label';
      lab.textContent=label;
      const copy=document.createElement('span');
      copy.className='v15-platform-metric-copy';
      copy.textContent=help;
      card.append(value,lab,copy);
      return card;
    };
    const action=(label,target,primary=false)=>{
      const button=document.createElement('button');
      button.className=(primary?'primary-btn':'pill-btn')+' v15-platform-action';
      button.dataset.route=target;
      button.textContent=label;
      return button;
    };
    const replaceAfterHead=(...nodes)=>{
      [...main.children].forEach(el=>{if(el!==head)el.remove();});
      nodes.forEach(node=>main.appendChild(node));
    };
    const contextCard=(heading,copyText,iconSvg)=>{
      const card=document.createElement('div');
      card.className='card v15-platform-context-card';
      const icon=document.createElement('div');
      icon.className='v15-platform-context-icon';
      icon.innerHTML=iconSvg;
      const copy=document.createElement('div');
      copy.className='v15-platform-context-copy';
      const eyebrow=document.createElement('span');
      eyebrow.className='v15-platform-eyebrow';
      eyebrow.textContent='Platform Admin';
      const h=document.createElement('h2');
      h.textContent=heading;
      const p=document.createElement('p');
      p.textContent=copyText;
      copy.append(eyebrow,h,p);
      card.append(icon,copy);
      return card;
    };

    if(r==='platform-home'){
      if(title) title.textContent='Platform operations';
      if(subtitle) subtitle.textContent='System activity, safety attention and advertising across active Locations.';
      const context=contextCard('Governed platform view','Broader operational scope still does not mean unrestricted access to private learning information.',icons.shield);

      const attention=document.createElement('section');
      attention.className='v15-platform-section';
      const ah=document.createElement('div');
      ah.className='v15-platform-section-head';
      ah.innerHTML='<div><span class="v15-platform-eyebrow">Needs attention</span><h2>Review queues</h2></div>';
      const ag=document.createElement('div');
      ag.className='v15-platform-metric-grid';
      ag.append(
        metric('open_reports','Open reports','Safety reports waiting for governed review',numberOf('open_reports')>0?'is-attention':''),
        metric('submitted_campaigns','Submitted campaigns','Campaign revisions waiting in review flow',numberOf('submitted_campaigns')>0?'is-attention':'')
      );
      attention.append(ah,ag);

      const system=document.createElement('section');
      system.className='v15-platform-section';
      const sh=document.createElement('div');
      sh.className='v15-platform-section-head';
      sh.innerHTML='<div><span class="v15-platform-eyebrow">Platform view</span><h2>Current footprint</h2></div>';
      const sg=document.createElement('div');
      sg.className='v15-platform-metric-grid v15-platform-metric-grid-wide';
      sg.append(
        metric('locations','Active Locations','Locations in the platform view'),
        metric('accounts','Accounts','Aggregate account count'),
        metric('learners','Learner profiles','Aggregate learner-profile count'),
        metric('audit_events','Audited actions','Governed actions in the summary'),
        metric('live_ad_placements','Sponsored placements','Currently live sponsored placements')
      );
      system.append(sh,sg);

      const actions=document.createElement('div');
      actions.className='v15-platform-quick-actions';
      actions.append(
        action('Safety review','platform-safety',numberOf('open_reports')>0),
        action('Ads review','platform-ads',numberOf('submitted_campaigns')>0),
        action('Location admins','location-admins'),
        action('Audit log','platform-audit')
      );
      replaceAfterHead(context,attention,system,actions);
      return;
    }

    if(r==='platform-safety'){
      if(title) title.textContent='Safety & trust';
      if(subtitle) subtitle.textContent='Review safety signals and governed actions without treating reports as findings.';
      const context=contextCard('Safety review','Reports are requests for review, not proof of wrongdoing. Exceptional actions remain logged and scoped.',icons.shield);
      const grid=document.createElement('div');
      grid.className='v15-platform-metric-grid v15-platform-safety-grid';
      grid.append(
        metric('open_reports','Open reports','Items currently waiting for review',numberOf('open_reports')>0?'is-attention':''),
        metric('audit_events','Audited actions','Governed actions recorded in the platform summary')
      );
      const actions=document.createElement('div');
      actions.className='v15-platform-quick-actions';
      actions.append(action('Location admins','location-admins'),action('Audit log','platform-audit'));
      replaceAfterHead(context,grid,actions);
      return;
    }

    if(r==='platform-ads'){
      if(title) title.textContent='Ads review';
      if(subtitle) subtitle.textContent='Review submitted creatives separately from commercial approval and inventory.';
      const summaryGrid=document.createElement('div');
      summaryGrid.className='v15-platform-metric-grid v15-platform-ads-summary';
      summaryGrid.append(
        metric('submitted_campaigns','Submitted campaigns','Campaigns currently in submitted state',numberOf('submitted_campaigns')>0?'is-attention':''),
        metric('live_ad_placements','Live placements','Sponsored placements currently live')
      );

      const section=document.createElement('section');
      section.className='section v15-platform-review-section';
      const sectionHead=document.createElement('div');
      sectionHead.className='section-title';
      const sectionTitle=document.createElement('h2');
      sectionTitle.textContent='Creative review queue';
      sectionHead.appendChild(sectionTitle);
      const stack=document.createElement('div');
      stack.className='stack';
      const reviews=Array.isArray(live.data?.platformAdReview)?live.data.platformAdReview:[];
      if(reviews.length){
        reviews.forEach(review=>{
          const card=document.createElement('div');
          card.className='card v15-platform-review-card';
          const row=document.createElement('div');
          row.className='between';
          const copy=document.createElement('div');
          const h=document.createElement('h3');
          h.textContent=review.campaign_name||review.headline||'Campaign revision';
          const state=document.createElement('p');
          state.className='card-sub';
          state.textContent=(review.current_review_state||'pending').replace(/_/g,' ').replace(/^./,c=>c.toUpperCase());
          copy.append(h,state);
          const actions=document.createElement('div');
          actions.className='row v15-platform-review-actions';
          [['Approve','approved','primary-btn'],['Request changes','changes_requested','pill-btn'],['Reject','rejected','danger-btn']].forEach(([label,decision,klass])=>{
            const button=document.createElement('button');
            button.className=klass+' small';
            button.dataset.liveAdReview=review.revision_id;
            button.dataset.reviewScope='platform';
            button.dataset.decision=decision;
            button.textContent=label;
            actions.appendChild(button);
          });
          row.append(copy,actions);
          card.appendChild(row);
          stack.appendChild(card);
        });
      }else{
        const empty=document.createElement('div');
        empty.className='card empty-state';
        const h=document.createElement('h3');
        h.textContent='No Ads waiting';
        const p=document.createElement('p');
        p.className='muted';
        p.textContent='No submitted campaign revision currently needs platform review.';
        empty.append(h,p);
        stack.appendChild(empty);
      }
      section.append(sectionHead,stack);
      replaceAfterHead(summaryGrid,section);
    }
  }

  function polishAdsWorkspace(){
    const r=route();
    const main=document.querySelector('.main');
    if(!main||!['ads-home','ads-create','ads-inventory','ads-analytics'].includes(r)) return;
    const head=main.querySelector('.page-head');
    const title=head?.querySelector('h1');
    const subtitle=head?.querySelector('p');

    if(r==='ads-home'){
      if(title) title.textContent='Raahi Ads';
      if(subtitle) subtitle.textContent='Create and manage education-only campaigns. Advertising never changes verification or organic ranking.';
      const create=head?.querySelector('[data-route="ads-create"]');
      if(create) create.textContent='Create campaign';
      main.querySelectorAll('.stack > .card.clickable').forEach(card=>{
        card.classList.add('v15-ad-campaign-card');
        const state=card.querySelector('.badge');
        if(state?.textContent) state.textContent=state.textContent.replace(/_/g,' ').replace(/^./,c=>c.toUpperCase());
      });
      return;
    }

    if(r==='ads-create'){
      if(title) title.textContent='Create campaign';
      if(subtitle) subtitle.textContent='Set the campaign goal, audience and dates. You can review details before anything goes live.';
      const form=main.querySelector('#live-ad-create-form');
      if(!form) return;
      form.classList.add('v15-ads-form');
      const rename=(name,label,placeholder)=>{
        const input=form.querySelector('[name="'+name+'"]');
        const field=input?.closest('.field');
        const lab=field?.querySelector('label');
        if(lab) lab.textContent=label;
        if(placeholder&&input) input.placeholder=placeholder;
      };
      rename('owner','Advertiser');
      rename('objective','Campaign goal');
      rename('name','Campaign name');
      rename('audience','Who should see this?','Example: families looking for Class 10 tuition');
      rename('category','Learning topic','Example: Mathematics, admissions, music');
      rename('starts','Starts');
      rename('ends','Ends');
      const submit=form.querySelector('button[type="submit"]');
      if(submit) submit.textContent='Create draft';
      if(!form.querySelector('.v15-ads-form-note')){
        const note=document.createElement('div');
        note.className='notice v15-ads-form-note';
        note.textContent='Draft campaigns are not shown to learners until the required review and placement steps are complete.';
        form.prepend(note);
      }
      return;
    }

    if(r==='ads-inventory'){
      if(title) title.textContent='Sponsored availability';
      if(subtitle) subtitle.textContent='Choose a placement and date range to check or reserve availability.';
      const form=main.querySelector('#live-ad-inventory-form');
      if(form){
        form.classList.add('v15-ads-form');
        const units=form.querySelector('[name="units"]')?.closest('.field')?.querySelector('label');
        if(units) units.textContent='Units needed';
        const check=form.querySelector('[data-live-check-inventory]');
        if(check) check.textContent='Check dates';
        const reserve=form.querySelector('button[type="submit"]');
        if(reserve) reserve.textContent='Reserve dates';
      }
      const result=[...main.querySelectorAll(':scope > .section.card')].at(-1);
      if(result){
        result.classList.add('v15-ads-results-card');
        const rows=Array.isArray(window.RaahiLearningLive?.data?.adInventory)?window.RaahiLearningLive.data.adInventory:[];
        if(rows.length){
          const list=document.createElement('div');
          list.className='v15-ads-availability-list';
          rows.forEach(row=>{
            const item=document.createElement('div');
            item.className='v15-ads-availability-row';
            const copy=document.createElement('div');
            const date=document.createElement('strong');
            date.textContent=row.inventory_date||'Date';
            const detail=document.createElement('span');
            const remaining=Number(row.remaining_units??0);
            const capacity=Number(row.capacity??0);
            detail.textContent=remaining+' of '+capacity+' units available';
            copy.append(date,detail);
            const max=document.createElement('span');
            max.className='badge';
            max.textContent='Up to '+String(row.max_units_per_campaign??'—')+' per campaign';
            item.append(copy,max);
            list.appendChild(item);
          });
          result.replaceChildren(list);
        }
      }
      return;
    }

    if(r==='ads-analytics'){
      if(title) title.textContent='Campaign results';
      if(subtitle) subtitle.textContent='Only aggregate totals are shown. Raahi does not provide a named viewer list.';
      const card=main.querySelector(':scope > .card');
      if(card){
        card.classList.add('v15-ads-results-card');
        const rows=Array.isArray(window.RaahiLearningLive?.data?.adMetrics)?window.RaahiLearningLive.data.adMetrics:[];
        if(rows.length){
          const totals=rows.reduce((acc,row)=>{
            acc.views+=Number(row.sponsored_views||0);
            acc.opens+=Number(row.opens||0);
            acc.enquiries+=Number(row.enquiries||0);
            acc.visits+=Number(row.external_visits||0);
            return acc;
          },{views:0,opens:0,enquiries:0,visits:0});
          const grid=document.createElement('div');
          grid.className='v15-ads-metric-grid';
          [['Sponsored views',totals.views],['Opens',totals.opens],['Enquiries',totals.enquiries],['External visits',totals.visits]].forEach(([label,value])=>{
            const item=document.createElement('div');
            item.className='v15-ads-metric-card';
            const strong=document.createElement('strong');
            strong.textContent=String(value);
            const span=document.createElement('span');
            span.textContent=label;
            item.append(strong,span);
            grid.appendChild(item);
          });
          card.replaceChildren(grid);
        }else{
          const muted=card.querySelector('.muted');
          if(muted&&/No aggregate metrics/i.test(muted.textContent||'')) muted.textContent='No aggregate results are available for this campaign yet.';
        }
      }
    }
  }

  function polishInstituteLearning(){
    if(route()!=='org-teaching') return;
    const main=document.querySelector('.main');
    if(!main) return;
    const subtitle=main.querySelector('.page-head p');
    if(subtitle) subtitle.textContent='Learning options offered by this institute.';
    for(const node of main.querySelectorAll('p,.card-sub,.muted')){
      const text=(node.textContent||'').trim();
      if(/staff access allows it/i.test(text)){
        node.textContent='Create a learning option if you can manage learning for this institute.';
      }
    }
  }

  function polishManagerWorkspace(){
    const r=route();
    if(!['manager-home','manager-people','manager-learning'].includes(r)) return;
    const live=window.RaahiLearningLive;
    const main=document.querySelector('.main');
    const overview=live?.data?.managerOverview;
    if(!main||!overview||typeof overview!=='object') return;
    if(main.dataset.v15ManagerRoute===r) return;
    main.dataset.v15ManagerRoute=r;

    const scope=(Array.isArray(live.context?.manager_scopes)?live.context.manager_scopes:[])[0]||null;
    const locationName=scope?.location_name||live.context?.selected_location?.name||'Local';
    const head=main.querySelector('.page-head');
    const title=head?.querySelector('h1');
    const subtitle=head?.querySelector('p');

    const valueOf=key=>Object.prototype.hasOwnProperty.call(overview,key)&&overview[key]!=null?String(overview[key]):'—';
    const numberOf=key=>Object.prototype.hasOwnProperty.call(overview,key)&&overview[key]!=null?Number(overview[key]):null;
    const metric=(key,label,help,kind='')=>{
      const card=document.createElement('div');
      card.className='card v15-manager-metric-card'+(kind?' '+kind:'');
      const value=document.createElement('strong');
      value.className='v15-manager-metric-value';
      value.textContent=valueOf(key);
      const lab=document.createElement('span');
      lab.className='v15-manager-metric-label';
      lab.textContent=label;
      const copy=document.createElement('span');
      copy.className='v15-manager-metric-copy';
      copy.textContent=help;
      card.append(value,lab,copy);
      return card;
    };
    const action=(label,target,primary=false)=>{
      const button=document.createElement('button');
      button.className=(primary?'primary-btn':'pill-btn')+' v15-manager-action';
      button.dataset.route=target;
      button.textContent=label;
      return button;
    };
    const replaceAfterHead=(...nodes)=>{
      [...main.children].forEach(el=>{if(el!==head)el.remove();});
      nodes.forEach(node=>main.appendChild(node));
    };

    if(r==='manager-home'){
      if(title) title.textContent=locationName+' operations';
      if(subtitle) subtitle.textContent='What needs attention and how local learning is moving.';

      const scopeCard=document.createElement('div');
      scopeCard.className='card v15-manager-scope-card';
      const icon=document.createElement('div');
      icon.className='v15-manager-scope-icon';
      icon.innerHTML=icons.location;
      const copy=document.createElement('div');
      copy.className='v15-manager-scope-copy';
      const eyebrow=document.createElement('span');
      eyebrow.className='v15-manager-eyebrow';
      eyebrow.textContent='Local Manager';
      const h=document.createElement('h2');
      h.textContent=locationName;
      const p=document.createElement('p');
      p.textContent='Aggregate local activity only — private learner and Class content stays private.';
      copy.append(eyebrow,h,p);
      scopeCard.append(icon,copy);

      const attention=document.createElement('section');
      attention.className='v15-manager-section';
      const attentionHead=document.createElement('div');
      attentionHead.className='v15-manager-section-head';
      attentionHead.innerHTML='<div><span class="v15-manager-eyebrow">Needs attention</span><h2>Today</h2></div>';
      const attentionGrid=document.createElement('div');
      attentionGrid.className='v15-manager-metric-grid';
      const reports=numberOf('open_reports');
      const requests=numberOf('open_learning_requests');
      attentionGrid.append(
        metric('open_reports','Open reports','Governed reports waiting for review',reports&&reports>0?'is-attention':''),
        metric('open_learning_requests','Learning requests','Public local needs currently open',requests&&requests>0?'is-attention':'')
      );
      attention.append(attentionHead,attentionGrid);

      const activity=document.createElement('section');
      activity.className='v15-manager-section';
      const activityHead=document.createElement('div');
      activityHead.className='v15-manager-section-head';
      activityHead.innerHTML='<div><span class="v15-manager-eyebrow">Local activity</span><h2>Learning ecosystem</h2></div>';
      const grid=document.createElement('div');
      grid.className='v15-manager-metric-grid v15-manager-metric-grid-four';
      grid.append(
        metric('active_classes','Active Classes','Current Classes in this Location'),
        metric('teaching_options','Learning options','Public local teaching supply'),
        metric('published_community_posts','Community posts','Published local conversations'),
        metric('live_ad_placements','Sponsored placements','Live local sponsored placements')
      );
      activity.append(activityHead,grid);

      const actions=document.createElement('div');
      actions.className='v15-manager-quick-actions';
      actions.append(action('Review reports','manager-reports',reports&&reports>0),action('Learning activity','manager-learning'),action('Open Raahi Desk','raahi-desk'));
      replaceAfterHead(scopeCard,attention,activity,actions);
      return;
    }

    if(r==='manager-people'){
      if(title) title.textContent='People & safety';
      if(subtitle) subtitle.textContent='Review concerns without creating a browseable learner directory.';

      const privacy=document.createElement('div');
      privacy.className='card v15-manager-privacy-card';
      const icon=document.createElement('div');
      icon.className='v15-manager-scope-icon';
      icon.innerHTML=icons.shield;
      const copy=document.createElement('div');
      copy.className='v15-manager-scope-copy';
      const h=document.createElement('h2');
      h.textContent='Privacy by design';
      const p=document.createElement('p');
      p.textContent='Local Managers work from governed reports and aggregate activity. Raahi does not expose a learner directory here.';
      copy.append(h,p);
      privacy.append(icon,copy);

      const reportsCard=metric('open_reports','Open reports','Reports are review requests, not proof of wrongdoing',numberOf('open_reports')>0?'is-attention':'');
      reportsCard.classList.add('v15-manager-focus-card');
      reportsCard.appendChild(action('Review reports','manager-reports',numberOf('open_reports')>0));
      replaceAfterHead(privacy,reportsCard);
      return;
    }

    if(r==='manager-learning'){
      if(title) title.textContent='Learning activity';
      if(subtitle) subtitle.textContent='Classes, teaching supply and learner demand across '+locationName+'.';

      const grid=document.createElement('div');
      grid.className='v15-manager-metric-grid v15-manager-learning-grid';
      grid.append(
        metric('active_classes','Active Classes','Current local Classes'),
        metric('teaching_options','Learning options','Public teaching supply'),
        metric('open_learning_requests','Learning requests','Public local demand'),
        metric('published_community_posts','Community posts','Local learning conversations')
      );
      const actions=document.createElement('div');
      actions.className='v15-manager-quick-actions';
      actions.append(action('Open Raahi Desk','raahi-desk'),action('Founding supply','founding-supply'));
      replaceAfterHead(grid,actions);
    }
  }

  function polishConversationThreads(){
    const r=route();
    const live=window.RaahiLearningLive;
    if(!live) return;

    if(r==='messages'){
      const head=document.querySelector('.main .page-head');
      const subtitle=head?.querySelector('p');
      if(subtitle) subtitle.textContent='Your conversations with teachers and Classes.';
      document.querySelectorAll('.main .stack > .card').forEach(card=>card.classList.add('v15-conversation-preview'));
      return;
    }

    if(!['enquiry','class-thread'].includes(r)) return;
    const main=document.querySelector('.main');
    const thread=r==='enquiry'?live.data?.enquiryThread:live.data?.classThread;
    if(!main||!thread) return;

    main.classList.add('v15-conversation-page');
    const head=main.querySelector('.page-head');
    const subtitle=head?.querySelector('p');
    if(r==='class-thread'&&subtitle){
      const learner=thread.learner_name||'this learner';
      subtitle.textContent='Private Class conversation about '+learner+'.';
    }else if(r==='enquiry'&&subtitle){
      subtitle.textContent=subtitle.textContent.replace(/\s*[\uFFFD·]\s*/g,' · ');
    }

    const card=main.querySelector(':scope > .card');
    if(!card) return;
    card.classList.add('v15-conversation-shell');

    const stack=card.querySelector(':scope > .stack');
    const messages=Array.isArray(thread.messages)?thread.messages:[];
    if(stack){
      stack.classList.add('v15-message-list');
      const bubbles=[...stack.querySelectorAll(':scope > .notice')];
      bubbles.forEach((bubble,index)=>{
        const message=messages[index]; if(!message) return;
        const mine=String(message.sender_account_id||'')===String(live.context?.account?.account_id||'');
        const previous=index>0?messages[index-1]:null;
        const continuation=!!previous&&String(previous.sender_account_id||'')===String(message.sender_account_id||'');
        bubble.classList.add('v15-message-bubble',mine?'is-mine':'is-theirs');
        bubble.classList.toggle('is-continuation',continuation);
        const sender=bubble.querySelector('strong');
        if(sender){
          sender.classList.add('v15-message-sender');
          if(mine) sender.textContent='You';
        }
        bubble.querySelector('p')?.classList.add('v15-message-body');
        bubble.querySelector('.tiny')?.classList.add('v15-message-time');
      });
      if(stack.dataset.v15ConversationScrolled!=='true'){
        stack.dataset.v15ConversationScrolled='true';
        requestAnimationFrame(()=>{stack.scrollTop=stack.scrollHeight;});
      }
    }

    const textarea=card.querySelector(r==='enquiry'?'#live-enquiry-message':'#live-class-message');
    const send=card.querySelector(r==='enquiry'?'[data-live-send-enquiry-message]':'[data-live-send-class-message]');
    const field=textarea?.closest('.field');
    if(textarea){
      textarea.placeholder='Write a message…';
      textarea.setAttribute('aria-label','Write a message');
    }
    if(field&&send&&!card.querySelector('.v15-conversation-composer')){
      const composer=document.createElement('div');
      composer.className='v15-conversation-composer';
      field.insertAdjacentElement('beforebegin',composer);
      composer.append(field,send);
      const divider=composer.previousElementSibling;
      if(divider?.classList.contains('divider')) divider.classList.add('v15-composer-divider');
    }

    if(r==='enquiry'){
      const meta=card.querySelector(':scope > .between');
      if(meta) meta.classList.add('v15-conversation-meta');
      const state=meta?.querySelector('.badge');
      if(state) state.textContent=(state.textContent||'').replace(/^./,c=>c.toUpperCase());
    }
  }

  function polishSettings(){
    if(route()!=='settings') return;
    const main=document.querySelector('.main');
    if(!main) return;

    const head=main.querySelector('.page-head');
    const subtitle=head?.querySelector('p');
    if(subtitle) subtitle.textContent='Your profile, sign-in and account.';

    const grid=main.querySelector(':scope > .grid.two');
    const cards=grid?[...grid.children].filter(el=>el.classList.contains('card')):[];
    const profile=cards[0], security=cards[1];

    if(profile && profile.dataset.v15SettingsProfile!=='true'){
      profile.dataset.v15SettingsProfile='true';
      profile.classList.add('v15-settings-card','v15-settings-profile');
      const intro=document.createElement('div');
      intro.className='v15-settings-section-head';
      intro.innerHTML='<div class="v15-settings-icon">'+icons.people+'</div><div><h3>Profile</h3><p>How your name and photo appear on Raahi.</p></div>';
      profile.prepend(intro);
      const label=profile.querySelector('.field label');
      if(label) label.textContent='Name on Raahi';
      const save=profile.querySelector('#live-profile-form button[type="submit"]');
      if(save) save.textContent='Save name';
      const avatar=profile.querySelector('[data-route="avatar-picker"]');
      if(avatar) avatar.textContent='Profile photo';
    }

    if(security && security.dataset.v15SettingsSecurity!=='true'){
      security.dataset.v15SettingsSecurity='true';
      security.classList.add('v15-settings-card','v15-settings-security');
      const title=security.querySelector('h3');
      if(title) title.textContent='Security';
      const badges=[...security.querySelectorAll('.badge')];
      if(badges[0]) badges[0].textContent='Google sign-in';
      if(badges[1]){
        badges[1].textContent='Phone confirmation';
        badges[1].classList.remove('warning');
        badges[1].classList.add('info');
      }
      const copy=security.querySelector('.card-sub');
      if(copy) copy.textContent='Raahi may ask you to confirm your phone before sensitive changes.';
      const phone=security.querySelector('[data-route="phone-check"]');
      if(phone) phone.textContent='Phone security';
      const icon=document.createElement('div');
      icon.className='v15-settings-icon';
      icon.innerHTML=icons.shield;
      title?.insertAdjacentElement('beforebegin',icon);
    }

    const account=[...main.querySelectorAll(':scope > .section.card')].find(card=>/Account lifecycle|Account/i.test(card.querySelector('h3')?.textContent||''));
    if(account && account.dataset.v15SettingsAccount!=='true'){
      account.dataset.v15SettingsAccount='true';
      account.classList.add('v15-settings-card','v15-settings-account');
      const title=account.querySelector('h3');
      if(title) title.textContent='Account';
      const originalCopy=account.querySelector(':scope > p');
      const actions=account.querySelector(':scope > .row');
      const lead=document.createElement('p');
      lead.className='card-sub v15-account-lead';
      lead.textContent='Sign out above, or manage longer-term account options here.';
      title?.insertAdjacentElement('afterend',lead);

      const details=document.createElement('details');
      details.className='v15-account-options';
      const summary=document.createElement('summary');
      summary.textContent='Pause or close account';
      details.appendChild(summary);
      const body=document.createElement('div');
      body.className='v15-account-options-body';
      if(originalCopy){
        originalCopy.textContent='Pausing limits new public activity. Account closure can be blocked while responsibilities are unresolved.';
        body.appendChild(originalCopy);
      }
      if(actions) body.appendChild(actions);
      details.appendChild(body);
      account.appendChild(details);
    }
  }

  function polishNotifications(){
    if(route()!=='notifications') return;
    const main=document.querySelector('.main');
    const stack=main?.querySelector(':scope > .stack');
    const live=window.RaahiLearningLive;
    if(!main||!stack||!Array.isArray(live?.data?.notifications)) return;

    const head=main.querySelector('.page-head');
    const subtitle=head?.querySelector('p');
    if(subtitle) subtitle.textContent='Updates from your Classes, enquiries and Raahi activity.';

    const rows=live.data.notifications;
    const unread=rows.filter(n=>!n.read_at).length;
    if(!main.querySelector('.v15-notification-summary')){
      const summary=document.createElement('div');
      summary.className='v15-notification-summary';
      const strong=document.createElement('strong');
      strong.textContent=unread ? String(unread)+' new' : 'All caught up';
      const span=document.createElement('span');
      span.textContent=unread
        ? (rows.length===unread ? 'Everything here still needs a look.' : String(rows.length-unread)+' already read.')
        : 'No unread updates right now.';
      summary.append(strong,span);
      stack.insertAdjacentElement('beforebegin',summary);
    }

    const categoryFor=type=>{
      if(/message|enquiry/.test(type)) return {label:/enquiry/.test(type)?'Enquiry':'Message',icon:icons.messages};
      if(/activity/.test(type)) return {label:'Activity',icon:icons.sparkle};
      if(/test/.test(type)) return {label:'Test',icon:icons.audit};
      if(/class/.test(type)) return {label:'Class',icon:icons.classes};
      if(/trial/.test(type)) return {label:'Trial',icon:icons.teaching};
      if(/organization/.test(type)) return {label:'Institute',icon:icons.people};
      return {label:'Update',icon:icons.bell};
    };

    stack.classList.add('v15-notification-list');
    const cards=[...stack.querySelectorAll(':scope > .card')];
    cards.forEach((card,index)=>{
      const n=rows[index]; if(!n) return;
      card.classList.add('v15-notification-card');
      card.classList.toggle('is-unread',!n.read_at);
      card.classList.toggle('is-read',!!n.read_at);
      const between=card.querySelector(':scope > .between'); if(!between) return;
      between.classList.add('v15-notification-row');

      let icon=between.querySelector(':scope > .v15-notification-icon');
      const category=categoryFor(n.notification_type||'');
      if(!icon){
        icon=document.createElement('div');
        icon.className='v15-notification-icon';
        icon.setAttribute('aria-hidden','true');
        between.prepend(icon);
      }
      icon.innerHTML=category.icon;

      const copy=[...between.children].find(el=>el!==icon && !el.classList.contains('row'));
      if(copy){
        copy.classList.add('v15-notification-copy');
        if(!copy.querySelector('.v15-notification-kind')){
          const kind=document.createElement('span');
          kind.className='v15-notification-kind';
          kind.textContent=category.label;
          copy.prepend(kind);
        }
        copy.querySelector('h3')?.classList.add('v15-notification-title');
      }

      const actions=between.querySelector(':scope > .row');
      if(actions){
        actions.classList.add('v15-notification-actions');
        const mark=actions.querySelector('[data-live-notification-read]');
        if(mark){ mark.classList.add('v15-mark-read'); mark.textContent='Mark read'; }
        const read=actions.querySelector('.badge');
        if(read) read.classList.add('v15-read-badge');
      }
    });
  }

  function polishAvatarPicker(){
    if(route()!=='avatar-picker') return;
    const main=document.querySelector('.main');
    const live=window.RaahiLearningLive;
    if(!main||!live?.context?.account) return;
    const head=main.querySelector('.page-head');
    const title=head?.querySelector('h1');
    const sub=head?.querySelector('p');
    if(title) title.textContent='Profile photo';
    if(sub) sub.textContent='Choose how you appear on Raahi. Learner profiles stay separate.';

    const card=main.querySelector('.form-card,.card');
    const form=card?.querySelector('#live-avatar-form');
    if(!card||!form||card.dataset.v15AvatarPicker==='true') return;
    card.dataset.v15AvatarPicker='true';
    card.classList.add('v15-avatar-card');

    const account=live.context.account||{};
    const meta=live.session?.user?.user_metadata||{};
    const googlePhoto=meta.avatar_url||meta.picture||'';
    const name=account.display_name||meta.full_name||meta.name||'Raahi member';

    const preview=document.createElement('div');
    preview.className='v15-avatar-preview';
    const visual=document.createElement('div');
    visual.className='v15-avatar-preview-visual';
    if(googlePhoto){
      const img=document.createElement('img');
      img.src=googlePhoto; img.alt=''; img.referrerPolicy='no-referrer';
      visual.appendChild(img);
    } else {
      visual.textContent=initials(name);
    }
    const copy=document.createElement('div');
    copy.className='v15-avatar-preview-copy';
    copy.innerHTML='<strong></strong><span></span>';
    copy.querySelector('strong').textContent=name;
    copy.querySelector('span').textContent=googlePhoto?'Your Google photo is available to import.':'Use a clean initials avatar for now.';
    preview.append(visual,copy);
    form.insertAdjacentElement('beforebegin',preview);

    if(googlePhoto){
      const google=document.createElement('button');
      google.type='button';
      google.className='primary-btn';
      google.dataset.liveImportGoogleAvatar='true';
      google.textContent='Use my Google photo';
      form.insertAdjacentElement('beforebegin',google);
    }

    form.innerHTML='<input type="hidden" name="type" value="initials"><input type="hidden" name="ref" value=""><button class="pill-btn" type="submit">Use initials</button>';
    const back=document.createElement('button');
    back.type='button'; back.className='ghost-btn'; back.dataset.route='settings'; back.textContent='Back to settings';
    form.insertAdjacentElement('afterend',back);

    const note=document.createElement('p');
    note.className='tiny muted v15-avatar-note';
    note.textContent='Your Google photo is copied into Raahi only when you choose it. Raahi never publishes a Google photo automatically.';
    card.appendChild(note);
  }

  function polishCardsAndContext(){
    for(const card of document.querySelectorAll('[data-live-option].card')) card.classList.add('v14-market-card');
    for(const tiny of document.querySelectorAll('.rightbar .tiny')) if(tiny.textContent.trim()==='Selected Location') tiny.textContent='Exploring';
  }

  let scheduled=false;
  const observer=new MutationObserver(schedule);
  const observe=()=>observer.observe(document.documentElement,{subtree:true,childList:true});
  function polish(){
    scheduled=false;
    observer.disconnect();
    try{
      polishBrand();
      polishIcons();
      polishShell();
      polishWelcome();
      polishHome();
      polishPageHead();
      polishEmptyStates();
      suppressMeaninglessEmptySponsored();
      polishLocationPicker();
      addHomeArt();
      polishExploreBrowse();
      polishDiscoveryPeople();
      polishCommunityPeople();
      polishMessagePeople();
      polishLearningRequest();
      polishProviderDetail();
      polishTeacherWorkspace();
      polishInstituteWorkspace();
      polishInstituteLearning();
      polishManagerWorkspace();
      polishPlatformWorkspace();
      polishAdsWorkspace();
      polishConversationThreads();
      polishSettings();
      polishNotifications();
      polishAvatarPicker();
      polishCardsAndContext();
    } finally {
      observer.takeRecords();
      observe();
    }
  }
  function schedule(){
    if(scheduled) return;
    scheduled=true;
    queueMicrotask(polish);
  }
  observe();
  window.addEventListener('hashchange',schedule);
  window.addEventListener('load',schedule);
  schedule();
})();
