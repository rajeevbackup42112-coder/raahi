# Raahi Learning V1.3 — Source Bundle Reconstruction

This directory reconstructs the inspected/tested Raahi Learning V1.3 browser source from GitHub while preserving the previously byte-verified original V1.3 source bundle.

The original V1.3 bundle remains immutable. The AI Builder v2 retrofit is stored as a separately verified patch layered on top of that baseline.

## Canonical reconstruction

Run from repository root:

```bash
node apps/raahi-learning/build-source-v13.mjs
```

Output:

`apps/raahi-learning/reconstructed-v13/`

The builder refuses to complete unless every integrity check below passes.

### Immutable original V1.3 base

Base tar SHA-256:

`9aa71d002775f719970fcf6d48c324f4f3270ac9f65aa1c7e8a2f9f17c2dc9cc`

The existing small tail pieces remain the canonical original-bundle piece order. Do not replace them with the superseded direct `part11.b64`, `part11-03.b64`, or `part11-03-03.b64` transfers that were previously observed to mutate bytes through the connector.

### AI Builder v2 retrofit patch

Patch source:

`apps/raahi-learning/retrofit-v13.patch.b64`

Compressed patch SHA-256:

`8a68163024ef1b100ebc4d56b8b1cfa56bf3459fc9f897952b6ca5602a19afa9`

Decoded patch SHA-256:

`ced0f5ca5b590e8ca344011f8f008c8fa719d57cca6ca3ead63b01a4fc6efc08`

The builder verifies the compressed bytes, decompresses them, verifies the raw patch, applies it to the immutable base, and then verifies the reconstructed source-file hashes.

## Frozen-source anchors

The original V1.1 frozen anchors remain unchanged:

- `app.fixture.js`: `6eb67b36931c45aa4113c77005d82c13bb14ec145500e08cfd92130ebcef576c`
- `styles.css`: `b2d89e454f8e13712d10058c876f5efe2c8c69acf73dd6aade158241900f7bdd`

Current retrofit anchors include:

- `README.md`: `1cb628ac91c839891123b0f4651e3db95be866c87186aa4bed7be8036f8043af`
- `app.live-core-v13.js`: `b8fea9446bba5171aa399d709eede2a0403949e96015157aa0ab1db320834a0f`
- `live.js`: `cdc44f514b1f396799313c977a4a48fe8efad33ae1f6054db776682c977796aa`
- `tests/cdp-v13-actions.mjs`: `612e8d5e404c9c84b8e3dd441cf863bae3aa1bc8d9d7e73aa6deef812b2d215f`
- `tests/cdp-live-contract.mjs`: `056788dcfa5c431b25385e7912bb24136d6d63f95bafc8a4bd48d8a22fe39acf`

`build-source-v13.mjs` contains the complete expected-file hash list.

## Independent persistent backup

ChatGPT Library backup:

`/Raahi Learning/Raahi_Learning_Integrated_V1.3_DEV.zip`

ZIP SHA-256:

`379dece3fb33fadd68843823a82917469b77e39b8d24448328b713ff98b246ef`

The Library ZIP is an independent handoff/backup artifact. GitHub base+patch reconstruction is the canonical source-control recovery path.

## Browser validation represented by this source

The reconstructed retrofit source passed:

- 84 reachable canonical routes;
- desktop + mobile live contract: **168/168**;
- 0 live-contract issues;
- 0 route/workspace guard failures;
- focused V1.3 action contracts: **12/12**;
- privileged deep-link guards: **32/32**;
- semantic checks: **15/15**;
- workspace checks: **154/154**;
- interaction checks: **26/26**;
- no direct browser DML against operational tables;
- no phone-primary OTP login path in `live.js`;
- frozen V1.1 fixture and CSS preserved byte-for-byte.

Real hosted Google OAuth, hosted phone OTP/reverification, and the mandatory walking skeleton remain external/runtime gates; they are not claimed by this source reconstruction.