# Raahi Learning V1.3 — Source Bundle Reconstruction

This folder makes the inspected/tested Raahi Learning V1.3 browser source reproducible from GitHub even though earlier direct large-file transfers through the connector were observed to mutate bytes.

## Canonical reconstruction

Run from the repository root:

```bash
node apps/raahi-learning/build-source-v13.mjs
```

The script reconstructs into:

`apps/raahi-learning/reconstructed-v13/`

It refuses to extract if the reconstructed tarball does not have this exact SHA-256:

`9aa71d002775f719970fcf6d48c324f4f3270ac9f65aa1c7e8a2f9f17c2dc9cc`

The builder also verifies representative critical source files after extraction.

## Important integrity rule

Do **not** replace the verified smaller tail pieces with the superseded direct `part11.b64`, `part11-03.b64`, or `part11-03-03.b64` forms. Those direct transfers were observed to mutate bytes and were removed from the branch. `build-source-v13.mjs` is the canonical piece order.

## Frozen-source anchors

- Frozen V1.1 fixture `app.fixture.js` SHA-256: `6eb67b36931c45aa4113c77005d82c13bb14ec145500e08cfd92130ebcef576c`
- Frozen styles `styles.css` SHA-256: `b2d89e454f8e13712d10058c876f5efe2c8c69acf73dd6aade158241900f7bdd`
- V1.3 live core SHA-256: `925ea0ecdbb95f76a2c548f3efa3fbdd3d99ac1bf355d5d59f945a626c14274b`
- V1.3 `live.js` SHA-256: `8ae054cbd24e33775f1782f78609531e1003ea391e6acd9a2c10c264caedf058`

## Independent persistent backup

ChatGPT Library backup:

`/Raahi Learning/Raahi_Learning_Integrated_V1.3_DEV.zip`

ZIP SHA-256:

`c1acb034d81da01379886cbea7311fd500b30375cb48b99c4e8bdde5e6a8e113`

The Library ZIP is a handoff/backup artifact only; GitHub reconstruction is the source-control recovery path.

## Validation evidence

The reconstructed tar source was compared to the inspected V1.3 integrated source. Source files matched byte-for-byte. Local generated audit-result JSON files are not included in the tar because they are test outputs, not application source.

The corresponding V1.3 browser validation includes:

- 83 canonical routes × desktop/mobile = 166 checks;
- 0 UI contract issues;
- 0 route/workspace guard failures;
- focused V1.3 action suite: 7/7 PASS;
- no direct browser DML against operational tables;
- no phone-primary OTP login path in `live.js`;
- frozen V1.1 fixture and CSS preserved byte-for-byte.
