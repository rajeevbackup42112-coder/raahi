# Raahi Learning V1.3 — Activity Submission Side-Effect Closure

Status: **PROVEN IN LEARNING DEV**  
Date: 2026-09-18

Closed gaps:

- **SE-06A** — Activity submit/resubmit notifies the provider side exactly once;
- **SE-06B** — changes-requested/final review notifies learner-side Accounts exactly once.

Migrations:

- `1027_v13_activity_submission_side_effects.sql`
- `1028_v13_activity_review_idempotency_fix.sql`
- `1029_v13_activity_review_privilege_restore.sql`

## Defects found and classified

### Implementation — idempotent replay ordering

The original Activity review command validated `submission.current_status='submitted'` before checking the idempotency cache.

Result: the first request-changes transition succeeded, changed status to `changes_requested`, then an exact retry with the same idempotency key incorrectly failed with `SUBMISSION_NOT_AWAITING_REVIEW`.

Fix: keep authorization first, then perform exact idempotency replay detection, then validate lifecycle state for genuinely new requests.

### Implementation — migration privilege regression

The first 1028 replacement accidentally revoked the authenticated execute grant required by the existing `SECURITY INVOKER` public wrappers.

Fix: migration 1029 restores the original private-command execute contract. No authorization was broadened beyond the pre-existing 0601 contract.

## Privacy / authority

- submission text is never copied into a notification;
- teacher feedback is never copied into a notification;
- notifications carry opaque Activity/submission/revision context;
- notification Open re-enters ordinary authorized Activity/submission projections;
- unrelated Accounts receive no signal and cannot read Activity detail.

## Automated proof

GitHub Actions run: `35343637753`  
Exact deployed/tested commit: `f649d0fce148033f04c1daefdb6d06b6adc6bfdf`  
Evidence artifact: `raahi-learning-activity-side-effects-35343637753-1`  
Artifact digest: `sha256:be431044e2fe55fc0fc25188bbd9b55b3197ec1174ed2d5ce59147acec042d65`

Result: **PASS**

Proof IDs:

- Learner: `7d979f62-6170-43b8-98c7-1d6a348a8ab0`
- Class: `34cb0f0f-e6b9-4352-b0b2-610d52d3fc54`
- Activity: `9cf4ae10-65fb-42c2-9c5e-5b692639d661`
- Submission: `d17d1052-a3ae-4813-ab57-a2ed8a53a1dd`
- Revision 1: `7de70a51-3471-4253-80fa-28f2f9dbed50`
- Revision 2: `c98ff168-9e10-424d-9ba9-86723a1c9f10`

## Proven checks

1. Initial submission notified provider once without response text.
2. Provider notification opened authorized submission-review context.
3. Changes requested notified learner once without teacher feedback.
4. Exact retry of changes-requested produced no duplicate and correctly replayed cached result.
5. Resubmission created revision 2 and notified provider once without response text.
6. Final review notified learner once without teacher feedback.
7. Exact retry of final review produced no duplicate and replayed cached result.
8. Both revision rows preserve learner performer, teacher reviewer, timestamps and outcomes.
9. Learner review notifications opened authorized Activity context.
10. Unrelated Account received no signal and Activity projection was denied.

## Next

Proceed to **SE-07**: when released Test results are already visible, answer-key correction must notify affected evaluated learner-side Accounts generically, without answer, score, or correction-reason leakage.
