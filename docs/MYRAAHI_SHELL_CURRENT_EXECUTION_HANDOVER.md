# MyRaahi Shared Shell — Current Execution Handover

Last updated: 2026-09-26

## Purpose

Exact execution continuity for the isolated `myraahi.co.in` public-shell walking skeleton.

This is separate from the cross-project strategy handover at:

`docs/RAAHI_MASTER_HANDOVER.md`

---

## Repository state

Repository:

`rajeevbackup42112-coder/raahi`

Implementation branch:

`myraahi-shared-shell-v1`

Current validated HEAD:

`a99ee64924afbca98178dfb59c4d86bee5944f4c`

Important preceding commits:

- `7b806836da64968ceddedce1e426167972192a61` — scaffold isolated MyRaahi public shell
- `8a8349430bcccdc8ec3f5720a5563a37aac76507` — add shell CI validation
- `24ddbed73f487027f9e2a0bf00738558335d267a` — pin current Cloudflare toolchain
- `699871e0a5ae9b98508e01cd66415a1c5c1e1dda` — fix Worker header typing

No production deployment has occurred.

No production DNS has changed.

No Learning production database/auth behavior has changed.

---

## Validation evidence

GitHub Actions workflow:

`Validate MyRaahi Shell`

Latest successful run:

- Run ID: `36247865290`
- Head SHA: `c3424217c1ce8a43866b705ce3cc42f7cbe842d7`
- Result: **SUCCESS**

Passed steps:

1. dependency install
2. TypeScript Worker typecheck
3. browser JavaScript syntax check
4. Wrangler Worker dry-run bundle
5. SQLite/D1 schema application
6. development fixture application/assertions
7. Chromium installation
8. real-browser Playwright UI checks on mobile/desktop/stress cases
9. UI evidence artifact upload

Gate-9 browser evidence also found and fixed one implementation defect: selected Location context is now preserved in catalogue-error copy.

Earlier failed CI attempts were resolved:
- first failure: invalid old Cloudflare Workers types version
- second failure: TypeScript header object narrowing
- both are fixed in current HEAD

---

## Current implementation

Path:

`apps/myraahi-shell/`

Contains:

- `src/index.ts`
  - read-only public Worker API
  - `GET /api/v1/health`
  - `GET /api/v1/locations`
  - `GET /api/v1/catalog?location=<slug>`
  - D1 parameterized queries
  - static-asset fallback
  - basic security headers

- `public/index.html`
  - Raahi location-first homepage
  - no login wall
  - “How can Raahi help you today?”

- `public/styles.css`
  - mobile-first responsive shell

- `public/app.js`
  - logged-out Location browser persistence
  - catalogue loading
  - LIVE/PAUSED rendering
  - Raahi-owned Product URL validation
  - Location hint handoff
  - human loading/error/recovery states

- `migrations/0001_public_shell.sql`
  - locations
  - products
  - location_products
  - config_audit_events
  - schema_meta
  - indexes/check constraints

- `fixtures/dev-seed.sql`
  - DEVELOPMENT/STAGING ONLY illustrative Gomoh/Dhanbad configuration
  - explicitly not production launch truth

- `wrangler.jsonc`
  - Worker/static-assets/D1 structure
  - D1 database ID intentionally placeholder
  - no production route configured

- `README.md`
  - scope, safety and local setup

CI:

`.github/workflows/myraahi-shell-ci.yml`

---

## Important product/architecture state

Read before continuing:

1. `docs/MYRAAHI_SHARED_FRONT_DOOR_PRODUCT_CONTRACT_V0.1.md`
2. `docs/MYRAAHI_SHARED_FOUNDATION_DOMAIN_MODEL_V0.1.md`
3. `docs/MYRAAHI_SHARED_FRONT_DOOR_SCREEN_BACKEND_CONTRACTS_V0.1.md`
4. `docs/MYRAAHI_FREE_INFRA_IDENTITY_ARCHITECTURE_GATE_V0.1.md`
5. `docs/MYRAAHI_PUBLIC_SHELL_D1_WORKER_BLUEPRINT_V0.1.md`
6. `docs/RAAHI_DNA_V0.1.md`
7. `docs/RAAHI_SHARED_FOUNDATION_REUSE_MATRIX_V0.1.md`

Frozen direction:

- shared front door = `myraahi.co.in`
- Location first
- public discovery before authentication
- focused products remain independent
- Cloudflare Worker + D1 is the first public-shell walking-skeleton architecture
- live Learning backend is not being repurposed/migrated for this first step
- shared Account/SSO is a separate technology spike after the public shell proof

---

## What has NOT been done

Do not assume any of these exist yet:

- Cloudflare D1 database
- Cloudflare Worker deployment
- staging URL
- `myraahi.co.in` DNS/production route
- production Location/Product data
- shared Account/SSO
- OTP integration
- admin web UI
- sponsored content
- Learning production Location deep-link adapter
- browser visual QA

---

## Gate 13 runtime proof — completed

Real non-production Cloudflare resources now exist:

- staging D1: `myraahi-shell-gate13-staging`
- staging Worker: `myraahi-shell-gate13-staging`
- staging URL: `https://myraahi-shell-gate13-staging.rajeev-backup4-2112.workers.dev`
- deployed Worker version: `a91ea906-7d3a-450f-81b1-7243363a2ae9`

Proven in real Cloudflare runtime:
- D1 migration applied remotely;
- staging fixture applied remotely;
- health/locations/catalog APIs return correct data;
- real browser renders against deployed Worker/D1;
- public Product names update from D1 without frontend redeploy;
- LocationProduct LIVE/PAUSED state updates from D1 without frontend redeploy.

The temporary Dhanbad Ride LIVE proof was reverted. Current intended staging baseline:
- Dhanbad Learn = LIVE
- Dhanbad Ride = PAUSED

Branding decision:
- public `learning` display = **Learn**
- public `toto` display = **Ride**
- stable internal keys remain `learning` and `toto`
- fuller focused-brand forms may be **Raahi Learn** and **Raahi Ride**

Latest branch validation:
- commit `4704da826f4b1256b9a9008bcacd5d99c35647f1`
- workflow `Validate MyRaahi Shell`
- run `36291608117`
- result: SUCCESS

## Gate 13D shared-identity state

V1 architecture direction is now frozen:

- shared identity authority = Supabase Auth project `iiwwmqokaeflaenhlyip`
- MyRaahi D1 does not become the production Account identity store
- stable authenticated subject = verified Supabase issuer + user UUID
- public MyRaahi remains login-free
- focused products retain their own roles/capabilities/transactions
- origin-local sessions are acceptable for V1
- seamless true SSO is optional future UX, not a launch blocker

Detailed main-branch doc:
`docs/MYRAAHI_GATE13_SHARED_IDENTITY_SSO_SPIKE_V0.1.md`

Existing isolated branch spike:
- `migrations/0002_gate13_sso_spike.sql`
- `src/gate13-sso-spike.ts`
- disabled unless `ENABLE_GATE13_SSO_SPIKE=true`
- verifies Learn ES256 JWT via public JWKS
- accepts token only in HTTPS POST body
- creates spike-only D1 identity/session rows
- issues HttpOnly/Secure/SameSite=Lax MyRaahi spike cookie
- explicitly NOT production SSO design

Privacy-safe fallback harness:
- `spikes/shared-identity/generate-proof.mjs`
- compares SHA-256 of subject and outputs only boolean identity continuity

Latest CI:
- branch HEAD `a99ee64924afbca98178dfb59c4d86bee5944f4c`
- run `36297963846`
- result: SUCCESS

## Cross-product Gate 16 state

MyRaahi public shell work is now integrated with Raahi Learn through a dedicated Location adapter on:

`raahi-learning-implementation-v1`

Learning branch HEAD:
`e96a6236df75cfac6a1a4373fb3abb35c41f38a9`

Adapter:
`apps/raahi-learning/myraahi-location-handoff-v1.js`

Cloud evidence:
- Model Tests `36709495982` = SUCCESS
- deployed DEV read-only handoff `36709496149` = SUCCESS
- deployed adapter captures Dhanbad hint, removes query, and performs zero writes while logged out
- executable adapter test proves authenticated path calls canonical `set_selected_location` then refreshes `get_my_account_context`

Canonical main-branch evidence:
`docs/MYRAAHI_GATE16_WALKING_SKELETON_V0.1.md`

## Exact next action

Gate 16 remains PARTIAL for one reason only:

perform one explicitly authorized authenticated DEV/browser handoff proving:

MyRaahi Location hint
→ deployed Learn adapter
→ real `set_selected_location`
→ real `get_my_account_context`
→ same target Location in UI/backend.

Do not:
- recreate/bypass `.github/RAAHI_LEARNING_DEV_WRITES_ENABLED`;
- auto-run sealed synthetic writer workflows;
- mutate a production user preference for evidence;
- direct-write `account_location_preferences`;
- start Gate 17 broad implementation before this proof.

Everything else in Gates 0–15 and the non-writing portions of Gate 16 is already complete.
