# Raahi Learning — Canonical Alignment Audit — Pre-Launch — 2026-09-23

Status: **ALIGNMENT AUDIT OPEN — FEATURE EXPANSION FROZEN — CORE DOMAIN RETAINED**

Repository: `rajeevbackup42112-coder/raahi`  
Branch: `raahi-learning-implementation-v1`  
Supabase DEV / current public backend: `iiwwmqokaeflaenhlyip`

## 1. Why this audit exists

A genuine first-Teacher run exposed two related problems:

1. a normal Account could reach Home without being guided through the frozen first-use intent journey;
2. a newly added Start teaching affordance existed in source/tests but initially failed as a real mobile interaction.

These are not evidence that the Raahi domain model is wrong. They are evidence that later V1.3/V1.4 orchestration and test layers can drift from the original human journey even while database/security invariants remain correct.

This audit therefore compares:

`frozen product intent → AI Builder rules → intended human journeys → current UI/orchestration → tests → live behavior`.

Do not restart product discovery or rebuild the database unless a genuine domain contradiction is found.

## 2. Canonical principles that remain authoritative

The following remain aligned and are not reopened:

- one Raahi Account may learn, teach, manage a Learner and represent an Organization;
- Account != Learner;
- intent is guidance, not permanent role assignment;
- Location is discovery/community context, not identity or membership;
- changing Location must not remove Classes, Enquiries, Messages or history;
- no public Learner directory;
- no unrestricted DM;
- Enquiry is the controlled relationship-starting boundary;
- one Class model supports 1:1 and group learning;
- no public ratings/reviews in V1;
- Google authenticates; it does not grant Raahi authority;
- phone OTP is a trust check for selected sensitive actions, not a second login;
- UI does not directly mutate core operational tables;
- canonical RPCs and PostgreSQL remain authoritative;
- Founding Supply may prepare only a private Teacher-requested draft and only the same Teacher may publish it;
- market activation seeds usefulness, never fake people, demand, engagement or traction.

## 3. Audit classification

Every finding is classified as one of:

- **ALIGNED** — current behavior matches canonical intent.
- **INTENTIONAL EVOLUTION** — later design change is documented and consistent with the original problem.
- **PRESENTATION DRIFT** — backend/rules remain correct but user-facing flow/copy drifted.
- **INTEGRATION DEFECT** — valid layers do not connect into the intended journey.
- **IMPLEMENTATION DEFECT** — agreed contract is correct but code is wrong.
- **TEST COVERAGE GAP** — tests prove pieces/routes rather than the human journey.
- **UNPROVEN** — needs browser evidence before judgment.
- **DOMAIN CONTRADICTION** — would require reopening AI Builder impact analysis. None confirmed in this audit so far.

## 4. Current alignment matrix

| Area | Canonical intent | Current evidence | Classification | Required action |
|---|---|---|---|---|
| Account / Learner identity | One Account can have multiple learning/teaching/org relationships; Account != Learner | Frozen rules, DB contracts and persona tests preserve this | **ALIGNED** | Keep |
| Google authentication | Google authenticates only; Raahi authority remains server-owned | Hosted Auth/Account continuity and backend authorization proven | **ALIGNED** | Keep |
| First-use intent | New Account should see “What brings you here today?” and choose learn / help someone / teach / institute / explore | Genuine Account reached ordinary Home with no Learner, teaching or org authority and did not receive first-use guidance | **INTEGRATION / PRESENTATION DRIFT** | Restore first-use orchestration |
| Intent vs permanent role | Intent guides first task; never locks Account to one role | Backend supports multiple capabilities/relationships | **ALIGNED underneath; UX needs re-proof** | Add multi-intent journey tests |
| Returning-user landing | Established users should not repeat onboarding | Existing sessions generally land Home/workspace | **LIKELY ALIGNED** | Prove with returning personas |
| Become a Teacher later | Any eligible Account can later start teaching | Home CTA now exists; backend enable/assisted paths exist | **ALIGNED concept; journey integration defective** | Preserve as secondary path after first-use fix |
| Teacher self-service onboarding | Human journey: Start teaching → profile basics → What I Teach → Locations → availability → preview/publish | Current setup exposes “Teacher capability / Server-authorized on this Account” and immediately enables teaching before normal profile work | **PRESENTATION DRIFT / JOURNEY GAP** | Re-humanize and replay full self-service journey |
| Assisted Teacher onboarding | Teacher asks; Raahi prepares private draft; Teacher reviews/publishes | Backend/state/consent model remains correct; genuine request reached `requested` with 0 public supply | **ALIGNED rules; integration UX needs repair** | Keep backend, repair pre-teacher routing |
| Pre-teacher route guards | URL changing must never grant teacher authority | Guard worked, but legitimate onboarding flow collided with the guard | **SECURITY ALIGNED / INTEGRATION DEFECT** | Keep guard; fix journey so normal users do not hit it |
| Home | Useful local network; simple primary actions; not a dashboard | V1.4 simplified hero, Location emphasis, find teacher / need tuition, empty-state suppression | **INTENTIONAL EVOLUTION / MOSTLY ALIGNED** | Re-check after first-use restoration |
| Explore | Browseable marketplace, rich genuine teacher/options, no fabricated supply | V1.4 category/teacher presentation added; genuine supply policy retained | **MOSTLY ALIGNED** | Journey-test discovery → profile → enquiry |
| Learning Request | “What are you looking to learn?” human flow, privacy-safe genuine need | V1.4 copy humanizes form; backend invariants remain | **MOSTLY ALIGNED** | End-to-end mobile proof |
| Messages | Contextual safe conversations, no unrestricted DMs | Conversation authorization remains relationship-scoped; V1.4 humanizes Messages copy | **ALIGNED concept** | Verify empty → enquiry → active thread journey |
| Classes | User sees Classes, invitations and learning; Membership remains internal | Some live copy still exposes “relationship-scoped”, “Membership”, server recheck language | **PRESENTATION DRIFT** | Remove internal mechanics from ordinary UI |
| Learning profiles / Parent | Parent acts for learner without impersonation; simple Me/Rahul/Ananya mental model | Backend is correct, but some UI exposes “Account”, “access path”, management invariants | **PRESENTATION DRIFT** | Humanize; preserve authority |
| Student navigation | Learning-focused navigation, no parent impersonation | Existing frozen/student workspace exists and security tests cover Test authority | **ALIGNED underneath / UX UNPROVEN** | Real persona journey on mobile |
| Location | Selected Location changes discovery, not existing relationships/history | DB/property tests explicitly prove preservation; V1.4 chooser reinforces switching | **ALIGNED** | Keep; add human switch regression |
| Community | Local useful learning discussion; no fake engagement | Raahi Desk is explicitly platform-authored; no fake-person policy encoded | **ALIGNED / INTENTIONAL EVOLUTION** | Seed only truthful useful content |
| Founding Supply provenance | Genuine, consented assisted supply only | Explicit provenance/state/invariants present | **ALIGNED** | Keep |
| Phone trust | Only sensitive commands; resume intended action; not repeated login | StartMessaging + server trust gate proven | **ALIGNED concept** | Journey-test interruption/resume on final critical flows |
| Settings | Human goals; security detail progressively disclosed | Current screen-level wording not yet re-audited against V1.4 plan | **UNPROVEN** | Browser/copy audit |
| Organization onboarding | Guided institute creation; permissions remain strict underneath | Backend and permission tests strong; first-use institute journey not part of current convergence tests | **TEST COVERAGE GAP / UNPROVEN UX** | Add brand-new institute journey |
| Workspace switching | Multiple capabilities can coexist; switching context must not grant authority | UI tests directly select `data-live-role-select` after pre-seeding personas | **AUTHORITY ALIGNED; HUMAN UX UNPROVEN** | Audit visible switcher and humanize labels |
| Admin / Local Manager | Strict scope underneath, simple operational presentation | Scope/authority tests strong; V1.4 operational copy partially polished | **MOSTLY ALIGNED** | Preserve; lower launch priority |
| Ads | Governed, education-only, clearly Sponsored, isolated from private learning | Existing state/permission model remains | **ALIGNED** | Preserve |
| Empty states | Helpful and encouraging, not technical | V1.4 substantially improved Home/Explore/Classes/Messages empties | **INTENTIONAL EVOLUTION / ALIGNED** | Keep |
| Mobile behavior | Critical journeys work by touch, not only DOM/source assertions | Start teaching existed in source but failed genuine iPhone tapping before two fixes | **TEST COVERAGE GAP** | Make mobile action E2E a release gate |
| Test strategy | Acceptance tests should prove human goals and cross-layer journeys | UI convergence tests pre-create Learners/Teacher capability via RPC, then explicitly choose workspace and inspect routes at desktop/mobile viewports | **TEST COVERAGE GAP** | Add clean-account journey suite |
| Late overlay architecture | Presentation slices should not silently break routing/interaction | V1.4 layers wrap render/afterRender and inject DOM controls after base handlers; Start teaching defect arose here | **IMPLEMENTATION RISK** | Consolidate critical orchestration rather than adding more patch overlays |

## 5. Most important confirmed drift

### A. First-use onboarding drift — P0

Frozen V1.3 requirement:

**new Google Account → profile confirmation → What brings you here today? → guided setup or explore → Home**

Observed genuine behavior:

**Google Account → Home**, despite no Learner, no teaching capability, no Organization and no manager scope.

The later Home “Are you a teacher? Start teaching” entry is useful as a returning-user secondary action, but it must not replace first-use intent.

### B. Human-language drift — P0/P1

Ordinary users should not need to understand:

- capability;
- server-authorized Account;
- relationship-scoped;
- Membership;
- learner-side access path;
- authorization projection/state language.

Examples remain in current Teacher setup, Classes and Learning profiles surfaces. The backend terminology is valid; exposing it to normal users is not the intended product.

### C. Journey-test drift — P0

Current UI convergence tests are valuable but they are primarily **route/visual/permission convergence tests**.

For example, they:

- create a self Learner directly through RPC before browser inspection;
- enable teaching directly through RPC before Teacher route inspection;
- authenticate and wait for `#/home`;
- explicitly choose a live workspace;
- then compare individual routes at desktop/mobile viewport.

Therefore they can pass while the human journey:

**brand-new Account → choose intent → gain relationship/capability through UI → continue**

is broken.

That is exactly the gap exposed by the real Teacher run.

### D. Public positioning contradiction — P0

The frozen V1 product language explicitly removed **Find Students** and prohibits a public Learner directory.

The later V1.4 delight plan and implementation nevertheless introduced:

**Find teachers. Find students. Learn locally.**

That wording implies a discovery surface the product deliberately does not provide and weakens the privacy model.

Correction now adopted:

**Find teachers. Share what you need. Learn locally.**

Genuine learner demand remains expressed through privacy-safe Learning Requests rather than a student directory.

### E. Overlay integration fragility — P1

V1.4 presentation/activation layers intentionally avoided backend redesign, but several now:

- wrap `renderRoute` / `afterRender`;
- inject controls into already-rendered DOM;
- add routes after the core application has initialized;
- rely on separate event delegation or direct handlers.

This made rapid iteration possible but increases the chance that a screen “exists” without participating correctly in core navigation/lifecycle handling.

Before broad launch, critical first-use/onboarding orchestration should be consolidated into one authoritative flow rather than extended with more Home-page patches.

## 6. What has NOT drifted

The audit does **not** support rebuilding:

- Account / Learner model;
- Teacher/Profile/Teaching Option ownership;
- Organization authority;
- Enquiry;
- Class / Invitation / Membership;
- Activity / Test;
- Location;
- Community provenance;
- Ads;
- RLS / canonical RPC architecture;
- phone-trust model.

The core product remains recognizable as the intended Raahi Learning Network.

## 7. Repair order

### Slice 1 — First-use orchestration

Acceptance target:

1. brand-new Account with no meaningful relationship/capability does not silently land on generic Home;
2. user sees **What brings you here today?**;
3. Learn / Help someone / Teach / Institute / Explore routes are human-guided;
4. choosing intent grants no authority by itself;
5. “Explore” remains a valid no-setup path;
6. returning established users do not repeat first-use onboarding;
7. later addition of another relationship remains available.

### Slice 2 — Teacher onboarding humanization

- remove capability/Account/server-authorized jargon;
- self-service path becomes a coherent guided flow;
- assisted path remains private until Teacher consent;
- legitimate pre-teacher pages never collide with Teacher workspace guards;
- Home Start teaching remains as a secondary re-entry point.

### Slice 3 — Parent/Learner + Classes language cleanup

- hide Membership/access-path mechanics;
- use “My learning / Rahul / Ananya” language;
- retain the exact same server permissions/invariants.

### Slice 4 — Workspace/context switching audit

- show only contexts the Account truly has;
- switching context never grants authority;
- labels describe human goals, not backend roles;
- do not force users to understand “role” as permanent identity.

### Slice 5 — Launch Journey E2E

Create browser journeys from **clean starting Accounts**, not pre-seeded capability states:

- explore-only new user;
- self learner;
- parent adds learner;
- self-service Teacher;
- assisted Teacher;
- Teacher + Parent multi-context;
- institute owner;
- discovery → enquiry;
- request → provider response;
- invitation → Class;
- Location switch persistence;
- phone-trust interruption/resume;
- logout/login persistence.

Every P0 journey runs desktop and mobile-sized browser interaction and verifies backend state after important transitions.

## 8. Release rule from this point

Do not call a surface launch-ready because:

- its route renders;
- its button exists in source;
- its RPC unit tests pass;
- its database invariant passes;
- a pre-seeded persona can open the page.

For a critical feature, launch-ready now means:

**canonical rule green → backend green → clean-account real browser journey green → mobile interaction green → genuine human canary green.**

## 9. Current genuine Teacher request

The existing real assisted Teacher request should remain untouched while alignment repair is in progress.

Its safe state is useful evidence:

- request exists because the Teacher explicitly asked;
- state is `requested`;
- no public Teacher Profile exists yet;
- no Teaching Option exists yet;
- no silent Teacher authority should be added.

Resume it only after the pre-teacher journey and assisted-flow routing are aligned and covered by the new E2E gate.

## 10. Execution status — 2026-09-23

Completed in source / backend:

- Slice 1 first-use alignment contract: `120-first-use-intent-alignment-contract-v1.4k.md`;
- additive `accounts.first_use_completed_at` migration applied;
- established Accounts backfilled without changing authority;
- canonical `complete_first_use_onboarding` command added;
- frontend first-use routing prepared;
- Slice 2 human-language contract: `121-human-language-alignment-contract-v1.4k.md`;
- Teacher setup / Classes / Learning profiles / phone-check copy humanized in source;
- V1.4 **Find Students** contradiction corrected in both plan and implementation.

The current genuine assisted Teacher request remains private and untouched:
- state = `requested`;
- public Teacher Profiles = 0;
- Teaching Options = 0.

Not yet complete:

- browser qualification of the new first-use flow;
- mobile tap qualification;
- production frontend deployment of these alignment changes;
- clean-account launch journey suite;
- Google profile-confirmation alignment proof;
- workspace/context-switching UX audit;
- institute clean-account onboarding proof.

The Remote Desktop Commander device is currently offline, so frontend deployment is intentionally held rather than bypassing the browser qualification gate.

## 11. Immediate execution decision

**Do not restart product design. Do not add more features.**

Proceed with:

1. get the alignment CI fully green;
2. qualify first-use + Teacher onboarding on a Cloudflare preview with real browser interaction when the authorized remote device returns;
3. add clean-account desktop/mobile E2E;
4. audit Google profile confirmation, workspace/context switching and institute first-use;
5. deploy aligned frontend only after preview gates pass;
6. then resume the genuine Teacher proof.
