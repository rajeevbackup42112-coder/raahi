(() => {
  'use strict';

  // Presentation-only launch polish. No authority, routing, data or business-rule changes.
  const pilotGoogleOnly = window.RAAHI_RELEASE_CONFIG?.phoneTrustMode === 'controlled_pilot_google_only';
  const replacements = new Map([
    ['taking_new_learners', 'Taking new learners'],
    ['not_taking_new_learners', 'Not taking new learners'],
    ['in_person', 'In person'],
    ['one_to_one', '1:1'],
    ['changes_requested', 'Changes requested'],
    ['draft_ready', 'Ready for review'],
    ['in_progress', 'In progress'],
    ['interest_only', 'Coming soon'],
    ['home_sponsored', 'Home Sponsored'],
    ['explore_sponsored', 'Explore Sponsored'],
    ['community_event', 'Community Sponsored'],
    ['external_url', 'External link'],
    ['course_batch', 'Course / batch'],
    ['learn_more', 'Learn more'],
    ['visit_site', 'Visit site'],
    ['other_education', 'Other education'],
    ['platform_admin', 'Platform Admin'],
    ['local_manager', 'Local Manager'],
    ['platform_editorial', 'Raahi editorial'],
    ['server-authorized', 'Access confirmed'],
    ['Server-authorized', 'Access confirmed'],
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
    ['This personalizes the first workspace. It does not permanently lock your account into one role.',
     'Choose what you want to do first. You can use Raahi in other ways anytime.'],
    ['You can have more than one workspace. Access appears only after the required Raahi relationship or capability exists.',
     'Choose the part of Raahi you want to use now. You can switch between the options available to you anytime.'],
    ['This does not lock your Account into one role.','You can use Raahi in other ways later.'],
    ['Learning history belongs to this Learner, not to your login.',
     'Your learning history stays with this learning profile even if your sign-in changes.'],
    ['Raahi creates one Learner identity and keeps its learning history separate from your Account.',
     'Raahi keeps this learner’s learning history together in one profile.'],
    ['The creator becomes the initial Organization administrator. Staff are added later with private invitations.',
     'You’ll manage this institute first. You can invite other staff later.'],
    ['Accepting links this Account to the same Learner and existing learning history. It does not create another Learner.',
     'Accepting gives you access to this learner’s existing learning history. It does not create a duplicate learner profile.'],
    ['This invitation grants only the listed Organization capabilities.',
     'This invitation gives you only the staff permissions shown below.'],
    ['Loading current authorized data…','Loading your Raahi information…'],
    ['Private to your Account.','Only you can see your saved items.'],
    ['Current relationship-scoped Classes.','Your current Classes.'],
    ['No current Classes are available in this context.','No current Classes are available here.'],
    ['Messages are scoped to one Class + one Learner.','A private conversation about this learner and Class.'],
    ['No contextual thread selected','No Class conversation selected'],
    ['Choose a learner from the Class or open Message from your Class context.',
     'Choose a learner from the Class to open this conversation.'],
    ['Only learner-side authority can transfer, and V1.2 offers eligible Classes from the same provider. The server rechecks capacity and authority.',
     'You can move this learner only to an eligible Class from the same teacher or institute. Raahi checks that space is still available when you confirm.'],
    ['Blocking limits ordinary contact without rewriting shared learning history.',
     'Blocking stops ordinary new contact while keeping existing learning and safety records.'],
    ['The server still preserves governed Class, safety and audit records where required.',
     'Existing Class, report and safety records are kept where needed.'],
    ['Current authorized submission history.','Review the learner’s submitted work and feedback.'],
    ['Learners are relationship-scoped and never exposed through a public directory.',
     'Your learning profiles are private and never shown in a public learner directory.'],
    ['Use explicit live fields; Location choices are server-validated.',
     'Add the details learners need to understand what you teach.'],
    ['Public provider profile controlled by your teach capability.',
     'This is the public profile learners can see.'],
    ['Provider-authorized Classes.','Create and manage your Classes.'],
    ['Create a Class material using governed Storage or an external link.',
     'Add a Class material as a file or external link.'],
    ['Organization-owned public teaching options.','Public learning options offered by this institute.'],
    ['Create one if your Organization capability permits it.',
     'Create a learning option if your staff access allows it.'],
    ['Staff are invited with private one-time links. Raahi does not expose an Account directory.',
     'Invite staff with private one-time links. Raahi does not provide a public people directory.'],
    ['Capabilities','Permissions'],
    ['manage_profile','Edit institute profile'],
    ['manage_teaching_options','Manage learning options'],
    ['manage_classes','Manage Classes'],
    ['manage_ads','Manage Raahi Ads'],
    ['manage_members','Manage staff'],
    ['No Organization management capability is currently active.',
     'You don’t currently have staff permissions to manage this institute.'],
    ['Organization workspace','Institute tools'],
    ['No editable Organization is selected.','No institute is selected for editing.'],
    ['Organization unavailable','Institute unavailable'],
    ['Select an authorized Organization workspace.','Choose an institute you’re allowed to manage.'],
    ['Save Organization profile','Save institute profile'],
    ['No Organization teaching options','No institute learning options'],
    ['Manager views are aggregate/operational, not a learner directory.',
     'This view shows local totals and public provider activity, not individual learner profiles.'],
    ['Raahi intentionally does not expose a public or manager-browseable learner directory. Use governed reports and aggregate Location projections.',
     'Raahi does not provide a public learner directory. Use reports and Location summaries for operational review.'],
    ['Location-scoped learning operations.','Learning activity and supply in this Location.'],
    ['No current reports are visible in this Location scope.','No reports currently need review in this Location.'],
    ['Governed Location state actions.','Manage whether this Location is live or paused.'],
    ['Education-only policy review, separated from commercial clearance.',
     'Review education-only campaigns for this Location. Campaign approval and payment checks are handled separately.'],
    ['Exceptional actions remain audited and scoped.','Sensitive actions are logged and limited to what is necessary.'],
    ['Policy, commercial and inventory states remain independent.',
     'Review campaign policy, payment readiness and ad availability separately.'],
    ['Governed action history. Human summary first; technical identifiers remain available when needed.',
     'A readable history of important platform actions. Open Technical details only when you need IDs.'],
    ['No audit entries are visible to this projection.','No audit entries are available here.'],
    ['Education-only campaigns owned by your authorized advertiser context.',
     'Create and manage education-only campaigns for the advertiser you’re using.'],
    ['Create a campaign when your advertiser eligibility is enabled.',
     'You can create a campaign once advertising is available for this advertiser.'],
    ['Advertising is an explicit capability/eligibility, not a shortcut to verification.',
     'Advertising access is separate from verification.'],
    ['Campaign creation is server-authorized. Paid visibility cannot buy verification, endorsement or organic ranking.',
     'You can create campaigns only when advertising is enabled for this advertiser. Paying for visibility does not buy verification, endorsement or a higher organic ranking.'],
    ['Campaign dates and education context are explicit.','Set the campaign purpose, audience and dates.'],
    ['Targets lock when the first creative revision is submitted.',
     'The Location and placement can’t be changed after the first creative is submitted for review.'],
    ['Commercial clearance','Commercial approval'],
    ['Location × placement × day availability; reservations are all-or-nothing.',
     'Check whether this placement is available for every day in your date range.'],
    ['Every revision is reviewed independently; Sponsored labeling is mandatory in serving UI.',
     'Each creative version is reviewed separately. Live ads are always clearly labelled Sponsored.'],
    ['Advertiser analytics are aggregate only.','Analytics show totals only, never a named viewer list.'],
    ['No eligible Sponsored placement selected.','No sponsored item is selected.'],
    ['Location changes public discovery and Community context, not existing Classes/history.',
     'Changing Location updates what you discover locally. Your existing Classes and learning history stay available.'],
    ['Interest does not auto-publish a profile or learning request.',
     'Registering interest does not publish your profile or a learning request.'],
    ['Update the Account avatar metadata without changing learner identity/history.',
     'Choose how your Raahi profile picture appears. This does not change any learner profile or learning history.'],
    ['Membership confirmed by the server.','You’re in.'],
    ['This live route has no fixture fallback.','This page isn’t available right now.'],
    ['Nothing is currently available for this authorized route.','Return to a Raahi page you can use.'],
    ['Fee is provider-supplied information. Payment happens directly between learner side and provider in V1.',
     'The teacher shared this fee. Payments are arranged directly with the teacher.'],
    ['The accepted Invitation created one active Class Membership. There is no extra join step after accepting the Invitation.',
     'The learner is now part of this Class. There is no extra joining step.'],
    ['Past is derived from time; Raahi does not track attendance in V1.',
     'Past sessions are shown by date. Raahi does not mark attendance.'],
    ['Contextual Class + learner thread. This works even if Rahul joined as an existing offline learner without an Enquiry.',
     'A private conversation about Rahul and this Class. You can use it even if the Class started outside an earlier Enquiry.'],
    ['A copied private storage path never grants access. Current Class authorization is checked when material is opened.',
     'Private Class materials open only for people who still have access to this Class.'],
    ['Destination capacity is re-checked when you confirm. Transfer creates destination Membership and ends the source as Transferred atomically.',
     'Raahi checks that the new Class still has space when you confirm. If the move succeeds, the learner leaves this Class and joins the new one together.'],
    ['Leaving ends active access. Shared Class feed/material access stops according to the V1 historical-access rules; Rahul’s legitimate own learning records are preserved.',
     'Leaving ends access to current Class updates and materials. Rahul’s own learning records remain available where appropriate.'],
    ['Blocking prevents ordinary new contact according to policy. It does not erase Enquiry history, Reports, Membership records or safety evidence.',
     'Blocking stops ordinary new contact. Existing learning history, reports and safety records are kept where needed.'],
    ['Parent/Guardian management authority allows oversight but does not allow impersonating Rahul to start or submit a Test.',
     'You can see Rahul’s Test status and released results, but Rahul must start and submit the Test from their own learner login.'],
    ['One responsible teacher per Class in V1.','Each Class has one responsible teacher.'],
    ['This is Class membership, not a public learner directory. Teacher access is limited to learners in the Class and permitted learning context.',
     'This list only includes learners in this Class. It is not a public learner directory.'],
    ['Protected files follow Class authorization.','Private files open only for people who still have access to the Class.'],
    ['Fixed/configured packages — no auction or CPC bidding in V1.',
     'Raahi uses fixed ad packages—there is no auction or pay-per-click bidding.'],
    ['One account may hold several capabilities.','Your Raahi account can support more than one way of using Raahi.'],
    ['These are capabilities/relationships, not a permanent account type.',
     'You can use Raahi in different ways as your needs change.'],
    ['Teacher workspace','Teaching'],
    ['Organization context','Institute'],
    ['Local Manager scope','Local Manager area'],
    ['Platform scope','Platform overview'],
    ['Cross-Location authority','All active Locations'],
    ['Platform-scoped','All Locations'],
    ['capability-based access','staff permissions'],
    ['Organization ownership','Institute ownership'],
    ['Classes and Campaigns remain Organization-owned even if an employee who created them later loses access.',
     'Classes and campaigns stay with the institute even if the staff member who created them later leaves.'],
    ['Local operations — public/local scope, not private Class surveillance.',
     'Local operations show public activity and local trends, not private Class content.'],
    ['Platform Admin uses governed commands and audit trails. Wider scope does not mean arbitrary direct table editing or casual private-data access.',
     'Platform Admin actions are logged. Broader access still does not mean unrestricted access to private learning information.'],
    ['Upcoming is derived from availability time; it is not another stored lifecycle state.',
     'This Test becomes available automatically at the scheduled time.'],
    ['Submitted creative becomes immutable. Material changes require a new Draft Revision.',
     'After you submit this creative for review, it can’t be edited. Create a new version for later changes.'],
    ['A newer Draft Revision never replaces it implicitly.',
     'A newer draft does not replace the live ad until it is approved.'],
    ['Review scope','What this action affects'],
    ['Restrictions are scoped: discovery, new Enquiries, messaging, Class access.',
     'Restrictions can be limited to discovery, new Enquiries, messaging or Class access.'],
    ['LEARNER MEMBERSHIP','LEARNER'],
    ['MEMBER CAPABILITIES','STAFF PERMISSIONS'],
    ['Learning context','Learning profile'],
    ['Organization management capability','Institute management access'],
    ['No memberships.','No learners are currently in this Class.'],
  ]);

  const phraseReplacements = [
    [/^(.+) belongs to another Raahi workspace\.$/,'$1 is available in another Raahi view.'],
    [/^(.+) requires different server-authorized authority\.$/,'You don’t currently have access to $1.'],
    [/^Your current Account does not have the required .* for this page\.$/,'This page isn’t available with your current Raahi access.'],
    [/^Your current Organization access does not include\s*$/,'Your staff access does not include'],
    [/^No server authority is granted by opening this URL\.$/,'Opening a link does not add permissions.'],
    [/^Public profiles are shown only when the server projection allows them\.$/,'This teacher profile is not available right now.'],
    [/^Only current public Organization data is shown\.$/,'Only current public institute information is shown.'],
    [/^Protected Test content is shown only to authorized self learner\/provider context\.$/,'This Test is available only to the learner taking it and the teacher managing it.'],
    [/^Guardian view shows status only; protected questions, answers and attempt-taking stay with self learner\/provider authority\.$/,'You can see Test status and released results here. The learner must take the Test from their own learning profile.'],
    [/One account may hold several capabilities\./g,'Your Raahi account can support more than one way of using Raahi.'],
    [/Protected files follow Class authorization\./g,'Private files open only for people who still have access to the Class.'],
    [/capability-based access/g,'staff permissions'],
    [/The Organization owns its profile, Classes and Campaigns\. Removing an employee does not delete Organization history\./g,
     'The institute keeps its profile, Classes and campaigns even when a staff member leaves.'],
    [/deletion cannot silently strand learner responsibilities or erase shared\/safety history\./g,
     'Raahi will first make sure the learner can still access their learning and that required shared or safety records are kept.'],
  ];

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
      let next=replacements.get(trimmed);
      if(next===undefined){
        next=trimmed;
        for(const [pattern,replacement] of phraseReplacements) next=next.replace(pattern,replacement);
        if(next===trimmed) continue;
      }
      const lead=raw.match(/^\s*/)?.[0]||'';
      const trail=raw.match(/\s*$/)?.[0]||'';
      node.nodeValue=lead+next+trail;
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
