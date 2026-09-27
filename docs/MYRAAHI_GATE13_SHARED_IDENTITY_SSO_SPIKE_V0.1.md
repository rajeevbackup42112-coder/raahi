# MyRaahi Gate 13D — Shared Identity / SSO Technology Spike v0.1

Last updated: 2026-09-27

Method: AI Builder Cheat Code v2.0 — Gate 13 Technology Proof

Status: **ARCHITECTURE DIRECTION FROZEN; ONE NON-PRODUCTION IDENTITY-CONTINUITY BROWSER PROOF REMAINS**

Scope:
- MyRaahi shared shell
- Raahi Learn as first focused-product integration
- one durable Raahi human identity
- no production auth migration in this spike

---

## 1. Question being proved

Can Raahi have one durable human identity across multiple focused products without:
- creating a second Account database;
- migrating Raahi Learn's working production auth;
- making phone OTP the universal login;
- sharing private JWT secrets between products;
- making the public MyRaahi shell require sign-in?

---

## 2. Current Raahi Learn auth evidence

Canonical Supabase project:

`iiwwmqokaeflaenhlyip`

Project region:
`ap-south-1`

Public Learn origin:

`https://learning.myraahi.co.in`

Supabase Site URL is currently the public Learn origin.

DEV redirects remain allow-listed.

Historic local hosted-auth proof used:

`http://localhost:4173/index.html`

Raahi Learn currently uses:
- Google as primary authentication;
- Supabase Auth project-wide user identity;
- phone verification as a separate trust primitive;
- product capabilities/relationships separate from authentication.

A live authenticated browser session was inspected read-only.

Observed client storage:
- Supabase session is stored under an origin-local `sb-<project>-auth-token` key;
- only the Learn origin can directly read that localStorage value.

Observed access-token metadata only:
- JWT algorithm: **ES256**
- token type: JWT
- issuer: `https://iiwwmqokaeflaenhlyip.supabase.co/auth/v1`
- audience: `authenticated`
- token has a key ID (`kid`) suitable for JWKS key selection

The access token itself was not copied into documentation.

---

## 3. Current Supabase platform evidence

Current Supabase documentation confirms:

1. Supabase Auth exposes public JWKS for asymmetric JWT verification.
2. ES256 is a recommended asymmetric signing algorithm.
3. A verifier should validate:
   - signature;
   - issuer;
   - audience;
   - expiration;
   - relevant client/session claims where applicable.
4. Automatic identity linking links OAuth identities with the same verified email to one Supabase user in the same project.
5. Supabase Auth can now act as an OAuth 2.1/OIDC server.
6. OAuth 2.1 Server is currently beta and free on all Supabase plans during the beta period.
7. Enabling OAuth-server mode requires:
   - enabling the feature;
   - configuring an authorization path;
   - building an authorization/consent UI;
   - registering clients.

Sources checked through current Supabase docs:
- JWT/JWKS
- Identity Linking
- OAuth 2.1 Server / Getting Started
- OAuth 2.1 Flows
- SSR/session storage guidance

---

## 4. Important distinction

### Identity continuity

Question:

> Is this the same Raahi human?

Recommended authority:
- the existing Supabase Auth user UUID from project `iiwwmqokaeflaenhlyip`.

This is the durable cross-product subject.

### Session continuity

Question:

> Is this browser already signed into this particular Raahi origin/app?

Current Learn implementation:
- origin-local Supabase browser session.

Therefore:

**one identity does not automatically mean one browser session across subdomains.**

This is expected web security behavior, not a defect.

---

## 5. V1 architecture decision

### ADOPT — Shared identity authority

Use the existing Raahi Learn Supabase Auth project as the first shared Raahi identity authority.

A human's canonical Raahi authentication subject is:

`Supabase project iiwwmqokaeflaenhlyip + auth user UUID`

Do not create a parallel Account identity in D1.

### ADOPT — Public shell remains anonymous-first

MyRaahi public catalogue continues to require no Account.

No Supabase client/session is needed merely to:
- choose Location;
- browse Product availability;
- enter public product discovery.

### ADOPT — Product/local sessions may remain separate in V1

When a product needs authentication, it may obtain a session against the shared identity authority on its own origin.

The important V1 invariant is:
- same human resolves to same Raahi auth subject;
- product relationship/capability remains product-owned.

A repeated Google authorization step across products is a UX cost, but not an identity split.

### ADOPT — Token validation without shared secret

When MyRaahi or another backend needs to accept a Supabase access token:
- use the project's public JWKS;
- validate ES256 signature;
- validate issuer;
- validate audience;
- validate expiry;
- apply server-owned Raahi authorization afterward.

Do not share the JWT signing private/legacy secret.

Do not treat a valid JWT as Product/Admin authority.

---

## 6. What V1 does NOT do

Do not:
- copy Learn's localStorage session into another origin;
- put access/refresh tokens in URLs;
- use query parameters as bearer-token transport;
- create a second MyRaahi users table merely to duplicate auth identity;
- make D1 authoritative for Account identity;
- make phone OTP a second Account;
- infer platform/product role from Google metadata;
- migrate Learn's current auth storage before evidence demands it.

---

## 7. True cross-product SSO options considered

### Option A — Same Supabase identity, per-origin sessions

**Mechanism**
Each Raahi product authenticates against the same Supabase project when needed.

**Benefits**
- minimal change to Learn;
- same durable user UUID;
- no new auth backend;
- uses existing Google setup;
- lowest migration/security risk;
- compatible with public-first MyRaahi.

**Cost**
User may need an additional Google auth interaction on a new origin.

**V1 result**
**ADOPT.**

---

### Option B — Supabase OAuth 2.1/OIDC Server as Raahi identity provider

**Mechanism**
Enable the existing Supabase project as OAuth/OIDC IdP and register Raahi products as clients.

**Benefits**
- standards-based;
- existing user base;
- PKCE;
- JWKS;
- client-specific OAuth tokens;
- possible long-term clean app federation.

**Costs/risks**
- feature is beta;
- currently free during beta, so future pricing cannot be assumed;
- requires enabling OAuth-server functionality;
- requires authorization/consent UI;
- requires client registry;
- current Site URL/authorization UI would interact with Learn's production auth surface unless deliberately redesigned;
- more moving parts before a second authenticated product is live.

**V1 result**
**DEFER.**
Retain as the leading true-SSO upgrade candidate after real multi-product login friction exists.

---

### Option C — Shared parent-domain auth cookies / central auth.myraahi.co.in

**Mechanism**
Introduce a central auth application and shared parent-domain cookie/session.

**Benefits**
Potential seamless cross-subdomain session.

**Costs/risks**
- changes Learn's current static/localStorage auth design;
- introduces high-sensitivity custom session infrastructure;
- cookie scope/logout/refresh/CSRF/revocation design required;
- migration risk is high relative to current need.

**V1 result**
**REJECT/DEFER.**

---

### Option D — Custom one-time token broker

**Mechanism**
Product exchanges short-lived handoff code for session.

**Benefits**
Can bridge otherwise independent origins.

**Costs/risks**
Custom security-sensitive protocol, replay/revocation/expiry/storage complexity.

**V1 result**
**REJECT unless a future product constraint proves standards-based options insufficient.**

---

## 8. Data ownership consequence

### D1 public shell

Owns:
- Location
- Product
- LocationProduct
- public configuration

Does NOT own:
- Account identity
- Google identity
- refresh tokens
- phone trust
- product roles

### Supabase Auth

Owns:
- durable authenticated subject
- Google identity
- sessions/tokens
- confirmed phone identity where applicable

### Focused product

Owns:
- Teacher/Parent/Learner/Driver/etc. relationships
- product capabilities
- product transactions
- product-specific verification

---

## 9. Cross-product subject contract

Future Raahi products should refer to the authenticated human using a stable external-auth subject abstraction:

- `auth_issuer`
- `auth_subject`

For the current shared authority:

- issuer = `https://iiwwmqokaeflaenhlyip.supabase.co/auth/v1`
- subject = verified JWT `sub` / Supabase user UUID

A focused product using a separate database may store this pair rather than copying Google identity details.

This keeps future identity-provider migration possible.

---

## 10. Minimum non-production identity-continuity proof

This proof intentionally does not change Supabase Auth configuration.

Preconditions:
- authorized test browser;
- existing known Raahi Learn Google test identity;
- `http://localhost:4173/index.html` still in the existing DEV redirect allow-list;
- same Supabase project and current publishable key.

Procedure:

1. From an existing Learn authenticated session, record the current Supabase user UUID privately in the harness.
2. Do not print/email/document the UUID.
3. Serve a tiny MyRaahi auth proof at `http://localhost:4173/index.html`.
4. Clear only the localhost proof's Supabase session storage.
5. Initialize Supabase client against `iiwwmqokaeflaenhlyip`.
6. Start Google OAuth with redirect back to the exact localhost proof URL.
7. Authenticate with the same designated test Google identity.
8. After return, call `auth.getUser()`.
9. Compare returned UUID to the previously observed Learn UUID.
10. Output only:
   - `same_raahi_subject=true/false`
   - provider
   - issuer
   - session present
11. Sign out of the localhost proof session.
12. Confirm the existing Learn production browser/session remains usable.

Pass criteria:
- same Google human resolves to the same Supabase user UUID;
- no second Raahi Account is created;
- Learn production data/role/context remains unchanged;
- no Supabase configuration change was required.

This is the remaining empirical proof for this spike.

---

## 11. Future true-SSO trigger

Do not build true SSO merely because it is technically possible.

Reopen this architecture only when:
- at least two Raahi products requiring authentication are genuinely live;
- users actually move between them;
- repeated authentication causes measurable friction;
- or a security/operations need justifies central session management.

At that point, reassess Supabase OAuth 2.1/OIDC first.

---

## 12. Gate 13D current result

**ARCHITECTURE DIRECTION: PASS**

**EMPIRICAL IDENTITY-CONTINUITY PROOF: PENDING**

No product/business decision is blocked.

The next action is the localhost two-surface identity proof when an authorized browser device is available.
