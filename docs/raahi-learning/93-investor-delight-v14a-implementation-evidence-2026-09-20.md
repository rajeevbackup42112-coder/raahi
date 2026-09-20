# Raahi Learning Network V1.4A — Investor + Delight Implementation Evidence — 2026-09-20

Status: **QUALIFIED SOURCE CANDIDATE — NOT YET DEPLOYED TO PUBLIC ORIGIN**

Public production remains live at `https://learning.myraahi.co.in` on the previously qualified public artifact until this V1.4A candidate is packaged and deployed.

## 1. Objective

V1.4A is a presentation-only investor/market-readiness pass. It makes Raahi feel warmer, more human, more local and easier to scan without reopening frozen product rules or changing backend authority/state logic.

Companion design docs:

- `90-emotional-design-blueprint-v1.4.md`
- `91-investor-delight-screen-redesign-plan-v1.4.md`
- `92-market-activation-seeding-blueprint-v1.4.md`

## 2. Core design decision

**Home is discovery + momentum, not product documentation.**

The final V1.4A Home deliberately reduces explanation and feature density:

- selected Location is visually obvious;
- hero headline: **Find. Learn. Grow.**;
- supporting copy: **Teachers and learning near you.**;
- primary actions: **Find a teacher** and **I need tuition**;
- current Classes appear under **Your learning** only when there is something useful to show;
- empty `Your learning` is suppressed rather than presenting a sad empty dashboard block;
- discovery becomes **For you in <Location>**;
- Home limits discovery to two compact provider cards; richer details remain in Explore/profile screens;
- teacher cards on Home remove verification/mode/save clutter while retaining identity, subject, locality, fee and availability;
- a real advertising section is titled **Featured**, while each ad itself remains clearly labelled `Sponsored`;
- empty Sponsored sections remain suppressed.

## 3. Implemented presentation changes

V1.4A is delivered as additive assets:

- `apps/raahi-learning/delight-v14.css`
- `apps/raahi-learning/delight-v14.js`

The layer adds:

- visible `RAAHI` brand with `Your local learning network` descriptor;
- warmer lilac/amber/mint/sky visual system over the existing purple identity;
- learning-themed SVG iconography and removal of ambiguous/broken glyphs on touched surfaces;
- richer Welcome screen and value cards;
- locality-led Home treatment;
- simpler Home information hierarchy;
- warmer empty states;
- richer Location cards;
- human avatar fallbacks for Community, Messages and providers;
- browse affordances on live Explore when the base implementation does not already provide them;
- more natural student/parent/teacher language;
- reduced-motion support;
- responsive mobile behaviour.

The V1.4A DOM layer performs no Supabase calls, RPCs, direct table writes, fetches or operational state transitions.

## 4. Release integration

Canonical reconstruction and release packaging now include:

- `delight-v14.css` in the document head;
- `delight-v14.js` after the established V1.3 product/launch overlays.

GitHub Model Tests now watch the V1.4 assets and run `tests/delight-v14.test.mjs` plus JS syntax validation.

Release-package tests were extended so packages fail if the V1.4 assets are missing.

Public Privacy/Terms copy was also corrected from the historical `controlled pilot` language to the current **early public release in Gomoh and Dhanbad** wording.

## 5. Visual QA evidence

The candidate was rendered in isolated local browser profiles against the frozen V1.3 frontend fixture plus the V1.4A presentation layer.

Desktop QA:

- normal browser viewport observed at approximately `1275 × 646` CSS pixels;
- Home hero reduced to ~215px high;
- selected Location, headline and two primary actions are visible immediately;
- useful Class/discovery content moves materially higher on the page;
- compact teacher cards preserve the key decision information while removing secondary verification/mode/save clutter from Home;
- no route or click-target ownership was changed.

Mobile QA:

- `390 × 844` viewport checks were run for Welcome, Home, Explore and Location chooser;
- document width stayed at the viewport width on the core screens;
- sidebar correctly collapses to mobile navigation;
- Welcome value cards intentionally use an internal horizontal swipe row on small screens rather than creating a tall stacked page;
- Home remains readable with compact hero/actions and single-column content.

## 6. Regression evidence

Final local qualification on the simplified-Home source:

- `git diff --check`: clean;
- V1.4 JS syntax: clean;
- production/launch guard suite: **48/48 passed**;
- backend-free model/property suite: **5,349,572 cases, 0 failures**;
- earlier production-like load guard on this V1.4A branch state: **9/9 passed**;
- V1.4-specific presentation tests verify no backend mutation/fetch/RPC code, truthful activity rules, reduced-motion support, packaging integration and simplified-Home copy;
- V1.4 source was checked for common mojibake markers and corrected before qualification.

## 7. Backend boundary discovered during visual work

The existing backend already supports:

- Account `avatar_type` / `avatar_ref`;
- Learner `avatar_type` / `avatar_ref`;
- Organization `logo_type` / `logo_ref`;
- public teacher profile projection with teacher avatar metadata;
- organization discovery logo metadata.

One small future enhancement is required for fully photo-forward Explore cards: `discover_teaching_options()` does not currently project teacher `avatar_type` / `avatar_ref` even though the public teacher-profile RPC does. This should be handled later as a narrow projection-contract slice, not by leaking Google profile photos or redesigning the backend.

Google identity `avatar_url` metadata exists for signed-in identities but must not be treated as automatically public Raahi profile photography. Raahi-approved avatar/profile choices remain the publication authority.

## 8. Market-activation boundary

Raahi Desk, seeded-vs-assisted-vs-organic provenance, Founding Teacher recognition and unclaimed organization listing flows are intentionally **not** implemented in V1.4A. They remain a separate domain/backend slice governed by `92-market-activation-seeding-blueprint-v1.4.md`.

V1.4A therefore improves the product’s emotional/visual quality without mixing new marketplace truth/provenance concepts into the already-proven production backend.

## 9. Next release steps

1. Commit and push the exact qualified V1.4A source.
2. Require GitHub Model Tests green on that exact commit.
3. Reconstruct/package the exact candidate using the canonical release path.
4. Prefer a Cloudflare preview deployment if available; otherwise perform a tightly controlled production Pages upload with immediate browser canary.
5. Verify Welcome, authenticated Home, Explore, Location switching, Google OAuth continuity and public policy pages on the deployed origin.
6. Only then mark V1.4A `PUBLIC LIVE` and update the handover again.
