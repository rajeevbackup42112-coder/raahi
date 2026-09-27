# MyRaahi Shared Front Door — Gate 14 Executable Screen ↔ Backend Contracts v0.1

Last updated: 2026-09-27

Method: AI Builder Cheat Code v2.0 — Gate 14

Status: **PASS AS EXECUTABLE CONTRACT SPECIFICATION**

Evidence prerequisite:
- Gate 13 public Worker/D1 runtime proof passed.
- Gate 13 identity-continuity proof passed.

## 1. Proven execution architecture

### Shared public shell
- runtime: Cloudflare Worker + static assets;
- public configuration authority: D1;
- public configuration entities: Location, Product, LocationProduct;
- public reads require no Account.

### Identity
- central identity authority: existing Supabase Auth project `iiwwmqokaeflaenhlyip`;
- Google is the currently proven provider;
- each Raahi origin keeps an origin-local session;
- same human authenticating through the same Supabase project resolves to the same Supabase user UUID;
- V1 does not copy access/refresh tokens across origins.

### Focused products
- focused Product owns its business state and authorization;
- shared shell passes only safe Location/navigation context;
- product revalidates current state before a consequential action.

---

# 2. Contract format

For every interaction:

**Screen / Intent → Read contract → Write contract → Side effects → Authority owner → Failure/recovery**

No UI is permitted to write authoritative tables directly.

---

# 3. Public Home — no Location selected

## Intent
Understand Raahi and choose the place relevant right now.

## Read
`GET /api/v1/locations`

### Response
Public-safe fields only:
- Location id
- slug
- display name
- region label
- state already filtered to selectable/public rows

## Write
None.

Browser may store an explicit selected Location only after user choice.

## Side effects
None.

## Owner
Shared shell backend owns Location truth.

## Failure
- API unavailable → human retry state.
- zero Locations → honest no-service state.
- no invented default city.

---

# 4. Public Home — Location selected

## Intent
See what Raahi genuinely offers in this Location.

## Read
`GET /api/v1/catalog?location=<normalized-slug>`

### Server validation
1. slug format valid;
2. Location exists;
3. Location public state evaluated;
4. join only ACTIVE Products;
5. return only LIVE + deliberately visible PAUSED LocationProducts.

### Response
Location:
- slug
- display name
- region
- public state

Products:
- stable key
- public display name
- short human description
- icon ref
- LocationProduct public state
- approved entry URL
- optional availability message

## Write
None.

Logged-out selected Location remains lightweight browser state.

## Side effects
None.

## Owner
D1/shared backend owns catalogue truth.

## Failure
- invalid slug → `LOCATION_REQUIRED` / `LOCATION_NOT_FOUND`;
- nonselectable Location → `LOCATION_NOT_SELECTABLE`;
- datastore/runtime failure → `SERVICE_UNAVAILABLE`;
- UI never substitutes another Location silently.

---

# 5. Change Location — logged out

## Intent
Browse another town.

## Read
Public Location list/catalogue.

## Write
Browser-local preference only:
`raahi.selectedLocation.v1 = <slug>`

## Server write
None.

## Side effects
Catalogue refetch.

## Owner
Human owns preference intent; shared backend validates selectable truth.

## Failure
If stored slug becomes invalid:
- discard/ignore invalid preference;
- ask human to choose again;
- do not create an Account.

---

# 6. Product card — LIVE

## Intent
Enter one focused Raahi Product.

## Read
Current public catalogue.

## Write
None in shared shell.

## Navigation contract
Target comes from server-approved Product configuration.

Allowed context:
- normalized selected Location, e.g. `raahi_location=gomoh`.

Forbidden in public URL:
- Supabase access token;
- refresh token;
- OTP;
- private draft;
- raw verification evidence;
- admin authority.

## Side effects
Navigation only.

## Authority owner
Shared backend owns approved destination.
Focused Product owns whether the requested Product action remains available.

## Failure
Unsafe/unapproved destination → no live CTA.
Product unavailable after navigation → focused Product provides recovery.

---

# 7. Product card — PAUSED

## Intent
Understand that a known service is temporarily unavailable.

## Read
Catalogue.

## Write
None.

## Side effects
None.

## Authority owner
LocationProduct state in shared backend.

## Failure/recovery
No ordinary LIVE navigation/action.
Human can choose another Product/Location.

---

# 8. Authentication request from a consequential action

## Intent
Establish accountable durable Raahi identity only when needed.

## Preconditions
- visitor has reached a shared/focused action whose rule requires auth;
- safe return context exists;
- explicit current Location exists where relevant.

## Read
Focused/shared rule decides auth requirement.

## Write
No business transaction yet.

## Authentication contract
Use the same central Supabase Auth project for Raahi-owned origins.

V1 session model:
- each origin initiates its own PKCE/OAuth flow;
- each origin stores its own session locally;
- identity continuity is the Supabase user UUID;
- no refresh-token transfer between origins.

## Safe pre-auth context
May contain:
- approved return path;
- selected Location;
- safe draft reference/nonce.

Must not contain:
- raw access/refresh token in URL;
- unbounded arbitrary return URL;
- sensitive payload in plaintext query.

## Side effects
Authentication session established on the requesting origin only.

## Authority owner
Supabase Auth proves identity.
Raahi/focused backend separately resolves business authority.

## Failure
- user cancels → no business consequence;
- wrong Account → product must revalidate ownership/context before submit;
- provider outage → preserve safe draft and allow retry;
- callback not allow-listed → fail safely, do not fall back invisibly in production.

---

# 9. Identity resolution

## Intent
Map an authenticated provider session to the durable Raahi human identity.

## Read
Validated Supabase user identity.

## Canonical identifier
Supabase user UUID for the current V1 identity authority.

## Write
Future shared Account bootstrap/link only when Account layer is implemented.

## Invariant
Same Supabase user UUID must resolve to the same Raahi Account.

## Side effects
None merely from reading identity.

## Failure
Ambiguous/conflicting Account mapping → stop at recovery; never auto-merge.

---

# 10. Selected Location across authentication

## Intent
Keep the user's explicit current journey after auth.

## Before auth
Store safe selected Location context.

## After auth
1. validate Location still selectable;
2. preserve explicit current choice;
3. once authenticated Account preference exists, optionally persist it through canonical command.

## Future write contract
`set_my_selected_location(location_id, idempotency_key)`

## Authority
Human chooses; backend validates.

## Failure
Location invalidated during OAuth → keep authenticated session, return to chooser.

---

# 11. Future authenticated Account context

This contract becomes executable when shared Account storage is introduced.

## Read
`get_my_raahi_context()`

Returns only:
- Account id
- display presentation
- Account lifecycle state
- selected Location preference
- shared trust summary if needed
- platform capabilities
- Location Admin scopes

Must not return every focused-product relationship.

## Write
None.

## Failure
No mapped active Account → controlled bootstrap/recovery, not duplicate Account creation.

---

# 12. Future profile update

## Command
`update_my_raahi_profile(display_name, avatar_type, avatar_ref, idempotency_key)`

## Preconditions
- authenticated active Account;
- valid presentation fields.

## Permitted effect
Presentation fields only.

## Forbidden effect
Cannot modify:
- provider verification;
- phone trust;
- admin capability;
- focused-product role.

## Side effects
Optional audit only if future policy requires; no notification by default.

---

# 13. Platform Admin — Location read

## Read
`admin_list_locations()`

Requires current Platform Admin capability.

Returns:
- complete Location lifecycle;
- safe configuration;
- LocationProduct summary;
- scoped admin summary needed for governance.

## Write
None.

## Failure
No current capability → `NOT_AUTHORIZED`.

---

# 14. Platform Admin — create Location

## Command
`admin_create_location(input, idempotency_key)`

## Preconditions
- Platform Admin current at execution;
- canonical fields valid;
- unique slug;
- initial state permitted.

## Atomic effects
- create Location;
- create required audit event;
- persist idempotent result.

## Forbidden
No direct client table insert.

## Failure
Validation/duplicate/stale authority → no partial Location.

---

# 15. Platform Admin — Location lifecycle

## Command
`admin_set_location_state(location_id, target_state, reason, expected_state, idempotency_key)`

## Preconditions
- Platform Admin;
- current state matches transition rule;
- stronger reason/confirmation for retirement.

## Atomic effects
- transition Location;
- audit event;
- idempotency result.

## Non-effects
Must not:
- delete focused-product history;
- rewrite Account preferences silently;
- move product records.

## Failure
Stale expected state → return current state and allowed recovery.

---

# 16. Product registry read/write

## Read
`admin_list_products()`

## Commands
- `admin_create_product(...)`
- `admin_update_product_display(...)`
- `admin_retire_product(...)`

## Authority
Platform Admin only.

## Validation
- unique stable Product key;
- approved Raahi destination;
- lifecycle rules.

## Side effects
Audit + idempotency.

## Non-effects
No focused-product operational data change.

---

# 17. LocationProduct configuration

## Read
`admin_get_location_products(location_id)`

Authority:
- Platform Admin;
- delegated Location Admin only for own scope.

## Command
`admin_set_location_product_state(location_id, product_id, target_state, expected_state, reason, idempotency_key)`

## Preconditions
- current actor scope valid;
- Location/Product current;
- transition valid;
- LIVE readiness contract passes.

## Atomic effects
- one LocationProduct transition;
- audit event;
- idempotent command result.

## Public side effect
Public catalogue changes after cache/freshness window.

Current proven propagation:
- API/D1 truth changes immediately;
- browser may retain response for configured `max-age=30`.

## Non-effects
No direct focused-product history mutation.

---

# 18. Location Admin assignment

## Commands
- `admin_assign_location_admin(location_id, account_id, idempotency_key)`
- `admin_end_location_admin_assignment(assignment_id, reason, idempotency_key)`

## Authority
Platform Admin initially.

## Preconditions
- target Account active;
- Location valid;
- duplicate-active assignment prevented.

## Atomic effects
- assignment grant/end;
- audit;
- idempotent result.

## Failure
Stale/revoked Platform Admin or duplicate grant → no duplicate authority.

---

# 19. Phone trust — deferred executable contract

The product rule remains valid, but no shared-shell V1 action currently requires phone proof.

When a slice needs it, Gate 13 must reopen for provider/runtime proof.

Future conceptual commands:
- `request_phone_trust_challenge(phone)`
- `verify_phone_trust_challenge(challenge_id, otp)`

Must preserve:
- phone proof ≠ identity verification;
- server-side provider secret;
- no OTP plaintext persistence;
- anti-abuse/rate rules;
- exact normalized phone.

Do not implement merely because Learning already has provider code.

---

# 20. Auth/session logout semantics

V1 proven model:

### Local sign-out
An origin signs out its own current Supabase session.

Expected:
- that origin loses authenticated session;
- other Raahi-origin sessions remain intact;
- browser Location preference may remain because it is non-sensitive.

### Global sign-out
Not part of first shell contract.

A future “sign out of all Raahi” control requires explicit cross-session semantics and technology proof.

Do not label local sign-out as “sign out everywhere.”

---

# 21. Cache contract

Public catalogue:
- may be publicly cached for short bounded freshness;
- current staging implementation uses browser `max-age=30`, edge `s-maxage=120`, stale-while-revalidate 300.

These are implementation defaults, not permanent business rules.

Consequential focused-product actions:
- never trust cached shell state as final authority.

Authenticated/session responses:
- must not be publicly cached;
- auth/session routes use private/no-store behavior when implemented.

---

# 22. Read/write symmetry audit

| User-visible fact/action | Read source | Write source |
|---|---|---|
| Selectable Locations | shared public API/D1 | Platform Admin command |
| Product available in Location | shared catalogue/D1 | LocationProduct admin command |
| Selected logged-out Location | browser state + server validation | browser only |
| Durable identity | Supabase Auth | Supabase Auth provider flow |
| Shared Account presentation | future Account projection | future profile command |
| Location Admin scope | future server projection | admin assignment command |
| Product transaction state | focused Product | focused Product canonical command |
| Phone trust | future shared/product projection | future OTP trust commands |

No field is intentionally sourced from one authoritative system for reads and a different unrelated system for writes.

---

# 23. Security execution requirements

1. server-current authority on every consequential write;
2. no token/role/verification truth from client claims;
3. no access/refresh token in navigation URLs;
4. allow-listed auth return destinations;
5. no public caching of auth responses;
6. D1 public endpoints remain read-only until authenticated admin command layer exists;
7. focused Product revalidates business action;
8. origin-local sessions do not imply cross-origin business authority;
9. same identity UUID alone does not grant provider/admin capability;
10. local logout wording matches local-session semantics.

---

# Gate 14 result

**PASS as the executable contract specification for the current V1 scope.**

Contracts depending on Account-admin writes are specifications, not implemented claims.

Next gate:
**Gate 15 — Side-Effects Matrix.**
