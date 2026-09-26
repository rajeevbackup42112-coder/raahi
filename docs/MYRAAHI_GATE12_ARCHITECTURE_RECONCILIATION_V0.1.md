# MyRaahi Shared Front Door — Gate 12 Architecture Reconciliation v0.1

Last updated: 2026-09-26

Method: AI Builder Cheat Code v2.0 — Gate 12

Status: **LOGICAL ARCHITECTURE PASS; PHYSICAL TECHNOLOGY CHOICES REMAIN SUBJECT TO GATE 13 PROOF**

Scope: shared MyRaahi front door and common identity/location foundation.

---

# 1. Architecture law

For consequential shared actions:

> UI expresses intent → canonical shared command validates current identity/authority/state → authoritative datastore commits the valid transition → read projection renders current truth → cache/realtime only assists delivery.

For focused-product actions:

> Shared shell routes/contextualizes → focused Product validates and owns its own transaction.

---

# 2. Authority/source-of-truth boundaries

## Shared public configuration

Authoritative concepts:
- Location
- Product
- LocationProduct

Current candidate physical authority:
- isolated shared configuration datastore (D1 candidate).

The browser is never authoritative for:
- Location lifecycle;
- Product availability;
- Product destination allowlist.

## Shared Account identity

Logical authority:
- one durable Raahi Account plus authenticated identity linkage.

Physical authority:
- **NOT YET FROZEN**.

Must be proven at Gate 13.

## Focused-product operational state

Authoritative source:
- each focused Product’s own backend/database according to its existing architecture.

Examples:
- Learning classes/requests/tests remain Learning-owned;
- ride matching/vehicle state remains Mobility-owned.

Shared shell does not become a write-through operational database.

---

# 3. Command boundary

## Public shell V0

No public consequential write API required.

Allowed:
- public catalogue reads;
- browser-local selected Location preference.

## Future authenticated shared commands

Canonical commands include:
- set selected Account Location;
- update own shared profile;
- shared phone-trust commands;
- Platform Admin Location/Product operations;
- Location Admin delegated configuration;
- admin assignment/revocation.

Rules:
- server validates current authority;
- consequential commands are idempotent;
- direct browser table mutation prohibited;
- command returns stable machine reason + human recovery mapping.

---

# 4. Read/projection boundary

## Public projections

- list public/selectable Locations;
- get public catalogue for selected Location.

Only public-safe fields.

## Authenticated Account projection

When identity exists:
- own Account presentation;
- selected Location preference;
- minimal shared trust summary;
- platform capability summary;
- Location Admin scopes.

Do not fetch every product relationship on every homepage load.

## Admin projections

Purpose-built:
- Locations and lifecycle;
- Product registry;
- LocationProduct configuration/readiness;
- scoped admin assignments;
- necessary audit views.

No generic “admin SQL browser.”

---

# 5. Authentication vs authorization

## Authentication

External/technical identity system proves:
- authenticated provider/session identity.

Current candidates/evidence:
- existing Supabase Auth/Google patterns;
- possible central open-source/shared solution if necessary.

## Authorization

Raahi server state proves:
- Account status;
- Platform Admin capability;
- Location Admin assignment;
- focused-product relationship/capability.

Authentication provider never grants Raahi business authority.

## Phone trust

Separate trust primitive:
- OTP provider proves challenge result;
- Raahi server records exact phone-control trust meaning.

Phone trust is neither login role nor professional verification.

---

# 6. Storage/file boundary

Shared shell V1 needs no user-uploaded files.

Therefore:
- no shared file storage service is required for initial shell;
- no logo/avatar upload feature should be added merely because infrastructure exists;
- Product-specific documents/evidence remain with focused Product.

If shared avatar/upload later becomes real, it gets a separate storage/privacy/technology proof.

---

# 7. Realtime/background jobs

## Shared public shell

No realtime dependency is required for V1.

Product catalogue can be:
- request/refetch based;
- short-cache assisted.

No polling loop is required.

## Background jobs

None required for public shell V0.

Future candidates:
- health/readiness reconciliation;
- trust expiry derived checks;
- ad expiry;
- cleanup.

Do not create cron infrastructure until a real state transition requires it.

Focused products keep their own realtime/jobs.

---

# 8. Audit/event strategy

Consequential shared configuration/authority changes create immutable audit evidence.

Audit is required for:
- Location lifecycle;
- Product registry/lifecycle;
- LocationProduct changes;
- Platform/Location Admin authority grants/revocations;
- future shared trust-sensitive administrative operations.

Ordinary public reads and browser Location choices do not require heavy audit.

Event/audit data must avoid secrets and unnecessary PII.

---

# 9. Idempotency and concurrency

Consequential shared commands use:
- idempotency key;
- request fingerprint;
- current-state validation;
- uniqueness/state constraints.

Concurrency behavior:
- stale admin writes fail against current canonical state;
- duplicate grants cannot create duplicate active authority;
- retries after lost responses return the prior committed result.

Public reads are naturally repeatable.

---

# 10. External-service boundaries

## Authentication provider
Purpose: technical identity/session only.

## OTP provider
Purpose: phone-control challenge only.

Paid OTP is an accepted recurring cost boundary.

## Focused Product integration
Purpose:
- navigation;
- safe Location context;
- later identity handoff/session interoperability.

## Maps / AI / analytics / email
Not required by the first shell.
No recurring paid API may enter architecture merely for polish.

---

# 11. Deployment/runtime assumptions

Current strongest candidate for public shell:

- Cloudflare Worker/static assets;
- D1 for tiny shared public configuration;
- custom Raahi domain later;
- no production route until staging evidence passes.

Why it fits rules:
- public discovery requires no Account;
- configuration is tiny/read-heavy;
- shell can fail independently from Learning;
- no need to consume another Supabase Free project;
- low operational/cost footprint.

This remains a **technology hypothesis** until Gate 13 real staging proof.

---

# 12. Product integration topology

Preferred logical topology:

myraahi.co.in
→ selected Location
→ focused Product destination

Possible destinations:
- subdomain;
- path;
- separate Raahi-owned deployment.

The product contract does not require one monolithic web app.

Integration must preserve:
- Raahi brand continuity;
- explicit Location context;
- safe return path;
- eventual Account continuity where proven.

No identity/session token is placed in ordinary Product URL query parameters.

---

# 13. Failure isolation

Shared shell failure must not corrupt focused products.

Focused Product outage must not corrupt shared configuration.

Identity-provider outage:
- public browsing should still work where safe.

OTP-provider outage:
- only actions that truly require fresh phone proof should be blocked.

LocationProduct PAUSE/OFF:
- affects new shared discovery/admission;
- does not delete focused-product history.

---

# 14. Caching

Caching may reduce free-tier reads, but:

- cached state is delivery optimization;
- consequential decisions use current server/product truth;
- cache cannot make an unavailable Product authoritative;
- cache freshness policy must be explicit before production.

Current prototype’s short public cache is an implementation default, not invariant.

---

# 15. Security boundary

Shared shell must enforce:
- approved Product destination origins;
- input normalization;
- no raw query/database endpoint;
- no client-owned authority;
- no secrets in static assets;
- protected admin commands;
- safe auth return destinations;
- current server checks for consequential transitions.

A public repository does not imply public credentials.

---

# 16. Physical architecture options re-evaluated

## Option A — Shared shell inside Learning production Supabase
**Result:** REJECT as first path.
Reason: unnecessary coupling/failure risk.

## Option B — Isolated Cloudflare Worker + D1 public shell, identity later
**Result:** LEADING CANDIDATE, subject to Gate 13 proof.

## Option C — New central auth stack + shared DB from day one
**Result:** DEFER.
Reason: security/migration complexity before public shell value/SSO need is proven.

## Option D — Another new Supabase Free project
**Result:** REJECT as default because it works against project-count/cost strategy.

---

# 17. Existing implementation reconciliation

Branch:
- myraahi-shared-shell-v1

Current scaffold:
- Worker read API;
- D1 public config schema;
- static responsive UI;
- Playwright UI checks.

Interpretation under Gate 12:
- compatible with logical architecture;
- may serve as Gate 13 public-shell technology spike;
- is not yet production architecture evidence;
- must not expand into shared identity/admin/product operations before the relevant proof gates.

---

# 18. Architecture questions intentionally deferred to Gate 13

1. Can Cloudflare Worker + D1 deploy/run reliably under our actual free account and desired staging topology?
2. Can configuration updates be applied safely and reflected without frontend rebuild?
3. What is the safest free cross-subdomain Account/SSO architecture?
4. Can existing Learning identity be integrated without dangerous migration or duplicate Accounts?
5. How are auth return context and draft resume preserved securely?
6. What exact OTP provider primitive/server evidence is available for shared trust?

These are technology facts, not product decisions.

---

# Gate 12 result

**PASS at the logical architecture level.**

No architecture contradiction was found against Gates 0–11.

Physical choices are explicitly provisional until Gate 13 technology proof.

Next gate: **Gate 13 — Technology Proof / Spikes**.

First spike should prove the isolated public shell in a real non-production Cloudflare environment before any SSO work.
