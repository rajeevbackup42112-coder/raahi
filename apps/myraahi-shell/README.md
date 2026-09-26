# MyRaahi Shared Shell v0.1

This is the isolated walking-skeleton implementation of the common Raahi front door.

## What it proves

- Location-first entry
- public browsing without login
- Product catalogue driven by configuration rather than frontend hard-coding
- LIVE / PAUSED / OFF product behavior
- browser-only Location persistence for logged-out users
- safe Raahi-owned Product deep links carrying only a Location hint
- Cloudflare Worker + D1 architecture

## What it deliberately does not implement

- shared Account / SSO
- OTP
- provider verification
- Platform/Location Admin web UI
- product operational state
- advertising
- AI navigation
- production DNS

Read these first:

- `../../docs/MYRAAHI_SHARED_FRONT_DOOR_PRODUCT_CONTRACT_V0.1.md`
- `../../docs/MYRAAHI_SHARED_FOUNDATION_DOMAIN_MODEL_V0.1.md`
- `../../docs/MYRAAHI_SHARED_FRONT_DOOR_SCREEN_BACKEND_CONTRACTS_V0.1.md`
- `../../docs/MYRAAHI_FREE_INFRA_IDENTITY_ARCHITECTURE_GATE_V0.1.md`
- `../../docs/MYRAAHI_PUBLIC_SHELL_D1_WORKER_BLUEPRINT_V0.1.md`

## Local setup

1. Install dependencies in this directory.
2. Create/apply the local D1 schema:
   - `npm run db:migrate:local`
3. Load the development fixture:
   - `npm run db:seed:local`
4. Start:
   - `npm run dev`

The `wrangler.jsonc` database ID is intentionally a placeholder. Do not deploy until a non-production Cloudflare D1 database is explicitly created and the binding is replaced with its ID.

## Safety

- No production route is configured.
- No write API is exposed.
- The dev seed is illustrative only and is not production launch truth.
- Do not point `myraahi.co.in` to this Worker without explicit launch approval.
