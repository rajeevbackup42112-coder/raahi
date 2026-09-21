# Raahi Learning — Raahi Desk Provenance Domain Contract V1.4B

Status: **IMPLEMENTATION CONTRACT — MARKET ACTIVATION SLICE 1**

Parent blueprint: `92-market-activation-seeding-blueprint-v1.4.md`

## 1. Problem

A new Location needs useful Community content before organic activity is dense enough to make the network feel alive. Raahi may publish genuine editorial guidance as the platform, but must never disguise platform-created material as independent user activity.

The first market-activation slice therefore adds a truthful, auditable **Raahi Desk** publishing path for local Community posts.

> Seed usefulness, never fake popularity.

This slice does not create teachers, learners, Learning Requests, enquiries, comments, reactions, ratings or successful-match signals.

## 2. Actors and authority

### Ordinary authenticated Account
May continue publishing normal Community posts through the existing `publish_community_post` command when all existing Community rules pass.

### Platform Admin
May publish a local Raahi Desk editorial post through a new canonical command.

The first slice deliberately does **not** reuse Local Manager moderation authority as editorial publishing authority. Moderating a Location does not automatically grant the right to speak for Raahi. A scoped Desk capability may be introduced later if operational need proves it necessary.

### Public/authenticated reader
Sees Raahi Desk content in normal local Community discovery with explicit platform attribution.

## 3. Provenance model

Every Community post receives a server-owned `provenance_kind`.

Allowed values:

- `organic` — authored and published by the Account through the normal Community command.
- `platform_editorial` — published through the Raahi Desk command by an authorized Platform Admin.
- `assisted` — reserved for a later separately-governed slice representing genuine user content published with explicit assistance/permission.

Migration default for all existing rows: `organic`.

No browser field may choose or forge provenance.

For `platform_editorial`:
- the real operator Account remains stored internally in `author_account_id` for auditability;
- public projections present the author as **Raahi Desk**;
- public projections do not expose the operator Account ID as the apparent public author;
- personal block relationships must not silently hide Raahi Desk editorial posts, because the public author is the platform rather than the operator as a private person;
- users may still report a Raahi Desk post for moderation/review.

## 4. State and lifecycle

This first slice reuses existing Community visibility state:
- `published`
- `hidden`
- `removed`

No separate draft/scheduled editorial workflow is introduced yet.

A Raahi Desk post is created directly as `published` only after the canonical command verifies:
- authenticated active Account;
- active `platform_admin` capability;
- target Location exists and is `live`;
- valid Community post type;
- nonblank body within existing Community length bounds;
- optional external URL follows the same storage model as ordinary posts;
- idempotency key is valid and request fingerprint matches on retry.

## 5. Invariants

1. Existing Community rows become `organic` without changing their meaning.
2. Ordinary `publish_community_post` can create only `organic` posts.
3. Browser/client direct writes to `community_posts` remain denied.
4. Only the new canonical Raahi Desk command can create `platform_editorial` in this slice.
5. Platform Admin authority is checked server-side on every new execution.
6. Same idempotency key + same request returns the same logical post; same key + changed request fails.
7. Raahi Desk never creates or simulates reactions/comments.
8. Public Community projections expose explicit provenance.
9. Public Raahi Desk attribution is always exactly `Raahi Desk`; it cannot be supplied by the caller.
10. Internal operator identity remains available to audit and moderation code but is not rendered as the public author.
11. Editorial content remains tied to one real live Location.
12. Existing Community moderation/report semantics remain intact.
13. Existing organic-user block semantics remain intact.
14. No new public table grants are introduced.
15. No SECURITY DEFINER function is placed in `public`; the public RPC wrapper remains SECURITY INVOKER and delegates to an internal guarded command.

## 6. Canonical command contract

New browser-callable RPC:

`public.publish_raahi_desk_post(p_location_id uuid, p_post_type text, p_body text, p_external_url text, p_idempotency_key text) -> jsonb`

Permitted effect:
- insert one Community post with `provenance_kind='platform_editorial'`;
- record the invoking Platform Admin Account internally as `author_account_id`;
- write a Location audit entry `community.raahi_desk_publish`;
- return `post_id`, `visibility_status`, `provenance_kind` and public attribution label.

Failure examples:
- `PLATFORM_ADMIN_REQUIRED`
- `LOCATION_NOT_LIVE`
- `INVALID_POST_TYPE`
- `INVALID_POST_BODY`
- existing idempotency errors

The command does not accept a public author name, Account ID, engagement count, timestamp override or provenance value.

## 7. Read-contract changes

`discover_community_posts` and `get_community_post` add:

- `provenance_kind`
- `attribution_label`
- `is_platform_editorial`
- `can_block_author`

For organic posts:
- `author_account_id` remains the real author Account ID;
- `author_name` remains the Account display name;
- `attribution_label` is null;
- `can_block_author=true`.

For Raahi Desk:
- `author_account_id=null` in the public projection;
- `author_name='Raahi Desk'`;
- `attribution_label='Platform-authored'`;
- `is_platform_editorial=true`;
- `can_block_author=false`.

The underlying row still retains the operator Account ID.

## 8. UI contract

Community:
- Raahi Desk cards show **Raahi Desk** plus a compact **Platform-authored** badge.
- Raahi Desk detail shows the same platform-authored provenance explicitly.
- Report remains available.
- Block-author is not offered for platform-editorial content.
- Comments and helpful reactions remain genuine user actions and are counted normally.

Platform workspace:
- a Raahi Desk route is available only when the current authorized workspace is Platform.
- the form asks for Location, post type, body and optional external link.
- the form contains explicit copy that content will publish publicly as Raahi Desk.
- successful publish refreshes Community from the server and opens the selected Location Community.

No hidden fixture/fake-post path is introduced.

## 9. Acceptance tests

### Schema/provenance
- Existing posts read as `organic`.
- Constraint rejects unknown provenance.
- Direct authenticated table insert remains denied.
- Ordinary publish produces `organic`.
- Raahi Desk publish produces `platform_editorial`.

### Authority
- Account without `platform_admin` is denied.
- Platform Admin can publish to a live Location.
- Platform Admin is denied for non-live/unknown Location.
- Caller cannot choose attribution or another author.

### Projection/privacy
- Raahi Desk public projection says `Raahi Desk`.
- Operator Account ID/name is not emitted as the public author.
- Organic post projections are unchanged except for additive provenance fields.
- Blocking a Platform Admin as a person does not hide platform-editorial posts.
- Blocking an organic author still hides that author’s organic posts.

### Integrity
- Idempotent retry returns one post.
- Reusing the same key with modified body fails.
- No reaction/comment rows are created by Raahi Desk publish.
- Location audit records the real operator and post target.

### Browser
- Platform workspace exposes Raahi Desk composer.
- Non-platform workspace does not expose the composer.
- Published item appears in Community with the Platform-authored badge.
- Community menu for Raahi Desk offers Report but not Block author.

## 10. Deferred deliberately

Not part of Slice 1:
- Assisted-user publication and consent evidence.
- Unclaimed organisation/provider listings.
- Founding Teacher badge.
- editorial drafts/scheduling/recurring automation.
- platform-authored comments.
- analytics dashboards for organic/assisted/editorial percentages.
- Local Manager Desk publishing authority.

Those require their own authority/provenance contracts rather than being smuggled into this migration.
