# Raahi Learning V1.3 — AI Builder Cheat Code v2 Retrofit Gate

Status: **INTERNAL RETROFIT CLOSED — R4 WALKING SKELETON PROVEN; REPRESENTATIVE PERSONA / UI CONVERGENCE IS NEXT.**

## 1. Decision

Raahi Learning will **not** return to Gate 0 or redesign the product from scratch. The existing domain remains authoritative unless a real contradiction, security/privacy defect, regulatory requirement, failed usability/E2E scenario, pilot evidence, or proven technical impossibility appears.

The one-time AI Builder Cheat Code v2 retrofit added the execution layers that the earlier process underweighted:

1. technology proof;
2. Screen ↔ Backend contracts;
3. read/write permission symmetry;
4. side-effects completeness;
5. one real walking-skeleton E2E journey;
6. vertical-slice implementation for remaining work;
7. adversarial/persona regression before launch readiness.

The internal contract/test portion of that retrofit is now closed. Do not restart broad feature work while the external Auth proof remains unproven.

## 2. Frozen product/domain rules

These remain unchanged:

- Account ≠ Learner;
- one Account may learn, teach, manage a Learner and represent an Organization;
- one managing guardian per Learner in V1;
- no turning-18 migration;
- no public Learner directory;
- controlled Enquiry before contextual relationship messaging;
- optional Trial;
- pending Class Invitation reserves capacity;
- one Class model for 1:1 and group learning;
- learner-side authority for Class acceptance/transfer/leave;
- parent cannot impersonate Learner for Tests;
- Activity/Test lifecycle/history rules;
- education-only governed Ads isolated from private learning;
- PostgreSQL remains operational source of truth;
- UI never directly mutates core operational tables;
- canonical RPCs re-check current authority/state;
- Realtime invalidates/refetches only;
- private Storage re-checks current authorization;
- consequential commands remain idempotent;
- no public ratings, attendance or generic progress percentage in V1.

## 3. Defect classification rule

Before any significant fix, classify it:

- **Domain defect:** rules/entities/relationships/states cannot safely represent a legitimate required scenario. Run full impact analysis: `rules → entities → relationships → states → permissions → UI → tests → architecture/DB`.
- **Integration defect:** valid layers do not connect correctly. Fix the contract/integration; do not redesign the domain.
- **Implementation defect:** agreed contract is right but code is wrong. Patch the smallest vertical slice and regress.
- **Test/harness defect:** product behavior is right but fixture/oracle/harness is stale or wrong. Fix the test, never weaken an invariant.

## 4. Gate R1 — Technology proof

### Proven

- canonical PostgreSQL RPC/state model;
- RLS/privilege separation;
- idempotency behavior;
- invitation/capacity transactional rules;
- governed Storage authorization;
- notification derivation mechanics;
- private bearer-token invitation pattern;
- server-derived phone-trust projection from Supabase Auth data;
- 90-day phone-trust command gating in DEV;
- real hosted Google → Supabase Auth round trip;
- one Auth user ↔ one Raahi Account continuity;
- real hosted phone attachment while preserving the same Auth user / Account;
- Class Invitation acceptance interruption on missing trust and successful resume after fresh phone proof.

The periodic **same-phone refresh** ceremony remains a provider-specific pre-launch smoke case. It is intentionally separate from ordinary product regression and does not block the completed R4 walking skeleton.

**R1 status: PASS FOR CURRENT PRODUCT / WALKING-SKELETON TECHNOLOGY ASSUMPTIONS.**

See `51-hosted-auth-r4-walking-skeleton-closure-v1.3.md`.

## 5. Gate R2 — Screen ↔ Backend contracts + permission symmetry

The route/contract audit is complete and the finite internal findings have been closed.

After closure:

- reachable canonical routes: **84**;
- desktop/mobile live contract: **168/168 PASS**;
- route/workspace guard failures: **0**;
- focused V1.3 action contracts: **12/12 PASS**;
- privileged deep-link checks: **32/32 PASS**;
- semantic checks: **15/15 PASS**;
- workspace checks: **154/154 PASS**;
- interaction checks: **26/26 PASS**.

Closed findings include live `teacher-members`, exact Community report targeting, `community-post` route inventory, capability-aware Organization controls, safe Notification destinations, private invite OAuth query hardening, and stronger test oracles.

**R2 status: PASS for the internal/browser/backend contract layer.** The phone interruption/resume path remains part of R1/R4 because it requires real hosted Auth.

See `45-v1.3-screen-backend-contract-audit.md` and `47-ai-builder-v2-internal-retrofit-closure-v1.3.md`.

## 6. Gate R3 — Side-effects matrix

The side-effects decision matrix is complete and frozen in `46-v1.3-side-effects-matrix-audit.md`.

Rules remain:

- notification failure does not undo committed core state unless a business rule explicitly requires atomic delivery;
- notifications never grant authority;
- private message bodies are not copied unnecessarily;
- Sponsored viewer push is prohibited;
- expiry correctness does not depend on browser timers or notifications;
- separate audit is added only where the business row does not preserve enough actor/time/outcome evidence.

Non-walking-skeleton side-effect implementation gaps remain deliberately queued for their owning vertical slices after R4. Do **not** implement them as another horizontal notification project.

**R3 status: AUDIT PASS / IMPLEMENTATION QUEUED BY VERTICAL SLICE.**

## 7. Gate R4 — Mandatory real walking skeleton

The required cross-layer journey is now **PROVEN in Learning DEV**.

Evidence covers:

1. real hosted Auth / Account continuity;
2. Learner authority setup and manager→self handoff;
3. discovery/provider relationship and canonical Enquiry;
4. provider engage/reply;
5. Class creation/activation and pending Invitation capacity reservation;
6. phone-trust interruption before acceptance;
7. supported hosted phone proof on the same Auth user / Account;
8. resumed acceptance with exactly one Membership;
9. authorized Class projections;
10. contextual Class message sent through the normal browser UI;
11. receiver Notification shown in the normal Notifications UI;
12. actual Notification **Open** button routing to the safe Class-thread deep link;
13. server reauthorization on deep-link open;
14. unrelated projection + RLS + browser denial with no private thread data leaked.

The ordinary regression form of the final boundary uses genuine DEV test sessions and isolated cloud browsers, not fixture business results.

**R4 status: PASS.**

See `50-dev-test-identity-session-harness-v1.3.md` and `51-hosted-auth-r4-walking-skeleton-closure-v1.3.md`.

## 8. Gate R5 — Vertical slices only after R4

After the walking skeleton passes, every remaining slice must close:

`database/state → canonical command → projection → permissions → side effects → UI → browser action test → DB/runtime test → old regression suite`.

Queued examples include remaining Enquiry/Trial side effects, Class/Session/Membership/post effects, Activity review effects, Test-correction effects, Organization authority-change effects, Storage browser E2E, and account closure/recovery journeys.

## 9. Gate R6 — Persona/adversarial E2E

After vertical slices, run whole stories including:

- adult learner;
- parent with one/multiple Learners;
- Learner without/with later self-access;
- teacher and teacher+parent;
- institute owner and limited-capability staff;
- invite recipient;
- Local Manager;
- advertiser/operator;
- Platform Admin;
- wrong Google account;
- stale/changed phone;
- shared-device context switching;
- revoked authority;
- expired/replayed invitation;
- concurrent last-seat acceptance;
- unrelated-account deep-link tampering;
- copied private file URL;
- direct DML attempt;
- weak-network/retry/duplicate-click behavior.

UI/workspace selection never grants authority.

## 10. Gate R7 — Reliability/security/launch

Before any public launch claim:

- full frozen DB regressions PASS;
- V1.3 regressions PASS;
- browser persona E2E PASS;
- Security Advisor has no material findings;
- true concurrent races are tested;
- p50/p95/p99 under representative load are measured;
- pool/lock/deadlock/timeout behavior is checked;
- soak and Storage browser authorization are tested;
- external Auth/SMS failure recovery is tested;
- no DEV fixed OTP mapping reaches production;
- production OAuth redirects/secrets/environment are reviewed;
- synthetic DEV data is cleaned;
- explicit go/no-go report exists.

Security Advisor after migration 1021 currently reports **0 findings**.

## 11. Immediate continuation rule

The sequence is now:

1. keep the proven DEV genuine-session harness as the regression foundation;
2. expand to a bounded representative persona cohort;
3. begin frozen-prototype UI / interaction convergence using autonomous browser evidence;
4. close remaining work one vertical slice at a time;
5. run adversarial/recovery/concurrency/persona regression;
6. complete reliability/security/load/launch gates.

Do not return to repeated manual Google logins for ordinary regression. Google OAuth and SMS/OTP remain small provider-specific smoke suites.

Current control document: `52-master-lifecycle-gates-traceability-v1.3.md`.

## 12. What this retrofit is not

It is not restarting brainstorming, recreating the database, chasing cosmetic imperfections, adding fake Auth, or shipping without real cross-layer evidence.

It is a finite closure pass that has now reduced the next unknown to the real hosted Auth boundary.