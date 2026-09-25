# Raahi Learning — Pre-Launch Live Simulation Registry

Date: 2026-09-23
Environment: https://learning.myraahi.co.in
Purpose: controlled production-like testing before public promotion. These accounts are test personas using real Google sign-in. Public promotion has not started.

## Persistent browser personas

| Browser | Google account | Current test persona | Persistent CDP port | Current authority/state |
|---|---|---|---:|---|
| Raahi-01 | rajeev.backup1.2112@gmail.com | Local Manager — Gomoh | 9231 | local_manager scope for Gomoh |
| Raahi-02 | rajeev.backup2.2112@gmail.com | Local Manager — Dhanbad | 9232 | local_manager scope for Dhanbad |
| Raahi-03 | rajeev.backup3.2112@gmail.com | Self Learner | 9233 | one self Learner identity |
| Raahi-04 | rajeev.backup4.2112@gmail.com | Parent | 9234 | manages `Raahi Test Learner 04` |
| Raahi-05 | rajeev.backup5.2112@gmail.com | Self-service Teacher candidate | 9235 | parked at phone-trust gate |
| Raahi-06 | rajeev.backup6.2112@gmail.com | Institute candidate | 9236 | setup reached phone-trust requirement |
| Raahi-07 | mrrajeevsinha2112@gmail.com | Proven Teacher — Gomoh | 9237 | teach capability; public profile; one teaching option |
| Raahi-08 | choudhary.ajit2112@gmail.com | Platform Admin | 9238 | platform_admin capability |
| Raahi-09 | nareshkumar62922@gmail.com | Explorer / no-authority canary | 9239 | first-use Explore completed; no learner/capability/org/manager scope |

## Live-simulation rules

- Preserve each browser profile and its cookies/session; do not mix Google identities.
- Test through the real website wherever practical; use backend inspection only to verify outcomes or prepare clearly controlled test state.
- Test personas may use clearly designated test data. Do not confuse seeded/bypassed phone-trust state with evidence that the real SMS provider worked.
- Real OTP/provider proof remains a separate canary path.
- Let state accumulate across rounds instead of resetting after every scenario.
- Exercise permitted actions and forbidden actions repeatedly, including refresh, logout/login, deep-link, double-submit and context-switch cases.

## Defect candidates discovered during persona setup

1. `Raahi-04` Parent: Add Learner succeeded in backend/context, but the screen remained on Add Learner until reload before showing Parent home. Reproduce before classifying severity.
2. `Raahi-06` Institute: Create Institute correctly hit phone-trust protection but surfaced raw `PHONE_TRUST_REQUIRED` on the form instead of transferring into the phone-check/resume flow. This is a confirmed UX/continuity defect candidate.
3. `Raahi-09` Explorer: internal UI role projection reports `learner` while the account has no Learner identity, capability, organization or manager scope. Treat as an authority-canary observation; verify that it cannot perform Learner-only actions before deciding whether this is merely presentation/default-role behavior or a defect.

## Next execution loop

Round 1: verify every persona's home/context, navigation and permission boundaries.
Round 2: perform real cross-persona learning flow: Learner/Parent -> discovery -> Teacher -> enquiry/conversation -> Class -> learning activity.
Round 3: complete Teacher and Institute test personas with controlled phone-trust state, while keeping real OTP testing separate.
Round 4+: repeat with accumulated history and edge/recovery scenarios until no unresolved launch-blocking defects remain.

## Round 1 baseline observations

All nine isolated browser profiles are now authenticated and persistent. A first navigation sweep covered Home/Explore/Classes/Community/Messages/Settings for Self Learner, Parent, Teacher and Explorer personas without crashes.

Additional observation: a Gomoh Local Manager can use the general Location picker to select Dhanbad. The manager dashboard label then says `Dhanbad Overview`, but its operational counts remain the Gomoh manager-scope data (1 learning option), while the genuine Dhanbad Local Manager sees 0 learning options. This currently looks like a context/label mismatch rather than proven cross-location data leakage: backend projection appears to remain manager-scope constrained while the UI Location label follows the user's general selected Location. Treat as a launch defect until the manager/location model is made unambiguous.

Reload persistence also worked across the test personas. Authorized context is asynchronous on reload; the Gomoh manager showed the loading shell for several seconds before restoring the correct manager context. Record as performance/UX observation, not yet a functional defect.

## Round 2 cross-persona findings

- `Raahi-03` successfully added `Raahi Test Dependent 03` while retaining its self Learner identity. The same Account now exercises self-Learner + Parent context switching. The earlier `Raahi-04` add-Learner stale-screen observation did not reproduce on this second path, so keep it as a transient/timing candidate rather than a confirmed defect.
- `Raahi-04` Parent successfully discovered `Raahi-05` in Dhanbad and sent an Enquiry as `Raahi Test Learner 04`.
- `Raahi-05` is not blank: controlled test data already gives it a visible Science Teacher profile, one Science teaching option, an active teach capability, and `Raahi Test Science Class 05` in draft state. Preserve this as controlled test state.
- Teacher/Parent Enquiry messaging persists correctly, but the acting thread and the other browser's Messages preview can remain stale until reload. The authoritative message appears after reload. V1.4L repair refetches the sender thread immediately and uses low-risk Realtime invalidation surfaces for the other browser.
- `Raahi-03` discovered the genuine Gomoh Teacher `Raahi-07` and opened its existing active Mathematics Enquiry. Attempting the same Enquiry again surfaced raw `DUPLICATE_ACTIVE_ENQUIRY`. V1.4L repair now detects that condition, finds the existing active relationship for the same Learner + Teaching Option, and opens it with human guidance.
- `Raahi-06` Institute creation phone-trust continuity remains confirmed: current public build surfaces raw `PHONE_TRUST_REQUIRED`. V1.4L routes `create_organization` through the same resumable sensitive-action mechanism used by Teacher onboarding.
- `Raahi-05` draft Class had no visible activation path in the current public build. V1.4L adds the canonical `activate_class` action to draft Class management and refetches authoritative Class state.

## V1.4L repair qualification

- Backend model/property suite: 5,349,572 generated checks, 0 failures.
- Node regression suite: 127 tests passed, 0 failed.
- `node --check` and `git diff --check` are clean.
- Applied Supabase migration version is `20260923134900_v14l_realtime_invalidation_publication`; source file is aligned to that version.
- No direct browser table mutation, service-role key, provider secret, or weakened phone-trust rule was introduced.
- GitHub Browser Contract #21 exposed a genuine fast-load race: the async base bootstrap could paint and submit Institute setup before `live-product-fix-v13.js` had registered its early-submit guard. The reconstructed build and controlled-pilot release package now load the product-fix script before the live bootstrap can paint setup forms. The context browser contract then passed five consecutive local runs; both build and release ordering are regression-tested.

## Round 2 cross-persona evidence

- Raahi-04 Parent successfully discovers the controlled Dhanbad Teacher listing and opens the existing Enquiry for `Raahi Test Learner 04`.
- Raahi-05 Teacher receives the relationship in Messages, opens the Enquiry thread, and can send a reply through the canonical message path.
- Raahi-04 sees the Teacher reply after authoritative refresh. Realtime presentation is still treated as invalidation/refetch, not as authority.
- Raahi-03 Self Learner discovers the genuine Gomoh Mathematics Teacher and existing active Enquiry. A second send on the currently deployed build surfaced raw `DUPLICATE_ACTIVE_ENQUIRY`; the repair candidate opens the existing Enquiry with human guidance instead.
- Raahi-04 generated a one-time private Learner code. Raahi-05 attempted to invite that Learner to `Raahi Test Science Class 05`.
- The invitation was correctly rejected because the Class is still `draft`, but the currently deployed UI has no activation action and surfaced raw `CLASS_NOT_ACTIVE`. This blocks the Class lifecycle in the live simulation.
- Repair candidate adds a canonical `activate_class` action for a draft Teacher Class, then refetches authoritative Class management state.
- Repair candidate also clears cached route loads after Learner creation, addresses Institute phone-trust continuation, fixes Local Manager operational Location labeling, and refreshes Enquiry/Class views after mutations.

## Repair qualification before deployment

- Backend-free model/property suite: 5,349,572 generated cases, 0 failures.
- Focused and release regression suite: 129 Node tests, 129 passed.
- Sealed browser contract: 15 profile/intent checks + 4 Teacher/phone-resume checks + 8 Learner/Parent/Institute/context checks = 27 passed.
- No repair adds direct browser operational-table DML or privileged secrets.

Next gate: commit/push the qualified repair candidate, let GitHub qualification run, deploy one batch, then repeat the exact cross-persona journey from draft Class activation through private invitation and Learner join.
### CI bootstrap race hardening

GitHub Browser Contract #23 exposed a slower-runner-only Parent setup race: the early-submit replay expired after ~1 second before the canonical product-fix handlers were fully ready. The repair now waits on an explicit `__productFixV13Ready` signal and retains the captured form values for up to 10 seconds. Local sealed browser qualification remains 27/27 green after the change.
Browser Contract #24 moved the slow-runner failure from Parent setup to Institute setup, confirming the issue was the generic early-submit replay rather than a Parent-specific flow. The replay now waits for the fully rendered canonical handler set and replays through the live submit button (with requestSubmit fallback), preserving captured values.
## Round 2 continuation — Class learning surface

- The repaired build was exercised live through Class activation, private Learner invitation, learner join, Class update and session scheduling.
- `Raahi Test Learner 04` is now an active member of `Raahi Test Science Class 05`.
- Teacher 05 published the controlled Class update `PRE-LAUNCH TEST: Welcome to the Science class.` and scheduled the controlled in-person session for 24 Sept 2026, 18:00–19:00.
- Teacher 05 created and published the controlled Activity `PRE-LAUNCH TEST: Water basics`.
- Parent/Learner Class view received the session, Class update and Activity after authoritative refresh.
- New defect found: clicking the Activity card navigated to `#/activity` before copying `activity_id` into live selected state, so the detail page said `No Activity selected`. The same ordering defect also applied to Test cards.
- Repair candidate now captures Activity/Test cards first, stores the server-projected identifier, clears route-load cache and only then opens the detail route.
- Local qualification after this repair: focused V1.4L tests 11/11 green; sealed browser contract remains 15 + 4 + 8 = 27/27 green.

Next: push/qualify this small navigation repair, publish one batch, then continue the same Class journey with Activity submission, Teacher review/feedback and Test lifecycle.
## Round 2 continuation — Activity review

- After the Activity-card routing repair went live, Parent 04 opened `PRE-LAUNCH TEST: Water basics` correctly and submitted a controlled text response for `Raahi Test Learner 04`.
- Teacher 05 received the private `Activity submission received` notification and the notification deep link correctly selected the Class, Learner and Activity.
- New launch defect found at the review destination: the Teacher saw raw submission JSON and no review actions, even though canonical server RPCs `review_submission` and `request_submission_changes` already exist.
- Repair candidate replaces the raw JSON surface with a human submission-review page, shows the latest learner response, supports optional file opening, requires feedback when requesting changes, and calls only the canonical review RPCs.
- After either review action, the browser refetches authoritative account state and `get_activity_detail`; no direct operational-table DML is added.
- Focused V1.4L regression is now 12/12 green.

Next gate: push/qualify/deploy the review UI repair, then exercise request-changes -> Learner revision -> Teacher reviewed end to end before moving into Tests.
## Round 2 continuation — revision loop closed

- Teacher 05 requested changes on the controlled Activity submission with specific feedback.
- Parent 04 received `Activity changes requested`, opened the Activity, saw the Teacher feedback, revised the response and submitted Revision 2.
- Teacher 05 opened the latest authorized submission, saw Revision 2, added feedback and marked it reviewed.
- This proves the Activity loop end to end: publish -> learner submit -> teacher changes requested -> learner revision -> teacher reviewed.
- While preparing the next Test proof, a role-surface gap was found: the backend permits any account that can make the learning decision (including a self Learner) to create the private Class code, but the current Learning profiles UI only exposes that button for managed Learners.
- Repair candidate exposes `Private Class code` for self Learners as well, without changing authorization; the canonical RPC remains the authority.
- Focused V1.4L regression is now 13/13 green.

Next: qualify/deploy this small self-Learner UI repair, add Self Learner 03 to the controlled Test Class, and exercise the Test lifecycle with guardian oversight kept separate.
## Round 3 — Test lifecycle entry

- Self Learner 03 received and accepted a private invitation into `Raahi Test Science Class 05` using the newly exposed self-Learner private Class code. Relationship visibility remained independent of selected Location.
- Teacher 05 created `PRE-LAUNCH TEST: Water quiz` with one controlled multiple-choice question.
- Parent 04 opened the Test as guardian and correctly saw oversight only: status metadata was visible, while protected questions/answers and attempt-taking remained hidden.
- Self Learner 03 opened the same Test, started it, saved an answer and submitted the attempt successfully.
- New launch gap found: the Teacher Class UI had no way to open learner Test attempts for evaluation/release, even though provider-safe projections and canonical `evaluate_test_attempt` / `set_test_results_visibility` RPCs already exist.
- Repair candidate adds a Teacher-only `Test review` section, fetches the selected learner attempt through safe projections, displays human review state, evaluates through the canonical RPC, and releases results explicitly through the canonical visibility RPC.
- Local qualification: focused V1.4L regression 14/14 green; sealed browser contract 27/27 green.

Next: push/qualify/deploy the Test review repair and complete submitted -> evaluated -> result released -> self Learner result proof.
## Round 3 — Test lifecycle closed; Class materials gap found

- Teacher 05 evaluated Self Learner 03's submitted `PRE-LAUNCH TEST: Water quiz` attempt, recorded controlled feedback, and explicitly released results.
- Backend state confirms the attempt is `evaluated`, score `1.00`, with results visible.
- Self Learner 03 reopened the Test and saw only the released result: evaluated, score 1, and Teacher feedback.
- Parent 04 opened the same Test for its managed Learner and saw guardian oversight only; protected questions, answers and attempt-taking were not exposed.
- This closes the Test proof: publish -> self learner start/save/submit -> teacher evaluate -> explicit result release -> self learner result visibility, while guardian permissions remain separate.
- Teacher 05 then created and linked `PRE-LAUNCH TEST: Water reference` as Class material. The authoritative `get_class_learning_overview` projection returned Class materials, but neither Teacher nor Learner Class detail rendered them. This made a successfully linked resource unreachable in normal Class use.
- Repair candidate renders authorized Class materials on Teacher and Learner Class detail, supports governed files through the existing file action, and external links with `noopener noreferrer`. No new authority is introduced.
- Focused V1.4L regression is now 15/15 green; local sealed browser contracts complete successfully.

Next gate: push/qualify/deploy the Class materials visibility repair, prove the material from both Teacher and Learner browsers, then continue with contextual Class messaging and remaining actor workspaces.
## Round 4 — Class materials proven; contextual messaging defect

- The Class material visibility repair was qualified in GitHub (Model Tests #761 and Browser Contract #30) and deployed to the controlled public site at source `bbb93b3d3a60c214547c4b3f5f371976cc4b16f8`.
- Teacher 05 and Parent 04 both opened `Raahi Test Science Class 05` and saw `PRE-LAUNCH TEST: Water reference`, its description and the authorized `Open link` action. The material is now reachable from ordinary Class use.
- Teacher 05 then sent a controlled private Class message to `Raahi Test Learner 04`; Parent 04 received it and replied. Reloading the Teacher thread showed both messages, proving the canonical relationship/message write path.
- New UX defect found: after either participant sends a Class message, the current thread remains stale until a later navigation/reload even though the write succeeds.
- Repair candidate captures the existing Class-message action, calls only canonical `send_class_learner_message`, immediately refetches `get_class_learner_thread`, and renders authoritative state. No message payload table is exposed to Realtime or directly mutated by the browser.
- Focused V1.4L regression is now 16/16 green; sealed browser contracts complete successfully.

Next gate: qualify/deploy the immediate Class-thread refresh repair, re-run both directions, then move to learning requests/opportunities and the Institute/Manager/Admin actor workspaces.
### Class-thread refresh cache hardening

The first immediate-refresh repair correctly refetched `get_class_learner_thread`, but the dedicated thread deep-link helper still owned its own private load cache. A direct assignment to `live.data.classThread` could therefore be overwritten by the helper's stale cached value during the same render cycle. The repair now exposes a narrow `__setClassThreadDataV13(classId, learnerId, data)` synchronization seam that updates both the helper cache and `live.data.classThread` from the freshly refetched authoritative projection. This does not add a second source of truth; PostgreSQL/RPC output remains authoritative. Focused regression remains 16/16 green and sealed browser contracts remain green.