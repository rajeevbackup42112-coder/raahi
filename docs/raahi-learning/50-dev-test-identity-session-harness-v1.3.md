# Raahi Learning V1.3 — DEV Test Identity / Session Harness

Status: **PROVEN in Learning DEV**. Approved by product owner on 2026-09-18; final deterministic cloud proof passed on 2026-09-18.

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
- The build emits the DEV login page only from `raahi-learning-implementation-v1`; other branches do not receive the artifact.
- The cloud proof explicitly verifies the identity factory returns HTTP 403 without GitHub OIDC.
- The runner waits until `build-meta.json` reports the exact `GITHUB_SHA`; stale Cloudflare deployments cannot be certified.
- Harness dependencies are lockfile-pinned, installed with `npm ci`, and gated by `npm audit --audit-level=high`.

## Stable personas

- `learner` — ordinary Account; canonical command creates/reuses one self Learner.
- `teacher` — ordinary Account; canonical `enable_teaching` command proves teaching capability.
- `unrelated` — ordinary Account with no learner relationship; used for deny/privacy proofs.
- `admin` — DEV test Account; test data factory seeds `platform_admin` only after Account bootstrap.

These are test infrastructure identities, separate from the Rajeev1–Rajeev8 Google/phone provider-smoke identities. Their confirmed DEV phone state is deterministic test-fixture trust state created through Supabase Auth admin APIs; it is **not** evidence that SMS/OTP delivery works. Google and SMS/OTP remain separate provider-smoke suites.

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

## Observed execution evidence

### First run — expected harness defect found

- GitHub Actions run: `35300761837`
- Commit: `7501deeff3d667aa386f98c0cd8fddaafea7a7ce`
- Result: **FAIL**
- Failure: `PHONE_TRUST_REQUIRED` when first-time teaching was enabled.
- Classification: **Test-Harness/Data**, not Domain or product defect.
- Product behavior was correct: first-time `enable_teaching` is fresh-phone gated by the frozen V1.3 contract.
- Fix: the dedicated DEV identity factory now seeds confirmed Auth phone state for deterministic regression personas. SMS ceremony remains a separate provider smoke test.

### Final deterministic proof — pass

- GitHub Actions run: `35301682676`
- Exact tested/deployed commit: `f3ca1434c6c9c8f65ca3e6858b79ce69eed94680`
- Workflow job: `genuine-session-harness`
- Result: **PASS**
- Evidence artifact: `raahi-learning-dev-harness-35301682676-1`
- Artifact digest: `sha256:8f4fa196af7be1b9d554b60d5dbcf8a4e742a79c1e2a30d7d2878e92221f3f01`
- Dependency audit: **PASS** at high/critical threshold.
- Backend-free model suite on the harness commits: **PASS**.

Proven checks:

1. exact DEV commit is deployed before testing starts;
2. unauthenticated identity-factory request is rejected;
3. four real Supabase Auth sessions are issued;
4. Accounts bootstrap through canonical `bootstrap_account`;
5. Teacher capability is enabled through canonical `enable_teaching`;
6. Learner self-profile is created/reused through canonical `create_learner`;
7. DEV admin capability is seeded only by the protected fixture boundary;
8. authorized Learner direct RLS read succeeds;
9. unrelated direct RLS read returns no Learner row;
10. four isolated Chromium contexts establish genuine sessions through the DEV-only login page and reach the real Raahi application.

Independent database verification matched the CI artifact: all four Accounts are active, Teacher has only `teach`, Admin has `platform_admin`, Learner has one active `self` relationship, and Unrelated has no Learner relationship.

## Operational consequence

Ordinary Raahi Learning regression no longer depends on the product owner manually signing into multiple Google browsers. Google OAuth and SMS/OTP are retained as small provider-smoke tests. Product journeys, permissions, stale/retry cases, and multi-actor browser tests can now use isolated cloud contexts backed by genuine DEV sessions.

The next expansion should use the same harness for the remaining Class-message/deep-link privacy walking-skeleton boundary, then grow from four actors to representative persona shards rather than returning to manual multi-browser login.

## Classification

This is testing architecture / implementation infrastructure. It does not alter frozen Raahi product rules, actor authority, learner ownership, Class rules, phone trust rules, or production authentication.
