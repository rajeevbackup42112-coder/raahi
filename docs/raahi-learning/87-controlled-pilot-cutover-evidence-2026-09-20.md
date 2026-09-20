# Raahi Learning V1.3 — Controlled-Pilot Cutover Evidence — 2026-09-20

> Superseded for current production state by `89-public-go-live-evidence-2026-09-20.md`. This file remains the technical cutover evidence.

Status: **READY FOR FINAL GO-LIVE APPROVAL — REAL PILOT USERS NOT YET ADMITTED**

Repository: `rajeevbackup42112-coder/raahi`  
Branch: `raahi-learning-implementation-v1`  
Supabase project: `iiwwmqokaeflaenhlyip`  
Public origin: `https://learning.myraahi.co.in`  
Prepared release source anchor: `19283d62664d92cf45bd4916640d62b6643131b0`

## 1. Public deployment and release integrity

- Separate Cloudflare Pages Direct Upload project: `raahi-learning-prod`.
- Public custom domain: `learning.myraahi.co.in`.
- GoDaddy CNAME: `learning -> raahi-learning-prod.pages.dev`.
- HTTPS/TLS and public origin return HTTP 200.
- All 10 deployed release files were downloaded from both the Pages hostname and the custom domain and matched the prepared release candidate byte-for-byte by SHA-256.
- `build-meta.json` reports `release_mode=CONTROLLED_PILOT`, origin `https://learning.myraahi.co.in`, project ref `iiwwmqokaeflaenhlyip`, and source commit `19283d62664d92cf45bd4916640d62b6643131b0`.
- DEV login marker is absent from the public origin.
- Privacy and Terms are deployed from the hash-verified release artifact.

## 2. Production Google OAuth proof

- Google OAuth project/client: production Raahi Learning client.
- Google publishing status remains **Testing**; the app has not been published to the general public.
- Supabase Google provider uses the production client.
- Supabase Site URL is `https://learning.myraahi.co.in`; DEV and public redirect URLs remain explicitly allow-listed.
- Real Google OAuth completed successfully on the public origin.
- Two explicitly allowed Google test users completed genuine Google sign-in through the production client.
- Both identities bootstrapped fresh Raahi Accounts through the normal product path after synthetic cleanup.

## 3. Pre-cleanup recovery boundary

A logical off-platform database backup completed before destructive cleanup at UTC `20260920T095507Z`.

Backup contents:

- `roles.sql` SHA-256 `168a95a9c745af5ed4679751f90419ac9dc434240a213b03e32a06d5664c2308`
- `schema.sql` SHA-256 `ae33919b21771b1ee2f3ddde5990f8a72489fbd909a58c971cc0221b01f089c0`
- `data.sql` SHA-256 `0cab9beb31c70ee07909dbc9a1fc8b4a0cf4e032cc55b9a5c8d0df63bda9adeb`
- Storage objects at backup precheck: `0`.
- Credential material is not stored in the manifest.
- A restore rehearsal is still a future paid-production requirement; this pilot evidence proves backup creation and checksum integrity, not a completed restore.

## 4. Synthetic cleanup and writer seal

- Fail-closed public-domain cleanup executed in one transaction.
- All non-Location `public` application tables were emptied.
- `public.locations` was preserved.
- Exactly 70 Auth users marked by authoritative metadata `raahi_test_harness=true` were deleted.
- Harness Auth users remaining: `0`.
- Reviewed genuine/non-harness Auth users preserved: `8`.
- Storage objects remained `0`.
- All 17 synthetic writer workflows are manual-only and retain their missing-marker guard.
- `.github/RAAHI_LEARNING_DEV_WRITES_ENABLED` is deleted.
- Writer-seal guardrails passed 46/46 and the backend-free model suite passed 5,349,572 cases with zero failures.
- GitHub Model Tests passed on the writer-seal commit `63569e955bf6cf6bc3df8f00e34fff9ae87e4308`.
- `dev-test-identities` is sealed at version 19 with JWT verification enabled and a fixed non-mutating HTTP 410 response.
- All retired MessageCentral custom Edge Function secrets were removed; no custom Edge Function secrets remain.

## 5. Pilot geography and trust state

- Dhanbad remains `live`.
- Gomoh transitioned from `preparing` to `live` under guarded SQL.
- Dhanbad and Gomoh are the only live Locations.
- `phone_trust_mode = controlled_pilot_google_only`.
- `phone_trust_enforcement_enabled = false`.
- Anonymous `list_public_locations` remains denied on the public API with HTTP 401 / permission denied.
- The authenticated location projection returns exactly `dhanbad` and `gomoh` for both genuine canary users.
- The second genuine canary changed Selected Location to Gomoh; `get_my_account_context()` subsequently returned `selected_location.slug = gomoh` and `state = live`, proving persistence through the canonical projection.

## 6. Genuine Google controlled-pilot canary

The original automated production canary expected password identities. That assumption is incompatible with the frozen Google-only pilot: all eight preserved genuine identities are Google identities and have no password. No password users were created to satisfy the stale harness.

The controlled-pilot canary was therefore executed through the real product/Auth path and database authorization boundary:

- public `build-meta.json`: HTTP 200;
- public release mode: `CONTROLLED_PILOT`;
- DEV-login marker: absent;
- anonymous Location RPC: denied;
- two real Google test users: authenticated successfully through the production OAuth client;
- fresh Raahi Accounts: exactly two distinct active Accounts after their sign-ins;
- canary user A own Account rows: `1`;
- canary user A cross-Account rows: `0`;
- canary user B own Account rows: `1`;
- canary user B cross-Account rows: `0`;
- Account-context RPC returns each user's own Account ID;
- authenticated Location projection healthy for both;
- notification projection healthy for both.

The password-based GitHub canary is now restricted to future isolated non-DEV environments and fails closed for `CONTROLLED_PILOT` mode. The canonical cutover runbook has been updated accordingly.

## 7. Post-cutover database/security health

Observed after cleanup and Gomoh activation:

- latest migration: `20260919202746 / 1038_v13_remove_public_trust_policy_rpc`;
- Auth users: `8` genuine, `0` harness;
- Storage objects: `0`;
- deadlocks: `0`;
- waiting locks: `0`;
- transactions over 30 seconds: `0`;
- public views: `0`;
- public tables without RLS: `0`;
- public tables without forced RLS: `0`;
- public security-definer functions: `0`;
- private security-definer functions executable by PUBLIC: `0`;
- private security-definer functions executable by anon: `0`.

Security Advisor: only the known Free-plan `auth_leaked_password_protection` warning. This is not part of the Google-only pilot sign-in path.  
Performance Advisor: informational unused-index notices only; do not remove indexes merely because the pre-pilot dataset is small.

## 8. Final gate

All technical controlled-pilot cutover prerequisites are now proven except the explicit business action of admitting the pilot audience.

**Do not yet:**

- publish the Google OAuth app to the general public;
- add the broader pilot audience as test users;
- announce or admit real pilot users.

The next irreversible product/operational step is the explicit final go-live approval required by section 12 of the cutover runbook.

## 9. Final runtime snapshot after genuine canary

Observed at `2026-09-20T11:00:50Z` after both genuine Google canaries completed:

- Auth users: `8`; harness Auth users: `0`;
- fresh pilot Accounts: `2`;
- saved Account Location preferences: `1` (Gomoh canary persistence proof);
- audit rows from fresh bootstrap: `2`;
- Learners, Organizations, Teaching Options, Learning Requests, Enquiries, Classes and Notifications: `0`;
- Storage objects: `0`;
- live Locations: `dhanbad`, `gomoh` only.

Final post-correction regression:

- model/property suite: `5,349,572` cases, `0` failures;
- launch guardrail suite: `45/45` passed;
- focused controlled-pilot/canary guards: `21/21` passed;
- `git diff --check`: clean before commit.
