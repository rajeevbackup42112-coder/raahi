# Raahi Learning — Current Execution Handover: Pre-Launch Live Simulation Round 5

Date: 2026-09-25  
Repository: `rajeevbackup42112-coder/raahi`  
Branch: `raahi-learning-implementation-v1`  
Supabase DEV / controlled-pilot project: `iiwwmqokaeflaenhlyip`  
Public site: `https://learning.myraahi.co.in`  
Cloudflare Pages project: `raahi-learning-prod`

## Read this first

Continue from this document. Do **not** restart product planning, redesign Raahi Learning, recreate the database, or repeat already-proven flows from scratch.

Then read:

1. `docs/raahi-learning/130-prelaunch-live-simulation-registry-2026-09-23.md`
2. `docs/raahi-learning/129-current-execution-handover-first-teacher-closed-2026-09-23.md`
3. `docs/raahi-learning/120-first-use-intent-alignment-contract-v1.4k.md`
4. `docs/raahi-learning/121-human-language-alignment-contract-v1.4k.md`
5. `docs/raahi-learning/122-google-profile-confirmation-alignment-contract-v1.4k.md`
6. `docs/raahi-learning/123-teacher-onboarding-continuity-contract-v1.4k.md`
7. `docs/raahi-learning/124-learner-parent-institute-context-contract-v1.4k.md`

Use AI Builder Cheat Code discipline already established for this project: preserve business rules and invariants, prove through vertical slices, and do not introduce a second source of truth.

---

# 1. Exact source/deployment state at handover

## GitHub branch / implementation HEAD

The latest **implementation/code** commit is:

`dfbc89a445418a4a2115e194d7035b60bddbe671` — **Polish Platform audit and Ads context**

Two docs-only handover commits were added after it, so the branch tip after handover preparation is expected to be `aedfff48bb4e3cdbe874f59ffb123c2e38813bcb`. Do not mistake those documentation commits for a new product build.

Parent of the implementation commit:

`2f96efcd984b80ded0f65bc45434d24f49d12a9b` — **Avoid redundant Class thread refetch**

Recent sequence:

- `dfbc89a` — Polish Platform audit and Ads context
- `2f96efc` — Avoid redundant Class thread refetch
- `523c054` — Synchronize Class thread cache after send
- `cda012b` — Refresh Class thread after send
- `bbb93b3` — Show Class materials to authorized members
- `f122cba` — Add Teacher Test review flow
- `381ef86` — Expose private Class code to self Learners
- `142f9a2` — Add human Activity review flow
- `0a26696` — Fix Class learning card routing
- `fa8baf3` — Make setup replay deterministic
- `cce150f` — Harden early setup replay on slow runners
- `d0d7819` — Repair live simulation lifecycle blockers
- `9eef735` — Repair prelaunch live simulation flows

## Public production currently deployed

Verified from `https://learning.myraahi.co.in/build-meta.json` on 2026-09-25:

`2f96efcd984b80ded0f65bc45434d24f49d12a9b`

Release mode is `CONTROLLED_PILOT`, origin is `https://learning.myraahi.co.in`, project ref is `iiwwmqokaeflaenhlyip`.

Therefore:

- **Public is on 2f96efc.**
- **GitHub branch is one commit ahead on dfbc89a.**
- The Platform Audit / Ads presentation polish in `dfbc89a` is **not yet proven live** and should not be deployed until its browser qualification is green.

Do not accidentally roll public back behind `2f96efc`.

---

# 2. Latest CI state — this is the immediate gate

For branch HEAD `dfbc89a`:

- **Raahi Learning Model Tests #765** — PASS
- **Raahi Learning Onboarding Browser Contract #33** — FAIL

Failure is only in:

**Run Learner Parent Institute + context-switch browser proof**

Exact failure:

`PARENT_HOME_NOT_REACHED_iphone`

The iPhone Parent scenario stayed at:

`#/learner-add`

Body showed the normal Add Learner form. The contract timed out after 7 seconds waiting for Parent home. The captured RPC call list did **not** contain `create_learner`.

This resembles the earlier slow-runner/bootstrap submit race family, but do not label it flaky without reproducing it. The commit itself is presentation-focused, so first determine whether this is:

- a timing regression in early setup replay,
- a CI-only race,
- or a real regression exposed by the newest bundle.

### Immediate next action

**Do not deploy `dfbc89a` yet.**

First reproduce the exact `context-browser-contract.mjs` iPhone Parent journey on the current branch and make Browser Contract green again. If local sealed browser tests are green but GitHub remains red, add narrowly targeted diagnostics and rerun rather than weakening the assertion.

---

# 3. Remote computer state

Remote Desktop device used throughout:

`931e6073-983d-4a7c-92b6-71f04d7efe8c` — Dipti

Local repo:

`C:\Users\Dipti\Downloads\raahi-cutover-20260920`

E2E directory:

`C:\Users\Dipti\Downloads\raahi-cutover-20260920\tests\raahi-learning-e2e`

At the moment this handover was prepared, Remote Desktop Commander reported **no device available**. Therefore the current local working-tree status could not be re-read.

When the device reconnects, first run read-only:

`git status --short --branch`  
`git log -8 --oneline --decorate`

Do not blindly reset local work. Compare it to GitHub branch HEAD `dfbc89a` first.

Windows build PATH historically needs:

`C:\Windows\System32;C:\Program Files\Git\usr\bin`

---

# 4. Persistent live browser personas

Keep the isolated profiles and cookies. Do not mix identities.

| Browser | Account | CDP | Effective current purpose |
|---|---|---:|---|
| Raahi-01 | rajeev.backup1.2112@gmail.com | 9231 | Gomoh Local Manager |
| Raahi-02 | rajeev.backup2.2112@gmail.com | 9232 | Dhanbad Local Manager |
| Raahi-03 | rajeev.backup3.2112@gmail.com | 9233 | Self Learner + also manages test dependent |
| Raahi-04 | rajeev.backup4.2112@gmail.com | 9234 | Parent managing `Raahi Test Learner 04` |
| Raahi-05 | rajeev.backup5.2112@gmail.com | 9235 | Controlled Dhanbad Science Teacher test persona |
| Raahi-06 | rajeev.backup6.2112@gmail.com | 9236 | Institute candidate; do not create a fake public institute |
| Raahi-07 | mrrajeevsinha2112@gmail.com | 9237 | First genuine Gomoh Mathematics Teacher |
| Raahi-08 | choudhary.ajit2112@gmail.com | 9238 | Platform Admin |
| Raahi-09 | nareshkumar62922@gmail.com | 9239 | Explorer / no-authority canary |

Important correction to older registry wording: Raahi-05 is no longer merely a blank Teacher candidate. Controlled test state already gives it an active Science teaching surface and Class. Preserve that accumulated test state.

---

# 5. Live simulation state already proven

Do not redo these as if they were unknown. Reuse them for regression where useful.

## Discovery / Enquiry / messaging

- Parent 04 discovered Teacher 05 in Dhanbad and sent an Enquiry for `Raahi Test Learner 04`.
- Teacher 05 received and engaged the Enquiry.
- Enquiry messages persist and cross-persona visibility is proven.
- Duplicate active Enquiry now opens the existing relationship with human guidance instead of surfacing raw `DUPLICATE_ACTIVE_ENQUIRY`.
- Genuine Gomoh Teacher 07 remains visible with real Class 9–12 Mathematics tuition facts.

## Class lifecycle

Controlled Class:

`Raahi Test Science Class 05`

State: **active**

Current members include:

- `Raahi Test Learner 04`
- self Learner `Rajeev.backup3.2112`

Proven:

- draft Class activation
- private Learner code
- invitation
- acceptance/join
- Class post/update
- session scheduling
- Class membership visibility

## Activity lifecycle — fully closed

Activity:

`PRE-LAUNCH TEST: Water basics`

Proven end to end:

teacher publish  
→ learner submission  
→ teacher requests changes with feedback  
→ learner Revision 2  
→ teacher review  
→ reviewed state + feedback visible

The old raw JSON Teacher submission review was replaced with a human review surface using only canonical RPCs.

## Test lifecycle — fully closed

Test:

`PRE-LAUNCH TEST: Water quiz`

Proven:

teacher publish  
→ self Learner starts/saves/submits  
→ Teacher opens provider-safe Test review  
→ evaluates attempt  
→ explicit results release  
→ self Learner sees evaluated result and Teacher feedback

Backend proof recorded:

- attempt state `evaluated`
- score `1.00`
- results visible
- controlled Teacher feedback present

Guardian boundary was separately proven: Parent 04 sees oversight/status only; protected questions, answers and attempt-taking are not exposed.

## Class materials

Material:

`PRE-LAUNCH TEST: Water reference`

Teacher 05 created and linked it as a controlled external material.

A product gap was found because the backend returned Class materials but the normal Class page did not render them. Repair `bbb93b3` now renders authorized Class materials for Teacher and Learner/Parent views.

Live proof after deployment showed:

- Teacher Class page sees the material + description + Open link
- Parent Class page sees the same authorized material
- external links use `noopener noreferrer`
- governed file opening continues through the existing file path

## Contextual Class messaging

Teacher 05 and Parent 04 exchanged controlled Class-thread messages for `Raahi Test Learner 04`.

Initial defect: after send, the acting thread stayed stale until reload.

Repair sequence:

- `cda012b` immediate authoritative refetch
- `523c054` synchronize the deep-link helper cache with fresh thread data
- `2f96efc` avoid the redundant second refetch from the helper fallback

The public site is currently on this stabilized `2f96efc` state.

---

# 6. Round 5 Manager / Platform / Ads sweep

Dhanbad Local Manager 02 was exercised read-only across:

- Overview
- People
- Learning
- Reports
- Ads Review
- Location Settings
- Raahi Desk
- Founding Supply

Observed invariants held:

- operational scope remained Dhanbad
- People did not become a public Learner directory
- Founding Supply did not manufacture demand
- Raahi Desk clearly identifies Platform-authored content
- no synthetic activity was seeded

Platform Admin 08 exercised read-only:

- Platform Overview
- Safety
- Ads Ops
- Audit

Ads was also inspected without creating a fake campaign.

Two presentation issues were repaired in branch HEAD `dfbc89a`:

1. Platform Audit raw JSON rows were humanized into action/target/time summaries with technical details expandable.
2. Ads navigation no longer shows an Organization link when the Account has no Organization context.

These changes are committed but **not yet public** because Browser Contract #33 is red.

---

# 7. Product and safety invariants — do not weaken these

- No fake Teachers, fake learner demand, fake ratings, fake engagement or fake credentials in public.
- Controlled test entities must be clearly test-only.
- No public Learner directory.
- Operator never publishes a Teacher profile on the Teacher's behalf.
- Operator never invents Teacher facts.
- Google remains primary sign-in.
- Phone trust is a separate trust check, not a second login and not a capability grant.
- Preserve unique-phone ownership; never steal/move a phone between Auth users merely to pass a test.
- Account, capability and current context are separate.
- First-use intent guides setup; it never grants authority.
- One Account can legitimately have multiple contexts.
- Browser UI never directly mutates core operational tables.
- Consequential writes go through canonical RPCs.
- Realtime is invalidation/refetch only; PostgreSQL remains the source of truth.
- Location does not own identity/history.
- Exact sensitive action must survive OTP/phone-trust interruption and resume.
- Do not re-enable synthetic DEV writers.
- Do not recreate `.github/RAAHI_LEARNING_DEV_WRITES_ENABLED`.
- Never expose provider/API secrets.

---

# 8. Known remaining work

## Launch blocker now

Resolve Browser Contract #33 on `dfbc89a` before deployment.

## After green CI

Package and deploy `dfbc89a` as one batch:

1. reconstruct exact frontend
2. run focused + model + sealed browser qualification
3. prepare controlled-pilot release
4. deploy preview
5. verify preview build-meta and no direct table DML
6. deploy Cloudflare `main`
7. verify custom-domain build-meta equals exact commit
8. live check Platform Audit and Ads navigation with Raahi-08

## Continue live simulation after admin batch

Prioritize real user value / authority boundaries, not arbitrary screen coverage:

- verify current Class-thread immediate-refresh behavior from both Teacher and Parent browsers on public
- Learning Requests / Teaching Opportunities only when a genuine request exists; do **not** create fake demand just to make the page non-empty
- Institute flow only with a genuine institute or non-mutating UI inspection; do not publish a fake institute
- Local Manager / Platform / Safety negative-permission checks
- Community/report/block exact-target checks
- logout/login, reload, deep-link and double-submit recovery for the accumulated Class history
- then move toward controlled Gomoh supply/demand pilot with additional genuine Teachers and a small number of genuine learners/parents

---

# 9. CI commands / qualification

Focused repair suite:

`node --test tests\prelaunch-live-simulation-v14l.test.mjs`

Syntax:

`node --check apps\raahi-learning\live-product-fix-v13.js`

Sealed browser contracts from `tests\raahi-learning-e2e`:

`node onboarding-browser-contract.mjs`  
`node teacher-onboarding-browser-contract.mjs`  
`node context-browser-contract.mjs`

Expected historic contract counts:

- profile + intent: 15
- Teacher onboarding + phone resume: 4
- Learner / Parent / Institute / context switching: 8
- total: 27

Do not change the expected behavior simply to make CI green.

---

# 10. Release pattern

Set exact commit and branch:

`GITHUB_SHA=<exact HEAD>`  
`GITHUB_REF_NAME=raahi-learning-implementation-v1`

Build:

`node apps\raahi-learning\build-source-v13.mjs`

Release package:

- `RAAHI_RELEASE_MODE=CONTROLLED_PILOT`
- `RAAHI_RELEASE_CONFIRM_TARGET=CONTROLLED_PILOT_SAME_PROJECT`
- `RAAHI_RELEASE_PROJECT_REF=iiwwmqokaeflaenhlyip`
- `RAAHI_RELEASE_ORIGIN=https://learning.myraahi.co.in`
- `RAAHI_RELEASE_COMMIT=<exact HEAD>`
- set publishable key from the existing controlled-pilot source
- set a fresh output folder
- `node scripts\prepare-learning-release.mjs`

Deploy preview first with Wrangler, inspect, then deploy branch `main`.

Never deploy a different SHA than the one that passed qualification.

---

# 11. First genuine Teacher remains canonical founding-supply proof

Genuine Teacher account:

`mrrajeevsinha2112@gmail.com`

Public profile:

**Class 9–12 Mathematics Teacher**

Teaching option:

**Class 9–12 Mathematics Tuition**

Truthful facts supplied and reviewed by the Teacher:

- Class 9–12 Mathematics
- 10 years experience
- Home tuition + coaching in Gomoh
- ₹3000/month

This is the proof that assisted founding supply can close without operator impersonation or fabricated facts.

Do not reopen the first-Teacher debugging unless a regression specifically affects it.

---

# 12. Phone-trust history worth preserving

The first genuine Teacher hit a duplicate-phone conflict because the initially entered number already belonged to another Supabase Auth user.

Correct behavior:

- did not steal or move the existing phone
- diagnosed Auth phone uniqueness
- used a different number supplied by the human
- resumed the exact pending action after verification

StartMessaging duplicate-owner protection and human guidance are part of the current safety model. Do not bypass them.

---

# 13. Exact start prompt for the next chat

Use:

> Continue Raahi Learning from `docs/raahi-learning/131-current-execution-handover-prelaunch-live-simulation-round5-2026-09-25.md`. Repo `rajeevbackup42112-coder/raahi`, branch `raahi-learning-implementation-v1`, Supabase `iiwwmqokaeflaenhlyip`. First verify GitHub and public build-meta read-only. Public should currently be `2f96efcd984b80ded0f65bc45434d24f49d12a9b`. The latest product-code commit is `dfbc89a445418a4a2115e194d7035b60bddbe671`; docs-only handover commits follow it. Do not deploy `dfbc89a` until Browser Contract #33 is repaired/re-run green. The current failure is `PARENT_HOME_NOT_REACHED_iphone` in `context-browser-contract.mjs`. Remote Desktop device may need reconnecting; when available, inspect local git status before changing anything. Continue autonomously until genuine human credentials/OTP or a product decision is required.

---

# 14. Working style

Keep going autonomously. Do not stop for routine technical choices. Do not silently change frozen business rules.

When a contradiction appears, do impact analysis in this order:

rules → entities → relationships → states → permissions → UI → tests.

Prefer:

**test → evidence → narrow repair → automated regression → preview → one controlled deployment → repeat live journey**

over piecemeal production edits.

