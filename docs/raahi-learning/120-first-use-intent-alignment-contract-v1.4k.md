# Raahi Learning V1.4K — First-Use Intent Alignment Contract

Status: **IMPLEMENTATION CONTRACT — RESTORES FROZEN V1.3 FIRST-USE JOURNEY WITHOUT DOMAIN REDESIGN**

Companion audit: `119-canonical-alignment-audit-prelaunch-2026-09-23.md`

## 1. Problem

The frozen V1.3 UX requires a newly bootstrapped Account to be guided by intent before falling into a generic Home surface.

Observed genuine behavior allowed an Account with no Learners, teaching capability, Organization membership or manager scope to land directly on Home. Later Home CTAs partly compensated for that, but they do not replace the original first-use journey.

## 2. Human goal

After Google sign-in, a genuinely new/empty Account should answer one simple question:

**What brings you here today?**

Choices remain:

- I want to learn
- I’m helping someone learn
- I teach
- I represent an institute
- I’m just exploring

This is a first-task choice, not a permanent role.

## 3. Actors

- authenticated Raahi Account;
- Raahi frontend;
- canonical Account context;
- existing Learner / Teacher / Organization setup commands.

No new authority actor is introduced.

## 4. Rules

1. Google authentication never infers a Raahi role/capability.
2. First-use intent grants **no authority**.
3. The intent screen appears only while the Account's first-use step is incomplete.
4. Choosing an intent completes only the first-use guidance step, then routes to the existing setup path.
5. Existing setup commands remain the only way to create Learner/Teacher/Organization authority or relationships.
6. “I’m just exploring” is valid and requires no Learner/Teacher/Organization creation.
7. Established Accounts must not be forced through first-use again.
8. An Account may later add other relationships regardless of its first choice.
9. Direct navigation to privileged workspaces remains server-authorized.
10. No selected intent is needed for authorization, analytics or server policy.

## 5. Minimal data

Add only:

`accounts.first_use_completed_at timestamptz null`

No permanent role field and no stored intent enum are required.

Reason: the product only needs to know whether the one-time guidance step has been completed. Storing the user's initial choice is unnecessary for authority and violates the minimum-data preference unless a later genuine product need appears.

## 6. Existing-account backfill

On migration:

Mark first use complete for Accounts that already have any meaningful Raahi relationship/authority:

- active Account↔Learner access;
- active Account capability;
- active Organization membership;
- active Location staff assignment;
- any assisted Teacher onboarding request.

Leave genuinely empty Accounts incomplete so they receive the intended guidance on their next authenticated entry.

A current genuine assisted Teacher request therefore counts as having already entered a meaningful setup journey and must not be reset back to first-use.

## 7. State

Only two UX states:

- `pending`: `first_use_completed_at is null`
- `complete`: timestamp present

This is **not** a business lifecycle for Learner/Teacher/Organization authority.

## 8. Canonical write

Add:

`complete_first_use_onboarding(p_idempotency_key)`

Effect:

- resolve current Account from authenticated identity;
- set `first_use_completed_at = coalesce(existing, server now())`;
- return the server-owned completion timestamp;
- change no capability, Learner relationship, Organization membership, Location scope or public profile.

The command is safe to retry.

## 9. Account context

`get_my_account_context()` exposes:

`account.first_use_completed_at`

The frontend treats absence of this field as **feature not activated** rather than forcing onboarding. This makes frontend/backend rollout fail-safe.

## 10. Screen ↔ backend contract

### Authenticated Home entry

If:
- session exists;
- Account context exists;
- `first_use_completed_at` field is present and null;

then render/route to `onboarding-intent` instead of generic Home.

### Intent click

While first-use is pending:

1. call `complete_first_use_onboarding`;
2. refresh `get_my_account_context`;
3. route using existing pages:

| Intent control | Existing destination |
|---|---|
| I want to learn | `learner-setup` |
| I’m helping someone learn | `learner-add` |
| I teach | `teacher-setup` |
| I represent an institute | `institute-setup` |
| I’m just exploring | `home` |

If the completion write fails, remain on the intent screen and show a recoverable error.

### Later use

After completion, manually entering setup flows or choosing another context continues to use the existing normal product paths. The first-use marker never blocks them.

## 11. Invariants

- completion cannot grant `teach`;
- completion cannot create a Learner;
- completion cannot create an Organization;
- completion cannot assign manager/platform authority;
- completion cannot publish anything;
- completion cannot change selected Location;
- completion timestamp is server-owned;
- repeated command does not change the original completion time;
- Account context remains backward compatible;
- established Accounts are not unexpectedly onboarded again;
- an assisted Teacher request remains private/public behavior exactly as before.

## 12. Recovery / edge cases

- double tap: first request wins; subsequent retry returns/retains same completion timestamp;
- network loss after server commit: retry is safe;
- old frontend against new DB: ignores the extra context field;
- new frontend against old DB: field absent, so it does not force first-use;
- user chooses Teach then closes app before setup: first-use stays complete; Home's Start teaching affordance provides re-entry;
- user chooses Explore: Home opens and future Teacher/Learner actions remain available;
- user revisits `onboarding-intent` later: normal existing routing may still be used; the one-time marker does not grant or restrict authority.

## 13. Acceptance tests

### Contract
- migration adds only first-use completion metadata;
- context exposes it;
- canonical completion command is current-Account scoped and idempotent;
- command performs no capability/relationship/public-content writes.

### Browser
- clean empty Account enters intent instead of generic Home;
- each of five choices routes to correct existing setup surface;
- choice itself grants no authority;
- Explore returns Home without creating a Learner/Teacher/Organization;
- established Account lands normally;
- Teacher+Parent multi-context Account is not re-onboarded;
- direct Teacher URL on unprivileged Account remains denied.

### Mobile
Run the same intent choices at iPhone-sized and Android-sized viewports through real click/tap interaction, not source assertions only.

## 14. Non-goals

This slice does not:

- redesign Google profile confirmation;
- redesign Teacher self-service screens;
- humanize all technical copy;
- change workspace switching;
- change phone trust;
- process the pending genuine Teacher request.

Those are subsequent alignment slices after this one is green.
