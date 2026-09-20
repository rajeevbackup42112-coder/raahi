# Raahi Learning V1.3 — Handover / Current State

**Read this file first in a new conversation.**

Repository: `rajeevbackup42112-coder/raahi`  
Implementation branch: `raahi-learning-implementation-v1`  
Canonical docs: `docs/raahi-learning/`

> This branch is isolated from older Raahi ride work on `main`. Do not replay mobility migrations or overwrite the older commute app.

## Current status

**Foundation, R4, genuine-session testing, the 20-persona cohort, workspace convergence, SE-01 through SE-08, post-SE-08 combined regression, bounded Class race/recovery/shared-browser security, and a bounded release-reliability smoke are proven in DEV. The stable recovery/shared-browser product-code proof anchor is `d0232c4fdb9410d4902063740974b7110da59473`. Release Reliability run `35442347699` on `10111144a2d00fb28d02a4217c4225a5188673b6` passed 20 genuine personas, 800 authenticated reads, 20 cross-account denial checks and 20 browser sign-ins with no latency warnings. DEV migration ceiling is now `1038_v13_remove_public_trust_policy_rpc`. `build-meta.json` may advance across source-compatible documentation/test commits, so always read it at execution time rather than pinning a non-app SHA as permanent current product state. Production-scale/soak, operational alert delivery, DB+Storage restore, real-provider smoke, production infrastructure and launch gates remain open. See docs 68–76.**

Supabase DEV project: `iiwwmqokaeflaenhlyip`, region `ap-south-1`.

The old 2026-09-13 zero-Auth preflight is historical only. Real hosted Google/phone identities now exist, Auth→Account continuity is proven, the original Rajeev R4 phone-interruption/resume chain remains durable, and the final Class-message / notification / copied-link privacy boundary is autonomously proven in isolated cloud browsers. The normal regression foundation now uses DEV-only OIDC-protected test identities with genuine Supabase sessions and intact RLS. See `50-dev-test-identity-session-harness-v1.3.md`, `51-hosted-auth-r4-walking-skeleton-closure-v1.3.md`, and `52-master-lifecycle-gates-traceability-v1.3.md`.

Do **not** restart product design, rebuild the database, continue random bug fixing, or deploy publicly.

Read next:

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
