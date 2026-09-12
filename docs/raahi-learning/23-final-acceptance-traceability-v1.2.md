# Raahi Learning V1.2 — Final Acceptance / UI / Data Traceability

Status: **FINAL PRE-SUPABASE TRACEABILITY MATRIX.**

Purpose: prove that every major inspected UI journey has a data owner, secure read path, canonical write path, and explicit regression target before implementation begins.

This is not a replacement for detailed Given/When/Then tests in `05-acceptance-regression-v1.md`; it is the cross-layer map used during implementation reviews.

| UI / Journey | Primary data / projection | Canonical writes | Critical acceptance / invariant |
|---|---|---|---|
| Welcome / OTP / first-use intent | Account/auth projection | account bootstrap/profile preference | onboarding intent never becomes permanent role |
| Learner management | Learner + Account↔Learner access | create learner, grant/end self access, controlled management transfer | learner history survives account/operator changes; siblings isolated |
| Settings / Take a break / Delete account | Account lifecycle + blocker projection | pause, resume, request closure | pause does not destroy Classes; closure cannot strand responsibility |
| Location picker | Live/available Location projection + selected preference | set selected Location | selected Location changes discovery context only |
| Register Interest | Location + Location Interest | register/withdraw interest | interest does not auto-create Request/Teaching Option |
| Home / Explore | public Teacher/Org/Teaching Option + optional Sponsored projection | Save/Enquire only after explicit action | organic rank separate from Sponsored; no public Learner directory |
| Teacher profile / What I Teach | public Teacher/Teaching Option/verification projections | Save, Send Enquiry | exact verification only; no public ratings/reviews |
| Organization profile | public Organization/Teaching Options | Save, Send Enquiry | Organization authority separate from employee account ownership |
| Learning Request create/edit/view | Learner-authorized Request + sanitized public projection | post/update/close/reopen | manager owns formal decision when active; public view hides learner private identity |
| Teaching Opportunities | sanitized Open Requests | express interest | teacher receives no unrestricted learner search/contact |
| Enquiry Pending | Enquiry projection | engage/decline | ordinary messaging not open while Pending |
| Enquiry Active | Enquiry + messages | send contextual message, schedule Trial, close | contextual relationship only; no global DM |
| Trial | Enquiry Trial Event | propose/schedule/cancel | optional; no Trial relationship entity required |
| Class Invitation | Invitation + reserved-seat snapshot | send/decline/cancel/expire/accept | seat reserved at send time; fee snapshot immutable while Pending |
| Invite existing offline learner | private share-code resolver + Invitation | create/revoke code; send invite with code | no public Learner directory; one-time code consumed atomically with invite |
| Join success | Invitation + Membership | accept Invitation | exactly one Membership; retry safe |
| My Classes | `my_classes` projection grouped by Learner | none/limited navigation actions | changing Location never hides active Classes |
| Class learner view | Membership-authorized Class projection | class post/comment where permitted, leave/transfer request | URL possession alone never grants access |
| Teacher Class management | responsible Teacher/Org Class projection | schedule/invite/remove/complete/author learning | Teacher member list exists only inside Class context |
| Sessions | Class Session projection | schedule/reschedule/cancel | no Attendance subsystem; past derived from time |
| Materials | Class-authorized Material projection | add/share/unshare Material | copied storage URL does not grant access |
| Activity | Activity + linked Materials | publish/close | one Activity model covers Assignment/Practice/Exercise |
| Submission | learner-owned Submission/Revisions | submit/resubmit; teacher request changes/review | performer may be parent, owner remains Learner; failed retry not shown as Submitted |
| Test Upcoming | Test with availability timing | none | Upcoming derived from time, not separate stored lifecycle |
| Test Available/In Progress | Test + Attempt | start, save answer, submit | first Attempt locks definition; self-access required; one Attempt |
| Test Results | Attempt/result projection | evaluate/correct result/feedback; show results | manager may oversee but not take Test; feedback private |
| Transfer / Leave | Membership + destination Class | transfer, leave | Transfer atomic; Leave distinct from Block |
| Past Class | Membership historical projection | none except allowed history actions | end-state-specific historical access is deterministic |
| Report concern | Report + optional Learner context | report subject | reporting remains available independent of ordinary messaging; report ≠ guilt |
| Block | private Block relation | block/unblock if supported | block does not erase history/evidence or automatically end Class |
| Community feed | Location Community projection | publish/comment/react/report | Location-based; no public downvote; moderation scoped |
| Local Manager | Location-scoped public/local ops projections | moderation, local review/restriction actions | cannot casually read private Class/Submissions/Tests/Messages |
| Platform Safety / Verification | moderation-private projections | restriction/report/verification decisions | explicit capability + audit; no generic status shortcut |
| Advertiser eligibility | eligibility projection | request/enable/restrict advertising | Ads eligibility separate from teaching trust/verification |
| Campaign create/target | Campaign + target projection | create/update targets | only eligible live sale contexts; no behavioral microtargeting |
| Creative revision | exact Campaign Revision | submit revision | submitted creative immutable; edit creates new Revision |
| Ad review | Review + exact Revision + evidence | request evidence, approve/reject/change request | reviewer scope/conflict checked; never approve “latest” implicitly |
| Commercial clearance | Commercial Clearance | confirm/revoke | payment/waiver never overrides policy review |
| Ad inventory | daily inventory + reservation | reserve/confirm/release | deterministic daily locking; no oversell; request atomic across dates |
| Ad placement | Placement + exact serving Revision | set serving revision, pause/resume/end | per-Location independence; approved exact Revision only |
| Sponsored viewer detail | eligible Sponsored projection | hide/report/enquire | view/open/hide keeps viewer private; Enquire starts normal controlled contact |
| Ads analytics | aggregate daily metrics | none/derived ingestion | no named viewer/lead CRM; views/opens not mislabeled as leads |
| Notifications | derived notification projection | read/acknowledge | notification failure cannot roll back core business state |

---

# Cross-cutting regression gates

## Authorization

Every protected page/projection must still deny access when opened directly with a URL and frontend workspace/navigation guard bypassed.

## Stale state

Every consequential command must re-check current authoritative state; UI state loaded earlier cannot force a transition.

## Idempotency

At minimum: Class Invitation send/accept, Transfer, Submission, Test Start/Submit, Campaign Revision submit/review where retryable, Ads reservation/confirm/release, Commercial Clearance.

## Concurrency

At minimum: Class seat reservation at Invitation send, Class transfer, Test first-Attempt lock, Ads daily capacity reservation.

## History

No account/profile closure, block, moderation action or Location switch may silently destroy another actor’s legitimate shared learning/safety/audit history.

## Organic vs Sponsored

No Ads command/table/capability may alter organic ranking, verification, endorsement or trust state.

## Removed-concept guard

Implementation review must reject any accidental reintroduction of:

- Enrollment;
- Batch entity;
- Adult/Minor learner entity split;
- turning-18 lifecycle;
- Attendance;
- generic progress %;
- public star ratings/reviews;
- public Learner directory;
- unrestricted DM;
- platform tuition payments in V1.2.

---

# Exit condition

When implementation begins, a slice is accepted only when its relevant rows in this matrix are demonstrably supported by schema + secure reads + canonical writes + regression tests.
