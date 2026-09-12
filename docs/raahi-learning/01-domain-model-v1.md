# Raahi Learning V1 — Canonical Domain Model

Status: **Conceptual model frozen for V1. Physical design reviewed through database blueprint v1.1.**

## Canonical concepts

### Identity and access

- **Account** — authenticated human using Raahi.
- **Learner** — person whose learning history/classes/work belong to them.
- **Account–Learner Access** — relationship describing whether an Account may act for a Learner (self or managing parent/guardian).
- **Account Capability** — explicit unscoped capability where authority is not represented by a Learner/Organization/Location relationship (for example teaching eligibility, Community posting eligibility, verifier/platform/commercial capability).
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
- **Class Invitation** — controlled invitation to join a specific Class; a valid Pending invitation may reserve Class capacity until expiry/resolution.
- **Class Membership** — actual learner access to a Class.
- **Session** — lightweight scheduled occurrence of a Class.
- **Material** — learning resource shared with one or more Classes.
- **Class Post** — private Class update, announcement, or permitted learner question/discussion item. Never public Community content merely because participants share a Location.
- **Class Learner Conversation** — contextual private communication for one Class + Learner between the responsible teacher and authorized learner-side Accounts. This supports direct/offline Class invitations without fabricating Enquiry history and is not unrestricted platform DM.
- **Activity** — underlying assignment/practice/exercise concept.
- **Submission** — learner work for an Activity; meaningful revisions preserved.
- **Test** — structured assessment whose definition becomes immutable once valid attempts begin, except for governed answer-key correction.
- **Test Attempt** — one learner's protected attempt at a Test.

### Community and trust

- **Community Post** — Location-scoped public learning/community content.
- **Community Comment/Reaction** — controlled interactions; no public downvote model.
- **Verification** — exact verified claim attached to a teacher/Organization/profile.
- **Report** — request for review/moderation; not proof of wrongdoing.
- **Block** — contact/control relationship; not equivalent to Class removal.
- **Scoped Restriction** — explicit restriction of one capability/surface such as public discovery, new Enquiries, messaging, Class access, Community or Ads. Restrictions must not collapse unrelated capabilities into one giant status.

### Ads

- **Advertising Eligibility** — whether an Account/Organization may advertise.
- **Campaign** — advertiser's promotion initiative.
- **Campaign Target** — requested Location + Sponsored placement context before serving.
- **Campaign Revision** — exact immutable public ad content version being reviewed/shown.
- **Ad Review** — decision against a specific Campaign Revision.
- **Commercial Clearance** — whether the agreed commercial condition is satisfied.
- **Inventory Capacity** — sellable Sponsored capacity for Location × placement × time; physical implementation may use overlap-safe daily buckets.
- **Inventory Reservation** — temporary/confirmed claim by a Campaign against capacity.
- **Ad Placement** — per-Location serving state for a Campaign, pinned to an exact approved serving Revision.
- **Claim Evidence** — supporting material for claims requiring substantiation.
- **Ad Frequency State** — private operational control used to protect user experience; never advertiser-facing viewer history.
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
- Capability grants and scoped restrictions supplement relationship-based authorization; they do not replace Learner/Organization/Location relationships.

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
- Class **has** Sessions, Materials, Class Posts, Activities and Tests.
- A Class + Learner may have a contextual learner-side/teacher conversation governed by current authorization.
- Material may be shared with one or multiple Classes.
- Activity **has** learner Submissions.
- Test **has** learner Test Attempts.

### Community

- Community Post **belongs to** one Location.
- Community permissions derive from Account capabilities/policy, not a separate Community identity.

### Ads

- Eligible Account/Organization **creates** Campaign.
- Campaign **has requested Campaign Targets** for Location/placement.
- Campaign **has many** Campaign Revisions.
- Campaign Revision **receives** one or more Ad Reviews over time.
- Campaign **targets** Locations through Ad Placements after inventory is valid.
- Ad Placement **serves one exact approved Campaign Revision** at a time.
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

In V1 a valid Pending invitation reserves one finite Class seat until its finite expiry/resolution.

### Class Membership

**Active → Completed / Left / Transferred / Removed**

### Activity

**Draft → Open → Closed**

### Submission

Current status is **Submitted / Changes Requested / Reviewed**; revisions are historical versions rather than a large state machine.

### Test

**Draft → Available → Closed**

Upcoming is derived from start time. Result visibility is separate. Test definition locks once the first valid Attempt begins.

### Test Attempt

**In Progress → Submitted → Evaluated / Invalidated**

### Location

**Preparing → Live → Paused → Retired**

### Scoped Restriction

A restriction is applied to an explicit capability/surface and later may be lifted/expire. It must not silently become a platform-wide punishment unless the safety decision explicitly says so.

### Ads

Do not collapse Ads into one status. Separate:

- Advertiser eligibility
- Campaign existence
- Campaign Target
- Campaign Revision review
- Commercial Clearance
- Inventory Reservation
- per-Location Ad Placement

A Campaign may validly have an approved serving Revision, be commercially Cleared, be Live in Dhanbad, and Paused in Gomoh at the same time.

## Universal invariants

1. **Learner ownership** — learning history/artifacts belong to Learner, not merely the Account performing the action.
2. **Authorization-at-execution** — every consequential action re-checks current authority when executed.
3. **Idempotency** — repeated logical command must not perform the action twice.
4. **Capacity** — Class capacity and Ads inventory capacity may never be exceeded.
5. **Privacy** — browsing, Saving, or viewing Sponsored content does not create a relationship or expose identity.
6. **Class security** — possession of a Class/file URL never grants access.
7. **Location** — selected Location changes discovery/community context, not ownership of existing relationships.
8. **Discovery vs current learning** — provider availability affects new relationships, not existing Classes.
9. **Safety** — Report remains available independently of ordinary communication permissions; Block does not erase evidence; restrictions are explicitly scoped.
10. **Assessment integrity** — Test structure cannot be silently changed after valid Attempts start; answer-key correction is explicit and audited.
11. **Ads integrity** — paid Sponsored visibility cannot buy verification, endorsement, or organic ranking; live serving is pinned to an exact approved Revision.
12. **Ads privacy** — frequency/hide/view operational data is never exposed as named advertiser viewer data.
13. **Server authority** — current authoritative state wins over stale UI.
14. **No direct state mutation** — business state transitions occur through canonical commands, not arbitrary UI writes.
