# Raahi Learning — First Genuine Founding Supply Closure — 2026-09-23

Status: **CLOSED — FIRST GENUINE TEACHER PUBLISHED BY TEACHER CONSENT**

Repository: `rajeevbackup42112-coder/raahi`  
Branch: `raahi-learning-implementation-v1`  
Supabase: `iiwwmqokaeflaenhlyip`  
Public: `https://learning.myraahi.co.in`

## 1. What this proof established

The first genuine assisted Teacher journey has now completed end to end through the real production UI, real Google-authenticated Teacher session, real phone trust, canonical RPCs and public Explore.

No operator published for the Teacher.

The Teacher explicitly chose **Publish these details**.

## 2. Teacher-provided facts used

Only user-provided facts were used:

- teaches: Class 9–12 Mathematics;
- experience: 10 years;
- mode: home tuition + coaching;
- area: Gomoh;
- fee: ₹3000/month.

Private draft wording was kept conservative:

- headline: **Class 9–12 Mathematics Teacher**
- experience: **10 years teaching Class 9–12 Mathematics.**
- first option: **Class 9–12 Mathematics Tuition**
- category: **Mathematics**
- description: **Home tuition and coaching for Class 9–12 Mathematics in Gomoh.**
- teaching mode: **in_person**
- area: **Gomoh**
- fee: **₹3000/month**
- bio: blank

## 3. Consent boundary

Before Teacher publication:

- assisted request: `draft_ready`;
- public Teacher Profiles: **0**;
- public Teaching Options: **0**;
- active `teach` capability: **0**.

The private draft was visible to the same Teacher for exact review.

The operator did not press Publish and did not grant teaching authority manually.

## 4. Phone-trust incident and fix

On the first publication attempt, the Teacher entered a mobile number that was already confirmed on another Supabase Auth / Raahi sign-in.

Observed:

- OTP send succeeded;
- verification/attachment failed;
- old UI surfaced a generic Edge Function / 502-style failure.

Root cause:

Supabase Auth keeps confirmed phone numbers unique. The current Google-authenticated Teacher Account could not claim a phone already owned by a different Auth user.

Repair:

- StartMessaging Edge Function now checks Auth phone ownership **before provider send**;
- ownership is rechecked immediately before Auth attachment for race safety;
- duplicate phone returns safe code `PHONE_ALREADY_IN_USE`;
- frontend maps it to:
  **This mobile number is already linked to another Raahi sign-in. Use a different mobile number or sign in with the account that already uses it.**
- the existing phone-uniqueness/security boundary was preserved; no identity data was moved automatically.

The original challenge later became `expired`.

The Teacher then used a different mobile number.

Final phone state:

- Auth phone confirmed: **yes**;
- latest StartMessaging challenge: **verified**;
- verification attempts on successful challenge: **1**.

## 5. Exact-action resume

The original **Publish these details** action remained preserved across the phone-security interruption.

After the alternate number was verified, Raahi resumed the exact pending canonical assisted-accept action.

No second Publish click or operator-side publish was needed.

## 6. Final canonical state

Read-only production verification after Teacher consent:

- active `teach` capability: **1**
- Teacher Profiles: **1**
- Teaching Options: **1**
- assisted request state: **accepted**
- resolution reason: `teacher_accepted_exact_draft`

Teacher Profile:

- headline: **Class 9–12 Mathematics Teacher**
- visibility: **visible**

First Teaching Option:

- title: **Class 9–12 Mathematics Tuition**
- category: **Mathematics**
- mode: **in_person**
- area: **Gomoh**
- fee: **₹3000/month**
- availability: **taking_new_learners**

## 7. Public-market proof

Genuine production browser verification at **Explore Gomoh** shows:

- **Class 9–12 Mathematics Tuition**
- provider: **Rajeev Sinha**
- headline: **Class 9–12 Mathematics Teacher**
- location: **Gomoh**
- fee: **₹3000/month**
- state: **Taking new learners**

Therefore the supply item is not merely present in the database; it is discoverable through the intended public marketplace surface.

## 8. Teacher ownership proof

Using the same genuine Teacher browser session:

- Teacher Home is accessible;
- **Edit profile** is present;
- **Manage** is present for Teaching Opportunities;
- Teacher Profile edit opens successfully;
- the Teacher is the server-owned Account behind the Profile/Teaching Option.

No URL change was used to grant teaching authority; the capability came only from the accepted canonical assisted-onboarding command.

## 9. Final production cleanup

Final public frontend source:

`e4010e3c4120c9e3cd832fd593a2df1a2edfa8a3`

Production Cloudflare Pages deployment:

`e2c0f704-b065-46c5-a861-4e5c325f58d1`

Exact URL:

`https://e2c0f704.raahi-learning-prod.pages.dev`

Immediate rollback anchor:

- deployment: `4cea554e-b3ea-4af0-8260-130c87014ad0`
- source: `fea1e26`

Release verification:

- custom-domain build-meta source = `e4010e3`;
- release mode = `CONTROLLED_PILOT`;
- file hash mismatches = **0**;
- packaged forbidden DEV/secret references = **0**;
- production source contains the clear duplicate-phone guidance.

Final Teacher workspace reload shows:

- **Access confirmed**
- not **Server-authorized**.

## 10. Regression evidence

Latest relevant gates:

- Model Tests **#747** — success on final presentation cleanup;
- Onboarding Browser Contract **#20** — success on the immediately preceding functional source, covering the full critical onboarding/browser flows;
- genuine production Teacher publish and public-discovery smoke — success.

Browser Contract #20 includes the existing sealed Chromium suites for:

- profile + first-use intent;
- self-service and assisted Teacher + phone-resume;
- self Learner / Parent / Institute / context switching.

## 11. Product conclusion

The first genuine Founding Supply proof is complete.

The proven path is now:

**ordinary Google Account → Start teaching → assisted request → operator prepares private draft from Teacher-provided facts → same Teacher reviews → phone trust when required → exact Publish action resumes → teach capability + Profile + first Teaching Option created canonically → public Explore visibility → Teacher-owned edit controls.**

This closes the original first-real-Teacher launch gate.
