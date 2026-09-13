# Raahi Learning V1.3 — Consolidated Product + UX Review Gate

Status: **REVIEW CONSOLIDATED.** This document narrows the V1.3 delta after comparing the final UX audit against the deliberately frozen V1/V1.2 product decisions. It does **not** authorize a broad redesign of the Raahi Learning domain.

Review rule: **easy intent, strict authority; preserve yesterday's product simplifications unless a concrete scenario proves they cannot work.**

## Executive conclusion

The V1/V1.2 product model remains sound. The final UI/competitor/DB audit found implementation and usability gaps, but it did **not** produce evidence that the core domain should be redesigned.

The only intentional product-level amendment for V1.3 is the authentication direction:

- Google is the primary production sign-in path;
- Google name/photo are onboarding defaults only and remain editable inside Raahi;
- phone verification is an Account trust signal, not the main repeated login mechanism;
- phone trust may become stale after the agreed freshness period (currently 90 days) and is rechecked only for selected trust-sensitive actions;
- stale phone trust must never remove existing Class, Activity, Test or history access;
- authorization still comes only from current server-side relationships/capabilities/state.

Everything else in this document is either implementation completion over already-approved rules, presentation/orchestration improvement, or explicitly deferred/rejected.

## Product rules that remain frozen

The following decisions are **not reopened** by the V1.3 audit:

- Account is not Learner; learning history belongs to Learner.
- One Account may learn, manage a Learner, teach and represent an Organization.
- V1 keeps **one active managing Parent/Guardian per Learner**. Rich multi-guardian/supporter models remain deferred until real evidence requires them.
- No Adult Learner / Minor Learner split and no turning-18 migration lifecycle.
- No public Learner or Account directory.
- Browsing or Saving never creates contact permission.
- Enquiry remains the controlled relationship-starting boundary.
- Enquiry lifecycle remains Pending → Active → Closed.
- Trial remains optional inside Enquiry; it is not a separate mandatory lifecycle.
- Class Invitation remains separate from Membership and may reserve finite capacity.
- Membership remains the Class-private access boundary.
- One Class model supports 1:1 and Group.
- One responsible teacher/instructor per Class in V1.
- Parent/guardian management never grants learner Test-taking impersonation.
- Activity/Test integrity rules remain strict.
- No public star ratings/reviews in V1.
- Community remains local, authenticated and separate from private Class content.
- Sponsored remains education-only, clearly labeled, aggregate-analytics only, and absent from private learning/Test/message surfaces.
- UI never directly mutates core operational tables; canonical RPC/state rules continue to win.
- Realtime remains invalidation/refetch only; PostgreSQL remains source of truth.

## Authentication amendment

### Production entry

Preferred flow:

**Open Raahi / follow a Raahi link → Continue with Google → find/bootstrap Raahi Account → confirm/edit name and profile image suggestion → continue the intended action.**

Google is authentication, not authorization. A Google account does not create Teacher, Guardian, Institute or Manager authority.

### Google profile data

- Google-provided name is an editable onboarding default.
- Later Google profile changes must not silently overwrite an established Raahi display name.
- Google photo may be suggested during onboarding, but it must never be auto-published as a Teacher/Learner image.
- If the user chooses to use it, Raahi should import/copy it into Raahi-controlled media rather than depend permanently on an external Google avatar URL.

### Phone trust

Phone verification belongs to the **Account**, not the Learner.

Recommended behavior:

- verify phone once before the first trust-sensitive action that requires it;
- store durable server-owned verification freshness;
- after 90 days, mark trust stale rather than invalidating the Account;
- request a fresh OTP only when the user next performs a selected trust-sensitive action;
- existing Classes, Materials, Activities, Tests and history continue normally;
- a phone-number change immediately invalidates the prior phone-trust freshness.

Do not use JWT/session `amr` timestamp alone as the 90-day source of truth because it is session-scoped.

Exact trust-sensitive action matrix is an implementation-spec task, not a reason to reopen the domain model.

## Required V1.3 implementation completion

These are required because the currently integrated frontend exposes technical gaps or fails to provide a human path for already-approved capabilities. They do **not** change the core product model.

### 1. First-use intent must actually set up the user

Current issue: a newly bootstrapped Account may have no authorized workspace and therefore no meaningful next step.

Required guided paths:

- **I want to learn** → create/select self Learner using existing canonical learner command.
- **I’m helping someone learn** → inline create/select managed Learner.
- **I teach** → enable teaching → Teacher profile → What I Teach → Location/availability → publish.
- **I represent an institute** → create Organization → guided institute setup.
- **I’m exploring** → ordinary non-privileged Home/Explore experience.

Intent guides setup; it never grants authority by itself.

### 2. Human learner switching and inline Add learner

Replace technical acting-context language with a simple learning/family selector such as:

**Me · Rahul · Ananya · + Add learner**

If a user adds a Learner while composing an Enquiry or Learning Request, create the Learner through the canonical command and resume the same draft with that Learner selected.

### 3. Learner later receiving their own Account access

The approved domain already allows an existing Learner to later gain self-access without recreating history. The current command requires a target Account UUID, which is not a usable human journey.

Add a private, expiring, one-time invitation mechanism:

**Managing guardian → Set up Rahul’s own access → private link → Rahul authenticates → accepts → same Learner gets self access.**

This invitation is implementation infrastructure for the existing relationship rule; it does not create a new Learner type or guardian hierarchy.

### 4. WhatsApp-friendly existing learner share flow

Keep the existing secure learner share-code model and its one-time/expiry/capacity rules. Present the bearer token as a private WhatsApp-friendly link instead of making users copy a technical code.

The link never grants Class Membership. It only lets an authorized teacher resolve the intended Learner and send the normal seat-reserving Class Invitation.

Do not add a generic public/untargeted teacher-created join link in V1.3.

### 5. Guided Teacher onboarding

Present one human journey over the existing backend primitives:

**Start teaching → profile basics → What I Teach → Locations → availability → preview → publish.**

Do not expose capability/object terminology to first-time teachers.

### 6. Guided Institute onboarding

Wire the existing Organization creation command into first-use onboarding. The creator remains the initial authorized Organization administrator as already implemented.

Replace technical UUID entry with human flows:

- Organization Class responsible teacher → select from eligible current Organization members.
- Adding a staff member → private, expiring Organization staff invitation link; recipient authenticates and accepts once.

Keep granular capability codes underneath, but present friendly permission labels/presets in the UI.

### 7. Messages must represent all authorized contextual conversations

The navigation already promises **Messages**, but the current implementation effectively lists Enquiries while Class/Learner conversations are accessible only from inside Classes.

Provide one contextual Messages inbox that can list:

- Enquiry conversations;
- authorized Class + Learner threads.

Every conversation retains its context and current authorization checks. There is still no unrestricted DM search/compose directory.

This likely requires a small read-only authorized conversation-list projection; it does not change messaging permission rules.

### 8. Notifications must be produced by real business transitions

The notification table/read path exists, but current business commands do not yet generate a useful notification stream.

Add a deliberately small transition-to-notification matrix for meaningful events such as:

- Enquiry received/replied/connected;
- Class Invitation;
- important Session change;
- Activity changes requested / reviewed where useful;
- Test available / result released;
- contextual Class message;
- Organization staff invitation;
- relevant safety/admin resolution.

Every notification must deep-link to the exact authorized context and recheck current authorization at open time. Notifications remain derived/non-authoritative; notification failure never reverses the business transition. Sponsored viewer push remains prohibited.

### 9. Wording and visual simplification

Keep lifecycle/security terms in specifications and admin/audit surfaces, not ordinary end-user copy.

Examples of concepts to hide or translate for normal users:

- capability / authorization scope;
- derived lifecycle state;
- immutable revision;
- reserved occupancy;
- projection;
- Account UUID;
- internal Invitation/Membership mechanics unless the distinction matters to the user.

Use natural actions such as **Send enquiry**, **Reply & connect**, **Schedule trial**, **Join Class**, **Invite staff**, **Add learner**, **Take a break**.

### 10. Helpful recovery instead of raw rule errors

Preserve existing domain guards but translate them into recoverable UX:

- duplicate Learning Request → offer the existing request;
- materially different need/learner → offer to create a new request using the entered details;
- stale/expired Invitation → explain and return to the relevant Class/teacher context;
- closure blocker → show the specific responsibility to transfer/resolve;
- weak network → preserve drafts where practical, disable duplicate submits while in-flight, and reuse the same logical idempotency key on retry.

### 11. Advertiser/admin simplification

Do not alter Ads governance. Simplify the advertiser-facing campaign journey into a guided wizard while preserving approval, commercial clearance, immutable approved revision, inventory and placement controls underneath.

Likewise, keep Local/Platform admin controls strict while reducing unnecessary operational jargon in routine screens.

## Explicitly deferred / rejected after the final review

The following are **not** required V1.3 changes:

- secondary Family Supporter relationship — defer;
- multiple managing guardians — reject V1;
- logged-out Teacher/Institute/Teaching Option discovery — defer until acquisition evidence justifies the additional anonymous surface;
- logged-out Community — reject V1.3;
- anonymous Sponsored serving — defer;
- generic public Learner/Account directory — reject;
- unrestricted DM search/compose — reject;
- generic teacher-created join link — defer;
- response-time public badge — defer until real data exists;
- public star ratings/reviews — reject V1;
- attendance, progress percentage, multi-teacher Class, platform tuition payment, global Community — remain deferred/removed as previously decided.

## Final implementation register

Classification: **A** presentation only; **B** orchestration over existing backend; **C** small backend/auth/projection extension; **E** enabling infrastructure for an already-approved relationship/flow (not a new product rule).

| ID | Required item | Class | V1.3 disposition |
|---|---|---:|---|
| V13-01 | Google-primary authentication | C | Adopt |
| V13-02 | Editable Google-name default | B | Adopt |
| V13-03 | Google photo opt-in import, never auto-public | B/C | Adopt |
| V13-04 | Durable Account phone-trust freshness | C | Adopt |
| V13-05 | No hard day-90 learning/account lock | A/C | Freeze |
| V13-06 | Intent-driven first-use setup | B | Adopt |
| V13-07 | Base Explore path without privileged authority | B | Adopt |
| V13-08 | Inline Add learner / learner selector | B | Adopt |
| V13-09 | Learner self-access invitation link | E | Adopt |
| V13-10 | Learner share token rendered as private WhatsApp link | B | Adopt |
| V13-11 | Guided Teacher onboarding | B | Adopt |
| V13-12 | Guided Institute creation | B | Adopt |
| V13-13 | Private Organization staff invitation | E | Adopt |
| V13-14 | Responsible teacher member picker | B | Adopt |
| V13-15 | Human Organization permission labels/presets | A/B | Adopt |
| V13-16 | Unified contextual Messages inbox | C | Adopt |
| V13-17 | Meaningful transition notifications + deep links | C | Adopt |
| V13-18 | Friendly Enquiry/Trial/Request wording and recovery | A/B | Adopt |
| V13-19 | Account-closure blocker checklist | B/C | Adopt |
| V13-20 | Simplified advertiser/admin presentation | A/B | Adopt |
| V13-21 | Weak-network draft/retry protection | B | Adopt |
| V13-22 | Secondary family supporter | — | Defer |
| V13-23 | Logged-out marketplace discovery | — | Defer |

## Scenario suite required before implementation is considered complete

1. New Google user bootstraps exactly one Raahi Account and can edit imported display name.
2. Google photo is never automatically published; explicit opt-in import is required.
3. New self-learner intent creates/selects one self Learner and continues.
4. Parent adds Rahul inline during an Enquiry/Request and the draft resumes unchanged except for learner selection.
5. Parent with Rahul/Ananya can switch context without sibling data leakage.
6. Stale (>90-day) phone trust does not block existing Class/Activity/Test/history.
7. Stale phone trust does trigger before a selected trust-sensitive action and the pending user action survives OTP.
8. Changing the registered phone invalidates the previous trust freshness.
9. Learner self-access invite links to the same Learner and preserves history.
10. Managing guardian cannot accidentally turn their own Account into the Learner self identity.
11. Pending Enquiry still blocks unrestricted messaging; Reply & connect opens it once.
12. Existing learner private WhatsApp token remains one-time/expiring and produces a normal Class Invitation.
13. Institute owner onboarding creates Organization/creator authority once.
14. Organization staff invite is private, expiring, revocable/replay-safe and creates only intended membership/capabilities.
15. Organization Class responsible teacher can only be selected from eligible current members.
16. Messages inbox lists Enquiry and authorized Class threads but cannot manufacture access.
17. Notification deep links recheck current permission before rendering private context.
18. Notification failure cannot roll back the core transition.
19. Guardian can view permitted Test oversight but still cannot Start/Save/Submit a learner Test.
20. Weak-network retries reuse one logical idempotency key and do not duplicate state.
21. Account closure translates server blockers into concrete resolution steps.
22. No V1.3 path exposes a public Learner/Account directory or unrestricted DM surface.

## DB compatibility conclusion

The core database/domain model remains valid.

Expected V1.3 backend work is limited to:

- Google Auth integration and continuation handling;
- durable phone-trust freshness + guards for the chosen action matrix;
- optional safe Google-avatar import handling;
- learner self-access invitation infrastructure;
- Organization member invitation infrastructure;
- authorized contextual conversation-list projection;
- real notification production/context/deep-link contract;
- optional closure-readiness projection if needed for clean UI.

Existing canonical commands already cover Account bootstrap/profile, Learner creation, teaching enable/profile/options, Organization creation, Enquiry/Trial, Learning Request lifecycle, learner share code + Class Invitation, Class/Activity/Test/Storage, Account pause/resume/closure and Organization capability management once the target identity is safely resolved.

No evidence supports rebuilding the Learner/Class/Enquiry/Test/Ads domain.

## Change-control after this gate

After this consolidation, another platform doing something differently is not sufficient reason to reopen V1.3.

A new product/domain change requires one of:

1. a contradiction in the frozen rules;
2. a security/privacy defect;
3. a failed scenario/usability test that cannot be fixed by presentation/orchestration;
4. real pilot-user evidence showing the current simpler model cannot represent the needed journey safely.

Otherwise, treat the request as post-V1 evidence/backlog rather than redesigning the implementation.

## Next gate

1. define the exact Google + phone-trust authentication scenarios and selected trust-sensitive actions;
2. rewrite the clickable prototype/end-user wording to the consolidated V1.3 flows without touching the proven DB yet;
3. replay the full persona/scenario suite on mobile and desktop;
4. perform UI ↔ canonical RPC/projection reconciliation;
5. produce the minimal migration/RPC delta;
6. only then modify Supabase/frontend implementation.
