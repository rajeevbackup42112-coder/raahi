# Raahi Learning V1.4B — Raahi Desk Public Live Evidence — 2026-09-21

Status: **PUBLIC LIVE — MARKET ACTIVATION SLICE 1 GREEN**

Repository: `rajeevbackup42112-coder/raahi`
Branch: `raahi-learning-implementation-v1`
Public origin: `https://learning.myraahi.co.in`
Supabase project: `iiwwmqokaeflaenhlyip`

## 1. Exact source and CI

V1.4B source commit:

`3735e7e2717a04043bd7af7552a7b0b5ec757622`

Commit:

`Add Raahi Desk provenance slice`

GitHub Model Tests:
- run number: **649**
- run ID: **35576898111**
- exact head SHA: `3735e7e2717a04043bd7af7552a7b0b5ec757622`
- conclusion: **success**

Local qualification before the exact commit:
- production/launch guard suite: **56/56 passed**
- backend-free model/property suite: **5,349,572 cases, 0 failures**
- production-like load guard: **9/9 passed**
- V1.4B JavaScript syntax check: passed
- `git diff --check`: clean

## 2. Provenance/domain closure

The first market-activation slice implements truthful Community provenance:

- `organic` — genuine Account-authored Community content
- `platform_editorial` — Raahi Desk platform-authored Community content
- `assisted` — reserved for a later consent-governed genuine-user assistance slice

Hard boundary:

> Seed usefulness, never fake popularity.

Raahi Desk cannot supply or forge:
- public author identity;
- provenance;
- engagement counts;
- comments or reactions;
- timestamps;
- student/parent/teacher identities;
- Learning Requests;
- enquiries;
- ratings/reviews;
- successful-match signals.

The internal operator remains auditable, while public projections render platform-editorial content as:

**Raahi Desk · Platform-authored**

## 3. Supabase migration proof

Permanent migration applied successfully:

`20260921055900_v14_raahi_desk_provenance`

Post-migration runtime smoke passed on the live database inside a transaction and rolled back.

Proven behaviours:
- existing/ordinary Community publishing stays `organic`;
- non-Platform Admin cannot publish as Raahi Desk;
- Platform Admin canonical command can publish `platform_editorial` to a live Location;
- same-key/same-request idempotent retry returns the same post;
- same key with a changed request is rejected;
- public projection hides the internal operator identity;
- public attribution is exactly Raahi Desk / Platform-authored;
- personal blocking of the internal operator does not hide platform speech;
- organic-author blocking remains unchanged;
- genuine user comments/reactions remain genuine user actions;
- direct authenticated writes to `community_posts` remain denied;
- unknown provenance fails the database constraint;
- Location audit records the real operator and target post.

After rollback:
- synthetic test Auth users: **0**
- synthetic test posts: **0**
- synthetic comments/reactions: **0**

Current live activation state at release closure:
- active `platform_admin` capabilities: **0**
- Community posts: **0**
- Community comments: **0**
- Community post reactions: **0**

Therefore V1.4B introduced **no fake activity and no real seeded content** during qualification.

## 4. Supabase advisor review

Security advisor after migration:
- no new Raahi Desk/RLS/security finding;
- only the pre-existing Auth warning that leaked-password protection is disabled.

The current public product uses Google-only sign-in and does not expose password login, so this unrelated Auth configuration was not changed as part of V1.4B.

Performance advisor:
- only existing unused-index informational findings;
- no release-blocking V1.4B finding.

## 5. Exact release artifact

Release directory:

`C:\Users\Dipti\Downloads\raahi-learning-v14b-3735e7e-release`

Deploy-only directory:

`C:\Users\Dipti\Downloads\raahi-learning-v14b-3735e7e-deploy`

Release manifest `SHA256SUMS.txt` SHA-256:

`8547c0b68c8e9b233630298d6c366f82258a7b810733d290c6a700eb12bc02b3`

Package:
- 13 deployable public files;
- exact `build-meta.json` source SHA `3735e7e...`;
- V1.4B `market-activation-v14b.js` present;
- DEV login file absent;
- release mode remains the existing compatibility token `CONTROLLED_PILOT`.

Pre-deploy package scan:
- forbidden public matches: **0**
- deploy-copy hash mismatches: **0**

## 6. Preview qualification

Cloudflare Pages project:

`raahi-learning-prod`

Preview deployment:
- ID: `9617fe9a-527f-4caa-a56f-20ea4c490935`
- branch: `v14b-3735e7e-preview`
- URL: `https://9617fe9a.raahi-learning-prod.pages.dev`
- alias: `https://v14b-3735e7e-preview.raahi-learning-prod.pages.dev`
- source: `3735e7e`

Preview `build-meta.json` reported the exact V1.4B source SHA.

Raw public preview verification:
- hash mismatches: **0**
- forbidden public matches: **0**

Signed-out preview:
- Welcome rendered;
- Google sign-in CTA present;
- no DEV UI;
- direct `#/raahi-desk` did not expose a composer;
- safe denial rendered: **Platform workspace required**.

A temporary exact preview OAuth redirect was added only for authenticated preview QA.

Real Google OAuth then returned to the V1.4B preview origin and authenticated Home rendered successfully.

Authenticated preview passed:
- simplified Home;
- Explore;
- Community;
- Messages;
- direct Raahi Desk route denied to the ordinary non-platform Account;
- Dhanbad -> Gomoh -> Dhanbad Location round trip;
- Privacy;
- Terms.

After QA the temporary preview OAuth redirect was removed. Supabase Auth URL configuration returned to its original five redirect entries.

## 7. Production rollback anchor

Immediately before V1.4B production deployment, production was V1.4A:

- deployment ID: `14245932-652a-44cd-adcf-a86a425ea5fe`
- production branch: `main`
- Pages URL: `https://14245932.raahi-learning-prod.pages.dev`
- source SHA: `36f13d49c1c330e3334d89fa06dd090f67650bd7`

This deployment is the immediate V1.4B rollback anchor.

## 8. Production deployment

The exact preview-qualified deploy directory was uploaded to the existing Pages project on production branch `main`.

V1.4B production deployment:
- deployment ID: `42f1a854-a4e7-41a4-8e7a-dd4edf8f921d`
- Pages URL: `https://42f1a854.raahi-learning-prod.pages.dev`
- source: `3735e7e`
- custom origin: `https://learning.myraahi.co.in`

No second Pages project was created.

Public `build-meta.json` after promotion:

`commit_sha = 3735e7e2717a04043bd7af7552a7b0b5ec757622`

Production raw-file verification:
- hash mismatches: **0**
- forbidden public matches: **0**

## 9. Production browser canary

Authenticated production browser canary passed:
- Home — Dhanbad / Find. Learn. Grow.;
- Explore;
- Community;
- Messages;
- direct Raahi Desk route safely denied to the ordinary Account;
- Dhanbad -> Gomoh -> Dhanbad Location round trip.

A separate local Edge InPrivate production canary also passed:
- signed-out Welcome;
- Continue with Google present;
- direct `#/raahi-desk` showed **Platform workspace required**;
- no publishing composer exposed.

TinyFish could not run the redundant final production signed-out canary because its wallet balance was exhausted. This was not a release blocker because the exact artifact already passed the signed-out preview canary, production raw hashes matched the same artifact byte-for-byte, and local InPrivate production verification completed successfully.

## 10. Final state

V1.4B is **PUBLIC LIVE** at:

`https://learning.myraahi.co.in`

Exact source:

`3735e7e2717a04043bd7af7552a7b0b5ec757622`

Raahi Desk infrastructure is live, but **nobody currently has Platform Admin authority and no Raahi Desk post has been seeded**.

Do not grant Platform Admin to an arbitrary Account merely to exercise the feature. Capability assignment and real market activation remain separate operational actions.

The next market-activation engine from `92-market-activation-seeding-blueprint-v1.4.md` is **Founding Supply**: genuine teacher/coaching-organisation onboarding with explicit review/consent and no fabricated supply.
