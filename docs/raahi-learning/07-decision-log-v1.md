# Raahi Learning V1 — Decision Log

This document records high-impact product decisions so future chats/agents do not reintroduce discarded complexity without evidence.

## Product positioning

- **Decision:** Raahi Learning supports all legitimate learning, not only school tuition.
- **Decision:** Local-first; Raahi launches one Location at a time.
- **Decision:** Discovery + ongoing private learning + Local Community are connected parts of one product.
- **Decision:** Ads is a separate governed commercial layer, not generic ad-tech.

## Terminology

- Market → **Location**.
- Market Manager → **Local Manager**.
- Provider → contextual Teacher/Coach/Instructor in UI.
- Offering → **What I Teach**.
- Requirement → **Learning Request**.
- Inquiry → **Enquiry**.
- Classroom → **Class**.
- Paid placement → **Sponsored**.

## Identity simplification

- **One Account may have multiple capabilities.** Do not create mutually exclusive learner/teacher/parent account types.
- **Learner is separate from Account.** Learning history belongs to the Learner.
- **Removed:** Adult Learner and Minor Learner as separate entities.
- **Removed:** turning-18 product migration/lifecycle. Age may affect permissions/policy without recreating identity.
- **V1:** one managing Parent/Guardian per Learner. Rich multi-guardian hierarchy deferred.
- Parent acts **for** a Learner rather than impersonating the Learner.

## Relationship simplification

- **Removed Enrollment as a separate domain object.**
- Approved journey: **Enquire → optional Trial → Class Invitation → Join → Membership**.
- Trial is an optional structured event inside Enquiry, not a mandatory lifecycle.
- **Removed Batch entity.** Saturday/Sunday groups are separate Classes; “batch” remains normal display wording.

## Learning simplification

- One Class concept supports 1:1 and Group.
- One responsible teacher/instructor per Class in V1.
- **Activity** unifies Assignment / Practice / Exercise.
- Tests remain separate because timing/attempt integrity differs materially.
- Attendance removed from V1.
- Generic overall progress percentage removed from V1.
- Archive states removed from many user-facing flows; use Past/Closed/history where sufficient.

## Discovery & privacy

- No public Learner directory.
- Learning Requests are sanitized and do not expose child photo, exact address or private contact data.
- Saving is private and creates no relationship.
- Browsing creates no messaging permission.
- Enquiry is the controlled relationship-starting action.
- No public generic Message button from provider discovery.

## Class security

- Invitation and Membership are separate.
- Membership, not URL possession, grants Class access.
- Class capacity must be transactionally protected.
- Transfer changes Memberships without rebuilding learner identity/history.
- Block is not the same as Leave Class.

## Parent/student permissions

- Same app, permission-driven surfaces; no separate Guardian or minor app.
- Parent may assist young learner with upload/access where allowed; learning artifact remains learner-owned.
- Parent management does not automatically grant Test-taking impersonation rights.
- Student/learner can report safety concerns independently of normal marketplace permissions.

## Location

- Selected Location changes discovery/community context, not existing Classes/Enquiries/Saved/history.
- A teacher may teach in multiple Locations under one identity.
- Public availability affects new discovery, not current learning relationships.
- Location pause does not automatically destroy private Classes.

## Community

- V1 Community is local, not global.
- No public downvote model.
- Community exists for useful learning discussion/events/support, not engagement for its own sake.
- Private Class content never leaks into Community.

## Trust

- No public star ratings/reviews in V1.
- Verification badges describe exact verified claims; no generic “Verified Teacher”.
- No public personal phone/email/home address by default.
- Report is a request for review, not proof of guilt.
- Serious safety cases may trigger immediate precautionary restrictions with audit/escalation.

## Ads

- Ads only for relevant educational promotion in V1.
- Every paid placement visibly says Sponsored.
- Sponsored placement is separate from organic ranking.
- Money cannot buy verification, recommendation or organic position.
- Commercial Ads do not appear in private learning/Test/Message/student learning surfaces.
- No behavioral microtargeting or named viewer lists.
- Simple fixed/configured packages before auctions/CPC/CPM.
- Finite inventory; demand never increases user-facing ad density.
- Inventory holds expire and cannot be oversold.
- No category/location exclusivity in V1.
- Anti-monopoly logic must consider advertiser Organization, not only Campaign count.
- One V1 Campaign uses one materially consistent creative across selected Locations.
- Review applies to an exact immutable Campaign Revision.
- Claims may require evidence.
- Commercial Clearance and content approval are separate.
- Multi-Location serving is independent per Location.
- Platform Admin can perform Ads Operations initially; dedicated Ads Ops is deferred until volume justifies it.

## Architecture decisions

- V1: modular monolith, relational source of truth.
- UI may read authorized projections but never directly mutate core operational tables.
- One canonical command per business transition.
- Authorization = actor + acting-for + object + relationship/scope.
- Consequential commands are idempotent.
- Server state beats stale UI.
- Capacity/inventory commands are atomic/transactionally protected.
- Core state commits before notifications/realtime side effects.
- Realtime is invalidation/refetch, not source of truth.
- Organic search and Sponsored serving are architecturally separate.
- Significant admin/safety/commercial actions are auditable.

## Explicitly deferred until evidence exists

- microservices / Kafka / event sourcing;
- global community;
- multi-teacher Class;
- rich multi-guardian workflows;
- institute ERP/payroll/branch administration;
- platform tuition payments/escrow;
- advertiser CRM;
- Ads bidding/auction/CPC/CPM;
- sponsored push notifications;
- built-in live video;
- certificates/gamification/leaderboards;
- AI tutor;
- complex calendar/attendance.

## V1.3 authentication amendment

This amendment changes authentication UX only; it does not reopen the domain model above.

- **Primary production sign-in:** Google via Supabase Auth.
- Google authentication proves Account identity/session only. It never grants Raahi role/capability/relationship authority.
- Google-provided name and photo are editable onboarding defaults, not legal verification or permission truth.
- Google photo is never automatically public; explicit opt-in import into Raahi-controlled media is required.
- Phone verification becomes an **Account trust signal**, not the repeated primary login flow.
- Phone trust uses a 90-day freshness policy for selected trust-sensitive actions only.
- Stale phone trust must not block existing Class/Activity/Test/history access, existing contextual messaging, Leave/Transfer, or Report/Block/safety actions.
- New trust/authority/public/commercial transitions may require fresh phone proof as specified in `41-authentication-phone-trust-v1.3.md`.
- Phone change invalidates previous trust freshness.
- V1.3 does **not** use paid Advanced Phone MFA merely to implement this freshness policy.
- A public phone-login fallback is not added unless separately approved later.
- DEV may use Supabase-supported fixed test OTP mappings; production test OTP mappings are forbidden.
- External Google OAuth credentials and a production SMS provider remain configuration/service boundaries, not database assumptions.
- The final V1.3 UX review does **not** re-open one-managing-guardian, public learner directory, unrestricted DM, public ratings, anonymous Community, or other intentionally deferred V1 complexity.
- Logged-out marketplace discovery is deferred until acquisition evidence justifies the additional anonymous surface.


## V1.3 public-launch Location amendment

- A Raahi Account is not permanently bound to one city/locality.
- Selected Location is the current local context for discovery, Community and other locality-scoped public surfaces.
- Users may switch Locations freely; switching Location does not alter Account identity, Learners, Classes, Messages, history or existing relationships.
- Dhanbad and Gomoh are both live/selectable for first public launch.
- Gomoh is the first acquisition/promotion market, not an authorization boundary.
- A Gomoh user switching to Dhanbad is normal supported behavior.
- Future Locations such as Topchachi, Bokaro and Ranchi are added as independent configurable Locations when ready; no new account model is required.
- Do not introduce a special Dhanbad-region hierarchy before evidence shows it is necessary.
- See `88-gomoh-first-public-launch-model-2026-09-20.md`.

## Change-control rule

A future agent should not reintroduce a removed entity/state/role because it “sounds standard”. First demonstrate a concrete scenario that cannot be represented safely with the frozen simpler model. Then perform impact analysis across business rules, entities, relationships, states, permissions, money, matching/discovery, UI and tests before changing the model.
