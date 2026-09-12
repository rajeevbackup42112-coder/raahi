# Raahi Learning V1.1 — Final UI→DB Implementation Delta

Status: **BINDING FINAL PRE-SUPABASE DELTA.**

This document adds the final technical changes proven necessary only after building and inspecting the real clickable UI pages. It is applied **after** `14-ui-db-implementation-delta-v1.md`.

If this file conflicts with earlier schema/migration wording, this file wins because it comes from the later inspected page-level reconciliation.

---

## 1. Location lifecycle: add `interest_only`

Update the Location state model to:

`interest_only → preparing → live ↔ paused → retired`

User-facing behavior:

- `interest_only`: “Raahi isn’t available here yet”; only Register Interest / demand-supply collection is allowed;
- `preparing`: local launch preparation is underway; Register Interest/onboarding may continue but full live discovery/community behavior is not yet available;
- `live`: normal Location discovery/community/Ads eligibility according to module rules;
- `paused`: appropriate new public activity/serving stops while existing private learning is preserved unless another rule applies;
- `retired`: no new normal activity; legitimate history remains.

Migration impact:

- extend `locations.state` CHECK constraint to include `interest_only`;
- any helper such as `is_location_live()` must treat only `live` as live discovery;
- `register_location_interest` is allowed for `interest_only` and `preparing`;
- Sponsored serving is never eligible merely because an `interest_only`/`preparing` Location row exists.

No separate `Draft` user-facing Location state is required in V1.1.

---

## 2. Secure private Learner share codes

Real Teacher Class-management UI proved that existing offline learners cannot be invited safely using a free-text/public Learner search, and the product still rejects fabricated Enquiry history.

Add `learner_share_codes`:

- `id uuid pk default gen_random_uuid()`;
- `learner_id uuid not null fk learners`;
- `created_by_account_id uuid not null fk accounts`;
- `code_hash text not null unique` — do not store the plaintext share code;
- `state text not null check state in ('active','consumed','revoked','expired')`;
- `expires_at timestamptz not null`;
- `consumed_at timestamptz null`;
- `revoked_at timestamptz null`;
- `created_at timestamptz not null default now()`.

Recommended V1.1 policy:

- short-lived (for example 24 hours as configuration, not hard-coded product architecture);
- one-time use;
- unpredictable code/token;
- only the Learner side authorized to make formal learning decisions may create it (`can_make_learning_decision`);
- code does not create a public/searchable Learner identity;
- resolve path reveals only the minimum information needed for the intended Class Invitation.

Canonical commands:

### `create_learner_share_code(p_learner_id, p_idempotency_key)`

- derive current Account;
- require `can_make_learning_decision(p_learner_id)`;
- invalidate/revoke prior active code if V1 policy permits only one active share code;
- generate high-entropy plaintext token, store only hash, return plaintext once;
- audit only metadata, never raw token.

### `revoke_learner_share_code(p_share_code_id, p_idempotency_key)`

- same learner-side authority;
- idempotently transition Active → Revoked.

### Teacher/institute invite path using code

`send_class_invitation_with_share_code(p_class_id, p_share_code, p_fee_display_text, p_idempotency_key)` (name may be refined during SQL implementation):

1. derive/authorize responsible Teacher or authorized Organization actor;
2. hash and resolve the code;
3. require Active/unexpired code;
4. lock Class row and enforce capacity including current reservations;
5. create the normal targeted Pending Class Invitation for the resolved Learner;
6. store the optional fee snapshot described below;
7. consume the share code atomically;
8. commit and notify afterward.

Active Enquiry-origin invitations may continue to target the Enquiry’s Learner directly without a share code, because that relationship already provides the learner identity/context.

Tests:

- code cannot be enumerated/search-browsed;
- unrelated Teacher cannot resolve Learner identity without possessing the exact code;
- expired/revoked/consumed code fails;
- retry cannot create duplicate Invitation or consume twice;
- Class-capacity race still uses the locked Class row;
- no public learner directory endpoint/view is added.

---

## 3. Class Invitation fee snapshot

Add to `class_invitations`:

- `fee_display_text text null`.

Purpose:

The inspected Join page shows the fee/terms the learner side is agreeing to when accepting that exact Invitation (for example `₹1,500/month · paid directly to teacher`).

Rules:

- informational snapshot only;
- no wallet/payment/escrow/refund subsystem;
- payment remains directly between learner side and provider in V1;
- teacher/institute sets/copies this value when sending the Invitation;
- once Invitation is Pending, normal editing must not silently change the displayed fee snapshot; material changes require cancelling/reissuing the Invitation;
- acceptance preserves the snapshot as historical Invitation data.

This is preferable to reading the latest mutable Teaching Option fee after the learner has already received the Invitation.

---

## 4. Test result teacher feedback

Add to `test_attempts`:

- `teacher_feedback text null`.

Rules:

- responsible Teacher/authorized evaluation command may set/update feedback while evaluating/correcting the Attempt according to Test policy;
- learner/guardian visibility follows Test result visibility and their existing result-read permissions;
- feedback is private learning data, never public Community/profile data;
- answer-key correction does not erase teacher feedback unless a specific correction command intentionally changes it;
- audit significant exceptional result corrections, not ordinary feedback prose in generic audit metadata.

No generic “overall progress” entity is introduced.

---

## 5. Account pause / resume / closure commands

`accounts.lifecycle_status` remains narrow: `active | paused | closed`.

Clarified semantics from the inspected Settings UI:

### `active`
Normal authorized behavior.

### `paused`
The Account can still authenticate and access legitimate existing private learning/history/responsibilities, but cannot initiate/publish new public/discovery/commercial activity that the pause policy disables. Existing Classes are not automatically terminated.

### `closed`
No normal new Account activity. Application history/shared/safety/audit records remain according to retention and business ownership. Authentication credentials may later be detached/deleted without cascading application history.

Canonical commands:

- `pause_account(p_idempotency_key)`;
- `resume_account(p_idempotency_key)`;
- `request_account_closure(p_idempotency_key)` / `close_account(...)` (final SQL naming may differ).

Closure preconditions must check for unresolved responsibilities that cannot be silently stranded, including at least:

- active `manage` relationship where the Account is the sole V1 managing Parent/Guardian for a Learner with active responsibilities;
- responsible Teacher obligations/active Classes where policy requires handoff/completion;
- Organization authority that requires handoff if this Account is the only actor able to satisfy a required responsibility;
- unresolved safety/legal retention constraints where applicable.

If blockers exist, the command returns structured blocker categories; it does **not** partially delete/cascade business rows.

“Delete account” in UI may map to the guarded closure flow plus separate authentication deletion after application responsibilities are resolved.

---

## 6. Page/deep-link authorization is a mandatory read boundary

No new table is required, but the real UI proved the importance of explicit route/page read authorization.

Rules:

- navigation/workspace selection is never authority;
- opening a privileged URL directly must not expose the privileged projection before authorization succeeds;
- Local Manager pages always require current Location assignment/scope;
- Platform operations require explicit platform/safety/verifier/commercial capabilities as appropriate;
- Teacher/Organization management pages require the actual teaching/Organization relationship/capability;
- Ads advertiser pages require advertising eligibility plus Organization/Account authority as appropriate;
- a denial page may explain missing workspace/scope without leaking the requested private data.

Implementation direction:

- server/data projection and RPC authorization remains authoritative;
- frontend route guards improve UX but are defense-in-depth only;
- RLS/views/functions must remain safe if a route guard is bypassed.

Add regression tests for unauthorized direct reads of privileged projections, not only hidden navigation links.

---

## 7. Migration sequence impact

Apply the following updates to the existing sequence:

### Foundation / Identity

Existing 0100–0104 family remains, plus:

- Account pause/resume/closure RPCs and tests may be added to the Identity slice or a small immediate follow-up Identity migration before Locations.

### Locations

- `0200_locations_tables.sql` includes `interest_only` state;
- existing `0203_location_interests.sql` remains.

### Learner share codes

Add after Identity and before Classes need the feature, preferably:

- `0250_learner_share_codes.sql` (or another dependency-correct placement after Identity);
- RLS/RPCs for create/revoke/resolve-invite path.

It may be physically created later near Classes if implementation prefers, but it must exist before generic offline-learner Class invitation is enabled.

### Classes

- add `class_invitations.fee_display_text` in 0500/0501 family before invitation RPCs;
- sending/resending/cancelling rules respect immutable Pending fee snapshot.

### Tests

- add `test_attempts.teacher_feedback` in 0700;
- evaluation/result read projections include feedback according to result visibility.

### Final privilege hardening

- include direct privileged-page/projection denial tests for Teacher/Organization/Local Manager/Platform/Ads scopes.

---

## 8. Final first-slice impact

The first implementation slice remains **Foundation + Identity**, but now its acceptance criteria explicitly include:

- Account pause/resume/closure command semantics and blocker behavior (if implemented in the first slice);
- no permanent role field;
- deep-link/workspace UI must never be relied on as authorization;
- later Learner share codes must be designed to use `can_make_learning_decision` and the existing Account↔Learner authority model.

Do not start Locations or later slices until the first slice passes its own RLS/RPC/idempotency/privilege tests.

---

## 9. Final gate

Once `16-ui-page-freeze-and-final-reconciliation-v1.1.md` and this delta are included in the implementation approval record, the pre-Supabase design gate is complete.

The implementation contract is:

`10-sql-migration-plan-v1.1.md` + `14-ui-db-implementation-delta-v1.md` + this file.

Supabase implementation is still controlled, versioned, slice-by-slice and test-gated.
