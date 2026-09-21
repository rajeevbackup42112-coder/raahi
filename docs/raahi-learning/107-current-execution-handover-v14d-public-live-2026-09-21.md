# Raahi Learning — Current Execution Handover — V1.4D Public Live — 2026-09-21

Status: **V1.4D PUBLIC LIVE — CITY-SCOPED MARKET ACTIVATION GREEN — ONE MANUAL GLOBAL-ADMIN BOOTSTRAP PENDING**

Repo: `rajeevbackup42112-coder/raahi`
Branch: `raahi-learning-implementation-v1`
Supabase: `iiwwmqokaeflaenhlyip`
Public origin: `https://learning.myraahi.co.in`

## Read first

1. `107-current-execution-handover-v14d-public-live-2026-09-21.md`
2. `106-v14d-scoped-market-activation-public-live-evidence-2026-09-21.md`
3. `105-scoped-market-activation-authority-contract-v1.4d.md`
4. `104-city-admin-ownership-bootstrap-2026-09-21.md`
5. `103-current-execution-handover-v14c-public-live-2026-09-21.md`
6. `102-v14c-founding-supply-public-live-evidence-2026-09-21.md`
7. `92-market-activation-seeding-blueprint-v1.4.md`
8. `99-handover.md`

Do not restart V1.4A/B/C/D design or deployment qualification.

## Exact production

Application SHA:
`89edd9c12c8e37a70e1f8fb46faf544ac75fe6b2`

Production deployment:
`6dd2f1d7-3514-47a7-b7b2-631d079a19be`

Production URL:
`https://learning.myraahi.co.in`

Rollback anchor:
`18f52dbf-fbb7-4371-906a-09734f0fb9df` / `c990d9a...`

GitHub Model Tests:
- #656
- ID `35591347033`
- success

Permanent migration:
`20260921105250_v14d_scoped_market_activation_authority`

## Current authority

Gomoh:
- `rajeev.backup1.2112@gmail.com`
- active `local_manager`
- Raahi Desk + Founding Supply only in Gomoh

Dhanbad:
- `rajeev.backup2.2112@gmail.com`
- active `local_manager`
- Raahi Desk + Founding Supply only in Dhanbad

Global requested owner:
- `choudhary.ajit2112@gmail.com`
- active Raahi Account exists
- global `platform_admin` still NOT granted

Do not convert either city manager into global admin.

## Server proof

Real Gomoh and Dhanbad manager identities passed symmetric rollback production proofs:
- own city allowed;
- other city hidden/denied;
- no synthetic residue.

## Manual gate now on screen

Supabase dashboard is authenticated.

The SQL Editor is open and pre-filled with the guarded first-global-admin bootstrap for:

`choudhary.ajit2112@gmail.com`

The assistant did not press Run because the connected database safety layer explicitly blocked assistant-driven first-admin privilege escalation.

The user only needs to press **Run** once in Supabase SQL Editor.

Expected result:
- one row for Ajit;
- `capability_code = platform_admin`;
- `status = active`.

After the user says done, immediately verify read-only:
1. exactly one active Platform Admin;
2. Account/email matches Ajit;
3. `ops.bootstrap_platform_admin` audit exists;
4. `get_my_account_context()` under Ajit's genuine Auth UID contains `platform_admin`;
5. no city-manager scope changed.

Then perform Ajit global browser canary if Ajit's Google session is available.

## Browser gates

The two city-manager Edge windows are currently at Google password prompts.

Do not ask for or store their passwords.

Once the user signs them in manually:
- backup1 should show Manager workspace with Raahi Desk + Founding Supply for Gomoh only;
- backup2 should show Manager workspace with Raahi Desk + Founding Supply for Dhanbad only.

Existing SPA tabs may need one ordinary refresh after a release; CDN assets use `max-age=0, must-revalidate`.

## Next after admin bootstrap

1. Verify global-admin and city-admin UI authority.
2. Onboard one genuine Teacher end-to-end in one Location.
3. Teacher initiates assistance request.
4. Correct city admin prepares private draft.
5. Teacher reviews and accepts.
6. Verify genuine Explore supply.
7. Verify normal Teacher editing/availability controls.
8. Repeat for a very small founding cohort.
9. Then continue Raahi Desk activation / genuine seeding from blueprint 92.

No fake users, demand, reviews, enquiries, matches or engagement.
