(() => {
  'use strict';

  const PARAM = 'raahi_location';
  const PENDING_KEY = 'raahi.learning.myraahi-location-handoff.v1';
  const MAX_RPC_ATTEMPTS = 5;

  const normalizeSlug = value => {
    const slug = String(value || '').trim().toLowerCase();
    return /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(slug) && slug.length <= 120 ? slug : null;
  };

  const readPending = () => {
    try {
      const value = JSON.parse(sessionStorage.getItem(PENDING_KEY) || 'null');
      const slug = normalizeSlug(value?.slug);
      const idempotencyKey = typeof value?.idempotencyKey === 'string' && value.idempotencyKey
        ? value.idempotencyKey
        : null;
      const attempts = Number.isInteger(value?.attempts) ? value.attempts : 0;
      return slug && idempotencyKey ? { slug, idempotencyKey, attempts } : null;
    } catch (_) {
      return null;
    }
  };

  const savePending = pending => {
    sessionStorage.setItem(PENDING_KEY, JSON.stringify(pending));
  };

  const clearPending = () => {
    sessionStorage.removeItem(PENDING_KEY);
  };

  const captureLocationHint = () => {
    const url = new URL(window.location.href);
    if (!url.searchParams.has(PARAM)) return readPending();

    const slug = normalizeSlug(url.searchParams.get(PARAM));
    url.searchParams.delete(PARAM);
    history.replaceState(history.state, '', url.pathname + url.search + url.hash);

    if (!slug) {
      clearPending();
      return null;
    }

    const existing = readPending();
    const pending = existing?.slug === slug
      ? existing
      : {
          slug,
          idempotencyKey: `myraahi-location-${slug}-${crypto.randomUUID()}`,
          attempts: 0
        };

    savePending(pending);
    return pending;
  };

  let pending = captureLocationHint();
  let inFlight = false;

  const setDebugState = state => {
    const live = window.RaahiLearningLive;
    if (live) live.__myraahiLocationHandoffV1 = state;
  };

  const finish = state => {
    clearPending();
    pending = null;
    setDebugState(state);
  };

  const wait = setInterval(async () => {
    if (!pending || inFlight) return;

    const live = window.RaahiLearningLive;
    const api = window.RaahiLearningCore;
    if (!live || !api || !live.client) return;

    // Preserve the hint across Google OAuth / bootstrap. Apply only after Learn
    // has a real authenticated Account context and its canonical Location list.
    if (!live.session || !live.context?.account) return;

    const locations = Array.isArray(live.data?.locations) ? live.data.locations : [];
    if (!locations.length) return;

    const target = locations.find(location =>
      normalizeSlug(location?.slug) === pending.slug
    );

    if (!target) {
      finish({ status: 'ignored', reason: 'LOCATION_NOT_FOUND', slug: pending.slug });
      api.toast?.('That Raahi location is not available in Learn.', 'warning');
      return;
    }

    if (target.state !== 'live') {
      finish({ status: 'ignored', reason: 'LOCATION_NOT_LIVE', slug: pending.slug });
      api.toast?.('Learn is not currently available in that location.', 'warning');
      return;
    }

    if (normalizeSlug(live.context?.selected_location?.slug) === pending.slug) {
      finish({ status: 'already_selected', slug: pending.slug });
      return;
    }

    const locationId = target.location_id || target.id || null;
    if (!locationId) {
      finish({ status: 'ignored', reason: 'LOCATION_ID_MISSING', slug: pending.slug });
      return;
    }

    inFlight = true;
    try {
      const { data, error } = await live.client.rpc('set_selected_location', {
        p_location_id: locationId,
        p_idempotency_key: pending.idempotencyKey
      });
      if (error) throw error;

      const contextResult = await live.client.rpc('get_my_account_context');
      if (contextResult.error) throw contextResult.error;
      live.context = contextResult.data;
      live.routeLoads?.clear?.();

      finish({
        status: 'applied',
        slug: pending.slug,
        changed: data?.changed !== false
      });

      api.render?.();
    } catch (error) {
      pending.attempts += 1;
      savePending(pending);
      setDebugState({
        status: 'retrying',
        slug: pending.slug,
        attempts: pending.attempts
      });

      if (pending.attempts >= MAX_RPC_ATTEMPTS) {
        setDebugState({
          status: 'failed',
          slug: pending.slug,
          attempts: pending.attempts
        });
        api.toast?.('Raahi could not switch Learn to that location right now. You can choose it from Learn.', 'warning');
        clearInterval(wait);
      }
    } finally {
      inFlight = false;
    }
  }, 400);

  window.addEventListener('pagehide', () => clearInterval(wait), { once: true });
})();
