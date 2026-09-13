# Raahi Learning V1.3 — AI Builder v2 Internal Retrofit Closure

Status: **INTERNAL RETROFIT CLOSED — EXTERNAL HOSTED-AUTH PROOF IS THE ACTIVE GATE.**

This checkpoint closes the one-time internal AI Builder Cheat Code v2 retrofit that followed the V1.3 product/UX review. It does not reopen the frozen product/domain design and it does not claim production readiness.

## What is now closed

The finite internal findings from the Screen ↔ Backend contract audit have been closed without weakening server authorization:

- `teacher-members` has a live renderer and browser coverage;
- `community-report` submits the intended Community target rather than silently reusing Class context;
- reachable `community-post` is part of the canonical route/test inventory;
- Organization workspace controls are capability-aware rather than assuming every staff member has every Organization capability;
- Notification rows have centralized safe destinations that refetch through ordinary authorized projections;
- private Learner/staff invitation bearer values are preserved locally across Google OAuth and removed from the visible redirect query;
- stronger route/test oracles cover reachable-vs-declared routes, capability-scoped Organization members, notification destinations and exact Community report targets.

The remaining phone interruption/resume proof is intentionally not marked closed because it depends on real hosted Supabase Auth configuration and a real browser/Auth round trip.

## Browser evidence after closure

- canonical reachable routes: **84**;
- desktop + mobile live contract: **84 × 2 = 168/168 PASS**;
- live-contract issues: **0**;
- route/workspace guard failures: **0**;
- focused V1.3 action contracts: **12/12 PASS**;
- privileged deep-link guard checks: **32/32 PASS**;
- semantic checks: **15/15 PASS**;
- workspace checks: **154/154 PASS**;
- interaction checks: **26/26 PASS**.

The legacy workspace test was corrected because its old 77-route V1.2 oracle treated shared routes as workspace-specific. This was a **test/harness defect**, not a product or authorization change.

A Chromium local/file-navigation problem encountered during invite/OAuth testing was also classified as a **test/harness defect**. The production invite hardening itself remains unchanged.

## Frozen-byte evidence

The V1.1 frozen anchors remain byte-identical:

- `app.fixture.js`: `6eb67b36931c45aa4113c77005d82c13bb14ec145500e08cfd92130ebcef576c`
- `styles.css`: `b2d89e454f8e13712d10058c876f5efe2c8c69acf73dd6aade158241900f7bdd`

Current V1.3 retrofit anchors:

- `app.live-core-v13.js`: `b8fea9446bba5171aa399d709eede2a0403949e96015157aa0ab1db320834a0f`
- `live.js`: `cdc44f514b1f396799313c977a4a48fe8efad33ae1f6054db776682c977796aa`
- `tests/cdp-v13-actions.mjs`: `612e8d5e404c9c84b8e3dd441cf863bae3aa1bc8d9d7e73aa6deef812b2d215f`
- `tests/cdp-live-contract.mjs`: `056788dcfa5c431b25385e7912bb24136d6d63f95bafc8a4bd48d8a22fe39acf`

## Backend/security state

DEV migrations through `1021_v13_phone_trust_command_guards` are applied.

Relevant V1.3 runtime markers include:

- `V13_CONTEXTUAL_INBOX_ORG_PICKER_PASS`
- `V13_LEARNER_SELF_ACCESS_INVITATION_PASS`
- `V13_ORGANIZATION_MEMBER_INVITATION_PASS`
- `V13_NOTIFICATION_TRANSITION_WIRING_PASS`
- `V13_PHONE_TRUST_PROJECTION_PASS`
- `V13_PHONE_TRUST_COMMAND_GUARDS_PASS`

Migration 1020 derives `unverified / stale / fresh` phone-trust state from Supabase Auth's server-owned phone confirmation state. Migration 1021 applies the frozen 90-day gate only to selected creation/escalation actions while preserving existing learning/safety and completed idempotent retries.

Supabase Security Advisor after 1021: **0 findings**.

## Side-effects gate

Document 46 completed the V1.3 side-effects decision matrix. The matrix is frozen; remaining non-walking-skeleton side-effect implementation gaps stay queued for their owning vertical slices after the real walking skeleton. They must not be implemented as another broad horizontal notification project.

## Active gate now

No more broad backend/frontend implementation should start before the following real technology proof:

1. hosted DEV Google provider configuration is verified;
2. real Google → Supabase session succeeds in a browser;
3. `bootstrap_account` resolves/creates exactly one Raahi Account and survives logout/login;
4. hosted DEV phone OTP/test configuration is verified through an authorized Auth-management surface;
5. a signed-in Google-primary Account attaches/reverifies phone using supported Supabase Auth;
6. server-owned phone confirmation evidence changes as expected;
7. the interrupted trust-sensitive command resumes and rechecks current state/authority.

Then run the mandatory walking skeleton:

**Google sign-in → Account/bootstrap → Learner context → discovery → Enquiry → provider engage → Class Invitation → real phone-trust interruption/resume → Membership → Class → contextual message.**

No fixture-mode business result may substitute for a real boundary in that journey.

## Change-control rule

A failure in the technology proof/walking skeleton must first be classified as Domain, Integration, Implementation, or Test/Harness. Only a genuine Domain defect reopens:

`rules → entities → relationships → states → permissions → UI → tests → architecture/DB`.

Do not deploy publicly from this checkpoint.