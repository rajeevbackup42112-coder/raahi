# Raahi Learning V1.3 — Gomoh-First Public Launch Model — 2026-09-20

Status: **FROZEN LAUNCH MODEL — PUBLIC ADMISSION STILL REQUIRES FINAL APPROVAL**

## 1. Core Location rule

A Raahi Account is not permanently bound to one city or locality.

**Selected Location is the user's current local context.** A user may switch Locations whenever they want. The selected Location changes local discovery, Community context and other locality-scoped public surfaces, but it does not change or erase the user's identity, Learners, Classes, Messages, history or existing relationships.

Examples:

- a student may browse Gomoh, then switch to Dhanbad to discover options there;
- a teacher may be based in Gomoh and publish Teaching Options in Gomoh, Dhanbad or multiple configured Locations;
- the same model later extends to Topchachi, Bokaro, Ranchi and other configured Locations without creating a new account or a new product silo.

## 2. Launch scope

The first public launch should **not** technically restrict Raahi to Gomoh-only users.

Launch configuration:

- Dhanbad = `live`;
- Gomoh = `live`;
- both are normal selectable Locations;
- users may freely switch between them;
- initial acquisition/promotion = Gomoh-first;
- Dhanbad remains fully usable for users who choose it;
- future Locations are added as independent configurable Locations when operationally ready.

Gomoh is therefore the **first acquisition market**, not a hard authorization boundary.

## 3. Why this is the scalable model

This preserves one clean platform model:

**one Raahi identity → many selectable Locations → local context changes without changing authority/history**.

It naturally supports connected education markets such as Gomoh ↔ Dhanbad without introducing a special Dhanbad-region hierarchy or one-off geographic permission rules.

A future proximity/region layer may improve discovery ordering, but it is not required for V1 public launch and must not replace the simple selectable-Location model.

## 4. Existing implementation evidence

The current implementation already behaves this way:

- Gomoh became visible in the live Location chooser when its database state changed from `preparing` to `live`, without a frontend redeployment;
- both Dhanbad and Gomoh are returned by the authenticated Location projection;
- a genuine Google canary user changed Selected Location from Dhanbad to Gomoh;
- the canonical `get_my_account_context()` projection then returned `selected_location.slug = gomoh` and `state = live`;
- existing Account identity and authorization remained unchanged.

This is evidence that Location is configuration/context, not a hard-coded city silo.

## 5. Public-launch interpretation

When final go-live is approved:

1. Raahi becomes genuinely usable by ordinary Google users rather than only the current two OAuth test users.
2. The product remains a Dhanbad + Gomoh selectable-Location network.
3. Initial promotion, onboarding outreach and observation focus on Gomoh.
4. If a Gomoh user switches to Dhanbad, that is expected product behavior, not an exception.
5. Expansion to Topchachi/Bokaro/Ranchi later is primarily a Location-configuration and local-market readiness decision, not a new account model.

## 6. Final gate

Do not publish the Google OAuth app or admit the broader public until explicit final go-live approval is given.
