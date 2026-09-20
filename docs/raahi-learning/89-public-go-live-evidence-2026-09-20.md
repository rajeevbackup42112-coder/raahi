# Raahi Learning V1.3 — Public Go-Live Evidence — 2026-09-20

Status: **PUBLIC LIVE**

Repository: `rajeevbackup42112-coder/raahi`  
Branch: `raahi-learning-implementation-v1`  
Public origin: `https://learning.myraahi.co.in`  
Supabase project: `iiwwmqokaeflaenhlyip`

## 1. Approval and launch model

Explicit public go-live approval was received on 2026-09-20.

The frozen public Location model is:

- one Raahi Account is not permanently bound to one city/locality;
- Dhanbad and Gomoh are both `live` and normally selectable;
- users may switch Location freely;
- Location changes local discovery/community context, not Account identity, Learners, Classes, Messages, history or existing relationships;
- Gomoh is the first acquisition/promotion market, not an authorization boundary;
- Dhanbad remains fully usable;
- future Locations such as Topchachi, Bokaro and Ranchi are added as independent configured Locations when ready.

See `88-gomoh-first-public-launch-model-2026-09-20.md`.

## 2. Google OAuth public admission

Immediately before public admission:

- Google Auth Platform publishing status: `Testing`;
- user type: `External`;
- exactly two Google test users were configured;
- CI run #643 on commit `a197c5499ca4206bfc7e061aecb0a093fbe8aeb1` was green;
- harness Auth users: `0`;
- Storage objects: `0`;
- Dhanbad and Gomoh were the only live Locations.

Public admission action:

- Google Auth Platform `Publish app` was executed and confirmed;
- publishing status changed to **In production**;
- user type remains **External**;
- no OAuth scopes were added or broadened;
- Supabase Site URL and redirect configuration were not changed.

The old test-user list is no longer an admission boundary while the OAuth application is In production.

## 3. Non-test Google user proof

A Google identity that was **not** one of the two configured OAuth test users was selected from the Google account chooser on the public origin.

The flow completed through Google consent and returned to:

`Home - Raahi Learning`

The user reached the normal Dhanbad Home experience and a fresh active Raahi Account was bootstrapped through the normal product path.

Supabase proof after that sign-in:

- total Auth users: `8`;
- harness Auth users: `0`;
- fresh application Accounts: `4`;
- the non-test Google identity had a new active Account created at `2026-09-20T13:29:20Z` after a successful sign-in at `2026-09-20T13:29:17Z`.

This is the public-admission proof: an identity outside the former Google test-user allow-list completed the production OAuth path successfully.

## 4. Immediate post-launch health

Observed at `2026-09-20T13:30:32Z`:

- latest migration: `20260919202746` / V1.3 migration ceiling `1038`;
- Auth users: `8`;
- harness Auth users: `0`;
- application Accounts: `4`;
- Storage objects: `0`;
- live Locations: `dhanbad`, `gomoh` only;
- deadlocks: `0`;
- waiting locks: `0`;
- transactions over 30 seconds: `0`;
- public views: `0`;
- public tables without RLS: `0`;
- public tables without forced RLS: `0`;
- public security-definer functions: `0`;
- private security-definer functions executable by PUBLIC: `0`;
- private security-definer functions executable by anon: `0`.

Security Advisor remains unchanged with only the known leaked-password-protection warning. Primary public authentication is Google-only, so no password sign-in surface was introduced by this launch.

## 5. Compatibility labels retained deliberately

The runtime key `phone_trust_mode=controlled_pilot_google_only` and the already-deployed release artifact's `release_mode=CONTROLLED_PILOT` are retained for compatibility/provenance in this first public launch.

They no longer represent the public-admission gate. Public admission is now controlled by Google OAuth publishing status and is **open**.

The phone-trust key currently drives the proven Google-only behavior that suppresses phone verification. Renaming it in-place would require a new migration, application release and regression cycle with no user-facing launch benefit. Any future rename to a more general production name must therefore be handled as an explicit compatibility migration, not as an emergency post-launch edit.

## 6. Current production state

Raahi Learning is now **genuinely public** at `https://learning.myraahi.co.in`.

Operationally:

- public Google sign-in: open;
- Dhanbad: live/selectable;
- Gomoh: live/selectable;
- initial public promotion: Gomoh-first;
- users may switch between Dhanbad and Gomoh normally;
- phone verification remains intentionally disabled for this launch;
- synthetic writer workflows remain sealed;
- DEV test identity factory remains sealed;
- no harness Auth users remain;
- production data must now be treated as real user data.

From this point onward, **do not recreate the DEV-write marker, re-enable synthetic writers, run destructive pilot cleanup, or treat the shared Supabase project as disposable DEV data**.

## 7. Public-user authorization and origin proof

After public OAuth admission, the newly admitted non-test Google user was checked under the authenticated database role:

- own Account rows: `1`;
- cross-Account rows against an existing canary Account: `0`;
- canonical Account context returned the user's own Account ID;
- authenticated Location projection returned `dhanbad` and `gomoh`;
- no authorization broadening was observed.

The production origin was fetched again after OAuth publication:

- `https://learning.myraahi.co.in/` returned HTTP `200`;
- the returned document contained the Raahi application surface.

This closes the immediate public-admission proof: open Google OAuth, normal Account bootstrap, intact RLS isolation, selectable live Locations and healthy public origin.
