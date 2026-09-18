# Raahi Learning V1.3 — Core UI Convergence Proof

Status: **PROVEN IN LEARNING DEV**  
Date: 2026-09-18

Reference UI: frozen clickable artifact `Raahi_Learning_Clickable_UI_v1.1.zip`  
Prototype SHA-256: `2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

## Scope

First live convergence slice:

- adult/self learner;
- teacher;
- desktop `1440×900`;
- mobile `390×844`.

Routes:

`home`, `explore`, `classes`, `notifications`, `learners`, `community`, `messages`, `settings`, `teacher-home`, `teaching-options`, `opportunities`, `teacher-classes`, `teacher-profile-edit`.

## First run

Run `35305438400` correctly failed on six checks representing three duplicated desktop/mobile presentation drifts:

1. learner Home heading was dynamic instead of frozen `Learn locally. Keep learning together.`;
2. Community heading omitted the selected Location prefix;
3. Teacher Home heading used `Teacher Home` instead of frozen `Teach locally, without chasing leads.`.

Classification: **Implementation/UI drift**.

No product rule, authority rule, backend contract or data model changed.

## Fix

A narrow live presentation overlay restores only those page headings. Live data, permissions, RPCs and PostgreSQL state remain unchanged.

Commit: `693a9a6a29edf49b286002c5d8695195f3d0cb31`.

## Final proof

GitHub Actions run: `35305699864`  
Exact deployed/tested commit: `693a9a6a29edf49b286002c5d8695195f3d0cb31`  
Evidence artifact: `raahi-learning-ui-convergence-core-35305699864-1`  
Artifact digest: `sha256:e241285f0980a09ec6da6401bcc61509eca6a84b5484c0590fe1fc0af7a57305`

PASS proves for all routes/viewports in scope:

- frozen page-heading contract;
- no horizontal overflow;
- matching desktop/mobile shell visibility;
- matching topbar geometry;
- matching main-column position;
- matching heading typography/background shell;
- genuine DEV Auth sessions and canonical learner/teacher setup;
- live product rendering rather than fixture-mode business output.

## Next

Continue with managed-parent + Organization workspace convergence, then privileged operational workspaces.
