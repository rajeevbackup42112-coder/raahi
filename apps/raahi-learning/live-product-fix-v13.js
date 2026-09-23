(() => {
  'use strict';

  // V1.3 post-SE-08 combined regression anchor; no runtime or business-rule change.
  const PENDING_ACTION_KEY = 'raahi.learning.pending-trust-action.v13';
  const PHONE_FLOW_KEY = 'raahi.learning.phone-flow.v13';

  // The base app can paint first-use forms a few milliseconds before this
  // overlay has finished attaching its canonical capture handlers. If a very
  // fast user submits during that window, defer the submit instead of dropping
  // the action. This listener is registered before live.js finishes loading.
  const EARLY_SETUP_FORMS = new Set([
    'live-google-profile-form',
    'live-create-self-learner-form',
    'live-create-managed-learner-form',
    'live-create-org-form',
    'live-teacher-profile-form',
    'live-option-form'
  ]);
  document.addEventListener('submit', e => {
    const form = e.target;
    if (!(form instanceof HTMLFormElement) || !EARLY_SETUP_FORMS.has(form.id)) return;
    if (window.RaahiLearningLive?.__productFixV13) return;
    e.preventDefault();
    e.stopImmediatePropagation();
    const retries = Number(form.dataset.raahiEarlySubmitRetries || '0');
    if (retries >= 20) return;
    form.dataset.raahiEarlySubmitRetries = String(retries + 1);
    setTimeout(() => {
      if (form.isConnected) form.requestSubmit();
    }, 50);
  }, true);

  const wait = setInterval(() => {
    const live = window.RaahiLearningLive;
    const api = window.RaahiLearningCore;
    if (!live || !api || !live.client) return;
    clearInterval(wait);
    if (live.__productFixV13) return;
    live.__productFixV13 = true;

    const originalRenderRoute = live.renderRoute.bind(live);
    const originalCanOpenRoute = live.canOpenRoute.bind(live);
    const originalRightbarHtml = live.rightbarHtml.bind(live);
    const originalAfterRender = live.afterRender.bind(live);
    const h = api.escapeHtml;
    const badge = api.badge;

    // Human context labels. Internal route/authority values remain unchanged.
    Object.assign(api.workspaceLabels,{
      learner:'My learning',
      student:'My learning',
      parent:'Learners I manage',
      teacher:'Teaching',
      institute:'Institute',
      manager:'Local operations',
      platform:'Platform operations',
      ads:'Raahi Ads'
    });
    const arr = v => Array.isArray(v) ? v : (v == null ? [] : [v]);
    const idk = prefix => `${prefix}-${crypto.randomUUID()}`;
    const currentLearners = () => arr(live.context?.learners);
    const selectedLearner = () => currentLearners().find(x => x.learner_id === live.selected.learnerId) || currentLearners()[0] || null;
    const errorText = e => e?.message || e?.details || e?.hint || String(e || 'Unknown error');
    const isPhoneGate = e => /PHONE_TRUST_REQUIRED/i.test(errorText(e));
    const selectedLocationName = () => live.context?.selected_location?.name || arr(live.data.locations).find(x => x.state === 'live')?.name || 'Choose location';
    const managerOperationalLocationName = () => arr(live.context?.manager_scopes)[0]?.location_name || selectedLocationName();
    const profileOnboardingPending = () => {
      const account = live.context?.account;
      return !!account
        && Object.prototype.hasOwnProperty.call(account,'profile_onboarding_completed_at')
        && account.profile_onboarding_completed_at === null;
    };
    const firstUsePending = () => {
      const account = live.context?.account;
      return !!account
        && Object.prototype.hasOwnProperty.call(account,'first_use_completed_at')
        && account.first_use_completed_at === null;
    };
    const replaceFirstPageTitle = (html, title) => String(html || '').replace(/<h1>[\s\S]*?<\/h1>/, `<h1>${h(title)}</h1>`);
    const viewAuthorized = role => {
      const context = live.context || {};
      const learners = arr(context.learners);
      const capabilities = arr(context.capabilities);
      const organizations = arr(context.organizations);
      const scopes = arr(context.manager_scopes);
      if (role === 'learner' || role === 'student') return learners.some(x => x.access_type === 'self');
      if (role === 'parent') return learners.some(x => x.access_type === 'manage');
      if (role === 'teacher') return capabilities.includes('teach');
      if (role === 'institute') return organizations.some(o => arr(o.capabilities).some(code => String(code).startsWith('manage_')));
      if (role === 'manager') return scopes.length > 0 || capabilities.includes('platform_admin');
      if (role === 'platform') return capabilities.includes('platform_admin');
      if (role === 'ads') return capabilities.includes('platform_admin') || organizations.some(o => arr(o.capabilities).includes('manage_ads'));
      return false;
    };


    async function rpc(name, params={}) {
      const { data, error } = await live.client.rpc(name, params);
      if (error) throw error;
      return data;
    }

    const phoneTrustMode = () => String(window.RAAHI_RELEASE_CONFIG?.phoneTrustMode || 'phone_trust_required');
    const phoneTrustProvider = () => String(window.RAAHI_RELEASE_CONFIG?.phoneTrustProvider || 'supabase');

    function phoneTrustErrorMessage(code) {
      const messages = {
        PHONE_ALREADY_IN_USE:'This mobile number is already linked to another Raahi sign-in. Use a different mobile number or sign in with the account that already uses it.',
        INVALID_OTP:'That verification code is not correct. Check the latest SMS and try again.',
        CHALLENGE_EXPIRED:'This verification code has expired. Send a new phone code.',
        CHALLENGE_NOT_ACTIVE:'This phone-check request is no longer active. Send a new phone code.',
        VERIFY_ATTEMPTS_EXCEEDED:'Too many incorrect attempts. Send a new phone code.',
        PHONE_OTP_RATE_LIMIT:'Too many phone-code requests. Please wait a little before trying again.',
        PHONE_OTP_PROVIDER_LIMIT:'The SMS provider is temporarily limiting requests. Please try again shortly.',
        PHONE_OTP_PROVIDER_BALANCE:'Phone verification is temporarily unavailable. Please try again later.',
        PHONE_OTP_SEND_FAILED:'Raahi could not send the phone code. Please try again.',
        PHONE_CONFIRM_FAILED:'Raahi could not attach this verified phone right now. Please try again later.'
      };
      return messages[code] || null;
    }

    async function externalPhoneTrust(provider, body) {
      const functionName = provider === 'startmessaging'
        ? 'phone-trust-startmessaging'
        : provider === 'messagecentral'
          ? 'phone-trust-messagecentral'
          : null;
      if (!functionName) throw new Error('Phone verification provider is unavailable.');
      const { data, error } = await live.client.functions.invoke(functionName, { body });
      let providerCode = data?.error || null;
      if (!providerCode && error?.context && typeof error.context.clone === 'function') {
        try {
          const payload = await error.context.clone().json();
          providerCode = payload?.error || null;
        } catch (_) {}
      }
      if (error || !data?.ok) {
        throw new Error(phoneTrustErrorMessage(providerCode) || errorText(error || data?.error || 'Phone verification failed.'));
      }
      return data;
    }

    function savePendingAction(action) {
      sessionStorage.setItem(PENDING_ACTION_KEY, JSON.stringify(action));
    }
    function loadPendingAction() {
      try { return JSON.parse(sessionStorage.getItem(PENDING_ACTION_KEY) || 'null'); }
      catch (_) { return null; }
    }
    function clearPendingAction() { sessionStorage.removeItem(PENDING_ACTION_KEY); }

    async function refreshCoreState() {
      const [ctx, classes, invitations, notifications, enquiries, conversations] = await Promise.all([
        rpc('get_my_account_context'), rpc('get_my_classes'), rpc('get_my_class_invitations'),
        rpc('get_my_notifications', { p_limit: 50 }), rpc('get_my_enquiries'), rpc('get_my_conversations')
      ]);
      live.context = ctx;
      live.data.classes = arr(classes);
      live.data.invitations = arr(invitations);
      live.data.notifications = arr(notifications);
      live.data.enquiries = arr(enquiries);
      live.data.conversations = arr(conversations);
    }

    async function refreshCurrentEnquiryThread() {
      if (!live.selected.enquiryId) return;
      try { live.data.enquiryThread = await rpc('get_enquiry_thread',{p_enquiry_id:live.selected.enquiryId}); }
      catch (_) { live.data.enquiryThread = null; }
    }

    async function refreshCurrentClassManagement() {
      if (!live.selected.classId) return;
      try { live.data.classManagement = await rpc('get_teacher_class_management',{p_class_id:live.selected.classId}); }
      catch (_) { live.data.classManagement = null; }
    }

    function currentPendingInvitation() {
      const learner = selectedLearner();
      const id = live.selected.invitationId;
      return arr(live.data.invitations).find(x => x.invitation_id === id)
        || arr(live.data.invitations).find(x => (!learner || x.learner_id === learner.learner_id) && (x.display_state === 'pending' || x.state === 'pending'))
        || null;
    }

    function pageClasses() {
      const learner = selectedLearner();
      const xs = arr(live.data.classes).filter(c => c.context_kind === 'learner' && (!learner || c.learner_id === learner.learner_id));
      const invitations = arr(live.data.invitations).filter(i => (!learner || i.learner_id === learner.learner_id) && (i.display_state === 'pending' || i.state === 'pending'));
      const invHtml = invitations.length ? `<div class="section"><div class="section-title"><h2>Class Invitations</h2></div><div class="stack">${invitations.map(i => `<div class="card"><div class="between"><div><h3>${h(i.class_title)}</h3><p class="card-sub">${h(i.provider_name)} · for ${h(i.learner_name)}</p></div>${badge('Pending','warning')}</div><p class="tiny muted">Seat reserved until ${h(new Date(i.expires_at).toLocaleString())}</p><button class="primary-btn" data-live-fix-open-invite="${i.invitation_id}">Review invitation</button></div>`).join('')}</div></div>` : '';
      const classHtml = xs.length ? xs.map(c => `<div class="card clickable" data-live-class="${c.class_id}" data-live-membership="${c.membership_id || ''}" data-live-class-learner="${c.learner_id || ''}" data-route="class-detail"><div class="between"><h3>${h(c.title)}</h3>${badge(c.class_state, c.class_state === 'active' ? 'success' : '')}</div><p class="card-sub">${h(c.class_type || '')}</p></div>`).join('') : api.empty('No Classes','No current Classes are available in this context.');
      return api.layout(`${api.pageHead('My Classes','Your current Classes and pending invitations, all in one place.')}${invHtml}<div class="section"><div class="section-title"><h2>Classes</h2></div><div class="stack">${classHtml}</div></div>`);
    }

    function pageInvitation() {
      const inv = currentPendingInvitation();
      if (!inv) return api.layout(api.pageHead('Class Invitation','Pending invitations reserve capacity until expiry or resolution.') + api.empty('No pending invitation','There is no current invitation for this learner.'));
      return api.layout(`${api.pageHead(h(inv.class_title),`${h(inv.provider_name)} · for ${h(inv.learner_name)}`)}<div class="card"><div class="between">${badge(inv.display_state || inv.state,'warning')}<span>Expires ${h(new Date(inv.expires_at).toLocaleString())}</span></div><p>Fee: ${h(inv.fee_display_text || 'Not specified')}</p><div class="notice">When you accept, Raahi checks that the invitation is still valid and then joins this learner to the Class.</div><div class="row" style="margin-top:14px"><button class="primary-btn" data-live-fix-accept-invite="${inv.invitation_id}">Accept & join</button><button class="pill-btn" data-live-decline-invite>Decline</button></div></div>`);
    }

    function pageLearners() {
      const learners = currentLearners();
      return api.layout(`${api.pageHead('Learning profiles','Keep your own learning and the learners you manage in one place.','<button class="primary-btn" data-route="learner-add">Add learner</button>')}<div class="stack">${learners.map(l => `<div class="card"><div class="between"><div><h3>${h(l.display_name)}</h3><p class="card-sub">${h(l.access_type === 'self' ? 'My learning' : 'Managed by you')}</p></div><div class="row">${l.access_type === 'manage' ? `<button class="pill-btn small" data-live-enable-self="${l.learner_id}">Set up learner login</button><button class="pill-btn small" data-live-share-learner="${l.learner_id}">Private Class code</button><button class="danger-btn small" data-live-fix-end-management="${l.access_id}">End my management</button>` : ''}</div></div>${l.access_type === 'manage' ? '<p class="tiny muted">You can stop managing this learner only when they will still have another valid way to access or manage their learning.</p>' : ''}</div>`).join('') || api.empty('No learner profiles','Add your own learning profile or a learner you manage.')}</div>`);
    }

    function normalizeIndianMobileInput(value) {
      let digits = String(value || '').replace(/\D/g, '');
      if (digits.length === 12 && digits.startsWith('91')) digits = digits.slice(2);
      if (digits.length === 11 && digits.startsWith('0')) digits = digits.slice(1);
      if (!/^[6-9]\d{9}$/.test(digits)) throw new Error('Enter a valid 10-digit Indian mobile number.');
      return '+91' + digits;
    }

    function formatIndianMobileField(input) {
      let digits = String(input?.value || '').replace(/\D/g, '');
      if (digits.length >= 12 && digits.startsWith('91')) digits = digits.slice(2);
      if (digits.length === 11 && digits.startsWith('0')) digits = digits.slice(1);
      if (input) input.value = digits.slice(0, 10);
    }

    async function signOutCurrentDevice() {
      sessionStorage.removeItem(PHONE_FLOW_KEY);
      clearPendingAction();
      live.__phoneTrustV13 = null;
      const { error } = await live.client.auth.signOut({ scope:'local' });
      if (error) throw error;
      const cleanUrl = location.origin + location.pathname + '#/welcome';
      location.replace(cleanUrl);
    }

    function pageFirstUseIntent() {
      return `<div class="auth-shell"><div class="auth-card wide-card">
        <div class="eyebrow">WELCOME TO RAAHI</div>
        <h1>What brings you here today?</h1>
        <p class="muted">Choose what you want to do first. You can always use Raahi in other ways later.</p>
        <div class="intent-grid">
          <button class="intent-card" data-live-first-use-intent="learner"><strong>I want to learn</strong><span>Set up my own learning profile</span></button>
          <button class="intent-card" data-live-first-use-intent="parent"><strong>I’m helping someone learn</strong><span>Add a learner I manage</span></button>
          <button class="intent-card" data-live-first-use-intent="teacher"><strong>I teach</strong><span>Set up my teaching presence</span></button>
          <button class="intent-card" data-live-first-use-intent="institute"><strong>I represent an institute</strong><span>Set up an education institute</span></button>
          <button class="intent-card" data-live-first-use-intent="explore"><strong>I’m just exploring</strong><span>See teachers and learning around me</span></button>
        </div>
      </div></div>`;
    }

    function pagePhoneCheck() {
      if (phoneTrustMode() === 'controlled_pilot_google_only') {
        return `<div class="auth-shell"><div class="auth-card"><div class="eyebrow">Pilot access</div><h1>Google sign-in is enough for this pilot</h1><p class="muted">Phone verification is not required during the controlled Gomoh + Dhanbad pilot.</p><button class="primary-btn wide" data-live-fix-resume-action>Continue</button><button class="ghost-btn wide" data-live-fix-logout>Log out</button></div></div>`;
      }
      const trust = live.__phoneTrustV13;
      if (!trust) return `<div class="auth-shell"><div class="auth-card"><div class="eyebrow">Phone trust check</div><h1>Checking your phone trust…</h1><p class="muted">Raahi is reading the current server-verified trust state.</p><button class="ghost-btn wide" data-live-fix-logout>Log out</button></div></div>`;
      if (trust.state === 'fresh') return `<div class="auth-shell"><div class="auth-card"><div class="eyebrow">Phone trust</div><h1>Phone confirmed</h1><p class="muted">Your current phone trust is fresh.</p><button class="primary-btn wide" data-live-fix-resume-action>Continue</button><button class="ghost-btn wide" data-live-fix-logout>Log out</button></div></div>`;
      const hasPhone = !!trust.has_phone;
      return `<div class="auth-shell"><div class="auth-card"><div class="eyebrow">Quick phone check</div><h1>${hasPhone ? 'Confirm you still have this phone' : 'Add a phone for trust-sensitive actions'}</h1><p class="muted">This is not a second login. It is a security check for sensitive actions. It does not change what you can do in Raahi.</p>${hasPhone ? `<div class="notice">Current phone: ${h(trust.masked_phone || '')}</div>` : '<div class="field"><label>Indian mobile number</label><div class="row" style="gap:8px;align-items:center"><span class="pill-btn" aria-hidden="true" style="pointer-events:none">+91</span><input id="live-fix-phone" inputmode="numeric" autocomplete="tel-national" maxlength="12" placeholder="9876543210" aria-describedby="live-fix-phone-help"></div><span class="field-note" id="live-fix-phone-help">Enter your 10-digit mobile number. Raahi adds +91 automatically. You can also paste a number starting with +91.</span></div>'}<button class="primary-btn wide" data-live-fix-send-phone-otp>${hasPhone ? 'Send confirmation code' : 'Send phone code'}</button><div class="divider"></div><div class="field"><label>Verification code</label><input id="live-fix-phone-otp" inputmode="numeric" autocomplete="one-time-code"></div><button class="pill-btn wide" data-live-fix-verify-phone>Verify & continue</button><button class="ghost-btn wide" data-route="settings">Cancel</button><button class="ghost-btn wide" data-live-fix-logout>Log out</button></div></div>`;
    }

    live.canOpenRoute = function(route, required, state) {
      if (live.session && live.context && !live.pendingInvite && (profileOnboardingPending() || firstUsePending())) {
        // This does not authorize the requested route. It only lets renderRoute
        // replace any deep link with the mandatory onboarding surface before
        // privileged route data can render.
        return true;
      }
      return originalCanOpenRoute(route, required, state);
    };

    const originalRender = live.renderRoute;
    live.renderRoute = function(route, coreApi) {
      if (live.session && live.context) {
        if (!live.pendingInvite && profileOnboardingPending()) {
          if (route !== 'google-profile' && location.hash !== '#/google-profile') history.replaceState(null,'','#/google-profile');
          return originalRender('google-profile', coreApi);
        }
        if (!live.pendingInvite && firstUsePending()) {
          if (route !== 'onboarding-intent' && location.hash !== '#/onboarding-intent') history.replaceState(null,'','#/onboarding-intent');
          return pageFirstUseIntent();
        }
        if (route === 'classes' && ['learner','student','parent'].includes(coreApi.state.role)) return pageClasses();
        if (route === 'invitation') return pageInvitation();
        if (route === 'learners') return pageLearners();
        const roleSelect = document.querySelector('[data-live-role-select]');
      if (roleSelect) roleSelect.setAttribute('aria-label','Switch Raahi view');

      if (route === 'phone-check' || route === 'otp') {
          if (!live.__phoneTrustLoadingV13 && !live.__phoneTrustV13) {
            live.__phoneTrustLoadingV13 = true;
            setTimeout(async () => {
              try { live.__phoneTrustV13 = await rpc('get_my_phone_trust'); }
              catch (e) { live.__phoneTrustV13 = { state:'error', has_phone:false, error:errorText(e) }; }
              finally { live.__phoneTrustLoadingV13 = false; coreApi.render(); }
            }, 0);
          }
          return pagePhoneCheck();
        }
      }
      const rendered = originalRender(route, coreApi);
      if (route === 'home' && ['learner','student','parent'].includes(coreApi.state.role)) {
        return replaceFirstPageTitle(rendered, 'Learn locally. Keep learning together.');
      }
      if (route === 'community') {
        return replaceFirstPageTitle(rendered, `${selectedLocationName()} Community`);
      }
      if (route === 'teacher-home') {
        return replaceFirstPageTitle(rendered, 'Teach locally, without chasing leads.');
      }
      if (route === 'teacher-profile-edit') {
        return String(rendered).replace(
          'Public provider profile controlled by your teach capability.',
          'Tell learners about your teaching experience and approach.'
        );
      }
      if (route === 'teaching-option-edit') {
        return String(rendered)
          .replace('Use explicit live fields; Location choices are server-validated.','Add what you teach, how you teach, and where learners can find you.')
          .replace('<label>Live Locations</label>','<label>Where can learners find this?</label>');
      }
      if (route === 'manager-home') {
        return replaceFirstPageTitle(rendered, `${managerOperationalLocationName()} Overview`);
      }
      if (route === 'ads-eligibility') {
        return replaceFirstPageTitle(rendered, 'Advertising eligibility');
      }
      if (route === 'ads-inventory') {
        return replaceFirstPageTitle(rendered, 'Ads Inventory');
      }
      return rendered;
    };

    live.workspaceDenied = function(route, allowed, coreApi) {
      const choices = arr(allowed)
        .filter(viewAuthorized)
        .map(r => `<button class="pill-btn" data-live-role="${h(r)}">Switch to ${h(coreApi.workspaceLabels?.[r] || r)}</button>`)
        .join('');
      return coreApi.layout(`${coreApi.pageHead('This page isn’t available here','Choose another Raahi view you already have access to.')}
        <div class="card empty"><div class="empty-icon">↪</div><h3>You don’t have access to this page yet</h3>
        <p>If you use Raahi in more than one way, choose another view below.</p>
        <div class="wrap" style="justify-content:center">${choices}</div></div>`);
    };

    live.rightbarHtml = function(coreApi) {
      const base = originalRightbarHtml(coreApi);
      if (live.context && ['learner','student','parent'].includes(coreApi.state.role)) return `${base}<div class="card"><div class="tiny muted">Learning access</div><p class="text-sm">Manage your own learning and the learners you help.</p><a class="pill-btn small" href="#/learners">Manage learning profiles</a></div>`;
      return base;
    };

    async function executePendingAction(action) {
      if (!action) return false;
      const result = await rpc(action.rpc, action.params);
      if (result?.organization_id) live.selected.organizationId = result.organization_id;
      clearPendingAction();
      await refreshCoreState();
      if (action.postRole) api.state.role = action.postRole;
      if (action.clearTeachingOption) live.selected.teachingOptionId = null;
      if (action.postRole === 'teacher') {
        try { live.data.teacherWorkspace = await rpc('get_my_teacher_workspace'); }
        catch (_) { live.data.teacherWorkspace = null; }
      }
      if (action.postRole === 'institute') {
        const orgId = live.selected.organizationId || arr(live.context?.organizations)[0]?.organization_id || null;
        if (orgId) {
          live.selected.organizationId = orgId;
          try { live.data.orgWorkspace = await rpc('get_organization_workspace',{p_organization_id:orgId}); }
          catch (_) { live.data.orgWorkspace = null; }
        }
      }
      return result;
    }

    async function runSensitiveAction(action, successRoute, successText) {
      const pendingAction = { ...action, successRoute: action.successRoute || successRoute || null };
      try {
        await executePendingAction(pendingAction);
        api.toast(successText,'success');
        if (successRoute) api.go(successRoute); else api.render();
      } catch (e) {
        if (isPhoneGate(e)) {
          savePendingAction(pendingAction);
          live.__phoneTrustV13 = null;
          api.go('phone-check');
        } else api.toast(errorText(e),'danger');
      }
    }
    live.runSensitiveActionV13 = runSensitiveAction;

    async function sendPhoneOtp() {
      if (phoneTrustMode() === 'controlled_pilot_google_only') throw new Error('Phone verification is not required during this pilot.');
      const trust = live.__phoneTrustV13 || await rpc('get_my_phone_trust');

      const provider = phoneTrustProvider();
      if (provider === 'messagecentral' || provider === 'startmessaging') {
        let phone = null;
        if (!trust.has_phone) {
          phone = normalizeIndianMobileInput(document.querySelector('#live-fix-phone')?.value);
        }
        const sent = await externalPhoneTrust(provider, { action:'send', ...(phone ? { phone } : {}) });
        sessionStorage.setItem(PHONE_FLOW_KEY, JSON.stringify({
          provider,
          challenge_id:sent.challenge_id,
        }));
        api.toast('Verification code sent','success');
        return;
      }

      if (trust.has_phone) {
        const { data: userData, error: userError } = await live.client.auth.getUser();
        if (userError) throw userError;
        const phone = userData.user?.phone;
        if (!phone) throw new Error('Confirmed phone is unavailable in Auth.');
        const e164 = phone.startsWith('+') ? phone : `+${phone}`;
        const { error } = await live.client.auth.signInWithOtp({ phone: e164, options: { shouldCreateUser: false } });
        if (error) throw error;
        sessionStorage.setItem(PHONE_FLOW_KEY, JSON.stringify({ provider:'supabase', phone:e164, type:'sms' }));
      } else {
        const phone = normalizeIndianMobileInput(document.querySelector('#live-fix-phone')?.value);
        const { error } = await live.client.auth.updateUser({ phone });
        if (error) throw error;
        sessionStorage.setItem(PHONE_FLOW_KEY, JSON.stringify({ provider:'supabase', phone, type:'phone_change' }));
      }
      api.toast('Verification code sent','success');
    }

    async function verifyPhoneOtp() {
      if (phoneTrustMode() === 'controlled_pilot_google_only') throw new Error('Phone verification is not required during this pilot.');
      const token = document.querySelector('#live-fix-phone-otp')?.value?.trim();
      if (!token) throw new Error('Enter the verification code.');
      const flow = JSON.parse(sessionStorage.getItem(PHONE_FLOW_KEY) || 'null');
      if (!flow) throw new Error('Send a verification code first.');

      if (flow.provider === 'messagecentral' || flow.provider === 'startmessaging') {
        if (!flow.challenge_id) throw new Error('Send a verification code first.');
        await externalPhoneTrust(flow.provider, { action:'verify', challenge_id:flow.challenge_id, code:token });
        await live.client.auth.refreshSession().catch(() => {});
      } else {
        if (!flow.phone || !flow.type) throw new Error('Send a verification code first.');
        const { error } = await live.client.auth.verifyOtp({ phone: flow.phone, token, type: flow.type });
        if (error) throw error;
      }

      sessionStorage.removeItem(PHONE_FLOW_KEY);
      live.__phoneTrustV13 = await rpc('get_my_phone_trust');
      if (live.__phoneTrustV13?.state !== 'fresh') throw new Error('Phone proof completed but trust is not fresh.');
      const pending = loadPendingAction();
      if (pending) {
        await executePendingAction(pending);
        api.toast('Phone confirmed and action completed','success');
        api.go(pending.successRoute || 'classes');
      } else {
        api.toast('Phone confirmed','success');
        api.go('settings');
      }
    }

    document.addEventListener('input', e => {
      if (e.target?.id === 'live-fix-phone') formatIndianMobileField(e.target);
    }, true);

    document.addEventListener('submit', async e => {
      const form = e.target;
      if (!(form instanceof HTMLFormElement) || form.id !== 'live-google-profile-form' || !profileOnboardingPending()) return;
      e.preventDefault();
      e.stopImmediatePropagation();
      const submit = form.querySelector('button[type="submit"]');
      if (submit) submit.disabled = true;
      try {
        const fd = new FormData(form);
        const display = String(fd.get('display') || '').trim();
        if (!display) throw new Error('Enter the name you want to show on Raahi.');
        await rpc('update_account_profile',{
          p_display_name:display,
          p_avatar_type:live.context.account.avatar_type || 'none',
          p_avatar_ref:live.context.account.avatar_ref || null,
          p_idempotency_key:idk('google-profile')
        });
        await rpc('complete_profile_onboarding',{p_idempotency_key:idk('profile-onboarding')});
        live.context = await rpc('get_my_account_context');
        api.toast('Raahi profile saved','success');
        api.go('onboarding-intent');
      } catch (err) {
        api.toast(errorText(err),'danger');
      } finally {
        if (submit?.isConnected) submit.disabled = false;
      }
    }, true);

    document.addEventListener('submit', async e => {
      const form = e.target;
      if (!(form instanceof HTMLFormElement)) return;
      if (!['live-create-self-learner-form','live-create-managed-learner-form','live-create-org-form'].includes(form.id)) return;
      e.preventDefault();
      e.stopImmediatePropagation();
      const submit = form.querySelector('button[type="submit"]');
      if (submit) submit.disabled = true;
      try {
        const fd = new FormData(form);

        if (form.id === 'live-create-self-learner-form' || form.id === 'live-create-managed-learner-form') {
          const accessType = form.id === 'live-create-self-learner-form' ? 'self' : 'manage';
          const result = await rpc('create_learner',{
            p_display_name:String(fd.get('name') || '').trim(),
            p_access_type:accessType,
            p_avatar_type:'none',
            p_avatar_ref:null,
            p_idempotency_key:idk(accessType === 'self' ? 'learner-self' : 'learner-manage')
          });
          live.context = await rpc('get_my_account_context');
          live.selected.learnerId = result?.learner_id || null;
          api.state.role = accessType === 'self' ? 'learner' : 'parent';
          await refreshCoreState();
          api.go('home');
          return;
        }

        await runSensitiveAction({
          rpc:'create_organization',
          params:{
            p_organization_type:String(fd.get('type') || 'other_education'),
            p_name:String(fd.get('name') || '').trim(),
            p_description:String(fd.get('description') || '').trim() || null,
            p_public_contact_text:null,
            p_venue_text:null,
            p_website_url:null,
            p_logo_type:'none',
            p_logo_ref:null,
            p_idempotency_key:idk('organization')
          },
          successRoute:'org-home',
          postRole:'institute'
        },'org-home','Institute created');
      } catch (err) {
        api.toast(errorText(err),'danger');
      } finally {
        if (submit?.isConnected) submit.disabled = false;
      }
    }, true);

    document.addEventListener('submit', async e => {
      const form = e.target;
      if (!(form instanceof HTMLFormElement) || api.state.role !== 'teacher') return;
      const options = arr(live.data.teacherWorkspace?.teaching_options);

      if (form.id === 'live-teacher-profile-form' && options.length === 0) {
        e.preventDefault();
        e.stopImmediatePropagation();
        const fd = new FormData(form);
        await runSensitiveAction({
          rpc:'upsert_teacher_profile',
          params:{
            p_headline:String(fd.get('headline') || '').trim() || null,
            p_bio:String(fd.get('bio') || '').trim() || null,
            p_experience_summary:String(fd.get('experience') || '').trim() || null,
            p_visibility_status:String(fd.get('visibility') || 'visible'),
            p_idempotency_key:idk('teacher-profile')
          },
          successRoute:'teaching-option-edit',
          postRole:'teacher',
          clearTeachingOption:true
        },'teaching-option-edit','Profile saved — now add what you teach');
        return;
      }

      if (form.id === 'live-option-form' && options.length === 0 && !live.selected.teachingOptionId) {
        e.preventDefault();
        e.stopImmediatePropagation();
        const fd = new FormData(form);
        const locationIds = [...form.querySelectorAll('input[name="locations"]:checked')].map(x=>x.value);
        if (!locationIds.length) {
          api.toast('Choose at least one Location','danger');
          return;
        }
        await runSensitiveAction({
          rpc:'publish_teaching_option',
          params:{
            p_organization_id:null,
            p_title:String(fd.get('title') || '').trim(),
            p_category:String(fd.get('category') || '').trim() || null,
            p_description:String(fd.get('description') || '').trim() || null,
            p_teaching_mode:String(fd.get('mode') || ''),
            p_area_or_venue_text:String(fd.get('area') || '').trim() || null,
            p_fee_display_text:String(fd.get('fee') || '').trim() || null,
            p_location_ids:locationIds,
            p_idempotency_key:idk('first-teaching-option')
          },
          successRoute:'teacher-home',
          postRole:'teacher'
        },'teacher-home','Your teaching setup is ready');
      }
    }, true);

    document.addEventListener('click', async e => {
      const t = e.target.closest?.('[data-live-first-use-intent],[data-live-enable-teaching],[data-live-confirm-enquiry],[data-live-engage-enquiry],[data-live-send-enquiry-message],[data-live-fix-activate-class],[data-live-fix-open-invite],[data-live-fix-accept-invite],[data-live-fix-end-management],[data-live-fix-confirm-end-management],[data-live-fix-send-phone-otp],[data-live-fix-verify-phone],[data-live-fix-resume-action],[data-live-fix-logout],[data-live-fix-open-trial-notification],[data-live-fix-open-class-session-notification],[data-live-fix-open-class-post-notification],[data-live-fix-open-class-lifecycle-notification],[data-live-fix-open-activity-submission-notification],[data-live-fix-open-test-correction-notification],[data-live-fix-open-organization-authority-notification]');
      if (!t) return;
      e.preventDefault(); e.stopImmediatePropagation();
      try {
        if (t.dataset.liveFirstUseIntent && firstUsePending()) {
          const destination = {
            learner:'learner-setup',
            parent:'learner-add',
            teacher:'teacher-setup',
            institute:'institute-setup',
            explore:'home'
          }[t.dataset.liveFirstUseIntent];
          if (!destination) throw new Error('Choose a valid Raahi starting path.');
          t.disabled = true;
          try {
            await rpc('complete_first_use_onboarding',{ p_idempotency_key:idk('first-use') });
            live.context = await rpc('get_my_account_context');
            api.go(destination);
          } finally {
            if (t.isConnected) t.disabled = false;
          }
          return;
        }
        if (t.hasAttribute('data-live-enable-teaching')) {
          await runSensitiveAction({
            rpc:'enable_teaching',
            params:{p_idempotency_key:idk('enable-teaching')},
            successRoute:'teacher-profile-edit',
            postRole:'teacher'
          },'teacher-profile-edit','Teaching setup started');
          return;
        }
        if (t.hasAttribute('data-live-confirm-enquiry')) {
          const teachingOptionId = t.dataset.liveConfirmEnquiry;
          const learner = selectedLearner();
          const message = document.querySelector('#live-enquiry-opening')?.value || null;
          document.querySelector('.modal-backdrop')?.remove();
          if (!learner) throw new Error('Select an authorized learner.');
          try {
            const result = await rpc('send_enquiry',{
              p_learner_id:learner.learner_id,
              p_teaching_option_id:teachingOptionId,
              p_location_id:selectedLocationId(),
              p_opening_message:message,
              p_idempotency_key:idk('enquiry')
            });
            live.selected.enquiryId = result?.enquiry_id || null;
            live.routeLoads.clear();
            await refreshCoreState();
            await refreshCurrentEnquiryThread();
            api.toast('Enquiry sent','success');
            api.go('enquiry');
            return;
          } catch (err) {
            if (!/DUPLICATE_ACTIVE_ENQUIRY/i.test(errorText(err))) throw err;
            await refreshCoreState();
            const existing = arr(live.data.enquiries).find(x => x.state === 'active' && x.learner_id === learner.learner_id && x.teaching_option_id === teachingOptionId);
            if (!existing) throw err;
            live.selected.enquiryId = existing.enquiry_id;
            live.routeLoads.clear();
            await refreshCurrentEnquiryThread();
            api.toast('You already have an active enquiry here. Opening it.','info');
            api.go('enquiry');
            return;
          }
        }
        if (t.hasAttribute('data-live-engage-enquiry')) {
          if (!live.selected.enquiryId) throw new Error('No Enquiry is selected.');
          await rpc('engage_enquiry',{p_enquiry_id:live.selected.enquiryId,p_idempotency_key:idk('engage')});
          live.routeLoads.clear();
          await refreshCoreState();
          await refreshCurrentEnquiryThread();
          api.toast('Enquiry engaged','success');
          api.render();
          return;
        }
        if (t.hasAttribute('data-live-send-enquiry-message')) {
          if (!live.selected.enquiryId) throw new Error('No Enquiry is selected.');
          const body = document.querySelector('#live-enquiry-message')?.value?.trim();
          if (!body) throw new Error('Write a message.');
          await rpc('send_enquiry_message',{p_enquiry_id:live.selected.enquiryId,p_body:body,p_idempotency_key:idk('enquiry-message')});
          live.routeLoads.clear();
          await refreshCoreState();
          await refreshCurrentEnquiryThread();
          api.toast('Message sent','success');
          api.render();
          return;
        }
        if (t.hasAttribute('data-live-fix-activate-class')) {
          const classId = live.selected.classId || live.data.classManagement?.class?.class_id || null;
          if (!classId) throw new Error('No Class is selected.');
          await rpc('activate_class',{p_class_id:classId,p_idempotency_key:idk('activate-class')});
          live.routeLoads.clear();
          await refreshCoreState();
          await refreshCurrentClassManagement();
          api.toast('Class activated','success');
          api.render();
          return;
        }
        if (t.dataset.liveFixOpenInvite) {
          live.selected.invitationId = t.dataset.liveFixOpenInvite;
          api.go('invitation');
          return;
        }
        if (t.dataset.liveFixOpenTrialNotification) {
          const n = arr(live.data.notifications).find(x => (x.notification_id || x.id) === t.dataset.liveFixOpenTrialNotification);
          const enquiryId = n?.payload?.enquiry_id || null;
          if (!enquiryId) throw new Error('Trial notification no longer has a valid Enquiry destination.');
          live.selected.enquiryId = enquiryId;
          live.routeLoads.clear();
          api.go('trial');
          return;
        }
        if (t.dataset.liveFixOpenClassSessionNotification) {
          const n = arr(live.data.notifications).find(x => (x.notification_id || x.id) === t.dataset.liveFixOpenClassSessionNotification);
          const classId = n?.payload?.class_id || null;
          if (!classId) throw new Error('Class Session notification no longer has a valid Class destination.');
          live.selected.classId = classId;
          live.routeLoads.clear();
          api.go('class-detail');
          return;
        }
        if (t.dataset.liveFixOpenClassPostNotification) {
          const n = arr(live.data.notifications).find(x => (x.notification_id || x.id) === t.dataset.liveFixOpenClassPostNotification);
          const classId = n?.payload?.class_id || null;
          if (!classId) throw new Error('Class post notification no longer has a valid Class destination.');
          live.selected.classId = classId;
          live.routeLoads.clear();
          const providerRole = ['teacher','institute'].includes(api.state.role);
          api.go(providerRole ? 'teacher-class' : 'class-detail');
          return;
        }
        if (t.dataset.liveFixOpenClassLifecycleNotification) {
          const n = arr(live.data.notifications).find(x => (x.notification_id || x.id) === t.dataset.liveFixOpenClassLifecycleNotification);
          const type = n?.notification_type || '';
          const p = n?.payload || {};
          if (p.learner_id) live.selected.learnerId = p.learner_id;
          live.routeLoads.clear();
          if (type === 'class_membership_removed') {
            api.go('classes');
            return;
          }
          const classId = type === 'class_membership_transferred' ? p.destination_class_id : p.class_id;
          if (!classId) throw new Error('Class lifecycle notification no longer has a valid Class destination.');
          live.selected.classId = classId;
          const providerRole = ['teacher','institute'].includes(api.state.role);
          api.go(providerRole ? 'teacher-class' : 'class-detail');
          return;
        }
        if (t.dataset.liveFixOpenActivitySubmissionNotification) {
          const n = arr(live.data.notifications).find(x => (x.notification_id || x.id) === t.dataset.liveFixOpenActivitySubmissionNotification);
          const type = n?.notification_type || '';
          const p = n?.payload || {};
          const classId = p.class_id || null;
          const activityId = p.activity_id || null;
          const learnerId = p.learner_id || null;
          if (!classId || !activityId || !learnerId) throw new Error('Activity notification no longer has a valid authorized destination.');
          live.selected.classId = classId;
          live.selected.learnerId = learnerId;
          live.selected.activityId = activityId;
          live.selected.enquiryId = null;
          live.selected.testId = null;
          live.selected.teachingOptionId = null;
          live.selected.communityPostId = null;
          live.selected.adCampaignId = null;
          live.routeLoads.clear();
          if (type === 'activity_submission_received') {
            live.data.activity = await rpc('get_activity_detail',{ p_activity_id:activityId, p_learner_id:learnerId });
            const loc = live.context?.selected_location?.location_id || arr(live.data.locations).find(x => x.state === 'live')?.location_id || '';
            const key = ['submission-review',classId,learnerId,'',activityId,'','','','',loc].join('|');
            live.routeLoads.set(key,'done');
            api.go('submission-review');
          } else {
            api.go('activity');
          }
          return;
        }
        if (t.dataset.liveFixOpenTestCorrectionNotification) {
          const n = arr(live.data.notifications).find(x => (x.notification_id || x.id) === t.dataset.liveFixOpenTestCorrectionNotification);
          const p = n?.payload || {};
          const testId = p.test_id || null;
          const classId = p.class_id || null;
          if (!testId || !classId) throw new Error('Test correction notification no longer has a valid authorized destination.');
          live.selected.testId = testId;
          live.selected.classId = classId;
          live.routeLoads.clear();
          api.go('test-results');
          return;
        }
        if (t.dataset.liveFixOpenOrganizationAuthorityNotification) {
          const n = arr(live.data.notifications).find(x => (x.notification_id || x.id) === t.dataset.liveFixOpenOrganizationAuthorityNotification);
          const organizationId = n?.payload?.organization_id || null;
          if (!organizationId) throw new Error('Organization notification no longer has a valid destination.');

          // The notification is only a hint. Refresh the current Account projection and make
          // the destination RPC recheck membership/capability before showing any workspace.
          await refreshCoreState();
          const organization = arr(live.context?.organizations).find(x => x.organization_id === organizationId);
          const currentlyAuthorized = arr(organization?.capabilities).some(code => String(code).startsWith('manage_'));
          if (!organization || !currentlyAuthorized) {
            live.selected.organizationId = null;
            live.data.orgWorkspace = null;
            live.routeLoads.clear();
            api.state.role = 'learner';
            api.toast('Organization access is no longer available.','warning');
            api.go('home');
            return;
          }

          try {
            live.data.orgWorkspace = await rpc('get_organization_workspace',{ p_organization_id:organizationId });
          } catch (_) {
            live.selected.organizationId = null;
            live.data.orgWorkspace = null;
            live.routeLoads.clear();
            api.state.role = 'learner';
            api.toast('Organization access is no longer available.','warning');
            api.go('home');
            return;
          }
          live.selected.organizationId = organizationId;
          live.routeLoads.clear();
          api.state.role = 'institute';
          api.go('org-home');
          return;
        }
        if (t.dataset.liveFixAcceptInvite) {
          const invitationId = t.dataset.liveFixAcceptInvite;
          await runSensitiveAction({ rpc:'accept_class_invitation', params:{ p_invitation_id:invitationId, p_idempotency_key:idk('accept-invite') }, successRoute:'join-success' }, 'join-success', 'Class joined');
          return;
        }
        if (t.dataset.liveFixEndManagement) {
          api.modal('End learner management?', '<div class="notice warning">Raahi will allow this only if the learner will still have another valid way to access or manage their learning. Existing learning history is not deleted.</div>', `<button class="pill-btn" data-modal-close>Cancel</button><button class="danger-btn" data-live-fix-confirm-end-management="${h(t.dataset.liveFixEndManagement)}">End my management</button>`);
          return;
        }
        if (t.dataset.liveFixConfirmEndManagement) {
          document.querySelector('.modal-backdrop')?.remove();
          await rpc('end_learner_access',{ p_access_id:t.dataset.liveFixConfirmEndManagement, p_idempotency_key:idk('end-management') });
          await refreshCoreState();
          if (api.state.role === 'parent' && !currentLearners().some(x=>x.access_type === 'manage')) api.state.role = currentLearners().some(x=>x.access_type === 'self') ? 'learner' : api.state.role;
          live.selected.learnerId = currentLearners().find(x=>x.access_type === 'self')?.learner_id || currentLearners()[0]?.learner_id || null;
          api.toast('Learner management ended','success');
          api.go('home');
          return;
        }
        if (t.hasAttribute('data-live-fix-send-phone-otp')) { await sendPhoneOtp(); return; }
        if (t.hasAttribute('data-live-fix-verify-phone')) { await verifyPhoneOtp(); return; }
        if (t.hasAttribute('data-live-fix-logout')) { await signOutCurrentDevice(); return; }
        if (t.hasAttribute('data-live-fix-resume-action')) {
          const pending = loadPendingAction();
          if (pending) {
            await executePendingAction(pending);
            api.toast('Action completed','success');
            api.go(pending.successRoute || 'classes');
          } else api.go('settings');
        }
      } catch (err) { api.toast(errorText(err),'danger'); }
    }, true);

    live.afterRender = function(route, coreApi) {
      originalAfterRender(route, coreApi);

      if (live.session && live.context) {
        const unread = arr(live.data.notifications).filter(n => !n.read_at).length;
        const top = document.querySelector('.top-actions');
        if (top && !top.querySelector('[data-live-fix-notifications-link]')) {
          const link = document.createElement('a');
          link.className = 'pill-btn';
          link.href = '#/notifications';
          link.dataset.liveFixNotificationsLink = 'true';
          link.setAttribute('aria-label', unread ? `Notifications, ${unread} unread` : 'Notifications');
          link.textContent = unread ? `Notifications ${unread}` : 'Notifications';
          top.prepend(link);
        }
      }

      if (route === 'teacher-class' && live.data.classManagement?.class?.state === 'draft') {
        const actions = document.querySelector('.main .page-actions');
        if (actions && !actions.querySelector('[data-live-fix-activate-class]')) {
          const button = document.createElement('button');
          button.className = 'primary-btn';
          button.dataset.liveFixActivateClass = 'true';
          button.textContent = 'Activate Class';
          actions.prepend(button);
        }
      }

      const localManagerScope = arr(live.context?.manager_scopes)[0] || null;
      if (localManagerScope && coreApi.state.role === 'manager') {
        const locationButton = document.querySelector('.top-actions [data-route="location-picker"]');
        if (locationButton) {
          const label = locationButton.querySelector('.label');
          if (label) label.textContent = localManagerScope.location_name;
          locationButton.removeAttribute('data-route');
          locationButton.disabled = true;
          locationButton.setAttribute('aria-label', `Local operations are scoped to ${localManagerScope.location_name}`);
          locationButton.title = `Local operations are scoped to ${localManagerScope.location_name}`;
        }
      }

      if (route === 'phone-check' || route === 'otp') {
        if (live.__phoneTrustV13?.state === 'fresh' && loadPendingAction()) setTimeout(() => {}, 0);
      }
      if (route === 'teacher-home') {
        const heading = document.querySelector('.main h1');
        if (heading) heading.style.fontSize = window.innerWidth <= 720 ? '28px' : '36px';
      }
      if (route === 'notifications') {
        const cards = [...document.querySelectorAll('.main .stack > .card')];
        arr(live.data.notifications).forEach((n, index) => {
          const type = n.notification_type || '';
          const card = cards[index];
          const row = card?.querySelector('.row');
          if (!row || row.querySelector('[data-live-notification-open],[data-live-fix-open-trial-notification],[data-live-fix-open-class-session-notification],[data-live-fix-open-class-post-notification],[data-live-fix-open-class-lifecycle-notification],[data-live-fix-open-activity-submission-notification],[data-live-fix-open-test-correction-notification],[data-live-fix-open-organization-authority-notification]')) return;
          if (/^trial_(scheduled|rescheduled|cancelled)$/.test(type)) {
            const button = document.createElement('button');
            button.className = 'primary-btn small';
            button.textContent = 'Open';
            button.dataset.liveFixOpenTrialNotification = n.notification_id || n.id;
            row.prepend(button);
          } else if (/^class_session_(scheduled|cancelled)$/.test(type)) {
            const button = document.createElement('button');
            button.className = 'primary-btn small';
            button.textContent = 'Open';
            button.dataset.liveFixOpenClassSessionNotification = n.notification_id || n.id;
            row.prepend(button);
          } else if (/^(class_announcement|class_question)$/.test(type)) {
            const button = document.createElement('button');
            button.className = 'primary-btn small';
            button.textContent = 'Open';
            button.dataset.liveFixOpenClassPostNotification = n.notification_id || n.id;
            row.prepend(button);
          } else if (/^(class_membership_left|class_membership_removed|class_membership_transferred|class_completed)$/.test(type)) {
            const button = document.createElement('button');
            button.className = 'primary-btn small';
            button.textContent = 'Open';
            button.dataset.liveFixOpenClassLifecycleNotification = n.notification_id || n.id;
            row.prepend(button);
          } else if (/^activity_submission_(received|reviewed|changes_requested)$/.test(type)) {
            const button = document.createElement('button');
            button.className = 'primary-btn small';
            button.textContent = 'Open';
            button.dataset.liveFixOpenActivitySubmissionNotification = n.notification_id || n.id;
            row.prepend(button);
          } else if (type === 'test_results_corrected') {
            const button = document.createElement('button');
            button.className = 'primary-btn small';
            button.textContent = 'Open';
            button.dataset.liveFixOpenTestCorrectionNotification = n.notification_id || n.id;
            row.prepend(button);
          } else if (/^organization_(access_changed|membership_removed)$/.test(type)) {
            const button = document.createElement('button');
            button.className = 'primary-btn small';
            button.textContent = 'Open';
            button.dataset.liveFixOpenOrganizationAuthorityNotification = n.notification_id || n.id;
            row.prepend(button);
          }
        });
      }
      if (route === 'learners' || route === 'org-members') {
        document.querySelectorAll('.main .card .between').forEach(el => {
          el.style.flexWrap = 'wrap';
          el.style.gap = '12px';
        });
        document.querySelectorAll('.main .card .row').forEach(el => {
          el.style.flexWrap = 'wrap';
          el.style.gap = '8px';
          el.style.maxWidth = '100%';
        });
      }
      if (['manager-home','manager-people','manager-learning','platform-home','platform-safety','platform-ads','platform-audit'].includes(route)) {
        document.querySelectorAll('.main').forEach(el => {
          el.style.minWidth = '0';
          el.style.maxWidth = '100%';
        });
        document.querySelectorAll('.main .card, .main .notice').forEach(el => {
          el.style.maxWidth = '100%';
          el.style.minWidth = '0';
          el.style.boxSizing = 'border-box';
          el.style.overflow = 'hidden';
        });
        document.querySelectorAll('.main .notice code').forEach(el => {
          el.style.display = 'block';
          el.style.width = '100%';
          el.style.maxWidth = '100%';
          el.style.whiteSpace = 'pre-wrap';
          el.style.overflowWrap = 'anywhere';
          el.style.wordBreak = 'break-word';
        });
      }
    };

    api.render();
  }, 50);
})();
