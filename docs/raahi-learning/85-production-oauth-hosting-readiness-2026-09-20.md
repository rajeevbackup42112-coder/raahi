# Raahi Learning V1.3 — Production OAuth + Hosting Readiness — 2026-09-20

Status: **PREPARED — NO PUBLIC DEPLOYMENT YET**

This document records the exact external-integration state reached after the Stage Ready handover in doc 84.

## 1. Release anchor

Implementation branch:
`raahi-learning-implementation-v1`

Release candidate source anchor:
`19283d62664d92cf45bd4916640d62b6643131b0`

The controlled-pilot browser source was reconstructed from this exact commit and both canonical source integrity anchors passed.

Offline CONTROLLED_PILOT packaging also passed.

Candidate metadata:
- release mode: `CONTROLLED_PILOT`
- origin: `https://learning.myraahi.co.in`
- Supabase project: `iiwwmqokaeflaenhlyip`
- phone trust mode: `controlled_pilot_google_only`
- phone trust provider: disabled
- DEV login/proof entry points: absent

Release guard regression:
- 8 tests
- 8 PASS
- 0 FAIL

Prepared local ZIP:
`raahi-learning-controlled-pilot-19283d6.zip`

ZIP SHA-256:
`810537844CC47D39591D685BAA543D79C4277558BFBDC743D419C9AC0EB6A1CA`

The ZIP contains exactly 10 public files:
- `index.html`
- `styles.css`
- `live.js`
- `app.live-core-v13.js`
- `live-product-fix-v13.js`
- `live-thread-deeplink-v13.js`
- `launch-polish-v13.js`
- `privacy.html`
- `terms.html`
- `build-meta.json`

The ZIP is an operator-side prepared artifact only and is not committed to source control.

## 2. Production Google OAuth — complete pre-public configuration

Dedicated Google Cloud project:
**Raahi Learning Production**

Google Auth Platform app:
**Raahi Learning**

Audience:
**External**

Publishing status:
**Testing**

Current test users:
1

Scopes configured:
- `openid`
- `userinfo.email`
- `userinfo.profile`

Sensitive scopes:
0

Restricted scopes:
0

Branding configured:
- homepage: `https://learning.myraahi.co.in/`
- privacy: `https://learning.myraahi.co.in/privacy.html`
- terms: `https://learning.myraahi.co.in/terms.html`
- authorized domain: `myraahi.co.in`

Dedicated Web OAuth client:
**Raahi Learning Production Web**

Authorized JavaScript origin:
`https://learning.myraahi.co.in`

Authorized redirect URI:
`https://iiwwmqokaeflaenhlyip.supabase.co/auth/v1/callback`

The Google Client Secret was transferred directly from Google Cloud to Supabase Auth through the authenticated browser. It was not sent through chat or committed to GitHub.

## 3. Supabase Auth — current pre-cutover state

Learning project:
`iiwwmqokaeflaenhlyip`

Google provider:
**Enabled**

Production Google credentials:
**Installed**

Current Site URL remains intentionally:
`https://dev.learning.myraahi.co.in`

This was preserved so current DEV behavior remains stable before public deployment.

Current redirect allow-list includes DEV entries plus:
- `https://learning.myraahi.co.in/`
- `https://learning.myraahi.co.in/**`

No public-origin auth proof has been run yet because the public origin does not exist.

## 4. Google domain verification

Google Search Console already has a verified Domain Property for:
`myraahi.co.in`

Public DNS contains an existing Google site-verification TXT record.

Therefore Google domain ownership is already established under the current Google account.

Final production/publishing verification can proceed after the public homepage/policy URLs exist.

## 5. Cloudflare hosting — current state

Cloudflare account is authenticated.

Existing DEV Pages project:
**raahi-learning-dev**

Existing DEV domains:
- `dev.learning.myraahi.co.in`
- `raahi-learning-dev.pages.dev`

DEV production branch:
`raahi-learning-implementation-v1`

Automatic deployments:
**Enabled**

Current deployed DEV commit observed:
`19283d62664d92cf45bd4916640d62b6643131b0`

Current DEV build:
- root: `/apps/raahi-learning`
- command: `node build-source-v13.mjs && cp hosted-auth-proof-v13.html reconstructed-v13/hosted-auth-proof-v13.html`
- output: `/reconstructed-v13`

### Hosting decision

Do **not** attach the public pilot domain to `raahi-learning-dev`.

Reason:
the DEV project automatically deploys every implementation-branch commit and includes DEV-only engineering artifacts.

Recommended public pilot hosting:
**separate Cloudflare Pages project using Direct Upload of the already-built controlled-pilot candidate**.

This makes production deployment explicit and prevents future DEV commits from auto-publishing to real users.

No production Pages project has been created yet because creating/uploading it would make a public deployment and crosses the explicit deployment-approval gate.

## 6. DNS — current state

Authoritative nameservers:
- GoDaddy `ns77.domaincontrol.com`
- GoDaddy `ns78.domaincontrol.com`

Existing DEV record:
- `dev.learning` CNAME → `raahi-learning-dev.pages.dev`

Production hostname:
`learning.myraahi.co.in`

Current production DNS state:
**unused / no record**

Therefore the production hostname can be added without disturbing DEV.

The future production CNAME must be created in GoDaddy after the dedicated public Pages project exists.

## 7. Support mailbox — operational

Required public address:
`support@myraahi.co.in`

Provider:
**Zoho Mail Forever Free organization**

Organization:
**Raahi Learning**

Domain ownership:
**verified**

Mailbox:
**support@myraahi.co.in**

The mailbox is the first Zoho organization user and is active.

GoDaddy DNS now carries the exact Zoho India mail records:

MX:
- `@ → mx.zoho.in`, priority 10
- `@ → mx2.zoho.in`, priority 20
- `@ → mx3.zoho.in`, priority 50

SPF:
- `@ TXT v=spf1 include:zoho.in ~all`

DKIM:
- host `zmail._domainkey`
- Zoho-generated RSA public key published exactly as supplied by Zoho.

Existing Google site-verification TXT, DMARC and non-mail application records were preserved.

Authoritative GoDaddy DNS verification passed for:
- all three MX records;
- SPF;
- DKIM;
- Zoho domain-verification TXT.

Independent public resolver verification passed through:
- Google Public DNS `8.8.8.8`;
- Cloudflare resolver `1.1.1.1`.

Live mail proof:
- outbound mail from `support@myraahi.co.in` reached `choudhary.ajit2112@gmail.com`;
- inbound mail from `choudhary.ajit2112@gmail.com` reached the Zoho inbox for `support@myraahi.co.in`.

Zoho setup wizard reports:
**Your setup is complete!**

Therefore the public support-address launch prerequisite is closed.

## 8. Remaining sequence

Before public-origin proof:

1. functional `support@myraahi.co.in` — **DONE**;
2. obtain explicit product-owner approval to create the public Pages deployment;
3. create a separate Cloudflare Pages Direct Upload project;
4. upload the exact prepared controlled-pilot artifact;
5. attach `learning.myraahi.co.in`;
6. add the required GoDaddy CNAME;
7. verify homepage, Privacy and Terms publicly;
8. switch Supabase Site URL from DEV to public origin at controlled-pilot cutover;
9. run real production-Google sign-in proof;
10. complete any Google production/publishing checks now that public URLs exist;
11. continue the controlled-pilot backup/cleanup/writer-seal/geography/canary sequence from doc 78;
12. stop again for explicit final go-live approval before admitting real users.

## 9. Explicitly not done

- no public production Pages deployment;
- no `learning.myraahi.co.in` DNS record;
- no Supabase Site URL cutover;
- no synthetic cleanup;
- no harness Auth deletion;
- no DEV writer marker removal;
- no `dev-test-identities` seal deployment;
- no Gomoh activation;
- no controlled-pilot canary;
- no real users admitted.
