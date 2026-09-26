# MyRaahi Shared Front Door — Gate 4 Domain Invariant Register v0.1

Last updated: 2026-09-26

Method: AI Builder Cheat Code v2.0 — Gate 4

Scope: shared `myraahi.co.in` front door and shared identity/location foundation.

These truths must remain valid regardless of UI, hosting platform, database, authentication provider, or implementation framework.

---

## 1. Authority invariants

**INV-AUTH-01** — Authentication proves a technical identity/session, not Raahi business authority.

**INV-AUTH-02** — A selected Location never grants Location Admin or product authority.

**INV-AUTH-03** — Platform Admin authority exists only through current server-owned platform capability/governance state.

**INV-AUTH-04** — Location Admin authority exists only through a current active server-owned scoped assignment.

**INV-AUTH-05** — Product-specific authority remains owned by the focused Product and its current relationships/capabilities.

**INV-AUTH-06** — UI visibility, hidden controls, route access, client labels or stale cached role state never constitute authority.

**INV-AUTH-07** — Every consequential command resolves current Account + actor context/capability + target object + Location/Product scope at execution time.

---

## 2. Consent invariants

The shared front door currently has limited consent-bearing transitions, but the following still apply.

**INV-CONSENT-01** — Sign-in, phone verification, profile publication and future sponsored/provider onboarding cannot be inferred merely from browsing.

**INV-CONSENT-02** — Optional Google profile photo/default metadata cannot be silently published as Raahi public profile truth.

**INV-CONSENT-03** — A user choosing a Location consents only to browsing in that context; it does not imply membership, relocation, provider registration or admin assignment.

**INV-CONSENT-04** — If a focused Product requires consent between parties, the shared shell must not manufacture or collapse that consent.

---

## 3. Privacy invariants

**INV-PRIV-01** — Public discovery exposes only public-safe Location/Product data.

**INV-PRIV-02** — Shared shell does not need or receive focused-product private operational data merely for navigation convenience.

**INV-PRIV-03** — Passive browsing does not require phone, precise GPS or Account creation.

**INV-PRIV-04** — Trust/verification evidence is exposed only as the minimum claim necessary for the audience; raw evidence documents remain scoped to the relevant verification workflow.

**INV-PRIV-05** — Admin/support visibility is purpose- and scope-limited; Platform Admin is not automatically entitled to every focused-product private record.

**INV-PRIV-06** — Secrets, OTP plaintext, provider secrets and unsafe session material never enter public logs, URLs or client-readable configuration.

---

## 4. Agreement invariants

The shared shell itself does not create multi-party contractual/product agreements.

**INV-AGREE-01** — Entry into a focused Product or authentication cannot be treated as acceptance of another party's product-specific offer/request/agreement.

**INV-AGREE-02** — Where a focused Product has two-sided acceptance, each party's acceptance remains distinct and product-owned.

**INV-AGREE-03** — Shared Product availability state LIVE does not mean any particular provider/participant has agreed to an individual transaction.

---

## 5. Capacity invariants

The shared shell currently has no scarce transaction capacity such as seats or appointment slots.

**INV-CAP-01** — Shared catalogue state must not invent or reserve focused-product capacity.

**INV-CAP-02** — Any capacity claim shown by a focused Product remains authoritative only according to that Product's current server state.

**INV-CAP-03** — Future sponsored inventory, if limited, must not exceed configured placement capacity; payment demand cannot silently increase ad density beyond product limits.

---

## 6. Atomicity invariants

**INV-ATOM-01** — Consequential shared state transition and its required authoritative state changes succeed/fail together.

**INV-ATOM-02** — Admin authority assignment plus its required active-state/audit consequence cannot leave a half-authorized state.

**INV-ATOM-03** — Location/Product lifecycle command cannot partially update public state while leaving canonical relationship state contradictory.

**INV-ATOM-04** — Notification/analytics failure, when later added, must not normally roll back a successfully committed core transition unless the product rule explicitly makes the side effect part of the business transaction.

---

## 7. History invariants

**INV-HIST-01** — Changing selected Location does not rewrite historical product records.

**INV-HIST-02** — Pausing/offlining/retiring a LocationProduct changes new shared availability, not previously accepted focused-product history.

**INV-HIST-03** — Ending an admin assignment preserves assignment/action history.

**INV-HIST-04** — Product/Location renaming/display changes do not silently rewrite historical identifiers or accepted records.

**INV-HIST-05** — Audit history is append-oriented; corrective action creates new evidence rather than falsifying the past.

---

## 8. Evidence invariants

**INV-EVID-01** — Claimed, submitted, phone-confirmed, identity-verified, qualification-verified and approved are distinct states/facts.

**INV-EVID-02** — OTP success proves control of the challenged phone at the relevant time only.

**INV-EVID-03** — Authentication-provider success proves provider identity/session only.

**INV-EVID-04** — Public “LIVE” Product status requires actual readiness evidence defined by the integration contract; marketing intent alone is insufficient.

**INV-EVID-05** — Expired/revoked verification evidence cannot remain represented as current.

**INV-EVID-06** — A technology capability assumption is not considered proven until a real spike produces observed evidence.

---

## 9. Independence invariants

**INV-INDEP-01** — Payment/sponsorship cannot buy verification.

**INV-INDEP-02** — Payment/sponsorship cannot buy Platform/Location Admin authority.

**INV-INDEP-03** — Selected Location cannot buy/create product authority.

**INV-INDEP-04** — One product relationship does not automatically grant authority in another product.

**INV-INDEP-05** — Platform Admin governance does not automatically override focused-product business invariants.

**INV-INDEP-06** — Infrastructure vendor/account ownership does not itself establish Raahi business authority.

---

## 10. Retention and access invariants

**INV-RET-01** — Losing current participation/availability is separate from deleting historical records.

**INV-RET-02** — LocationProduct OFF/PAUSED/RETIRED does not automatically delete focused-product history.

**INV-RET-03** — Ending admin authority revokes future admin actions but preserves audit/history.

**INV-RET-04** — Closing an Account, deleting personal data, anonymizing history and terminating product relationships are separate decisions and must not be collapsed before explicit lifecycle/privacy design.

**INV-RET-05** — Temporary browser Location preference can be discarded without deleting durable Account/product data.

---

## 11. Money invariants

Current shared shell does not settle user transactions.

**INV-MONEY-01** — Core Raahi access remains free to users under current business doctrine.

**INV-MONEY-02** — Shared shell does not silently become payment settlement authority for focused products.

**INV-MONEY-03** — Advertising exists only as a limited survival-cost mechanism and remains separated from trust/verification/organic legitimacy.

**INV-MONEY-04** — If a future focused Product handles money, its settlement/refund/tax rules remain product-owned unless explicitly promoted to a proven shared payment service.

**INV-MONEY-05** — Paid OTP is an accepted operational expense; other recurring paid service dependencies require explicit exception/evidence review.

---

## 12. Idempotency invariants

**INV-IDEM-01** — Retrying a consequential shared command cannot duplicate the business outcome.

**INV-IDEM-02** — Same idempotency key with conflicting request fingerprint is rejected.

**INV-IDEM-03** — Network retry/browser refresh cannot create duplicate active Location Admin assignments or duplicate shared Product/Location entries.

**INV-IDEM-04** — Safe repeated public reads have no consequential side effect.

---

## 13. Server-authority invariants

**INV-SERVER-01** — Current authoritative server state beats stale UI/cache for consequential decisions.

**INV-SERVER-02** — Client-supplied verification timestamps, role labels, Product states or admin scopes are never trusted as canonical.

**INV-SERVER-03** — Public catalogue is derived from canonical shared Location/Product/LocationProduct state.

**INV-SERVER-04** — A focused Product validates its current product-specific state before completing a consequential action even if the shell previously showed it as LIVE.

**INV-SERVER-05** — Realtime/cache/navigation hints are delivery/context mechanisms, not authoritative business truth.

---

## 14. Safety invariants

The shared front door is not itself a high-risk safety product, but safety rules still apply.

**INV-SAFE-01** — Protective sign-out, access revocation, account recovery and admin revocation paths must not be blocked merely because optional trust evidence is stale.

**INV-SAFE-02** — If a Product becomes unsafe/unavailable, Raahi must be able to PAUSE/OFF it without deleting user history.

**INV-SAFE-03** — A failed auth/OTP/external provider flow must fail closed for protected actions while preserving safe recovery.

**INV-SAFE-04** — Public navigation must never send users to an unapproved arbitrary destination supplied by attacker-controlled configuration/client input.

**INV-SAFE-05** — Free-tier/cost pressure cannot justify knowingly false availability, weak authorization or unsafe credential handling.

---

## 15. Cross-invariant conflicts and precedence

When invariants appear to conflict, use these precedence rules:

1. Safety/security/privacy/authority constraints override convenience.
2. Historical truth overrides cosmetic consistency.
3. Current server authority overrides cached/previous UI state.
4. Minimum data overrides speculative future reuse.
5. Focused-product business authority overrides shared-shell assumptions about product transactions.
6. User's explicit current Location intent overrides an older saved preference, unless current Location is no longer valid/safe.

---

## 16. Reconciliation with existing domain model

The earlier `MYRAAHI_SHARED_FOUNDATION_DOMAIN_MODEL_V0.1.md` invariant list is compatible with this register.

This Gate 4 document becomes the canonical **business invariant register**.

The domain-model document remains the structural/data interpretation and must be revalidated at Gate 7.

---

## 17. Gate 4 result

**PASS.**

No invariant contradiction currently requires reopening Gate 0–3 decisions.

Next gate: **Gate 5 — complete state lifecycles and invalid transitions**.
