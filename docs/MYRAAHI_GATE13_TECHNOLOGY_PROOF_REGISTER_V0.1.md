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
