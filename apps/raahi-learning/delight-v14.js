(() => {
  'use strict';

  // Presentation-only V1.4 delight layer. No data fetches, RPCs, writes, authority or routing changes.
  const icons={
    home:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M3.5 10.7 12 3.8l8.5 6.9v8.2a1.6 1.6 0 0 1-1.6 1.6H5.1a1.6 1.6 0 0 1-1.6-1.6v-8.2Z" stroke="currentColor" stroke-width="1.8"/><path d="M9.2 20.5v-6.2h5.6v6.2" stroke="currentColor" stroke-width="1.8"/></svg>',
    explore:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><circle cx="11" cy="11" r="6.5" stroke="currentColor" stroke-width="1.8"/><path d="m16 16 4.4 4.4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>',
    classes:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 5.5h6.8c1.2 0 2.2.7 2.2 1.8v11.2c0-1.1-1-1.8-2.2-1.8H4V5.5Zm16 0h-6.8c-1.2 0-2.2.7-2.2 1.8v11.2c0-1.1 1-1.8 2.2-1.8H20V5.5Z" stroke="currentColor" stroke-width="1.7"/></svg>',
    community:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M7.5 12.5a3.2 3.2 0 1 0 0-6.4 3.2 3.2 0 0 0 0 6.4Zm9.2-1.3a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5ZM2.8 19c.4-3 2.2-4.7 4.7-4.7s4.4 1.7 4.8 4.7m1.2-5.2c1-.8 2-1 3.2-1 2.2 0 3.8 1.4 4.1 3.8" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>',
    messages:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 5.5h16v11.3H9l-5 3.4V5.5Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M8 9.4h8M8 13h5" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>',
    location:'<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 21s6-5.9 6-11a6 6 0 1 0-12 0c0 5.1 6 11 6 11Z" stroke="currentColor" stroke-width="1.8"/><circle cx="12" cy="10" r="2.2" stroke="currentColor" stroke-width="1.8"/></svg>',
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
    const routeIcons={home:'home',explore:'explore',classes:'classes','teacher-classes':'classes',community:'community',messages:'messages'};
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

  function polishWelcome(){
    const card=[...document.querySelectorAll('.auth-card')].find(x=>/Continue with Google/i.test(x.textContent||''));
    if(!card) return;
    card.classList.add('v14-welcome-card'); card.closest('.auth-shell')?.classList.add('v14-auth-shell');
    const copy=card.querySelector('.auth-copy'); if(copy){
      const eyebrow=copy.querySelector('.eyebrow'); if(eyebrow) eyebrow.textContent='YOUR LOCAL LEARNING NETWORK';
      const h1=copy.querySelector('h1'); if(h1) h1.textContent='Find teachers. Find students. Learn locally.';
      const p=copy.querySelector('p'); if(p) p.textContent='Explore learning in Dhanbad and Gomoh. Switch Locations anytime with one Raahi account.';
    }
    if(!card.querySelector('.v14-welcome-values')){
      const values=document.createElement('div'); values.className='v14-welcome-values';
      values.innerHTML=`<div class="v14-value"><div class="v14-value-icon">${icons.explore}</div><strong>Find the right teacher</strong><span>Discover learning options in the Location you choose.</span></div><div class="v14-value"><div class="v14-value-icon">${icons.messages}</div><strong>Share what you need</strong><span>Post a genuine learning need and connect through Raahi.</span></div><div class="v14-value"><div class="v14-value-icon">${icons.community}</div><strong>Learn with your community</strong><span>Useful local questions, opportunities and conversations.</span></div>`;
      const button=[...card.querySelectorAll('button')].find(x=>/Continue with Google/i.test(x.textContent||''));
      if(button) button.insertAdjacentElement('beforebegin',values);
    }
    if(!card.querySelector('.v14-trust-strip')){
      const strip=document.createElement('div'); strip.className='v14-trust-strip';
      strip.innerHTML='<span>Google sign-in</span><span>Privacy-first</span><span>Local learning relationships</span>';
      const button=[...card.querySelectorAll('button')].find(x=>/Continue with Google/i.test(x.textContent||''));
      if(button) button.insertAdjacentElement('afterend',strip);
    }
    const intro=card.querySelector('[data-raahi-public-intro]');
    if(intro) intro.textContent='Teachers, learning opportunities and local conversations - connected around the places you choose.';
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
      entry.innerHTML='<span>Are you a teacher?</span><button class="ghost-btn small" data-route="teacher-setup">Start teaching</button>';
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
