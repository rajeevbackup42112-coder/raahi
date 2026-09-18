# Raahi Learning V1.3 — Organization Authority Side-Effect Closure

Status: **PROVEN IN LEARNING DEV**  
Date: 2026-09-18

Closed gaps:

- **SE-08A** — a real Organization member capability change notifies the affected Account exactly once with generic recipient-safe content;
- **SE-08B** — real Organization member removal notifies the removed Account exactly once, immediately revokes the former Organization projection, and makes notification Open fail safely.

Implementation:

- migration `1031_v13_organization_authority_side_effects`;
- current-authority notification Open routing in `apps/raahi-learning/live-product-fix-v13.js`;
- isolated `sidefx_org` personas and protected `inspect_organization_authority_audit` action in `dev-test-identities`;
- dedicated runner `tests/raahi-learning-e2e/organization-authority-side-effects.mjs`;
- workflow `.github/workflows/raahi-learning-organization-authority-side-effects.yml`.

## Privacy / authority

- `organization_access_changed` uses the generic title/body `Organization access updated` / `Your access in an Organization was updated.`;
- `organization_membership_removed` uses the generic title/body `Organization access ended` / `Your access to an Organization has ended.`;
- both payloads contain exactly `organization_id` and `organization_member_id`;
- capability code, enabled state, removal account ID, reasons and evidence stay out of the notification;
- the existing governed audit remains authoritative for private transition detail;
- a notification is only a hint: Open refreshes `get_my_account_context` and calls `get_organization_workspace` under the current genuine session;
- unrelated Accounts receive no signal and cannot read the Organization workspace.

## Automated proof

GitHub Actions run: `35350835314`  
Exact deployed/tested commit: `92608284f22c68d68b69b6dc7a28d077e08818ed`  
Evidence artifact: `raahi-learning-organization-authority-side-effects-35350835314-1`  
Artifact ID: `10548898717`  
Artifact digest: `sha256:571620b89ad467da0ffa8d5c0b26ae88d51913837833412f1fecd41562c1dc94`

Result: **PASS**

Proof IDs:

- Organization: `2648f02d-ac17-48b2-8bbf-d0f0025e7baa`
- Organization member: `72467f65-83ff-4841-b7c7-2d84f96cab40`
- owner Account: `4b4f4221-5add-4ee4-b2ce-7b5acd88e717`
- member Account: `f22627d1-76fc-4b5d-927e-73a71e7817d1`
- unrelated Account: `da9012a8-9e4f-4f13-abed-6d2ceadea254`

## Proven checks

1. Disabling `manage_profile` from a member who retained `manage_ads` created exactly one generic `organization_access_changed` notification.
2. Exact retry returned the cached command result and created no duplicate notification or audit row.
3. The member's current Account context projected only `manage_ads`, and the ordinary Organization workspace RPC remained authorized.
4. The member used the actual notification **Open** button, reached `#/org-home`, saw the correct Organization and Ads action, and the browser held the current `manage_ads` capability set.
5. Removing the member created exactly one generic `organization_membership_removed` notification; exact retry again created no duplicate.
6. The former Organization disappeared from `get_my_account_context`, and direct `get_organization_workspace` returned `NOT_AUTHORIZED` immediately.
7. The same signed-in browser session opened the removal notification, refreshed current authority, reached safe Home, and retained no selection, context or workspace for the removed Organization.
8. Exactly two governed audit rows existed: one capability change and one member removal, both attributed to the owner Account, with private details preserved only in audit metadata.
9. The unrelated Account received zero Organization-authority notifications and could not read the Organization workspace.
10. The DEV static artifact remained on exact commit `92608284f...` throughout the authoritative run.

## Independent database verification

A separate post-run DEV SQL read verified:

- member status `ended` with a real `ended_at` timestamp;
- retained capability row `manage_ads` remains historical data but grants no access because membership status is ended;
- exactly two member notifications with the exact two-field payloads above;
- unrelated notification count `0`;
- exactly two transition audit rows with owner actor `4b4f4221-5add-4ee4-b2ce-7b5acd88e717`;
- capability audit metadata `{capability_code: manage_profile, enabled: false}`;
- removal audit metadata points to member Account `f22627d1-76fc-4b5d-927e-73a71e7817d1`.

## Failure classification / evidence hardening

Three earlier red runs were test/harness findings, not product-domain defects:

- an ambiguous text locator was narrowed to the Organization page heading;
- the removal notification refetch was made independent of Realtime delivery timing while retaining the same authenticated browser session;
- a reused multi-Organization test Account was correctly allowed to retain access to other Organizations, while the proof was tightened around the removed Organization's exact boundary.

No frozen business rule changed. The final run and artifact above are authoritative.

## Security / regression state

- migration `1031` is present in DEV;
- Edge Function `dev-test-identities` version `16` is active and remains protected by its canonical GitHub Actions OIDC checks;
- Supabase Security Advisor introduced no new migration finding; the only current warning is the pre-existing leaked-password-protection setting;
- model tests and the general DEV E2E harness both passed on the final commit.

## Next

Every side-effect gap SE-01 through SE-08 is closed. Proceed to the combined-regression gate, then adversarial/recovery/race testing.
