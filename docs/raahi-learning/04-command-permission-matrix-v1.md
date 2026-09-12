# Raahi Learning V1 — Command & Permission Matrix

Status: **Canonical behaviour reference for writes. Updated after physical blueprint review v1.1.** API/RPC names may change; business ownership may not.

## Command rule

Every consequential write must answer:

1. Who is acting?
2. For whom/which Organization/Location are they acting?
3. What exact object is being changed?
4. What relationship or capability grants authority?
5. Is an active scoped restriction relevant?
6. What current-state preconditions must still be true?
7. Is the command idempotent?
8. Does it require an atomic transaction?
9. Should it create an audit record?

## Identity & learner access

| Command | Who may act | Key checks | Transaction / audit |
|---|---|---|---|
| `create_learner` | authenticated Account | valid profile data; duplicate warning | audit useful |
| `grant_learner_self_access` | authorized manager/platform path | learner exists; target account identity confirmed; no conflicting active self access | atomic + audit |
| `transfer_learner_management` | authorized support/platform path in V1 | current manager valid; new manager valid | atomic + audit |
| `end_learner_access` | authorized relationship owner/platform | cannot strand active responsibilities without controlled path | audit |
| `grant_account_capability` | authorized platform/policy path | capability valid; scope belongs in relationship table if scoped | audit for privileged capabilities |
| `revoke_account_capability` | authorized platform/policy path | current grant valid | audit for privileged capabilities |

## Organizations

| Command | Who may act | Key checks | Notes |
|---|---|---|---|
| `create_organization` | permitted Account | education-relevant Organization type | audit if verified/privileged |
| `add_organization_member` | authorized Organization manager/platform | scope/capability permitted | audit |
| `grant_organization_member_capability` | authorized Organization manager/platform | member active; capability allowed | audit where privileged |
| `remove_organization_member` | authorized Organization manager/platform | campaigns/classes remain Organization-owned | audit |

## Teaching & discovery

| Command | Actor | Preconditions |
|---|---|---|
| `publish_teaching_option` | teacher or authorized Organization member | owner valid; selected Locations eligible; minimum public data satisfied; discovery restrictions checked |
| `set_teaching_availability` | Teaching Option owner | affects new discovery only; never terminates Classes |
| `post_learning_request` | Account authorized for Learner | Location valid; no prohibited private learner exposure; duplicate check |
| `update_learning_request` | same learner-side authority | only non-material edits to existing context |
| `close_learning_request` | same learner-side authority | Request Open; close reason recorded |
| `reopen_learning_request` | same authority | underlying need still materially the same |
| `save_teacher_profile` | authenticated Account | no relationship/contact permission created |
| `save_teaching_option` | authenticated Account | no relationship/contact permission created |
| `save_organization` | authenticated Account | no relationship/contact permission created |
| corresponding `unsave_*` | same Account | private bookmark only |

## Enquiries

| Command | Actor | Preconditions |
|---|---|---|
| `send_enquiry` | Account authorized for Learner | valid Teaching Option/provider; Teaching Option owner matches provider; no duplicate active same-context Enquiry; provider accepts new enquiries where relevant; restrictions checked |
| `express_interest_in_request` | provider authority | Request Open; teacher/Organization allowed to respond; restrictions checked |
| `engage_enquiry` | receiving side | Enquiry Pending; authority valid |
| `decline_enquiry` | receiving side | Enquiry Pending/eligible |
| `close_enquiry` | authorized participant/system policy | valid reason; history retained |
| `send_enquiry_message` | authorized participant | Enquiry Active; contextual messaging permissions valid; messaging restrictions checked |
| `schedule_trial_event` | authorized enquiry participant | Enquiry Active; trial optional |

## Classes

| Command | Actor | Preconditions | Hard transaction? |
|---|---|---|---|
| `create_class` | teacher/authorized Organization member | one responsible teacher; capacity >=1; 1:1 capacity=1 | no |
| `activate_class` | responsible teacher | class setup valid | guarded |
| `send_class_invitation` | responsible teacher | learner/contact context valid; Class Active/eligible; no duplicate Pending invite; finite expiry; capacity includes Active Memberships + other unexpired Pending invites | **YES — reserves seat** |
| `accept_class_invitation` | Account authorized for Learner | invitation Pending/unexpired; Class Active/eligible; reserved seat valid; no active duplicate Membership | **YES** |
| `decline_class_invitation` | authorized learner-side actor | invitation Pending | atomic release + idempotent |
| `cancel_class_invitation` | responsible teacher/authorized system | invitation Pending | atomic release + idempotent |
| `expire_class_invitation` | system/authorized job | Pending and expiry passed | atomic release + idempotent |
| `transfer_learner` | teacher + permitted learner-side/business rule path | source Membership Active; destination valid/capacity available | **YES** |
| `leave_class` | authorized learner-side actor | Membership Active; consequence confirmation | atomic state change |
| `complete_membership` | responsible teacher/system | Class/course completion rule | idempotent |
| `remove_learner` | responsible teacher or safety/admin path | valid reason/authority | audit for exceptional/safety cases |
| `mark_class_past` | responsible teacher | unresolved active concerns/tests handled or warned | guarded |
| `publish_class_post` | responsible teacher or permitted Class participant according to post type | Active Membership/teacher authority; Class access valid | guarded |
| `comment_on_class_post` | permitted Class participant | post visible; comments enabled; current Class authorization valid | guarded |
| `send_class_learner_message` | responsible teacher or currently authorized learner-side Account | exact Class+Learner thread; no unrestricted cross-platform DM; messaging restrictions checked | guarded |

## Sessions & materials

| Command | Actor | Preconditions |
|---|---|---|
| `schedule_session` | responsible teacher | Class valid |
| `reschedule_session` | responsible teacher | Session not irreversibly past; notify affected users after commit |
| `cancel_session` | responsible teacher | valid Session |
| `add_material` | responsible teacher/authorized Organization path | content permitted; file authorization metadata valid |
| `share_material_to_class` | material owner + Class authority | target Class valid |
| `remove_material_from_class` | authorized teacher | access revoked only from selected audience; shared references preserved elsewhere |

## Activities & submissions

| Command | Actor | Preconditions | Idempotent? |
|---|---|---|---|
| `publish_activity` | responsible teacher | Activity valid; state Draft |
| `close_activity` | responsible teacher | state Open |
| `submit_activity` | learner self or explicitly allowed manager assisting learner | active Membership; Activity Open/late rule allows; learner ownership preserved | **YES** |
| `request_submission_changes` | responsible teacher | current submission exists | guarded |
| `review_submission` | responsible teacher | submission exists/current | guarded |

Important: `performed_by_account_id` may be parent, but `learner_id` remains the owner of the learning work.

## Tests

| Command | Actor | Preconditions | Hard transaction? |
|---|---|---|---|
| `publish_test` | responsible teacher | questions/config valid |
| `start_test` | learner self-access | active Class Membership; Test currently available; attempt policy permits; lock Test definition if first valid Attempt | **YES/idempotent** |
| `save_test_answer` | learner owning Attempt | Attempt In Progress | guarded |
| `submit_test` | learner owning Attempt/system timeout | exact Attempt In Progress; answers persisted | **YES/idempotent** |
| `evaluate_test_attempt` | authorized teacher/system | Attempt Submitted | guarded |
| `invalidate_test_attempt` | authorized exceptional path | reason required | **audit** |
| `correct_answer_key` | authorized teacher/admin | Test definition already locked or evaluated attempts exist; structural question/choice edits prohibited; affected results identified | **audit + transactional recalculation** |
| `set_results_visibility` | responsible teacher | Test valid | guarded |

A parent with management access does not automatically have `start_test`/`submit_test` permission.

## Community

| Command | Actor | Preconditions |
|---|---|---|
| `publish_community_post` | Account with current posting capability/policy eligibility | legitimate connection to Location; content policy valid; Community restriction checked |
| `comment_on_community_post` | permitted account | post visible; policy valid; restriction checked |
| `react_to_community_content` | permitted account | approved positive/contextual reaction type |
| `hide_or_remove_community_content` | scoped moderator | Location scope/authority valid; reason/audit where significant |

## Trust & Safety

| Command | Actor | Preconditions |
|---|---|---|
| `report_subject` | permitted Account including student safety access | target exists at report time or valid preserved context; abuse controls |
| `block_account` | Account | cannot erase evidence/history |
| `apply_scoped_restriction` | authorized safety/platform role | credible basis; subject + exact scope + optional Location explicit | audit required |
| `lift_scoped_restriction` | authorized safety/platform role | restriction Active; reason/authority valid | audit required |
| `resolve_report` | authorized reviewer | report review completed; report count alone is not guilt | audit |
| `grant_verification_claim` | authorized verifier | exact claim/evidence rules satisfied | audit |
| `revoke_verification_claim` | authorized verifier/platform | reason required | audit |

## Ads

| Command | Actor | Preconditions | Hard transaction/audit? |
|---|---|---|---|
| `enable_advertising` | authorized platform/commercial role | subject eligible | audit |
| `create_ad_campaign` | eligible advertiser member | Organization/Account authority valid |
| `set_ad_campaign_targets` | advertiser authority | requested Locations live/eligible for sale; placement types valid; one consistent campaign creative rule | guarded |
| `submit_campaign_revision` | advertiser authority | immutable revision created; target context/objective valid | idempotent |
| `request_ad_evidence` | authorized reviewer | exact revision; substantiation needed | audit |
| `review_campaign_revision` | Local Manager or Platform reviewer according to scope | exact revision; no conflict of interest; cross-location rules | audit + stale-revision protection |
| `reserve_ad_inventory` | advertiser/Ads ops according to flow | current daily capacity for every requested date; valid targets; concentration rules; hold policy | **YES/idempotent** |
| `confirm_ad_inventory` | authorized Ads ops/system | valid hold + required conditions | **YES** |
| `release_ad_inventory` | system/authorized actor | valid reservation | **YES** |
| `confirm_commercial_clearance` | authorized commercial role | terms recorded | audit + idempotent |
| `revoke_commercial_clearance` | authorized commercial/platform role | reason | audit |
| `set_ad_serving_revision` | authorized Ads/system flow | exact Revision belongs to Campaign and is Approved; never selects latest implicitly | guarded + audit where significant |
| `pause_ad_placement` | advertiser/authorized platform depending reason | placement eligible | reason retained; audit for policy/admin |
| `resume_ad_placement` | authorized actor | serving Revision approved; commercial/date/location/inventory/restriction conditions still valid | guarded |
| `end_ad_placement` | system/authorized actor | expiry/cancel conditions | idempotent |

Per-user frequency controls are system serving logic only and are never advertiser-accessible named viewer history.

## Admin scope rules

### Local Manager

Authority is always attached to assigned Location(s). May handle local Community moderation, local public learning concerns, permitted single-Location Ads relevance/review, and local reports. Cannot casually access private Class/Submission/Test data.

### Platform Admin

Handles cross-Location issues, serious safety escalation, Organization/platform restrictions, Ads conflicts/cross-Location review, exceptional operations. Admin actions still use governed commands and auditing.

## Idempotency priority

Mandatory for at least:

- send/accept Class Invitation where capacity is affected;
- transfer Learner;
- submit Activity;
- start Test;
- submit Test;
- submit/review Campaign Revision where retries matter;
- reserve/confirm/release Ads inventory;
- Commercial Clearance confirmation.

## Direct write prohibition

Application UI must not directly execute updates such as:

- `class_memberships.state = 'active'`
- `class_invitations.state = 'accepted'`
- `test_attempts.state = 'submitted'`
- `tests.definition_locked_at = ...`
- `access_restrictions.state = 'active'`
- `ad_inventory_reservations.state = 'confirmed'`
- `ad_placements.serving_revision_id = latest_revision`

Those are outcomes of canonical commands after invariant and authorization checks.
