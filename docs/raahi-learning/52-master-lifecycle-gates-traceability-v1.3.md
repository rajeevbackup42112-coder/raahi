# Raahi Learning V1.3 — Master Lifecycle Gate Status + Traceability Spine

Status: **ACTIVE CONTROL DOCUMENT**  
Date: 2026-09-19

Purpose: provide one compact resume point for the AI Product Lifecycle Master Cheat Code v2.0 without duplicating the canonical product/domain documents.

## 1. Lifecycle gate status

| Gate | Status | Evidence / note |
|---|---|---|
| Existing-project truth reconstruction | PROVEN | GitHub, migrations, deployed DEV artifact and Supabase state were read before resuming implementation. |
| Problem / scope / non-goals | PROVEN | Frozen Raahi Learning product documents. |
| Actors / ownership / authority | PROVEN | Account ≠ Learner; manager/self/provider/Organization/admin authority frozen and implemented. |
| Rules / invariants / state lifecycles | PROVEN | AI Builder v2 retrofit + model/runtime suites. |
| Product freeze | PROVEN | Domain changes require explicit contradiction/impact analysis. |
| Architecture / source of truth | PROVEN | UI → canonical RPC → PostgreSQL; projections for reads; Realtime invalidation only. |
| Screen ↔ backend contracts | PROVEN | Docs 45/47; live contract and guard suites. |
| Side-effects decision matrix | PROVEN AS AUDIT | Doc 46; implementation continues only inside owning vertical slices. |
| Hosted Google + initial phone technology proof | PROVEN | Real Supabase Google/phone identities and continuity evidence. |
| Periodic same-phone refresh provider smoke | QUEUED | Keep in pre-launch Auth smoke suite; not an ordinary regression dependency. |
| DEV test identity/session harness | PROVEN | Doc 50; genuine sessions, OIDC-protected fixture boundary, RLS retained, isolated browsers. |
| Mandatory walking skeleton | PROVEN | Doc 51; includes Class message, notification Open deep link and unrelated denial. |
| Representative persona expansion | PROVEN | 20 genuine DEV identities/sessions, unique Accounts, own-row RLS allow/cross-row deny, 20 isolated Chromium sign-ins. See doc 53. |
| UI / interaction convergence | PROVEN FOR V1.3 WORKSPACE SURFACES | Core learner/teacher, managed-parent/Organization, Local Manager/Platform Admin, Raahi Ads, and bounded Organization staff capability surfaces are proven. See docs 54–58. |
| Remaining vertical slices | PROVEN IN DEV | SE-01 through SE-08 closed; see docs 60–67. |
| Post-SE-08 combined regression | PROVEN IN DEV | All 15 suites passed exact commit a9f7ae5; deployed marker independently verified. See doc 68. |
| Adversarial / recovery / race testing | PROVEN FOR BOUNDED DEV SCENARIOS | Last-seat race, real committed-response loss/recovery through a fresh client, concurrent same-key replay, stale-session denial, shared-browser account switching and private-cache isolation all pass. This is not production load certification. See docs 69–70. |
| Reliability / load / security / launch | ACTIVE — BOUNDED DEV RELIABILITY + CATALOG SECURITY PASS | 20 genuine personas, 800 authenticated reads, cross-account denial and 20 browser sign-ins passed with no latency warnings. DB health and migration-1032 rollback/recreate rehearsal are proven. Migration 1033 removes deferred-anonymous RPC grants; catalog audit reports no missing public RLS, public views/SECURITY DEFINER RPCs, PUBLIC/anon RPC execute grants, direct authenticated operational DML, or unsafe auth metadata patterns. Stage progression now uses the existing Free Learning project through a Gomoh+Dhanbad controlled pilot. Paid production isolation/capacity/restore, operational alerting, leaked-password protection and broader rollout remain deferred until pilot traction. See docs 71–73. |

## 2. Defect rule

Every failure is classified before a fix:

- **Domain** — legitimate required scenario cannot be represented safely; run full impact analysis.
- **Integration** — correct layers do not connect.
- **Implementation** — agreed contract is correct but code/UI is wrong.
- **Test-Harness** — product is correct but fixture/oracle/runner is wrong.

Only Domain defects reopen frozen product design.

## 3. Critical traceability spine

| Rule / invariant | Canonical transition / read | UI surface | Scenario / proof |
|---|---|---|---|
| Auth user maps to exactly one Raahi Account | `bootstrap_account`, `get_my_account_context` | hosted sign-in / Account bootstrap | real Google Auth continuity proof |
| Learner owns learning history; Account authority is explicit | `create_learner`, learner-access commands, account context | Learning profiles / learner context | manager→self handoff + R4 chain |
| New direct provider relationship begins as controlled Enquiry | `send_enquiry`, `engage_enquiry`, `send_enquiry_message`, Enquiry projections | Explore / Enquiry / Messages | R4 relationship chain |
| Pending Invitation reserves capacity; Membership only after acceptance | `send_class_invitation`, `accept_class_invitation`, Class projections | Class Invitation / My Classes | R4 capacity + exactly-one Membership proof |
| Sensitive acceptance requires fresh phone trust without changing authority | `get_my_phone_trust`, `accept_class_invitation` guard | phone-check interruption/resume | Rajeev 4 hosted phone attach + resumed acceptance |
| Class messages exist only inside an authorized Class+Learner relationship | `send_class_learner_message`, `get_class_learner_thread` | Class message | autonomous R4 browser proof |
| Notification never grants authority | derived `class_message` notification + projection recheck | Notifications → Open | teacher Open button routes to authorized deep link |
| Copied private link must fail closed for unrelated Account | `get_class_learner_thread` authorization + RLS | copied Class-thread URL | unrelated projection/RLS/browser denial |
| UI/workspace choice never grants authority | server-derived context/capability projections | role/workspace switcher | route/workspace guard suites |
| Browser never owns core operational state | canonical RPCs only | all consequential actions | contract/runtime audits; no direct browser DML |

## 4. Testing architecture

Normal product regression:

`GitHub Actions / isolated Chromium → DEV-only test login → genuine Supabase Auth session → normal Raahi UI → canonical RPC/RLS → PostgreSQL`.

Provider ceremony testing remains separate:

`small real Google / SMS-OTP smoke suite`.

Do not return to repeated manual Google login as the ordinary regression mechanism.

## 5. Immediate sequence

1. Preserve doc 68 as the post-SE-08 combined-regression anchor, docs 69–70 as bounded recovery/shared-browser closure, doc 71 as reliability/observability/recovery evidence, doc 72 as production-operations procedure, doc 73 as catalog-security hardening, doc 74 as production-like load/operator guard readiness, doc 75 as production-canary/recovery-inventory readiness, and doc 76 as the latest external-input boundary.
2. Treat `d0232c4fdb9410d4902063740974b7110da59473` as the bounded recovery/shared-browser product-code proof anchor. Do not pin a documentation/test-only `build-meta` SHA as the permanent deployed product state; read `build-meta.json` at execution time and verify `apps/raahi-learning/` source compatibility.
3. Preserve the successful bounded release-reliability proof on `10111144a2d00fb28d02a4217c4225a5188673b6` / run `35442347699`: 20 personas, 800 authenticated reads, 20 cross-account denials and 20 browser sign-ins, no latency warnings.
4. Do not run production-like load until an isolated Learning target and pilot traffic expectation exist; guarded harness/workflow are already prepared in doc 74.
5. Do not create infrastructure until explicit cost confirmation. Current connector quote: branch USD 0.01344/hour; new project USD 0/month. Current Supabase branching guidance makes a branch useful for migration preview but insufficient for the full Auth/Storage/restore/provider gate set, so a dedicated Learning project in `ap-south-1` is the recommended next target.
6. Turn the doc-71 monitoring design into real alert delivery/escalation when the production environment/channel is selected.
7. Define RPO/RTO and execute the already-prepared DB+Storage backup/restore procedure against an isolated target; compare `scripts/raahi-learning-recovery-inventory.sql` before/after.
8. Complete periodic real-provider same-phone refresh with user-held Google/SMS authentication, separately from the automated harness.
9. Resolve or explicitly accept the leaked-password-protection warning before launch.
9. Guarded manual production-like load workflow and backup scripts are prepared with explicit project separation/target-binding tests; see doc 74.
10. Guarded production-candidate canary and recovery inventory are prepared; current DEV inventory baseline is captured in doc 75.
11. Approved strategy is now same-project Stage Ready → controlled Gomoh+Dhanbad pilot, with paid production only after traction; see docs 76–77.
12. Current migration ceiling is `1034_v13_stage_gomoh_location`: Dhanbad `live`, Gomoh `preparing`.
13. Pilot cutover still requires synthetic cleanup, DEV-writer shutdown, backup, real providers/public origin and explicit go-live approval.

DEV migration ceiling is now `1033_v13_deferred_anonymous_location_rpc_acl`; migration 1032 remains the FK-index performance closure; the two former unindexed-FK advisor findings are closed. Do not remove young-system indexes merely because the DEV unused-index advisor has not observed traffic through them.

Do not restart product discovery or recreate already-proven architecture/database work.


## Stage Ready closure — 2026-09-19

**STAGE READY CLOSED.** Canonical evidence: `80-stage-ready-closeout-v1.3.md`.

Remaining gates are external-provider proof and controlled-pilot cutover only. No Domain/business-rule reopening is implied.


## Controlled pilot Google-only trust change — 2026-09-20

Decision record: `81-controlled-pilot-google-only-trust-v1.3.md`.

The first Gomoh + Dhanbad controlled pilot no longer requires phone proof.

Current pilot invariant:

**Authenticated Google identity is sufficient; phone verification must not be requested while `phone_trust_mode=controlled_pilot_google_only`.**

Impact was traced through:

rules → entities/relationships → states → permissions → UI → tests.

No entity/relationship/authority/RLS model changed.

Migration 1037 adds an explicit server-owned, fail-closed trust-mode setting. The existing central phone-trust guard remains in every owning command and resumes enforcement when the setting is returned to `phone_trust_required`.

Release configuration must match server policy:

- controlled pilot: `controlled_pilot_google_only` + provider `disabled`;
- future dedicated production: `phone_trust_required` by default until a real provider is explicitly proven.

MessageCentral is retired for the pilot and its deployed Edge Function is sealed at version 6.

Fresh Stage regression is required before the post-change baseline can be re-frozen.


## Google-only Stage re-closure — 2026-09-20

**STAGE READY CLOSED AGAIN.**

Canonical post-change evidence:

`82-stage-ready-google-only-pilot-closeout-v1.3.md`

Final current-source validation commit:

`61fd03555910cb16f744d653317c31986e1039cd`

Green proof set:

- Model Tests `35467717423`;
- DEV E2E `35467717381`;
- UI Core `35467717405`;
- UI Parent/Organization `35467717378`;
- UI Privileged/Admin `35467717353`;
- UI Ads `35467717394`;
- Organization staff boundaries `35467402738`;
- Organization authority side effects `35467397044` clean rerun.

Migration ceiling:

`1038_v13_remove_public_trust_policy_rpc`

Current server trust policy:

`controlled_pilot_google_only`

Phone trust remains architecturally preserved but is not enforced during the first controlled pilot.
