# Raahi Learning V1.4K — Learner, Parent, Institute and Context-Switching Contract

Status: **IMPLEMENTATION CONTRACT — LAUNCH-CRITICAL FIRST-USE CONTINUATION**

Companion:
- `119-canonical-alignment-audit-prelaunch-2026-09-23.md`
- `120-first-use-intent-alignment-contract-v1.4k.md`
- `122-google-profile-confirmation-alignment-contract-v1.4k.md`
- `123-teacher-onboarding-continuity-contract-v1.4k.md`

## 1. Goal

A clean Account must be able to continue beyond the first-use choice into a real, useful Raahi context without learning backend vocabulary.

Covered continuations:

- **I want to learn** → create my learning profile → My learning;
- **I’m helping someone learn** → add learner → Learners I manage;
- **I represent an institute** → create institute → Institute;
- established multi-context Account → switch among only contexts already authorized.

## 2. Authority model stays unchanged

The browser never manufactures a role.

Canonical commands remain the only writes:

- `create_learner(..., p_access_type='self')`;
- `create_learner(..., p_access_type='manage')`;
- `create_organization(...)`.

Context switching is a presentation choice over authority already present in `get_my_account_context`. It grants nothing.

## 3. Human context labels

Visible context labels should describe what the user is doing:

- learner / student → **My learning**
- parent → **Learners I manage**
- teacher → **Teaching**
- institute → **Institute**
- manager → **Local operations**
- platform → **Platform operations**
- ads → **Raahi Ads**

Internal route values and capability codes remain unchanged.

## 4. First-use completion

### Self learner

After `create_learner(access_type='self')` succeeds:

- refresh account context;
- current context becomes My learning;
- created Learner is selected;
- route to Home;
- no Parent/Teacher/Institute authority is implied.

### Parent / guardian

After `create_learner(access_type='manage')` succeeds:

- refresh account context;
- current context becomes Learners I manage;
- created Learner is selected;
- route to Home;
- parent cannot take a Learner’s Test as the Learner.

### Institute owner

After `create_organization` succeeds:

- refresh account context;
- select the created Organization;
- current context becomes Institute;
- route to Institute Home;
- only server-returned Organization capabilities determine visible actions.

## 5. Switching

For an established Account:

- selector contains only contexts derivable from current server authority;
- selecting a context does not call any authority-granting RPC;
- deep-linking to an unavailable context remains denied;
- selected context changes navigation/presentation only;
- underlying Learner/Class/Organization history is preserved.

## 6. Browser acceptance

At desktop and mobile size:

- clean self-learner journey submits the form and reaches useful Home;
- clean parent journey submits the form and reaches useful Home;
- clean institute journey submits the form and reaches Institute Home;
- resulting fake-backend contract state contains only the expected new relationship;
- no real Supabase network access is made in sealed browser contract;
- multi-context selector shows only authorized contexts;
- switching Parent ↔ Teaching (or another seeded combination) changes view without an authority mutation RPC;
- unavailable Platform/Admin view is not offered.

## 7. Non-goals

This slice does not alter:

- Learner ownership/history;
- guardian Test restrictions;
- Organization capability schema;
- invite flows;
- phone trust;
- genuine production data;
- Location persistence rules.
