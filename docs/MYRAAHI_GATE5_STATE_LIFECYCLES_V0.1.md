# MyRaahi Shared Front Door — Gate 5 State Lifecycles v0.1

Last updated: 2026-09-26

Method: AI Builder Cheat Code v2.0 — Gate 5

Scope: shared `myraahi.co.in` front door and shared location/identity foundation.

For every lifecycle, first question: **status of what?**

---

# 1. Location lifecycle

**Stateful concept:** one Raahi Location / operating-discovery market.

States:
- PREPARING
- LIVE
- PAUSED
- RETIRED

| Current | Trigger / actor | Preconditions | Next | Side effects | Invalid transitions | Recovery |
|---|---|---|---|---|---|---|
| PREPARING | Publish Location / Platform Admin | Required configuration complete; canonical Location valid | LIVE | Becomes publicly selectable; audit | Direct client-side state mutation | Fix readiness/config and retry |
| PREPARING | Abandon Location / Platform Admin | Governance reason | RETIRED | Hidden from normal selector; history retained; audit | RETIRED→LIVE through ordinary flow | Create deliberate new/replacement Location decision |
| LIVE | Pause Location / Platform Admin | Current LIVE; reason | PAUSED | New normal local entry blocked/limited; audit | Browser/user pause | Correct authority and retry |
| PAUSED | Resume Location / Platform Admin | Current PAUSED; safety/readiness restored | LIVE | Public selector restored; audit | Resume if underlying readiness still failed | Remain PAUSED and show missing condition |
| LIVE | Retire Location / Platform Admin | Strong confirmation + reason + history preservation | RETIRED | Removed from normal selection; history references retained; audit | Silent deletion | Recreate only through explicit governance if ever justified |
| PAUSED | Retire Location / Platform Admin | Governance confirmation | RETIRED | Same as above | — | — |

### Terminal
RETIRED is terminal in normal flow.

### Race rule
Two admins changing Location state concurrently: command must compare current state; one valid transition wins, stale command fails with current truth.

---

# 2. Product registry lifecycle

**Stateful concept:** one globally registered Raahi focused Product definition.

States:
- ACTIVE
- RETIRED

| Current | Trigger / actor | Preconditions | Next | Side effects | Invalid | Recovery |
|---|---|---|---|---|---|---|
| ACTIVE | Retire Product / Platform Admin | Strong governance reason; historical references preserved | RETIRED | Product can no longer be newly exposed as LIVE; audit | Browser/client retirement | Reconsider before command; no ordinary resurrection |
| RETIRED | Any normal activation | — | — | — | RETIRED→ACTIVE | Create explicit new product-version/governance decision if truly needed |

### Terminal
RETIRED is terminal in normal operation.

---

# 3. LocationProduct lifecycle

**Stateful concept:** availability of one Product in one Location.

States:
- OFF
- PREPARING
- LIVE
- PAUSED

| Current | Trigger / actor | Preconditions | Next | Side effects | Invalid transitions | Recovery |
|---|---|---|---|---|---|---|
| OFF | Begin setup / authorized admin | Product ACTIVE; Location not RETIRED | PREPARING | Internal setup begins; not normal public choice | User/browser sets state | Authorized admin fixes config |
| OFF | Fast enable / authorized admin | Explicit readiness proof permits; Location LIVE; Product ACTIVE | LIVE | Appears as public live choice; audit | LIVE without readiness | Remain OFF/PREPARING |
| PREPARING | Publish / authorized admin | Readiness checks pass; Location LIVE; Product ACTIVE | LIVE | Public live availability; audit | Publish if integration target unsafe/unready | Stay PREPARING and show missing readiness |
| PREPARING | Cancel setup / authorized admin | Reason | OFF | Hidden; setup can later restart; audit | Delete historical product data | Leave product-owned data untouched |
| LIVE | Pause / authorized admin | Current LIVE; reason | PAUSED | Normal new entry blocked; may stay visibly unavailable; audit | Product history cancellation | Keep history; product handles existing relationships |
| PAUSED | Resume / authorized admin | Current PAUSED; readiness restored; Location LIVE; Product ACTIVE | LIVE | Normal public entry restored; audit | Resume while Location not LIVE/Product retired | Remain PAUSED |
| LIVE | Withdraw / authorized admin | Explicit withdrawal reason | OFF | Hidden from normal catalogue; history preserved; audit | Silent destructive off | Keep product history accessible per product rules |
| PAUSED | Withdraw / authorized admin | Explicit reason | OFF | Hidden; audit | — | — |

### Race rule
State transition validates current state at execution. Stale admin UI loses to server truth.

### Cross-state rule
LocationProduct can only be actionable when:
- Location = LIVE
- Product = ACTIVE
- LocationProduct = LIVE

---

# 4. Account lifecycle

**Stateful concept:** one durable shared Raahi Account.

Provisional states:
- ACTIVE
- PAUSED
- CLOSED

Important: detailed closure/deletion/anonymization policy is not yet finalized; therefore this lifecycle is only sufficient for shared access control, not privacy deletion.

| Current | Trigger / actor | Preconditions | Next | Side effects | Invalid | Recovery |
|---|---|---|---|---|---|---|
| ACTIVE | Protective/admin pause / authorized governance or future user safety flow | Valid reason/rule | PAUSED | Shared consequential actions restricted; history preserved | Pause by ordinary product UI without authority | Correct actor/rule |
| PAUSED | Restore / authorized recovery/governance | Recovery conditions satisfied | ACTIVE | Shared access restored | Auto-restore from stale client | Complete recovery |
| ACTIVE | Close Account / future explicit closure flow | Closure rules satisfied | CLOSED | Normal shared self-service ends; history/privacy handling per future policy | Immediate hard-delete as equivalent to close | Separate deletion/anonymization policy |
| PAUSED | Close Account / future explicit closure flow | Same | CLOSED | Same | — | — |

### Terminal
CLOSED is terminal for ordinary self-service.

### Deferred decision
Full privacy/account deletion and historical anonymization is **not frozen**. Do not implement destructive Account closure until that separate lifecycle is designed.

---

# 5. LocationStaffAssignment lifecycle

**Stateful concept:** one scoped Location Admin assignment for one Account and Location.

States:
- ACTIVE
- ENDED

| Current | Trigger / actor | Preconditions | Next | Side effects | Invalid | Recovery |
|---|---|---|---|---|---|---|
| none | Assign / Platform Admin | Account active; Location valid; no duplicate active same scope | ACTIVE | Authority begins; audit | Duplicate active assignment | Return existing/conflict |
| ACTIVE | End / Platform Admin | Assignment still active | ENDED | Future scoped admin commands denied; audit/history retained | Client-only revocation | Execute canonical command |
| ENDED | Re-enable same row | — | — | — | ENDED→ACTIVE mutation | Create a new assignment row so history remains truthful |

### Concurrency
Unique active assignment rule prevents two duplicate active grants.

---

# 6. AccountCapability lifecycle

**Stateful concept:** one shared platform capability grant, initially primarily Platform Admin.

Recommended event-style states:
- ACTIVE
- REVOKED

| Current | Trigger / actor | Preconditions | Next | Side effects | Invalid | Recovery |
|---|---|---|---|---|---|---|
| none | Grant / authorized bootstrap/governance | Strong authority; Account valid | ACTIVE | Capability available; audit | Self-grant via UI | Reject |
| ACTIVE | Revoke / authorized governance | Current active grant | REVOKED | Future capability checks fail; audit | Stale session preserves power | Server check denies; refresh |
| REVOKED | Reactivate same row | — | — | — | Rewrite old grant | Create a new grant event/record if re-granted |

---

# 7. Phone trust lifecycle

**Stateful concept:** freshness of evidence that Account controlled a particular phone.

Derived states:
- UNVERIFIED
- FRESH
- STALE

This is preferably **derived from evidence/timestamps**, not manually set as arbitrary status.

| Current | Trigger | Preconditions | Next | Side effects | Invalid | Recovery |
|---|---|---|---|---|---|---|
| UNVERIFIED | Successful OTP proof | Valid Account/challenge/provider evidence | FRESH | Record server-owned verification evidence/time | Client supplies verified timestamp | Reject |
| FRESH | Time passes beyond trust freshness window | Existing proof age exceeds rule | STALE | Trust-sensitive new actions may require re-proof | Silent deletion of established unrelated relationships | Reverify when needed |
| STALE | Successful re-verification | Valid challenge/provider evidence | FRESH | Refresh trust evidence/time | Product manually marks fresh | Reject |
| FRESH/STALE | Phone identity removed/changed | Valid identity/account flow | UNVERIFIED or new-number state per final auth design | Old phone trust no longer applies | Old proof transfers to new phone | Require new proof |

### Important
Trust freshness window is not yet frozen for shared MyRaahi because final OTP architecture/action requirements are not proven.

Do not invent a duration at implementation time.

---

# 8. Logged-out selected Location lifecycle

**Stateful concept:** browser preference, not business entity.

Conceptual conditions:
- NONE
- SELECTED_VALID
- SELECTED_INVALID

| Current | Trigger | Preconditions | Next | Effect | Recovery |
|---|---|---|---|---|---|
| NONE | User selects public Location | Location selectable | SELECTED_VALID | Store lightweight browser preference | — |
| SELECTED_VALID | User changes Location | New Location selectable | SELECTED_VALID | Replace browser preference | — |
| SELECTED_VALID | Saved Location later not selectable | Server validation fails | SELECTED_INVALID | Do not silently choose another city | Ask user to choose |
| SELECTED_INVALID | User chooses valid Location | Valid choice | SELECTED_VALID | Replace invalid value | — |
| any | Browser storage unavailable/cleared | — | NONE | No durable consequence | Ask again when needed |

This state must never create authority.

---

# 9. Authentication handoff lifecycle

**Stateful concept:** one interrupted journey requiring authentication.

Conceptual states:
- PREPARED
- AUTH_IN_PROGRESS
- AUTHENTICATED_RESUMABLE
- CANCELLED
- EXPIRED/INVALID

| Current | Trigger | Preconditions | Next | Side effect | Recovery |
|---|---|---|---|---|---|
| PREPARED | Start auth | Safe return context | AUTH_IN_PROGRESS | Preserve safe draft/context reference | — |
| AUTH_IN_PROGRESS | Auth success | Identity/session valid | AUTHENTICATED_RESUMABLE | Resolve Account and return intent | Revalidate draft/current state |
| AUTH_IN_PROGRESS | User cancels/fails | — | CANCELLED | No business write | Return to safe pre-auth context |
| AUTHENTICATED_RESUMABLE | Resume action | Draft and authority still valid | terminal for handoff | Continue product/shared action | If stale, keep session and recover |
| PREPARED/AUTH_IN_PROGRESS | Context expires/invalid | TTL/security failure | EXPIRED/INVALID | Discard unsafe context only | Keep safe auth/session as applicable; rebuild action |

Exact technical persistence is Gate 13 territory.

---

# 10. Verification claim lifecycle

**Stateful concept:** one exact verification claim inside a focused product/shared projection.

Generic conceptual lifecycle only:
- NOT_SUBMITTED
- SUBMITTED
- APPROVED
- REJECTED
- EXPIRED/REVOKED

The **shared shell does not own the transition workflow**. Focused products do.

Shared invariant:
- public projection may show APPROVED/current claim;
- EXPIRED/REVOKED cannot remain displayed as current;
- one claim type does not imply another.

Do not implement a universal shared verification state machine until repeated real product cases justify it.

---

# 11. Sponsored placement lifecycle — deferred

Advertising self-service is out of current V1 shell.

If later implemented, its lifecycle must be designed at that time rather than inferred from this shell.

Only invariant retained now:
- expired/inactive sponsored content must stop displaying;
- payment never affects verification/authority.

---

# 12. Invalid transition policy

For every shared stateful concept:

1. server checks current canonical state;
2. stale client transition is rejected;
3. no partial side effect occurs;
4. response includes current state and human-recoverable next action;
5. UI refetches current projection;
6. retry is idempotent when same action was already successfully committed.

---

# 13. Gate 5 result

**PASS for the current shared-front-door scope**, with two explicit deferred items:
- full Account deletion/anonymization lifecycle;
- exact phone-trust freshness duration.

Neither deferred item blocks public-shell discovery/configuration design.

They **will block implementation of destructive Account closure or trust-sensitive shared actions** until resolved/evidence-backed.

Next gate: **Gate 6 — edge cases and recovery catalogue**.
