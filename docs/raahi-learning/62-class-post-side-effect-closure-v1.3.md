# Raahi Learning V1.3 — Class Post Side-Effect Closure

Status: **PROVEN IN LEARNING DEV**  
Date: 2026-09-18

Closed gaps:

- **SE-04A** — provider important/announcement Class posts notify active learner-side Accounts;
- **SE-04B** — learner Class questions notify the provider side.

Migration:

- `1025_v13_class_post_side_effects.sql`

## Explicit no-push behavior preserved

- ordinary provider Class update: refresh-only;
- ordinary learner Class update: refresh-only;
- Class post comments: refresh-only.

## Privacy and authority

- notification bodies do not copy Class-post body text;
- notifications carry opaque Class/post identifiers only;
- notification Open routes to the ordinary Class surface and current authorization is rechecked;
- unrelated Accounts receive no signal and cannot read the Class projection.

## Automated proof

GitHub Actions run: `35341050959`  
Exact deployed/tested commit: `8c6a5f7ee54a561449eb905ff945d270849ff0da`  
Evidence artifact: `raahi-learning-class-post-side-effects-35341050959-1`  
Artifact digest: `sha256:0063996b8dadf56d84757ca29e16f5f03e3bc468f4de69706aba21298ec92ed0`

Result: **PASS**

Proof IDs:

- Learner: `102686be-481b-4c60-937a-062efeaa135b`
- Class: `75d781a9-faf6-4093-9958-513b1388076d`
- Membership: `c089d5e6-a7f5-49e5-b0e0-8b0f77434664`
- Announcement post: `74d516ba-60cc-4a1b-a8a5-3d7db7e194d5`
- Learner question: `cbcb22e4-041c-4200-8a01-fe30e0caf85d`

Independent database cross-check:

- announcement row remains visible and generated exactly one `class_announcement` notification;
- learner question row remains visible and generated exactly one `class_question` notification.

## Proven checks

1. Ordinary provider post produced no push.
2. Provider announcement produced exactly one learner-side notification.
3. Provider important update produced exactly one learner-side notification.
4. Provider post body was not copied into notification.
5. Ordinary learner post produced no push.
6. Learner question produced exactly one provider-side notification.
7. Learner question body was not copied into notification.
8. Idempotent retries produced no duplicate signal.
9. Class post comments produced no push.
10. Notification Open re-entered the authorized Class.
11. Unrelated Account received no signal and Class projection was denied.

## Next

Proceed to **SE-05A–SE-05E**: Class Membership leave/remove/transfer, Class completion, and Class activation audit.
