# Raahi Learning V1.3 — Current Execution Handover — 2026-09-20

Status: **STAGE READY — GOOGLE-ONLY CONTROLLED-PILOT BASELINE**
Purpose: exact continuation point for a new ChatGPT conversation. Do not restart planning or redo closed work.

---

## 0. Resume instruction for the next chat

Continue **Raahi Learning V1.3** from this exact handover state.

Do **not** restart product planning, redesign the product, recreate the database, redo completed slices, re-open frozen rules casually, or deploy publicly without explicit approval.

Use connected GitHub + Supabase directly and verify the current state read-only before changing anything.

Working style:

- keep going autonomously until a genuine user-held/external decision or credential action is required;
- do not ask approval for routine code/docs/DEV technical changes;
- do not silently change frozen business rules;
- if a contradiction is found, classify it first as Domain / Integration / Implementation / Test-Harness;
- only a Domain defect reopens:
  rules → entities → relationships → states → permissions → UI → tests → architecture/DB;
- UI never directly mutates core operational tables;
- consequential writes go through canonical RPCs;
- PostgreSQL remains source of truth;
- Realtime only invalidates/refetches;
- do not publicly deploy or admit real users without explicit Rajeev go-live approval.

---

## 1. Project identifiers

Repository:
`rajeevbackup42112-coder/raahi`

Implementation branch:
`raahi-learning-implementation-v1`

Current branch HEAD at handover:
`b061da421632c415c3bae12df311c25874e44f31`
message: `Link production Google OAuth preparation`

Supabase Learning project used for DEV → Stage → controlled pilot:
`iiwwmqokaeflaenhlyip`

Region:
`ap-south-1`

DEV origin:
`https://dev.learning.myraahi.co.in`

Planned public controlled-pilot origin:
`https://learning.myraahi.co.in`

Separate project that must NEVER be repurposed for Learning:
`hoshprxoyhjyyigxkang`
(Where Is My Raahi)

Approved environment strategy:

**Learning DEV → Stage Ready → same-project controlled pilot (Gomoh + Dhanbad) on Free Supabase → paid isolated production after traction.**

Do not create a paid Supabase project merely to reach the first controlled pilot.

---

## 2. Read these documents first, in order

1. `docs/raahi-learning/84-current-execution-handover-2026-09-20.md` — **this exact handover**
2. `docs/raahi-learning/83-production-google-oauth-preparation-v1.3.md` — **next external gate and exact OAuth values**
3. `docs/raahi-learning/82-stage-ready-google-only-pilot-closeout-v1.3.md` — **current Stage Ready closure + proof set**
4. `docs/raahi-learning/81-controlled-pilot-google-only-trust-v1.3.md` — **current pilot trust rule + impact analysis**
5. `docs/raahi-learning/78-controlled-pilot-cutover-runbook-v1.3.md` — **exact controlled-pilot cutover procedure**
6. `docs/raahi-learning/76-single-project-stage-controlled-pilot-strategy-v1.3.md`
7. `docs/raahi-learning/52-master-lifecycle-gates-traceability-v1.3.md`
8. `docs/raahi-learning/99-handover.md`

Historical only:

- `80-stage-ready-closeout-v1.3.md` — pre-Google-only Stage closure; superseded by doc 82.
- `79-messagecentral-phone-trust-provider-v1.3.md` — retired MessageCentral experiment; not current pilot provider.

---

## 3. Current Stage Ready conclusion

Raahi Learning V1.3 is **Stage Ready** again after the approved Google-only pilot change.

Canonical closeout:
`82-stage-ready-google-only-pilot-closeout-v1.3.md`

Final validated app-source commit:
`61fd03555910cb16f744d653317c31986e1039cd`

The current branch HEAD is later only because docs were added/linked after that proof. Model tests remain green on current HEAD.

Final exact current-source proof set on `61fd0355`:

- Model Tests run `35467717423` — PASS
- DEV genuine-session E2E run `35467717381` — PASS
- UI Core Learner/Teacher run `35467717405` — PASS
- UI Parent/Organization run `35467717378` — PASS
- UI Privileged/Admin run `35467717353` — PASS
- UI Ads run `35467717394` — PASS

Additional post-change sensitive proof:

- Organization Staff Boundaries run `35467402738` — PASS
- Organization Authority Side Effects run `35467397044` — clean rerun PASS
- Activity/Class/Test/Enquiry side-effect suites — green on Google-only baseline

Current HEAD model run:
- `35477835725` — PASS on `b061da42`

Do not re-run broad suites merely because a new chat started. Verify current HEAD/state first and continue from here.

---

## 4. Current database / Supabase state

Latest migration:

`20260919202746 / 1038_v13_remove_public_trust_policy_rpc`

Current trust setting:

`phone_trust_mode = controlled_pilot_google_only`

Current phone trust enforcement:

`false`

This is intentional for the first controlled pilot.

Current Locations:

- Dhanbad = `live`
- Gomoh = `preparing`

Do **not** make Gomoh live before the controlled-pilot cutover.

Current Storage object count:
`0`

Current security catalog at handover:

- public tables without RLS = 0
- public tables without FORCE RLS = 0
- public views = 0
- public SECURITY DEFINER functions = 0
- app_private SECURITY DEFINER functions executable by PUBLIC = 0
- app_private SECURITY DEFINER functions executable by anon = 0

Security Advisor:
- only known Free-plan warning: leaked-password protection disabled.

Performance Advisor:
- unused-index INFO notices only; do not remove young-system indexes simply because DEV has not used them yet.

---

## 5. Current authentication rule — IMPORTANT

### Controlled pilot

**Google sign-in only.**

For the first Gomoh + Dhanbad controlled pilot:

- do not ask users for phone verification;
- do not ask for SMS OTP;
- do not ask for WhatsApp OTP;
- Google authentication is sufficient;
- phone trust is NOT marked fresh;
- the phone-trust prerequisite is temporarily dormant under the explicit server-side pilot mode;
- all role/ownership/RLS/state/capacity/audit/idempotency checks remain unchanged.

This is NOT a fake OTP bypass.

It is an explicit product rule for the controlled pilot.

### Future direction after traction

Preferred mature model:

**Google primary sign-in → normal use → selected sensitive action → WhatsApp OTP → 90-day phone trust → resume action**

Do not turn OTP into a second login on every session.

Current preferred future provider:
**direct Meta WhatsApp Business Platform Cloud API**

---

## 6. Meta WhatsApp work already completed

Meta test environment proof is complete:

- My Raahi Meta developer app created;
- WhatsApp use case connected to My Raahi Business Portfolio;
- Meta-generated test business number provisioned;
- user recipient phone verified;
- test WhatsApp message successfully received.

Production setup was intentionally paused before adding a real business phone number.

A dedicated My Raahi SIM/business number is **not** a first-pilot launch dependency.

Do not continue Meta production setup during the initial Google-only pilot unless the user explicitly changes strategy.

---

## 7. MessageCentral state — retired

MessageCentral was technically integrated, but real onboarding exposed a **₹4,999 minimum recharge**, which is disproportionate for the pilot.

Current decision:
**Do not use MessageCentral for the controlled pilot.**

Deployed function:
`phone-trust-messagecentral`

Current deployed version:
`6`

Current source:
`supabase/functions/phone-trust-messagecentral/pilot-disabled-index.ts`

Behavior:
- verify_jwt = true
- always HTTP 410
- error:
  `PHONE_PROVIDER_DISABLED_DURING_GOOGLE_ONLY_PILOT`
- no outbound SMS call
- no OTP validation
- no Auth/database trust mutation

Old MessageCentral secrets were added to Supabase during evaluation.
They are unused by the sealed function and should be removed before public cutover.
Do not expose them in chat/source control.

---

## 8. DEV synthetic writer / identity state

DEV identity factory:

`dev-test-identities`

Current state:
- ACTIVE
- version 17 at handover
- still mutation-capable for Stage/test work

Prepared sealed replacement exists:
`supabase/functions/dev-test-identities/pilot-sealed-index.ts`

Do **not** deploy the seal until controlled-pilot cutover.

DEV writer marker:

`.github/RAAHI_LEARNING_DEV_WRITES_ENABLED`

All known synthetic writer workflows fail closed if the marker is removed.

At pilot cutover:
- remove the marker;
- seal automatic synthetic writers;
- deploy sealed identity factory;
- never recreate the writer marker once real pilot data enters, unless the project returns to a fully synthetic-only state.

---

## 9. Synthetic data cleanup readiness

Prepared public-domain cleanup:

`scripts/raahi-learning-pilot-clean-public-domain.sql`

Prepared Auth harness cleanup:

`tests/raahi-learning-e2e/pilot-delete-harness-auth.mjs`

The cleanup has been transactionally rehearsed with rollback.

The public-domain cleanup:
- preserves `public.locations`;
- removes synthetic application-domain data;
- includes `phone_trust_challenges`;
- preserves reviewed genuine/non-harness Auth identities;
- requires exact confirmation;
- fails closed on schema/state assumptions.

Harness Auth deletion:
- deletes only users with authoritative metadata `raahi_test_harness=true`;
- preserves genuine/non-harness identities.

Do not execute final cleanup before cutover backup + writer seal sequence.

---

## 10. Frozen product behavior still unchanged

Except for the explicit pilot trust-mode decision, the existing business/domain baseline remains frozen.

Key invariants:

- Account ≠ Learner; Learner owns learning history.
- One Account may learn, teach, manage Learner, represent Organization.
- One active managing guardian per Learner in V1.
- No turning-18 lifecycle/migration.
- Active manager owns formal learner-side marketplace/relationship decisions where present; otherwise self-access may act.
- Guardian cannot impersonate Learner for Tests.
- No public Learner directory.
- Discovery/Learning Request → controlled Enquiry; Trial optional inside Enquiry.
- Pending Class Invitation reserves capacity; Membership begins on acceptance.
- One responsible Teacher per Class.
- Activity unifies Assignment/Practice/Exercise.
- Test definition locks at first valid Attempt; guardian has oversight only.
- Selected Location changes discovery/community, not private Classes/Messages/history.
- Community local/authenticated only; no global Community or unrestricted DM.
- No attendance, generic progress %, public ratings/reviews, ERP/payroll, platform tuition-payment collection.
- Ads education-only, clearly Sponsored, aggregate-only advertiser data, excluded from private/class/test surfaces.
- UI/workspace selection never grants authority.
- UI never directly mutates core operational tables; consequential writes use canonical RPCs.
- PostgreSQL is source of truth; Realtime only invalidates/refetches.

---

## 11. Branding / public presentation state

Branding is approved for pilot.

Keep:
- Raahi Learning name;
- purple/white visual system;
- orange avatar accents;
- current simple Raahi mark;
- anonymous tagline:
  `LOCAL LEARNING. ONE PLACE AT A TIME.`
- signed-in learner headline:
  `Learn locally. Keep learning together.`

Launch polish already closed:
- no raw operational JSON on Manager/Platform overview;
- readable metric cards;
- public consumer-facing copy;
- Privacy page;
- Terms page;
- raw enum/internal terminology cleanup;
- escaped-newline presentation artifact fixed;
- CI guards prevent raw Manager/Platform JSON from returning.

Public policy files:
- `apps/raahi-learning/privacy.html`
- `apps/raahi-learning/terms.html`

Support address:
`support@myraahi.co.in`

This mailbox must be functional before public launch.

---

## 12. Controlled-pilot release packaging

Release builder:
`scripts/prepare-learning-release.mjs`

Modes:

### CONTROLLED_PILOT

Requires:
- exact confirmation `CONTROLLED_PILOT_SAME_PROJECT`;
- exact Learning Supabase ref `iiwwmqokaeflaenhlyip`;
- public non-DEV HTTPS origin.

Pilot release configuration:
- `phoneTrustMode = controlled_pilot_google_only`
- `phoneTrustProvider = disabled`

### NON_DEV

Dedicated future production packaging remains fail-closed:
- `phoneTrustMode = phone_trust_required`
- provider remains disabled until a real provider is explicitly proven.

This prevents the temporary Google-only pilot relaxation from silently becoming permanent production behavior.

---

## 13. Controlled-pilot canary

File:
`tests/raahi-learning-e2e/production-canary.mjs`

CONTROLLED_PILOT mode:
- requires exact confirmation `CONTROLLED_PILOT_SAME_PROJECT`;
- requires exact Learning ref `iiwwmqokaeflaenhlyip`;
- rejects Where Is My Raahi project;
- rejects DEV web origin;
- requires HTTPS;
- requires publishable key;
- requires exact target binding;
- requires distinct identities.

Do not run until the public origin exists and final real Google auth is configured.

---

## 14. Answer to the user's last unresolved question

User asked:

> “shall we change our existing Raahi Learning to prod?”

Interpretation in current context:
the existing **Google OAuth testing project/client**.

Current recommendation:

**No. Do not convert/reuse the existing Google testing project as the production OAuth project.**

Keep:
- existing Google testing project/client for DEV/test;
- current Learning Supabase project for DEV → Stage → controlled pilot.

Create:
- a separate **Google Cloud production project/client** for public OAuth.

Recommended production Google Cloud project:
**Raahi Learning Production**

Recommended OAuth app:
**Raahi Learning**

Recommended Web OAuth client:
**Raahi Learning Production Web**

This follows the Google production-readiness approach previously verified during this project: separate testing and production Google Cloud projects/clients.

This separation is about Google OAuth credentials.
It does **not** change the approved same-Supabase-project controlled-pilot strategy.

---

## 15. Exact next external gate — production Google OAuth

Canonical preparation:
`docs/raahi-learning/83-production-google-oauth-preparation-v1.3.md`

The user's connected Desktop Commander device was online and Google Auth Platform was opened before this handover.

The next chat should first ask/inspect what screen the user is currently on, not restart setup.

Production Google OAuth values:

### Google Cloud project

Name:
**Raahi Learning Production**

Audience:
**External**

Scopes only:
- `openid`
- `userinfo.email`
- `userinfo.profile`

Do not request Gmail, Drive, Calendar or other sensitive scopes.

### Branding

App name:
**Raahi Learning**

Homepage:
`https://learning.myraahi.co.in/`

Privacy:
`https://learning.myraahi.co.in/privacy.html`

Terms:
`https://learning.myraahi.co.in/terms.html`

Authorized domain:
`myraahi.co.in`

Support email:
`support@myraahi.co.in`

### Web OAuth client

Client name:
**Raahi Learning Production Web**

Authorized JavaScript origin:
`https://learning.myraahi.co.in`

Authorized redirect URI:
`https://iiwwmqokaeflaenhlyip.supabase.co/auth/v1/callback`

Do NOT add DEV origin/localhost/unrelated Raahi origins to the production client.

Do not send the Google Client Secret through chat.

Final branding verification may require public homepage/privacy/terms to be live first.

---

## 16. Next execution sequence to launch

Once the production Google Cloud project/client is created:

1. retain Client ID + Secret securely;
2. prepare public `learning.myraahi.co.in` artifact/hosting;
3. ensure homepage + privacy + terms are reachable;
4. ensure `support@myraahi.co.in` works;
5. complete required Google production branding/domain verification;
6. configure production Google Client ID/Secret directly in Supabase Auth;
7. configure Supabase Site URL / allowed redirects for `https://learning.myraahi.co.in`;
8. run real Google sign-in proof on the public origin;
9. freeze the release commit;
10. take off-platform DB backup;
11. take Storage backup;
12. remove retired MessageCentral secrets;
13. execute final public-domain synthetic cleanup;
14. delete harness Auth users;
15. remove DEV writer marker / seal writers;
16. deploy sealed `dev-test-identities`;
17. package/deploy controlled-pilot artifact;
18. switch Gomoh `preparing → live`;
19. verify only Dhanbad + Gomoh are live;
20. run CONTROLLED_PILOT canary;
21. stop and obtain explicit Rajeev go-live approval;
22. only then admit real users.

---

## 17. Things NOT to do yet

- Do not buy a new WhatsApp SIM for the first pilot.
- Do not continue Meta WhatsApp production setup.
- Do not reactivate MessageCentral.
- Do not require phone verification in the first pilot.
- Do not execute synthetic cleanup yet.
- Do not delete harness Auth users yet.
- Do not remove the DEV writer marker yet.
- Do not seal `dev-test-identities` yet.
- Do not switch Gomoh live yet.
- Do not run the controlled-pilot canary yet.
- Do not admit real users yet.
- Do not publicly deploy without explicit user approval.
- Do not create a paid Supabase project merely for the pilot.
- Do not repurpose `hoshprxoyhjyyigxkang`.
- Do not turn OTP into routine login after the pilot.

---

## 18. What the next chat should say/do first

First:
- read this doc and docs 83, 82, 81, 78;
- verify repo HEAD and Supabase migration/trust/location state read-only;
- confirm there is no unexpected drift;
- determine which Google Auth Platform screen the user is currently on.

Then continue the production Google OAuth setup field-by-field.

Do not ask the user to repeat project context.

Do not ask for routine approval.

Do not ask for or expose the Google Client Secret.

Stop only when a genuinely user-held account/security action is required or immediately before public go-live.
