(() => {
  'use strict';

  const wait = setInterval(() => {
    const live = window.RaahiLearningLive;
    const api = window.RaahiLearningCore;
    if (!live || !api || !live.client) return;
    clearInterval(wait);
    if (live.__threadDeepLinkV13) return;
    live.__threadDeepLinkV13 = true;

    const originalRenderRoute = live.renderRoute.bind(live);
    const originalAfterRender = live.afterRender?.bind(live);
    const h = api.escapeHtml;
    const arr = v => Array.isArray(v) ? v : (v == null ? [] : [v]);
    let threadLoad = { key: null, status: 'idle', data: null, error: null };
    let threadGeneration = 0;
    const actorKey = () => `${live.session?.user?.id || ''}|${live.context?.account?.account_id || ''}`;
    function invalidateThread() {
      threadGeneration++;
      threadLoad = { key: null, status: 'idle', data: null, error: null };
      live.data.classThread = null;
    }
    live.__setClassThreadDataV13 = (classId, learnerId, data) => {
      if (!classId || !learnerId || !data) return false;
      threadGeneration++;
      const key = `${actorKey()}|${classId}|${learnerId}`;
      threadLoad = { key, status: 'done', data, error: null };
      live.data.classThread = data;
      return true;
    };
    // Never retain private conversation data across authentication events.
    live.client.auth.onAuthStateChange(() => {
      invalidateThread();
      setTimeout(() => api.render(), 0);
    });

    async function rpc(name, params={}) {
      const { data, error } = await live.client.rpc(name, params);
      if (error) throw error;
      return data;
    }

    function errorText(e) {
      return e?.message || e?.details || e?.hint || String(e || 'Access unavailable');
    }

    function hashContext() {
      const raw = String(location.hash || '').replace(/^#\//, '');
      const qIndex = raw.indexOf('?');
      const route = qIndex >= 0 ? raw.slice(0, qIndex) : raw;
      const qs = qIndex >= 0 ? raw.slice(qIndex + 1) : '';
      const params = new URLSearchParams(qs);
      return {
        route,
        classId: params.get('class_id'),
        learnerId: params.get('learner_id')
      };
    }

    function safeDeniedPage() {
      return api.layout(`${api.pageHead('Class message','Protected Class conversation')}<div class="card empty"><div class="empty-icon">↪</div><h3>Class conversation unavailable</h3><p>This Account does not currently have access to this Class conversation. Raahi rechecks authorization every time a Class link is opened.</p><button class="pill-btn" data-route="home">Back to Home</button></div>`);
    }

    function loadingPage() {
      return api.layout(`${api.pageHead('Class message','Checking current Class access…')}<div class="card"><p class="muted">Raahi is rechecking your current Class and Learner relationship.</p></div>`);
    }

    function renderThread(t) {
      return api.layout(`${api.pageHead(h(t.class_title || 'Class message'),`Private Class + ${h(t.learner_name || 'Learner')} thread`)}<div class="card"><div class="stack">${arr(t.messages).map(m=>`<div class="notice"><strong>${h(m.sender_name || '')}</strong><p>${h(m.body || '')}</p><span class="tiny muted">${m.created_at ? h(new Date(m.created_at).toLocaleString()) : ''}</span></div>`).join('') || '<p class="muted">No messages yet.</p>'}</div><div class="divider"></div><div class="field"><label>Message</label><textarea id="live-class-message"></textarea></div><button class="primary-btn" data-live-send-class-message>Send message</button></div>`);
    }

    function ensureThreadLoad(classId, learnerId, coreApi) {
      const key = `${actorKey()}|${classId}|${learnerId}`;
      if (threadLoad.key === key && ['loading','done','error'].includes(threadLoad.status)) return;
      const generation = ++threadGeneration;
      threadLoad = { key, status: 'loading', data: null, error: null };
      setTimeout(async () => {
        try {
          const data = await rpc('get_class_learner_thread', {
            p_class_id: classId,
            p_learner_id: learnerId
          });
          if (generation !== threadGeneration || threadLoad.key !== key) return;
          threadLoad = { key, status: 'done', data, error: null };
          live.data.classThread = data;
        } catch (e) {
          if (generation !== threadGeneration || threadLoad.key !== key) return;
          threadLoad = { key, status: 'error', data: null, error: errorText(e) };
          live.data.classThread = null;
        } finally {
          if (generation === threadGeneration) coreApi.render();
        }
      }, 0);
    }

    live.renderRoute = function(route, coreApi) {
      if ((route !== 'class-thread' || !live.session || !live.context) && threadLoad.key !== null) invalidateThread();
      if (route === 'class-thread' && live.session && live.context) {
        const ctx = hashContext();
        const classId = ctx.classId || live.selected.classId;
        const learnerId = ctx.learnerId || live.selected.learnerId;
        if (classId && learnerId) {
          live.selected.classId = classId;
          live.selected.learnerId = learnerId;
          ensureThreadLoad(classId, learnerId, coreApi);
          const key = `${actorKey()}|${classId}|${learnerId}`;
          if (threadLoad.key !== key || threadLoad.status === 'loading') return loadingPage();
          if (threadLoad.status === 'error') return safeDeniedPage();
          if (threadLoad.status === 'done' && threadLoad.data) return renderThread(threadLoad.data);
        }
      }
      return originalRenderRoute(route, coreApi);
    };

    live.afterRender = function(route, coreApi) {
      originalAfterRender?.(route, coreApi);
      if (route === 'class-thread' && live.selected.classId && live.selected.learnerId) {
        const desired = `#/class-thread?class_id=${encodeURIComponent(live.selected.classId)}&learner_id=${encodeURIComponent(live.selected.learnerId)}`;
        if (location.hash !== desired) {
          history.replaceState({}, '', `${location.pathname}${location.search}${desired}`);
        }
      }
    };

    document.addEventListener('click', e => {
      if (!e.target.closest?.('[data-live-send-class-message]')) return;
      const key = threadLoad.key;
      setTimeout(() => {
        if (threadLoad.key === key) invalidateThread();
        api.render();
      }, 900);
    }, true);
  }, 25);
})();
