# Raahi Master Handover

Last updated: 2026-09-26

## Purpose

This is the cross-project continuity document for the wider Raahi journey. Chat threads are temporary and may hit conversation limits. This file is intended to preserve the exact strategic state, agreed principles, current discoveries, and the next action so a new chat can continue without reconstructing the discussion from memory.

Individual Raahi projects may continue to keep their own execution handovers. This file is the higher-level Raahi strategy and discovery handover.

---

## Raahi North Star

Raahi is a trusted digital layer for everyday life in smaller Indian cities and towns.

The operating philosophy is:

1. Solve one genuine local problem at a time.
2. Make the experience dramatically simpler than the current workaround.
3. Build trust and local legitimacy into the product.
4. Prove the product with real users in one locality.
5. Learn from actual behaviour and improve the product.
6. Expand only after the product is mature.
7. Reuse proven Raahi patterns across future products without forcing users into a giant super-app.

Do not build technology merely because it is interesting or available.

---

## Market Strategy

### Pilot market

Gomoh is the primary live pilot market.

Reasons:
- The founder is from Gomoh and understands the locality.
- Gomoh has limited digital infrastructure for many everyday needs.
- Real-user behaviour can be observed directly.
- Small scale makes experimentation and learning practical.
- Larger cities such as Dhanbad, Bokaro and Ranchi already have stronger incumbents.

The intended expansion model is:

Gomoh -> prove product -> mature operating model -> replicate to other comparable places -> expand to larger cities where Raahi has a clear advantage.

Do not assume that success in Gomoh automatically implies success in a larger city. Before entering a larger market, identify why Raahi is materially better than existing options there.

---

## Location-First Product Shell

Raahi follows a BookMyShow-style location-first model.

User flow:

Choose location -> see only the Raahi services genuinely available in that place.

Examples:
- Gomoh -> Gomoh Learning / ToTo / Shops / other live services
- Dhanbad -> Dhanbad Doctors / ToTo / Shops / Learning as available
- Ranchi -> only services that are actually launched there

The location should influence listings, search, admins, boundaries, pricing, availability, events, moderation and other local rules.

Raahi may grow in two directions:
- Depth: more services inside one place.
- Breadth: a mature service replicated to another place.

Do not launch every Raahi product everywhere at once.

---

## Common Raahi Front Door and Identity Foundation

`myraahi.co.in` is the intended common front door for the Raahi ecosystem.

The preferred first-time user journey is:

1. Land on `myraahi.co.in`.
2. Choose or confirm a location.
3. See a simple prompt such as "How can Raahi help you today?"
4. Show only the Raahi products/services that are genuinely live in that location.
5. Allow public browsing without forcing authentication first.
6. Require authentication only when the user attempts a consequential action such as booking, contacting, ordering, posting, applying, becoming a provider or otherwise creating operational state.

Authentication should not be confused with identity verification.

Suggested trust/identity progression:
- Visitor: no account; can browse public information.
- Verified user: phone OTP verified.
- Local profile: profile completed and locality associated.
- Verified provider: stronger role-specific verification, for example teacher credentials, driver/vehicle documents, doctor registration, or shop/owner verification.

Raahi should communicate verification precisely, e.g. phone verified, identity verified, professional credentials verified, rather than implying that OTP alone proves identity.

The common foundation should initially stay small and reusable:
- location
- user identity/profile
- authentication
- verification status
- products enabled per location
- local administration/configuration

Specialized business logic should remain inside the relevant product so Learning, ToTo, Doctors, Shops, etc. can evolve independently.

The desired architecture is therefore:

One Raahi front door + one shared identity/locality foundation + independently evolving products.

AI should not be required for the initial homepage experience. Start with clear deterministic navigation/cards. A future "Ask Raahi" layer may route natural-language needs to the correct product after enough real usage data exists.

---

## Product Sequencing Principle

Raahi should not begin as a single giant super-app.

Each product should feel complete and focused for its own problem:
- Raahi Learning should feel like a learning product.
- Raahi ToTo should feel like a transport product.
- Raahi Local should feel like a local discovery/commerce product.
- Doctors should feel like a healthcare discovery/appointment experience.

Shared identity, trust, locality, notifications, maps, payments and administration may eventually become common infrastructure underneath the products.

Users do not need to understand the shared infrastructure.

Trust should transfer gradually from one successful Raahi product to the next.

---

## Existing Raahi / Related Products Discussed

Examples already built or explored include:

- Raahi Learning
- Raahi ToTo
- Raahi Blink / local commerce direction
- Where is my Raahi?
- School transport work
- Naresh local sports/community website/blog
- Other smaller Raahi experiments

The recurring theme is:

"Something useful exists locally, but there is no simple trustworthy digital layer around it."

---

## Core Problem Hypothesis

Many small-town needs are currently solved through:

- personal references
- WhatsApp groups
- phone calls
- posters/signboards
- Google / Justdial
- brokers/middlemen
- physically visiting locations

The strongest recurring gaps are:

1. Discovery - who or what exists near me?
2. Availability - are they actually active/open/available?
3. Trust - is this person/business genuine?
4. Reputation - what happened when local people dealt with them?
5. Coordination - how do both sides connect and complete the interaction?
6. Local relevance - does the information actually apply to this locality?

A major Raahi hypothesis is that the real offline competitor is often:

"Do you know someone?"

Raahi should preserve the trust advantage of word-of-mouth while improving discoverability and coordination.

---

## Raahi Problem Observatory

The Observatory is not a backlog of apps.

Its purpose is to collect real local frictions before deciding what to build.

Lifecycle:

Suspected problem -> evidence -> talk to real people -> observe current workaround -> validate pain -> design smallest solution -> pilot locally -> build only if justified.

Evaluate opportunities using:
- pain
- frequency
- trust requirement
- fragmentation of current workaround
- locality advantage
- contribution to wider Raahi ecosystem
- operational complexity
- regulatory/safety risk

Important principle:

Do not search for app ideas.
Search for friction in ordinary local life.

A future exercise planned for the Observatory is to follow one ordinary small-town family's full week and record every point where they need something or someone outside the household.

---

## Cost and Infrastructure Doctrine

Raahi should remain free for users.

Current hard constraint:
- Prefer free tiers, open-source, browser-native or self-hosted components.
- Avoid recurring paid APIs and subscriptions wherever practical.
- The domain myraahi.co.in is already owned.
- Paid OTP verification is acceptable.
- Other recurring API/subscription spend should be treated as a design smell until free/open alternatives have been exhausted.

Future architecture decisions should prefer:
- free hosting tiers
- free database/auth tiers
- efficient storage
- compressed/capped media
- free/open maps where practical
- free/open analytics
- database-native search before dedicated paid search
- free/open notifications where possible
- minimal operational infrastructure

If real usage eventually exceeds free tiers, reconsider economics based on actual demand rather than theoretical scale.

---

## Monetization Doctrine

Raahi should not charge users simply for accessing the core local utility.

Advertising may be used minimally to cover survival/maintenance costs.

Preferred ad style:
- featured local shop
- sponsored local offer
- promoted local event
- featured service in a locality

Ads should:
- be highly local
- be useful and contextually relevant
- feel native to the product experience
- remain clearly labeled as sponsored/promoted
- never secretly manipulate organic trust/rankings
- never make the interface noisy

Trust takes priority over monetization.

---

## GitHub / Open-Source Research Direction

The objective is not to copy large open-source products wholesale.

Preferred approach:

Raahi UX + Raahi business rules remain our own.

Use open-source selectively for mature backend concepts or infrastructure where it removes real complexity.

Projects already identified for possible study:
- Medusa - commerce/order/inventory concepts for Raahi Shops/Blink
- NexCal - appointment/provider scheduling concepts for Doctors/services
- MapLibre - maps
- Photon / OpenStreetMap - geocoding/search
- Meilisearch - future local search if Postgres becomes insufficient
- Umami - analytics
- Revive Adserver - ad-system inspiration, likely too heavy initially
- PocketBase - tiny standalone experiments
- ShopClass - listings/marketplace patterns
- OpenPass - local events inspiration
- TPT School - school-management ideas

Key discipline:

Do not add infrastructure merely because it is free.
Free software can still create complexity, compute, storage and maintenance cost.

Before adopting an external GitHub project:
1. Understand what Raahi has already built.
2. Identify the actual capability gap.
3. Search external projects specifically for that gap.
4. Borrow/adapt only what materially improves Raahi.

---

## GitHub Access Verified in This Chat

The connected GitHub account is:

rajeevbackup42112-coder

Repositories visible during this discussion:

- rajeevbackup42112-coder/raahi
- rajeevbackup42112-coder/raahi-toto
- rajeevbackup42112-coder/raahimini
- rajeevbackup42112-coder/schooltransportos
- rajeevbackup42112-coder/Where-is-my-Raahi-
- rajeevbackup42112-coder/krishna

The GitHub connector can read repository source, docs, branches, commits and other repository data.

Naresh's project was not present in the connected repository list during this discussion. It is known to exist locally on an authorized computer from other project work, so it may require Desktop Commander or a separate GitHub installation/account if it is not pushed through this connection.

---

## Current Discovery: "Raahi Archaeology Pass"

Before continuing broad external GitHub exploration, the next major task is to inspect Raahi's own repositories and reconstruct what has already been learned.

For each project, capture:

1. Problem being solved
2. Actors/users
3. Core business rules
4. Trust/verification decisions
5. Location model
6. User journeys
7. Important states/invariants
8. Tech stack
9. Database model
10. What was actually implemented
11. What became complicated
12. What worked well
13. What patterns repeat across projects
14. What can become shared Raahi infrastructure
15. What genuine gaps remain that external open-source projects could fill

Desired output:

"Raahi Existing Product Knowledge Map" / "Raahi DNA"

This should be evidence-based using:
- actual GitHub source
- canonical docs
- project-specific handovers
- relevant prior conversation context when necessary

Do not rely on chat memory alone.

---

## Archaeology Pass — First Synthesis Completed

A first evidence-based archaeology pass has now been completed across:

- `raahi` / `raahi-learning-implementation-v1`
- `raahi-toto` / `main`
- `Where-is-my-Raahi-` / `implementation-v1`
- `schooltransportos` / `main`
- `raahimini` / `rocket-staging-ready`

The synthesis is stored in:

`docs/RAAHI_DNA_V0.1.md`

Major findings:

1. The strongest common model is **Location → products enabled in that Location → local product rules → user journey**.
2. Location is context/configuration, not permanent user identity.
3. For the shared `myraahi.co.in` front door, the stronger cross-product rule is **Discovery is public. Transactions/actions are authenticated.**
4. Raahi Learning's Google-first login gate is product/history-specific and must not be treated as a platform-wide invariant.
5. Raahi Learning contains the strongest proven reusable model for separating authentication, phone trust and authority.
6. OTP proves control of a phone, not legal identity and not role/capability authority.
7. One Raahi Account may have multiple capabilities/relationships; avoid one global permanent role.
8. Global Admin vs Location Admin scoped authority is already well modeled and partly implementation-proven.
9. A generic Location × Product enablement concept is the key missing shared-shell layer.
10. Where is my Raahi proves that invisible technical session ownership can protect ephemeral public experiences without visible login.
11. School Transport reinforces cost discipline: derive useful truthful functionality from existing data before introducing paid APIs.
12. Raahi Learning Ads provides strong trust guardrails: Sponsored visibility can be purchased; trust/verification/organic ranking cannot.
13. The common architecture pattern across mature projects is UI → authorized reads + canonical commands/RPCs → PostgreSQL source of truth → realtime/notifications as derived delivery.

---

## Shared Foundation Reuse Matrix — Completed

A code-level reuse pass has now been completed and stored in:

`docs/RAAHI_SHARED_FOUNDATION_REUSE_MATRIX_V0.1.md`

Key outcome:

**Do not choose one existing Raahi application as the codebase for the shared shell.**

Instead:

- reuse/adapt Raahi Learning's proven backend semantics for Account, Location, selected Location, scoped admin, phone trust, audit and canonical commands;
- rebuild the shared Location-first homepage cleanly using the stronger Raahi ToTo product model;
- borrow modern OAuth/session plumbing selectively from Raahi Mini / Raahi School;
- use Where is my Raahi anonymous-session/Turnstile patterns only where a genuinely ephemeral public action needs them;
- keep product-specific operational data and state inside each focused product.

Important implementation findings:

1. Raahi Learning's backend/database foundation is considerably more reusable than its current frontend.
2. Learning's current frontend is reconstructed/retrofit-heavy under `apps/raahi-learning`; do not make that the shared shell.
3. Raahi ToTo's Location-first UI/model strongly validates the shared-home concept, but its actual `app-1.js`–`app-4.js` code is a hard-coded prototype and should not become production core.
4. Raahi School and Raahi Mini contain cleaner modern Next.js/Supabase OAuth/session plumbing that may be adapted, but their role/onboarding semantics are too product-specific to copy wholesale.
5. The missing common platform feature is a small generic **Product registry + Location × Product enablement/state** layer.

---

## Shared Front Door Product Contract — Frozen V0.1

The shared `myraahi.co.in` product contract has now been created and frozen at:

`docs/MYRAAHI_SHARED_FRONT_DOOR_PRODUCT_CONTRACT_V0.1.md`

Key frozen decisions include:

- `myraahi.co.in` is the shared front door.
- Location first.
- Public discovery before authentication.
- Authentication at consequential persistent actions.
- Safe draft/context should survive auth handoff.
- Selected Location is context, not identity or authority.
- One Account may participate in multiple Raahi products/relationships.
- No permanent single end-user role across the platform.
- Product availability is independently configurable per Location.
- Product-specific operational data remains product-owned.
- Exact verification claims replace vague generic “Verified”.
- Google-first Account authentication + selective phone trust is the current default direction; phone-only fallback is deferred until real-user evidence requires it.
- Global vs Location Admin authority is explicitly scoped.
- Sponsored visibility cannot purchase trust.
- Shared shell will be a clean new implementation, not the Learning retrofit frontend or ToTo prototype.
- No AI-first navigation in the initial shell.
- No new recurring non-OTP paid API/subscription without first exhausting free/open alternatives.

---

## MyRaahi Public Shell — Implementation Started and Validated

The design gates have now advanced into a deliberately isolated implementation.

Repository:

`rajeevbackup42112-coder/raahi`

Implementation branch:

`myraahi-shared-shell-v1`

Current branch HEAD:

`62c1bc0c8d60d70a5a57be396674184c41549131`

Validated implementation commit:

`699871e0a5ae9b98508e01cd66415a1c5c1e1dda`

Branch-specific execution handover:

`docs/MYRAAHI_SHELL_CURRENT_EXECUTION_HANDOVER.md`

### Validation evidence

GitHub Actions workflow:

`Validate MyRaahi Shell`

Successful run:

- Run ID: `36239610837`
- Validated SHA: `699871e0a5ae9b98508e01cd66415a1c5c1e1dda`
- Result: **SUCCESS**

Passed:
- dependency install
- TypeScript Worker typecheck
- browser JavaScript syntax
- Wrangler dry-run bundle
- D1/SQLite schema validation
- development fixture validation/assertions

### Current implementation scope

Path:

`apps/myraahi-shell/`

Implemented:
- Cloudflare Worker read-only public API
- D1 schema for Locations, Products and LocationProducts
- responsive public Location-first homepage
- no-login first-value journey
- browser persistence of logged-out selected Location
- LIVE/PAUSED Product rendering
- safe Raahi-owned Product deep links with Location hint
- human loading/error/recovery states
- development/staging-only fixture
- automated branch CI

Not implemented:
- shared Account/SSO
- OTP
- admin web UI
- sponsored content
- production catalogue
- production D1
- production DNS
- production deployment
- Learning production adapter

### Safety state

No production deployment has occurred.

No `myraahi.co.in` production DNS has changed.

No Raahi Learning production database/auth behavior has changed.

The D1 database ID remains an intentional placeholder.

---

## AI Builder Cheat Code v2.0 — Strict Gate Reconciliation

The actual personal Library file `AI-Builder-Cheat-Code-v2.0.md` was retrieved and read in full. MyRaahi work is now governed by that strict gate sequence.

New canonical gate artifacts on `main`:

- `docs/MYRAAHI_AI_BUILDER_GATE_REGISTER_V0.1.md`
- `docs/MYRAAHI_GATE1_ACTOR_CATALOGUE_V0.1.md`
- `docs/MYRAAHI_GATE2_AUTHORITY_MATRIX_V0.1.md`
- `docs/MYRAAHI_GATE3_BUSINESS_RULES_V0.1.md`
- `docs/MYRAAHI_GATE4_INVARIANTS_V0.1.md`
- `docs/MYRAAHI_GATE5_STATE_LIFECYCLES_V0.1.md`
- `docs/MYRAAHI_GATE6_EDGE_RECOVERY_V0.1.md`
- `docs/MYRAAHI_GATE7_MINIMUM_DATA_V0.1.md`
- `docs/MYRAAHI_GATE8_BEHAVIOUR_FLOWS_V0.1.md`
- `docs/MYRAAHI_GATE9_UI_BEHAVIOUR_FREEZE_V0.1.md`
- `docs/MYRAAHI_GATE10_ACCEPTANCE_SCENARIOS_V0.1.md`
- `docs/MYRAAHI_GATE11_CHANGE_IMPACT_REGISTER_V0.1.md`
- `docs/MYRAAHI_GATE12_ARCHITECTURE_RECONCILIATION_V0.1.md`
- `docs/MYRAAHI_GATE13_TECHNOLOGY_PROOF_REGISTER_V0.1.md`

Current gate status:

- Gates 0–8: PASS
- Gate 9: PASS with real Chromium evidence
- Gate 10: PASS as canonical acceptance specification; execution is slice-dependent
- Gate 11: PASS
- Gate 12: PASS logically; physical choices remain provisional pending technology proof
- Gate 13: ACTIVE/PARTIAL

### Gate 9 evidence

Implementation branch:

`myraahi-shared-shell-v1`

Final validated public-shell commit:

`c3424217c1ce8a43866b705ce3cc42f7cbe842d7`

Successful GitHub Actions run:

`36247865290`

Passed:
- install
- TypeScript
- browser JS syntax
- Worker dry-run bundle
- D1-compatible schema/fixture
- Chromium
- Playwright real-browser checks

Browser checks covered 375px, 430px, 1366px, 320px long-Location stress, Location switching, PAUSED behavior, refresh persistence, header overlap/overflow, and error recovery.

Two early failures were test-harness selector defects. One real implementation defect was found visually: catalogue-error copy lost selected Location context. It was fixed and regression-tested in `c3424217…`.

### Gate 13 access evidence

The public shell build/browser primitives are proven, but real Cloudflare runtime is not yet proven.

Attempts:
- TinyFish Cloudflare read-only automation could not start because TinyFish wallet balance was `-$0.04`.
- Plugin Directory search found no Cloudflare Workers/D1 connector.
- GitHub repo search found no existing Cloudflare deployment workflow/token reference that can be safely reused.
- Authorized Desktop Commander device `Dipti` was offline when checked.

This is classified as an external authorized-access evidence boundary, not a product/code defect.

---

## Gate 13 — Real Cloudflare Runtime Proven

The isolated MyRaahi public-shell runtime spike is now complete and passed.

Non-production resources:

- D1: `myraahi-shell-gate13-staging`
- D1 ID: `5ee83f6f-66a7-4abd-ba0d-94bf609f967f`
- Worker: `myraahi-shell-gate13-staging`
- workers.dev URL: `https://myraahi-shell-gate13-staging.rajeev-backup4-2112.workers.dev`
- Worker version: `a91ea906-7d3a-450f-81b1-7243363a2ae9`

Evidence:
- real remote D1 migration succeeded;
- dev/staging fixture succeeded;
- live Worker health/locations/catalogue API succeeded;
- real Edge browser rendered the live Worker/D1 shell;
- Dhanbad ToTo changed PAUSED → LIVE through D1 only;
- live API changed immediately;
- browser changed after the configured 30-second cache window;
- Worker version did not change;
- no frontend rebuild/redeploy was needed;
- D1 audit evidence exists;
- staging baseline was restored to Dhanbad ToTo PAUSED afterward.

Production remained untouched:
- no `myraahi.co.in` DNS change;
- no custom-domain route;
- no Learning production database/auth change.

GitHub Actions remains suitable as headless cloud compute, but the repo still lacks `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`. Current successful staging deployment used the already-authorized local Wrangler OAuth session on Dipti. Do not copy that broad OAuth credential into GitHub secrets; bootstrap a narrowly scoped API token later.

---

## MyRaahi Gate 13 — Real Cloudflare Runtime Passed

The public-shell technology spike has now passed in a real non-production Cloudflare environment.

Staging resources:
- D1 database: `myraahi-shell-gate13-staging`
- Worker: `myraahi-shell-gate13-staging`
- URL: `https://myraahi-shell-gate13-staging.rajeev-backup4-2112.workers.dev`
- Worker version: `a91ea906-7d3a-450f-81b1-7243363a2ae9`

Real evidence:
- remote D1 migration succeeded;
- remote staging fixture succeeded;
- health/locations/catalog APIs succeeded;
- real browser rendered against deployed Worker/D1;
- changing Product public display metadata in D1 changed the live page without redeploy;
- changing Dhanbad Ride from PAUSED→LIVE changed the same deployed page from unavailable to **Open Ride** without redeploy;
- the row was then reverted LIVE→PAUSED and the same deployed page returned to paused treatment.

Production remained untouched.

### Brand vocabulary decision

Public product naming is now:
- **Learn**
- **Ride**
- future **Health**
- **Shops**
- **Events** when introduced

Raahi remains the master brand.

Inside focused products, fuller forms may be:
- **Raahi Learn**
- **Raahi Ride**
- **Raahi Health**

Stable backend keys remain implementation-friendly:
- `learning`
- `toto`
- etc.

This was classified as AI Builder Gate-11 **Class A — branding/copy only** for the shared shell; no domain/state/authority migration was needed.

Branch source/tests were updated and validated:
- `myraahi-shared-shell-v1`
- validated commit `4704da826f4b1256b9a9008bcacd5d99c35647f1`
- CI run `36291608117` = SUCCESS

Gate-13 evidence is documented at:
`docs/MYRAAHI_GATE13_TECHNOLOGY_PROOF_REGISTER_V0.1.md`

---

## MyRaahi Shared Identity Direction — Gate 13D

The auth/SSO spike has produced a simpler V1 decision.

### Current facts

Raahi Learn uses Supabase Auth project:

`iiwwmqokaeflaenhlyip`

Public origin:

`https://learning.myraahi.co.in`

A live session inspected read-only showed:
- origin-local Supabase session storage;
- ES256 JWT;
- issuer `https://iiwwmqokaeflaenhlyip.supabase.co/auth/v1`;
- audience `authenticated`;
- asymmetric key ID present.

Current Supabase docs confirm:
- public JWKS verification for ES256;
- automatic linking of OAuth identities with the same verified email within a project;
- Supabase OAuth 2.1/OIDC Server exists and is currently beta/free on all plans during beta.

### V1 decision

Use the **existing Raahi Learn Supabase Auth project as the shared Raahi identity authority**.

Do not create a duplicate Account database in D1.

Canonical authenticated subject:
- auth issuer
- verified Supabase user UUID

MyRaahi remains public-first.

Focused products keep their own:
- roles;
- relationships;
- permissions;
- transactions;
- verification workflows.

V1 browser sessions may remain origin-local. A user may need another Google authentication interaction when entering a different authenticated Raahi product, but it must resolve to the same durable Raahi subject.

True seamless SSO is **not a V1 launch blocker**.

Leading future true-SSO candidate:
- Supabase OAuth 2.1/OIDC Server

Deferred due to unnecessary current complexity:
- parent-domain custom auth cookies
- custom token broker
- migration of Learn's current localStorage session model

Detailed document:

`docs/MYRAAHI_GATE13_SHARED_IDENTITY_SSO_SPIKE_V0.1.md`

---

## MyRaahi Gate 13D — Shared Identity State

V1 identity architecture is now frozen:

- canonical Raahi authenticated subject comes from Supabase Auth project `iiwwmqokaeflaenhlyip`;
- subject is issuer + verified Supabase user UUID;
- MyRaahi D1 is not the production Account identity store;
- MyRaahi public browsing remains anonymous-first;
- focused products own their own roles, permissions and transactions;
- origin-local sessions are acceptable in V1;
- true seamless SSO is not a launch blocker.

Current Supabase evidence:
- Raahi Learn session is origin-local in browser storage;
- JWT algorithm = ES256;
- issuer = Learn Supabase Auth project;
- audience = authenticated;
- current docs support public JWKS verification;
- Supabase OAuth 2.1/OIDC server exists, currently beta/free on all plans during beta, but requires authorization UI/client configuration.

Future true-SSO candidate:
**Supabase OAuth 2.1/OIDC Server**

Deferred:
- custom parent-domain cookie migration
- custom token broker
- changing Learn production auth now

Detailed doc:
`docs/MYRAAHI_GATE13_SHARED_IDENTITY_SSO_SPIKE_V0.1.md`

### Existing experimental handoff

The isolated shell branch already contains a spike-only Learn → MyRaahi handoff:
- ES256/JWKS token verification
- HTTPS POST token handoff
- spike-only issuer+subject mapping
- HttpOnly MyRaahi session cookie
- feature flag `ENABLE_GATE13_SSO_SPIKE`

It is explicitly NOT production-ready. Before any productionization it would require login-CSRF/state binding, revocation/session semantics, lifecycle/cleanup and stronger protocol review.

Latest branch validation:
- branch `myraahi-shared-shell-v1`
- HEAD `a99ee64924afbca98178dfb59c4d86bee5944f4c`
- CI run `36297963846` = SUCCESS

---

## MyRaahi Gate 16 — Walking Skeleton Current State

Canonical document:

`docs/MYRAAHI_GATE16_WALKING_SKELETON_V0.1.md`

Status:

**PARTIAL — one controlled authenticated DEV preference-transition proof remains.**

### Cross-product adapter implemented

Raahi Learning branch:

`raahi-learning-implementation-v1`

Current branch HEAD:

`e96a6236df75cfac6a1a4373fb3abb35c41f38a9`

New adapter:

`apps/raahi-learning/myraahi-location-handoff-v1.js`

It:
- consumes only `raahi_location`;
- normalizes/validates the slug;
- preserves pending intent in sessionStorage across auth;
- removes the query parameter from the visible URL;
- waits for authenticated Learn Account context and Learn's own Location list;
- requires target Learn Location state LIVE;
- invokes the existing canonical `set_selected_location` RPC;
- refreshes `get_my_account_context`;
- never writes the preference table directly;
- never treats Location as role/admin authority;
- never reads/transfers auth tokens.

### Cloud evidence

Model Tests:

- run `36709495982`
- SHA `e96a6236df75cfac6a1a4373fb3abb35c41f38a9`
- result: **SUCCESS**

The actual adapter source is executed in a VM test which proves:
- logged-out arrival does not write;
- authenticated context causes `set_selected_location`;
- Dhanbad Location ID is passed;
- idempotency key is used;
- canonical account context is refreshed to Dhanbad;
- pending handoff state is cleared.

Real deployed DEV read-only proof:

- workflow: `MyRaahi Learn Location Handoff Readonly`
- run `36709496149`
- result: **SUCCESS**
- artifact: `myraahi-learning-location-handoff-readonly-36709496149-1`
- digest: `sha256:effd883eb4ddfd4913c65ae7167c825f7f21cf86765aab513dfe4c47acd67607`

Observed on `dev.learning.myraahi.co.in`:
- deployed adapter asset present;
- `raahi_location=dhanbad` captured;
- query parameter removed from visible URL;
- **zero** `set_selected_location` requests while logged out;
- normal signed-out Learn UI remained intact.

The deployed DEV app SHA was `ae6a7e8e9c215ea554e2475a39319ad561e8ce46`. It is source-compatible with `e96a6236…`; the later differences are tests/workflows only and `appChanges=[]`.

### DEV synthetic-write seal

The controlled-pilot safety seal remains intact.

`.github/RAAHI_LEARNING_DEV_WRITES_ENABLED` is intentionally absent.

Synthetic DEV writer workflows remain manual-only and fail closed.

An attempted automatic DEV E2E writer run stopped at the write guard before any mutation. The temporary push trigger was removed immediately.

Do not recreate/bypass that marker merely to satisfy Gate 16.

### Remaining proof — WS-10

One exact evidence step remains:

authenticated deployed DEV browser
→ valid MyRaahi Location hint
→ real Learn `set_selected_location`
→ real preference write
→ `get_my_account_context`
→ same target Location in browser and backend.

This must use an explicitly authorized controlled test path.

No production user preference, production Auth configuration, service-role direct table write or synthetic-writer guard bypass may substitute for it.

---

## Exact Current Point / Next Action

Current AI Builder state:

- Gates 0–15: **PASS / reconciled for current V1 scope**
- Gate 16: **PARTIAL / CURRENT**
- Gate 17: **BLOCKED until Gate 16 closes**

Do not restart:
- archaeology;
- public-shell architecture;
- Cloudflare runtime proof;
- identity architecture;
- Gate 14 contracts;
- Gate 15 side-effects;
- Learn Location adapter implementation.

### Exact remaining action

Close Gate 16 WS-10 only:

1. use an explicitly authorized authenticated DEV/test Learn browser context;
2. establish/confirm an initial canonical selected Location different from the target;
3. enter deployed Learn with a valid MyRaahi `raahi_location` hint;
4. observe the deployed adapter invoke the real canonical `set_selected_location` RPC;
5. confirm `get_my_account_context` returns the target Location;
6. confirm the browser Learn context shows the same target Location;
7. confirm no role, capability, admin scope or unrelated Product data changes;
8. repeat/reload safely to prove idempotent recovery.

Do not bypass the sealed synthetic DEV writer workflow.

If no authorized state-changing DEV browser path is available, stop at this evidence boundary rather than weakening the guard.

After WS-10 passes:
- mark Gate 16 PASS;
- begin Gate 17 vertical slices one at a time.

Production remains untouched:
- no `myraahi.co.in` DNS cutover;
- no production Learn Auth change;
- no production preference write solely for test evidence.

---

## Handover Discipline Going Forward

Update this master handover after every material decision, defect classification, or technology/evidence gate.

A new chat resumes with:

"Read docs/RAAHI_MASTER_HANDOVER.md and continue from Exact Current Point."
