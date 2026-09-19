# Class invitation race and retry proof — V1.3

Status: **BOUNDED SCENARIOS PROVEN IN DEV; BROADER GATE OPEN**. Date: 2026-09-19.

Harness commit: `0e7a2c63505c3ab5e7e2f8782f45d1196230ef73`.
Successful [run 35413460137](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35413460137).
Artifact: `10574831553`; digest `sha256:75bc7f13ab41c5d37147339e28da9b621b7a23a76bdd98ffcac767272a976fd2`.

The same commit also passed Model Tests run `35413460093` and DEV E2E run `35413460106`.

Deployed application remained `a9f7ae577edb9a84120e20591de20d921cc66055` at both boundaries. Git ancestry and file diff confirmed only harness/workflow changes. No product, migration or Edge Function change was needed.

## Proven behavior

- Two real concurrent invitation RPCs competed for one seat. Exactly one succeeded; the other returned `CLASS_CAPACITY_FULL`.
- The losing learner could not accept the winning invitation (`NOT_AUTHORIZED`).
- Two concurrent same-key acceptance requests returned the same membership.
- An actual cached server response was discarded by the harness, then retry returned the original invitation. This is simulated response loss on replay, not an outage or loss of the first commit response.
- Fresh-key acceptance returned the same membership with `already_accepted`; changed payload with an existing key was rejected.
- Authenticated RLS reads found exactly one invitation and membership; the teacher saw one acceptance notification.

The workflow uses genuine Supabase sessions via the existing OIDC-only `sidefx_test` identity suite. It shares the Test correction concurrency group and uses separate run-labelled Classes. Its own group does not cancel in-progress work; existing Test correction workflow cancellation behavior still applies if separately triggered.

## Independent database verification

Class `1ee4cc84-59fd-44d7-a1da-a1374e40b487`; invitation `7938d943-75ef-4cfe-9413-9f999edd7477`; membership `d9ed5303-a0b1-4dec-bfa8-56bd7c1d83a0`.

| Stored result | Count |
|---|---:|
| Accepted invitation | 1 |
| Active membership | 1 |
| Invitation notification | 1 |
| Acceptance notification | 1 |
| `class.invitation_send` audit | 1 |
| `class.invitation_accept` audit | 1 |

Counts were read independently using the Supabase connector after the workflow completed.

## Open work and security observation

This is not load, deadlock-stress, browser crash/restart, stale-phone, shared-device, provider-outage or whole-gate proof. Those remain open.

The live Supabase security advisor returned one warning: `auth_leaked_password_protection` is disabled. No other security lints were returned. This does not establish a complete security review. [Provider remediation](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). No Auth configuration mutation tool is exposed in the current connector.

Periodic same-phone provider smoke requires the user's real Google-linked DEV account and user-held SMS verification. Follow doc 48 section 8: preserve Auth/Account identity and phone, check Google remains linked, refresh trust, retry preserved command, and verify ordinary Google return. Automated DEV identities do not substitute for this ceremony. Do not fabricate OTP evidence or ask for credentials in chat.

The current cloud browser initially contained only a blank tab. Opening DEV did not return during a bounded attempt; no authenticated provider session or OTP ceremony was observed. Browser access and user-held authentication are required to complete this separate gate.
