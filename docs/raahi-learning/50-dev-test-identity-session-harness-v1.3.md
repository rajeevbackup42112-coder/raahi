# Raahi Learning V1.3 — DEV Test Identity / Session Harness

Status: implementation slice approved by product owner on 2026-09-18.

## Purpose

Normal Raahi regression must not depend on repeated Google/OTP ceremony. Google/phone remain provider-smoke tests. Ordinary product testing uses genuine Supabase Auth sessions in the isolated Learning DEV project with normal RPC/RLS authorization still active.

## Trust and production guards

- DEV Supabase project only: `iiwwmqokaeflaenhlyip`.
- Browser login page hard-rejects every hostname except `dev.learning.myraahi.co.in`.
- The identity factory is a DEV Edge Function.
- The Edge Function accepts only a GitHub Actions OIDC token issued for `rajeevbackup42112-coder/raahi` on `refs/heads/raahi-learning-implementation-v1`.
- No service-role key, refresh token, password, OTP, or OAuth credential is committed or returned by the identity factory.
- Test passwords are random per workflow run and exist only in runner memory.
- RLS is not disabled. Product commands/projections remain unchanged.
- The DEV login page creates no role/capability and is not linked from the product UI.

## Stable personas

- `learner` — ordinary Account; canonical command creates/reuses one self Learner.
- `teacher` — ordinary Account; canonical `enable_teaching` command proves teaching capability.
- `unrelated` — ordinary Account with no learner relationship; used for deny/privacy proofs.
- `admin` — DEV test Account; test data factory seeds `platform_admin` only after Account bootstrap.

These are test infrastructure identities, separate from the Rajeev1–Rajeev8 Google/phone provider-smoke identities.

## Evidence boundary

The identity factory proves test setup only. It is not evidence that product authorization works. Authorization claims must still be proven through genuine persona sessions at projection/API/database/browser boundaries.

## First acceptance proof

1. GitHub Actions obtains a repository/branch-bound OIDC token.
2. DEV identity factory ensures the four stable Auth users and rotates random per-run passwords.
3. Each persona signs in with `signInWithPassword` and receives a genuine Supabase session.
4. Each Account bootstraps through canonical `bootstrap_account` if needed.
5. Teacher enables teaching through canonical `enable_teaching`.
6. Learner creates/reuses one self Learner through canonical `create_learner`.
7. DEV factory seeds only the admin test capability.
8. Unrelated persona cannot read the Learner through context or direct RLS table access.
9. Four isolated Chromium contexts sign in through the DEV test login page and reach the real Raahi application.
10. Sanitized JSON/screenshots are uploaded as CI evidence; no tokens/passwords are stored.

## Classification

This is testing architecture / implementation infrastructure. It does not alter frozen Raahi product rules, actor authority, learner ownership, Class rules, phone trust rules, or production authentication.
