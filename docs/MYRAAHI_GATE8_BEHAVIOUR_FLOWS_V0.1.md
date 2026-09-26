# MyRaahi Shared Front Door — Gate 8 Behaviour Flows v0.1

Last updated: 2026-09-26

Method: AI Builder Cheat Code v2.0 — Gate 8

Behaviour format:

**Need → Decide → Act → Confirm / Recover**

Scope: shared `myraahi.co.in` front door and shared identity/location layer. Focused-product business flows remain owned by those products.

---

# 1. Brand-new visitor — first 10 minutes

## BF-01 — First visit, no Account

**Need**  
“I heard of Raahi. What can it actually do for me here?”

**Decide**  
Choose the town/locality relevant right now.

**Act**
1. Open `myraahi.co.in`.
2. See Raahi brand and “How can Raahi help you today?”
3. Choose Location manually.
4. See only Products genuinely available there.
5. Open one relevant Product.

**Confirm**
- selected Location is obvious;
- available Product choices match that Location;
- no sign-in was demanded before value.

**Recover**
- if Location unavailable, choose another;
- if catalogue fails, retry;
- if no Product live, Raahi says so honestly instead of filling the page with fake options.

---

## BF-02 — First visit, user does not understand “Location”

**Need**  
User wants a service, not to learn Raahi terminology.

**Decide**  
Recognize familiar town names.

**Act**
- tap a simple “Choose location” control;
- select Gomoh/Dhanbad/etc.

**Confirm**
- UI says “Available in Gomoh” rather than exposing internal market/tenant terminology.

**Recover**
- user can reopen/change Location at any time.

---

## BF-03 — First visit enters Product and only later needs Account

**Need**  
User wants to inspect a teacher/route/shop/doctor option.

**Decide**  
Browse enough to know the Product is relevant.

**Act**
1. Enter focused Product publicly.
2. Browse allowed public discovery.
3. Prepare a meaningful action.
4. Product explains why sign-in is needed.
5. Authenticate.
6. Resume safe prepared context.
7. Product revalidates and completes action if still valid.

**Confirm**
- user did not lose Location/draft unnecessarily;
- Account identity is clear before final consequence where wrong-account risk matters.

**Recover**
- cancel auth → return to safe public context;
- stale draft → keep session and refresh only invalid portion.

---

# 2. Returning visitor — next day

## BF-04 — Logged-out returning visitor

**Need**  
“Take me back to what works in my town.”

**Decide**  
Use previously chosen Location if still valid.

**Act**
1. Open home.
2. Shell reads browser preference.
3. Server validates Location is still selectable.
4. Show current catalogue.

**Confirm**
- user sees Location clearly;
- catalogue is current, not yesterday’s hard-coded screen.

**Recover**
- saved Location paused/retired → explain and ask for another;
- storage missing → simple chooser, no forced Account.

---

## BF-05 — Returning authenticated Account

**Need**  
Use Raahi again without re-onboarding.

**Decide**  
Continue current explicit Location or saved preference when no newer explicit choice exists.

**Act**
- open shared shell or focused Product;
- resolve Account/session;
- retrieve minimal shared context only when needed.

**Confirm**
- existing profile/identity is recognized;
- product-specific relationships remain intact.

**Recover**
- expired session → authenticate and return safely;
- saved Location invalid → choose another without losing Account history.

---

# 3. Day-30 established user

## BF-06 — Established user uses multiple Raahi Products

**Need**  
Same person may use Learning for child, Shops for household, and Mobility for travel.

**Decide**  
Choose today’s need, not a permanent platform role.

**Act**
1. Open Raahi.
2. Confirm/change Location.
3. Choose Product.
4. Focused Product resolves the relevant actor context.

**Confirm**
- homepage does not ask “Are you a learner or driver?” globally;
- one Account can enter different product contexts.

**Recover**
- if Product-specific authority changed, Product handles it without corrupting shared Account.

---

## BF-07 — Established user travels to another city

**Need**  
“I am normally in Gomoh, but today I need something in Dhanbad.”

**Decide**  
Explicitly change Location to Dhanbad.

**Act**
- switch Location;
- see Dhanbad catalogue;
- enter Product.

**Confirm**
- old Gomoh history remains;
- current session stays in Dhanbad until changed;
- change does not grant Dhanbad provider/admin authority.

**Recover**
- switching back restores Gomoh catalogue; no identity duplication.

---

# 4. Multi-capability human

## BF-08 — Account holder is both ordinary user and Location Admin

**Need**  
Use Raahi personally, then manage local configuration.

**Decide**  
Enter explicit admin context only for admin task.

**Act**
- normal shell shows ordinary user experience;
- admin surface requires current scoped server authority;
- admin changes one Location/Product configuration through canonical command.

**Confirm**
- personal Location selection is not treated as admin scope;
- admin action is audited.

**Recover**
- assignment revoked mid-session → command denied, user can continue ordinary Raahi use.

---

## BF-09 — Account holder is participant in several focused roles

**Need**  
A teacher might also be a parent; a shop owner may also book rides.

**Decide**  
Focused Product presents the relevant context where necessary.

**Act**
- shared shell routes to Product;
- Product resolves relationship/capability and asks user to choose context only if action differs.

**Confirm**
- no one permanent global role overwrites the others.

**Recover**
- if one product capability ends, unrelated Account/Product access remains.

---

# 5. Deep-link / WhatsApp entry

## BF-10 — Shared Raahi Product deep link

**Need**  
Someone receives a link to a Raahi Product/page via WhatsApp.

**Decide**  
Understand what Location/Product the link concerns.

**Act**
1. Open deep link.
2. Product/shared route validates safe Location/context.
3. Public content may render without auth where allowed.
4. Consequential/private action triggers auth if necessary.

**Confirm**
- link does not expose private data;
- selected Location is clear;
- sign-in returns to the intended safe destination.

**Recover**
- expired/invalid link → human explanation + closest safe public destination;
- wrong Account → product access check denies without leaking protected details.

---

## BF-11 — Deep link conflicts with existing selected Location

**Need**  
User in Gomoh clicks a valid Dhanbad Product link.

**Decide**
Explicit link intent may represent a temporary new Location context, but must be made visible.

**Act**
- show Dhanbad context clearly;
- user may accept/switch if required by Product flow.

**Confirm**
- no silent city change hidden from user.

**Recover**
- back/return restores prior shell context if technically safe and intuitive.

This exact navigation/history behavior is validated at Gate 9.

---

# 6. Failure/recovery flows

## BF-12 — Catalogue service unavailable

**Need**
User wants local options.

**Act**
- shell attempts public read.

**Recover**
- show concise retry state;
- do not force login;
- do not manufacture products from old assumptions;
- if an approved fresh-enough cache exists later, use only according to explicit cache policy.

---

## BF-13 — Product becomes unavailable after selection

**Need**
User tapped a Product that was just paused.

**Act**
- focused Product checks current truth.

**Recover**
- explain temporary unavailability;
- preserve safe shell Location;
- return to current catalogue;
- do not create partial transaction.

---

## BF-14 — Authentication interruption

**Need**
User prepared an action and was asked to sign in.

**Act**
- authentication provider flow starts.

**Recover variants**
- cancel → return to prepared public context;
- success → resolve Account, revalidate draft, continue;
- provider failure → safe retry;
- wrong Account → do not auto-submit; allow switch;
- return context expired → keep session, restart only invalid action context.

---

## BF-15 — Weak network / refresh / back button

**Need**
User continues despite unreliable mobile connectivity.

**Act**
- refresh/back/retry.

**Confirm**
- Location context remains understandable;
- public reads are safe to repeat;
- consequential commands are server/idempotency protected.

**Recover**
- no duplicate outcome;
- stale state triggers refetch rather than destructive reset.

---

# 7. Admin behaviour flow

## BF-16 — Platform Admin launches a Product in a Location

**Need**
“Learning is ready for Gomoh; make it available.”

**Decide**
Confirm actual integration readiness, not just marketing desire.

**Act**
1. Open admin context.
2. Select Location.
3. View current LocationProduct state and readiness evidence.
4. Request transition PREPARING → LIVE.
5. Server rechecks scope/current state/readiness.
6. Commit/audit.

**Confirm**
- public catalogue reflects LIVE without frontend code change.

**Recover**
- readiness missing → remain PREPARING with reason;
- stale state → refresh;
- duplicate click → same result;
- revoked admin → deny.

---

## BF-17 — Location Admin pauses one local Product

**Need**
Temporarily stop new entry because local operation is unavailable.

**Act**
- request LIVE → PAUSED within assigned Location.

**Confirm**
- only that Location/Product changes;
- other cities/products remain unaffected;
- history remains.

**Recover**
- wrong Location scope → deny;
- product currently OFF/PREPARING → show current state and allowed actions.

---

# 8. Trust behaviour flow

## BF-18 — Product requires phone trust

**Need**
Product wants stronger contact/accountability proof before a specific action.

**Decide**
Only request phone proof at that point.

**Act**
1. User is already authenticated.
2. Product/shared trust boundary explains why phone is needed.
3. Send challenge.
4. User submits OTP.
5. Server/provider verify.
6. Record exact phone-control trust fact.
7. Return to product action for fresh server revalidation.

**Confirm**
- UI says what was proven;
- no “identity verified” overclaim.

**Recover**
- OTP fail/timeout/provider outage → retain Account/session and safe draft; allow rule-compliant retry.

---

# 9. Location-not-supported flow

## BF-19 — User cannot find their town

**Need**
User expects Raahi in another location.

**Current V1 behavior**
- show only supported/selectable Locations;
- do not imply nationwide availability.

**Recover**
A future “Tell me when Raahi comes here” waitlist is not automatically added because it creates new consent/data/notification rules.

This remains a future product decision.

---

# 10. No-live-products flow

## BF-20 — Location exists but no Product is currently live

**Need**
User selected a legitimate Raahi Location.

**Act**
- catalogue returns no LIVE/visible PAUSED products.

**Confirm**
- page says Raahi has nothing ready there right now;
- does not fill space with unsupported categories.

**Recover**
- allow Location change;
- future interest notification requires separate decision.

---

# 11. Day-30 expectation test

By day 30, an established user should be able to answer without thinking:

- Which Location am I browsing?
- What Raahi services actually work here?
- How do I switch city?
- Am I signed in?
- Which focused Product am I currently using?
- Why am I being asked for phone/authentication now?
- Can I return to Raahi home?

If the UI requires them to understand:
- LocationProduct;
- capability;
- tenant;
- lifecycle;
- RPC;
- trust freshness;
- auth subject;
then Gate 9 fails.

---

# 12. Behaviour rules derived from simulations

1. Location selector must remain easy to find after initial selection.
2. Product selection must not be tied to a permanent user role.
3. Explicit current Location must be visible after deep-link/location change.
4. Auth handoff must be resumable or fail gracefully without destroying valid work.
5. Shared shell should remain useful to logged-out users on day 1 and day 30.
6. Multi-product use must not require duplicate Raahi Accounts.
7. Admin context must be explicit and separate from ordinary browsing context.
8. Focused Product—not the shared homepage—owns detailed product transaction behavior.
9. No-live/no-supported state must be a legitimate polished state, not an error.
10. Mobile interruption/refresh/back are normal behavior, not edge-only behavior.

---

# Gate 8 result

**PASS** for behavior modelling.

The next gate is **Gate 9 — UI behaviour validation and wording**.

Gate 9 must review the existing shell prototype against these journeys rather than assuming the current implementation is already frozen.
