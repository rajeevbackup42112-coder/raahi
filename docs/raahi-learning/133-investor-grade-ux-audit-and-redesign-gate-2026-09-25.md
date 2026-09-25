# Raahi Learning — Investor-Grade UX Audit and Redesign Gate

Date: 2026-09-25  
Repo: `rajeevbackup42112-coder/raahi`  
Branch: `raahi-learning-implementation-v1`  
Public: `https://learning.myraahi.co.in`

## Decision

Do **not** treat Raahi Learning as visually launch-ready yet.

The functional/product foundation is strong, but the current presentation does not yet feel like one polished consumer learning brand. The next pre-launch gate is a product-wide UX and visual-system redesign, followed by full mobile + desktop visual regression.

Deployment of the current human-language candidate is frozen until this gate is closed.

Current undeployed branch product source:
`751548f4cc0e1250a1f727d01e336c51050b62a6` — **Stabilize setup forms during overlay bootstrap**

This source includes the product-wide human-language work plus the bounded setup-submit reliability repair. GitHub Model Tests #774 and Browser Contract #37 are green. It is intentionally **not deployed** while this UX redesign gate is open.

Current public product remains `5d8ea741a4c782a3978f4d3c096024e3dbc0fead`.

## Audit evidence

Authenticated live crawl completed across Raahi-02 through Raahi-09:
- 8 authenticated browser profiles
- 13 role contexts
- 461 rendered screens
- 232 desktop screens
- 229 iPhone screens
- 5,947 visible interactive controls inventoried
- 53 distinct live routes reached safely without production mutations

Supplemental deterministic audit covered 32 record-dependent / first-use routes at desktop + iPhone:
- 64 additional rendered screens
- exact local frontend built from the current branch
- no production writes

Raahi-01 was also audited for the unauthenticated Welcome experience. Its signed-in Gomoh Local Manager session currently requires a real Google login before account-specific review can resume.

The QA-only State Gallery is not considered launch-facing product UX.

## What the audit found

Across the 461 authenticated live screens:
- 227 screens had at least one measurable UX/layout issue
- 176 horizontal-overflow findings
- 224 mobile small-tap-target findings
- 14 interactive-overlap findings
- 42 text-heavy first-screen findings
- 6 repeated generic-CTA findings
- 2 clipped-control findings

The supplemental 32-route fixture audit found another 36 issue screens, including interaction overlap and excessive first-screen density on important detail/action routes.

These counts are diagnostic evidence, not a product score. Some findings repeat the same systemic shell defect across multiple routes.

## Root causes

### 1. Mobile shell is compressed desktop UI

At 390 px the top bar tries to show too much at once:
- Raahi brand
- Notifications text button
- Location
- current context selector
- avatar

The result is horizontal overflow, hidden/truncated brand treatment and collisions.

Bottom navigation also truncates labels such as **My Classes** and can overlap page actions or long content.

### 2. Visual identity is too weak after login

Learner Home is the strongest surface, but many Teacher, Institute and Admin pages fall back to:
- large white cards
- sparse empty space
- initials instead of meaningful avatar/profile imagery
- repeated text labels
- little visual storytelling or learning energy

The product should feel educational, trustworthy, local and alive — not like a generic admin console.

### 3. Navigation and CTA hierarchy is inconsistent

Examples:
- multiple cards using only **Manage**
- large role/context selector occupying prime mobile header space
- Notifications represented as a large text control instead of a compact bell + badge
- role-specific bottom-nav labels being shortened until they become ambiguous
- secondary actions competing visually with primary actions

### 4. Dense workflow screens need progressive disclosure

Notifications, Audit, Settings, Class threads, Enquiries and some Ads/Admin pages put too much information into the first mobile viewport.

Important content should be scannable first, expandable second.

### 5. Interactive sizing is not mobile-first

Many links/buttons are below a comfortable mobile touch target.

Minimum launch target should be 44×44 CSS pixels for touch controls, with stronger spacing around destructive and high-consequence actions.

## Raahi Design System V1 — required before page-by-page polish

Create one reusable system for:
- typography scale
- spacing scale
- page width/grid
- cards and sections
- primary / secondary / quiet / destructive buttons
- pills and status badges
- form fields and help text
- avatar / profile-photo fallback
- empty states
- loading and error states
- notification rows
- responsive tables
- mobile bottom navigation
- desktop sidebar
- mobile and desktop headers
- role/context switcher
- sponsored-content treatment

Do not redesign pages independently without this shared system.

## Mobile shell target

The mobile header should become intentionally mobile-first:

- compact Raahi mark / wordmark
- compact Location chip
- notification bell with numeric badge
- real avatar or polished avatar fallback

Move context switching out of the crowded top row — for example into an account/context sheet or a compact second-level control when multiple contexts exist.

Bottom navigation:
- maximum 5 clear destinations at a time
- no truncated labels
- no content/action overlap
- active state visually obvious
- 44 px+ touch targets

The current desktop header should not simply shrink into mobile.

## Avatar and human presence

Current initials are acceptable only as a fallback.

For consumer-facing profiles:
- support real teacher/institute/profile images where the user supplies them
- use Google profile image only with the existing user-controlled profile/privacy rules
- provide polished generated-color initials when no photo exists
- never invent a real person's photo or credentials

Teacher and institute discovery cards should visually communicate trust and personality without becoming social-media noise.

## Welcome / login redesign

Current mobile Welcome page is too text-heavy and its feature cards can overflow horizontally.

Target:
1. strong Raahi brand moment
2. one clear promise
3. one short supporting sentence
4. one primary **Continue with Google** action
5. compact trust/privacy reassurance
6. optional visual illustration / local-learning motif
7. supporting feature cards below the fold, not competing with sign-in

The user should understand Raahi in roughly five seconds.

## Role workspace redesign

### Learner / Parent
Keep the strong **Find. Learn. Grow.** direction.
Improve teacher cards, profile imagery, notification experience, Messages and Learning Profiles.

### Teacher
Make the home page action-oriented:
- profile readiness
- new opportunities
- current Classes
- upcoming work
- recent learner activity

Avoid a sparse dashboard with one or two empty white cards.

### Institute
Replace repeated **Manage** buttons with meaningful actions:
- Edit learning options
- Manage Classes
- Manage staff
- Open Raahi Ads

### Manager / Platform / Ads
Preserve operational seriousness but reduce internal-tool feeling through clearer information hierarchy, compact metrics, progressive disclosure and mobile-safe action layouts.

## Investor-grade visual acceptance gate

Before launch, every launch-facing route must pass at minimum:

- desktop 1440×900
- iPhone-class 390×844

For every permitted actor/context:
- no horizontal page overflow
- no overlapping interactive controls
- no clipped button/nav labels
- no bottom navigation covering actionable content
- touch controls at least 44×44 where practical
- one clear page purpose
- one visually dominant primary action when an action is required
- no raw enum/database/implementation language
- meaningful empty/loading/error state
- avatar/profile fallback is intentional
- mobile first viewport is scannable
- destructive actions visually separated from routine actions

Add automated screenshot/layout regression so these rules cannot silently regress.

## Implementation order

1. Freeze current deployment.
2. Build Raahi Design System V1 tokens/components.
3. Replace mobile + desktop shell first.
4. Redesign Welcome/login.
5. Redesign Learner/Parent Home + Explore + profile cards.
6. Redesign Teacher workspace.
7. Redesign Institute workspace.
8. Redesign Notifications + Messages + Class/Enquiry detail workflows.
9. Redesign Manager / Platform / Ads operational workspaces.
10. Run full 9-profile desktop/mobile visual audit again.
11. Only then resume normal release qualification and controlled-pilot deployment.

This is a presentation/experience program. Frozen business rules, canonical RPC authority, privacy boundaries and product invariants remain unchanged.

## Current human step

Raahi-01 / port 9231 currently reaches Google sign-in and no longer has an authenticated Raahi session.

Its unauthenticated Welcome experience has been audited. To complete the account-specific Gomoh Local Manager review, sign into Raahi-01 with the intended Google account when convenient.

Raahi-02 already provides Local Manager role coverage, so redesign work does not need to wait for this login.

