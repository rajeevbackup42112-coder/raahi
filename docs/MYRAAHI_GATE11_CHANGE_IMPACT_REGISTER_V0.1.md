# MyRaahi Shared Front Door — Gate 11 Change Impact Register v0.1

Last updated: 2026-09-26

Method: AI Builder Cheat Code v2.0 — Gate 11

Classification:
- **A — UI/copy only**
- **B — orchestration only**
- **C — small backend extension**
- **D — domain/business-rule change**

This register prevents the new shared Raahi shell from silently changing existing focused products.

---

## CR-01 — Create myraahi.co.in as a common front door

**Current behavior**
Existing Raahi products are entered independently.

**Observed problem/evidence**
Raahi now has multiple local products and needs a location-first common starting point without merging their domain logic.

**Proposed behavior**
One shared location-first front door routes users to Products live in the selected Location.

**Classification**
**D for the new shared platform domain**, but **no direct change** to focused-product rules.

**Impact**
- Rules: adds shared discovery/routing rules.
- Entities: Location, Product, LocationProduct.
- Relationships: shared configuration only.
- States: shared Location/Product availability.
- Permissions: shared admin scope.
- UI: new shell.
- Tests: new shared acceptance catalogue.
- Architecture/DB: new lightweight shared boundary.

**Decision**
**ADOPT.**

---

## CR-02 — Public discovery before authentication

**Current behavior**
Raahi Learning production historically uses Google-first entry.

**Observed problem/evidence**
Shared front door must show value before asking for identity; Raahi ToTo model already established “Discovery is public. Transactions are authenticated.”

**Proposed behavior**
Shared shell public browsing; auth only at meaningful persistent action.

**Classification**
**D** if applied to an existing focused Product’s protected acquisition flow.
**B/new behavior** inside the new shared shell because no prior shell exists.

**Impact**
Applying this to Learning itself would affect UI, auth boundary, public data projections, privacy and tests.

**Decision**
**ADOPT for shared shell.**
**DEFER for changing Learning production.** Learning requires its own impact analysis before logged-out discovery changes.

---

## CR-03 — One Account with multiple capabilities rather than one global role

**Current behavior**
Different products have historically used role-oriented routing in different ways.

**Observed problem/evidence**
Same human can be parent/teacher/driver/shop owner/admin across Raahi; a single platform role is structurally wrong.

**Proposed behavior**
Shared Account is role-neutral; product relationships/capabilities remain scoped.

**Classification**
**D.**

**Decision**
**ADOPT for shared foundation.** Do not migrate existing product role models wholesale until each adapter is designed.

---

## CR-04 — Location is context, not Account identity

**Classification**
**D shared-domain rule.**

**Decision**
**ADOPT.**

---

## CR-05 — Add Location × Product enablement

**Current behavior**
Products know their own locations; no common cross-product catalogue exists.

**Proposed behavior**
Shared LocationProduct relationship determines public Product availability.

**Classification**
**D shared-domain addition.**

**Decision**
**ADOPT.**

---

## CR-06 — Show PAUSED Product rather than always hiding it

**Classification**
**A/B product default**, not invariant.

**Decision**
**ADOPT as V0 default**, subject to usability evidence. Can change later without domain redesign if rules remain truthful.

---

## CR-07 — Use “How can Raahi help you today?” as homepage primary question

**Classification**
**A.**

**Decision**
**ADOPT as current wording baseline.**

---

## CR-08 — Manual Location selection before automatic GPS

**Classification**
**B/UI orchestration default.**

**Decision**
**ADOPT V0.** Future optional suggestion can be added if evidence shows value; explicit user selection remains authoritative.

---

## CR-09 — Cloudflare Worker + D1 public shell

**Classification**
**C / architecture choice**, not domain change.

**Decision**
**PROVISIONALLY ADOPT for public-shell technology spike/walking skeleton.** Must pass Gate 13 real staging proof before architecture freeze.

---

## CR-10 — Put shared shell inside Learning’s current Supabase project

**Classification**
**C/D architecture coupling.**

**Decision**
**REJECT as first implementation path.**

---

## CR-11 — Create another Supabase Free project solely for common shell

**Decision**
**REJECT as default.**

---

## CR-12 — Google-first shared Account authentication

**Classification**
**D identity behavior / architecture-dependent.**

**Decision**
**DEFER FINAL FREEZE to Gate 13.** It remains current direction, not proven shared SSO solution.

---

## CR-13 — Phone-only universal login

**Classification**
**D.**

**Decision**
**DEFER/DO NOT DEFAULT.** Adopt only if real pilot evidence demonstrates Google-first exclusion/problem and architecture supports safe recovery.

---

## CR-14 — Shared cross-product SSO

**Classification**
**D identity/integration behavior.**

**Decision**
**ADOPT as desired outcome, DEFER implementation design to Gate 13 spike.**

---

## CR-15 — Generic universal provider verification engine

**Classification**
**D.**

**Decision**
**REJECT for V1 shared core.** Share exact claims only when a real repeated abstraction emerges.

---

## CR-16 — Full shared advertising platform now

**Decision**
**DEFER.** Keep only doctrine/guardrails until real advertiser workflow is designed.

---

## CR-17 — AI-first homepage/search

**Decision**
**REJECT for initial shell; DEFER until catalogue breadth/real language data makes it useful.**

---

## CR-18 — Existing public-shell scaffold built before strict Gate sequence

**Classification**
**Implementation sequencing issue, not product rule change.**

**Decision**
**RECLASSIFY as prototype/spike evidence.** Do not discard it; do not treat it as production-ready until Gates 0–16 pass.

---

## CR-19 — Browser-based automated UI evidence

**Decision**
**ADOPT.** Does not change product behavior.

---

## CR-20 — Current Playwright selector fixes

**Observed failures**
Ambiguous test selectors matched two valid UI controls/accessibility strings.

**Classification**
**Test/harness defect** under Gate 18 taxonomy.

**Decision**
**ADOPT test-only fixes.** Do not change UI merely to satisfy a bad selector.

---

# Gate 11 result

The shared-shell change register is **complete for current decisions**.

Important boundary:
- public browse before auth is frozen for the shared shell;
- it is **not permission to alter Raahi Learning production’s auth boundary** without a separate product-level impact analysis.

Architecture decisions remain provisional until Gate 12 review + Gate 13 proof.