# Raahi Learning V1.3 — Raahi Ads UI Convergence Proof

Status: **PROVEN IN LEARNING DEV**  
Date: 2026-09-18

Reference UI: frozen clickable artifact `Raahi_Learning_Clickable_UI_v1.1.zip`.

## Scope

Advertiser workspace convergence with genuine DEV Auth and real Organization advertising authority.

Covered routes:

- `ads-home`
- `ads-eligibility`
- `ads-create`
- `ads-inventory`
- `ads-analytics`

Viewports:

- desktop `1440×900`
- mobile `390×844`

The advertiser proof uses an Organization owner with real `manage_ads` capability. UI workspace selection is performed through the normal authorized-workspace selector.

## Defects found and classified

### Implementation / UI

The first real frozen-vs-live comparison found two deterministic title mismatches:

1. frozen `Advertising eligibility` vs live `Ads eligibility`;
2. frozen `Ads Inventory` vs live `Inventory`.

Fix: title-only presentation convergence in `live-product-fix-v13.js`.

No Ads business rule, capability, review state, inventory rule, commercial-clearance rule, RPC, or database state changed.

### Test-Harness

A later run failed with `Invalid login credentials` while the Ads and Organization-staff suites were running concurrently.

Root cause: both suites reused the same DEV identity namespace and each rotated the same persona password.

Fix:

- Ads now uses isolated suite namespace `ui4_ads`;
- Organization staff uses isolated suite namespace `ui4_staff`;
- no browser/session/product behavior changed.

This preserves the already-proven rule that concurrent cloud suites must never share mutable test credentials.

## Final proof

GitHub Actions run: `35325523017`  
Exact deployed/tested commit: `97cd93dbc5537457e753ca377c64d4a763ff3408`  
Evidence artifact: `raahi-learning-ui-convergence-ads-35325523017-1`  
Artifact digest: `sha256:ef9446d2255dd1d381bf100abc8ebeb94cc6a3cdb8a64d64cf8e002aff787e21`

Result: **PASS**

## Proven checks

- genuine DEV Auth session;
- real Organization `manage_ads` authority;
- normal Raahi Ads workspace selection;
- frozen title/shell geometry convergence;
- desktop/mobile responsive behavior;
- no horizontal overflow;
- exact build unchanged for the duration of the proof;
- advertiser ownership remains distinct from platform/local review and commercial-clearance authority.

## Next

Bounded Organization staff capability surfaces are proven separately in doc 58. After the combined regression anchor, move to remaining vertical-slice and adversarial/recovery/race gates rather than reopening broad UI design.
