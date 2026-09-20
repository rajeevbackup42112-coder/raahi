# Raahi Learning V1.3 — Public Origin + Production Google OAuth Proof — 2026-09-20

Status: **PUBLIC ORIGIN VERIFIED — PRODUCTION GOOGLE AUTH VERIFIED — REAL USERS NOT YET ADMITTED**

## 1. Public Pages deployment

Dedicated production Cloudflare Pages project:
`raahi-learning-prod`

Production Pages hostname:
`https://raahi-learning-prod.pages.dev`

Deployment method:
**Pages Direct Upload**

The uploaded source was the immutable controlled-pilot ZIP:
`raahi-learning-controlled-pilot-19283d6.zip`

ZIP SHA-256:
`810537844CC47D39591D685BAA543D79C4277558BFBDC743D419C9AC0EB6A1CA`

Cloudflare unpacked exactly 10 files.

Independent verification against the local candidate:
- all 10 production Pages files returned HTTP 200;
- every deployed file SHA-256 matched the local release candidate byte-for-byte.

## 2. Production custom domain

Public origin:
`https://learning.myraahi.co.in`

Cloudflare requested:
- CNAME name: `learning`
- target: `raahi-learning-prod.pages.dev`

GoDaddy DNS now contains exactly that production CNAME.

Existing `dev.learning` remains pointed to `raahi-learning-dev.pages.dev`.

GoDaddy authoritative nameservers both return the new production CNAME.

Google Public DNS and Cloudflare Public DNS both resolve the production hostname to the Pages target.

The Cloudflare edge serves the custom hostname over HTTPS with HTTP 200.

All 10 files served through `https://learning.myraahi.co.in` were re-downloaded and matched the approved release-candidate hashes byte-for-byte.

## 3. Supabase Auth production URL cutover

Learning project:
`iiwwmqokaeflaenhlyip`

Supabase Site URL is now:
`https://learning.myraahi.co.in`

DEV redirects remain allow-listed.

Production redirects remain allow-listed:
- `https://learning.myraahi.co.in/`
- `https://learning.myraahi.co.in/**`

This follows current Supabase guidance that Site URL should be the official production URL while environment-specific URLs remain in the redirect allow-list.

## 4. Production Google OAuth proof

Dedicated production Google OAuth credentials were already installed in Supabase.

A real Google sign-in was performed from:
`https://learning.myraahi.co.in`

Test identity:
`choudhary.ajit2112@gmail.com`

Observed backend evidence:
- Supabase Google identity update occurred at the authentication attempt;
- Auth user remained non-harness;
- linked Raahi Account exists and is active.

Final clean browser proof:
1. public Welcome page loaded;
2. Continue with Google opened Google account chooser;
3. configured test account selected;
4. Google/Supabase callback completed;
5. browser returned to **Home — Raahi Learning**;
6. authenticated Dhanbad Home projection rendered.

Therefore production Google OAuth is verified end-to-end.

## 5. OAuth loop incident and resolution

During the first public OAuth proof, repeated login appeared to loop.

Root cause:
the local Windows/router resolver still cached the earlier NXDOMAIN state for `learning.myraahi.co.in` immediately after the new CNAME was created.

Evidence:
- Google → Supabase authentication succeeded;
- the Supabase Google identity timestamp updated at each attempt;
- callback browser tab ended on `learning.myraahi.co.in — Network error`;
- public Google DNS and Cloudflare DNS already resolved the hostname;
- direct Cloudflare edge access returned HTTP 200.

Temporary diagnostic action:
Edge Secure DNS was switched from its original current-provider mode to Cloudflare DoH.

After DNS propagation completed:
- a clean OAuth attempt returned to Raahi Home successfully;
- router/default DNS began resolving `learning.myraahi.co.in`;
- Edge Secure DNS was restored to its exact original state: **Secure DNS ON → Use current service provider**.

No application code or OAuth configuration change was required.

## 6. Support mailbox

`support@myraahi.co.in` remains operational on Zoho Mail Free.

Two-way mail delivery was already proven.

## 7. Current controlled-pilot boundary

Still not done:
- mandatory off-platform database dump;
- final synthetic public-domain cleanup;
- harness Auth deletion;
- DEV synthetic writer seal;
- sealed `dev-test-identities` deployment;
- retired MessageCentral secret removal;
- Gomoh `preparing → live`;
- controlled-pilot canary;
- Google app general-public admission/publishing decision;
- final explicit real-user go-live approval.

No general pilot audience has been admitted.

## 8. Current backup blocker

The prepared canonical database backup script requires a direct Postgres connection URL.

Current findings:
- no database password is stored in the repo;
- no direct DB URL is referenced by GitHub workflows;
- no saved Learning database connection was found on the operator PC;
- Supabase Dashboard confirms the database password is not viewable after project creation;
- resetting the database password will break any existing direct Postgres connections;
- the operator PC currently has neither Docker nor the Supabase CLI/pg_dump toolchain required by the canonical dump procedure.

Supabase Free does not provide automatic downloadable daily backups; current Supabase guidance recommends CLI `db dump` for Free projects.

Therefore the next cutover action requires an explicit decision to rotate/reset the database password and establish a temporary controlled backup execution path. Do not perform destructive synthetic cleanup before this backup exists.

## 9. Non-harness Auth classification

Exactly 8 non-harness Auth identities currently exist.

Known Raahi/operator identities:
- `rajeev.backup1.2112@gmail.com`
- `rajeev.backup2.2112@gmail.com`
- `rajeev.backup3.2112@gmail.com`
- `rajeev.backup4.2112@gmail.com`
- `rajeev.backup5.2112@gmail.com`
- `rajeev.backup6.2112@gmail.com`
- `choudhary.ajit2112@gmail.com`

Additional non-harness identity:
- `nareshkumar62922@gmail.com` (display name: Naresh Kumar)

No non-harness Auth identity has been deleted.

The later public-domain reset intentionally removes pre-pilot Raahi application rows while preserving reviewed non-harness Auth identities unless explicitly decided otherwise.
