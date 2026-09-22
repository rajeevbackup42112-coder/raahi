(() => {
  'use strict';

  const wait = setInterval(() => {
    const live = window.RaahiLearningLive;
    const api = window.RaahiLearningCore;
    if (!live || !api || !live.client || !live.renderRoute) return;
    clearInterval(wait);
    if (live.__adminManagementV14E) return;
    live.__adminManagementV14E = true;

    const originalRenderRoute = live.renderRoute.bind(live);
    const originalAfterRender = live.afterRender?.bind(live);
    const h = api.escapeHtml;
    const arr = v => Array.isArray(v) ? v : (v == null ? [] : [v]);
    const idk = prefix => `${prefix}-${crypto.randomUUID()}`;
    const state = { rows: null, loading: false, resolved: null, targetLocation: null };

    const isPlatform = () =>
      arr(live.context?.capabilities).includes('platform_admin') &&
      api.state.role === 'platform';

    async function rpc(name, params = {}) {
      const { data, error } = await live.client.rpc(name, params);
      if (error) throw error;
      return data;
    }

    function denied() {
      return api.layout(`${api.pageHead('Location Admins','Manage city-scoped Local Managers.')}
        <div class="card empty"><h3>Platform Admin required</h3>
        <p>This page changes administrative authority and is available only in the authorized Global Platform Admin workspace.</p></div>`);
    }

    function managerCard(manager, locationName) {
      return `<div class="notice between" style="gap:12px">
        <div><strong>${h(manager.display_name || 'Raahi Account')}</strong>
        <div class="tiny muted">${h(manager.email || '')}</div></div>
        <button class="pill-btn small" data-admin-end="${h(manager.assignment_id)}"
          data-admin-location="${h(locationName || 'Location')}">Remove access</button>
      </div>`;
    }

    function locationCard(row) {
      const managers = arr(row.local_managers);
      return `<div class="card">
        <div class="between" style="gap:12px">
          <div><div class="tiny muted">${h(row.location_state || '')}</div>
          <h3>${h(row.location_name || 'Location')}</h3>
          <div class="tiny muted">${h(row.location_slug || '')}</div></div>
          <button class="primary-btn small" data-admin-start-assign="${h(row.location_id)}"
            data-admin-location-name="${h(row.location_name || 'Location')}">Assign Local Admin</button>
        </div>
        <div class="section stack">
          ${managers.length ? managers.map(m => managerCard(m, row.location_name)).join('')
            : '<div class="notice">No active Local Manager assigned.</div>'}
        </div>
      </div>`;
    }

    function page() {
      if (!live.session || !live.context || !isPlatform()) return denied();
      if (state.rows === null) {
        return api.layout(`${api.pageHead('Location Admins','Manage city-scoped administrative authority.')}
          <div class="card empty"><h3>Loading Location admins…</h3></div>`);
      }
      return api.layout(`${api.pageHead('Location Admins','Assign or remove city-scoped Local Managers without Supabase SQL.')}
        <div class="card"><div class="notice"><strong>Global vs local authority</strong><br>
          Local Managers operate only their assigned Location. This screen never grants Global Platform Admin.
        </div></div>
        <div class="section stack">
          ${state.rows.length ? state.rows.map(locationCard).join('')
            : '<div class="card empty"><h3>No Locations available</h3></div>'}
        </div>`);
    }

    async function loadRows() {
      if (state.loading) return;
      state.loading = true;
      try {
        state.rows = arr(await rpc('get_platform_location_admins'));
      } catch (err) {
        state.rows = [];
        api.toast(err?.message || err?.details || 'Could not load Location admins','danger');
      } finally {
        state.loading = false;
        api.render();
      }
    }

    function openAssign(locationId, locationName) {
      state.targetLocation = { locationId, locationName };
      state.resolved = null;
      api.modal(
        `Assign Local Admin · ${h(locationName)}`,
        `<div class="notice">Enter the exact Google email of an existing Raahi Account. If the person has never signed in to Raahi, ask them to sign in once and retry.</div>
         <div class="field"><label>Google email</label>
         <input id="admin-email-input" type="email" autocomplete="off" maxlength="320" placeholder="name@gmail.com"></div>
         <div id="admin-email-result"></div>`,
        '<button class="pill-btn" data-modal-close>Cancel</button><button class="primary-btn" data-admin-resolve>Find Account</button>'
      );
    }

    function showResolved(result) {
      const el = document.querySelector('#admin-email-result');
      if (!el) return;
      if (!result?.found) {
        el.innerHTML = '<div class="notice">No active Raahi Account found for that email. Ask the person to sign in to Raahi once, then retry.</div>';
        return;
      }
      const scopes = arr(result.manager_locations);
      const alreadyHere = scopes.some(x => x.location_id === state.targetLocation?.locationId);
      const globalCopy = result.is_platform_admin
        ? '<div class="notice">This Account is already a Global Platform Admin and does not need Local Manager authority.</div>'
        : '';
      el.innerHTML = `<div class="notice"><strong>${h(result.display_name || 'Raahi Account')}</strong><br>
          <span class="tiny">${h(result.email || '')}</span>
          ${scopes.length
            ? `<div class="tiny muted" style="margin-top:8px">Current Local Manager scope: ${scopes.map(x => h(x.location_name)).join(', ')}</div>`
            : '<div class="tiny muted" style="margin-top:8px">No current Local Manager scope.</div>'}
        </div>${globalCopy}
        ${result.is_platform_admin ? ''
          : alreadyHere ? '<div class="notice success">Already an active Local Manager for this Location.</div>'
          : `<button class="primary-btn wide" data-admin-confirm-assign>Assign to ${h(state.targetLocation?.locationName || 'Location')}</button>`}`;
    }

    api.routeMeta['location-admins'] = 'Location Admins';
    const platformNav = api.roleNav?.platform;
    if (Array.isArray(platformNav) && !platformNav.some(x => x?.[0] === 'location-admins')) {
      const locationIndex = platformNav.findIndex(x => x?.[0] === 'manager-location');
      platformNav.splice(locationIndex >= 0 ? locationIndex + 1 : platformNav.length, 0, ['location-admins','♙','Location Admins']);
    }

    live.renderRoute = function(route, coreApi) {
      if (route === 'location-admins') return page();
      return originalRenderRoute(route, coreApi);
    };

    live.afterRender = function(route, coreApi) {
      originalAfterRender?.(route, coreApi);
      if (route === 'location-admins' && live.session && live.context && isPlatform() && state.rows === null) loadRows();
    };

    document.addEventListener('click', async e => {
      const target = e.target.closest?.(
        '[data-admin-start-assign],[data-admin-resolve],[data-admin-confirm-assign],[data-admin-end],[data-admin-confirm-end]'
      );
      if (!target) return;
      e.preventDefault();
      e.stopImmediatePropagation();
      try {
        if (target.matches('[data-admin-start-assign]')) {
          openAssign(target.dataset.adminStartAssign, target.dataset.adminLocationName || 'Location');
          return;
        }
        if (target.matches('[data-admin-resolve]')) {
          const email = document.querySelector('#admin-email-input')?.value?.trim();
          if (!email) throw new Error('Enter the exact Google email.');
          state.resolved = await rpc('resolve_platform_account_email',{ p_email: email });
          showResolved(state.resolved);
          return;
        }
        if (target.matches('[data-admin-confirm-assign]')) {
          if (!state.resolved?.found || !state.targetLocation?.locationId) throw new Error('Resolve an Account first.');
          if (state.resolved.is_platform_admin) throw new Error('Global Platform Admin does not need Local Manager authority.');
          await rpc('assign_local_manager',{
            p_location_id: state.targetLocation.locationId,
            p_target_account_id: state.resolved.account_id,
            p_idempotency_key: idk('assign-local-manager')
          });
          document.querySelector('.modal-backdrop')?.remove();
          state.rows = null;
          state.resolved = null;
          state.targetLocation = null;
          api.toast('Local Admin assigned','success');
          api.render();
          return;
        }
        if (target.matches('[data-admin-end]')) {
          api.modal(
            `Remove Local Admin access · ${h(target.dataset.adminLocation || 'Location')}`,
            '<div class="field"><label>Reason</label><textarea id="admin-end-reason" maxlength="500" placeholder="Why is this access being removed?"></textarea></div>',
            `<button class="pill-btn" data-modal-close>Cancel</button><button class="primary-btn" data-admin-confirm-end="${h(target.dataset.adminEnd)}">Remove access</button>`
          );
          return;
        }
        if (target.matches('[data-admin-confirm-end]')) {
          const reason = document.querySelector('#admin-end-reason')?.value?.trim();
          if (!reason) throw new Error('Enter a reason.');
          await rpc('end_location_staff_assignment',{
            p_assignment_id: target.dataset.adminConfirmEnd,
            p_reason: reason,
            p_idempotency_key: idk('end-local-manager')
          });
          document.querySelector('.modal-backdrop')?.remove();
          state.rows = null;
          api.toast('Local Admin access removed','success');
          api.render();
        }
      } catch (err) {
        api.toast(err?.message || err?.details || 'Admin action failed','danger');
      }
    }, true);
  }, 30);
})();
