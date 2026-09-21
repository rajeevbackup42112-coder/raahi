# Raahi Learning V1.4C — Founding Supply Public Live Evidence — 2026-09-21

Status: **PUBLIC LIVE — FOUNDING SUPPLY WALKING SKELETON GREEN**

Repository: `rajeevbackup42112-coder/raahi`
Branch: `raahi-learning-implementation-v1`
Public origin: `https://learning.myraahi.co.in`
Supabase project: `iiwwmqokaeflaenhlyip`

## 1. Production source

The exact V1.4C application source deployed to production is:

`c990d9a8b854b362d88bb4e1b7b8cf99a6538d95`

Commit:

`Guard Founding Supply reads before auth`

GitHub Model Tests:
- run number: **652**
- run ID: **35585071238**
- exact head SHA: `c990d9a8b854b362d88bb4e1b7b8cf99a6538d95`
- conclusion: **success**

The immediately preceding implementation commit was:

`fd7ead36f13ed81eb9bed832734ddf122e2f2b07`

Commit:

`Add assisted Founding Supply onboarding`

GitHub Model Tests run **#651** passed on that exact implementation SHA before preview qualification.

A later repository-only migration-history alignment commit is:

`42772f6fdf799db59d540e4777d432088a0bdc28`

GitHub Model Tests:
- run number: **653**
- run ID: **35587700337**
- exact head SHA: `42772f6fdf799db59d540e4777d432088a0bdc28`
- conclusion: **success**

That commit renames the three migration files to match Supabase's actual applied migration versions. It does not change the deployed browser application and does not require a production redeploy.

## 2. Qualification before migration/deployment

Final local qualification after the signed-out auth-guard fix:
- production/launch guard suite: **65/65 passed**
- Founding Supply focused tests: **9/9 passed**
- backend-free model/property suite: **5,349,572 cases, 0 failures**
- production-like load guard: **9/9 passed**
- V1.4C JavaScript syntax check: passed
- `git diff --check`: clean

## 3. Founding Supply contract

The V1.4C walking skeleton is deliberately narrow:

> Genuine Teacher asks for help -> Raahi prepares a private draft -> the same authenticated Teacher reviews the exact proposal -> only that Teacher can publish it.

This reuses the canonical Teacher Profile and Teaching Option model.

The Platform cannot:
- create a Teacher identity;
- silently initiate assisted onboarding for an Account that did not request help;
- accept on behalf of the Teacher;
- publish the draft directly;
- fabricate engagement, demand, ratings, reviews, enquiries or successful matches.

Before Teacher acceptance:
- no Teacher Profile is created;
- no Teaching Option is created;
- nothing is discoverable publicly.

After acceptance:
- the real Teacher Account owns the visible Teacher Profile;
- the real Teacher Account owns the first Teaching Option;
- creation provenance is `assisted`;
- the accepted request remains the auditable consent/provenance anchor;
- future edits use normal Teacher controls.

## 4. Permanent Supabase migrations

The permanent V1.4C migrations are registered in Supabase as:

1. `20260921093234_v14c_founding_supply_assisted_teacher_onboarding`
2. `20260921093410_v14c_founding_supply_fk_indexes`
3. `20260921093510_v14c_founding_supply_explicit_browser_deny`

The repository migration filenames were later aligned to these exact applied versions to prevent future migration tooling from mistaking already-applied migrations for new migrations.

The first migration adds:
- private assisted-onboarding request ledger;
- bounded private draft fields;
- state machine: `requested`, `draft_ready`, `accepted`, `declined`, `cancelled`, `withdrawn`;
- Teacher Profile creation provenance;
- Teaching Option creation provenance;
- canonical Teacher request/accept/decline/cancel RPCs;
- canonical Platform prepare/withdraw RPCs;
- Teacher-only read projection;
- Platform-only queue projection;
- acceptance audit/consent evidence;
- future phone-trust compatibility.

The second migration adds FK-covering indexes surfaced by Supabase's performance advisor.

The third migration adds an explicit authenticated-browser deny policy to the private assistance ledger. Browser access remains RPC-only.

## 5. Transactional database proof

Before permanent migration, the complete migration + lifecycle was run against Supabase inside a transaction and rolled back successfully.

After permanent migration, the full runtime smoke was run again against the permanently migrated schema and rolled back successfully.

The smoke proved:
- Teacher initiates the request for self;
- request creates no public supply;
- non-Platform Account cannot prepare;
- Platform Admin can prepare only the private draft;
- draft creates no public supply;
- Platform Admin cannot accept for the Teacher;
- Teacher can read the exact private proposal;
- same Teacher can accept;
- acceptance materialises exactly one visible Teacher Profile;
- acceptance materialises exactly one first Teaching Option;
- acceptance materialises the founding Location link;
- assisted provenance is retained;
- active `teach` capability is created if permitted;
- acceptance audit evidence exists;
- idempotent retry does not duplicate supply;
- accepted option is discoverable as the genuine Teacher;
- ordinary self-service remains `organic`;
- direct browser writes remain denied.

After rollback and release closure:
- assisted onboarding requests: **0**
- assisted Teacher Profiles: **0**
- assisted Teaching Options: **0**
- active Platform Admins: **0**
- synthetic test users: **0**

No fake supply was created during qualification.

## 6. Supabase advisor closure

Initial post-migration performance review surfaced five missing FK-covering indexes. Those were added before release freeze.

Initial security review surfaced the private assistance ledger as RLS-enabled without a policy. Although direct grants were already closed and access was RPC-only, an explicit authenticated deny policy was added so the browser boundary is visible to both humans and advisors.

After hardening:
- no new V1.4C security exposure remained;
- no new V1.4C missing-FK-index performance warning remained;
- only normal/pre-existing informational findings remained;
- the pre-existing Auth leaked-password-protection warning remained unchanged because the public product uses Google-only sign-in and V1.4C did not change Auth mode.

## 7. Exact release artifact

Final release directory:

`C:\Users\Dipti\Downloads\raahi-learning-v14c-c990d9a-release`

Final deploy-only directory:

`C:\Users\Dipti\Downloads\raahi-learning-v14c-c990d9a-deploy`

Release manifest `SHA256SUMS.txt` SHA-256:

`3d65a65ea8b394eafad639450b0fc33f420e0ec0467d43ba7f21582c8d734a7d`

Final package:
- 14 deployable public files;
- 13 files represented in `build-meta.json`;
- exact source SHA `c990d9a...`;
- `founding-supply-v14c.js` present;
- DEV login file absent;
- forbidden public matches: **0**;
- deploy-copy hash mismatches: **0**.

## 8. Preview qualification and caught defect

The first V1.4C preview used implementation SHA `fd7ead3...`.

Preview deployment:
- ID: `75d830c9-8ac2-437e-a1d5-e9138e7d47d7`
- branch: `v14c-fd7ead3-preview`
- URL: `https://75d830c9.raahi-learning-prod.pages.dev`

That preview correctly failed closed visually for signed-out users, but browser canary caught a background defect: direct navigation to the signed-out assisted Teacher route still attempted its private RPC and surfaced a permission error.

No data was exposed and no write occurred.

The defect was fixed by guarding assisted-read loading on a valid session/context. Regression tests were added, producing final SHA `c990d9a...`.

Corrected preview:
- deployment ID: `1b8c55c7-5c74-48eb-88c0-360cd82a2655`
- branch: `v14c-c990d9a-preview`
- URL: `https://1b8c55c7.raahi-learning-prod.pages.dev`
- alias: `https://v14c-c990d9a-preview.raahi-learning-prod.pages.dev`

Corrected preview verification:
- exact build SHA match;
- public file hash mismatches: **0**;
- forbidden public matches: **0**;
- signed-out assisted Teacher route renders normal Welcome with no unauthorized background RPC;
- signed-out Platform Founding Supply route fails closed with **Platform workspace required**.

Authenticated preview OAuth was not repeated because the Supabase dashboard session required re-authentication to temporarily add another preview redirect. This was not used as a reason to weaken redirect controls.

Instead, the exact byte-verified artifact was promoted and authenticated canary was completed on the already-authorized production origin before release closure.

## 9. Production rollback anchor

Immediately before V1.4C promotion, production was V1.4B:

- deployment ID: `42f1a854-a4e7-41a4-8e7a-dd4edf8f921d`
- branch: `main`
- Pages URL: `https://42f1a854.raahi-learning-prod.pages.dev`
- source SHA: `3735e7e2717a04043bd7af7552a7b0b5ec757622`

This is the immediate V1.4C rollback anchor.

## 10. Production deployment

V1.4C production deployment:

- deployment ID: `18f52dbf-fbb7-4371-906a-09734f0fb9df`
- branch: `main`
- Pages URL: `https://18f52dbf.raahi-learning-prod.pages.dev`
- source: `c990d9a`
- public origin: `https://learning.myraahi.co.in`

Production `build-meta.json`:

`commit_sha = c990d9a8b854b362d88bb4e1b7b8cf99a6538d95`

Production raw-file verification:
- hash mismatches: **0**
- forbidden public matches: **0**
- Founding Supply asset hash matched build-meta.

## 11. Production browser canary

Authenticated production Account passed:
- Home / Dhanbad;
- Explore;
- Community;
- Messages;
- Teacher Setup;
- Teacher Setup Help;
- ordinary Account denied Platform Founding Supply workspace;
- Dhanbad -> Gomoh -> Dhanbad Location round trip.

Teacher Setup visibly offers:
- **Set it up myself**
- **Ask Raahi to help**

Teacher Setup Help visibly states:
- the Teacher stays in control;
- Raahi prepares only a private draft;
- the draft does not appear in Explore until the Teacher signs in and publishes the exact draft;
- the current founding Location is shown.

No assistance-request button was pressed during release canary, so no real Teacher data was created.

Signed-out/InPrivate production:
- normal Welcome rendered;
- Google sign-in CTA present;
- direct assisted Teacher route remained signed out and did not surface the previous background permission error.

Policy pages:
- Privacy follows canonical redirect and resolves HTTP 200;
- Terms follows canonical redirect and resolves HTTP 200.

## 12. Final state

V1.4C Founding Supply is **PUBLIC LIVE**.

Application deployment source:

`c990d9a8b854b362d88bb4e1b7b8cf99a6538d95`

Current repository migration-history alignment head:

`42772f6fdf799db59d540e4777d432088a0bdc28`

The next operational gate is not another code deployment.

Before the first genuine assisted Teacher can complete the full real-world flow, Raahi needs a deliberately chosen real Account to hold the `platform_admin` capability. There are currently **0 active Platform Admins**.

Do not grant that capability to an arbitrary Account.
