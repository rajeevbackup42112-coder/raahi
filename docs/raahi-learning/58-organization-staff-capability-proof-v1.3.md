# Raahi Learning V1.3 — Bounded Organization Staff Capability Proof

Status: **PROVEN IN LEARNING DEV**  
Date: 2026-09-18

## Purpose

Prove that Organization staff workspaces derive from exact server-authorized capabilities rather than persona labels, URLs, or UI workspace choice.

The proof uses genuine Supabase Auth sessions, canonical private staff invitations, normal browser navigation and server-side authorization failures.

## Actors and authority

Organization:

- Organization ID: `8c431f0d-220a-4877-88b2-e98e8ea81672`

Owner:

- Account ID: `89d5aace-670d-4fa7-98ba-7fd413185e34`
- active capabilities: `manage_ads`, `manage_classes`, `manage_members`, `manage_profile`, `manage_teaching_options`

Profile-limited staff:

- Account ID: `5c5322ac-270f-4c3f-8332-ff6781cfa792`
- Organization member ID: `259b3e66-d710-4e02-985b-80862b271689`
- exact capability: `manage_profile`

Ads-limited staff:

- Account ID: `a28318a8-6ea2-4afe-a9c3-e3b46fb86978`
- Organization member ID: `c15cea62-51e0-4c8b-9f88-f664626c6dce`
- exact capability: `manage_ads`

Unrelated Account:

- Account ID: `9d3ac31e-bfb3-4c9a-90a8-1663b6d09a43`
- no Organization membership.

## Canonical setup

The owner issues private invitations through:

`issue_organization_member_invitation`

Staff accept through:

`accept_organization_member_invitation`

No direct Organization-membership or capability-table writes are used by the proof.

The resulting Account context is then re-read and exact capability sets are asserted.

## Server authorization checks

The proof confirms:

- profile-limited staff cannot issue Organization member invitations;
- ads-limited staff cannot update the Organization profile;
- unrelated Account cannot read the Organization workspace;
- capability-denied calls fail server-side rather than relying on hidden buttons.

## Browser checks

Profile-limited staff:

- receives Institute workspace;
- does **not** receive Raahi Ads workspace;
- can open Institute Profile;
- direct Institute Learning deep link remains capability-denied;
- direct Institute Members deep link remains capability-denied;
- unauthorized action controls are absent.

Ads-limited staff:

- receives Institute and Raahi Ads workspaces;
- can open Raahi Ads and Create Campaign;
- direct Institute Profile route remains `manage_profile`-denied.

Unrelated Account:

- receives neither Institute nor Raahi Ads privileged workspace;
- copied/deep-linked Organization home fails closed;
- absence of a workspace selector is accepted as valid behavior when there is no authorized workspace to switch to.

## Test-Harness findings

Three harness-only issues were corrected during proof construction:

1. concurrent Ads/staff suites initially shared one mutable credential namespace;
2. a missing display-name value caused `bootstrap_account` to be called without its required argument;
3. the unrelated-user oracle incorrectly assumed every Account must have a workspace selector.

None required a product/domain change.

Final isolated namespaces:

- advertiser convergence: `ui4_ads`
- Organization staff boundaries: `ui4_staff`

## Final proof

GitHub Actions run: `35325846951`  
Exact deployed/tested commit: `9da38c7c224d3131709329905d7cd1233558226c`  
Evidence artifact: `raahi-learning-org-staff-boundaries-35325846951-1`  
Artifact digest: `sha256:ad96323cca6ec263691a633d4737304c4ae5ff7da8bc00e0788c61ef070596bd`

Result: **PASS**

## Frozen rule reinforced

**Workspace selection never grants authority.**

Authority continues to come from the signed-in Account plus current Organization membership/capabilities, with canonical RPC/RLS enforcement on every consequential operation.

## Next

Establish one combined exact-build regression anchor across model tests, genuine-session harness, 20-persona cohort and all UI/capability convergence suites. Then proceed to remaining vertical-slice and adversarial/recovery/race gates.
