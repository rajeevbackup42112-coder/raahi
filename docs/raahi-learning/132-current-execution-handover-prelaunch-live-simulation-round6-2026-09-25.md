# Raahi Learning — Current Execution Handover: Pre-Launch Live Simulation Round 6

Date: 2026-09-25  
Repository: `rajeevbackup42112-coder/raahi`  
Branch: `raahi-learning-implementation-v1`  
Supabase controlled-pilot project: `iiwwmqokaeflaenhlyip`  
Public site: `https://learning.myraahi.co.in`  
Cloudflare Pages project: `raahi-learning-prod`

## Read this first

Continue from this document. Do not restart product planning, recreate the database, repeat already-closed lifecycle slices, or manufacture public activity to make empty screens non-empty.

Then read:
1. `131-current-execution-handover-prelaunch-live-simulation-round5-2026-09-25.md`
2. `130-prelaunch-live-simulation-registry-2026-09-23.md`
3. `124-learner-parent-institute-context-contract-v1.4k.md`

Preserve AI Builder Cheat Code discipline, canonical RPC authority, PostgreSQL as source of truth, and Realtime as invalidation/refetch only.

---

# 1. Exact source and deployment state

Latest product-code commit:

`5d8ea741a4c782a3978f4d3c096024e3dbc0fead` — **Prevent duplicate Class message submits**

It is based on the Round-5 admin-polish commit `dfbc89a445418a4a2115e194d7035b60bddbe671` plus the docs-only handover commits that followed it.
The product-code sequence now includes:
- `5d8ea74` — Prevent duplicate Class message submits
- docs-only handover commits `d0479f2`, `a9f8d1c`, `aedfff4`, `8cad4c2`
- `dfbc89a` — Polish Platform audit and Ads context
- `2f96efc` — Avoid redundant Class thread refetch

The public custom domain is verified on exact product source:

`5d8ea741a4c782a3978f4d3c096024e3dbc0fead`

Public build metadata:
- release mode: `CONTROLLED_PILOT`
- origin: `https://learning.myraahi.co.in`
- project ref: `iiwwmqokaeflaenhlyip`
- remote artifact hash mismatches: **0**
- browser direct operational-table DML found: **none**
- privileged/service-role secret references found: **none**

Cloudflare deployment for the current product:
- production Pages URL: `https://cde839be.raahi-learning-prod.pages.dev`
- preview used before promotion: `https://8d8ef527.raahi-learning-prod.pages.dev`
- preview alias: `https://v14l-5d8ea74-preview.raahi-learning-prod.pages.dev`

Immediate prior product source `dfbc89a` was successfully deployed first and remains a known rollback source; the earlier stable public source `2f96efc` is also preserved in release history.

---

# 2. Browser Contract #33 closure and qualification

The original Browser Contract #33 failure on `dfbc89a` was:
`PARENT_HOME_NOT_REACHED_iphone`.

An unchanged rerun of the exact same commit passed:
- profile + intent: **15/15**
- Teacher onboarding + phone resume: **4/4**
- Learner / Parent / Institute / context switching: **8/8**
- total: **27/27**

No product behavior was weakened to make the contract green.
Local qualification of `dfbc89a` also passed:
- focused pre-launch regression: **18/18**
- model/property suite: **5,349,572 / 5,349,572**
- sealed browser contracts: **27/27**

The admin batch was then previewed, hash-verified, deployed and live-proven before Round 6 continued.

---

# 3. Round-5 admin fixes are live and proven

Platform Admin 08 live proof on the public site:
- Platform Audit renders human action / target / time summaries first.
- Technical identifiers and metadata remain under expandable **Technical details**.
- Live proof showed 45 audit cards and 45 Technical details expanders.
- Audit authority remains Platform-only.

Raahi Ads live proof on the same Account:
- navigation shows Campaigns, Create, Inventory and Analytics.
- Organization is absent when the Account has no Organization context.
- no fake campaign was created.

Dhanbad Local Manager 02 regression:
- role switcher exposes only Local operations.
- People explicitly says manager views are aggregate/operational and not a learner directory.
- direct Platform and Safety deep links are denied.

Explorer / no-authority canary 09 regression:
- direct Teacher, Institute, Manager, Platform and Ads deep links are denied.
- Learning Profiles remains a legitimate path to create a learner relationship, but no learner/capability/admin authority is pre-granted.

---

# 4. Class-thread immediate refresh remains green

Existing controlled Class:
`Raahi Test Science Class 05`

Class ID:
`db84dddf-a7db-4fc0-8ec9-dbf7bdcdbd72`

Managed learner:
`Raahi Test Learner 04`

Learner ID:
`301e33c7-863c-4c90-be51-9f90b15836cc`

On public `dfbc89a`:
- Teacher 05 sent one controlled Class message.
- the new message appeared immediately.
- exactly one `send_class_learner_message` RPC occurred.
- exactly one authoritative `get_class_learner_thread` refetch occurred.
Parent 04 repeated the same proof:
- one send
- one thread refetch
- immediate visibility

A full reload/deep-link recovery check from both Teacher and Parent preserved accumulated Class-thread history and restored the message composer.

---

# 5. Round-6 defect found: duplicate Class-message double submit

A controlled live double-click test on `dfbc89a` exposed a real launch defect.

Two synchronous clicks on **Send message** produced:
- 2 `send_class_learner_message` RPCs
- 2 different generated idempotency keys
- 2 authoritative thread refetches
- 2 visible duplicate messages

Root cause:
- the browser generated a new idempotency key for every click;
- the Class-message action had no in-flight UI command lock.

The backend authority model was not the problem.

## Narrow repair

The Class-message UI command now:
- ignores a second click while the current send is in flight;
- marks the button busy and disables it before the canonical RPC;
- performs the existing canonical send and authoritative refetch;
- clears the busy state in `finally` if the original button remains connected.

No database rule, authorization rule, RPC contract, or message semantics changed.

Focused regression now explicitly asserts the in-flight lock.

---

# 6. Exact repair qualification

Final repair source:
`5d8ea741a4c782a3978f4d3c096024e3dbc0fead`

Local:
- syntax: clean
- focused pre-launch regression: **18/18**
- model/property suite: **5,349,572 cases, 0 failures**
- sealed browser chain: **27/27**

Real local-candidate proof used the isolated Teacher 05 authenticated session against the real controlled-pilot backend:
- two immediate clicks
- **1 send**
- **1 thread refetch**
- **1 visible message**

GitHub:
- Raahi Learning Model Tests **#770** — PASS
- Raahi Learning Onboarding Browser Contract **#34** — PASS on first attempt
- browser counts: **15 + 4 + 8 = 27/27**

The repair was then packaged, previewed, hash-verified, and promoted unchanged to Cloudflare `main`.
Production double-submit proof on Teacher 05:
- two immediate clicks
- **1 send**
- **1 thread refetch**
- **1 visible message**

Production double-submit proof on Parent 04:
- two immediate clicks
- **1 send**
- **1 thread refetch**
- **1 visible message**

Therefore the duplicate Class-message defect is closed live.

---

# 7. Recovery checks closed in this round

Reload + deep link:
- Teacher Class thread restored correctly.
- Parent Class thread restored correctly.
- accumulated history remained visible.
- composer remained usable.

Logout + Google login:
- isolated Explorer 09 was signed out through the normal Settings action.
- Welcome rendered with **Continue with Google**.
- the browser's existing Google session completed normal sign-in without password/OTP intervention.
- the same canary returned to authenticated Dhanbad Home.

No Teacher or Parent production session was sacrificed for this proof.

---

# 8. Genuine-target gates intentionally not fabricated

Teacher 05 Teaching Opportunities in Dhanbad:
- **No current opportunities**
- no public Learning Requests currently match the Location.

Platform Safety:
- **0 open reports**
- **0 live sponsored placements**
- **0 submitted campaigns**

Gomoh Community from Self Learner 03:
- no existing posts
- UI says **Start the conversation in Gomoh**

Therefore report-resolution, block-exact-target and community-target mutation proofs were not manufactured. Revisit them only when a genuine or already-authorized controlled target exists.

Raahi-06 already has the clearly controlled test context `Raahi Test Institute 06`; it was inspected read-only and no new public institute was created.
---

# 9. Product and safety invariants — keep these unchanged

- No fake Teachers, fake learner demand, fake ratings, fake engagement or fake credentials in public.
- Controlled test entities must remain clearly test-only.
- No public or manager-browseable Learner directory.
- Operator never publishes a Teacher profile on the Teacher's behalf.
- Operator never invents Teacher facts.
- Google remains primary sign-in.
- Phone trust is a separate trust check, not a role/capability grant.
- Preserve unique-phone ownership; never steal/move a phone merely to pass a test.
- Account, capability and current context remain separate.
- Context switching never creates authority.
- Browser UI never directly mutates core operational tables.
- Consequential writes use canonical RPCs.
- Realtime is invalidation/refetch only; PostgreSQL remains authoritative.
- Location does not own identity/history.
- Exact sensitive action must survive phone-trust interruption and resume.
- Do not recreate `.github/RAAHI_LEARNING_DEV_WRITES_ENABLED`.
- Never expose provider/API secrets.

---

# 10. Persistent browser personas

Keep the existing isolated profiles/cookies:
- Raahi-01 / 9231 — Gomoh Local Manager
- Raahi-02 / 9232 — Dhanbad Local Manager
- Raahi-03 / 9233 — Self Learner + manages controlled dependent
- Raahi-04 / 9234 — Parent managing `Raahi Test Learner 04`
- Raahi-05 / 9235 — controlled Dhanbad Science Teacher
- Raahi-06 / 9236 — controlled test Institute context
- Raahi-07 / 9237 — genuine Gomoh Mathematics Teacher
- Raahi-08 / 9238 — Platform Admin
- Raahi-09 / 9239 — Explorer / no-authority canary

---

# 11. What remains

The technical Round-5/6 gates are closed.

Do not create synthetic demand or community activity just to continue testing.

Next useful work should be driven by real pilot value:
1. onboard additional genuine Gomoh Teachers only from facts they provide;
2. admit a small number of genuine learners/parents;
3. exercise genuine discovery → enquiry → Class journeys as real demand appears;
4. when a genuine Community/report target exists, run exact-target report/block recovery checks;
5. continue permission, reload, deep-link and double-submit regression while history accumulates.

If a new product defect is found, follow:
**test → evidence → narrow repair → automated regression → preview → exact deployment → repeat live journey**.

---

# 12. Exact start prompt for the next chat

> Continue Raahi Learning from `docs/raahi-learning/132-current-execution-handover-prelaunch-live-simulation-round6-2026-09-25.md`. Repo `rajeevbackup42112-coder/raahi`, branch `raahi-learning-implementation-v1`, Supabase `iiwwmqokaeflaenhlyip`. First verify GitHub product-code HEAD and public `build-meta.json` read-only. Public should be exact product source `5d8ea741a4c782a3978f4d3c096024e3dbc0fead`. Round 6 closed the duplicate Class-message double-submit defect: production Teacher and Parent double-click proofs both produced one send, one authoritative refetch and one visible message. CI Model Tests #770 and Browser Contract #34 are green; sealed browser count is 27/27. Do not manufacture Learning Requests, Community posts, reports, ads or public institutes. Continue with genuine pilot value and permission/recovery regression until human credentials/OTP or a product decision is genuinely required.

---

# 13. Working style

Continue autonomously for routine technical choices. Do not silently change frozen business rules.

When a contradiction appears, impact-analyze:
rules → entities → relationships → states → permissions → UI → tests.

Prefer exact evidence and reversible, narrow repairs over broad redesign.
