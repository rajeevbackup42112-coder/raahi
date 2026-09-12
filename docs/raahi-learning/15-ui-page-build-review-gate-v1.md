# Raahi Learning V1 — UI Page Build & Review Gate

Status: **REQUIRED BEFORE FINAL DB RECONCILIATION AND SUPABASE IMPLEMENTATION.**

The project is returning to an explicit UI-first validation step before database execution.

The previous image prototypes helped discover product behavior, but generated images are not sufficiently precise to serve as the final implementation contract. Before Supabase, Raahi Learning should have an inspectable, clickable UI prototype built from the frozen product rules, using hard-coded/demo data only.

## Required sequence

1. **UI page inventory** — enumerate every V1 page, modal, drawer and important state.
2. **Build clickable UI pages** — real frontend pages/components with hard-coded fixture data; no Supabase/database integration.
3. **Journey inspection** — walk all actor journeys end to end.
4. **Screen-state inspection** — inspect happy, empty, loading, validation, stale, denied, unavailable, ended and safety states where relevant.
5. **Permission inspection** — verify the same page behaves correctly for self learner, managing parent, teacher, organization member, Local Manager and platform/admin capabilities without creating separate products.
6. **Responsive/accessibility inspection** — mobile-first plus desktop/tablet sanity; labels and CTAs must be understandable without internal domain jargon.
7. **UI behavior freeze v1.1** — record final pages, actions, states and copy after inspection.
8. **UI ↔ DB reconciliation** — run the final inspected UI against the physical DB/command design. Every displayed field/action/state must map to data, secure projection, permission and canonical command. Every DB table/state must prove a UI/product/invariant purpose.
9. **Revise DB/SQL plan if needed.**
10. **Only then approve Supabase implementation.**

## UI prototype rules

- Use hard-coded fixtures and deterministic scenarios; do not create temporary DB tables merely to make screens work.
- UI may simulate transitions locally for prototype inspection, but any simulated business transition must be tagged/mapped to its future canonical command.
- Written frozen product rules remain authoritative over old generated images.
- Do not reintroduce Enrollment, Batch, Adult/Minor learner identities, turning-18 lifecycle, attendance, generic progress %, public ratings/reviews, public learner directory, global Community, multi-teacher Class or tuition-payment collection.
- Ads remain clearly Sponsored and excluded from My Classes, Activities, Tests and private Messages.
- Parent acts **for** the Learner; learner ownership is never transferred to the parent.

## Minimum canonical page set

### Shared / identity
- Welcome / login / OTP shell
- first-use intent selection (“What would you like to do first?”)
- account/profile settings
- learner management (“My learning”, Rahul/Ananya contexts)
- avatar/photo picker
- Location selector
- Location unavailable / Register Interest
- Saved items
- Notifications

### Learner / parent discovery
- Home
- Explore/search/results
- Teacher profile
- Organization profile
- What I Teach detail
- Enquiry compose/confirmation
- Enquiry conversation
- optional Trial event states
- Learning Request create/edit/view/close/reopen
- teacher-interest response to Request
- Class Invitation
- Join success / stale / expired / capacity-unavailable states

### Ongoing learning
- My Classes
- Class home/feed
- Announcement/question/update detail
- Materials
- Sessions
- Activity detail
- Submission / Changes Requested / Reviewed
- Test Upcoming/Available/In Progress/Submitted/Results
- learner-specific Class communication
- Transfer Class
- Leave Class
- Past Class / historical-access states
- Report concern / Block / safety restriction messaging

### Teacher / organization
- teacher profile editor
- What I Teach list/create/edit/availability
- Teaching Opportunities
- Enquiry handling
- Class create/manage
- invite learner
- Class members
- Activity/Test/Material creation
- Organization profile/member-capability surfaces needed for V1

### Community / local operations
- Location Community feed
- post/comment/reaction/report states
- Local Manager overview
- local people/learning/community/reports/location settings
- Ads review entry where permitted

### Raahi Ads
- advertiser eligibility/onboarding
- Campaign list/create
- objective + Locations + placement + dates/package
- inventory availability/hold failure
- creative/revision
- evidence/review states
- Commercial Clearance state
- per-Location placement status
- aggregate analytics
- Sponsored viewer card/result/detail
- Hide / Report / Enquire from Sponsored content
- Ads admin/review queue and exact-revision review

## Inspection questions for every page

For each page/state answer:

1. What does the user need to know here?
2. What can they do?
3. What must they not see/do?
4. Whose data is this (Account, Learner, Organization, Location, Class, Campaign)?
5. What happens after every CTA?
6. What if the state changed since the screen loaded?
7. What if the user taps twice/retries?
8. What if permission is lost while the page is open?
9. What is the empty/error/unavailable state?
10. Does the page accidentally imply a business concept we removed?

## Final reconciliation output

After the real UI pages are inspected, update `13-ui-db-reconciliation-v1.md` with page-level mappings and produce a final implementation approval. Until then, Supabase remains untouched.