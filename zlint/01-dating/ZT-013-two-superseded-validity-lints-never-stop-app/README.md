# ZT-013 — two superseded validity lints never stop applying

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | zlint's own testdata, both cases |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed `error` on a certificate issued 2021-09-01 from both the 39-month and
the 825-day lint; correct `NE` from both.

Each lint names the day it stopped applying, in its own `Description`, and
implements only the day it started:

```go
Description:   "Subscriber Certificates issued after 1 July 2016 but prior to
                1 March 2018 MUST have a Validity Period no greater than 39
                months.",
EffectiveDate: util.SubCert39Month,          // 2016-07-02

Description:   "Subscriber Certificates issued after 1 March 2018, but prior to
                1 September 2020, MUST NOT have a Validity Period greater than
                825 days.",
EffectiveDate: util.SubCert825Days,          // 2018-03-02
```

Neither sets `IneffectiveDate`, so `CheckEffective` tests the lower bound
alone. The field is not exotic: `lint.LintMetadata` carries it, 27 lints set
it, and this family uses it —
`lint_e_server_cert_valid_time_longer_than_200_days.go` bounds itself between
the two SC081 milestones, and `cabf_cs_br`'s 39-month lint between
`CABF_CS_BRs_1_2_Date` and `CABF_CS_CSC_31_Date`. Both closing constants
already exist in `util/time.go`: `util.SubCert825Days` closes the 39-month
lint, and `util.AppleReducedLifetimeDate` (2020-09-01) closes the 825-day one,
being the effective date of the 398-day lint that replaced it.

The control is the mechanism working. On `subCertValidTimeTooLong.pem`,
notBefore 2017-08-31, the 39-month lint reports `error` and the other two
report `NE`; on `SANIPv4Address.pem`, notBefore 2021-09-01, all three report
`error`.

No conformance verdict changes, which is why this is Low: every certificate
reported outside a window is also reported by the stricter limit that replaced
it. What changes is the count and the reason. A consumer tallying distinct
violated requirements sees three where the document states one, and two of the
three cite clauses that had been superseded before the certificate was signed.

Fix: `IneffectiveDate: util.SubCert825Days` on the 39-month lint, and
`IneffectiveDate: util.AppleReducedLifetimeDate` on the 825-day lint.
