# Raahi Learning V1 — Product + UI Behaviour Freeze

Status: **FROZEN for V1 unless a new scenario proves a contradiction.**

## Product identity

Working public name: **Raahi Learning**.

Positioning: local learning for people of any age, launched one Raahi Location at a time.

Raahi is not only a tutor marketplace and not a generic social network. It has three connected layers:

1. **Discovery & relationship formation** — find learning, post a Learning Request, Enquire.
2. **Private ongoing learning** — Classes, Materials, Activities, Tests, Sessions.
3. **Local learning community** — useful local discussion/events/support.

Raahi Ads is a separate governed commercial slice for clearly labeled educational Sponsored visibility.

## Public terminology

| Internal/business idea | User-facing language |
|---|---|
| Market/service area | **Location** |
| Market manager | **Local Manager** |
| Provider | Teacher / Coach / Instructor as context requires |
| Offering | **What I Teach** |
| Requirement | **Learning Request** |
| Inquiry | **Enquiry** |
| Classroom | **Class / My Classes** |
| Classroom Membership | hidden internal concept |
| Assignment engine | **Activity**, labeled Assignment / Practice / Exercise |
| Exam | Test / Quiz as context requires |
| Notice | Announcement / Important Announcement |
| Ad | **Sponsored** |

Removed from V1 user language: Enrollment, Market, Find Students, generic Verified Teacher, Book Class.

## Identity model

- One Raahi **Account** can learn, teach, manage a learner, and/or represent an Organization.
- A **Learner** is the person whose learning history belongs to them.
- Learner is not the same thing as login Account.
- A child may exist as a Learner without having a login.
- Parent/Guardian acts **for Rahul**, not by impersonating Rahul.
- V1 uses one managing Parent/Guardian per learner. Rich multi-guardian workflows are deferred.
- There is no Adult Learner entity, Minor Learner entity, or turning-18 lifecycle. Age may affect permissions/policy without recreating learning identity.

## Core discovery flow

Two valid entry paths:

### Browse path

**Explore → Teacher/Institute → What I Teach → Enquire → optional Trial → Class Invitation → Join Class**

### Learning Request path

**Post Learning Request → Teacher expresses interest → Pending Enquiry → engage → optional Trial → Class Invitation → Join Class**

Both converge into the same Enquiry system.

## Learning Request

Lifecycle: **Draft → Open → Closed**.

- One Learner + one meaningful learning need + one Location context.
- Material change (e.g. Maths → Guitar, Rahul → Ananya) creates a new Request.
- Minor preference edits can update the same Request.
- Closed may reopen if the underlying need is still meaningfully the same.
- Duplicate active Requests for the same need should be controlled.
- Public Request never exposes child photo, exact address, private phone/email, or a public learner profile.

## Enquiry

Lifecycle: **Pending → Active → Closed**.

- Pending means one side expressed interest but unrestricted conversation is not yet open.
- Active means permitted contextual communication can happen.
- Closed reasons may include declined, withdrawn, joined Class, no longer needed, inactivity.
- No unrestricted public Message button.
- Browsing or Saving never creates an Enquiry.

## Trial

Trial is optional and lives inside the Enquiry context as a scheduled/agreed event. It is not a mandatory gate or major relationship lifecycle.

## Class model

- One **Class** concept supports 1:1 and Group learning.
- “Batch” may be used naturally in names, but is not a separate business object.
- One responsible Teacher/Instructor per Class in V1.
- A Class is the private access/security boundary.
- Core capabilities: Updates, Materials, Announcements, Sessions, Questions/Discussion where allowed, Activities, Tests.
- No built-in attendance system in V1.
- No generic progress percentage.

Class lifecycle: **Draft → Active → Past**.

## Class Invitation

Lifecycle: **Pending → Accepted / Declined / Expired / Cancelled**.

Invitation is a real business object because it may reserve capacity and must survive stale/double-action scenarios.

Accepting a valid invitation creates Class Membership.

## Class Membership

Lifecycle: **Active → Completed / Left / Transferred / Removed**.

- Invitation is not Membership.
- There is no separate Enrollment object in V1.
- Transfer can move a learner from Saturday Class to Sunday Class without recreating their learning identity/history.
- Historical access depends on end reason and policy.
- Forwarding a Class URL never grants access.

## Activities and submissions

Assignment, Practice and Exercise share one underlying **Activity** concept.

Activity lifecycle: **Draft → Open → Closed**.

A due date is a property, not a lifecycle state.

Submission visible states: **Submitted / Changes Requested / Reviewed** with meaningful previous revisions preserved.

Parent may assist a young learner operationally (for example upload a photo), but the Submission remains the learner's work.

## Tests

Test lifecycle: **Draft → Available → Closed**.

Upcoming can be derived from availability time; result visibility is separate.

Attempt lifecycle: **In Progress → Submitted → Evaluated / Invalidated**.

- Refresh/multiple tabs resume the same logical attempt.
- Double submit must not create duplicate outcomes.
- No public leaderboard.

## Parent and student experience

- Same application; permissions determine available surfaces.
- No separate Guardian application and no separate minor application.
- Parent can see learner context (Mine / Rahul / Ananya where relevant).
- Parent cannot impersonate learner to take Tests.
- Student learning-focused navigation may be: Home · My Classes · Practice · Tests · Notifications.
- Student/learner safety reporting must remain accessible independently of ordinary marketplace permissions.

## Location model

Location lifecycle: **Preparing → Live → Paused → Retired**.

Selected Location controls new Home/Explore/Community discovery context.

Changing Location must **not** remove or hide existing:

- My Classes
- Enquiries
- Saved items
- Messages
- learning history

A teacher can serve multiple Locations under one identity. Public discovery availability is separate from existing Classes.

## Community

- Local Location-based Community only in V1.
- No global community.
- Purpose: learning questions, resources, educational events, useful local support.
- No public downvotes.
- No generic engagement-growth mechanics.
- Private Class content never leaks into Community.

## Trust and safety

- No public learner directory.
- No public star ratings/reviews in V1.
- Verification badges must state exact claims (Identity verified, Qualification verified, etc.).
- Payment cannot buy verification or endorsement.
- Public personal phone/email/home address are protected by default.
- Blocking is not the same action as Leaving a Class.
- Report does not prove guilt.
- Serious safety cases may cause immediate precautionary restriction with audit/escalation.

## V1 navigation reference

### General adult/parent
Home · Explore · My Classes · Community · Messages

### Teacher
Home · Teaching Opportunities · My Classes · Community · Messages

### Student learning-focused
Home · My Classes · Practice · Tests · Notifications

### Local Manager
Overview · People · Learning · Community · Reports · Location Settings

Profile/settings/role capabilities may live under avatar/menu.

## Explicitly removed/deferred complexity

Removed for V1:

- separate Enrollment object
- Batch entity
- Adult vs Minor learner entities
- turning-18 lifecycle
- major Trial lifecycle
- separate Assignment and Practice systems
- attendance
- artificial overall progress %
- public star ratings/reviews
- public learner profiles/directory
- generic global Community
- multi-teacher Class
- institute ERP/payroll
- platform tuition-payment collection

Deferred unless real demand proves the need:

- rich multi-guardian permissions
- complex enterprise organization approval flows
- built-in live video
- certificates/gamification/leaderboards
- advanced CRM for advertisers/institutions
