# Raahi Learning V1.3 — Hosted Auth + R4 Live Evidence Checkpoint

Status: **R1 PASS THROUGH PHONE TRUST; R4 IN PROGRESS**

Date: 2026-09-13  
Supabase DEV project: `iiwwmqokaeflaenhlyip`  
Hosted DEV origin: `https://dev.learning.myraahi.co.in`

## Proven hosted Auth state

### Google OAuth / Account continuity

Primary learner-side DEV identity:
- Google email: `rajeev.backup1.2112@gmail.com`
- Auth user ID: `580f39b5-4341-4473-af7d-301b8245263b`
- Raahi Account ID: `8c96dbc0-9627-48e2-86a1-3ec72e42e7ec`
- Account lifecycle: `active`

Real Google OAuth completed successfully on the hosted DEV origin. The first-account bootstrap defect discovered during execution was corrected by migration 1022 so that an authenticated Auth user without a Raahi Account yields `ACCOUNT_NOT_FOUND` rather than `AUTH_REQUIRED`; the canonical bootstrap path then creates exactly one Account.

### Phone attachment / trust

Primary learner-side confirmed phone is stored by Supabase as `919000000001`.

Evidence:
- Auth user ID preserved across phone attachment.
- Raahi Account ID preserved across phone attachment.
- pending `phone_change` cleared.
- `phone_confirmed_at`: `2026-09-13T18:35:13Z`.
- `get_my_phone_trust()` returned `fresh`.
- trust valid until `2026-12-12T18:35:13Z`.

A harness-only comparison defect was found because the browser input used `+919000000001` while Supabase returned `919000000001`. The hosted proof harness now normalizes phone strings before continuity comparison. No Auth/domain behavior changed.

Harness normalization commit: `0f79ac5180b05b14b95b3515b6d2b16cbdc745b0`.

## R4 learner state

Learner created through the canonical flow:
- learner ID: `c47ca00d-26dd-48c3-a7e4-5be33d2fad06`

`get_my_account_context()` succeeded after creation.

## DEV environment provisioning discovered during R4

R4 discovery initially blocked because DEV contained zero Locations and zero active platform administrators.

This was classified as **DEV environment provisioning**, not a domain/business-rule defect.

### First DEV platform administrator

Dedicated DEV test identity:
- Google email: `rajeev.backup5.2112@gmail.com`
- Auth user ID: `3edc69c1-2cd5-4c40-9d53-79e90aa9e393`
- Raahi Account ID: `aa859365-b999-4338-9974-0c6d500a6e40`

A one-time, guarded DEV-only bootstrap granted `platform_admin` with `granted_by_account_id = NULL`. The bootstrap refuses to run if an active platform administrator already exists and records a system audit event. It is deliberately stored outside `supabase/migrations/` so it cannot be applied automatically to production.

DEV bootstrap source:
`supabase/dev-provisioning/2026-09-13-learning-dev-bootstrap-platform-admin.sql`

Bootstrap-source commit: `7d00afd31ee82e146c89541831847df0fedb3fb0`.

All normal future capability changes remain governed by the canonical `grant_account_capability()` / `revoke_account_capability()` commands.

### Dhanbad Location

The Location itself was NOT inserted directly. After Backup5 held `platform_admin`, provisioning used the existing canonical commands:

1. `create_location()` → `interest_only`
2. `set_location_state()` → `preparing`
3. `set_location_state()` → `live`

Provisioned Location:
- location ID: `028ee066-2130-45d6-8e17-6ceb9b0f1f80`
- name: `Dhanbad`
- slug: `dhanbad`
- region: `Dhanbad`
- state/province: `Jharkhand`
- country: `IN`
- lifecycle state: `live`

The canonical command audit trail remains authoritative for the Location creation/state transitions.

## Current gate

R4 may now continue from the learner-side Location selection/discovery step.

Still required for R4 PASS:
- select Dhanbad for learner-side context;
- provision/enable provider-side teaching as needed;
- discovery;
- Enquiry;
- provider engage/reply;
- Class Invitation;
- trust interruption/resume behavior where applicable;
- Membership exactly once;
- contextual Class message;
- notification/deep-link evidence;
- unrelated-user denial.

Do not restart product/domain design. Any further failure must first be classified as Domain / Integration / Implementation / Test-Harness / DEV Provisioning before changing behavior.
