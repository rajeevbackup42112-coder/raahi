# Raahi Learning V1.4D — Scoped Market Activation Public Live Evidence — 2026-09-21

Status: **PUBLIC LIVE — CITY-SCOPED MARKET ACTIVATION GREEN — GLOBAL ADMIN BOOTSTRAP MANUAL GATE**

Repository: `rajeevbackup42112-coder/raahi`
Branch: `raahi-learning-implementation-v1`
Supabase: `iiwwmqokaeflaenhlyip`
Public origin: `https://learning.myraahi.co.in`

## 1. Exact application source

Production application SHA:

`89edd9c12c8e37a70e1f8fb46faf544ac75fe6b2`

Commit:

`Scope market activation to city admins`

GitHub Model Tests:
- run #656
- run ID: `35591347033`
- conclusion: success

## 2. Authority model

Frozen V1.4D rule:

- global `platform_admin`: cross-Location Raahi Desk + Founding Supply authority;
- active Location `local_manager`: Raahi Desk + Founding Supply only inside assigned Location;
- Local Manager never becomes Platform Admin;
- server checks the exact target/request Location;
- Teacher consent rules remain unchanged.

Live city ownership:
- Gomoh: `rajeev.backup1.2112@gmail.com` = active `local_manager`
- Dhanbad: `rajeev.backup2.2112@gmail.com` = active `local_manager`

Requested global owner:
- `choudhary.ajit2112@gmail.com`

At release closure there are still 0 active global Platform Admins because the connected database execution safety layer blocked direct first-admin privilege creation. The manual bootstrap SQL has been prepared in the authenticated Supabase SQL Editor but has not been run by the assistant.

## 3. Permanent migration

Applied Supabase migration:

`20260921105250_v14d_scoped_market_activation_authority`

It updates:
- Raahi Desk command authorization;
- Founding Supply prepare authorization;
- Founding Supply withdraw authorization;
- Founding Supply operational queue filtering.

No new raw browser table grants were introduced.

## 4. Qualification

Local/CI proof:
- production/operational JS tests: 70/70 passed
- focused scoped-market tests: green
- backend-free model/property suite: 5,349,572 cases, 0 failures
- production-like load guards: 9/9 passed
- syntax checks: passed
- git diff check: clean

Database proof:
- full migration + runtime dry run passed inside transaction before permanent apply;
- permanent migration applied successfully;
- post-migration runtime smoke passed;
- synthetic users/Locations/posts/requests after rollback: 0.

Supabase advisors after apply:
- no new V1.4D security finding;
- only pre-existing leaked-password-protection warning remains;
- performance findings are informational unused-index notices.

## 5. Real city-manager production proof

Both genuine city-manager Auth identities were exercised server-side using request-context impersonation inside rollback transactions.

Gomoh manager proof:
- can read own-location Founding Supply request;
- can publish Raahi Desk in Gomoh;
- cannot publish Raahi Desk in Dhanbad;
- can prepare Gomoh private Teacher draft;
- Dhanbad manager cannot see or withdraw that Gomoh request.

Dhanbad manager proof:
- can read own-location Founding Supply request;
- can publish Raahi Desk in Dhanbad;
- can prepare Dhanbad private Teacher draft;
- Gomoh manager cannot see that Dhanbad request;
- Gomoh manager cannot publish into Dhanbad.

All synthetic Teacher/request/post rows rolled back. Final residue:
- synthetic users: 0
- rollback posts: 0
- rollback requests: 0

## 6. Release artifact

Release directory:
`C:\Users\Dipti\Downloads\raahi-learning-v14d-89edd9c-release`

Deploy directory:
`C:\Users\Dipti\Downloads\raahi-learning-v14d-89edd9c-deploy`

SHA256SUMS file SHA-256:
`29e56868784ca4f9359d4d4fdd581000638162faf0db405bd1acad53972b1abc`

Package verification:
- 14 deployable public files;
- build-meta exact SHA match;
- deploy-copy mismatches: 0;
- forbidden DEV/secret matches: 0;
- DEV login file absent.

## 7. Preview

Preview deployment:
- ID: `bcf907d0-0d83-4bf9-8a8a-86777363e08f`
- branch: `v14d-89edd9c-preview`
- URL: `https://bcf907d0.raahi-learning-prod.pages.dev`
- alias: `https://v14d-89edd9c-preview.raahi-learning-prod.pages.dev`

Preview verification:
- build SHA exact;
- hash mismatches: 0;
- forbidden matches: 0;
- signed-out Raahi Desk resolved to Welcome;
- signed-out Founding Supply failed closed with scoped-access message.

## 8. Production deployment

Production deployment:
- ID: `6dd2f1d7-3514-47a7-b7b2-631d079a19be`
- branch: `main`
- Pages URL: `https://6dd2f1d7.raahi-learning-prod.pages.dev`
- custom origin: `https://learning.myraahi.co.in`
- source: `89edd9c`

Immediate rollback anchor:
- ID: `18f52dbf-fbb7-4371-906a-09734f0fb9df`
- source: `c990d9a`

Production file verification:
- build-meta SHA: exact
- hash mismatches: 0
- forbidden public matches: 0

## 9. Browser cache observation

An already-open SPA tab initially displayed V1.4B copy after production promotion because only the hash route changed; the document itself had not reloaded.

This was not a CDN caching defect:
- Cloudflare asset headers: `Cache-Control: public, max-age=0, must-revalidate`.

A forced full-document reload immediately loaded V1.4D and showed the new scoped-access copy.

Operational implication:
- existing tabs need a normal page refresh after deployment;
- no packaging change is required.

## 10. Browser canary limitation

The two dedicated city-admin browser windows were signed out.

Google sign-in progressed to:
- `rajeev.backup1.2112@gmail.com` password prompt;
- `rajeev.backup2.2112@gmail.com` password prompt.

The assistant did not request, store, infer or type Google passwords.

Therefore real-account browser-manager UI canary remains pending manual Google authentication, while the exact same real identities passed server-side production authorization proofs.

## 11. Global-admin manual gate

The user selected:

`choudhary.ajit2112@gmail.com`

as the first global Platform Admin.

The Account already exists and is active. No platform_admin capability exists yet.

The connected database execution safety layer blocked assistant-driven first-admin privilege creation. That block was not bypassed.

The authenticated Supabase SQL Editor is open and pre-filled with a guarded one-time bootstrap that:
- aborts if any active Platform Admin already exists;
- matches the exact active Ajit Account + email;
- inserts exactly one active `platform_admin`;
- writes `ops.bootstrap_platform_admin` audit evidence;
- returns the resulting global admin row.

The assistant deliberately did not press **Run**.

Once the user presses Run successfully, immediately verify:
- exactly one active Platform Admin;
- it is Ajit's Account;
- audit row exists;
- Ajit account context includes `platform_admin`;
- global Raahi Desk + Founding Supply routes become available after sign-in/refresh.
