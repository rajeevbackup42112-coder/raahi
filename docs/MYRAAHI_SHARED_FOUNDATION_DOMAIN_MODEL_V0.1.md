# MyRaahi Shared Foundation — Canonical Domain Model v0.1

Last updated: 2026-09-26

Status: **DESIGN BASELINE — NO DATABASE IMPLEMENTATION YET**

Parent contract:
- `docs/MYRAAHI_SHARED_FRONT_DOOR_PRODUCT_CONTRACT_V0.1.md`

Evidence inputs:
- `docs/RAAHI_DNA_V0.1.md`
- `docs/RAAHI_SHARED_FOUNDATION_REUSE_MATRIX_V0.1.md`

---

## 1. Design objective

Model only the state that must be shared across Raahi products.

The common core should know:

- who the Raahi Account is;
- which Raahi Locations exist;
- which focused Products exist;
- which Products are available in which Locations;
- the user's selected Location preference after sign-in;
- who has platform-wide or Location-scoped administration authority;
- minimal shared Account trust/profile state;
- enough audit/idempotency state to make consequential shared commands safe.

The common core should **not** own:

- Classes/tests/teacher marketplace state;
- rides/matching/vehicles;
- school transport operations;
- doctor appointment lifecycles;
- shop inventory/orders;
- any other focused-product operational model.

---

# 2. Canonical shared entities

## 2.1 Account

Represents one durable Raahi human account.

Minimum conceptual attributes:

- `id`
- authentication subject/reference
- `display_name`
- avatar choice/reference
- lifecycle state
- profile onboarding completion metadata if retained
- phone trust timestamp/state inputs where the chosen auth architecture supports it
- created/updated timestamps

Important rules:

- Account is not a role.
- Account is not permanently bound to a Location.
- Account is not a Teacher/Driver/Doctor/Shop.
- Product identities/relationships link back to Account when needed.
- Authentication-provider metadata is not automatically public profile truth.

### Lifecycle

`ACTIVE → PAUSED → ACTIVE`

`ACTIVE/PAUSED → CLOSED`

Closed is terminal for normal self-service operations unless a deliberately designed recovery path is later approved.

Exact deletion/anonymization policy is deferred to privacy/retention design.

---

## 2.2 Location

Represents one named Raahi local market/context users understand.

Examples:
- Gomoh
- Dhanbad
- Bokaro
- Ranchi

It is not necessarily an administrative municipal boundary.

Minimum conceptual attributes:

- `id`
- unique `slug`
- display name
- region/district/state/country metadata where useful
- lifecycle state
- optional public display metadata
- created/updated timestamps

### Lifecycle

`PREPARING → LIVE → PAUSED → LIVE`

`PREPARING/LIVE/PAUSED → RETIRED`

Normal public selector primarily exposes LIVE.

A previously selected PAUSED Location may be shown truthfully with a prompt to choose another active Location.

RETIRED remains referentially valid for history but is not a normal selection.

---

## 2.3 Product

Represents one focused Raahi capability/product visible from the shared shell.

Examples:
- Learning
- ToTo / Mobility
- Doctors
- Shops

Minimum conceptual attributes:

- `id`
- stable unique `key`
- public display name
- short human description
- icon/image reference
- destination integration metadata
- platform lifecycle/state
- display metadata
- created/updated timestamps

### Product lifecycle

Keep platform lifecycle minimal:

`ACTIVE`
`RETIRED`

A Product may exist globally while being OFF/PREPARING/PAUSED in individual Locations.

The Product entity does not contain domain operational data.

---

## 2.4 LocationProduct

Relationship entity defining whether and how one Product is exposed in one Location.

This is the central missing shared-shell entity discovered during archaeology.

Minimum conceptual attributes:

- `id`
- `location_id`
- `product_id`
- rollout state
- optional local public label/description override
- optional display order
- optional product-entry configuration that is genuinely shared
- created/updated timestamps

Unique relationship:

`(location_id, product_id)`

### Lifecycle

`OFF → PREPARING → LIVE → PAUSED → LIVE`

Any non-retired state may move to OFF when the Product is deliberately withdrawn from that Location, subject to preservation of product-owned historical relationships.

Interpretation:

- **OFF** — not offered; hidden from normal homepage.
- **PREPARING** — internal setup; hidden unless an explicit Coming Soon experiment is approved.
- **LIVE** — normal public choice.
- **PAUSED** — known product temporarily unavailable for new normal activity; can remain visible with truthful status.

### Public eligibility invariant

A LocationProduct can be publicly actionable only when:

- Location = LIVE;
- Product = ACTIVE;
- LocationProduct = LIVE.

A PAUSED LocationProduct may be publicly visible as unavailable but not actionable for normal new activity.

---

## 2.5 AccountLocationPreference

Stores the selected Location preference for an authenticated Account.

Minimum conceptual attributes:

- `account_id` — one row per Account
- `selected_location_id`
- updated timestamp

Important rules:

- preference only;
- does not own history;
- does not grant local authority;
- does not move product relationships;
- may point to a Location that later becomes PAUSED/RETIRED, in which case UX requests a new selection.

Logged-out Location selection is not an entity in the shared database in V1; it is browser/session state.

---

## 2.6 AccountCapability

Represents only genuinely platform-level Account authority/capability.

Examples initially:

- `platform_admin`

Potential future shared capabilities must earn their way into the common core.

Minimum conceptual attributes:

- `account_id`
- capability code
- state
- granted-by Account where applicable
- granted/revoked timestamps
- reason/audit linkage where appropriate

### Important rule

Do **not** use AccountCapability as a dumping ground for every product role.

Teacher, Driver, Doctor, Shop Owner, Guardian, etc. remain product-specific relationships/identities unless a real cross-product capability is discovered.

---

## 2.7 LocationStaffAssignment

Represents explicit scoped administrative authority for an Account in a Location.

Initial staff type:

- `location_admin`

Minimum conceptual attributes:

- `id`
- `location_id`
- `account_id`
- staff type
- state
- assigned-by Account
- assigned/ended timestamps
- reason where relevant

### Lifecycle

`ACTIVE → ENDED`

A new assignment may later be created after an ended one; history is retained.

### Rules

- selected Location never grants this assignment;
- one active assignment per Account + Location + staff type;
- Platform Admin does not need a LocationStaffAssignment to exercise platform governance;
- Location Admin authority is limited to its assigned scope.

---

## 2.8 SharedAuditEvent

Immutable/shared audit record for consequential shared-platform operations.

Use for events such as:

- Location created/state changed
- Product created/retired
- LocationProduct state changed
- Location Admin assigned/ended
- platform capability granted/revoked
- shared Account lifecycle actions
- trust-sensitive shared Account actions where appropriate

Minimum conceptual attributes:

- id
- actor kind
- actor Account where applicable
- action type
- target type/id
- optional Location id
- optional Product id
- reason
- disciplined metadata
- created timestamp

Do not log secrets, OTP plaintext, unnecessary PII, or full sensitive payloads.

---

## 2.9 IdempotentCommandRecord

Represents the replay-safety envelope for consequential shared commands.

Conceptual key:

`(actor, command_name, idempotency_key)`

Stores enough request fingerprint/result metadata to:
- safely return the previous result for a true retry;
- reject key reuse with conflicting inputs;
- prevent double administrative writes.

This may reuse the proven Raahi Learning command-ledger pattern.

---

# 3. Shared trust state

## 3.1 Phone trust

Phone trust belongs to Account trust posture, not a provider identity.

Conceptual derived states:

- `UNVERIFIED`
- `FRESH`
- `STALE`

If the final architecture retains the Learning model, durable input may include `phone_trust_verified_at` while the authentication system remains authoritative for the confirmed phone and confirmation timestamp.

Phone trust is **not**:
- identity verification;
- professional verification;
- role;
- Location membership.

---

## 3.2 Verification claims

Do not introduce a universal generic verification table in v0.1 merely for architectural symmetry.

Reason:

- Teacher qualification belongs to Learning/provider review.
- Doctor registration belongs to Doctors.
- Driver/vehicle documents belong to mobility.
- Shop existence belongs to Shops.

The shared shell may later consume a small, explicit public trust projection from products.

If cross-product evidence reuse becomes real, design a shared verification service from actual repeated cases rather than a polymorphic generic table now.

---

# 4. Relationship map

`Account`
- has zero/one `AccountLocationPreference`
- has zero/many `AccountCapability`
- has zero/many `LocationStaffAssignment`
- may link to product-owned identities/relationships outside the shared core

`Location`
- has zero/many `LocationProduct`
- has zero/many `LocationStaffAssignment`
- may be selected by many Accounts through preferences

`Product`
- has zero/many `LocationProduct`

`LocationProduct`
- joins exactly one Location and one Product

No Product operational entities point through LocationProduct unless the focused product genuinely needs that reference. The shared shell should not become a mandatory runtime dependency for every domain transaction.

---

# 5. Core invariants

## Identity

1. One authentication subject maps to at most one active Raahi Account.
2. Account does not contain a permanent end-user role.
3. Product role/relationship creation cannot be inferred solely from authentication.
4. Profile completion cannot imply verification.
5. Phone confirmation cannot imply identity/professional verification.

## Location

6. Location slug is globally unique within Raahi.
7. Selected Location is preference/context only.
8. Changing selected Location never grants authority.
9. Changing selected Location never rewrites historical product ownership.
10. A normal public chooser cannot newly select RETIRED Locations.

## Product

11. Product key is unique.
12. One LocationProduct relationship exists per Location + Product.
13. A LocationProduct cannot be normally actionable unless Location is LIVE and Product is ACTIVE.
14. OFF/PREPARING products are not presented as normal live choices.
15. PAUSED products cannot create normal new product activity through the shared entry path.
16. Changing LocationProduct state never destroys focused-product history.

## Administration

17. Platform Admin authority comes only from server-owned capability state.
18. Location Admin authority comes only from active scoped assignment.
19. Location Admin cannot administer another Location through client-controlled identifiers.
20. Location Admin controls cannot grant Platform Admin.
21. Consequential shared admin writes use canonical audited commands.
22. Shared UI never directly mutates authoritative core tables.

## Reliability

23. Consequential shared commands are safe under retry.
24. Same idempotency key with conflicting request fingerprint is rejected.
25. Realtime/client state never overrides newer database truth.
26. Public catalogue responses derive from canonical Location/Product/LocationProduct state.

## Privacy/cost

27. Logged-out Location selection does not require Account creation.
28. Passive public browsing does not require phone collection.
29. Shared core stores no product-sensitive data merely for convenience.
30. OTP plaintext and provider secrets are never persisted/exposed to browser.
31. Shared audit data is minimum necessary and excludes secrets.

---

# 6. Derived public catalogue

The homepage needs a read projection, not raw table access.

Conceptual output:

- selected Location:
  - id
  - name
  - slug
  - public state
- products:
  - key
  - display name
  - short description
  - icon/image reference
  - public state in this Location
  - destination integration metadata
  - optional human availability message

Rules:

- only public-safe fields;
- no provider/user private state;
- deterministic ordering;
- if Location is not available, return truthful state rather than substituting a different city silently.

---

# 7. Shared Account context projection

After authentication, the shell may need:

- Account id
- display name/avatar presentation
- Account lifecycle state
- selected Location preference
- platform capability summary
- Location Admin scopes
- phone-trust summary if needed for shared UX
- profile-onboarding state if retained

It should not fetch every product relationship on every homepage load.

Products may query their own authorized context after entry.

---

# 8. Canonical shared commands

Initial conceptual command set:

### Account
- `update_account_profile`
- `set_selected_location`
- shared Account pause/close only after lifecycle/privacy design is complete

### Platform Admin
- `create_location`
- `set_location_state`
- `create_product` / `update_product_display`
- `retire_product`
- `set_location_product_state`
- `assign_location_admin`
- `end_location_admin_assignment`

### Trust
Phone-trust commands depend on final auth architecture and may adapt the proven Learning StartMessaging flow.

Do not add commands that exist only to edit implementation rows.

---

# 9. State-transition rules

## Location

Allowed normal transitions:

- PREPARING → LIVE
- LIVE → PAUSED
- PAUSED → LIVE
- PREPARING → RETIRED
- LIVE → RETIRED with stronger confirmation/governance
- PAUSED → RETIRED

Disallow normal RETIRED → LIVE resurrection. If ever needed, create an explicit recovery/recreation decision.

## Product

- ACTIVE → RETIRED
- RETIRED is terminal in normal flow

## LocationProduct

- OFF → PREPARING
- OFF → LIVE only if an explicit fast-enable path passes readiness checks
- PREPARING → LIVE
- PREPARING → OFF
- LIVE → PAUSED
- LIVE → OFF only with explicit withdrawal semantics
- PAUSED → LIVE
- PAUSED → OFF

Do not let shared state transitions cancel/invalidate already-created focused-product transactions automatically.

## Account capability

- ACTIVE → REVOKED
- re-grant semantics should retain history rather than rewrite past grant records

## Location staff assignment

- ACTIVE → ENDED
- new later assignment is a new historical row

---

# 10. Important non-entities

The following should **not** become shared entities in v0.1:

- Visitor
- Session Location
- Role
- Teacher
- Driver
- Doctor
- Shop
- Booking
- Ride
- Class
- Appointment
- Order
- Feed
- Notification
- Ad impression
- generic Recommendation
- generic Verification Evidence

Each is either ephemeral, product-owned, or not yet justified.

---

# 11. Architecture implications without choosing technology yet

This domain model requires a shared authority capable of:

- durable Account identity linkage;
- public Location/Product catalogue reads;
- authenticated Account preference/profile commands;
- scoped Platform/Location administration;
- audit/idempotency;
- secure cross-product identity handoff or verification.

It does **not** require all focused products to share one operational database.

The next architecture decision must therefore optimize for:

1. free-tier sustainability;
2. one durable human identity;
3. safe product independence;
4. simple deployment;
5. minimum migration risk to existing live products;
6. no hidden recurring API cost.

---

# 12. Next gate

Before database DDL:

1. define Screen ↔ Backend contracts;
2. evaluate shared-auth/session deployment options;
3. define URL/subdomain integration;
4. test the riskiest technology assumption: whether one authenticated Raahi identity can move from `myraahi.co.in` to a focused product with acceptable UX and free infrastructure;
5. only then freeze physical schema and walking skeleton.
