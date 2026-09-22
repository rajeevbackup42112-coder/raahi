# Raahi Learning — Global Admin / Location Admin Management Contract V1.4E

Status: **IMPLEMENTATION CONTRACT — ROUTINE ADMINISTRATION**

After the one-time first Global Admin bootstrap, routine Location-admin management must happen inside Raahi Learning, not through Supabase SQL.

## Authority

Only active `platform_admin` may use the screen or supporting read projections.

Consequential writes stay on existing canonical audited commands:
- `public.assign_local_manager(location_id,target_account_id,idempotency_key)`
- `public.end_location_staff_assignment(assignment_id,reason,idempotency_key)`

The UI never mutates operational tables directly.

## Identity

A future Local Admin must first have a genuine active Raahi Account. The Global Admin enters the exact Google email. If the person has never signed in, Raahi does not manufacture an Account; the UI asks that person to sign in once and retry.

## Read projections

- `get_platform_location_admins()`: Platform-only Location + active Local Manager projection.
- `resolve_platform_account_email(email)`: Platform-only exact case-insensitive lookup; not a fuzzy people directory.

## UI

Platform navigation gains **Location Admins**.

Assign: choose Location → exact email → resolve Account → review existing scopes → confirm → canonical assignment → refresh.

Remove: choose active assignment → provide reason → confirm → canonical end-assignment → refresh.

## Invariants

1. This screen never grants or revokes `platform_admin`.
2. Local Manager authority is always tied to one concrete Location.
3. Email lookup is exact and Platform-only.
4. Target must already be a genuine active Raahi Account.
5. Assignment/removal use canonical audited commands.
6. UI performs no direct table DML.
7. V1.4D city-scoped market-activation rules remain unchanged.
8. Assigning Local Manager grants no other capability.
9. Global Platform Admin does not need Local Manager authority.
