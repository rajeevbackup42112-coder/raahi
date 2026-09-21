# Raahi Learning — Current Execution Handover — V1.4A Public Live — 2026-09-21

Status: **V1.4A PUBLIC LIVE — NEXT SLICE IS MARKET ACTIVATION / SEEDING**

Repository: `rajeevbackup42112-coder/raahi`
Branch: `raahi-learning-implementation-v1`
Supabase: `iiwwmqokaeflaenhlyip`
Public origin: `https://learning.myraahi.co.in`

## 1. Read order in the next chat

1. `96-current-execution-handover-v14a-public-live-2026-09-21.md`
2. `95-v14a-public-live-evidence-2026-09-21.md`
3. `92-market-activation-seeding-blueprint-v1.4.md`
4. `91-investor-delight-screen-redesign-plan-v1.4.md`
5. `90-emotional-design-blueprint-v1.4.md`
6. `99-handover.md`
7. `89-public-go-live-evidence-2026-09-20.md`

Do not restart product design, V1.4A qualification or public-launch work.
## 2. Exact public-production state

V1.4A is now live on the existing Cloudflare Pages project `raahi-learning-prod`.

Production deployment:
- ID: `14245932-652a-44cd-adcf-a86a425ea5fe`
- production branch: `main`
- Pages URL: `https://14245932.raahi-learning-prod.pages.dev`
- custom domain: `https://learning.myraahi.co.in`
- exact source SHA: `36f13d49c1c330e3334d89fa06dd090f67650bd7`

Immediate rollback anchor:
- deployment ID: `3dcf61d0-9cb5-4ef7-9ec5-dc4b672bc52f`
- URL: `https://3dcf61d0.raahi-learning-prod.pages.dev`
- prior public `build-meta` SHA: `19283d62664d92cf45bd4916640d62b6643131b0`

Final V1.4A release checksum:
`713e0e47a28b57b83629339197b65df419ca35e970849897e6371301a79af33a`
## 3. Qualification closure

Exact final CI:
- GitHub Model Tests run #647
- run ID `35528092771`
- exact SHA `36f13d49...`
- success

Final local checks:
- focused V1.4/launch tests: 7/7
- production guards: 49/49
- model/property cases: 5,349,572 with 0 failures
- production-like load guard: 9/9

Production verification after upload:
- public `build-meta.json` exact SHA match
- public raw-file SHA mismatch count: 0
- DEV/secret/stale-copy public matches: 0
- authenticated Home: green
- Explore: green
- Community: green
- Messages: green
- Dhanbad -> Gomoh -> Dhanbad: green
- Privacy/Terms: green
- Google OAuth entry redirects correctly to Google
## 4. Frozen V1.4A Home

Home remains:

- selected Location
- **Find. Learn. Grow.**
- **Teachers and learning near you.**
- **Find a teacher**
- **I need tuition**
- **Your learning** only when useful
- **For you in <Location>**
- maximum two compact provider/learning cards
- richer discovery stays in Explore
- ad section heading **Featured**
- every actual ad still labelled **Sponsored**

Principle:

> Home = discovery + momentum, not product documentation.

Do not re-expand Home into a text-heavy product explanation.
## 5. Frozen product boundaries

Do not reopen:
- one platform, one Account identity, many Locations
- Location is browsing/discovery/community context, not Account membership
- Dhanbad + Gomoh stay live/selectable
- Gomoh-first promotion is not a geographic permission gate
- Account != Learner
- no turning-18 lifecycle
- no public Learner directory
- no unrestricted direct messaging
- Community remains local/authenticated
- canonical RPCs own consequential writes
- PostgreSQL remains source of truth
- realtime only invalidates/refetches
- no public ratings/reviews
- ads remain education-only, Sponsored-labelled and excluded from private/Class/Test surfaces
- Google OAuth is public / External / In production
- production data is real user data

Do not recreate DEV writers or synthetic production demand.
## 6. Exact next product slice

The next work is **not another visual redesign**.

Start from:

`92-market-activation-seeding-blueprint-v1.4.md`

The objective is to make Gomoh and Dhanbad feel alive without fabricating marketplace truth.

Required provenance distinction:
- organic user activity
- assisted/onboarded activity
- legitimate seeded/editorial/platform-created public material where explicitly allowed
- unclaimed organization/provider information where provenance is visible
- never fake teachers
- never fake learning requests
- never fake reviews/ratings
- never fake engagement

Raahi Desk / market activation tooling belongs in this separate slice.
## 7. Working method for the next slice

Before coding the seeding/backend slice, use the existing AI Builder discipline only for the **new domain concepts**:
rules -> actors/authority -> provenance -> states -> invariants -> permissions -> UI contracts -> tests -> architecture/database.

Do not redo the already-frozen core Raahi Learning model.

For any new consequential write:
- use a canonical RPC
- preserve auditability
- preserve provenance
- keep truthful public rendering
- define failure/recovery
- test RLS/authority boundaries

Build one vertical slice at a time and require a real E2E proof before broad expansion.
## 8. Operational notes

The workstation release folders remain outside Git and are not canonical source.

Do not expose:
- Supabase DB password
- service-role secrets
- OAuth client secret
- GitHub credentials
- Cloudflare credentials
- Auth sessions/tokens
- OTPs

Temporary preview OAuth redirect used during V1.4A QA was removed. Supabase redirect configuration was restored before production deployment.

Production rollback is available through the preserved prior Cloudflare deployment if a future regression is discovered.

## 9. Immediate continuation

1. Commit/push this deployment evidence and handover.
2. Verify GitHub CI on the documentation commit if triggered.
3. Read doc 92 completely.
4. Convert the market-activation/seeding blueprint into the smallest safe backend/domain vertical slice.
5. Continue autonomously until a genuine business/product decision is required.
