# Raahi Learning V1.2 — Pre-Supabase Readiness Review

Status: **PASS — PRE-SUPABASE DESIGN/HANDOVER WORK COMPLETE.**

This review answers one question:

> Is there any meaningful product, UI, domain, permission, lifecycle, schema-planning, migration-planning, testing or handover work that should be completed before touching the target Supabase project?

Result: **No blocking design/documentation gap remains.**

Supabase has not been inspected or mutated as part of this review.

---

## 1. Product / actor / ownership gate — PASS

Completed and challenged:

- local-learning problem definition;
- adult/self learner, parent/guardian, learner/student, teacher/coach/instructor, Organization, Local Manager, Platform roles/capabilities;
- Account vs Learner ownership;
- parent acting **for** Learner without impersonation;
- one Account supporting learn/teach/manage/Organization capabilities;
- Location-first product model;
- Raahi Ads as a separate Sponsored system.

Removed complexity remains removed unless future evidence proves it necessary.

---

## 2. Business rules / lifecycle gate — PASS

Canonical journeys and states have been challenged through normal, stale, concurrent, malicious and exceptional scenarios.

Core learner journey:

**Find → Enquire → optional Trial → Class Invitation → Join Class → Learn**

No separate Enrollment stage exists.

Important state models are intentionally small:

- Learning Request: Draft → Open → Closed;
- Enquiry: Pending → Active → Closed;
- Class: Draft → Active → Past;
- Invitation: Pending → Accepted/Declined/Expired/Cancelled;
- Membership: Active → Completed/Left/Transferred/Removed;
- Activity: Draft → Open → Closed;
- Attempt: In Progress → Submitted → Evaluated/Invalidated;
- Location: interest_only → preparing → live ↔ paused → retired.

---

## 3. Real UI gate — PASS

A real clickable backend-free V1.1 prototype was built and inspected.

Artifact:

`Raahi_Learning_Clickable_UI_v1.1.zip`

Library path:

`/Raahi Learning/Raahi_Learning_Clickable_UI_v1.1.zip`

SHA-256:

`2c10cb4ef8e3cef8cced61d67806d595abac6427307b2ea0ada5fa925db8ce66`

Coverage:

- 77 canonical routes/pages;
- 154 desktop/mobile route checks, 0 issues;
- 32 privileged deep-link checks, 0 unguarded pages;
- 26 interaction/business-rule checks, 0 failures;
- 15 semantic/accessibility sanity samples, 0 issues.

The route inventory is frozen in `18-ui-page-inventory-v1.1.md`.

---

## 4. UI ↔ DB reconciliation gate — PASS

The real pages were run in both directions against the physical design:

### UI → DB

Every important displayed field/action/state has a planned data owner, secure read path, permission model and canonical write command.

### DB → UI/product

Schema concepts that lacked a real V1 product/invariant purpose were removed/deferred rather than retained as technical cleverness.

Real-page findings incorporated into the final design include:

- `interest_only` Location state;
- private one-time Learner share codes;
- Invitation fee snapshot;
- Test teacher feedback;
- guarded Account pause/resume/closure;
- strict deep-link/read authorization.

---

## 5. Consolidated physical-design gate — PASS

`19-consolidated-database-blueprint-v1.2.md` is now the single physical design source for new implementation work.

It removes the need to reconstruct the final model from older blueprint + delta precedence.

It contains all binding corrections from the schema review and both UI reconciliation passes.

---

## 6. Consolidated migration-plan gate — PASS

`20-consolidated-sql-migration-plan-v1.2.md` is the single migration sequence for new implementation work.

Key dependency risks previously found are resolved:

- selected Location created after Location tables;
- scoped restrictions created only after Organizations exist;
- Enquiries do not depend on Ads until Ads migration adds campaign attribution;
- Audit + Idempotency exist before consequential RPCs;
- Learner share-code table exists before generic offline invite flow is enabled;
- account-closure blockers are extended after downstream responsibilities exist;
- Ads physical inventory uses overlap-safe daily rows;
- exact approved Campaign Revision is pinned to serving Placement.

---

## 7. Authorization/RLS gate — PASS AS DESIGN

The architecture does not rely on frontend roles/navigation for authority.

Authorization consistently evaluates:

- acting Account;
- acting-for Learner where applicable;
- exact target object;
- relationship/capability granting authority;
- Organization scope;
- Location scope;
- active scoped restrictions;
- current server state.

Production deep links must remain safe even if frontend guards are bypassed.

`SECURITY DEFINER` functions must use fixed safe `search_path`, derive actor from `auth.uid()`, minimize privileges/results and explicitly revoke public/default execute.

Actual RLS behavior still requires execution testing once the target Supabase environment is authorized.

---

## 8. Concurrency/idempotency gate — PASS AS DESIGN

High-risk transaction boundaries are explicitly defined:

- Invitation capacity reservation occurs at **send** time;
- valid Pending Invitation already owns its reserved seat;
- share-code consumption + Invitation creation is atomic;
- Invitation acceptance creates exactly one Membership;
- Transfer is atomic across source/destination;
- Class completion is atomic with eligible Membership completion;
- Test first Attempt locks definition;
- Test Start/Submit are retry-safe;
- Ads inventory locks daily buckets deterministically and cannot oversell;
- exact Campaign Revision review/serving prevents stale-latest mistakes.

Actual database race testing remains an execution-phase requirement, not a pre-Supabase design blocker.

---

## 9. Privacy/security boundary gate — PASS AS DESIGN

Explicit boundaries exist for:

- public/sanitized discovery;
- relationship-private Enquiries/Invitations;
- Class-private content;
- moderation-private data;
- commercial-private Ads data;
- private storage authorization.

No public Learner directory exists.

Saved items do not notify the saved party.

Sponsored views/opens/hides do not expose named viewers to advertisers.

Copied Class or storage URLs never grant access by themselves.

---

## 10. Ads gate — PASS

Ads is intentionally separate from organic ranking/trust.

Frozen rules include:

- always visibly Sponsored;
- education-relevant V1 scope;
- finite Location × placement × day inventory;
- no oversell;
- no category exclusivity/monopoly shortcut;
- exact immutable creative Revision review;
- Commercial Clearance separate from policy approval;
- no named viewer CRM;
- aggregate analytics;
- surface-based exclusion from private learning/message surfaces;
- no paid verification/endorsement/organic rank.

---

## 11. Handover/durability gate — PASS

Canonical documents are in GitHub branch:

`raahi-learning-v1-docs`

Canonical folder:

`docs/raahi-learning/`

The inspected prototype is persisted separately in the user's Library with recorded checksum.

`99-handover.md`, repository `README.md`, top-level `RAAHI_LEARNING_HANDOVER.md` and GitHub Issue #1 are the durable continuation points.

---

## 12. What is intentionally NOT completed before Supabase

The following are not missing design work; they require the actual target environment and therefore belong to the next phase:

- inspect existing target Supabase projects/schemas/config;
- verify enabled extensions/roles/storage/auth behavior in that project;
- create versioned SQL migrations against the chosen project;
- execute RLS/RPCs;
- run real transaction/concurrency tests;
- validate actual Storage policies and signed/private URL behavior;
- connect the production frontend to live projections/RPCs;
- production deployment.

These should **not** be simulated as completed without the target environment.

---

# Final readiness decision

**PRE-SUPABASE WORK IS COMPLETE.**

The project is ready to cross the environment boundary when the user chooses.

The first action after authorization is not “build the whole database.” It is:

1. inspect the target Supabase project/environment without mutating it;
2. compare existing state with the V1.2 contract;
3. implement only Foundation + Identity through versioned migration files;
4. run its migration/RLS/RPC/idempotency/authorization tests;
5. stop on any failure before proceeding to Locations.
