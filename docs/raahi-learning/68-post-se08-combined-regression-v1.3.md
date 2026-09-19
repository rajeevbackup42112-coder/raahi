# Post-SE-08 combined regression — V1.3

Status: **CLOSED IN DEV**. Verified 2026-09-19.

All 15 workflows passed on `a9f7ae577edb9a84120e20591de20d921cc66055`. The DEV harness artifact `dev-harness-proof.json` independently reports the same deployed commit, built at `2026-09-18T13:50:36.517Z`, with genuine Supabase sessions and intact RLS. This supersedes doc 59 as the latest combined regression anchor; doc 59 remains historical.

| Suite | Successful run | Artifact | SHA-256 |
|---|---|---|---|
| Organization Authority Side Effects | [35352509012](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35352509012) | 10550286850 | sha256:007d93615a76d32a9bde47ed58a71e0da9a046fb04868436315597624407fe44 |
| DEV E2E Harness | [35352509113](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35352509113) | 10550451912 | sha256:b7b047ac06d84ae5d34b45ed3e05d8d9101aa0e57aab13cd2fcb029e20634a93 |
| Organization Staff Boundaries | [35352509001](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35352509001) | 10550082149 | sha256:a39e432bc6cf02f06328423312ac6573ae3f31b40168720063f55a006d13b0cf |
| Model Tests | [35352509025](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35352509025) | Job logs | N/A |
| Class Post Side Effects | [35352509024](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35352509024) | 10550771001 | sha256:04b8a809f5039fbdb53109875a9cb4f356bbf1988f72e8c9a8baf1089bf62ddb |
| Enquiry Trial Side Effects | [35352509088](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35352509088) | 10550172026 | sha256:1eef9c217880945a4bfecea41aa568f6ca53ff0f02b568290a4072f42fd809b3 |
| Activity Side Effects | [35352509048](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35352509048) | 10551075835 | sha256:1ecb2f2366c95751313673f9a1f8ee32762f345277598eadfbf17e28d59d8e37 |
| Class Session Side Effects | [35352509074](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35352509074) | 10551026013 | sha256:ad24c1efd395178a78e58b2fe3f65c02fbd663d82f0eefe0db8fbdd05b9a3f3d |
| Class Lifecycle Side Effects | [35352509010](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35352509010) | 10550701813 | sha256:ab159e477d463e6de9315666157e31f17fe5afcacd8ef1a8a1b738ab63c3bd99 |
| UI Convergence Parent Org | [35352509019](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35352509019) | 10550516104 | sha256:eb6625e5c61f02c2f54fbb2510f8b13c8e60db8d1384ebcb035304d227804857 |
| Test Correction Side Effects | [35352509045](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35352509045) | 10551166485 | sha256:a2eebb8c14aff041522a97435a33eb322cea811942620f82de557e1459344057 |
| 20 Persona Cohort | [35352509033](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35352509033) | 10551065971 | sha256:2e2fa43e8a99cd4726bbd4bbcabbab251458239daa7f69dfc0eda6fc86e39d3a |
| UI Convergence Core | [35352509095](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35352509095) | 10550406897 | sha256:1a3931b2b489d29662aadbf320e41777796aafc33005f8745ff1f145076ed42e |
| UI Convergence Privileged | [35352508982](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35352508982) | 10551105895 | sha256:0a930685eaec9e3dc361b06b68cc669f5956fe15516b9e6a7d4bcae67b3d3fce |
| UI Convergence Ads | [35352508970](https://github.com/rajeevbackup42112-coder/raahi/actions/runs/35352508970) | 10551005925 | sha256:5069bc2b27f90ace30da6099935d6656c9f3c48e21d2c47197f0ed932efd3936 |

Artifacts have finite GitHub retention (DEV harness until 2026-10-02; other artifacts until 2026-10-18). Run links, identifiers and digests above preserve provenance, not the artifact bytes.

## Limits and continuation

This closes combined regression after all eight side-effect slices. It does not close the adversarial/recovery/race, reliability/load/security, periodic real-provider Auth smoke or launch gates. SE-08 removal proof includes a same-session document reload; it does not establish pure in-memory realtime invalidation. Continue with concurrent requests, committed-response recovery, stale authority and shared-device isolation in DEV. No public launch is authorized by this result.

