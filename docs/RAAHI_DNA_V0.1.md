# Raahi DNA v0.1

Last updated: 2026-09-26

Status: **FIRST ARCHAEOLOGY PASS — EVIDENCE-BASED, NOT YET AN IMPLEMENTATION SPEC**

## Purpose

This document extracts reusable product and architecture patterns from existing Raahi repositories before designing the shared `myraahi.co.in` foundation.

The objective is not to merge existing products into one monolith. It is to identify the strongest proven Raahi patterns, preserve product-specific boundaries, and avoid reinventing things already solved well.

Repositories inspected in this pass:

- `rajeevbackup42112-coder/raahi` — branch `raahi-learning-implementation-v1`
- `rajeevbackup42112-coder/raahi-toto` — branch `main`
- `rajeevbackup42112-coder/Where-is-my-Raahi-` — branch `implementation-v1`
- `rajeevbackup42112-coder/schooltransportos` — branch `main`
- `rajeevbackup42112-coder/raahimini` — branch `rocket-staging-ready`

This is a first pass focused on common Raahi foundations: location, identity/authentication, trust/verification, admin scope, public browsing, cost discipline and reusable operating principles.

---

## 1. Strongest cross-project pattern

Raahi repeatedly converges on the same structural idea:

**One reusable platform model + local configuration + product-specific business logic.**

The strongest generic hierarchy emerging from the repositories is:

**Raahi Location → products enabled in that Location → local product rules → user journey**

This appears most explicitly in `raahi-toto/docs/RAAHI3_LOCATION_FIRST_MODEL_V0.1.md`, where Raahi is described as a BookMyShow-style location-first system.

This aligns directly with the current strategic decision for `myraahi.co.in`.

---

## 2. Location should be context, not identity

### Evidence from Raahi Learning

Raahi Learning already implements:

- `locations`
- location lifecycle
- `account_location_preferences`
- `location_staff_assignments`
- Local Manager scope
- Global Platform Admin capability

Relevant files:

- `docs/raahi-learning/00-product-ui-freeze-v1.md`
- `docs/raahi-learning/01-domain-model-v1.md`
- `docs/raahi-learning/19-consolidated-database-blueprint-v1.2.md`
- `docs/raahi-learning/88-gomoh-first-public-launch-model-2026-09-20.md`
- `supabase/migrations/0200_locations_tables.sql`
- `supabase/migrations/0201_account_location_preferences.sql`
- `supabase/migrations/0202_locations_staff_rls_rpcs.sql`

Important proven rule:

> A Raahi Account is not permanently bound to one city/locality.

Selected Location changes local discovery/community context but does not erase identity, history or established relationships.

This should be retained as a core Raahi-wide principle.

### Improvement from Raahi ToTo

Raahi ToTo extends the concept from:

**Location → local content**

to:

**Location → enabled products → product-specific local rules**

Example:

- Gomoh: Local Car ON, Outstation Car ON, ToTo OFF
- Dhanbad: ToTo ON, Local Car ON, Outstation Car ON

This is the best current conceptual model for the shared Raahi homepage.

Relevant file:

- `docs/RAAHI3_LOCATION_FIRST_MODEL_V0.1.md`

---

## 3. Public discovery and authentication boundary

The existing projects contain two different approaches.

### Raahi Learning

Current Learning production was intentionally Google-sign-in-first.

Its V1.3 decision log explicitly deferred logged-out marketplace discovery.

That choice was appropriate for the Learning release at that stage, but it should **not** automatically become the shared Raahi homepage rule.

Relevant files:

- `docs/raahi-learning/07-decision-log-v1.md`
- `docs/raahi-learning/41-authentication-phone-trust-v1.3.md`

### Raahi ToTo

Raahi ToTo contains a cleaner generic product law:

> **Discovery is public. Transactions are authenticated.**

A visitor can choose a Location, see enabled products, enter a journey and understand serviceability before authentication.

Authentication begins only when persistent user-specific transactional state is about to be created.

Relevant file:

- `docs/RAAHI3_BROWSE_AUTH_BOUNDARY_V0.1.md`

This matches the newly agreed `myraahi.co.in` front-door strategy and should be treated as the stronger cross-product pattern.

### Where is my Raahi?

This project goes even further for an ephemeral utility:

- no visible product login
- invisible Supabase anonymous technical ownership
- short-lived operational state
- abuse controls beneath the product UX
- Cloudflare Turnstile prepared for anonymous-session abuse protection

Relevant files:

- `docs/PRODUCT_SPEC_V1.md`
- `docs/ANONYMOUS_AUTH_ABUSE_PROTECTION.md`

Reusable lesson:

> Technical session ownership and visible user-account UX do not have to be the same thing.

Do not force visible identity merely because the backend needs a secure owner for temporary state.

---

## 4. Authentication, trust and authority must remain separate

Raahi Learning has the strongest implementation-proven model here.

Frozen model:

**Google authenticates the Account. Phone OTP proves control of a phone for trust-sensitive actions. Raahi server relationships/capabilities determine authority.**

Relevant files:

- `docs/raahi-learning/41-authentication-phone-trust-v1.3.md`
- `docs/raahi-learning/112-startmessaging-phone-trust-provider-contract-v1.4f.md`
- `docs/raahi-learning/115-startmessaging-phone-trust-activation-contract-v1.4h.md`

Important reusable rules:

1. Google sign-in does not create Teacher/Driver/Admin/etc. authority.
2. Phone OTP is a trust signal, not a role.
3. Phone OTP is not proof of legal identity.
4. Role/authority comes from server-side relationships and scoped capabilities.
5. Trust-sensitive actions may require fresher proof than ordinary browsing/continuation.
6. Existing authorized relationships should not be unnecessarily blocked because a trust signal becomes stale.
7. Provider API keys stay server-side.
8. OTP plaintext is not persisted.

This is a strong foundation candidate for authenticated Raahi products.

---

## 5. Profile onboarding should not be confused with verification

Raahi Learning already distinguishes:

- Google identity/session
- Raahi Account
- editable display name
- optional Google photo suggestion
- profile onboarding completion
- phone trust
- exact verification claims
- product capabilities/relationships

Relevant files:

- `docs/raahi-learning/122-google-profile-confirmation-alignment-contract-v1.4k.md`
- `supabase/migrations/1007_onboarding_account_commands.sql`
- `supabase/migrations/20260923103500_v14k_google_profile_confirmation_alignment.sql`

Reusable principle:

> A completed profile is not a verified person.

The shared Raahi layer should communicate exact facts such as:

- Phone confirmed
- Identity verified
- Qualification verified
- Medical registration verified
- Vehicle documents verified
- Shop existence verified

Avoid a vague generic "Verified" badge.

---

## 6. One Account can have multiple capabilities

Raahi Learning avoids a permanent single `role` field.

Instead it uses:

- Account
- relationships
- scoped capabilities
- Organization memberships
- Location staff assignments

Relevant files:

- `docs/raahi-learning/01-domain-model-v1.md`
- `docs/raahi-learning/19-consolidated-database-blueprint-v1.2.md`

This is preferable for the wider Raahi ecosystem because one person might:

- be a learner/parent in Learning
- own a shop
- drive a vehicle
- manage a local organization
- later become a local admin

Do not force each human into a single platform-wide role.

Product-specific eligibility records can still exist where a lifecycle is materially distinct, e.g. Driver, Teacher Profile, Doctor Profile.

---

## 7. Local admin and global admin are already well understood

Both Raahi Learning and Raahi ToTo converge on:

### Global/Platform Admin

- create/manage Locations
- assign Local Admins
- govern cross-location configuration
- manage platform-level exceptions

### Local Admin

- authority is explicitly scoped to assigned Location(s)
- may manage only local configuration delegated to them
- cannot silently gain cross-city authority
- should not manually override core matching/business invariants

Relevant files:

- `docs/raahi-learning/105-scoped-market-activation-authority-contract-v1.4d.md`
- `docs/raahi-learning/108-global-admin-location-admin-management-contract-v1.4e.md`
- `docs/RAAHI3_ADMIN_UI_CONTRACT_V0.1.md`

Raahi Learning has implementation-proven canonical commands for assigning/removing Local Managers.

This should be strongly considered for reuse.

---

## 8. Product enablement per Location is the missing generic layer

Raahi Learning has Location configuration.

Raahi ToTo has the stronger conceptual notion of products independently enabled per Location.

The wider Raahi front door therefore likely needs a generic concept equivalent to:

- Raahi Product / Module
- Location Product Enablement

Illustrative examples:

- Gomoh + Learning = LIVE
- Gomoh + ToTo = PILOT
- Gomoh + Doctors = OFF
- Dhanbad + Learning = LIVE
- Dhanbad + Doctors = LIVE
- Dhanbad + Shops = PREPARING

This is a **candidate common-layer concept**, not yet a frozen schema.

The homepage should derive visible products from this configuration rather than hardcoding city/product cards.

---

## 9. Product state and Location state should be independent

Raahi ToTo explicitly separates:

- Location lifecycle
- product enablement within Location

That is stronger than one Location state alone.

A Location might be active while one product is paused.

Example:

- Dhanbad Location = ACTIVE
- Learning = LIVE
- ToTo = PAUSED
- Shops = PREPARING

This supports Raahi's "one problem at a time" rollout philosophy.

---

## 10. The strongest architecture pattern across projects

Raahi Learning, Raahi School, Raahi Mini and Where is my Raahi repeatedly converge on:

**UI → authorized reads/projections + canonical commands/RPCs → PostgreSQL authoritative state → Realtime/notifications as derived delivery**

Repeated rules:

- UI does not directly mutate core operational tables.
- Consequential transitions are canonical commands.
- Server state beats stale UI.
- Commands should be idempotent/guarded.
- Important transitions are auditable.
- Realtime invalidates/refetches; it is not the source of truth.
- Historical/business terms should not silently change when current configuration changes.

This is clearly part of Raahi's engineering DNA and should remain.

---

## 11. Cost discipline is already embedded in earlier Raahi products

Raahi School provides a particularly useful example:

- free-tier operation is accepted for pilots/budget-sensitive deployments
- GPS, the fastest-growing data, is aggressively archived/retained
- useful ETA is derived from existing route/trip progress instead of requiring a paid routing API
- precision is reduced truthfully when live data is weak

Relevant files:

- `docs/RAAHI_SCHOOL_BIBLE.md`
- `docs/RAAHI_SCHOOL_DECISION_LOG.md`

Reusable Raahi rule:

> Before adding a paid API, ask whether existing platform data can produce a useful, truthful approximation.

This matches the current Raahi doctrine: paid OTP is acceptable; recurring non-OTP APIs/subscriptions should first be challenged.

---

## 12. Trust and privacy pattern from School Transport

Raahi School reinforces another cross-product rule:

> Visibility should be bound to the user's actual relationship and current need.

Examples:

- parents see only linked children's journey data
- no public fleet browsing
- live vehicle location is active-trip-only
- stale location is never presented as current movement

This is broadly reusable for Doctors, Learning, transport and other sensitive products.

---

## 13. Useful lesson from Raahi Mini: progressive identity

Raahi Mini has already explored:

- unified login
- trusted role routing
- visible display identity
- progressive profile completion
- verified-phone booking gate
- passenger/driver/admin experiences
- anonymous read-only sharing for a specific scoped purpose

Relevant files:

- `docs/RAAHI_MASTER_ARCHITECTURE.md`
- `docs/RAAHI_V2_DECISIONS.md`
- `docs/RAAHI_V2_HANDOVER.md`

Reusable lesson:

> Identity should become stronger as the action becomes more consequential; do not demand maximum identity proof at the first screen.

However, Raahi Mini contains transport-specific role assumptions and should not become the generic shared identity schema without a separate impact review.

---

## 14. Advertising DNA already exists

Raahi Learning already contains a detailed native Sponsored model.

Core rule:

> **Sponsored visibility can be purchased. Trust cannot.**

Relevant file:

- `docs/raahi-learning/06-raahi-ads-v1.md`

Strong reusable ideas:

- clearly label paid visibility as Sponsored
- separate Sponsored placement from organic ranking
- no paid verification
- no hidden behavioral microtargeting
- finite ad inventory so advertiser demand cannot make UX increasingly ad-heavy
- contextual/location targeting
- aggregate analytics, not named viewer lists
- ads excluded from sensitive private product surfaces

The current wider Raahi monetization decision is even narrower: minimal local advertising only to cover survival cost.

The Learning ad architecture is therefore useful as a guardrail library, but the shared Raahi V1 ad implementation should probably be much smaller.

---

## 15. Current best candidate for the shared myraahi.co.in model

### Public shell

`myraahi.co.in`

→ selected Raahi Location

→ **How can Raahi help you today?**

→ products enabled in that Location

→ public discovery/browsing

→ authenticate only at meaningful action

### Shared foundation candidate

1. **Locations**
2. **Raahi Accounts**
3. **Selected Location preference** for signed-in users
4. **Product catalogue**
5. **Location × Product enablement/state**
6. **Global Admin**
7. **Location Admin assignments**
8. **Exact trust/verification claims**
9. **Common audit/idempotency conventions**

### Product-owned data

Keep inside each product:

- Learning Requests, Classes, Tests, etc.
- Ride Requests, Drivers, Vehicles, matching, etc.
- Doctor appointment rules
- Shop catalogue/orders
- other domain-specific lifecycles

Do not pull product-specific operational state into the shared homepage merely for architectural neatness.

---

## 16. Authentication candidate for the common shell

Not yet frozen, but the archaeology suggests a strong default:

### Before meaningful action

No visible login required for ordinary public discovery.

### At meaningful action

Use one Raahi Account.

Existing proven option:

- Google = primary Account authentication
- phone OTP = stronger trust/contact proof for selected consequential actions

This has stronger implementation evidence than using phone OTP as the only permanent identity mechanism.

However, the final common-shell auth decision should explicitly consider:
- users without convenient Google access
- phone-number recovery/account continuity
- OTP operating cost
- cross-product account recovery
- whether certain extremely simple products need only anonymous technical sessions

Do not choose a universal login method merely for consistency if a product safely needs less identity.

---

## 17. Important contradiction resolved by this archaeology

Raahi Learning says logged-out marketplace discovery was deferred.

Raahi ToTo says discovery is public and transactions are authenticated.

The new cross-Raahi decision is:

> For the shared `myraahi.co.in` front door, use the **public discovery / authenticated action** model.

Raahi Learning's existing Google-first entry remains a historical/product-specific implementation choice until deliberately changed.

Do not accidentally treat the Learning login gate as a platform-wide invariant.

---

## 18. What should be reused vs only studied

### Strong reuse candidates

- Location entity/lifecycle principles from Learning
- Account + capabilities/relationships model from Learning
- selected-location preference pattern
- Local Manager scoped assignment model
- platform/global admin separation
- Google profile confirmation concepts
- phone trust model and secure OTP provider boundary
- canonical command / idempotency / audit conventions
- location-first product enablement concept from ToTo
- public-discovery/authenticated-action rule from ToTo
- abuse-control concepts from Where is my Raahi
- cost/retention discipline from School Transport

### Study, but do not blindly reuse

- product-specific Learning roles/flows
- ToTo matching/domain model
- Raahi Mini single-operational-role assumptions
- School's one-school-per-deployment isolation model
- anonymous sessions from Where is my Raahi for products requiring durable user relationships
- full Raahi Learning Ads engine for the first shared homepage

---

## 19. Proposed next archaeology step

Before implementing the shared shell:

1. inspect actual frontend routing/auth/profile/location code in Raahi Learning
2. inspect actual Location/Product UI code in Raahi ToTo
3. inspect exact account/auth patterns in Raahi Mini and School where useful
4. identify code that is reusable as-is versus concepts that should be reimplemented cleanly
5. inspect Naresh's local platform separately for local-content/community patterns
6. only then freeze the `myraahi.co.in` shared-shell product spec and database contract

No production/application code should be modified during this archaeology stage.

---

## 20. Current Raahi DNA summary

The strongest current formulation is:

> **Raahi is a location-first family of focused products. A user should first see what genuinely works in the selected place, receive value before unnecessary authentication, use one durable Raahi identity when persistent state is needed, build trust progressively according to the action, and encounter product-specific logic only inside the relevant product.**

Engineering underneath should stay:

> **configuration over forks, canonical server commands over direct mutation, exact scoped authority over generic roles, truthful trust claims over vague badges, and free/lean infrastructure over unnecessary paid dependencies.**
