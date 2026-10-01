# Raahi Learning — Nine-Persona Real-User Story

Date: 2026-10-01
Environment: https://learning.myraahi.co.in
Execution rule: browser-first, persistent state, no direct database mutation to make a step pass.

## Story premise

A normal learning week unfolds across Gomoh and Dhanbad. Two families look for help, two teachers respond, an institute works on its own learning/advertising presence, local managers observe genuine aggregate activity, the Platform Admin reviews governed operations, and an ordinary explorer sees only what an ordinary user should see.

The objective is not merely to prove that buttons click. Every action must create a believable consequence for another logged-in account.

## Trust rules

- Treat every Gmail session as a persistent real user.
- Do not invent qualifications, testimonials, ratings, awards, school affiliations or examination results.
- Do not directly edit database rows to force an outcome.
- Use only actions exposed by the live website, except read-only backend verification after the fact.
- Existing historical content is preserved.
- Every visited page is audited for heading/context, controls, overflow, console errors, failed requests and visible outcome.

## Cast

| Browser | Account | Story role |
|---|---|---|
| Raahi-01 | rajeev.backup1.2112@gmail.com | Gomoh Local Manager |
| Raahi-02 | rajeev.backup2.2112@gmail.com | Dhanbad Local Manager |
| Raahi-03 | rajeev.backup3.2112@gmail.com | Self Learner + family decision-maker in Gomoh |
| Raahi-04 | rajeev.backup4.2112@gmail.com | Parent in Dhanbad |
| Raahi-05 | rajeev.backup5.2112@gmail.com | Dhanbad Science Teacher workspace |
| Raahi-06 | rajeev.backup6.2112@gmail.com | Institute operator + Raahi Ads advertiser |
| Raahi-07 | mrrajeevsinha2112@gmail.com | Gomoh Mathematics Teacher |
| Raahi-08 | choudhary.ajit2112@gmail.com | Platform Admin |
| Raahi-09 | nareshkumar62922@gmail.com | Ordinary learner/explorer with no privileged access |

## Narrative arc A — Dhanbad family and Science Teacher

1. P04 opens Home and reviews the learner it manages.
2. P04 opens its existing active Science enquiry and sends a natural question about the learner's next topic.
3. P05 opens Messages and receives that question through the existing relationship.
4. P05 replies with a useful, non-credentialled learning suggestion.
5. P04 returns to Messages and confirms the reply persisted in its own account.
6. P05 opens its active Science Class and sends one useful Class message/update for existing learners.
7. P04 opens the Class conversation from its own account and confirms the Class update is visible.
8. P02 checks Dhanbad operations and confirms aggregate activity remains useful without exposing private learner/message content.

## Narrative arc B — Gomoh learner and Mathematics Teacher

1. P03 switches deliberately into its own learning context and confirms the active learner is visually obvious.
2. P03 explores Gomoh and opens P07's Mathematics offering through discovery.
3. P03 opens the existing enquiry/relationship rather than creating a duplicate.
4. P03 sends a genuine learning question about coordinate geometry practice.
5. P07 opens Messages, reads the learner's question and replies with a useful next step.
6. P03 returns to Messages and confirms the reply persisted.
7. P07 inspects its Classes and current teaching workspace; no unrelated learner or private family information should leak.
8. P01 reviews Gomoh local operations and sees only aggregate/local operational information.

## Narrative arc C — Institute, advertising and governance

1. P06 opens Institute Overview, Profile, Learning, Classes and Team as an institute operator.
2. P06 switches to Raahi Ads and creates a draft education-only campaign; it is kept as a draft unless the UI explicitly requires review submission.
3. P06 reviews the campaign detail/creative/inventory/analytics surfaces that are legitimately available.
4. P08 opens Platform operations and Audit Log to confirm the governed action trail is understandable.
5. P08 opens Ads operations/review and verifies the institute draft is not silently treated as approved/live.
6. P08 checks local-operation scope and switches back without privilege/context confusion.
7. P09 explores Dhanbad as an ordinary user and must not gain Platform, Local Manager, Institute or advertiser controls.
8. P09 also verifies that quarantined controlled teaching supply remains absent from ordinary discovery.

## Cross-cutting behaviour

All nine users will also exercise ordinary navigation, Notifications, Settings/context switching and at least one refresh/re-entry during the story. The audit records every page actually visited, not only successful mutations.

## Per-page acceptance audit

For every page reached during execution record:

- actor/account and effective role;
- URL/hash, page title and primary heading;
- selected Location and selected learner/institute context where applicable;
- visible calls-to-action and whether they are semantically clear;
- horizontal overflow, clipped controls and obvious overlaps;
- console/page errors and failed network requests;
- any HTTP/RPC failure surfaced during the action;
- screenshot after the page settles;
- whether the expected consequence is visible to the same actor;
- where applicable, whether the consequence appears to the other actor after normal navigation/refresh.

A failure is documented as a product finding. The browser is not bypassed to manufacture a green result.

## Execution safety / stop conditions

Continue autonomously through ordinary live actions. Stop before:
- entering a new OTP or other human credential;
- making a false qualification/identity claim;
- publishing a paid/live advertisement or spending money;
- deleting/closing a real relationship or account merely to simplify the scenario;
- using direct table DML as a substitute for a missing/broken UI action.

Drafts, normal messages, learning requests, Class learning actions and governed admin reviews may persist because persistence is part of this test.
