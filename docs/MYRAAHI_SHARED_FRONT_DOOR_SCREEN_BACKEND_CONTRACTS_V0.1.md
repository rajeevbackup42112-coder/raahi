# MyRaahi Shared Front Door — Screen ↔ Backend Contracts v0.1

Last updated: 2026-09-26

Status: **DESIGN BASELINE — NO IMPLEMENTATION YET**

Parent documents:
- `MYRAAHI_SHARED_FRONT_DOOR_PRODUCT_CONTRACT_V0.1.md`
- `MYRAAHI_SHARED_FOUNDATION_DOMAIN_MODEL_V0.1.md`

---

## 1. Contract discipline

The public shell should use small purpose-built reads and canonical commands.

Rules:

1. UI does not query authoritative tables directly.
2. Public reads return only public-safe fields.
3. Consequential writes are canonical server commands.
4. Browser-selected Location before login is local/session state, not a database write.
5. Authenticated selected-Location updates are idempotent.
6. Product-specific operational actions happen inside the focused product.
7. The shell does not become a proxy for every product API.

---

# 2. Raahi Home

## Screen purpose

Answer:

> What can Raahi help me with in this Location?

## Inputs

- optional Location slug from route/query/browser state
- optional authenticated Raahi Account context

## Read contract

### `get_public_raahi_catalog(location_slug?)`

Public, no Account required.

Conceptual response:

```json
{
  "locations": [
    {
      "location_id": "uuid",
      "slug": "gomoh",
      "name": "Gomoh",
      "state": "LIVE"
    }
  ],
  "selected_location": {
    "location_id": "uuid",
    "slug": "gomoh",
    "name": "Gomoh",
    "state": "LIVE"
  },
  "products": [
    {
      "product_key": "learning",
      "name": "Learning",
      "short_description": "Find teachers and learning opportunities near you.",
      "icon_ref": "learning",
      "location_product_state": "LIVE",
      "entry_url": "https://learning.myraahi.co.in/",
      "availability_message": null
    }
  ]
}
```

### Behavior

- If no Location supplied, return selectable Locations and no invented selection.
- If supplied Location is LIVE, return its catalogue.
- If supplied Location is PAUSED/RETIRED/nonexistent, return explicit non-live state and active alternatives.
- Product list includes LIVE and, where product contract requires, PAUSED entries.
- OFF/PREPARING are hidden from normal public catalogue.

## UI actions

- Choose/change Location — browser state only when logged out.
- Open Product — navigation/deep-link, no shared write required.
- Sign in/profile — optional account action, not required for catalogue.

---

# 3. Location Chooser

## Read contract

May reuse the Locations portion of `get_public_raahi_catalog` or a smaller:

### `list_public_raahi_locations()`

Response:
- id
- slug
- name
- public state
- optional small region label

No private coverage/admin metadata.

## Logged-out select action

No server command required.

Store:
- chosen Location slug/id
- selection timestamp/version if useful

in browser-local/session state.

## Logged-in select action

### `set_my_selected_location(location_id, idempotency_key)`

Requirements:
- authenticated active Account
- target Location exists
- target is normally selectable in current lifecycle

Effect:
- upsert AccountLocationPreference
- audit only if policy later determines preference changes need audit; ordinary preference change does not need heavy audit by default
- return selected Location projection

Failure codes:
- `AUTH_REQUIRED`
- `ACCOUNT_NOT_ACTIVE`
- `LOCATION_NOT_FOUND`
- `LOCATION_NOT_SELECTABLE`
- `IDEMPOTENCY_CONFLICT`

---

# 4. Account Context

## Read contract

### `get_my_raahi_context()`

Authenticated.

Conceptual response:

```json
{
  "account": {
    "account_id": "uuid",
    "display_name": "Rajeev",
    "avatar_type": "initials",
    "avatar_ref": null,
    "lifecycle_state": "ACTIVE"
  },
  "selected_location": {
    "location_id": "uuid",
    "slug": "gomoh",
    "name": "Gomoh",
    "state": "LIVE"
  },
  "phone_trust": {
    "state": "UNVERIFIED",
    "verified_at": null
  },
  "platform_capabilities": [],
  "location_admin_scopes": []
}
```

Do not include all product memberships/relationships by default.

Focused products resolve their own context after entry.

---

# 5. Profile

## Read

Uses Account portion of `get_my_raahi_context()`.

## Command

### `update_my_raahi_profile(display_name, avatar_type, avatar_ref, idempotency_key)`

Authenticated.

Rules:
- user can change presentation fields only;
- cannot change trust/roles/admin authority;
- uploaded media rules remain separate if/when uploads are supported.

Failure codes:
- validation errors
- account not active
- idempotency conflict

---

# 6. Authentication Handoff Contract

Authentication itself may be implemented by the chosen identity architecture, but product behavior is frozen.

## Input from shell/product

- safe return destination
- selected Location
- safe product draft identifier/payload strategy
- reason for authentication in human language

## Requirements

1. Return target must be allow-listed/same Raahi origin family.
2. Open redirects are forbidden.
3. Sensitive product payloads are not placed in plaintext query strings.
4. Authentication cancellation returns user to safe pre-auth context.
5. Authentication success returns user to intended next step.
6. An explicit logged-out Location chosen immediately before auth remains current.

## Output

- authenticated Account/session or signed identity handoff
- restored safe return context

Technical details remain an architecture gate.

---

# 7. Platform Admin — Locations

## Read

### `admin_list_locations()`

Requires Platform Admin.

Returns:
- full Location lifecycle
- safe configuration metadata
- current Location Admin summary
- product enablement summary

## Commands

### `admin_create_location(..., idempotency_key)`

### `admin_set_location_state(location_id, target_state, reason, idempotency_key)`

Rules:
- canonical state-transition validation
- actor recorded
- consequential transition audited
- retiring LIVE Location requires stronger confirmation/reason

---

# 8. Platform Admin — Product Registry

## Read

### `admin_list_products()`

Requires Platform Admin.

## Commands

### `admin_create_product(product_key, display_metadata, entry_integration, idempotency_key)`

### `admin_update_product_display(product_id, display_metadata, idempotency_key)`

### `admin_retire_product(product_id, reason, idempotency_key)`

Rules:
- stable product key cannot be casually renamed;
- destination integration must use approved Raahi routes/origins;
- retiring Product cannot destroy product-owned data.

---

# 9. Platform/Location Admin — Location Product

## Read

### `admin_get_location_products(location_id)`

Authorized Platform Admin or assigned Location Admin with allowed scope.

## Command

### `admin_set_location_product_state(location_id, product_id, target_state, reason, idempotency_key)`

Rules:
- server validates actor scope;
- Location Admin cannot create/retire global Product definitions;
- allowed state transitions enforced;
- LIVE requires readiness preconditions later defined per Product integration;
- command affects shared discoverability/admission only;
- does not directly mutate product-owned operational state/history.

### Potential future command

`admin_update_location_product_display(...)`

Only add if local display overrides prove necessary.

---

# 10. Platform Admin — Location Admin Assignments

## Read

### `admin_list_location_admins(location_id?)`

Platform Admin sees all.

A Location Admin may see only assignments relevant to their own scope if needed.

## Commands

### `admin_assign_location_admin(location_id, account_id, idempotency_key)`

### `admin_end_location_admin_assignment(assignment_id, reason, idempotency_key)`

Platform Admin only initially.

Rules:
- account must exist and be active;
- duplicate active assignment prevented;
- changes audited;
- ending assignment does not delete history.

---

# 11. Phone Trust

The shell should not ask for phone trust during ordinary public discovery.

If a shared trust-sensitive action eventually requires it, adapt the proven Learning provider boundary.

Conceptual contracts:

### `request_phone_trust_challenge(phone)`

### `verify_phone_trust_challenge(challenge_id, otp)`

Requirements:
- authenticated Account if attaching proof to durable Raahi Account;
- provider secret server-side only;
- OTP plaintext never persisted;
- anti-abuse/rate controls;
- exact normalized phone handling;
- successful proof updates server-owned trust timestamp.

A focused Product may trigger these commands if its action requires shared phone trust.

---

# 12. Product integration contract

Each Product registered in the shell must provide at minimum:

- stable Product key
- approved entry URL/path
- Location context handoff strategy
- public-browse support declaration
- authentication boundary declaration
- whether shared Account/session can be consumed
- health/readiness signal strategy before LocationProduct can become LIVE

## V0 Location handoff

At minimum, Product entry should accept an explicit safe Location context, e.g. an approved query/path parameter, or resolve from shared Account context after sign-in.

Do not silently infer a different market from GPS when the user explicitly selected a Raahi Location.

---

# 13. Error semantics

The public shell should map technical errors to human language while retaining stable machine codes.

Examples:

- `LOCATION_NOT_FOUND` → “That Raahi location is not available.”
- `LOCATION_NOT_SELECTABLE` → “Raahi is temporarily unavailable there.”
- `PRODUCT_PAUSED` → “This service is temporarily unavailable in Gomoh.”
- `AUTH_REQUIRED` → authentication handoff, not a raw error
- `NOT_AUTHORIZED` → “You don't have access to manage this.”
- `IDEMPOTENCY_CONFLICT` → safe retry/reload path
- `SERVICE_UNAVAILABLE` → preserve context and offer retry

Do not expose raw database/provider errors to users.

---

# 14. Walking-skeleton contracts

The first end-to-end proof should need only:

1. `list/get public catalogue`
2. logged-out Location selection
3. Product entry/deep-link preserving Location
4. one authenticated Account context path
5. authenticated `set_my_selected_location`
6. Platform Admin changes one LocationProduct state
7. public homepage reflects that change without frontend code change
8. audit proves the admin change
9. one focused Product receives the intended Location context

No booking/order/class/matching logic needs to be moved into the shared shell for this proof.
