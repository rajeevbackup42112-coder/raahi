# MyRaahi Shared Front Door — Gate 6 Edge Cases & Recovery Catalogue v0.1

Last updated: 2026-09-26

Method: AI Builder Cheat Code v2.0 — Gate 6

Scope: shared `myraahi.co.in` front door and shared location/identity foundation.

The objective is not merely to reject bad situations. Each case defines the safest recoverable user/system outcome.

---

## EC-01 — Duplicate click on Location selection

**Case**  
User taps the same Location twice or browser retries.

**Risk**  
Duplicate writes for authenticated preference or confusing UI races.

**Recovery**  
- logged-out browser selection is harmless replacement;
- authenticated preference command is idempotent;
- UI renders the final canonical selection.

---

## EC-02 — Duplicate admin command

**Case**  
Admin double-clicks LIVE/PAUSE/assign action or network retries POST.

**Risk**  
Duplicate assignment/audit rows or contradictory transitions.

**Recovery**  
- require idempotency key/fingerprint;
- return prior successful result for exact retry;
- reject conflicting reuse;
- unique/transition constraints remain authoritative.

---

## EC-03 — Stale catalogue in browser

**Case**  
Shell showed Product LIVE, admin has since PAUSED it.

**Risk**  
User believes service is currently available.

**Recovery**  
- focused Product validates current serviceability before consequential action;
- refuse gracefully if no longer available;
- shell refetches current catalogue on return/retry;
- no product transaction is created from stale shell state.

---

## EC-04 — Stale admin screen

**Case**  
Two admins view same current state; one changes it; second submits old transition.

**Risk**  
Last-writer-wins business corruption.

**Recovery**  
- server validates expected/current state;
- stale transition rejected with current canonical state;
- second admin refetches and decides again.

---

## EC-05 — Location Admin authority revoked mid-session

**Case**  
Admin UI remains open after assignment is ended.

**Risk**  
Stale browser continues privileged writes.

**Recovery**  
- every write checks current server-owned assignment;
- command rejected as unauthorized;
- UI refreshes/re-routes to non-admin context;
- previous legitimate actions remain in history.

---

## EC-06 — Platform Admin authority revoked mid-session

**Case**  
Existing session still has UI controls.

**Recovery**  
Same server-current-authority rule; session alone is insufficient.

---

## EC-07 — Saved Location becomes PAUSED

**Case**  
Browser/account preference points to a now-paused Location.

**Risk**  
Silent incorrect fallback or dead screen.

**Recovery**  
- show saved Location truthfully as unavailable;
- ask user to choose another LIVE Location;
- do not silently switch;
- preserve Account/product history.

---

## EC-08 — Saved Location becomes RETIRED

**Recovery**  
- reject as normal selection;
- ask user to choose a current Location;
- keep historical references intact.

---

## EC-09 — Location disappears from cache but browser retains slug

**Case**  
Old/invalid/tampered slug in local storage.

**Recovery**  
- validate against server list/catalogue;
- clear invalid browser preference;
- show chooser;
- never create arbitrary Location from client input.

---

## EC-10 — User signs in with old saved Account preference differing from explicit current Location

**Case**  
Current browser = Gomoh; Account saved preference = Dhanbad.

**Recovery**  
- explicit current journey wins for this session;
- continue Gomoh;
- optionally update Account preference through canonical command.

---

## EC-11 — User cancels authentication

**Case**  
Login wall appeared only because they attempted consequential action.

**Recovery**  
- create no business state;
- return to safe pre-auth context/draft;
- allow further public browsing.

---

## EC-12 — Authentication succeeds but return context expired

**Risk**  
Unsafe replay or confusing failure.

**Recovery**  
- keep valid authenticated session;
- discard only expired/unsafe return context;
- take user to closest safe destination and explain that action needs to be started/refreshed again.

---

## EC-13 — Authentication succeeds under wrong Account

**Case**  
Shared device or user picks different Google account.

**Risk**  
Draft intended for another human is submitted.

**Recovery**  
- do not automatically submit consequence after auth;
- show resolved Account identity/context before final consequential submission where relevant;
- focused Product revalidates authority/ownership;
- allow sign-out/switch.

---

## EC-14 — User loses Google account / login method

**Status**  
Account recovery architecture not yet frozen.

**Recovery requirement**  
- do not silently create a second Raahi Account just because user chooses another provider;
- stop at a deliberate identity-recovery/linking flow once designed;
- existing product history remains untouched.

**Gate consequence**  
This is an evidence/design dependency for shared Account rollout, not for public browse shell.

---

## EC-15 — User loses phone/device

**Case**  
Phone trust cannot be refreshed.

**Recovery requirement**  
- stale phone trust may block only actions that truly require fresh phone proof;
- existing unrelated relationships/history are not deleted;
- safety/account recovery paths remain available.

---

## EC-16 — Phone OTP provider fails

**Case**  
Timeout/provider outage/message delayed.

**Recovery**  
- no fabricated phone trust;
- previous trust state remains unchanged;
- show retry/later path respecting rate limits;
- core authentication/public browsing remains available if rule allows.

---

## EC-17 — OTP entered after expiry

**Recovery**  
Reject challenge, allow new challenge when permitted; never reuse expired verification as evidence.

---

## EC-18 — Multiple OTP requests

**Risk**  
Confusing which code is valid; cost abuse.

**Recovery requirement**  
- server/provider boundary establishes one current valid challenge policy;
- old challenge handling explicit;
- enforce cooldown/rate/abuse rules;
- do not rely only on disabled UI button.

Exact policy waits for technology spike/provider evidence.

---

## EC-19 — User refreshes during Location selection

**Recovery**  
Browser preference remains if saved; otherwise chooser reappears. No server corruption.

---

## EC-20 — User refreshes during authentication handoff

**Recovery requirement**  
Safe return-context mechanism survives only within designed security/TTL rules; if not, authenticated session may survive while draft is rebuilt.

Technology-specific proof required at Gate 13.

---

## EC-21 — Browser back after switching Location

**Risk**  
URL/UI/storage disagree.

**Recovery**  
- define one deterministic current Location source for shell navigation;
- validate route/storage against server catalogue;
- browser back must not grant authority or resurrect invalid availability.

Exact URL/history behavior is Gate 9 UI contract.

---

## EC-22 — Browser storage disabled

**Recovery**  
Shell still works; user may need to choose Location again. No Account required merely to persist preference.

---

## EC-23 — Shared device

**Case**  
One family member signs out; another uses same browser with stored Location.

**Recovery**  
- logged-out Location preference may remain because it is non-sensitive;
- Account/private state must be removed/isolated by auth logout;
- never show prior user's private profile merely because Location remains.

---

## EC-24 — Weak/offline network on homepage

**Recovery**  
- truthful loading/retry state;
- if approved cached catalogue exists, clearly use only within freshness policy;
- do not claim current availability from indefinite stale cache.

---

## EC-25 — Network fails after admin command reaches server

**Risk**  
Admin retries because response was lost.

**Recovery**  
Idempotency returns prior result; audit is not duplicated.

---

## EC-26 — D1/shared configuration datastore unavailable

**Recovery**  
- public shell fails gracefully;
- do not invent Product availability;
- optional safe cache strategy only after explicit freshness design;
- focused products remain independently addressable if users already know their URLs, unless product itself depends on shell.

---

## EC-27 — Free-tier quota exhausted

**Risk**  
Raahi becomes unavailable or inconsistent.

**Recovery requirement**  
- monitoring/launch gate must surface quota;
- degrade truthfully;
- never silently switch to an unapproved paid dependency;
- business owner decides if growth justifies cost/change.

---

## EC-28 — Product destination URL misconfigured

**Risk**  
Broken navigation or malicious external redirect.

**Recovery**  
- configuration command validates approved origin/path;
- shell also allowlists destination at render/navigation time;
- invalid destination is not clickable as live;
- admin fixes configuration.

---

## EC-29 — Product destination is down

**Recovery**  
- shell cannot promise product health solely from its own catalogue;
- if detected, show human unavailable/retry state where integration supports health;
- product entry failure returns user safely to shell/known URL.

---

## EC-30 — Product says Location unsupported despite shell LIVE

**Case**  
Shared config and focused-product readiness drift.

**Recovery**  
- focused Product refuses current action;
- preserve user session/context;
- flag reconciliation issue;
- shared Product should be PAUSED until readiness is restored.

This is an integration defect, not justification to weaken product rule.

---

## EC-31 — Two admins concurrently assign same Location Admin

**Recovery**  
- uniqueness/current-state constraint permits one active assignment;
- duplicate command returns existing/conflict;
- no duplicate authority.

---

## EC-32 — Location Admin tries another Location ID

**Case**  
URL/API tampering.

**Recovery**  
Server ignores UI intent as authority, resolves assignment scope and rejects cross-Location action.

---

## EC-33 — Ordinary Account invokes admin endpoint directly

**Recovery**  
Server rejects; hiding admin UI is not the security control.

---

## EC-34 — Client supplies fake verified timestamp / role / Product state

**Recovery**  
Ignore client authority/trust claim; read server-owned state.

---

## EC-35 — Old deep link opens after Product becomes PAUSED/OFF

**Recovery**  
Focused Product/shared landing checks current state; show unavailable/history-safe path rather than starting new activity.

---

## EC-36 — Wrong Account opens a deep link

**Recovery**  
Authenticate if required, then product/server validates object-specific access. Do not leak object existence/details beyond permitted response.

---

## EC-37 — Deep link contains tampered Location

**Recovery**  
Normalize and validate against shared/product current scope; explicit safe server truth wins.

---

## EC-38 — Product participant changes role/context

**Case**  
Same human has multiple product capabilities.

**Recovery**  
Product makes actor context explicit where actions differ; shared shell does not collapse them into one role.

---

## EC-39 — Product/provider disappears after being advertised as available

**Recovery**  
Product-specific marketplace owns provider availability; shared shell only claims Product availability, not individual provider guarantee unless explicitly integrated.

---

## EC-40 — Verification evidence expires after page was loaded

**Recovery**  
Consequential action requiring verification rechecks current server claim; stale badge/display cannot authorize.

---

## EC-41 — Sponsored content expires while cached

**Future**
Expired placement must not remain indefinitely visible. Cache invalidation/freshness policy required before ads launch.

---

## EC-42 — Sponsored advertiser also has organic listing

**Future**
Paid placement is separately labelled; payment does not merge into verification/organic legitimacy.

---

## EC-43 — User asks to delete Account

**Status**
Full Account deletion/anonymization lifecycle is deferred.

**Recovery now**
Do not implement destructive delete behind a vague button. Until policy is frozen, no production shared Account closure/delete flow.

---

## EC-44 — User wants Location not yet supported

**Recovery**
Do not fake nationwide coverage. Show current supported Locations only. A future interest/waitlist flow requires its own product rule and consent/data design.

---

## EC-45 — Manual GPS/location guess conflicts with user selection

**Future optional location suggestion**
Explicit user's selected Raahi Location wins unless invalid. GPS is assistance, not authority.

---

## EC-46 — Duplicate Product registry key

**Recovery**
Reject atomically; stable key cannot be silently renamed/overwritten.

---

## EC-47 — Product retired while LocationProduct remains LIVE in stale data

**Recovery**
Public eligibility requires Product ACTIVE + Location LIVE + LocationProduct LIVE. Product retirement overrides stale child configuration.

---

## EC-48 — Location retired while child products remain LIVE in rows

**Recovery**
Public eligibility requires Location LIVE; child rows do not make retired Location public.

---

## EC-49 — Configuration corruption/inconsistent rows

**Recovery**
Server projection applies eligibility invariants; admin/operational correction through audited runbook. Never let client repair authoritative state ad hoc.

---

## EC-50 — CI/prototype passes but real platform behavior differs

**Risk**
Treating buildability as technology proof.

**Recovery**
Classify as technology/integration evidence gap; Gate 13 requires real staging proof before architecture dependency is frozen.

---

# Cross-cutting recovery principles

1. **Preserve valid identity/session when the business draft fails.**
2. **Preserve history when current authority/availability changes.**
3. **Reject stale authority at execution, not just in UI.**
4. **Use idempotency for uncertain network outcomes.**
5. **Never manufacture trust/availability because an external service failed.**
6. **Prefer asking the user to reselect/reconfirm only the invalid portion, not restarting the entire journey.**
7. **Focused Product is final authority for its own transaction.**
8. **Public shell failure should not corrupt focused Product state.**
9. **Recovery paths must use human language and preserve safe context.**
10. **If no safe recovery rule exists, stop implementation at that feature rather than guessing.**

---

# Gate 6 result

**PASS for the current shared-front-door scope.**

Explicit unresolved recovery/design dependencies carried forward:
- Account recovery/provider linking;
- destructive Account deletion/anonymization;
- exact OTP challenge/freshness/rate semantics;
- exact cache freshness/degraded-mode semantics;
- auth-handoff persistence mechanism.

These do not block public discovery modelling, but relevant ones must be proven/resolved before shared Account/trust production implementation.

Next gate: **Gate 7 — revalidate minimum entities and relationships against Gates 0–6**.
