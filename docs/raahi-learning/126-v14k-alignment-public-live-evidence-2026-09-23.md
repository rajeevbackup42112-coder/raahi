# Raahi Learning V1.4K — Alignment Public-Live Evidence — 2026-09-23

Status: **PUBLIC LIVE — ALIGNMENT REPAIR DEPLOYED AND GENUINE PUBLIC CANARY GREEN**

Repository: `rajeevbackup42112-coder/raahi`  
Branch: `raahi-learning-implementation-v1`  
Supabase: `iiwwmqokaeflaenhlyip`  
Public origin: `https://learning.myraahi.co.in`

## 1. Release source

Release commit:

`b770a9ba6bb6d220fb2f46e91b28d85f2850df3f`

This commit is a descendant of the previously live production source `dc15952`.

App/backend differences from `dc15952` to this release are limited to:

- `apps/raahi-learning/delight-v14.js`
- `apps/raahi-learning/founding-supply-v14c.js`
- `apps/raahi-learning/live-product-fix-v13.js`
- `supabase/migrations/20260923085000_v14k_first_use_intent_alignment.sql`
- `supabase/migrations/20260923103500_v14k_google_profile_confirmation_alignment.sql`

The two migrations were already applied and verified before the frontend release.

## 2. Pre-release qualification

Latest green automated evidence before release:

- Raahi Learning Model Tests **#730** — success.
- Raahi Learning Onboarding Browser Contract **#14** — success.

Browser Contract #14 covers **27 actual Chromium interactions**:

- 15 Google-profile + first-use intent interactions across desktop, iPhone-size and Android-size;
- 4 Teacher self-service/assisted + phone-resume interactions across desktop and iPhone-size;
- 8 self Learner / Parent / Institute / multi-context-switch interactions across desktop and iPhone-size.

The browser contract blocks real Supabase network access, so these UX proofs cannot write to genuine data.

## 3. Genuine DEV canary

Using a genuine Google-authenticated session on `https://dev.learning.myraahi.co.in`:

- established Account landed on Home;
- Home showed the aligned **Find. Learn. Grow.** presentation;
- **Start teaching** was visible;
- clicking Start teaching opened the humanized four-step Teacher setup;
- clicking **Ask Raahi to help** opened the existing genuine assisted request;
- request showed **Your request is private. Nothing is public yet.**;
- no **Publish these details** button was present in the `requested` state;
- reload preserved the authenticated request state.

No Teacher Profile, Teaching Option or teach capability was created.

## 4. Release package

Release mode:

`CONTROLLED_PILOT`

Target:

- origin: `https://learning.myraahi.co.in`
- Supabase project: `iiwwmqokaeflaenhlyip`
- phone trust: `phone_trust_required`
- provider: `startmessaging`

Package:

- deployable files: **15**
- content-hash mismatches before deploy: **0**
- forbidden DEV/secret references: **0**
- `build-meta.json` SHA-256:

`68332de2f65b0dda2c4a9883b1f5344b133f5f873f97938c736e89ac7631703c`

## 5. Preview

Cloudflare Pages preview:

- deployment ID: `d521accb-6f58-4bf4-aefd-d7697ea6a833`
- branch: `v14k-b770a9b-preview`
- source: `b770a9b`
- exact URL: `https://d521accb.raahi-learning-prod.pages.dev`

Preview verification:

- exact build-meta commit: `b770a9ba6bb6d220fb2f46e91b28d85f2850df3f`
- release mode: `CONTROLLED_PILOT`
- hash mismatches against release manifest: **0**

## 6. Production deployment

Cloudflare Pages production:

- deployment ID: `7cbe5890-cf90-4379-80a7-88abfbe0a4a9`
- branch: `main`
- source: `b770a9b`
- exact Pages URL: `https://7cbe5890.raahi-learning-prod.pages.dev`
- custom origin: `https://learning.myraahi.co.in`

Immediate rollback anchor:

- deployment ID: `7df0393a-541b-445b-97af-48be0f0b6f6a`
- source: `dc15952`

Custom-domain verification:

- exact build-meta commit: `b770a9ba6bb6d220fb2f46e91b28d85f2850df3f`
- hash mismatches: **0**
- forbidden DEV/secret references in packaged artifact: **0**

## 7. Genuine public browser smoke

Using the same authorized real browser profile:

1. clean public Welcome showed the aligned signed-out copy:
   - **Find teachers. Share what you need. Learn locally.**
2. **Continue with Google** completed successfully without another credential prompt;
3. public Home loaded as the genuine signed-in Account;
4. Home showed **Find. Learn. Grow.** and **Start teaching**;
5. **Start teaching → Ask Raahi to help** opened the genuine private request;
6. request remained `requested`;
7. no **Publish these details** button was present;
8. page reload preserved the same private state;
9. browser-fetched build-meta matched exact release commit `b770a9b`.

## 8. Genuine Teacher state after public release

Read-only database verification after public smoke:

- assisted request state: **requested**
- Teacher Profiles for the genuine Account: **0**
- Teaching Options for the genuine Account: **0**
- active `teach` capability: **0**

No publication occurred during canary or deployment.

## 9. Security advisor

Supabase Security Advisor after the V1.4K migrations reports only the existing Auth warning:

- **Leaked Password Protection Disabled**

No new V1.4K security lint was introduced.

## 10. Launch status

The V1.4K alignment repair is now publicly live and qualified.

Closed launch blockers:

- Google profile-confirmation bypass;
- missing/incorrect first-use intent orchestration;
- missing Explore choice;
- Teacher setup deep-link guard collision;
- Teacher overlay initialization race;
- phone-trust action loss;
- incomplete self-service Teacher onboarding;
- backend vocabulary on ordinary setup surfaces;
- public **Find Students** positioning contradiction;
- unproven Learner/Parent/Institute/context-switch continuations.

The next execution step is the original first genuine Founding Supply proof.

That request is safely waiting at `requested`.

Do not prepare the private draft using invented Teacher facts. The request currently contains no proposed teaching details. A genuine Teacher-provided subject/level, experience/profile wording, teaching mode/area and fee wording are required before an operator can prepare the draft.
