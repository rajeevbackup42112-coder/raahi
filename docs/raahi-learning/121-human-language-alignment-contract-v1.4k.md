# Raahi Learning V1.4K — Human Language Alignment Contract

Status: **PRESENTATION ALIGNMENT SLICE — NO AUTHORITY OR DOMAIN CHANGE**

Companion: `119-canonical-alignment-audit-prelaunch-2026-09-23.md`

## 1. Problem

The frozen product deliberately keeps capability, authorization, Membership, Account-internal and invariant terminology out of ordinary user journeys.

Later implementation layers preserved those rules correctly but exposed some of the internal vocabulary directly on Teacher setup, My Classes and Learning profiles.

Examples include:

- Teacher capability;
- Server-authorized on this Account;
- relationship-scoped Classes;
- Membership;
- current authority;
- learner-side access path;
- server rechecks this invariant;
- consent version.

These are valid implementation concepts, but normal users should not need to understand them.

## 2. Rule

**Strict authority underneath; ordinary human language above.**

This slice changes copy/presentation only.

It must not change:

- Account / Learner identity;
- teaching capability behavior;
- Teacher publication rules;
- Class Invitation / Membership state;
- guardian/learner authority;
- phone trust;
- Founding Supply consent;
- canonical RPC calls;
- RLS or table permissions.

## 3. Teacher setup target

Replace implementation vocabulary with:

1. **About you** — introduction / teaching experience;
2. **What you teach** — subject / level / learning option;
3. **Where and how** — Location / online / in person / fee information;
4. **Review and publish** — user approves what becomes public.

Assisted setup still says clearly:

- Raahi prepares a private draft;
- nothing becomes public until the Teacher chooses Publish;
- the Teacher can decline/cancel;
- operator cannot publish for the Teacher.

The backend consent version remains stored/auditable but is not shown as a technical code in the normal review screen.

## 4. My Classes target

User-facing copy should explain:

- current Classes;
- pending invitations;
- accepting joins the learner to the Class after Raahi checks the invitation is still valid.

Do not expose `Membership`, `relationship-scoped`, or `authority` terminology.

## 5. Learning profiles target

Use:

- **My learning** for self access;
- **Managed by you** for a learner the Account manages;
- **Set up learner login** where appropriate;
- explain that ending management is allowed only when the learner will still have another valid way to access/manage their learning.

Do not expose `Account`, `access path`, or `invariant` wording to ordinary users.

## 6. Phone trust copy

Precision remains important, but ordinary copy should say:

**This is a security check for sensitive actions. It does not change what you can do in Raahi.**

No reference to roles/authority is necessary.

## 7. Acceptance

- no canonical RPC name changes;
- no database migration;
- no permission changes;
- existing model/security tests stay green;
- source tests prevent the removed internal phrases from returning to the ordinary surfaces;
- later real-browser regression verifies the same actions remain available/denied exactly as before.
