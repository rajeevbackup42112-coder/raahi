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


## Spike 13D — Cross-product Account / SSO

Status: **NOT STARTED**.

Do not start until Spike 13C proves the public runtime.

Must prove later:
- real Google/OAuth sign-in;
- one durable Raahi identity;
- safe cross-subdomain/product handoff;
- logout/relogin;
- session expiry;
- explicit Location survives auth;
- safe return target;
- no duplicate Account creation;
- compatibility with existing Learning identity;
- recovery/linking constraints;
- phone trust remains separate.

---


---

## Spike 13E — Current Cloudflare Free-tier viability check

### Purpose
Confirm that the proposed public-shell runtime still fits Raahi's zero-recurring-cost doctrine using current provider limits rather than old assumptions.

### Official Cloudflare evidence checked on 2026-09-26

Workers Free:
- 100,000 Worker requests/day;
- 10 ms CPU time per HTTP request;
- 50 external subrequests/invocation;
- 1,000 subrequests to Cloudflare services/invocation;
- 128 MB memory;
- up to 100 Workers/account.

D1 Free:
- 5,000,000 rows read/day;
- 100,000 rows written/day;
- 5 GB total account storage;
- up to 10 D1 databases/account;
- 500 MB maximum per D1 database;
- 50 D1 queries per Worker invocation;
- 7-day Time Travel recovery.

Important current behavior:
- since 2026-09-01, D1 Free daily read/write limits are enforced as hard failures until midnight UTC after the limit is exceeded.

Official references:
- https://developers.cloudflare.com/workers/platform/limits/
- https://developers.cloudflare.com/workers/platform/pricing/
- https://developers.cloudflare.com/d1/platform/pricing/
- https://developers.cloudflare.com/d1/platform/limits/
- https://developers.cloudflare.com/changelog/post/2026-09-01-d1-free-tier-limit-enforcement/

### Design consequence
For the initial MyRaahi public shell, these limits are materially larger than the expected pilot configuration workload.

However, launch design must treat quota exhaustion as a real failure mode:
- catalogue reads should be indexed and minimal;
- avoid wasteful polling;
- static assets should not trigger unnecessary D1 reads;
- cache public catalogue safely where freshness rules permit;
- if D1 quota is exhausted, return human temporary-unavailability/retry behavior rather than stale invented availability;
- do not auto-upgrade to a paid plan.

**Result: PASS as current free-tier suitability evidence, subject to real account/runtime proof.**

---

## Spike 13F — Branch deployment-safety configuration check

Current branch file:
`apps/myraahi-shell/wrangler.jsonc`

Observed:
- Worker name: `myraahi-shell`
- `workers_dev: true`
- static assets served from `./public`
- Worker-first routing only for `/api/*`
- D1 binding name: `DB`
- database name: `myraahi-shell-db`
- database ID remains the deliberate placeholder `00000000-0000-0000-0000-000000000000`
- no custom-domain route is configured

### Design consequence
The branch cannot accidentally bind to a real D1 database until the placeholder is intentionally replaced, and it is currently prepared for a `workers.dev` staging deployment rather than production `myraahi.co.in` routing.

**Result: PASS as configuration safety evidence.**


---

## Spike 13G — GitHub Actions as headless cloud computer

### Why this matters
The reusable AI-project tooling doctrine says GitHub Codespaces is the preferred interactive cloud development computer and Desktop Commander is reserved mainly for real-user validation. In the current ChatGPT connector, interactive Codespaces terminal control is not exposed, but GitHub Actions is available and already successfully runs MyRaahi builds/tests in GitHub's cloud.

### Read-only Cloudflare credential probe
A branch-only workflow was added on `myraahi-shared-shell-v1`:

`.github/workflows/myraahi-cloudflare-access-probe.yml`

Commit:
`f82324ca407e4c86c1f7be5b268a1229f62ad512`

Workflow run:
`36261265502`

The probe:
1. checked out the isolated branch;
2. installed the existing shell dependencies;
3. checked only whether standard GitHub Actions secret names were populated;
4. would have run read-only `wrangler whoami` if credentials existed;
5. contained no deploy/create/delete/DNS command.

### Observed result
The workflow showed:
- `CLOUDFLARE_API_TOKEN` = unavailable/empty;
- `CLOUDFLARE_ACCOUNT_ID` = unavailable/empty;
- `wrangler whoami` was skipped;
- no Cloudflare access or change occurred.

This proves the current repository cannot yet deploy/probe Cloudflare from GitHub Actions using those standard secret names.

### Consequence
GitHub Actions **can** serve as the headless cloud execution environment for Gate 13 after a one-time Cloudflare credential bootstrap. Desktop Commander is not required for routine build/deploy once those credentials are safely available to the workflow.

The preferred zero-recurring-cost path is therefore:
1. one-time Cloudflare authentication/token bootstrap by the user in an authorized browser/Codespace;
2. store only the required scoped Cloudflare API token and account ID as GitHub Actions secrets;
3. GitHub Actions handles non-production D1 creation/migrations/staging deployment headlessly;
4. Desktop Commander is used later only for real-user/browser validation when warranted.

**Result: PASS for GitHub Actions cloud-compute feasibility; BLOCKED only on one-time Cloudflare credential bootstrap.**

# Gate 13 current result

**PARTIAL / ACTIVE.**

Passed:
- Worker/toolchain buildability
- D1-compatible schema/fixture locally in CI
- real Chromium public-shell behavior
- real Cloudflare Worker runtime
- real remote D1 migration/fixture
- real browser → Worker → D1 catalogue path
- D1 configuration change reflected in the live homepage without frontend redeploy
- staging baseline cleanup/audit

Still not passed:
- cross-product Account / SSO
- account recovery/linking primitive
- shared auth-handoff/draft-resume primitive
- OTP provider primitive for a shared Account trust layer
- GitHub Actions Cloudflare deployment credential bootstrap

## Exact next action

Start **Spike 13D — Cross-product Account / SSO** in an isolated non-production lab.

Do not alter Raahi Learning production authentication behavior.

Separately, when convenient, create a narrowly scoped Cloudflare API token for GitHub Actions so routine future staging deployment can move from the local Wrangler OAuth session to headless GitHub cloud execution.
