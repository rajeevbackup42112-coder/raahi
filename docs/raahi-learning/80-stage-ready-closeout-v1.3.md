# Raahi Learning V1.3 — Stage Ready Closeout

Status: **STAGE READY**  
Date: 2026-09-19

This document freezes the evidence boundary immediately before real-provider onboarding and controlled-pilot cutover.

## 1. Stage Ready decision

Raahi Learning V1.3 is now **Stage Ready** for the approved lifecycle:

**Learning DEV → Stage Ready → same-project controlled pilot (Gomoh + Dhanbad) on Free Supabase → paid isolated production after traction.**

Stage Ready does **not** mean public launch has occurred.

Still prohibited at this point:

- admitting real public users;
- switching Gomoh from `preparing` to `live`;
- final synthetic/public-domain cleanup;
- deleting harness Auth users;
- removing the DEV writer marker;
- sealing the DEV identity factory;
- deploying the public pilot origin;
- running the controlled-pilot production canary;
- claiming real MessageCentral delivery proof before provider credentials and real-phone testing.

## 2. Branding / presentation review

Approved pilot presentation:

- product name: **Raahi Learning**;
- public pilot origin: **https://learning.myraahi.co.in**;
- current purple/white Raahi visual system retained;
- current Raahi mark retained;
- public purpose copy made explicit;
- Privacy and Terms surfaces included in release packaging;
- internal implementation labels/raw enum wording removed from user-facing presentation where reviewed;
- Local Manager / Platform Admin raw JSON summaries replaced with readable metric cards;
- escaped newline rendering artifact removed;
- privileged convergence now permanently fails if raw operational JSON or escaped newline artifacts reappear.

Final privileged visual evidence:
- Local Manager overview renders metric cards rather than raw projection JSON;
- Platform Admin overview renders metric cards rather than raw projection JSON;
- desktop and mobile privileged convergence passed.

## 3. Final Stage regression evidence

### Model / static guards

- Model Tests run `35461322054` — PASS
  - final launch presentation polish;
  - release packaging;
  - provider selection guard;
  - DEV writer seal;
  - pilot identity seal;
  - pilot cleanup guards;
  - MessageCentral phone-trust regression.

### Genuine-session DEV E2E

- DEV E2E run `35461310572` — PASS
- DEV E2E run `35461586112` — PASS after deployment-oracle hardening.

The genuine-session proof continues to cover:
- authenticated Raahi flows;
- Dhanbad live / Gomoh preparing behavior;
- Gomoh marketplace/community consequential-write rejection while preparing;
- current hosted browser source.

### UI convergence

- Core Learner/Teacher: run `35461537474` — PASS
- Parent/Organization: run `35461547153` rerun — PASS
- Privileged Local Manager/Platform Admin: run `35461586108` — PASS
- Ads: run `35461543267` rerun — PASS

Privileged artifact:
- artifact ID `10590550067`
- digest `sha256:8106a8ae80fe33be7d90610dcb1fc2411e64ad64f4452c5b5c70ee8c7f9b382a`

The privileged proof includes the final user-visible metric-card presentation and the new raw-JSON / escaped-whitespace guards.

### Side-effect / integration suites

Final clean proof set after deployment-oracle normalization:

- Activity side effects: `35461145982` — PASS
- Class lifecycle side effects: `35461150736` — PASS
- Test correction side effects: `35461155243` — PASS
- Class session side effects: `35461158620` — PASS
- Class post side effects: `35461162458` — PASS
- Enquiry/Trial side effects: `35461532808` rerun — PASS

The earlier red runs in this wave were classified as Test-Harness/infrastructure timing:
- source-equivalent DEV deployment SHA rotation;
- one DB statement timeout during an unusually broad CI burst;
- one fixture-page/browser timeout before a product assertion.

No frozen business rule was changed to obtain green evidence.

## 4. Deployment-oracle hardening

The browser/side-effect harnesses no longer assume that the DEV deployment SHA must remain byte-for-byte equal to the workflow SHA for the whole proof.

The current rule is:

1. identify the deployed commit from `build-meta.json`;
2. fetch the deployed commit if it was created after runner checkout;
3. diff the actual `apps/raahi-learning/` source;
4. accept rotation only when there is no relevant Learning app-source difference;
5. continue to fail if real application source changed underneath the proof.

This preserves test integrity while eliminating false reds caused by later docs/tests/workflow commits.

## 5. Current Supabase / geography state

Project:
- Learning DEV: `iiwwmqokaeflaenhlyip`

Migration ceiling:
- `1036_v13_phone_trust_explicit_browser_deny`

Locations:
- Dhanbad = `live`
- Gomoh = `preparing`

Do not change Gomoh to `live` before the controlled-pilot cutover sequence.

## 6. Synthetic cleanup readiness

Prepared:
- `scripts/raahi-learning-pilot-clean-public-domain.sql`
- `tests/raahi-learning-e2e/pilot-delete-harness-auth.mjs`

The public-domain reset has been transactionally rehearsed with rollback after MessageCentral migration 1035.

It preserves:
- `public.locations`;
- the reviewed genuine/non-harness Auth identities.

It removes at cutover:
- synthetic application-domain data;
- MessageCentral test challenge rows;
- harness Auth users through the separate authoritative metadata-gated cleanup.

No final cleanup has occurred yet.

## 7. MessageCentral readiness

Selected provider:
**MessageCentral VerifyNow**

Canonical detail:
`79-messagecentral-phone-trust-provider-v1.3.md`

Implemented:
- migration 1035 challenge ledger;
- migration 1036 explicit browser deny;
- Edge Function `phone-trust-messagecentral` v1 with JWT verification;
- release provider selection = `messagecentral`;
- provider credentials are not present in browser/source/release artifacts.

Not yet completed:
- MessageCentral account activation;
- Edge Function provider secrets;
- real Indian-phone OTP delivery/validation proof.

Therefore Stage is ready, but provider integration is **not yet pilot-proven**.

## 8. Next gates

### User-held external gate 1 — MessageCentral

Create/activate MessageCentral VerifyNow and obtain the provider credentials.

Secrets must be configured directly in Supabase Edge Function secrets:

- `MESSAGECENTRAL_CUSTOMER_ID`
- `MESSAGECENTRAL_PASSWORD`
- `MESSAGECENTRAL_EMAIL`

Do not paste raw provider password into chat or source control.

Then execute the real-provider same-phone smoke defined in doc 79.

### User-held external gate 2 — Google

Create/configure the production Google OAuth project/client for:
- `myraahi.co.in`
- public origin `https://learning.myraahi.co.in`

Complete Google production branding/redirect verification and real hosted sign-in proof.

### Controlled-pilot cutover

After both providers are proven:
- freeze release commit;
- off-platform DB backup;
- Storage backup;
- final public-domain cleanup;
- harness Auth deletion;
- writer seal;
- identity-factory seal;
- public release artifact;
- Gomoh activation;
- public-domain deployment;
- CONTROLLED_PILOT canary;
- explicit Rajeev go-live approval;
- only then admit real users.

## 9. Stage Ready conclusion

**Raahi Learning V1.3 is Stage Ready.**

The next unresolved work is no longer product architecture or ordinary implementation.

The next true gate is **real-provider onboarding and proof**, beginning with MessageCentral VerifyNow.
