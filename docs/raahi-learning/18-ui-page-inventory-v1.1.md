# Raahi Learning V1.1 — Frozen UI Page Inventory

Status: **INSPECTED / FROZEN.**

This is the canonical route/page inventory from the inspected backend-free clickable prototype `Raahi_Learning_Clickable_UI_v1.1.zip`.

Prototype SHA-256: `2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

The prototype contains **77 canonical routes/pages**.

## Shared / identity

`welcome`, `otp`, `onboarding-intent`, `avatar-picker`, `home`, `settings`, `learners`, `location-picker`, `register-interest`, `saved`, `notifications`, `states`.

## Learner / parent discovery

`explore`, `teacher`, `institute`, `teaching-detail`, `request-new`, `request-edit`, `request-detail`, `enquiry-new`, `enquiry`, `trial`, `invitation`, `join-success`.

## Ongoing learning / safety

`classes`, `class-detail`, `class-post`, `materials`, `sessions`, `class-thread`, `class-transfer`, `class-leave`, `report-concern`, `block-user`, `past-class`, `activity`, `submission-review`, `test-upcoming`, `test`, `test-results`, `messages`.

## Teacher workspace

`teacher-home`, `teaching-options`, `teaching-option-edit`, `opportunities`, `teacher-classes`, `teacher-class`, `teacher-members`, `teacher-activity`, `teacher-test`, `teacher-material`, `teacher-profile-edit`.

## Institute workspace

`org-home`, `org-profile`, `org-teaching`, `org-members`.

## Community / local operations

`community`, `community-new`, `community-report`, `manager-home`, `manager-people`, `manager-learning`, `manager-reports`, `manager-location`, `manager-ads`.

## Platform operations

`platform-home`, `platform-safety`, `platform-ads`, `platform-audit`.

## Raahi Ads

`ads-home`, `ads-eligibility`, `ads-create`, `ads-inventory`, `ads-creative`, `ads-campaign`, `ads-analytics`, `sponsored-detail`.

## Important modal/drawer states

- QA scenario drawer;
- optional Trial scheduling;
- Account **Take a break** confirmation;
- guarded **Delete account** / closure with unresolved responsibility blockers;
- Class options drawer/modal;
- Teacher Create Class;
- Teacher Invite Learner by private learner code;
- Schedule Session;
- Community comment;
- close Learning Request;
- Local Manager report review;
- Sponsored Hide/Report menu;
- Test submit confirmation.

## Inspected edge states

- empty discovery / no matching learning;
- Location `interest_only` vs `preparing` vs `live`;
- Pending Enquiry with messaging closed;
- expired Class Invitation;
- no reservable Class seat;
- Class access denied after permission change;
- closed Learning Request with existing Enquiries preserved;
- failed Submission does not display Submitted;
- Changes Requested / Reviewed submission history;
- Upcoming Test derived from time;
- submitted Test locked;
- Past Class read-only rules;
- Ads inventory full without overselling;
- privileged deep link opened from wrong workspace;
- wrong-workspace page renders **Switch workspace**, never privileged data.

## Inspection results

- **154** canonical route/viewport checks: 0 issues;
- **32** privileged deep-link checks: 0 unguarded pages;
- **26** interaction/business-rule checks: 0 failures;
- **15** semantic/accessibility sanity samples: 0 issues.

## Authority rule

This inventory defines the required V1.1 product surfaces, not authorization. Production reads and commands must still enforce current Account, Learner, Organization, Location, Class and capability/relationship scope server-side. Navigation or workspace selection is never authority.
