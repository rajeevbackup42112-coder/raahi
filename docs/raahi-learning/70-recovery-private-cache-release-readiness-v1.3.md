# Raahi Learning V1.3 — Recovery, private-cache and release-readiness closure

Status: **BOUNDED RECOVERY / SHARED-BROWSER GATE CLOSED IN DEV; RELEASE-READINESS WORK CONTINUES**  
Date: 2026-09-19

This document closes the post-SE-08 bounded recovery and shared-browser work that occurred after docs 68–69 were first written. It does **not** certify production load, backup/recovery, external provider readiness or public launch.

## 1. Exact application and workflow anchor

Bounded recovery/shared-browser product proof commit:

`d0232c4fdb9410d4902063740974b7110da59473`

Current deployed DEV artifact commit after migration 1032:

`945bdf9f7fbcabbd4eb05c627800381b65c5f54b`

The Git diff from `d0232c4...` to `945bdf9...` contains only `supabase/migrations/20260919120454_1032_v13_invitation_acceptance_fk_indexes.sql`; browser/product source is unchanged.

DEV origin:

`https://dev.learning.myraahi.co.in`

All four workflows triggered for that exact SHA completed successfully:

| Suite | Run | Result | Evidence |
|---|---|---|---|
| Model Tests | [35419424855](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35419424855) | PASS | backend-free invariant suite + release-package/cache tests |
| Class Race Recovery | [35419424832](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35419424832) | PASS | artifact 10577655406; `sha256:1e136f228a65af86edffe2418763233a595e30b5b1a3af21ad797e5dfe31f60b` |
| DEV E2E Harness | [35419424856](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35419424856) | PASS | artifact 10577096415; `sha256:97c1e315aaa030e5279cbba85b580e680b150ad80205e56bd17903cadd254d6a` |
| UI Convergence Core | [35419424831](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35419424831) | PASS | artifact 10577610444; `sha256:5cee64865915ee745a58658a0e4ec897f6cb9e689e801ab264347511b97456b4` |

The `d0232c4...` DEV harness independently read the deployed `build-meta` marker for the bounded recovery proof. After migration 1032 was committed, DEV E2E Harness run [35441874762](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35441874762) rebuilt/deployed exact commit `945bdf9...` and passed with artifact `10583962946`, digest `sha256:9cb6105db7520b5f5c9574a745f5d12f7cc85eba211514f6931adbb604fa2be5`. Its proof reports `exact_dev_commit_deployed: true`, genuine sessions and intact RLS.

## 2. Recovery and race proof now closed for bounded DEV scenarios

The final Class Race Recovery artifact proves, with genuine Supabase sessions and intact RLS:

- concurrent invitation requests competing for the last Class seat produce exactly one winner;
- the losing / unrelated learner cannot consume the winning invitation;
- an acceptance can commit while the first response is deliberately discarded, then recover through a newly authenticated Supabase client;
- concurrent same-key retries return the same Membership;
- changed payload under a reused idempotency key is rejected;
- duplicate/fresh-key acceptance does not create a second Membership;
- 40 cached acceptance retries at concurrency 8 returned the same committed result;
- final-run bounded retry latency: p50 307 ms, p95 909 ms, max 931 ms;
- document reload restores the private thread for the same genuine persisted session;
- cross-tab sign-out hides private Class content;
- a different Account signing into the same browser context cannot reopen the first Account's copied private thread link;
- Class removal immediately denies the old session's Class read and message write;
- cached acceptance replay cannot reactivate a removed Membership.

This is a bounded correctness/idempotency/concurrency proof. It is **not** a production throughput, soak, capacity or saturation certification.

## 3. Shared-browser failure classification

Earlier red runs were investigated rather than treated as product-domain failures.

- Run `35419160382` timed out waiting for an unrelated-account denial page.
- Diagnostic run `35419312772` showed the first tab sitting safely at `#/welcome` after the second tab signed in. It did not show the first Account's private content leaking into the second Account.
- The harness oracle was corrected so safe sign-out/welcome behavior is accepted rather than requiring automatic cross-tab account adoption.

During that investigation a genuine defence-in-depth weakness was also found: the private Class-thread cache key did not include the current Auth user / Raahi Account. Commit `d0232c4` hardened it by:

- adding Auth user and Account IDs to the private cache key;
- clearing the private thread cache on every Auth state event;
- clearing `live.data.classThread`;
- using a generation counter so late responses from a prior session are ignored;
- invalidating private cached data outside the Class-thread route.

`tests/thread-cache.test.mjs` proves that a late private response cannot populate the next Account's page and that access is rechecked after an Account change.

## 4. Release packaging proof

Commit `d0232c4` also added the offline release packager and its regression test.

The packager:

- requires an exact 40-character release commit;
- requires an HTTPS production origin;
- rejects DEV/test/preview origins;
- rejects the Learning DEV and ride project references;
- accepts only a publishable client key and rejects the known DEV publishable key;
- verifies reconstructed-source metadata against the requested commit;
- excludes DEV login/proof pages and fixture entry points;
- packages only required production browser files;
- refuses to overwrite an existing output directory;
- writes `build-meta.json` with per-file SHA-256 hashes;
- labels output as an **unverified production candidate**.

This is packaging guard evidence only. It does not deploy or qualify a production environment.

## 5. DEV performance-advisor closure

A fresh Supabase Performance Advisor read identified exactly two uncovered foreign keys:

- `learner_self_access_invitations.accepted_by_account_id`;
- `organization_member_invitations.accepted_by_account_id`.

The tables are currently small in DEV, and no current privileged RPC body was found filtering directly on `accepted_by_account_id`. The indexes were therefore treated as preventive relationship/FK hygiene rather than evidence of a current slow query.

Migration:

`20260919120454 / 1032_v13_invitation_acceptance_fk_indexes`

Repository file:

`supabase/migrations/20260919120454_1032_v13_invitation_acceptance_fk_indexes.sql`

Indexes:

- `learner_self_access_invite_accepted_by_idx`;
- `organization_member_invite_accepted_by_idx`.

Post-migration verification:

- both physical indexes exist;
- the `unindexed_foreign_keys` advisor finding is gone;
- the performance advisor now reports only unused-index informational notices;
- the two new indexes naturally appear unused immediately after creation;
- no existing indexes were removed merely because young DEV traffic has not used them.

No authorization, RLS, RPC, state or browser behavior changed.

## 6. Current security state

A fresh Supabase Security Advisor read reports one warning:

`auth_leaked_password_protection`

Leaked-password protection is disabled. This is **not resolved** by this closure. Current connector capabilities do not expose the Auth setting mutation surface, so it remains a pre-launch configuration/acceptance gate.

No RLS relaxation or authorization bypass was introduced to close any test.

## 7. Current DEV platform snapshot

- Supabase Learning DEV: `iiwwmqokaeflaenhlyip`
- region: `ap-south-1`
- project state: `ACTIVE_HEALTHY`
- PostgreSQL: 17
- migration ceiling: `1032_v13_invitation_acceptance_fk_indexes`
- `dev-test-identities`: ACTIVE, version 16
- deployed DEV artifact: exact `945bdf9...` (browser/product source unchanged from the `d0232c4...` recovery proof anchor)
- no Learning production Supabase project selected
- no public deployment authorized

## 8. Gates that remain open

The next work is release/reliability work, not another product redesign pass:

1. broader realistic load/soak/capacity testing beyond the bounded 40-request cached-retry burst;
2. monitoring, alerting and incident-response definition/proof;
3. database **and Storage-object** backup strategy, recovery targets and restore rehearsal;
4. migration rollback/forward-fix rehearsal;
5. leaked-password-protection resolution or explicit risk acceptance;
6. periodic real-provider same-phone SMS trust refresh with user-held authentication;
7. dedicated Learning production Supabase project selection/creation;
8. final production domain/origin;
9. production Google OAuth, SMS provider, redirect URLs and secrets;
10. production-candidate regression on production-like infrastructure;
11. controlled pilot audience and go/no-go criteria;
12. explicit Rajeev approval before public launch.

Do not interpret this document as public-launch authorization.
