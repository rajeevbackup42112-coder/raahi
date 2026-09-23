# Raahi Learning V1.4K — Google Profile Confirmation Alignment Contract

Status: **IMPLEMENTATION CONTRACT — RESTORES FROZEN V1.3 AUTH → PROFILE → INTENT JOURNEY**

Companion documents:
- `119-canonical-alignment-audit-prelaunch-2026-09-23.md`
- `120-first-use-intent-alignment-contract-v1.4k.md`

## 1. Problem

The frozen V1.3 journey requires:

**Google sign-in → Account/bootstrap → confirm/edit Raahi name and optional profile-image suggestion → first-use intent → intended action.**

The current browser contains a good `google-profile` screen, but normal OAuth bootstrap does not route a newly created Account through it. OAuth returns without a route hash, the router defaults to Home, and the screen is therefore bypassable in ordinary first use.

## 2. Human goal

A new user should understand that:

- Google signs them in;
- the name shown on Raahi is editable;
- a Google photo is only an optional suggestion;
- no Google photo is published automatically;
- after confirming their Raahi profile, they choose what they came to do.

This is onboarding UX only. It must never grant Learner, Teacher, Organization, manager or platform authority.

## 3. Minimal state

Add:

`accounts.profile_onboarding_completed_at timestamptz null`

This timestamp means only:

> the Account has completed the one-time Raahi profile-confirmation step.

It is not a verification badge, identity-assurance level, role, capability, or authorization signal.

All Accounts that existed before this migration are backfilled complete. The new requirement applies only to Accounts created after activation.

## 4. Canonical command

Add:

`complete_profile_onboarding(p_idempotency_key)`

The command:

- resolves only the current authenticated Account;
- sets the timestamp once using server time;
- is idempotent;
- creates no capability, Learner, Organization, Location scope, public profile or content;
- does not modify the user's display name/avatar itself.

The existing `update_account_profile` remains the canonical profile write.

## 5. Account context

`get_my_account_context().account` exposes:

`profile_onboarding_completed_at`

Frontend rollout is fail-safe:

- field absent → do not force the new gate;
- field present + null → profile confirmation is pending;
- timestamp present → normal flow.

## 6. Browser orchestration

For an authenticated Account:

1. pending private invitation remains highest-priority intended-action recovery;
2. if profile onboarding is pending, render `google-profile`;
3. after successful profile save:
   - call `update_account_profile`;
   - call `complete_profile_onboarding`;
   - refresh Account context;
   - route to `onboarding-intent`;
4. if first-use intent is still pending, show the canonical five-choice intent screen;
5. established users do not repeat either screen.

The existing optional **Use Google photo** action may import a governed Raahi-owned copy, but it does not by itself finish profile onboarding. The user still confirms the profile form.

## 7. Invariants

- Google metadata never grants Raahi authority;
- profile confirmation never grants Raahi authority;
- Google photo is never auto-published;
- later Google profile changes never silently overwrite Raahi profile data;
- later ordinary profile edits do not affect the onboarding timestamp;
- first-use intent remains a separate step;
- private-invite continuation is not broken;
- logout/login preserves completion;
- existing genuine Accounts are not unexpectedly forced through the new gate.

## 8. Acceptance tests

- new post-migration Account has profile onboarding pending;
- existing Accounts are backfilled complete;
- context exposes both profile and first-use completion independently;
- completion command is current-Account scoped, idempotent and authority-neutral;
- exact browser flow is profile → intent, not generic Home;
- name can be edited before completion;
- optional Google photo stays opt-in;
- first-use intent cannot be skipped merely by refreshing;
- returning established user lands normally;
- mobile-sized browser can submit profile and reach intent.

## 9. Non-goals

This slice does not:

- change Google OAuth provider configuration;
- require a Google photo;
- create public Learner/Teacher photos;
- create a permanent role/persona;
- change phone trust;
- process the pending genuine Teacher request.
