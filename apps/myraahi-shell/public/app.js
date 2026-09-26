const STORAGE_KEY = "raahi.selectedLocation.v1";

const iconByProduct = {
  learning: "🎓",
  toto: "🛺",
  doctors: "🩺",
  shops: "🛍️",
  local: "⌖",
};

const state = {
  locations: [],
  selectedLocation: null,
  products: [],
};

const els = {
  dialog: document.getElementById("locationDialog"),
  locationList: document.getElementById("locationList"),
  locationButton: document.getElementById("locationButton"),
  locationButtonLabel: document.getElementById("locationButtonLabel"),
  chooseLocationCta: document.getElementById("chooseLocationCta"),
  status: document.getElementById("status"),
  catalog: document.getElementById("catalog"),
  catalogLocation: document.getElementById("catalogLocation"),
  productGrid: document.getElementById("productGrid"),
  heroSubtitle: document.getElementById("heroSubtitle"),
};

function savedLocation() {
  try {
    return localStorage.getItem(STORAGE_KEY);
  } catch {
    return null;
  }
}

function saveLocation(slug) {
  try {
    localStorage.setItem(STORAGE_KEY, slug);
  } catch {
    // The shell still works without persistence.
  }
}

function clearSavedLocation() {
  try {
    localStorage.removeItem(STORAGE_KEY);
  } catch {
    // No-op.
  }
}

async function getJson(url) {
  const response = await fetch(url, { headers: { accept: "application/json" } });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(body?.error?.message || "Raahi could not load this right now.");
    error.code = body?.error?.code || "REQUEST_FAILED";
    throw error;
  }
  return body;
}

function setStatus({ title, message, action = "Retry", mode = "normal", onAction }) {
  els.catalog.hidden = true;
  els.status.hidden = false;
  els.status.className = `status-card ${mode}`;
  els.status.innerHTML = `
    <div class="status-icon" aria-hidden="true">${mode === "error" ? "!" : "⌖"}</div>
    <h2>${escapeHtml(title)}</h2>
    <p>${escapeHtml(message)}</p>
    ${onAction ? `<button class="primary-button" id="statusAction" type="button">${escapeHtml(action)}</button>` : ""}
  `;
  if (onAction) document.getElementById("statusAction").onclick = onAction;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function safeProductUrl(entryUrl, locationSlug) {
  try {
    const target = new URL(entryUrl, window.location.origin);
    const isRaahi =
      target.hostname === "myraahi.co.in" ||
      target.hostname.endsWith(".myraahi.co.in") ||
      target.hostname === window.location.hostname;

    if (!isRaahi) return null;
    target.searchParams.set("raahi_location", locationSlug);
    return target.toString();
  } catch {
    return null;
  }
}

function renderLocations() {
  const current = state.selectedLocation?.slug;
  els.locationList.innerHTML = state.locations
    .map(
      (location) => `
        <button
          type="button"
          class="location-option"
          data-location="${escapeHtml(location.slug)}"
          aria-current="${location.slug === current ? "true" : "false"}"
        >
          <span>
            <strong>${escapeHtml(location.display_name)}</strong>
            <small>${escapeHtml(location.region || "Raahi location")}</small>
          </span>
          <span aria-hidden="true">→</span>
        </button>
      `
    )
    .join("");

  els.locationList.querySelectorAll("[data-location]").forEach((button) => {
    button.addEventListener("click", () => {
      els.dialog.close();
      void chooseLocation(button.dataset.location);
    });
  });
}

function openLocationDialog() {
  renderLocations();
  if (typeof els.dialog.showModal === "function") els.dialog.showModal();
}

function renderCatalog() {
  const location = state.selectedLocation;
  els.status.hidden = true;
  els.catalog.hidden = false;
  els.locationButtonLabel.textContent = location.display_name;
  els.catalogLocation.textContent = location.display_name;
  els.heroSubtitle.textContent =
    `Here’s what Raahi can help with in ${location.display_name} right now.`;

  if (!state.products.length) {
    els.productGrid.innerHTML = `
      <div class="empty-products">
        Raahi is here in ${escapeHtml(location.display_name)}, but no public service is live yet.
        We’ll only show something when it is genuinely ready.
      </div>
    `;
    return;
  }

  els.productGrid.innerHTML = state.products
    .map((product) => {
      const isLive = product.state === "LIVE";
      const href = isLive ? safeProductUrl(product.entry_url, location.slug) : null;
      const action =
        isLive && href
          ? `<a class="product-link" href="${escapeHtml(href)}">Open ${escapeHtml(product.display_name)} <span aria-hidden="true">→</span></a>`
          : `<span class="paused-label">${escapeHtml(product.availability_message || "Temporarily unavailable")}</span>`;

      return `
        <article class="product-card" data-state="${escapeHtml(product.state)}">
          <div class="product-icon" aria-hidden="true">${iconByProduct[product.key] || "•"}</div>
          <h3>${escapeHtml(product.display_name)}</h3>
          <p>${escapeHtml(product.short_description)}</p>
          <div class="product-action">${action}</div>
        </article>
      `;
    })
    .join("");
}

async function loadLocations() {
  const body = await getJson("/api/v1/locations");
  state.locations = Array.isArray(body.locations) ? body.locations : [];
  renderLocations();
}

async function chooseLocation(slug) {
  const known = state.locations.find((location) => location.slug === slug);
  if (!known) {
    clearSavedLocation();
    state.selectedLocation = null;
    setStatus({
      title: "Choose an available location",
      message: "That saved Raahi location is no longer available.",
      action: "Choose location",
      onAction: openLocationDialog,
    });
    return;
  }

  state.selectedLocation = known;
  els.locationButtonLabel.textContent = known.display_name;
  els.heroSubtitle.textContent =
    `Here’s what Raahi can help with in ${known.display_name} right now.`;
  setStatus({
    title: `Loading ${known.display_name}`,
    message: "Checking what Raahi can genuinely help with there.",
    mode: "loading",
  });

  try {
    const body = await getJson(`/api/v1/catalog?location=${encodeURIComponent(slug)}`);
    state.selectedLocation = body.location;
    state.products = Array.isArray(body.products) ? body.products : [];
    saveLocation(slug);
    renderCatalog();
  } catch (error) {
    if (error.code === "LOCATION_NOT_SELECTABLE" || error.code === "LOCATION_NOT_FOUND") {
      clearSavedLocation();
    }
    els.heroSubtitle.textContent =
      `We couldn’t check what Raahi can help with in ${known.display_name} right now.`;
    setStatus({
      title: "Raahi couldn’t load this location",
      message: error.message,
      action: "Choose another location",
      mode: "error",
      onAction: openLocationDialog,
    });
  }
}

async function bootstrap() {
  setStatus({
    title: "Loading Raahi",
    message: "Checking the locations currently available.",
    mode: "loading",
  });

  try {
    await loadLocations();
  } catch {
    setStatus({
      title: "Raahi couldn’t load",
      message: "We couldn’t check the current Raahi locations. Please try again.",
      action: "Try again",
      mode: "error",
      onAction: () => void bootstrap(),
    });
    return;
  }

  const saved = savedLocation();
  if (saved && state.locations.some((location) => location.slug === saved)) {
    await chooseLocation(saved);
    return;
  }

  if (saved) clearSavedLocation();

  setStatus({
    title: "Start with your location",
    message: "Raahi is local first. Pick your town and we’ll show only what is available there.",
    action: "Choose location",
    onAction: openLocationDialog,
  });
}

els.locationButton.addEventListener("click", openLocationDialog);
els.chooseLocationCta?.addEventListener("click", openLocationDialog);

void bootstrap();
