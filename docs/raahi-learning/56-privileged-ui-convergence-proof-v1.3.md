# Raahi Learning V1.3 — Privileged Workspace UI Convergence Proof

Status: **PROVEN IN LEARNING DEV**  
Date: 2026-09-18

Reference UI: frozen clickable artifact `Raahi_Learning_Clickable_UI_v1.1.zip`.

## Scope

Third convergence slice:

- Local Manager with real Dhanbad Location assignment;
- Platform Admin with real `platform_admin` capability;
- desktop `1440×900`;
- mobile `390×844`.

Routes:

`manager-home`, `manager-people`, `manager-learning`, `manager-reports`, `manager-ads`, `manager-location`, `platform-home`, `platform-safety`, `platform-ads`, `platform-audit`.

## Real authority setup

The proof does not treat persona labels as authority.

- Platform Admin Account has active `platform_admin` in `account_capabilities`.
- Local Manager authority is assigned through canonical `assign_local_manager`.
- Dhanbad assignment remains active in `location_staff_assignments`.
- privileged projections are successfully read before browser comparison.

DEV evidence:

- Platform Admin Account: `8e2c1e83-a5b3-452e-b1d8-6c61283a4689`
- Local Manager Account: `ef813789-7592-45fe-be68-d008bb724df0`
- Local Manager assignment: `a6ce6aee-1581-4efc-80f5-376143680e02`
- Dhanbad Location: `028ee066-2130-45d6-8e17-6ceb9b0f1f80`

## Defects found and classified

### Test-Harness

1. Privileged browser comparison initially assumed the current workspace without waiting for the live authorized-workspace selector.
2. Platform Admin therefore remained in the default manager-compatible workspace and privileged Platform routes correctly failed closed.

Fix: the harness now waits for `[data-live-role-select]`, verifies that the required server-authorized option exists, selects it normally, waits for the expected route, and proves the selection persisted.

No authorization rule changed.

### Implementation / UI

The first real privileged comparison found:

1. Local Manager Overview used a generic `Local Manager` title rather than the frozen Location-aware Overview pattern.
2. operational JSON projections could force horizontal overflow;
3. Platform Ads and Platform Audit still overflowed after the first containment pass.

Fixes are presentation-only:

- Local Manager home now renders `<selected Location> Overview`;
- long operational JSON is constrained to the main column and wraps safely;
- Platform Ads/Audit summaries are included in the same responsive containment rule.

No RPC, capability, staff assignment, audit semantics, or database state changed.

## Final proof

GitHub Actions run: `35320690248`  
Exact deployed/tested commit: `ea885b975c2b9b5fcdbf89e99937df6bedf5fe68`  
Evidence artifact: `raahi-learning-ui-convergence-privileged-35320690248-1`  
Artifact digest: `sha256:81d3207d4ac77a3715c72f9e7a2a63f3a5fc41ef75e676205e53ecffffc7650f`

Result: **PASS**

The same exact commit also passed:

- Model Tests;
- DEV E2E Harness;
- Core learner/teacher UI convergence;
- Parent/Organization UI convergence.

## Proven checks

- real Local Manager Location scope;
- real Platform Admin capability;
- normal live workspace selection;
- privileged deep routes fail closed unless the correct workspace is selected;
- frozen privileged page headings / shell geometry;
- responsive desktop/mobile behavior;
- no horizontal overflow in privileged operational projections;
- exact build remains unchanged for the duration of the proof.

## Next

Proceed to advertiser / Raahi Ads workspace convergence, then bounded Organization staff capability surfaces. Commercial-clearance capability remains distinct from advertiser ownership and must not be conflated with the advertiser workspace.
