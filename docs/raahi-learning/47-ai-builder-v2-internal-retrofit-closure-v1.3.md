# Raahi Learning V1.3 — AI Builder v2 Retrofit Closure / Auth + Walking-Skeleton Handover

**Status:** CURRENT CANONICAL EXECUTION CHECKPOINT. The one-time AI Builder Cheat Code v2 internal retrofit is closed. Do **not** restart product design, continue random bug hunting, or resume horizontal feature building. The next substantive gate is real hosted Auth proof, followed immediately by the mandatory walking skeleton.

Repository: `rajeevbackup42112-coder/raahi`  
Branch: `raahi-learning-implementation-v1`  
Supabase DEV project: `iiwwmqokaeflaenhlyip`  
Region: `ap-south-1`

No public deployment has been performed.

---

## 1. Frozen product rules

Do not reopen these without concrete evidence of contradiction, security/privacy defect, regulatory requirement, failed real E2E/usability evidence, pilot evidence, or technical impossibility:

- `Account ≠ Learner`; Learner owns learning history.
- One Account may learn, teach, manage a Learner and represent an Organization.
- One active managing guardian per Learner in V1.
- No turning-18 migration/lifecycle.
- No public Learner directory.
- Active learner-side authority owns formal marketplace/Class decisions; guardian management never grants Test-taking impersonation.
- Direct discovery / Learning Request converge on controlled Enquiry.
- Approved relationship flow: `Enquire → optional Trial → Class Invitation → Join → Membership`.
- Pending Class Invitation reserves capacity.
- One responsible Teacher per Class in V1.
- Activity unifies Assignment / Practice / Exercise.
- Tests remain separate and strict.
- No attendance, generic progress percentage, public ratings/reviews, unrestricted DM, global Community, institute ERP/payroll, or platform tuition-payment collection.
- Community remains local/authenticated.
- Ads remain education-only, Sponsored-labelled, aggregate-only for advertisers and excluded from Class/Activity/Test/private-message learning surfaces.
- UI/workspace selection is never authorization.
- PostgreSQL is operational source of truth.
- Consequential transitions go through canonical RPCs; browser UI does not directly mutate core operational tables.
- Realtime only invalidates/refetches.
- Private Storage authorization is rechecked server-side.

The principal V1.3 amendment remains **Google-primary authentication + selective periodic phone trust**.

---

## 2. AI Builder v2 retrofit result

The retrofit did **not** find a need to redesign the domain model. It found finite cross-layer integration/test gaps, which were classified and closed rather than used as excuses to alter frozen product rules.

Companion retrofit artifacts:

- `44-ai-builder-v2-retrofit-gate-v1.3.md`
- `45-v1.3-screen-backend-contract-audit.md`
- `46-v1.3-side-effects-matrix-audit.md`

### Screen ↔ Backend / permission-symmetry closure

Closed without weakening server authorization:

- real `teacher-members` renderer + route-specific data loading;
- correct Community report target type/id rather than silently targeting the current Class;
- previously omitted reachable `community-post` route added to browser inventory;
- capability-aware Organization UI for `manage_profile`, `manage_teaching_options`, `manage_classes`, `manage_members`, `manage_ads`;
- notification rows open a safe authorized destination rather than only supporting mark-read;
- private Learner/staff invitation bearer tokens are preserved same-origin for Auth continuation and removed from the visible Google OAuth redirect URL;
- browser/test oracle now rejects generic fallback pages instead of accepting any page with a heading.

### Side-effects audit closure

The side-effects matrix explicitly records notification/audit/Storage/deep-link behavior and intentional `none` decisions.

Important remaining attention signals identified for later owning vertical slices include selected Trial/Session changes, Activity submission/review events, major Membership changes, and already-released Test-result corrections. These were intentionally **not** implemented as a horizontal notification project before the walking skeleton.

---

## 3. Current backend state

V1.2 backend remains complete. V1.3 forward migrations applied in DEV:

- `1015_v13_contextual_inbox_and_org_teacher_picker`
- `1016_v13_learner_self_access_invitations`
- `1017_v13_organization_member_invitations`
- `1018_v13_notification_transition_wiring`
- `1019_v13_notification_initial_enquiry_dedup`
- `1020_v13_phone_trust_projection`
- `1021_v13_phone_trust_command_guards`

### V1.3 runtime markers proven

- `V13_CONTEXTUAL_INBOX_ORG_PICKER_PASS`
- `V13_LEARNER_SELF_ACCESS_INVITATION_PASS`
- `V13_ORGANIZATION_MEMBER_INVITATION_PASS`
- `V13_NOTIFICATION_TRANSITION_WIRING_PASS`
- `V13_PHONE_TRUST_PROJECTION_PASS`
- `V13_PHONE_TRUST_COMMAND_GATE_CORE_PASS`
- `V13_PHONE_TRUST_COMMAND_GUARDS_PASS`

Touched frozen V1.2 suites rerun successfully after V1.3 notification/guard work include:

- `REQUESTS_ENQUIRIES_RUNTIME_TESTS_PASS`
- `CLASS_COMMUNICATION_RUNTIME_TESTS_PASS`
- `ACTIVITIES_SUBMISSIONS_RUNTIME_TESTS_PASS`
- `TESTS_ATTEMPTS_RUNTIME_TESTS_PASS`

Latest Supabase Security Advisor after migration 1021: **0 findings**.

### Phone-trust implementation already resolved

Do **not** add a duplicate Raahi `phone_trust_verified_at` column.

Supabase Auth's server-owned `auth.users.phone_confirmed_at` is the durable trust clock. Migration 1020 derives `unverified / stale / fresh` using the frozen 90-day window. Migration 1021 gates only selected trust-creating/escalating commands.

Proven policy behavior includes:

- stale phone blocks a new trust-sensitive command;
- fresh phone allows it;
- already-completed idempotent command retries still return their cached result after later staleness;
- protective/de-escalating actions remain available while stale where frozen policy requires that;
- ordinary existing Class/learning/Test/safety access is not intentionally removed merely because phone trust becomes stale.

What remains unproved is the **real hosted phone verification browser round trip** that updates this Auth evidence.

---

## 4. Current frontend/browser checkpoint

The latest persisted V1.3 integration includes the AI Builder v2 retrofit delta.

### Browser evidence

- reachable routes under test: **84**;
- desktop + mobile contract: **84 × 2 = 168/168 PASS**;
- contract issues: **0**;
- route/workspace guard failures: **0**;
- focused V1.3 action contracts: **12/12 PASS**;
- privileged deep-link guard cases: **32/32 PASS**;
- semantic checks: **15/15 PASS**;
- legacy workspace matrix after V1.3 oracle correction: **154/154 PASS**;
- interaction suite: **26/26 PASS**;
- no direct browser DML against operational tables;
- no phone-primary login path in `live.js`;
- no raw Account-UUID ordinary-user workflow.

The only browser-test failures encountered during this retrofit after application fixes were classified as **test/harness defects** (including opaque-origin `sessionStorage` behavior and the old 77-route workspace matrix). Product rules were not weakened to make those tests pass.

### Frozen byte anchors

- `app.fixture.js` SHA-256: `6eb67b36931c45aa4113c77005d82c13bb14ec145500e08cfd92130ebcef576c`
- `styles.css` SHA-256: `b2d89e454f8e13712d10058c876f5efe2c8c69acf73dd6aade158241900f7bdd`

Current retrofit source anchors verified by `build-source-v13.mjs` include:

- `app.live-core-v13.js`: `b8fea9446bba5171aa399d709eede2a0403949e96015157aa0ab1db320834a0f`
- `live.js`: `cdc44f514b1f396799313c977a4a48fe8efad33ae1f6054db776682c977796aa`
- `tests/cdp-v13-actions.mjs`: `612e8d5e404c9c84b8e3dd441cf863bae3aa1bc8d9d7e73aa6deef812b2d215f`
- `tests/cdp-live-contract.mjs`: `056788dcfa5c431b25385e7912bb24136d6d63f95bafc8a4bd48d8a22fe39acf`

---

## 5. Reproducible source + persistent artifact

Canonical GitHub recovery command:

```bash
node apps/raahi-learning/build-source-v13.mjs
```

Recovery model:

1. reconstruct immutable original V1.3 base tar;
2. verify base tar SHA-256;
3. decode verified retrofit patch;
4. verify compressed and decompressed patch SHA-256;
5. apply patch;
6. verify all listed current source-file hashes.

Integrity anchors:

- original V1.3 base tar SHA-256: `9aa71d002775f719970fcf6d48c324f4f3270ac9f65aa1c7e8a2f9f17c2dc9cc`
- retrofit patch gzip SHA-256: `8a68163024ef1b100ebc4d56b8b1cfa56bf3459fc9f897952b6ca5602a19afa9`
- retrofit patch raw SHA-256: `ced0f5ca5b590e8ca344011f8f008c8fa719d57cca6ca3ead63b01a4fc6efc08`

Independent ChatGPT Library backup:

`/Raahi Learning/Raahi_Learning_Integrated_V1.3_DEV.zip`

Latest ZIP SHA-256:

`379dece3fb33fadd68843823a82917469b77e39b8d24448328b713ff98b246ef`

Do not treat the older `c1acb034...` ZIP as the current retrofit artifact.

---

## 6. Exact remaining external technology gate

The connected Supabase tooling can manage database/migrations/Edge operations but does not expose the hosted Auth provider/test-OTP configuration needed for this proof. A connected authenticated remote browser was also not available at the latest checkpoint.

Therefore **do not claim these steps have passed yet**.

### Google Auth proof

Prove with real hosted DEV configuration:

1. Google provider enabled for DEV Supabase Auth.
2. Browser `signInWithOAuth({ provider: 'google' })` round trip succeeds.
3. Returned Supabase Auth identity maps through `bootstrap_account` to exactly one Raahi Account.
4. Logout/login with the same Google identity returns the same Account/history.
5. Google display name/photo remain editable onboarding suggestions only and grant no authority.
6. Wrong-Google-account/recovery behavior is observed deliberately.

### Phone proof

Using supported hosted DEV SMS/test-OTP configuration, prove:

1. signed-in Google user can attach/verify a phone;
2. successful verification updates trusted server-owned Auth confirmation evidence;
3. same-phone periodic re-verification refreshes `auth.users.phone_confirmed_at` as expected;
4. stale→fresh status is visible through the migration-1020 projection;
5. no Raahi fake-OTP bypass exists.

If actual provider behavior contradicts the current assumption, classify that as a **technology-proof failure** before changing product rules.

---

## 7. Mandatory next gate: one real walking skeleton

Once real hosted Auth is configured, do **not** return to horizontal feature development. Execute this complete DEV journey first with synthetic identities.

### Guardian/Learner side

1. Real Google sign in.
2. Supabase session established.
3. `bootstrap_account` resolves/creates exactly one Raahi Account.
4. First-use intent creates/selects the Learner context through canonical commands.
5. Discovery projection loads.
6. Send Enquiry through canonical RPC.

### Provider side

7. Distinct provider signs in with a real Auth identity.
8. Provider sees the Enquiry through authorized projections.
9. Provider engages/responds.
10. Provider sends Class Invitation.

### Learner side

11. Learner-side Account sees the real Notification/deep link.
12. Invitation acceptance encounters stale/missing phone trust where intended.
13. Intended action is preserved.
14. Real phone verification succeeds.
15. The exact Invitation acceptance resumes.
16. Server rechecks current authority, invitation state and capacity.
17. Membership is created.
18. Both sides open the Class through authorized projections.
19. One contextual Class message is exchanged.
20. Refresh/logout/login does not lose the resulting state.

Required boundaries must all be real:

`browser → hosted Supabase Auth → authorized projection → canonical RPC → PostgreSQL → side effect/notification → browser`

No fixture business result may substitute for a real layer in this test.

---

## 8. After the walking skeleton

Only after the walking skeleton passes:

1. continue one vertical slice at a time;
2. close side-effect gaps inside their owning slice, not as a horizontal notification project;
3. run whole-story persona/adversarial E2E including new users, parents, self-access learners, teachers, multi-capability users, limited institute staff, invite recipients, managers/admins, wrong Google account, stale/changed phone, shared device, revoked authority, replayed invite, concurrent last seat, copied private file URL, direct DML and weak-network retries;
4. run true concurrency/load/soak/security/Storage/provider-failure gates;
5. perform production OAuth/SMS/env/secrets review and synthetic cleanup;
6. issue explicit go/no-go.

Do not deploy implicitly.

---

## 9. Defect handling rule

Every significant future failure is classified before changing design:

- **Domain defect** → full impact analysis: `rules → entities → relationships → states → permissions → UI → tests → architecture/DB`.
- **Integration defect** → repair the contract between valid layers.
- **Implementation defect** → smallest vertical-slice code fix + regression.
- **Test/harness defect** → fix the test; never weaken a business invariant to turn it green.

---

## 10. Exact continuation instruction for a new chat

> Continue Raahi Learning from repository `rajeevbackup42112-coder/raahi`, branch `raahi-learning-implementation-v1`. Read `docs/raahi-learning/47-ai-builder-v2-internal-retrofit-closure-v1.3.md` first, then `99-handover.md`, `44-ai-builder-v2-retrofit-gate-v1.3.md`, `45-v1.3-screen-backend-contract-audit.md`, `46-v1.3-side-effects-matrix-audit.md`, `41-authentication-phone-trust-v1.3.md` and `07-decision-log-v1.md`. Do not restart product design, do not randomly hunt bugs and do not add broad new features. The AI Builder v2 internal retrofit is closed: 84 reachable routes / 168 desktop+mobile checks pass, focused actions 12/12 pass, migration 1021 public phone-trust guards pass, Security Advisor is 0, and the current Library artifact SHA is `379dece3fb33fadd68843823a82917469b77e39b8d24448328b713ff98b246ef`. The next substantive gate is real hosted DEV Google OAuth + real hosted phone verification proof; after that execute the mandatory real walking skeleton Google → Account/bootstrap → Learner context → discovery → Enquiry → provider engage → Invitation → phone interruption/resume → Membership → Class → contextual message. Only after the walking skeleton passes continue by vertical slice. Do not add fake OTP and do not deploy publicly.
