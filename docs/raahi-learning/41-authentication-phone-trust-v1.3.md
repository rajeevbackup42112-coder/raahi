# Raahi Learning V1.3 — Authentication + Phone Trust Policy

Status: **FROZEN FOR V1.3 DESIGN.** Implementation must preserve the existing Raahi authorization model and must not turn phone freshness into a second login requirement for ordinary learning.

## 1. Purpose

V1.3 changes the authentication experience without changing Raahi's authority model.

Production intent:

**Google authenticates the Account. Phone OTP establishes/re-establishes a trusted contact signal. Server-side Raahi relationships/capabilities/state determine authority.**

This document does not enable Google OAuth or a production SMS provider by itself.

## 2. Authentication principles

- Google is the primary production sign-in path.
- A successful Google sign-in authenticates an `auth.users` identity/session; it does not create Teacher, Guardian, Institute, Local Manager or Platform authority.
- Raahi `Account` remains the application identity linked to the Supabase Auth user.
- Google name and photo are suggestions/defaults only.
- Raahi display name remains editable.
- Google profile changes never silently overwrite an established Raahi profile.
- Google photo is never automatically public. User opt-in is required before importing it into Raahi-controlled media.
- Phone verification is attached to the Account trust posture, never to Learner identity.
- A child Learner may continue to exist without a login or phone.
- No paid Advanced Phone MFA is required for V1.3.

## 3. Phone-trust state

Recommended durable application state:

`accounts.phone_trust_verified_at timestamptz null`

Do not duplicate the phone number in Raahi application tables solely to implement freshness if Supabase Auth remains the authoritative phone holder.

A helper should derive one of:

- `unverified` — no currently confirmed Auth phone / no successful trust confirmation;
- `fresh` — confirmed Auth phone exists and trust was successfully re-proven within 90 days;
- `stale` — confirmed phone exists but trust is older than 90 days or predates the current phone confirmation/change.

Conceptual freshness condition:

- current Auth phone is present;
- Auth phone is confirmed;
- `phone_trust_verified_at` is not null;
- `phone_trust_verified_at >= auth.users.phone_confirmed_at`;
- `phone_trust_verified_at >= now() - interval '90 days'`.

A confirmed phone change therefore makes the old trust timestamp stale automatically.

## 4. What stale phone trust MUST NOT block

Phone freshness is not a global security wall. Stale trust must not prevent an already-authorized user from continuing existing learning or exercising safety rights.

No fresh-phone requirement for:

- opening Home or existing authorized workspaces;
- viewing an existing Class, Materials, Sessions or Class history;
- viewing/opening an existing Activity;
- submitting/revising an Activity where the current relationship already authorizes it;
- learner-self Test Start / Save / Submit;
- viewing released Test result/history/guardian oversight already authorized by current relationships;
- reading or replying inside an already-Active Enquiry;
- reading/sending an already-authorized Class contextual message;
- viewing Notifications;
- viewing Saved items;
- ordinary authenticated Explore/discovery;
- ordinary non-sensitive profile edits such as display name/bio/avatar;
- leaving a Class or using an already-authorized learner-side transfer path;
- account pause/resume;
- Report / Block / safety-report actions;
- Local/Platform/Admin read-only dashboards where current capability already authorizes the read.

Important invariant: **Safety reporting must never be made harder because a phone is stale.**

## 5. Actions that require FRESH phone trust

Fresh phone trust should guard creation of a new trust/authority/public/commercial relationship, not every consequential button.

### Marketplace / learning relationship creation

Require fresh trust before:

- posting/opening a new Learning Request;
- sending a new Enquiry;
- provider expressing interest in a Learning Request;
- accepting a new Class Invitation (creates a new private learning relationship).

If freshness is stale, preserve the draft/intended action, complete OTP, then resume exactly where the user stopped.

### Teaching / public provider presence

Require fresh trust before:

- first enabling/publishing a Teacher presence;
- publishing a new What-I-Teach item;
- changing an existing Teaching Option from unavailable/non-public back into a state that actively solicits new learners after trust is stale.

Do **not** require OTP for every profile typo/edit while a currently authorized Teacher is already operating.

### Organization / delegated authority

Require fresh trust before:

- creating a new Organization;
- issuing an Organization staff invitation;
- accepting an Organization staff invitation that grants membership/capabilities;
- materially changing another member's delegated capability set if the actor's phone trust is stale.

Read-only Organization workspaces remain available under current authorization.

### Learner identity-linking authority

Require fresh trust before:

- issuing a Learner self-access invitation;
- accepting a Learner self-access invitation.

The invitation must still preserve the existing rule that the Learner is not recreated and the managing Account cannot accidentally become the same Learner's self identity.

### Account/security/contact

Require fresh or newly verified phone proof before:

- changing the registered phone number;
- closing the Account permanently;
- other future identity/contact recovery operations that materially alter account control.

### Community

V1.3 policy:

- creating a new Community post requires phone trust to be fresh;
- comments/reactions do not trigger a new OTP merely because 90 days elapsed;
- Report and Block never require fresh trust.

This gives public posting a modest anti-abuse gate without turning Community into an OTP-heavy experience.

### Ads / commercial / staff operations

When the current actor has the necessary server capability, fresh trust is required before high-consequence actions such as:

- submitting an ad Campaign/Revision for review;
- commercial-clearance confirmation;
- inventory confirmation / placement activation;
- local/platform admin state-changing moderation or restriction actions.

Draft editing and read-only operational review do not need an OTP solely due to age of phone trust.

## 6. Actions explicitly NOT made phone-freshness gates

Do not add fresh-phone checks to:

- learner Test-taking;
- Activity submission;
- existing Enquiry/Class messaging;
- leaving/transferring an existing Class relationship;
- ordinary file access/upload already authorized by a Class/Activity relationship;
- Report/Block/safety reporting;
- every comment/reaction;
- every Teacher/Organization profile edit;
- every admin dashboard read.

This prevents the 90-day policy from becoming invisible recurring login friction.

## 7. OTP UX

When fresh trust is needed:

1. preserve the current draft / route / intended command parameters locally and safely;
2. explain the interruption in plain language: **“Quick phone check — please confirm you still have access to this number.”**
3. send OTP to the currently associated number, or collect and verify a new number if none exists;
4. after successful server-verifiable proof, update `phone_trust_verified_at`;
5. resume the intended action;
6. do not route the user back to Home unless the original action no longer exists/is authorized.

If the business state changed while OTP was being completed, the resumed canonical command must re-evaluate current server state and return a helpful recovery path rather than forcing stale UI intent.

## 8. Technical trust-proof rule

The database must never accept a client-supplied timestamp or boolean such as `phone_verified=true`.

A command that records fresh trust must be able to prove, server-side, that the currently authenticated Auth user has just completed an acceptable phone-verification event.

Preferred implementation investigation order:

1. Verify in DEV whether standard Supabase phone reauthentication/verification produces server-verifiable recent OTP evidence in the refreshed JWT (`amr`/timestamp) for the same Google-authenticated user.
2. If verified, allow a narrowly-scoped canonical `confirm_phone_trust` command to validate that recent Auth evidence and stamp server `now()`.
3. If standard Auth does not provide sufficient trustworthy evidence, use the smallest server-side verification seam necessary (for example an Auth-aware server/Edge path) rather than trusting the browser.

Do not implement this using paid Advanced Phone MFA merely to obtain AAL2; V1.3 does not require the Advanced Phone MFA product.

## 9. DEV testing

For development business-flow testing:

- keep using Supabase Auth's supported fixed test-OTP mapping for synthetic test numbers;
- no real SMS needs to be sent;
- no OTP bypass is hard-coded into Raahi frontend/RPCs/public tables;
- test OTP configuration exists only in the DEV Auth configuration and should have an expiry where supported;
- the same normal Auth verification APIs are exercised so the resulting session/JWT is real.

Google integration should be tested separately with a small number of controlled Google test identities once Google OAuth credentials are configured.

Production test-OTP mappings must not exist.

## 10. External-service boundary

The following require external configuration and are not silently performed by database/UI work:

- Google Cloud OAuth client / consent-screen configuration;
- Supabase Google-provider client ID/secret configuration;
- production SMS provider configuration and SMS spend.

Implementation may prepare all code/contracts before those credentials/services are connected.

## 11. Given / When / Then acceptance scenarios

### AUTH-01 — Google login does not grant role

**Given** a new user signs in with Google
**When** Raahi bootstraps their Account
**Then** the Account has no Teacher/Guardian/Organization/admin authority merely because Google authenticated them.

### AUTH-02 — editable Google name

**Given** Google supplies a display name
**When** first-use onboarding opens
**Then** Raahi pre-fills the name but allows editing before/after bootstrap according to the profile flow.

### AUTH-03 — Google image never auto-public

**Given** Google supplies a profile photo
**When** the Account is created
**Then** no public Teacher/Learner/Organization image is published unless the user explicitly chooses/imports it.

### TRUST-01 — stale trust does not block learning

**Given** an Account's phone trust is 92 days old
**And** it already has authorized learner/Class access
**When** the user opens Class materials or performs an already-authorized Activity/Test action
**Then** no phone OTP is required solely because trust is stale.

### TRUST-02 — stale trust gates a new Enquiry

**Given** phone trust is stale
**When** the user sends a new Enquiry
**Then** Raahi preserves the Enquiry draft, requests phone verification, and resumes the same Enquiry after successful proof.

### TRUST-03 — phone change invalidates old freshness

**Given** phone trust was fresh yesterday
**When** the registered phone is changed and newly confirmed today
**Then** the old trust timestamp cannot satisfy freshness until the new phone proof is recorded.

### TRUST-04 — safety never blocked

**Given** phone trust is stale or absent
**When** an otherwise authenticated/authorized learner reports a safety concern or blocks another Account where the rule permits
**Then** Raahi does not demand a fresh phone OTP before accepting the protective action.

### TRUST-05 — Class Invitation acceptance

**Given** a valid Pending Class Invitation and stale phone trust
**When** the authorized learner-side Account accepts
**Then** Raahi requests a phone check, preserves the Invitation, then revalidates expiry/capacity/current authority before accepting.

### TRUST-06 — existing chat continues

**Given** an Enquiry is already Active
**And** phone trust becomes stale
**When** either currently authorized side sends a contextual message
**Then** the message flow remains available without phone re-verification.

### TRUST-07 — server owns freshness

**Given** a malicious client submits a forged timestamp/verified flag
**When** it attempts to mark phone trust fresh
**Then** the server rejects/ignores the client claim and updates freshness only from server-verifiable Auth evidence.

### TRUST-08 — Community protection remains accessible

**Given** a user has stale phone trust
**When** they Report or Block from Community
**Then** the protective action remains available without a fresh OTP.

### TRUST-09 — new public Community post

**Given** phone trust is stale
**When** the user attempts to create a new public Community post
**Then** Raahi requires a phone check and resumes the post draft afterward.

### TRUST-10 — permanent closure is sensitive

**Given** an Account is otherwise eligible for closure
**And** phone trust is stale
**When** the user confirms permanent closure
**Then** fresh phone proof is required before the canonical closure transition executes.

## 12. Non-goals

V1.3 does not add:

- mandatory OTP at every login;
- paid Advanced Phone MFA;
- mandatory phone for every Learner;
- phone-based authorization roles;
- hard day-90 logout;
- phone-freshness requirement for ordinary learning/safety actions;
- a public phone login button unless separately approved later;
- SMS/WhatsApp marketing or Sponsored notifications.
