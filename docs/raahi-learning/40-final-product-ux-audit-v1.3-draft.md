# Raahi Learning V1.3 — Final Product + UX Audit (Draft Review Gate)

Status: **AUDIT DRAFT — NO PRODUCT RULE, DATABASE, AUTH CONFIGURATION OR FRONTEND CHANGE IS AUTHORIZED BY THIS DOCUMENT.**

Purpose: close one deliberate product/UX review before the next implementation phase. This audit used the frozen 77-page prototype, the integrated V1.2 frontend, canonical product/backend docs, read-only inspection of the deployed Supabase dev contract, current Supabase Auth documentation, and current flow patterns from Google Classroom, Outschool, ClassDojo, Preply, UrbanPro, TeacherOn, Wyzant and Superprof.

Review principle: **easy intent, strict authority.** User intent should be easy to express; actual authority continues to come from server-side relationships, capabilities and current state.

## Principles that remain frozen

- Account is not Learner; learning history belongs to Learner.
- One Account may learn, manage a learner, teach and represent an Organization.
- Navigation/workspace choice never grants authority.
- No public Learner or Account directory.
- Browsing/Saving never grants contact permission.
- Enquiry remains the controlled marketplace relationship boundary.
- Trial stays optional inside Enquiry.
- Pending Class Invitation reserves finite capacity.
- Membership remains the Class-private access boundary.
- Parent/guardian management never grants Test-taking impersonation.
- Test definition/Attempt integrity rules remain strict.
- Private Class/Activity/Test/message content stays private.
- Sponsored remains education-only, clearly labeled, aggregate-analytics only, and absent from protected learning/private surfaces.
- UI never directly mutates core operational tables; canonical RPC/state rules continue to win.

## Key findings

### 1. Public browse before authentication

Current phone-first entry creates unnecessary acquisition friction. V1.3 should allow a logged-out visitor to browse only sanitized public marketplace discovery: live Locations, Teacher public profile, Organization public profile and Teaching Option/What-I-Teach details.

This is a small backend extension, not UI-only. `list_public_locations()` already permits `anon`, while `discover_teaching_options`, `get_teaching_option_public`, `get_teacher_profile_public` and `get_organization_public` are currently authenticated-only. If adopted, only these deliberately sanitized SECURITY DEFINER reads should gain anonymous EXECUTE. Underlying tables, Learners, Classes, Saves, Enquiries, Messages and Community remain protected.

Logged-out Community and anonymous Sponsored serving are **not** part of this change.

### 2. Google-primary Account authentication

Recommended entry:

**Browse → meaningful action → Continue with Google → bootstrap/find Raahi Account → confirm/edit Raahi display name → continue the exact intended action.**

Google name/photo are onboarding defaults, not authorization or legal identity proof. Raahi display name stays editable and later Google changes never silently overwrite it. A Google photo must never be auto-published as a Teacher/learner image. If persisted, explicit user confirmation should copy it into Raahi-controlled media rather than treat an external URL as a permanent Raahi upload.

### 3. Phone OTP becomes trust freshness

The proposed three-month phone check fits if implemented as **soft trust freshness**, not periodic account expiry.

- phone verification belongs to Account, not Learner;
- stale phone trust never logs the user out or removes existing Class/history access;
- existing Class learning, permitted Activities, Tests and released history continue;
- fresh trust is required for selected trust-sensitive actions such as new Enquiry, new Learning Request, accepting a new Class Invitation, publishing teaching, Organization creation/member invitation, learner-access invitation and sensitive contact/identity changes;
- Community posting/reporting may require a verified phone without necessarily forcing a new OTP exactly at day 90.

Do not rely only on JWT `amr` for the 90-day rule because it is session-scoped. Recommended minimal backend support: server-owned `accounts.phone_trust_verified_at`, comparison with current `auth.users.phone_confirmed_at` so a phone change invalidates older trust, and canonical helper/guard functions that record fresh trust only after server-verifiable phone confirmation/OTP.

### 4. First-use onboarding contradiction

The live frontend bootstraps a new Account and then offers only already-authorized workspaces. A genuine new Account may have no Learner, teach capability or Organization and therefore no useful workspace.

Intent must perform setup rather than pretend authority already exists:

- **I want to learn** → create self Learner if needed;
- **I’m helping someone learn** → inline create managed Learner;
- **I teach** → `enable_teaching` → Teacher Profile → What I Teach → Location/availability → publish;
- **I represent an institute** → `create_organization` → guided institute setup;
- **I’m exploring** → ordinary Explore/Home with no privileged capability.

The backend primitives already exist; the live frontend is missing this orchestration.

### 5. Family/learner UX

Replace technical acting-context language with human learning cards:

**Your learning: Me · Rahul · Ananya · + Add learner.**

When a parent is already composing a Request/Enquiry and chooses Add learner, `create_learner` should run inline and return them to the same task with that Learner selected.

The current live frontend does not wire `create_learner` even though the backend already supports it.

### 6. Learner later receiving own access

The backend command `grant_learner_self_access` requires a target Account UUID. That proves the authority rule, but is not a viable human journey.

V1.3 should add a private, expiring, one-time **Learner self-access invitation**:

**Manager → Set up Rahul’s own access → share private link → Rahul authenticates → accept → same Rahul Learner gains self access.**

No history is recreated, and the current rule preventing the active manager Account from also becoming Rahul’s self Account remains.

This requires a replay-safe invitation/token object or equivalent server capability.

### 7. Guardian rule is the only major family-domain decision still open

Real family use strongly suggests father/mother or another guardian may share supervision. Do **not** allow two full `manage` relationships because formal marketplace decision authority becomes ambiguous.

Audit recommendation if the rule changes: retain exactly **one active managing guardian**, plus optional narrower **family supporter** relationships. A supporter may see appropriate Class/material/session/activity/Test-oversight information, receive relevant learner notifications, report concerns and optionally assist uploads; a supporter may not take Tests, create/close formal marketplace relationships, accept/decline Class Invitations, voluntarily transfer/leave, grant learner self access or change guardian authority.

This is a true domain/permission change and needs explicit approval before implementation.

### 8. Enquiry and Trial

Keep `Pending → Active → Closed` internally, but make the UX natural:

- learner side: **Send enquiry** with contextual opening note;
- provider side: **Reply & connect** / **Decline**;
- unrestricted messaging opens only after the existing engage transition;
- Trial appears as optional **Schedule trial** action inside the Enquiry, not a mandatory journey stage.

### 9. Learning Request recovery

Preserve duplicate/material-change rules, but guide the user:

- duplicate → “You already have a Maths request open. View/edit it?”
- materially different learner/need → “Create a new request using these details?”

No domain change required.

### 10. WhatsApp-friendly offline learner invitation

Existing learner share codes are high-entropy, hashed, one-time and expiring, and `send_class_invitation_with_share_code` already enforces authority/capacity atomically.

Present the same bearer token as a private link instead of requiring humans to copy a code:

**Rahul’s family → Share with teacher → WhatsApp Raahi link → teacher authenticates → selects eligible Class → sends Invitation.**

The link never grants Class access itself. A generic untargeted teacher-created join link is deferred because it introduces bearer-seat and learner-targeting complexity.

### 11. Teacher onboarding

Use one guided setup over existing primitives:

**I teach → phone trust if required → enable teaching → profile → What I Teach → Locations → availability → preview → publish.**

Do not expose Profile vs Teaching Option vs capability mechanics to a first-time teacher.

Objective trust claims such as Identity verified / Qualification verified stay. Public star ratings/reviews stay rejected. Response-time badges are deferred until real data exists.

### 12. Institute onboarding and staff

`create_organization` already creates the Organization, creator membership and initial management capabilities, but the live frontend never wires Organization creation.

Institute staff is a genuine missing journey: the live UI currently asks for a raw “Known Account ID / UUID”. Do not solve this with a public Account search.

Add a private expiring **Organization member invitation**:

**Admin → invite staff → choose friendly permission preset → share link → recipient authenticates → accepts → membership/capabilities created once.**

Organization Class creation must also replace “Responsible teacher Account ID” with a picker of eligible active Organization members.

Keep granular backend capability codes, but show friendly labels/presets such as Profile & public information, Learning & Classes, Ads, Manage staff.

### 13. Messages is incomplete

The nav says **Messages**, but the current live route lists Enquiries only; Class+Learner contextual conversations are accessible only from inside a Class.

V1.3 should provide one contextual Messages inbox listing both:

- Enquiry conversations;
- authorized Class + Learner threads.

Each item names its context. There is still no unrestricted DM directory. This likely needs a small authorized conversation-list projection.

### 14. Notifications are structurally present but not wired to real transitions

The `notifications` table, private read projection and `app_private.enqueue_notification` helper exist, but read-only deployed-schema inspection found no domain function or trigger currently invoking the helper.

V1.3 needs a deliberately small notification matrix: Enquiry received/replied/connected, Class Invitation, important Session change, Activity/changes requested, Test available/result released, contextual Class message, Organization staff invitation, and appropriate safety resolution. Every notification must carry enough source/learner context to open the exact authorized screen. Sponsored viewer push remains prohibited.

Notification delivery must remain derived/non-authoritative; failure must not own or reverse the core business transition.

### 15. Community, Ads, closure and low-connectivity

- Community stays authenticated/local in V1.3; no logged-out feed and no global community.
- Logged-out Explore stays ad-free initially; anonymous Sponsored serving is deferred.
- Advertiser UI should become a simple campaign wizard while approval, commercial clearance, immutable approved revision and inventory rules remain underneath.
- Account closure blockers remain strict but become a human checklist of responsibilities to resolve.
- Weak-network UX preserves typed drafts where practical, disables duplicate submits while in flight, reuses the same logical idempotency key on retry, and never claims success before the server confirms it.

## Master candidate register

Classification: **A** presentation only; **B** orchestration over existing backend; **C** small backend/auth/projection extension; **D** domain/relationship/permission change.

| ID | Candidate | Class | Recommendation |
|---|---|---:|---|
| UX-01 | Logged-out Teacher/Institute/Teaching Option discovery | C | Adopt |
| UX-02 | Logged-out Community feed | C | Reject V1.3 |
| UX-03 | Anonymous Sponsored serving | C | Defer |
| UX-04 | Google-primary sign-in | C/B | Adopt |
| UX-05 | Editable Google-name default | B | Adopt |
| UX-06 | Google photo suggested, never auto-public | B/C | Adopt principle |
| UX-07 | Resume exact intended action after auth | B | Adopt |
| UX-08 | Account phone trust separate from login | C | Adopt |
| UX-09 | 90-day freshness only for selected trust actions | C | Adopt |
| UX-10 | Hard day-90 account/learning lock | D | Reject |
| UX-11 | Intent performs first-use setup | B | Adopt |
| UX-12 | Base “Explore” experience without privilege | B | Adopt |
| UX-13 | Inline Add learner | B | Adopt |
| UX-14 | Family/learning cards instead of technical context | A/B | Adopt |
| UX-15 | Private learner self-access invitation | D | Adopt |
| UX-16 | Secondary family supporter | D | **Decision required** |
| UX-17 | Multiple full managing guardians | D | Reject |
| UX-18 | Friendly Enquiry wording with same states | A/B | Adopt |
| UX-19 | Trial as optional Enquiry action | A/B | Adopt |
| UX-20 | Helpful Request duplicate/material-change recovery | A/B | Adopt |
| UX-21 | Learner share code rendered as private WhatsApp link | B | Adopt |
| UX-22 | Generic untargeted teacher join link | D | Defer |
| UX-23 | Guided Teacher onboarding | B | Adopt |
| UX-24 | Objective verification/availability trust signals | A/B | Adopt |
| UX-25 | Public star ratings/reviews | D | Reject |
| UX-26 | Response-time badge | C | Defer |
| UX-27 | Guided Institute creation | B | Adopt |
| UX-28 | Private Organization staff invitation | D | Adopt |
| UX-29 | Responsible teacher picker, never UUID entry | B | Adopt |
| UX-30 | Human org permission labels/presets | A/B | Adopt |
| UX-31 | Unified contextual Messages inbox | C | Adopt |
| UX-32 | Unrestricted DM compose/search | D | Reject |
| UX-33 | Meaningful notification production + deep links | C | Adopt |
| UX-34 | Engagement/promotion spam notifications | D | Reject |
| UX-35 | Simpler Class/Activity/Test wording | A | Adopt |
| UX-36 | Guardian Test-taking | D | Reject |
| UX-37 | Account closure blocker checklist | B/C | Adopt |
| UX-38 | Simplified advertiser campaign wizard | A/B | Adopt |
| UX-39 | Simplify Local/Platform operational jargon | A | Adopt |
| UX-40 | Context-aware mobile nav labels | A | Adopt |
| UX-41 | Weak-network draft/retry protection | B | Adopt |
| UX-42 | Public Learner/Account directory to solve invites | D | Reject |

## Scenario additions that must be automated/replayed

1. Logged-out visitor opens public Teaching Option → Enquire → Google auth → exact option resumes.
2. New self learner intent creates self Learner once and continues.
3. Parent adds Rahul inline during Enquiry/Request and resumes same draft.
4. Parent with Rahul/Ananya switches context without leaking sibling data.
5. 92-day-old phone trust does not block existing Class/Activity/Test/history.
6. 92-day-old phone trust does trigger before a new Enquiry and the draft survives OTP.
7. Phone change makes older phone-trust record stale.
8. Learner self-access private invite links to the same Learner/history.
9. Active manager cannot consume the Learner self-access invite as the same Account.
10. Pending Enquiry still blocks free messaging; Reply & connect opens it once.
11. Private learner WhatsApp share token is one-time and produces a normal seat-reserving Invitation.
12. Institute owner onboarding creates Organization/creator authority once without UUID entry.
13. Organization staff invite is private, expiring, revocable and idempotent.
14. Organization Class responsible teacher is chosen only from eligible current members.
15. Messages inbox lists both Enquiry and authorized Class threads; stale relationship cannot grant access.
16. Notification deep link rechecks current authorization before opening its source.
17. Manager/supporter Test oversight never grants Start/Save/Submit.
18. Weak-network retry reuses one logical idempotency key.
19. Logged-out discovery cannot expose Community content.
20. Account closure translates blockers into specific resolution steps.

## DB/auth compatibility summary

**Existing backend already supports most B items:** Account bootstrap/profile, Learner creation, teaching enable/profile/options, Organization creation, Enquiry/Trial, Learning Request lifecycle, learner share code + Class Invitation, Class/Activity/Test/Storage, Account pause/resume/closure and Organization capability management once a target Account is known.

**C additions:** narrow anonymous discovery grants; Google OAuth/continuation handling; durable phone-trust record/helpers; optional explicit Google-avatar import; contextual conversation-list projection; real notification production/context contract; optional structured closure-readiness projection.

**D additions:** Learner self-access invitation; Organization member invitation; and, only if approved, family-supporter relationship/permission matrix.

No evidence supports rebuilding the core Learner/Class/Enquiry/Test/Ads domain.

## One product decision required before final V1.3 freeze

Current frozen rule: one active managing guardian per Learner.

Audit recommendation: **keep exactly one manager, but allow optional narrower family supporters.**

If approved:

- rule: manager owns formal marketplace/relationship decisions; supporter is oversight/help only;
- relationship: add `support` (or equivalent) to learner access;
- lifecycle: existing `active|ended` remains sufficient;
- supporter may see permitted learning/oversight, receive relevant notifications, report concerns and optionally assist upload;
- supporter may not take Tests, post/close the Learner’s formal marketplace relationship, accept/decline Class Invitation, transfer/leave, grant self access or alter guardian authority;
- Class-thread audience, closure blockers, sibling isolation and support-ending tests must be updated.

This is the only frozen family rule this audit recommends reconsidering, and it must not be changed silently.

## Next gate after that decision

1. finalize this register and exact phone-trust action matrix;
2. rewrite the clickable prototype and end-user wording only;
3. run persona journeys, mobile/desktop and privileged/deep-link regression;
4. perform final UI ↔ DB reconciliation;
5. write exact C/D migration/RPC deltas;
6. extend Given/When/Then automation;
7. only then modify Supabase and the integrated frontend.

After the V1.3 UX/Product freeze, another platform doing something differently is not sufficient reason to reopen design. A later change requires a demonstrated contradiction, security/privacy issue, failed usability test, or real pilot-user evidence.
