# Raahi Learning V1.2 — Supabase Execution Checklist

Status: **USE ONLY AFTER USER AUTHORIZES SUPABASE ACCESS.**

This checklist is deliberately prepared before the environment is touched so the next phase begins with inspection and control rather than improvisation.

---

# A. Read-only project identification

Before mutation record:

- Supabase project name/reference;
- environment purpose (dev/test/staging/prod);
- region;
- whether this project already contains Raahi ride/Toto/other unrelated objects;
- current migration history;
- current schemas/tables/views/functions/triggers/policies;
- current Auth providers/settings relevant to OTP/login;
- current Storage buckets/policies;
- enabled extensions required by V1.2;
- existing cron/realtime configuration if any.

If the project is not clearly the intended Raahi Learning environment, stop.

---

# B. Read-only compatibility diff

Compare the target against:

- `19-consolidated-database-blueprint-v1.2.md`;
- `20-consolidated-sql-migration-plan-v1.2.md`.

Classify every discovered existing object as:

- compatible/reusable;
- unrelated—must remain isolated;
- conflicting—requires migration/namespace decision;
- legacy—must not be silently reused;
- unknown—requires investigation.

Do not retrofit the new product into similarly named legacy tables merely because names overlap.

---

# C. Pre-mutation safeguards

Before first write:

- confirm source-control branch for migrations;
- record current environment state/migration version;
- confirm backup/restore expectations appropriate to the environment;
- confirm no secret/service-role values will be committed;
- confirm migration actor has only the access needed;
- confirm first execution target is non-production unless explicitly approved otherwise;
- confirm all subsequent schema changes will be migration-driven rather than manual dashboard edits.

---

# D. Foundation + Identity migration review

Review SQL for:

- `0001_extensions_helpers.sql`;
- `0002_common_updated_at.sql`;
- `0100_identity_tables.sql`;
- `0101_identity_constraints_indexes.sql`;
- `0102_command_infrastructure.sql`;
- `0103_identity_rls_helpers.sql`;
- `0104_identity_rpcs.sql`.

Before execution verify:

- `accounts.auth_user_id` is nullable and `ON DELETE SET NULL`;
- no `selected_location_id` exists on Accounts;
- no permanent role field exists;
- one-active-self and one-active-manager constraints are implemented;
- Audit + Idempotency exist before consequential RPCs;
- actor identity comes from `auth.uid()`;
- `SECURITY DEFINER` search paths are fixed/safe;
- public/default function execute is revoked before explicit grants;
- Account pause/resume/closure semantics do not cascade-delete domain history.

---

# E. Apply Foundation + Identity only

Do not apply Locations in the same batch.

After migration, immediately run:

- schema/constraint assertions;
- RLS direct-read tests;
- direct-write denial tests;
- helper-function authority tests;
- create learner tests;
- manager/self authority tests;
- Account lifecycle tests;
- idempotency tests;
- privilege-escalation tests.

If any mandatory test fails, stop and forward-fix before continuing.

---

# F. Foundation + Identity go/no-go record

Record:

- migration identifiers applied;
- tests run;
- pass/fail counts;
- any forward fix migration;
- unresolved risks;
- explicit decision: `GO TO LOCATIONS` or `STOP`.

No implicit “looks okay” continuation.

---

# G. Later slice discipline

For every later slice repeat:

1. review SQL against consolidated blueprint;
2. apply only that slice;
3. run its slice tests;
4. record result;
5. proceed only after explicit pass.

Especially do not combine Classes + Activities + Tests + Ads merely to save execution time.

---

# H. Mandatory live-database race tests

Once the relevant slices exist, prove with real concurrent transactions:

- last-seat Invitation **send** race;
- valid Pending Invitation acceptance retry;
- capacity reduction floor;
- Transfer atomicity;
- share-code consume + invite race;
- Test first Attempt definition lock;
- duplicate Test Start/Submit;
- overlapping Ads daily reservation race and deterministic row-lock ordering.

These cannot be fully certified by documentation alone.

---

# I. Storage validation

When Storage is configured:

- public profile media deliberately public only;
- learner-private media cannot be fetched by unrelated account;
- Class private asset access follows current Class/learner authorization;
- Left/Removed historical rules behave correctly;
- copied private URL/path without current authorization fails;
- Ads evidence is review-private;
- Sponsored creative intended for public serving is separately handled.

---

# J. Realtime / notifications validation

Verify:

- realtime only causes refetch/invalidation;
- websocket payload is not treated as business truth;
- notification delivery failure does not roll back domain transactions;
- Ads cannot buy push-notification access in V1.2.

---

# K. Frontend integration gate

Only connect a production UI action after:

- secure read projection exists;
- canonical RPC exists;
- permission/RLS tests pass;
- stale/retry behavior is defined;
- UI displays success only after authoritative confirmation.

Use `18-ui-page-inventory-v1.1.md` and `23-final-acceptance-traceability-v1.2.md` as the connection checklist.

---

# L. Final pre-launch checks

Before a real Location launch:

- Location state is intentionally `live`;
- Local Manager assignment is valid;
- moderation/escalation paths work;
- private learning access tests pass;
- critical concurrency tests pass;
- backup/recovery expectations are known;
- telemetry/logging is sufficient for support;
- Ads are enabled only if separately ready; learning launch does not imply Ads launch.

---

# Stop conditions

Stop implementation immediately if any of these appear:

- need to reintroduce a removed product concept solely because schema is inconvenient;
- frontend asks to directly update a protected operational state;
- RLS requires trusting a caller-supplied Account id instead of authenticated context;
- Local Manager can read unrelated private learning data;
- manager can take learner Test;
- Class capacity or Ads inventory can oversell under race;
- copied private URLs bypass authorization;
- paid Ads can affect verification/organic rank;
- a migration would require deleting legitimate learning/safety/audit history to proceed.

Resolve the contradiction before continuing.
