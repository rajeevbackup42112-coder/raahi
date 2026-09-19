# Raahi Learning V1.3 — Controlled Pilot Google-Only Trust Decision

Status: **APPROVED + IMPLEMENTED — REQUIRES FRESH POST-CHANGE STAGE REGRESSION**
Date: 2026-09-20

## 1. Decision

For the first controlled Gomoh + Dhanbad pilot:

**Google authentication is sufficient. Phone/WhatsApp verification is not required.**

This is a deliberate temporary pilot rule, not a removal of the phone-trust architecture.

Post-pilot direction:

**Google remains the primary sign-in. WhatsApp OTP becomes an additional trust proof only for selected sensitive actions once Raahi has traction and user trust.**

Raahi should not require OTP on every login.

## 2. Why this changed

The previous Stage Ready baseline expected selected sensitive actions to require fresh phone trust.

During real provider onboarding, two practical facts became clear:

1. MessageCentral imposed a ₹4,999 minimum wallet top-up, which is disproportionate for a tiny controlled pilot.
2. Direct Meta WhatsApp Cloud API is technically attractive for the future, but production use requires a dedicated business phone number/SIM and additional production setup that is not necessary to prove initial Raahi Learning demand.

The controlled pilot should optimize for:

- low friction;
- low cost;
- fast learning;
- real product adoption evidence;
- no premature infrastructure commitment.

Therefore phone verification is deferred until after the pilot proves traction.

## 3. Frozen pilot behavior

During `controlled_pilot_google_only` mode:

- Google is the only user authentication requirement.
- Raahi must not ask a user to add or confirm a phone number.
- Existing role/authority/ownership checks remain unchanged.
- Existing RLS remains unchanged.
- Existing account/learner/organization/class authority remains unchanged.
- Existing audit/idempotency/capacity/state checks remain unchanged.
- Anonymous access is not introduced.
- No fake OTP bypass is introduced.
- Phone trust is not silently marked fresh.
- Phone verification is simply not an active prerequisite during this explicit pilot mode.

## 4. Impact analysis

### Rules

Changed only for the controlled pilot:

Old:
> selected creation/escalation actions require fresh phone trust.

Pilot:
> authenticated Google identity is sufficient for selected creation/escalation actions while the explicit Google-only pilot mode is active.

Future:
> selected creation/escalation actions return to requiring fresh additional phone trust.

### Entities / relationships

No entity or relationship model changes.

Unchanged:

- Account ≠ Learner;
- guardian/learner authority;
- Organization authority;
- Class Membership and invitation ownership;
- Teacher/provider authority;
- Local Manager / Platform Admin capabilities.

### States

One operational trust-policy state is added:

- `controlled_pilot_google_only`
- `phone_trust_required`

The setting is server-owned in:

`app_private.runtime_settings`

If the setting is missing or unknown, enforcement defaults to **enabled**.

This is intentionally fail-closed.

### Permissions

No permission grant is added.

Phone-trust bypass occurs only inside the existing server trust guard. It does not bypass:

- current Account requirement;
- capability checks;
- learner-side authority;
- organization authority;
- local/admin authority;
- RLS;
- state transitions;
- idempotency;
- capacity;
- moderation restrictions.

### UI

The controlled-pilot release declares:

`phoneTrustMode: 'controlled_pilot_google_only'`

and:

`phoneTrustProvider: 'disabled'`

The pilot UI:

- does not ask for a phone number;
- does not present an OTP form during normal flows;
- if an old/manual phone-check route is reached, it states that Google sign-in is sufficient for the pilot;
- cannot send or verify an OTP while pilot mode is active.

### Tests

Required post-change proof:

- Model/static guard for explicit fail-closed trust mode;
- release package selects Google-only mode;
- MessageCentral provider remains disabled;
- genuine-session E2E remains green;
- Core / Parent-Org / Privileged / Ads UI convergence remains green;
- sensitive side-effect suites remain green without phone proof;
- no raw OTP/login path appears in the public pilot artifact.

## 5. Backend implementation

Migration:

`20260920020500_1037_v13_controlled_pilot_google_only_trust.sql`

Adds:

`app_private.runtime_settings`

Current value:

`phone_trust_mode = controlled_pilot_google_only`

Adds:

`app_private.phone_trust_enforcement_enabled()`

Behavior:

- returns false only for the exact reviewed pilot value;
- returns true for any other value;
- returns true if the setting is absent.

Updates:

`app_private.require_fresh_phone_trust()`

Behavior:

- in Google-only pilot mode: return without phone enforcement;
- otherwise: preserve the existing `has_fresh_phone_trust()` / `PHONE_TRUST_REQUIRED` behavior.

Migration 1038 removes the temporary public trust-policy projection so the established security invariant remains intact:

**zero public SECURITY DEFINER RPCs.**

Operational verification reads the server-owned setting through trusted SQL/runbooks rather than exposing a browser-facing policy RPC.

## 6. Affected commands

The following existing command-level phone-trust boundaries are intentionally dormant during the controlled pilot and automatically resume when full enforcement is restored:

- post learning request;
- reopen learning request;
- send enquiry;
- send sponsored enquiry;
- express interest in request;
- accept Class invitation;
- publish teaching option;
- create Organization;
- add Organization member;
- issue Organization member invitation;
- accept Organization member invitation;
- set Organization member capability;
- grant learner self-access;
- issue learner self-access invitation;
- accept learner self-access invitation;
- request Account closure;
- publish Community post;
- submit ad campaign revision;
- confirm ad commercial clearance;
- confirm ad inventory;
- apply access restriction;
- lift access restriction;
- moderate Community content;
- resolve report.

Additional direct trust checks are also covered because they call the same central guard, including:

- enabling teaching;
- making a Teacher profile visible;
- reopening teaching availability to new learners;
- activating an ad placement.

No command was individually patched to bypass phone trust.

## 7. MessageCentral outcome

MessageCentral is **not** the controlled-pilot provider.

Reason:

- real dashboard showed minimum top-up of ₹4,999;
- this is commercially disproportionate for the initial pilot.

The MessageCentral integration work is preserved as historical integration evidence, but the active DEV function is sealed.

Current deployed function:

`phone-trust-messagecentral` version 6

Behavior:

- JWT verification remains enabled;
- always returns HTTP 410;
- error:
  `PHONE_PROVIDER_DISABLED_DURING_GOOGLE_ONLY_PILOT`;
- cannot send SMS;
- cannot verify OTP;
- cannot change phone trust.

The existing MessageCentral secrets should be removed from Supabase when convenient because they are no longer needed.

## 8. Future OTP direction

Preferred future direction after pilot traction:

**Direct Meta WhatsApp Business Platform Cloud API**

Why:

- Google remains the identity/login layer;
- WhatsApp is widely available to the target Indian audience;
- Meta provides first-class Authentication templates;
- direct Cloud API avoids an additional OTP reseller;
- current Meta India Authentication pricing observed during review was ₹0.1150 per delivered message at the base tier;
- no pilot-scale minimum wallet commitment was shown.

Meta test-environment proof already completed:

- a My Raahi Meta developer app was created;
- the WhatsApp use case was connected to the My Raahi business portfolio;
- Meta's generated test business number successfully delivered a test WhatsApp message to the user's verified recipient number.

Production setup is intentionally paused before adding a real business number.

Future production setup will likely require:

- dedicated My Raahi business phone number/SIM;
- WhatsApp Business Account;
- production phone registration;
- approved Authentication template;
- secure permanent/system-user access token;
- billing/payment configuration;
- real delivery and wrong/correct-code proof.

Do not perform this production setup merely to launch the first controlled pilot.

## 9. Re-enable rule after pilot

Phone trust must not be re-enabled casually or by a browser flag.

Reactivation must be a reviewed server-side change:

1. choose/prove the real provider;
2. implement and test provider send/verify;
3. ensure server-only secret handling;
4. prove wrong OTP rejection;
5. prove correct OTP updates the authoritative trust state;
6. verify pending sensitive action resumes;
7. set `phone_trust_mode = phone_trust_required`;
8. change release UI from Google-only to the selected provider;
9. run full regression;
10. deploy.

The 90-day phone freshness design remains the intended post-pilot model unless a later product decision explicitly changes it.

## 10. Current user experience

Controlled pilot:

**Continue with Google → Raahi Account → normal product use**

No phone prompt.

Future mature flow:

**Continue with Google → normal product use → selected sensitive action → Verify on WhatsApp → 90-day phone trust → resume action**

This keeps the pilot simple without throwing away the stronger long-term trust model.
