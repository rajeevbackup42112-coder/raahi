# Shared Identity Continuity Spike

This is a local-only Gate 13D test harness.

It proves one thing:

> The same designated Google test identity resolves to the same Supabase Auth subject when authenticating from a second already-allow-listed app surface.

It does **not** prove or implement seamless cross-origin SSO.

## Privacy rule

Do not print or commit the Supabase user UUID.

Before running the proof, compute SHA-256 of the existing Raahi Learn user UUID privately and provide only that hash to the generator as `EXPECTED_SUBJECT_SHA256`.

The browser output contains only:

- `session_present`
- `same_raahi_subject`
- provider
- issuer

It never renders the UUID, access token, refresh token, email, or phone.

## Generate locally

From `apps/myraahi-shell`:

```
SUPABASE_URL=...
SUPABASE_PUBLISHABLE_KEY=...
EXPECTED_SUBJECT_SHA256=...
node spikes/shared-identity/generate-proof.mjs
```

On Windows PowerShell, set the environment variables first and run the same Node command.

The generated file is:

`.generated-shared-identity-proof/index.html`

Do not commit that generated directory.

## Run

Serve the generated directory on the already-approved DEV proof origin:

`http://localhost:4173/index.html`

Use the same designated Google test identity already used by Raahi Learn.

Pass:

`same_raahi_subject=true`

After proof, sign out of the localhost proof session and confirm the existing Learn production browser/session remains usable.

## Safety

Do not:
- change Supabase redirect configuration;
- change Google OAuth configuration;
- modify Learning production code;
- place tokens in URL parameters;
- copy the raw user UUID into documentation.
