# MyRaahi Shared Front Door — Product Contract v0.1

Last updated: 2026-09-26

Status: **FROZEN PRODUCT BASELINE FOR ARCHITECTURE DESIGN — NO IMPLEMENTATION IMPLIED**

This contract defines the common Raahi entry experience at `myraahi.co.in`. It does not merge product-specific business logic into one application.

It is derived from the Raahi Master Handover, Raahi DNA archaeology, and Shared Foundation Reuse Matrix.

---

## 1. Human problem

In smaller towns, useful local services often exist but are fragmented across word-of-mouth, WhatsApp, phone calls, posters, local brokers, isolated websites, and disconnected apps.

Raahi should give a person one simple local starting point:

> **What can Raahi help me with in this place?**

The shared front door should help the user discover which Raahi utilities actually work in the selected locality, without forcing account creation before the user sees value.

---

## 2. Product promise

`myraahi.co.in` is the common location-first front door to the Raahi family.

Core journey:

**Choose Location → see what Raahi genuinely offers there → enter the relevant focused product → authenticate only when a meaningful persistent action requires it.**

The shared shell is not itself a super-app containing all domain logic.

---

## 3. Core product laws

1. **Location first.**
2. **One problem at a time.**
3. **Only show genuine local availability.**
4. **Discovery is public; consequential actions are authenticated.**
5. **Authentication is not verification.**
6. **Verification must state exactly what has been verified.**
7. **One human should not need separate Raahi identities for every product.**
8. **Selected Location is context, not permanent identity.**
9. **Product-specific business rules remain product-owned.**
10. **Trust takes priority over monetization.**
11. **Free/lean infrastructure is preferred; paid OTP is the accepted recurring API exception.**
12. **Configuration should enable expansion; city-specific forks should not.**

---

## 4. Actors

### 4.1 Visitor

A person with no active Raahi Account session.

May:
- open `myraahi.co.in`;
- choose/change Location;
- see public products available in that Location;
- enter public discovery surfaces of those products;
- understand what Raahi can do before signing in.

Must not need to:
- create an Account;
- provide a phone number;
- provide precise GPS location;
- choose a permanent role.

### 4.2 Raahi Account

A durable authenticated human account.

May:
- retain profile and selected Location preference;
- perform product actions permitted by product-specific relationships/capabilities;
- build trust signals over time;
- participate in more than one Raahi product.

An Account is not permanently labelled as Passenger, Teacher, Parent, Driver, Shopkeeper, etc.

### 4.3 Provider identity / relationship

A product-specific representation used only when a provider lifecycle genuinely requires one.

Examples:
- Teacher Profile
- Driver
- Doctor Profile
- Shop/Business

Provider status does not replace the Raahi Account.

### 4.4 Location Admin

A Raahi Account with explicit administration authority for one or more assigned Locations.

May operate only within assigned scope and delegated controls.

Location Admin authority must never be inferred from selected Location.

### 4.5 Platform Admin

Platform-wide governance authority.

May:
- create/manage Locations;
- manage shared Product registry;
- enable/configure Product availability per Location;
- assign/remove Location Admin authority;
- handle platform-level governance and audited exceptions.

---

## 5. First-time public journey

### 5.1 Arrival

User opens:

`https://myraahi.co.in`

The first screen should make Raahi understandable quickly.

Preferred primary language:

> **How can Raahi help you today?**

A visible Location selector appears near the question.

### 5.2 Location selection

If no Location has previously been selected:

- ask the user to choose a Raahi Location;
- manual selection must always be available;
- do not require precise GPS merely to enter Raahi;
- optional location suggestion may be added later only if it materially reduces effort.

### 5.3 Product discovery

After choosing a Location, show only products appropriate for public display in that Location.

Example:

**Gomoh**
- Learning
- ToTo
- Shops

**Dhanbad**
- Learning
- Doctors
- ToTo
- Shops

These examples are illustrative, not launch configuration.

### 5.4 Product entry

Tapping a product enters that focused Raahi experience.

The user should not feel that they have entered an unrelated company/app.

The destination may technically be another route/subdomain/application, but the transition should preserve:
- Raahi identity/branding;
- selected Location where applicable;
- return path to Raahi home.

---

## 6. Homepage information hierarchy

The homepage should prioritize:

1. Raahi identity
2. selected Location
3. “How can Raahi help you today?”
4. enabled local products
5. very limited useful local Sponsored content later
6. account/profile control only when relevant

Avoid:
- long explanatory text;
- product marketing paragraphs before the user sees options;
- forced sign-in;
- generic nationwide catalogues;
- unavailable products presented as normal live choices;
- banner-ad clutter.

---

## 7. Product registry semantics

The shared shell needs a small Product registry.

A Product is a Raahi capability/focused product, not a domain record.

Illustrative fields/concepts:
- stable product key
- public display name
- short description
- icon/image reference
- destination URL/path
- active/retired platform availability
- optional display metadata

Examples:
- `learning`
- `toto`
- `doctors`
- `shops`

The registry must not contain:
- Classes
- rides
- appointments
- shop orders
- provider operational state

Those belong to the focused product.

---

## 8. Location lifecycle

Shared Location lifecycle:

### PREPARING
Configured internally but not offered as a normal public Raahi Location.

### LIVE
Publicly selectable and able to expose its live/paused products.

### PAUSED
Temporarily not accepting normal new local activity at the shared platform level.

Existing product relationships/history must not be destroyed.

### RETIRED
No longer offered as an active Raahi Location.

Historical references remain valid where needed.

A future interest/waitlist state may be added only if a real acquisition need appears. Do not add it solely for completeness.

---

## 9. Location × Product lifecycle

Each Product is enabled independently per Location.

Initial shared lifecycle:

### PREPARING
Product is being configured/onboarded for this Location.

Default homepage behavior: hidden from ordinary product choices unless Raahi deliberately runs a “Coming soon” acquisition experiment.

### LIVE
Product is publicly available as a normal choice.

### PAUSED
Known product temporarily unavailable for new normal activity.

Default homepage behavior: keep it visible with a clear temporary-unavailability state when hiding it would confuse returning users.

### OFF
Product is not offered in the Location.

Default homepage behavior: hidden.

This lifecycle affects new entry/discovery, not existing product history or already-valid relationships.

---

## 10. Location selection and persistence

### Logged-out visitor

Selected Location should be stored using lightweight browser/session state.

Do not create an Account merely to remember Gomoh.

### Authenticated Account

Raahi may persist selected Location as Account preference.

### Reconciliation rule

If a visitor explicitly selects Gomoh and then signs in, sign-in must not unexpectedly switch them to an older saved Dhanbad preference.

The current explicit journey choice wins for that session and may update the saved Account preference.

### Invariant

Changing selected Location never:
- creates a new Account;
- changes verification;
- changes provider identity;
- deletes history;
- moves existing Classes/rides/orders/appointments;
- grants local admin authority.

---

## 11. Public browse vs authenticated action boundary

### Public by default

The shell should permit:
- choosing Location;
- seeing enabled products;
- reading public product summaries;
- entering product public-discovery surfaces;
- understanding serviceability/availability at a non-personal level where safe.

### Authentication required

Authentication begins when the user performs an action that creates/accesses meaningful persistent personal state, for example:
- request/book a ride;
- contact/apply to a teacher through Raahi;
- place an order;
- book/request an appointment;
- post/comment where identity/accountability is required;
- save private preferences/history;
- become/onboard as a provider;
- access private messages/history;
- perform admin operations.

Each focused product must explicitly map its own boundary.

### Draft-preservation law

If authentication is triggered after the user has already prepared an action:

> preserve the user's safe draft/context and return them to the intended action after successful authentication.

Do not make the user start over without a security reason.

---

## 12. Shared authentication baseline

### Default V1 direction

Use a durable Raahi Account with free/low-cost authentication as the ordinary identity layer.

The strongest existing implementation evidence supports:

- Google as the default low-cost Account sign-in path;
- paid phone OTP as an additional trust/contact proof for selected consequential actions.

This is a product baseline, not a requirement to show Google sign-in on the public homepage.

### Important separation

**Google authentication**
proves control of the Google identity/session.

**Phone confirmation**
proves control of a phone number at the time of proof.

**Raahi verification**
may prove specific provider facts through evidence/review.

**Raahi authority**
comes from server-owned relationships/capabilities.

None of these should be conflated.

### Phone-only fallback

A universal phone-only account model is not frozen in v0.1.

Reason:
- recurring OTP cost;
- account linking/recovery complexity;
- existing Google-first implementation evidence.

If real users demonstrate that Google-only account entry excludes meaningful Gomoh adoption, add an evidence-based fallback rather than guessing now.

---

## 13. Cross-product identity expectation

Desired human experience:

> If I am already signed into Raahi, another Raahi product should not treat me as a completely unknown person without a good reason.

However, the technical cross-subdomain/session architecture is **not frozen by this product contract**.

Architecture must evaluate:
- one shared auth project vs multiple product backends;
- cookie/session boundaries;
- free-tier constraints;
- product data isolation;
- safe account linking.

Do not promise seamless SSO until the walking skeleton proves it.

---

## 14. Profile baseline

Shared Account profile should initially contain only broadly useful identity presentation fields.

Candidate minimum:
- Raahi display name
- chosen profile image/initials
- account lifecycle metadata required operationally

Google metadata may suggest defaults, but:
- display name remains Raahi-controlled/editable;
- Google photo is not automatically published;
- Google changes do not silently overwrite an established Raahi profile.

Do not put product-specific biography/qualification/vehicle/shop data into the generic Account profile.

---

## 15. Trust and verification vocabulary

Raahi must avoid one vague universal “Verified” badge.

The system should be able to state exact claims such as:
- Phone confirmed
- Identity verified
- Teacher qualification verified
- Doctor registration verified
- Driver licence verified
- Vehicle documents verified
- Shop existence verified

### Rules

1. Verification claims have explicit type and scope.
2. Product-specific evidence/review remains product-owned unless a genuine reusable verification service emerges.
3. Paid promotion can never create verification.
4. Selected Location can never imply verification.
5. Account age/activity can never silently be presented as identity proof.
6. Expired/revoked evidence must not remain displayed as current.

---

## 16. Admin rules

### Platform Admin

Can manage:
- Locations
- Product registry
- Location × Product availability
- Location Admin assignments
- platform governance

### Location Admin

Can manage only assigned local scope and delegated configuration.

### Invariants

- selecting a Location does not grant admin rights;
- Location Admin cannot become Platform Admin through local controls;
- consequential admin changes are audited;
- UI never receives arbitrary database-edit powers;
- product-specific admin controls remain inside the product unless truly shared.

---

## 17. Sponsored content baseline

Raahi may later show minimal Sponsored local content to cover survival costs.

Initial product law:

> **Sponsored visibility can be purchased. Trust cannot.**

Sponsored content must:
- be clearly labelled;
- be relevant to selected Location;
- be limited in density;
- never alter verification;
- never secretly replace organic ranking;
- never dominate the primary “How can Raahi help you?” task.

No generic third-party ad network is required by this contract.

---

## 18. Privacy/minimum-data rules

1. Do not collect identity before it is needed.
2. Do not ask for phone number just to browse.
3. Do not require precise location just to select a town.
4. Do not duplicate sensitive data across products without a clear need.
5. Public shell should know the minimum required to route users to local Raahi products.
6. Product-specific sensitive data remains scoped to the product and authorized relationships.
7. Technical abuse controls should be as invisible as practical to legitimate users.

---

## 19. Failure/recovery behavior

### Location list unavailable

Show a clear temporary problem and retry.

Do not invent a default city as if it were confirmed.

### Product list unavailable

Do not display stale/unverified availability as current without an explicit cached-state design.

### Product becomes PAUSED after homepage load

The destination product remains authoritative and should reject new action gracefully.

### Authentication cancelled

Return the user to the safe prepared context where possible.

### Authentication succeeds but product action fails

Keep the authenticated session and safe draft; explain the recoverable failure.

### Old saved Location no longer LIVE

Ask user to choose another active Location.

### Product destination unavailable

Shared shell should not pretend the service is working; provide a human recovery path.

---

## 20. Non-goals for the first shared shell

Do not initially build:

- an AI chatbot as primary navigation;
- one giant shared operational database for every product;
- unified cross-product feed;
- universal provider-verification workflow;
- complex recommendation ranking;
- loyalty/rewards system;
- full advertising marketplace;
- cross-city social network;
- automatic GPS city selection as the only entry path;
- paid maps/search/AI APIs merely for polish;
- a nationwide catalogue.

---

## 21. Initial screen contract

### Screen: Raahi Home

Must answer:
- Where am I browsing?
- What can Raahi help me with here?
- Which products actually work here?
- How do I change Location?

Primary controls:
- Location selector
- one card/action per public Location Product
- optional sign-in/profile affordance
- later, at most minimal Sponsored local placement

### Screen: Location chooser

Must:
- show only public/selectable Locations;
- support manual selection;
- identify paused/unavailable Locations truthfully if they are shown at all.

### Screen: Authentication handoff

Appears only when needed.

Must:
- explain why sign-in is needed in human language;
- preserve intended destination/action;
- return to the product journey after success.

---

## 22. Acceptance scenarios

### AS-01 — first visit without login

Given a new visitor opens `myraahi.co.in`,
when no Location is selected,
then Raahi asks for a Location without requiring sign-in or phone number.

### AS-02 — selected Location changes catalogue

Given Gomoh and Dhanbad expose different live Products,
when the visitor switches from Gomoh to Dhanbad,
then the visible Product choices change to Dhanbad configuration without changing user identity.

### AS-03 — hidden unavailable product

Given Doctors is OFF in Gomoh,
when Gomoh is selected,
then Doctors is not shown as a normal live choice.

### AS-04 — live product entry without auth

Given Learning is LIVE in Gomoh,
when a logged-out visitor taps Learning,
then they may enter its allowed public discovery experience without being forced through shared-shell authentication.

### AS-05 — consequential action triggers auth

Given a logged-out visitor prepares a valid product action,
when they attempt to submit/create persistent personal state,
then authentication is required before the action is created.

### AS-06 — draft survives auth

Given a visitor has prepared an action and authentication is triggered,
when authentication succeeds,
then the safe draft/context is restored and the user returns to the intended next step.

### AS-07 — explicit Location survives login

Given a logged-out visitor explicitly selected Gomoh,
and their historical Account preference is Dhanbad,
when they sign in,
then the active journey remains Gomoh and may update the saved preference rather than unexpectedly switching the screen to Dhanbad.

### AS-08 — Location does not grant authority

Given an Account selects Dhanbad,
when they have no Dhanbad Location Admin assignment,
then no Dhanbad admin capability becomes available.

### AS-09 — exact verification

Given a provider has only phone confirmation,
when their public trust state is shown,
then Raahi may say Phone confirmed but must not say Identity verified or Profession verified.

### AS-10 — paused product

Given ToTo was LIVE and becomes PAUSED in Gomoh,
when a returning user opens Gomoh,
then Raahi presents the temporary state truthfully and does not allow a new normal ToTo request through the shared entry path.

### AS-11 — current relationships survive location/product changes

Given a user has existing Learning history,
when they change Location or Learning becomes PAUSED for new acquisition,
then existing authorized history is not deleted or reassigned.

### AS-12 — sponsored trust separation

Given a local shop buys Sponsored visibility,
when it appears on Raahi,
then it is labelled Sponsored and receives no automatic verification or organic-rank privilege.

---

## 23. Frozen v0.1 decisions

The following are now treated as product baseline unless intentionally reopened with impact analysis:

1. `myraahi.co.in` is the shared front door.
2. User chooses/has a selected Raahi Location before the local Product catalogue is meaningful.
3. Public browsing precedes authentication.
4. Authentication occurs at consequential persistent actions.
5. Draft/context should survive authentication.
6. Selected Location is context, not identity or authority.
7. One Account can participate in multiple Raahi products/relationships.
8. No single permanent platform-wide end-user role.
9. Product availability is independently configurable per Location.
10. Product-specific domain data remains product-owned.
11. Google-first Account auth + selective phone trust is the current default direction, with phone-only fallback deferred to evidence.
12. Exact verification claims replace vague universal “Verified”.
13. Global and Location Admin authority are explicitly scoped and server-owned.
14. Sponsored visibility never buys trust.
15. Shared shell should be clean/new; do not reuse Learning retrofit frontend or ToTo prototype as production core.
16. No AI-first navigation in initial shell.
17. No non-OTP recurring paid API/subscription should be introduced without exhausting free/open alternatives.

---

## 24. Next design gate

With the product contract frozen, the next phase is:

1. canonical shared entities and relationships;
2. state diagrams;
3. invariants/uniqueness constraints;
4. Screen ↔ Backend contracts;
5. authentication/session architecture options under free-tier constraints;
6. product integration URL/subdomain model;
7. database/RPC blueprint;
8. walking-skeleton plan;
9. only then implementation.

Any architecture that contradicts this contract must reopen the relevant product decision explicitly rather than silently changing it.
