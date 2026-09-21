# Raahi Learning — Scoped Market Activation Authority Contract V1.4D

Status: **IMPLEMENTATION CONTRACT — LOCATION-SCOPED OPERATIONS**

Parent decisions:
- Gomoh admin: `rajeev.backup1.2112@gmail.com`
- Dhanbad admin: `rajeev.backup2.2112@gmail.com`
- Global admin requested: `choudhary.ajit2112@gmail.com`

## 1. Problem

Raahi Desk and Founding Supply were initially restricted to `platform_admin`.

That was safe for the walking skeleton, but it conflicts with the operating model now chosen for expansion:

- each Location has its own local admin;
- that admin should operate local market activation;
- local authority must not silently become cross-city authority;
- a separate global Platform Admin remains the super-admin for cross-Location operations.

## 2. Authority model

### Global Platform Admin

An Account with active `platform_admin` capability may:
- publish Raahi Desk content in any live Location;
- view Founding Supply requests across all live Locations;
- prepare a Founding Supply draft for any request;
- withdraw an unaccepted Founding Supply request in any Location;
- continue using existing global Platform surfaces.

### Local Manager

An Account with active `location_staff_assignments.staff_type='local_manager'` may:
- publish Raahi Desk content only in assigned active Location(s);
- view Founding Supply requests only in assigned active Location(s);
- prepare a Founding Supply draft only for requests in assigned active Location(s);
- withdraw an unaccepted Founding Supply request only in assigned active Location(s).

A Local Manager may not:
- see another Location's Founding Supply queue;
- publish Raahi Desk into another Location;
- prepare or withdraw another Location's assisted onboarding;
- gain global Platform surfaces merely because they are a Local Manager.

## 3. Source of truth

Server authorization remains authoritative.

Client role/navigation checks are convenience and usability only.

Every consequential command must re-check:
- authenticated active Account;
- global `platform_admin`, OR
- active `local_manager` assignment for the exact target Location.

## 4. Raahi Desk

Canonical RPC remains:

`public.publish_raahi_desk_post(...)`

Authorization becomes:

`platform_admin OR local_manager(target_location)`

All existing provenance rules remain frozen:
- public author = Raahi Desk;
- badge = Platform-authored;
- internal operator retained for audit;
- no fake comments/reactions/demand;
- provenance = `platform_editorial`.

Audit metadata records whether authority came from:
- `global_platform`; or
- `location_local_manager`.

## 5. Founding Supply

### Operational queue

Existing read RPC remains:

`public.get_platform_assisted_teacher_onboarding(state?)`

The name is retained for compatibility, but semantics become:

- Platform Admin: all eligible requests;
- Local Manager: only requests whose founding Location is in that manager's active scope;
- unscoped Account: denied.

### Prepare

`public.prepare_assisted_teacher_onboarding(...)`

The command first resolves the request's founding Location and then authorizes against that exact Location.

### Withdraw

`public.withdraw_assisted_teacher_onboarding(...)`

The command resolves the request's founding Location and authorizes against that exact Location.

### Teacher acceptance

Teacher-side request/review/accept/decline/cancel authority is unchanged.

Local Manager authority never substitutes for Teacher consent.

## 6. UI contract

### Manager workspace

Manager navigation gains:
- Raahi Desk
- Founding Supply

Raahi Desk:
- local admin sees the assigned Location as the operational Location;
- a one-Location manager does not get a global Location-switch control in the composer;
- client refuses an out-of-scope target before calling the server.

Founding Supply:
- queue copy explicitly states the Location scope;
- server response is already filtered to authorized Locations;
- no cross-city requests are rendered.

### Platform workspace

Global Platform navigation retains:
- Raahi Desk
- Founding Supply

Global operator may change Location and sees cross-Location Founding Supply requests.

## 7. Invariants

1. Local Manager is never equivalent to Platform Admin.
2. Every local market-activation command is bound to a concrete Location.
3. Local Manager authorization is checked server-side for that exact Location.
4. Founding Supply queue filtering is server-side.
5. Client-side filtering is not a security boundary.
6. Teacher consent and assisted provenance rules remain unchanged.
7. Raahi Desk provenance and anti-fake-activity rules remain unchanged.
8. No new raw table grants are introduced.
9. Existing global Platform Admin behavior remains valid.
10. Audit evidence distinguishes global vs Location-scoped operator authority.

## 8. Acceptance tests

- Gomoh Local Manager can publish Raahi Desk in Gomoh.
- Gomoh Local Manager cannot publish Raahi Desk in Dhanbad.
- Dhanbad Local Manager can publish Raahi Desk in Dhanbad.
- Gomoh Local Manager Founding Supply queue excludes Dhanbad.
- Dhanbad Local Manager Founding Supply queue excludes Gomoh.
- Local Manager can prepare only requests in assigned Location.
- Local Manager can withdraw only requests in assigned Location.
- Unscoped Account cannot read the operational queue.
- Global Platform Admin sees both Locations and can operate both.
- Preparing a draft still creates no public Teacher supply.
- Existing Teacher acceptance remains the only path that materialises assisted public supply.
- Existing self-service organic Teacher path is unchanged.

## 9. Global-admin bootstrap boundary

The user selected `choudhary.ajit2112@gmail.com` as the global admin.

The connected database execution safety layer blocks direct first-time creation of the global `platform_admin` capability as a privileged escalation.

Do not bypass that safety guard through an alternate tool path.

If no existing Platform Admin is available to call the canonical grant command, perform one explicit user-visible/manual first-admin bootstrap in Supabase, with the existing zero-admin guard and audit record. After the first global admin exists, all future capability grants/revocations must use canonical audited commands.
