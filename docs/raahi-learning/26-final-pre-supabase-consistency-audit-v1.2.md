# Raahi Learning V1.2 — Final Pre-Supabase Consistency Audit

Status: **PASS. NO BLOCKING CROSS-DOCUMENT CONTRADICTION REMAINS IN THE CURRENT V1.2 CONTRACT.**

This is the final document-level challenge before touching the target environment.

## Sources checked as current authority

- frozen Product / Domain / Architecture / Command / Acceptance / Ads rules;
- inspected UI inventory and freeze;
- consolidated physical DB blueprint V1.2;
- consolidated migration plan V1.2;
- final acceptance traceability;
- implementation runbook;
- Supabase execution checklist;
- implementation approval / handover.

Historical review/delta documents were treated as traceability, not competing current authority.

---

## Identity consistency — PASS

Consistent across UI/domain/DB/commands:

- Account ≠ Learner;
- one Account may learn, manage, teach and represent an Organization;
- no permanent role field;
- active manager owns formal learner-side marketplace decisions when present;
- self-access remains the basis for Test-taking learner actions;
- learner work/history remains Learner-owned;
- Account pause/closure cannot cascade-delete another actor's legitimate records.

No Adult/Minor entity split or turning-18 migration has reappeared.

---

## Location consistency — PASS

Current canonical lifecycle:

`interest_only → preparing → live ↔ paused → retired`

Consistent behavior:

- selected Location is preference/context only;
- Register Interest can operate before launch;
- full public discovery/community requires live state;
- changing selected Location does not hide Classes/Enquiries/Saved/history;
- Local Manager authority is explicitly Location-scoped.

---

## Discovery / Enquiry consistency — PASS

- no public Learner directory;
- browse Teaching Option and Learning Request routes converge to controlled Enquiry;
- Pending Enquiry does not grant ordinary messaging;
- Trial remains optional inside Enquiry;
- Saving creates no relationship/contact permission;
- public Learning Request is sanitized.

---

## Class / capacity consistency — PASS

One rule is now consistent everywhere:

> a valid Pending Class Invitation reserves its finite seat at **send time**.

Therefore:

- send is the capacity race;
- acceptance of that valid Pending Invitation consumes the already-reserved seat;
- duplicate acceptance creates one Membership;
- capacity floor includes Active Memberships + valid Pending Invitations;
- fee terms shown at Join come from Invitation snapshot;
- private share-code invite consumes code + creates Invitation atomically;
- Enrollment remains absent.

---

## Ongoing learning consistency — PASS

- Membership is Class access boundary;
- historical access derives from Membership end state;
- no Attendance subsystem;
- Session past state is time-derived;
- Activity unifies Assignment/Practice/Exercise;
- parent-assisted submission records performer separately from Learner owner;
- failed submission cannot be shown as Submitted before confirmation;
- Class completion is one atomic governed transition.

---

## Assessment consistency — PASS

- Test definition locks no later than first valid Attempt;
- one V1 Attempt per Learner/Test;
- Test-taking requires learner self-access, not guardian management authority;
- results visibility is separate from Test lifecycle;
- teacher feedback is private Attempt/result data;
- answer-key correction is explicit, audited and recalculates affected results;
- no generic overall progress metric exists.

---

## Safety / privacy consistency — PASS

- Report is a request for review, not proof of guilt;
- Block is separate from Leave Class;
- restrictions are scoped rather than one giant status;
- Local Manager does not get casual private learning access;
- privileged deep links require server-side scope authorization;
- copied Class/storage URL never grants permission;
- private share code is not a public Learner lookup mechanism.

---

## Ads consistency — PASS

- Sponsored and organic systems are architecturally separate;
- paid visibility cannot alter verification/endorsement/organic rank;
- Sponsored is surface-governed and excluded from protected learning/private messaging;
- Campaign review targets exact immutable Revision;
- Placement pins exact approved serving Revision;
- commercial clearance is independent from review;
- physical capacity is daily overlap-safe inventory;
- user-level frequency/hide records remain private from advertiser;
- reporting is aggregate and views/opens are not mislabeled as leads.

---

## DB dependency consistency — PASS

No known circular/invalid sequencing remains in the consolidated plan:

- Identity before Locations;
- selected Location preference after Locations;
- Organizations before scoped Organization restrictions;
- Enquiries before Ads, with Sponsored attribution added later;
- share-code table before generic offline invite flow is enabled;
- Classes before Activities/Tests;
- Ads Campaigns before Ads inventory/serving;
- full Account closure blocker expansion after downstream responsibilities exist.

---

## UI authorization consistency — PASS

The inspected UI may show workspace switching for usability, but the technical contract consistently states:

> navigation/workspace selection is never authorization.

Direct protected reads must still be denied when relationship/capability/scope is absent.

---

## Remaining configurable values — NOT BLOCKERS

These are deliberately configuration/policy rather than unresolved architecture:

- Class Invitation expiry duration;
- Learner share-code expiry;
- Ads hold duration;
- Ads frequency cap/window;
- Ads rate-card/package amounts;
- idempotency retention;
- notification retention;
- detailed Community posting eligibility;
- exact public copy/content for some moderation reasons.

They can be chosen/adjusted without changing the core data model.

---

## Environment-dependent items — CANNOT BE COMPLETED HONESTLY BEFORE SUPABASE INSPECTION

These are the only meaningful remaining unknowns:

- exact target Supabase project identity/current schema;
- existing migrations/legacy objects;
- enabled extensions;
- Auth/OTP configuration in that project;
- existing Storage buckets/policies;
- actual role/grant behavior in that project;
- live concurrency/RLS/storage test results.

They require the authorized environment and are therefore intentionally deferred.

---

# Final conclusion

The pre-Supabase package is internally coherent and complete enough to begin environment inspection.

There is no remaining product/UI/schema-planning task that should be invented merely to delay the next boundary.

**Do not touch Supabase until the user explicitly authorizes it; when authorized, inspect read-only first.**
