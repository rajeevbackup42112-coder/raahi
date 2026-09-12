# Raahi Learning V1 — Canonical Domain Model

Status: **Conceptual model frozen for V1.** Physical schema comes later.

## Canonical concepts

### Identity and access

- **Account** — authenticated human using Raahi.
- **Learner** — person whose learning history/classes/work belong to them.
- **Account–Learner Access** — relationship describing whether an Account may act for a Learner (self or managing parent/guardian).
- **Organization** — school, university, coaching institute, academy, etc.
- **Organization Membership** — who may act for an Organization and with what capabilities.

### Location

- **Location** — Raahi's local operating/discovery/community boundary (e.g. Gomoh, Dhanbad).
- **Location Assignment** — scope granting a Local Manager authority for one or more Locations.

### Teaching and discovery

- **Teaching Option** — public “What I Teach” item by an individual teacher or Organization.
- **Learning Request** — one Learner seeking one meaningful learning need in one Location context.
- **Saved Item** — private bookmark relationship; no social signal.

### Relationship formation

- **Enquiry** — controlled communication context between the learner side and a teacher/Organization.
- Trial is represented as a structured event within Enquiry, not a separate relationship layer.

### Private learning

- **Class** — private learning space; 1:1 or Group.
- **Class Invitation** — controlled invitation to join a specific Class.
- **Class Membership** — actual learner access to a Class.
- **Session** — lightweight scheduled occurrence of a Class.
- **Material** — learning resource shared with one or more Classes.
- **Activity** — underlying assignment/practice/exercise concept.
- **Submission** — learner work for an Activity; meaningful revisions preserved.
- **Test** — structured assessment.
- **Test Attempt** — one learner's protected attempt at a Test.

### Community and trust

- **Community Post** — Location-scoped public learning/community content.
- **Community Comment/Reaction** — controlled interactions; no public downvote model.
- **Verification** — exact verified claim attached to a teacher/Organization/profile.
- **Report** — request for review/moderation; not proof of wrongdoing.
- **Block** — contact/control relationship; not equivalent to Class removal.

### Ads

- **Advertising Eligibility** — whether an Account/Organization may advertise.
- **Campaign** — advertiser's promotion initiative.
- **Campaign Revision** — exact immutable public ad content version being reviewed/shown.
- **Ad Review** — decision against a specific Campaign Revision.
- **Commercial Clearance** — whether the agreed commercial condition is satisfied.
- **Inventory Capacity** — sellable Sponsored capacity for Location × placement × time.
- **Inventory Reservation** — temporary/confirmed claim by a Campaign against capacity.
- **Ad Placement** — per-Location serving state for a Campaign.
- **Claim Evidence** — supporting material for claims requiring substantiation.
- Ads reuse the existing Enquiry and Report systems.

## Concepts deliberately not created

- Enrollment
- Batch
- Adult Learner
- Minor Learner
- turning-18 migration
- Trial relationship object
- Assignment and Practice as separate domain models
- Attendance
- generic Progress percentage
- public Learner Profile
- advertiser viewer list / lead directory
- Ads conversation system
- global Community

## Core relationships

### Identity

- Account **may act for** many Learners.
- Learner may have self-access through an Account.
- One Account may also have teaching capabilities and Organization memberships.
- Learning artifacts always belong to the Learner even when another Account performs an allowed operational action.

### Teaching and discovery

- Account or Organization **publishes** Teaching Options.
- Learner **has** Learning Requests.
- Learning Request **belongs to** a Location.
- Enquiry may originate from:
  - Learner-side action against a Teaching Option; or
  - Provider interest in a Learning Request.
- Both flows converge into the same Enquiry model.

### Learning

- Class **has one responsible teacher** in V1.
- Class may be operated by an Organization.
- Class **has** Class Invitations.
- Valid accepted Invitation **creates** Class Membership.
- Learner **accesses Class through Membership**.
- Class **has** Sessions, Activities and Tests.
- Material may be shared with one or multiple Classes.
- Activity **has** learner Submissions.
- Test **has** learner Test Attempts.

### Community

- Community Post **belongs to** one Location.
- Community permissions derive from Account capabilities/policy, not a separate Community identity.

### Ads

- Eligible Account/Organization **creates** Campaign.
- Campaign **has many** Campaign Revisions.
- Campaign Revision **receives** one or more Ad Reviews over time.
- Campaign **targets** Locations through Ad Placements.
- Campaign **reserves** Inventory Capacity through Inventory Reservations.
- Campaign **requires** valid Commercial Clearance before serving.
- Claim Evidence **supports** a specific Campaign Revision/claim.
- Explicit Sponsored Enquiry reuses normal Enquiry with attribution source.

## Canonical lifecycles

### Learning Request

**Draft → Open → Closed**

Closed may reopen when the underlying need is still the same.

### Enquiry

**Pending → Active → Closed**

### Class

**Draft → Active → Past**

### Class Invitation

**Pending → Accepted / Declined / Expired / Cancelled**

### Class Membership

**Active → Completed / Left / Transferred / Removed**

### Activity

**Draft → Open → Closed**

### Submission

Current status is **Submitted / Changes Requested / Reviewed**; revisions are historical versions rather than a large state machine.

### Test

**Draft → Available → Closed**

Upcoming is derived from start time. Result visibility is separate.

### Test Attempt

**In Progress → Submitted → Evaluated / Invalidated**

### Location

**Preparing → Live → Paused → Retired**

### Ads

Do not collapse Ads into one status. Separate:

- Advertiser eligibility
- Campaign existence
- Campaign Revision review
- Commercial Clearance
- Inventory Reservation
- per-Location Ad Placement

A Campaign may validly be Approved, commercially Cleared, Live in Dhanbad, and Paused in Gomoh at the same time.

## Universal invariants

1. **Learner ownership** — learning history/artifacts belong to Learner, not merely the Account performing the action.
2. **Authorization-at-execution** — every consequential action re-checks current authority when executed.
3. **Idempotency** — repeated logical command must not perform the action twice.
4. **Capacity** — Class capacity and Ads inventory capacity may never be exceeded.
5. **Privacy** — browsing, Saving, or viewing Sponsored content does not create a relationship or expose identity.
6. **Class security** — possession of a Class URL never grants access.
7. **Location** — selected Location changes discovery/community context, not ownership of existing relationships.
8. **Discovery vs current learning** — provider availability affects new relationships, not existing Classes.
9. **Safety** — Report remains available independently of ordinary communication permissions; Block does not erase evidence.
10. **Ads integrity** — paid Sponsored visibility cannot buy verification, endorsement, or organic ranking.
11. **Server authority** — current authoritative state wins over stale UI.
12. **No direct state mutation** — business state transitions occur through canonical commands, not arbitrary UI writes.
