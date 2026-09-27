# MyRaahi Shared Front Door — Gate 15 Side-Effects Matrix v0.1

Last updated: 2026-09-27

Method: AI Builder Cheat Code v2.0 — Gate 15

Status: **PASS AS SIDE-EFFECT SPECIFICATION**

Core rule:

> A business command is not complete until all required side effects are either committed consistently or explicitly classified as asynchronous/non-blocking.

The shared shell must stay small. Most focused-product side effects remain outside this matrix.

---

## 1. Side-effect classes

### Class A — business-coupled
Must succeed atomically with the core transition or the command fails.

Examples:
- authoritative state transition;
- unique authority grant;
- idempotency result necessary to prevent duplicate business effect.

### Class B — evidence-coupled
Must be created as part of the successful business command, preferably same transaction.

Examples:
- audit event for admin/governance changes.

### Class C — derived delivery
May happen after commit; failure does not roll back the core business state.

Examples:
- cache expiry/invalidation;
- analytics;
- future notifications;
- non-authoritative realtime refresh.

### Class D — navigation/local UX
Browser-only consequence. Never authoritative.

Examples:
- saved logged-out Location;
- redirect to focused Product;
- loading/success/error presentation.

---

# 2. Public discovery matrix

| Trigger | Core state write | Audit | Cache effect | External effect | UI effect | Failure semantics |
|---|---|---|---|---|---|---|
| Open home | none | none | public read may be cached | none | Location chooser/catalogue | read failure → retry state |
| Choose Location logged out | browser state only | none | next catalogue read | none | catalogue changes | invalid Location → chooser |
| Change Location logged out | browser state replace | none | next catalogue read | none | catalogue changes | previous durable state untouched |
| Open LIVE Product | none | none | none | navigation only | enter focused Product | unsafe URL → no navigation |
| View PAUSED Product | none | none | none | none | unavailable message | no LIVE action |

No analytics/notification is required for V1 public discovery.

---

# 3. Identity/auth matrix

| Trigger | Core state | Audit | External provider | Browser/session | Product effect | Failure |
|---|---|---|---|---|---|---|
| Start OAuth | no Raahi business write | none | Google/Supabase auth flow | PKCE verifier + return context | none yet | cancel/provider error leaves business state untouched |
| OAuth success | origin-local Supabase session | provider/auth logs only | Supabase issues session | local session established | future Account resolution | callback/allowlist error → safe auth failure |
| Resolve identity | no role grant | none by default | validate Supabase identity | same user UUID | Account lookup/bootstrap later | ambiguous mapping stops |
| Local sign-out | current origin session ends | none by default | Supabase local-session revoke | local auth key removed | other origin sessions unchanged | failure must not falsely claim sign-out |
| Global sign-out future | not implemented | future | multi-session semantics required | all intended sessions | all Raahi origins | must reopen Gate 13 |

No product authority is granted merely by OAuth success.

---

# 4. Future selected-Location Account preference

Command:
`set_my_selected_location`

| Side effect | Class | Required |
|---|---|---|
| AccountLocationPreference upsert | A | yes |
| Idempotency outcome | A | yes |
| Audit | none/default | no |
| Notification | none | no |
| Analytics | C | optional later |
| Public catalogue refetch | D | yes for UX |
| Product history mutation | forbidden | never |

---

# 5. Platform Admin — create Location

Command:
`admin_create_location`

| Side effect | Class | Required |
|---|---|---|
| Location row | A | yes |
| uniqueness enforcement | A | yes |
| idempotency record/result | A | yes |
| SharedAuditEvent | B | yes |
| cache refresh/expiry | C | yes operationally |
| notification | none V1 | no |
| analytics | C | optional |
| focused-product mutation | forbidden | never |

If audit cannot be created in the same authoritative transaction when the admin command layer is implemented, the command design must be reconsidered.

---

# 6. Platform Admin — Location lifecycle change

Command:
`admin_set_location_state`

| Side effect | Class | Required |
|---|---|---|
| lifecycle transition | A | yes |
| expected-state/concurrency guard | A | yes |
| idempotency | A | yes |
| audit before/after + reason | B | yes |
| public catalogue effect | C/read projection | yes after commit |
| existing Product history rewrite | forbidden | never |
| user notification | deferred | no V1 |

PAUSE/RETIRE changes admission/discovery, not historical ownership.

---

# 7. Product registry change

Commands:
- create Product
- update display
- retire Product

Required:
- A: Product canonical state
- A: validation of stable key/destination
- A: idempotency for consequential commands
- B: audit
- C: catalogue cache freshness
- D: changed public cards after fresh read

Forbidden:
- focused-product operational mutation;
- automatic provider verification;
- paid placement side effects.

---

# 8. LocationProduct transition

Command:
`admin_set_location_product_state`

This is the most important shared configuration transition.

| Side effect | Class | Required |
|---|---|---|
| LocationProduct state update | A | yes |
| current-state/readiness validation | A | yes |
| idempotency result | A | yes |
| audit before/after/reason | B | yes |
| public API projection changes | derived from A | yes |
| browser cache expiry/invalidation | C | yes operationally |
| frontend rebuild | forbidden dependency | never |
| focused-product history cancellation | forbidden | never |

### Proven staging behavior
A D1 PAUSED→LIVE change:
- changed API truth immediately;
- changed browser rendering after current `max-age=30`;
- required no Worker/frontend deployment.

This is acceptable current V1 behavior.

---

# 9. Location Admin assignment

Commands:
- assign Location Admin
- end assignment

Required:
- A: assignment row/state
- A: uniqueness/current-state guard
- A: idempotency
- B: audit including granting/revoking actor
- C: session/UI context may refresh

Forbidden:
- self-grant from selected Location;
- automatic Platform Admin;
- deletion of historical actions.

Revocation must take effect on the next server authorization check even if the browser UI is stale.

---

# 10. Future shared profile update

Command:
`update_my_raahi_profile`

Required:
- A: allowed presentation-field change
- A: ownership/account validation
- A: idempotency if submission is consequential enough

Optional:
- B audit only if future governance requires it
- C avatar cache refresh if media is later introduced

Forbidden:
- authority change;
- verification change;
- product-role change.

---

# 11. Future phone-trust commands

Deferred until a real shared action requires them.

Potential request challenge:
- external SMS/OTP send = C/external attempt;
- challenge server record = A if used;
- no trust state yet.

Verify challenge:
- provider proof = required evidence;
- phone trust timestamp/evidence = A;
- audit/security event = B where needed;
- product draft resume = D/C after proof.

Provider send/verify failure never creates trust.

---

# 12. Sponsored content — deferred

Doctrine only.

When implemented:
- payment/sponsor approval cannot be coupled to verification;
- placement expiry must stop visibility;
- ad analytics are derived/non-authoritative;
- organic/trust state never changes from sponsorship.

---

# 13. Focused Product boundary

The shared shell may trigger:
- navigation;
- safe Location context;
- origin-local authentication.

The shared shell does not own side effects such as:
- class membership;
- enquiry;
- ride booking;
- driver assignment;
- appointment;
- shop order;
- payment settlement;
- private messaging.

Those side-effect matrices remain inside the focused Product.

---

# 14. Side-effect failure law

After a core transition is committed:

### Must not roll back for
- analytics failure;
- optional notification failure;
- cache invalidation delay;
- UI refresh failure.

### Must fail/rollback before commit for
- authority failure;
- invalid current state;
- uniqueness violation;
- required audit/idempotency persistence if designed transactionally;
- required external evidence where business meaning depends on it.

---

# 15. Observability requirements

For every future shared consequential command record:
- command name;
- actor Account;
- actor scope;
- target;
- Location/Product scope;
- success/failure code;
- idempotency key/fingerprint reference;
- authoritative created/updated timestamp;
- audit event where required.

Do not log:
- OTP plaintext;
- access/refresh token;
- provider secret;
- unnecessary private payload.

---

# Gate 15 result

**PASS as the canonical side-effect specification.**

The first implemented public shell currently has almost no business side effects by design.

Next gate:
**Gate 16 — Mandatory Real Walking Skeleton.**
