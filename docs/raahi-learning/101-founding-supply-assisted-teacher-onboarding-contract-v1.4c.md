# Raahi Learning — Founding Supply Assisted Teacher Onboarding Contract V1.4C

Status: **IMPLEMENTATION CONTRACT — MARKET ACTIVATION ENGINE 2 / SLICE 1**

Parent blueprint: `92-market-activation-seeding-blueprint-v1.4.md`

## 1. Problem

Raahi needs genuine early teacher supply in Gomoh and Dhanbad, but platform staff must not create a teacher profile that appears to have been independently authored or approved by a teacher who has not actually agreed.

The smallest safe Founding Supply slice is therefore:

> **Teacher requests help -> Raahi prepares a private draft -> the same teacher reviews and explicitly accepts -> only then does the profile and first teaching option become public.**

Raahi never publishes first and asks for permission later.

This first slice is teacher-only. Assisted coaching-organisation onboarding and unclaimed organisation listings remain separate later concepts.

## 2. Why this reuses the existing model

The current product already has:
- Account identity;
- `teach` capability;
- Teacher Profile;
- Teaching Option;
- Teaching Option Location;
- self-service teacher setup;
- public teacher/option discovery;
- canonical RPC-only consequential writes;
- server-side audit.

V1.4C must not create a parallel “seed teacher” profile system.

The assisted path materialises the **same canonical Teacher Profile and Teaching Option rows** used by organic self-service, but only after the real Account owner accepts.

## 3. Actors

### Teacher Account

A genuine signed-in Account may ask Raahi to assist with first-time setup.

The Teacher:
- initiates the assistance request;
- owns the eventual profile and Teaching Option;
- sees the exact proposed public facts before publication;
- may accept, decline or cancel;
- may edit or stop the profile/option later through normal teacher controls.

### Platform Admin

A Platform Admin may prepare a draft only for an Account that already asked for help.

The Platform Admin:
- cannot create the teacher identity;
- cannot initiate assistance on behalf of a silent Account;
- cannot accept the proposal for the Teacher;
- cannot cause the proposal itself to appear in public discovery;
- may fill only the bounded Teacher/Profile/first-option fields defined below;
- may withdraw an unaccepted proposal.

### Public user

Public discovery sees only accepted, canonical teacher/profile/option data.

There is no public “draft”, “requested” or “awaiting consent” object.

## 4. Eligibility

The first vertical slice is deliberately restricted to **first-time teacher setup**.

A Teacher Account is eligible only when:
- Account lifecycle is active;
- there is no existing Teacher Profile row;
- there is no existing teacher-owned Teaching Option;
- there is no active assisted-onboarding request;
- a previously revoked `teach` capability does not exist.

An Account that already has teacher supply data uses normal self-service controls instead of Founding Supply assisted onboarding.

This restriction avoids hidden overwrites and makes consent semantics unambiguous.

## 5. States

`requested`
- Teacher asked Raahi for setup help.
- No proposal exists.
- Nothing is public.

`draft_ready`
- Platform Admin prepared one proposed Teacher Profile + one first Teaching Option.
- Teacher can review exact facts.
- Nothing is public yet.

`accepted`
- Teacher explicitly accepted the exact draft.
- Atomic materialisation completed.
- Teacher Profile is visible.
- First Teaching Option is taking new learners.
- Terminal.

`declined`
- Teacher rejected the draft.
- Nothing published.
- Terminal.

`cancelled`
- Teacher withdrew the request before acceptance.
- Nothing published.
- Terminal.

`withdrawn`
- Platform Admin withdrew an unaccepted request/draft.
- Nothing published.
- Terminal.

No partial public state is permitted.

## 6. Proposed data in Slice 1

Teacher Profile proposal:
- headline;
- bio;
- experience summary.

First Teaching Option proposal:
- title;
- category;
- description;
- teaching mode: online / in_person / both;
- area or venue text;
- fee display text;
- exactly one founding Location in this first slice.

The selected Location must still be live when the Teacher accepts.

The Platform Admin does not set:
- Account display name;
- Account avatar;
- reviews/ratings;
- verification status;
- engagement counts;
- enquiries;
- Classes;
- testimonials;
- “success” claims.

## 7. Provenance

Teacher Profiles and Teaching Options gain immutable creation provenance:

- `organic` — created through existing self-service teacher commands;
- `assisted` — first materialised from an accepted assisted-onboarding request.

Existing rows default to `organic`.

For assisted rows, an internal `assisted_onboarding_request_id` links the public supply row to its consent/audit evidence.

This provenance is primarily an integrity and operating metric. It does **not** change public authorship.

An assisted Teacher Profile is still the **Teacher's profile**, not “Raahi-authored”.

Public UI therefore does not display an “assisted” badge by default.

## 8. Consent semantics

Teacher acceptance is the authoritative consent event.

The acceptance screen must show:
- exact proposed headline;
- exact bio;
- exact experience summary;
- exact first Teaching Option;
- exact founding Location;
- explicit statement that acceptance will publish these details publicly;
- consent text version.

Acceptance must be performed by the same authenticated Account that requested assistance.

The database records:
- request creator / Teacher Account;
- Platform Admin who prepared the draft;
- proposal timestamp;
- consent text version;
- accepting Account;
- acceptance timestamp;
- resulting Teacher Profile / Teaching Option IDs;
- audit event.

No checkbox or Platform Admin assertion substitutes for the Teacher's own authenticated acceptance.

## 9. Canonical commands

### Teacher

`request_assisted_teacher_onboarding(location_id, idempotency_key)`

Effect:
- creates one private `requested` assistance record.

`accept_assisted_teacher_onboarding(request_id, idempotency_key)`

Effect, atomically:
- revalidates eligibility;
- revalidates live Location;
- revalidates exact state `draft_ready`;
- enables `teach` for the accepting Teacher if needed;
- creates visible Teacher Profile with `creation_provenance='assisted'`;
- creates first Teaching Option with `creation_provenance='assisted'`;
- links Teaching Option to founding Location;
- records consent and audit;
- marks request `accepted`.

`decline_assisted_teacher_onboarding(request_id, idempotency_key)`

Effect:
- `draft_ready -> declined`;
- publishes nothing.

`cancel_assisted_teacher_onboarding(request_id, idempotency_key)`

Effect:
- `requested|draft_ready -> cancelled`;
- publishes nothing.

### Platform Admin

`prepare_assisted_teacher_onboarding(request_id, proposed fields..., idempotency_key)`

Effect:
- requires active Platform Admin;
- only `requested -> draft_ready`;
- saves a private bounded draft;
- publishes nothing.

`withdraw_assisted_teacher_onboarding(request_id, reason, idempotency_key)`

Effect:
- `requested|draft_ready -> withdrawn`;
- publishes nothing.

## 10. Read contracts

Teacher:
`get_my_assisted_teacher_onboarding()`

Returns only the current Account's own assistance records/draft data.

Platform:
`get_platform_assisted_teacher_onboarding(state?)`

Requires Platform Admin and returns the operational queue.

No raw table SELECT grant is added for browser roles.

## 11. Phone-trust compatibility

Requesting assistance is private and non-public.

Accepting assisted onboarding is equivalent to first-time teaching enablement + making a Teacher Profile visible + publishing the first Teaching Option.

Therefore the acceptance command is included in the server-owned “fresh phone trust required” command list.

Current Google-only trust mode may bypass enforcement centrally, exactly as existing teacher publication commands do.

If phone trust enforcement returns later, this slice automatically becomes trust-gated without redesign.

## 12. Invariants

1. Platform Admin cannot create an assistance request for a silent Teacher.
2. Platform Admin cannot accept for the Teacher.
3. Teacher cannot accept another Account's request.
4. Nothing becomes public before acceptance.
5. One Account cannot have two active assisted onboarding requests.
6. Existing teacher/profile/option data cannot be overwritten by this slice.
7. Revoked teaching capability cannot be silently re-enabled.
8. Location must be live at request and acceptance.
9. Ordinary self-service profile/option creation remains `organic`.
10. Accepted assisted profile/option creation provenance remains `assisted` even if the Teacher later edits normal fields.
11. Assisted provenance must reference the accepted assistance record.
12. No fake engagement/demand/ratings/reviews are created.
13. Direct browser writes to Teacher/Profile/Option/assistance tables remain denied.
14. Idempotent retries do not duplicate supply.
15. Reusing an idempotency key with changed data fails.
16. Acceptance is all-or-nothing in one database transaction.
17. Teacher can later correct/stop the result through existing normal teacher controls.

## 13. Screen-to-backend contract

### Teacher Setup

Keep the existing self-service path:
- **Set it up myself**

Add:
- **Ask Raahi to help**

This creates a private assistance request for the selected live Location.

### Setup Help status

`requested`:
- “Raahi is preparing a draft.”
- Cancel available.

`draft_ready`:
- show exact proposed public data;
- **Publish these details**;
- **Decline**;
- Cancel available.

`accepted`:
- route to normal Teacher workspace.
- normal editing/availability controls take over.

### Platform workspace

Add **Founding Supply** queue:
- genuine Teacher Account name;
- founding Location;
- request age/state;
- prepare bounded draft;
- withdraw request.

The Platform UI has no “publish as teacher” button.

## 14. Acceptance tests

### Authority
- ordinary Account can request only for itself;
- Platform Admin can prepare only a Teacher-requested record;
- non-platform Account cannot prepare;
- Teacher cannot accept another Teacher's request;
- Platform Admin cannot call Teacher acceptance as the target.

### No-public-before-consent
- requested record creates no Teacher Profile;
- prepared draft creates no Teacher Profile;
- prepared draft creates no Teaching Option;
- discovery remains unchanged until acceptance.

### Atomic accept
- one accept creates at most one teach capability;
- one visible Teacher Profile;
- one Teaching Option;
- one Teaching Option Location;
- request becomes accepted;
- provenance is assisted;
- audit/consent evidence exists.

### Recovery
- decline creates no public supply;
- cancel creates no public supply;
- withdraw creates no public supply;
- acceptance fails if Location stopped being live;
- acceptance fails if Teacher independently created supply after requesting assistance;
- idempotent retry returns the same materialised IDs.

### Organic regression
- existing self-service teacher setup remains available;
- normal profile insert defaults organic;
- normal Teaching Option insert defaults organic;
- existing discovery/enquiry/Class semantics are unchanged.

## 15. Deferred

Not in V1.4C Slice 1:
- pre-Account WhatsApp invitation tokens;
- Platform Admin targeting Accounts that did not request help;
- assisted organisation onboarding;
- unclaimed organisation listings;
- Founding Teacher public recognition badge;
- multiple initial Teaching Options;
- multi-Location assisted proposal;
- photos/logos;
- platform editing after acceptance;
- assisted Learning Requests;
- bulk import.

Those require separate authority/consent contracts after this walking skeleton is proven.
