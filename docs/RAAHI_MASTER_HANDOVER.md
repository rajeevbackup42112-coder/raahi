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

## Exact Current Point / Next Action

The common front-door decision is now agreed:

- `myraahi.co.in` is the shared Raahi entry point.
- Location comes first.
- The homepage asks how Raahi can help in that selected place.
- Only products actually live in that location are shown.
- Public browsing should not require login.
- Authentication begins when the user performs a consequential action.
- OTP verifies phone ownership, not full identity; stronger role-specific verification is separate.
- The shared core should stay minimal: location, profile/identity, authentication, verification status, enabled products per location, and local admin/configuration.
- Product-specific business logic remains inside each product.

The next chat should NOT restart the strategy discussion or redesign this foundation from scratch.

Start by reading this file in full.

Then perform the read-only Raahi Archaeology Pass, specifically asking: which pieces of the agreed common front door / identity / locality foundation have already been implemented well in existing Raahi projects?

Begin with:

1. rajeevbackup42112-coder/raahi
2. identify its important branches and canonical documentation
3. reconstruct the current Raahi Learning/product patterns from source + docs
4. identify reusable authentication, profile, locality, verification and city/product-enable patterns
5. then inspect raahi-toto
6. then Where-is-my-Raahi-
7. then schooltransportos
8. then raahimini / other experiments
9. inspect local-only projects such as Naresh separately when GitHub access is unavailable

Do not change production, deploy anything, or modify application code during the archaeology pass unless explicitly asked.

The immediate purpose is understanding and knowledge extraction, not implementation.

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

The goal is that a new chat can resume with:
"Read docs/RAAHI_MASTER_HANDOVER.md and continue from Exact Current Point."

No reconstruction from memory should be required.
