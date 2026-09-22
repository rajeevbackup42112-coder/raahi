# Raahi Learning — Current Execution Handover — First Real Teacher Proof — 2026-09-23

Status: **V1.4H PHONE TRUST PUBLIC LIVE — FIRST REAL TEACHER PROOF IN PROGRESS — START TEACHING HOME ENTRY FIX PUBLIC LIVE**

Repository: `rajeevbackup42112-coder/raahi`
Branch: `raahi-learning-implementation-v1`
Supabase: `iiwwmqokaeflaenhlyip`
Region: `ap-south-1`
Public origin: `https://learning.myraahi.co.in`
Cloudflare Pages project: `raahi-learning-prod`

Remote Desktop Commander:
- device: `Dipti`
- device id: `931e6073-983d-4a7c-92b6-71f04d7efe8c`

Local repo:
`C:\Users\Dipti\Downloads\raahi-cutover-20260920`

## 1. Working style / non-negotiable execution rules

Continue autonomously until a genuine product/business decision or unavoidable real-human action is required.

Do not:
- restart product planning;
- redesign frozen business rules;
- recreate the database;
- silently elevate privileges;
- manufacture Teachers, demand, Learning Requests, reviews, comments, reactions, enquiries, popularity or traction;
- publish assisted Teacher details without the real Teacher's explicit acceptance;
- expose provider secrets, OTPs, service-role keys or auth tokens;
- run destructive production cleanup;
- use direct frontend table DML for consequential writes.

Canonical consequential writes go through server RPCs.
PostgreSQL remains the source of truth.
Realtime only invalidates/refetches.

Use **AI Builder Cheat Code v2.0 / Implementation Cheat Code** discipline when a new slice is actually needed:
problem/rules/invariants/states/recovery/data/flows/contracts/tests → architecture/DB → one vertical slice.

## 2. Frozen product rules that still govern this work

- One platform, one Account, many possible learning/teaching/organization relationships.
- Location is discovery/community context, not account membership.
- Dhanbad + Gomoh are both live.
- Gomoh-first promotion does not restrict users to Gomoh.
- Account != Learner.
- No public Learner directory.
- No unrestricted DM.
- Community is authenticated/local.
- No public ratings/reviews.
- Ads are education-only and Sponsored-labelled.
- Production data must be genuine.
- Google is the normal sign-in.
- Phone OTP is **not** a second login. It is only a fresh-trust check for selected sensitive commands.
- Assisted Teacher onboarding: Raahi may prepare only a private bounded draft after a genuine Teacher asks; only that same Teacher can publish the exact draft.

## 3. Current public application

Latest application source SHA:

`b48fd7387e97f6df7c8324c73ad951c883b8c96b`

Commit:

`Expose Start teaching from Home`

GitHub CI:
- workflow: Raahi Learning Model Tests
- run #670
- run ID: `35793714334`
- conclusion: **success**

Current production Cloudflare deployment:
- ID: `22e74407-4a03-4614-a032-54d5c6765ce7`
- branch: `main`
- source: `b48fd73`
- exact URL: `https://22e74407.raahi-learning-prod.pages.dev`
- custom domain: `https://learning.myraahi.co.in`

Immediate frontend rollback anchor:
- deployment: `33e55d0e-a346-46d4-a756-0c580a5b08f4`
- source: `5d864733af9f32c6de6f604764e82d26f04856a6`

Custom-domain verification at handover:
- `build-meta.json` reports exact `b48fd7387e97f6df7c8324c73ad951c883b8c96b`
- `delight-v14.js` contains `Are you a teacher?`
- it contains `data-route="teacher-setup">Start teaching`
- no StartMessaging secret/key pattern appears in that public asset

The user has **not yet visually re-confirmed this new CTA on the mobile account after refreshing**. That is the very next browser observation.

## 4. Why the user could not see Start teaching

The user signed in on mobile as:

`mrrajeevsinha2112@gmail.com`

The screenshot showed the ordinary learner/parent-style Home:
- Dhanbad hero at that moment
- Find a teacher
- I need tuition
- Home / Explore / My / Community / Messages
- no visible Start teaching action

The backend Account exists and is active, but currently has:
- no `teach` capability
- no Learners
- no Organizations
- no manager scopes
- no other capabilities

The live core already had:
- `#/onboarding-intent`
- `#/teacher-setup`
- `Start teaching`
- the V1.4C assisted flow

The problem was **discoverability**: returning users with no authorized workspaces land on Home, but Home did not expose a path back into Teacher setup.

### Fix now public

Commit `b48fd73...` adds a small Home affordance for any Account without `teach`:

> Are you a teacher? **Start teaching**

It routes to `#/teacher-setup`.

Files changed:
- `apps/raahi-learning/delight-v14.js`
- `apps/raahi-learning/delight-v14.css`
- `tests/delight-v14.test.mjs`

It does **not** grant teacher capability merely by rendering the button.

## 5. Exact real Teacher test Account state

Account:
- email: `mrrajeevsinha2112@gmail.com`
- display name: `Rajeev Sinha`
- lifecycle: active

At handover, server-side `get_my_account_context()` returned:
- capabilities: `[]`
- learners: `[]`
- organizations: `[]`
- manager_scopes: `[]`
- selected Location: **Gomoh**

Important: the earlier mobile screenshot showed **Dhanbad**, while the later authoritative server snapshot showed **Gomoh**. Do not assume which city the Teacher wants. Before submitting the genuine assistance request, explicitly verify the Location currently shown in the app and switch it if necessary.

Phone trust for this Teacher Account:
- state: `unverified`
- has_phone: false

Current genuine supply state for this Account:
- assisted Teacher onboarding requests: **0**
- Teacher Profiles: **0**

Nothing has been published and no Teacher capability has been silently granted.

## 6. Exact next user journey to prove

After the user refreshes the current Home page, expected path:

1. Home displays:
   **Are you a teacher? Start teaching**
2. Tap **Start teaching**.
3. V1.4C `teacher-setup` page should appear.
4. Because `founding-supply-v14c.js` overrides this route, the page should offer:
   - **Set it up myself**
   - **Ask Raahi to help**
5. For the first real Founding Supply proof, choose **Ask Raahi to help**.
6. Verify the intended Location before submitting.
7. On `#/founding-supply-help`, tap **Ask Raahi to help**.
8. The system calls:
   `request_assisted_teacher_onboarding(p_location_id, p_idempotency_key)`
9. A real private request should be created.
10. Nothing public should exist yet.

Do **not** choose **Set it up myself** for this first proof unless the user explicitly decides to abandon the assisted Founding Supply proof. That button invokes the normal `enable_teaching` path.

## 7. Phone-trust behavior during this Teacher proof

Production runtime is now:

`phone_trust_mode = phone_trust_required`

StartMessaging is the active OTP delivery provider for trust-sensitive actions.

Important command behavior verified at handover:
- `request_assisted_teacher_onboarding` → **does NOT require fresh phone trust**
- `enable_teaching` → **does NOT require fresh phone trust**
- `accept_assisted_teacher_onboarding` → **DOES require fresh phone trust**

Therefore the real Teacher should be able to **request Raahi's help first without attaching a phone**.

The phone check should become relevant later when that same Teacher tries to publish the prepared assisted draft.

For first phone attach:
- UI asks for a normal 10-digit Indian mobile number
- Raahi adds `+91` automatically
- pasted `+91...`, `91...`, and leading-zero forms are normalized
- StartMessaging only delivers the server-generated OTP
- OTP plaintext is never persisted
- Supabase Auth remains the durable holder of confirmed phone / `phone_confirmed_at`
- fresh trust lasts 90 days

## 8. StartMessaging / V1.4H state

Permanent provider migration:

`20260922150119_v14f_startmessaging_phone_trust`

Permanent enforcement activation:

`20260922214214_v14h_activate_startmessaging_phone_trust`

Security cleanup:

`20260922214728_v14h_remove_public_phone_trust_policy_projection`

Edge Function:
- `phone-trust-startmessaging`
- ACTIVE
- version 4
- JWT verification enabled
- secret `STARTMESSAGING_API_KEY` exists only in Supabase Edge Function Secrets

MessageCentral remains sealed/dormant.

V1.4H has already proven:
- real StartMessaging provider send
- real hosted Raahi OTP send
- same Google Auth user after verification
- same Raahi Account
- phone trust became fresh
- logout → Google login continuity
- protected command allowed for fresh user
- unverified rollback user denied
- zero synthetic residue

Read:
- `116-v14h-startmessaging-phone-trust-public-live-evidence-2026-09-23.md`
- `117-current-execution-handover-v14h-public-live-2026-09-23.md`

## 9. Founding Supply implementation already public

Canonical contract:

`101-founding-supply-assisted-teacher-onboarding-contract-v1.4c.md`

Frontend:

`apps/raahi-learning/founding-supply-v14c.js`

Teacher routes:
- `teacher-setup`
- `founding-supply-help`

Operator route:
- `founding-supply`

Teacher-side RPCs:
- `get_my_assisted_teacher_onboarding`
- `request_assisted_teacher_onboarding`
- `cancel_assisted_teacher_onboarding`
- `decline_assisted_teacher_onboarding`
- `accept_assisted_teacher_onboarding`

Operator-side RPCs:
- `get_platform_assisted_teacher_onboarding`
- `prepare_assisted_teacher_onboarding`
- `withdraw_assisted_teacher_onboarding`

Assisted state flow:

`requested -> draft_ready -> accepted`

Alternative terminal paths include decline/cancel/withdraw.

### Critical invariant

The Local/Global operator may prepare a **private draft only**.

The operator cannot publish it for the Teacher.

Only `accept_assisted_teacher_onboarding` by the same authenticated Teacher may create the public Teacher Profile + first Teaching Option.

## 10. Operator authority already live

Global Platform Admin:
- `choudhary.ajit2112@gmail.com`

Gomoh Local Manager:
- `rajeev.backup1.2112@gmail.com`
- Gomoh only

Dhanbad Local Manager:
- `rajeev.backup2.2112@gmail.com`
- Dhanbad only

The V1.4D city-scope rules are already server-enforced.

When the genuine Teacher request exists:
- the correct city Local Manager may prepare it;
- the Global Platform Admin may also operate genuine requests;
- a Local Manager must not be able to operate the other city's request.

## 11. Exact continuation after the Teacher submits the request

Once the real request exists:

1. Query/read it first; do not fabricate details.
2. Confirm its founding Location and state = `requested`.
3. Open the correct Local Manager workspace (or Global Admin).
4. Navigate to **Founding Supply**.
5. Verify only the genuine request appears.
6. Prepare the draft using only real Teacher-provided information.
7. If the real details are not yet supplied, stop and ask the user/Teacher for the missing factual fields rather than inventing them.
8. Send the private draft for Teacher review.
9. Teacher signs in again.
10. Teacher opens setup help and sees the exact private draft.
11. On **Publish these details**, phone trust is expected to gate because `accept_assisted_teacher_onboarding` requires fresh phone trust.
12. Complete real StartMessaging verification on the Teacher's own phone.
13. Teacher personally presses **Publish these details**.
14. Verify server-side:
    - request = accepted
    - exactly one Teacher Profile is created/owned by this Account
    - exactly one initial Teaching Option exists
    - provenance is assisted as designed
    - Location is correct
    - no duplicate profile/option
15. Verify Explore in the same Location shows the genuine Teacher supply.
16. Verify normal Teacher workspace/edit/availability controls work after acceptance.
17. Document evidence and only then repeat with a very small genuine founding cohort.

## 12. Immediate next action in the new chat

Do **not** write more code first.

Ask the user to refresh the current mobile Home page.

Expected new UI beneath the Home hero:

**Are you a teacher? Start teaching**

If visible:
- tap **Start teaching**
- choose **Ask Raahi to help**
- verify intended Location
- submit the genuine request

If it is still not visible after a hard refresh:
1. verify public `build-meta.json` is still `b48fd7387e97f6df7c8324c73ad951c883b8c96b`;
2. inspect whether mobile cache/service-worker behavior is serving an old `delight-v14.js`;
3. do not add another duplicate CTA until the cache/render cause is known.

## 13. Current production/DB safety notes

- Production data is real user data.
- No fake seed supply.
- No current assisted request for the real Teacher test Account.
- No Teacher Profile for that Account.
- Do not silently run `enable_teaching`.
- Do not create a draft before a real request.
- Do not invent bio/experience/subject/fee/location.
- Do not expose phone number, OTP, StartMessaging key, service role or tokens in docs/chat.
- Do not redeploy merely because this handover doc advances the Git branch; deployed app source should remain `b48fd73...` until app code changes again.

## 14. Useful tool/runtime details

Remote Desktop Commander can go offline; device:
`931e6073-983d-4a7c-92b6-71f04d7efe8c`

Wrangler JS currently available under:
`C:\Users\Dipti\AppData\Local\npm-cache\_npx\32026684e21afda6\node_modules\wrangler\bin\wrangler.js`

Windows PowerShell may block `npx.ps1`; use `npx.cmd` or Node + Wrangler JS directly.

Build reconstruction needs PATH ordering with Windows System32 before Git usr/bin to avoid Git tar interpreting `C:\...` as a remote path.

Do not use TinyFish unless its wallet has been topped up; it previously exhausted funds.

## 15. Recommended read order

1. **This file**
2. `117-current-execution-handover-v14h-public-live-2026-09-23.md`
3. `116-v14h-startmessaging-phone-trust-public-live-evidence-2026-09-23.md`
4. `101-founding-supply-assisted-teacher-onboarding-contract-v1.4c.md`
5. `105-scoped-market-activation-authority-contract-v1.4d.md`
6. `108-global-admin-location-admin-management-contract-v1.4e.md`
7. `92-market-activation-seeding-blueprint-v1.4.md`
8. `99-handover.md`

The new chat should verify current state read-only first and then continue from the mobile **Start teaching** visibility check. Do not restart planning.
