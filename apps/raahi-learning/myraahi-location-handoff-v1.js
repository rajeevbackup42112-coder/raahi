(() => {
  'use strict';

  const PARAM = 'raahi_location';
  const STORAGE_KEY = 'raahi.learning.pending-myraahi-location.v1';
  const MARKER = '__RAAHI_MYRAAHI_LOCATION_HANDOFF_V1__';

  if (window[MARKER]) return;
  window[MARKER] = true;

  const validSlug = value => /^[a-z0-9][a-z0-9-]{0,62}$/.test(value || '');
  const normalizeSlug = value => String(value || '').trim().toLowerCase();

  function readPending() {
    try {
      const raw = sessionStorage.getItem(STORAGE_KEY);
      if (!raw) return null;
      const value = JSON.parse(raw);
      if (!validSlug(value?.slug) || typeof value?.idempotencyKey !== 'string' || !value.idempotencyKey) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  function clearPending() {
    try { sessionStorage.removeItem(STORAGE_KEY); } catch (_) {}
  }

  function captureIncomingLocation() {
    const url = new URL(location.href);
    if (!url.searchParams.has(PARAM)) return;
    const slug = normalizeSlug(url.searchParams.get(PARAM));
    if (validSlug(slug)) {
      const current = readPending();
      const idempotencyKey = current?.slug === slug
        ? current.idempotencyKey
        : `myraahi-location-${crypto.randomUUID()}`;
      try {
        sessionStorage.setItem(STORAGE_KEY, JSON.stringify({ slug, idempotencyKey }));
      } catch (_) {}
    } else {
      clearPending();
    }
    url.searchParams.delete(PARAM);
    const clean = url.pathname + (url.search || '') + (url.hash || '');
    try { history.replaceState({}, '', clean); } catch (_) {}
  }

  captureIncomingLocation();

  let applying = false;
  let timer = null;

  async function applyPendingLocation() {
    const pending = readPending();
    if (!pending) {
      if (timer) clearInterval(timer);
      return;
    }

    const live = window.RaahiLearningLive;
    if (!live?.client || !Array.isArray(live?.data?.locations)) return;
    if (!live.session || !live.context || applying) return;

    const target = live.data.locations.find(row =>
      normalizeSlug(row?.slug) === pending.slug && String(row?.state || '').toLowerCase() === 'live'
    );

    if (!target) {
      clearPending();
      if (timer) clearInterval(timer);
      return;
    }

    const currentSlug = normalizeSlug(live.context?.selected_location?.slug);
    if (currentSlug === pending.slug) {
      clearPending();
      if (timer) clearInterval(timer);
      return;
    }

    const locationId = target.location_id || target.id;
    if (!locationId) {
      clearPending();
      if (timer) clearInterval(timer);
      return;
    }

    applying = true;
    try {
      const { error } = await live.client.rpc('set_selected_location', {
        p_location_id: locationId,
        p_idempotency_key: pending.idempotencyKey
      });
      if (error) throw error;
      clearPending();
      if (timer) clearInterval(timer);
      location.reload();
    } catch (error) {
      applying = false;
      live.__myRaahiLocationHandoffError = error?.message || String(error || 'Location handoff failed');
    }
  }

  timer = setInterval(() => { void applyPendingLocation(); }, 250);
  void applyPendingLocation();
  setTimeout(() => { if (timer) clearInterval(timer); }, 20000);
})();
