(() => {
  'use strict';

  // Raahi Learning V1.4B market activation slice 1.
  // Raahi Desk publishes truthful platform-editorial Community content through
  // a canonical server command. It never fabricates user identities or engagement.

  const wait = setInterval(() => {
    const live = window.RaahiLearningLive;
    const api = window.RaahiLearningCore;
    if (!live || !api || !live.client || !live.renderRoute) return;
    clearInterval(wait);
    if (live.__marketActivationV14B) return;
    live.__marketActivationV14B = true;

    const originalRenderRoute = live.renderRoute.bind(live);
    const originalAfterRender = live.afterRender?.bind(live);
    const h = api.escapeHtml;
    const arr = v => Array.isArray(v) ? v : (v == null ? [] : [v]);
    const idk = prefix => `${prefix}-${crypto.randomUUID()}`;

    async function rpc(name, params = {}) {
      const { data, error } = await live.client.rpc(name, params);
      if (error) throw error;
      return data;
    }

    const managerScopes = () => arr(live.context?.manager_scopes)
      .filter(x => x.staff_type === 'local_manager' && x.location_state === 'live');
    const isGlobalOperator = () => arr(live.context?.capabilities).includes('platform_admin');
    const isMarketActivationRole = () => ['platform','manager'].includes(api.state.role);

    const browseSelectedLocation = () => live.context?.selected_location
      || arr(live.data?.locations).find(x => x.location_id === live.context?.selected_location_id)
      || null;
    const browseSelectedLocationId = () => browseSelectedLocation()?.location_id || browseSelectedLocation()?.id || null;
    const canOperateLocation = locationId => Boolean(locationId) && (
      isGlobalOperator()
      || managerScopes().some(x => x.location_id === locationId)
    );

    const selectedLocation = () => {
      const browse = browseSelectedLocation();
      const browseId = browse?.location_id || browse?.id || null;
      if (browse && canOperateLocation(browseId)) return browse;
      if (!isGlobalOperator()) {
        const scope = managerScopes()[0];
        if (!scope) return null;
        return arr(live.data?.locations).find(x => (x.location_id || x.id) === scope.location_id)
          || { location_id: scope.location_id, name: scope.location_name, state: scope.location_state };
      }
      return browse
        || arr(live.data?.locations).find(x => x.state === 'live')
        || null;
    };

    const selectedLocationId = () => selectedLocation()?.location_id || selectedLocation()?.id || null;
    const selectedLocationName = () => selectedLocation()?.name || 'selected Location';

    function operatorDenied() {
      return api.layout(`${api.pageHead('Raahi Desk','Platform-authored local learning content.')}
        <div class="card empty">
          <h3>Market activation access required</h3>
          <p>Raahi Desk is available only to the global Platform Admin or a Local Manager inside that manager's assigned Location.</p>
        </div>`);
    }

    function pageRaahiDesk() {
      if (!live.session || !live.context || !isMarketActivationRole()) return operatorDenied();
      const loc = selectedLocation();
      if (!loc) {
        return api.layout(`${api.pageHead('Raahi Desk','Platform-authored local learning content.')}
          <div class="card empty"><h3>Choose a live Location first</h3>
          <p>Raahi Desk content is always tied to one real live Location.</p>
          <button class="primary-btn" data-route="location-picker">Choose Location</button></div>`);
      }
      return api.layout(`${api.pageHead('Raahi Desk',`Publish useful local guidance as Raahi — never as a fictional user.`)}
        <div class="card">
          <div class="between">
            <div><div class="tiny muted">Publishing to</div><h3>${h(selectedLocationName())}</h3></div>
            ${isGlobalOperator() ? '<button class="pill-btn small" data-route="location-picker">Change Location</button>' : ''}
          </div>
          <div class="notice" style="margin-top:12px">
            This post will be publicly attributed to <strong>Raahi Desk</strong> and marked <strong>Platform-authored</strong>.
            Raahi Desk does not create fake students, teachers, requests, comments, reactions or popularity.
          </div>
        </div>
        <div class="section card form-card">
          <form id="raahi-desk-form">
            <div class="field"><label>Post type</label>
              <select name="type">
                <option value="question">Question</option>
                <option value="resource">Resource</option>
                <option value="event">Event / opportunity</option>
                <option value="update">Update</option>
                <option value="discussion">Discussion</option>
              </select>
            </div>
            <div class="field"><label>Post</label>
              <textarea name="body" required maxlength="12000" placeholder="Share a useful local learning question, guide, opportunity or update."></textarea>
            </div>
            <div class="field"><label>Optional external link</label>
              <input name="url" type="url" placeholder="https://">
            </div>
            <button class="primary-btn" type="submit">Publish as Raahi Desk</button>
          </form>
        </div>`);
    }

    api.routeMeta['raahi-desk'] = 'Raahi Desk';
    for (const role of ['platform','manager']) {
      const nav = api.roleNav?.[role];
      if (Array.isArray(nav) && !nav.some(x => x?.[0] === 'raahi-desk')) {
        const communityIndex = nav.findIndex(x => x?.[0] === 'community');
        nav.splice(communityIndex >= 0 ? communityIndex : 1, 0, ['raahi-desk','✦','Raahi Desk']);
      }
    }

    live.renderRoute = function(route, coreApi) {
      if (route === 'raahi-desk') return pageRaahiDesk();
      return originalRenderRoute(route, coreApi);
    };

    function editorialPostById(postId) {
      return arr(live.data?.community).find(p => p.post_id === postId && p.provenance_kind === 'platform_editorial') || null;
    }

    function polishEditorialContent(route) {
      if (route === 'community') {
        if (isMarketActivationRole() && canOperateLocation(browseSelectedLocationId())) {
          const normalNewPost = document.querySelector('[data-route="community-new"]');
          if (normalNewPost) {
            normalNewPost.dataset.route = 'raahi-desk';
            normalNewPost.textContent = 'New Raahi Desk post';
          }
        }
        for (const menu of document.querySelectorAll('[data-live-community-menu]')) {
          const post = editorialPostById(menu.dataset.liveCommunityMenu);
          if (!post) continue;
          const card = menu.closest('.card');
          if (!card) continue;
          card.dataset.raahiDesk = 'true';
          const author = card.querySelector('.between strong');
          if (author && !card.querySelector('[data-raahi-desk-badge]')) {
            const badge = document.createElement('span');
            badge.dataset.raahiDeskBadge = 'true';
            badge.className = 'badge info';
            badge.textContent = post.attribution_label || 'Platform-authored';
            badge.style.marginLeft = '8px';
            author.insertAdjacentElement('afterend', badge);
          }
          menu.setAttribute('aria-label','Raahi Desk post options');
        }
      }

      if (route === 'community-post' && live.data?.communityPost?.provenance_kind === 'platform_editorial') {
        const mainCard = document.querySelector('.main-content .card');
        if (mainCard && !mainCard.querySelector('[data-raahi-desk-detail]')) {
          const notice = document.createElement('div');
          notice.dataset.raahiDeskDetail = 'true';
          notice.className = 'notice';
          notice.innerHTML = '<strong>Raahi Desk · Platform-authored</strong><br>This post is published by Raahi as local learning guidance, not by a fictional community member.';
          mainCard.prepend(notice);
        }
      }
    }

    live.afterRender = function(route, coreApi) {
      originalAfterRender?.(route, coreApi);
      polishEditorialContent(route);
    };

    document.addEventListener('click', e => {
      const menu = e.target.closest?.('[data-live-community-menu]');
      if (!menu) return;
      const post = editorialPostById(menu.dataset.liveCommunityMenu);
      if (!post) return;
      e.preventDefault();
      e.stopImmediatePropagation();
      api.modal(
        'Raahi Desk post',
        `<div class="stack">
          <div class="notice"><strong>Platform-authored</strong><br>This content is published by Raahi Desk, not by a fictional local user.</div>
          <button class="pill-btn" data-live-report-community="${h(post.post_id)}">Report post</button>
        </div>`,
        '<button class="pill-btn" data-modal-close>Close</button>'
      );
    }, true);

    document.addEventListener('submit', async e => {
      const form = e.target;
      if (!(form instanceof HTMLFormElement) || form.id !== 'raahi-desk-form') return;
      e.preventDefault();
      e.stopImmediatePropagation();

      if (!isMarketActivationRole()) {
        api.toast('Market activation access required','danger');
        return;
      }

      const locationId = selectedLocationId();
      if (!locationId || !canOperateLocation(locationId)) {
        api.toast('This Location is outside your market-activation scope','danger');
        return;
      }

      const fd = new FormData(form);
      const body = String(fd.get('body') || '').trim();
      const type = String(fd.get('type') || 'update');
      const url = String(fd.get('url') || '').trim() || null;
      if (!body) {
        api.toast('Write the Raahi Desk post first','danger');
        return;
      }

      const submit = form.querySelector('button[type="submit"]');
      if (submit) submit.disabled = true;
      try {
        await rpc('publish_raahi_desk_post', {
          p_location_id: locationId,
          p_post_type: type,
          p_body: body,
          p_external_url: url,
          p_idempotency_key: idk('raahi-desk')
        });
        live.data.community = arr(await rpc('discover_community_posts', {
          p_location_id: locationId,
          p_limit: 50
        }));
        live.routeLoads?.clear?.();
        api.toast('Published as Raahi Desk','success');
        api.go('community');
      } catch (err) {
        api.toast(err?.message || err?.details || 'Could not publish Raahi Desk post','danger');
      } finally {
        if (submit) submit.disabled = false;
      }
    }, true);
  }, 30);
})();
