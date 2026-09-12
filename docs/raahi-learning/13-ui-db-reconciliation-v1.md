# Raahi Learning V1 — UI Prototype ↔ Database Reconciliation

Status: **PASSED WITH BINDING CORRECTIONS. Supabase remains untouched.**

Purpose: prove that the frozen UI behavior and the physical database/command design describe the same product before any database implementation begins.

This review audits in both directions:

1. **UI → DB:** every approved screen/action/state must be supported by authorized data, one canonical command where a business transition occurs, and correct stale/idempotent behavior.
2. **DB → UI/Product:** every significant table/state/command must have a real V1 purpose and must not reintroduce removed complexity.

Generated images remain style/layout references only. Written frozen behavior wins when an image contains drift.

---

# 1. Reconciliation outcome

The core model survives the UI challenge. No reason was found to reintroduce:

- Enrollment;
- Batch as a domain entity;
- Adult/Minor Learner entities;
- turning-18 migration;
- Trial as a relationship layer;
- Attendance;
- generic Progress %;
- public star ratings/reviews;
- public Learner directory;
- global Community;
- advertiser CRM/viewer lists;
- platform tuition payments.

However, the UI audit exposed several real gaps/ambiguities that must be treated as binding corrections before/later migrations are written.

## Binding corrections discovered

1. **Selected Location preference** must live in `account_location_preferences`, not as an early FK on `accounts`.
2. **Location launch interest / Register Interest** is a real V1 UI flow and needs persistence + commands.
3. **Marketplace decision authority** must be derived without an Adult/Minor entity: when a Learner has an active `manage` relationship, the manager owns marketplace/formal relationship decisions; otherwise active `self` access may act for self. Self-access still owns appropriate learning actions such as Submission/Test and safety reporting.
4. **Organization public logo/avatar** must be supported.
5. **Activity resources/attachments** need an explicit reusable link to Materials.
6. **Reports** need optional Learner context so a parent/student can report a concern about a specific learning relationship without putting that context only in free text.
7. **Class completion** must be one governed business transition, not a UI sequence that can leave a Past Class with unintended Active Memberships.
8. **Historical Class access** needs a deterministic V1 rule rather than an undefined per-Class policy.
9. **Class Learner Thread status** is redundant with Membership/restriction state and should not become an independent lifecycle users cannot control.
10. **Session “Completed”** need not be a stored business state in V1; past is derived from time because Attendance is not modeled.
11. **Ads eligibility must be surface-based rather than age-state-based.** Raahi does not need an Adult/Minor product split to serve educational Sponsored content. General Home/Explore/Community may contain governed educational Sponsored content; private learning surfaces remain ad-free.
12. **Existing offline learner onboarding** must not fabricate an Enquiry. V1 requires the Learner to exist in Raahi before the teacher sends a normal Class Invitation. A future one-time share-code/link helper may improve onboarding but is not required to model the learning relationship.
13. `accounts.auth_user_id` must be nullable after account closure as already decided in the SQL migration plan.

These corrections do not change the product's core journey; they make the physical design accurately support it.

---

# 2. Identity / onboarding — PASS WITH AUTHORITY CLARIFICATION

## Approved UI

One Account may:

- learn;
- manage one or more Learners;
- teach;
- represent an Organization.

A Learner may exist without a login. A Learner may later receive self-access without recreating history.

## DB support

- `accounts`
- `learners`
- `account_learner_access`
- `account_capabilities`
- `organization_members` + member capabilities

## Binding authority rule

Raahi does not need date-of-birth-driven product identities to distinguish learning actions from formal marketplace decisions.

For a Learner:

- if an active `manage` relationship exists, **formal marketplace/relationship decisions are manager-owned** in V1 (post/close Request, learner-side Enquiry decisions, accept/decline Class Invitation, voluntary Leave/Transfer decisions where learner-side consent is required);
- if no active manager exists, active `self` access may make those decisions;
- active `self` access may still perform permitted learning actions such as Class participation, Submissions, Tests and safety Reports even when a manager exists;
- manager access does not grant Test-taking impersonation.

This preserves guardian-led learning management where configured without introducing Minor/Adult entities or an automatic turning-18 workflow.

Required helper/command concept: `can_make_learning_decision(learner_id)` in addition to `can_act_for_learner` / `has_learner_self_access`.

## Prototype corrections

Do not implement mutually exclusive “Student account / Parent account / Teacher account” identities. Onboarding choices are personalization/capability setup only.

---

# 3. Location selection and launch — GAP RESOLVED

## Approved UI

- choose/change Location;
- Home/Explore/Community change with selected Location;
- Classes, Enquiries, Saved items, Messages and history remain;
- unavailable/preparing Location shows **Raahi isn't available here yet → Register Interest**;
- user may express `learn` and/or `teach` interest;
- interest never auto-publishes a Teaching Option or Learning Request when the Location launches;
- Local Manager/Platform can use aggregate demand/supply signals for launch readiness.

## Existing DB support

`locations` already supports `preparing | live | paused | retired`.

## Required persistence

Add:

### `account_location_preferences`

- `account_id pk/fk accounts`
- `selected_location_id fk locations`
- `updated_at`

This is preference only.

### `location_interests`

- `id uuid pk`
- `location_id uuid fk locations`
- `account_id uuid fk accounts`
- `intent_type text` — `learn | teach`
- `state text` — `active | withdrawn`
- `created_at`, `updated_at`
- one active row per `(location_id, account_id, intent_type)`

V1 `Register Interest` requires authentication; it is not an anonymous marketing-contact database.

Canonical commands:

- `set_selected_location`
- `register_location_interest`
- `withdraw_location_interest`
- governed `change_location_state` / launch command for Platform authority

Read projections may expose aggregate readiness counts to authorized Local/Platform managers without turning waitlist interest into a public user directory.

---

# 4. Learner self-discovery — PASS

UI:

**Home/Explore → search → Teacher/Institute → What I Teach → Save/Enquire → optional Trial → Class Invitation → Join → My Classes**

DB mapping:

- public discovery → Teacher Profile / Organization / Teaching Option + Location junction;
- Save → private Saved tables;
- Enquire → `enquiries`;
- Trial → `enquiry_trial_events`;
- Join → Class Invitation + Membership.

Rules confirmed:

- profile view creates no relationship;
- Save creates no contact permission and provider cannot see who Saved;
- no public Message CTA bypassing Enquiry;
- no Enrollment record hidden behind Join;
- current availability is revalidated by command when an action is taken.

Prototype drift to remove: stars/ratings, Book Class, Enrollment.

---

# 5. Parent/guardian flow — PASS

UI:

**Explore/Post Request → For Rahul → Enquire → optional Trial → Invitation → Join Rahul → oversee learning**

DB mapping:

- acting Account comes from auth;
- learning ownership uses `learner_id`;
- authority uses `account_learner_access`;
- `my_classes_v`/private projections include learner context;
- Submission records Learner owner separately from performer Account.

Sibling isolation is preserved because Rahul and Ananya have separate Learner IDs even when the same Account manages both.

Parent oversight does not grant Start/Submit Test authority.

---

# 6. Learning Request / Teaching Opportunities — PASS

UI:

**Create Request → Open → provider expresses interest → Pending Enquiry → Active Enquiry → Close/Reopen**

DB mapping:

- `learning_requests`
- sanitized `public_learning_requests_v`
- `express_interest_in_request` → Pending Enquiry

Rules confirmed:

- public projection never exposes child photo/contact/exact address/public Learner profile;
- material edit to learner/need requires new Request;
- duplicate Open Requests controlled semantically;
- closing Request blocks new interest but does not close existing Enquiries;
- teacher opportunities are a query/projection, not another entity.

---

# 7. Teacher / Organization discovery — PASS WITH PUBLIC ASSET CORRECTION

UI supports:

- Teacher public profile;
- Organization public profile;
- one or more What I Teach items;
- per-item availability;
- multiple Locations;
- exact Verification badges.

DB supports individual-vs-Organization ownership with XOR Teaching Option owner and scoped Organization capabilities.

## Required public Organization asset

Add Organization profile logo/avatar fields, e.g.:

- `logo_type text` — `builtin | upload | none`
- `logo_ref text null`

or an equivalent public-profile asset reference implemented consistently with public storage.

This is presentation data, not a new domain lifecycle.

---

# 8. Class Invitation / Join — PASS

The prototype Join flow maps cleanly to:

- `class_invitations` Pending row = finite reserved seat;
- finite `expires_at`;
- atomic `accept_class_invitation`;
- exactly one Active Membership;
- current server state wins on stale/double action.

Last-seat races are transactionally protected by Class-row serialization.

A copied **Class URL** never grants access.

## Existing offline learner rule

Do not fabricate an Enquiry simply because a teacher already knows the student offline.

For V1, a normal Class Invitation requires an existing Raahi Learner record. The parent/student can join Raahi/create the Learner first, then the teacher can send the Invitation through a consented/direct connection path. A one-time share-code/link helper can be added later without changing Invitation/Membership semantics.

No public Learner search directory is introduced.

---

# 9. My Classes / private Class — PASS WITH HISTORY RULE

UI:

**My Classes → Class feed → Announcement/Question → Material → Session → Activity → Test → contextual Class/Learner messages**

DB support:

- Membership = access boundary;
- `class_posts` and comments = feed/announcement/question;
- `materials` + Class links;
- Sessions;
- Activities/Submissions;
- Tests/Attempts;
- `class_learner_threads/messages` for contextual private communication independent of Enquiry history.

This correctly supports learners who joined from an existing offline relationship.

## Deterministic historical access rule for V1

Avoid a configurable per-Class history-policy subsystem.

- `Active`: normal Class access subject to restrictions.
- `Completed`: read-only access to appropriate Class history/materials + own artifacts/results.
- `Transferred`: read-only access to appropriate source-Class history + own artifacts/results.
- `Left`: ongoing Class feed/material access ends; learner retains own Submission/Test/result/history records where appropriate.
- `Removed`: Class-private access ends; legitimate own/safety/audit records remain according to policy.

Safety restriction may override ordinary historical access immediately.

This rule should be implemented in Class read helpers/RLS, not as another membership lifecycle.

---

# 10. Class contextual messaging — PASS WITH STATE SIMPLIFICATION

`class_learner_threads` is needed because Class communication must work even without a marketplace Enquiry.

However, an independent `thread.status = active|closed` creates redundant state with no separate approved user action.

**Correction:** thread existence is enough. Read/write eligibility is derived from:

- current Membership/end-state historical policy;
- current learner-side authority;
- responsible Teacher authority;
- scoped messaging/Class restrictions.

Remove/defer independent Thread status/closed_at unless a future real scenario proves a separate thread lifecycle is needed.

If a managing Parent exists, the Class/Learner thread audience includes the permitted manager; do not create a hidden unrestricted teacher↔managed-learner DM.

---

# 11. Sessions — PASS WITH STATE SIMPLIFICATION

V1 has no Attendance system.

Therefore Session needs:

- scheduled date/time;
- delivery/location details;
- cancellation/reschedule information.

A separate stored `completed` state is unnecessary; “Past” can be derived from time.

Recommended physical representation: scheduled fields + nullable cancellation fields rather than `scheduled|cancelled|completed` lifecycle.

---

# 12. Activity / Submission — GAP RESOLVED

Core flow already maps correctly:

**Open Activity → optional submission → Submitted → Changes Requested → resubmit → Reviewed**

- no Submission row for an Activity that does not require one;
- one logical Submission per Learner/Activity;
- revisions preserve history;
- performer Account may be parent while learner owns work;
- retries do not duplicate logical revision.

## Missing Activity resource support

The approved UI allows a teacher to attach/use learning resources with an Activity.

Add:

### `activity_material_links`

- `activity_id fk activities`
- `material_id fk materials`
- unique pair

Command must ensure the Material is authorized for the Activity's Class (or atomically share it to that Class according to teacher intent).

Do not create a separate Assignment-file model.

---

# 13. Tests — PASS

UI:

**Upcoming → Available → Start → save → Submit → Results when visible**

DB/command model supports:

- Upcoming derived from time;
- Test definition lock at first valid Attempt;
- one logical Attempt per Learner/Test V1;
- refresh/retry resumes existing Attempt;
- parent management cannot impersonate test-taking;
- result visibility is independent from closure;
- audited post-lock answer-key correction recalculates safely.

No leaderboard/progress entity required.

---

# 14. Transfer / Leave / Remove / Complete — PASS WITH COMMAND CORRECTION

Transfer remains atomic and needs no Enrollment object.

## Class completion correction

The UI should expose a single intentional course/Class completion action, not require the teacher to complete Memberships manually and then separately mark the Class Past.

Canonical command should be **`complete_class`**:

- lock Class;
- verify Class can complete;
- transition eligible Active Memberships to `completed` in the same transaction (or require explicit resolution for any exceptional Membership that cannot complete);
- transition Class to `past`;
- close/lock further normal learning writes according to policy;
- notify after commit.

Remove/avoid a free-standing `mark_class_past` path that can create a Past Class with unintended Active Memberships.

Leave/Remove/Transfer remain separate business actions.

Block remains separate from Leave/Remove.

---

# 15. Location switching — PASS

`account_location_preferences` changes discovery context only.

Every My Classes/Enquiry/Saved/Message query is authorization/relationship based and must never filter established relationships solely by selected Location.

Location `paused` affects new local discovery/Community/Ads according to policy and does not automatically destroy existing private Classes.

---

# 16. Community — PASS

UI maps to:

- `community_posts`
- comments;
- positive/contextual reactions;
- Report/moderation.

No public downvote, no global Community and no Class-content leakage.

Posting eligibility is capability/policy/Location based rather than an Adult/Minor entity.

---

# 17. Reports / Safety / Verification — PASS WITH LEARNER CONTEXT CORRECTION

Generic Report targeting is useful, but parent/student safety flows need optional learning context.

Add to `reports`:

- `context_learner_id uuid null fk learners`

The Report command verifies the reporter may legitimately reference that Learner (self/manage/safety path). This enables “I am reporting a concern involving Rahul in this Class/teacher context” without encoding child identity only in free text.

Report still does not mutate the target or prove guilt.

Exact Verification claims map cleanly to `verification_claims`.

Scoped Restrictions correctly avoid a giant all-purpose suspended Account state.

---

# 18. Organization — PASS

One Organization identity supports:

- public profile;
- authorized members/capabilities;
- Teaching Options;
- Classes;
- Ads.

Campaigns and Classes survive employee/member removal because the Organization/domain objects own the relationship, not the employee who clicked Create.

No payroll/ERP/branch-accounting subsystem is introduced.

---

# 19. Local Manager — PASS

Location assignment provides the authority scope for:

- Community moderation;
- local public learning issues;
- permitted Ads review;
- launch/readiness views;
- Reports.

Local Manager must not gain broad private Class/Submission/Test reads.

Launch readiness is a projection over real local data such as:

- Teaching Options;
- Location Interests;
- Learning Requests;
- Community readiness;
- unresolved local Reports.

No separate “readiness score entity” is required.

---

# 20. Raahi Ads — advertiser — PASS

UI:

**objective → Locations/placement → date/inventory/package context → creative → Revision → evidence/review → Commercial Clearance → reservation → placement → analytics**

DB supports:

- Campaign targets before serving;
- immutable Revisions;
- exact Review;
- Claim Evidence;
- Commercial Clearance independent of Review;
- overlap-safe daily inventory buckets;
- atomic multi-day reservation;
- per-Location Placements;
- exact `serving_revision_id`;
- aggregate metrics.

No auctions/CPC/CPM/wallet/CRM required.

Package/rate presentation may initially be governed configuration plus commercial snapshot (`package_code`, agreed amount, rate-card code). Do not invent a billing suite merely because a prototype shows a payment-looking card.

If self-service rate-card administration becomes a real requirement later, add a small configuration model then.

---

# 21. Raahi Ads — viewer — PASS WITH SURFACE RULE CLARIFICATION

The product no longer needs age-state logic merely to decide whether educational Sponsored content can render.

V1 rule:

### Sponsored allowed only on governed general discovery/community surfaces

Examples:

- Home;
- Explore;
- selected Local Community educational/event placements.

### Sponsored prohibited on private learning surfaces

- My Classes;
- individual Class;
- Class Materials/feed;
- Activities;
- Tests;
- private Enquiry/Class messages;
- Notifications as paid placement.

This is **surface-based**, not “turn 18 and start seeing Ads”.

Ads remain education-relevant, contextual/broad and cannot target using protected child/private learning behavior.

Viewer flow maps to Open / Enquire / external destination / Hide / Report.

- view/open does not expose identity;
- Enquire reuses normal Enquiry with Sponsored attribution;
- Hide + frequency state remain private;
- Save, where offered, saves the underlying Organization/Teaching Option rather than requiring `saved_campaigns`.

---

# 22. Ads admin/review — PASS

Exact-revision review and serving eliminate stale-review drift.

Local Manager review is Location-scoped and conflict checked; Platform authority handles cross-Location/escalated campaigns.

Pause reason remains because policy/safety/Raahi-operational/commercial causes have different consequences.

Commercial Clearance cannot force rejected content Live; approval cannot force uncleared inventory Live.

---

# 23. Reverse DB → UI/product audit

The following significant technical concepts all have a real V1 purpose:

| DB concept | Product/UI justification | Keep? |
|---|---|---|
| Account | authenticated actor | KEEP |
| Learner | learning owner independent of login | KEEP |
| Account↔Learner Access | self/manager authority | KEEP |
| Account Capabilities | teaching/admin/safety capability without fixed role | KEEP |
| Organization + member capability | institute/university ownership | KEEP |
| Location + staff assignment | local-first operation | KEEP |
| Scoped Restriction | precise safety/action restriction | KEEP |
| Teacher Profile / Teaching Option | discovery | KEEP |
| Saved relations | private bookmark UI | KEEP |
| Learning Request | learner broadcasts need safely | KEEP |
| Enquiry + messages | controlled relationship formation | KEEP |
| Trial Event | optional scheduling inside Enquiry | KEEP lightweight |
| Class | private learning boundary | KEEP |
| Invitation | finite join opportunity/capacity reservation | KEEP |
| Membership | actual Class access | KEEP |
| Session | schedule occurrence | KEEP lightweight |
| Material | reusable Class resource | KEEP |
| Class Posts/Comments | announcements/questions/feed | KEEP |
| Class Learner Thread/Messages | contextual private communication without fake Enquiry | KEEP, remove independent thread lifecycle |
| Activity | Assignment/Practice/Exercise engine | KEEP |
| Submission + revisions | learner work/history | KEEP |
| Test/Questions/Choices/Attempt | assessment integrity | KEEP |
| Community tables | local forum | KEEP |
| Verification | exact trust claim | KEEP |
| Report | moderation request | KEEP |
| Block | contact control separate from Class | KEEP |
| Access Restriction | safety enforcement | KEEP |
| Ads Eligibility/Campaign/Revision/Review | governed Sponsored content | KEEP |
| Commercial Clearance | money/commercial condition separate from approval | KEEP |
| Ads daily inventory/reservations | finite scalable inventory | KEEP |
| Placement | per-Location serving reality | KEEP |
| Hide/Frequency | user experience protection/privacy | KEEP |
| Aggregate Ads metrics | advertiser reporting without viewer lists | KEEP |
| Idempotency | retry safety | KEEP internal |
| Audit | significant action evidence | KEEP internal |
| Notifications | derived user alerts | KEEP |
| Location Interest | unavailable-location launch signal | **ADD** |
| Activity↔Material link | Activity attachment/resource UI | **ADD** |

No table was found that requires bringing back Enrollment, Batch, Attendance, Adult/Minor identities, generic Progress, public ratings or advertiser viewers.

---

# 24. Prototype drift rejected

Do **not** implement these even if they appear in generated images:

- star ratings / review counts;
- Enrollment / Offer Enrollment / Accept Enrollment;
- Book Class ticketing semantics;
- Adult vs Minor product accounts;
- turning-18 account migration;
- generic progress/attendance percentages;
- global Community;
- public learner directory/photos;
- generic “Verified Teacher” badge;
- old “Market” terminology;
- paid notification placements;
- wallet/payment-led Ads architecture;
- Ads changing organic rank.

---

# 25. Required technical deltas before implementation

Treat the following as authoritative overrides to `03-database-blueprint-v1.1.md` / `10-sql-migration-plan-v1.1.md` until those files are consolidated into a later revision:

1. `accounts.auth_user_id` nullable after credential/account closure according to retention policy.
2. Remove `accounts.selected_location_id`; use `account_location_preferences` after Locations.
3. Add `location_interests` and commands/indexes.
4. Add Organization public logo/avatar reference.
5. Add `can_make_learning_decision(learner_id)` authorization rule/helper.
6. Add deterministic historical Membership read policy by end state.
7. Remove/defer independent `class_learner_threads.status/closed_at`.
8. Simplify Session completion to derived-by-time; store cancellation explicitly.
9. Add `activity_material_links`.
10. Add `reports.context_learner_id`.
11. Replace split `complete_membership` + free `mark_class_past` UX with governed `complete_class` command semantics.
12. Ads eligibility is governed by UI surface + policy, not an Adult/Minor identity or turning-18 event.

These are implementation-contract changes, not optional notes.

---

# 26. Exit result

UI → DB: **PASS WITH CORRECTIONS ABOVE**.

DB → UI/Product: **PASS; no removed major complexity has re-entered.**

The physical/SQL plan may proceed only if the corrections in section 25 are incorporated into implementation/migrations.

Supabase remains untouched at this point.