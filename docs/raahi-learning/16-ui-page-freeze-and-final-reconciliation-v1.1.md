# Raahi Learning V1.1 — Inspected UI Page Freeze + Final UI↔DB Reconciliation

Status: **PASSED. UI pages inspected and frozen for V1.1. Supabase remains untouched.**

This gate supersedes the earlier image-only reconciliation as the final pre-database UI validation. A real backend-free clickable prototype was built from the frozen product rules, inspected on mobile and desktop, challenged through deterministic edge states, and then reconciled against the current database/command design.

## Prototype artifact

Canonical artifact name: `Raahi_Learning_Clickable_UI_v1.1.zip`

Persistent Library path: `/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`

SHA-256: `2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

A lightweight GitHub prototype branch also exists for handover context: `raahi-learning-ui-v1`. The zipped artifact is the exact inspected build and includes the UI code, audit scripts, audit results and screenshots.

## Inspection coverage

The inspected prototype contains **77 canonical routes/pages** spanning:

- Welcome/OTP/first-use intent/profile/avatar/learner contexts;
- Home/Explore/Teacher/Institute/What-I-Teach/Saved;
- Learning Request create/edit/view/close/reopen;
- Enquiry compose/conversation and optional Trial;
- Class Invitation/Join success/My Classes;
- protected Class feed, Class post, Materials, Sessions, learner-specific Class messaging;
- Transfer/Leave/Block/Report/Past Class;
- Activity/Submission feedback/Test upcoming/available/submitted/results;
- Teacher profile, teaching options, opportunities, Classes, members, Activities, Tests and Materials;
- Institute profile, learning and member capabilities;
- Local Community and Community post/report flows;
- Local Manager overview/people/learning/reports/location/Ads review;
- Platform safety/verification/Ads operations/audit;
- Advertiser eligibility, Campaign create, inventory, creative Revision, Campaign state, analytics and Sponsored detail.

Automated checks at the final freeze:

- **154 canonical route/viewport checks** (77 routes × desktop/mobile): 0 issues;
- **32 privileged deep-link checks**: 0 unguarded pages;
- **26 interaction/business-rule checks**: 0 failures;
- **15 semantic/accessibility sanity samples**: 0 issues.

Representative privileged mobile pages and the wrong-workspace deep-link state were also visually inspected.

## UI behavior now frozen

### Identity / workspace

- One Account may learn, teach, manage a Learner and represent an Organization.
- First-use intent selects the first workspace only; it is not a permanent account role.
- The prototype workspace selector is an inspection control, not production authorization.
- Privileged deep links render **Switch workspace** rather than privileged data when opened under the wrong prototype workspace.
- Production authorization must still re-check Account + acting-for + capability/relationship + Organization/Location scope.

### Learner / parent

- Parent/Guardian acts **for** the Learner; learning ownership remains with the Learner.
- A managed Learner may later receive self-access without creating a new Learner identity/history.
- There is no public Learner directory.
- Existing offline learners use a short-lived private learner-share code when a teacher/institute needs to target a Class Invitation without an Enquiry.
- Marketplace relationship actions are controlled; browsing/saving never grants messaging permission.

### Discovery / relationship

- Browse → What I Teach → Send Enquiry → contextual Enquiry.
- Learning Request and direct discovery converge into the same Enquiry model.
- Trial is optional and stays inside Enquiry context.
- A valid Pending Class Invitation already reserves its finite seat.
- Accepting a valid Invitation creates Class Membership and leads directly to Class access; there is no extra join stage.

### Ongoing learning

- Membership is the Class access boundary.
- Class-private materials re-check current authorization; a copied path/URL is not access.
- Class feed, Materials, Sessions, Activities, Tests and learner-specific Class messaging are separate inspectable surfaces.
- Activity revisions preserve prior work; failed network submission does not display Submitted.
- Parent can assist operationally with a learner Submission while the Learner remains the work owner.
- Parent may oversee a Test but management authority does not grant Test-taking impersonation.
- Upcoming Test is derived from availability time.
- No Attendance subsystem or invented overall progress score exists.

### Teacher / institute

- A Teacher has a real Class-management view distinct from the learner Class view.
- Class members are visible only inside the Class context; this is not a public learner directory.
- Generic offline learner invitation uses a private learner code, not name search.
- Pending Invitations reserve seats at send time.
- Teacher Activity/Test/Material authoring is inspectable.
- Organization members receive scoped capabilities; Organization-owned Classes/Campaigns survive employee access changes.

### Location / local operations

- The inspected UI distinguishes `interest_only` (not available yet) from `preparing` and `live`.
- `interest_only` and `preparing` support Register Interest but not normal live discovery/community behavior.
- Changing selected Location affects discovery/community context only; it does not hide existing Classes/Enquiries/Saved/history.
- Local Manager pages expose public/local operational data, not casual private Class/Submissions/Tests/Messages.

### Community / safety

- Community is Location-based and purpose-limited.
- Reactions are positive/contextual; no public downvote model.
- Community report creates a request for review, not automatic guilt/punishment.
- Block is separate from Leave Class.
- Safety reporting remains available independent of normal marketplace permissions.

### Raahi Ads

- Sponsored is clearly labeled.
- Viewer identity remains private on view/open/hide; deliberate Enquiry starts normal controlled contact.
- Sponsored is surface-governed and excluded from My Classes, Class, Activity, Test and private Messages.
- Review, Commercial Clearance and inventory remain independent conditions.
- Serving is pinned to an exact approved Campaign Revision.
- Ads analytics remain aggregate; there is no named viewer/lead directory.

## Final DB gaps found by the real pages

The clickable UI proved six additional technical requirements beyond `14-ui-db-implementation-delta-v1.md`:

1. `locations.state` needs `interest_only` before `preparing`.
2. secure one-time `learner_share_codes` are required to support existing offline learner invitation without a public directory or fake Enquiry history.
3. `class_invitations` needs optional `fee_display_text` snapshot because Join displays the terms actually offered; this remains informational and does not create tuition payments.
4. `test_attempts` needs optional `teacher_feedback` because released Test Results show a teacher note.
5. Settings requires canonical guarded Account pause/resume/closure commands; closure must fail while unresolved learner-management/sole responsibilities remain.
6. page/route authorization must explicitly enforce capability/scope on every privileged read; workspace navigation itself is never authority.

These changes are specified in `17-final-ui-db-implementation-delta-v1.1.md`.

## Concepts still rejected after real-page inspection

The inspected UI provides no reason to restore:

- separate Enrollment;
- Batch entity;
- Adult/Minor Learner entities;
- turning-18 migration;
- Attendance;
- generic progress percentage;
- public ratings/reviews;
- public Learner directory;
- unrestricted DM;
- advertiser viewer CRM;
- platform tuition-payment collection.

## Exit result

The UI-first build/review gate is now **closed successfully**.

The final implementation contract is the frozen Product/Domain/Architecture documents plus:

- `10-sql-migration-plan-v1.1.md`;
- `14-ui-db-implementation-delta-v1.md`;
- `16-ui-page-freeze-and-final-reconciliation-v1.1.md`;
- `17-final-ui-db-implementation-delta-v1.1.md`.

Only after these are read together may Supabase implementation begin, and implementation still proceeds slice-by-slice starting with Foundation + Identity.
