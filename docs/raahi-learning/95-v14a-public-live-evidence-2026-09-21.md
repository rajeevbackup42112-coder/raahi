# Raahi Learning V1.4A — Public Live Evidence — 2026-09-21

Status: **PUBLIC LIVE — PRODUCTION CUTOVER GREEN**

Repository: `rajeevbackup42112-coder/raahi`
Branch: `raahi-learning-implementation-v1`
Public origin: `https://learning.myraahi.co.in`
Supabase project: `iiwwmqokaeflaenhlyip`

## 1. Exact production source

Production V1.4A source commit:

`36f13d49c1c330e3334d89fa06dd090f67650bd7`

Commit message:

`Remove stale controlled pilot copy`

GitHub Model Tests:
- run number: **647**
- run ID: **35528092771**
- exact head SHA: `36f13d49c1c330e3334d89fa06dd090f67650bd7`
- conclusion: **success**
Local qualification on the final source:
- focused launch-polish + delight tests: **7/7 passed**
- production/launch guard suite: **49/49 passed**
- backend-free model/property suite: **5,349,572 cases, 0 failures**
- production-like load guard: **9/9 passed**
- `git diff --check`: clean
- V1.4 JavaScript syntax checks: clean

The final public Google-only copy is:

`Google sign-in is all you need. Phone verification is not required.`

The stale phrase `During this controlled pilot` is rejected by regression coverage.

## 2. Exact release artifact

Release directory used for qualification:

`C:\Users\Dipti\Downloads\raahi-learning-v14a-36f13d4-release`

Deploy-only directory:

`C:\Users\Dipti\Downloads\raahi-learning-v14a-36f13d4-deploy`

`SHA256SUMS.txt` SHA-256:
`713e0e47a28b57b83629339197b65df419ca35e970849897e6371301a79af33a`

Release boundary checks:
- embedded file hashes matched before upload
- no `dev-test-login-v13.html`
- no `dev-test-login`
- no `dev-test-identities`
- no `sb_secret_`
- no `dev.learning.myraahi`
- release mode remains `CONTROLLED_PILOT` only as the existing compatibility/package token
- Google OAuth itself remains public / In production

## 3. Preview qualification

Cloudflare Pages project:

`raahi-learning-prod`

Qualified preview alias:

`https://v14a-36f13d4-preview.raahi-learning-prod.pages.dev`

Preview deployment URL:

`https://d2989661.raahi-learning-prod.pages.dev`
Preview `build-meta.json` reported the exact final SHA `36f13d49...`.

Authenticated preview browser canary passed:
- Welcome
- Google sign-in entry and real OAuth callback
- simplified authenticated Home
- Explore
- Dhanbad -> Gomoh -> Dhanbad Location round trip
- Community
- Messages
- Privacy
- Terms
- no DEV marker

A temporary exact preview OAuth redirect was added only for preview QA and was removed immediately afterward. Supabase Auth redirect configuration was restored to its pre-preview set.

## 4. Production rollback anchor

Immediately before V1.4A production deployment, public production reported:

`commit_sha = 19283d62664d92cf45bd4916640d62b6643131b0`

Cloudflare production deployment:
- deployment ID: `3dcf61d0-9cb5-4ef7-9ec5-dc4b672bc52f`
- production branch: `main`
- URL: `https://3dcf61d0.raahi-learning-prod.pages.dev`
This is the immediate pre-V1.4A rollback anchor.

## 5. Production deployment

Wrangler version: `4.135.0`

The exact deploy-only directory was uploaded to the **existing** Pages project `raahi-learning-prod` on production branch `main`.

Production deployment completed successfully:
- deployment ID: `14245932-652a-44cd-adcf-a86a425ea5fe`
- production URL: `https://14245932.raahi-learning-prod.pages.dev`
- attached source: `36f13d4`
- custom public origin remained `https://learning.myraahi.co.in`

No second Pages project was created.

## 6. Production exact-build verification

After deployment, public `build-meta.json` returned:

`commit_sha = 36f13d49c1c330e3334d89fa06dd090f67650bd7`

Every file listed in public `build-meta.json` was downloaded as raw bytes and SHA-256 checked.
Result:
- remote file hash mismatches: **0**
- forbidden public boundary matches: **0**

The forbidden scan included:
- `dev-test-login`
- `dev-test-identities`
- `dev.learning.myraahi`
- `sb_secret_`
- exact stale phrase `During this controlled pilot`

## 7. Production browser canary

A previously authenticated normal Edge session on the public origin remained valid after deployment.

Authenticated Home passed with:
- Dhanbad
- `Find. Learn. Grow.`
- `Teachers and learning near you.`
- `Find a teacher`
- `I need tuition`
- `For you in Dhanbad`
- compact local-network empty/growth state
Authenticated Explore passed with:
- `Explore Dhanbad`
- teacher/learning search
- Learning Request action
- Maths / Science / English / Coding / Music discovery chips

Authenticated Community passed with:
- `Dhanbad Learning Community`
- local learning discussion copy
- `New post`
- healthy empty state

Authenticated Messages passed with:
- `Messages`
- existing-connection safety copy
- healthy empty state

Location switching was proven on production:
- Dhanbad -> Gomoh
- Home changed to `GOMOH` / `For you in Gomoh`
- Gomoh -> Dhanbad
- Home returned to `DHANBAD` / `For you in Dhanbad`
The Location change executed through the normal canonical `set_selected_location` path, not direct table mutation.

Google sign-in entry was independently checked from a clean cloud browser. It redirected to Google OAuth at `accounts.google.com`; the cloud browser had no signed-in Google account, so no credentials were entered. Production OAuth continuity is additionally backed by the earlier public admission proof and the green authenticated production session.

Public Privacy and Terms pages returned the V1.4A early-public-release copy.

## 8. Final state

V1.4A is now **PUBLIC LIVE** at:

`https://learning.myraahi.co.in`

Production is serving the exact qualified source SHA:

`36f13d49c1c330e3334d89fa06dd090f67650bd7`

Do not redeploy the older V1.4A package anchored to `bd267487...`.

The next planned work is the separate market-activation / seeding / Raahi Desk slice governed by `92-market-activation-seeding-blueprint-v1.4.md`. Do not mix that backend/domain work into the completed V1.4A release.
