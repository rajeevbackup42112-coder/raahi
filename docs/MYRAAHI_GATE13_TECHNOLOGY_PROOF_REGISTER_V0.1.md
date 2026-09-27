# MyRaahi Shared Front Door — Gate 13 Technology Proof Register v0.1

Last updated: 2026-09-26

Method: AI Builder Cheat Code v2.0 — Gate 13

Status: **IN PROGRESS — PUBLIC-SHELL BUILD/BROWSER PRIMITIVES PROVEN; REAL CLOUDFLARE RUNTIME ACCESS BLOCKED BY EXTERNAL AUTH/TOOLING**

---

## Spike 13A — Can the isolated shell build as a real Cloudflare Worker + D1-shaped application?

### Hypothesis
The proposed shell can compile/bundle using the current Cloudflare Worker toolchain and its D1 schema can be applied deterministically.

### Test
GitHub Actions on branch `myraahi-shared-shell-v1`:
- dependency install;
- TypeScript typecheck;
- browser JavaScript syntax;
- Wrangler dry-run bundle;
- SQLite application of D1-compatible schema;
- fixture application/assertions.

### Observed evidence
Passed repeatedly, including final UI-regression run:
- run `36247865290`
- commit `c3424217c1ce8a43866b705ce3cc42f7cbe842d7`

### Limitations
Dry-run/SQLite compatibility is not proof that the user’s real Cloudflare account, D1 binding, quotas, deployment route or runtime behave correctly.

### Design consequence
Cloudflare Worker + D1 remains a viable candidate, but physical architecture is not yet frozen.

**Result: PASS as build/tooling primitive.**

---

## Spike 13B — Can the public shell behave correctly in a real browser before deployment?

### Hypothesis
The current shell interaction model works at representative mobile/desktop sizes without a login wall or layout breakage.

### Test
Real Chromium/Playwright browser checks at:
- 375×667
- 430×932
- 1366×768
- 320×700 long-Location stress case

Also tested:
- Location selection and switching;
- PAUSED Product treatment;
- refresh persistence;
- no horizontal overflow;
- header non-overlap;
- human error/recovery;
- no sign-in wall.

### Observed evidence
Final run `36247865290`: **SUCCESS**.

Evidence artifact from preceding successful visual run:
- artifact `10908027024`
- name `myraahi-shell-ui-evidence`
- digest `sha256:98460e9ce74b6e27d783aedb52b6913e7fee9e13942e0f322bac4c3da13126cd`

Visual inspection found one implementation defect in error-state Location wording. It was fixed in `c3424217…` and regression-tested successfully.

### Limitations
Chromium CI is not Safari/iOS/real-device proof and uses mocked HTTP API responses rather than a deployed Worker/D1 runtime.

### Design consequence
Gate 9 is PASS; deployed-runtime proof is still required.

**Result: PASS for browser/UI primitive.**

---


---

## Spike 13C — Real non-production Cloudflare runtime

**Result: PASS.**

### Authorized access

Desktop Commander device:
- `Dipti`
- device id `931e6073-983d-4a7c-92b6-71f04d7efe8c`

Read-only Wrangler check confirmed:
- Wrangler already authenticated locally through OAuth;
- Cloudflare account email: `rajeev.backup4.2112@gmail.com`;
- Account ID: `2dcc43fbce0fcf0413d4e05f4a959a1e`;
- OAuth permissions include Workers write and D1 write.

No credential value was copied into GitHub or exposed in repository content.

### Isolated source checkout

A clean shallow checkout of branch:

`myraahi-shared-shell-v1`

was created at:

`C:\Users\Dipti\Downloads\myraahi-gate13-20260927`

Branch HEAD used for the spike:

`f82324ca407e4c86c1f7be5b268a1229f62ad512`

### Non-production D1

Created:

`myraahi-shell-gate13-staging`

Database ID:

`5ee83f6f-66a7-4abd-ba0d-94bf609f967f`

Region:
- APAC
- observed serving colo: SIN

A temporary local-only Wrangler config was used:
- `wrangler.gate13.jsonc`
- unique staging Worker name
- `workers_dev: true`
- no custom-domain route
- staging D1 binding only

This file was not committed.

### Schema + fixture proof

Applied remotely:
- `0001_public_shell.sql`
- `fixtures/dev-seed.sql`

Observed import evidence:
- schema migration succeeded;
- fixture import succeeded;
- 34 rows written during fixture import;
- database size approximately 0.09 MB;
- six tables reported after setup.

### Worker deployment

Unique non-production Worker:

`myraahi-shell-gate13-staging`

Staging URL:

`https://myraahi-shell-gate13-staging.rajeev-backup4-2112.workers.dev`

Version ID:

`a91ea906-7d3a-450f-81b1-7243363a2ae9`

Observed:
- three static assets uploaded;
- Worker startup time 2 ms;
- only staging D1 + static assets bound;
- no custom domain/DNS change.

### Real API proof

The deployed runtime returned:

`/api/v1/health`
- `ok: true`
- service `myraahi-shell`
- schema version `0.1`

`/api/v1/locations`
- Gomoh LIVE
- Dhanbad LIVE

Initial catalogue:
- Gomoh: Learning LIVE, ToTo LIVE
- Dhanbad: Learning LIVE, ToTo PAUSED

### Real browser proof

The deployed staging URL was opened in the isolated Edge profile on the authorized machine.

Initial browser state:
- title: `Raahi — Your local starting point`
- no login wall
- Location chooser shown
- no Product cards before Location choice
- no horizontal overflow at the tested desktop viewport

After setting/selecting Dhanbad and reloading against the real deployed API:
- selected Location displayed as Dhanbad;
- Learning card = LIVE / Open Learning;
- ToTo card = PAUSED / temporary-unavailability copy;
- no horizontal overflow.

### Dynamic configuration without frontend redeploy

Controlled staging-only mutation:
- Dhanbad ToTo changed from PAUSED → LIVE in D1;
- audit record `audit-gate13-20260927-toto-live` inserted.

Immediately after mutation:
- live API returned ToTo = LIVE;
- no Worker deployment occurred.

The already-open browser initially retained the prior PAUSED card because the public API response uses browser `max-age=30`.

After that cache window expired and the same deployed page was refreshed:
- Dhanbad ToTo rendered LIVE;
- CTA changed to `Open ToTo →`;
- Worker version remained exactly `a91ea906-7d3a-450f-81b1-7243363a2ae9`.

This proves:
> Location/Product configuration can change the live homepage without rebuilding or redeploying frontend assets.

### Cache evidence

Observed real behavior:
- D1/API truth updated immediately;
- an already-open browser can remain stale for up to the configured browser cache window (~30 seconds);
- after expiry, normal refresh receives current configuration.

Design consequence:
- 30-second browser cache is acceptable as the current staging default;
- product/admin UX should not imply configuration changes are instantaneous;
- if future operational requirements need faster propagation, change cache policy through impact analysis rather than hidden cache-busting.

### Audit/integrity evidence

Deployment list after the D1 mutation still showed only:
- version `a91ea906-7d3a-450f-81b1-7243363a2ae9`

D1 audit record confirmed:
- action: `set_location_product_live`
- target: `lp-dhanbad-toto`
- Location: `loc-dhanbad`
- Product: `prd-toto`
- before: PAUSED
- after: LIVE
- reason: Gate 13 dynamic configuration proof

### Cleanup

After proof, staging D1 was restored to the fixture baseline:
- Dhanbad ToTo = PAUSED
- original temporary-unavailability message restored
- restoration audit record `audit-gate13-20260927-toto-restore` inserted.

The non-production Worker/D1 remain available for continued Gate-13 experiments.

### Production safety

Not touched:
- `myraahi.co.in` DNS
- custom-domain routes
- Raahi Learning production database
- Raahi Learning authentication
- any production Product state



---

## Spike 13D — Cross-product Account / identity continuity

**Result: PASS for V1 identity continuity.**

Important terminology:

> This spike proves **one durable Raahi identity across independent Raahi origins**. It does **not** prove one shared browser session/cookie across all subdomains.

That distinction is deliberate.

### Existing Learning session model observed read-only

Public Learning origin:

`https://learning.myraahi.co.in`

Observed authenticated browser storage:
- Supabase Auth session stored in origin-scoped `localStorage`;
- storage key: `sb-iiwwmqokaeflaenhlyip-auth-token`;
- no auth cookies observed.

Consequence:
- another Raahi origin cannot automatically read Learning's browser session;
- using the same Supabase project alone is not seamless cross-origin SSO.

### Existing Supabase redirect configuration evidence

Repository release evidence confirms the Auth redirect allow-list intentionally includes:
- DEV Learning redirects;
- `https://learning.myraahi.co.in/`;
- `https://learning.myraahi.co.in/**`.

It does not include arbitrary workers.dev URLs.

Observed in the first workers.dev auth-lab attempt:
- Google authentication completed;
- Supabase returned the callback to the configured Learning Site URL rather than the workers.dev lab.

No production Auth setting was modified.

### Clean non-production test origin

Existing allow-listed DEV origin:

`https://dev.learning.myraahi.co.in`

DNS:
- CNAME → `raahi-learning-dev.pages.dev`

DEV is a separate Cloudflare Pages project and remained server-code unchanged during this spike.

### Browser-only isolated PKCE harness

A second Supabase client was created only inside the DEV browser context using:
- same Supabase project `iiwwmqokaeflaenhlyip`;
- current publishable key;
- PKCE flow;
- separate storage key `raahi-sso-lab`;
- callback to a static DEV privacy page;
- test Location `gomoh`.

No Learning source file, deployment artifact, Supabase Auth setting, database row or server configuration was modified.

### Identity continuity result

The isolated DEV client completed Google OAuth and code exchange successfully.

Resulting provider:
- Google

Resulting Supabase user UUID matched the already-authenticated public Learning session **exactly**.

This proves:
> A Raahi user authenticating independently from another Raahi origin through the same Supabase Auth project resolves to the same durable user identity rather than creating a duplicate Account identity.

The exact UUID is intentionally omitted from this document.

### Location preservation

Before OAuth:
- lab Location was explicitly set to Gomoh.

After the complete OAuth round trip and session establishment:
- selected Location remained Gomoh.

This validates the product rule that explicit current Location can survive authentication independently from identity.

### Session isolation proof

The lab session was signed out locally.

Observed:
- lab session became signed out;
- test Location remained Gomoh;
- public Learning session remained authenticated as the same Google/Supabase user.

This proves per-origin sessions can coexist without one origin's local sign-out unintentionally terminating another origin's browser session.

### Re-entry friction proof

After local lab sign-out, Google OAuth was initiated again.

Observed:
- the browser returned to the DEV callback within a few seconds;
- no credential-entry screen or account chooser was required in that browser state;
- the resulting Supabase user UUID again matched the same durable identity.

This shows that independent per-origin sessions can be re-established with very low friction when the user already has a valid Google browser session.

It does **not** guarantee Google will never display an account chooser or consent prompt; that remains provider/browser-state dependent.

### Architecture consequence

For V1, prefer:

**Central Raahi identity + independent origin-local sessions**

over:

**Parent-domain shared refresh-token cookie SSO**

Reasons:
1. no need to copy refresh/access tokens between origins;
2. no need to change Learning's proven localStorage auth immediately;
3. local sign-out can remain scoped;
4. same Supabase user UUID prevents duplicate Raahi identity;
5. Google can provide low-friction re-authentication in ordinary already-signed-in browsers;
6. reduces cross-product blast radius while Raahi products remain independently evolvable.

A true shared-cookie/session architecture may be reconsidered only if real pilot behavior shows that the brief re-authentication redirect creates material friction.

### Cleanup

- isolated DEV lab session signed out;
- no DEV source/deployment changed;
- temporary workers.dev auth-lab assets removed;
- staging shell redeployed to normal 3-asset baseline;
- `/auth-lab.html` returns 404;
- Dhanbad ToTo staging baseline verified PAUSED.

Final cleaned staging Worker version after lab removal:

`15856ec6-3f9f-4518-9054-593f1d506171`

### Production safety

Not changed:
- Learning source code;
- Learning public deployment;
- Learning DEV deployment;
- Supabase Auth redirect configuration;
- Google OAuth configuration;
- `myraahi.co.in` DNS;
- Learning database/business state.


# Gate 13 current result

**PASS for the current MyRaahi shared-front-door V1 technology scope.**

Proven:
- Worker/toolchain buildability;
- D1-compatible schema/fixture in CI;
- real Chromium public-shell behavior;
- real Cloudflare Worker runtime;
- real remote D1 migration and configuration mutation;
- browser → Worker → D1 end-to-end path;
- configuration-driven homepage update without frontend redeploy;
- one durable Supabase/Google user identity across independent Raahi origins;
- explicit Location preservation through OAuth;
- independent per-origin session isolation;
- low-friction re-authentication in an already signed-in Google browser.

Intentionally deferred because V1 does not require them yet:
- parent-domain shared-cookie SSO;
- universal Account recovery/provider-linking workflow;
- shared phone-trust/OTP implementation outside product actions;
- GitHub Actions Cloudflare credential bootstrap.

These deferred primitives must reopen Gate 13 when a future vertical slice actually depends on them.

## Exact next action

Proceed to **Gate 14 — Executable Screen ↔ Backend Contracts**, updated to reflect the proven architecture:

- public shell on Cloudflare Worker + D1;
- central Supabase Auth identity;
- origin-local sessions;
- same durable user UUID across Raahi products;
- no shared refresh-token transfer;
- focused Product remains authoritative for its own actions.

Then complete Gate 15 side-effects matrix and Gate 16 real walking-skeleton definition before broader implementation.
