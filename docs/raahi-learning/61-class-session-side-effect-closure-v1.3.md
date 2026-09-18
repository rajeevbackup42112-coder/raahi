# Raahi Learning V1.3 — Class Session Side-Effect Closure

Status: **PROVEN IN LEARNING DEV**  
Date: 2026-09-18

Closed gaps:

- **SE-03A** — Class Session scheduling notification + actor audit;
- **SE-03B** — Class Session cancellation notification + actor audit.

Migration:

- `1024_v13_class_session_side_effects.sql`

## Invariants preserved

- Class/session state remains authoritative in PostgreSQL.
- Notifications remain derived and best-effort.
- Only currently active learner-side Accounts are notified.
- Notifications do not grant Class access.
- Session private location text is not copied into notification content.
- Cancellation reason is retained only in governed audit history and is not pushed to learners.
- Idempotent retry creates no duplicate notification or audit.
- Unrelated Accounts cannot read the Class projection or Class Session row.

## UI integration

The Notifications surface now adds an **Open** action for:

- `class_session_scheduled`
- `class_session_cancelled`

Open uses only the opaque `class_id` from notification payload, then routes to the ordinary Class projection. Current authorization is rechecked there.

## Automated proof

GitHub Actions run: `35337429615`  
Exact deployed/tested commit: `b086ceed3a601b2f939d36e23b0c6521871384f7`  
Evidence artifact: `raahi-learning-class-session-side-effects-35337429615-1`  
Artifact digest: `sha256:dcc4abd39672a5ad1f1a8cb81c1fb34f190b834b9aca3a2ed17b1cd689ac9abe`

Result: **PASS**

## Proof IDs

- Learner: `fe62d78e-927b-435a-a5a0-393645070e02`
- Class: `7fa51a0f-1b85-41af-a073-eb07e55cec1b`
- Membership: `f184588a-1570-4253-94dc-a742c1ee0b43`
- Session: `bb1d70c8-31a2-4cdf-91e7-1a381fe30018`

## Proven checks

1. Scheduling produced exactly one learner-side `class_session_scheduled` notification.
2. Notification contains time/delivery context but not private meeting/location text.
3. Scheduling produced exactly one `class_session.schedule` audit row with the provider actor.
4. Retrying schedule with the same idempotency key produced no duplicate.
5. Notification Open returned to the authorized Class surface.
6. Cancellation produced exactly one `class_session_cancelled` notification.
7. Cancellation notification did not expose the private cancellation reason.
8. Cancellation produced exactly one `class_session.cancel` audit row with the provider actor and governed reason.
9. Retrying cancellation produced no duplicate.
10. Unrelated Account Class projection and direct Class Session row access were denied.

## Independent database cross-check

For Session `bb1d70c8-31a2-4cdf-91e7-1a381fe30018`:

- final session state is cancelled;
- `class_session_scheduled` count = 1;
- `class_session_cancelled` count = 1;
- `class_session.schedule` audit count = 1;
- `class_session.cancel` audit count = 1.

## Next

Proceed to **SE-04A / SE-04B**: provider important/announcement Class-post notification and learner-question provider notification.
