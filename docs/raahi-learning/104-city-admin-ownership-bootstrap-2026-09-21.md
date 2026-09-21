# Raahi Learning — City Admin Ownership Bootstrap — 2026-09-21

Status: **LIVE — LOCATION-SCOPED ADMIN OWNERSHIP ESTABLISHED**

## Decision

The user designated:

- `rajeev.backup1.2112@gmail.com` as the **Gomoh admin**
- `rajeev.backup2.2112@gmail.com` as the **Dhanbad admin**

This was implemented as existing canonical Location-scoped authority:

`location_staff_assignments.staff_type = 'local_manager'`

It was **not** implemented as global `platform_admin`.

## Why

Raahi already separates:
- global, unscoped Platform authority via `account_capabilities.platform_admin`;
- Location-scoped operational authority via `location_staff_assignments.local_manager`.

The user's wording was explicitly city-specific, so assigning global Platform authority would have exceeded the requested scope.

## Identity bootstrap

Both Google identities already existed in Supabase Auth from prior genuine Google sign-ins, but their Raahi `accounts` rows were absent after the historical cleanup.

They were re-created through the canonical:

`public.bootstrap_account(...)`

path while impersonating the matching authenticated Auth UID.

No synthetic Auth user was created.

## Live assignments

### Gomoh

Google identity:
`rajeev.backup1.2112@gmail.com`

Raahi Account:
`618293b0-ed8f-4813-bd50-17826944a54a`

Location:
- name: Gomoh
- ID: `0e181491-a468-47ae-8c6a-a6b1920d5524`
- state: live

Assignment:
- staff type: `local_manager`
- assignment ID: `5fe00ea3-51bf-41b8-8d72-8ae21d924a6f`
- status: active
- global Platform Admin: **false**

### Dhanbad

Google identity:
`rajeev.backup2.2112@gmail.com`

Raahi Account:
`f84c2bf8-5bee-4542-82e6-4b83ed1cc25e`

Location:
- name: Dhanbad
- ID: `028ee066-2130-45d6-8e17-6ceb9b0f1f80`
- state: live

Assignment:
- staff type: `local_manager`
- assignment ID: `a41aadaa-e23c-452d-858a-7328756403cc`
- status: active
- global Platform Admin: **false**

## Audit

The one-time environment bootstrap recorded system audit entries:

`ops.bootstrap_local_manager`

for each Location-scoped assignment.

Normal future Location-manager assignment/removal should use the existing canonical Platform-governed commands once a global Platform authority path exists.

## Runtime verification

`public.get_my_account_context()` was executed under each genuine Auth UID.

Verified:
- backup1 has one manager scope: Gomoh / local_manager / live;
- backup2 has one manager scope: Dhanbad / local_manager / live;
- neither Account has an unscoped capability;
- neither Account has `platform_admin`.

## Important current boundary

V1.4B Raahi Desk publishing and V1.4C Founding Supply Platform queue currently require `platform_admin`, not `local_manager`.

Therefore these two city admins can use existing Local Manager surfaces for their assigned Location, but **they cannot yet operate Raahi Desk or prepare Founding Supply drafts**.

Do not silently widen this authority.

The next product decision is whether:
1. Raahi Desk and Founding Supply should remain global-Platform-only and a separate global Platform Admin should be chosen; or
2. those workflows should gain carefully Location-scoped Local Manager authority so Gomoh and Dhanbad admins can operate only within their own city.
