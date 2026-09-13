# Raahi Learning V1.3 — Phone Trust Technical Resolution

Status: **IMPLEMENTATION RESOLUTION FOR THE FROZEN POLICY IN `41-authentication-phone-trust-v1.3.md`.**

This document does not change which actions require fresh phone trust. It resolves how freshness is represented and proven server-side.

## 1. Finding

Current Supabase Auth behavior provides a simpler durable source of truth than the provisional application-column design in section 3 of the frozen policy.

Supabase Auth owns `auth.users.phone_confirmed_at`.

Current Auth implementation behavior verified from Supabase documentation/source:

- confirming a signed-in user's phone change (`verifyOtp(..., type: 'phone_change')`) sets the confirmed phone and updates `phone_confirmed_at`;
- successful SMS OTP verification (`verifyOtp(..., type: 'sms')`) calls the Auth phone-confirmation path and refreshes `phone_confirmed_at`;
- the timestamp is therefore server-owned Auth evidence, not a browser-provided claim.

## 2. V1.3 implementation decision

Do **not** add `accounts.phone_trust_verified_at`.

For V1.3, derive trust directly from the currently authenticated Supabase Auth user:

- `unverified`: no confirmed Auth phone / no `phone_confirmed_at`;
- `fresh`: confirmed phone exists and `phone_confirmed_at + 90 days > now()`;
- `stale`: confirmed phone exists but that 90-day window has expired.

This is implemented by DEV migration:

`1020_v13_phone_trust_projection`

Public authenticated read projection:

`get_my_phone_trust()`

Private helpers:

- `app_private.read_my_phone_trust()`
- `app_private.has_fresh_phone_trust()`
- `app_private.require_fresh_phone_trust()`

No client-supplied timestamp or boolean is accepted.

## 3. Initial phone verification

For a Google-authenticated Account that does not yet have a confirmed phone:

1. user enters their phone in the Raahi phone-check UX;
2. browser calls Supabase Auth `updateUser({ phone })`;
3. Supabase sends the phone-change OTP;
4. browser verifies using `verifyOtp({ phone, token, type: 'phone_change' })`;
5. Supabase Auth updates the user's confirmed phone and `phone_confirmed_at`;
6. `get_my_phone_trust()` immediately derives `fresh`;
7. the original Raahi action is resumed and its canonical command revalidates current business state/authority.

The confirmed phone-change event itself is sufficient fresh proof. No second Raahi "confirm trust" write is necessary.

## 4. Periodic re-verification

When the same confirmed phone becomes stale:

1. preserve the intended Raahi action/draft;
2. call phone OTP sign-in for the already-linked phone with user creation disabled;
3. verify the SMS OTP normally;
4. successful Supabase SMS verification refreshes `auth.users.phone_confirmed_at` and returns a valid session;
5. verify that the returned Auth user ID is the same user that initiated the phone check;
6. re-read `get_my_phone_trust()`; it must now be `fresh`;
7. resume the original canonical Raahi command.

The Raahi UI does not expose phone OTP as its normal login button; Google remains the primary login UX. Supabase necessarily treats the verified phone as an Auth identity once linked, which is an implementation property rather than a Raahi role/authority grant.

## 5. Why JWT AMR is not the durable source

Supabase JWTs expose Authentication Methods Reference (`amr`) entries and OTP sign-in produces an `otp` authentication method. AMR is useful session evidence, but V1.3 does not need to persist or trust it as the long-lived phone-freshness clock because:

- `phone_confirmed_at` is durable across sessions;
- it is owned by Supabase Auth;
- current SMS verification refreshes it;
- it directly corresponds to control of the currently associated phone;
- it avoids maintaining a second application timestamp and synchronization rules.

## 6. Security invariants

- `auth.users.phone_confirmed_at` is read server-side only through the private trust helper.
- The browser cannot submit a freshness timestamp.
- An unconfirmed/no-phone user is never considered fresh.
- A 90-day-expired confirmation is stale.
- Phone freshness is still **not authorization**; all original relationship/capability/state checks remain mandatory.
- Existing learning/Test/safety actions listed as non-gated in policy 41 remain non-gated.
- A resumed action after OTP must execute the normal canonical command; no stale client intent bypasses current server state.
- The periodic OTP flow must use `shouldCreateUser: false` so a typo/new number cannot silently create another Auth user.
- The client must compare the Auth user ID before and after periodic OTP verification and fail safely on any mismatch.

## 7. Runtime evidence

DEV smoke marker:

`V13_PHONE_TRUST_PROJECTION_PASS`

The smoke verifies:

- no-phone → `unverified`;
- 91-day-old confirmation → `stale`;
- recent confirmation → `fresh`;
- private fresh-trust guard rejects unverified/stale states;
- changing the Auth-owned confirmation timestamp changes derived trust without any client/app timestamp;
- anonymous callers cannot read the projection.

Supabase Security Advisor after migration 1020: **0 findings**.

## 8. Remaining external proof

This technical model is implemented and database-tested, but hosted Auth still needs real environment evidence:

- Google provider must be configured/enabled in the DEV Supabase Auth project;
- phone provider/test OTP mapping must be configured in hosted DEV Auth;
- at least one real Google → phone-change OTP → periodic SMS OTP round trip must be executed against hosted Auth;
- frontend resume behavior must then be validated in the 25-persona E2E cohort.

The connected Supabase database tool does not expose hosted Auth provider/test-OTP configuration. Do not add fake application OTP logic to work around that boundary.
