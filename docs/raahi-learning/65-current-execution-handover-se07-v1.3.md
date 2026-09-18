# Raahi Learning V1.3 — Current Execution Handover: SE-07 Test Correction

Status: **ACTIVE HANDOVER — RESUME HERE EXACTLY**  
Date: 2026-09-18

This file records the exact implementation/test state at the point the ChatGPT conversation reached its limit. Do not restart planning, Auth setup, R4, UI convergence, or already-closed side-effect slices.

## 1. Canonical environment

Repository:

- `rajeevbackup42112-coder/raahi`
- branch: `raahi-learning-implementation-v1`

Supabase:

- Dashboard/login Account: `rajeev.backup3.2112@gmail.com`
- Organization: `rajeev.backup3.2112@gmail.com's Org`
- Organization ID: `zxcnmenntsusjsgmonfz`
- DEV project: `iiwwmqokaeflaenhlyip`
- region: `ap-south-1`
- project URL: `https://iiwwmqokaeflaenhlyip.supabase.co`

DEV product:

- `https://dev.learning.myraahi.co.in/`

No public production deployment has been authorized.

## 2. Exact Git / deployment state

Last **product-affecting** implementation commit at handover:

`8c68f057b27ae352a6fe5283c5534bd7f34b1113`

Commit message:

`Add Test correction side-effect personas and audit inspector`

Cloudflare DEV `build-meta.json` was verified serving that exact product commit:

`8c68f057b27ae352a6fe5283c5534bd7f34b1113`

After that verification, documentation-only handover commits were added, including:

- `7d4df0dde2f4f58659300794304f8d590883d233` — this detailed SE-07 handover;
- `25095e13f142af1928d11d684d9db91c573219dd` — canonical `99-handover.md` updated to point here.

Therefore the Git branch may be ahead of the deployed static commit by documentation-only changes. This is intentional. In the next chat, inspect the latest branch head read-only and compare product-sensitive files before deciding whether a Cloudflare rebuild is required.

## 3. Supabase migration state

DEV migrations are applied through:

`1030_v13_test_correction_side_effects`

Relevant side-effect migrations:

- 1023 — `v13_enquiry_trial_side_effects`
- 1024 — `v13_class_session_side_effects`
- 1025 — `v13_class_post_side_effects`
- 1026 — `v13_class_membership_lifecycle_side_effects`
- 1027 — `v13_activity_submission_side_effects`
- 1028 — `v13_activity_review_idempotency_fix`
- 1029 — `v13_activity_review_privilege_restore`
- 1030 — `v13_test_correction_side_effects`

Do not recreate or reapply these blindly. Verify current migration state first.

## 4. Proven/closed work

Do not reopen these without contradictory runtime evidence.

### Foundation

- AI Builder v2 retrofit: closed
- hosted Google/phone Auth core proof: proven
- R4 mandatory walking skeleton: proven
- DEV genuine-session test harness: proven
- 20-persona deterministic cohort: proven baseline
- exact-build combined regression anchor: doc 59

### UI / capability convergence

Proven:

- core learner/teacher;
- managed parent / Organization;
- Local Manager / Platform Admin;
- Raahi Ads;
- bounded Organization staff capabilities.

Docs 54–58 contain the evidence.

### Side-effect slices

Closed/proven:

- **SE-01** Enquiry decline/close — migration 1023 / doc 60
- **SE-02** Trial schedule/reschedule/cancel — migration 1023 / doc 60
- **SE-03** Class Session schedule/cancel — migration 1024 / doc 61
- **SE-04** Class post attention signals — migration 1025 / doc 62
- **SE-05** Class Membership/Class lifecycle — migration 1026 / doc 63
- **SE-06** Activity submission/review — migrations 1027–1029 / doc 64

Important SE-06 fixes already made:

- exact review retry must check idempotency before rejecting the now-changed submission lifecycle state;
- migration 1029 restored the pre-existing authenticated execute grant for the private Activity review command.

Do not undo these fixes.

## 5. Regression state at handover

On head `8c68f057...`, the following runs were already **SUCCESS**:

- Model Tests — run `35344097640`
- DEV E2E Harness — run `35344097650`
- Class Session Side Effects — run `35344097606`
- Enquiry Trial Side Effects — run `35344097602`
- Organization Staff Boundaries — run `35344097547`
- Class Lifecycle Side Effects — run `35344097563`
- Class Post Side Effects — run `35344097609`
- Activity Side Effects — run `35344097580`
- Parent/Organization UI Convergence — run `35344097592`
- Core UI Convergence — run `35344097542`
- Privileged UI Convergence — run `35344097614`

The 20-Persona Cohort run `35344097573` subsequently completed **SUCCESS** on the same product commit `8c68f057...`.

So the full recorded head-regression set listed above, including the 20-persona cohort, is green for the last product-affecting handover commit.

## 6. Current active slice — SE-07 released Test correction

This is the exact unfinished work.

Frozen side-effect decision from doc 46:

> If Test results are already visible, correcting a released answer key must notify affected evaluated learner-side Accounts generically. Never include answers, selected choices, score, or correction reason in the notification. Existing correction audit remains authoritative.

### Already implemented

#### A. Migration 1030 applied

File:

`supabase/migrations/1030_v13_test_correction_side_effects.sql`

The canonical private command `app_private.cmd_correct_answer_key` now:

- requires an already-locked Test;
- preserves existing class-management authority;
- corrects the answer key;
- recalculates evaluated attempts;
- writes existing `test.answer_key_correct` audit history;
- **only if `results_visible=true` and at least one evaluated attempt was recalculated**, emits `test_results_corrected` to evaluated learner-side Accounts;
- notification payload contains only:
  - `test_id`
  - `class_id`
- notification body is generic:
  - title: `Test results updated`
  - body: `Results for a completed Test were updated after a correction.`
- answer text, selected choices, score, and correction reason are not copied into the notification.

The public `correct_answer_key` contract remains unchanged.

#### B. Notifications UI integration committed

Commit:

`f5b15919f2a742549c8a397081c04e570c50630a`

`apps/raahi-learning/live-product-fix-v13.js` now supports an **Open** button for `test_results_corrected`.

Open behavior:

- reads only `test_id` and `class_id` from notification payload;
- sets current Test/Class context;
- clears route-load cache;
- routes to existing `test-results`;
- the ordinary Test projection rechecks authorization.

Notification does not grant authority.

#### C. Test identities + protected audit inspector committed and deployed

Branch-head commit:

`8c68f057b27ae352a6fe5283c5534bd7f34b1113`

New DEV test suite:

`sidefx_test`

Personas:

- learner — `e2e.sidefxtest.learner@dev.learning.myraahi.co.in`
- teacher — `e2e.sidefxtest.teacher@dev.learning.myraahi.co.in`
- unrelated — `e2e.sidefxtest.unrelated@dev.learning.myraahi.co.in`

DEV Edge Function:

- `dev-test-identities`
- status: ACTIVE
- version: **15**
- custom GitHub OIDC protection remains in function body; `verify_jwt=false` is intentional for this custom OIDC boundary
- deployed function contains:
  - `sidefx_test`
  - `inspect_test_correction_audit`

The audit inspector:

- is restricted to suite `sidefx_test`;
- accepts Test question IDs;
- returns only `test.answer_key_correct` audit rows for those questions.

### NOT YET DONE

There is currently **no** committed:

- `tests/raahi-learning-e2e/test-correction-side-effects.mjs`
- `.github/workflows/raahi-learning-test-correction-side-effects.yml`
- SE-07 proof artifact/run
- SE-07 closure document
- doc-46 SE-07 PASS marking

Therefore **SE-07 is implemented but NOT PROVEN/CLOSED**.

Do not mark it PASS until the proof below succeeds.

## 7. Exact next implementation/test sequence

Start here.

### Scenario A — results already visible: correction MUST notify

Using genuine `sidefx_test` sessions:

1. bootstrap learner, teacher, unrelated Accounts;
2. enable teacher and create/publish a teaching option;
3. ensure learner self-profile;
4. create Enquiry → provider engage;
5. create/activate one-to-one Class → Invitation → learner acceptance;
6. teacher creates a Test;
7. add at least one question;
8. add at least two choices with an initial correct choice;
9. publish Test;
10. learner starts Test — this is important because first valid Attempt locks the definition;
11. learner answers using the original correct choice;
12. learner submits;
13. provider evaluates the attempt;
14. provider sets Test result visibility to `true`;
15. record baseline learner notifications;
16. provider calls `correct_answer_key` changing correctness to the other choice, with a distinctive private correction reason;
17. assert learner receives exactly **one** `test_results_corrected`;
18. assert payload has correct `test_id` + `class_id`;
19. assert notification contains **none** of:
    - answer text;
    - selected-choice text/ID if rendered as private explanation;
    - old/new score;
    - correction reason;
20. retry the exact same `correct_answer_key` idempotency key;
21. assert notification count remains one;
22. call protected `inspect_test_correction_audit`;
23. assert exactly one audit row for the corrected question;
24. assert teacher Account is the actor;
25. assert recalculation count is present/expected in governed audit metadata;
26. ordinary learner browser:
    - Notifications
    - click actual **Open** on `Test results updated`
    - land on `#/test-results`
    - authorized results projection loads;
27. unrelated Account:
    - receives no correction notification;
    - direct Test projection/attempt access remains denied.

### Scenario B — results hidden: correction MUST NOT notify

Use a second Test (simplest/clearest) with an evaluated attempt but keep `results_visible=false`.

1. create/publish/attempt/submit/evaluate second Test;
2. leave result visibility false;
3. correct its locked answer key;
4. assert correction succeeds and audit is written;
5. assert learner receives **zero** `test_results_corrected` for that second Test;
6. retry same idempotency key;
7. assert still zero notification and one audit row.

This proves the migration's visibility condition rather than only the happy path.

### Expected public RPC signatures

- `create_test(p_class_id uuid, p_title text, p_instructions text, p_available_from timestamptz, p_closes_at timestamptz, p_duration_seconds integer, p_idempotency_key text)`
- `add_test_question(p_test_id uuid, p_position integer, p_prompt text, p_points numeric, p_idempotency_key text)`
- `add_test_choice(p_question_id uuid, p_position integer, p_choice_text text, p_is_correct boolean, p_idempotency_key text)`
- `publish_test(p_test_id uuid, p_idempotency_key text)`
- `start_test(p_test_id uuid, p_learner_id uuid, p_idempotency_key text)`
- `save_test_answer(p_attempt_id uuid, p_question_id uuid, p_selected_choice_id uuid, p_text_response text, p_idempotency_key text)`
- `submit_test(p_attempt_id uuid, p_idempotency_key text)`
- `evaluate_test_attempt(p_attempt_id uuid, p_teacher_feedback text, p_idempotency_key text)`
- `set_test_results_visibility(p_test_id uuid, p_visible boolean, p_idempotency_key text)`
- `correct_answer_key(p_question_id uuid, p_correct_choice_id uuid, p_reason text, p_idempotency_key text)`
- `get_test_attempt(p_test_id uuid, p_learner_id uuid)`
- `get_test_definition(p_test_id uuid, p_learner_id uuid)`
- `get_test_oversight(p_test_id uuid, p_learner_id uuid)`
- `get_my_notifications(p_limit integer)`

Use the existing side-effect E2E scripts (Class/Activity) as coding patterns. Do not manually fabricate Auth tokens or disable RLS.

## 8. After SE-07 passes

Only then:

1. independently cross-check notification/audit/business rows in Supabase;
2. create SE-07 closure doc (next numeric doc after this handover is fine);
3. update doc 46 row:
   - `Correct released answer key` → PASS;
4. proceed to **SE-08 Organization authority changes**:
   - SE-08A capability change notification;
   - SE-08B member removal notification;
5. after SE-08, doc-46 implementation gaps should be closed;
6. run one new combined regression anchor;
7. then move to adversarial/recovery/race testing;
8. after that: reliability/security/load/provider-smoke/launch-readiness.

## 9. Frozen execution discipline

- PostgreSQL remains source of truth.
- UI expresses intent; canonical server commands own transitions.
- UI never directly mutates core operational tables.
- Realtime only invalidates/refetches.
- Notification failure must not roll back authoritative business transitions.
- Notification payload never grants authority.
- Deep-link/Open navigation must recheck current authorization.
- Private bodies/reasons/evidence do not enter ordinary notifications.
- Retry/idempotency must not duplicate attention signals or audit rows.
- Class/Learner/Test authority rules must not be weakened to satisfy a test.
- Every failure is classified first:
  - Domain
  - Integration
  - Implementation
  - Test-Harness
- Only Domain defects reopen frozen product design.

## 10. Browser/testing rule

Ordinary regression must remain autonomous:

`GitHub Actions / isolated Chromium → DEV-only genuine Supabase session → normal Raahi UI → canonical RPC/RLS → PostgreSQL`

Do not return to asking the product owner to sign into many Google browser profiles for ordinary regression.

Google OAuth and SMS/OTP remain small provider-specific smoke suites.

No DevTools/browser injection/localStorage hacks.

## 11. Recommended first commands/actions in next chat

1. Read:
   - this file;
   - `99-handover.md`;
   - `46-v1.3-side-effects-matrix-audit.md`;
   - `64-activity-submission-side-effect-closure-v1.3.md`;
   - migration 1030;
   - current `live-product-fix-v13.js`;
   - current `dev-test-identities/index.ts`.
2. Read-only verify:
   - branch head;
   - DEV `build-meta.json`;
   - migration 1030 present;
   - Edge Function version/content;
   - latest CI status, especially the previously-running 20-Persona Cohort.
3. Create SE-07 E2E runner + workflow.
4. Run it.
5. Classify failures before patching.
6. Do not begin SE-08 until SE-07 proof is green and documented.
