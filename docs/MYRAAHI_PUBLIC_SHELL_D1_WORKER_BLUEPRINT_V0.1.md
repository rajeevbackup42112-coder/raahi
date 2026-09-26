# MyRaahi Public Shell — D1 + Worker Blueprint v0.1

Last updated: 2026-09-26

Status: **IMPLEMENTATION BLUEPRINT FOR WALKING SKELETON — NO DEPLOYMENT AUTHORIZED**

Parent:
- `MYRAAHI_FREE_INFRA_IDENTITY_ARCHITECTURE_GATE_V0.1.md`

Scope is intentionally limited to the **public Location-first shell**. Shared Account/SSO is excluded until the identity spike.

---

## 1. Runtime shape

### Public origin

Eventually:

`https://myraahi.co.in`

First proof should use a non-production/staging hostname until accepted.

### Runtime

- Cloudflare Worker
- Worker Static Assets for the shell UI
- Cloudflare D1 binding for public configuration
- no required login
- no public write endpoints in the first skeleton

### Source of truth

D1 is canonical for:
- Locations
- Product definitions
- LocationProduct availability

The browser is not authoritative for availability.

---

# 2. Physical D1 schema

SQLite/D1 semantics.

## 2.1 `locations`

```sql
CREATE TABLE locations (
  id TEXT PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  region TEXT,
  state_or_province TEXT,
  country_code TEXT NOT NULL DEFAULT 'IN',
  state TEXT NOT NULL
    CHECK (state IN ('PREPARING','LIVE','PAUSED','RETIRED')),
  display_order INTEGER NOT NULL DEFAULT 100,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

Indexes:

```sql
CREATE INDEX idx_locations_public_order
ON locations(state, display_order, display_name);
```

---

## 2.2 `products`

```sql
CREATE TABLE products (
  id TEXT PRIMARY KEY,
  product_key TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  short_description TEXT NOT NULL,
  icon_ref TEXT NOT NULL,
  entry_url TEXT NOT NULL,
  state TEXT NOT NULL
    CHECK (state IN ('ACTIVE','RETIRED')),
  display_order INTEGER NOT NULL DEFAULT 100,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

Rules:
- `product_key` is stable.
- `entry_url` must be validated by server/config tooling against approved Raahi origins before future admin writes are enabled.
- do not put domain operational data here.

---

## 2.3 `location_products`

```sql
CREATE TABLE location_products (
  id TEXT PRIMARY KEY,
  location_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  state TEXT NOT NULL
    CHECK (state IN ('OFF','PREPARING','LIVE','PAUSED')),
  local_display_name TEXT,
  local_short_description TEXT,
  availability_message TEXT,
  display_order INTEGER,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,

  FOREIGN KEY (location_id) REFERENCES locations(id),
  FOREIGN KEY (product_id) REFERENCES products(id),
  UNIQUE (location_id, product_id)
);
```

Indexes:

```sql
CREATE INDEX idx_location_products_catalog
ON location_products(location_id, state, display_order);

CREATE INDEX idx_location_products_product
ON location_products(product_id);
```

---

## 2.4 `config_audit_events`

Include from the start for future safe configuration tooling even if first writes happen only through controlled migration/CLI.

```sql
CREATE TABLE config_audit_events (
  id TEXT PRIMARY KEY,
  actor_type TEXT NOT NULL,
  actor_ref TEXT,
  action TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  location_id TEXT,
  product_id TEXT,
  reason TEXT,
  before_json TEXT,
  after_json TEXT,
  created_at TEXT NOT NULL
);
```

No public endpoint exposes this table.

---

## 2.5 `schema_meta`

```sql
CREATE TABLE schema_meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

Use for:
- schema/config version
- seed provenance

Not for business state.

---

# 3. Initial seed philosophy

Seed only enough to prove configuration.

Illustrative, not final launch truth:

Locations:
- Gomoh
- Dhanbad

Products:
- Learning
- ToTo

LocationProducts should deliberately differ so location switching is visibly testable.

Do not publish fake Doctors/Shops as LIVE merely to fill the homepage.

The final launch catalogue must reflect actual product readiness.

---

# 4. Public Worker API

Base:

`/api/v1`

No generic SQL proxy.

No browser-accessible write API in the initial walking skeleton.

---

## 4.1 GET `/api/v1/health`

Purpose:
- deployment/config sanity

Response:

```json
{
  "ok": true,
  "service": "myraahi-shell",
  "schema_version": "v0.1"
}
```

Must not expose secrets/config internals.

---

## 4.2 GET `/api/v1/locations`

Returns normal public/selectable Locations.

Default:
- LIVE Locations

Optional behavior for known saved PAUSED slug is handled through catalog lookup, not by making all PAUSED Locations normal choices.

Response fields:
- slug
- display_name
- region label if useful

Cacheable.

---

## 4.3 GET `/api/v1/catalog?location=gomoh`

Server steps:

1. normalize slug;
2. fetch Location;
3. if missing → 404 machine code `LOCATION_NOT_FOUND`;
4. if RETIRED/PREPARING → explicit unavailable response;
5. query LocationProducts joined to ACTIVE Products;
6. include LIVE + PAUSED LocationProducts;
7. sort deterministically;
8. return public-safe projection.

Example:

```json
{
  "location": {
    "slug": "gomoh",
    "display_name": "Gomoh",
    "state": "LIVE"
  },
  "products": [
    {
      "key": "learning",
      "display_name": "Learning",
      "short_description": "Find teachers and learning opportunities near you.",
      "icon_ref": "learning",
      "state": "LIVE",
      "entry_url": "https://learning.myraahi.co.in/",
      "availability_message": null
    }
  ]
}
```

---

# 5. Caching

Public catalogue changes infrequently.

Use conservative cache headers such as short edge/browser freshness plus revalidation after configuration changes.

Do not cache authenticated/admin data with public catalogue rules.

Initial design goal:
- reduce D1 reads;
- keep change propagation acceptably fast;
- avoid stale false availability for long periods.

Exact TTL is implementation/test detail, not a product invariant.

---

# 6. Browser state

For logged-out shell V0:

Store only:
- selected Location slug
- optional last-selection timestamp/version

Do not store:
- phone
- profile
- provider identity
- product private draft in shell storage unless explicitly designed later

On load:

1. read saved Location;
2. validate it against current API;
3. if invalid/nonselectable, ask user to choose;
4. never silently substitute another city as if user selected it.

---

# 7. Product deep-link contract — shell V0

The shell may append a non-sensitive Location hint using a stable parameter such as:

`?raahi_location=gomoh`

Rules:
- only normalized Raahi Location slug;
- no identity token;
- no private draft data;
- no arbitrary return URL from untrusted input;
- product may ignore the hint until its adapter is implemented;
- future product adapter validates the Location against its own rules/shared catalogue.

For the walking skeleton, prove context handoff on a non-production product adapter before changing Learning production.

---

# 8. UI implementation baseline

Mobile-first.

Minimum components:

- Raahi brand header
- Location selector/pill
- hero question:
  - “How can Raahi help you today?”
- Product cards
- PAUSED product treatment
- empty/no-live-product state
- simple footer/trust language
- loading/error/retry states

Avoid:
- sidebar-heavy desktop-first layout
- sign-in wall
- long marketing copy
- carousel clutter
- ad implementation in first skeleton
- AI chat box
- fake user avatar before authentication

Desktop should widen gracefully, not become a different information architecture.

---

# 9. No-auth admin/config proof

Because final Platform Admin identity is not yet selected, do **not** ship an unauthenticated admin UI.

During the walking skeleton, prove dynamic configuration through one controlled development mechanism:

- versioned seed/migration, or
- authenticated operator-only CLI/Wrangler D1 execution

Required proof:

- change one `location_products.state`
- reload public shell
- UI changes without frontend rebuild

Record the change in test evidence.

A production admin UI comes only after shared identity/admin auth is proven.

---

# 10. Security boundaries

1. Worker code uses bound D1 database; browser never receives Cloudflare API credentials.
2. No raw-query endpoint.
3. Parameterized statements only.
4. Validate Location slug length/format.
5. Validate response shapes.
6. Security headers appropriate to static app.
7. Strict allowlist for Product entry URLs in future config commands.
8. No service/admin secrets in client bundle.
9. No public configuration mutation endpoint in V0.
10. No auth tokens in Location/product deep links.

---

# 11. Walking skeleton test matrix

## WS-01 — first load

Open shell with empty browser state.

Expected:
- no login;
- user is asked to choose Location;
- no invented default.

## WS-02 — Gomoh

Choose Gomoh.

Expected:
- URL/UI clearly indicates Gomoh;
- only Gomoh configured Products appear.

## WS-03 — Dhanbad

Switch to Dhanbad.

Expected:
- catalogue changes;
- selected Location persists on refresh.

## WS-04 — Product OFF

Set one LocationProduct OFF through controlled config.

Expected:
- product disappears from normal choices after cache refresh;
- no frontend rebuild.

## WS-05 — Product PAUSED

Set Product PAUSED.

Expected:
- product remains truthfully visible if contract says so;
- normal entry/action is not presented as available.

## WS-06 — Product entry

Tap a LIVE Product.

Expected:
- navigates only to allowlisted configured Product URL;
- Location hint contains only normalized slug.

## WS-07 — invalid saved Location

Place invalid/retired slug in browser storage.

Expected:
- shell rejects it and asks user to choose;
- does not silently switch.

## WS-08 — API failure

Simulate catalogue API failure.

Expected:
- human retry state;
- no fake product availability.

## WS-09 — responsive

Verify at representative mobile and desktop widths.

Expected:
- no overlapping controls;
- Location selector visible;
- main task clear;
- cards usable by touch/keyboard.

## WS-10 — free-tier efficiency

Inspect request/query behavior.

Expected:
- indexed catalogue query;
- no polling loop;
- no unnecessary D1 writes;
- cache behaves as designed.

---

# 12. Implementation stop conditions

Stop before public production launch if:

- product catalogue still uses hard-coded frontend truth;
- any public write endpoint is unauthenticated;
- invalid external entry URLs can be configured;
- D1 schema migration replay is not deterministic;
- location persistence produces surprise city switches;
- mobile UI has overlapping/inaccessible controls;
- existing production products must be modified to make the skeleton work;
- identity/SSO is being improvised rather than separately proven.

---

# 13. Next action after skeleton design

When implementation is authorized:

1. choose repository/worktree strategy;
2. scaffold Cloudflare Worker/static UI;
3. create local D1 migration;
4. implement public read APIs;
5. build Location-first UI;
6. run local automated contract tests;
7. deploy only to non-production/staging hostname;
8. run browser/mobile verification;
9. prove configuration change without frontend rebuild;
10. document evidence;
11. then start the isolated identity/SSO spike.

Do not point `myraahi.co.in` production DNS to the new shell until explicit launch approval.
