# Raahi Learning — StartMessaging Phone Trust Activation Contract V1.4H

Status: **ACTIVATION CANDIDATE — ALL PRE-ACTIVATION PROOFS PASSED**

## What changes

Google remains Raahi Learning's primary sign-in.

StartMessaging becomes the production delivery provider only when a canonical Raahi command requires fresh phone trust.

Release configuration:
- `phoneTrustMode = phone_trust_required`
- `phoneTrustProvider = startmessaging`

Database runtime setting:
- `phone_trust_mode = phone_trust_required`

## What does not change

- Phone OTP is not a second account or ordinary login.
- Roles, learner authority and admin authority continue to come from Raahi server relationships/capabilities.
- Safety/reporting actions that were not in the trust-sensitive command set remain available without an OTP gate.
- A fresh phone proof remains valid for 90 days.
- StartMessaging API key remains only in Supabase Edge Function Secrets.
- MessageCentral remains sealed.
- OTP plaintext is never persisted.

## Activation evidence already passed

1. StartMessaging KYC approved.
2. Provider sandbox real send succeeded.
3. Raahi hosted real send succeeded.
4. Ajit verified a real OTP.
5. Same Supabase Auth user survived.
6. Same Raahi Account survived.
7. Global Platform Admin capability survived.
8. Phone trust became `fresh`.
9. Logout -> Google login created a new sign-in event but returned to the same Auth user and same Raahi Account.
10. Phone trust remained `fresh` after re-login.
11. A protected canonical Raahi Desk command succeeded under `phone_trust_required` in a rollback transaction.
12. The protected proof left zero content residue.

## Deployment order

To avoid a half-enabled state:

1. qualify exact activation source and release package;
2. deploy the frontend artifact that knows `startmessaging` while the database still remains pilot mode;
3. verify the public artifact;
4. apply the V1.4H runtime-setting migration;
5. immediately verify:
   - policy = `phone_trust_required`;
   - Ajit remains `fresh`;
   - protected command passes for Ajit;
   - unverified account is denied;
6. run browser canary;
7. preserve the immediately previous Pages deployment as rollback anchor.

If the frontend deployment fails, do not apply the activation migration.
If the migration/post-activation proof fails, restore `controlled_pilot_google_only` and roll the frontend back.
