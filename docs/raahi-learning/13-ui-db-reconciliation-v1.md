# Raahi Learning V1 — UI Prototype ↔ Database Reconciliation

Status: **REQUIRED BEFORE SUPABASE IMPLEMENTATION.**

Purpose: prove that the frozen UI behavior and the physical database/command design describe the same product.

This is a two-way audit:

1. **UI → DB:** every approved screen/action/state must be supported by data, permissions, commands and transactions.
2. **DB → UI:** every significant table/state/command must exist because the product actually needs it, not because technical design drifted beyond V1.

## Audit method

For each canonical screen/flow, record:

| UI surface/action | Required read data | Command | Preconditions/permission | Resulting state | Stale/double behavior | DB/projection support | Gap/action |
|---|---|---|---|---|---|---|---|

Then run reverse checks by module:

| DB concept | Real UI/product purpose | User-facing or internal | Necessary for V1? | Remove/defer/change? |
|---|---|---|---|---|

## Canonical flows to audit

### A. Identity / onboarding
- one Account may learn, teach, manage a Learner and represent an Organization;
- learner creation without learner login;
- parent/guardian acts **for Rahul**;
- self-access linked later without recreating learner history;
- avatar/photo behavior;
- selected Location preference;
- capability activation without permanent mutually exclusive role accounts.

### B. Learner self-discovery
**Home/Explore → search → Teacher/Institute → What I Teach → Save/Enquire → optional Trial → Class Invitation → Join → My Classes**

Challenge:
- public profile projection;
- availability and Location filtering;
- Save privacy;
- no relationship on profile view;
- Enquiry target ownership consistency;
- no Enrollment object hidden behind UI;
- invitation acceptance/capacity/idempotency.

### C. Parent/guardian for learner
**Explore/Post Request → choose “For Rahul” → Enquire → Trial if wanted → Invitation → Join Rahul → oversee Class**

Challenge:
- Account actor vs Learner owner;
- one managing guardian V1;
- parent-assisted Submission ownership;
- parent oversight versus Test impersonation;
- sibling separation under same Account.

### D. Learning Request
**Create → Open → teacher interest → Pending Enquiry → Active Enquiry → Close/Reopen**

Challenge:
- sanitized public projection;
- material edits create new Request;
- duplicate Open requests;
- existing Enquiries survive Request closure;
- no public learner profile leakage.

### E. Teacher/provider
**Create profile → What I Teach → Location availability → Teaching Opportunities → Enquiry → Class creation/invite → operate Class**

Challenge:
- individual versus Organization owner XOR;
- per-Teaching-Option availability;
- multiple Locations;
- responsible teacher per Class;
- provider cannot see private Saved users;
- public availability changes do not terminate Classes.

### F. My Classes / private learning
**My Classes → Class feed → Announcement/Question → Material → Session → Activity → Submission → Test**

Challenge:
- direct/offline joined learner has Class communication even without fake Enquiry;
- Class Membership is actual access boundary;
- copied URL/file path cannot bypass authorization;
- learner-specific contextual messaging;
- class-private projections;
- Past Class and end-reason access rules.

### G. Activity / Submission
**Open Activity → optional submission → Submit → Changes requested → resubmit → Reviewed**

Challenge:
- Activities without submission do not force Submission rows;
- one logical Submission per Learner/Activity;
- revisions preserve history;
- performer Account may differ from Learner owner;
- retry/idempotency does not duplicate revisions.

### H. Tests
**Upcoming/Available → Start → save answers → Submit → Results when visible**

Challenge:
- Upcoming derived from time, not extra lifecycle;
- parent cannot Start/Submit merely because they manage Learner;
- one logical Attempt V1;
- refresh/multiple tabs resume same Attempt;
- Test definition locks at first valid Attempt;
- result visibility independent from Test closure;
- post-lock answer-key correction is audited and recalculates safely.

### I. Class changes and exceptions
**Transfer / Leave / Remove / Complete / Mark Past**

Challenge:
- transfer atomically creates destination Membership and ends source as Transferred;
- no Enrollment teardown;
- capacity includes valid pending reservations;
- end reasons drive historical access policy;
- Block is not Leave Class;
- safety restriction can independently freeze access.

### J. Location switching
**Gomoh ↔ Dhanbad**

Challenge:
- selected Location changes Home/Explore/Community only;
- Classes, Enquiries, Saved, Messages/history remain;
- Location pause affects new local discovery/Ads without automatically deleting private learning.

### K. Community
**Local feed → Post/Comment/Reaction → Report/moderation**

Challenge:
- Location-scoped participation;
- no public downvotes;
- no private Class leakage;
- minor/student posting permissions are policy-driven rather than Adult/Minor entities;
- moderator scope by Location.

### L. Trust / safety / verification
**Report / Block / Verification badges / restrictions**

Challenge:
- Report does not mutate target automatically;
- exact verification claims only;
- restrictions are scoped by capability/Location rather than giant Account status;
- Block preserves history/evidence;
- student can report concern independently of marketplace permissions.

### M. Organizations
**Organization profile → authorized member → Teaching Options → Classes → Ads**

Challenge:
- Campaign/Class ownership survives employee removal;
- V1 does not become institute ERP;
- capability-based member authorization;
- one Organization identity rather than duplicated profiles.

### N. Local Manager
**Overview → People/Learning/Community/Reports/Location Settings/Ads review**

Challenge:
- all commands Location-scoped;
- no casual access to private Class/Submissions/Tests;
- conflict-of-interest escalation for Ads;
- local pause/readiness does not create cross-Location authority.

### O. Raahi Ads — advertiser
**Campaign objective → target Locations → package/inventory/date → creative → revision → evidence/review → commercial clearance → reservation → scheduled/live → analytics**

Challenge:
- campaign targets exist before placement;
- exact immutable Revision approval;
- commercial state separate from review;
- daily inventory buckets support multi-day packages;
- no partial silent reservation;
- anti-monopoly/concentration controls;
- one Campaign can serve different Locations independently;
- no full CRM/wallet/auction accidentally introduced.

### P. Raahi Ads — viewer
**Sponsored card/result → Open → Enquire/Learn More/Hide/Report**

Challenge:
- Sponsored label always available to renderer;
- viewing/opening does not expose user identity;
- Enquire reuses normal Enquiry model with attribution;
- Hide/frequency state remains private;
- no commercial Ads on protected learning surfaces.

### Q. Ads admin/review
**Review queue → exact Revision → evidence → approve/change/reject/escalate → placement control**

Challenge:
- stale review cannot approve newer Revision;
- Local Manager scope/conflict checks;
- Platform cross-Location review;
- serving_revision_id points only to approved exact Revision;
- pause reason retained because commercial consequences differ.

## Reverse DB → UI/product challenge

Review every table in `03-database-blueprint-v1.1.md` and ask:

1. Which approved user flow or invariant needs this?
2. Could it be a relationship/attribute instead of an entity?
3. Does it reintroduce something explicitly removed (Enrollment, Batch, Adult/Minor learner split, Trial relationship, Attendance, generic progress, public ratings, advertiser CRM)?
4. Is its lifecycle actually visible as different behavior?
5. Is it needed in V1 or only “might be useful someday”?

Any table failing this test is removed/deferred before migrations.

## Known prototype drift to ignore/correct

Generated visual prototypes sometimes showed:

- star ratings/reviews;
- Enrollment wording;
- `Book Class` style behavior;
- overbuilt Ads billing/payment screens;
- Adult/Minor account segmentation;
- generic progress/attendance numbers;
- old Market terminology;
- generic verified-teacher badges.

These are not requirements. Written frozen rules override them.

## Exit criteria

This gate passes only when:

- every approved CTA has exactly one canonical command or harmless local/read behavior;
- every displayed state can be derived from stored/authorized data;
- every screen has a secure read projection strategy;
- every important failure/stale state has a UI response;
- every DB lifecycle transition has a real business purpose;
- no removed complexity has re-entered through the schema;
- all gaps are reflected back into Product/Domain/Architecture/Schema/Command/Acceptance docs as required.

After passing, update `12-implementation-approval-v1.md` to **APPROVED FOR IMPLEMENTATION** and only then connect to Supabase.