# ZT-025 — `e_crl_unique_revoked_certificate` has no reachable Error branch

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool |
| **Cases** | positive/ |
| **Verified against** | real CRL a certificate from Mozilla CA incident [bug 1943379](https://bugzilla.mozilla.org/show_bug.cgi?id=1943379) |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed `warn`; the class is `e_`-prefixed and, as shipped, structurally
cannot report anything past `warn`.

```go
func (l *uniqueRevokedCertificate) Execute(c *x509.RevocationList) *lint.LintResult {
    serials := make(map[string]bool)
    for _, rc := range c.RevokedCertificates {
        if serials[rc.SerialNumber.String()] {
            return &lint.LintResult{Status: lint.Warn, ...}
        }
        serials[rc.SerialNumber.String()] = true
    }
    return &lint.LintResult{Status: lint.Pass}
}
```

zlint's own test (`TestUniqueRevokedCertificate`) asserts `lint.Warn` for the
duplicate case, so this is deliberate rather than a slip. Until it is picked,
this class should be excluded from any error-floor denominator rather than
counted as an unmeasured gap — it was never going to answer past `Warn` on any
CRL.
