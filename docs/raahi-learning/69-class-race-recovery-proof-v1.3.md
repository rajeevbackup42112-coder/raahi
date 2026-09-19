# Class invitation race, recovery and shared-browser proof — V1.3

Status: **BOUNDED SCENARIOS PROVEN IN DEV; PRODUCTION RELIABILITY / LOAD GATE OPEN**. Date: 2026-09-19.

This document records the complete bounded Class invitation/recovery sequence. It does not certify production load, provider outage behavior, backup recovery or public launch.

## Evidence sequence

### Initial last-seat / idempotency proof

Harness commit: `0e7a2c63505c3ab5e7e2f8782f45d1196230ef73`  
Successful [run 35413460137](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35413460137)  
Artifact: `10574831553`  
Digest: `sha256:75bc7f13ab41c5d37147339e28da9b621b7a23a76bdd98ffcac767272a976fd2`

This established the one-seat race, exactly-one winner, unrelated acceptance denial, duplicate acceptance safety, same-key replay, changed-payload rejection and exact notification/audit cardinality.

### Stronger first-response recovery / stale-session proof

Harness commit: `ccb17214298ca8e508bfcd7deb19899f5a149909`  
Successful [run 35419057069](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35419057069)

This strengthened the proof by discarding the first **real** acceptance response after the server committed, re-authenticating a fresh Supabase client and recovering through concurrent same-key retries. It also proved immediate stale-session denial after Class removal and that cached acceptance cannot reactivate a removed Membership.

That run executed 40 cached same-account acceptance retries at concurrency 8: p50 766 ms, p95 868 ms, max 930 ms. This is bounded idempotency/concurrency evidence, not production load certification.

### Final account-isolated cache / shared-browser proof

Exact application commit: `d0232c4fdb9410d4902063740974b7110da59473`  
Successful [Class Race Recovery run 35419424832](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35419424832)  
Artifact: `10577655406`  
Digest: `sha256:1e136f228a65af86edffe2418763233a595e30b5b1a3af21ad797e5dfe31f60b`

Companion exact-SHA workflows were also green:

- Model Tests [35419424855](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35419424855);
- DEV E2E Harness [35419424856](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35419424856), artifact `10577096415`, digest `sha256:97c1e315aaa030e5279cbba85b580e680b150ad80205e56bd17903cadd254d6a`;
- UI Convergence Core [35419424831](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35419424831), artifact `10577610444`, digest `sha256:5cee64865915ee745a58658a0e4ec897f6cb9e689e801ab264347511b97456b4`.

The DEV harness independently confirmed that the deployed `build-meta` commit was the same exact `d0232c4...`.

## Proven behavior

Across the evidence sequence:

- two real concurrent invitation RPCs competed for one seat; exactly one succeeded and the other returned `CLASS_CAPACITY_FULL`;
- the unrelated/losing learner could not accept the winning invitation;
- the committed first acceptance response could be discarded and recovered through a newly authenticated Supabase client;
- concurrent same-key acceptance retries returned the same Membership;
- a changed payload with an existing idempotency key was rejected;
- fresh-key duplicate acceptance did not create another Membership;
- authenticated RLS reads and independent database checks found exactly one accepted invitation and active Membership at the acceptance boundary;
- notification and governed-audit cardinality remained one per logical transition;
- a private Class thread survived document reload for the same genuine persisted session;
- cross-tab sign-out removed private content;
- a second Account signing into the same browser context could not reopen the first Account's copied private Class-thread link;
- Class removal immediately denied the old session's Class read;
- the old session's Class-message write failed with `ACTIVE_MEMBERSHIP_REQUIRED`;
- cached acceptance replay did not reactivate the removed Membership.

Final-run bounded cached-retry measurement: 40 requests, concurrency 8, p50 307 ms, p95 909 ms, max 931 ms.

## Shared-browser investigation and classification

Earlier shared-browser runs exposed two different issues that were deliberately separated.

Run `35419160382` timed out waiting for a specific unrelated-account denial page. Diagnostic run `35419312772` showed the first tab sitting safely at `#/welcome` after another tab signed in. That was a **Test/Harness oracle issue**: the product is not required to make an already signed-out tab automatically adopt a different Account.

The diagnostic did not show private content leaking.

During the same investigation a genuine defence-in-depth **Implementation** weakness was identified: the private Class-thread browser cache was keyed by Class and Learner but not by current Auth user / Raahi Account.

Commit `d0232c4` corrected that by:

- including Auth user and Account IDs in the private cache key;
- invalidating the cache on every Auth state event;
- clearing `live.data.classThread`;
- using a generation counter to discard late responses from the prior session;
- invalidating cached private data outside the private Class-thread route.

The backend-free `tests/thread-cache.test.mjs` proves that a late private response cannot populate the next Account's page and that access is rechecked after Account changes.

The final shared-browser workflow passes with the honest security oracle: private content must be absent and old-link access must be re-authorized. Automatic cross-tab account adoption is not a product requirement.

## Independent database verification from the initial proof

Class `1ee4cc84-59fd-44d7-a1da-a1374e40b487`; invitation `7938d943-75ef-4cfe-9413-9f999edd7477`; Membership `d9ed5303-a0b1-4dec-bfa8-56bd7c1d83a0`.

| Stored result | Count |
|---|---:|
| Accepted invitation | 1 |
| Active Membership | 1 |
| Invitation notification | 1 |
| Acceptance notification | 1 |
| `class.invitation_send` audit | 1 |
| `class.invitation_accept` audit | 1 |

These counts were read independently through the Supabase connector after the workflow completed.

## Remaining boundaries

The bounded adversarial/recovery work above is closed. The following are still separate pre-launch gates:

- realistic throughput/load/soak/capacity testing beyond the bounded retry burst;
- monitoring, alerting and incident response;
- database plus Storage-object backup and restore rehearsal;
- migration rollback/forward-fix rehearsal;
- leaked-password-protection resolution or explicit risk acceptance;
- periodic same-phone provider smoke with user-held Google/SMS authentication;
- production Supabase/domain/provider configuration and production-candidate regression.

The live security advisor still reports `auth_leaked_password_protection` disabled. Do not claim this is resolved.

Periodic same-phone provider smoke remains governed by doc 48 section 8. Do not fabricate OTP evidence or request passwords/OTP codes in chat.

See doc 70 for the release-readiness continuation and the post-proof performance-advisor closure.
