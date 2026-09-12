# Raahi Ads V1 — Product & Commercial Model

Status: **Behaviourally defined and included in Raahi Learning V1.**

## Purpose

Raahi Ads is **relevant sponsored local learning visibility**, not a generic ad network.

The problem it solves:

- schools/universities/coaching institutes/academies/teachers need credible access to relevant local learners and parents;
- users benefit from discovering legitimate educational opportunities they may not find organically;
- Raahi gains a revenue stream without taking a percentage of tuition fees or corrupting organic discovery.

## Allowed V1 advertiser use cases

Strong fit:

- school/college/university admissions;
- coaching/course/new-batch promotion;
- music/dance/karate/coding/spoken-English/yoga and other learning opportunities;
- educational events, open days, scholarship tests, competitions, workshops;
- institution/program awareness.

Not V1:

- generic consumer advertising;
- loans/insurance/real estate unrelated to learning;
- political ads;
- gambling/adult/restricted products;
- general B2B ad marketplace.

## Core invariant

> **Sponsored visibility can be purchased. Trust cannot.**

Paid campaigns cannot buy:

- Verification badges;
- “Raahi Recommended”;
- organic #1 ranking;
- category/location exclusivity;
- named user/viewer lists.

Every paid unit must visibly say **Sponsored**.

## Protected surfaces

Ads may appear in controlled adult/parent-facing surfaces such as:

- Home Sponsored card;
- Explore Sponsored result;
- selected Sponsored educational events/opportunities in Local Community.

No commercial Ads in:

- My Classes;
- individual Class;
- Activities/Practice/Assignments;
- Tests;
- private Messages;
- student-focused learning surfaces.

No Sponsored push notifications in V1.

## Targeting

V1 targeting is contextual and broad:

- selected live Raahi Location(s);
- broad adult audience context when useful;
- education category/goal.

No Facebook-style behavioral microtargeting.

Advertisers do not receive:

- browsing history;
- private search/message signals;
- child data lists;
- identities of people who merely viewed/opened an ad.

A user's identity becomes known only when the user deliberately initiates a normal Raahi Enquiry or intentionally leaves Raahi for an approved external destination according to normal web behavior.

## Advertiser identity

Advertising is a capability of an existing Account or Organization, not a mutually exclusive Advertiser account type.

Campaigns belong to the Organization/advertiser identity, not to an employee who happens to create them.

V1 may start with one authorized advertising contact per Organization; the conceptual model allows multiple authorized members later.

## Campaign goals

Suggested V1 advertiser objectives:

- **Admissions**
- **Course / New Batch**
- **Event / Open Day / Scholarship Test**
- **Institution Awareness**

These are advertiser-friendly goals; underlying placement/inventory mechanics remain governed separately.

## Campaign structure

A V1 Campaign contains one materially consistent promotion across selected Locations.

If Gomoh and Dhanbad require materially different copy/claims/fees/creative, use separate Campaigns rather than hidden Location-specific variants.

## Revision integrity

Approval applies to an exact immutable Campaign Revision.

If an advertiser materially changes:

- headline;
- image;
- fee;
- accreditation/ranking/placement claim;
- destination;
- substantive offer;

then a new reviewable revision is required.

An approved old revision may continue to run while a new revision is reviewed, provided the old revision remains valid/safe and the campaign remains otherwise eligible.

## Review ownership

- Single-Location normal campaign: authorized Local Manager/reviewer may handle local relevance/policy.
- Cross-Location campaign: Platform-level authority handles approval/coordination.
- Manager conflict of interest: reviewer cannot approve their own/connected institution's campaign; escalate.
- Sales/commercial staff cannot override policy/safety review merely because advertiser paid.

## Claim substantiation

Claims such as accreditation, recognition, placement rates, ranks, guaranteed selection/admission, or other material superlatives may require evidence before approval.

Review may therefore request Claim Evidence associated with the exact Campaign Revision.

Evidence is private review material unless explicitly intended/public.

## Commercial model

V1 should use simple fixed/configured packages rather than auctions, CPC or CPM bidding.

Possible package families:

- Admissions Visibility
- Course / Batch Promotion
- Event Promotion
- Institution Awareness

Commercial clearance records whether the agreed condition is satisfied. It does **not** mean the creative is approved.

Likewise approval does not mean commercial clearance exists.

Raahi sells **Sponsored visibility**, not guaranteed leads/admissions/outcomes.

If an ad runs as contracted but gets zero Enquiries, that does not automatically imply refund.

If Raahi materially fails to provide the agreed placement for Raahi-caused reasons, extension/credit may be appropriate according to configured policy.

## Finite inventory

High advertiser demand must never make Raahi more ad-heavy than intended.

Define inventory as:

**Location × Placement Type × Time Window × Capacity**

Example:

Dhanbad × Home Sponsored × Jan 1–7 × capacity 5 Campaigns in rotation.

Capacity is commercial inventory, not number of ads simultaneously visible.

> **Demand can exhaust inventory; demand cannot redefine user-facing ad density.**

## Inventory reservation

Temporary holds prevent a user from completing a long campaign flow only to lose the slot immediately, while also preventing indefinite inventory blocking.

Reservation lifecycle:

**Held → Confirmed / Released / Expired**

Rules:

- every hold has explicit expiry;
- duplicate/excessive holds can be blocked;
- current server capacity wins over stale UI;
- held + confirmed units may never exceed capacity;
- review failure or abandonment releases inventory according to policy;
- confirmed inventory does not authorize unapproved creative.

## No monopoly / exclusivity

One Organization must not acquire all scarce inventory by:

- duplicate Campaigns;
- slightly renamed Campaigns;
- duplicate Organization identities;
- purchasing every slot in a Location/category.

V1 does not sell category or Location exclusivity.

Raahi should remain accessible to legitimate small local educators as well as major universities/coaching brands.

## Multi-Location campaigns

A Campaign may target multiple live Locations.

Availability is evaluated separately per Location/placement/time. One unavailable Location does not require rejecting all others.

Serving is per Location:

- Gomoh = Live
- Dhanbad = Waiting
- Bokaro = Paused

is valid for one Campaign.

Location targeting describes where the opportunity can genuinely serve users, not where the advertiser is headquartered. A national online university may legitimately target Gomoh if the opportunity is genuinely available there.

## Serving eligibility

An Ad Placement may run only when all relevant conditions are valid, including:

- advertiser eligibility enabled;
- exact Campaign Revision approved;
- Commercial Clearance valid;
- Inventory Reservation confirmed/valid;
- target Location live;
- scheduled time reached and not expired;
- placement not paused/restricted;
- user/surface eligible for Ads;
- frequency/experience limits satisfied.

No one should have a magic “force Live ignoring rules” path.

## Rotation

System owns fair serving/rotation among eligible campaigns. V1 should not promise mathematically exact impression shares.

Commercial promise is participation in the agreed Sponsored placement/time under Raahi's controlled serving rules.

Buying multiple placements does not override per-user frequency controls.

## Analytics

Advertiser-facing metrics remain aggregate, for example:

- Sponsored views
- Opens
- Enquiries
- External destination visits

Breakdown by Location is valuable.

Do not call a view/open a “lead.” A user becomes a real Enquiry only after explicit contact intent.

No named viewer lists.

## User controls

Users may:

- open Sponsored content;
- Enquire intentionally;
- follow approved external destination;
- Save where relevant;
- Hide;
- Report.

Hiding affects that user's experience and does not expose their identity to advertiser.

Reports trigger review; report volume alone does not prove violation.

## Ads operations

V1 can let Platform Admin perform commercial Ads Operations initially. A dedicated Ads Operations staff capability should be introduced when real volume justifies it.

Do not burden Local Managers with all commercial negotiation, payment, scheduling, moderation and local ecosystem responsibilities.

## Pause reason matters

Different reasons have different commercial/safety consequences:

- advertiser-initiated;
- policy/safety;
- Raahi operational failure;
- Location operational pause;
- commercial/admin.

A safety pause is not automatically refundable. Raahi-caused material service failure may justify extension/credit.

## V1 deliberate exclusions

- ad auctions / bidding;
- CPC/CPM billing;
- guaranteed impressions/leads;
- advertiser CRM/lead assignment system;
- sponsored push notifications;
- per-Location creative variants within one Campaign;
- category/location exclusivity;
- behavior-based user audience builder;
- child/adolescent commercial microtargeting;
- full advertiser payment wallet/accounting suite.
