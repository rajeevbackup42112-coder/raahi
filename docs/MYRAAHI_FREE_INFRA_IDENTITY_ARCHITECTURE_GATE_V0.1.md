# MyRaahi Shared Foundation — Free Infrastructure & Identity Architecture Gate v0.1

Last updated: 2026-09-26

Status: **ARCHITECTURE DECISION GATE — RECOMMENDED PHASED PATH, IDENTITY SSO NOT YET FROZEN**

Parent documents:
- `MYRAAHI_SHARED_FRONT_DOOR_PRODUCT_CONTRACT_V0.1.md`
- `MYRAAHI_SHARED_FOUNDATION_DOMAIN_MODEL_V0.1.md`
- `MYRAAHI_SHARED_FRONT_DOOR_SCREEN_BACKEND_CONTRACTS_V0.1.md`

## 1. Hard constraints

- Raahi remains free for users.
- Prefer free tiers/open source.
- Recurring paid APIs/subscriptions are not acceptable by default.
- Paid OTP is acceptable.
- `myraahi.co.in` is already owned.
- Existing live products must not be destabilized merely to create the shared shell.
- Raahi Learning already has real production users/data and must be treated as non-disposable.
- Shared identity is a long-term goal, but a risky auth migration must not block proving the public Location-first shell.

---

## 2. Current official free-tier facts checked 2026-09-26

### Cloudflare Workers Free

Current documentation reports:
- 100,000 requests/day
- 10 ms CPU per invocation
- custom-domain routing supported

This is sufficient for a small-town public shell if endpoints remain lightweight.

### Cloudflare D1 Free

Current documentation reports:
- 5 million rows read/day
- 100,000 rows written/day
- 5 GB total storage
- free daily limits are actively enforced as of September 2026

This is far above expected initial shared-shell configuration traffic.

### Supabase Free

Current pricing reports:
- 50,000 monthly active users
- 500 MB database
- 1 GB file storage
- 5 GB egress
- maximum 2 active Free projects
- free projects may pause after inactivity

The 2-project limit makes creating a new Supabase project for every Raahi product/foundation a poor long-term default.

### Auth.js

Auth.js remains free/open source and supports OAuth providers, but cross-subdomain Raahi SSO on the intended Cloudflare/product topology has not yet been proven in our environment.

Do not choose it solely because it is open source.

---

# 3. Architecture options

## Option A — Put the shared core inside Raahi Learning's existing Supabase project

### Shape

`myraahi.co.in`
→ shared tables/API inside current Learning Supabase
→ current Supabase Auth identity
→ Learning remains in same backend
→ future products integrate with this shared project where practical

### Advantages

- strongest reuse of proven Learning Account/Location/admin/phone-trust backend;
- no additional Supabase project;
- existing Google identities remain aligned;
- PostgreSQL/RLS/RPC model already proven;
- fewer technologies.

### Risks

- shared platform becomes coupled to an already-live focused product;
- mistakes in new migrations/RLS can affect Learning production;
- public shell traffic/config and Learning operational data share quotas/failure domain;
- existing Learning frontend session is product-origin-specific;
- cross-subdomain SSO is not automatically solved merely because the same Supabase project is used;
- future product independence may weaken.

### Classification

**Technically plausible, but too risky to make the first move directly in production.**

Use only after a non-production proof and migration-impact review.

---

## Option B — Cloudflare Worker + D1 for the shared public core; keep existing product auth initially

### Shape

`myraahi.co.in`
→ Cloudflare Worker/static assets
→ D1 shared shell configuration:
  - Locations
  - Products
  - LocationProducts
  - later shared admin/audit as architecture matures

Focused product entry:
→ `learning.myraahi.co.in`
→ existing Learning auth/backend unchanged initially

Other products remain independently hosted.

### Advantages

- no new paid subscription;
- no new Supabase project;
- isolates the new shell from live Learning;
- ideal for tiny read-heavy configuration data;
- custom domain fits existing Raahi domain strategy;
- public Location/Product catalogue can be proven without touching product databases;
- makes rollback simple because focused products remain unchanged.

### Risks

- shared Account/auth is not solved on day one;
- D1 + Supabase creates a multi-database architecture if later identity uses Supabase;
- Platform/Location Admin auth must eventually be integrated safely;
- product-health/readiness synchronization must be explicitly designed.

### Classification

**Best first walking-skeleton architecture for the public shell.**

It proves the highest-value user journey with the lowest production risk.

---

## Option C — New central open-source auth + D1 shared core from day one

Possible candidate class:
- Auth.js or another maintained open-source authentication framework
- Google OAuth
- D1/database-backed Account/session state
- Raahi-controlled cross-subdomain session design
- custom OTP trust integration later

### Advantages

- Raahi identity becomes independent of any focused product backend;
- potentially clean cross-product architecture;
- avoids Supabase project-count constraint;
- no auth SaaS subscription required if self-hosted.

### Risks

- new security-critical infrastructure;
- existing Learning identities must be linked/migrated;
- existing products need adapters;
- cross-subdomain cookie/session behavior must be proven;
- phone trust/provider integration must be rebuilt;
- increases implementation burden before public-shell value is proven.

### Classification

**Potential long-term candidate, not justified as the first implementation step.**

Technology attractiveness is not sufficient reason to rewrite proven authentication.

---

# 4. Recommended phased architecture

## Phase 0 — Public shell walking skeleton

Use:

- Cloudflare Worker/static assets at `myraahi.co.in`
- D1 for public shared configuration
- no required shell login
- Location choice in browser state
- Product entry links to existing focused products
- explicit Location context passed safely to the product
- no production product database migration

Minimum D1 scope:

- Locations
- Products
- LocationProducts
- SharedAuditEvent only if admin mutation is included in the walking skeleton
- admin identity can initially be a tightly controlled development/test gate during the spike; final auth architecture must replace it before production admin use

Goal:

Prove:
- Gomoh/Dhanbad selector
- different product catalogue by Location
- product state changed by configuration without frontend redeploy
- safe deep-link to Learning carrying Location context
- mobile/desktop UX

This delivers the visible Raahi front door without risking Learning.

---

## Phase 1 — Identity SSO technology spike

Before implementing a shared Raahi Account broadly, run an isolated technical proof using non-production subdomains.

Suggested lab:

- `auth-lab.myraahi.co.in`
- `product-lab.myraahi.co.in`

Test at least two approaches:

### Spike A — Existing Supabase Auth as identity authority

Prove:
- Google OAuth
- parent/sibling-subdomain session handoff strategy
- safe return path
- Account identity continuity
- refresh/expiry/logout
- no exposure of refresh secrets to unsafe browser surfaces
- product adapter feasibility

This should use a safe non-production environment/config and must not mutate Learning production identity behavior.

### Spike B — Open-source central auth candidate

Only if Spike A proves awkward/unsafe.

Prove the same scenarios with the candidate framework before considering migration.

Decision criterion:

Choose the simplest architecture that:
- produces one durable Raahi identity;
- works across Raahi-owned subdomains;
- stays free at pilot scale;
- can be secured and tested;
- does not require dangerous product rewrites;
- allows phone trust separately.

---

## Phase 2 — Shared Account/admin core

Only after SSO architecture is proven:

Add to shared core:
- Account
- selected Account Location preference
- Platform Admin capability
- LocationStaffAssignment
- audit/idempotency
- phone trust integration if shared

Then integrate one focused product as the first identity consumer.

Recommended first consumer:
- Raahi Learning, because its Account/Location/trust model already has the strongest evidence.

Do not integrate all products simultaneously.

---

# 5. Why D1 is appropriate for the public shell but not automatically for every Raahi product

D1 is attractive for:
- tiny configuration tables;
- read-heavy public catalogue;
- local admin configuration;
- audit at modest volume;
- zero-idle-cost shell infrastructure.

Do not automatically migrate:
- Learning relational operational model;
- complex transport matching;
- existing Postgres/PostGIS workloads;
- systems that depend on mature Postgres RLS/RPC semantics.

Use the right data engine for the problem.

"Free" is not a reason to migrate working products.

---

# 6. Public shell failure model under free limits

Cloudflare's Free plan now enforces daily D1 limits.

Therefore:

- index Location/Product queries;
- avoid full scans;
- cache the public catalogue aggressively where safe;
- keep public shell writes extremely rare;
- degrade with a truthful cached catalogue if a safe cache strategy is implemented;
- monitor free-limit usage;
- never silently produce false product availability if fresh state cannot be confirmed.

At Gomoh pilot scale, limits should be generous, but the system must treat limit exhaustion as a real failure mode rather than assuming infinite free capacity.

---

# 7. Decision currently frozen

### Freeze now

**The first MyRaahi walking skeleton should isolate the shared public shell on Cloudflare Worker + D1 and should not modify the live Learning backend merely to launch the front door.**

### Not frozen yet

The final cross-product Account/SSO implementation.

That must be selected only after the identity technology spike.

---

# 8. Walking skeleton success criteria

A successful first skeleton proves:

1. `myraahi.co.in` loads on mobile and desktop.
2. no login required for first value.
3. Location can be selected manually.
4. Gomoh and Dhanbad can expose different configured Product catalogues.
5. changing Location updates the catalogue.
6. an admin/config change can make a Product LIVE/PAUSED/OFF without rebuilding frontend code.
7. Learning can be entered with the intended Location context.
8. returning from the Product can restore the Raahi Location context.
9. no existing Learning production business data/auth behavior was changed.
10. shell survives ordinary refresh/back/forward navigation.
11. free-tier usage remains negligible and observable.

After this proof, run the SSO spike before adding shared Account-dependent features.

---

# 9. Explicitly rejected shortcuts

Do not:

- create a third/new Supabase project just because it is familiar;
- move all products into D1;
- move all product tables into Learning's production database immediately;
- invent custom authentication cryptography;
- expose D1 administrative APIs directly to browsers;
- use a static hard-coded city/product list as final production truth;
- make AI the routing layer;
- require OTP to view the homepage;
- migrate all existing users before SSO is proven.

---

# 10. Next technical design step

Define the physical D1 schema and Worker API for the **public-shell walking skeleton only**.

Keep Account/SSO tables out of the first physical schema until the identity spike decides where shared identity should live.

This is an intentional sequencing choice, not abandonment of the common Account product contract.
