# Raahi Learning V1.2 — Master Test Case Catalog

Status: **CANONICAL QA BLUEPRINT.**

Purpose: map the frozen UI, business rules, commands and data invariants into an executable QA catalog before Supabase implementation. This catalog distinguishes tests that can be proven now from tests that require a real PostgreSQL/Supabase runtime.

## Status vocabulary

- **UI-PASS** — already exercised against the inspected clickable prototype.
- **MODEL-PASS** — exercised against the backend-free model/property harness.
- **PLANNED-DB** — requires real schema/RLS/RPC execution.
- **PLANNED-LOAD** — requires staging-like concurrency/performance tooling.
- **PLANNED-CHAOS** — requires controlled runtime failure injection.
- **PLANNED-SEC** — requires real RLS/storage/auth endpoints or dynamic security testing.

A MODEL-PASS never substitutes for PLANNED-DB/LOAD/SEC where the property depends on PostgreSQL locking, grants, RLS, indexes, Storage or network behavior.

---

# A. Identity, Learner authority and Account lifecycle

| ID | Type | Scenario | Expected result | Current status |
|---|---|---|---|---|
| ID-001 | Scenario | Account creates a Learner | Learner exists; creator does not automatically become a second identity | PLANNED-DB |
| ID-002 | Invariant | Grant first active self access | Exactly one active self relationship | PLANNED-DB |
| ID-003 | Negative | Try to grant second active self access | Rejected | PLANNED-DB |
| ID-004 | Invariant | Grant first active manager access | Exactly one active manager relationship | PLANNED-DB |
| ID-005 | Negative | Try to grant second active manager access | Rejected/controlled transfer required | PLANNED-DB |
| ID-006 | Permission | Active manager accepts Rahul's formal marketplace decision | Allowed | PLANNED-DB |
| ID-007 | Permission | Rahul self account tries same formal decision while active manager exists | Denied by `can_make_learning_decision` | PLANNED-DB |
| ID-008 | Permission | Rahul self account starts Rahul's Test | Allowed when Class/Test conditions pass | MODEL-PASS + PLANNED-DB |
| ID-009 | Permission | Managing parent starts Rahul's Test | Denied | MODEL-PASS + PLANNED-DB |
| ID-010 | History | End manager access | Learner history remains intact | PLANNED-DB |
| ID-011 | Scenario | Later grant Rahul self access | Same Learner/history reused; no duplicate Learner | UI-PASS + PLANNED-DB |
| ID-012 | Lifecycle | Pause Account | Existing legitimate private history remains; prohibited new public/commercial actions stop | PLANNED-DB |
| ID-013 | Lifecycle | Resume paused Account | Normal permitted behavior restored | PLANNED-DB |
| ID-014 | Negative | Close sole manager with unresolved learner responsibility | Closure rejected with blocker | MODEL-PASS + PLANNED-DB |
| ID-015 | Negative | Close responsible teacher with unresolved required Class responsibility | Closure rejected with blocker | MODEL-PASS + PLANNED-DB |
| ID-016 | Negative | Close sole required Organization authority | Closure rejected with blocker | MODEL-PASS + PLANNED-DB |
| ID-017 | Retry | Repeat pause/resume/closure command with same idempotency key | One logical transition/result | PLANNED-DB |
| ID-018 | Security | Forge `acting_for_learner_id` for unrelated Learner | Denied even if client sends valid UUID | PLANNED-SEC |
| ID-019 | Security | Directly update Account/Learner access table as normal client | Denied | PLANNED-SEC |
| ID-020 | Audit | Privileged access transfer occurs | Significant transfer is auditable without sensitive overcollection | PLANNED-DB |

---

# B. Location and locality behavior

| ID | Type | Scenario | Expected result | Current status |
|---|---|---|---|---|
| LOC-001 | State | `interest_only` Location | Register Interest available; normal discovery/community/Ads serving unavailable | UI-PASS + PLANNED-DB |
| LOC-002 | State | `preparing` Location | Interest/onboarding may continue; normal live experience still gated | UI-PASS + PLANNED-DB |
| LOC-003 | State | `live` Location | Normal permitted discovery/community behavior | PLANNED-DB |
| LOC-004 | State | `paused` Location | New relevant public activity/Ads serving stops; existing private learning preserved | PLANNED-DB |
| LOC-005 | State | `retired` Location | No new normal activity; legitimate history preserved | PLANNED-DB |
| LOC-006 | Scenario | Switch selected Location | Home/Explore/Community context changes only | UI-PASS + MODEL-PASS |
| LOC-007 | Invariant | Switch Location with active Classes/Enquiries/Saved | Existing relationships/history remain reachable | MODEL-PASS + PLANNED-DB |
| LOC-008 | Idempotency | Register same learn interest twice | One active interest | PLANNED-DB |
| LOC-009 | Scenario | Same Account registers learn + teach interest | Both may coexist | PLANNED-DB |
| LOC-010 | Negative | Location launch occurs | Must not auto-create Learning Request/Teaching Option | PLANNED-DB |
| LOC-011 | Permission | Local Manager opens different Location's operations URL | Denied | UI-PASS + PLANNED-SEC |
| LOC-012 | Ads | Sponsored serving in `interest_only`/`preparing` | Never serves | MODEL-PASS + PLANNED-DB |

---

# C. Discovery, profiles, Teaching Options and Saved

| ID | Type | Scenario | Expected result | Current status |
|---|---|---|---|---|
| DIS-001 | Scenario | Teacher publishes valid Teaching Option | Discoverable only in eligible live Locations | PLANNED-DB |
| DIS-002 | Scenario | Organization publishes Teaching Option | Ownership remains Organization-scoped | PLANNED-DB |
| DIS-003 | Invariant | Teaching Option has both Teacher and Organization owners | Rejected by XOR constraint/command | PLANNED-DB |
| DIS-004 | State | Set option `not_taking_new_learners` | New discovery/enquiry behavior changes; existing Classes unaffected | PLANNED-DB |
| DIS-005 | State | Set option `no_longer_offered` | No new offer; history remains | PLANNED-DB |
| DIS-006 | Privacy | Save Teacher/Option/Organization | Private bookmark; provider is not notified | UI-PASS + PLANNED-DB |
| DIS-007 | Permission | Saving provider then trying to Message directly | No contact permission gained | UI-PASS + PLANNED-DB |
| DIS-008 | Trust | Public profile has exact qualification verification | Exact badge can display | PLANNED-DB |
| DIS-009 | Trust | Advertiser pays for campaign | Cannot create verification/endorsement | MODEL-PASS + PLANNED-DB |
| DIS-010 | Regression | Search public learner directory | No such endpoint/page exists | UI-PASS + PLANNED-SEC |
| DIS-011 | Regression | Public star rating/review field requested | Not present in V1.2 projection | UI-PASS + PLANNED-DB |
| DIS-012 | Organic/Ads | Paid Campaign exists | Organic ordering does not use payment state | PLANNED-DB |

---

# D. Learning Requests

| ID | Type | Scenario | Expected result | Current status |
|---|---|---|---|---|
| LR-001 | State | Create Draft Request | Draft not public | PLANNED-DB |
| LR-002 | State | Publish Draft → Open | Sanitized public Request becomes discoverable | MODEL-PASS + PLANNED-DB |
| LR-003 | State | Close Open Request | Closed with reason; retained in history | MODEL-PASS + PLANNED-DB |
| LR-004 | State | Reopen Closed Request with materially same need | Allowed | MODEL-PASS + PLANNED-DB |
| LR-005 | Negative | Reopen closed Request after Maths→Guitar material change | Must create a new Request | MODEL-PASS + PLANNED-DB |
| LR-006 | Negative | Change Rahul Request into Ananya Request | Rejected; create new Request | PLANNED-DB |
| LR-007 | Duplicate | Post duplicate open Request for same learner/need/location | Warn/prevent according to command rule | PLANNED-DB |
| LR-008 | Privacy | Public Request projection | No child phone/email/exact address/private avatar | MODEL-PASS + PLANNED-SEC |
| LR-009 | Permission | Unrelated Account edits Request | Denied | PLANNED-SEC |
| LR-010 | Permission | Active manager edits Rahul Request | Allowed | PLANNED-DB |
| LR-011 | Permission | Rahul self account edits formal Request while manager active | Denied in V1.2 | PLANNED-DB |
| LR-012 | Location | Switch Account's selected Location | Existing Open Request retains its own Location | MODEL-PASS + PLANNED-DB |

---

# E. Enquiries and Trial

| ID | Type | Scenario | Expected result | Current status |
|---|---|---|---|---|
| ENQ-001 | Scenario | Learner side sends Enquiry from Teaching Option | Pending Enquiry created with correct provider | PLANNED-DB |
| ENQ-002 | Scenario | Provider expresses interest in Learning Request | Same unified Enquiry model | PLANNED-DB |
| ENQ-003 | Negative | Enquiry references Teaching Option owned by different provider | Rejected | PLANNED-DB |
| ENQ-004 | Duplicate | Duplicate same-context Pending/Active Enquiry | Prevented/warned | PLANNED-DB |
| ENQ-005 | Permission | Pending Enquiry ordinary message | Denied | MODEL-PASS + PLANNED-DB |
| ENQ-006 | State | Receiving side engages Pending Enquiry | Active | PLANNED-DB |
| ENQ-007 | Permission | Active participant messages | Allowed unless restricted | MODEL-PASS + PLANNED-DB |
| ENQ-008 | Permission | Unrelated Account posts message | Denied | PLANNED-SEC |
| ENQ-009 | Trial | Schedule optional Trial inside Active Enquiry | Event recorded; Enquiry remains relationship boundary | PLANNED-DB |
| ENQ-010 | Trial | Multiple trial events | Allowed without new Trial relationship object | PLANNED-DB |
| ENQ-011 | State | Close Enquiry | History retained; ordinary new messages stop | PLANNED-DB |
| ENQ-012 | Sponsored | Sponsored CTA Enquire | Reuses normal Enquiry; no `ad_enquiry` entity | PLANNED-DB |

---

# F. Learner share codes

| ID | Type | Scenario | Expected result | Current status |
|---|---|---|---|---|
| SHR-001 | Scenario | Authorized learner side creates code | Unpredictable plaintext returned once; only hash persisted | PLANNED-DB |
| SHR-002 | Permission | Unrelated Account creates Rahul code | Denied | PLANNED-SEC |
| SHR-003 | Privacy | Teacher browses Learners without code | No browse/search endpoint | UI-PASS + PLANNED-SEC |
| SHR-004 | State | Consume active unexpired code with valid invite | Code consumed atomically with Invitation | MODEL-PASS + PLANNED-DB |
| SHR-005 | Negative | Consume code second time | Rejected | MODEL-PASS + PLANNED-DB |
| SHR-006 | Negative | Use revoked code | Rejected | MODEL-PASS + PLANNED-DB |
| SHR-007 | Negative | Use expired code | Rejected | MODEL-PASS + PLANNED-DB |
| SHR-008 | Race | Consume vs revoke simultaneously | Exactly one wins; no Invitation from invalid code | PLANNED-LOAD |
| SHR-009 | Retry | Network timeout after successful consume/invite then retry | One Invitation; code not double-consumed | PLANNED-CHAOS |
| SHR-010 | Abuse | Brute-force code space | Rate-limited; high-entropy token prevents practical enumeration | PLANNED-SEC |
| SHR-011 | Audit | Code operations audited | Never log raw plaintext token | PLANNED-SEC |

---

# G. Classes, Invitations, Membership and historical access

| ID | Type | Scenario | Expected result | Current status |
|---|---|---|---|---|
| CLS-001 | Scenario | Create 1:1 Class capacity 1 | Valid | PLANNED-DB |
| CLS-002 | Negative | 1:1 Class capacity >1 | Rejected | PLANNED-DB |
| CLS-003 | Scenario | Send Invitation with free seat | Pending Invitation created and seat reserved immediately | MODEL-PASS + PLANNED-DB |
| CLS-004 | Race | Many invitation sends for last seat | At most remaining capacity succeeds | MODEL-PASS + PLANNED-LOAD |
| CLS-005 | Duplicate | Send second Pending invite same Class/Learner | Rejected/idempotent | MODEL-PASS + PLANNED-DB |
| CLS-006 | Scenario | Accept valid Pending Invitation | Exactly one Active Membership; Invitation Accepted | MODEL-PASS + PLANNED-DB |
| CLS-007 | Invariant | Acceptance of already-reserved Invitation | Does not consume a second seat | MODEL-PASS + PLANNED-DB |
| CLS-008 | Retry | Double-tap Accept | One Membership/result | PLANNED-DB |
| CLS-009 | Stale | Invitation expires while Join page open | Accept fails authoritatively; UI refreshes | UI-PASS + PLANNED-DB |
| CLS-010 | Scenario | Decline Pending Invitation | Reservation released | MODEL-PASS + PLANNED-DB |
| CLS-011 | Scenario | Teacher cancels Pending Invitation | Reservation released | MODEL-PASS + PLANNED-DB |
| CLS-012 | Scenario | Expiry worker expires Invitation | Reservation released idempotently | MODEL-PASS + PLANNED-DB |
| CLS-013 | Fee | Pending Invitation has fee snapshot | Join shows exact offered terms | UI-PASS + PLANNED-DB |
| CLS-014 | Negative | Silently edit fee after Pending | Not allowed; cancel/reissue required | PLANNED-DB |
| CLS-015 | Capacity | Reduce Class capacity below Active+reserved | Rejected | PLANNED-DB |
| CLS-016 | Transfer | Transfer learner to destination with capacity | Source → Transferred + destination Active atomically | MODEL-PASS + PLANNED-DB |
| CLS-017 | Race | Two transfers claim final destination seat | Only one succeeds | PLANNED-LOAD |
| CLS-018 | Failure | Destination validation fails mid-transfer | Source remains Active; no partial transfer | MODEL-PASS + PLANNED-CHAOS |
| CLS-019 | Leave | Learner side leaves Active Class | Membership Left; Block state unchanged | PLANNED-DB |
| CLS-020 | Remove | Teacher/safety removes learner | Membership Removed; access revoked according to policy | PLANNED-DB |
| CLS-021 | Complete | Complete Class | Class Past + eligible Active memberships Completed atomically | MODEL-PASS + PLANNED-DB |
| CLS-022 | Complete | Class includes Left/Transferred/Removed learners | Their states remain unchanged | MODEL-PASS + PLANNED-DB |
| CLS-023 | History | Completed membership opens Past Class | Appropriate read-only history available | UI-PASS + PLANNED-DB |
| CLS-024 | History | Left learner opens shared feed/material | Shared Class access denied; own allowed artifacts/history remain | PLANNED-DB |
| CLS-025 | History | Removed learner opens copied Class URL | Class-private access denied | UI-PASS + PLANNED-SEC |
| CLS-026 | Location | Location later pauses | Existing private Class continues unless separate restriction applies | PLANNED-DB |
| CLS-027 | Direct origin | Offline-origin learner uses Class thread after joining | Works without fake Enquiry | UI-PASS + PLANNED-DB |
| CLS-028 | Messaging | Left/Removed learner sends Class-thread message | Denied | PLANNED-DB |
| CLS-029 | Security | Guess another Class/member/thread UUID | RLS/projection denies | PLANNED-SEC |
| CLS-030 | Load | 100k logical invites into capacity 50 | Maximum 50 valid reservations | MODEL-PASS; real PLANNED-LOAD |

---

# H. Sessions, files and Materials

| ID | Type | Scenario | Expected result | Current status |
|---|---|---|---|---|
| MAT-001 | Scenario | Schedule Session | Session visible to authorized Class participants | PLANNED-DB |
| MAT-002 | Derived state | Session time passes | Past derived from time; no Attendance/Completed subsystem required | UI-PASS + PLANNED-DB |
| MAT-003 | Scenario | Cancel Session | Cancelled timestamp/reason retained | PLANNED-DB |
| MAT-004 | Scenario | Share one Material to multiple Classes | Reusable links; removing one link preserves others | PLANNED-DB |
| MAT-005 | Permission | Learner without Class access requests private Material | Denied | PLANNED-SEC |
| MAT-006 | Security | Copy private storage URL/path | Does not bypass current authorization | PLANNED-SEC |
| MAT-007 | Failure | Storage upload fails before metadata completion | No falsely usable file linkage | PLANNED-CHAOS |
| MAT-008 | Revocation | Membership access lost while signed/file page open | Subsequent authorized retrieval denied | PLANNED-SEC |

---

# I. Activities and Submissions

| ID | Type | Scenario | Expected result | Current status |
|---|---|---|---|---|
| ACT-001 | State | Publish Draft Activity | Open Activity | PLANNED-DB |
| ACT-002 | State | Close Open Activity | Closed; due date itself is not state | PLANNED-DB |
| ACT-003 | Regression | Label Activity as Assignment/Practice/Exercise | Same underlying entity/engine | UI-PASS + PLANNED-DB |
| ACT-004 | Material | Link authorized Material to Activity | Visible within Class authorization | PLANNED-DB |
| ACT-005 | Negative | Link Material not shared/authorized for Class | Rejected | PLANNED-DB |
| ACT-006 | Submission | Learner submits required work | One logical Submission with revision 1 | PLANNED-DB |
| ACT-007 | Parent assist | Manager uploads Rahul's work | performer = parent, owner = Rahul | UI-PASS + PLANNED-DB |
| ACT-008 | Retry | Same submit request retried | No duplicate logical Submission/revision | PLANNED-DB |
| ACT-009 | Failure | Network fails before server confirms | UI must not show Submitted | UI-PASS + PLANNED-CHAOS |
| ACT-010 | Revision | Changes Requested then resubmit | Prior revision retained; new revision created | UI-PASS + PLANNED-DB |
| ACT-011 | Concurrency | Two simultaneous resubmits | Unique ordered revision numbers; no overwrite | PLANNED-LOAD |
| ACT-012 | Permission | Unrelated Account reads Rahul Submission | Denied | PLANNED-SEC |

---

# J. Tests and Attempts

| ID | Type | Scenario | Expected result | Current status |
|---|---|---|---|---|
| TST-001 | State | Publish valid Draft Test | Available according to configured time/state | PLANNED-DB |
| TST-002 | Derived | Test start time in future | UI shows Upcoming; no separate Upcoming DB state | UI-PASS + PLANNED-DB |
| TST-003 | Permission | Learner self starts available Test | One In-Progress Attempt | MODEL-PASS + PLANNED-DB |
| TST-004 | Permission | Managing parent starts learner Test | Denied | MODEL-PASS + PLANNED-DB |
| TST-005 | Retry | Start same Test twice | Same logical Attempt returned/resumed | MODEL-PASS + PLANNED-DB |
| TST-006 | Concurrency | Two tabs Start simultaneously | One Attempt; definition locks once | PLANNED-LOAD |
| TST-007 | Invariant | First valid Attempt starts | Test definition locked no later than this point | PLANNED-DB |
| TST-008 | Negative | Ordinary structural edit after definition lock | Rejected | PLANNED-DB |
| TST-009 | Scenario | Save answer repeatedly | Latest answer persisted for same Attempt/question | PLANNED-DB |
| TST-010 | Scenario | Submit In-Progress Attempt | Submitted exactly once | MODEL-PASS + PLANNED-DB |
| TST-011 | Retry | Double Submit | One submitted Attempt/result | MODEL-PASS + PLANNED-DB |
| TST-012 | Timeout | Duration expires | Saved answers auto-submit per rule | PLANNED-DB |
| TST-013 | Evaluation | Teacher evaluates Attempt | Evaluated with private result data | PLANNED-DB |
| TST-014 | Feedback | Teacher adds feedback | Visible only with result permissions/visibility | UI-PASS + PLANNED-DB |
| TST-015 | Visibility | Results hidden | Learner/manager cannot see unreleased result | PLANNED-SEC |
| TST-016 | Correction | Answer-key correction after evaluated Attempts | Explicit audited command recalculates affected results transactionally | PLANNED-DB |
| TST-017 | Invalidation | Exceptional invalidation | Reason required; audited | PLANNED-DB |
| TST-018 | Security | Another learner requests Attempt/result UUID | Denied | PLANNED-SEC |

---

# K. Community, Reports, Blocks, Restrictions and Verification

| ID | Type | Scenario | Expected result | Current status |
|---|---|---|---|---|
| SAFE-001 | Scenario | Eligible user posts in live Location Community | Published according to policy | PLANNED-DB |
| SAFE-002 | Regression | Downvote/dislike API requested | Not part of public V1.2 model | UI-PASS + PLANNED-DB |
| SAFE-003 | Permission | Learning-only student account posts publicly without required policy capability | Denied | PLANNED-DB |
| SAFE-004 | Report | User reports content/person | Report created; target not automatically punished | MODEL-PASS + PLANNED-DB |
| SAFE-005 | Learner safety | Learner self reports concern independent of manager marketplace authority | Allowed | PLANNED-DB |
| SAFE-006 | Parent safety | Manager attaches managed Learner context to report | Allowed | PLANNED-DB |
| SAFE-007 | Negative | Unrelated Account attaches arbitrary Learner context | Denied | PLANNED-SEC |
| SAFE-008 | Block | User blocks Account | Ordinary contact affected according to policy; history retained | MODEL-PASS + PLANNED-DB |
| SAFE-009 | Invariant | Block while both are in same Class | Does not silently end Membership | MODEL-PASS + PLANNED-DB |
| SAFE-010 | Moderation | Reviewer applies precise messaging restriction | Only intended scope affected | PLANNED-DB |
| SAFE-011 | Moderation | Discovery restriction exists | Existing Class access remains unless separately restricted | PLANNED-DB |
| SAFE-012 | Permission | Local Manager attempts private Test/Submission access | Denied | UI-PASS + PLANNED-SEC |
| SAFE-013 | Audit | Significant restriction applied/lifted | Actor/scope/reason auditable | PLANNED-DB |
| SAFE-014 | Verification | Verifier grants exact claim | Exact public label available | PLANNED-DB |
| SAFE-015 | Abuse | Many Reports alone | Must not mechanically equal guilt/punishment | MODEL-PASS + PLANNED-DB |
| SAFE-016 | Privacy | Moderator evidence fields | Not public/advertiser accessible | PLANNED-SEC |

---

# L. Raahi Ads

| ID | Type | Scenario | Expected result | Current status |
|---|---|---|---|---|
| ADS-001 | Eligibility | Eligible Organization creates Campaign | Allowed with scoped authority | PLANNED-DB |
| ADS-002 | Negative | Noneligible subject creates serving Campaign | Rejected | PLANNED-DB |
| ADS-003 | Target | Campaign targets multiple Locations/placements | Explicit target rows | PLANNED-DB |
| ADS-004 | Revision | Submit Revision 1 | Immutable review target | PLANNED-DB |
| ADS-005 | Revision | Edit after submission | New Revision required | PLANNED-DB |
| ADS-006 | Review | Reviewer approves exact Revision 1 | Approval applies only to R1 | MODEL-PASS + PLANNED-DB |
| ADS-007 | Stale | R2 exists while stale reviewer approves R1 | R1 only; R2 remains unapproved | MODEL-PASS + PLANNED-DB |
| ADS-008 | Conflict | Local Manager reviews own/connected Organization campaign | Denied/escalated | PLANNED-SEC |
| ADS-009 | Evidence | Claim requires evidence | Review can request; evidence remains private | PLANNED-DB |
| ADS-010 | Commercial | Payment/waiver cleared but Revision rejected | Cannot serve | MODEL-PASS + PLANNED-DB |
| ADS-011 | Commercial | Revision approved but clearance pending | Cannot serve | MODEL-PASS + PLANNED-DB |
| ADS-012 | Inventory | Reserve daily units within capacity | Held reservation | MODEL-PASS + PLANNED-DB |
| ADS-013 | Race | Many Campaigns claim final inventory unit | Capacity never exceeded | MODEL-PASS + PLANNED-LOAD |
| ADS-014 | Multi-day | One requested day full in atomic package | Whole requested reservation fails/behaves according to package rule; no hidden partial booking | PLANNED-DB |
| ADS-015 | Hold | Hold expires | Units released | MODEL-PASS + PLANNED-DB |
| ADS-016 | Confirm | Confirm valid hold | Confirmed without extra units | MODEL-PASS + PLANNED-DB |
| ADS-017 | Serving | Placement uses exact approved `serving_revision_id` | Valid only if same Campaign and approved | MODEL-PASS + PLANNED-DB |
| ADS-018 | State | Location pauses | Placement cannot serve there; other Locations independent | PLANNED-DB |
| ADS-019 | Surface | Home/Explore/configured Community | Sponsored may serve if all gates pass | MODEL-PASS + PLANNED-DB |
| ADS-020 | Surface | My Classes/Class/Activity/Test/private Messages | Sponsored never serves | UI-PASS + MODEL-PASS + PLANNED-DB |
| ADS-021 | Privacy | Viewer sees/opens/hides Sponsored item | Advertiser never receives named viewer list | PLANNED-SEC |
| ADS-022 | Enquiry | Viewer deliberately Enquires from Sponsored detail | Normal Enquiry created; intentional contact boundary | PLANNED-DB |
| ADS-023 | Analytics | Advertiser views metrics | Aggregate views/opens/enquiries/visits only | UI-PASS + PLANNED-DB |
| ADS-024 | Terminology | Mere view/open | Never labeled a lead | UI-PASS |
| ADS-025 | Frequency | Same user exceeds configured frequency | Further serving suppressed; private operational state only | PLANNED-DB |
| ADS-026 | Anti-monopoly | Same Organization submits duplicates to monopolize scarce inventory | Concentration policy considers Organization, not Campaign count | PLANNED-DB |
| ADS-027 | Load | 100k logical attempts into capacity 100 | Max 100 units | MODEL-PASS; real PLANNED-LOAD |
| ADS-028 | Security | Advertiser queries `ad_frequency_state` | Denied | PLANNED-SEC |
| ADS-029 | Regression | Ads payment attempts to set verification/organic rank | No command/path exists | PLANNED-SEC |
| ADS-030 | Failure | Notification/analytics write fails after serving/command commit | Core commercial/domain state remains valid | PLANNED-CHAOS |

---

# M. Notifications, audit, idempotency and async behavior

| ID | Type | Scenario | Expected result | Current status |
|---|---|---|---|---|
| SYS-001 | Failure | Core command commits, notification provider fails | Domain state remains committed; notification retriable | PLANNED-CHAOS |
| SYS-002 | Realtime | Realtime event delayed/dropped | Client refetch gets authoritative state | PLANNED-CHAOS |
| SYS-003 | Idempotency | Same key + same request | Existing logical result returned | PLANNED-DB |
| SYS-004 | Idempotency | Same key + different fingerprint | Rejected as misuse/conflict | PLANNED-DB |
| SYS-005 | Audit | Ordinary low-risk action | Avoid excessive sensitive audit payload | PLANNED-DB |
| SYS-006 | Audit | Significant safety/admin/commercial action | Append-oriented audit row present | PLANNED-DB |
| SYS-007 | Security | Normal client inserts/updates audit row | Denied | PLANNED-SEC |
| SYS-008 | Security | Normal client modifies idempotency outcome | Denied | PLANNED-SEC |
| SYS-009 | Async | Expiry worker runs twice | Invitation/hold expiry remains idempotent | PLANNED-DB |
| SYS-010 | Async | Worker misses one schedule and later catches up | Current expired objects reconciled without invalid resurrection | PLANNED-CHAOS |

---

# N. UI stale-state, responsive and accessibility regression

| ID | Type | Scenario | Expected result | Current status |
|---|---|---|---|---|
| UI-001 | Responsive | All 77 canonical routes on mobile/desktop | No rendering/title/overflow failures | UI-PASS |
| UI-002 | Permission | 32 privileged deep links under wrong workspace | No privileged data leakage | UI-PASS; PLANNED-SEC backend |
| UI-003 | Scenario | Core learner journey | Expected fixture transitions | UI-PASS |
| UI-004 | Scenario | Parent manages Rahul but Test-taking boundary remains | UI does not render impersonation action | UI-PASS |
| UI-005 | Stale | Invitation/full-capacity fixture | Correct error/refresh path | UI-PASS |
| UI-006 | Stale | Failed Submission fixture | Does not display Submitted | UI-PASS |
| UI-007 | Ads | Protected learning surfaces | No Sponsored cards | UI-PASS |
| UI-008 | Regression | Enrollment/Batch/ratings/public learner directory | Not present | UI-PASS |
| UI-009 | Accessibility | Semantic/accessibility sanity sample | No known issues in inspected sample | UI-PASS |
| UI-010 | Backend integration | Replace fixtures with secure projections/RPCs | Entire UI suite rerun; no behavior drift | PLANNED-DB |

---

# O. Migration, RLS, grants and database-integrity tests

| ID | Type | Scenario | Expected result | Current status |
|---|---|---|---|---|
| DB-001 | Migration | Fresh database applies migrations from zero | Success in documented order | PLANNED-DB |
| DB-002 | Migration | Local reset/reapply multiple times | Deterministic clean rebuild | PLANNED-DB |
| DB-003 | Schema | Expected constraints/indexes exist | Verified | PLANNED-DB |
| DB-004 | RLS | New core table accidentally lacks intended RLS | Test fails build/gate | PLANNED-DB |
| DB-005 | Grants | `anon`/`authenticated` can directly mutate protected core table | Must be false | PLANNED-SEC |
| DB-006 | RPC | Allowed client can execute only intended public RPCs | Verified | PLANNED-SEC |
| DB-007 | RLS | Service/system path differs from human path | Explicit controlled privileges only | PLANNED-SEC |
| DB-008 | Constraint | XOR owner/subject rule violated | DB rejects even if command bug exists | PLANNED-DB |
| DB-009 | Constraint | Duplicate active relationship/attempt/membership | DB/command rejects | PLANNED-DB |
| DB-010 | Forward-fix | Shared migration has defect | Correct through new migration, not history rewrite | PLANNED-DB |

---

# P. Real load/performance/stress tests — staging only

These are deliberately not marked PASS before a real database exists.

| ID | Type | Workload | Required evidence | Status |
|---|---|---|---|---|
| PERF-001 | Baseline | Typical public reads + authenticated dashboard reads | p50/p95/p99 + error rate | PLANNED-LOAD |
| PERF-002 | Command | Enquiry/Save/Request write mix | throughput/latency/locks | PLANNED-LOAD |
| PERF-003 | Contention | Last Class seat, 100–1000 simultaneous sends | zero oversell; lock wait/deadlock metrics | PLANNED-LOAD |
| PERF-004 | Contention | Last Ads inventory unit across Campaigns | zero oversell | PLANNED-LOAD |
| PERF-005 | Contention | Test Start from two tabs / many learners | one Attempt per learner; lock behavior | PLANNED-LOAD |
| PERF-006 | Spike | Burst from quiet → 10× expected pilot traffic | recovery and error-rate behavior | PLANNED-LOAD |
| PERF-007 | Soak | Sustained expected traffic for hours | no connection/memory/lock degradation | PLANNED-LOAD |
| PERF-008 | Data volume | Large historical Classes/Posts/Messages/Attempts | query plans/index effectiveness | PLANNED-LOAD |
| PERF-009 | RLS | Same hot read with RLS at realistic memberships | RLS overhead measured | PLANNED-LOAD |
| PERF-010 | Realtime | Class/community invalidation fan-out | delivery delay/drop behavior; DB correctness independent | PLANNED-LOAD |
| PERF-011 | Storage | Concurrent authorized Material access | signed/access path latency and revocation correctness | PLANNED-LOAD |
| PERF-012 | Breakpoint | Increase concurrency until SLO fails | known safe capacity, graceful failure, no invariant breach | PLANNED-LOAD |

---

# Q. Exit rules

Before a slice is accepted in implementation:

1. all test cases relevant to that slice move from PLANNED-DB/SEC to PASS;
2. no invariant/security case may be waived merely because UI hides the action;
3. failed concurrency/security tests block the next slice;
4. performance tests are run only when enough real schema exists to make the measurement meaningful;
5. a MODEL-PASS remains recorded as design evidence but is never used to waive the corresponding real database test;
6. any newly discovered business behavior must first update the product/UI/data contract, then this catalog, before implementation is altered.

This catalog is the master QA reference for Raahi Learning V1.2.