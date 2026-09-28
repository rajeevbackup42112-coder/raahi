# MyRaahi — Gate 14 Screen ↔ Backend Executable Contracts v0.1

Last updated: 2026-09-28

Method: AI Builder Cheat Code v2.0 — Gate 14

Status: **PASS AS EXECUTABLE CONTRACT**

Scope: shared `myraahi.co.in` front door and the minimum cross-product integration needed before a walking skeleton.

Architecture already proven at Gate 13:
- Cloudflare Worker + D1 for shared public configuration;
- Supabase Auth project `iiwwmqokaeflaenhlyip` as Raahi identity authority;
- origin-local sessions in V1;
- same Google human resolves to the same Supabase user UUID across allowed Raahi origins;
- no refresh/access-token transfer between ordinary Raahi origins;
- focused Product owns its own transactions/roles.

---

# 1. Contract law

Every screen/backend interaction must declare:

1. user intent;
2. exact request;
3. authentication requirement;
4. authoritative source;
5. allowed response fields;
6. side effects;
7. failure codes;
8. retry/idempotency behavior;
9. UI recovery.

The browser is never authoritative for:
- Location lifecycle;
- Product availability;
- Account authority;
- admin scope;
- trust/verification;
- focused-product transaction state.

---

# 2. Public Home — initial load

## User intent

> “What can Raahi help me with where I am interested right now?”

## Screen

`/`

## Backend reads

### A. Health

`GET /api/v1/health`

Authentication: none.

Expected 200 shape:

```json
{
  "ok": true,
  "service": "myraahi-shell",
  "schema_version": "0.1"
}
```

Purpose:
- operational diagnosis only;
- normal UI does not need to block on health first.

Side effects: none.

Cache: no business authority.

### B. Public Locations

`GET /api/v1/locations`

Authentication: none.

Authority:
- D1 `locations`.

Allowed fields:
- stable Location id;
- slug;
- display name;
- small region label;
- public lifecycle state.

Must not return:
- admin assignment;
- internal notes;
- audit details;
- private operational metadata.

Expected 200:

```json
{
  "locations": [
    {
      "id": "loc-gomoh",
      "slug": "gomoh",
      "display_name": "Gomoh",
      "region": "Dhanbad district",
      "state": "LIVE"
    }
  ]
}
```

Failure:
- `SERVICE_UNAVAILABLE` → human retry state.

Retry:
- safe/read-only.

Side effects: none.

---

# 3. Location selection — logged out

## User intent

> “Show me Raahi for Gomoh.”

## Browser action

Store only normalized selected Location slug in browser-local state.

Current key:
`raahi.selectedLocation.v1`

This is convenience state, not identity or authority.

## Server reconciliation

After selection/reload, browser must call current public backend truth.

A browser-stored Location is accepted only if current API still exposes it as selectable.

Invalid/stale/tampered value:
- clear/ignore it;
- ask user to choose again.

No database write.

No audit.

---

# 4. Public catalogue

## Request

`GET /api/v1/catalog?location=<normalized-slug>`

Example:
`GET /api/v1/catalog?location=gomoh`

Authentication: none.

Authority:
- D1 `locations`
- D1 `products`
- D1 `location_products`

Expected 200:

```json
{
  "location": {
    "slug": "gomoh",
    "display_name": "Gomoh",
    "region": "Dhanbad district",
    "state": "LIVE"
  },
  "products": [
    {
      "key": "learning",
      "display_name": "Learn",
      "short_description": "Find teachers and learning opportunities near you.",
      "icon_ref": "learning",
      "state": "LIVE",
      "entry_url": "https://learning.myraahi.co.in/",
      "availability_message": null
    }
  ]
}
```

Visibility:
- LIVE → normal action;
- PAUSED → truthful unavailable treatment if configured to show;
- PREPARING/OFF → not a normal public action.

Stable internal key and public brand are separate:
- `learning` → Learn
- `toto` → Ride

Failure codes:
- `LOCATION_NOT_FOUND`
- `LOCATION_NOT_SELECTABLE`
- `SERVICE_UNAVAILABLE`

Retry:
- GET is repeatable.

Cache:
- current public API may use short browser caching;
- cache is delivery optimization only;
- focused Product revalidates its own operational truth.

Side effects: none.

---

# 5. Product card → focused Product

## User intent

> “Open Learn for Gomoh.”

## Preconditions

- current Location is explicit;
- Product is currently actionable according to public catalogue;
- destination belongs to an approved Raahi origin/path.

## Navigation contract

The shared shell may pass only non-sensitive context in the URL.

V1 allowed context:
- normalized Location slug/hint.

Example conceptual destination:
`https://learning.myraahi.co.in/?location=gomoh`

Exact adapter syntax is Product-owned and must be frozen per Product integration.

Forbidden in URL:
- access token;
- refresh token;
- private draft payload;
- phone/email;
- admin capability;
- verification evidence.

No shared write is required merely to enter a Product.

Focused Product is authoritative after entry.

If Product is stale/down:
- Product rejects/recovers;
- shell catalogue never guarantees transaction availability.

---

# 6. Authentication boundary — V1

## Shared rule

The public MyRaahi shell does not authenticate merely to render catalogue.

Authentication begins only when a focused Product or future shared action genuinely requires durable identity.

## Identity authority

Supabase Auth issuer:

`https://iiwwmqokaeflaenhlyip.supabase.co/auth/v1`

Canonical subject:
- verified JWT `sub` / Supabase user UUID.

## Session rule

V1 sessions are origin-local.

A new Raahi origin may authenticate independently through the same Supabase Auth project.

Gate 13 proof established:
- same Google human → same Supabase UUID;
- explicit Location can survive OAuth;
- local sign-out on one origin need not terminate another origin's local browser session.

## Forbidden default

Do not copy Learning localStorage tokens into MyRaahi.

Do not make the experimental Gate-13 D1 SSO tables the production Account store.

---

# 7. Authenticated “my Raahi context” — production contract, not implemented yet

This is the first authenticated shared contract needed only when a shared screen/action requires it.

## Request

Conceptual:
`GET /api/v1/me`

Authentication:
- valid Supabase access token presented in Authorization header by the current origin's own authenticated client/session.

Server verification:
- ES256;
- public JWKS;
- issuer exact match;
- audience `authenticated`;
- expiry;
- subject present.

Important:
A valid token proves identity only.

It does not prove:
- Platform Admin;
- Location Admin;
- Teacher;
- Parent;
- Driver;
- verification;
- phone trust.

## Minimum response

```json
{
  "authenticated": true,
  "subject": {
    "issuer": "https://iiwwmqokaeflaenhlyip.supabase.co/auth/v1"
  },
  "selected_location": null,
  "platform_capabilities": [],
  "location_admin_scopes": []
}
```

Do not return the raw auth subject UUID unless the UI actually needs it.

Do not return all focused-product relationships.

Authority for capabilities/preferences:
- future shared authoritative store/commands frozen only when the corresponding slice is implemented.

---

# 8. Authenticated selected Location — future shared command

Required only if Raahi decides signed-in Location preference must roam between origins/devices.

Until then:
- browser-local explicit Location is sufficient for public shell.

If implemented:

`PUT /api/v1/me/location`

Body:

```json
{
  "location_id": "loc-gomoh",
  "idempotency_key": "..."
}
```

Preconditions:
- verified active Raahi subject;
- Location exists/selectable;
- current explicit Location intent is clear.

Effect:
- one account preference changes;
- no role/authority changes.

Idempotency required.

This command is **not part of the current public shell implementation**.

---

# 9. Shared profile — future command

Not needed for public walking skeleton.

If implemented:

`PATCH /api/v1/me/profile`

Allowed:
- display presentation only.

Forbidden:
- role;
- capability;
- verification;
- phone trust;
- Product relationship.

Idempotency/retry semantics must be explicit.

---

# 10. Admin Location/Product configuration — required for full walking skeleton

Current Gate-13 runtime proved configuration mutation through authenticated operator tooling/CLI, not through a production admin web contract.

Production contract:

## Read

`GET /api/v1/admin/locations/<location_id>/products`

Requires:
- verified Supabase subject;
- current server-owned Platform Admin or allowed Location Admin scope.

## Command

`PUT /api/v1/admin/locations/<location_id>/products/<product_key>/state`

Body:

```json
{
  "target_state": "PAUSED",
  "reason": "Local operation temporarily unavailable",
  "idempotency_key": "..."
}
```

Server must recheck:
- token identity;
- account/capability current state;
- Location scope;
- Product existence;
- current LocationProduct state;
- allowed transition;
- readiness if target LIVE.

Effect:
- one canonical LocationProduct transition;
- append audit evidence;
- no focused-product history mutation.

Failure codes:
- `AUTH_REQUIRED`
- `NOT_AUTHORIZED`
- `LOCATION_NOT_FOUND`
- `PRODUCT_NOT_FOUND`
- `INVALID_TRANSITION`
- `READINESS_NOT_MET`
- `IDEMPOTENCY_CONFLICT`
- `STALE_STATE`

Retry:
- idempotency key protects duplicate intent.

This contract is **not implemented yet**.

---

# 11. Audit contract

Consequential shared admin writes create immutable audit evidence in the same transaction/atomic unit where practical.

Minimum evidence:
- event id;
- actor auth issuer/subject reference or resolved shared account id;
- action;
- target;
- Location/Product scope;
- before state;
- after state;
- reason where required;
- timestamp;
- idempotency key/command reference.

Public reads and logged-out Location preference do not generate heavy audit events.

---

# 12. Phone trust boundary

No phone challenge exists on the public Home flow.

If a future shared action needs phone trust:
- authenticate first;
- explain why;
- invoke a dedicated server-side OTP provider boundary;
- record exact phone-control evidence only;
- never treat it as professional or identity verification.

Gate 13 does not need to reopen until a real slice requires this.

---

# 13. Error mapping

Backend machine code → public UI:

- `LOCATION_NOT_FOUND` → “That Raahi location isn't available.”
- `LOCATION_NOT_SELECTABLE` → “Raahi isn't available there right now.”
- `PRODUCT_PAUSED` → “This service is temporarily unavailable.”
- `AUTH_REQUIRED` → explain action-specific sign-in need.
- `NOT_AUTHORIZED` → “You don't have access to manage this.”
- `STALE_STATE` → refresh current state; do not overwrite silently.
- `IDEMPOTENCY_CONFLICT` → safe reload/recovery.
- `SERVICE_UNAVAILABLE` → preserve Location/context and offer retry.

No raw SQL, D1, Supabase, Cloudflare or provider error is shown to ordinary users.

---

# 14. Exact V1 screen/backend matrix

| Screen / intent | Backend | Auth | Write? | Authority | Implemented now? |
|---|---|---:|---:|---|---|
| Home initial | `GET /api/v1/locations` | No | No | D1 | Yes |
| Home health/diagnostic | `GET /api/v1/health` | No | No | Worker | Yes |
| Select Location logged out | browser local state + current API reconciliation | No | No | Browser preference + D1 validation | Yes |
| Show local Products | `GET /api/v1/catalog?location=...` | No | No | D1 | Yes |
| Open Product | approved navigation adapter | No by default | No | D1 destination config + focused Product | Partially; Location adapter per Product remains |
| Authenticate in focused Product | Supabase Auth on Product origin | Yes | Auth session | Supabase Auth | Proven in Learn |
| Shared account context | `GET /api/v1/me` | Yes | No | Supabase identity + shared capability store | No |
| Persist signed-in Location | `PUT /api/v1/me/location` | Yes | Yes | Shared command store | No / optional V1 |
| Admin view | admin read projection | Yes | No | shared admin authority | No |
| Admin change Product state | canonical admin state command | Yes | Yes | shared config + audit | No |
| Focused Product transaction | Product API/RPC | Product-specific | Product-specific | focused Product | Outside shell |

---

# 15. Gate-14 freeze

Frozen:
1. public shell is anonymous-first;
2. D1 is shared public configuration authority;
3. Supabase Auth is shared identity authority;
4. same identity does not imply shared browser session;
5. access/refresh tokens do not move through ordinary URLs;
6. focused Product owns focused transactions;
7. admin writes require server-side current authority + idempotency + audit;
8. browser Location preference never grants authority.

Not frozen:
- exact future admin UI layout;
- whether signed-in Location preference is persisted cross-device in V1;
- true seamless SSO;
- shared phone trust implementation;
- exact Account/profile storage physical schema.

Those reopen only when a vertical slice requires them.

---

# Gate 14 result

**PASS AS EXECUTABLE CONTRACT.**

Current implementation covers the anonymous public-read subset.

Before broad implementation, complete:
- Gate 15 Side-Effects Matrix;
- Gate 16 Walking Skeleton definition/proof plan.
