# MyRaahi Shared Front Door — Gate 10 Given/When/Then Acceptance Catalogue v0.1

Last updated: 2026-09-26

Method: AI Builder Cheat Code v2.0 — Gate 10

Scope: shared `myraahi.co.in` front door and common location/identity foundation.

These are product acceptance scenarios. Technology-specific tests may implement them differently.

---

## Public discovery

### AT-01 — First visit has value before authentication

**Given** a new visitor with no Account session and no saved Location  
**When** they open `myraahi.co.in`  
**Then** Raahi asks them to choose a Location and does not require Google login, phone OTP or precise GPS.

### AT-02 — Location drives catalogue

**Given** Gomoh and Dhanbad have different current LocationProduct configurations  
**When** the visitor switches from Gomoh to Dhanbad  
**Then** the visible Product catalogue changes to Dhanbad configuration without changing human identity.

### AT-03 — OFF Product hidden

**Given** Doctors is OFF in Gomoh  
**When** Gomoh catalogue is rendered  
**Then** Doctors is not presented as a normal public Product choice.

### AT-04 — PREPARING Product hidden

**Given** Shops is PREPARING in Gomoh and no explicit Coming Soon experiment exists  
**When** Gomoh catalogue is rendered  
**Then** Shops is not shown as live/available.

### AT-05 — PAUSED Product is truthful

**Given** ToTo is PAUSED in Dhanbad  
**When** Dhanbad catalogue is rendered  
**Then** ToTo is shown only according to the agreed paused treatment, with no normal live CTA and no internal state-machine terminology.

### AT-06 — No-live-products state

**Given** a LIVE Location has no public LIVE/visible PAUSED Products  
**When** user selects it  
**Then** Raahi shows an honest polished empty state and allows Location change rather than inventing unavailable services.

---

## Location persistence and reconciliation

### AT-07 — Logged-out Location persists

**Given** a logged-out visitor selects Gomoh  
**When** they refresh/reopen in the same browser with valid lightweight storage  
**Then** Gomoh is restored only after current server validation.

### AT-08 — Invalid saved Location is rejected

**Given** browser storage contains an invalid/retired/tampered Location slug  
**When** shell starts  
**Then** it clears/ignores the invalid preference and asks user to choose a valid Location.

### AT-09 — Explicit current Location beats old Account preference

**Given** visitor explicitly selected Gomoh and their Account preference from an older session is Dhanbad  
**When** they authenticate successfully  
**Then** the active journey remains Gomoh and may update saved preference instead of silently switching to Dhanbad.

### AT-10 — Location change does not grant authority

**Given** an ordinary Account selects Dhanbad  
**When** they attempt a Dhanbad admin command  
**Then** server denies it unless an active Dhanbad Location Admin assignment exists.

### AT-11 — Location change preserves history

**Given** Account has existing Learning history associated with prior contexts  
**When** they switch selected Location  
**Then** no existing Class/request/ride/order/appointment history is rewritten or moved.

---

## Product navigation

### AT-12 — LIVE Product public entry

**Given** Learning is LIVE in Gomoh  
**When** a logged-out visitor taps Learning  
**Then** shell may route them into Learning’s permitted public entry/discovery without forcing shared-shell login.

### AT-13 — Safe Location hint

**Given** user selected Gomoh and enters a focused Product  
**When** shell creates the Product navigation target  
**Then** only normalized non-sensitive Location context is handed off; no identity token/private draft is placed in public URL.

### AT-14 — Malicious destination rejected

**Given** Product configuration or client input attempts to navigate to an unapproved arbitrary origin  
**When** shell prepares navigation  
**Then** the destination is rejected/not rendered as a normal live action.

### AT-15 — Focused Product is final transaction authority

**Given** shell previously displayed ToTo as LIVE  
**And** the mobility product has since become unavailable  
**When** user attempts a ride action  
**Then** mobility backend refuses gracefully and no transaction is created solely because the shell was stale.

---

## Authentication handoff

### AT-16 — Consequential action triggers authentication

**Given** logged-out visitor has prepared a valid action that requires durable personal state  
**When** they attempt final submission  
**Then** authentication is required before business state is created.

### AT-17 — Cancelling authentication creates no partial business state

**Given** authentication was triggered for a prepared action  
**When** user cancels/fails sign-in  
**Then** no consequence is committed and user returns to safe pre-auth context where possible.

### AT-18 — Safe draft resumes after auth

**Given** a valid safe draft and successful authentication  
**When** user returns from provider  
**Then** draft/context is restored, current server state is revalidated, and only then may the action proceed.

### AT-19 — Stale draft does not bypass server

**Given** a draft was valid before authentication but underlying state changed during auth  
**When** user returns  
**Then** current server truth wins and the user gets a recovery path instead of stale automatic submission.

### AT-20 — Wrong Account protection

**Given** a shared device and user authenticates with a different Account than expected  
**When** consequential action is about to submit  
**Then** product/server checks ownership/authority and does not leak or submit another user’s private state.

### AT-21 — Unsafe return URL rejected

**Given** attacker modifies an auth return/deep-link destination to an external/unapproved origin  
**When** auth handoff validates return context  
**Then** redirect is rejected/replaced with a safe Raahi destination.

---

## Profile and trust

### AT-22 — Self profile edit cannot grant authority

**Given** active Account edits display name/avatar  
**When** profile command executes  
**Then** only permitted presentation fields change; admin/trust/product authority remains unchanged.

### AT-23 — Phone proof remains exact

**Given** Account successfully completes phone OTP  
**When** trust is displayed  
**Then** Raahi may say phone confirmed but must not claim identity/professional verification unless separate evidence supports it.

### AT-24 — Failed OTP does not manufacture trust

**Given** challenge expires/provider fails/wrong OTP is entered  
**When** verification fails  
**Then** prior trust state remains unchanged and user gets rule-compliant retry/recovery.

### AT-25 — Expired professional evidence disappears as current claim

**Given** focused Product previously approved a professional verification claim that later expires/revokes  
**When** public trust projection is rendered  
**Then** it no longer presents that claim as current.

---

## Admin authority and lifecycle

### AT-26 — Platform Admin creates Location

**Given** current authenticated Account has Platform Admin capability  
**When** they create a unique valid Location  
**Then** canonical Location is created in allowed initial state and action is audited; duplicate retry does not create another Location.

### AT-27 — Ordinary Account cannot create Location

**Given** authenticated Account has no Platform Admin capability  
**When** they call create-Location command directly  
**Then** server returns unauthorized and no Location is created.

### AT-28 — Location Admin is scoped

**Given** Account is Location Admin for Gomoh only  
**When** they attempt delegated configuration for Dhanbad  
**Then** server denies action without leaking privileged Dhanbad admin data.

### AT-29 — Revoked admin loses future write access immediately

**Given** Location Admin assignment is ended while browser remains open  
**When** stale UI submits another command  
**Then** server denies it based on current assignment.

### AT-30 — LIVE transition needs readiness

**Given** Product is PREPARING in Gomoh  
**And** required integration readiness is missing  
**When** authorized admin requests LIVE  
**Then** transition is rejected with recoverable readiness reason and Product remains PREPARING.

### AT-31 — Concurrent admin transition

**Given** two authorized admins load LocationProduct as LIVE  
**When** admin A pauses it and admin B submits a stale different transition  
**Then** only a transition valid against current canonical state commits; stale command receives current state.

### AT-32 — Duplicate Location Admin assignment prevented

**Given** Account already has active Location Admin assignment for Gomoh  
**When** same/another Platform Admin retries the grant  
**Then** there remains exactly one active assignment and result is idempotent/conflict-safe.

---

## Idempotency and network recovery

### AT-33 — Lost response after successful command

**Given** server commits a consequential command but network response is lost  
**When** client retries with same idempotency key and request fingerprint  
**Then** server returns the original committed outcome and does not duplicate effects.

### AT-34 — Conflicting idempotency-key reuse

**Given** an idempotency key already represents one request fingerprint  
**When** caller reuses it with materially different input  
**Then** server rejects conflict rather than applying second intent.

### AT-35 — Browser refresh does not duplicate public reads

**Given** visitor refreshes homepage repeatedly  
**When** public reads repeat  
**Then** no consequential business state is created.

---

## Privacy/adversarial

### AT-36 — Client role tampering fails

**Given** browser sends a fake role/admin flag/verification timestamp  
**When** protected command executes  
**Then** server ignores client claim and resolves authority/trust from canonical state.

### AT-37 — URL Location tampering fails safely

**Given** attacker changes Location id/slug in URL/request  
**When** server validates it  
**Then** only valid public/current Location is accepted and no authority is gained.

### AT-38 — Wrong Account deep-link privacy

**Given** Account B opens a private deep link created for Account A  
**When** product resolves object access  
**Then** B receives a safe unauthorized/not-found response without private leakage.

### AT-39 — Public shell leaks no provider evidence

**Given** unauthenticated visitor browses catalogue  
**When** network/UI data is inspected  
**Then** no private verification documents, account records or admin configuration are present.

### AT-40 — Shared shell does not ingest focused-product private data unnecessarily

**Given** Learning/Mobility has private operational records  
**When** shell renders public home  
**Then** those records are not required/transferred merely for catalogue rendering.

---

## History/retention

### AT-41 — PAUSE does not delete history

**Given** Product has existing users/history in Gomoh  
**When** LocationProduct becomes PAUSED  
**Then** new normal entry is affected while existing focused-product history remains intact.

### AT-42 — OFF does not delete history

Same as AT-41 for deliberate withdrawal to OFF.

### AT-43 — Ending admin preserves audit

**Given** Location Admin performed valid actions then assignment ends  
**When** audit/history is reviewed  
**Then** prior actions/assignment history remain attributable.

---

## Sponsored-content guardrails

### AT-44 — Sponsored is labelled

**Given** future paid local placement is approved  
**When** shown to user  
**Then** it is clearly labelled Sponsored/Promoted.

### AT-45 — Sponsor payment does not create verification

**Given** advertiser pays for placement  
**When** trust state is rendered  
**Then** no verification claim changes unless separate legitimate evidence/review exists.

### AT-46 — Sponsorship does not secretly override organic legitimacy

**Given** paid placement coexists with organic results  
**When** user views the surface  
**Then** paid visibility is distinguishable and organic/trust ranking rules are not silently rewritten by payment.

---

## Failure/availability

### AT-47 — Public catalogue backend unavailable

**Given** catalogue service fails  
**When** homepage cannot confirm current availability  
**Then** shell presents human retry/recovery and does not invent live Products.

### AT-48 — Free-tier quota/service limit

**Given** underlying free service refuses request due to quota  
**When** shell is affected  
**Then** behavior fails truthfully and does not silently switch to an unauthorized paid dependency.

### AT-49 — Invalid saved preference plus API recovery

**Given** saved Location is invalid and a retry later succeeds  
**When** user selects a valid Location  
**Then** shell recovers without requiring Account recreation or reload of unrelated state.

---

## UI/comprehension

### AT-50 — No internal terminology in normal public journey

**Given** ordinary visitor uses home/Location chooser/catalogue/error states  
**When** visible copy is inspected  
**Then** it does not require understanding LocationProduct, capability, tenant, RPC, lifecycle enum or authentication-subject terminology.

### AT-51 — Mobile controls do not overlap

**Given** representative narrow mobile viewport and realistic/long Location label  
**When** header/home/dialog are rendered  
**Then** primary controls remain usable, non-overlapping and without horizontal page overflow.

### AT-52 — PAUSED card is not mistaken for LIVE CTA

**Given** Product is PAUSED  
**When** card renders  
**Then** user cannot trigger normal LIVE action and unavailable state is clear in text, not only color.

### AT-53 — Error state exposes no raw infrastructure error

**Given** backend returns technical failure  
**When** UI renders recovery  
**Then** user sees human language and stable recovery action, not raw SQL/provider/HTTP internals.

---

# Gate 10 result

**READY AS A REGRESSION CATALOGUE**, but full Gate 10 PASS depends on Gate 9’s real-browser evidence confirming the UI-specific scenarios and on later technology spikes implementing/testing authentication scenarios.

The scenarios are now the canonical acceptance target; passing is staged by implementation slice rather than claimed prematurely.
