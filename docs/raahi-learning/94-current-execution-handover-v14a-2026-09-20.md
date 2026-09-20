# Raahi Learning — Current Execution Handover — V1.4A — 2026-09-20

Status: **HANDOVER FROZEN — V1.4A QUALIFIED SOURCE + PACKAGE READY, NOT YET DEPLOYED**

Repository: `rajeevbackup42112-coder/raahi`  
Branch: `raahi-learning-implementation-v1`  
Supabase project currently used by the public early release: `iiwwmqokaeflaenhlyip`  
Public origin: `https://learning.myraahi.co.in`

## 1. Read order in the next chat

Read these files in order:

1. `docs/raahi-learning/94-current-execution-handover-v14a-2026-09-20.md` — **this file; exact current execution state**
2. `docs/raahi-learning/93-investor-delight-v14a-implementation-evidence-2026-09-20.md`
3. `docs/raahi-learning/92-market-activation-seeding-blueprint-v1.4.md`
4. `docs/raahi-learning/91-investor-delight-screen-redesign-plan-v1.4.md`
5. `docs/raahi-learning/90-emotional-design-blueprint-v1.4.md`
6. `docs/raahi-learning/99-handover.md`
7. `docs/raahi-learning/89-public-go-live-evidence-2026-09-20.md`
8. `docs/raahi-learning/88-gomoh-first-public-launch-model-2026-09-20.md`

Do not restart product design or backend architecture.

## 2. Current public-production state

Raahi Learning is already publicly reachable at:

`https://learning.myraahi.co.in`

Google OAuth is already **In production / External**. Public Google admission has been proven with an account that was outside the former OAuth test-user list.

Dhanbad and Gomoh are both live/selectable Locations.

Gomoh is the first promotion/acquisition market, not an account or permission boundary.

Selected Location is a browsing/discovery/community context. It does not replace Account identity or erase Classes, Messages, relationships or learning history.

Production data must now be treated as real user data.

**Important:** the V1.4A visual redesign described below has **not yet been deployed to the public origin**. Public production remains on the previously qualified artifact.

## 3. V1.4A product/design decision

The user correctly observed that the earlier Home was still too text-heavy.

The frozen V1.4A direction is:

> **Home = discovery + momentum, not product documentation.**

Final simplified Home hierarchy:

- selected Location;
- **Find. Learn. Grow.**
- short support line: **Teachers and learning near you.**
- two primary actions:
  - **Find a teacher**
  - **I need tuition**
- **Your learning** only when there is useful current Class content;
- empty Your-learning block is suppressed;
- **For you in <Location>**;
- only two compact learning/provider cards on Home;
- richer information remains inside Explore and provider/profile detail;
- advertising section heading becomes **Featured**, while every actual ad remains explicitly labelled **Sponsored**.

Home teacher cards intentionally remove secondary verification/mode/save clutter while retaining the useful scan information: identity, subject, locality, fee and availability.

## 4. V1.4A implementation

Presentation layer:

- `apps/raahi-learning/delight-v14.css`
- `apps/raahi-learning/delight-v14.js`

It adds:

- `RAAHI — Your local learning network` presentation;
- warmer visual system;
- proper SVG navigation/location icons;
- richer Welcome;
- simpler locality-led Home;
- improved Explore, Community, Messages and Location presentation;
- avatar/initial fallbacks;
- better empty states;
- mobile responsiveness;
- reduced-motion support;
- public Terms/Privacy copy updated from historical controlled-pilot wording to early-public-release wording.

The V1.4A delight layer contains no Supabase calls, RPCs, fetches or direct operational table mutations.

## 5. Exact V1.4A source anchor

**Candidate commit:**

`bd2674873b88002907f8e45ee8e90bd10937dad5`

Commit message:

`Add investor delight UI pass`

This exact commit was pushed to:

`origin/raahi-learning-implementation-v1`

### GitHub qualification

Workflow:

`Raahi Learning Model Tests`

Run:

- run number: **645**
- run ID: **35522473066**
- exact head SHA: `bd2674873b88002907f8e45ee8e90bd10937dad5`
- conclusion: **success**

Local qualification on the same intended V1.4A source:

- production/launch guards: **48/48 passed**
- backend-free model/property suite: **5,349,572 cases, 0 failures**
- production-like load guard earlier in this V1.4A qualification: **9/9 passed**
- `git diff --check`: clean at qualification
- V1.4 JS syntax: clean

## 6. Exact-build reconstruction

The frozen frontend was reconstructed locally from the canonical V1.3 source bundle using:

- Windows tar: `C:\Windows\System32\tar.exe`
- Git patch: `C:\Program Files\Git\usr\bin\patch.exe`

The first attempt failed harmlessly because Git tar shadowed Windows tar and interpreted `C:\...` as a remote path. The corrected PATH order used Windows tar first and Git patch second.

Successful reconstruction output:

`C:\Users\Dipti\Downloads\raahi-cutover-20260920\apps\raahi-learning\reconstructed-v13`

Reconstructed `build-meta.json` exact commit:

`bd2674873b88002907f8e45ee8e90bd10937dad5`

No DEV branch marker was supplied during reconstruction.

## 7. Exact release package — built, not deployed

Package directory:

`C:\Users\Dipti\Downloads\raahi-learning-v14a-bd26748-release`

Release metadata:

- release mode: `CONTROLLED_PILOT`
- exact commit: `bd2674873b88002907f8e45ee8e90bd10937dad5`
- origin: `https://learning.myraahi.co.in`
- project ref: `iiwwmqokaeflaenhlyip`

The name `CONTROLLED_PILOT` is still the package-mode token used by the existing same-project packager. It does **not** mean Google OAuth is still in Testing; Google OAuth is already public/production. Do not casually rename this package mode without impact analysis because it also selects the current Google-only phone-trust configuration.

Package public files:

- `app.live-core-v13.js`
- `build-meta.json`
- `delight-v14.css`
- `delight-v14.js`
- `index.html`
- `launch-polish-v13.js`
- `live.js`
- `live-product-fix-v13.js`
- `live-thread-deeplink-v13.js`
- `privacy.html`
- `styles.css`
- `terms.html`

Additional local integrity file:

- `SHA256SUMS.txt`

Package checks:

- embedded `build-meta.json` file hashes: **all matched**
- DEV/secret boundary matches for `dev-test-login`, `dev-test-identities`, `sb_secret_`, `dev.learning.myraahi`: **0**
- no `dev-test-login-v13.html` shipped
- `SHA256SUMS.txt` SHA256:
  `e24b804c90a75184050f4279aa346f5de9bb3c5ddb4f91948f8bf1414c3e7056`

The package has **not** been uploaded to Cloudflare yet.

## 8. Visual QA already completed

Isolated Edge QA profiles were used rather than disturbing the normal authenticated browsers.

Desktop Home was checked around a `1275 × 646` CSS viewport.

The simplified Home showed:

- Gomoh;
- Find. Learn. Grow.;
- Teachers and learning near you.;
- Find a teacher;
- I need tuition;
- compact Your learning;
- two compact provider cards;
- Featured/Sponsored section.

Mobile checks were performed at `390 × 844` for:

- Welcome;
- Home;
- Explore;
- Location chooser.

Core pages did not show accidental document-width overflow.

Welcome value cards intentionally become an internal horizontally swipeable row on small screens.

## 9. Backend boundary discovered during UI work

Existing backend already supports:

- Account `avatar_type` / `avatar_ref`;
- Learner `avatar_type` / `avatar_ref`;
- Organization logo metadata;
- public teacher-profile avatar metadata.

One narrow later enhancement remains:

`discover_teaching_options()` does not currently project teacher avatar metadata, although the public teacher-profile RPC already does.

Therefore fully photo-forward Explore cards may later need a small projection-contract change. This is **not** a backend redesign.

Google identity `avatar_url` metadata exists but must not automatically become a public Raahi profile photo. Raahi-approved profile/avatar choices remain the publication authority.

## 10. IMPORTANT dirty-worktree warning at handover

After the CI-green V1.4A commit and exact package were created, the local checkout contains **uncommitted follow-up work** plus the generated reconstruction directory.

Current tracked local modifications:

1. `apps/raahi-learning/launch-polish-v13.js`
2. `tests/launch-polish.test.mjs`

Untracked generated directory:

3. `apps/raahi-learning/reconstructed-v13/`

These tracked modifications are **NOT part of commit `bd267487...` and NOT part of the already-built exact release package**.

Intent of the local follow-up:

- remove the remaining user-facing phrase `During this controlled pilot` from Google-only phone-trust copy;
- add a regression assertion that the public live service no longer calls itself a controlled pilot.

However, the current local `launch-polish-v13.js` diff also contains Windows-encoding mojibake, including corrupted apostrophe/em-dash/middle-dot characters.

### Required treatment

Do **not** commit or deploy those local tracked diffs as-is.

In the next chat:

1. inspect `git diff -- apps/raahi-learning/launch-polish-v13.js tests/launch-polish.test.mjs`;
2. preserve the intended semantic copy change;
3. repair all mojibake in the touched JS using UTF-8-safe tooling;
4. run the focused launch-polish + V1.4 tests;
5. rerun production guards;
6. commit this as a small follow-up **only if** the copy change is still desired before deployment;
7. if that follow-up is committed, rebuild/repackage from the new exact SHA; do not deploy the old package while claiming the new copy is included.

The generated `reconstructed-v13/` directory is build output and should not be committed.

## 11. Exact next execution sequence

Resume from here:

1. Read this handover and doc 93.
2. Inspect/repair the two uncommitted launch-polish files described above.
3. Decide through implementation logic, not a new product discussion, whether the last `controlled pilot` phrase should be removed before deployment. The user has already publicly launched; the likely answer is yes.
4. Make the minimal UTF-8-safe copy/test fix.
5. Run:
   - `git diff --check`
   - JS syntax checks
   - focused launch/V1.4 tests
   - full 48-test production guard suite
   - 5,349,572-case model suite if tracked production source changes
6. Commit/push the follow-up without asking for routine approval.
7. Verify GitHub Model Tests on the exact new SHA.
8. Reconstruct the frontend on that exact SHA.
9. Repackage the public artifact on that exact SHA.
10. Reverify embedded hashes + DEV/secret boundary.
11. Check Cloudflare authentication/deployment tooling.
12. Prefer a **Cloudflare Pages branch/preview deployment first** if available.
13. Browser-canary the preview:
    - Welcome;
    - Google sign-in entry;
    - authenticated Home;
    - Explore;
    - Dhanbad/Gomoh switching;
    - Community/Messages shell;
    - Privacy/Terms;
    - no DEV marker.
14. If preview is green, deploy to the existing `raahi-learning-prod` Pages project / public origin.
15. Immediately run production browser canary and verify the deployed `build-meta.json` exact SHA.
16. Update doc 93/99 or create the next deployment evidence doc marking V1.4A **PUBLIC LIVE**.
17. Commit/push deployment evidence.
18. Only then start the separate **Raahi Desk / market activation / seeding backend slice** from doc 92.

## 12. Cloudflare state

Existing Pages project:

`raahi-learning-prod`

Pages hostname:

`raahi-learning-prod.pages.dev`

Custom public domain:

`https://learning.myraahi.co.in`

V1.4A has **not** been deployed there yet.

At the handover point, the workstation had:

- `npx` available;
- no globally resolved `wrangler` command was found in PATH;
- Cloudflare CLI authentication had **not yet been checked** for this V1.4A deployment step.

Do not assume CLI auth exists. Check it.

## 13. Do not reopen these frozen rules

- one platform, one identity, many Locations;
- Location is context, not account membership;
- Dhanbad + Gomoh stay live/selectable;
- Gomoh-first promotion is not a geography gate;
- Account != Learner;
- no turning-18 lifecycle;
- no public Learner directory;
- no unrestricted DM;
- Community remains local/authenticated;
- canonical RPCs own consequential writes;
- PostgreSQL is source of truth;
- realtime only invalidates/refetches;
- no public ratings/reviews;
- ads remain education-only, Sponsored-labelled and excluded from private/Class/Test surfaces.

## 14. Working style

The user wants autonomous continuation.

- Do not restart planning.
- Do not ask routine technical approvals.
- Do not silently change frozen business rules.
- For contradictions use impact analysis:
  rules -> entities -> relationships -> states -> permissions -> UI -> tests.
- Keep going until a genuine human login/consent/business decision boundary is reached.
- Commit/push routine implementation changes using best judgement.
- Never expose secrets.
- Do not touch real production data destructively.

## 15. Security reminders

Never expose:

- Supabase DB password;
- DPAPI credential blob;
- Google OAuth client secret;
- Supabase service-role secrets;
- GitHub credentials/token;
- OTPs;
- full DKIM.

The old backup/security state remains described in docs 87–89 and 99.

## 16. Product phase after V1.4A deployment

Do **not** immediately start building more features.

The next planned product/domain slice is the market-activation/seeding system in doc 92, including the distinction between legitimate assisted/seeded activity and organic user activity.

The objective is to make Gomoh and Dhanbad feel alive **without fabricating demand, fake teachers, fake reviews, fake ratings or fake engagement**.

The UI should increasingly feel human, visual, curious and optimistic, but the platform's factual/trust surfaces must remain truthful.
