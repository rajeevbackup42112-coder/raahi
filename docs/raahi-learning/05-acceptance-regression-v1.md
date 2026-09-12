# Raahi Learning V1 — Acceptance & Regression Gates

Status: **Canonical behavioural test set. Updated after physical blueprint review v1.1.** These scenarios should become automated tests as implementation proceeds.

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

### Multiple capabilities on one Account
**Given** Amit learns Guitar and is also eligible to teach Maths  
**When** he uses both capabilities  
**Then** one Account supports both without a mutually exclusive permanent role.

## Discovery

### Browsing creates no relationship
**Given** Priya views a teacher profile  
**When** she leaves without Enquiring  
**Then** no Enquiry/contact permission is created.

### Saving is private
**Given** Priya Saves a teacher/profile/Teaching Option  
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

### Provider ownership consistency
**Given** a Teaching Option belongs to Amit  
**When** a command attempts to create an Enquiry that references the Option but names another provider  
**Then** the command is rejected.

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

### Sending an invitation reserves capacity
**Given** a Group Class has one unreserved seat remaining  
**When** the responsible Teacher successfully sends Rahul a V1 Class Invitation  
**Then** the Pending unexpired Invitation reserves that seat until accepted/declined/cancelled/expired.

### Cannot over-reserve by sending invitations
**Given** all remaining Class capacity is already occupied or reserved by valid Pending Invitations  
**When** Teacher attempts to send another seat-reserving Invitation  
**Then** the command fails and Class capacity remains valid.

### Accept invitation
**Given** valid Pending Invitation and its reserved capacity  
**When** authorized learner-side actor accepts  
**Then** exactly one Active Membership is created and Invitation becomes Accepted atomically.

### Double accept
**Given** acceptance succeeds but network retries  
**When** same logical command arrives again  
**Then** no duplicate Membership is created.

### Expired invitation releases seat
**Given** a Pending Invitation reaches its finite expiry  
**When** expiry is processed or a later command observes the expiry  
**Then** the seat is no longer reserved and stale acceptance cannot create Membership.

### Expired stale screen
**Given** Invitation expired after screen loaded  
**When** user presses Accept from stale screen  
**Then** command is rejected using current authoritative state.

### Last-seat race
**Given** only one capacity unit can still validly be reserved/consumed  
**When** two concurrent commands compete for it  
**Then** Class capacity is never exceeded.

### Capacity cannot be reduced below obligations
**Given** a Class has Active Memberships and unexpired Pending seat reservations  
**When** Teacher attempts to reduce capacity below that total  
**Then** the command is rejected until obligations are resolved.

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

## Private Class feed and contextual messaging

### Private Class post never leaks to Community
**Given** Teacher publishes an Announcement inside Rahul's Class  
**When** public/local Community feed renders  
**Then** the Class Post is not included merely because the Class and user share a Location.

### Offline learner can communicate without fake Enquiry
**Given** Rahul was invited directly as an existing offline learner and has no marketplace Enquiry with Teacher  
**When** Rahul joins the Class  
**Then** the permitted Class+Learner contextual thread can support learner-side/teacher communication without creating fabricated Enquiry history.

### Guardian remains in managed learner thread
**Given** Rahul has an active managing Parent/Guardian  
**When** Teacher sends a message in Rahul's Class+Learner thread  
**Then** the thread follows the learner-side visibility policy and cannot silently become an unrestricted hidden teacher↔student DM.

### Thread access follows current authority
**Given** an Account previously managed Rahul but management access ended  
**When** that Account attempts to read/send another Rahul thread message  
**Then** current authorization is rechecked and access is refused.

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

### First attempt locks definition
**Given** a published Test has no Attempts  
**When** Rahul successfully starts the first valid Attempt  
**Then** the Test definition becomes locked no later than that transaction.

### Structural edit after attempt is blocked
**Given** a valid Test Attempt exists  
**When** Teacher tries to change a question prompt, add/remove a choice, or otherwise alter Test structure through normal editing  
**Then** the edit is rejected.

### Answer-key correction is explicit
**Given** a Test is locked and an answer key is discovered to be wrong  
**When** authorized `correct_answer_key` is executed  
**Then** the correction is audited and affected evaluated Attempts are recalculated according to policy; ordinary edit paths remain blocked.

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

## Scoped safety restrictions

### Discovery-only restriction
**Given** Amit has a policy issue requiring removal from new discovery but no current Class-safety restriction  
**When** a `public_discovery` restriction is applied  
**Then** Amit disappears from relevant new discovery while existing Class Memberships are not automatically ended.

### Serious Class-access restriction
**Given** authorized safety reviewer identifies a serious credible concern  
**When** an explicit `class_access` or `messaging` restriction is applied  
**Then** affected access is blocked according to the restriction without relying on a generic Teacher status.

### Unrelated capability survives
**Given** an Account receives an Ads-only restriction  
**When** restriction becomes active  
**Then** unrelated learning history/Classes are not automatically destroyed unless another explicit restriction applies.

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

**Given** an Account may read Community but does not currently have posting capability  
**When** it attempts to publish  
**Then** publishing is rejected without needing a permanent Account role.

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

### Campaign targets exist before Placement
**Given** a Campaign requests Gomoh + Dhanbad Home Sponsored  
**When** it is submitted/reviewed before serving  
**Then** the system can determine requested Locations/placement scope without fabricating live Ad Placements.

### Overlapping package dates cannot double-sell capacity
**Given** daily Dhanbad Home capacity is fully reserved for Jan 4  
**When** one package requests Jan 1–7 and another requests Jan 4–10  
**Then** the second reservation cannot sell another unit for Jan 4 merely because the package date ranges differ.

### Inventory race
**Given** one Ads inventory unit remains on a required daily bucket  
**When** two advertisers reserve concurrently  
**Then** Held + Confirmed capacity never exceeds configured capacity.

### Stale availability
**Given** screen says one inventory spot remains but another advertiser consumes it  
**When** stale user attempts Reserve  
**Then** server rejects reservation and offers current alternatives.

### Exact revision review
**Given** reviewer opened Revision 1 and advertiser later creates Revision 2  
**When** reviewer acts on old screen  
**Then** decision can apply only to Revision 1 and must never approve Revision 2 implicitly.

### Exact serving revision
**Given** Revision 1 is Approved and serving while Revision 2 is Draft/Under Review  
**When** ad rendering occurs  
**Then** Placement renders Revision 1 and never selects Revision 2 merely because it is newer.

### Approved replacement
**Given** Revision 2 becomes Approved  
**When** authorized serving-revision switch succeeds  
**Then** Placement may begin serving Revision 2; the switch is explicit and current state is revalidated.

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

### Frequency control stays private
**Given** Raahi uses user-level serving state to prevent Priya seeing ABC School too frequently  
**When** ABC School opens analytics  
**Then** it receives only aggregate metrics and cannot see Priya's identity, frequency record, or Hide action.

### Multiple placement metrics remain distinguishable
**Given** one Campaign runs in both Home Sponsored and Explore Sponsored in Dhanbad  
**When** analytics are aggregated  
**Then** Placement-level daily metrics can be combined or broken down without conflating the two inventory products.

### Student learning surfaces ad-free
**Given** learner is using My Classes/Activity/Test/private Message surfaces  
**When** page renders  
**Then** no commercial Raahi Ads placement appears.

## File/storage regression gates

### Copied private file URL
**Given** Rahul can access a Class Material file and Aman cannot  
**When** Aman obtains the storage path/link  
**Then** current object authorization still denies access.

### Submission file visibility
**Given** Rahul submits a private file  
**When** another learner in the same Class attempts to fetch it  
**Then** the other learner cannot access Rahul's Submission unless a deliberate product rule grants it.

### Ad claim evidence remains private
**Given** advertiser supplies accreditation evidence for review  
**When** ordinary Raahi user opens the public Sponsored card  
**Then** private review evidence is not exposed unless specifically intended as public content.

## Cross-product regression checklist

Before release, prove that:

- removing Enrollment did not break join/transfer/history;
- siblings' learning cannot be mixed under one parent Account;
- parent assistance cannot reassign learning ownership;
- Location switch cannot hide existing Classes;
- public provider availability cannot terminate current learning;
- direct offline learner joining does not require fake Enquiry history;
- private Class posts/messages cannot leak into Community/public projections;
- Class capacity cannot be over-reserved through multiple Pending Invitations;
- Test definition cannot silently mutate after Attempts begin;
- scoped safety restrictions do not accidentally disable unrelated capabilities;
- Ads cannot change organic ranking or verification;
- Ads overlapping date packages cannot oversell the same physical inventory day;
- Ads serving cannot use an unapproved/latest Draft revision;
- advertiser cannot access named frequency/hide/view records;
- direct table writes cannot bypass command invariants;
- stale UI cannot exceed Class or Ads capacity;
- RLS/file access cannot be bypassed with copied URLs.
