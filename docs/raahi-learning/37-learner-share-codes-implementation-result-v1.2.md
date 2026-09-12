# Raahi Learning V1.2 — Learner Share Codes Implementation Result

Status: **IMPLEMENTED IN DEV AND PASSED SLICE GATE. STOP BEFORE ORGANIZATIONS / TEACHER DISCOVERY.**

Target Supabase project:

- ref: `iiwwmqokaeflaenhlyip`
- region: `ap-south-1`
- PostgreSQL: 17.6

## Applied migration

- `0250_learner_share_codes`

Source:

`supabase/migrations/0250_learner_share_codes.sql` on branch `raahi-learning-implementation-v1`.

## Implemented data model

`learner_share_codes`:

- `id uuid pk`
- `learner_id uuid fk learners`
- `created_by_account_id uuid fk accounts`
- `code_hash text unique not null`
- lifecycle `active | consumed | revoked | expired`
- finite `expires_at`
- `consumed_at`, `revoked_at`, `created_at`
- physical state/timestamp consistency checks
- physical partial uniqueness: at most one row with `state='active'` per Learner

## V1 policy decisions made during implementation

The frozen design allowed implementation discretion on several details. The implemented V1 policy is:

1. **Token entropy:** 24 random bytes (192 bits) generated inside PostgreSQL and encoded as URL-safe `rl_...` token text.
2. **Persistence:** plaintext is never persisted; only SHA-256 hash is stored.
3. **TTL:** 24 hours, expressed through private helper `learner_share_code_ttl()` so TTL can be changed by a forward migration without changing schema/command contract.
4. **One active code per Learner:** creating a replacement first records already-expired active rows as Expired and revokes any remaining active predecessor, then creates the replacement while holding the Learner row lock.
5. **Secret idempotency:** the first successful `create_learner_share_code` response returns plaintext once. The persisted idempotency result deliberately contains no plaintext or hash. A same-key replay returns the same logical share-code ID/expiry but `share_code = null`. If the first secret-bearing response is lost, the UI must explicitly request a replacement using a new idempotency key; that replacement revokes the previous active code.
6. **Protective revoke while paused:** creation requires normal active `can_make_learning_decision`; a paused current formal learner-side authority may revoke an already-issued code.

These choices preserve the stronger rule that a retry mechanism must never become secret storage.

## Commands and private primitive

Public authenticated commands:

- `create_learner_share_code(learner_id, idempotency_key)`
- `revoke_learner_share_code(share_code_id, idempotency_key)`

Private owner-only primitive prepared for the later Classes slice:

- `resolve_active_learner_share_code(plaintext_token)`

The resolver:

- is not a public API;
- requires exact high-entropy token possession;
- returns only Share Code ID + Learner ID;
- resolves only `active` and unexpired rows;
- locks the resolved row `FOR UPDATE` so `0502` can later compose atomic Invitation creation + token consumption.

No public Learner browse/search/directory endpoint or generic share-code resolve endpoint was added.

## Security / least privilege

- RLS enabled and forced on `learner_share_codes`;
- authenticated clients have no direct table read/write grant;
- explicit deny policy documents no-client-table-access intent;
- public wrappers are `SECURITY INVOKER`;
- private command implementations are `SECURITY DEFINER` with empty fixed `search_path`;
- private hash/generator/authority/resolver helpers are owner-only;
- `anon` cannot execute create/revoke RPCs;
- raw token is not written to Audit metadata, Idempotency result JSON, or the share-code table.

Post-slice function ACL inspection confirmed private helpers are owner-only except the two private command implementations intentionally executable through authenticated wrappers.

## Real runtime tests executed

Reusable source:

`tests/db/025_learner_share_codes_runtime_smoke.sql`

Executed markers:

- `SHARE_CODE_BASIC_PASS`
- `SHARE_CODE_PERMISSION_PASS`
- `SHARE_CODE_STATE_PASS`
- `SHARE_CODE_TERMINAL_PASS`

Verified against real PostgreSQL/Supabase:

- authorized manager can create private code;
- generated token has expected 192-bit URL-safe format;
- expiry is finite and currently ~24h;
- same-key retry creates no duplicate and never replays plaintext;
- same key with different Learner/request fingerprint is rejected;
- stored hash equals hash(exact plaintext) and plaintext itself is not stored;
- raw token absent from persisted Idempotency result and Audit metadata;
- exact token resolves through private helper;
- wrong token does not resolve;
- active Learner self Account cannot overrule active manager to create code;
- unrelated Account cannot create code;
- authenticated direct table read/write denied;
- authenticated private-resolver execution denied;
- anonymous create denied;
- no public resolve/search/browse Learner function exists;
- creating replacement revokes predecessor;
- at most one Active code per Learner is also physically enforced;
- expired-by-time token does not resolve and may be recorded Expired on learner-side revoke;
- revoked token does not resolve;
- consumed token does not resolve;
- terminal timestamp consistency check rejects contradictory consumed+revoked state;
- paused current formal manager can revoke existing token;
- revoke is idempotent/retry-safe.

All synthetic users/data were inside rollback transactions.

Final counts remain zero for:

- Auth users;
- Accounts;
- Learners;
- Locations;
- Learner Share Codes;
- Audit rows;
- Idempotency rows.

## Advisor review

Security Advisor after `0250`:

- **0 findings**

Performance Advisor:

- only expected `unused_index` INFO notices on the empty development database;
- no new security/RLS or overlapping-policy issue.

## Tests deliberately deferred, not falsely marked complete

The public invite-by-code command cannot exist until Classes exist. Therefore these master-catalog properties remain future gates:

- `SHR-004` atomic active-code consumption with valid Class Invitation;
- `SHR-005` second consumption rejection in real invite path;
- `SHR-008` real consume-vs-revoke concurrency — exactly one terminal outcome;
- `SHR-009` timeout-after-success retry — one Invitation, no double consume;
- `SHR-010` endpoint-level abuse/rate limiting.

They move to the Classes `0502` / staging security-concurrency gate. The current slice proves the independent secret lifecycle and authorization primitives those tests depend on.

## Slice verdict

**PASS.**

Foundation + Identity, Locations, and Learner Share Codes have now passed their controlled implementation gates.

Current stop gate:

> **STOP BEFORE ORGANIZATIONS / TEACHER DISCOVERY (`0300–0302`).**

Do not start Restrictions (`0350+`) until Organizations/Discovery passes its own ownership, capability, public projection, Saved privacy, RLS and command tests.