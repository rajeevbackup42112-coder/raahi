# Raahi Learning V1.3 — Hosted Auth + Walking Skeleton Runbook

Status: **EXECUTION RUNBOOK — ACTIVE GATE R1 → R4**

Project: `iiwwmqokaeflaenhlyip`  
Region: `ap-south-1`  
Supabase URL: `https://iiwwmqokaeflaenhlyip.supabase.co`

This runbook is deliberately narrow. It proves the external Auth boundaries and then one complete user-value chain. It must not become another broad implementation pass.

## 1. Known starting state

At the 2026-09-13 checkpoint:

- project is `ACTIVE_HEALTHY`;
- packaged V1.3 frontend points to the canonical project and active publishable key;
- `auth.users` = **0**;
- `auth.identities` = **0**;
- `public.accounts.auth_user_id` has a unique index;
- 1020/1021 phone-trust projection/guards are already applied and runtime-tested;
- Security Advisor after 1021 = **0 findings**;
- the repository-root `.env` points to an older Raahi mobility project and is **not** a Raahi Learning Auth source. Do not repoint it casually.

## 2. Evidence discipline

For every R1/R4 step capture:

1. browser action performed;
2. Auth user ID before/after;
3. Raahi Account ID before/after;
4. relevant canonical RPC result/error;
5. relevant PostgreSQL business row/state;
6. authorized projection seen by each actor;
7. notification/deep-link if expected;
8. classification of any failure: Domain / Integration / Implementation / Test-Harness.

Do not use fixture-mode business output as proof of a real boundary.

## 3. Google configuration preflight

### Google Cloud OAuth client

Use a Web application OAuth client.

For the hosted Supabase project, Google Authorized redirect URI must include:

`https://iiwwmqokaeflaenhlyip.supabase.co/auth/v1/callback`

For a localhost proof served on port 4173, Google Authorized JavaScript origins should include:

`http://localhost:4173`

Use only basic identity scopes required by Supabase/Raahi: `openid`, email and profile. Do not request unrelated Google scopes.

### Supabase hosted Auth

In project `iiwwmqokaeflaenhlyip`:

- enable Google provider;
- enter the matching Web Client ID/secret;
- configure Site URL / redirect allow list for the exact local proof URL;
- for the current static V1.3 proof, use:
  `http://localhost:4173/index.html`
  as the exact browser return URL if that is the page being served;
- do not use the old mobility domain/project as a shortcut.

The V1.3 browser already removes private invitation bearer query parameters before starting Google OAuth.

## 4. Google proof — exact assertions

### Baseline SQL

Before first Google login:

```sql
select count(*) as auth_users from auth.users;
select count(*) as auth_identities from auth.identities;
select count(*) as raahi_accounts from public.accounts;
```

Expected for the current pristine Auth project: Auth users/identities are zero. Existing `public.accounts` may contain only synthetic DB-test fixtures if any survived; normal runtime suites should roll back.

### Browser action

1. Serve reconstructed V1.3 source on `http://localhost:4173`.
2. Open `http://localhost:4173/index.html`.
3. Choose `Continue with Google`.
4. Complete Google consent/sign-in using a designated DEV test Google identity.
5. Return to the same Raahi page.

The browser bootstrap should:

- obtain a real Supabase session;
- call `get_my_account_context()`;
- if it receives `ACCOUNT_NOT_FOUND`, derive the Google display name only as an onboarding default and call `bootstrap_account(p_display_name)`;
- re-read `get_my_account_context()`.

### After-login SQL

```sql
select
  u.id as auth_user_id,
  u.email,
  u.phone,
  u.phone_confirmed_at,
  u.raw_app_meta_data->>'provider' as primary_provider,
  u.created_at,
  u.last_sign_in_at
from auth.users u
order by u.created_at;

select
  i.user_id,
  i.provider,
  i.provider_id,
  i.created_at
from auth.identities i
order by i.user_id, i.created_at;

select
  a.id as account_id,
  a.auth_user_id,
  a.display_name,
  a.lifecycle_status,
  a.created_at
from public.accounts a
join auth.users u on u.id=a.auth_user_id
order by a.created_at;
```

PASS requires:

- exactly one new Auth user for the Google identity;
- a Google identity belonging to that same Auth user;
- exactly one Raahi Account for that Auth user;
- no duplicate `accounts.auth_user_id` mapping;
- user can edit Raahi display name independently of Google profile defaults.

### Logout/login continuity

Record `auth_user_id` and `account_id`, sign out, then sign in again with the same Google identity.

PASS requires both IDs to remain unchanged.

Wrong-Google-account behavior is a separate adversarial case; do not merge two Google identities merely because emails/names look related.

## 5. Phone hosted-Auth configuration preflight

Before live phone proof, record the hosted Auth settings that materially affect safety:

- phone provider enabled;
- SMS provider or fixed DEV test OTP configured;
- OTP expiration;
- minimum resend frequency/rate limit;
- test phone mappings, if used;
- test-OTP validity end time, if supported.

No fixed DEV OTP mapping may be copied to production.

The connected database tool cannot configure this hosted Auth surface. Do not add a Raahi fake OTP endpoint to compensate.

## 6. Initial phone attachment proof

### Preflight read-only duplicate check

Before initiating attachment:

```sql
select
  nullif(trim(phone_change),'') as pending_phone,
  count(*) as pending_rows,
  min(phone_change_sent_at) as oldest_sent_at,
  max(phone_change_sent_at) as newest_sent_at
from auth.users
where nullif(trim(phone_change),'') is not null
group by nullif(trim(phone_change),'')
having count(*) > 1;
```

Expected in clean DEV: zero duplicate pending phone-change groups.

Do not introduce a unique index on Supabase-managed `auth.users.phone_change`.

### Browser/Auth action

For the signed-in Google test user:

1. record current Auth user ID, Account ID and Google identity;
2. enter a designated DEV E.164 test phone;
3. call supported Supabase `updateUser({ phone })`;
4. enter the real hosted/test OTP;
5. verify with `type: 'phone_change'`;
6. capture returned Auth user ID;
7. re-read `get_my_phone_trust()`.

### Post-attach SQL

```sql
select
  u.id,
  u.email,
  u.phone,
  u.phone_confirmed_at,
  u.phone_change,
  u.phone_change_sent_at,
  u.updated_at
from auth.users u
order by u.created_at;

select user_id, provider, provider_id, created_at
from auth.identities
order by user_id, provider;

select a.id as account_id, a.auth_user_id, a.display_name
from public.accounts a
join auth.users u on u.id=a.auth_user_id
order by a.created_at;
```

PASS requires:

- Auth user ID before/after is identical;
- same Raahi Account ID remains mapped;
- Google identity remains linked;
- phone identity, if created by Auth, belongs to the same Auth user;
- confirmed phone is the intended phone;
- `phone_confirmed_at` is recent;
- pending phone-change state is cleared;
- `get_my_phone_trust()` returns `fresh`.

Then sign out and Google-sign-in again. PASS requires the same Auth user ID and Account ID.

## 7. Pending `phone_change` hardening gate

Current Supabase Auth has a documented edge case where duplicate stale `phone_change` values can cause `phone_change` verification to resolve the wrong Auth row.

Before production readiness, implement vendor-aligned hygiene only after hosted OTP expiry is known:

- grace period > configured OTP validity + safety margin;
- clear only stale pending phone-change state;
- Raahi-managed attach fails closed if another non-stale pending claim exists for the normalized phone;
- post-verification Auth user continuity is mandatory;
- no direct uniqueness/index modification to Supabase-managed `phone_change` without explicit vendor support.

For the first pristine DEV walking-skeleton proof, the duplicate query above must be empty before proceeding.

## 8. Periodic same-phone trust refresh proof

Use the same already-confirmed phone. Do **not** try to force refresh with `updateUser({ phone: samePhone })`.

1. record Auth user ID, Account ID, confirmed phone and old `phone_confirmed_at`;
2. make the trust projection stale in an isolated DEV test setup only, without changing relationships/authority;
3. request phone OTP for the already-confirmed phone with user creation disabled;
4. verify normal `sms` OTP;
5. capture returned session/user;
6. require returned Auth user ID = starting Auth user ID;
7. require confirmed phone unchanged;
8. require Google identity still linked;
9. require `phone_confirmed_at` > old value;
10. require `get_my_phone_trust()` = `fresh`;
11. retry the preserved canonical command.

After this OTP proof creates an OTP-authenticated session, Google remains Raahi's normal sign-in UX. Sign out and Google-sign-in again; the same Auth user and Raahi Account must return.

## 9. Mandatory R4 walking skeleton

Use two distinct real DEV Auth identities: learner/guardian side and provider side.

### Learner/guardian side

1. real Google sign-in;
2. Account/bootstrap/context succeeds;
3. create/select Learner context through normal UI/canonical RPC;
4. select Location if required;
5. authorized teacher/provider discovery loads;
6. send Enquiry through canonical command.

Evidence:

- Enquiry row exists once;
- learner-side `get_my_enquiries()` / `get_my_conversations()` shows it;
- provider receives authorized Enquiry projection/notification;
- unrelated Account cannot read it.

### Provider side

7. distinct real Google identity signs in;
8. enable/setup teaching if required;
9. provider sees the Enquiry;
10. provider engages/replies;
11. provider sends Class Invitation.

Evidence:

- same Enquiry state transition is visible to both authorized sides;
- Class Invitation is `pending`;
- pending Invitation reserves capacity;
- learner-side notification/deep link resolves only through current authorization.

### Phone interruption / resume

12. arrange learner-side trust as missing/stale for the acceptance command;
13. attempt Class Invitation acceptance;
14. canonical command must reject with phone-trust requirement without corrupting Invitation/capacity;
15. preserve intended action in browser without embedding a reusable bearer in OAuth/notification URL;
16. complete real supported phone proof;
17. re-read trust = `fresh`;
18. resume the same acceptance command;
19. command rechecks current Invitation state, authority and capacity;
20. Membership is created exactly once.

### Class + message

21. both sides open the Class through authorized projections;
22. exchange one contextual Class message;
23. receiving side gets a safe notification/deep link;
24. unrelated Account cannot read the thread/message.

## 10. Database evidence queries for R4

Use IDs captured from the UI/RPC results; do not identify rows by display names alone.

```sql
select * from public.enquiries where id = '<captured-enquiry-id>'::uuid;
select * from public.class_invitations where id = '<captured-invitation-id>'::uuid;
select * from public.class_memberships where class_id = '<captured-class-id>'::uuid and learner_id = '<captured-learner-id>'::uuid;
select * from public.class_learner_threads where class_id = '<captured-class-id>'::uuid and learner_id = '<captured-learner-id>'::uuid;
select * from public.class_learner_messages where thread_id = '<captured-thread-id>'::uuid order by created_at;
select recipient_account_id, notification_type, source_type, source_id, created_at
from public.notifications
where source_id in ('<captured-enquiry-id>'::uuid,'<captured-invitation-id>'::uuid,'<captured-class-id>'::uuid)
order by created_at;
```

When validating privacy, use authorized public projections/RPCs as the user actors. Direct SQL is evidence of stored state, not proof that a client can read it.

## 11. R4 PASS definition

R4 passes only if all of these are simultaneously true:

- both actors are real hosted Auth users;
- Account continuity is proven;
- no fixture-mode business result substitutes for a real RPC/state transition;
- Enquiry → engagement → Invitation → trust interruption → phone proof → acceptance → Membership is one coherent chain;
- capacity/invitation invariants hold;
- phone proof does not change Raahi authority;
- same Auth user survives phone proof and later Google login;
- contextual Class messaging works;
- notifications deep-link safely;
- unrelated actor denial is demonstrated;
- no direct operational-table browser mutation occurs;
- no fake OTP exists;
- cleanup leaves only intentional DEV test identities/data.

## 12. Current external blocker

At this checkpoint, the connected Supabase plugin exposes database/project operations but not the hosted Auth provider/test-OTP configuration endpoint, and the authorized Remote Desktop device is offline.

Therefore the only legitimate next external action is to obtain an authorized hosted-Auth/browser surface (Supabase Dashboard/Management API plus browser) and execute this runbook. Until then, do not start another horizontal product implementation pass and do not deploy.