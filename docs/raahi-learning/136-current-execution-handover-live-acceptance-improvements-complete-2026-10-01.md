# Raahi Learning — Live Acceptance Improvements Complete

Date: 2026-10-01

## Canonical continuation state

Repository: `rajeevbackup42112-coder/raahi`
Branch: `raahi-learning-implementation-v1`
Local repo: `C:\Users\Dipti\Downloads\raahi-cutover-20260920`
Supabase controlled pilot: `iiwwmqokaeflaenhlyip`
Public: `https://learning.myraahi.co.in`

The accepted live-user improvement sequence from handover 135 is complete.

Deployed product SHA:
`68bfa4aa5cb817cebf4e1b9c663a209204bcc683`

Production Cloudflare deployment:
`a902432a-ba89-47ce-8b45-4279ac9e944d`

Immediate rollback anchor:
`dc0cd251-b708-4e20-b755-b1bc0d2defd3`
source `7d99b69165df0de0ca02e7778fde995b302ff624`

Do not confuse later documentation-only commits with the deployed product SHA.

## Completed improvement slices

- Slice A: semantic navigation cards — product commit `7b896fe618bd94948fdd21421bc3c4793b67083d`.
- Slice B: active learner context clarity — product commit `bf65527b0d4379e1d2467b32d4817d1b44e0948e`.
- Slice C: P06 Institute identity ambiguity — resolved as data reconciliation, not UI masking.
  - kept active Organization `251ad6fe-4b3b-4ade-84bf-5cad13cf2880`;
  - closed duplicate Organization `5c970182-38e1-42ff-a9a0-58a48d317e1a`;
  - ended only the duplicate creator membership;
  - preserved both creation audit records and all history;
  - no Classes, teaching options, Ads campaigns, enquiries, verification claims, saves, restrictions or invitations were attached to the retired duplicate.
- Slice D: human display normalization — commit `2abe922025027eede15a7771eab313399fdb7160`.
- Slice E: narrower Enquiry/notification refreshes — commit `644868c`; repeated notification history compacted — commit `68bfa4a`.
- Slice F: Platform Admin local-operations clarity and searchable Audit Log — commit `7e317ed`.
- Slice G: controlled Dhanbad test supply gated from ordinary discovery through canonical Platform Admin restriction RPC.

Launch-hygiene restriction:
`6914be17-0132-4516-8f33-470e50ab367a`
scope: `public_discovery`
target: controlled Teacher account `1e5eab7c-b8df-4148-9dba-5673fee7eee2`
Location: Dhanbad `028ee066-2130-45d6-8e17-6ceb9b0f1f80`

The controlled teaching option itself remains intact and clearly test-only.

## Qualification evidence

Independent CI for final product SHA `68bfa4aa...`:
- Raahi Learning Model Tests #812 — success.
- Raahi Learning Onboarding Browser Contract #57 — success.

Exact local preview:
- origin `http://127.0.0.1:4173`;
- `build-meta.json` commit `68bfa4aa5cb817cebf4e1b9c663a209204bcc683`.

Final exact-SHA candidate audit:
- 9/9 personas completed;
- 14 role contexts;
- 508 desktop/mobile screens;
- 6,498 controls inventoried;
- 0 screens with detected issues;
- 0 issue counts.

Cloudflare preview:
- deployment `827b6c88-b5e1-4aee-9c7d-9dfdefe595f3`;
- URL `https://827b6c88.raahi-learning-prod.pages.dev`;
- alias `https://acceptance-68bfa4a.raahi-learning-prod.pages.dev`;
- build metadata and all declared hashes match the production artifact metadata.

Public production `build-meta.json` now reports the exact same product SHA and file hashes.

## Post-deploy proof

Final nine-persona production smoke: PASS.

All nine authenticated Accounts retained their expected role/context shell, avatar, notification control and no horizontal overflow.

P08:
- Platform Admin capability present;
- Audit Log reached successfully;
- all Technical details disclosure controls measured 44px;
- no Audit overflow;
- Ads Home reached successfully.

P06:
- exactly one active Institute context remains;
- surviving ID is `251ad6fe-4b3b-4ade-84bf-5cad13cf2880`;
- Institute Home/Profile/Members resolve correctly after deployment.

P05:
- controlled Teacher workspace remains intact;
- test Teacher identity and Class history were not deleted or relabelled.

P09:
- fresh Home / Explore / Community / Messages / Classes / Notifications / Settings pass;
- 0 console errors, 0 failed requests, 0 HTTP >=400 in inspected states;
- 0 privileged navigation leaks;
- controlled test option `Raahi Test Science Tuition 05` is absent from the fresh Explore evidence.

## Current operational conclusion

The targeted P1/P2 live-acceptance improvement program is complete and deployed.
No new P0/P1 was found in final candidate or post-deploy verification.

Continue future work from this document. Do not redo the frozen nine-persona acceptance study or Slices A-G unless new evidence shows a regression.

Next product phase should focus on genuine market seeding and controlled real-user onboarding, while preserving the launch-hygiene restriction until controlled test supply is no longer needed.
