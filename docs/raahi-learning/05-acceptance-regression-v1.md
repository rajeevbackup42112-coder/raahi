# Raahi Learning V1 — Acceptance & Regression Gates

Status: **Canonical behavioural test set.** These scenarios should become automated tests as implementation proceeds.

## Identity & learner ownership

### Parent creates learner
**Given** Neha manages Rahul and Rahul has no login  
**When** Neha creates Rahul as a learner  
**Then** one Rahul Learner exists and Rahul does not require a separate Account.

### Learner later gets own login
**Given** Rahul already has Classes/history  
**When** Rahul receives self-access  
**Then** the Account links to the same Learner and existing history is preserved.

### Parent assists submission
**Given** Ananya completes work on paper  
**When** her mother uploads it  
**Then** the Submission belongs to Ananya while Raahi may audit who performed the upload.

## Discovery

### Browsing creates no relationship
**Given** Priya views a teacher profile  
**When** she leaves without Enquiring  
**Then** no Enquiry/contact permission is created.

### Saving is private
**Given** Priya Saves a Teaching Option  
**When** the provider uses Raahi  
**Then** the provider is not told Priya saved it.

### Location changes discovery only
**Given** Priya has active Classes/Enquiries and selected Gomoh  
**When** she changes Location to Dhanbad  
**Then** Explore/Community change to Dhanbad while Classes, Enquiries, Saved items, Messages and history remain.

## Learning Requests

### Duplicate active Request
**Given** Rahul already has an Open Maths Request in Gomoh  
**When** an authorized parent attempts an essentially identical active Request  
**Then** Raahi warns/prevents duplicate publication.

### Material edit
**Given** Request is for Rahul's Maths  
**When** user tries changing it to Ananya's Drawing  
**Then** a new Request is required rather than rewriting the existing context.

### Close Request
**Given** Request is Open  
**When** learner-side actor closes it as “Found what I needed”  
**Then** no new teacher interest may originate from the Request, while existing Enquiries remain.

## Enquiries

### Direct Enquiry
**Given** Priya views Amit's valid Teaching Option  
**When** she taps Enquire  
**Then** one Pending Enquiry exists.

### Provider engagement
**Given** Enquiry is Pending  
**When** provider engages  
**Then** Enquiry becomes Active and contextual messaging permission opens.

### Multiple legitimate providers
**Given** Priya is considering two Guitar teachers  
**When** she Enquires with each  
**Then** two independent Enquiries may coexist.

## Trial

**Given** an Active Enquiry  
**When** both sides agree to a Trial  
**Then** the Trial can be scheduled inside that Enquiry without creating a new relationship layer.

**Given** no Trial happens  
**When** both sides wish to proceed  
**Then** Class Invitation is still allowed.

## Class Invitations & capacity

### Accept invitation
**Given** valid Pending Invitation and available/reserved capacity  
**When** authorized learner-side actor accepts  
**Then** exactly one Active Membership is created and Invitation becomes Accepted atomically.

### Double accept
**Given** acceptance succeeds but network retries  
**When** same logical command arrives again  
**Then** no duplicate Membership is created.

### Expired stale screen
**Given** Invitation expired after screen loaded  
**When** user presses Accept from stale screen  
**Then** command is rejected using current authoritative state.

### Last-seat race
**Given** one seat remains and two valid acceptances occur concurrently  
**When** both commands execute  
**Then** Class capacity is never exceeded; only the valid winner creates Membership.

## Class Membership

### Same subject with multiple teachers
**Given** Rahul studies Maths with Teacher A  
**When** he legitimately joins Olympiad Maths with Teacher B  
**Then** both Memberships may be Active.

### Transfer
**Given** Rahul is Active in Saturday Class  
**When** authorized transfer to Sunday Class succeeds  
**Then** destination Membership becomes Active and source becomes Transferred atomically.

### Forwarded Class URL
**Given** Aman has no Membership  
**When** Rahul sends Aman a Class URL  
**Then** Aman cannot access private Class content.

### Membership revoked while page open
**Given** Rahul's Membership ends  
**When** old browser tries another protected operation  
**Then** authorization is rechecked and access is refused.

## Activities

### Activity without submission
**Given** Guitar Practice has `submission_required=false`  
**When** learner opens it  
**Then** Raahi does not force a file/text submission.

### Submission retry
**Given** learner submitted work and client retries  
**When** same logical submission command repeats  
**Then** accidental duplicate current submissions are not created.

### Changes requested
**Given** teacher requests a revision  
**When** learner resubmits  
**Then** latest revision becomes current while meaningful prior revision history remains.

## Tests

### Upcoming derived state
**Given** Test opens tomorrow  
**When** learner views it today  
**Then** UI may show Upcoming based on time without requiring a separate business lifecycle state.

### Start Test retry
**Given** Test is available  
**When** Start is repeated/refreshed  
**Then** the same valid In Progress Attempt is resumed rather than creating accidental attempts.

### Double submit
**Given** Attempt is Submitted  
**When** Submit repeats  
**Then** exactly one Submitted outcome remains.

### Parent cannot impersonate test-taking
**Given** Neha manages Rahul  
**When** Neha views Rahul's Test area  
**Then** management access alone does not grant Start/Submit Test permission.

### Result visibility
**Given** Test is Closed and results hidden  
**When** learner opens Test  
**Then** results remain hidden until authorized result visibility is enabled.

## Provider availability vs existing learning

**Given** Amit has active learners  
**When** Teaching Option becomes “Not taking new learners”  
**Then** current Classes remain unchanged.

**Given** a Teaching Option is no longer publicly offered  
**When** existing Class is still Active  
**Then** Class continues unless separately ended/restricted.

## Safety, block and reports

### Student report
**Given** learner has a safety concern  
**When** learner uses Report  
**Then** reporting is allowed independently of normal marketplace/guardian communication permission.

### Report is not guilt
**Given** one or many Reports exist  
**When** moderation reviews target  
**Then** report volume alone does not automatically prove wrongdoing.

### Block is not Leave Class
**Given** learner blocks teacher while Class remains Active  
**When** Block takes effect  
**Then** Raahi does not silently rewrite Membership; stronger safety separation uses explicit safety action.

## Community

**Given** private Class content exists  
**When** Community feed renders  
**Then** private Class content never appears merely because author/learner shares a Location.

## Ads regression gates

### Sponsored label
**Given** paid placement renders  
**When** user sees it  
**Then** `Sponsored` is clearly visible.

### Organic isolation
**Given** a teacher/institute buys Ads  
**When** organic results are ranked  
**Then** payment does not modify organic relevance ranking.

### Viewing is anonymous to advertiser
**Given** Priya sees/opens Sponsored content  
**When** no explicit Enquiry is sent  
**Then** advertiser receives no individual viewer identity.

### Explicit Sponsored Enquiry
**Given** Priya deliberately sends Enquiry from Sponsored content  
**When** command succeeds  
**Then** normal Enquiry system is used with Sponsored source attribution.

### Inventory race
**Given** one Ads inventory unit remains  
**When** two advertisers reserve concurrently  
**Then** held + confirmed capacity never exceeds configured capacity.

### Stale availability
**Given** screen says one inventory spot remains but another advertiser consumes it  
**When** stale user attempts Reserve  
**Then** server rejects reservation and offers current alternatives.

### Exact revision review
**Given** reviewer opened Revision 1 and advertiser later creates Revision 2  
**When** reviewer acts on old screen  
**Then** decision can apply only to Revision 1 and must never approve Revision 2 implicitly.

### Payment cannot override policy
**Given** Commercial Clearance is Cleared but Revision is Rejected  
**When** scheduled time arrives  
**Then** Ad does not run.

### Approval cannot override commercial state
**Given** Revision is Approved but Commercial Clearance Pending  
**When** scheduled time arrives  
**Then** Ad does not run.

### Per-Location serving
**Given** Campaign targets Gomoh and Dhanbad  
**When** Gomoh Placement pauses  
**Then** Dhanbad may remain Live.

### Student learning surfaces ad-free
**Given** learner is using My Classes/Activity/Test/private Message surfaces  
**When** page renders  
**Then** no commercial Raahi Ads placement appears.

## Cross-product regression checklist

Before release, prove that:

- removing Enrollment did not break join/transfer/history;
- siblings' learning cannot be mixed under one parent Account;
- parent assistance cannot reassign learning ownership;
- Location switch cannot hide existing Classes;
- public provider availability cannot terminate current learning;
- private Class content cannot leak into Community/public projections;
- Ads cannot change organic ranking or verification;
- direct table writes cannot bypass command invariants;
- stale UI cannot exceed Class or Ads capacity;
- RLS/file access cannot be bypassed with copied URLs.
