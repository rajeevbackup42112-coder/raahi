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

`699871e0a5ae9b98508e01cd66415a1c5c1e1dda`

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

Successful run:

- Run ID: `36239610837`
- Head SHA: `699871e0a5ae9b98508e01cd66415a1c5c1e1dda`
- Result: **SUCCESS**

Passed steps:

1. dependency install
2. TypeScript Worker typecheck
3. browser JavaScript syntax check
4. Wrangler Worker dry-run bundle
5. SQLite/D1 schema application
6. development fixture application
7. fixture assertions

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

## Exact next action

The next execution step is **non-production Cloudflare staging**, not production launch.

Proceed in this order:

1. obtain/access the authorized Cloudflare account for `myraahi.co.in`;
2. create a non-production D1 database for the shell;
3. replace the placeholder D1 ID only on the implementation branch/config used for staging;
4. apply `0001_public_shell.sql`;
5. apply the dev/staging fixture only to that non-production database;
6. deploy the Worker to a non-production hostname / workers.dev or dedicated staging subdomain;
7. test:
   - mobile
   - desktop
   - Location selection
   - Gomoh/Dhanbad catalogue difference
   - refresh persistence
   - PAUSED treatment
   - API failure/recovery
   - safe Product deep links
8. perform a controlled D1 config change and prove the homepage changes without frontend rebuild;
9. document screenshots/browser findings and any UX fixes;
10. only after public-shell proof, begin isolated cross-product SSO technology spike.

Do not point production `myraahi.co.in` to this shell without explicit launch approval.

Do not modify Learning production auth/database as part of staging shell setup.
