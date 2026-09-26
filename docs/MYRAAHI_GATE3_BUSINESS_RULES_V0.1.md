# MyRaahi Shared Front Door — Gate 3 Canonical Business Rule Catalogue v0.1

Last updated: 2026-09-26

Method: AI Builder Cheat Code v2.0 — Gate 3

Scope: shared `myraahi.co.in` front door and common location/identity foundation.

Rule format:

**Action → Actor → Preconditions → Invariant → Permitted effect → Failure/recovery**

Implementation choices such as Cloudflare, D1, Supabase, cookies, subdomains and specific frameworks are intentionally excluded from business rules unless the rule depends on an externally proven primitive.

---

## BR-01 — Browse Raahi without an Account

**Action** → Open shared Raahi home  
**Actor** → Visitor  
**Preconditions** → Shared public service is available  
**Invariant** → Passive discovery must not require identity/phone/precise GPS  
**Permitted effect** → Show the public Location-selection experience  
**Failure/recovery** → If public configuration is unavailable, show truthful retry/recovery; do not invent a default Location or force sign-in

---

## BR-02 — Select browsing Location

**Action** → Select Location  
**Actor** → Visitor or Account holder  
**Preconditions** → Location exists and is publicly selectable  
**Invariant** → Selected Location is context only, not identity/authority  
**Permitted effect** → Make Location the current browsing context; for authenticated Account it may also become saved preference  
**Failure/recovery** → If Location is no longer selectable, keep user identity/session intact and ask them to choose another Location

---

## BR-03 — Preserve explicit Location across authentication

**Action** → Authenticate after explicitly selecting Location  
**Actor** → Visitor becoming Account holder  
**Preconditions** → Safe current Location context exists; authentication succeeds  
**Invariant** → Recent explicit user intent must not be silently replaced by an older stored preference  
**Permitted effect** → Continue current journey in explicit Location and optionally update saved Account preference  
**Failure/recovery** → If selected Location becomes unavailable during auth, return user to Location chooser with session preserved

---

## BR-04 — Show local Product catalogue

**Action** → View products for selected Location  
**Actor** → Visitor or Account holder  
**Preconditions** → Location is valid for public browsing  
**Invariant** → Raahi must not present unavailable/unapproved Products as live local capability  
**Permitted effect** → Show only Product entries allowed by current Location × Product public state  
**Failure/recovery** → On uncertain/unavailable configuration, show retry/unavailable state; do not substitute stale false availability without an explicitly approved cache policy

---

## BR-05 — Hide OFF/PREPARING Product from ordinary live catalogue

**Action** → Build public catalogue  
**Actor** → Shared backend/shell  
**Preconditions** → LocationProduct current state is OFF or PREPARING  
**Invariant** → Internal setup must not be represented as available service  
**Permitted effect** → Exclude from ordinary live choices  
**Failure/recovery** → A future Coming Soon experiment requires an explicit product change, not accidental exposure

---

## BR-06 — Present PAUSED Product truthfully

**Action** → Build public catalogue  
**Actor** → Shared backend/shell  
**Preconditions** → LocationProduct state is PAUSED; Location itself remains public  
**Invariant** → Returning users must not be misled into believing temporarily unavailable service is live  
**Permitted effect** → Show Product as temporarily unavailable when product contract calls for visibility; block normal new entry/action as live  
**Failure/recovery** → User may choose another Product/Location or retry later

---

## BR-07 — Enter a focused Product

**Action** → Open focused Product  
**Actor** → Visitor or Account holder  
**Preconditions** → Product is LIVE for selected Location; destination is an approved Raahi integration target  
**Invariant** → Shared shell may route but must not create product authority  
**Permitted effect** → Navigate with only safe routing context such as normalized Location hint  
**Failure/recovery** → If destination unavailable/invalid, remain in shell and show truthful recovery; never navigate to arbitrary untrusted URL

---

## BR-08 — Trigger authentication only at consequential action

**Action** → Attempt a shared/product action that creates/accesses meaningful persistent personal state  
**Actor** → Visitor  
**Preconditions** → Focused/shared rule declares authentication required  
**Invariant** → Discovery remains public while consequential private state requires accountable identity  
**Permitted effect** → Start authentication handoff with safe return context  
**Failure/recovery** → Cancellation returns user to safe pre-auth context; no partial business state is created

---

## BR-09 — Preserve safe draft across authentication

**Action** → Resume after successful authentication  
**Actor** → Newly authenticated Account holder  
**Preconditions** → Pre-auth draft/context is still valid and safe to restore  
**Invariant** → Authentication must not make user repeat valid work without necessity; restored draft cannot bypass current server validation  
**Permitted effect** → Restore safe context and continue to intended action  
**Failure/recovery** → If draft is stale/unsafe/invalid, preserve session and explain what must be re-entered or refreshed

---

## BR-10 — Create/use durable Raahi Account

**Action** → Establish Account from authenticated identity  
**Actor** → Authenticated human  
**Preconditions** → Authentication evidence is valid and not already linked incompatibly  
**Invariant** → One authentication identity cannot silently create duplicate active Raahi Accounts  
**Permitted effect** → Resolve/create one durable Account according to identity-linking rules  
**Failure/recovery** → Ambiguous/conflicting identity enters recovery/support path; never auto-merge accounts without explicit safe rule

---

## BR-11 — Update own shared profile presentation

**Action** → Edit display name/avatar presentation  
**Actor** → Active Account holder  
**Preconditions** → Authenticated; input valid  
**Invariant** → Self-service profile edits cannot modify authority, trust evidence or product relationships  
**Permitted effect** → Update permitted own presentation fields  
**Failure/recovery** → Reject invalid fields without changing protected state

---

## BR-12 — Confirm phone trust

**Action** → Complete phone OTP challenge  
**Actor** → Authenticated Account holder  
**Preconditions** → Valid challenge/session; provider verification succeeds; anti-abuse rules pass  
**Invariant** → Phone proof means control of phone only; never identity/professional authority  
**Permitted effect** → Record server-owned phone trust evidence/time according to trust model  
**Failure/recovery** → Failed/expired/provider-error challenge leaves prior trust state unchanged and offers safe retry when allowed

---

## BR-13 — Claim professional/provider verification

**Action** → Present verification status publicly  
**Actor** → Focused Product/shared public projection  
**Preconditions** → Relevant focused product has current approved evidence/claim  
**Invariant** → Claimed/submitted/phone-confirmed/identity-verified/profession-verified are different truths  
**Permitted effect** → Display only exact current verification claim  
**Failure/recovery** → Expired/revoked/unknown evidence must remove or downgrade claim; never fall back to generic “Verified”

---

## BR-14 — Create Location

**Action** → Create Raahi Location  
**Actor** → Platform Admin  
**Preconditions** → Current platform authority; required fields; unique slug/name rules  
**Invariant** → Client input cannot self-grant platform authority; duplicate canonical Location identity prevented  
**Permitted effect** → Create Location initially in controlled non-live state unless explicit readiness rule permits otherwise  
**Failure/recovery** → Validation/conflict returns no partial Location/configuration

---

## BR-15 — Change Location lifecycle

**Action** → Transition Location state  
**Actor** → Platform Admin  
**Preconditions** → Current state permits requested transition; stronger confirmation/reason where required  
**Invariant** → State change must not destroy historical product/user relationships  
**Permitted effect** → Apply allowed transition atomically and audit it  
**Failure/recovery** → Invalid/stale transition rejected with current state; admin reloads/reconsiders

---

## BR-16 — Create shared Product registry entry

**Action** → Register Product  
**Actor** → Platform Admin  
**Preconditions** → Unique stable Product key; approved display/integration data  
**Invariant** → Product registry describes capability, not product-domain operational data  
**Permitted effect** → Create ACTIVE shared Product definition  
**Failure/recovery** → Reject duplicates/unsafe destination without partial entry

---

## BR-17 — Configure Product availability for Location

**Action** → Change LocationProduct state/config  
**Actor** → Platform Admin or explicitly delegated Location Admin  
**Preconditions** → Current scoped authority; valid Location/Product; allowed transition; readiness evidence for LIVE where required  
**Invariant** → Admin scope is server-validated; shared discoverability change does not rewrite focused-product history  
**Permitted effect** → Apply one Location × Product transition and audit it  
**Failure/recovery** → Stale state, missing readiness or out-of-scope actor gets recoverable rejection; no partial state

---

## BR-18 — Activate Product LIVE only when integration is genuinely ready

**Action** → Transition LocationProduct to LIVE  
**Actor** → Authorized admin expresses intent; readiness rule owns permission  
**Preconditions** → Location is eligible; Product active; integration destination valid; required readiness checks pass  
**Invariant** → “LIVE” means ordinary users can genuinely receive the promised product experience  
**Permitted effect** → Expose as live public choice  
**Failure/recovery** → Keep PREPARING/PAUSED and report missing readiness; never override simply for marketing convenience

---

## BR-19 — Assign Location Admin

**Action** → Assign Location Admin authority  
**Actor** → Platform Admin  
**Preconditions** → Target Account active; Location valid; no duplicate active assignment  
**Invariant** → Selected Location or ordinary Account status never implies admin authority  
**Permitted effect** → Create active scoped assignment with audit/history  
**Failure/recovery** → Conflict/invalid Account rejected without changing other scopes

---

## BR-20 — End Location Admin authority

**Action** → End Location Admin assignment  
**Actor** → Platform Admin  
**Preconditions** → Active target assignment exists  
**Invariant** → Ending authority does not erase historical actions/assignment history  
**Permitted effect** → Mark assignment ended/revoked; future shared admin commands fail scope check  
**Failure/recovery** → Duplicate retry returns stable result/idempotent outcome; stale UI cannot preserve revoked power

---

## BR-21 — Execute shared consequential command

**Action** → Any shared state-changing command  
**Actor** → Authorized human through UI/client  
**Preconditions** → Authenticated where required; current server authority; valid current state; idempotency input where consequential  
**Invariant** → Server authority/current state beats stale UI; coupled effects are atomic where business-coupled  
**Permitted effect** → Commit valid transition and required audit/idempotency result  
**Failure/recovery** → No partial transition; return stable human-recoverable machine reason

---

## BR-22 — Retry shared consequential command

**Action** → Retry same command  
**Actor** → Same authorized Account/system client  
**Preconditions** → Same idempotency key/fingerprint for same intended action  
**Invariant** → Retry cannot duplicate consequential outcome  
**Permitted effect** → Return prior committed result or safely continue once  
**Failure/recovery** → Same key with conflicting input is rejected as idempotency conflict

---

## BR-23 — Reject client-derived authority

**Action** → Evaluate any claimed role/scope/trust from browser input  
**Actor** → Shared/focused backend  
**Preconditions** → Client supplies context/claim  
**Invariant** → Client visibility, hidden buttons, role labels, Location choice or stale session state are not authority  
**Permitted effect** → Resolve authority from current server-owned relationship/capability state  
**Failure/recovery** → Unauthorized action rejected; UI refreshes authoritative context

---

## BR-24 — Keep product-specific business logic product-owned

**Action** → Execute product transaction  
**Actor** → Product participant  
**Preconditions** → User entered focused Product and satisfies its rules  
**Invariant** → Shared shell identity/routing cannot bypass focused-product authority/state machine  
**Permitted effect** → Focused Product handles its own transition  
**Failure/recovery** → Product-specific recovery remains in focused Product; shared shell may only provide navigation/support context

---

## BR-25 — Protect history when Location/Product availability changes

**Action** → Pause/off/retire shared Location or LocationProduct  
**Actor** → Authorized admin  
**Preconditions** → Valid transition/governance  
**Invariant** → Availability for new discovery is separate from historical accepted/published relationships/transactions  
**Permitted effect** → Stop/alter new shared entry as defined while preserving product history  
**Failure/recovery** → Existing authorized users can still reach product history according to product rules; no silent deletion/reassignment

---

## BR-26 — Sponsored visibility remains separate from trust

**Action** → Show future paid placement  
**Actor** → Shared/focused advertising surface  
**Preconditions** → Valid approved sponsored placement in selected Location/context  
**Invariant** → Payment cannot buy verification, admin authority or secret organic rank manipulation  
**Permitted effect** → Show limited clearly labelled Sponsored placement  
**Failure/recovery** → Invalid/expired placement disappears; organic/trust state remains unchanged

---

## BR-27 — Do not collect unnecessary identity

**Action** → Request user data  
**Actor** → Shared shell/product onboarding  
**Preconditions** → Data is necessary for current permitted action  
**Invariant** → Minimum data and purpose limitation  
**Permitted effect** → Collect/use only required data  
**Failure/recovery** → If user declines optional data, continue where business rule safely allows; do not block public discovery

---

## BR-28 — External provider failure must not manufacture success

**Action** → Depend on authentication/OTP/other external provider  
**Actor** → Shared backend/system  
**Preconditions** → External call/result required  
**Invariant** → Missing/failed/ambiguous provider evidence cannot be treated as success  
**Permitted effect** → Commit only after required provider evidence is valid  
**Failure/recovery** → Preserve safe prior state and allow retry/recovery according to rate/safety rules

---

## BR-29 — Free infrastructure is a design constraint, not a truth override

**Action** → Choose infrastructure/integration  
**Actor** → Product/engineering owner  
**Preconditions** → Capability need is proven  
**Invariant** → Cost avoidance cannot justify misleading availability, weak security or broken authority  
**Permitted effect** → Prefer free/open/self-hosted option that satisfies rules and evidence  
**Failure/recovery** → If no safe free option exists, stop for explicit business decision rather than silently weakening rules

---

## BR-30 — Focused Product readiness is authoritative for product action

**Action** → User enters Product from a catalogue that has become stale  
**Actor** → Visitor/Account holder  
**Preconditions** → Shared shell previously displayed Product as LIVE  
**Invariant** → Current focused-product/server state beats earlier shared UI state  
**Permitted effect** → Product validates current serviceability before consequential action  
**Failure/recovery** → Product refuses gracefully and directs user back/retry; shared state can subsequently reconcile

---

# Product defaults vs business rules

The following are **defaults**, not invariants:

- homepage copy “How can Raahi help you today?”
- card-based navigation rather than search/AI;
- manual Location selection first;
- PAUSED Product visible rather than hidden;
- Google-first Account sign-in direction;
- specific visual layout/iconography.

Changing these may be UI/orchestration change if underlying rules stay intact.

# Technical choices, not business rules

The following are currently technical choices/spikes:

- Cloudflare Worker;
- D1;
- Supabase;
- Auth.js;
- cookies/localStorage mechanism;
- subdomain topology;
- exact cache TTL;
- exact programming framework.

They must not be promoted into product invariants without evidence.

# Gate 3 result

**PASS**, subject to reconciliation with Gates 4–6.

No unresolved business decision blocks the shared-shell rule catalogue at this stage.

Next gate: **Gate 4 — Reconcile and freeze domain invariants against these normalized rules**.
