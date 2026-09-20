# Raahi Learning V1.3 — Production Google OAuth Preparation

Status: **PREPARED — USER-HELD GOOGLE CLOUD SETUP PENDING**  
Date: 2026-09-20

## 1. Purpose

The controlled Gomoh + Dhanbad pilot uses:

**Google sign-in only.**

Phone/SMS/WhatsApp verification is not a pilot launch dependency.

Google production OAuth is therefore the final external authentication dependency before controlled-pilot cutover.

## 2. Environment rule

Use a **separate Google Cloud project for production/publishing**.

Do not convert the existing DEV/testing Google OAuth project into the production project.

This follows current Google OAuth production guidance and keeps testing and public credentials separated.

The same Supabase Learning project is intentionally used for the first controlled pilot, but the Google production OAuth client is distinct from the DEV/testing OAuth client.

## 3. Production Google Cloud project

Recommended project/display naming:

- Google Cloud project name: **Raahi Learning Production**
- OAuth app name: **Raahi Learning**
- OAuth client name: **Raahi Learning Production Web**
- Audience: **External**

Only the scopes required by Supabase Google sign-in should be configured:

- `openid`
- `userinfo.email`
- `userinfo.profile`

Do not add Google Drive, Gmail, Calendar or other sensitive/restricted scopes.

## 4. Branding values

Public application origin:

`https://learning.myraahi.co.in`

Recommended OAuth branding:

- App name: **Raahi Learning**
- User support email: **support@myraahi.co.in**
- Homepage:
  `https://learning.myraahi.co.in/`
- Privacy Policy:
  `https://learning.myraahi.co.in/privacy.html`
- Terms of Service:
  `https://learning.myraahi.co.in/terms.html`
- Authorized domain:
  `myraahi.co.in`

The homepage must be public and must expose an easy-to-find Privacy link before final Google production verification.

The domain should be verified in Google Search Console using a Domain Property/DNS verification under an account that is also an owner/editor of the Google Cloud project.

## 5. Web OAuth client

Application type:

**Web application**

Authorized JavaScript origin:

`https://learning.myraahi.co.in`

Production Google callback registered as an Authorized Redirect URI:

`https://iiwwmqokaeflaenhlyip.supabase.co/auth/v1/callback`

Do not add the DEV web origin to the production client.

Do not add localhost, preview or unrelated Raahi origins to the production client.

## 6. Supabase configuration boundary

Do **not** replace the currently working DEV Google credentials yet.

At controlled-pilot cutover:

1. copy the production Google Client ID and Client Secret directly into the Supabase Google provider configuration;
2. never place the Client Secret in GitHub, browser code or chat;
3. update Supabase Auth URL Configuration so the public pilot origin is an allowed redirect destination;
4. set the production Site URL / allowed redirect configuration for:
   `https://learning.myraahi.co.in`;
5. test real Google sign-in from the public origin;
6. verify returned session belongs to the Learning Supabase project;
7. verify Account bootstrap/onboarding still works;
8. only then continue cutover.

Because the same Supabase project becomes the real controlled-pilot project after cutover, replacing the DEV/testing Google client at that point is intentional.

## 7. Google verification / publishing

Current Google guidance requires a production app to use a production/publishing project and complete the applicable production verification process.

Before submitting/publishing branding:

- public homepage exists;
- Privacy Policy is public;
- Terms page is public;
- authorized domain is verified;
- support email works;
- app branding accurately describes Raahi Learning;
- requested scopes are limited to identity/profile/email.

Do not claim access to Google data Raahi does not use.

## 8. Current blocker ordering

The OAuth project/client can be created before public deployment.

Final branding verification/publication may need the public homepage and policy URLs to be live.

Therefore recommended sequence is:

1. create production Google Cloud project;
2. configure Branding/Audience/Data Access;
3. create Web OAuth client with the exact origin/callback values above;
4. retain Client ID + Secret securely;
5. prepare public Raahi artifact/domain;
6. make public homepage/privacy/terms reachable during cutover;
7. complete Google branding/domain verification as required;
8. install production client credentials in Supabase;
9. run real public Google sign-in proof.

## 9. Secret-handling rule

The Google OAuth Client ID is not a password.

The Google OAuth Client Secret **is a secret**.

Do not send the Client Secret through chat or commit it to GitHub.

Enter it directly into Supabase Auth provider configuration when the cutover reaches that step.

## 10. Pilot login target

The intended public experience is:

**Open Raahi Learning → Continue with Google → Google consent/sign-in → return to Raahi Learning → Account bootstrap/profile → product**

No phone prompt follows during the controlled pilot.
