# MyRaahi → Raahi Learning Location Handoff — Change Impact v0.1

Last updated: 2026-09-27

Method: AI Builder Cheat Code v2.0 — Gate 11 change-impact discipline applied before cross-product implementation.

Status: **APPROVED FOR ISOLATED SPIKE BRANCH ONLY**

## 1. Current behavior

MyRaahi shell passes a safe normalized query hint:

`?raahi_location=<slug>`

Raahi Learning currently has:
- canonical Locations;
- `list_public_locations`;
- authenticated Account context containing `selected_location`;
- canonical `set_selected_location` command;
- Google OAuth;
- sessionStorage preservation logic for private invitation context.

But Learning currently has **no parser/consumer for `raahi_location`**.

Therefore:
- MyRaahi can navigate into Learning;
- Learning does not yet guarantee that the Location explicitly chosen in MyRaahi becomes the active Learning Location.

This is a Gate-16 walking-skeleton gap.

---

## 2. Proposed behavior

When Learning is opened with:

`?raahi_location=gomoh`

Learning should:

1. validate the hint syntax as a simple Raahi Location slug;
2. save the hint plus a stable idempotency key in same-origin session storage;
3. remove the hint from the visible URL;
4. if signed out, continue normal Learning Google-auth UX with no auth-boundary change;
5. preserve the hint through the OAuth round trip;
6. after authenticated Account/bootstrap context is available:
   - match the slug only against Learning's current live Location projection;
   - if already selected, clear the pending hint;
   - otherwise call existing canonical `set_selected_location`;
7. clear the pending hint only after successful application;
8. reload/rebootstrap Learning so all Location-scoped projections use current server truth.

If the hinted Location is not currently live/known to Learning:
- do not create it;
- do not silently switch to a different guessed Location;
- discard/recover from the invalid handoff and let Learning remain authoritative.

---

## 3. Classification

**Type B — orchestration-only change.**

Why not C/D:
- no new backend RPC;
- no schema migration;
- no lifecycle change;
- no new authority;
- no auth-provider configuration change;
- no new product role;
- no change to Learning's Google-first entry boundary.

It composes an existing public Location projection with an existing canonical preference command.

---

## 4. Authority impact

None.

The query parameter:
- never grants authority;
- never grants Location Admin scope;
- never grants Teacher/Learner role;
- is not trusted as a Location id.

Server-owned Learning Location rows and `set_selected_location` remain authoritative.

---

## 5. Identity/auth impact

No authentication architecture change.

The handoff hint is:
- non-sensitive;
- stored in sessionStorage, not long-term identity;
- preserved through the existing same-origin Google OAuth flow.

Private invitation bearer-token handling remains untouched.

---

## 6. Data impact

No new durable entity.

Temporary browser state:
- pending Location slug;
- stable idempotency key.

Durable write uses existing:
- `account_location_preferences`
through
- `set_selected_location`.

Changing selected Location retains all existing Learning history and relationships.

---

## 7. UI impact

Expected:
- user entering from MyRaahi lands in the Location they explicitly chose;
- no additional onboarding page;
- no extra role question;
- no duplicate Location chooser after auth when the handoff is valid.

If invalid:
- Learning remains truthful and authoritative rather than forcing the shell's hint.

No visual redesign required.

---

## 8. Failure/recovery impact

### OAuth interruption
Pending Location remains in same-origin session storage and can resume after successful auth.

### Network failure during set_selected_location
Reuse the same stored idempotency key on retry.

### Stale/unknown slug
Do not apply; clear/recover safely.

### Account preference already matches
Clear pending state; no unnecessary RPC.

### Stale UI
Post-success reload/bootstrap reads current server context.

### Multiple different incoming hints
Most recent explicit navigation intent replaces older unconsumed hint.

---

## 9. Regression surfaces

Must verify:
- ordinary direct Learning visit unchanged;
- Google-first sign-in unchanged;
- private learner/org invitation preservation unchanged;
- DEV and public OAuth callback unchanged;
- manual Learning Location switching unchanged;
- existing Account history unaffected;
- invalid/tampered `raahi_location` grants nothing;
- MyRaahi Dhanbad → Learning results in Dhanbad after auth;
- MyRaahi Gomoh → Learning results in Gomoh after auth;
- already-authenticated user gets location applied without new auth;
- signed-out user retains location through OAuth.

---

## 10. Implementation boundary

Implement first on a new isolated branch from current Learning HEAD:

`myraahi-learning-location-handoff-spike`

Do not push directly to:
`raahi-learning-implementation-v1`

Do not deploy to:
`learning.myraahi.co.in`

A DEV/preview proof is required before any merge decision.

---

## 11. Decision

**PROCEED with isolated spike branch.**

This change closes the identified Gate-16 integration gap without changing Raahi Learning's domain or authentication rules.
