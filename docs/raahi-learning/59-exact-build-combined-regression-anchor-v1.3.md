# Raahi Learning V1.3 — Exact-Build Combined Regression Anchor

Status: **PROVEN IN LEARNING DEV**  
Date: 2026-09-18

Exact product commit: `8c7a7bff574bfa547a0243fb98266143172a974f`

This is the first single-commit regression anchor after completing the V1.3 workspace-convergence work. All major foundational suites passed against the same branch commit.

## Passing suites

- Model Tests — run `35335623612`
- Organization Staff Boundaries — run `35335623636`
- Privileged UI Convergence — run `35335623684`
- Core Learner/Teacher UI Convergence — run `35335623807`
- DEV Genuine-Session E2E Harness — run `35335623587`
- Raahi Ads UI Convergence — run `35335623584`
- Parent/Organization UI Convergence — run `35335623572`
- 20-Persona Cohort — run `35335623562`

All eight concluded **success**.

## What this anchor proves

- model/runtime contracts remain intact;
- genuine DEV Auth/session infrastructure works;
- 20 deterministic personas still isolate correctly;
- learner/teacher workspace convergence is intact;
- managed-parent/Organization convergence is intact;
- Local Manager/Platform Admin convergence is intact;
- Raahi Ads workspace convergence is intact;
- bounded Organization staff capability enforcement is intact.

This anchor predates the side-effect migrations beginning with 1023. Later side-effect slices must preserve this baseline through regression.

## Regression rule

For product-affecting commits, a failed suite must be classified before any code change:

- Domain
- Integration
- Implementation
- Test-Harness

Do not weaken authorization or frozen rules to restore a green build.
