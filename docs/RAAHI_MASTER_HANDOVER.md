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

## Exact Current Point / Next Action

Do not restart strategy, archaeology, Gates 0–12, shell scaffolding or UI redesign.

Current implementation branch:
`myraahi-shared-shell-v1`

Current validated implementation commit:
`c3424217c1ce8a43866b705ce3cc42f7cbe842d7`

Current gate:
**Gate 13 — Technology Proof / Spikes**

### Next action

The tooling strategy has now been rechecked against the earlier reusable AI-project tooling doctrine:

- GitHub Codespaces = intended interactive cloud development computer.
- GitHub Actions = available headless cloud execution in the current chat.
- Desktop Commander = real-user/browser validation, not routine coding/deployment.

A read-only GitHub Actions Cloudflare access probe was run:

- branch commit: `f82324ca407e4c86c1f7be5b268a1229f62ad512`
- workflow run: `36261265502`
- result: standard secrets `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` are not currently available to the repo workflow.
- no Cloudflare action or deployment occurred.

Therefore the preferred next step is a **one-time Cloudflare credential bootstrap**, after which GitHub Actions can handle non-production staging without keeping Dipti in the critical path.

One-time bootstrap options:
1. authorize Cloudflare in an interactive GitHub Codespace/browser and create a narrowly scoped API token/account ID for Actions; or
2. use the authorized local browser/Desktop Commander once solely to create/store those GitHub Actions secrets.

After the secrets exist, continue Gate 13 entirely through GitHub Actions for D1 creation/migrations/staging deploy, then reserve Desktop Commander for real-user validation.

Do not use paid TinyFish or a paid cloud VM merely to solve this bootstrap.



Then:

1. verify Cloudflare dashboard authentication **read-only**;
2. confirm the authorized Cloudflare account/zone for `myraahi.co.in`;
3. confirm Workers/D1 access;
4. create only a non-production D1 database and Worker/staging target;
5. apply `apps/myraahi-shell/migrations/0001_public_shell.sql`;
6. load `apps/myraahi-shell/fixtures/dev-seed.sql` only in non-production;
7. deploy only to workers.dev or a dedicated staging hostname;
8. verify real API + mobile/desktop browser behavior;
9. change one non-production LocationProduct state and prove the homepage changes without frontend rebuild;
10. document observed evidence/limits;
11. only then begin the separate cross-product Account/SSO spike.

Do not point production `myraahi.co.in` to the shell.
Do not modify Raahi Learning production auth/database.

---

## Handover Discipline Going Forward

At every major decision or material discovery, update this master handover.

Before a chat reaches its limit, update the document with:
- decisions made
- assumptions changed
- completed research
- repository/branch state relevant to the work
- unresolved questions
- exact next action

Project-specific execution work should continue to maintain its own detailed handover as well.

A new chat should resume with:
"Read docs/RAAHI_MASTER_HANDOVER.md and continue from Exact Current Point."

No reconstruction from memory should be required.
