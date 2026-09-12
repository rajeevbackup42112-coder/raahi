# Raahi Learning V1 — Command & Permission Matrix

Status: **Canonical behaviour reference for writes.** API/RPC names may change, business ownership may not.

## Command rule

Every consequential write must answer:

1. Who is acting?
2. For whom/which Organization/Location are they acting?
3. What exact object is being changed?
4. What relationship or capability grants authority?
5. What current-state preconditions must still be true?
6. Is the command idempotent?
7. Does it require an atomic transaction?
8. Should it create an audit record?

## Identity & learner access

| Command | Who may act | Key checks | Transaction / audit |
|---|---|---|---|
| `create_learner` | authenticated Account | valid profile data; duplicate warning | audit useful |
| `grant_learner_self_access` | authorized manager/platform path | learner exists; target account identity confirmed | atomic + audit |
| `transfer_learner_management` | authorized support/platform path in V1 | current manager valid; new manager valid | atomic + audit |
| `end_learner_access` | authorized relationship owner/platform | cannot strand active responsibilities without controlled path | audit |

## Organizations

| Command | Who may act | Key checks | Notes |
|---|---|---|---|
| `create_organization` | permitted Account | education-relevant Organization type | audit if verified/privileged |
| `add_organization_member` | authorized Organization manager/platform | scope/capability permitted | audit |
| `remove_organization_member` | authorized Organization manager/platform | campaigns/classes remain Organization-owned | audit |

## Teaching & discovery

| Command | Actor | Preconditions |
|---|---|---|
| `publish_teaching_option` | teacher or authorized Organization member | owner valid; selected Locations eligible; minimum public data satisfied |
| `set_teaching_availability` | Teaching Option owner | affects new discovery only; never terminates Classes |
| `post_learning_request` | Account authorized for Learner | Location valid; no prohibited private learner exposure; duplicate check |
| `update_learning_request` | same learner-side authority | only non-material edits to existing context |
| `close_learning_request` | same learner-side authority | Request Open; close reason recorded |
| `reopen_learning_request` | same authority | underlying need still materially the same |
| `save_teaching_option` | authenticated Account | no relationship/contact permission created |
| `unsave_teaching_option` | same Account | private bookmark only |

## Enquiries

| Command | Actor | Preconditions |
|---|---|---|
| `send_enquiry` | Account authorized for Learner | valid Teaching Option/provider; no duplicate active same-context Enquiry; provider accepts new enquiries where relevant |
| `express_interest_in_request` | provider authority | Request Open; teacher/Organization allowed to respond |
| `engage_enquiry` | receiving side | Enquiry Pending; authority valid |
| `decline_enquiry` | receiving side | Enquiry Pending/eligible |
| `close_enquiry` | authorized participant/system policy | valid reason; history retained |
| `send_enquiry_message` | authorized participant | Enquiry Active; contextual messaging permissions valid |
| `schedule_trial_event` | authorized enquiry participant | Enquiry Active; trial optional |

## Classes

| Command | Actor | Preconditions | Hard transaction? |
|---|---|---|---|
| `create_class` | teacher/authorized Organization member | one responsible teacher; capacity >=1 | no |
| `activate_class` | responsible teacher | class setup valid | maybe |
| `send_class_invitation` | responsible teacher | learner/contact context valid; Class can potentially accept; avoid duplicate Pending invite | reservation logic may require transaction |
| `accept_class_invitation` | Account authorized for Learner | invitation Pending, unexpired, Class Active/eligible, capacity available/reserved, no active duplicate Membership | **YES** |
| `decline_class_invitation` | authorized learner-side actor | invitation Pending | idempotent |
| `cancel_class_invitation` | responsible teacher/authorized system | invitation Pending | release reservation atomically |
| `transfer_learner` | teacher + permitted learner-side/business rule path | source Membership Active; destination valid/capacity available | **YES** |
| `leave_class` | authorized learner-side actor | Membership Active; consequence confirmation | atomic state change |
| `complete_membership` | responsible teacher/system | Class/course completion rule | idempotent |
| `remove_learner` | responsible teacher or safety/admin path | valid reason/authority | audit for exceptional/safety cases |
| `mark_class_past` | responsible teacher | unresolved active concerns/tests handled or warned | guarded |

## Sessions & materials

| Command | Actor | Preconditions |
|---|---|---|
| `schedule_session` | responsible teacher | Class valid |
| `reschedule_session` | responsible teacher | Session not irreversibly past; notify affected users after commit |
| `cancel_session` | responsible teacher | valid Session |
| `add_material` | responsible teacher/authorized Organization path | content permitted |
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
| `start_test` | learner self-access | active Class Membership; Test currently available; attempt policy permits | **YES/idempotent** |
| `save_test_answer` | learner owning Attempt | Attempt In Progress | guarded |
| `submit_test` | learner owning Attempt/system timeout | exact Attempt In Progress; answers persisted | **YES/idempotent** |
| `evaluate_test_attempt` | authorized teacher/system | Attempt Submitted | guarded |
| `invalidate_test_attempt` | authorized exceptional path | reason required | **audit** |
| `correct_answer_key` | authorized teacher/admin | explicit correction; affected results identified | **audit + transactional recalculation** |
| `set_results_visibility` | responsible teacher | Test valid | guarded |

A parent with management access does not automatically have `start_test`/`submit_test` permission.

## Community

| Command | Actor | Preconditions |
|---|---|---|
| `publish_community_post` | permitted adult/account capability | legitimate connection to Location; content policy valid |
| `comment_on_community_post` | permitted account | post open/visible; policy valid |
| `react_to_community_content` | permitted account | approved reaction type |
| `hide_or_remove_community_content` | scoped moderator | Location scope/authority valid; reason/audit where significant |

## Trust & Safety

| Command | Actor | Preconditions |
|---|---|---|
| `report_subject` | permitted Account including student safety access | target exists; abuse controls |
| `block_account` | Account | cannot erase evidence/history |
| `apply_precautionary_restriction` | authorized safety role | credible safety basis; scope explicit | audit required |
| `resolve_report` | authorized reviewer | report review completed; report count alone is not guilt | audit |
| `grant_verification_claim` | authorized verifier | exact claim/evidence rules satisfied | audit |
| `revoke_verification_claim` | authorized verifier/platform | reason required | audit |

## Ads

| Command | Actor | Preconditions | Hard transaction/audit? |
|---|---|---|---|
| `enable_advertising` | authorized platform/commercial role | subject eligible | audit |
| `create_ad_campaign` | eligible advertiser member | Organization/Account authority valid |
| `submit_campaign_revision` | advertiser authority | immutable revision created; Locations/objective valid | idempotent |
| `request_ad_evidence` | authorized reviewer | exact revision; substantiation needed | audit |
| `review_campaign_revision` | Local Manager or Platform reviewer according to scope | exact revision; no conflict of interest; cross-location rules | audit + stale-revision protection |
| `reserve_ad_inventory` | advertiser/Ads ops according to flow | current capacity; valid window; concentration rules; hold policy | **YES/idempotent** |
| `confirm_ad_inventory` | authorized Ads ops/system | valid hold + required conditions | **YES** |
| `release_ad_inventory` | system/authorized actor | valid reservation | **YES** |
| `confirm_commercial_clearance` | authorized commercial role | terms recorded | audit + idempotent |
| `revoke_commercial_clearance` | authorized commercial/platform role | reason | audit |
| `pause_ad_placement` | advertiser/authorized platform depending reason | placement eligible | reason retained; audit for policy/admin |
| `resume_ad_placement` | authorized actor | approval/commercial/date/location still valid | guarded |
| `end_ad_placement` | system/authorized actor | expiry/cancel conditions | idempotent |

## Admin scope rules

### Local Manager

Authority is always attached to assigned Location(s). May handle local Community moderation, local public learning concerns, permitted single-Location Ads relevance/review, and local reports. Cannot casually access private Class/Submission/Test data.

### Platform Admin

Handles cross-Location issues, serious safety escalation, Organization/platform restrictions, Ads conflicts/cross-Location review, exceptional operations. Admin actions still use governed commands and auditing.

## Idempotency priority

Mandatory for at least:

- accept Class Invitation;
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
- `ad_inventory_reservations.state = 'confirmed'`

Those are outcomes of canonical commands after invariant checks.
