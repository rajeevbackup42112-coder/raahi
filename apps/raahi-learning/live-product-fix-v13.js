(() => {
  'use strict';

  // V1.3 exact-build combined regression anchor — workspace + cohort; no business-rule change.
  const PENDING_ACTION_KEY = 'raahi.learning.pending-trust-action.v13';
  const PHONE_FLOW_KEY = 'raahi.learning.phone-flow.v13';

  const wait = setInterval(() => {
    const live = window.RaahiLearningLive;
    const api = window.RaahiLearningCore;
    if (!live || !api || !live.client) return;
    clearInterval(wait);
    if (live.__productFixV13) return;
    live.__productFixV13 = true;

    const originalRenderRoute = live.renderRoute.bind(live);
    const originalRightbarHtml = live.rightbarHtml.bind(live);
    const originalAfterRender = live.afterRender.bind(live);
    const h = api.escapeHtml;
    const badge = api.badge;
    const arr = v => Array.isArray(v) ? v : (v == null ? [] : [v]);
    const idk = prefix => `${prefix}-${crypto.randomUUID()}`;
    const currentLearners = () => arr(live.context?.learners);
    const selectedLearner = () => currentLearners().find(x => x.learner_id === live.selected.learnerId) || currentLearners()[0] || null;
    const errorText = e => e?.message || e?.details || e?.hint || String(e || 'Unknown error');
    const isPhoneGate = e => /PHONE_TRUST_REQUIRED/i.test(errorText(e));
    const selectedLocationName = () => live.context?.selected_location?.name || arr(live.data.locations).find(x => x.state === 'live')?.name || 'Choose location';
    const replaceFirstPageTitle = (html, title) => String(html || '').replace(/<h1>[\s\S]*?<\/h1>/, `<h1>${h(title)}</h1>`);

    async function rpc(name, params={}) {
      const { data, error } = await live.client.rpc(name, params);
      if (error) throw error;
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
      return api.layout(`${api.pageHead('My Classes','Current relationship-scoped Classes and pending invitations.')}${invHtml}<div class="section"><div class="section-title"><h2>Classes</h2></div><div class="stack">${classHtml}</div></div>`);
    }

    function pageInvitation() {
      const inv = currentPendingInvitation();
      if (!inv) return api.layout(api.pageHead('Class Invitation','Pending invitations reserve capacity until expiry or resolution.') + api.empty('No pending invitation','There is no current invitation for this learner.'));
      return api.layout(`${api.pageHead(h(inv.class_title),`${h(inv.provider_name)} · for ${h(inv.learner_name)}`)}<div class="card"><div class="between">${badge(inv.display_state || inv.state,'warning')}<span>Expires ${h(new Date(inv.expires_at).toLocaleString())}</span></div><p>Fee: ${h(inv.fee_display_text || 'Not specified')}</p><div class="notice">Accepting creates the Membership only after Raahi rechecks current authority, invitation state and reserved capacity.</div><div class="row" style="margin-top:14px"><button class="primary-btn" data-live-fix-accept-invite="${inv.invitation_id}">Accept & join</button><button class="pill-btn" data-live-decline-invite>Decline</button></div></div>`);
    }

    function pageLearners() {
      const learners = currentLearners();
      return api.layout(`${api.pageHead('Learning profiles','Manage only the learner relationships this Account currently owns.','<button class="primary-btn" data-route="learner-add">Add learner</button>')}<div class="stack">${learners.map(l => `<div class="card"><div class="between"><div><h3>${h(l.display_name)}</h3><p class="card-sub">${h(l.access_type === 'self' ? 'Self learning access' : 'Managed by this Account')}</p></div><div class="row">${l.access_type === 'manage' ? `<button class="pill-btn small" data-live-enable-self="${l.learner_id}">Set up learner login</button><button class="pill-btn small" data-live-share-learner="${l.learner_id}">Private Class code</button><button class="danger-btn small" data-live-fix-end-management="${l.access_id}">End my management</button>` : ''}</div></div>${l.access_type === 'manage' ? '<p class="tiny muted">Ending management succeeds only if another valid learner-side access path already exists. The server rechecks this invariant.</p>' : ''}</div>`).join('') || api.empty('No learner profiles','Add your own learning profile or a learner you manage.')}</div>`);
    }

    function pagePhoneCheck() {
      const trust = live.__phoneTrustV13;
      if (!trust) return `<div class="auth-shell"><div class="auth-card"><div class="eyebrow">Phone trust check</div><h1>Checking your phone trust…</h1><p class="muted">Raahi is reading the current server-verified trust state.</p></div></div>`;
      if (trust.state === 'fresh') return `<div class="auth-shell"><div class="auth-card"><div class="eyebrow">Phone trust</div><h1>Phone confirmed</h1><p class="muted">Your current phone trust is fresh.</p><button class="primary-btn wide" data-live-fix-resume-action>Continue</button></div></div>`;
      const hasPhone = !!trust.has_phone;
      return `<div class="auth-shell"><div class="auth-card"><div class="eyebrow">Quick phone check</div><h1>${hasPhone ? 'Confirm you still have this phone' : 'Add a phone for trust-sensitive actions'}</h1><p class="muted">This is not a second login and does not change your Raahi roles or learner authority.</p>${hasPhone ? `<div class="notice">Current phone: ${h(trust.masked_phone || '')}</div>` : '<div class="field"><label>Phone in E.164 format</label><input id="live-fix-phone" inputmode="tel" placeholder="+91…"></div>'}<button class="primary-btn wide" data-live-fix-send-phone-otp>${hasPhone ? 'Send confirmation code' : 'Send phone code'}</button><div class="divider"></div><div class="field"><label>Verification code</label><input id="live-fix-phone-otp" inputmode="numeric" autocomplete="one-time-code"></div><button class="pill-btn wide" data-live-fix-verify-phone>Verify & continue</button><button class="ghost-btn wide" data-route="settings">Cancel</button></div></div>`;
    }

    const originalRender = live.renderRoute;
    live.renderRoute = function(route, coreApi) {
      if (live.session && live.context) {
        if (route === 'classes' && ['learner','student','parent'].includes(coreApi.state.role)) return pageClasses();
        if (route === 'invitation') return pageInvitation();
        if (route === 'learners') return pageLearners();
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
      if (route === 'manager-home') {
        return replaceFirstPageTitle(rendered, `${selectedLocationName()} Overview`);
      }
      if (route === 'ads-eligibility') {
        return replaceFirstPageTitle(rendered, 'Advertising eligibility');
      }
      if (route === 'ads-inventory') {
        return replaceFirstPageTitle(rendered, 'Ads Inventory');
      }
      return rendered;
    };

    live.rightbarHtml = function(coreApi) {
      const base = originalRightbarHtml(coreApi);
      if (live.context && ['learner','student','parent'].includes(coreApi.state.role)) return `${base}<div class="card"><div class="tiny muted">Learning access</div><p class="text-sm">Manage your learner relationships through normal Raahi controls.</p><a class="pill-btn small" href="#/learners">Manage learning profiles</a></div>`;
      return base;
    };

    async function executePendingAction(action) {
      if (!action) return false;
      const result = await rpc(action.rpc, action.params);
      clearPendingAction();
      await refreshCoreState();
      return result;
    }

    async function runSensitiveAction(action, successRoute, successText) {
      try {
        await executePendingAction(action);
        api.toast(successText,'success');
        if (successRoute) api.go(successRoute); else api.render();
      } catch (e) {
        if (isPhoneGate(e)) {
          savePendingAction(action);
          live.__phoneTrustV13 = null;
          api.go('phone-check');
        } else api.toast(errorText(e),'danger');
      }
    }

    async function sendPhoneOtp() {
      const trust = live.__phoneTrustV13 || await rpc('get_my_phone_trust');
      if (trust.has_phone) {
        const { data: userData, error: userError } = await live.client.auth.getUser();
        if (userError) throw userError;
        const phone = userData.user?.phone;
        if (!phone) throw new Error('Confirmed phone is unavailable in Auth.');
        const e164 = phone.startsWith('+') ? phone : `+${phone}`;
        const { error } = await live.client.auth.signInWithOtp({ phone: e164, options: { shouldCreateUser: false } });
        if (error) throw error;
        sessionStorage.setItem(PHONE_FLOW_KEY, JSON.stringify({ phone:e164, type:'sms' }));
      } else {
        const phone = document.querySelector('#live-fix-phone')?.value?.trim();
        if (!/^\+[1-9]\d{7,14}$/.test(phone || '')) throw new Error('Enter a valid E.164 phone number including + and country code.');
        const { error } = await live.client.auth.updateUser({ phone });
        if (error) throw error;
        sessionStorage.setItem(PHONE_FLOW_KEY, JSON.stringify({ phone, type:'phone_change' }));
      }
      api.toast('Verification code sent','success');
    }

    async function verifyPhoneOtp() {
      const token = document.querySelector('#live-fix-phone-otp')?.value?.trim();
      if (!token) throw new Error('Enter the verification code.');
      const flow = JSON.parse(sessionStorage.getItem(PHONE_FLOW_KEY) || 'null');
      if (!flow?.phone || !flow?.type) throw new Error('Send a verification code first.');
      const { error } = await live.client.auth.verifyOtp({ phone: flow.phone, token, type: flow.type });
      if (error) throw error;
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

    document.addEventListener('click', async e => {
      const t = e.target.closest?.('[data-live-fix-open-invite],[data-live-fix-accept-invite],[data-live-fix-end-management],[data-live-fix-confirm-end-management],[data-live-fix-send-phone-otp],[data-live-fix-verify-phone],[data-live-fix-resume-action],[data-live-fix-open-trial-notification],[data-live-fix-open-class-session-notification],[data-live-fix-open-class-post-notification],[data-live-fix-open-class-lifecycle-notification],[data-live-fix-open-activity-submission-notification],[data-live-fix-open-test-correction-notification]');
      if (!t) return;
      e.preventDefault(); e.stopImmediatePropagation();
      try {
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
        if (t.dataset.liveFixAcceptInvite) {
          const invitationId = t.dataset.liveFixAcceptInvite;
          await runSensitiveAction({ rpc:'accept_class_invitation', params:{ p_invitation_id:invitationId, p_idempotency_key:idk('accept-invite') }, successRoute:'join-success' }, 'join-success', 'Class joined');
          return;
        }
        if (t.dataset.liveFixEndManagement) {
          api.modal('End learner management?', '<div class="notice warning">Raahi will allow this only if another valid learner-side access path already exists. Existing learning history is not deleted.</div>', `<button class="pill-btn" data-modal-close>Cancel</button><button class="danger-btn" data-live-fix-confirm-end-management="${h(t.dataset.liveFixEndManagement)}">End my management</button>`);
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
          if (!row || row.querySelector('[data-live-notification-open],[data-live-fix-open-trial-notification],[data-live-fix-open-class-session-notification],[data-live-fix-open-class-post-notification],[data-live-fix-open-class-lifecycle-notification],[data-live-fix-open-activity-submission-notification],[data-live-fix-open-test-correction-notification]')) return;
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
