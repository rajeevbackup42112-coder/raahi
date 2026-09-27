# MyRaahi Gate 13D — Cross-Product Identity Handoff Spike Contract v0.1

Last updated: 2026-09-27

Status: **TECHNOLOGY SPIKE CONTRACT — NON-PRODUCTION ONLY**

## Hypothesis

A user already authenticated in Raahi Learn can establish a separate MyRaahi shared-shell session **without**:
- changing Raahi Learn production auth behavior;
- sharing a service-role secret;
- putting access/refresh tokens in a URL;
- copying Learn roles/capabilities into MyRaahi.

## Existing evidence

Raahi Learn production:
- origin: `https://learning.myraahi.co.in`
- Supabase Auth project: `iiwwmqokaeflaenhlyip`
- authenticated session storage key is origin-local: `sb-iiwwmqokaeflaenhlyip-auth-token`
- JWT signing algorithm: `ES256`
- current JWT `kid`: `67fd6db6-e83b-4239-917f-cc55f882562d`
- issuer: `https://iiwwmqokaeflaenhlyip.supabase.co/auth/v1`
- audience: `authenticated`
- public JWKS exposes matching EC/P-256 signing key.

This means MyRaahi can cryptographically validate a Learn access token using public keys.

## Why this is only a handoff spike

Current Learn auth session is stored in browser-origin-scoped storage. Therefore:
- `learning.myraahi.co.in` session does not automatically appear at another origin;
- same brand/domain family does not itself provide SSO;
- a deliberate handoff/session mechanism is required.

## Spike actor

Use an already-authenticated controlled **Explorer/no-authority** Raahi Learn browser persona.

Reason:
- proves human identity continuity;
- avoids confusing Learning admin/teacher capability with shared identity;
- shared MyRaahi session must gain **no product/admin capability** from this proof.

## Handoff flow

1. Existing Learn browser already has valid Supabase session.
2. Browser extracts access token **inside the browser only**.
3. Browser creates a top-level HTTPS POST form to MyRaahi staging:
   `/api/v1/_spike/auth/learning-handoff`
4. Access token is submitted in POST body, never query string.
5. MyRaahi staging validates:
   - JWT signature through public JWKS;
   - exact issuer;
   - audience `authenticated`;
   - expiry;
   - non-empty subject.
6. MyRaahi maps only:
   - issuer
   - subject
   to one staging shared Account.
7. MyRaahi creates a random short-lived staging session.
8. Response sets:
   - Secure
   - HttpOnly
   - SameSite=Lax
   staging cookie.
9. Browser is redirected to staging shell.
10. `GET /api/v1/_spike/auth/me` proves the shared session resolves the same staging Account.

## Staging-only data

### sso_spike_accounts
- id
- issuer
- subject
- created_at
- unique(issuer, subject)

### sso_spike_sessions
- id
- account_id
- created_at
- expires_at

Do not store:
- Google access token;
- Supabase refresh token;
- email;
- Learning role;
- phone;
- professional verification;
- product relationships.

## Security constraints

1. Token is never logged.
2. Token is never persisted.
3. Token never enters URL/query/referrer/history.
4. Exact issuer/audience/expiry/signature are validated.
5. JWKS is public; no service-role secret is required.
6. Resulting shared session has no admin/product capability.
7. Session cookie is staging-origin only.
8. Session TTL is short.
9. Spike routes are clearly namespaced `/_spike/`.
10. Production `myraahi.co.in` and Learning code/config remain unchanged.

## Success criteria

PASS only if:
1. real existing Learn-authenticated Explorer persona completes handoff;
2. MyRaahi validates token cryptographically;
3. one staging Account is created/resolved;
4. browser lands back on MyRaahi staging with HttpOnly session;
5. `/me` returns authenticated shared Account;
6. repeating handoff for the same Learn identity resolves the same Account id;
7. no Learn role/capability appears in MyRaahi;
8. invalid/expired/tampered token is rejected;
9. token/session secrets are absent from logs/URLs.

## Failure / rejection criteria

Reject this architecture if:
- validation requires Learning service-role/JWT private secret;
- token must be placed in URL;
- browser must expose refresh token cross-origin;
- same identity creates duplicate shared Accounts;
- MyRaahi implicitly inherits Learning role/admin authority;
- handoff requires changes to Learning production OAuth settings merely for the spike.

## Design consequence if PASS

This would prove a **federated identity bridge primitive**, not final platform SSO.

Later product decision remains:
- whether Learning Auth becomes temporary shared identity issuer;
- whether MyRaahi becomes the long-term central identity authority;
- whether products consume MyRaahi sessions through a reverse handoff.

No such long-term choice is frozen by this spike.
