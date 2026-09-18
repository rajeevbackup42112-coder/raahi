# Raahi Learning V1.3 — Class / Membership Lifecycle Side-Effect Closure

Status: **PROVEN IN LEARNING DEV**  
Date: 2026-09-18

Closed gaps:

- **SE-05A** — learner leaves Class → provider notification + learner-side actor audit;
- **SE-05B** — provider removes learner → learner-side generic notification;
- **SE-05C** — same-provider transfer → destination-aware provider/other learner-side notification without actor self-notification;
- **SE-05D** — Class completion → affected learner-side notification;
- **SE-05E** — Class activation → actor audit only, no push.

Migration:

- `1026_v13_class_membership_lifecycle_side_effects.sql`

## Authority and privacy

- notifications are derived from committed membership transitions;
- removal reason is not copied into learner notifications;
- transfer notification contains source/destination Class IDs but no private message content;
- the acting learner Account is excluded from learner-side transfer notification to avoid self-notification;
- a removed learner is routed to **My Classes**, not force-opened into a Class projection that no longer authorizes that membership;
- completed membership remains readable through historical Class authority;
- unrelated Accounts receive no lifecycle signal and cannot read the Class projection.

## Automated proof

GitHub Actions run: `35341815439`  
Exact deployed/tested commit: `99710906586d14952cf3aa50ec9506b694948548`  
Evidence artifact: `raahi-learning-class-lifecycle-side-effects-35341815439-1`  
Artifact digest: `sha256:09b3618b9e6accbd3e9ea5712e129aea6e07f45ad81cd3db0b64133d49c745d1`

Result: **PASS**

## Key proof IDs / final states

- leave Membership `fc7dc7c0-82d3-4de2-9b7c-dda4f0634a1f` → `left`
- removed Membership `76e72f57-e240-4e97-9481-6adb1c36aff2` → `removed`
- transfer source Membership `a43db5ef-d8ed-4de2-99b6-40f9af7869bf` → `transferred`
- transfer destination Membership `6183b2c4-0497-442d-8abc-c6396757ede4` → `active`
- completed Membership `98368801-fb42-45fb-8833-d14a2b7c167b` → `completed`
- completed Class `7cf71b20-28e9-4b2a-91d9-31d24f29b5f2` → `past`

Independent DB cross-check shows exactly one signal for each tested lifecycle transition.

## Exact actor-history proof

Exactly one row each:

- `class.membership_leave` — learner-side actor;
- `class.membership_remove` — provider actor;
- `class.membership_transfer` — learner-side actor;
- `class.activate` — provider actor;
- `class.complete` — provider actor.

## Proven browser destinations

- learner-left provider signal → provider Class;
- transfer provider signal → destination provider Class;
- removed learner signal → My Classes safe destination;
- completed learner signal → historical/past Class.

## Next

Proceed to **SE-06A / SE-06B**: Activity submission/resubmission notification to provider and review outcome notification to learner-side Accounts.
