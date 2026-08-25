# ZT-045 — the two oldest validity lints measure the Validity Period exclusively

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `05-spec-reading` — Differing analysis of the normative text |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl |
| **Cases** | positive/ and negative/ |
| **Verified against** | zlint's own testdata, with a real subscriber certificate and zlint's own control |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

Observed `pass` on a certificate whose notAfter is exactly notBefore plus 825
days; correct `error`. The same on the 39-month lint at exactly 39 months.

Both old lints compare the ceiling instant against `notAfter` with an
exclusive `Before`:

```go
if c.NotBefore.AddDate(0, 0, 825).Before(c.NotAfter) { Error }   // 825 days
if c.NotBefore.AddDate(0, 39, 0).Before(c.NotAfter) { Error }    // 39 months
```

Every validity lint written since measures the period inclusively, through one
helper in `util/time.go`:

```go
func CertificateValidityInSeconds(cert *x509.Certificate) float64 {
	return cert.NotAfter.Add(1 * time.Second).Sub(cert.NotBefore).Seconds()
}
```

Medium rather than High: the check is not suppressible and takes nothing else
down with it, but it fails to report a real requirement, and the population is
bounded — both windows closed before 2020-09-01 and the newer lints already
use the inclusive helper, so no new issuance can enter either set.

Fix: use the helper the rest of the family uses, and make the month-stated
comparison inclusive.

```go
if util.GreaterThan(c, 825) { Error }
if !c.NotAfter.Before(c.NotBefore.AddDate(0, 39, 0)) { Error }
```

Both fixtures then need their notAfter moved back one second to keep asserting
what their test names say they assert.
