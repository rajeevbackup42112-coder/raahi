(() => {
  'use strict';

  // Raahi Learning V1.4C Founding Supply walking skeleton.
  // A real Teacher asks for help, Raahi prepares a private draft, and only the
  // same authenticated Teacher may accept before canonical public supply exists.

  const wait = setInterval(() => {
    const live = window.RaahiLearningLive;
    const api = window.RaahiLearningCore;
    if (!live || !api || !live.client || !live.renderRoute) return;
    clearInterval(wait);
    if (live.__foundingSupplyV14C) return;
    live.__foundingSupplyV14C = true;

    const originalRenderRoute = live.renderRoute.bind(live);
    const originalAfterRender = live.afterRender?.bind(live);
    const h = api.escapeHtml;
    const arr = v => Array.isArray(v) ? v : (v == null ? [] : [v]);
    const idk = prefix => `${prefix}-${crypto.randomUUID()}`;

    const state = {
      my: null,
      platform: null,
      myLoading: false,
      platformLoading: false,
      selectedRequestId: null
    };

    async function rpc(name, params = {}) {
      const { data, error } = await live.client.rpc(name, params);
      if (error) throw error;
      return data;
    }

    const locations = () => arr(live.data?.locations);
    const managerScopes = () => arr(live.context?.manager_scopes)
      .filter(x => x.staff_type === 'local_manager' && x.location_state === 'live');
    const isGlobalOperator = () => arr(live.context?.capabilities).includes('platform_admin');
    const isMarketActivationRole = () => ['platform','manager'].includes(api.state.role);

    const selectedLocation = () => live.context?.selected_location
      || locations().find(x => x.location_id === live.context?.selected_location_id)
      || locations().find(x => x.state === 'live')
      || null;
    const selectedLocationId = () => selectedLocation()?.location_id || selectedLocation()?.id || null;
    const selectedLocationName = () => selectedLocation()?.name || 'selected Location';
    const currentRequest = () => arr(state.my)[0] || null;

    function selfServiceTeacherSetup() {
      return `<div class="auth-shell"><div class="auth-card wide-card">
        <div class="eyebrow">Start teaching</div>
        <h1>Set up your teaching presence</h1>
        <p class="muted">Set it up yourself, or ask Raahi to prepare a private draft for you. You stay in control of what becomes public.</p>
        <div class="state-grid">
          <div class="state-card"><strong>1 · About you</strong><span>Add a short introduction and your teaching experience</span></div>
          <div class="state-card"><strong>2 · What you teach</strong><span>Subject, level and your first learning option</span></div>
          <div class="state-card"><strong>3 · Where and how</strong><span>Location, online or in person, and fee information</span></div>
          <div class="state-card"><strong>4 · Review and publish</strong><span>Check the details before anything becomes public</span></div>
        </div>
        <div class="section stack">
          <button class="primary-btn wide" data-live-enable-teaching>Set it up myself</button>
          <button class="pill-btn wide" data-route="founding-supply-help">Ask Raahi to help</button>
        </div>
        <button class="ghost-btn wide" data-route="onboarding-intent">Back</button>
      </div></div>`;
    }

    function proposalSummary(r) {
      return `<div class="stack">
        <div class="notice"><strong>About you</strong><br>${h(r.proposed_headline || '')}</div>
        ${r.proposed_bio ? `<div><div class="tiny muted">Bio</div><p>${h(r.proposed_bio)}</p></div>` : ''}
        ${r.proposed_experience_summary ? `<div><div class="tiny muted">Experience</div><p>${h(r.proposed_experience_summary)}</p></div>` : ''}
        <div class="notice"><strong>First teaching option</strong><br>${h(r.proposed_option_title || '')}
          ${r.proposed_option_category ? ` · ${h(r.proposed_option_category)}` : ''}
          <br><span class="muted">${h(r.proposed_teaching_mode || '')} · ${h(r.founding_location_name || '')}</span>
        </div>
        ${r.proposed_option_description ? `<div><div class="tiny muted">What you offer</div><p>${h(r.proposed_option_description)}</p></div>` : ''}
        ${r.proposed_area_or_venue_text ? `<div><div class="tiny muted">Area / venue</div><p>${h(r.proposed_area_or_venue_text)}</p></div>` : ''}
        ${r.proposed_fee_display_text ? `<div><div class="tiny muted">Fee display</div><p>${h(r.proposed_fee_display_text)}</p></div>` : ''}
      </div>`;
    }

    function pageTeacherHelp() {
      if (!live.session || !live.context) return originalRenderRoute('welcome', api);
      if (state.my === null) {
        return api.layout(`${api.pageHead('Teacher setup help','Private assisted onboarding with your approval.')}
          <div class="card empty"><h3>Loading your setup request…</h3></div>`);
      }

      const r = currentRequest();
      if (!r || ['declined','cancelled','withdrawn'].includes(r.state)) {
        return api.layout(`${api.pageHead('Teacher setup help','Raahi can prepare your first teaching draft for you to review.')}
          <div class="card">
            <h3>You stay in control</h3>
            <p>Raahi can prepare a private draft using the details you share with us. It will not appear in Explore until you sign in and publish the exact draft yourself.</p>
            <div class="notice">Founding Location: <strong>${h(selectedLocationName())}</strong></div>
            <div class="section row">
              <button class="primary-btn" data-founding-request-help>Ask Raahi to help</button>
              <button class="pill-btn" data-route="teacher-setup">Set it up myself</button>
            </div>
          </div>`);
      }

      if (r.state === 'requested') {
        return api.layout(`${api.pageHead('Teacher setup help','Your request is private. Nothing is public yet.')}
          <div class="card">
            <h3>Raahi is preparing your draft</h3>
            <p>We will prepare a proposed profile and first teaching option for ${h(r.founding_location_name || selectedLocationName())}. You will see every public detail before deciding.</p>
            <div class="notice">No Teacher Profile or Teaching Option has been published from this request.</div>
            <button class="pill-btn" data-founding-cancel="${h(r.request_id)}">Cancel request</button>
          </div>`);
      }

      if (r.state === 'draft_ready') {
        return api.layout(`${api.pageHead('Review your teaching draft','Nothing is public until you choose Publish these details.')}
          <div class="card">
            ${proposalSummary(r)}
            <div class="notice" style="margin-top:16px">
              By choosing <strong>Publish these details</strong>, you confirm that the information above is accurate and can be shown publicly as your Teacher Profile and first teaching option.
            </div>
            <div class="section row">
              <button class="primary-btn" data-founding-accept="${h(r.request_id)}">Publish these details</button>
              <button class="pill-btn" data-founding-decline="${h(r.request_id)}">Decline</button>
              <button class="ghost-btn" data-founding-cancel="${h(r.request_id)}">Cancel request</button>
            </div>
          </div>`);
      }

      if (r.state === 'accepted') {
        return api.layout(`${api.pageHead('Teacher setup published','You approved this assisted setup.')}
          <div class="card"><div class="notice success">Your Teacher Profile and first teaching option are now live. You can edit them anytime from your Teacher workspace.</div>
          <button class="primary-btn" data-founding-open-teacher>Open Teacher workspace</button></div>`);
      }

      return api.layout(`${api.pageHead('Teacher setup help','Assisted onboarding')}
        <div class="card"><p>Status: <strong>${h(r.state || 'unknown')}</strong></p></div>`);
    }

    function operatorDenied() {
      return api.layout(`${api.pageHead('Founding Supply','Genuine Teacher-assisted onboarding.')}
        <div class="card empty"><h3>Market activation access required</h3>
        <p>Founding Supply is available only to the global Platform Admin or a Local Manager for that manager's assigned Location.</p></div>`);
    }

    function platformRequestCard(r) {
      const selected = state.selectedRequestId === r.request_id;
      return `<div class="card">
        <div class="between">
          <div>
            <div class="tiny muted">${h(r.founding_location_name || '')}</div>
            <h3>${h(r.teacher_display_name || 'Teacher Account')}</h3>
            <p class="muted">${h(r.state || '')}</p>
          </div>
          ${r.state === 'requested' ? `<button class="primary-btn small" data-founding-prepare="${h(r.request_id)}">Prepare draft</button>` : ''}
        </div>
        ${r.state === 'draft_ready' ? `<div class="notice">Waiting for the Teacher to review the exact draft.</div>
          <button class="pill-btn small" data-founding-withdraw="${h(r.request_id)}">Withdraw</button>` : ''}
        ${selected ? foundingDraftForm(r) : ''}
      </div>`;
    }

    function foundingDraftForm(r) {
      return `<div class="section"><div class="divider"></div>
        <form id="founding-supply-draft-form" data-request-id="${h(r.request_id)}">
          <div class="notice">This form prepares a <strong>private draft only</strong>. It cannot publish for the Teacher.</div>
          <div class="field"><label>Teacher headline</label><input name="headline" maxlength="240" required></div>
          <div class="field"><label>Bio</label><textarea name="bio" maxlength="5000"></textarea></div>
          <div class="field"><label>Experience summary</label><textarea name="experience" maxlength="2000"></textarea></div>
          <div class="field"><label>First teaching option title</label><input name="title" maxlength="200" required></div>
          <div class="field"><label>Category</label><input name="category" maxlength="120"></div>
          <div class="field"><label>Description</label><textarea name="description" maxlength="5000"></textarea></div>
          <div class="field"><label>Teaching mode</label><select name="mode"><option value="in_person">In person</option><option value="online">Online</option><option value="both">Both</option></select></div>
          <div class="field"><label>Area / venue</label><input name="area" maxlength="500"></div>
          <div class="field"><label>Fee display</label><input name="fee" maxlength="500" placeholder="Contact for details"></div>
          <button class="primary-btn" type="submit">Send private draft for Teacher review</button>
        </form>
      </div>`;
    }

    function pagePlatformFoundingSupply() {
      if (!live.session || !live.context || !isMarketActivationRole()) return operatorDenied();
      if (state.platform === null) {
        return api.layout(`${api.pageHead('Founding Supply','Genuine Teacher-assisted onboarding.')}
          <div class="card empty"><h3>Loading genuine requests…</h3></div>`);
      }
      const active = arr(state.platform).filter(x => ['requested','draft_ready'].includes(x.state));
      const scopeCopy = isGlobalOperator()
        ? 'You can operate genuine requests across live Locations.'
        : `You can operate only your assigned Location${managerScopes().length === 1 ? `: <strong>${h(managerScopes()[0].location_name || '')}</strong>` : 's'}.`;
      return api.layout(`${api.pageHead('Founding Supply','Teachers asked for help first. Raahi prepares; the Teacher publishes.')}
        <div class="card"><div class="notice"><strong>No silent onboarding.</strong> Only Accounts that explicitly requested assistance appear in this queue. Drafts remain private until the Teacher accepts.<br>${scopeCopy}</div></div>
        <div class="section stack">
          ${active.length ? active.map(platformRequestCard).join('') : '<div class="card empty"><h3>No active Teacher assistance requests</h3><p>Nothing is manufactured to fill this queue.</p></div>'}
        </div>`);
    }

    api.routeMeta['founding-supply-help'] = 'Teacher Setup Help';
    api.routeMeta['founding-supply'] = 'Founding Supply';
    for (const role of ['platform','manager']) {
      const nav = api.roleNav?.[role];
      if (Array.isArray(nav) && !nav.some(x => x?.[0] === 'founding-supply')) {
        const deskIndex = nav.findIndex(x => x?.[0] === 'raahi-desk');
        nav.splice(deskIndex >= 0 ? deskIndex + 1 : 1, 0, ['founding-supply','♧','Founding Supply']);
      }
    }

    live.renderRoute = function(route, coreApi) {
      if (route === 'teacher-setup') return selfServiceTeacherSetup();
      if (route === 'founding-supply-help') return pageTeacherHelp();
      if (route === 'founding-supply') return pagePlatformFoundingSupply();
      return originalRenderRoute(route, coreApi);
    };

    async function loadMine() {
      if (state.myLoading) return;
      state.myLoading = true;
      try {
        state.my = arr(await rpc('get_my_assisted_teacher_onboarding'));
      } catch (err) {
        state.my = [];
        api.toast(err?.message || 'Could not load setup help','danger');
      } finally {
        state.myLoading = false;
        api.render();
      }
    }

    async function loadPlatform() {
      if (state.platformLoading) return;
      state.platformLoading = true;
      try {
        state.platform = arr(await rpc('get_platform_assisted_teacher_onboarding',{p_state:null}));
      } catch (err) {
        state.platform = [];
        api.toast(err?.message || 'Could not load Founding Supply queue','danger');
      } finally {
        state.platformLoading = false;
        api.render();
      }
    }

    live.afterRender = function(route, coreApi) {
      originalAfterRender?.(route, coreApi);
      if (route === 'founding-supply-help' && live.session && live.context && state.my === null) loadMine();
      if (route === 'founding-supply' && live.session && live.context && isMarketActivationRole() && state.platform === null) loadPlatform();
    };

    document.addEventListener('click', async e => {
      const target = e.target.closest?.(
        '[data-founding-request-help],[data-founding-cancel],[data-founding-accept],[data-founding-decline],[data-founding-prepare],[data-founding-withdraw],[data-founding-confirm-withdraw],[data-founding-open-teacher]'
      );
      if (!target) return;
      e.preventDefault();
      e.stopImmediatePropagation();

      try {
        if (target.matches('[data-founding-request-help]')) {
          const locationId = selectedLocationId();
          if (!locationId) throw new Error('Choose a live Location first.');
          await rpc('request_assisted_teacher_onboarding',{
            p_location_id:locationId,
            p_idempotency_key:idk('founding-request')
          });
          state.my = null;
          api.toast('Setup help requested','success');
          api.render();
          return;
        }

        if (target.matches('[data-founding-cancel]')) {
          await rpc('cancel_assisted_teacher_onboarding',{
            p_request_id:target.dataset.foundingCancel,
            p_idempotency_key:idk('founding-cancel')
          });
          state.my = null;
          api.toast('Setup request cancelled','success');
          api.render();
          return;
        }

        if (target.matches('[data-founding-decline]')) {
          await rpc('decline_assisted_teacher_onboarding',{
            p_request_id:target.dataset.foundingDecline,
            p_idempotency_key:idk('founding-decline')
          });
          state.my = null;
          api.toast('Draft declined','success');
          api.render();
          return;
        }

        if (target.matches('[data-founding-accept]')) {
          const action={
            rpc:'accept_assisted_teacher_onboarding',
            params:{
              p_request_id:target.dataset.foundingAccept,
              p_idempotency_key:idk('founding-accept')
            },
            successRoute:'teacher-home',
            postRole:'teacher'
          };
          if (typeof live.runSensitiveActionV13 === 'function') {
            state.my = null;
            await live.runSensitiveActionV13(action,'teacher-home','Your teaching details are now published');
          } else {
            await rpc(action.rpc,action.params);
            api.toast('Your teaching details are now published','success');
            window.location.hash = '#/teacher-home';
            window.location.reload();
          }
          return;
        }

        if (target.matches('[data-founding-open-teacher]')) {
          window.location.hash = '#/teacher-home';
          window.location.reload();
          return;
        }

        if (target.matches('[data-founding-prepare]')) {
          state.selectedRequestId = target.dataset.foundingPrepare;
          api.render();
          return;
        }

        if (target.matches('[data-founding-withdraw]')) {
          const requestId = target.dataset.foundingWithdraw;
          api.modal(
            'Withdraw assisted onboarding',
            '<div class="field"><label>Reason</label><textarea id="founding-withdraw-reason" maxlength="500" required></textarea></div><p class="tiny muted">Withdrawing publishes nothing.</p>',
            `<button class="pill-btn" data-modal-close>Cancel</button><button class="primary-btn" data-founding-confirm-withdraw="${h(requestId)}">Withdraw</button>`
          );
          return;
        }

        if (target.matches('[data-founding-confirm-withdraw]')) {
          const reason = document.querySelector('#founding-withdraw-reason')?.value?.trim();
          if (!reason) throw new Error('Enter a withdrawal reason.');
          document.querySelector('.modal-backdrop')?.remove();
          await rpc('withdraw_assisted_teacher_onboarding',{
            p_request_id:target.dataset.foundingConfirmWithdraw,
            p_reason:reason,
            p_idempotency_key:idk('founding-withdraw')
          });
          state.platform = null;
          state.selectedRequestId = null;
          api.toast('Assisted onboarding withdrawn','success');
          api.render();
        }
      } catch (err) {
        api.toast(err?.message || err?.details || 'Founding Supply action failed','danger');
      }
    }, true);

    document.addEventListener('submit', async e => {
      const form = e.target;
      if (!(form instanceof HTMLFormElement) || form.id !== 'founding-supply-draft-form') return;
      e.preventDefault();
      e.stopImmediatePropagation();

      const fd = new FormData(form);
      const submit = form.querySelector('button[type="submit"]');
      if (submit) submit.disabled = true;
      try {
        await rpc('prepare_assisted_teacher_onboarding',{
          p_request_id:form.dataset.requestId,
          p_headline:String(fd.get('headline') || '').trim(),
          p_bio:String(fd.get('bio') || '').trim() || null,
          p_experience_summary:String(fd.get('experience') || '').trim() || null,
          p_option_title:String(fd.get('title') || '').trim(),
          p_option_category:String(fd.get('category') || '').trim() || null,
          p_option_description:String(fd.get('description') || '').trim() || null,
          p_teaching_mode:String(fd.get('mode') || ''),
          p_area_or_venue_text:String(fd.get('area') || '').trim() || null,
          p_fee_display_text:String(fd.get('fee') || '').trim() || null,
          p_idempotency_key:idk('founding-prepare')
        });
        state.platform = null;
        state.selectedRequestId = null;
        api.toast('Private draft sent for Teacher review','success');
        api.render();
      } catch (err) {
        api.toast(err?.message || err?.details || 'Could not prepare draft','danger');
      } finally {
        if (submit) submit.disabled = false;
      }
    }, true);
  }, 30);
})();
