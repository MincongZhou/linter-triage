# ZT-011 — `e_excessively backdated` is switched off by the field it polices

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ and negative/ |
| **Verified against** | fixtures `excbakdat_sct1_old1_eff{0,1}.pem` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed `NE` for a certificate backdated to 2023-06-12; correct `error`.

The lint reports a `notBefore` more than 48 hours older than an embedded SCT.
It carries `EffectiveDate: util.SC62EffectiveDate` (2023-09-15) and the
framework decides applicability from `c.NotBefore` — the same field the lint
exists to distrust. Backdate past the ballot date and the only check that
detects a falsified issuance date disables itself.

Upstream's own test declares the `NE` intended, which does not make it
correct.

Fix: gate on the earliest embedded SCT timestamp, which the body already
parses.
