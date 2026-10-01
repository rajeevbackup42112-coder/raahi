# Raahi Learning — Nine-Persona Real-User Story Execution

Date: 2026-10-01
Environment: https://learning.myraahi.co.in
Scenario: `137-nine-persona-real-user-story-2026-10-01.md`

## Executive result

The nine persistent Google-login personas were exercised as one connected live ecosystem, through their existing browser sessions and the public Raahi Learning site.

The test deliberately allowed state to persist. No database mutation was used to manufacture a successful browser outcome. Cross-user messages and Class communication created during this story remain visible when those Gmail accounts are opened again.

Overall result: **core learning ecosystem PASS, with one genuine Ads eligibility UX defect discovered.**

No new P0/P1 authority, privacy, data-loss or cross-account leakage defect was found.

## Persistent story outcomes

### Dhanbad family ↔ Science Teacher

P04 Parent asked P05 Teacher:
> We are revising electricity this week. Could you suggest what to practise before the next class—circuits, symbols or numericals?

P05 received it in its own Messages view and replied:
> Start with circuit symbols and simple series/parallel diagrams. After that, practise 4–5 basic current-and-voltage numericals and bring any doubts to the next class.

P04 then reopened the Enquiry from its own login and saw the Teacher response.

P05 also posted into the existing Science Class conversation:
> For this week, revise circuit symbols and draw one series and one parallel circuit before class. Bring one question you found difficult.

P04 reopened the Class conversation and saw that message.

P02 Dhanbad Local Manager then opened Operations, Learning activity, People & safety and Reports. None of the private Enquiry/Class message text appeared in those manager views.

### Gomoh learner ↔ Mathematics Teacher

P03 intentionally switched into its own Learner context. The UI identified:
`Learning for Rajeev.backup3.2112 · Your learning profile`.

P03 explored Gomoh, opened `Class 9–12 Mathematics Tuition`, reused the existing Enquiry and asked about coordinate geometry/distance-formula practice.

P07 saw the question in its own Teacher login and replied with a concrete study sequence: coordinate plane, Pythagoras theorem, then distance-formula practice.

P03 reopened the Enquiry and saw the Teacher reply.

P01 Gomoh Local Manager then reviewed Home, Learning activity, People & safety and Reports. Private learner/teacher message text did not leak into manager operations.

## Institute / Ads / Platform story

P06 Institute successfully opened:
- Institute workspace
- Institute Profile
- Institute Learning
- Manage Classes
- Institute members through the Home-page **Manage team** action
- Raahi Ads
- Create campaign

The Institute/member relationship remained singular and coherent. **Manage team** correctly resolved to `#/org-members`; its absence from the unrelated Classes subpage is not classified as a defect.

P06 then behaved like an advertiser and completed a valid draft-campaign form for an education-awareness campaign. The browser submitted through the canonical `create_ad_campaign` RPC.

The server correctly refused creation because this advertiser is not currently eligible:
`ADVERTISING_NOT_ENABLED`.

No campaign was created and nothing went live.

### Product finding — Ads eligibility experience

Classification: **P2 UX / trust / continuity issue**, not an authorization failure.

Observed experience:
1. Ads Home shows **Create campaign**.
2. P06 can open the full campaign creation form.
3. The page says drafts can be reviewed before anything goes live.
4. All required form fields validate.
5. Only after submission does the user receive the raw backend error `ADVERTISING_NOT_ENABLED`.

Expected product behavior:
- if the advertiser is not enabled, make that state clear before campaign creation;
- either disable/hide Create campaign or route to an eligibility explanation/action;
- never surface raw `ADVERTISING_NOT_ENABLED` to a normal advertiser.

This finding was not bypassed by enabling Ads behind the browser.

## Platform Admin governance

P08 was exercised through raw CDP because the existing 9238 profile has a known Playwright handshake quirk.

Platform role successfully covered desktop and mobile:
- Platform operations
- Safety & trust
- Ads review
- Location Admins
- Audit Log
- opening Audit technical detail

Current governance state was coherent:
- 2 active Locations
- 10 Accounts
- 3 Learner profiles
- 0 open reports
- 0 submitted Ads campaigns
- 0 live sponsored placements

Audit Log search and technical-detail disclosure worked without horizontal overflow. Platform Ads correctly showed no submitted campaign after P06's rejected creation attempt.

## Ordinary-user boundary

P09 remained an ordinary user throughout.

Desktop and mobile audits covered:
- Home
- Explore Dhanbad
- Community
- Messages
- My Classes
- Notifications
- Settings

Results:
- privilege leaks: **0**
- horizontal overflow: **0**
- console errors: **0**
- failed requests: **0**
- HTTP >=400 responses: **0**
- the quarantined `Raahi Test Science Tuition 05` option was absent from fresh P09 Explore evidence.

P09 did not receive Platform, Local Manager, Institute or advertiser controls.

## Page-level audit summary

Arc A audited 14 settled live pages across P04, P05 and P02.
Arc B audited 14 settled live pages across P03, P07 and P01.
P06 Institute/Ads traversal audited the main organization and advertiser surfaces before and during the rejected campaign attempt.
P08 governance was audited on both desktop and mobile.
P09 ordinary-user navigation was audited on both desktop and mobile.

Across the successful learning/manager arcs, every recorded page had:
- no horizontal overflow;
- no console/page errors;
- no failed requests;
- no HTTP >=400 response.

The only intentional error evidence in the story is the P06 campaign submission, whose RPC returned HTTP 400 with `ADVERTISING_NOT_ENABLED`.

Some long full-page screenshots timed out after fonts had loaded; this did not prevent DOM, route, network and cross-account outcome verification. Successful screenshots were retained. Screenshot timeout is treated as harness/evidence-capture friction, not a Raahi product failure.

## What the user can independently see now

Because these were persistent live actions rather than disposable fixtures:
- P04/P05 can see the new Science Enquiry conversation;
- P04/P05 can see the new Science Class message;
- P03/P07 can see the new Mathematics Enquiry conversation;
- P01/P02 remain operational managers with aggregate-only visibility;
- P06 still has no new Ads campaign because the server rejected creation before persistence;
- P08 continues to see governed Platform/Admin state;
- P09 remains an ordinary-user canary.

## Evidence

Scenario definition:
`docs/raahi-learning/137-nine-persona-real-user-story-2026-10-01.md`

Arc A evidence:
`tests/raahi-learning-e2e/artifacts-real-user-story-2026-10-01/arc-a-dhanbad/`

Arc B evidence:
`tests/raahi-learning-e2e/artifacts-real-user-story-2026-10-01/arc-b-gomoh/`

Arc C / P06 evidence:
`tests/raahi-learning-e2e/artifacts-real-user-story-2026-10-01/arc-c-governance/`

P08 targeted Platform/Ads evidence:
`artifacts-live-user-acceptance-2026-09-28/P08-platform-admin/targeted-platform-ads.json`

P09 evidence:
`artifacts-live-user-acceptance-2026-09-28/P09-explorer/results.json`

## Next gate

Freeze this evidence before changing the product.

The next implementation slice should address the P06 Ads eligibility experience only, then replay:
Institute -> Raahi Ads -> Create campaign

Success means an ineligible advertiser gets a clear human explanation before submission, with no raw backend error and no weakening of the existing server-side eligibility check.
