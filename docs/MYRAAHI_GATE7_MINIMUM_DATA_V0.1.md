# MyRaahi Shared Front Door — Gate 7 Minimum Data, Entities & Relationships v0.1

Last updated: 2026-09-26

Method: AI Builder Cheat Code v2.0 — Gate 7

Scope: shared `myraahi.co.in` front door and common identity/location foundation.

This document revalidates the earlier domain model only after Gates 0–6.

---

## 1. Entity inclusion test

For an entity to remain in the shared core, it must be required to enforce at least one shared business rule/invariant and must not merely duplicate a UI label.

---

## 2. Account — KEEP logically, physical implementation deferred until identity spike

**Why it exists**
- one durable Raahi human identity across focused products;
- selected Location preference;
- shared profile presentation;
- shared trust/admin relationships.

**Owner**
- the human owns self-service presentation/preference intent;
- Raahi shared backend owns canonical Account state/authority linkage.

**Lifecycle**
- ACTIVE / PAUSED / CLOSED (destructive deletion still deferred).

**Relationships giving authority/access**
- AccountCapability;
- LocationStaffAssignment;
- focused-product relationships outside shared core.

**History**
- durable identity linkage and governance history must survive ordinary Location/Product changes.

**Can it be derived?**
No. A durable cross-product identity requires a stable Raahi account identifier once shared identity is implemented.

**Physical V0 public shell**
Do not add an Account table to D1 merely because the logical model contains Account. Identity location depends on Gate 13 architecture proof.

---

## 3. Location — KEEP

**Why**
- location-first catalogue and admin scope require a canonical Raahi market/context.

**Owner**
- platform governance.

**Lifecycle**
- PREPARING / LIVE / PAUSED / RETIRED.

**Relationships**
- LocationProduct;
- AccountLocationPreference;
- LocationStaffAssignment.

**History**
- stable id/slug references survive lifecycle/display-name changes.

**Can derive?**
No. Do not infer canonical Location from arbitrary GPS/city text.

---

## 4. Product — KEEP

**Why**
- shared shell must know the small set of focused Raahi capabilities.

**Owner**
- platform governance.

**Lifecycle**
- ACTIVE / RETIRED.

**Relationships**
- LocationProduct.

**History**
- stable product key survives display changes.

**Can derive?**
No. Hard-coded frontend cards would violate configuration/expansion rules.

---

## 5. LocationProduct — KEEP

**Why**
- core location-first requirement: each Product is independently enabled/configured per Location.

**Owner**
- platform/scoped local governance.

**Lifecycle**
- OFF / PREPARING / LIVE / PAUSED.

**Relationships**
- exactly one Location;
- exactly one Product.

**History**
- state changes audited; focused-product history not owned here.

**Can derive?**
No. Neither Location nor Product alone determines local availability.

**Uniqueness**
One canonical row/relationship per Location + Product.

---

## 6. AccountLocationPreference — KEEP logically, physical identity store deferred

**Why**
- signed-in Account should remember selected Location without making Location part of identity.

**Owner**
- Account holder.

**Lifecycle**
- replaceable preference, not historical business state.

**Relationships**
- one Account;
- one selected Location.

**History**
Long history is not required by business rules.

**Can derive?**
No reliably; last focused-product use is not equivalent to explicit current preference.

**Logged-out equivalent**
Not a database entity: browser/session state only.

---

## 7. AccountCapability — KEEP, but deliberately tiny

**Why**
- server-owned platform-wide authority such as Platform Admin.

**Owner**
- platform governance.

**Lifecycle**
- grant ACTIVE → REVOKED; re-grant should preserve history.

**Relationships**
- Account.

**Must not become**
A universal role table for teacher/driver/doctor/shop/parent.

**Can derive?**
Not safely from UI/session metadata.

---

## 8. LocationStaffAssignment — KEEP

**Why**
- explicit scoped local administration.

**Owner**
- Platform Admin/platform governance.

**Lifecycle**
- ACTIVE → ENDED, new assignment for later re-grant.

**Relationships**
- Account;
- Location;
- staff type/capability.

**History**
Must survive revocation.

**Can derive?**
No. Selected Location/account profile cannot imply authority.

---

## 9. SharedAuditEvent — KEEP when shared writes exist

**Why**
- consequential admin/authority/configuration actions require durable evidence.

**Owner**
- system-generated; not editable by ordinary users.

**Lifecycle**
- append-only evidence.

**Relationships**
- actor Account where applicable;
- target entity;
- optional Location/Product scope.

**Can derive?**
No. Current rows do not explain who changed what/why.

**Public-shell V0**
Configuration migration/CLI evidence may precede full admin audit implementation, but production mutable admin configuration requires audit.

---

## 10. IdempotentCommandRecord — KEEP when consequential shared commands exist

**Why**
- uncertain networks/retries must not duplicate assignments/state transitions.

**Owner**
- shared command layer.

**Lifecycle**
- created per consequential intent; retention policy technical/operational.

**Can derive?**
No after-the-fact without risking duplicate effects.

**Public read-only V0**
Not needed until write commands are introduced.

---

## 11. Phone trust evidence — KEEP as shared Account fact, shape deferred

**Why**
- selected consequential actions may require recent proof of phone control.

**Owner**
- Raahi server semantics based on provider evidence.

**Possible minimum representation**
- confirmed phone reference from identity system;
- `phone_trust_verified_at` or equivalent evidence record.

**Do not create yet**
A generic verification table.

**Reason**
Final source of authenticated phone and cross-product identity architecture must be proven first.

---

## 12. Authentication identity link — REQUIRED logically, physical model deferred

**Why**
- one durable Raahi Account must map safely to provider identity/identities.

**Risk**
Account linking/recovery is a known unresolved edge.

**Decision**
Do not prematurely choose one-provider-one-column schema.

Gate 13 identity spike must determine:
- whether Auth provider is authoritative store;
- whether multiple provider identities are linkable;
- how recovery avoids duplicate Accounts.

---

## 13. Product integration metadata — KEEP within Product unless complexity proves otherwise

Minimum:
- approved entry URL/path;
- display/icon metadata;
- perhaps integration mode/version later.

Do not create a separate ProductIntegration entity until multiple integrations per Product or versioned contracts become real.

---

## 14. Product readiness — DERIVE / adapter evidence, not a generic stored business entity yet

A Product becoming LIVE requires readiness evidence.

Do not create a generic `readiness_status` merely because a screen may want a badge.

Possible sources:
- validated destination;
- health/integration check;
- explicit release evidence.

Freeze physical representation only after technology/product integration spike.

---

## 15. Auth handoff context — EPHEMERAL technical record/state, not core business entity

May need:
- return target;
- selected Location;
- safe draft reference;
- expiry/nonce.

This exists to implement Gate 8/9 behavior safely.

Do not treat it as durable business history.

Physical mechanism is Gate 13.

---

## 16. Visitor — NOT AN ENTITY

No database row simply because someone browsed the homepage.

---

## 17. Product participant roles — NOT SHARED ENTITIES

Do not add:
- Teacher;
- Driver;
- Doctor;
- Passenger;
- Parent;
- Shop Owner

to the shared-core schema.

They remain focused-product entities/relationships.

---

## 18. Generic verification evidence — REJECT FOR V0 SHARED CORE

Why reject:
- qualification, doctor registration, driver licence, vehicle RC, shop existence have different evidence/review/lifecycle rules;
- a polymorphic generic table would hide domain differences and create premature coupling.

Shared shell may consume exact projected claims later.

---

## 19. Generic Role — REJECT

A single `role` column would contradict multi-capability identity.

---

## 20. Session Location row for every visitor — REJECT

Browser preference is sufficient for logged-out discovery.

Do not create database identities to remember Gomoh.

---

## 21. Shared Notification entity — DEFER

No shared notification requirement is proven for the initial shell.

Side-effects Gate 15 may later justify specific notification/event infrastructure.

---

## 22. Shared Advertisement entities — DEFER

Monetization doctrine exists, but the first shell does not need a full ad system.

Do not create advertiser/campaign/impression tables until a real placement workflow is designed.

---

# Canonical relationship map

```
Account
  ├── 0..1 AccountLocationPreference ──> Location
  ├── 0..* AccountCapability
  ├── 0..* LocationStaffAssignment ───> Location
  └── 0..* focused-product relationships (outside shared core)

Location
  └── 0..* LocationProduct ───────────> Product

Product
  └── 0..* LocationProduct ───────────> Location

SharedAuditEvent
  └── references actor/target/scope as needed

IdempotentCommandRecord
  └── binds actor + command + key + request fingerprint/result
```

---

# Minimum shared data by phase

## Public-shell walking-skeleton phase

Physically required:
- Location
- Product
- LocationProduct
- schema/config version
- controlled config audit/evidence as needed

Not required:
- Account
- Account preference
- capabilities
- staff assignment
- OTP
- identity links

This is legitimate because public discovery itself requires no Account.

## Shared-identity phase

Add only after technology proof:
- Account
- authentication identity linkage/source
- AccountLocationPreference
- shared profile fields
- phone trust evidence if needed

## Shared-admin phase

Add:
- AccountCapability
- LocationStaffAssignment
- SharedAuditEvent
- IdempotentCommandRecord

Final ordering may combine identity/admin in one vertical slice only if the walking skeleton and technology proof justify it.

---

# Reconciliation result

The earlier `MYRAAHI_SHARED_FOUNDATION_DOMAIN_MODEL_V0.1.md` is broadly correct.

Changes/clarifications introduced by strict Gate 7:
1. physical Account storage is explicitly deferred until identity architecture proof;
2. authentication identity linkage is called out as a required logical concern;
3. auth handoff context is classified as ephemeral technical state;
4. generic verification, notification and ad entities are explicitly rejected/deferred;
5. Product readiness remains evidence/derived state rather than a new entity;
6. public-shell V0 data is intentionally much smaller than eventual shared foundation data.

---

# Gate 7 result

**PASS.**

No new entity is required to proceed to behavior modelling.

Next gate: **Gate 8 — behavior flows and persona simulations**.
