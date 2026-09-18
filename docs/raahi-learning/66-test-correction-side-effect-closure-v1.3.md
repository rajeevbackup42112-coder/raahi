# Raahi Learning V1.3 — Test Correction Side-Effect Closure

Status: **PROVEN IN LEARNING DEV**  
Date: 2026-09-18

Closed gap:

- **SE-07** — correcting a locked answer key notifies affected evaluated learner-side Accounts exactly once when results are already visible, and sends no correction notification while results remain hidden.

Implementation:

- migration `1030_v13_test_correction_side_effects.sql`;
- notification Open routing in `apps/raahi-learning/live-product-fix-v13.js`;
- isolated `sidefx_test` personas and protected `inspect_test_correction_audit` action in `dev-test-identities`;
- dedicated runner `tests/raahi-learning-e2e/test-correction-side-effects.mjs`;
- workflow `.github/workflows/raahi-learning-test-correction-side-effects.yml`.

## Privacy / authority

- the correction notification is generic;
- its payload contains only `test_id` and `class_id`;
- answer text, question text, selected choices, score and correction reason are not copied into the notification;
- the governed correction audit remains authoritative for the private reason, chosen correction and recalculation count;
- notification Open does not grant authority and re-enters the ordinary Test result projection;
- unrelated Accounts receive no notification and all Test definition, Attempt and oversight projections remain denied.

## Automated proof

GitHub Actions run: `35348046502`  
Exact deployed/tested commit: `53d7a96f0f16b22434fd01a9446acecb6eda7061`  
Evidence artifact: `raahi-learning-test-correction-side-effects-35348046502-1`  
Artifact digest: `sha256:b0646ae23a34a12c606dd98c6b52cc4abf6da6bfb0add7e624fad6f695b311ff`

Result: **PASS**

Proof IDs:

- Learner: `6eb4522a-edba-47ba-9f02-eec892532d3c`
- Class: `c9327d93-ed9c-44de-8470-1cf6b1653b12`
- Visible Test: `2d9204b5-7627-4a06-a2a6-472e04cbff3a`
- Visible question: `331df4f6-1bb2-43cc-8bc8-57a89042765d`
- Visible Attempt: `e338e065-247e-44aa-b713-1fcfe8082dda`
- Hidden Test: `464596bb-43ea-4a0b-ad68-18d7bd1f86d6`
- Hidden question: `058a4fef-ef21-4c9a-9795-1048a3624f09`
- Hidden Attempt: `f4de59a8-36c1-483c-b3ec-07e33aa6d75a`

## Proven checks

1. Visible-results correction recalculated the evaluated Attempt and created exactly one `test_results_corrected` notification for the learner Account.
2. The visible notification used the exact generic title/body and an exact two-field payload containing only `test_id` and `class_id`.
3. The visible notification contained no question, answer, selected-choice, score or correction-reason material.
4. Exact retry of the visible correction created no duplicate notification or audit row.
5. Hidden-results correction recalculated the evaluated Attempt but created zero `test_results_corrected` notifications.
6. Exact retry of the hidden correction still produced zero notifications and one audit row.
7. Each Test question had exactly one `test.answer_key_correct` audit row with the teacher Account as actor and `recalculated_attempts=1`.
8. The learner used the actual notification **Open** button, reached `#/test-results`, and the authorized Test result remained visible after the route settled.
9. The corrected visible score was projected as `0`; the hidden Test did not expose its score through the learner projection before release.
10. The unrelated Account received no correction signal and received `null` from the Test definition, Attempt and oversight projections.

## Independent database verification

After the final workflow completed, a separate DEV SQL read verified:

- visible Test: `results_visible=true`, evaluated Attempt score `0`, learner correction-notification count `1`, unrelated count `0`;
- visible payload: only the expected `test_id` and `class_id`;
- hidden Test: `results_visible=false`, evaluated Attempt score `0`, correction-notification count `0`;
- two correction audit rows total, one per question, both performed by teacher Account `9f29b8c5-78ac-458a-acbc-4ac5bac9a5b7`, each with recalculation count `1`.

## Evidence-hardening note

The first green run proved the assertions but captured its screenshot during a transient loading repaint. The runner was strengthened to require the authorized result title to remain visible after a settle interval and to reject either loading state. The final run and artifact above are the authoritative SE-07 evidence and show the settled result screen.

## Next

Proceed to **SE-08 Organization authority changes**:

- **SE-08A** — generic notification when an Organization member's capabilities change;
- **SE-08B** — generic notification when an Organization member is removed, with immediate safe denial of former access.
