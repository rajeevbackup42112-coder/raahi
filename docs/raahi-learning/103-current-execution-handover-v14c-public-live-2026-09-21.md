# Raahi Learning — Current Execution Handover — V1.4C Public Live — 2026-09-21

Status: **V1.4C PUBLIC LIVE — FOUNDING SUPPLY WALKING SKELETON GREEN — NEXT GATE IS PLATFORM ADMIN OWNERSHIP**

Repository: `rajeevbackup42112-coder/raahi`
Branch: `raahi-learning-implementation-v1`
Supabase: `iiwwmqokaeflaenhlyip`
Public origin: `https://learning.myraahi.co.in`

## 1. Read order

1. `103-current-execution-handover-v14c-public-live-2026-09-21.md`
2. `102-v14c-founding-supply-public-live-evidence-2026-09-21.md`
3. `101-founding-supply-assisted-teacher-onboarding-contract-v1.4c.md`
4. `100-current-execution-handover-v14b-public-live-2026-09-21.md`
5. `98-v14b-raahi-desk-public-live-evidence-2026-09-21.md`
6. `92-market-activation-seeding-blueprint-v1.4.md`
7. `99-handover.md`

Do not restart V1.4A, V1.4B or V1.4C launch qualification.

## 2. Exact production state

V1.4C is live on the existing Cloudflare Pages project `raahi-learning-prod`.

Production:
- deployment ID: `18f52dbf-fbb7-4371-906a-09734f0fb9df`
- branch: `main`
- Pages URL: `https://18f52dbf.raahi-learning-prod.pages.dev`
- custom origin: `https://learning.myraahi.co.in`
- deployed application SHA: `c990d9a8b854b362d88bb4e1b7b8cf99a6538d95`

Immediate rollback anchor:
- deployment ID: `42f1a854-a4e7-41a4-8e7a-dd4edf8f921d`
- Pages URL: `https://42f1a854.raahi-learning-prod.pages.dev`
- V1.4B source SHA: `3735e7e2717a04043bd7af7552a7b0b5ec757622`

Final V1.4C release manifest hash:

`3d65a65ea8b394eafad639450b0fc33f420e0ec0467d43ba7f21582c8d734a7d`

## 3. Repository state

Application deployment commit:
- `c990d9a8b854b362d88bb4e1b7b8cf99a6538d95`
- CI run #652, ID `35585071238`, passed.

After production deployment, migration-history filenames were aligned to Supabase's actual applied versions:
- repository commit `42772f6fdf799db59d540e4777d432088a0bdc28`
- GitHub Model Tests run **#653**, ID `35587700337`, passed;
- no application/browser behaviour change;
- no production redeploy required.

The alignment prevents future migration tooling from replaying already-applied V1.4C migrations.

## 4. Permanent V1.4C migrations

Actual Supabase history:

1. `20260921093234_v14c_founding_supply_assisted_teacher_onboarding`
2. `20260921093410_v14c_founding_supply_fk_indexes`
3. `20260921093510_v14c_founding_supply_explicit_browser_deny`

The private assistance ledger is RLS-enforced and explicitly denies direct authenticated browser access. Browser workflows use canonical RPCs.

## 5. Frozen Founding Supply rule

The first assisted Teacher slice is:

> Teacher requests help -> Raahi prepares private draft -> same Teacher reviews -> same Teacher explicitly publishes.

Never convert this into:
- platform-created Teacher accounts;
- pre-published Teacher profiles;
- silent consent;
- admin acceptance on behalf of a Teacher;
- fake supply, demand or engagement.

Only first-time Teacher setup is eligible for the walking skeleton.

If the Account already has Teacher/Profile/Teaching Option data, use normal self-service controls instead.

## 6. State machine

Assistance states:
- `requested`
- `draft_ready`
- `accepted`
- `declined`
- `cancelled`
- `withdrawn`

Only `accepted` materialises canonical public Teacher supply.

`requested` and `draft_ready` must remain private.

## 7. Authority

Teacher can:
- request help for self;
- read own exact proposal;
- accept;
- decline;
- cancel.

Platform Admin can:
- read genuine requested queue;
- prepare bounded private draft;
- withdraw an unaccepted request.

Platform Admin cannot:
- create the request for a silent Teacher;
- accept for the Teacher;
- directly publish a Teacher profile/option through this slice.

## 8. Current live activation state

At handover:
- active Platform Admins: **0**
- assisted onboarding requests: **0**
- assisted Teacher Profiles: **0**
- assisted Teaching Options: **0**
- synthetic test users: **0**

Therefore the infrastructure is live but not yet operationally activated.

The release canary deliberately did not press **Ask Raahi to help** for the real test Account.

## 9. Production canary closure

Green:
- exact production build-meta SHA;
- zero public hash mismatches;
- zero forbidden public matches;
- Home;
- Explore;
- Community;
- Messages;
- Teacher Setup;
- Teacher Setup Help;
- ordinary Account denied Platform Founding Supply;
- Dhanbad -> Gomoh -> Dhanbad;
- signed-out/InPrivate Welcome;
- Privacy 200 after canonical redirect;
- Terms 200 after canonical redirect.

Teacher Setup shows:
- **Set it up myself**
- **Ask Raahi to help**

Teacher Setup Help states:
- private draft;
- Teacher review;
- nothing public before Teacher publication.

## 10. Preview defect that must remain covered

The first preview on `fd7ead3...` revealed that a signed-out direct assisted-Teacher route rendered Welcome but still attempted the private read RPC in the background.

That was fixed in `c990d9a...` by requiring valid session/context before assisted reads.

Regression coverage now asserts the session/context guard.

Do not remove this guard.

## 11. Current admin ownership and next genuine decision

City-scoped ownership is now established:
- `rajeev.backup1.2112@gmail.com` = Gomoh `local_manager`;
- `rajeev.backup2.2112@gmail.com` = Dhanbad `local_manager`.

Neither Account has global `platform_admin`.

See `104-city-admin-ownership-bootstrap-2026-09-21.md`.

The next genuine product decision is authority scope for market activation:

1. keep Raahi Desk + Founding Supply global-Platform-only and choose a separate global Platform Admin; or
2. extend those workflows with carefully Location-scoped Local Manager authority, so each city admin may operate only inside the assigned Location.

Do not silently widen Local Manager authority and do not grant global Platform Admin merely to make the screens accessible.

Then repeat with a very small founding cohort before broader promotion.

## 12. Next product slices after the real Teacher proof

Do not start these before the real walking skeleton is proven:
- assisted coaching-organisation onboarding;
- carefully governed unclaimed organisation listings;
- truthful Founding Teacher recognition;
- Raahi Desk editorial activation;
- broader Gomoh-first launch seeding.

## 13. Operational rules

Do not expose:
- DB password;
- service-role key;
- OAuth client secret;
- auth session/token;
- OTP;
- Cloudflare credentials;
- GitHub credentials.

Production data is real.

No synthetic writer or hidden fake-supply path should be introduced.

Desktop Commander remains the preferred authenticated browser/workstation path.

TinyFish wallet was exhausted during V1.4B closure; do not depend on it for the next step unless balance is restored.
