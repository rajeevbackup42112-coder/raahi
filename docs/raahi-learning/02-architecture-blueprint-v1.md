# Raahi Learning V1 — Architecture Blueprint

Status: **Architecture boundaries frozen enough to guide physical design. No deployment yet.**

## Recommended style

Use a **modular monolith** for V1:

**UI → authorized reads + canonical business commands → relational source of truth → events/notifications/realtime**

Do not start with microservices, event sourcing, Kafka, CQRS infrastructure, or multiple independent sources of truth.

## Logical modules

| Module | Owns |
|---|---|
| Identity & Access | Accounts, Learners, Account↔Learner authority, Organization membership |
| Locations | Location lifecycle and Location-scoped staff authority |
| Discovery | Teaching Options, Learning Requests, Saved items |
| Enquiries | Controlled relationship formation and enquiry messaging |
| Classes | Classes, Invitations, Memberships, Sessions, Materials |
| Activities | Activities and Submissions |
| Assessment | Tests, Test Attempts, evaluation/result visibility |
| Community | Local Community content and permitted interactions |
| Trust & Safety | Reports, Blocks, restrictions, Verification |
| Ads | Campaigns, revisions, review, commercial clearance, inventory and placements |
| Notifications | Derived delivery only; never owns core truth |
| Audit | Significant business/admin/safety/commercial actions |

These are ownership boundaries, not necessarily separate deployed services.

## Read/write rule

### Reads

Authorized projections/views may be queried efficiently for UI use.

Examples: Explore results, public profiles, My Classes summary, Community feed, active Sponsored placements.

### Writes

**UI never directly mutates core operational state.**

Writes happen through canonical business commands such as:

- `post_learning_request`
- `send_enquiry`
- `accept_class_invitation`
- `transfer_learner`
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
4. **What relationship/capability grants authority?** — self access, parent management, teacher responsibility, Organization membership, Local Manager Location assignment, Platform capability.

Example:

- Neha accepts Rahul's Class Invitation because her Account has management authority over Rahul.
- Rahul takes Rahul's Test because Rahul's Account has learner self-access + active Class Membership.
- Neha may view Rahul's Test status but does not gain `take_test` authority merely by being his parent.

## Canonical command ownership

| Command | Owner module |
|---|---|
| Create learner / grant learner access | Identity & Access |
| Publish Teaching Option | Discovery |
| Post/close Learning Request | Discovery |
| Send/engage/decline Enquiry | Enquiries |
| Send/accept/decline/cancel Invitation | Classes |
| Transfer/leave/remove learner | Classes / Safety-approved path |
| Publish Activity | Activities |
| Submit/review Activity work | Activities |
| Start/submit/evaluate Test | Assessment |
| Publish/moderate Community content | Community / Trust & Safety |
| Report / Block | Trust & Safety |
| Submit/review Ad revision | Ads |
| Reserve/confirm/release Ad inventory | Ads |
| Confirm/revoke Commercial Clearance | Ads |
| Pause/resume Ad placement | Ads |

There should be **one production command per meaningful business transition**.

## Hard transaction boundaries

### Accept Class Invitation

Atomic operation must cover:

- current invitation is Pending;
- caller has authority for target Learner;
- invitation not expired/cancelled;
- Class still accepts learners;
- capacity/reserved seat is valid;
- duplicate Membership does not already exist;
- Membership is created;
- Invitation becomes Accepted;
- reserved capacity is consumed/released consistently.

Partial success is not allowed.

### Transfer Learner

Atomic operation must ensure:

- destination Class can accept learner;
- destination Membership is created;
- source Membership becomes Transferred;
- failed destination creation cannot strand learner between Classes.

### Start/Submit Test

Start must enforce one valid attempt according to policy. Submit must persist answers and transition the exact Attempt exactly once.

### Reserve Ads Inventory

Concurrent holds/confirmations must never make reserved + confirmed capacity exceed configured Inventory Capacity.

### Campaign review

A review decision references an exact immutable Campaign Revision. An old screen must never approve a newer revision accidentally.

## Idempotency

Treat idempotency as platform-wide infrastructure for consequential commands.

Each command invocation should support a logical idempotency key or equivalent operation identity so network retries/double taps return the existing result rather than repeat side effects.

Priority commands:

- accept Invitation;
- transfer learner;
- submit Activity work;
- start/submit Test;
- review Ad revision;
- reserve inventory;
- commercial clearance actions.

## Server authority and stale UI

UI state is advisory. Before executing a command, authoritative state is re-read/revalidated.

Examples:

- “1 seat left” on a 30-minute-old screen does not guarantee the seat.
- expired invitation cannot be accepted from stale UI.
- old Ad review tab cannot approve a newer revision.
- removed Membership cannot keep using private Class APIs because the page was already open.

## Events and side effects

Commit core state first. After successful commit, publish/derive side effects such as:

- notifications;
- realtime invalidation;
- analytics counters;
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
- Ads inventory availability.

Actions revalidate against relational source of truth.

## Organic vs Sponsored architecture

Keep separate retrieval paths:

- **Organic discovery** computes organic relevance.
- **Ads serving** chooses eligible Sponsored inventory.
- UI composes them with explicit `Sponsored` labeling.

Do not implement paid weight inside the organic ranking calculation.

## Data privacy boundaries

### Public/discovery
Teacher/Organization profile, Teaching Options, sanitized Learning Requests, Community public content, Sponsored creative.

### Relationship-private
Enquiries, Enquiry messages, Class Invitations.

### Class-private
Materials, Activities, Submissions, Tests, Attempts, Class discussion.

### Moderation-private
Reports, reviewer notes, evidence, safety decisions.

### Commercial-private
Ads prices/packages, Commercial Clearance, Inventory Reservations, internal Ads operations notes.

Authorization/RLS must reflect these boundaries.

## File/storage authorization

Files must inherit the business object's access policy. Secret URLs alone are not authorization.

Examples:

- Class Material: permitted Class audience only.
- Learner Submission: learner, permitted parent/guardian, responsible teacher and authorized safety/admin actors.
- Ad Claim Evidence: advertiser's authorized members and authorized reviewers only.

## Audit requirements

Audit significant actions including:

- learner management/access changes;
- Organization authority changes;
- safety restrictions and exceptional removals;
- Test invalidation / answer-key correction / result recalculation;
- Verification grant/revoke;
- Ad review decisions;
- commercial overrides/waivers;
- inventory exceptions;
- significant Platform/Location admin actions.

Audit should answer: **who, what, target, when, authority/scope, and reason where required**.

## Architecture non-negotiables

- One canonical command per business transition.
- UI never directly mutates core business tables.
- Reads may use secure projections/views; writes use business commands.
- Authorization considers actor + acting-for + object + relationship/scope.
- Server state wins over stale UI.
- Critical commands are idempotent.
- Class and Ads capacity are transactionally protected.
- Core state commits before notification/realtime side effects.
- Realtime invalidates/refetches only.
- Organic and Sponsored systems remain separate.
- Significant admin/safety/commercial actions are auditable.
