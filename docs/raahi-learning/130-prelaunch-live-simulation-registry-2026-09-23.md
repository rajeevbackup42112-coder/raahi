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