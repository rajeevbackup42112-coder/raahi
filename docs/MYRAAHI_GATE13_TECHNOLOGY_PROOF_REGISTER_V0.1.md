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

## Spike 13C — Real non-production Cloudflare account/runtime access

### Hypothesis
The user’s authorized Cloudflare account can host a non-production Worker + D1 database for the shell without affecting production DNS.

### Required test
1. authenticate to the user’s Cloudflare account;
2. verify Workers/D1 access;
3. create a non-production D1 database;
4. apply migration and staging fixture;
5. bind it to the isolated Worker;
6. deploy only to workers.dev or a dedicated non-production hostname;
7. call real health/locations/catalog APIs;
8. use a real browser against the deployed shell;
9. change one LocationProduct value in D1;
10. prove the homepage changes without rebuilding frontend assets.

### Access attempts/evidence

#### TinyFish
A read-only Cloudflare dashboard automation was attempted.

Result:
- automation did **not start**;
- TinyFish wallet balance was `-$0.04`;
- tool reported insufficient wallet funds;
- no Cloudflare page was visited and no change occurred.

Raahi doctrine consequence:
- do not make paid TinyFish browser credits a product/runtime dependency;
- TinyFish top-up remains an optional operator convenience only.

#### Cloudflare plugin/connector
ChatGPT Plugin Directory was searched for `Cloudflare Workers D1`.

Result:
- no matching plugin available.

#### GitHub repository
Repository search found no existing `CLOUDFLARE_API_TOKEN`, `wrangler deploy`, or Cloudflare workflow reference that can be safely reused as an already-established deployment path.

This does not prove no secret exists in GitHub settings; secrets are intentionally not exposed/read through repository search.

#### Desktop Commander
Known authorized device:
- `Dipti`
- device id `931e6073-983d-4a7c-92b6-71f04d7efe8c`

At the time of this Gate 13 attempt:
- device status: **offline**

Therefore it cannot currently be used to open the user’s authenticated/local browser or terminal.

### Current evidence conclusion
Real Cloudflare access/runtime remains **UNPROVEN** due to an external authentication/tool-access boundary, not due to a product, architecture or code defect.

### Preferred continuation
Use Desktop Commander once the authorized device is online:
1. locate/open Cloudflare dashboard in browser;
2. let the user authenticate manually if needed;
3. verify account/zone read-only first;
4. create only non-production D1/Worker resources after access is established;
5. do not change production DNS.

Alternative:
- TinyFish can be used if the user independently chooses to add wallet credit, but this is not required/recommended for Raahi infrastructure design.

**Result: BLOCKED ON EXTERNAL AUTHORIZED ACCESS.**

---

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

Not yet passed:
- real Cloudflare Worker runtime
- real D1 binding/runtime mutation proof
- cross-product identity/SSO
- OTP provider primitive

## Exact next action

Bring the authorized Desktop Commander device online and perform a read-only Cloudflare access check.

Then continue Spike 13C without touching production DNS or Learning production.
