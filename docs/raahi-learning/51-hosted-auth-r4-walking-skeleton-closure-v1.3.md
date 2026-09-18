# Raahi Learning V1.3 — Hosted Auth + R4 Walking Skeleton Closure

Status: **R4 PROVEN IN LEARNING DEV**  
Date: 2026-09-18  
Repository: `rajeevbackup42112-coder/raahi`  
Branch: `raahi-learning-implementation-v1`  
Supabase DEV: `iiwwmqokaeflaenhlyip`

This is execution evidence. It does not change frozen Raahi product rules.

## 1. Hosted Auth evidence

Real hosted Supabase Auth identities now exist and remain mapped one-to-one to Raahi Accounts.

### Rajeev 1 — Google + phone continuity

- Auth user: `580f39b5-4341-4473-af7d-301b8245263b`
- Raahi Account: `8c96dbc0-9627-48e2-86a1-3ec72e42e7ec`
- Auth identities: Google + phone
- confirmed phone state exists in hosted Auth
- Google remains the normal primary sign-in UX

### Rajeev 4 — interrupted-action phone attachment

- Auth user: `c8f064e6-ee6d-49c2-9a05-c7e4dd3335af`
- Raahi Account: `6a0d9209-339d-42a4-acd9-e13a3dde8b46`
- Auth identities after proof: Google + phone
- same Auth user and Account survived phone attachment
- fresh phone trust allowed the preserved Class Invitation acceptance to resume

No Raahi fake OTP endpoint was introduced. Hosted Supabase Auth remained the proof mechanism.

The periodic **same-phone refresh** ceremony is still a provider-specific smoke case to keep in the pre-launch Auth suite. It is not required to reopen the completed walking-skeleton gate.

## 2. Original R4 relationship/phone-resume chain

The original real-user chain remains durable in DEV:

- Learner: `dec5913e-58c6-47cd-b8ba-032567c668d2`
- Class: `1ecb3582-61b2-4a9f-88a4-ffff4cc26f4a`
- Invitation: `f3d1d310-907a-4fd3-923b-6122b1ca060e`
- Membership: `136aa637-f83e-4e68-9da5-f2b0ebaa01c7`

Current server evidence:

- Rajeev 1 former `manage` access = ended;
- Rajeev 4 `self` access = active;
- Invitation = accepted;
- exactly one active Membership exists for that Class + Learner;
- Membership points to the accepted Invitation.

This chain proves the authority handoff and phone-trust interruption/resume boundary.

## 3. Autonomous Class-message / privacy closure

The final R4 boundary was re-proven with isolated genuine DEV sessions so it no longer depends on manual multi-browser login.

GitHub Actions run: `35304128510`  
Exact deployed/tested commit: `dbf7216f61e99d63d0cd559f05dbdd327e85e620`  
Evidence artifact: `raahi-learning-r4-class-thread-35304128510-1`  
Artifact digest: `sha256:2ce65875913e82479ee0dd3f41193a8112b38aa0971d1d7a5804732e00966970`

Captured IDs:

- Learner: `e7e1f58a-cdc5-430e-95ef-67d7124ca4c8`
- Enquiry: `f25ffbb7-b901-4a25-9e8e-aaf466a20e8a`
- Class: `57bfb489-60d3-4e0e-87f6-ee4f0fda4e0e`
- Invitation: `4d70e960-e2a2-4efb-a463-cd76ab5d9b5b`
- Membership: `7abe8972-8cf9-434a-9439-de867467a923`
- Class thread: `bd2226b9-7739-432a-abd7-9787df921043`
- Class message: `1059916a-96b1-43f7-bb2f-2144b986b915`
- receiver notification: `75ee4a46-21eb-4d9f-b813-b11234299304`

Proven sequence:

1. genuine learner/teacher/unrelated Supabase sessions issued;
2. Teacher setup uses canonical commands;
3. Learner relationship → Enquiry → provider engage/reply → Class → Invitation → acceptance uses canonical commands;
4. exactly one active Membership exists;
5. Class thread does not exist before the first message;
6. Learner sends the first contextual Class message through the normal Raahi browser UI;
7. exactly one receiver `class_message` notification is created;
8. Teacher sees the notification in the normal Notifications UI;
9. Teacher clicks the actual **Open** button;
10. UI routes to a safe link containing only opaque Class/Learner IDs;
11. Teacher sees the authorized thread and exact message;
12. unrelated projection call returns `NOT_AUTHORIZED`;
13. unrelated direct RLS read returns zero thread rows;
14. unrelated browser opens the exact copied notification link and gets **Class conversation unavailable**;
15. unrelated browser does not receive Class title, Learner name, or message body;
16. server recheck confirms one Class+Learner thread and one exact message.

Independent PostgreSQL verification matched the CI artifact: Class active/capacity 1, Invitation accepted, active Membership count 1, thread count 1, exact message count 1, and receiver notification payload references the same Class/Learner/thread/message IDs.

## 4. Harness defect discovered and fixed

An intermediate proof run failed because the core harness and R4 harness rotated the same test-persona passwords concurrently.

Classification: **Test-Harness concurrency defect**.

Fix:

- test identities are now namespaced by suite;
- core harness uses `core` personas;
- R4 proof uses isolated `r4` personas;
- provider sessions/credentials no longer race across workflows.

No product authorization rule was weakened.

## 5. R4 verdict

The mandatory walking skeleton is **PROVEN** for the required cross-layer boundaries:

`Auth → Account → Learner → discovery/provider relationship → Enquiry → Class Invitation → phone trust interruption/resume → Membership → Class → contextual message → notification/deep link → unrelated denial`.

R4 must not be reopened merely because later UI-convergence work changes presentation. Reopen only if a regression fails, a frozen rule changes, or a real domain/security contradiction appears.

## 6. Next gate

Continue with the Master Lifecycle sequence:

1. keep the DEV identity/session harness as the normal regression foundation;
2. expand representative deterministic personas;
3. UI/interaction convergence against the frozen V1.3 artifact;
4. remaining vertical slices;
5. adversarial/recovery/concurrency testing;
6. reliability/security/load/launch gates.

Google OAuth and SMS/OTP remain small provider-specific smoke suites rather than the ordinary regression mechanism.
