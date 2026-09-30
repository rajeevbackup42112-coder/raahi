# MyRaahi — Gate 16 Walking Skeleton E2E v0.1

Last updated: 2026-09-30

Method: AI Builder Cheat Code v2.0 — Gate 16

Status: **PARTIAL — ONE CONTROLLED AUTHENTICATED DEV STATE-TRANSITION PROOF REMAINS**

---

## 1. Walking-skeleton journey

The smallest cross-product Raahi journey is:

> MyRaahi public shell → choose a real Location → open Learn → Learn receives that Location → if authenticated, Learn applies it through its canonical Location-preference command → Learn continues as the same durable Raahi identity.

This is intentionally narrower than a full product launch.

It must prove the boundaries rather than broad feature coverage.

---

## 2. Required boundaries

The walking skeleton must cross:

1. deployed MyRaahi frontend;
2. deployed MyRaahi Worker API;
3. D1 shared public configuration;
4. Product routing;
5. Raahi Learn deployed frontend;
6. shared Raahi identity authority;
7. Learn canonical Location preference command;
8. Learn backend account context.

It must not:
- copy Learn into MyRaahi;
- create a second Location system;
- transfer bearer/refresh tokens in URLs;
- reinterpret Location as role/admin scope;
- bypass the DEV synthetic-write seal;
- change production Auth/DNS merely to prove the test.

---

## 3. Evidence already passed

### WS-01 — Real MyRaahi runtime

**PASS**

Non-production Cloudflare Worker + D1:

- Worker: `myraahi-shell-gate13-staging`
- D1: `myraahi-shell-gate13-staging`
- staging URL:
  `https://myraahi-shell-gate13-staging.rajeev-backup4-2112.workers.dev`

Proven:
- remote D1 migration;
- remote staging fixture;
- health/Locations/catalog API;
- real browser rendering.

---

### WS-02 — Configuration-driven catalogue

**PASS**

Real D1-only changes changed the already-deployed shell without frontend rebuild.

Proven examples:
- public brand metadata Learning → Learn / ToTo → Ride;
- Dhanbad Ride PAUSED → LIVE → PAUSED;
- corresponding live catalogue/browser behavior changed;
- staging baseline was restored;
- D1 audit evidence remained.

This proves MyRaahi public availability is configuration-driven.

---

### WS-03 — MyRaahi produces a safe focused-Product handoff

**PASS**

For Gomoh → Learn, the real staging shell generated:

`https://learning.myraahi.co.in/?raahi_location=gomoh`

Observed:
- destination is a Raahi-owned origin;
- only safe Location context is passed;
- no access token;
- no refresh token;
- no email/phone;
- no admin/role/trust claim.

The focused Product loaded successfully in a real browser with the Location hint present.

---

### WS-04 — Durable identity continuity

**PASS**

Gate 13D proved:

- central identity authority = Supabase Auth project `iiwwmqokaeflaenhlyip`;
- same designated Google human on a separate allowed DEV surface resolved to the same Supabase user UUID;
- privacy-safe comparison returned `same_raahi_subject=true`;
- explicit test Location Gomoh survived OAuth;
- isolated proof sign-out did not disturb the public Learn session.

Therefore:
> Raahi identity continuity is real; browser session continuity is not required for V1.

---

### WS-05 — Learn canonical Location mechanism identified

**PASS**

Raahi Learn already owns the authoritative preference command:

`public.set_selected_location(p_location_id, p_idempotency_key)`

implemented through:

`app_private.cmd_set_selected_location`

It:
- requires an authenticated/current Account;
- validates the Location;
- rejects retired Location;
- writes `account_location_preferences`;
- uses the existing idempotency framework;
- returns the canonical Location result.

No new Location table/state was created for MyRaahi integration.

---

### WS-06 — Learn MyRaahi Location adapter implemented

**PASS AT CODE/CONTRACT LEVEL**

Learning branch:

`raahi-learning-implementation-v1`

Adapter:

`apps/raahi-learning/myraahi-location-handoff-v1.js`

Current integration commit family:
- initial adapter: `ef6611c3764690ba4e0a31190a3dc45e64e60502`
- build/CI corrections followed;
- cloud-proof branch state: `e96a6236df75cfac6a1a4373fb3abb35c41f38a9`

Adapter behavior:
1. reads only `raahi_location`;
2. validates normalized slug;
3. stores pending handoff in sessionStorage so it can survive auth navigation;
4. removes the query from the visible URL;
5. waits for Learn authenticated Account context + canonical Location list;
6. matches by Learn's own Location slug;
7. requires Location state = LIVE;
8. if already selected, performs no write;
9. otherwise invokes `set_selected_location` with an idempotency key;
10. refreshes `get_my_account_context`;
11. updates Learn from canonical server context;
12. never directly writes `account_location_preferences`;
13. never reads/moves auth tokens;
14. never changes role/admin scope.

---

### WS-07 — Existing Learning regression surface remains healthy

**PASS**

Evidence around the integration:

- Model Tests run `36708780190` → SUCCESS at `19eb96a…`;
- Onboarding Browser Contract run `36708718077` → SUCCESS after packaging correction;
- cloud-proof Model Tests run `36709495982` → SUCCESS at `e96a6236…`.

The full reconstructed Learning browser contract continued to pass:
- responsive shell;
- Notifications;
- mobile action targets;
- Settings;
- conversations;
- Teacher;
- Institute;
- Local Manager;
- Platform;
- Ads;
- human-language and onboarding checks.

Earlier failures during this slice were classified correctly:
- CI newline injected into shell command → test/workflow wiring defect;
- literal newline token in build source → packaging defect;
- test expected `location.state` instead of actual `target.state` → test-harness defect.

No business rule was weakened to make tests pass.

---

### WS-08 — Actual adapter behavior is exercised in cloud CI

**PASS**

`tests/myraahi-location-handoff-v1.test.mjs` executes the actual adapter source in a controlled JS VM.

It proves:

Logged-out phase:
- Dhanbad hint captured;
- idempotency key generated;
- no canonical write before authenticated Account context exists.

Authenticated simulated Learn phase:
- real adapter calls `set_selected_location`;
- target Location ID is Dhanbad;
- idempotency key is reused;
- adapter calls `get_my_account_context`;
- returned canonical context becomes Dhanbad;
- pending session state is cleared;
- Learn re-render is requested.

This is executable logic evidence, not only regex/static inspection.

---

### WS-09 — Real deployed DEV browser read-only integration proof

**PASS**

Workflow:
`MyRaahi Learn Location Handoff Readonly`

Run:
`36709496149`

Target SHA:
`e96a6236df75cfac6a1a4373fb3abb35c41f38a9`

Result:
**SUCCESS**

Sanitized artifact:
`myraahi-learning-location-handoff-readonly-36709496149-1`

Artifact digest:
`sha256:effd883eb4ddfd4913c65ae7167c825f7f21cf86765aab513dfe4c47acd67607`

Observed deployment:
- deployed app SHA: `ae6a7e8e9c215ea554e2475a39319ad561e8ce46`;
- source-compatible with target;
- later changed files were tests/workflows only;
- `appChanges=[]`.

Real Chromium against:
`https://dev.learning.myraahi.co.in/?raahi_location=dhanbad#/home`

Observed:
- deployed adapter asset present;
- Dhanbad hint captured;
- query parameter removed from visible URL;
- zero calls to `set_selected_location` while logged out;
- normal Learn signed-out UI rendered;
- no backend mutation occurred.

This proves the deployed adapter respects the authentication boundary.

---

## 4. Safety guard encountered during proof

The existing controlled-pilot system deliberately removed:

`.github/RAAHI_LEARNING_DEV_WRITES_ENABLED`

The project test:
`tests/dev-write-seal.test.mjs`

requires:
- the marker remain absent;
- known synthetic writer workflows remain manual-only;
- the workflows fail closed when the marker is missing.

An attempted automatic DEV E2E run stopped at:

`Guard DEV synthetic writes`

before any synthetic account or database write occurred.

That was correct system behavior.

The accidental push trigger added to the writer workflow was removed immediately.

Restoration commit:
`ae6a7e8e9c215ea554e2475a39319ad561e8ce46`

The seal must not be bypassed merely to complete Gate 16.

---

## 5. The one remaining proof

### WS-10 — Authenticated deployed browser → canonical Learn Location write

**PENDING**

Required evidence:

1. use an authorized authenticated Raahi Learn DEV/test browser context;
2. initial canonical selected Location is known and different from target;
3. enter Learn with a valid MyRaahi Location hint;
4. deployed adapter captures/cleans the hint;
5. adapter calls real `set_selected_location`;
6. backend commits the Location preference;
7. real `get_my_account_context` returns target Location;
8. browser Learn context renders the target Location;
9. no role/capability/admin scope changes;
10. retry/reload does not duplicate harmful effects.

Preferred target example:
- initial = Gomoh
- incoming = Dhanbad

This is a real DEV write to one Account preference.

It must be executed only through an explicitly authorized controlled test path.

Do not:
- recreate the removed DEV-write marker casually;
- auto-run sealed synthetic writers;
- use service-role/direct table writes as a substitute;
- modify production user preference merely to satisfy the gate.

---

## 6. Why Gate 16 is not yet marked PASS

The AI Builder walking-skeleton rule requires one real frontend → backend → database → frontend loop.

We have separately proven:
- real frontend;
- real Worker/D1;
- real cross-product navigation;
- real identity;
- real deployed adapter capture;
- actual adapter command behavior in deterministic CI;
- the real canonical Learn RPC.

But the exact combined deployed authenticated adapter → real Learn preference write has not yet been observed.

Therefore:

> **Gate 16 remains PARTIAL rather than being overstated as PASS.**

This is an evidence gap, not a product-design or implementation gap.

---

## 7. Production state

No MyRaahi production launch has occurred.

No production `myraahi.co.in` DNS switch has occurred.

No production Google/Supabase Auth configuration change was made for this integration.

No production Learning Location preference was changed to satisfy Gate 16.

---

# Gate 16 result

**PARTIAL — one controlled authenticated DEV preference-transition proof remains.**

Once WS-10 passes, Gate 16 can close and Gate 17 vertical-slice implementation may begin.
