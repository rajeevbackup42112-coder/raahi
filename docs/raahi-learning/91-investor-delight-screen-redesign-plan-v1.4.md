# Raahi Learning Network — Investor + Delight Screen Redesign Plan V1.4

Status: **IMPLEMENTATION PLAN — PRESENTATION LAYER ONLY UNLESS EXPLICITLY NOTED**

Companion: `90-emotional-design-blueprint-v1.4.md`

## 1. Scope and non-goals

This pass improves emotional quality, brand communication, visual richness and first-impression value without reopening frozen business rules.

Do not change:

- Account/role/relationship authority;
- Location switching semantics;
- Class, Message, Enquiry or Learning Request states;
- privacy/safety invariants;
- organic vs Sponsored separation;
- canonical RPC/write architecture.

Changes should be implemented as presentation/copy/components first. Any new seeded-content data model must pass normal Builder gates separately.

## 2. Logged-out Welcome — P0

Current weakness: secure and functional, but visually sparse and explains features rather than creating desire.

Target first impression: **“This is my local learning network.”**

Recommended structure:

- RAAHI wordmark + “Your local learning network”;
- warm hero with student/teacher learning illustration or authentic local-learning visual treatment;
- headline: **Find teachers. Find students. Learn locally.**;
- supporting line: **Explore learning in Dhanbad and Gomoh. Switch Locations anytime with one Raahi account.**;
- primary CTA: `Continue with Google`;
- three visual value cards: `Find the right teacher`, `Share what you need`, `Learn with your local community`;
- small trust strip: `Google sign-in · Privacy-first · Local learning relationships`;
- Privacy/Terms remain visible.

Do not show fabricated people, ratings or activity counts on the logged-out surface.

## 3. Home — P0

Current weakness: structurally good but reads like a dashboard and exposes too many empty modules.

Target: a lively local learning homepage that answers “what can I do here today?”

Hero proposal:

**Dhanbad / Gomoh**  
**Your local learning network**  
`Find teachers` · `Post what you need` · `See what’s happening`

Home content order:

1. `For you in <Location>` — featured genuine teachers/options or a useful action if supply is still thin.
2. `Students are looking for` — only genuine, privacy-safe Learning Request summaries.
3. `This week in learning` — Raahi Desk/local events/opportunities.
4. `From your Community` — useful recent local posts.
5. `My learning` — Classes/messages/context, lower on the page once the user has relationships.

Empty-state rewrite examples:

- `No active Classes` → **Your Classes will live here** / “When you join a teacher or learning group, you’ll find it here.”
- `No current public options` → **We’re growing <Location>’s learning network** / “Post what you need, or check another Location.”
- `No sponsored learning opportunities` should disappear entirely when empty rather than consume visual space.

## 4. Explore — P0

Current weakness: visually becomes a search form plus an empty result.

Target: browseable marketplace even before the user knows what to type.

Add visual entry points:

- subject/category chips with friendly icons;
- `Taking new learners` section;
- `Recently added in <Location>`;
- `Home tuition`, `Coaching/Class`, `Online` facets where already supported by data;
- rich teacher/option cards with photo/logo, subject, short proposition, locality, availability and exact trust badges.

## 5. Teacher / Learning Option profile — P0

Target: the most persuasive and trustworthy screen in the marketplace.

Visual hierarchy:

- large real teacher photo or organisation logo;
- name + concise teaching proposition;
- subjects/classes and Locations served;
- availability / “Taking new learners” when genuinely declared;
- exact verification/trust claims, never a vague generic “Verified Teacher” badge;
- experience/approach in natural language;
- learning options as visual cards;
- prominent `Ask about this` / `Send enquiry` CTA;
- safe template questions to reduce messaging friction.

Avoid review-star UI until real review policy/data exists.

## 6. Learning Request — P0

Target: feel like asking the local learning network for help, not filling an administrative form.

Lead with: **What are you looking to learn?**

Progressively ask only the minimum required fields, use examples, show selected Location clearly, and explain who will be able to see the request. Completion should end with an encouraging confirmation such as **Your learning request is now visible in Gomoh** rather than an internal state name.

Do not fabricate demand. Assisted requests must represent a real student/parent need and retain their genuine ownership.

## 7. Community — P0

Current weakness: an empty discussion surface makes the whole network feel inactive.

Target: useful local learning activity from first launch day.

Community composition:

- Raahi Desk editorial questions/guides, clearly labelled;
- genuine teacher updates;
- genuine student/parent Learning Request-linked discussions where allowed;
- local events/opportunities;
- achievements;
- lightweight polls;
- recurring local rituals such as `Ask a Teacher` and `This week in learning`.

Cards should use avatar/photo, author identity, locality/time context, optional informative image, short readable copy and existing healthy interaction rules.

Empty Community should be treated as a launch defect once Raahi Desk exists; the platform should seed useful editorial content before promoting a new Location.

## 8. Messages / Enquiries — P1

Current copy such as “relationship-scoped conversations” should become user language.

Suggested header: **Messages**  
Supporting copy: **Talk safely with teachers and learning connections you’ve already connected with.**

When empty: **No conversations yet** / “Start by asking a teacher about a learning option.” Provide a route to Explore where appropriate.

Thread UI should emphasise people, relationship context and the originating learning option rather than internal message/thread metadata.

## 9. My Classes — P1

Suggested supporting copy: **Your current Classes and invitations, all in one place.**

When empty: **Your learning journey will show up here** / “When you join a Class, you’ll see its teacher, activities and updates here.”

Active Class cards should feature teacher/organisation identity, subject/title, next useful action and learner context before technical state labels.

## 10. Location chooser — P0 signature interaction

This should become one of Raahi’s memorable product moments.

Instead of a plain list, show each live Location as a warm locality card:

- Location name;
- concise descriptor such as `Local teachers, Classes and Community`;
- optional truthful activity hints when data exists;
- current-selection indicator;
- one-tap switch.

Copy: **Choose the learning community you want to explore. You can switch anytime.**

Never imply that switching Location changes the user’s identity, existing Classes, Messages or history.

## 11. Settings / learning profiles — P1

Reduce the feeling of an account-control panel. Group settings into human goals:

- `My profile`;
- `Learning profiles`;
- `Privacy & safety`;
- `Sign-in & account`.

Trust/security explanations remain precise but should be progressive disclosure rather than dominate ordinary screens.

## 12. Navigation and brand shell — P0

Retain the simple desktop/mobile navigation architecture but strengthen identity:

- visible RAAHI brand mark/wordmark;
- subtitle `Your local learning network` where space allows;
- Location control visually stronger than a generic pill;
- replace broken/ambiguous glyphs (`?`, control-character icons) with consistent accessible SVG/iconography;
- selected navigation state should feel softer and more inviting;
- real user/profile avatar in the top area when available.

The existing responsive layout remains valuable and should be evolved rather than replaced.

## 13. Seed-content integration — separate gated slice

Presentation can be prepared now, but persisted Raahi Desk/editorial content requires normal domain review before schema/RPC changes.

The UI should be designed for four visible provenance types: `Raahi Desk`, `Assisted`, `Organic`, `Unclaimed listing`.

## 14. Implementation sequence

**Slice A — Brand shell + copy foundation**  
Welcome, nav/icon repair, RAAHI descriptor, locality emphasis, system-language replacement, empty-state tone.

**Slice B — Home + Location signature experience**  
Hero, local activity composition, empty-module suppression, richer Location chooser.

**Slice C — Explore + profile marketplace richness**  
Subject browse, image-forward teacher/organisation cards, stronger trust/availability hierarchy.

**Slice D — Learning Request + Community + Raahi Desk presentation**  
Warm request journey, editorial/community card system and provenance labels.

**Slice E — Classes + Messages + Settings refinement**  
Humanise relationship surfaces without changing authority or states.

**Slice F — Seed-content backend/domain work**  
Only after separate rule/state/data review; do not bolt editorial persistence directly onto existing user-post ownership.

## 15. Investor-demo acceptance test

Without narration, a first-time viewer should be able to identify Raahi as a local learning network, recognise the selected Location, see real people/opportunities/activity, understand how a student finds help and how a teacher gets discovered, and understand that changing Location scales the same network to another town/city.

The finished experience should feel **alive because useful things and real people are present**, not because decorative animation or fabricated activity has been added.
