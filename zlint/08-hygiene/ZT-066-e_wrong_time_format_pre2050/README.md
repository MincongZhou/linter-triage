# ZT-066 — `e_wrong_time_format_pre2050` names a correction that cannot be made

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `08-hygiene` — Descriptions, citations, severities and tests |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ |
| **Verified against** | zlint's own `SANCaseNotMatchingCN.pem` |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

The lint reports a `GeneralizedTime` used for a date before 2050, citing RFC
5280 § 4.1.2.5: "Certificates valid through the year 2049 MUST be encoded in
UTC time". Correct for a date `UTCTime` can express — and `UTCTime` carries a
two-digit year, so § 4.1.2.5.1 fixes its range at **1950 through 2049**.

`SANCaseNotMatchingCN.pem` has `notAfter` encoded `00010101000000Z`: **year
1**. It is before 2050 and outside `UTCTime` entirely, so the lint demands an
encoding that cannot represent the value. `Execute` compares
`t.Before(util.GeneralizedDate)` with no lower bound.

Low. The certificate is genuinely defective — a `notAfter` of year 1 is
nonsense — and no verdict about it changes. What is wrong is the remedy: a CA
acting on this finding has nowhere to go, because the defect is the value and
no encoding change repairs it.
