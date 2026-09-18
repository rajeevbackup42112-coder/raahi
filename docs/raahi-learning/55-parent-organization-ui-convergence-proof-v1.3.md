# Raahi Learning V1.3 — Parent + Organization UI Convergence Proof

Status: **PROVEN IN LEARNING DEV**  
Date: 2026-09-18

Reference UI: frozen clickable artifact `Raahi_Learning_Clickable_UI_v1.1.zip`.

## Scope

Second convergence slice:

- managed-parent learner-side workspace;
- Organization owner / Institute workspace;
- desktop `1440×900`;
- mobile `390×844`.

Routes:

`home`, `explore`, `classes`, `notifications`, `learners`, `community`, `messages`, `settings`, `org-home`, `org-profile`, `org-teaching`, `org-members`.

## Harness findings

Two early failures were **Test-Harness assumptions**, not product defects:

1. a single-workspace Account may have no workspace selector at all; the harness now accepts the server-selected implicit workspace;
2. frozen fixture data uses Gomoh / Bright Minds Academy while live DEV uses the actual selected Location / Organization. Dynamic Location and Organization-name headings are now compared semantically rather than as fixture literals.

The fixture Organization workspace is entered through its own normal **Institute** switch control before comparison.

## Product findings and fix

The first real comparison found two narrow mobile presentation defects:

- `Learning profiles`: learner management action buttons overflowed the mobile card;
- `Institute members`: member action controls overflowed the mobile card.

Classification: **Implementation/UI**.

Fix: presentation-only wrapping/gap constraints are applied after render on those two routes. No business rule, RPC, permission, relationship or database state changed.

Fix commit: `b5dba207be1a26ab5b7fea82069508e0a5eb8453`.

## Final proof

Hardened parent + Organization run:

- GitHub Actions run: `35317746540`
- exact tested/deployed commit: `5688a0ab22bdbff3653b75073a71b325e3bbae55`
- evidence artifact: `raahi-learning-ui-convergence-parent-org-35317746540-1`
- artifact digest: `sha256:279317c77e2ef4eeeb2c6753e8eef280c3a90d60b32f180a7a49e8cb7bca619a`
- result: **PASS**

The runner now verifies the exact build both before and after the proof so a mid-run Cloudflare deployment cannot be mistaken for UI drift.

Core learner + teacher regression was rerun on a stable exact build after the same hardening:

- GitHub Actions run: `35317981047`
- exact tested/deployed commit: `9bb1d202ccf3852d7e208e48c9828e8be880b142`
- evidence artifact: `raahi-learning-ui-convergence-core-35317981047-1`
- artifact digest: `sha256:24677d8b4653d9265fdc07846c8e733dd21eef95f010f80b7cfbd0ef3ae15a5f`
- result: **PASS**

## Proven checks

Across the scoped routes/viewports:

- frozen page/shell presentation contract converges;
- dynamic Location/Organization data remains live rather than fixture-forced;
- no horizontal overflow remains;
- desktop/mobile shell visibility matches;
- main-column geometry and heading typography/background shell match;
- genuine DEV Auth sessions and canonical parent/Organization setup are used;
- live product projections are rendered, not fixture business output;
- deployment SHA remains unchanged across each proof.

## Next

Proceed to privileged operational workspace convergence:

- Local Manager;
- Platform Admin;
- Ads / commercial operations;
- bounded capability-specific Organization staff surfaces.

Authority must be established through real capabilities/scopes; persona labels alone never grant access.
