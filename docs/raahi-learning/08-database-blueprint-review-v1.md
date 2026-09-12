# Raahi Learning V1 — Physical Database Blueprint Review

Status: **REVIEW COMPLETE. Original `03-database-blueprint-v1.md` does not yet pass the Supabase gate.**

This review challenged the first physical blueprint against the frozen Product/UI rules, Domain Model, Architecture, Command Matrix, Acceptance tests, and Raahi Ads rules.

The overall relational/modular direction is sound. No removed product concept such as Enrollment, Batch, Adult/Minor Learner split, or a separate Trial relationship needs to return. However, several physical omissions could violate frozen behaviour if implemented as written.

## Verdict

**Do not deploy `03-database-blueprint-v1.md` as-is.**

A corrected blueprint is written separately as `03-database-blueprint-v1.1.md`. The findings below explain why each correction exists.

---

## Blocking findings

### 1. Private Class communication was missing

Frozen UI behaviour includes Class updates/announcements/questions and contextual Parent/Learner ↔ Teacher communication. The first schema had Enquiry messages but no reliable communication path for an existing offline learner who joins a Class without an Enquiry.

That would either force fake Enquiry history or leave the user-facing `Messages`/Class discussion behaviour unimplemented.

**Correction:** add:

- `class_posts` / `class_post_comments` for private Class updates, announcements and permitted questions/discussion;
- one `class_learner_thread` per Class + Learner plus messages for contextual learner-side/guardian ↔ responsible-teacher communication.

This is an implementation of already-frozen behaviour, not a new relationship layer.

### 2. Scoped safety/platform restrictions were missing

The architecture deliberately rejected a single giant `teacher_status`. Public discovery, new Enquiries, Community, Class access, messaging and Ads may need to be restricted independently.

The first schema had profile visibility and Ads eligibility but no general way to represent scoped precautionary restrictions.

**Correction:** add scoped `access_restrictions` with explicit subject, capability/surface scope, optional Location scope, reason and lifecycle. Safety commands remain audited.

### 3. Ads had no explicit requested target Locations before serving

Campaign review scope and inventory selection must know which Locations the advertiser requested before Ad Placements exist. The first schema jumped from Campaign to inventory/placement without a clean requested-target relationship.

**Correction:** add `ad_campaign_targets` for requested Location + placement type. Cross-Location review can then be determined before serving.

### 4. Ads inventory time windows could overlap and oversell

`ad_inventory_windows(location, placement, window_start, window_end)` with uniqueness only on the exact range does not prevent overlapping windows such as Jan 1–7 and Jan 4–10 from each selling full capacity.

That violates the invariant that inventory can never be oversold.

**Correction:** physically represent capacity with non-overlapping daily buckets:

`Location × Placement Type × Inventory Date × Capacity`.

A multi-day reservation atomically claims each required daily bucket. Packages may still be sold as 7/14/30-day products; the physical capacity model remains overlap-safe.

### 5. Serving was not pinned to an exact approved Campaign Revision

A Campaign may have Revision 1 approved while Revision 2 or 3 is being edited/reviewed. The first `ad_placements` table did not record which immutable approved revision was actually being served.

Without an explicit pointer, a query based on “latest revision” could accidentally display unapproved content.

**Correction:** every live/waiting Ad Placement references the exact `serving_revision_id`. Changing serving creative is a governed command and the referenced revision must be approved.

### 6. Per-user Ads frequency control could not be implemented

The product freezes frequency/experience limits across placements, while advertiser analytics must remain aggregate. `ad_metrics_daily` alone cannot prevent one user from repeatedly seeing the same campaign.

**Correction:** add a private operational frequency state keyed to viewer Account + Campaign (or equivalent privacy-preserving serving key). It is never exposed to advertisers and should have retention/cleanup rules.

### 7. Test definition immutability was not enforceable

The first schema allowed questions/choices to be edited even after a learner had started an Attempt. That could rewrite the meaning of completed/in-progress assessment data.

Frozen rules require structure to lock after the first valid Attempt and answer-key corrections to use an explicit audited path with result recalculation.

**Correction:** lock Test structure when the first Attempt starts. Prompt/question/choice structure becomes immutable. Correct-answer changes occur only through the canonical audited `correct_answer_key` command.

### 8. Class Invitation seat reservation semantics were ambiguous

The first schema had both `expires_at` and `seat_reserved_until`, allowing indefinite or inconsistent reservations. Frozen V1 behaviour says finite-capacity Invitations reserve a seat until accepted/declined/expired.

**Correction:** in V1, every Pending Class Invitation has a finite `expires_at`; that Pending invitation itself is the seat reservation. Remove the second reservation timestamp. Sending/accepting/cancelling/expiring an Invitation must protect capacity atomically.

### 9. Capability/permission storage was incomplete

The architecture is capability + relationship based, not a permanent Account role. Some unscoped capabilities—teaching eligibility, public Community posting eligibility, platform/safety/verifier/commercial privileges—cannot be represented by Account↔Learner or Organization/Location relationships alone.

**Correction:** add a small `account_capabilities` mechanism for explicit unscoped capabilities. Organization and Location scope still come from their relationship tables.

This avoids reintroducing a giant `role` field.

---

## Important non-blocking corrections

### Learner avatar/photo

A Learner can exist without an Account, yet the frozen UI supports built-in avatar or optional photo. Therefore learner visual identity cannot live only on `accounts`.

**Correction:** Learner also stores avatar type/reference. Public projections must continue to protect child imagery.

### Current selected Location

Selected Location changes discovery/community context but not relationships. Persisting it on Account is a UI preference, not a domain lifecycle.

**Correction:** allow nullable `selected_location_id` (or equivalent preference record) on Account. Anonymous pre-login selection may remain client-side.

### Saving a teacher profile

Frozen behaviour describes saving a teacher/institute, not only a specific Teaching Option.

**Correction:** include `saved_teacher_profiles` in addition to saved Teaching Options/Organizations.

### Community reactions

A physical schema should avoid a nullable polymorphic `post_id OR comment_id` if easy FK-safe alternatives exist.

**Correction:** separate `community_post_reactions` and `community_comment_reactions`.

### Ads targeting context

V1 targeting includes selected Location(s), broad adult audience context and optional education category/goal.

**Correction:** Campaign stores one simple V1 `audience_context` and optional `education_category`; no behavioural audience-builder entity is introduced.

### Ads analytics dimension

A Campaign may buy multiple placement types in one Location. Daily metrics keyed only by Campaign + Location cannot distinguish them.

**Correction:** aggregate metrics by `ad_placement_id + metric_date`; campaign/location totals are derived.

### Notifications need learner context

A parent may receive a notification about Rahul while also learning for themselves.

**Correction:** notifications may carry nullable `context_learner_id` so UI can say “For Rahul” without changing ownership.

### Audit actor may be System

Some valid transitions happen from system timeout/expiry logic.

**Correction:** audit supports Account or System actor semantics rather than requiring a human actor for every record.

---

## Design choices deliberately retained

The review found no reason to restore:

- Enrollment;
- Batch entity;
- Adult vs Minor Learner entities;
- turning-18 migration;
- Trial as a major relationship object;
- separate Assignment and Practice domain models;
- Attendance;
- generic Progress percentage;
- public Learner directory;
- Ads viewer/lead directory;
- global Community.

The following first-draft choices remain valid:

- Account separate from Learner;
- one active managing Parent/Guardian per Learner in V1;
- one responsible teacher per Class;
- Class Invitation separate from Membership;
- Activity + Submission revisions;
- Test + Attempt separation;
- Location-scoped Local Manager authority;
- exact Verification claims;
- Campaign Revision + Review separation;
- Commercial Clearance separate from approval;
- aggregate advertiser analytics;
- command/RPC ownership for consequential writes;
- RLS as defense in depth, not the only business-rule engine.

---

## Supabase gate after review

The database may move toward SQL migrations only after the corrected blueprint is checked for the following:

1. every frozen UI function has a physical home;
2. every consequential transition has a canonical command owner;
3. Class capacity and Ads capacity are transactionally enforceable;
4. parent-assisted actions preserve Learner ownership;
5. copied URLs cannot bypass row/file authorization;
6. Test definition cannot mutate under existing Attempts;
7. Ad serving can never select an unapproved revision;
8. per-user Ads frequency controls stay private from advertisers;
9. scoped safety restrictions do not collapse into one Account/Teacher status;
10. no intentionally removed product concept has returned.

`03-database-blueprint-v1.1.md` incorporates these corrections and is the next schema-review artifact.