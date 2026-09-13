# Raahi Learning V1.3 — Start Here

**Repository:** `rajeevbackup42112-coder/raahi`  
**Implementation branch:** `raahi-learning-implementation-v1`  
**Canonical docs:** `docs/raahi-learning/`

## Current status

Raahi Learning V1.2 backend remains complete. The bounded **V1.3 backend/browser delta plus the one-time AI Builder Cheat Code v2 internal retrofit are closed in Supabase DEV**.

The active gate is now:

**real hosted Google/phone Auth proof → mandatory real walking skeleton → vertical slices only.**

DEV Supabase project: `iiwwmqokaeflaenhlyip` (`ap-south-1`).

No public deployment has been performed.

Read first:

1. `docs/raahi-learning/99-handover.md`
2. `docs/raahi-learning/47-ai-builder-v2-internal-retrofit-closure-v1.3.md`
3. `docs/raahi-learning/44-ai-builder-v2-retrofit-gate-v1.3.md`
4. `docs/raahi-learning/43-v1.3-implementation-checkpoint.md`
5. `docs/raahi-learning/41-authentication-phone-trust-v1.3.md`

## Product direction

Do not redesign the domain. Frozen rules still include `Account ≠ Learner`, one managing guardian in V1, controlled Enquiry, optional Trial, Invitation before Membership, guardian Test non-impersonation, local Community, no public Learner directory and governed education-only Ads.

The principal V1.3 amendment is:

**Google-primary authentication + selective 90-day phone trust.**

Google profile name/photo are editable onboarding defaults only. Phone verification is periodic trust/contact proof and must not become routine login or remove ordinary existing learning access merely because it is stale.

Do not add Family Supporters/multi-guardian complexity, anonymous marketplace browsing, fake OTP, attendance, generic progress %, public ratings/reviews, unrestricted DM, global Community, or other deferred complexity without new evidence.

## Applied V1.3 DEV delta

Applied migrations:

- `1015_v13_contextual_inbox_and_org_teacher_picker`
- `1016_v13_learner_self_access_invitations`
- `1017_v13_organization_member_invitations`
- `1018_v13_notification_transition_wiring`
- `1019_v13_notification_initial_enquiry_dedup`
- `1020_v13_phone_trust_projection`
- `1021_v13_phone_trust_command_guards`

V1.3 runtime markers pass and Supabase Security Advisor after 1021 reports **0 findings**.

## AI Builder v2 closure evidence

- reachable canonical routes: **84**;
- desktop/mobile live contract: **168/168 PASS**;
- issues: **0**;
- guard failures: **0**;
- focused V1.3 action contracts: **12/12 PASS**;
- privileged deep-link checks: **32/32 PASS**;
- semantic checks: **15/15 PASS**;
- workspace checks: **154/154 PASS**;
- interaction checks: **26/26 PASS**.

Internal gaps closed include `teacher-members`, exact Community report targeting, `community-post` route coverage, capability-aware Organization controls, safe Notification destinations, and private invitation OAuth query hardening.

## Source recovery

Run:

```bash
node apps/raahi-learning/build-source-v13.mjs
```

Verified immutable base tar:

`9aa71d002775f719970fcf6d48c324f4f3270ac9f65aa1c7e8a2f9f17c2dc9cc`

Verified retrofit patch:

- gzip: `8a68163024ef1b100ebc4d56b8b1cfa56bf3459fc9f897952b6ca5602a19afa9`
- raw: `ced0f5ca5b590e8ca344011f8f008c8fa719d57cca6ca3ead63b01a4fc6efc08`

Persistent backup:

`/Raahi Learning/Raahi_Learning_Integrated_V1.3_DEV.zip`

ZIP SHA-256:

`379dece3fb33fadd68843823a82917469b77e39b8d24448328b713ff98b246ef`

## Exact remaining boundary

1. verify hosted DEV Google provider configuration;
2. complete a real browser Google → Supabase session round trip;
3. prove `bootstrap_account` resolves the same Raahi Account across logout/login;
4. verify hosted DEV SMS/test-OTP configuration through an authorized Auth-management surface;
5. prove signed-in phone attach/reverify and server-owned confirmation state;
6. run the mandatory walking skeleton:
   **Google sign-in → Account/bootstrap → Learner context → discovery → Enquiry → provider engage → Class Invitation → phone interruption/resume → Membership → Class → contextual message**;
7. only then continue remaining work as vertical slices;
8. then persona/adversarial E2E, concurrency/load/security/chaos and launch readiness.

Do not claim production readiness or deploy publicly before those gates.

The repository `main` branch contains older Raahi work and must not be treated as the Raahi Learning implementation.