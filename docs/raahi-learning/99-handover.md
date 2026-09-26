# Raahi Learning - Handover / Current State

**For the current state, read `133-investor-grade-ux-audit-and-redesign-gate-2026-09-25.md` first.**

Repository: `rajeevbackup42112-coder/raahi`  
Implementation branch: `raahi-learning-implementation-v1`  
Canonical docs: `docs/raahi-learning/`

> This branch is isolated from older Raahi ride work on `main`. Do not replay mobility migrations or overwrite the older commute app.

## Current status

**2026-09-26 INVESTOR-GRADE UX REDESIGN GATE — SLICES 1–5 CLOSED / UNDEPLOYED:** read `133-investor-grade-ux-audit-and-redesign-gate-2026-09-25.md` first. The baseline live audit covers all nine persistent browser profiles across 14 role contexts, 493 screens and 6,360 controls on desktop + iPhone. Raahi-01 has been re-authenticated and is included. Slice 1 exact product SHA `bcc1161166b05345d63a2d083bffac22803b2e2f` redesigned the shared responsive shell, Welcome and Profile photo UX; Model Tests #778 and Browser Contract #38 passed first attempt. Slice 2 exact SHA `b32372b03d62afaee7b0cd97c02fa3035afef5a8` redesigned Notifications into a scan-friendly mobile inbox; Model Tests #779 and Browser Contract #39 passed first attempt. Slice 3 exact SHA `998b92b42bdd7173eae5f114d9741fdae07dac85` enforces 44px mobile action targets across difficult screens; Model Tests #781 and Browser Contract #40 passed first attempt. Slice 4 exact SHA `05210a8fafd970d1ae6b3719028145a09e9e70c6` redesigns Settings into Profile / Security / Account hierarchy with destructive account actions progressively disclosed; Model Tests #783 and Browser Contract #41 passed first attempt. Slice 5 exact SHA `f4c85ae421362448f15812befd9e66de287b4dea` redesigns Enquiry/Class conversation detail into left/right bubbles with latest-message positioning while preserving canonical send/refetch paths and the Class double-submit lock; Conversation UX browser contract passes 16/16. Exact Slice 5 qualification includes 5,349,572 model cases / 0 failures, source 35/35, shell 5/5, Notifications 9/9, mobile actions 32/32, Settings 8/8, Conversation 16/16, human-language 168/168 and existing interactions 27/27. Model Tests #785 and Browser Contract #42 passed first attempt. Do not deploy these UX slices while the broader redesign gate remains open. Public was reverified unchanged on `5d8ea741a4c782a3978f4d3c096024e3dbc0fead`.

**2026-09-25 PRE-LAUNCH LIVE SIMULATION ROUND 6:** public is verified on exact product source `5d8ea741a4c782a3978f4d3c096024e3dbc0fead`. Browser Contract #33 was rerun unchanged on `dfbc89a` and passed 27/27; the admin Audit/Ads polish was previewed, hash-verified and deployed. Round 6 then exposed a real Class-message double-submit race: two immediate clicks created two messages because each click generated a fresh idempotency key. The narrow UI in-flight lock repair `5d8ea74` passed 5,349,572 model cases, focused 18/18, sealed browser 27/27, GitHub Model Tests #770 and Browser Contract #34. Preview and production hashes match with zero mismatches. Live Teacher and Parent double-click proofs now each produce one send, one authoritative thread refetch and one visible message. Reload/deep-link and Explorer logout→Google-login recovery are green. Safety has 0 open reports and Gomoh Community has no existing posts, so exact-target report/block/community mutations were intentionally not fabricated. Read `132-current-execution-handover-prelaunch-live-simulation-round6-2026-09-25.md` first.

**2026-09-23 FIRST GENUINE TEACHER CLOSED:** V1.4K public source `e4010e3` is live. The first genuine assisted Teacher supplied real facts, reviewed the private draft, passed phone trust with an alternate number after a duplicate-phone conflict was correctly diagnosed, and explicitly published. Canonical state is **1 active teach capability / 1 visible Teacher Profile / 1 Teaching Option / request accepted**. The option is visible in Explore Gomoh and Teacher edit ownership is proven. Duplicate-phone trust now fails early with clear guidance, and Teacher workspace shows **Access confirmed** instead of internal authorization language. Read `129-current-execution-handover-first-teacher-closed-2026-09-23.md` first, then `128-first-genuine-founding-supply-closure-2026-09-23.md`.

**2026-09-23 V1.4K PUBLIC LIVE — FIRST GENUINE TEACHER DRAFT INPUT NEEDED:** alignment repair source `b770a9b` is live at `https://learning.myraahi.co.in` via Cloudflare deployment `7cbe5890-cf90-4379-80a7-88abfbe0a4a9`; custom-domain hashes match, genuine DEV and public Google-auth canaries are green, and the existing assisted Teacher request remains `requested` with **0 profile, 0 teaching options, 0 active teach capability**. The request contains no proposed Teacher facts. Do not fabricate them. Read `127-current-execution-handover-first-teacher-draft-input-needed-2026-09-23.md` first, then `126-v14k-alignment-public-live-evidence-2026-09-23.md`.

**2026-09-23 V1.4K ALIGNMENT QUALIFIED — GENUINE DEV CANARY NEXT:** first-use/profile onboarding, Teacher onboarding continuity, Learner/Parent/Institute continuations and human context switching are repaired and qualified. Applied migrations: `v14k_first_use_intent_alignment` and `v14k_google_profile_confirmation_alignment`. Model Tests #730 passed. Sealed real-browser Contract #14 passed **27 interactions**: 15 profile/intent, 4 Teacher/phone-resume, 8 Learner/Parent/Institute/context-switch. DEV carries the aligned source; PUBLIC remains on the older pre-alignment frontend. The genuine assisted Teacher request remains `requested` with **0 profile, 0 teaching options, 0 active teach capability**. Do not process it yet. Next: one genuine Google-authenticated DEV browser canary, then guarded public release. Read `125-current-execution-handover-v14k-alignment-qualified-2026-09-23.md` first.

**2026-09-23 FIRST REAL TEACHER PROOF IN PROGRESS:** the first genuine Teacher test Account is active but has no teacher capability/profile/request yet. A discoverability defect was found: returning ordinary Accounts could not see a path to Teacher setup from Home. Source `b48fd7387e97f6df7c8324c73ad951c883b8c96b` adds **Are you a teacher? Start teaching** to Home for non-teacher Accounts; CI #670 passed and production deployment `22e74407-4a03-4614-a032-54d5c6765ce7` is live. The user has not yet visually re-confirmed the CTA after refresh. Read `118-current-execution-handover-first-real-teacher-2026-09-23.md` first; then continue with the real **Start teaching -> Ask Raahi to help** flow. Do not silently use self-service `enable_teaching` for this first assisted proof.

**2026-09-23 V1.4H STARTMESSAGING PHONE TRUST PUBLIC LIVE:** Google remains primary sign-in; StartMessaging is now the production OTP delivery provider only for trust-sensitive actions. Exact frontend source `5d864733af9f32c6de6f604764e82d26f04856a6`, production deployment `33e55d0e-a346-46d4-a756-0c580a5b08f4`, CI #668 success. Runtime phone trust is `phone_trust_required`; Ajit's logout→Google-login continuity and fresh-trust protected-command proof passed, while an unverified rollback account was denied. Phone entry is normal 10-digit India format with +91 added automatically, and Phone check exposes Log out. Read `117-current-execution-handover-v14h-public-live-2026-09-23.md` first.

**2026-09-22 V1.4E GLOBAL ADMIN LOCATION ADMIN MANAGEMENT PUBLIC LIVE:** exact app SHA `ca4890629e787a5d969edce691dbac6f756f318d`, production deployment `c0ab3d26-185e-45e1-a18b-9cff6504f405`, CI #658 success. Global Admin `choudhary.ajit2112@gmail.com` can now manage routine city-admin assignments from Raahi's new **Location Admins** screen using canonical audited commands. Gomoh remains `rajeev.backup1.2112@gmail.com`; Dhanbad remains `rajeev.backup2.2112@gmail.com`. Read `111-current-execution-handover-v14e-public-live-2026-09-22.md` first.

**2026-09-21 V1.4D SCOPED MARKET ACTIVATION PUBLIC LIVE:** city-scoped Raahi Desk + Founding Supply authority is live from exact application SHA `89edd9c12c8e37a70e1f8fb46faf544ac75fe6b2`. Gomoh local manager `rajeev.backup1.2112@gmail.com` can operate only Gomoh; Dhanbad local manager `rajeev.backup2.2112@gmail.com` can operate only Dhanbad. The permanent migration `20260921105250_v14d_scoped_market_activation_authority` is applied. Real manager identities passed rollback production proofs for own-city allow / cross-city deny with zero residue. Production deployment is `6dd2f1d7-3514-47a7-b7b2-631d079a19be`; exact file hashes match and forbidden public matches are zero. `choudhary.ajit2112@gmail.com` is the user-selected first global Platform Admin, but the connected execution safety layer blocked assistant-driven first-admin privilege creation. The authenticated Supabase SQL Editor is pre-filled with a guarded one-time bootstrap and is waiting for the user to press Run. Read `107-current-execution-handover-v14d-public-live-2026-09-21.md` first, then `106-v14d-scoped-market-activation-public-live-evidence-2026-09-21.md`.

**2026-09-21 V1.4C FOUNDING SUPPLY PUBLIC LIVE:** the assisted Teacher onboarding walking skeleton is deployed at `https://learning.myraahi.co.in` from exact application SHA `c990d9a8b854b362d88bb4e1b7b8cf99a6538d95`. A genuine Teacher must request help first; Raahi may prepare only a private bounded draft; only that same authenticated Teacher can accept and publish the exact proposal. Permanent migrations `20260921093234`, `20260921093410`, and `20260921093510` are applied and transactionally proven. Production artifact hashes match with zero forbidden public matches. Home/Explore/Community/Messages, Teacher Setup/Help, ordinary-user Platform denial, signed-out behavior, Privacy/Terms, and Dhanbad -> Gomoh -> Dhanbad are green. There are currently **0 active Platform Admins, 0 assisted requests, and 0 assisted Teacher Profiles/Teaching Options**, so no fake supply was introduced. Read `103-current-execution-handover-v14c-public-live-2026-09-21.md` first, then `102-v14c-founding-supply-public-live-evidence-2026-09-21.md`. The next genuine gate is deliberate Platform Admin ownership, followed by one real Teacher end-to-end proof.

**2026-09-20 PUBLIC GO-LIVE:** Google Auth Platform is now **In production** and External. A Google identity outside the former two-user OAuth test list completed consent on the public origin, landed on Home, and bootstrapped a fresh active Raahi Account. Dhanbad + Gomoh are live/selectable; promotion is Gomoh-first, not Gomoh-restricted. Production data must now be treated as real user data. Read `89-public-go-live-evidence-2026-09-20.md` first.

**Historical controlled-pilot cutover record:** before public admission, the hash-verified release candidate was reachable at `https://learning.myraahi.co.in`, the pre-cleanup logical backup was checksum-verified, synthetic public data and harness Auth users were removed, synthetic writers and `dev-test-identities` were sealed, retired MessageCentral secrets were removed, Dhanbad + Gomoh were the only live Locations, and the genuine two-user Google/RLS canary was green. At that historical point Google OAuth was still in Testing and real users had not yet been admitted. This is superseded by the PUBLIC GO-LIVE state above; see `87-controlled-pilot-cutover-evidence-2026-09-20.md` only for cutover evidence.

**Foundation, R4, genuine-session testing, the 20-persona cohort, workspace convergence, SE-01 through SE-08, post-SE-08 combined regression, bounded Class race/recovery/shared-browser security, and a bounded release-reliability smoke are proven in DEV. The stable recovery/shared-browser product-code proof anchor is `d0232c4fdb9410d4902063740974b7110da59473`. Release Reliability run `35442347699` on `10111144a2d00fb28d02a4217c4225a5188673b6` passed 20 genuine personas, 800 authenticated reads, 20 cross-account denial checks and 20 browser sign-ins with no latency warnings. Current migration ceiling is now `20260922214728_v14h_remove_public_phone_trust_policy_projection`. `build-meta.json` may advance across source-compatible documentation/test commits, so always read it at execution time rather than pinning a non-app SHA as permanent current product state. Production-scale/soak, operational alert delivery and DB+Storage restore remain separate operational hardening items. Real StartMessaging provider smoke and public phone-trust activation are now closed in V1.4H. See docs 68–76.**

Supabase DEV project: `iiwwmqokaeflaenhlyip`, region `ap-south-1`.

The old 2026-09-13 zero-Auth preflight is historical only. Real hosted Google/phone identities now exist, Auth→Account continuity is proven, the original Rajeev R4 phone-interruption/resume chain remains durable, and the final Class-message / notification / copied-link privacy boundary is autonomously proven in isolated cloud browsers. The normal regression foundation now uses DEV-only OIDC-protected test identities with genuine Supabase sessions and intact RLS. See `50-dev-test-identity-session-harness-v1.3.md`, `51-hosted-auth-r4-walking-skeleton-closure-v1.3.md`, and `52-master-lifecycle-gates-traceability-v1.3.md`.

Do **not** restart product design, rebuild the database, recreate the DEV-write marker, re-enable synthetic writers, or run destructive pilot cleanup. Google OAuth is already public and production data must be treated as real user data.

Read next:

1. `133-investor-grade-ux-audit-and-redesign-gate-2026-09-25.md` - **canonical current UX gate; deployment frozen until product-wide visual redesign and mobile/desktop regression are closed**
2. `132-current-execution-handover-prelaunch-live-simulation-round6-2026-09-25.md` - Round-6 functional baseline; admin polish and Class-message double-submit recovery are public-live and proven
3. `131-current-execution-handover-prelaunch-live-simulation-round5-2026-09-25.md` - Round-5 predecessor and Browser Contract #33 failure context
4. `130-prelaunch-live-simulation-registry-2026-09-23.md` - persistent isolated browser personas and accumulated live-simulation state
5. `129-current-execution-handover-first-teacher-closed-2026-09-23.md` - first genuine Teacher closure and controlled Gomoh pilot baseline
2. `117-current-execution-handover-v14h-public-live-2026-09-23.md` - **V1.4H StartMessaging phone trust public-live handover**
3. `116-v14h-startmessaging-phone-trust-public-live-evidence-2026-09-23.md` - **exact V1.4H deployment, migrations, identity continuity, enforcement and browser evidence**
4. `115-startmessaging-phone-trust-activation-contract-v1.4h.md` - activation contract and rollout order
5. `111-current-execution-handover-v14e-public-live-2026-09-22.md` - historical V1.4E admin-management handover
6. `106-v14d-scoped-market-activation-public-live-evidence-2026-09-21.md` - historical V1.4D city-manager scope evidence
7. `105-scoped-market-activation-authority-contract-v1.4d.md` - **frozen global-vs-Location market activation authority contract**
8. `104-city-admin-ownership-bootstrap-2026-09-21.md` - live Gomoh/Dhanbad city-admin ownership
9. `103-current-execution-handover-v14c-public-live-2026-09-21.md` - historical V1.4C handover
10. `102-v14c-founding-supply-public-live-evidence-2026-09-21.md` - historical V1.4C public-live evidence
11. `101-founding-supply-assisted-teacher-onboarding-contract-v1.4c.md` - Founding Supply consent contract
12. `100-current-execution-handover-v14b-public-live-2026-09-21.md` - historical V1.4B handover
9. `98-v14b-raahi-desk-public-live-evidence-2026-09-21.md` - historical V1.4B public-live evidence
10. `92-market-activation-seeding-blueprint-v1.4.md` - **market-activation master blueprint**

5. `89-public-go-live-evidence-2026-09-20.md` - public Google admission baseline

1. `88-gomoh-first-public-launch-model-2026-09-20.md` - **frozen public-launch Location model: Dhanbad + Gomoh selectable; Gomoh-first acquisition, no geographic account lock**

1. `87-controlled-pilot-cutover-evidence-2026-09-20.md` — **latest continuation state; final technical cutover evidence; read this first in a new chat**

1. `86-public-origin-google-oauth-proof-2026-09-20.md` — **latest continuation state; public origin + production Google OAuth proof; read this first in a new chat**\n2. `85-production-oauth-hosting-readiness-2026-09-20.md` — prior production OAuth/hosting readiness state\n2. `84-current-execution-handover-2026-09-20.md` — prior Stage Ready execution handover
2. `83-production-google-oauth-preparation-v1.3.md` — **exact next external gate: production Google OAuth project/client and values**
2. `82-stage-ready-google-only-pilot-closeout-v1.3.md` — **current Stage Ready closure and exact post-change proof set**
2. `81-controlled-pilot-google-only-trust-v1.3.md` — **current approved pilot trust rule and impact analysis**
2. `78-controlled-pilot-cutover-runbook-v1.3.md` — **current same-project pilot cutover: backup, synthetic cleanup, writer/identity seal, Google auth, Gomoh activation, canary**
3. `80-stage-ready-closeout-v1.3.md` — **historical pre-1037 Stage Ready baseline; must be superseded by fresh post-change closure**
4. `79-messagecentral-phone-trust-provider-v1.3.md` — **historical MessageCentral experiment; retired for pilot**
2. `77-stage-ready-single-project-progress-v1.3.md` — latest Stage progression: Gomoh preparing, same-project pilot canary, synthetic inventory, DEV-writer seal
3. `76-single-project-stage-controlled-pilot-strategy-v1.3.md` — approved zero-cost Stage→Gomoh+Dhanbad controlled-pilot strategy
4. `75-production-canary-recovery-inventory-readiness-v1.3.md` — guarded canary + recovery-inventory baseline
5. `74-production-like-load-operator-guard-readiness-v1.3.md` — guarded manual load workflow + backup/operator guard proof
4. `73-security-catalog-hardening-v1.3.md` — security catalog audit, migration 1033 and exact runtime denial proof
5. `72-production-operations-monitoring-backup-restore-runbook-v1.3.md` — prepared production operations / monitoring / backup / restore runbook; execution proof awaits production-like target
6. `71-bounded-reliability-observability-recovery-v1.3.md` — bounded reliability, health, rollback rehearsal and recovery boundary
7. `70-recovery-private-cache-release-readiness-v1.3.md` — bounded recovery/cache/release-packaging closure
8. `69-class-race-recovery-proof-v1.3.md` — complete bounded race/recovery/shared-browser proof
9. `68-post-se08-combined-regression-v1.3.md` — all 15 post-SE-08 suites green on a9f7ae5
10. `67-organization-authority-side-effect-closure-v1.3.md` — latest closed side-effect slice
11. `46-v1.3-side-effects-matrix-audit.md`
12. `66-test-correction-side-effect-closure-v1.3.md`
13. `65-current-execution-handover-se07-v1.3.md` — historical SE-07 execution handover
14. `59-exact-build-combined-regression-anchor-v1.3.md` — historical anchor
15. `52-master-lifecycle-gates-traceability-v1.3.md`
16. `51-hosted-auth-r4-walking-skeleton-closure-v1.3.md`
17. `50-dev-test-identity-session-harness-v1.3.md`
18. `47-ai-builder-v2-internal-retrofit-closure-v1.3.md`
19. `41-authentication-phone-trust-v1.3.md`
20. `48-hosted-auth-and-walking-skeleton-runbook-v1.3.md` — section 8 provider smoke remains open

## Frozen product rules

- `Account ≠ Learner`; Learner owns learning history.
- One Account may learn, teach, manage a Learner and represent an Organization.
- One active managing guardian per Learner in V1.
- No turning-18 migration/lifecycle.
- Active manager owns formal learner-side marketplace/relationship decisions where a manager exists; otherwise active self-access may act.
- Guardian authority never grants Test-taking impersonation.
- No public Learner directory.
- Discovery/Learning Request journeys converge on controlled Enquiry.
- Trial remains optional inside Enquiry.
- Pending Class Invitation reserves capacity; Membership begins only after acceptance.
- One responsible Teacher per Class in V1.
- Activity unifies Assignment/Practice/Exercise.
- Test definition locks at first valid Attempt; guardian receives oversight only.
- Selected Location changes discovery/community, not existing private Classes/Messages/history.
- Community remains local/authenticated; no global Community or unrestricted DM.
- No attendance, generic progress percentage, public star ratings/reviews, institute ERP/payroll, or platform tuition-payment collection.
- Ads are education-only, Sponsored-labelled, aggregate-only for advertisers and excluded from Class/Activity/Test/private-message surfaces.
- UI/workspace selection never grants authority.
- UI does not directly mutate operational tables; canonical RPCs own consequential transitions.
- Realtime invalidates/refetches only.

## V1.3 authentication + trust direction

### Controlled pilot

Current approved pilot flow:

**Google sign-in → Raahi Account → editable Raahi name/photo → intent-based setup → normal product use**

Rules during the Gomoh + Dhanbad controlled pilot:

- Google is the only required user authentication.
- Do not ask users for phone or WhatsApp verification.
- Phone trust is not marked fresh; its prerequisite is temporarily disabled by explicit server policy.
- All existing role, ownership, RLS, state, capacity, audit and idempotency checks remain in force.
- Anonymous marketplace browsing remains deferred.
- No fake OTP bypass exists.

Server policy:

`phone_trust_mode = controlled_pilot_google_only`

Trust-mode migration: `1037_v13_controlled_pilot_google_only_trust`; current migration ceiling: `1038_v13_remove_public_trust_policy_rpc`

The mode is fail-closed: absent or unknown configuration restores phone-trust enforcement.

Public controlled-pilot artifact:

- `phoneTrustMode = controlled_pilot_google_only`
- `phoneTrustProvider = disabled`

### Post-pilot direction

Google remains primary authentication.

Once Raahi has traction and user trust, selected sensitive actions should require an additional OTP proof rather than adding OTP to every login.

Current preferred future channel:

**direct Meta WhatsApp Business Platform Cloud API**

Intended future flow:

**Google sign-in → normal use → selected sensitive action → WhatsApp OTP → 90-day phone trust → resume action**

The 90-day phone freshness model remains the intended future design unless a later explicit product decision changes it.

### MessageCentral

MessageCentral is retired for the controlled pilot because its real account required a ₹4,999 minimum top-up.

The deployed `phone-trust-messagecentral` function is sealed at version 6 and returns HTTP 410. It cannot send SMS or change trust.

See docs 79 and 81.

## AI Builder v2 internal retrofit closure

The finite internal Screen ↔ Backend findings are closed:

- `teacher-members` renderer;
- exact Community report target;
- `community-post` included in route inventory;
- capability-aware Organization controls;
- safe Notification destinations;
- private invitation bearer removed from OAuth redirect query and kept only through local same-origin handoff;
- stronger route/capability/deep-link/test oracles.

The side-effects matrix is complete/frozen. Remaining non-walking-skeleton side-effect implementation stays queued for owning vertical slices after the real walking skeleton.

## Browser/frontend evidence

- reachable canonical routes: **84**;
- desktop/mobile live contract: **168/168 PASS**;
- issues: **0**;
- guard failures: **0**;
- focused V1.3 action contracts: **12/12 PASS**;
- privileged deep-link checks: **32/32 PASS**;
- semantic checks: **15/15 PASS**;
- workspace checks: **154/154 PASS**;
- interaction checks: **26/26 PASS**;
- no direct operational-table browser DML;
- no phone-primary login path in `live.js`;
- no raw Account UUID workflow.

Frozen anchors:

- `app.fixture.js`: `6eb67b36931c45aa4113c77005d82c13bb14ec145500e08cfd92130ebcef576c`
- `styles.css`: `b2d89e454f8e13712d10058c876f5efe2c8c69acf73dd6aade158241900f7bdd`

Current retrofit anchors:

- `app.live-core-v13.js`: `b8fea9446bba5171aa399d709eede2a0403949e96015157aa0ab1db320834a0f`
- `live.js`: `cdc44f514b1f396799313c977a4a48fe8efad33ae1f6054db776682c977796aa`

## Source recovery / persistent artifact

GitHub reconstruction:

```bash
node apps/raahi-learning/build-source-v13.mjs
```

Verified immutable base tar:

`9aa71d002775f719970fcf6d48c324f4f3270ac9f65aa1c7e8a2f9f17c2dc9cc`

Verified retrofit patch:

- gzip SHA-256: `8a68163024ef1b100ebc4d56b8b1cfa56bf3459fc9f897952b6ca5602a19afa9`
- raw SHA-256: `ced0f5ca5b590e8ca344011f8f008c8fa719d57cca6ca3ead63b01a4fc6efc08`

Persistent ChatGPT Library backup:

`/Raahi Learning/Raahi_Learning_Integrated_V1.3_DEV.zip`

ZIP SHA-256:

`379dece3fb33fadd68843823a82917469b77e39b8d24448328b713ff98b246ef`

## Current execution gate

**Resume at release/reliability readiness. Do not redo SE-01 through SE-08, combined regression, or the bounded Class race/recovery/shared-browser proof.**

Current exact state:

- all side-effect gaps SE-01 through SE-08 are closed;
- doc 68 remains the 15-suite post-SE-08 combined-regression anchor on `a9f7ae5...`;
- stronger committed-response recovery and stale-session proof passed at `ccb1721...`;
- bounded recovery/shared-browser product proof commit is `d0232c4fdb9410d4902063740974b7110da59473`;
- exact-SHA Model Tests, Class Race Recovery, DEV E2E Harness and UI Convergence Core all passed for `d0232c4...`;
- the first exact-build post-1032 DEV anchor was `945bdf9f7fbcabbd4eb05c627800381b65c5f54b`; later source-compatible docs/test commits can advance `build-meta`, so read it at execution time;
- bounded Release Reliability run `35442347699` passed on `10111144a2d00fb28d02a4217c4225a5188673b6`: 20 genuine sessions/accounts, 800 authenticated steady-state reads, all 20 cross-account denial checks, and 20 browser sign-ins with no latency warnings;
- post-reliability DB health snapshot found 0 waiting locks, 0 transactions over 30 seconds and 0 recorded deadlocks; repeatable read-only checks live in `scripts/raahi-learning-release-health.sql`;
- migration 1032 reverse/recreate SQL was rehearsed inside a rolled-back DEV transaction and both real indexes remained intact afterward;
- the shared-browser flow now proves persisted-session reload, cross-tab sign-out privacy, second-Account sign-in and rejection of the first Account's copied private Class-thread link;
- private Class-thread cache is account/session isolated and guarded against late responses from a previous session;
- release packaging has offline guard tests but is not a production qualification;
- DEV migration ceiling is `1038_v13_remove_public_trust_policy_rpc`;
- migration 1033 removed the unusable anonymous EXECUTE grants from `list_public_locations()` and its private helper, consistent with deferred anonymous marketplace browsing;
- DEV E2E run `35445058520` on exact commit `486bcb9...` proves `deferred_anonymous_location_rpc_denied`, genuine sessions, RLS allow/deny and browser sign-ins still pass;
- catalog audit currently finds 0 public tables without RLS, 0 public views, 0 public SECURITY DEFINER RPCs, 0 PUBLIC/anon RPC execute grants, 0 private SECURITY DEFINER PUBLIC/anon execute grants, 0 direct authenticated operational-table DML grants and 0 `auth.role()`/user-metadata authorization patterns;
- the two former unindexed-FK advisor findings are closed; unused-index informational notices remain and must not be treated as automatic removal instructions;
- Supabase Security Advisor still reports `auth_leaked_password_protection` disabled;
- `dev-test-identities` remains ACTIVE at version 16;
- guarded production-like load harness + manual-only workflow are prepared and reject both existing Supabase projects;
- guarded non-DEV production canary is prepared;
- database and Storage backup scripts are prepared with secret-free manifests and restore_verified=false;
- recovery inventory script executed successfully on DEV at migration 1033 and provides the source baseline for future restore comparison;
- current Supabase cost quote: branch USD 0.01344/hour; new project USD 0/month; no resource has been created because explicit cost confirmation is required;
- Supabase Dashboard read-only inspection is blocked by expired browser authentication/hCaptcha; no setting was changed;
- no dedicated Learning production Supabase project has been selected;
- no public deployment is authorized.

Current milestone: **STAGE READY — GOOGLE-ONLY CONTROLLED PILOT BASELINE**.

Canonical new-chat handover: `86-public-origin-google-oauth-proof-2026-09-20.md`.

The pre-change Stage Ready evidence remains historical in doc 80. Fresh post-change closure is doc 82 and is now the canonical launch baseline.

Current approved behavior:
- controlled pilot uses Google only;
- no pilot phone/WhatsApp prompt;
- MessageCentral is sealed/dormant;
- future WhatsApp OTP is post-traction work.

Next work:
- production Google OAuth project/client + real public-origin sign-in proof;
- prepare public pilot origin `https://learning.myraahi.co.in`;
- then execute controlled-pilot cutover.

User-controlled / external gates:
- public pilot origin: **https://learning.myraahi.co.in**;
- production Google OAuth project/client and domain/branding configuration;
- `support@myraahi.co.in` is active on Zoho Mail Free with live MX/SPF/DKIM and proven two-way delivery;
- explicit Rajeev approval immediately before public Gomoh + Dhanbad launch.

A dedicated WhatsApp business SIM, Meta production phone registration and OTP template approval are intentionally **not** pilot launch gates.

Approved environment strategy:

**Learning DEV → Stage Ready → same-project controlled pilot (Gomoh + Dhanbad) on Free Supabase → paid isolated production after traction.**

Do not create a paid Supabase branch/project merely to reach the first controlled pilot. Do not repurpose the Where Is My Raahi project.
