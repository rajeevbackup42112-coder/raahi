# Raahi Learning — Current Execution Handover: Live Acceptance → Targeted Improvements

Date: 2026-10-01

## Start here

This is the canonical continuation document for the current Raahi Learning work.

Repository:
`rajeevbackup42112-coder/raahi`

Branch:
`raahi-learning-implementation-v1`

Local repo on Dipti:
`C:\Users\Dipti\Downloads\raahi-cutover-20260920`

Supabase controlled pilot:
`iiwwmqokaeflaenhlyip`

Public:
`https://learning.myraahi.co.in`

Remote Desktop device:
- name: `Dipti`
- device ID: `931e6073-983d-4a7c-92b6-71f04d7efe8c`

## Exact SHA separation

Current branch product-code HEAD:
`bf65527b0d4379e1d2467b32d4817d1b44e0948e` — **Clarify learner workspaces and active context**

Current public production remains:
`7d99b69165df0de0ca02e7778fde995b302ff624` — **Close final mobile audit disclosure target**

Do not confuse the branch tip with the deployed product. The improvement work after the frozen live-acceptance baseline is intentionally undeployed.

The branch also contains MyRaahi location/SSO handoff work between the frozen public release and the current improvement commits. Do not deploy the branch casually. Promotion must follow exact-SHA qualification, preview, affected-persona replay, and final short nine-persona regression.

## User's requested end goal

The user explicitly asked for a real-user study using the nine already-authenticated Gmail browser profiles:

- touch only the browser during the study;
- behave like real users with realistic scenarios;
- inspect every visited screen top-to-bottom;
- inspect browser-visible backend behaviour through network/console/loading/realtime only;
- document required improvements;
- only after the study, separately implement the improvements and plan next steps.

The browser-only study is now complete and frozen. The current phase is the **separate improvement phase**.

End goal:
1. resolve the demonstrated P1/P2 findings in small controlled slices;
2. preserve all business/security invariants;
3. qualify every exact product SHA;
4. replay affected real personas;
5. run a short final nine-persona live regression;
6. gate controlled TEST ONLY supply before broad investor/general public showcase;
7. deploy only the exact previewed and qualified artifact;
8. update the final release handover separately.

Do not restart broad speculative redesign.

## Frozen live acceptance study

Artifact root:
`tests/raahi-learning-e2e/artifacts-live-user-acceptance-2026-09-28/`

Read these in order:
1. `01-scenario-book.md`
2. `02-screen-coverage-register.md`
3. `04-final-live-user-acceptance-report.md`
4. `06-consolidated-acceptance-findings-and-plan.md`
5. `05-improvement-execution-plan.md`

Important: earlier improvement-register files are historical/provisional. Use `06-consolidated-acceptance-findings-and-plan.md` as the canonical synthesis because it reconciles visual, semantic/accessibility, browser-network and controlled-interaction evidence.

Final acceptance coverage:
- 9 authenticated personas
- 14 effective role contexts
- 104 paired scenario states
- 208 matched desktop/mobile renderings
- 6 additional semantic/accessibility states
- 214 inspected live views/states
- private Enquiry send proof
- private Class-message send proof
- notification read-state proof
- P08 privileged network sweep

Across the accepted navigation journeys:
- no horizontal overflow;
- no app-side console/page errors;
- no failed browser requests;
- no HTTP >=400 responses;
- no privileged controls exposed to ordinary Explorer P09;
- no Account/learner/role history loss.

Controlled actions also passed:
- P04 → P05 Enquiry message appeared exactly once;
- P05 → P04 Class message used canonical send + authoritative thread refetch and appeared exactly once;
- notification mark-read mutated once and visibly updated unread state.

No fake public teacher/student demand, ratings, engagement, credentials, campaigns, institutes or community content were created by the study.

## Persistent nine personas

Ports / identities:
- Raahi-01 — port 9231 — `rajeev.backup1.2112@gmail.com` — Gomoh Local Manager
- Raahi-02 — port 9232 — `rajeev.backup2.2112@gmail.com` — Dhanbad Local Manager
- Raahi-03 — port 9233 — `rajeev.backup3.2112@gmail.com` — self learner + managed dependent + Parent contexts
- Raahi-04 — port 9234 — `rajeev.backup4.2112@gmail.com` — Parent managing `Raahi Test Learner 04`
- Raahi-05 — port 9235 — `rajeev.backup5.2112@gmail.com` — controlled Dhanbad Science Teacher
- Raahi-06 — port 9236 — `rajeev.backup6.2112@gmail.com` — controlled Institute + Ads
- Raahi-07 — port 9237 — `mrrajeevsinha2112@gmail.com` — genuine Gomoh Mathematics Teacher
- Raahi-08 — port 9238 — `choudhary.ajit2112@gmail.com` — Dhanbad Local operations + Platform Admin + Ads
- Raahi-09 — port 9239 — `nareshkumar62922@gmail.com` — ordinary Explorer / no-authority canary

Raahi-01 may require `localhost:9231` rather than `127.0.0.1:9231`.

Raahi-08 has intermittent Playwright browser-level CDP handshake timeouts. Its raw page CDP endpoint is reliable and was used successfully for the final acceptance and post-deploy checks.

## Canonical remaining findings and execution order

Canonical source:
`06-consolidated-acceptance-findings-and-plan.md`

### Slice A — semantic interactive cards — DONE

Original P1:
core clickable cards were `DIV.card.clickable` without link/button semantics, tabindex, accessible role/name or keyboard activation.

Implemented product commit:
`7b896fe618bd94948fdd21421bc3c4793b67083d` — **Make core navigation cards keyboard accessible**

Touched:
- `apps/raahi-learning/delight-v14.css`
- `apps/raahi-learning/delight-v14.js`
- `tests/delight-v14.test.mjs`

Independent CI:
- Model Tests #806 — success
- Browser Contract #52 — success

Do not redo this slice unless a replay proves regression.

### Slice B — active learner context clarity — DONE

Original P1:
P03 can act for self learner and managed dependent, while consequential actions did not make the active learner sufficiently explicit. Duplicate visible “My learning” contexts added ambiguity.

Implemented product commit:
`bf65527b0d4379e1d2467b32d4817d1b44e0948e` — **Clarify learner workspaces and active context**

Touched:
- `apps/raahi-learning/delight-v14.css`
- `apps/raahi-learning/delight-v14.js`
- `apps/raahi-learning/live-product-fix-v13.js`
- `tests/delight-v14.test.mjs`
- `tests/prelaunch-live-simulation-v14l.test.mjs`
- `tests/raahi-learning-e2e/context-browser-contract.mjs`

Independent CI:
- Model Tests #807 — success
- Browser Contract #53 — success

Local replay evidence exists under:
`tests/raahi-learning-e2e/artifacts-live-user-acceptance-2026-09-28/slice-b-local-replay/`

Do not redo this slice unless replay evidence shows a regression.

### Slice C — Institute identity ambiguity — NEXT

This is the immediate next task.

P06 exposes two distinct organization IDs with the same visible name:
- `251ad6fe-4b3b-4ade-84bf-5cad13cf2880`
- `5c970182-38e1-42ff-a9a0-58a48d317e1a`

Both render as:
`Raahi Test Institute 06`

This affects:
- organization context controls;
- Ads Create advertiser choices.

Required first action: **read-only root-cause analysis**.

Determine:
1. whether these are truly two Organization records for one logical Institute;
2. whether one Organization is surfaced twice through memberships/context rows;
3. which record owns Institute profile/member/Class/Ads relationships;
4. whether either is historical/test residue;
5. whether merge/archive could lose history or permissions.

Do not merge, delete, archive or alter organization data until ownership/history is proven.

Preferred resolution:
- if duplicate data: define and execute a safe reconciliation plan only after impact analysis;
- if both are legitimate same-name organizations: keep both records and add a stable human disambiguator such as Location + organization type/branch.

Replay after fix:
P06 Institute Home → context selector → Ads → Create.

## Remaining P2/P3 slices after Slice C

### Slice D — centralized human display normalization

Fix:
- raw enums: `in_person`, `one_to_one`, `group`;
- lowercase/internal status labels;
- Teacher Messages learner-oriented subtitle;
- Teacher notification “learner-side message” terminology;
- selected learning Location vs teaching Location explanation;
- Institute Classes learner-centric empty-state copy;
- raw UTC/ISO-like scheduled-event copy.

Use presentation mappings only. Do not mutate stored backend enum values.

Replay:
P03/P04/P05/P06/P07/P09.

### Slice E — notification scale + browser refresh efficiency

Presentation:
- reduce repeated conversation/Class notification noise;
- grouping / deterministic category filters if useful;
- consider Mark all read only with safe canonical semantics;
- never discard authoritative notification events.

Network:
- narrow post-mutation invalidation/refetch;
- remove duplicate Enquiry-thread fetch;
- do not refresh unrelated discovery/community/sponsored surfaces after a simple mark-read unless actually invalidated.

Reference path:
Class-message send is the good pattern: one canonical send + one authoritative thread refetch.

Replay:
P04/P05 Notifications, Enquiry send, mark-read, unread badge, request counts.

### Slice F — operator/admin clarity

Fix:
- Platform Admin Local-operations authority wording;
- Audit search/filter/pagination or incremental load;
- clearer managed-vs-read-only Location grouping if still useful;
- reduce routine governance prose while keeping trust guarantees discoverable.

Replay:
P01/P02/P08.

### Slice G — launch-data hygiene

Before broad investor/general public demonstration:
controlled Dhanbad supply labelled `TEST ONLY` must be quarantined/gated from ordinary public discovery.

Do not relabel test supply as genuine.

This is launch hygiene, not an excuse to invent supply.

## Current repo/worktree safety

Current tracked working tree is clean.

There are many untracked generated QA/runtime artifacts:
- `.wrangler/`
- reconstructed build output
- release folders
- many E2E evidence folders/scripts, including the live-acceptance study

Do **not** run blind `git clean`, `git reset --hard`, or delete generated folders wholesale.

The stale note in `06-consolidated-acceptance-findings-and-plan.md` saying the semantic-card patch was “uncommitted” is historical. That patch is now committed as `7b896fe`.

Current branch HEAD already includes the two completed improvement slices plus MyRaahi location/SSO handoff commits. Public production is still the frozen acceptance SHA `7d99b691...`.

Do not deploy current HEAD merely because CI is green. Complete the accepted improvement sequence, preview the exact final product SHA, replay affected personas, and run the final short nine-persona regression first.

## Frozen product/business invariants

Do not violate:
- no fake Teachers, learner demand, ratings, engagement or credentials in public;
- controlled test entities stay clearly test-only;
- no public or manager-browseable learner directory;
- operator never publishes a Teacher profile or invents Teacher facts;
- Google remains primary sign-in;
- phone trust remains separate from login/capability;
- unique phone ownership is preserved;
- Account, capability and current context remain separate;
- first-use intent grants no authority;
- browser never directly mutates operational tables;
- consequential writes use canonical RPCs;
- realtime only invalidates/refetches;
- PostgreSQL is source of truth;
- Location does not own identity/history;
- exact sensitive action survives phone-trust interruption;
- never re-enable synthetic DEV writers or recreate `.github/RAAHI_LEARNING_DEV_WRITES_ENABLED`;
- never expose secrets.

During live acceptance replays:
- use real browser UI like a normal user;
- use existing controlled entities for safe mutations;
- do not create fake public content merely for coverage.

## Qualification discipline for every remaining slice

1. impact analysis:
   rules → entities → relationships → states → permissions → UI → tests
2. smallest implementation change
3. source/static regression
4. dedicated browser contract
5. accumulated model/browser suites
6. commit exact product SHA
7. independent GitHub qualification
8. preview exact SHA
9. replay affected real personas against preview
10. production only from the exact previewed artifact
11. post-deploy affected-persona proof

After all accepted P1/P2 slices:
- run short nine-persona browser-only regression using the frozen scenario book;
- compare against the 104-screen acceptance baseline;
- confirm no new P0/P1;
- confirm launch-data hygiene;
- then promote the exact qualified artifact and update the release handover separately.

P3/Idea items should not delay controlled launch unless implementation reveals a deeper issue.

## Exact next-chat start sequence

1. Read this file completely.
2. Read:
   - `tests/raahi-learning-e2e/artifacts-live-user-acceptance-2026-09-28/06-consolidated-acceptance-findings-and-plan.md`
   - `.../02-screen-coverage-register.md`
   - `.../04-final-live-user-acceptance-report.md`
3. Verify read-only:
   - local `git status --short --branch`;
   - local/remote branch HEAD;
   - public `https://learning.myraahi.co.in/build-meta.json` remains `7d99b691...`;
   - GitHub Model #807 and Browser #53 are green for `bf65527...`.
4. Do not deploy.
5. Start **Slice C — Institute identity ambiguity** with read-only root-cause analysis of the two P06 organization IDs.
6. Only after the identity model is understood, choose safe data reconciliation or UI disambiguation.
7. Qualify/replay P06 before continuing to Slice D.

## Copy/paste prompt for the next chat

Continue Raahi Learning from `docs/raahi-learning/135-current-execution-handover-live-acceptance-improvements-2026-10-01.md`.

Repo: `rajeevbackup42112-coder/raahi`  
Branch: `raahi-learning-implementation-v1`  
Local repo: `C:\Users\Dipti\Downloads\raahi-cutover-20260920`  
Supabase controlled pilot: `iiwwmqokaeflaenhlyip`

First read the entire handover and the canonical live-acceptance synthesis it references. Verify Git/local/public state read-only before changing anything.

Current undeployed product HEAD is `bf65527b0d4379e1d2467b32d4817d1b44e0948e`; public production must remain `7d99b69165df0de0ca02e7778fde995b302ff624` until the accepted improvement sequence is complete.

The live nine-persona acceptance study is frozen and complete. Slice A (semantic navigation cards) and Slice B (active learner context clarity) are done and independently green. Do not redo them.

Immediate next task: Slice C — investigate P06's two indistinguishable Institute organization contexts read-only. IDs:
`251ad6fe-4b3b-4ade-84bf-5cad13cf2880`
`5c970182-38e1-42ff-a9a0-58a48d317e1a`

Do not merge/delete/archive anything until ownership/history/memberships/Ads relationships are proven. Then implement the smallest safe fix, qualify exact SHA, and replay P06 Institute → Ads → Create. Continue through the remaining accepted P2 slices, then run the final short nine-persona regression and deploy only the exact previewed/qualified artifact. Continue autonomously until a genuine product/data decision or human credential/OTP is required.

