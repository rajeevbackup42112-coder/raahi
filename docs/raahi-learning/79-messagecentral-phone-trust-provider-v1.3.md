# Raahi Learning V1.3 — MessageCentral phone-trust experiment

Status: **RETIRED FOR CONTROLLED PILOT — HISTORICAL INTEGRATION EVIDENCE ONLY**  
Date updated: 2026-09-20

## Current decision

MessageCentral VerifyNow is **not** the provider for the Gomoh + Dhanbad controlled pilot.

The pilot now runs in:

`controlled_pilot_google_only`

See:

`81-controlled-pilot-google-only-trust-v1.3.md`

Google is sufficient for the first controlled pilot. Raahi must not ask pilot users for phone verification.

## Why MessageCentral was retired

The technical integration worked as a viable provider pattern, but real account onboarding exposed a commercial blocker:

- MessageCentral required a minimum wallet top-up of ₹4,999.

That commitment is disproportionate for a pilot whose purpose is to validate real Raahi Learning demand before spending on scale infrastructure.

The decision is commercial/product-operational, not a failure of the API integration.

## What was implemented historically

The repository still contains the reviewed MessageCentral implementation:

- `supabase/migrations/20260919181500_1035_v13_messagecentral_phone_trust_challenges.sql`
- `supabase/migrations/20260919182000_1036_v13_phone_trust_explicit_browser_deny.sql`
- `supabase/functions/phone-trust-messagecentral/index.ts`
- `tests/messagecentral-phone-trust.test.mjs`

The implementation proved the provider-neutral trust pattern:

1. external provider proves possession;
2. provider OTP is never stored by Raahi;
3. only successful provider verification can update Supabase Auth phone confirmation;
4. `auth.users.phone_confirmed_at` remains the intended post-pilot trust clock;
5. existing 90-day freshness behavior can resume later.

This evidence may be useful when implementing a future provider, but MessageCentral itself is not selected.

## Active deployed state

The deployed Edge Function is intentionally sealed:

`phone-trust-messagecentral` version 6

Deployed source:

`supabase/functions/phone-trust-messagecentral/pilot-disabled-index.ts`

Behavior:

- JWT verification enabled;
- returns HTTP 410;
- returns `PHONE_PROVIDER_DISABLED_DURING_GOOGLE_ONLY_PILOT`;
- performs no outbound provider call;
- sends no SMS;
- changes no Auth or database state.

The public controlled-pilot release also declares:

- `phoneTrustMode = controlled_pilot_google_only`
- `phoneTrustProvider = disabled`

Therefore the UI and server both agree that no phone verification occurs in the controlled pilot.

## Existing secrets

MessageCentral credentials were configured in Supabase during provider evaluation.

They are not used by the sealed v6 function.

They should be removed from Supabase secrets when convenient because they are no longer required. Do not expose them in chat or source control.

## Future preferred direction

After pilot traction, the current preferred additional trust channel is:

**Direct Meta WhatsApp Business Platform Cloud API**

Google remains primary login.

The intended mature flow is:

**Google sign-in → normal Raahi use → selected sensitive action → WhatsApp OTP → 90-day fresh phone trust → resume action**

A dedicated My Raahi business phone number/SIM and complete Meta production setup are intentionally deferred until the pilot proves sufficient value to justify them.

## Rule

Do not reactivate MessageCentral merely because its old integration code exists.

Any future phone provider must be selected again on:

- current commercial terms;
- real delivery proof;
- security;
- provider reliability;
- minimum commitment;
- user experience;
- ability to preserve Raahi's server-authoritative trust model.
