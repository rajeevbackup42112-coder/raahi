# Raahi Learning V1.3 — Stage Ready Closeout after Google-Only Pilot Decision

Status: **STAGE READY — CURRENT CONTROLLED-PILOT BASELINE**  
Date: 2026-09-20

This document supersedes the pre-change Stage Ready closeout in doc 80.

Canonical pilot trust decision:

`81-controlled-pilot-google-only-trust-v1.3.md`

## 1. Current launch baseline

Approved lifecycle:

**Learning DEV → Stage Ready → same-project controlled pilot (Gomoh + Dhanbad) on Free Supabase → paid isolated production after traction.**

Controlled-pilot authentication:

**Google sign-in only.**

No phone, SMS or WhatsApp verification is required during the first controlled pilot.

Future additional trust direction:

**Google primary sign-in + WhatsApp OTP only for selected sensitive actions after traction.**

OTP must not become a routine second login.

## 2. Current database / trust state

Supabase project:

`iiwwmqokaeflaenhlyip`

Current migration ceiling:

`20260919202746 / 1038_v13_remove_public_trust_policy_rpc`

Current server trust setting:

`phone_trust_mode = controlled_pilot_google_only`

Current enforcement result:

`phone_trust_enforcement_enabled = false`

The setting is server-owned in `app_private.runtime_settings`.

Fail-closed behavior remains:

- exact `controlled_pilot_google_only` disables phone enforcement;
- any other value enables phone enforcement;
- a missing setting enables phone enforcement.

No role, ownership, RLS, state, capacity, audit or idempotency rule was removed.

## 3. Security correction

Migration 1037 initially included a temporary browser-readable trust-policy projection.

That projection was removed by migration 1038 before this closeout.

Current catalog proof:

- 0 public tables without RLS;
- 0 public tables without FORCE RLS;
- 0 public views;
- 0 public SECURITY DEFINER functions;
- 0 app_private SECURITY DEFINER functions executable by PUBLIC;
- 0 app_private SECURITY DEFINER functions executable by anon.

Security Advisor:

- only known Free-plan warning remains: leaked-password protection disabled.

Performance Advisor:

- informational unused-index notices only;
- no index is removed merely because it has not yet been used by the synthetic DEV workload.

## 4. Provider state

### MessageCentral

MessageCentral is retired for the controlled pilot because real onboarding exposed a ₹4,999 minimum wallet top-up.

Active deployed function:

`phone-trust-messagecentral` version 6

State:

**SEALED**

Behavior:

- JWT verification remains enabled;
- returns HTTP 410;
- returns `PHONE_PROVIDER_DISABLED_DURING_GOOGLE_ONLY_PILOT`;
- sends no SMS;
- verifies no OTP;
- changes no Auth/database trust state.

Existing MessageCentral secrets are no longer required and must be removed before public cutover.

### Meta WhatsApp

Direct Meta WhatsApp Cloud API remains the preferred post-pilot additional-trust direction.

Free test-environment proof completed:

- My Raahi Meta developer app created;
- WhatsApp use case connected to the My Raahi Business Portfolio;
- Meta test business number provisioned;
- user's recipient number verified;
- test WhatsApp message successfully received.

Production setup is intentionally paused before purchasing/assigning a dedicated My Raahi SIM/business number.

This is not a pilot launch dependency.

## 5. Public release configuration

For `CONTROLLED_PILOT` packaging:

- `phoneTrustMode = controlled_pilot_google_only`
- `phoneTrustProvider = disabled`

The UI must not request phone verification.

If an obsolete/manual phone-check route is reached, the pilot UI states that Google sign-in is sufficient and offers no OTP operation.

For future `NON_DEV` dedicated-production packaging:

- default `phoneTrustMode = phone_trust_required`
- provider remains `disabled` until a real provider is explicitly proven.

This prevents the temporary pilot relaxation from silently becoming the permanent production default.

## 6. Operational snapshots

Release-health SQL now records:

- `phone_trust_mode`;
- `phone_trust_enforcement_enabled`.

Recovery inventory now records the same trust-policy state alongside migrations, counts, Storage and security inventory.

Latest recovery snapshot after migration 1038 showed:

- current trust mode = `controlled_pilot_google_only`;
- enforcement = false;
- Storage objects = 0;
- public SECURITY DEFINER functions = 0;
- public tables without RLS = 0;
- public tables without FORCE RLS = 0.

## 7. Post-change regression evidence

Final exact current-source validation commit:

`61fd03555910cb16f744d653317c31986e1039cd`

### Model Tests

Run `35467717423` — **PASS**

Includes:

- controlled-pilot Google-only trust guard;
- release-package mode separation;
- MessageCentral pilot seal;
- launch polish;
- cleanup guards;
- operations guards;
- production-canary guards.

### Genuine-session DEV E2E

Run `35467717381` — **PASS**

This validates the hosted application with genuine Supabase sessions on the migration-1038 database baseline.

### UI convergence

- Core Learner/Teacher: run `35467717405` — **PASS**
- Parent/Organization: run `35467717378` — **PASS**
- Privileged Local Manager/Platform Admin: run `35467717353` — **PASS**
- Ads: run `35467717394` — **PASS**

### Sensitive side-effect coverage

The Google-only rule change also ran successfully through the existing sensitive-command suites:

- Activity side effects — PASS
- Class lifecycle side effects — PASS
- Class session side effects — PASS
- Class post side effects — PASS
- Test correction side effects — PASS
- Enquiry/Trial side effects — PASS
- Organization staff capability boundaries — PASS
- Organization authority side effects — PASS after a clean rerun

The two initial Organization reds were deployment/browser timing artifacts, not authorization or phone-trust failures. Their deployment oracles were brought to the same source-compatible model as the rest of the E2E suite.

## 8. Geography state

Current:

- Dhanbad = `live`
- Gomoh = `preparing`

Do not activate Gomoh before the controlled-pilot cutover.

No other Location should become live for the first pilot.

## 9. Synthetic / cutover state

Still not executed:

- final public-domain cleanup;
- harness Auth deletion;
- DEV writer seal;
- DEV identity-factory seal;
- Gomoh activation;
- public pilot deployment;
- controlled-pilot canary;
- admission of real users.

Prepared and rehearsed:

- fail-closed public-domain cleanup;
- harness Auth cleanup;
- database backup procedure;
- Storage backup procedure;
- release packaging;
- controlled-pilot canary;
- DEV writer seal;
- identity-factory seal.

## 10. Remaining external launch gates

The next launch dependency is now **production Google OAuth**, not phone/SMS/WhatsApp.

Required before public cutover:

1. production Google Cloud project/OAuth client for Raahi Learning;
2. public origin:
   `https://learning.myraahi.co.in`;
3. verified/appropriate OAuth branding and redirect configuration;
4. real Google sign-in proof on the public origin;
5. active `support@myraahi.co.in`;
6. final backup + cleanup + writer/identity seal;
7. Gomoh activation;
8. controlled-pilot canary;
9. explicit Rajeev go-live approval.

A dedicated WhatsApp business SIM is deliberately deferred until after pilot traction.

## 11. Stage Ready conclusion

**Raahi Learning V1.3 is Stage Ready again on the new Google-only controlled-pilot baseline.**

The phone-verification dependency has been removed from the first pilot without deleting the stronger future trust architecture.

The next execution gate is:

**production Google OAuth + public pilot origin preparation.**
