# MyRaahi Shared Front Door — Gate 9 UI Behaviour & Wording Freeze v0.1

Last updated: 2026-09-26

Method: AI Builder Cheat Code v2.0 — Gate 9

Status: **BEHAVIOUR/COPY FREEZE; VISUAL BROWSER VERIFICATION STILL REQUIRED BEFORE IMPLEMENTATION FREEZE**

Scope: public shared front door and the minimum shared interaction surfaces.

---

# 1. UI principle

The user should understand the front door without knowing:
- Product registry
- LocationProduct
- market lifecycle
- capabilities
- admin scope
- RPC
- account subject
- trust freshness
- backend/provider terminology

The public mental model is only:

> **Where do you need help? → What do you need? → Open the right Raahi service.**

---

# 2. Screen: Raahi Home — no Location selected

## User question
“What is this, and what do I do first?”

## Required visible elements
1. Raahi brand.
2. Primary question:
   **How can Raahi help you today?**
3. Clear Location action:
   **Choose location**
4. One short supporting sentence, maximum one or two lines on typical mobile.
5. No mandatory sign-in wall.
6. No fake avatar/profile.
7. No ads.

## Preferred supporting copy
**Choose your town to see what Raahi can genuinely help with there.**

Alternative acceptable phrasing may be tested, but must retain:
- locality;
- honesty of availability;
- brevity.

## Must not show
- “Select market”
- “Choose tenant”
- “Product availability configuration”
- long Raahi manifesto
- sign-up benefits paragraphs
- unavailable product grid before Location choice

---

# 3. Screen: Location chooser

## User question
“Which place do I want Raahi for?”

## Required behavior
- manual choice always available;
- recognizable town names;
- optional small district/state disambiguation;
- current selection visibly marked;
- close/cancel possible;
- changing Location is reversible.

## Preferred heading
**Where should Raahi help?**

## Supporting copy
**You can change this anytime. Choosing a location does not create an account.**

## Do not require
- GPS
- phone
- Google login
- address
- PIN code

unless a future evidence-backed use case changes the rule.

---

# 4. Screen: Raahi Home — Location selected

## User question
“What can I actually do here?”

## Required hierarchy
1. Raahi brand.
2. selected Location control remains visible.
3. **How can Raahi help you today?**
4. concise local context:
   **Here’s what Raahi can help with in Gomoh right now.**
5. Product choices.
6. optional small trust/locality note after the Product choices, not before them.

## Product card content
- recognizable icon/visual;
- human Product name;
- one short outcome-oriented description;
- clear action.

Examples:
- **Learning** — Find teachers and learning opportunities near you.
- **ToTo** — Find local transport options for your journey.
- **Shops** — Find useful local shops and what they offer.
- **Doctors** — Find local doctors and available care information.

Descriptions are examples; focused Product positioning may refine them.

## Card action
Prefer:
- **Open Learning**
- **Find a ride**
- **Find a doctor**
- **Explore shops**

Human verbs may be product-specific.

Do not use:
- Launch module
- Enter marketplace
- Open service instance

---

# 5. PAUSED Product behavior

## User question
“Why can’t I use this right now?”

If a previously known Product is PAUSED and shown:

- card remains visually distinguishable but not alarm-like;
- do not present the normal LIVE CTA;
- show concise human reason such as:
  **Temporarily unavailable**
  or
  **ToTo is temporarily unavailable in Gomoh.**

If a useful availability message exists, show one sentence maximum.

Do not expose:
- PAUSED
- state machine
- readiness gate
- admin reason codes

to ordinary users.

---

# 6. No-live-products state

This is a valid product state, not an error page.

Preferred copy:

**Raahi doesn’t have a service ready here yet.**

Supporting:
**We’ll only show something when it is genuinely available in this location.**

Primary action:
**Choose another location**

Do not invent disabled/future cards merely to make the page look full.

---

# 7. Loading state

Loading text should describe the user's goal, not infrastructure.

Acceptable:
- **Checking what Raahi can help with in Gomoh…**
- **Loading Raahi for Gomoh…**

Avoid:
- Fetching catalogue
- Connecting to D1
- Loading LocationProduct rows

Loading should not create layout jumps that hide Location context.

---

# 8. Error/retry state

Preferred pattern:

**Raahi couldn’t load this right now.**

**We couldn’t check what’s currently available in Gomoh.**

Action:
**Try again**

If Location itself became unavailable:
**Choose another location**

Do not blame the user or expose HTTP/database/provider codes.

---

# 9. Product navigation behavior

When user taps a LIVE Product:
- destination must remain Raahi-branded/familiar;
- selected Location should carry through where relevant;
- user can get back to shared Raahi home;
- navigation does not ask for shared authentication unless the Product action requires it.

If destination is invalid/down:
- do not send user to arbitrary or broken external URL knowingly;
- preserve current shell and Location when possible.

---

# 10. Authentication handoff UI

This screen appears only when a consequential action requires identity.

## User question
“Why do I have to sign in now?”

Required:
- human reason tied to the intended action;
- clear sign-in method(s);
- safe cancel/back;
- reassure by behavior, not marketing, that prepared context will be preserved where possible.

Example:
**Sign in to send this request**
**You can keep browsing without signing in.**

Do not say:
- authentication required by system
- establish account authority
- verify capability

## Wrong-account protection
Where the next action is consequential, resolved signed-in identity should be visible before final submission if ambiguity is plausible.

---

# 11. Authenticated header/profile behavior

When an Account exists:
- profile/avatar control may appear;
- must not replace or obscure Location control;
- mobile header must not have overlapping avatar/notification/location buttons;
- notification control should not appear until a shared notification need exists.

Account UI is secondary to the primary local task.

---

# 12. Admin UI behavior

Admin surface is separate from ordinary homepage mental model.

Admin must display:
- current admin context;
- Location scope where applicable;
- current server state;
- allowed next actions;
- consequence before destructive/availability-changing action.

Human labels:
- **Live**
- **Temporarily unavailable**
- **Preparing**
- **Not offered**

Internal database enums may differ, but ordinary admin copy should still be understandable.

Platform vs Location Admin scope must be visually explicit.

---

# 13. Deep-link behavior

A deep-link entrant should immediately understand:
- which Raahi Product/page;
- which Location if relevant;
- whether sign-in is needed only for the next action.

If link changes Location context from current shell selection, that difference must be visible.

No silent city switch.

---

# 14. Mobile-first requirements

Minimum:
- no horizontal scrolling;
- Location control usable with one thumb;
- tap targets large enough for ordinary touch use;
- primary question and first Product choices visible without excessive copy;
- modal/dialog fits viewport and scrolls safely;
- no overlapping header controls;
- browser back/refresh produces understandable state;
- product cards are not tiny desktop tiles compressed into mobile.

---

# 15. Desktop requirements

Desktop may:
- widen content;
- show 2–3 Product cards per row;
- use more breathing room.

Desktop must not:
- introduce a different information architecture;
- hide Location in a sidebar;
- turn the shell into an admin/dashboard aesthetic.

---

# 16. Accessibility/comprehension requirements

- semantic headings;
- keyboard-operable Location chooser and Product links;
- visible focus;
- sufficient contrast;
- reduced-motion support;
- status changes announced where practical;
- emoji/icon is not the only accessible Product label;
- error meaning is in text, not color alone;
- dialog has close control and focus behavior must be browser-tested.

---

# 17. Review of current branch prototype

Current prototype under:
`apps/myraahi-shell/public/`

### Strong alignment
- no login wall;
- clear “How can Raahi help you today?” headline;
- visible Location control;
- manual Location chooser;
- Product cards from backend configuration;
- PAUSED Product treatment;
- no-live state;
- human loading/retry copy;
- mobile responsive CSS;
- reduced-motion rule;
- no ads;
- no fake authenticated avatar;
- no backend terminology in ordinary UI.

### Items to verify/fix in real browser before Gate 9 full PASS
1. Dialog keyboard/focus/close behavior on mobile Safari and desktop browsers.
2. Header overlap at narrow mobile widths.
3. Very long Location name truncation.
4. Product-card copy height/wrapping.
5. PAUSED state clarity without looking like a clickable LIVE card.
6. Back-button behavior after Location changes.
7. Refresh restoration.
8. API error recovery.
9. No-live-products state visual quality.
10. Deep-link return/navigation once a real focused Product adapter exists.
11. Real accessibility focus visibility.
12. Product icons/visual tone feel like Raahi rather than a generic utility dashboard.

---

# 18. UI freeze boundary

Frozen behavior/copy intent:
- Location first;
- public first value;
- concise human language;
- selected Location always easy to find/change;
- Product availability truthful;
- no internal terminology;
- no login wall;
- no AI-first input;
- no ad clutter;
- auth appears only at meaningful action.

Not frozen:
- exact typography;
- exact colors;
- exact spacing;
- exact icons/illustrations;
- final logo/brand art;
- animation;
- exact Product-card copy;
- authenticated profile menu design.

These can improve without reopening domain rules if behavior remains unchanged.

---

# Gate 9 result

**PARTIAL — behaviour and wording contract is ready, but strict Gate 9 is not fully PASS until the existing prototype is verified in a real browser on representative mobile and desktop sizes.**

This is an **evidence gate**, not a business-decision gap.

We may continue preparing Gate 10 acceptance scenarios, but must not declare broad implementation readiness or freeze the current visual implementation until browser validation is complete.
