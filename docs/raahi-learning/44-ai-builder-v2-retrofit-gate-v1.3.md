# Raahi Learning V1.3 — AI Builder Cheat Code v2 Retrofit Gate

Status: **ACTIVE EXECUTION GATE — DO NOT RESTART THE PRODUCT OR CONTINUE RANDOM BUG FIXING.**

## 1. Decision

Raahi Learning will **not** return to Gate 0 and redesign the product from scratch.

The existing domain work remains authoritative unless the retrofit discovers a concrete contradiction, security/privacy defect, failed usability evidence, regulatory requirement, pilot evidence, or proven technical impossibility.

Raahi Learning will also **not** continue as an open-ended bug-fixing exercise.

Instead, the project now enters a one-time **AI Builder Cheat Code v2 retrofit** to close the execution layers that the original process underweighted:

1. technology proof;
2. Screen ↔ Backend contracts;
3. read/write permission symmetry;
4. side-effects completeness;
5. one real walking-skeleton E2E journey;
6. vertical-slice implementation for all remaining work;
7. adversarial/persona regression before launch readiness.

The objective is a robust free-to-use platform, not zero-defect theatre. Defects found in DEV are acceptable evidence that gates are working; changing product rules merely to remove failing tests is not.

---

## 2. What is already strong and remains frozen

The following areas were deeply designed and have held through implementation:

- Account ≠ Learner;
- one Account may learn, teach, manage a Learner and represent an Organization;
- one managing guardian in V1;
- no turning-18 migration;
- no public Learner directory;
- controlled Enquiry before unrestricted relationship messaging;
- optional Trial;
- Pending Class Invitation reserves capacity;
- one Class model for 1:1 and group learning;
- learner-side authority for Class acceptance/transfer/leave;
- parent cannot impersonate Learner for Tests;
- Activity/Test lifecycles and history rules;
- education-only governed Ads isolated from private learning;
- PostgreSQL is operational source of truth;
- UI never directly mutates core operational tables;
- canonical RPCs re-check current authority and state;
- Realtime only invalidates/refetches;
- private Storage re-checks current authorization;
- idempotent consequential commands;
- no public ratings, attendance or generic progress percentage in V1.

Do **not** reopen these merely because another product implements a different UX.

---

## 3. Defect classification rule

Before fixing any significant failure, classify it:

### A. Domain defect
The rules/entities/relationships/states cannot represent a legitimate required scenario safely.

**Action:** stop and run impact analysis:
`rules → entities → relationships → states → permissions → UI → tests → architecture/DB`.

### B. Integration defect
Two individually valid layers do not connect correctly.

Examples already found in Raahi:
- Class creation authority could not populate the responsible-teacher selector;
- modal actions rendered outside the event-delegation boundary;
- Notifications projection existed but transitions did not generate notifications.

**Action:** fix the contract/integration. Do not redesign the domain.

### C. Implementation defect
The agreed contract is correct but code does not implement it correctly.

**Action:** patch the smallest vertical slice and run regressions.

### D. Test/harness defect
The product behavior is correct but fixture, route inventory, assertion or test harness is stale/wrong.

**Action:** fix the test. Never weaken a business invariant to make the test pass.

Every future defect must receive one of these classifications before a product-rule change is considered.

---

## 4. Retrofit Gate R1 — Technology proofs

### Already proven sufficiently

- PostgreSQL canonical RPC/state model;
- RLS/privilege separation;
- idempotency behavior;
- capacity/invitation transactional logic;
- governed Storage authorization;
- notification derivation mechanics;
- private bearer-token invitation patterns;
- server-derived phone-trust projection from Supabase Auth data in DEV.

### Still requiring real external proof

1. **Google OAuth**
   - real Google provider enabled in Supabase DEV;
   - browser round trip succeeds;
   - `auth.users` identity resolves to exactly one Raahi Account;
   - logout/login preserves same Account;
   - Google name/photo remain onboarding defaults, not authority;
   - wrong-Google-account and account-link/recovery behavior is tested.

2. **Phone verification / refresh**
   - DEV SMS/test-OTP configuration exists outside Raahi code;
   - signed-in Account can attach/verify phone;
   - periodic same-phone OTP refresh updates server-owned Auth confirmation evidence;
   - the browser resumes the interrupted command after successful proof;
   - no fake OTP bypass exists in Raahi.

**Gate R1 cannot be marked PASS until the real browser/Auth round trips exist.**

---

## 5. Retrofit Gate R2 — Complete Screen ↔ Backend Contract Matrix

Before further broad implementation, every actionable V1.3 screen must have an explicit contract:

`Screen → data needed → read RPC/projection → read authority → CTA → write RPC → write authority → resulting state → refetch → destination → recovery`.

For each of the 83 canonical routes, record at minimum:

- route/workspace;
- actor/context;
- source projection(s);
- required relationship/capability;
- command(s), if any;
- idempotency requirement;
- success destination;
- stale/conflict recovery;
- notification/deep-link consequences;
- file/Storage consequences;
- empty/error/offline state.

### Mandatory symmetry question

For every write:

> **If this actor may perform the write, can the actor legitimately read every input necessary to perform it?**

A write permission without the minimum safe read projection is an incomplete feature contract.

**Gate R2 PASS:** every actionable route is traceable and no unresolved read/write symmetry gap remains.

---

## 6. Retrofit Gate R3 — Side-Effects Matrix

Every consequential transition must explicitly answer:

- who is notified?
- who must not be notified?
- notification count/deduplication;
- notification destination/deep link;
- audit event;
- Storage/file impact;
- background/expiry job impact;
- analytics/aggregate event, if needed;
- external message/email/SMS, if any;
- whether side-effect failure may roll back the main business transition.

Rules:

- private message bodies are not copied unnecessarily into notifications;
- Ads never create prohibited promotional notifications;
- delivery failure does not undo a committed core state change unless the business rule explicitly requires atomic delivery;
- initial action + its initial message must not create duplicate attention alerts;
- notifications never grant authority.

**Gate R3 PASS:** every core transition has an explicit side-effect decision, including explicit `none` where appropriate.

---

## 7. Retrofit Gate R4 — Mandatory walking skeleton

Before any more broad backend expansion, execute one **real** end-to-end journey across actual boundaries.

### Chosen Raahi Learning walking skeleton

Use synthetic DEV identities only.

**Learner/guardian side**
1. Google sign in.
2. `bootstrap_account` resolves/creates exactly one Raahi Account.
3. First-use intent creates/selects the Learner context.
4. Authorized discovery/read projection loads.
5. Send Enquiry through canonical RPC.

**Provider side**
6. Provider signs in as a distinct real Auth identity.
7. Provider sees the Enquiry through authorized projection.
8. Provider engages/responds.
9. Provider sends Class Invitation.

**Learner side**
10. Learner-side Account receives Notification/deep link.
11. If phone trust is stale/missing, the intended acceptance is preserved.
12. Real phone verification completes.
13. Invitation acceptance resumes and re-checks current server state/capacity/authority.
14. Class membership is created.
15. Both sides can open the Class through authorized projections.
16. One Class contextual message is exchanged.

### Walking-skeleton evidence required

- actual browser;
- actual Supabase Auth session;
- actual RPCs;
- actual PostgreSQL state;
- actual projections;
- actual notification/deep link;
- no direct operational-table DML;
- no fixture-mode business result substituted for a live layer.

**Gate R4 PASS:** the entire journey works end-to-end on DEV and survives refresh/logout/login where relevant.

---

## 8. Retrofit Gate R5 — From now on, vertical slices only

After R4, remaining work is implemented slice-by-slice. A slice is not complete until all layers pass:

`database/state → canonical command → projection → permissions → side effects → UI → browser action test → DB/runtime test → old regression suite`.

Do not build multiple backend modules first and postpone their UI integration.

Recommended remaining slices:

1. Google Auth + Account bootstrap/profile defaults;
2. phone attach/reverify + trust interruption/resume;
3. first-use intent/context creation;
4. Learner self-access private invitation flow;
5. Organization staff invitation + responsible-teacher selection;
6. contextual Messages + Notifications/deep links;
7. remaining teacher/institute/community/Ads/admin action wiring;
8. Storage/browser file-transfer E2E;
9. account closure/recovery/security journeys.

Each slice must leave the full previously-passed regression suite green before the next begins.

---

## 9. Retrofit Gate R6 — Persona and adversarial E2E

After vertical slices are closed, execute whole stories rather than page checks only.

Minimum personas/conditions:

- brand-new adult learner;
- parent with one Learner;
- parent with multiple Learners;
- Learner without own login;
- Learner gaining self-access later;
- teacher;
- teacher who is also a parent;
- institute owner;
- institute staff member with limited capabilities;
- invite recipient;
- Local Manager;
- advertiser/org operator;
- Platform Admin;
- wrong Google account;
- stale phone trust;
- changed phone;
- shared device/context switching;
- revoked authority;
- expired/replayed invitation;
- concurrent last-seat acceptance;
- unrelated-account/deep-link tampering;
- copied private file URL;
- direct DML attempt;
- weak network/retry/duplicate click.

No persona test may obtain authority from UI/workspace selection alone.

---

## 10. Retrofit Gate R7 — Reliability, security and launch reality

Before public launch claim:

- full frozen DB regression suite PASS;
- V1.3 tests PASS;
- browser persona E2E PASS;
- Security Advisor = 0 material findings;
- true concurrent last-seat/inventory/Test/idempotency races;
- real p50/p95/p99 under representative load;
- connection-pool/lock/deadlock/timeout checks;
- soak test;
- Storage upload/download and authorization under real browser sessions;
- external Auth/SMS failure recovery;
- no DEV fixed OTP mapping in production;
- production OAuth redirect/config checklist;
- production environment/secret review;
- synthetic data cleanup;
- explicit go/no-go report.

---

## 11. Immediate continuation rule for the current project

**Stop broad feature work and stop random bug hunting.**

Current sequence from this document:

1. finish the V1.3 Screen ↔ Backend contract matrix;
2. finish the side-effects matrix;
3. complete the real Google + phone technology proof when hosted Auth configuration is available;
4. execute the mandatory walking skeleton;
5. only then continue remaining work as vertical slices;
6. finish persona/adversarial E2E;
7. finish reliability/security/launch gates.

Existing migration 1021 and other DEV work are retained; do not roll back merely to recreate history. Any issue discovered during the retrofit is classified before it is fixed.

---

## 12. What this retrofit is NOT

It is not:

- restarting brainstorming;
- recreating the database;
- redesigning frozen domain rules;
- chasing every cosmetic imperfection;
- trying to achieve an impossible zero-bug implementation;
- shipping before real Auth/E2E evidence exists.

It is:

> **a finite closure pass that turns a strong domain model into an executable, cross-layer-proven product.**
