# Raahi Learning V1.3 — Enquiry + Trial Side-Effect Closure

Status: **PROVEN IN LEARNING DEV**  
Date: 2026-09-18

Closed gaps:

- **SE-01** — decline/close Enquiry notification to the opposite authorized side;
- **SE-02A** — Trial scheduling notification with time/context;
- **SE-02B** — Trial reschedule/cancel notifications plus actor audit history.

Migration:

- `1023_v13_enquiry_trial_side_effects.sql`

## Invariants preserved

- PostgreSQL domain transition remains authoritative.
- Notification failure is best-effort and must not roll back the business transition.
- Notifications do not grant authority.
- Private Enquiry message bodies are never copied into notification content.
- Idempotent command retry does not create duplicate attention signals.
- Reschedule/cancel actor history is durable in `audit_log`.
- Unrelated Accounts cannot read the Enquiry projection.
- Trial notification Open routes back through ordinary Enquiry authorization.

## UI integration fix

The existing Notifications UI understood `enquiry_*` destinations but not the new `trial_*` notification types.

A narrow V1.3 product-layer fix now adds **Open** for:

- `trial_scheduled`
- `trial_rescheduled`
- `trial_cancelled`

The Open action sets the notification's authorized `enquiry_id` context and routes to the existing Trial surface. The Trial/Enquiry projection rechecks server authorization.

No new authority is derived from the notification.

## Automated proof

GitHub Actions run: `35336768576`  
Test commit: `aa527ccfb778c48e92407ca6b587534da2e79898`  
Deployed product commit during proof: `aa527ccfb778c48e92407ca6b587534da2e79898`  
Evidence artifact: `raahi-learning-enquiry-trial-side-effects-35336768576-1`  
Artifact digest: `sha256:985c26935632782aa1f63e30fcf951157773d5ad3de45703afef60503ebdb43b`

Result: **PASS**

## Proven checks

1. New direct Enquiry produced one provider-side `enquiry_received` signal.
2. Structured opening message did not generate a duplicate `enquiry_message`.
3. Provider decline produced one `enquiry_declined` notification to the learner side.
4. Retrying the same decline idempotency key produced no duplicate.
5. Trial schedule produced one provider-side `trial_scheduled` notification with time/context.
6. Retrying schedule produced no duplicate.
7. Provider reschedule produced one learner-side `trial_rescheduled` notification.
8. Retrying reschedule produced no duplicate.
9. Learner-side cancel produced one provider-side `trial_cancelled` notification.
10. Retrying cancel produced no duplicate.
11. Active Enquiry close produced one `enquiry_closed` notification to the opposite side.
12. Retrying close produced no duplicate.
13. Exactly one `trial.reschedule` audit row exists with the provider actor.
14. Exactly one `trial.cancel` audit row exists with the learner-side actor.
15. Unrelated Account Enquiry projection returns `NOT_AUTHORIZED`.
16. Normal Notifications UI **Open** successfully re-enters authorized Enquiry/Trial context.

## Independent database cross-check

Proof IDs:

- first declined Enquiry: `d204a51c-ffa3-4757-8913-af66643a49f3`
- active-then-closed Enquiry: `e859b8a5-7172-4239-bcff-8da405ccbc42`
- Trial event: `d0f28392-88f6-495f-92bf-b76b23e59e76`

Observed:

- both Enquiries ended `closed`;
- Trial ended `cancelled`;
- notification counts were exactly one per intended transition/context (with two `enquiry_received` because two distinct Enquiries were created);
- `trial.reschedule` audit count = 1;
- `trial.cancel` audit count = 1.

## Next

Proceed to **SE-03A / SE-03B**: Class Session schedule/cancel notifications and actor audit history.
