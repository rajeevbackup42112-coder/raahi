# MyRaahi Shared Front Door — Gate 1 Actor Catalogue v0.1

Last updated: 2026-09-26

Method: AI Builder Cheat Code v2.0 — Gate 1

Scope: shared `myraahi.co.in` front door and common identity/location foundation only.

A product-specific actor such as Teacher, Driver, Doctor, Shop Owner, Parent, Guardian or Passenger remains owned by the relevant focused product unless the shared shell genuinely needs that actor context.

---

## 1. Human actors

### 1.1 Visitor

**Goal**
- Understand what Raahi can help with in a selected locality before creating/signing into an account.

**Can initiate**
- choose/change Location;
- view the public local product catalogue;
- enter public discovery surfaces of focused products;
- begin an action that may later require authentication.

**Can see**
- public Locations;
- public Product availability for selected Location;
- public-safe Product summaries;
- public-safe Sponsored content later.

**Must never see/do**
- private Account data;
- admin configuration;
- other users' private history;
- provider evidence documents;
- trust/admin controls;
- direct database identifiers as required input;
- consequential writes without the required authenticated/product authority.

**Multi-context**
- same human may later become a Raahi Account without losing the current public journey context.

---

### 1.2 Raahi Account holder

**Goal**
- Use Raahi across one or more focused products with one durable human identity and retained preferences/trust state.

**Can initiate**
- account/profile updates;
- authenticated product actions delegated to focused products;
- selected Location preference update;
- phone-trust verification when required;
- sign-out/account recovery flows once designed.

**Can see**
- own shared Account context;
- own selected Location;
- own exact trust claims that are shared;
- own platform/admin scopes if any;
- public catalogue.

**Must never see/do**
- infer product/provider authority merely from being authenticated;
- edit server-owned trust/admin capability directly;
- access another Account's private context;
- create product-specific authority from a client-side role choice.

**Multi-context**
- same Account may be learner, parent, teacher, driver, shop owner, etc. in different focused products;
- same Account may also hold Location Admin or Platform Admin authority;
- actor context must be explicit when consequences differ.

---

### 1.3 Product participant

This is a generic shared-shell reference to an Account holder who is acting inside one focused product.

Examples:
- learner/parent/teacher in Learning;
- passenger/driver in Mobility;
- patient/provider in Doctors;
- customer/shop owner in Shops.

**Goal**
- Complete a product-specific need after entering from the shared shell.

**Can initiate / see / must never see**
- defined by the focused product's own business rules and authority model.

**Shared-shell rule**
- MyRaahi may route and identify the Account/Location context;
- MyRaahi does not manufacture product authority.

**Multi-context**
- same human may be a participant in multiple products and multiple actor contexts inside a product.

---

### 1.4 Location Admin

**Goal**
- Operate only the delegated shared Raahi configuration for assigned Location(s).

**Can initiate**
- location-scoped configuration actions explicitly delegated by Platform Admin/product contract;
- potentially LocationProduct state/configuration changes once final authority matrix permits.

**Can see**
- assigned Location shared configuration;
- public catalogue state;
- local admin information required to perform delegated actions;
- audit evidence relevant to own permitted scope if later exposed.

**Must never see/do**
- manage other Locations without assignment;
- grant Platform Admin;
- alter unrelated product-domain operational data through shared shell;
- grant themselves additional scope;
- infer authority from selecting a Location.

**Multi-context**
- may simultaneously be ordinary Raahi user/product participant.

---

### 1.5 Platform Admin

**Goal**
- Govern shared Raahi foundation safely across all Locations.

**Can initiate**
- create/manage Locations;
- create/manage shared Product registry;
- configure Location × Product availability;
- assign/end Location Admin authority;
- platform governance and exceptional shared corrections.

**Can see**
- shared platform configuration across Locations;
- necessary audit/history for shared governance;
- Account lookup data only when needed for admin assignment/support and permitted by privacy design.

**Must never see/do**
- bypass focused-product business invariants merely because they are Platform Admin;
- silently rewrite accepted historical product decisions;
- use paid promotion to create trust/verification;
- edit raw production tables through ordinary UI.

**Multi-context**
- Platform Admin may also be a normal user/provider, but admin actions require explicit admin context and server authority.

---

### 1.6 Raahi operator/support person (future, not yet enabled)

**Goal**
- Help diagnose shared-shell issues without full Platform Admin power.

**Status**
- candidate future actor only.

**Rule**
- do not create a generic support role until real support scenarios prove what read/write authority is required.

---

## 2. System actors

### 2.1 MyRaahi Shared Shell

**Goal**
- Present the correct public Location/Product catalogue and route the human to the correct focused product.

**Can initiate**
- public read requests;
- safe navigation/deep-link handoff;
- authenticated shared commands only on explicit human intent once auth exists.

**Can see**
- public catalogue projections;
- authenticated Account context only when session/authorization permits.

**Must never do**
- invent availability;
- infer admin/provider authority from UI state;
- silently select a different Location against explicit user choice;
- directly mutate authoritative tables from browser code;
- expose secrets or cross-product private data.

---

### 2.2 Shared Foundation Backend

This may be implemented through Worker/D1 plus future identity components, but actor definition is logical, not technology-specific.

**Goal**
- enforce shared Raahi rules for Location, Product availability, Account context, admin scope, audit and idempotency.

**Can initiate**
- server-side validation;
- authoritative reads/writes;
- audit entries;
- derived projections.

**Can see**
- only shared-core state required for its purpose.

**Must never do**
- become authoritative for product-owned domain transitions;
- accept client-asserted authority/trust as truth;
- silently mutate focused-product state.

---

### 2.3 Focused Product

Examples:
- Raahi Learning;
- Raahi ToTo/Mobility;
- future Doctors;
- future Shops.

**Goal**
- own and enforce its product-specific business lifecycle.

**Can initiate**
- its own reads, commands, side effects and product-level auth/trust checks.

**Can see**
- shared Location/Account context only through explicitly supported integration;
- its own domain data according to its own authority model.

**Must never do**
- assume a selected Location grants product authority;
- trust unsigned/unvalidated shell hints as authoritative;
- alter shared Product/Location configuration outside the shared admin boundary.

---

### 2.4 Authentication provider

Current candidate evidence: Google/Supabase Auth or a future proven shared identity mechanism.

**Goal**
- prove possession/control of an authentication identity and establish a technical session.

**Can initiate**
- OAuth/authentication protocol events.

**Can see**
- authentication data required by provider contract.

**Must never do**
- decide Raahi provider roles;
- decide Location Admin authority;
- decide professional verification;
- decide product business authority.

---

### 2.5 OTP verification provider

**Goal**
- deliver/verify a phone challenge when a Raahi rule requires phone trust.

**Can initiate**
- send OTP;
- return provider verification result.

**Can see**
- minimum phone/challenge data required by provider.

**Must never do**
- become Raahi's role/identity/authority system;
- expose provider secrets to browser;
- cause Raahi to claim legal/professional identity verification merely because a phone challenge succeeded.

---

### 2.6 Browser/local storage

**Goal**
- retain lightweight logged-out selected-Location preference and safe temporary UI context.

**Can initiate**
- none independently; stores/returns browser state.

**Can see**
- minimal non-sensitive public journey data.

**Must never store**
- authoritative roles;
- verification timestamps as truth;
- admin capability;
- secrets/tokens in unsafe plaintext;
- sensitive product drafts without an explicit design.

---

### 2.7 Cloudflare edge/runtime

Current proposed shell hosting/runtime.

**Goal**
- serve shell assets/API and execute configured Worker/D1 access.

**Can initiate**
- platform/runtime execution, caching and request handling according to code/config.

**Must never be treated as**
- product authority merely because an action originates at the edge.

External platform behavior remains a technology assumption until staging proof.

---

### 2.8 Shared configuration datastore

Current proposed first-shell implementation: D1.

**Goal**
- hold authoritative public-shell configuration in the isolated first architecture.

**Owns in first shell**
- Locations;
- Products;
- LocationProducts;
- configuration audit/versioning as designed.

**Must never own by default**
- Learning Classes;
- rides;
- appointments;
- orders;
- professional verification documents;
- arbitrary focused-product operational data.

---

## 3. External/non-Raahi actors

### 3.1 Local advertiser / sponsor (deferred)

**Goal**
- pay for limited useful local sponsored visibility.

**Status**
- business actor acknowledged, but ad self-service is out of V1 shared-shell scope.

**Must never gain**
- verification;
- organic rank privilege;
- admin authority;
- access to named user/private behavior simply through sponsorship.

---

### 3.2 Future external integration/provider

Examples:
- maps/geocoding;
- email;
- analytics;
- AI.

**Rule**
- each external service becomes a system actor only after a real product need and technology/evidence gate.
- recurring paid non-OTP dependency requires explicit exception review.

---

## 4. Actor distinctions that are frozen

1. Visitor ≠ Account.
2. Account ≠ role.
3. Authentication provider ≠ Raahi authority.
4. Phone confirmation ≠ identity/professional verification.
5. Selected Location ≠ local membership/admin authority.
6. Product participant ≠ shared-platform capability.
7. Location Admin ≠ Platform Admin.
8. Platform Admin ≠ omnipotent focused-product business actor.
9. Shared Shell ≠ focused product.
10. Browser state ≠ authoritative server state.

---

## 5. Gate 1 result

**PASS**, subject to change control.

No unresolved business decision is required to identify the actors for the current shared-front-door scope.

Next gate: **Gate 2 — Decision ownership and authority matrix**.
