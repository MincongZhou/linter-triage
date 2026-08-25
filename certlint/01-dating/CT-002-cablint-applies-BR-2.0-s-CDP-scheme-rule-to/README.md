# CT-002 — cablint applies BR 2.0's CDP scheme rule to pre-2.0 certificates

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `01-dating` — Requirements applied to certificates that predate them |
| **Impact on certificates issued today** | **Medium** — changes the verdict on a narrow or infrequent shape still issued now, or on CA certificates in the wild |
| **Reproduction** | `./repro.sh` |
| **Requires** | the tool, openssl, a checkout of the tool (the script reads its source) |
| **Cases** | positive/ and negative/ |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

`lib/certlint/cablint.rb:282` requires every `cRLDistributionPoints` URI to
use the `http` scheme, unconditionally. That requirement arrived with BR 2.0.

```
certificate   issued 2021-11-24, two GeneralNames in one DistributionPoint
              URI:ldap://ldap07.actalis.it/...?certificateRevocationList;binary
              URI:http://crl07.actalis.it/Repository/AUTH-ROOT/getLastCRL

observed      E: CRL Distribution Point must be an HTTP URL
correct       no finding
```

**BR 1.8.7 §7.1.2.b**, in force at issuance: *"It MUST **contain** the HTTP
URL of the CA's CRL service."* This certificate contains it. **BR 2.0
§7.1.2.11.2** is what changed the requirement: *"All `GeneralName`s MUST be of
type `uniformResourceIdentifier`, and **the scheme of each** MUST be `http`."*

**Why this is a defect rather than a scope difference.** cablint is date-aware
and says so in its own source: it defines `BR_1_0_EFFECTIVE`,
`BR_1_7_1_EFFECTIVE`, `BR_2_0_0_EFFECTIVE` and `BR_2_0_1_EFFECTIVE` at lines
25–28, and gates other checks on `not_before` at lines 99, 297 and 328.

`cablint.rb:282` and `:285` are the CA branch; `:611` and `:614` are the
subscriber branch, with the identical pair of messages.

That is the distinction from a tool with no date mechanism at all, where
applying current requirements is a documented scope rather than an oversight.

Its condition is `ca_dps.length == 0`, which is true only for an **empty**
extension, whatever its message text says. Executed both ways on 2026-08-22:
draws it, and — a 2009 Deutsche Telekom intermediate whose only distribution
point is an `ldap://` URI — draws only the line-282 message. Apply the
proposed fix and cablint goes **silent** on that certificate, which pre-2.0 §
7.1.2.2.b requires to carry an HTTP URL. The fix would have traded an
over-report for a false negative.

The correct fix is two changes, because the two eras ask different questions:

```
from BR 2.0.0   report each distributionPoint whose scheme is not http   (282)
before it       report only when NONE of them is an http URI             (new)
```

The second branch does not exist in the source today; `ca_dps.length == 0` is
not it.
