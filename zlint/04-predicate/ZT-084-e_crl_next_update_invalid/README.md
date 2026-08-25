# ZT-084 — `e_crl_next_update_invalid` takes the CRL's population from a config flag, not from the CRL

| | |
|---|---|
| **Tool** | `zmap/zlint` at `v3.7.1-20-g1007b1d5` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, python3 |
| **Cases** | positive/ |
| **Verified against** | a real CCADB authority revocation list |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

```
$ zlint -format der positive/ZT-084-arl-only-ca-certs.crl
e_crl_next_update_invalid = error
  For CRLs covering Subscriber Certificates, nextUpdate must be at most 10 days after thisUpdate
```

The list says otherwise, in a critical extension:

```
X509v3 Issuing Distribution Point: critical
    Only CA Certificates
Last Update: May 13 18:00:00 2026 GMT
Next Update: May 11 23:59:59 2027 GMT
```

363 days, against BR § 7.2's twelve-month ceiling for a CRL covering CA
certificates. It conforms.

**The scope is configuration.**
`v3/lints/cabf_br/lint_crl_next_update_invalid.go`:

```go
type CrlNextUpdateInvalid struct {
    SubscriberCRL bool `comment:"Set this to false if the CRL to be linted covers CA certificates"`
}
```

`Execute` branches on that field and never reads `issuingDistributionPoint` —
which RFC 5280 § 5.2.5 makes the CRL's own statement of its population, and
which this list marks critical. **The shipped default is `true`**, confirmed
from `zlint -exampleConfig`, so an ARL is judged by the subscriber ceiling
unless the caller knew to reconfigure.

pkimetal sets it `false` for its ARL profiles only. A *full* CRL covering CA
certificates still gets the subscriber ceiling in production.

**Fix** — read the extension and keep the flag as an override for a caller
with other information. A list asserting neither boolean should keep the
subscriber ceiling: one that has not excluded end-entity certificates may hold
them.
