# Raahi Learning V1 — Architecture Blueprint

Status: **Architecture boundaries frozen enough to guide physical design. Physical blueprint reviewed through v1.1. No deployment yet.**

## Recommended style

Use a **modular monolith** for V1:

**UI → authorized reads + canonical business commands → relational source of truth → events/notifications/realtime**

Do not start with microservices, event sourcing, Kafka, CQRS infrastructure, or multiple independent sources of truth.

## Logical modules

| Module | Owns |
|---|---|
| Identity & Access | Accounts, Learners, Account↔Learner authority, Account capabilities, Organization membership |
| Locations | Location lifecycle and Location-scoped staff authority |
| Discovery | Teaching Options, Learning Requests, Saved items |
| Enquiries | Controlled relationship formation, Enquiry messaging and optional trial events |
| Classes | Classes, Invitations, Memberships, Sessions, Materials, private Class posts/discussion, contextual Class+Learner conversations |
| Activities | Activities and Submissions |
| Assessment | Tests, Test definition locking, Test Attempts, evaluation/result visibility |
| Community | Local Community content and permitted interactions |
| Trust & Safety | Reports, Blocks, scoped restrictions, Verification |
| Ads | Campaigns, requested targets, revisions, review, commercial clearance, overlap-safe inventory, placements, frequency control |
| Notifications | Derived delivery only; never owns core truth |
| Audit | Significant business/admin/safety/commercial actions |

These are ownership boundaries, not necessarily separate deployed services.

## Read/write rule

### Reads

Authorized projections/views may be queried efficiently for UI use.

Examples: Explore results, public profiles, My Classes summary, private Class feed, Community feed, active Sponsored placements.

### Writes

**UI never directly mutates core operational state.**

Writes happen through canonical business commands such as:

- `post_learning_request`
- `send_enquiry`
- `accept_class_invitation`
- `transfer_learner`
- `publish_class_post`
- `send_class_learner_message`
- `submit_activity`
- `start_test`
- `submit_test`
- `reserve_ad_inventory`
- `review_campaign_revision`

Each command revalidates current state, permissions and invariants.

## Authorization model

Do not rely on one fixed `role` field.

Each consequential authorization decision should answer:

1. **Who is acting?** — authenticated Account.
2. **For whom?** — Learner/Organization/Location scope if applicable.
3. **On what object?** — exact Request, Invitation, Test, Campaign, etc.
4. **What relationship/capability grants authority?** — self access, parent management, Account capability, teacher responsibility, Organization membership, Local Manager Location assignment, Platform capability.
5. **Is an active scoped restriction blocking this exact capability/surface?**

Example:

- Neha accepts Rahul's Class Invitation because her Account has management authority over Rahul.
- Rahul takes Rahul's Test because Rahul's Account has learner self-access + active Class Membership.
- Neha may view Rahul's Test status but does not gain `take_test` authority merely by being his parent.
- A teacher may be hidden from new discovery while an existing Class remains active unless a separate Class-access restriction applies.

## Canonical command ownership

| Command | Owner module |
|---|---|
| Create learner / grant learner access / grant Account capability | Identity & Access |
| Publish Teaching Option | Discovery |
| Post/close Learning Request | Discovery |
| Send/engage/decline Enquiry | Enquiries |
| Send/accept/decline/cancel Invitation | Classes |
| Transfer/leave/remove learner | Classes / Safety-approved path |
| Publish/comment Class Post | Classes |
| Send contextual Class+Learner message | Classes |
| Publish Activity | Activities |
| Submit/review Activity work | Activities |
| Publish/start/submit/evaluate/correct Test | Assessment |
| Publish/moderate Community content | Community / Trust & Safety |
| Report / Block / apply scoped restriction | Trust & Safety |
| Submit/review Ad revision | Ads |
| Reserve/confirm/release Ad inventory | Ads |
| Confirm/revoke Commercial Clearance | Ads |
| Pause/resume Ad placement / switch serving revision | Ads |

There should be **one production command per meaningful business transition**.

## Hard transaction boundaries

### Send / Accept Class Invitation

Sending a V1 Invitation reserves one finite seat until its finite expiry/resolution. Sending therefore must protect Class capacity as well as acceptance.

Acceptance atomically covers:

- current invitation is Pending;
- caller has authority for target Learner;
- invitation not expired/cancelled;
- Class still accepts learners;
- the reserved seat is valid;
- duplicate Membership does not already exist;
- Membership is created;
- Invitation becomes Accepted;
- reservation is consumed consistently.

Cancelling/declining/expiring must release reservation consistently. Partial success is not allowed.

### Transfer Learner

Atomic operation must ensure:

- destination Class can accept learner;
- destination Membership is created;
- source Membership becomes Transferred;
- failed destination creation cannot strand learner between Classes.

### Start/Submit Test

Start must enforce one valid attempt according to policy and lock Test definition no later than first valid Attempt creation. Submit must persist answers and transition the exact Attempt exactly once.

### Correct answer key

Once Test definition is locked, structural edits are prohibited. A correct-answer change uses a dedicated audited command that identifies affected evaluated Attempts and recalculates them transactionally.

### Reserve Ads Inventory

Physical capacity should be overlap-safe. The reviewed blueprint uses Location × placement × date capacity buckets. A multi-day/multi-location reservation locks/checks all required buckets atomically so concurrent holds/confirmations never exceed capacity on any day.

### Campaign review and serving revision

A review decision references an exact immutable Campaign Revision. An old screen must never approve a newer revision accidentally.

A Placement must also be pinned to an exact approved `serving_revision`. The “latest Campaign revision” must never be used implicitly for public serving.

## Idempotency

Treat idempotency as platform-wide infrastructure for consequential commands.

Each command invocation should support a logical idempotency key or equivalent operation identity so network retries/double taps return the existing result rather than repeat side effects.

Priority commands:

- send/accept Invitation where capacity is affected;
- transfer learner;
- submit Activity work;
- start/submit Test;
- review Ad revision;
- reserve/confirm/release Ads inventory;
- commercial clearance actions.

## Server authority and stale UI

UI state is advisory. Before executing a command, authoritative state is re-read/revalidated.

Examples:

- “1 seat left” on an old screen does not guarantee an Invitation can still reserve it.
- expired invitation cannot be accepted from stale UI.
- old Ad review tab cannot approve a newer revision.
- removed Membership cannot keep using private Class APIs because the page was already open.
- old Ads availability cannot oversell a daily capacity bucket.

## Events and side effects

Commit core state first. After successful commit, publish/derive side effects such as:

- notifications;
- realtime invalidation;
- aggregate analytics counters;
- search/index refresh;
- audit events where appropriate.

A notification outage must never make a valid Class join fail.

## Realtime

Realtime is **refetch/invalidation**, not source of truth.

Pattern:

1. Business command commits relational state.
2. Realtime informs interested clients that something changed.
3. Client refetches authorized authoritative projection.

## Search

Search/indexing may optimize Explore later, but search is never authoritative for transactional facts such as:

- Class seat capacity;
- invitation validity;
- Test attempt permission;
- Ads inventory availability;
- active safety restriction.

Actions revalidate against relational source of truth.

## Organic vs Sponsored architecture

Keep separate retrieval paths:

- **Organic discovery** computes organic relevance.
- **Ads serving** chooses eligible Sponsored inventory.
- UI composes them with explicit `Sponsored` labeling.

Do not implement paid weight inside the organic ranking calculation.

Ads serving additionally checks:

- target Location/placement;
- exact approved serving Revision;
- Commercial Clearance;
- confirmed inventory;
- Location state;
- Placement state/date;
- hidden/restriction/frequency rules;
- surface eligibility.

Private per-user frequency state may be used for serving but must never become advertiser-facing named viewer history.

## Data privacy boundaries

### Public/discovery
Teacher/Organization profile, Teaching Options, sanitized Learning Requests, Community public content, Sponsored creative.

### Relationship-private
Enquiries, Enquiry messages, Class Invitations.

### Class-private
Materials, Class posts/discussion, contextual Class+Learner conversations, Activities, Submissions, Tests, Attempts.

### Moderation-private
Reports, reviewer notes, evidence, safety decisions, scoped restriction reasons where sensitive.

### Commercial-private
Ads prices/packages, Commercial Clearance, Inventory Reservations, internal Ads operations notes, user-level Ads frequency controls.

Authorization/RLS must reflect these boundaries.

## File/storage authorization

Files must inherit the business object's access policy. Secret URLs alone are not authorization.

Examples:

- Class Material: permitted Class audience only.
- Learner Submission: learner, permitted parent/guardian, responsible teacher and authorized safety/admin actors.
- Community attachment: visibility follows public/moderation state.
- Ad Claim Evidence: advertiser's authorized members and authorized reviewers only.

Use storage metadata linked to the business object and signed/authorized retrieval rather than permanent public URLs for private files.

## Audit requirements

Audit significant actions including:

- learner management/access changes;
- Account capability grants/revocations where privileged;
- Organization authority changes;
- safety restrictions and exceptional removals;
- Test invalidation / answer-key correction / result recalculation;
- Verification grant/revoke;
- Ad review decisions;
- commercial overrides/waivers;
- inventory exceptions;
- serving-revision changes where operationally significant;
- significant Platform/Location admin actions.

Audit should answer: **who/what actor, action, target, when, authority/scope, and reason where required**. System-generated actions must be representable without pretending a human performed them.

## Architecture non-negotiables

- One canonical command per business transition.
- UI never directly mutates core business tables.
- Reads may use secure projections/views; writes use business commands.
- Authorization considers actor + acting-for + object + relationship/capability/scope + current restrictions.
- Server state wins over stale UI.
- Critical commands are idempotent.
- Class and Ads capacity are transactionally protected.
- Pending V1 Class Invitations have finite seat reservations.
- Test definition locks once valid Attempts begin.
- Core state commits before notification/realtime side effects.
- Realtime invalidates/refetches only.
- Organic and Sponsored systems remain separate.
- Ads live serving is pinned to an exact approved Revision.
- Per-user Ads frequency controls stay private from advertisers.
- Significant admin/safety/commercial actions are auditable.
