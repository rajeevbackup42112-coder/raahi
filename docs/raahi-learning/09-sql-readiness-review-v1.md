# Raahi Learning V1 — SQL Readiness Review

Status: **NEXT ACTIVE TECHNICAL GATE. Supabase remains untouched.**

This document defines the final review that converts `03-database-blueprint-v1.1.md` from a logical physical design into an executable PostgreSQL/Supabase migration contract.

The purpose is to decide implementation mechanics without changing frozen product behaviour.

## Review questions

### 1. State representation

For every lifecycle/status field decide one of:

- constrained `text` + `CHECK`;
- PostgreSQL enum;
- lookup/config table when values are business-configurable.

Default recommendation for V1: prefer constrained `text` for product lifecycles that may evolve, unless an enum materially improves safety and migration cost is acceptable.

Do not use free-form text for lifecycle states.

### 2. Foreign-key delete behaviour

Default principle:

- avoid `ON DELETE CASCADE` for shared/history/safety/business records;
- prefer `RESTRICT`/`NO ACTION` for core relationships;
- use explicit domain-ending commands rather than destructive cascades;
- cascade only for true internal child records that have no independent business/audit meaning.

Examples to review carefully:

- Account → Learner access;
- Class → Membership/Invitation/Posts/Activities/Tests;
- Activity → Submission/Revisions;
- Test → Questions/Attempts;
- Campaign → Revisions/Reviews/Reservations/Placements;
- Report/Audit evidence must survive ordinary UI deletion/hiding.

### 3. Partial unique indexes

Define exact SQL for at least:

- one active `self` access per Learner;
- one active `manage` access per Learner;
- one active `(Account, Learner, access_type)` relationship;
- one Pending Class Invitation per `(class_id, learner_id)`;
- one Active Membership per `(class_id, learner_id)`;
- one active capability grant per `(account_id, capability_code)`;
- one active restriction for the same exact subject/scope/location where duplicate restrictions add no meaning;
- one logical Test Attempt per `(test_id, learner_id)` in V1.

### 4. Class capacity transaction

The `send_class_invitation` transaction must lock the Class row (or equivalent serialization point), count:

- Active Memberships;
- Pending unexpired Invitations;

and reject if the new reservation would exceed `capacity`.

`accept_class_invitation`, `decline`, `cancel`, `expire`, `transfer`, and capacity-change commands must use the same authoritative capacity semantics.

No UI availability check is authoritative.

### 5. Test definition lock

Define a database-enforced strategy so ordinary writes cannot mutate Test Questions/Choices after `definition_locked_at` is set.

Possible implementation:

- revoke direct client writes entirely;
- all Test edits through guarded RPCs;
- trigger/check in edit functions rejects structural mutation once locked;
- `start_test` atomically sets `definition_locked_at` if null while creating/resuming the Attempt;
- `correct_answer_key` is the only approved post-lock answer-key mutation path and writes Audit.

### 6. Ads daily capacity transaction

`reserve_ad_inventory` must:

1. resolve all requested `ad_inventory_days` rows;
2. lock them in deterministic order to reduce deadlock risk;
3. expire/release stale Holds as defined;
4. calculate Held + Confirmed units for every bucket;
5. fail the whole reservation if any day would exceed capacity;
6. insert Reservation + Reservation Days atomically.

Never partially reserve only some dates in a multi-day transaction unless the user explicitly accepted a partial alternative beforehand.

### 7. Ad serving revision

Database/RPC contract must guarantee:

- `serving_revision_id` belongs to the Placement Campaign;
- exact Revision has an Approved review valid for the required review scope;
- setting a newer Draft/Under-Review revision is rejected;
- rendering reads `serving_revision_id`, never `MAX(revision_number)` or “latest revision”.

### 8. RLS vs RPC-only writes

Classify every table into:

- public/authorized read via RLS;
- private read via relationship-based RLS;
- no direct client writes — canonical RPC only;
- internal/service-only operational tables.

Expected RPC-only or heavily restricted writes include:

- learner access changes;
- Class Invitation lifecycle;
- Membership lifecycle;
- Test Attempt start/submit/evaluate/invalidate;
- scoped Restrictions;
- Verification decisions;
- Ad review/commercial/inventory/placement transitions;
- Audit/Idempotency records.

### 9. SECURITY DEFINER discipline

If Supabase RPCs use `SECURITY DEFINER`:

- fixed safe `search_path`;
- smallest possible privileges;
- never accept caller-supplied authorization claims at face value;
- derive actor from `auth.uid()`;
- re-check Learner/Organization/Location relationships inside the transaction;
- return minimal results;
- revoke direct execution from inappropriate roles;
- add tests proving callers cannot escalate scope.

### 10. Storage model

Define bucket/path policy for:

- Account/Learner avatars;
- Class Materials;
- Submission files;
- Community attachments;
- Campaign creatives;
- private Ad Claim Evidence.

Private objects should use non-public buckets or signed/authorized retrieval. Object metadata must link to a business record whose current permission is checked.

### 11. Idempotency contract

For each mandatory idempotent command:

- client supplies operation/idempotency key;
- RPC claims/inserts key atomically;
- same key + same request returns original result;
- same key + materially different request fails;
- successful domain state and idempotency result commit together;
- define retention period appropriate to retry horizon;
- system jobs use deterministic job keys rather than fake human Accounts.

### 12. Audit contract

Audit records should support:

- Account actor or System actor;
- exact action type;
- target and scope;
- reason when required;
- timestamp;
- limited structured metadata.

Do not place secrets, full message contents, or unnecessary child/private data into generic audit metadata.

### 13. Projection/views

Plan secure views/functions for common reads instead of exposing raw tables everywhere:

- public teacher/Teaching Option discovery;
- sanitized Open Learning Requests;
- My Classes summaries by authorized Account/Learner;
- private Class feed;
- Community Location feed;
- eligible Sponsored serving candidates;
- advertiser aggregate analytics.

### 14. Migration slicing

Do not create one giant migration. Suggested migration families:

1. identity/learner/capabilities;
2. locations/restrictions;
3. organizations/discovery;
4. requests/enquiries;
5. classes/invitations/memberships/files;
6. class feed/messages;
7. activities/submissions;
8. tests/attempts;
9. community/trust/safety;
10. ads campaign/review/commercial;
11. ads inventory/placement/frequency/metrics;
12. notification/idempotency/audit/projections.

Each family should include constraints, indexes, RLS, RPCs and tests needed for that slice before the next family depends on it.

## SQL-readiness output expected

The next artifact after this review should be:

**`10-sql-migration-plan-v1.md`**

It should contain:

- exact proposed table creation order;
- enum/check strategy;
- FK/delete actions;
- partial index definitions;
- RPC/function inventory and transaction notes;
- RLS matrix by table/view;
- storage buckets/policies;
- migration filenames/order;
- required tests per migration slice;
- explicit unresolved items, if any.

Only after the SQL Migration Plan is reviewed should Supabase be connected and migrations executed.