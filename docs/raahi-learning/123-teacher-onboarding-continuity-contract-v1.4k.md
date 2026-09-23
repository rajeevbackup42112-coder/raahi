# Raahi Learning V1.4K — Teacher Onboarding Continuity Contract

Status: **IMPLEMENTATION CONTRACT — REPAIRS EXISTING SELF-SERVICE + ASSISTED JOURNEYS**

Companion:
- `119-canonical-alignment-audit-prelaunch-2026-09-23.md`
- `101-founding-supply-assisted-teacher-onboarding-contract-v1.4c.md`
- `121-human-language-alignment-contract-v1.4k.md`

## 1. Problem

The backend correctly requires fresh phone trust for trust-sensitive Teacher publication actions.

The current frontend, however, has two paths that call sensitive commands directly:

- self-service `enable_teaching`;
- assisted `accept_assisted_teacher_onboarding`.

A `PHONE_TRUST_REQUIRED` response is therefore surfaced as an error instead of preserving the intended action, performing the trust check, and resuming the exact action.

The self-service path also drops a new Teacher on Teacher Home after profile save even when there is no first **What I Teach** option yet.

## 2. Canonical journey

### Self-service

**Start teaching → phone trust if required → About you → first What I Teach + Location → Teacher Home**

The first Teaching Option defaults to the existing canonical availability state `taking_new_learners`.

### Assisted

**Private draft ready → Publish these details → phone trust if required → exact acceptance resumes → Teacher Home**

No operator can publish for the Teacher.

## 3. Reuse existing trust mechanism

Do not add another OTP implementation.

Use the existing V1.3 pending-sensitive-action mechanism:

1. attempt the canonical RPC;
2. on `PHONE_TRUST_REQUIRED`, store only the RPC name, exact params and safe post-success UI metadata in sessionStorage;
3. route to the existing phone-check screen;
4. after successful phone confirmation, invoke the exact canonical RPC;
5. refresh Account/Teacher context;
6. route to the intended destination.

No OTP plaintext or secret is added to pending-action state.

## 4. Self-service derived progress

No new Teacher-onboarding database state is required.

Progress is derived from canonical state:

- no active `teach` capability → enable teaching;
- `teach` active + no Teacher Profile → About you;
- Teacher Profile + zero Teaching Options → first What I Teach;
- at least one Teaching Option → normal Teacher Home.

This avoids another lifecycle table merely for screen progress.

## 5. UI behavior

### Start teaching

`Set it up myself` must use trust-aware `enable_teaching`.

After success/resume:
- set current view to Teacher;
- refresh Teacher workspace;
- open Teacher Profile.

### First Teacher Profile

When there are zero Teaching Options:
- save the profile through `upsert_teacher_profile` using trust-aware continuation;
- refresh Teacher workspace;
- open a new What I Teach form.

Existing Teachers who already have Teaching Options retain ordinary profile-edit behavior.

### First What I Teach

When there are zero existing Teacher-owned Teaching Options:
- publish through canonical `publish_teaching_option`;
- include at least one live Location as today;
- preserve through phone trust if required;
- refresh Teacher workspace;
- open Teacher Home.

Existing Teaching Option editing behavior remains unchanged.

### Assisted acceptance

Use the same trust-aware action runner for `accept_assisted_teacher_onboarding`.

After success/resume:
- current view = Teacher;
- refresh Teacher workspace;
- open Teacher Home.

## 6. Invariants

- UI never grants teach capability itself;
- URL/view switching never grants authority;
- phone check never becomes a second login;
- pending action contains no OTP/provider secret;
- canonical commands still re-check current authority and state after phone verification;
- assisted request remains private until the same Teacher accepts;
- no duplicate profile/option on retries;
- existing Teacher edits are not forced through onboarding;
- no new database onboarding lifecycle is introduced.

## 7. Acceptance

- self-service enable preserves/resumes across `PHONE_TRUST_REQUIRED`;
- assisted acceptance preserves/resumes across `PHONE_TRUST_REQUIRED`;
- resumed action sets Teacher view only after server success;
- first profile continues to first What I Teach;
- first option continues to Teacher Home;
- existing Teacher with options can edit profile normally;
- source contains no direct operational table writes;
- model/security/phone-trust regressions remain green.
