# ZT-015 — `e_root_ca_key_usage_must_be_critical` dates a Baseline Requirement to 1999

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | two real trust-store roots |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed `error` on a self-signed CA issued in 1999; correct `NE`, which is
what the sibling lint says about the same certificate in the same run.

```go
// lint_ca_key_usage_not_critical.go
Name:          "e_ca_key_usage_not_critical",
Source:        lint.CABFBaselineRequirements,
EffectiveDate: util.CABEffectiveDate,        // 2012-07-01

// lint_root_ca_key_usage_must_be_critical.go
Name:          "e_root_ca_key_usage_must_be_critical",
Source:        lint.CABFBaselineRequirements,
EffectiveDate: util.RFC2459Date,             // 1999-01-01
```

Two lints, one source, one requirement, thirteen years apart. On
`positive/ZT-015-root-in-window.pem` zlint returns `NE` and `error` for the
two at once, which is the whole report: no reading of the Baseline
Requirements makes both right, and the general lint is the one carrying the
Forum's own date.

`util.RFC2459Date` names a document that does not state the requirement. RFC
2459 §4.2.1.3 says the extension SHOULD be marked critical; the MUST is the
Forum's, and BR 1.1.0 Appendix B is where it appears, scoped to certificates
generated after that appendix took effect.

The control certificate holds every other property fixed and moves only
`notBefore`, so nothing but the date distinguishes the two outcomes.

Fix: `EffectiveDate: util.CABEffectiveDate`, matching the sibling and the
`Source` both lints already declare.
