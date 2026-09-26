# Shared Raahi Foundation Reuse Matrix v0.1

Last updated: 2026-09-26

Status: **ARCHAEOLOGY OUTPUT — REVIEW BEFORE SHARED-SHELL IMPLEMENTATION**

## Purpose

This matrix answers one question:

> For the planned shared `myraahi.co.in` foundation, what should be reused from existing Raahi work, what should be adapted, what should remain concept-only, and what should be rejected as shared-platform code?

Classification:

- **REUSE/ADAPT** — implementation is mature enough to become a starting point, with explicit extraction/refactoring.
- **ADAPT PATTERN** — implementation pattern is useful, but code should be rewritten or isolated for the new shell.
- **CONCEPT ONLY** — product rule/UX model is strong, but current code is prototype/product-specific.
- **CONDITIONAL** — useful only for particular products/surfaces.
- **REJECT AS SHARED CORE** — valid in its original product but would damage the common Raahi model if generalized.

---

| Capability | Best existing source | Classification | Why | Main dependency / risk |
|---|---|---|---|---|
| Location entity + lifecycle | Raahi Learning migrations/docs | **REUSE/ADAPT** | Implemented relationally with lifecycle, auditability and server-owned commands. Already proven with Gomoh/Dhanbad. | Learning state names may need normalization for platform-wide use. |
| Selected Location preference | Raahi Learning | **REUSE/ADAPT** | Cleanly separates selected local context from Account identity/history. | Public visitors need a pre-auth location mechanism in addition to signed-in preference. |
| Location switching principle | Raahi Learning | **REUSE/ADAPT** | Proven rule: switching Location changes discovery context, not existing relationships/history. | Each product must define which surfaces are location-scoped. |
| Product catalogue | None complete | **NEW CLEAN IMPLEMENTATION** | Existing products know only their own domain. Shared shell needs a small generic Raahi product registry. | Avoid turning it into a plugin framework prematurely. |
| Location × Product enablement | Raahi ToTo location-first model | **CONCEPT ONLY → NEW IMPLEMENTATION** | This is the strongest existing model for BookMyShow-style Raahi. | Current ToTo implementation is hard-coded demo JS, not production code. |
| Product state per Location | Raahi ToTo | **CONCEPT ONLY → NEW IMPLEMENTATION** | Enables Learning LIVE while ToTo PAUSED/Doctors PREPARING in same city. Essential to one-problem-at-a-time rollout. | Need simple states; do not invent excessive lifecycle. |
| Shared public homepage | No production implementation | **NEW CLEAN IMPLEMENTATION** | Existing frontends are product-specific; none should become `myraahi.co.in` by inheritance. | Must remain simple and location-first. |
| Public browsing before login | Raahi ToTo product law | **ADAPT PATTERN** | “Discovery is public. Transactions are authenticated.” matches current cross-Raahi decision. | Each product must define its exact consequential-action boundary. |
| Preserve draft across authentication | Raahi ToTo browse/auth contract + Raahi Mini OAuth resume work | **ADAPT PATTERN** | User should not lose entered context when login is triggered at final action. | Requires safe draft serialization and open-redirect protection. |
| Account identity | Raahi Learning | **REUSE/ADAPT** | Strong distinction between Auth user and Raahi Account; avoids tying identity to one product role. | Shared Account schema must be extracted without Learning-specific fields. |
| One Account, multiple capabilities | Raahi Learning | **REUSE/ADAPT** | Correct for ecosystem where same human may learn, teach, drive, own a shop, etc. | Product-specific capability/relationship tables still needed. |
| Permanent single global role | Raahi Mini / some School flows | **REJECT AS SHARED CORE** | Useful in narrower products, but too restrictive for wider Raahi ecosystem. | Role routing can remain product-local where appropriate. |
| Google OAuth as account sign-in | Learning + School + Mini | **ADAPT PATTERN** | Proven repeatedly; low-friction and mature. School/Mini have cleaner Next.js plumbing; Learning has stronger identity semantics. | Do not force login before public discovery. Need recovery/fallback decision later. |
| OAuth callback/cookie handoff | Raahi Mini | **ADAPT PATTERN** | Modern server-side callback handles code exchange, safe return path and cookie commit before navigation. | Must be rebuilt for final hosting/origin and audited for redirects. |
| Profile confirmation | Raahi Learning | **REUSE/ADAPT** | Separates editable Raahi profile from Google metadata; Google photo is opt-in. | Current Learning frontend is retrofit-heavy; reuse backend semantics, not UI code. |
| First-use intent | Raahi Learning | **ADAPT PATTERN** | “What brings you here today?” is guidance, not role/authority. Good principle. | On shared homepage, public product choice may make a separate intent screen unnecessary. |
| Phone trust | Raahi Learning + StartMessaging contracts | **REUSE/ADAPT** | Most mature trust model: phone proof separate from login and authority, fresh/stale/unverified, server-side provider boundary. | Exact common-shell trust-sensitive actions must be defined; OTP cost must stay controlled. |
| Phone as primary permanent login | Older Mini/ToTo concepts | **DO NOT DEFAULT PLATFORM-WIDE** | OTP-only login can simplify some flows but raises cost/account-recovery/identity-linking concerns. | May remain valid for specific products/users if evidence requires it. |
| Phone number normalization UX | Raahi Mini | **ADAPT PATTERN** | Existing code handles Indian +91 normalization. | Must validate robustly server-side; UI convenience is not authority. |
| Exact verification claims | Raahi Learning | **REUSE/ADAPT** | Prevents vague “Verified” claims; trust can state Identity/Qualification/etc. precisely. | Shared claim taxonomy must stay small and product-aware. |
| Provider verification lifecycle | Product-specific | **CONDITIONAL / PRODUCT OWNED** | Teacher, Driver, Doctor, Shop each require different evidence and review. | Do not centralize every provider workflow into one generic table prematurely. |
| Global Platform Admin | Raahi Learning | **REUSE/ADAPT** | Proven unscoped platform capability. | Bootstrap remains security-sensitive. |
| Location Admin assignment | Raahi Learning | **REUSE/ADAPT** | Strong implementation with explicit scoped assignment, audited canonical commands and no cross-city leakage. | Naming may change from Local Manager to Location Admin in common shell. |
| Admin market/product configuration UX | Raahi ToTo | **CONCEPT ONLY** | Excellent mental model: health, enabled products, local policy, scoped authority. | Current code is UI-only demo; implement against canonical backend later. |
| Canonical commands/RPCs | Learning + School + Where is my Raahi + Mini | **REUSE ENGINEERING PATTERN** | Repeatedly proven to prevent stale UI/direct-table mutation problems. | Need disciplined API surface, not excessive RPC proliferation. |
| Idempotency | Raahi Learning / transport projects | **REUSE ENGINEERING PATTERN** | Consequential actions must tolerate retry/double submit. | Shared command envelope should be simple and standardized. |
| Audit log | Raahi Learning / transport projects | **REUSE/ADAPT** | Needed for admin, trust, safety and consequential configuration. | Avoid logging sensitive payloads unnecessarily. |
| PostgreSQL as source of truth | All mature Raahi products | **REUSE ENGINEERING LAW** | Strong cross-project convergence. | None beyond normal scalability discipline. |
| Realtime as invalidation/refetch | Learning + School | **REUSE ENGINEERING LAW** | Avoids treating realtime delivery as canonical truth. | Not every shell feature needs realtime. |
| Anonymous technical session | Where is my Raahi | **CONDITIONAL** | Excellent for ephemeral state without visible login. | Supabase anonymous users create durable Auth rows; abuse/cleanup must be considered. |
| Turnstile/bot protection | Where is my Raahi | **CONDITIONAL / ADAPT** | Useful when anonymous session creation or abuse-prone public writes exist. | Do not add CAPTCHA to ordinary passive browsing. |
| Public read-only sharing tokens | Raahi Mini | **CONDITIONAL** | Useful pattern for narrowly scoped temporary sharing without account creation. | Requires expiry/revocation and minimal disclosure. |
| Cost-aware derived functionality | Raahi School | **REUSE PRODUCT/ENGINEERING LAW** | Demonstrated useful ETA without paid routing API by deriving from existing facts. | Approximation must be labelled truthfully. |
| Data retention/archive discipline | Raahi School / Where is my Raahi | **ADAPT PATTERN** | Important for GPS/ephemeral high-volume data and free-tier survival. | Retention policy is domain-specific. |
| Native Sponsored rules | Raahi Learning Ads | **ADAPT GUARDRAILS** | Strong separation of paid visibility from trust/organic ranking. | Full Learning Ads engine is too heavy for initial common shell. |
| Full ad inventory/revision engine | Raahi Learning Ads | **DEFER / CONCEPT ONLY** | Mature but beyond survival-scale ads needed initially. | Complexity and operations cost. |
| Frontend code from Raahi Learning | `apps/raahi-learning` retrofit bundle | **DO NOT REUSE AS SHARED SHELL** | Current production frontend is reconstruction/patch/DOM-retrofit heavy and tied to Learning routes. | High coupling and maintenance burden. |
| Frontend code from Raahi ToTo | `app-1.js`…`app-4.js` | **DO NOT REUSE AS PRODUCTION CORE** | Hard-coded UI prototype. Great UX evidence, not production architecture. | No real backend/auth/data model. |
| Modern auth/session plumbing | Raahi School / Raahi Mini | **ADAPT PATTERN** | Cleaner Next.js/Supabase code than Learning’s retrofit frontend. | Their role/onboarding rules are product-specific; do not copy those semantics. |
| Separate deployment/database per local unit | Raahi School | **REJECT AS DEFAULT RAAHI-WIDE MODEL** | Correct for school tenancy/privacy, but conflicts with Raahi’s cross-location identity and shared shell. | Keep for products where legal/tenant isolation truly requires it. |

---

## Recommended shared-foundation build posture

The archaeology does **not** support choosing one existing repository as the base and renaming it to Raahi.

The evidence supports assembling a clean shared shell from proven pieces:

### Reuse/adapt from Raahi Learning backend

- Account identity semantics
- Locations
- selected Location preference
- scoped Location Admin authority
- Platform Admin authority
- profile confirmation semantics
- phone-trust model
- exact verification claims
- audit/idempotency/canonical-command conventions

### Rebuild cleanly from Raahi ToTo product concepts

- Location-first home
- Location × Product enablement
- product state per Location
- public discovery / authenticated action
- local product configuration mental model

### Borrow implementation plumbing selectively

From Raahi Mini / School:
- modern Next.js + Supabase OAuth/session patterns
- safe callback/resume patterns
- mobile phone-number UX patterns

### Use conditionally

From Where is my Raahi:
- anonymous technical sessions
- Turnstile abuse protection
- ephemeral-state privacy/TTL patterns

### Keep product-owned

- Learning domain
- mobility matching
- school operations
- doctor credentials/appointments
- shop inventory/orders
- other product-specific rules

---

## Candidate minimum shared data model — NOT YET FROZEN

The smallest plausible shared Raahi layer is:

### `accounts`

Durable Raahi human account linked to authentication identity.

### `locations`

Named Raahi operating/discovery location with lifecycle/configuration.

### `account_location_preferences`

Selected Location for authenticated users.

For logged-out users, selected Location can initially be client/session state rather than requiring an Account.

### `products`

Small registry such as:
- learning
- toto / mobility
- doctors
- shops
- local

This should describe the Raahi capability, not hold its domain data.

### `location_products`

Configuration for whether a product exists in a Location and its public rollout state.

Possible initial states should stay minimal, e.g.:
- preparing
- live
- paused

Do not add more without a real scenario.

### `account_capabilities`

Only genuinely platform-level capabilities.

### `location_staff_assignments`

Scoped local administration.

### verification/trust

Prefer exact claim/evidence models; do not force every product’s provider review into one over-generalized workflow until scenarios are mapped.

### audit/idempotency

Shared conventions for consequential platform commands.

---

## Candidate homepage read model

The first public request to `myraahi.co.in` should need very little data:

1. public live/selectable Locations
2. selected Location
3. public products enabled for that Location
4. small display metadata for each product:
   - name
   - short human description
   - icon/image reference
   - destination URL/path
   - current public state
5. optional minimal Sponsored local unit later

No authentication should be necessary merely to answer:

> “What can Raahi help me with in Gomoh?”

---

## Key implementation warning

Do not create the shared shell by moving all existing product databases into one schema.

The common layer should know **that Raahi Learning is live in Gomoh**, not the internal state of every Class or Learning Request.

Likewise it should know **that ToTo is available in Dhanbad**, not own the ride matcher.

Integration should begin with identity/location/navigation boundaries and only deepen when a real cross-product journey requires it.

---

## Next gate

Before coding the common shell, freeze:

1. exact public homepage journey
2. Location lifecycle used by the shared shell
3. Product registry semantics
4. Location × Product lifecycle
5. anonymous vs authenticated selected-Location persistence
6. common Account/auth strategy
7. cross-product sign-in/session behavior
8. minimal shared verification vocabulary
9. Global vs Location Admin authority
10. how product URLs/subdomains integrate with the common shell

Then define:

- entities/relationships
- states/invariants
- Given/When/Then scenarios
- Screen ↔ Backend contracts
- database/RPC blueprint
- walking skeleton

Only after those gates should implementation begin.
