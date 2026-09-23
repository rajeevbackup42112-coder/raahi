# Raahi Learning — Current Execution Handover — V1.4K Alignment Qualified

Date: **2026-09-23**
Status: **ALIGNMENT SOURCE + BACKEND + SEALED REAL-BROWSER QUALIFICATION GREEN; PUBLIC FRONTEND NOT YET UPDATED**

Repo: `rajeevbackup42112-coder/raahi`  
Branch: `raahi-learning-implementation-v1`  
Learning Supabase: `iiwwmqokaeflaenhlyip`

## 1. Why this handover exists

During the first genuine Teacher proof, a product-alignment audit found that the backend remained strong but the human first-use journey had drifted:

- new Google Accounts could bypass profile confirmation / first-use intent;
- Teacher setup could collide with workspace authorization UI;
- some ordinary screens exposed backend vocabulary;
- real browser journeys were under-tested because many prior UI tests began from pre-seeded authority.

Do not restart architecture or product design. V1.4K repairs orchestration and presentation while preserving canonical authority.

Read in this order:

1. `119-canonical-alignment-audit-prelaunch-2026-09-23.md`
2. `120-first-use-intent-alignment-contract-v1.4k.md`
3. `121-human-language-alignment-contract-v1.4k.md`
4. `122-google-profile-confirmation-alignment-contract-v1.4k.md`
5. `123-teacher-onboarding-continuity-contract-v1.4k.md`
6. `124-learner-parent-institute-context-contract-v1.4k.md`
7. this document.

## 2. Backend changes now applied

Permanent additive migrations applied:

- `v14k_first_use_intent_alignment`
- `v14k_google_profile_confirmation_alignment`

New server-owned metadata:

- `accounts.first_use_completed_at`
- `accounts.profile_onboarding_completed_at`

These are onboarding UX metadata only. They are not roles, capabilities or verification signals.

Canonical completion commands:

- `complete_first_use_onboarding(text)`
- `complete_profile_onboarding(text)`

Existing Accounts were grandfathered for profile confirmation.

## 3. Current live-data safety state

Read-only verification after repair:

- total Accounts: **7**
- existing Accounts profile-confirmation complete: **7 / 7**
- first-use complete: **4 / 7**

The genuine assisted Teacher test remains deliberately untouched:

- assisted request state: **requested**
- Teacher Profiles: **0**
- Teaching Options: **0**
- active `teach` capability: **0**

Do not silently enable teaching or publish anything for this Account.

## 4. Repaired journeys

### New Google user

**Google sign-in → confirm/edit Raahi profile → What brings you here today? → chosen setup/explore**

Five first-use choices:

- I want to learn
- I’m helping someone learn
- I teach
- I represent an institute
- I’m just exploring

Choosing an intent grants no authority.

### Self-service Teacher

**Start teaching → Set it up myself → phone check when required → Teacher Profile → first What I Teach + Location → Teacher Home**

Sensitive actions preserve and resume the exact intended action across phone trust.

### Assisted Teacher

**Ask Raahi to help → private draft → Teacher chooses Publish these details → phone check when required → exact acceptance resumes → Teacher Home**

Operator cannot publish for the Teacher.

### Learner / Parent / Institute

- self Learner creation → **My learning**
- managed Learner creation → **Learners I manage**
- Organization creation → **Institute**

Visible context labels are humanized. Context switching never grants authority.

## 5. Important implementation defects caught before public deployment

The new real-browser contract exposed and caused repair of:

1. first-use event-handler mismatch;
2. missing Explore choice;
3. Google profile-confirmation bypass;
4. onboarding vs deep-link authorization ordering;
5. late Founding Supply overlay re-render race;
6. sensitive Teacher actions losing intent at phone trust;
7. self-service Teacher stopping before first What I Teach;
8. context-switch labels exposing implementation-role language.

This is why route/source assertions alone are no longer sufficient for critical journeys.

## 6. Green qualification

### Model Tests

Latest confirmed: **Raahi Learning Model Tests #730 — SUCCESS**

Includes:

- backend-free invariant suite;
- V1.4K first-use alignment;
- V1.4K Google profile confirmation;
- V1.4K human-language alignment;
- V1.4K Teacher onboarding continuity;
- release/operational guards;
- phone-trust regressions;
- V1.4 product regressions;
- operations syntax;
- load-target guards.

### Sealed real-browser qualification

Latest confirmed: **Raahi Learning Onboarding Browser Contract #14 — SUCCESS**

The exact reconstructed frontend is exercised in Chromium while all real Supabase network access is blocked.

Green interactions:

- **15** profile + first-use intent interactions across desktop, iPhone-size and Android-size;
- **4** Teacher self-service/assisted + phone-resume interactions across desktop and iPhone-size;
- **8** self Learner / Parent / Institute / multi-context-switch interactions across desktop and iPhone-size.

These tests click actual controls and assert important state transitions in the sealed fake backend.

## 7. DEV vs PUBLIC frontend

DEV auto-deployment currently reported:

- origin: `https://dev.learning.myraahi.co.in`
- build-meta commit observed: `cf0b805a42303f3be46479ad03b1b7eb4a49b9a5`

The public origin `https://learning.myraahi.co.in` is still on the older pre-alignment release and has **not** been updated.

Do not deploy public yet.

## 8. DEV writer safety

Do **not** recreate `.github/RAAHI_LEARNING_DEV_WRITES_ENABLED`.

Do **not** re-enable synthetic DEV writers.

The Learning Supabase project contains genuine production data. The sealed browser contract intentionally replaces the old synthetic-write approach for these onboarding UX journeys.

## 9. Immediate next gate

The next meaningful gate is a **genuine authenticated browser canary on DEV**.

Use one of the existing remote-debug Edge profiles / an authorized browser session and verify the real DEV frontend with a genuine Google session.

Preferred canary scope before public release:

1. sign in to DEV with a genuine test Account;
2. confirm normal established-Account landing;
3. verify visible context labels and Home;
4. inspect Start teaching / assisted state read-only where applicable;
5. do not accept or publish the existing genuine assisted Teacher request;
6. verify logout/login continuity if practical;
7. capture screenshots / browser evidence;
8. only then prepare the aligned public release artifact.

If the authorized browser is at Google sign-in, the user may need to complete that one login action manually.

## 10. Public rollout after canary

Only after genuine DEV canary:

1. re-run latest Model Tests + browser contract against exact app source;
2. build controlled public release artifact with existing release guards;
3. verify hashes / forbidden references;
4. deploy public frontend;
5. verify `build-meta.json` exact release commit;
6. genuine public browser smoke;
7. then resume the existing real Teacher request from `requested`.

## 11. Never do

- do not restart product design;
- do not rebuild the database;
- do not change frozen authority rules casually;
- do not recreate DEV synthetic writers;
- do not process the genuine Teacher request before aligned public qualification;
- do not treat a route render or source assertion as sufficient launch evidence.
