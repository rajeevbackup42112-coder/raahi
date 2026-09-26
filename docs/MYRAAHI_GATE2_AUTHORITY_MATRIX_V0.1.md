# MyRaahi Shared Front Door — Gate 2 Decision Ownership & Authority Matrix v0.1

Last updated: 2026-09-26

Method: AI Builder Cheat Code v2.0 — Gate 2

Scope: shared `myraahi.co.in` front door and shared identity/location foundation.

Key distinction:

> A user may express intent. That does not mean the user owns every resulting decision.

---

## 1. Public discovery decisions

| Decision / action | Intent expressed by | Decision owner | Validator | Executor | Exception owner | Scope |
|---|---|---|---|---|---|---|
| Choose browsing Location | Visitor / Account holder | Human user | Shared shell validates Location is selectable | Browser/session; authenticated preference command later | User chooses another Location | Current browsing context only |
| Persist selected Location for Account | Account holder | Account holder | Shared backend checks active Account + selectable Location | Shared backend | Platform support only for corruption/recovery, not routine choice | Own Account preference |
| Which Locations appear as selectable | Platform Admin through configured state | Raahi platform governance | Shared backend lifecycle rules | Shared backend public projection | Platform Admin | Platform-wide |
| Which Products appear for a Location | Platform/authorized Location configuration | Raahi shared platform configuration | Shared backend checks Location + Product + LocationProduct states | Shared backend public projection | Platform Admin; limited Location Admin if delegated | Specific Location/Product pair |
| Whether PAUSED Product is shown as unavailable | Frozen product rule/config | Shared product contract | Shared backend/UI projection contract | Shared shell | Platform Admin may change state, not rewrite UI semantics ad hoc | Specific Location/Product |
| Enter a LIVE focused Product | Visitor / Account holder | Human user | Shared shell validates configured allowlisted Product destination | Browser navigation | User can return/change Location | Current journey |
| Accept Location hint inside focused Product | Human selected it; shell passes hint | Focused Product owns operational applicability | Focused Product validates hint and its own serviceability | Focused Product | Focused Product recovery | Focused Product context |

---

## 2. Authentication and identity decisions

| Decision / action | Intent expressed by | Decision owner | Validator | Executor | Exception owner | Scope |
|---|---|---|---|---|---|---|
| Start sign-in | Visitor / Account holder | Human user, triggered by product/shared rule | Auth handoff validates safe return target | Authentication system | Shared support only for recovery issues | Current login attempt |
| Is authentication required for a shared action? | Product contract/rule | Shared platform rule owner | Shared backend | Shared shell/backend | Product change control | Specific shared action |
| Is authentication required for a focused-product action? | Focused Product rule | Focused Product | Focused Product backend | Focused Product | Focused Product governance | Product-specific |
| Authentication identity is valid | Human supplies provider flow | Authentication provider | Provider protocol | Authentication provider/session system | Provider + Raahi recovery flow | Technical identity/session |
| Create/link Raahi Account from authenticated identity | Authenticated human arrives | Raahi shared identity rules | Shared identity backend | Shared identity backend | Platform support under explicit recovery rules | One durable Raahi Account |
| Edit display name/profile presentation | Account holder | Account holder | Shared backend validation | Shared backend | Account recovery/support | Own Account presentation |
| Decide Account role/capability | Never from UI role choice alone | Relevant Raahi authority/business relationship owner | Server-side relationship/capability rules | Shared or focused-product backend | Scoped admin/support per rule | Relevant capability/relationship |
| Phone trust challenge requested | Account holder/product flow | Product/shared trust rule | Shared trust backend checks need/rate/session | OTP boundary/provider | Support only for provider failure; not manual trust manufacture | Own Account/current trust action |
| Phone proof succeeds | Account holder enters OTP | OTP provider proves challenge; Raahi owns resulting trust claim semantics | Server verifies provider result and Account/session binding | Shared trust backend | Support may reset/retry, never fabricate success | Own Account |
| Identity/professional verification | Provider/applicant submits evidence | Relevant focused-product verification authority | Product-specific evidence/reviewer rules | Focused Product | Product-specific escalation | Specific claim only |

---

## 3. Shared platform configuration decisions

| Decision / action | Intent expressed by | Decision owner | Validator | Executor | Exception owner | Scope |
|---|---|---|---|---|---|---|
| Create Location | Platform Admin | Platform Admin under platform governance | Shared backend uniqueness/required data rules | Canonical shared command | Platform Admin governance | Platform-wide |
| Move Location PREPARING → LIVE | Platform Admin | Platform Admin | Shared backend readiness/lifecycle rules | Canonical command | Platform Admin; readiness exception must be explicit/audited if later allowed | One Location |
| Pause LIVE Location | Platform Admin | Platform Admin | Shared lifecycle rules | Canonical command | Platform Admin | One Location |
| Retire Location | Platform Admin | Platform Admin with stronger confirmation | Shared lifecycle/history rules | Canonical command | Platform Admin governance | One Location |
| Create shared Product definition | Platform Admin | Platform Admin | Shared backend stable-key/destination rules | Canonical command | Platform Admin | Platform-wide Product registry |
| Retire shared Product | Platform Admin | Platform Admin | Shared lifecycle/history rules | Canonical command | Platform Admin | One Product definition |
| Configure Product in Location | Platform Admin or delegated Location Admin | Shared Raahi governance within allowed scope | Shared backend validates actor scope + state transition | Canonical command | Platform Admin | One Location/Product |
| Change LocationProduct LIVE → PAUSED | Platform Admin or delegated Location Admin if authorized | Authorized scoped admin | Shared backend current state + scope | Canonical command | Platform Admin | One Location/Product |
| Change LocationProduct to LIVE | Authorized admin expresses intent | Raahi readiness rule owns final permission | Shared backend + Product readiness evidence | Canonical command | Platform Admin; no silent bypass | One Location/Product |
| Assign Location Admin | Platform Admin | Platform Admin | Shared backend validates Account + Location + duplicate-active assignment | Canonical command | Platform Admin | One Account/Location |
| End Location Admin assignment | Platform Admin | Platform Admin | Shared backend validates assignment/current state | Canonical command | Platform Admin | One assignment |
| Grant Platform Admin | Existing authorized platform bootstrap/governance mechanism | Platform governance, not ordinary admin UI | Strong server-controlled process | Server/admin bootstrap command | Explicit governance path only | Platform-wide |
| Raw database correction | Not an ordinary UI decision | Emergency operational governance only | Runbook/change approval | Authorized operator tooling | Platform governance | Narrow correction only |

---

## 4. Product-owned decisions

These are explicitly **not owned by the shared shell**.

| Decision example | Intent expressed by | Owner | Validator/executor |
|---|---|---|---|
| Accept teacher request / create class relationship | Learning actor | Raahi Learning rules | Learning backend |
| Book/request ride | Passenger | Mobility product rules | Mobility backend |
| Driver accepts/rejects ride | Driver | Mobility product rules | Mobility backend |
| Book doctor appointment | Patient/user | Doctors product rules | Doctors backend |
| Approve provider credentials | Provider submits; reviewer decides | Relevant focused product | Focused product verification workflow |
| Place shop order | Customer | Shops rules | Shops backend |
| Complete/cancel product transaction | Relevant product actor(s) | Focused product | Focused product backend |

Shared Account authentication may identify the human, but it does not own these decisions.

---

## 5. Sponsored visibility decisions

Current status: advertising self-service is deferred.

| Decision | Intent | Owner | Validator/executor | Scope |
|---|---|---|---|---|
| Create sponsored placement | Future advertiser requests | Raahi advertising governance | Future canonical ad workflow | Selected Location/Product placement |
| Label placement Sponsored | Non-optional Raahi rule | Raahi platform | Shared/product UI | Every paid placement |
| Grant verification because advertiser paid | Not permitted | Nobody | Must be rejected | Never |
| Override organic trust ranking due to payment | Not permitted under current doctrine | Nobody | Must be rejected | Never |

---

## 6. System-owned validation decisions

### Shared backend owns
- whether current Account/session is valid for a shared command;
- whether current actor has Platform/Location Admin scope;
- whether current shared state permits a transition;
- idempotency/retry outcome;
- current canonical Location/Product state.

### Browser/UI owns only
- collecting/displaying human intent;
- local ephemeral UI state;
- navigation presentation.

It never owns:
- authority;
- verification truth;
- lifecycle truth;
- admin scope.

### Focused Product backend owns
- focused-product authority;
- product-state transitions;
- product-private projections;
- product-specific safety rules.

### Authentication provider owns
- technical provider authentication result only.

### OTP provider owns
- challenge delivery/verification evidence only.

---

## 7. Exception rules

1. “Admin can handle it” is not an acceptable exception definition.
2. Location Admin exceptions remain Location-scoped and only where explicitly delegated.
3. Platform Admin cannot casually bypass focused-product invariants.
4. Manual database correction is an emergency operational path, not a normal business workflow.
5. Support staff are not granted hidden write power before support scenarios are explicitly designed.
6. No external provider response directly creates Raahi business authority.
7. No paid sponsor can buy verification or administrative authority.
8. A stale UI cannot execute a transition the server now rejects.

---

## 8. Multi-context authority rule

The same human may simultaneously be:
- ordinary Account holder;
- Learning participant;
- Driver;
- Shop owner;
- Location Admin;
- Platform Admin.

Therefore every consequential command must resolve:
1. **which Account** is acting;
2. **which actor context/capability** is being exercised;
3. **which object** is targeted;
4. **which Location/Product scope** applies;
5. **whether authority is current at execution time**.

A session alone is insufficient.

---

## 9. Gate 2 result

**PASS**, subject to Gate 3 rule normalization.

No unresolved product/business decision blocks the shared-shell authority model.

Next gate: **Gate 3 — Canonical Business Rule Catalogue**.
