# Raahi Learning — Model Tests

This folder contains backend-free property/invariant simulations used before Supabase implementation.

Run:

```bash
python tests/model/pre_supabase_model_tests.py
```

The current harness uses deterministic seed `20260912` and exercises more than five million modeled cases/operations across:

- Learning Request transitions;
- Enquiry messaging permission;
- Class Invitation/Membership capacity;
- Class transfer atomicity;
- Test Attempt authority/idempotency;
- Learner share-code lifecycle;
- Account closure blockers;
- Location preference independence;
- Ads inventory capacity;
- exact Campaign Revision serving;
- protected Sponsored surfaces;
- Report/Block independence;
- Class completion behavior;
- public Learning Request privacy projection.

These tests prove logical model properties only. They do **not** prove PostgreSQL locks, RLS, grants, indexes, Storage authorization, Realtime, network retry recovery or latency. Corresponding real database/security/load tests remain mandatory under `docs/raahi-learning/29-master-test-case-catalog-v1.2.md` and `31-staging-load-security-chaos-plan-v1.2.md`.

A failure exits nonzero, so this suite can later be added to CI without any Supabase dependency.